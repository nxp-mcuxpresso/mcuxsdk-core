# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require 'fileutils'
require 'tempfile'
require 'nokogiri'
require_relative '../../../../../../utils/sdk_utils'

module Internal
  module Mcux
    class ProjectDefinitionXml
      include SDKGenerator::SDKUtils
      def initialize(template, manifest_version, manifest_schema_dir, *_args, logger: nil, **_kwargs)
        @project_definition_xml = Nokogiri::XML(File.open(template), &:noblanks)
        # The root node
        @ksdk_examples_node = @project_definition_xml.at_xpath('examples')
        # The example node
        @example_node = @project_definition_xml.at_xpath('//examples/example')
        # The externalDefinitions node
        @externalDefinitions_node = @project_definition_xml.at_xpath('//examples/externalDefinitions')
        # The project type node
        @project_type_node = @project_definition_xml.at_xpath('//examples/example/projects')
        Core.assert(!@project_type_node.nil?) do
          'Project type must be non-empty.'
        end
        @toolchainSettings_node = Nokogiri::XML::Node.new('toolchainSettings', @project_definition_xml)
        @toolchainSetting_node = Nokogiri::XML::Node.new('toolchainSetting', @project_definition_xml)
        @toolchainSetting_node['id_refs'] = 'com.nxp.mcuxpresso'
        @toolchainSettings_node << @toolchainSetting_node
        @example_node << @toolchainSettings_node
        # The targets nodes : currently, redeye doesn't support multiple targtets. This way
        # is a fake one to adjust it to the generator core.
        @targets = {}
        @nodes = @project_definition_xml.xpath('//examples/example/target')
        @nodes.each do |target_node|
          target_name = target_node['name']
          Core.assert(!target_name.nil?) { 'missing target name' }
          # and use stripped version of target name
          @targets[ target_name.downcase ] = {
            'node' => target_node,
            'used' => false
          }
        end

        @logger = logger || Logger.new(STDOUT)

        @project_id = ''
        @project_name = ''
        @project_category = ''
        @corename = nil
        @coreid = nil
        @linked_project = nil

        @meta_componet = []
        @as_marco = {}
        @cc_marco = {}
        @cxx_marco = {}
        @undef_marco = {}
        @ld_marco = {}
        @mcux_include = []
        @link_lib = {}
        @sys_link_lib = {}
        @target = []
        @source = {}
        @prebuild_cmd = {}
        @postbuild_cmd = {}
        @tool_name = ''
        @toolchainfile_path = ''
        @binary_file_name = ''
        @build_type = 'exe'
        @converted_format = {}
        @jlink_script_file = {}
        @supportd_toolchains = ''
        @flash_driver_path = {}
        @manifest_version = manifest_version
        @manifest_schema_dir = manifest_schema_dir
        @trustzone_preprogram = ''
        @secure_gateway_importlib = []
        @secure_gateway_placement = {}
        @enable_secure_gateway_importlib = {}
        @link_file = {}
        @heap_stack_placement_style = {}
      end

      def targets
        return @targets.keys
      end

      # Get target node by target name and change it's flag to used
      # ==== arguments
      # target    - name of target
      def target_node(target, used: nil)
        Core.assert(target.is_a?(String) && !target.empty?) do
          'param must be non-empty string'
        end
        if @targets.key?(target)
          # use stripped downcase target name as key
          target = target.strip.downcase
          target_node = @targets[target]['node']
          @targets[target][ 'used' ] = true
          return target_node
        else
          return nil
        end
      end

      def add_extID(extid)
        whether_add = true
        @externalDefinitions_node.children.each do |definition_node|
          if definition_node['extID'] == extid
            whether_add = false
            break
          end
        end

        if whether_add
          definition_node = Nokogiri::XML::Node.new('definition', @project_definition_xml)
          definition_node['extID'] = extid
          @externalDefinitions_node << definition_node
        end
      end

      def projectname(proj_id, proj_name, proj_category, board_name)
        @project_id = proj_id
        @project_name = proj_name
        @project_category = proj_category
        @board_name = board_name
      end

      def add_toolchain(toolchains)
        @supportd_toolchains = toolchains
      end

      def add_source(path, vdir, filetype, toolchain, exclude)
        key = [File.dirname(path), vdir, filetype, toolchain, exclude].join(':')
        @source[key] = [] unless @source.key?(key)
        @source[key].push(File.basename(path)) unless @source[key].include?(File.basename(path))
      end

      def clear_sources!(*_args)
        @source.clear
      end

      def save(xmlpath)
        pre_build_steps_array = []
        post_build_steps_array = []
        ## targets free
        # Add meta-component
        @meta_componet.sort.each do |each|
          definition_node = Nokogiri::XML::Node.new('definition', @project_definition_xml)
          definition_node['extID'] = each
          @externalDefinitions_node << definition_node
        end

        @example_node['id'] = @project_id
        @example_node['name'] = @project_name
        @example_node['category'] = @project_category
        @example_node['dependency'] = @meta_componet.uniq.join(' ')
        if @coreid
          @example_node['device_core'] = @coreid
          add_extID(@coreid)
        end
        if @linked_project
          @example_node['linked_projects'] = @linked_project
          @linked_project.split(' ').each { |project| add_extID(project) }
        end
        unless @supportd_toolchains.empty?
          # Add the toolchain into extID
          @supportd_toolchains.split(/\s+/).each do |each|
            add_extID each
          end
        end

        unless @mcux_include.empty?
          include_paths_node = Nokogiri::XML::Node.new('include_paths', @project_definition_xml)
          @mcux_include.sort.each do |each_include|
            include_path_node = Nokogiri::XML::Node.new('include_path', @project_definition_xml)
            include_path_node['path'] = each_include
            include_paths_node << include_path_node
          end
          @example_node << include_paths_node
        end

        # Create source node
        @source.sort.each do |k, v|
          source_path, source_target_path, source_type, toolchain, exclude = k.split(':')
          source_node = Nokogiri::XML::Node.new('source', @project_definition_xml)
          source_node['path'] = source_path
          source_node['target_path'] = if source_target_path.nil? || source_target_path.strip.empty?
                                         # Add a default one
                                         'src'
                                       else
                                         source_target_path
                                       end
          source_node['type'] = source_type
          source_node['exclude'] = true if exclude == 'true' || exclude == true
          unless toolchain.nil? || toolchain == ''
            source_node['toolchain'] = toolchain
            toolchain.split(' ').each do |each|
              add_extID(each)
            end
          end
          v.uniq.sort.each do |file_name|
            files_node = Nokogiri::XML::Node.new('files', @project_definition_xml)
            files_node['mask'] = file_name
            source_node << files_node
          end
          @example_node << source_node
        end

        # Create the debug_configurations node
        unless @jlink_script_file.empty?
          @debug_configurations_node = Nokogiri::XML::Node.new('debug_configurations', @project_definition_xml)
          @toolchainSettings_node.after @debug_configurations_node
        end

        ## targets related
        # Add extra-lib into example_node as a source_node
        @targets.keys.each do |each_target|
          # get the corresponding target node
          target_node = target_node(each_target)
          # add the pre or post build cmd if needed.
          if !@prebuild_cmd.empty? || !@postbuild_cmd.empty?
            # add the prebuild cmd
            pre_build_steps_array.push(@prebuild_cmd[each_target]) if @prebuild_cmd.safe_key? each_target
            # add the postbuild cmd
            post_build_steps_array.push(@postbuild_cmd[each_target]) if @postbuild_cmd.safe_key? each_target
          end

          # lib should be presented in a source node regardless the targets.
          unless @link_lib.empty?
            @link_lib[each_target]&.sort&.each do |k, v|
              lib_path, lib_type, toolchain, virtual_dir = k.split(':')
              lib_node = Nokogiri::XML::Node.new('source', @project_definition_xml)
              lib_node['path'] = lib_path
              lib_node['type'] = lib_type
              lib_node['method'] = 'copy'
              lib_node['target_path'] = if virtual_dir.nil? || virtual_dir.strip.empty?
                                          # Add a default one
                                          'lib'
                                        else
                                          virtual_dir
                                        end

              unless toolchain.nil? || toolchain == ''
                lib_node['toolchain'] = toolchain
                toolchain.split(' ').each do |each|
                  add_extID(each)
                end
              end
              v.uniq.sort.each do |lib_name|
                lib_file_node = Nokogiri::XML::Node.new('files', @project_definition_xml)
                lib_file_node['mask'] = lib_name
                lib_node << lib_file_node
              end
              @example_node << lib_node
            end
          end

          if @jlink_script_file.key?(each_target)
            debug_configuration_node = Nokogiri::XML::Node.new('debug_configuration', @project_definition_xml)
            scripts_node = Nokogiri::XML::Node.new('scripts', @project_definition_xml)
            script_node = Nokogiri::XML::Node.new('script', @project_definition_xml)
            source_node = Nokogiri::XML::Node.new('source', @project_definition_xml)
            files_node = Nokogiri::XML::Node.new('files', @project_definition_xml)

            debug_configuration_node['id_refs'] = "com.nxp.mcuxpresso.core.debug.support.segger.#{each_target}"
            script_node['type'] = 'segger_script'
            source_node['path'] = File.dirname(@jlink_script_file[each_target])
            source_node['type'] = 'script'
            # The "target_path" is a required attribute in manifest 3.5
            source_node['target_path'] = 'script'
            files_node['mask'] = File.basename(@jlink_script_file[each_target])

            source_node << files_node
            script_node << source_node
            scripts_node << script_node
            debug_configuration_node << scripts_node
            @debug_configurations_node << debug_configuration_node

            add_extID("com.nxp.mcuxpresso.core.debug.support.segger.#{each_target}")
          end

          unless @link_file.empty?
            @link_file[each_target]&.each do |file, path|
              file_option = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.script"]')
              path_option = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.scriptdir"]')
              next if file_option.nil? || path_option.nil?
              file_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
              file_node.content = file
              file_option << file_node
              path_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
              path_node.content = path
              path_option << path_node
            end
          end

          # Add include path(c compiler include)
          unless @cc_marco.empty?
            @cc_marco[each_target]&.each do |macro|
              cc_defsymbols_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.compiler.option.preprocessor.def.symbols"]')
              next if cc_defsymbols_node_target.nil?
              macro_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
              macro_node.content = macro
              cc_defsymbols_node_target << macro_node
            end
          end

          unless @cxx_marco.empty?
            @cxx_marco[each_target]&.each do |macro|
              cpp_defsymbols_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.compiler.option.preprocessor.def"]')
              next if cpp_defsymbols_node_target.nil?
              macro_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
              macro_node.content = macro
              cpp_defsymbols_node_target << macro_node
            end
          end

          unless @undef_marco.empty?
            @undef_marco[each_target]&.each do |macro|
              undef_defsymbols_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.compiler.option.preprocessor.undef.symbol"]')
              next if undef_defsymbols_node_target.nil?
              macro_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
              macro_node.content = macro
              undef_defsymbols_node_target << macro_node
            end
          end

          unless @trustzone_preprogram.empty?
            preprogram_node = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.debugger.security.nonsecureimage"]')
            unless preprogram_node.nil?
              value_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
              value_node.content = @trustzone_preprogram
              preprogram_node << value_node
            end
          end

          unless @secure_gateway_importlib.empty?
            @secure_gateway_importlib&.each do | lib |
              lib_node = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.nonsecureobject"]')
              next if lib_node.nil?
              value_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
              value_node.content = lib
              lib_node << value_node
            end
          end

          # set secure gateway placement
          unless @secure_gateway_placement.empty?
            @secure_gateway_placement.each do |type, placement|
              placement_node = if type == 'c'
                                 target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.sgstubs.placement"]')
                               elsif type == 'cpp'
                                 target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.cpp.sgstubs.placement"]')
                               end
              unless placement_node.nil?
                value_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
                value_node.content = placement
                placement_node << value_node
              end
            end
          end

          # Enable generation of Secure Gateway Import Library
          unless @enable_secure_gateway_importlib.empty?
            @enable_secure_gateway_importlib.each do |type, enable|
              enable_node = if type == 'c'
                                 target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.sgstubenable"]')
                               elsif type == 'cpp'
                                 target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.cpp.sgstubenable"]')
                               end
              unless enable_node.nil?
                value_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
                value_node.content = enable
                enable_node << value_node
              end
            end
          end

          # Set heap and stack placement style
          unless @heap_stack_placement_style.empty?
            @heap_stack_placement_style.each do |type, style|
              if type == 'c'
                style_node = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.memory.heapAndStack.style"]')
                value = if style.strip.downcase == 'lpcxpresso style'
                          'com.crt.advproject.heapAndStack.lpcXpressoStyle'
                        else
                          'com.crt.advproject.heapAndStack.mcuXpressoStyle'
                        end
              elsif type == 'cpp'
                style_node = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.memory.heapAndStack.style.cpp"]')
                value = if style.strip.downcase == 'lpcxpresso style'
                          'com.crt.advproject.heapAndStack.lpcXpressoStyle.cpp'
                        else
                          'com.crt.advproject.heapAndStack.mcuXpressoStyle.cpp'
                        end
              end
              unless style_node.nil?
                value_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
                value_node.content = value
                style_node << value_node
              end
            end
          end

          # Delete the empty option node
          option_node = target_node.xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option')

          option_node.each do |each|
            if each.content.empty?
              each.remove
            else
              @toolchainSetting_node << each
            end
          end
        end
        # add postBuildStep and postBuildStep to toolchainSetting
        buildSteps_node = Nokogiri::XML::Node.new('buildSteps', @project_definition_xml)
        pre_build_steps_array&.uniq.each do |each_build_step|
          prebuild_node = Nokogiri::XML::Node.new('preBuildStep', @project_definition_xml)
          prebuild_node.content = each_build_step
          buildSteps_node << prebuild_node
        end
        post_build_steps_array&.uniq.each do |each_build_step|
          postbuild_node = Nokogiri::XML::Node.new('postBuildStep', @project_definition_xml)
          postbuild_node.content = each_build_step
          buildSteps_node << postbuild_node
        end
        @toolchainSetting_node.first_element_child.before(buildSteps_node) unless buildSteps_node.content.empty?

        # add the debug_configurations node
        unless @flash_driver_path.empty?
          @debug_configurations_node = Nokogiri::XML::Node.new('debug_configurations', @project_definition_xml) unless @project_definition_xml.at_xpath('//examples/example/debug_configurations')
          @debug_configuration_node = Nokogiri::XML::Node.new('debug_configuration', @project_definition_xml)
          @debug_configurations_node << @debug_configuration_node
          add_extID('com.crt.advproject.config.exe.debug')
          add_extID('com.crt.advproject.config.exe.release')
          # hardcode way
          @debug_configuration_node['id_refs'] = 'com.crt.advproject.config.exe.debug com.crt.advproject.config.exe.release'
          @drivers_node = Nokogiri::XML::Node.new('drivers', @project_definition_xml)
          @debug_configuration_node << @drivers_node

          @flash_driver_path.each do |id, path|
            driver_node = Nokogiri::XML::Node.new('driver', @project_definition_xml)
            driverBinary_node = Nokogiri::XML::Node.new('driverBinary', @project_definition_xml)
            files_node = Nokogiri::XML::Node.new('files', @project_definition_xml)
            driver_node << driverBinary_node
            driverBinary_node << files_node
            @drivers_node << driver_node

            driver_node['id_refs'] = id
            driverBinary_node['path'] = File.dirname(path)
            driverBinary_node['type'] = 'binary'
            driverBinary_node['target_path'] = 'binary'

            files_node['mask'] = File.basename(path)
          end
          @toolchainSettings_node.after(@debug_configurations_node)
        end
        # remove the target node
        @nodes.remove

        File.open(xmlpath, 'w') do |f|
          f.write(@project_definition_xml.to_xml(encoding: 'UTF-8'))
        end
        xml_array = []
        File.open(xmlpath, 'r') do |f|
          xml_array = f.readlines
          xml_array.each do |each|
            each.gsub!(/^<examples/, '<ksdk:examples')
            each.gsub!(/^<\/examples>/, '</ksdk:examples>')
          end
        end
        File.open(xmlpath, 'w') do |f|
          xml_array.each do |each|
            f.write(each)
          end
        end
        # validate <example>.xml with manifest schema
        @manifest_version&.each do | version |
          xsd = File.join(@manifest_schema_dir, "sdk_manifest_v#{version}.xsd")

          schema = Nokogiri::XML::Schema(File.open(xsd, 'r:utf-8').read)
          document = Nokogiri::XML(File.open(xmlpath))
          errors = schema.validate(document)
          err_msg = "For #{@board_name}, the generated #{@project_name}.xml is not valid against #{File.basename(xsd)}. Failed reason: #{errors.join(' ')}"
          raise err_msg unless errors.nil? || errors.empty?
        end
      end

      # Set project "nature" : cc
      def set_project_ccnature
        project_node = @project_definition_xml.at_xpath('/examples/example/projects/project[@nature="org.eclipse.cdt.core.cnature"]')
        project_node['nature'] = 'org.eclipse.cdt.core.ccnature' unless project_node.nil?
      end

      # Add meta-componet
      # ==== arguments
      # meta_componet    - meta component for each example
      def add_meta_component(meta_componet)
        @meta_componet.push(meta_componet) unless @meta_componet.include?(meta_componet)
      end

      # Add assembler 'name' macro of 'value' to target
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def add_assembler_macro(target, name, value)
        @as_marco[target] = [] unless @as_marco[target]
        if value.nil?
          @as_marco[target].push("-D#{name}")
        else
          @as_marco[target].push("-D#{name}=#{value}")
        end
        # @uvproj_file.assemblerTab.add_define(target, "#{name}=#{value}")
      end

      # Clear all assembler macros of target
      # ==== arguments
      # target    - target name
      def clear_assembler_macros!(target)
        @as_marco[target].clear if @as_marco.key?(target)
      end

      # Add compiler 'name' macro of 'value' to target
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def add_compiler_macro(target, name, value)
        @cc_marco[target] = [] unless @cc_marco[target]
        if value.nil?
          @cc_marco[target].push(name)
        else
          @cc_marco[target].push("#{name}=#{value}")
        end
      end

      # Clear all compiler macros of target
      # ==== arguments
      # target    - target name
      def clear_compiler_macros!(target)
        @cc_marco[target].clear if @cc_marco.key?(target)
      end

      def add_cpp_compiler_macro(target, name, value, *_args, **_kwargs)
        @cxx_marco[target] = [] unless @cxx_marco[target]
        if value.nil?
          @cxx_marco[target].push(name)
        else
          @cxx_marco[target].push("#{name}=#{value}")
        end
      end

      def clear_cxx_marcos!(target)
        @cxx_marco[target].clear if @cxx_marco.key?(target)
      end

      def undefine_compiler_macro(target, name, value)
        @undef_marco[target] = [] unless @undef_marco[target]
        if value.nil?
          @undef_marco[target].push(name)
        else
          @undef_marco[target].push("#{name}=#{value}")
        end
      end

      def clear_undefine_macro!(target)
        @undef_marco[target].clear if @undef_marco.key?(target)
      end

      def clear_core_info!
        @corename = nil
        @coreid = nil
      end

      def clear_linked_project!
        @linked_project = nil
      end

      def add_core_info(corename, coreid)
        @corename = corename
        @coreid = coreid
      end

      def add_linked_project(linked_project)
        @linked_project = (linked_project.split(' ').map { |project| @board_name + '_' + project }).join(' ') if linked_project
      end

      def add_trustzone_preprogram(trustzone_preprogram)
         name = "${linked:#{@board_name + '_' + trustzone_preprogram}}"
         @trustzone_preprogram = name
      end

      def add_secure_gateway_importlib(secure_gateway_importlib)
        secure_gateway_importlib&.each { |lib| @secure_gateway_importlib.push_uniq lib }
      end

      def set_secure_gateway_placement(secure_gateway_placement)
        type, placement = secure_gateway_placement.split(':').each { |item| item.strip! }
        if type == 'c'
          @secure_gateway_placement['c'] = "com.crt.advproject.link.sgstubs.#{placement}"
        elsif type == 'cpp'
          @secure_gateway_placement['cpp'] = "com.crt.advproject.link.cpp.sgstubs.#{placement}"
        end
      end

      def gen_secure_gateway_importlib(secure_gateway_importlib_gen)
        type, enable = secure_gateway_importlib_gen.split(':').each { |item| item.strip! }
        if type == 'c'
          @enable_secure_gateway_importlib['c'] = enable
        elsif type == 'cpp'
          @enable_secure_gateway_importlib['cpp'] = enable
        end
      end

      def set_heap_stack_placement(gen_cpp, heap_stack_placement)
        if gen_cpp
          @heap_stack_placement_style['cpp'] = heap_stack_placement
        else
          @heap_stack_placement_style['c'] = heap_stack_placement
        end
      end

      def enable_crp_in_image(target, enable_crp)
        return unless enable_crp

        target_node = target_node(target)
        return if target_node.nil?

        cpp_crp_node = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.cpp.crpenable"]')
        cpp_value_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
        cpp_value_node.content = enable_crp
        cpp_crp_node << cpp_value_node unless cpp_crp_node.nil?

        c_crp_node = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.crpenable"]')
        c_value_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
        c_value_node.content = enable_crp
        c_crp_node << c_value_node unless c_crp_node.nil?
      end

      def set_memory_sections(section_configs)
        unless section_configs.empty?
          # The memory node
          @memory_node = Nokogiri::XML::Node.new('memory', @project_definition_xml)
          ## No need to add the 'flash_size_kb' or 'ram_size_kb'
          # @memory_node['flash_size_kb'] = section_configs['flash_size_kb']
          # @memory_node['ram_size_kb'] = section_configs['ram_size_kb']
          section_configs['sections'].each do |_k, v|
            memoryBlock_node = Nokogiri::XML::Node.new('memoryBlock', @project_definition_xml)
            memoryBlock_node['addr'] = v['addr']
            memoryBlock_node['size'] = v['size']
            memoryBlock_node['access'] = v['access']
            memoryBlock_node['type'] = v['type']
            memoryBlock_node['id'] = v['id']
            memoryBlock_node['name'] = v['name']
            @memory_node << memoryBlock_node
          end
          @project_type_node.after(@memory_node)
        end
      end

      def set_debug_configuration(flash_id, driver_path)
        @flash_driver_path[flash_id] = driver_path unless driver_path.empty?
      end

      def add_c_preinclude(_target, cmd)
        @c_cmd = ' ' + cmd if cmd
      end

      def add_cpp_preinclude(_target, cmd)
        @cpp_cmd = ' ' + cmd if cmd
       end

      def set_jlink_script_file(target, value)
        @jlink_script_file[target] = value
      end

      ### Multicore configuration
      def set_multicore_configuration(target, configuration)
        target_node = target_node(target)
        return if target_node.nil?
        multicore_slave_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.gcc.multicore.slave"]')
        unless multicore_slave_node_target.nil?
          slave_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          slave_node_target.content = configuration
          multicore_slave_node_target << slave_node_target
        end
      end

      def set_cpp_multicore_configuration(target, configuration)
        target_node = target_node(target)
        return if target_node.nil?
        multicore_slave_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.cpp.multicore.slave"]')
        unless multicore_slave_node_target.nil?
          slave_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          slave_node_target.content = configuration
          multicore_slave_node_target << slave_node_target
        end
      end

      def configure_slaves(target, mastervalue, masteruserobjs)
        target_node = target_node(target)
        return if target_node.nil?
        multicore_master_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.gcc.multicore.master"]')
        unless multicore_master_node_target.nil?
          master_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          master_node_target.content = mastervalue
          multicore_master_node_target << master_node_target
        end

        multicore_master_userobjs_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.gcc.multicore.master.userobjs"]')
        unless multicore_master_userobjs_node_target.nil?
          master_userobjs_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          master_userobjs_node_target.content = masteruserobjs
          multicore_master_userobjs_node_target << master_userobjs_node_target
        end
      end

      def configure_cpp_slaves(target, mastervalue, masteruserobjs)
        target_node = target_node(target)
        return if target_node.nil?
        multicore_master_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.cpp.multicore.master"]')
        unless multicore_master_node_target.nil?
          master_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          master_node_target.content = mastervalue
          multicore_master_node_target << master_node_target
        end

        multicore_master_userobjs_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.cpp.multicore.master.userobjs"]')
        unless multicore_master_userobjs_node_target.nil?
          master_userobjs_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          master_userobjs_node_target.content = masteruserobjs
          multicore_master_userobjs_node_target << master_userobjs_node_target
        end
      end

      ### Asm Compiler options
      def assembler_set_architecture(target, architecture)
        target_node = target_node(target)
        return if target_node.nil?
        gas_arch_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gas.arch"]')
        unless gas_arch_node_target.nil?
          arch_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          arch_node_target.content = 'com.crt.advproject.gas.target.' + architecture
          gas_arch_node_target << arch_node_target
        end
      end

      def assembler_set_floating_point(target, float_point)
        target_node = target_node(target)
        return if target_node.nil?
        gas_fpu_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gas.fpu"]')
        unless gas_fpu_node_target.nil?
          fpu_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          fpu_node_target.content = 'com.crt.advproject.gas.fpu.' + float_point
          gas_fpu_node_target << fpu_node_target
        end
      end

      def assembler_suppress_warnings(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        warnings_nowarn_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.both.asm.option.warnings.nowarn"]')
        unless warnings_nowarn_node_target.nil?
          nowarn_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          nowarn_node_target.content = value
          warnings_nowarn_node_target << nowarn_node_target
        end
      end

      def assembler_add_assembler_flag(target, line)
        target_node = target_node(target)
        return if target_node.nil?
        flags_crt_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.both.asm.option.flags.crt"]')
        unless flags_crt_node_target.nil?
          crt_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          crt_node_target.content = line
          flags_crt_node_target << crt_node_target
        end
      end

      ### C Compiler Options
      ###
      def ccompiler_set_architecture(target, architecture)
        target_node = target_node(target)
        return if target_node.nil?
        gcc_arch_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gcc.arch"]')
        unless gcc_arch_node_target.nil?
          arch_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          arch_node_target.content = 'com.crt.advproject.gcc.target.' + architecture
          gcc_arch_node_target << arch_node_target
        end
      end

      def ccompiler_set_floating_point(target, float_point)
        target_node = target_node(target)
        return if target_node.nil?
        gcc_fpu_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gcc.fpu"]')
        unless gcc_fpu_node_target.nil?
          fpu_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          fpu_node_target.content = 'com.crt.advproject.gcc.fpu.' + float_point
          gcc_fpu_node_target << fpu_node_target
        end
      end

      def ccompiler_set_language_standard(target, language)
        target_node = target_node(target)
        return if target_node.nil?
        misc_dialect_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.c.misc.dialect"]')
        unless misc_dialect_node_target.nil?
          dialect_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          dialect_node_target.content = 'com.crt.advproject.misc.dialect.' + language
          misc_dialect_node_target << dialect_node_target
        end
      end

      def ccompiler_set_debugging_level(target, level)
        target_node = target_node(target)
        return if target_node.nil?
        debugging_level_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gcc.exe.debug.option.debugging.level"]')
        unless debugging_level_node_target.nil?
          level_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          level_node_target.content = 'gnu.c.debugging.level.' + level
          debugging_level_node_target << level_node_target
        end

        debugging_level_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gcc.exe.release.option.debugging.level"]')
        unless debugging_level_node_target.nil?
          level_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          level_node_target.content = 'gnu.c.debugging.level.' + level
          debugging_level_node_target << level_node_target
        end
      end

      def ccompiler_inhibit_all_warnings(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        warnings_nowarn_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.compiler.option.warnings.nowarn"]')
        unless warnings_nowarn_node_target.nil?
          nowarn_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          nowarn_node_target.content = value
          warnings_nowarn_node_target << nowarn_node_target
        end
      end

      def ccompiler_set_all_warnings(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        warnings_allwarn_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.compiler.option.warnings.allwarn"]')
        unless warnings_allwarn_node_target.nil?
          allwarn_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          allwarn_node_target.content = value
          warnings_allwarn_node_target << allwarn_node_target
        end
      end

      def ccompiler_set_extra_warnings(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        warnings_extrawarn_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.compiler.option.warnings.extrawarn"]')
        unless warnings_extrawarn_node_target.nil?
          extrawarn_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          extrawarn_node_target.content = value
          warnings_extrawarn_node_target << extrawarn_node_target
        end
      end

      def ccompiler_set_implicit_conversion_warnings(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        warnings_wconversion_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.compiler.option.warnings.wconversion"]')
        unless warnings_wconversion_node_target.nil?
          wconversion_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          wconversion_node_target.content = value
          warnings_wconversion_node_target << wconversion_node_target
        end
      end

      def ccompiler_set_warnings_as_errors(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        warnings_toerrors_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.compiler.option.warnings.toerrors"]')
        unless warnings_toerrors_node_target.nil?
          toerrors_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          toerrors_node_target.content = value
          warnings_toerrors_node_target << toerrors_node_target
        end
      end

      def ccompiler_enable_link_time_optimization(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        gcc_lto_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gcc.lto"]')
        unless gcc_lto_node_target.nil?
          lto_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          lto_node_target.content = value
          gcc_lto_node_target << lto_node_target
        end
      end

      def ccompiler_optimization_level(target, level)
        # debug
        target_node = target_node(target)
        return if target_node.nil?
        optimization_flags_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gcc.exe.debug.option.optimization.level"]')
        unless optimization_flags_node_target.nil?
          flags_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          flags_node_target.content = 'gnu.c.optimization.level.' + level
          optimization_flags_node_target << flags_node_target
        end
        # release
        optimization_flags_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gcc.exe.release.option.optimization.level"]')
        unless optimization_flags_node_target.nil?
          flags_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          flags_node_target.content = 'gnu.c.optimization.level.' + level
          optimization_flags_node_target << flags_node_target
        end
      end

      def ccompiler_set_ccompiler_optimization_flags(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        optimization_flags_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.compiler.option.optimization.flags"]')
        unless optimization_flags_node_target.nil?
          flags_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          flags_node_target.content = value
          optimization_flags_node_target << flags_node_target
        end
      end

      def ccompiler_do_not_search_system_directories(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        preprocessor_nostdinc_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.compiler.option.preprocessor.nostdinc"]')
        unless preprocessor_nostdinc_node_target.nil?
          nostdinc_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          nostdinc_node_target.content = value
          preprocessor_nostdinc_node_target << nostdinc_node_target
        end
      end

      ### secure state configuration
      def ccompiler_add_secure_state(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        secure_state_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gcc.securestate"]')
        unless secure_state_node_target.nil?
          node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          node_target.content = 'com.crt.advproject.gcc.securestate.' + value
          secure_state_node_target << node_target
        end
      end

      def ccompiler_add_other_flags(target, line)
        target_node = target_node(target)
        return if target_node.nil?
        misc_other_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.compiler.option.misc.other"]')
        unless misc_other_node_target.nil?
          other_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          other_node_target.content = if @c_cmd
                                        line + @c_cmd
                                      else
                                        line
                                      end
          misc_other_node_target << other_node_target
        end
      end

      ###
      #  cpp compiler settings
      def cppcompiler_set_architecture(target, architecture)
        target_node = target_node(target)
        return if target_node.nil?
        cpp_arch_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.cpp.arch"]')
        unless cpp_arch_node_target.nil?
          arch_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          arch_node_target.content = 'com.crt.advproject.cpp.target.' + architecture
          cpp_arch_node_target << arch_node_target
        end
      end

      def cppcompiler_set_floating_point(target, float_point)
        target_node = target_node(target)
        return if target_node.nil?
        cpp_fpu_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.cpp.fpu"]')
        unless cpp_fpu_node_target.nil?
          fpu_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          fpu_node_target.content = 'com.crt.advproject.cpp.fpu.' + float_point
          cpp_fpu_node_target << fpu_node_target
        end
      end

      def cppcompiler_set_language_standard(target, language)
        target_node = target_node(target)
        return if target_node.nil?
        misc_dialect_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.cpp.misc.dialect"]')
        unless misc_dialect_node_target.nil?
          dialect_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          dialect_node_target.content = 'com.crt.advproject.misc.dialect.' + language
          misc_dialect_node_target << dialect_node_target
        end
      end

      def cppcompiler_set_debugging_level(target, level)
        target_node = target_node(target)
        return if target_node.nil?
        debugging_level_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.cpp.exe.debug.option.debugging.level"]')
        unless debugging_level_node_target.nil?
          level_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          level_node_target.content = 'gnu.cpp.compiler.debugging.level.' + level
          debugging_level_node_target << level_node_target
        end

        debugging_level_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.cpp.exe.release.option.debugging.level"]')
        unless debugging_level_node_target.nil?
          level_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          level_node_target.content = 'gnu.cpp.compiler.debugging.level.' + level
          debugging_level_node_target << level_node_target
        end
      end

      def cppcompiler_inhibit_all_warnings(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        warnings_nowarn_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.compiler.option.warnings.nowarn"]')
        unless warnings_nowarn_node_target.nil?
          nowarn_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          nowarn_node_target.content = value
          warnings_nowarn_node_target << nowarn_node_target
        end
      end

      def cppcompiler_set_all_warnings(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        warnings_allwarn_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.compiler.option.warnings.allwarn"]')
        unless warnings_allwarn_node_target.nil?
          allwarn_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          allwarn_node_target.content = value
          warnings_allwarn_node_target << allwarn_node_target
        end
      end

      def cppcompiler_set_extra_warnings(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        warnings_extrawarn_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.compiler.option.warnings.extrawarn"]')
        unless warnings_extrawarn_node_target.nil?
          extrawarn_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          extrawarn_node_target.content = value
          warnings_extrawarn_node_target << extrawarn_node_target
        end
      end

      def cppcompiler_set_implicit_conversion_warnings(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        warnings_wconversion_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.compiler.option.warnings.wconversion"]')
        unless warnings_wconversion_node_target.nil?
          wconversion_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          wconversion_node_target.content = value
          warnings_wconversion_node_target << wconversion_node_target
        end
      end

      def cppcompiler_set_warnings_as_errors(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        warnings_toerrors_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.compiler.option.warnings.toerrors"]')
        unless warnings_toerrors_node_target.nil?
          toerrors_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          toerrors_node_target.content = value
          warnings_toerrors_node_target << toerrors_node_target
        end
      end

      def cppcompiler_enable_link_time_optimization(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        cpp_lto_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.cpp.lto"]')
        unless cpp_lto_node_target.nil?
          lto_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          lto_node_target.content = value
          cpp_lto_node_target << lto_node_target
        end
      end

      def cppcompiler_optimization_level(target, level)
        target_node = target_node(target)
        return if target_node.nil?
        # debug
        optimization_flags_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.cpp.exe.debug.option.optimization.level"]')
        unless optimization_flags_node_target.nil?
          flags_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          flags_node_target.content = 'gnu.cpp.compiler.optimization.level.' + level
          optimization_flags_node_target << flags_node_target
        end
        # release
        optimization_flags_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.cpp.exe.release.option.optimization.level"]')
        unless optimization_flags_node_target.nil?
          flags_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          flags_node_target.content = 'gnu.cpp.compiler.optimization.level.' + level
          optimization_flags_node_target << flags_node_target
        end
      end

      def cppcompiler_set_ccompiler_optimization_flags(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        optimization_flags_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.compiler.option.optimization.flags"]')
        unless optimization_flags_node_target.nil?
          flags_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          flags_node_target.content = value
          optimization_flags_node_target << flags_node_target
        end
      end

      def cppcompiler_do_not_search_system_directories(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        preprocessor_nostdinc_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.compiler.option.preprocessor.nostdinc"]')
        unless preprocessor_nostdinc_node_target.nil?
          nostdinc_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          nostdinc_node_target.content = value
          preprocessor_nostdinc_node_target << nostdinc_node_target
        end
      end

      ### cpp secure state configuration
      def cppcompiler_add_secure_state(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        secure_state_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.cpp.securestate"]')
        unless secure_state_node_target.nil?
          node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          node_target.content = 'com.crt.advproject.cpp.securestate.' + value
          secure_state_node_target << node_target
        end
      end

      def cppcompiler_add_other_flags(target, line)
        target_node = target_node(target)
        return if target_node.nil?
        misc_other_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.compiler.option.other.other"]')
        unless misc_other_node_target.nil?
          other_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          other_node_target.content = if @cpp_cmd
                                        line + @cpp_cmd
                                      else
                                        line
                                      end
          misc_other_node_target << other_node_target
        end
      end

      ###
      #  clinker settings
      def clinker_set_architecture(target, architecture)
        target_node = target_node(target)
        return if target_node.nil?
        link_arch_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.arch"]')
        unless link_arch_node_target.nil?
          arch_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          arch_node_target.content = 'com.crt.advproject.link.target.' + architecture
          link_arch_node_target << arch_node_target
        end
      end

      def clinker_set_floating_point(target, float_point)
        target_node = target_node(target)
        return if target_node.nil?
        link_fpu_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.fpu"]')
        unless link_fpu_node_target.nil?
          fpu_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          fpu_node_target.content = 'com.crt.advproject.link.fpu.' + float_point
          link_fpu_node_target << fpu_node_target
        end
      end

      def clinker_set_standard_start_files(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_nostart_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.link.option.nostart"]')
        unless option_nostart_node_target.nil?
          nostart_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          nostart_node_target.content = value
          option_nostart_node_target << nostart_node_target
        end
      end

      def clinker_set_use_default_libraries(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_nodeflibs_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.link.option.nodeflibs"]')
        unless option_nodeflibs_node_target.nil?
          nodeflibs_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          nodeflibs_node_target.content = value
          option_nodeflibs_node_target << nodeflibs_node_target
        end
      end

      def clinker_set_no_startup_or_default_libs(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_nostdlibs_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.link.option.nostdlibs"]')
        unless option_nostdlibs_node_target.nil?
          nodeflibs_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          nodeflibs_node_target.content = value
          option_nostdlibs_node_target << nodeflibs_node_target
        end
      end

      def clinker_omit_all_symbol_information(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_strip_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.link.option.strip"]')
        unless option_strip_node_target.nil?
          strip_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          strip_node_target.content = value
          option_strip_node_target << strip_node_target
        end
      end

      def clinker_set_nostaticlib(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_noshared_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.link.option.noshared"]')
        unless option_noshared_node_target.nil?
          noshared_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          noshared_node_target.content = value
          option_noshared_node_target << noshared_node_target
        end
      end

      def clinker_set_option_lib(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_lib_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.link.option.libs"]')
        unless option_lib_node_target.nil?
          lib_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          lib_node_target.content = value
          option_lib_node_target << lib_node_target
        end
      end

      def clinker_set_memory_load_image(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        c_memory_load_image = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.memory.load.image"]')
        unless c_memory_load_image.nil?
          value_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
          value_node.content = value
          c_memory_load_image << value_node
        end
      end

      def clinker_set_memory_section(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        c_memory_section_nodes = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.memory.sections"]')
        unless c_memory_section_nodes.nil?
          value_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
          value_node.content = value
          c_memory_section_nodes << value_node
        end
      end

      def clinker_set_other_linker_options(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_other_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.link.option.other"]')
        unless option_other_node_target.nil?
          other_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          other_node_target.content = value
          option_other_node_target << other_node_target
        end
      end

      def clinker_set_linker_heap_stack(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        memory_heapAndStack_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.memory.heapAndStack"]')
        unless memory_heapAndStack_node_target.nil?
          heapAndStack_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          heapAndStack_node_target.content = value
          memory_heapAndStack_node_target << heapAndStack_node_target
        end
      end

      ### secure state configuration
      def clinker_add_secure_state(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        secure_state_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.securestate"]')
        unless secure_state_node_target.nil?
          node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          node_target.content = 'com.crt.advproject.link.securestate.' + value
          secure_state_node_target << node_target
        end
      end

      def clinker_add_linker_flag(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_ldflags_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.link.option.ldflags"]')
        unless option_ldflags_node_target.nil?
          ldflags_node_target = option_ldflags_node_target.at_xpath('value')
          if ldflags_node_target.nil?
            ldflags_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
            ldflags_node_target.content = value
            option_ldflags_node_target << ldflags_node_target
          else
            ldflags_node_target.content = ldflags_node_target.content + ' ' + value
          end
        end
      end

      def clinker_add_other_objects(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_userobjs_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.c.link.option.userobjs"]')
        unless option_userobjs_node_target.nil?
          userobjs_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          userobjs_node_target.content = value
          option_userobjs_node_target << userobjs_node_target
        end
      end

      def clinker_add_linker_toram(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_link_toram_node = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.toram"]')
        unless option_link_toram_node.nil?
          link_toram_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
          link_toram_node.content = value
          option_link_toram_node << link_toram_node
        end
      end

      def clinker_set_memory_data(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_link_memory_data_node = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.memory.data"]')
        unless option_link_memory_data_node.nil?
          link_memory_data_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
          link_memory_data_node.content = value
          option_link_memory_data_node << link_memory_data_node
        end
      end

      ###
      #  cpplinker settings
      def cpplinker_add_other_objects(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_userobjs_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.link.option.userobjs"]')
        unless option_userobjs_node_target.nil?
          userobjs_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          userobjs_node_target.content = value
          option_userobjs_node_target << userobjs_node_target
        end
      end

      ### cpp secure state configuration
      def cpplinker_add_secure_state(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        secure_state_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.cpp.securestate"]')
        unless secure_state_node_target.nil?
          node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          node_target.content = 'com.crt.advproject.link.cpp.securestate.' + value
          secure_state_node_target << node_target
        end
      end

      def cpplinker_add_linker_toram(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_link_toram_node = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.cpp.toram"]')
        unless option_link_toram_node.nil?
          link_toram_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
          link_toram_node.content = value
          option_link_toram_node << link_toram_node
        end
      end

      def cpplinker_set_memory_data(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_link_memory_data_node = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.memory.data.cpp"]')
        unless option_link_memory_data_node.nil?
          link_memory_data_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
          link_memory_data_node.content = value
          option_link_memory_data_node << link_memory_data_node
        end
      end

      def cpplinker_set_architecture(target, architecture)
        target_node = target_node(target)
        return if target_node.nil?
        cpp_arch_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.cpp.arch"]')
        unless cpp_arch_node_target.nil?
          arch_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          arch_node_target.content = 'com.crt.advproject.link.cpp.target.' + architecture
          cpp_arch_node_target << arch_node_target
        end
      end

      def cpplinker_set_floating_point(target, float_point)
        target_node = target_node(target)
        return if target_node.nil?
        cpp_fpu_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.cpp.fpu"]')
        unless cpp_fpu_node_target.nil?
          fpu_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          fpu_node_target.content = 'com.crt.advproject.link.cpp.fpu.' + float_point
          cpp_fpu_node_target << fpu_node_target
        end
      end

      def cpplinker_set_standard_start_files(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_nostart_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.link.option.nostart"]')
        unless option_nostart_node_target.nil?
          nostart_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          nostart_node_target.content = value
          option_nostart_node_target << nostart_node_target
        end
      end

      def cpplinker_set_use_default_libraries(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_nodeflibs_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.link.option.nodeflibs"]')
        unless option_nodeflibs_node_target.nil?
          nodeflibs_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          nodeflibs_node_target.content = value
          option_nodeflibs_node_target << nodeflibs_node_target
        end
      end

      def cpplinker_set_no_startup_or_default_libs(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_nostdlibs_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.link.option.nostdlibs"]')
        unless option_nostdlibs_node_target.nil?
          nodeflibs_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          nodeflibs_node_target.content = value
          option_nostdlibs_node_target << nodeflibs_node_target
        end
      end

      def cpplinker_omit_all_symbol_information(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_strip_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.link.option.strip"]')
        unless option_strip_node_target.nil?
          strip_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          strip_node_target.content = value
          option_strip_node_target << strip_node_target
        end
      end

      def cpplinker_set_nostaticlib(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_noshared_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.link.option.noshared"]')
        unless option_noshared_node_target.nil?
          noshared_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          noshared_node_target.content = value
          option_noshared_node_target << noshared_node_target
        end
      end

      def cpplinker_set_option_lib(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_lib_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.link.option.libs"]')
        unless option_lib_node_target.nil?
          lib_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          lib_node_target.content = value
          option_lib_node_target << lib_node_target
        end
      end

      def cpplinker_set_memory_load_image(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        cpp_memory_load_image = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.memory.load.image.cpp"]')
        unless cpp_memory_load_image.nil?
          value_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
          value_node.content = value
          cpp_memory_load_image << value_node
        end
      end

      def cpplinker_set_memory_section(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        cpp_memory_section_nodes = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.memory.sections.cpp"]')
        unless cpp_memory_section_nodes.nil?
          value_node = Nokogiri::XML::Node.new('value', @project_definition_xml)
          value_node.content = value
          cpp_memory_section_nodes << value_node
        end
      end

      def cpplinker_set_other_linker_options(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_other_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.link.option.other"]')
        unless option_other_node_target.nil?
          other_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          other_node_target.content = value
          option_other_node_target << other_node_target
        end
      end

      def cpplinker_set_linker_heap_stack(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        heapAndStack_cpp_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.memory.heapAndStack.cpp"]')
        unless heapAndStack_cpp_node_target.nil?
          cpp_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          cpp_node_target.content = value
          heapAndStack_cpp_node_target << cpp_node_target
        end
      end

      def cpplinker_add_linker_flag(target, value)
        target_node = target_node(target)
        return if target_node.nil?
        option_ldflags_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.cpp.link.option.flags"]')
        unless option_ldflags_node_target.nil?
          ldflags_node_target = option_ldflags_node_target.at_xpath('value')
          if ldflags_node_target.nil?
            ldflags_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
            ldflags_node_target.content = value
            option_ldflags_node_target << ldflags_node_target
          else
            ldflags_node_target.content = ldflags_node_target.content + ' ' + value
          end
        end
      end

      def c_cpp_linker_setlibheader(target, compiler, linker)
        target_node = target_node(target)
        return if target_node.nil?
        # current, just newlib and newlibnano is supportd, the default is the redlib
        unless (compiler == 'newlibnano') || (compiler == 'newlib') || (compiler == 'redlib')
          Core.assert(false, 'Just newlib, newlibnano and redlib is supportd, and the redlib is the default one.')
        end
        compiler = 'codered' if compiler == 'redlib'
        gas_hdrlib_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gas.hdrlib"]')
        unless gas_hdrlib_node_target.nil?
          gas_hdrlib_node_target_value = Nokogiri::XML::Node.new('value', @project_definition_xml)
          gas_hdrlib_node_target_value.content = "com.crt.advproject.gas.hdrlib.#{compiler}"
          gas_hdrlib_node_target << gas_hdrlib_node_target_value
        end

        gas_specs_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gas.specs"]')
        unless gas_specs_node_target.nil?
          gas_specs_node_target_value = Nokogiri::XML::Node.new('value', @project_definition_xml)
          gas_specs_node_target_value.content = "com.crt.advproject.gas.specs.#{compiler}"
          gas_specs_node_target << gas_specs_node_target_value
        end

        gcc_hdrlib_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gcc.hdrlib"]')
        unless gcc_hdrlib_node_target.nil?
          gcc_hdrlib_node_target_value = Nokogiri::XML::Node.new('value', @project_definition_xml)
          gcc_hdrlib_node_target_value.content = "com.crt.advproject.gcc.hdrlib.#{compiler}"
          gcc_hdrlib_node_target << gcc_hdrlib_node_target_value
        end

        gcc_specs_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.gcc.specs"]')
        unless gcc_specs_node_target.nil?
          gcc_specs_node_target_value = Nokogiri::XML::Node.new('value', @project_definition_xml)
          gcc_specs_node_target_value.content = "com.crt.advproject.gcc.specs.#{compiler}"
          gcc_specs_node_target << gcc_specs_node_target_value
        end

        link_gcc_hdrlib_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.gcc.hdrlib"]')
        unless link_gcc_hdrlib_node_target.nil?
          link_gcc_hdrlib_node_target_value = Nokogiri::XML::Node.new('value', @project_definition_xml)
          link_gcc_hdrlib_node_target_value.content = "com.crt.advproject.gcc.link.hdrlib.#{compiler}.#{linker}"
          link_gcc_hdrlib_node_target << link_gcc_hdrlib_node_target_value
        end

        cpp_hdrlib_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.cpp.hdrlib"]')
        unless cpp_hdrlib_node_target.nil?
          cpp_hdrlib_node_target_value = Nokogiri::XML::Node.new('value', @project_definition_xml)
          cpp_hdrlib_node_target_value.content = "com.crt.advproject.cpp.hdrlib.#{compiler}"
          cpp_hdrlib_node_target << cpp_hdrlib_node_target_value
        end

        cpp_specs_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.cpp.specs"]')
        unless cpp_specs_node_target.nil?
          cpp_specs_node_target_value = Nokogiri::XML::Node.new('value', @project_definition_xml)
          cpp_specs_node_target_value.content = "com.crt.advproject.cpp.specs.#{compiler}"
          cpp_specs_node_target << cpp_specs_node_target_value
        end

        link_cpp_hdrlib_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="com.crt.advproject.link.cpp.hdrlib"]')
        unless link_cpp_hdrlib_node_target.nil?
          link_cpp_hdrlib_node_target_value = Nokogiri::XML::Node.new('value', @project_definition_xml)
          link_cpp_hdrlib_node_target_value.content = "com.crt.advproject.cpp.link.hdrlib.#{compiler}.#{linker}"
          link_cpp_hdrlib_node_target << link_cpp_hdrlib_node_target_value
        end
      end

      def archiver_set_flags(target, line)
        target_node = target_node(target)
        return if target_node.nil?
        option_flags_node_target = target_node.at_xpath('toolchainSettings/toolchainSetting[@id_refs="com.nxp.mcuxpresso"]/option[@id="gnu.both.lib.option.flags"]')
        unless option_flags_node_target.nil?
          flags_node_target = Nokogiri::XML::Node.new('value', @project_definition_xml)
          flags_node_target.content = line
          option_flags_node_target << flags_node_target
        end
      end

      def add_link_library(target, path, filetype, toolchain, virtual_dir)
        key = [File.dirname(path), filetype, toolchain, virtual_dir].join(':')
        @link_lib[target] = {} unless @link_lib[target]
        @link_lib[target][key] = [] unless @link_lib[target].key?(key)
        @link_lib[target][key].push(File.basename(path)) unless @link_lib[target][key].include?(File.basename(path))
      end

      # Clear compiler include paths of target
      # ==== arguments
      # target    - target name
      def clear_compiler_include!(_target)
        @mcux_include.clear
      end

      # Add compiler include path 'path' to target 'target'
      # ==== arguments
      # target    - target name
      # path      - include path
      def add_mcux_include(_target, path, *_args, **_kwargs)
        @mcux_include.push(path.tr('\\', '/')) unless @mcux_include.include?(path.tr('\\', '/'))
      end

      # set the prebuild cmd
      # ==== arguments
      # target    - the target of project
      # cmd       - the command
      def add_prebuild_script(target, cmd)
        @prebuild_cmd[target] = '' unless @prebuild_cmd[target]
        @prebuild_cmd[target] = cmd
      end

      def add_linker_file(target, path)
        key = File.basename(path)
        @link_file[target] = {} unless @link_file[target]
        @link_file[target][key] = '' unless @link_file[target].key?(key)
        @link_file[target][key] = File.dirname(path)
      end

      # set the postbuild cmd
      # ==== arguments
      # target    - the target of project
      # cmd       - the command
      def add_postbuild_script(target, cmd)
        @postbuild_cmd[target] = '' unless @postbuild_cmd[target]
        @postbuild_cmd[target] = cmd
      end
    end
  end
end

# Add library to target
# def add_library(target, library, *args, **kwargs)
#     # @uvproj_file.linkerTab.add_library(target, library)
# end

# def add_target(target, binary_path)
#     #@config_cmakelists.puts "set_target_properties( #{target} PROPERTIES LIBRARY_OUTPUT_DIRECTORY #{binary_path.gsub("\\","/")})"
#     @target << target
#     @target.uniq!
#     @binary_file_name = File.basename(binary_path,".*")
# end
# def converted_output_file(target, path, rootdir: nil)
#     format_map = {
#         'bin' => 'binary',
#         'hex' => 'ihex',
#         'srec' => 'srec',
#         'symbolsrec' => 'symbolsrec'
#     }
#     output_name = File.basename(path)
#     format = output_name.split('.')[1]

#     @converted_format[format_map[format]] = output_name
# end
# def linker_file(target, path)
#    #@config_cmakelists.puts "set(CMAKE_EXE_LINKER_FLAGS_#{target.upcase} \"${CMAKE_EXE_LINKER_FLAGS_#{target.upcase}} \"-T#{path}\"  -static)"
#     @linker_file[target] = Array.new unless(@linker_file[target])
#     @linker_file[target].push("#{path}")
# end
# # Add assembler include path 'path' to target 'target'
# # ==== arguments
# # target    - target name
# # path      - include path
# def add_assembler_include(target, path, *args, **kwargs)
#     @as_include.push("#{path.gsub("\\", "/")}")
# end

# # Clear assembler include paths of target
# # ==== arguments
# # target    - target name
# def clear_assembler_include!(target)
#     @as_include.clear
# end

# # Add compiler include path 'path' to target 'target'
# # ==== arguments
# # target    - target name
# # path      - include path
# def add_cpp_compiler_include(target, path, *args, **kwargs)
#     @cxx_include.push("#{path.gsub("\\", "/")}")
# end

# # Clear compiler include paths of target
# # ==== arguments
# # target    - target name
# def clear_cpp_compiler_include!(target)
#     @cxx_include.clear
# end
