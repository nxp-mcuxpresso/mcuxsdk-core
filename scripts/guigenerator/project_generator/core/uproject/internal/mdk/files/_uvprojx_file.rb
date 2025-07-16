# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../_xml_utils'
require_relative '../../../../_file'
require_relative '../../../../../../utils/cmsis'
require_relative '../../../../../../utils/_assert'
require_relative '../../../../../../utils/data_problems_logger'
# require_relative '../../../../../../pdsc_generator//pdsc_populator/pdsc_utils'
require 'nokogiri'
require 'logger'


module Internal
module Mdk

    # Common class to manipulate with .uvproj xml file
    # Subclasses and methods respond to GUI elements
    class UvprojxFile

        attr_reader :xml
        attr_reader :logger
        attr_reader :operations

        private

        def initialize(template, *args, logger: nil, **kwargs)
            @xml = XmlUtils.load(template)
            @xml_path = File.dirname(template)
            @logger = logger ? logger : Logger.new(STDOUT)
            @files_to_remove = []
            @components = []
            @data_err_logger = nil
        end

        # Save file
        # ==== arguments161
        # path      - string, file path to save
        def save(path, *args, **kargs)
            Core.assert(path.is_a?(String) && !path.empty?) do
                "param must be non-empty string"
            end
            @logger.debug("generate file: #{path}")
            XmlUtils::save(@xml, path)
        end

        # Clear all existing sources
        def add_source(path, vdir, source_target, *args, **kargs)
            @operations.add_source(path, vdir, source_target)
        end

        def set_source_alwaysBuild(file, vdir, targets, alwaysBuild, *args, **kwargs)
          value = alwaysBuild ? 1 : 0
          targets.each {|target|  @operations.set_source_alwaysBuild(file, vdir, target, value)}
        end

        def add_comfiguration(target, path, optlevel, *args, **kargs)
            @operations.add_comfiguration(target, path, optlevel)
        end

        # Clear all existing sources
        def clear_sources!(*args, **kargs)
            @operations.clear_sources!
        end

        # Clear FlashDriver info
        def clear_flashDriver!(*args, **kargs)
          @operations.clear_flashDriver!
        end

        def get_target_name(*args, **kwargs)
            return @operations.get_target_name(*args, **kwargs)
        end

        def set_target_name(*args, **kwargs)
            @operations.set_target_name(*args, **kwargs)
        end

        # Get list of available targets
        def targets(*args, **kargs)
            return @operations.targets
        end

        # Setup project name
        def clear_unused_targets!(*args, **kargs)
            @operations.clear_unused_targets!
        end

        # Setup project name
        # ==== arguments
        # target    - target name
        # value       - xml document
        def project_name(target, value, *args, used: false, **kargs)
            name_node = @operations.target_node(target, used: used).at_xpath("./TargetName")
            Core.assert(!name_node.nil?) do
                "no '<TargetName>' node"
            end
            name_node.content = value
        end

        def enable_batchbuild(target, value, *args, used: true, **kargs)
            @operations.set_option_node(
                target, "TargetOption/TargetCommonOption/SelectedForBatchBuild", @operations.convert_boolean(value), used: used
            )
        end

        # Return absolute paths to files to be remove
        # @return [Array<String>] Absolute paths to files
        def files_to_remove
          return @files_to_remove
        end

        # -------------------------------------------------------------------------------------
        # set compiler and assembler
        # @param [String] target: target name
        # @param [String] compiler: compiler name
        # @return [Nil]
        def set_compiler_assembler(target, compiler, *args, used: true, **kargs)
          value = compiler == 'armcc' ? 0 : 1
          # set compiler
          compiler_node = @operations.target_node(target, used: used).at_xpath("./uAC6")
          unless compiler_node
            compiler_node = Nokogiri::XML::Node.new('uAC6', @xml)
            @operations.target_node(target, used: used) << compiler_node
          end
          compiler_node.content = value
          # set assembler
          @operations.set_option_node(
              target, "TargetOption/TargetArmAds/Aads/uClangAs", value, used: used
          )
        end

        # Update include paths to default '.'
        # @return [nil]
        def update_include_paths
          @xml.xpath('//Cads/VariousControls/IncludePath').each do |include_element|
            new_content = include_element.content.split(';').reject { |p| p.start_with?'..' }.join(';')
            new_content = '.;' + new_content unless new_content.start_with?(';')
            include_element.content = new_content
          end
        end

        # Create structure for CMSIS data to example project file to @rte_xml, @rte_node
        # @return [Nil]
        def create_rte_component
          project_node = @xml.at_xpath('/Project/RTE/components')
          unless project_node
            project_node = @xml.at_xpath('/Project')
            cmsis_node = Nokogiri::XML::Node.new('RTE', @xml)
            project_node << cmsis_node
            components_node = Nokogiri::XML::Node.new('components', @xml)
            cmsis_node << components_node
            apis_node = Nokogiri::XML::Node.new('apis', @xml)
            cmsis_node << apis_node
            files_node = Nokogiri::XML::Node.new('files', @xml)
            cmsis_node << files_node
          end
          # Update xml
          @rte_xml = project_node
        end

        # Set target info for component
        # @param [Nokogiri::XML::Node] destination_node: element to which it will be added target info
        # @return [Nil]
        def add_target_info(destination_node)
          targets_node = Nokogiri::XML::Node.new('targetInfos', @xml)
          destination_node << targets_node
          @xml.xpath('//TargetName').each do |target_name|
            target_node = Nokogiri::XML::Node.new('targetInfo', @xml)
            target_node['name'] = target_name.content
            targets_node << target_node
          end
        end

        # Set board project template component and package
        # @param [CmsisCompVector] cmsis_vector: CMSIS ID vector for BOARD_project_template component
        # @param [Nokogiri::XML::Node] file_node: element of Board project file
        # @return [Nil]
        def add_component_and_package(cmsis_vector, file_node)
          component_node = Nokogiri::XML::Node.new('component', @xml)
          component_node['Cvariant'] = cmsis_vector.c_variant unless cmsis_vector.c_variant.nil?
          component_node['Cversion'] = cmsis_vector.version
          component_node['Csub'] = cmsis_vector.c_sub
          component_node['Cgroup'] = cmsis_vector.c_group
          component_node['Cclass'] = cmsis_vector.c_class
          file_node << component_node

          package_node = Nokogiri::XML::Node.new('package', @xml)
          package_node['url'] = cmsis_vector.url
          package_node['version'] = cmsis_vector.version
          package_node['vendor'] = cmsis_vector.c_vendor
          package_node['name'] = cmsis_vector.pack_name
          file_node << package_node
        end

        # copy file to destination folder
        # @param [String] destination: relative path from root example
        # @param [String] file_path: absolute file path to copy
        def copy_file_to_example(destination, file_path)
          FileUtils.mkdir_p(destination)
          unless File.exist?(file_path)
            @data_err_logger.log_data_error("example MDK '#{destination}', File cannot be copied, as it doesn't "\
                                       "exist: #{file_path}\n")
            return
          end

          FileUtils.cp(file_path, destination)
        end

        # copy board project template files to RTE folder
        # @param [String] file_path: file path
        # @param [String] c_class: Cclass of component
        # @param [String] part_name: device target name
        def copy_project_template_files(file_path, c_class, part_name)
          board_template_dst = 'RTE/' + c_class.sub(' ', '_') + '/' + part_name
          destination = File.join(@xml_path, board_template_dst)
          copy_file_to_example(destination, file_path)
        end

        # Add include path of specific file if not exist
        # @param [Array<String>] path: relative path to directory, where is a specific file
        # @return [nil]
        def add_include_path(path)
          @xml.xpath('//IncludePath').each do |include_element|
            next if path == '.'
            next if include_element.content.nil?
            next unless include_element.content.start_with? '.;'
            next if include_element.content.split(';').include?(path)

            path = ';' + path unless include_element.content.end_with? ';'
            include_element.content += path
          end
        end

        # Checks whether the directory path is mentioned in assembly includes (Aads) and if so, updates the assembly
        # include path
        # @param [String] old_path: old path of the files to be included in the project
        # @param [String] new_path: new path of the files to be included in the project
        # @return [nil]
        def check_asm_include_paths(old_path, new_path)
          @xml.xpath('//Aads/VariousControls/IncludePath').each do |el|
            paths = el.content.split(';').map { |p| p == old_path ? new_path : p }
            el.content = paths.join(';')
          end
        end

        # Remove files from groups
        # @param [Array<String>] contains_files: name of config files
        # @return [nil]
        def remove_files_from_group(contains_files)
          @xml.xpath('//Group').each do |group|
            addition_files = false
            group.xpath('Files/File').each do |file_element|
              file_name = file_element.at_xpath('FilePath').content
              if contains_files.include? File.basename(file_name)
                file_element.remove
              else
                addition_files = true
                # Move and update paths of specific files
                if file_name.start_with?('../')
                  # regex to delete all '../' at the beginning of path
                  new_file_name = file_name.scan(/[^\.\/]*[a-zA-Z0-9_].*/).join('')
                  file_element.at_xpath('FilePath').content = new_file_name
                  destination = File.dirname(File.join(@xml_path, new_file_name))
                  orig_abs_path = File.join(@xml_path, file_name)
                  @files_to_remove.push_uniq(orig_abs_path)
                  #FIXME [SDKGEN-1622] Use target path contained in the GroupName element
                  copy_file_to_example(destination, orig_abs_path)
                  add_include_path(File.dirname(new_file_name))
                  check_asm_include_paths(File.dirname(file_name), File.dirname(new_file_name))
                end
              end
            end
            group.remove unless addition_files
          end
        end

        # Set config file for component
        # @param [Array<String>] config_file: config file name of component
        # @return [Nokogiri::XML::Node] file_node: element of config file
        def add_config_file(config_file)
          file_node = Nokogiri::XML::Node.new('file', @xml)
          file_node['category'] = PdscUtils.get_pdsc_source_type(File.extname(config_file))
          file_node['attr'] = 'config'
          file_node['name'] = File.basename(config_file)
          return file_node
        end

        # Set board project template files
        # @param [CmsisCompVector] cmsis_vector: CMSIS ID vector for BOARD_project_template component
        # @param [Array<String>] config_files: Absolute path to Board_project_template files
        # @param [String] part_name: device part name
        # @param [ExampleInputData] example: example input data used for log_data_error
        # @return [Nil]
        def add_project_template_files(cmsis_vector, config_files, part_name, example)
          @data_err_logger = example
          files_node = @rte_xml.at_xpath('/Project/RTE/files')
          device_target_name = @rte_xml.at_xpath('/Project//Target//Device').content.sub(':', '_')
          if device_target_name.split('_').first != part_name
            @data_err_logger.log_data_error("example #{example.name} - UVPROJX, Target/Device_name: " \
            "'#{device_target_name}', yml/device_part_name: '#{part_name}'\n")
          end
          component_files_name = []
          config_files.each do |file_path|
            file = File.basename(file_path)
            component_files_name.push(file)
            file_node = add_config_file(file_path)
            instance_node = Nokogiri::XML::Node.new('instance', @xml)
            instance_node['index'] = '0'
            instance_node.content = 'RTE\\' + cmsis_vector.c_class.sub(' ', '_') + '\\' + device_target_name + '\\' + file
            file_node << instance_node
            copy_project_template_files(file_path, cmsis_vector.c_class, device_target_name)
            add_component_and_package(cmsis_vector, file_node)
            add_target_info(file_node)
            files_node << file_node
          end
          remove_files_from_group(component_files_name)
        end

        # Set CMSIS package for component
        # @param [HasH] cmsis_info: CMSIS ID vector
        # @param [Nokogiri::XML::Node] component_node: element of component
        # @return [Nil]
        def add_package_for_component(cmsis_info, component_node)
          package_node = Nokogiri::XML::Node.new('package', @xml)
          package_node['url'] = cmsis_info[:pack_url] if cmsis_info.safe_key?(:pack_url)
          package_node['schemaVersion'] = Pdsc::SCHEMA_VERSION
          package_node['version'] = cmsis_info[:pack_version]
          package_node['vendor'] = cmsis_info[:pack_vender]
          package_node['name'] = cmsis_info[:pack_name]
          component_node << package_node
        end

        # Set CMSIS apis for project files
        # @param [Hash] cmsis_info: CMSIS ID vector
        # @param [Nokogiri::XML::Node] apis_node: element of apis
        # @return [Nil]
        def add_api(cmsis_info, apis_node)
          api_node = Nokogiri::XML::Node.new('api', @xml)
          api_node['Capiversion'] = cmsis_info[:apiversion]
          api_node['Cgroup'] = cmsis_info[:cgroup]
          api_node['Cclass'] = cmsis_info[:cclass]
          api_node['exclusive'] = '0'
          apis_node << api_node
          add_package_for_component(cmsis_info, api_node)
          add_target_info(api_node)
        end

        # Set CMSIS components for project files
        # @param [Hash] cmsis_info: CMSIS component information
        # @return [Nil]
        def add_rte_component(cmsis_info)
          create_rte_component unless @rte_xml
          @components.each do |component_vector|
            return if component_vector[:cclass] == cmsis_info[:cclass] &&
              component_vector[:cgroup] == cmsis_info[:cgroup] &&
              component_vector[:csub] == cmsis_info[:csub] &&
              component_vector[:cvendor] == cmsis_info[:cvendor] &&
              component_vector[:cvariant] == cmsis_info[:cvariant]
          end
          @components.push(cmsis_info)
          # For ARM CMSIS API component, just add into api section
          if !cmsis_info[:apiversion].nil? && cmsis_info[:pack_vender] == 'ARM'
            apis_node = @rte_xml.at_xpath('/Project/RTE/apis')
            add_api(cmsis_info, apis_node)
            return
          end
          components_node = @rte_xml.at_xpath('/Project/RTE/components')
          component_node = Nokogiri::XML::Node.new('component', @xml)
          component_node['Cvendor'] = cmsis_info[:cvendor]
          component_node['Cversion'] = cmsis_info[:cversion]
          component_node['Capiversion'] = cmsis_info[:apiversion] if cmsis_info.safe_key?(:apiversion)
          component_node['Csub'] = cmsis_info[:csub] if cmsis_info.safe_key?(:csub)
          component_node['Cvariant'] = cmsis_info[:cvariant] if cmsis_info.safe_key?(:cvariant)
          component_node['Cgroup'] = cmsis_info[:cgroup]
          component_node['Cclass'] = cmsis_info[:cclass]
          component_node['Cbundle'] = cmsis_info[:cbundle] if cmsis_info.safe_key?(:cbundle)
          components_node << component_node
          add_package_for_component(cmsis_info, component_node)
          add_target_info(component_node)
        end

        # Set BOARD_project_template component for project files
        # @param [CmsisCompVector] cmsis_vector: CMSIS ID vector
        # @return [Nil]
        def add_project_template_component(cmsis_vector)
          create_rte_component unless @rte_xml
          components_node = @rte_xml.at_xpath('/Project/RTE/components')

          component_node = Nokogiri::XML::Node.new('component', @xml)
          component_node['Cvendor'] = cmsis_vector.c_vendor
          component_node['Cvariant'] = cmsis_vector.c_variant
          component_node['Cversion'] = cmsis_vector.version
          component_node['Csub'] = cmsis_vector.c_sub unless cmsis_vector.c_sub.nil?
          component_node['Cgroup'] = cmsis_vector.c_group
          component_node['Cclass'] = cmsis_vector.c_class
          components_node << component_node
          add_package_for_component(cmsis_vector, component_node)
          add_target_info(component_node)
          update_include_paths
        end

        # make subclasses private
        private

        # Internal class, provide common operations of xml project
        class DocumentOperations

            attr_reader :xml
            attr_reader :targets
            attr_reader :groups
            attr_reader :logger

            # Load all available targets in XML document and
            # mark them with no-used flag !
            # ==== arguments
            # xml       - xml document
            def initialize(xml, *args, logger: nil, **kwargs)
                # init object attributes
                @xml            = xml
                @logger         = logger
                @targets        = {}
                @groups         = {}
                # loop over targets
                nodes = @xml.xpath("/Project/Targets/Target")
                nodes.each do | target_node |
                    name_node = target_node.at_xpath("TargetName")
                    Core.assert(!name_node.nil?) do "no <TargetName> node!" end
                    # and use downcase stripped version of target name
                    target = name_node.content.strip.downcase
                    name_node.content = target
                    @targets[ target ] = {
                        'node'  => target_node,
                        'used'  => false
                    }
                end
            end

            def targets()
                return @targets.keys
            end

            # Return target node and set 'used' flag
            # ==== arguments
            # target    - name of target
            def target_node(target, used: nil)
                Core.assert(target.is_a?(String) && !target.empty?) do
                    "param must be non-empty string"
                end
                Core.assert(!used.nil?, "used cannot be nil!")
                # use downcase stripped version
                target = target.strip.downcase
                Core.assert(@targets.has_key?(target)) do
                    "target '#{target}' is not present. use one of: #{@targets.keys} "
                end
                Core.assert(!@targets[ target ][ 'node' ].nil?) do
                    "name '#{target}' does not exist"
                end
                if (used)
                    @targets[ target ][ 'used' ] = true
                end
                return @targets[ target ][ 'node' ]
            end

            # Clear unused targets
            def clear_unused_targets!
                @targets.each do | target_key, target_item |
                    if (target_item[ 'used' ] == false)
                        target_item[ 'node' ].remove()
                        @targets.delete(target_key)
                    end
                end
            end

            def get_target_name(target, *args, used: false, **kwargs)
                target_node = target_node(target, used: used)
                name_node = target_node.at_xpath("TargetName")
                Core.assert(!name_node.nil?) do "missing 'name' node" end
                return name_node.content
            end

            def set_target_name(target, value, *args, used: false, update_table: false, **kwargs)
                Core.assert(!update_table) do "not implemented" end
                target_node = target_node(target, used: used)
                name_node = target_node.at_xpath("TargetName")
                Core.assert(!name_node.nil?) do "missing 'name' node" end
                name_node.content = value
            end

            # Add source file into 'vdirexpr' directory
            # ==== arguments
            # path      - name of target
            # vdirexpr  - string, virtual dir expression
            def add_source(path, vdirexpr, source_target)
                extension   = File.extname(path)
                basename    = File.basename(path)
                filetype    = 5
            # choose filetype according extension
                if (extension =~ /(?i)^.(c)$/)
                    filetype = 1 # c files
                elsif (extension =~ /(?i)^.(s|asm)$/)
                    filetype = 2 # assembly files
                elsif (extension =~ /(?i)^.(o)$/)
                    filetype = 3 # object files
                elsif (extension =~ /(?i)^.(lib|a)$/)
                    filetype = 4 # libraries
                elsif (extension =~ /(?i)^.(h|hpp|txt|inc)$/)
                    filetype = 5 # other non-bulded files
                elsif (extension =~ /(?i)^.(cpp|cc)$/)
                    filetype = 8 # cpp files
                end
                targets.each do | target |
                    group_node = create_group(target, vdirexpr)
                # add <File>
                    file_node = Nokogiri::XML::Node.new("File", @xml)
                    group_node << file_node
                # add <FileName>
                    node = Nokogiri::XML::Node.new("FileName", @xml)
                    node.content = basename
                    file_node << node
                # add <FileType>
                    node = Nokogiri::XML::Node.new("FileType", @xml)
                    node.content = filetype
                    file_node << node
                # add <FilePath>
                    node = Nokogiri::XML::Node.new("FilePath", @xml)
                    node.content = path
                    file_node << node
                    unless source_target == nil
                        unless source_target.include?(target)
                            set_IncludeInBuild(file_node)
                        end
                    end
                end
            end

            def set_source_alwaysBuild(file, vdir, target, alwaysBuild)
              target_node = @xml.xpath("/Project/Targets/Target")
              target_node.each do |target_node|
                next unless target_node.at_xpath("./TargetName").content.split(' ')[-1] == target
                groups_node =  target_node.xpath("./Groups/Group")
                groups_node.each do | node |
                  if node.at_xpath("./GroupName").content == vdir
                    files_nodes = node.xpath("./Files/File")
                    files_nodes.each do |file_node|
                      if file_node.at_xpath("./FileName").content == file
                        file_node << "<FileOption>
                                  <CommonProperty>
                                    <IncludeInBuild>2</IncludeInBuild>
                                    <AlwaysBuild>#{alwaysBuild}</AlwaysBuild>
                                    <GenerateAssemblyFile>2</GenerateAssemblyFile>
                                    <AssembleAssemblyFile>2</AssembleAssemblyFile>
                                    <PublicsOnly>2</PublicsOnly>
                                    <StopOnExitCode>11</StopOnExitCode>
                                  </CommonProperty>
                                  <FileArmAds>
                                  </FileArmAds>
                                </FileOption>"
                      end
                    end
                  end
                end
              end
            end

            def add_comfiguration(target, folder, optlevel)
                target_node = @xml.xpath("/Project/Targets/Target")
                target_node.each do |target_node|
                    next unless target_node.at_xpath("./TargetName").content == target
                    groups_node =  target_node.xpath("./Groups/Group")
                    groups_node.each do | node |
                        if node.at_xpath("./GroupName").content == folder
                            groupoption_node = Nokogiri::XML::Node.new("GroupOption", @xml)
                            node << groupoption_node

                            grouparmads_node = Nokogiri::XML::Node.new("GroupArmAds", @xml)
                            groupoption_node << grouparmads_node

                            group_cads_node = Nokogiri::XML::Node.new("Cads", @xml)
                            group_cads_node.content = target_node.at_xpath("./TargetOption/TargetArmAds/Cads")
                            grouparmads_node << group_cads_node.text

                            group_aads_node = Nokogiri::XML::Node.new("Aads", @xml)
                            group_aads_node.content = target_node.at_xpath("./TargetOption/TargetArmAds/Aads")
                            grouparmads_node <<  group_aads_node.text

                            commonproperty_node = Nokogiri::XML::Node.new("CommonProperty", @xml)
                            commonproperty_node.content = target_node.at_xpath("./TargetOption/CommonProperty")
                            groupoption_node << commonproperty_node.text

                            convert = {'O0' => 1, 'O1' => 2, 'O2' => 3, 'O3' => 4}
                            set_option_node(
                                target.split(' ')[-1], "//GroupOption/GroupArmAds/Cads/Optim", convert_enum(optlevel, convert), used: true
                            )

                        end
                    end
                end
            end

            # Add source file into 'vdirexpr' directory
            def clear_sources!(used: false)
                targets.each do | target |
                    @groups[ target ] = {}
                    groups_node = target_node(target, used: false).at_xpath('Groups')
                    groups_node.remove() unless (groups_node.nil?)
                end
            end

            # Add source file into 'vdirexpr' directory
            def clear_flashDriver!(used: false)
              targets.each do | target |
                @groups[ target ] = {}
                flashDriver_node = target_node(target, used: false).at_xpath('TargetOption/TargetCommonOption/FlashDriverDll')
                flashDriver_node.remove() unless (flashDriver_node.nil?)
              end
            end

            def set_IncludeInBuild(file_node)
                common_property = @xml.at_xpath("/Project/Targets/Target/TargetOption/CommonProperty")
                common_property.at_xpath("./UseCPPCompiler").content = 2
                common_property.at_xpath("./RVCTCodeConst").content = 0
                common_property.at_xpath("./RVCTZI").content = 0
                common_property.at_xpath("./RVCTOtherData").content = 0
                common_property.at_xpath("./ModuleSelection").content = 0
                common_property.at_xpath("./IncludeInBuild").content = 0
                common_property.at_xpath("./AlwaysBuild").content = 2
                common_property.at_xpath("./GenerateAssemblyFile").content = 2
                common_property.at_xpath("./AssembleAssemblyFile").content = 2
                common_property.at_xpath("./PublicsOnly").content = 2
                common_property.at_xpath("./StopOnExitCode").content = 11

                file_option = Nokogiri::XML::Node.new("FileOption", @xml)
                file_node << file_option

                file_option << common_property

                fileArmAds_node = Nokogiri::XML::Node.new("FileArmAds", @xml)
                file_option << fileArmAds_node

                cads_node = Nokogiri::XML::Node.new("Cads", @xml)

                interw_node = Nokogiri::XML::Node.new("interw", @xml)
                interw_node.content = 2
                cads_node << interw_node
                optim_node = Nokogiri::XML::Node.new("Optim", @xml)
                optim_node.content = 0
                cads_node << optim_node
                oTime_node = Nokogiri::XML::Node.new("oTime", @xml)
                oTime_node.content = 2
                cads_node << oTime_node
                splitLS_node = Nokogiri::XML::Node.new("SplitLS", @xml)
                splitLS_node.content = 2
                cads_node << splitLS_node
                oneElfS_node = Nokogiri::XML::Node.new("OneElfS", @xml)
                oneElfS_node.content =2
                cads_node << oneElfS_node
                strict_node = Nokogiri::XML::Node.new("Strict", @xml)
                strict_node.content = 2
                cads_node << strict_node
                enumInt_node = Nokogiri::XML::Node.new("EnumInt", @xml)
                enumInt_node.content = 2
                cads_node << enumInt_node
                plainCh_node = Nokogiri::XML::Node.new("PlainCh", @xml)
                plainCh_node.content = 2
                cads_node << plainCh_node
                ropi_node = Nokogiri::XML::Node.new("Ropi", @xml)
                ropi_node.content = 2
                cads_node << ropi_node
                rwpi_node = Nokogiri::XML::Node.new("Rwpi", @xml)
                rwpi_node.content = 2
                cads_node << rwpi_node
                wLevel_node = Nokogiri::XML::Node.new("wLevel", @xml)
                wLevel_node.content = 0
                cads_node << wLevel_node
                uThumb_node = Nokogiri::XML::Node.new("uThumb", @xml)
                uThumb_node.content = 2
                cads_node << uThumb_node
                uSurpInc_node = Nokogiri::XML::Node.new("uSurpInc", @xml)
                uSurpInc_node.content = 2
                cads_node << uSurpInc_node
                uC99_node = Nokogiri::XML::Node.new("uC99", @xml)
                uC99_node.content = 2
                cads_node << uC99_node
                useXO_node = Nokogiri::XML::Node.new("useXO", @xml)
                useXO_node.content = 2
                cads_node << useXO_node

                fileArmAds_node  << cads_node

            end

            # Create virtual directory according 'vdirexpr' expression
            # ==== arguments
            # target    - name of target
            # vdirexpr  - vdirexpr
            def create_group(target, vdirexpr, used: false)
                if (@groups[ target].nil? || @groups[ target][ vdirexpr].nil?)
                    target_node = target_node(target, used: used)
                    groups_node = target_node.at_xpath('Groups')
                    if (groups_node.nil?)
                        groups_node = Nokogiri::XML::Node.new("Groups", @xml)
                        target_node << groups_node
                    end
                # add '<Group>'
                    group_node = Nokogiri::XML::Node.new("Group", @xml)
                    groups_node << group_node
                # add '<GroupName>'
                    name_node = Nokogiri::XML::Node.new("GroupName", @xml)
                    name_node.content = vdirexpr
                    group_node << name_node
                # add '<Files>'
                    files_node = Nokogiri::XML::Node.new("Files", @xml)
                    group_node << files_node
                # add to @groups
                    @groups[ target ] = {} if (@groups[ target ].nil?)
                    @groups[ target ][ vdirexpr ] = files_node
                end
                return @groups[ target ][ vdirexpr ]
            end

            # Setup  '<Option>' node
            # ==== arguments
            # target    - name of target
            # xpath     - xpath expression
            # value     - value to setup
            def set_option_node(target, xpath, value, used: nil)
                option_node = create_option_node(target, xpath, used: used)
                option_node.content = value
            end

            # Setup  '<Option>' node
            # ==== arguments
            # target    - name of target
            # xpath     - xpath expression
            def create_option_node(target, xpath, used: nil)
                option_node = target_node(target, used: used).at_xpath(xpath)
                if (option_node.nil?)
                # so the node requested by xpath does not exist
                # don't panic and tries create a new one
                # take the last node name from xpath expression
                # and tries to find parrent node
                    matched = xpath.match(/^(.*)\/([^\/]+)/)
                    Core.assert(!matched.nil?) do
                        "corrupted xpath #{xpath}"
                    end
                    parent_xpath, node_name = matched.captures
                    parent_node = target_node(target, used: used).at_xpath(parent_xpath)
                    Core.assert(!parent_node.nil?) do
                        "not such a node #{parent_xpath}"
                    end
                    option_node = Nokogiri::XML::Node.new(node_name, @xml)
                    parent_node << option_node
                end
                Core.assert(!option_node.nil?) do
                    "node of '#{xpath}' does not exist"
                end
                return option_node
            end
            # -------------------------------------------------------------------------------------
            # Create new node recursively if node does not exist
            # @param [String] target: the name of target
            # @param [String] xpath: xpath expression
            # @return [Nokogiri::XML::Element]: the created node of the xpath
            def create_option_node_for_src(target, xpath, used: nil)
              option_node = target_node(target, used: used).at_xpath(xpath)
              if (option_node.nil?)
                # so the node requested by xpath does not exist
                # don't panic and tries create a new one
                # take the last node name from xpath expression
                # and tries to find parrent node
                matched = xpath.match(/^(.*)\/([^\/]+)/)
                Core.assert(!matched.nil?) do
                  "corrupted xpath #{xpath}"
                end
                parent_xpath, node_name = matched.captures
                parent_node = target_node(target, used: used).at_xpath(parent_xpath)
                if parent_node.nil?
                  parent_node = create_option_node_for_src(target, parent_xpath, used: used)
                end
                Core.assert(!parent_node.nil?) do
                  "not such a node #{parent_xpath}"
                end
                option_node = Nokogiri::XML::Node.new(node_name, @xml)
                parent_node << option_node
              end
              Core.assert(!option_node.nil?) do
                "node of '#{xpath}' does not exist"
              end
              return option_node
            end

            def convert_string(value)
                Core.assert(value.is_a?(String)) do
                    "conversion error, value '#{value}' is not a String type"
                end
                return value
            end

            def convert_enum(value, convert)
                Core.assert(convert.has_key?(value)) do
                    "conversion error, value '#{value}' does not exists in enum '#{convert.keys.join(', ')}'"
                end
                return convert[ value ]
            end

            def convert_boolean(value)
                Core.assert(value.is_a?(TrueClass) || value.is_a?(FalseClass)) do
                    "conversion error, value '#{value}' must be a 'true' or 'false'"
                end
                return value ? '1' : '0'
            end
        end


        # Base tab class to inherit @operations attribute
        class TabBase
            attr_reader :operations
            def initialize(operations)
                @operations = operations
            end
        end


        class DeviceTab < TabBase

            private

            # Set device
            # ==== arguments
            # target    - name of target
            # value     - name of device
            def device(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/Device", value, used: used
                )
            end

            # Set vendor
            # ==== arguments
            # target    - name of target
            # value     - name of device
            def vendor(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/Vendor", value, used: used
                )
            end

            # Set cpu type
            # ==== arguments
            # target    - name of target
            # value     - name of device
            def cpu_type(target, value, *args, used: true, **kargs)
                if value.include? '.dfp'
                    value.slice! '.dfp'
                    @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/Cpu", "CPUTYPE(\"#{value}\") FPU3(DFPU)", used: used
                    )
                elsif value.include? '.fp'
                    value.slice! '.fp'
                    @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/Cpu", "CPUTYPE(\"#{value}\") FPU2", used: used
                    )
                else
                    @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/Cpu", "CPUTYPE(\"#{value}\")", used: used
                    )
                end
            end

            def set_cpu_fpu(target, cpu, fpu, dsp, *args, used: true, **kargs)
              convert_cpu = {'cortex-m0' => 'Cortex-M0', 'cortex-m0plus' => 'Cortex-M0+',
                         'cortex-m4' => 'Cortex-M4', 'cortex-m7' => 'Cortex-M7',
                         'cortex-m23' => 'Cortex-M23', 'cortex-m33' => 'Cortex-M33', 
                         'cortex-m55' => 'Cortex-M55', 'cortex-m85' => 'Cortex-M85'}
              convert_fpu = {'fpv4-sp-d16' => 'FPU2', 'fpv5-d16' => 'FPU3(DFPU)', 'fpv5-sp-d16' => 'FPU3(SFPU)', 'none' => ''}
              cpu_value = convert_cpu[cpu]
              Core.assert(cpu_value.is_a?(String), "unsupported cpu core!")
              # workaround: Get trustzone info from templates file as we don't know whether the cpu support trust zone from yml
              if ['Cortex-M23','Cortex-M33'].include? cpu_value
                option_node = @operations.target_node(target, used: used).at_xpath("TargetOption/TargetCommonOption/Cpu")
                trust_zone_opt = (option_node.content.include?'TZ') ? 'TZ' : '' unless option_node.content.nil?
              end
              dsp_value = dsp == true ? 'DSP' : '' if cpu_value == 'Cortex-M33'
              @operations.set_option_node(
                  target, "TargetOption/TargetCommonOption/Cpu", ("CPUTYPE(\"#{cpu_value}\") #{convert_fpu[fpu] || ''} #{trust_zone_opt || ''} #{dsp_value || ''}").strip, used: used
              )
            end
        end

        class TargetTab < TabBase

            private

            # Set big endian mode
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def big_endian(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/BigEnd", @operations.convert_boolean(value), used: used
                )
            end

            # Set Software Model
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def secure(target, value, *args, used:true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/nSecure", @operations.convert_boolean(value), used: used
                )
            end
        end


        class OutputTab < TabBase

            private

            # Set debug info
            # ==== arguments
            # target    - target name
            # value     - true/false
            def debug_info(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/DebugInformation", @operations.convert_boolean(value), used: used
                )
            end

            # Set name of output file
            # ==== arguments
            # target    - target name
            # value     - string
            def executable_name(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/OutputName", @operations.convert_string(value), used: used
                )
            end

            # Set output directory folder
            # ==== arguments
            # target    - target name
            # value     - path, string
            # ==== note
            # path must ends with backslash no matter what
            # otherwise some fields like <OutputName> get broken
            def folder(target, value, *args, used: true, **kargs)
                value = @operations.convert_string(value)
                value = File.to_backslash(value)
                value = "#{value}\\" if (value !~ /\\$/)
                # make build dir to mdk root path without "target" folder, to align with meta build system
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/OutputDirectory", '', used: used
                )
            end

            # Switch to create executable/application
            # Complement function to create_library
            # ==== arguments
            # target    - target name
            # value     - true, false
            def create_executable(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/CreateExecutable", @operations.convert_boolean(value), used: used
                )
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/CreateLib", @operations.convert_boolean(!value), used: used
                )
            end

            # Switch to create library
            # Complement function to create_library
            # ==== arguments
            # target    - target name
            # value     - true, false
            def create_library(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/CreateLib", @operations.convert_boolean(value), used: used
                )
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/CreateExecutable", @operations.convert_boolean(!value), used: used
                )
            end

            # Set browse information
            # ==== arguments
            # target    - target name
            # value     - true/false
            def browse_info(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BrowseInformation", @operations.convert_boolean(value), used: used
                )
            end

            def create_hex_file(target, value, *args, used: true, **kargs)
              @operations.set_option_node(
                  target, "TargetOption/TargetCommonOption/CreateHexFile", @operations.convert_boolean(value), used: used
              )
            end
        end


        class ListingTab < TabBase

            private

            # Set output folder of listing files
            # ==== arguments
            # target    - name of target
            # value     - path
            # ==== note
            # path must ends with backslash no matter what
            # otherwise some fields like <OutputName> get broken
            def folder(target, value, *args, used: true, **kargs)
                value = @operations.convert_string(value)
                value = File.to_backslash(value)
                value = "#{value}\\" if (value !~ /\\$/)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/ListingPath", value, used: used
                )
            end

            # Enable assembler listing
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def assembler_listing(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/AdsALst", @operations.convert_boolean(value), used: used
                )
            end

            # Enable assembler cross reference
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def assembler_cross_reference(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/AdsACrf", @operations.convert_boolean(value), used: used
                )
            end

            # Enable compiler listing
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def compiler_listing(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/RvctClst", @operations.convert_boolean(value), used: used
                )
            end

            # Enable preprocessor listing
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def preprocessor_listing(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/GenPPlst", @operations.convert_boolean(value), used: used
                )
            end

            # Enable linker listing
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def linker_listing(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/AdsLLst", @operations.convert_boolean(value), used: used
                )
            end

            # Enable linker memory map
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def linker_memory_map(target, value, *args, used: true, **kargs)
                linker_listing(target, true)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/AdsLmap", @operations.convert_boolean(value), used: used
                )
            end

            # Enable linker callgraph
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def linker_callgraph(target, value, *args, used: true, **kargs)
                linker_listing(target, true)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/AdsLcgr", @operations.convert_boolean(value), used: used
                )
            end

            # Enable linker symbols
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def linker_symbols(target, value, *args, used: true, **kargs)
                linker_listing(target, true)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/AdsLsym", @operations.convert_boolean(value), used: used
                )
            end

            # Enable linker cross reference
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def linker_cross_reference(target, value, *args, used: true, **kargs)
                linker_listing(target, true)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/AdsLsxf", @operations.convert_boolean(value), used: used
                )
            end

            # Enable linker size info
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def linker_size_info(target, value, *args, used: true, **kargs)
                linker_listing(target, true)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/AdsLszi", @operations.convert_boolean(value), used: used
                )
            end

            # Enable linker total info
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def linker_total_info(target, value, *args, used: true, **kargs)
                linker_listing(target, true)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/AdsLtoi", @operations.convert_boolean(value), used: used
                )
            end

            # Enable linker unused sections
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def linker_unused_sections(target, value, *args, used: true, **kargs)
                linker_listing(target, true)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/AdsLsun", @operations.convert_boolean(value), used: used
                )
            end

            # Enable linker veneers info
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def linker_veneers_info(target, value, *args, used: true, **kargs)
                linker_listing(target, true)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/AdsLven", @operations.convert_boolean(value), used: used
                )
            end
        end


        class UserTab < TabBase

            private

            # Enable run "before compilation1" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def before_compilation_run_1(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeCompile/RunUserProg1", @operations.convert_boolean(value), used: used
                )
            end

            # Setup "before compilation1" command
            # ==== arguments
            # target    - name of target
            # value     - string
            def before_compilation_command_1(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeCompile/UserProg1Name", @operations.convert_string(value), used: used
                )
            end

            # Enable dos mode for "before compilation1" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def before_compilation_dos_1(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeCompile/UserProg1Dos16Mode", @operations.convert_boolean(value), used: used
                )
            end

            # Enable run "before compilation2" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def before_compilation_run_2(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeCompile/RunUserProg2", @operations.convert_boolean(value), used: used
                )
            end

            # Setup "before compilation2" command
            # ==== arguments
            # target    - name of target
            # value     - string
            def before_compilation_command_2(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeCompile/UserProg2Name", @operations.convert_string(value), used: used
                )
            end

            # Enable dos mode for "before compilation2" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def before_compilation_dos_2(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeCompile/UserProg2Dos16Mode", @operations.convert_boolean(value), used: used
                )
            end

            # Enable run "before make1" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def before_make_run_1(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeMake/RunUserProg1", @operations.convert_boolean(value), used: used
                )
            end

            # Setup "before make1" command
            # ==== arguments
            # target    - name of target
            # value     - string
            def before_make_command_1(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeMake/UserProg1Name", @operations.convert_string(value), used: used
                )
            end

            # Enable dos mode for "before make1" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def before_make_dos_1(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeMake/UserProg1Dos16Mode", @operations.convert_boolean(value), used: used
                )
            end

            # Enable run "before make2" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def before_make_run_2(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeMake/RunUserProg2", @operations.convert_boolean(value), used: used
                )
            end

            # Setup "before make2" command
            # ==== arguments
            # target    - name of target
            # value     - string
            def before_make_command_2(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeMake/UserProg2Name", @operations.convert_string(value), used: used
                )
            end

            # Enable dos mode for "before make2" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def before_make_dos_2(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/BeforeMake/UserProg2Dos16Mode", @operations.convert_boolean(value), used: used
                )
            end

            # Enable run "after make1" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def after_make_run_1(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/AfterMake/RunUserProg1", @operations.convert_boolean(value), used: used
                )
            end

            # Setup "after make1" command
            # ==== arguments
            # target    - name of target
            # value     - string
            def after_make_command_1(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/AfterMake/UserProg1Name", @operations.convert_string(value), used: used
                )
            end

            # Enable dos mode for "after make1" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def after_make_dos_1(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/AfterMake/UserProg1Dos16Mode", @operations.convert_boolean(value), used: used
                )
            end

            # Enable run "after make1" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def after_make_run_2(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/AfterMake/RunUserProg2", @operations.convert_boolean(value), used: used
                )
            end

            # Setup "after make1" command
            # ==== arguments
            # target    - name of target
            # value     - string
            def after_make_command_2(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/AfterMake/UserProg2Name", @operations.convert_string(value), used: used
                )
            end

            # Enable dos mode for "after make1" command
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def after_make_dos_2(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetCommonOption/AfterMake/UserProg2Dos16Mode", @operations.convert_boolean(value), used: used
                )
            end

            def before_compile_run_1(target, value, *args, used: true, **kargs)
              @operations.set_option_node(
                target, "TargetOption/TargetCommonOption/BeforeCompile/RunUserProg1", @operations.convert_boolean(value), used: used
              )
            end

            def before_compile_command_1(target, value, *args, used: true, **kargs)
              @operations.set_option_node(
                target, "TargetOption/TargetCommonOption/BeforeCompile/UserProg1Name", @operations.convert_string(value), used: used
              )
            end

            def before_compile_run_2(target, value, *args, used: true, **kargs)
              @operations.set_option_node(
                target, "TargetOption/TargetCommonOption/BeforeCompile/RunUserProg2", @operations.convert_boolean(value), used: used
              )
            end

            def before_compile_command_2(target, value, *args, used: true, **kargs)
              @operations.set_option_node(
                target, "TargetOption/TargetCommonOption/BeforeCompile/UserProg2Name", @operations.convert_string(value), used: used
              )
            end
        end


        class CompilerTab < TabBase

            def initialize(*args)
                super
                @miscflags = {}
                #  key is target, value is an array contained Hash which the key is path and the value is flag
                @miscflags_for_src = {}
            end

            private

            # Enable interworking. This checkobx might be not visible for some architectures.
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def interworking(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/interw", @operations.convert_boolean(value), used: used
                )
            end

            # Add define
            # ==== arguments
            # target    - name of target
            # value     - string, format "name=value"
            def add_define(target, value, *args, used: true, **kargs)
                value = @operations.convert_string(value)
                node = @operations.create_option_node(
                    target, "TargetOption/TargetArmAds/Cads/VariousControls/Define", used: used
                )
                node.content = node.content.empty? ? value : "#{node.content}, #{value}"
            end

            # Clear defines
            # ==== arguments
            # target    - name of target
            def clear_defines!(target, *args, used: false, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/VariousControls/Define", '', used: false
                )
            end

            # Setup optimization level
            # ==== arguments
            # target    - name of target
            # value     - 'O0', 'O1', 'O2', 'O3'
            def optimization(target, value, *args, used: true, **kargs)
                convert = {'O0' => 1, 'O1' => 2, 'O2' => 3, 'O3' => 4, 'Ofast' => 5, 'Os' => 6, 'Oz' => 7}
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/Optim", @operations.convert_enum(value, convert), used: used
                )
            end

            def optimization_for_src(target, path, value, *args, used: true, **kargs)
              convert = {'O0' => 1, 'O1' => 2, 'O2' => 3, 'O3' => 4}
              node = @operations.create_option_node_for_src(target, "Groups/Group/Files/File[FilePath=\"#{path}\"]/FileOption/FileArmAds/Cads/Optim", used: used)
              node.content = @operations.convert_enum(value, convert)
            end

            def lto(target, value, *args, used: true, **kargs)
              @operations.set_option_node(
                  target, "TargetOption/TargetArmAds/Cads/v6Lto", value, used: used
              )
            end

            def ro_independent(target, value, *args, used: true, **kargs)
              @operations.set_option_node(
                  target, "TargetOption/TargetArmAds/Cads/Ropi", @operations.convert_boolean(value), used: used
              )
            end

            def rw_independent(target, value, *args, used: true, **kargs)
              @operations.set_option_node(
                  target, "TargetOption/TargetArmAds/Cads/Rwpi", @operations.convert_boolean(value), used: used
              )
            end

            def short_enums_wchar(target, short_enum, short_wchar, *args, used: true, **kargs)
              @operations.set_option_node(
                  target, "TargetOption/TargetArmAds/Cads/vShortEn", @operations.convert_boolean(short_enum), used: used
              )
              @operations.set_option_node(
                  target, "TargetOption/TargetArmAds/Cads/vShortWch", @operations.convert_boolean(short_wchar), used: used
              )
            end

            def use_rtti(target, value, *args, used: true, **kargs)
              @operations.set_option_node(
                  target, "TargetOption/TargetArmAds/Cads/v6Rtti", @operations.convert_boolean(value), used: used
              )
            end

            # Enable optimization for time
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def optimize_for_time(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/oTime", @operations.convert_boolean(value), used: used
                )
            end

            # Enable load/store multiple instruction
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def split_load_store_multiple(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/SplitLS", @operations.convert_boolean(value), used: used
                )
            end

            # Enable one elf section per function
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def one_elf_section_per_function(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/OneElfS", @operations.convert_boolean(value), used: used
                )
            end

            # Enable strict ansi-c
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def strict_ansi(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/Strict", @operations.convert_boolean(value), used: used
                )
            end

            # Enable enum as int type
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def enum_is_always_int(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/EnumInt", @operations.convert_boolean(value), used: used
                )
            end

            # Enable signed plain char
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def plain_char_is_signed(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/PlainCh", @operations.convert_boolean(value), used: used
                )
            end

            # Enable signed plain char
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def no_auto_includes(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/uSurpInc", @operations.convert_boolean(value), used: used
                )
            end

            def warnings(target, value, compiler, *args, used: true, **kargs)
                convert = if compiler == 'armcc'
                            { 'unspecified' => 0, 'nowarnings' => 1, 'allwarnings' => 2 }
                          else
                            { 'default' => 3, 'w' => 1, 'Weverything' => 2, 'Wall' => 3 }
                          end
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/wLevel", @operations.convert_enum(value, convert), used: used
                )
            end

            def turn_warnings_into_errors(target, value, compiler, *args, used: true, **kargs)
              if compiler == 'armclang'
                @operations.set_option_node(
                  target, "TargetOption/TargetArmAds/Cads/v6WtE", @operations.convert_boolean(value), used: used
                )
              end
            end

            def c99_mode(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/uC99", @operations.convert_boolean(value), used: used
                )
            end

            def all_mode(target, value, *args, used: true, **kargs)
                convert = { '-xc=default' => 0, '-xc=c90' => 1, '-xc=gnu90' => 2, '-xc=c99' => 3, '-xc=gnu99' => 4, '-xc=c11' => 5, '-xc=gunll' => 6,
                            '-std=c90' => 1, '-std=gnu90' => 2, '-std=c99' => 3, '-std=gnu99' => 4, '-std=c11' => 5, '-std=gnu11' => 6
                        }
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/v6Lang", @operations.convert_enum(value, convert), used: used
                )
            end

            def all_mode_cpp(target, value, *args, used: true, **kargs)
              convert = {'-std=c++98' => 1, '-std=gnu++98' => 2, '-std=c++11' => 3, '-std=gnu++11' => 4, '-std=c++03' => 5, '-std=c++14' => 6, '-std=gnu++14' => 7, '-std=c++17' => 8, '-std=gnu++17' => 9}
              @operations.set_option_node(
                  target, "TargetOption/TargetArmAds/Cads/v6LangP", @operations.convert_enum(value, convert), used: used
              )
            end
            # Add include path
            # ==== arguments
            # target    - name of target
            # value     - string, path
            def add_include(target, value, *args, used: true, **kargs)
                value = @operations.convert_string(value)
                node = @operations.create_option_node(
                    target, "TargetOption/TargetArmAds/Cads/VariousControls/IncludePath", used: used
                )
                return if !node.content.empty? && node.content.split(';').include?(value)
                node.content = node.content.empty? ? value : "#{node.content};#{value}"
            end

            # Clear all includes
            # ==== arguments
            # target    - name of target
            def clear_include!(target, *args, used: false, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Cads/VariousControls/IncludePath", '', used: false
                )
            end

            # Add flag to misc control
            # ==== arguments
            # target    - name of target
            # value     - string
            def add_misc_control(target, value, *args, used: true, **kargs)
                @operations.logger.debug("deprecated function 'add_misc_control', use 'add_misc_flag' !")
                add_misc_flag(target, value, *args, used: used, **kargs)
            end

            # Clear all misc controls
            # ==== arguments
            # target    - name of target
            def clear_misc_controls!(target, *args, used: false, **kargs)
                @operations.logger.debug("deprecated function 'clear_misc_controls', use 'clear_misc_flags!' !")
                init_target_otherflags(target)
                @miscflags[ target ].clear
                update_misc_controls(target, used: false)
            end

            def add_misc_flag(target, value, *args, used: true, **kargs)
                init_target_otherflags(target)
                @miscflags[ target ].push({'type' => 'flag', 'value' => @operations.convert_string(value)})
                update_misc_controls(target, used: used)
            end

            # -------------------------------------------------------------------------------------
            # Add flag to misc flag on source level
            # @param [String] target: name of target
            # @param [String] path: file path
            # @param [String] value: misc flag
            # @return [Nil]
            def add_misc_flag_for_src(target, path, value, *args, used: true, **kargs)
              @miscflags_for_src[target] = [] if @miscflags_for_src[target].nil?
              @miscflags_for_src[target].push({'path' => path, 'value' => @operations.convert_string(value)})
              update_misc_controls_for_src(target, used: used)
            end

            def clear_misc_flags!(target, *args, used: false, **kargs)
                init_target_otherflags(target)
                @miscflags[ target ].each_with_index do | item, index |
                    @miscflags[ target ].delete_at(index) if (item[ 'type' ] == "flag")
                end
                update_misc_controls(target, used: false)
            end

            def add_misc_sysinclude(target, value, *args, used: true, **kargs)
                init_target_otherflags(target)
                # TODO: quote keyarg
                @miscflags[ target ].push({'type' => 'sysinc', 'value' => "-J#{@operations.convert_string(value)}"})
                update_misc_controls(target, used: used)
            end

            def clear_misc_sysinclude!(target, *args, used: false, **kargs)
                init_target_otherflags(target)
                @miscflags[ target ].each_with_index do | item, index |
                    @miscflags[ target ].delete_at(index) if (item[ 'type' ] == "sysinc")
                end
                update_misc_controls(target, used: false)
            end

            private

            def init_target_otherflags(target, *args, **kargs)
                if (@miscflags[ target ].nil?)
                    @miscflags[ target ] = []
                end
            end

            def update_misc_controls(target, *args, used: true, **kargs)
                content = ''
                node = @operations.create_option_node(target, "TargetOption/TargetArmAds/Cads/VariousControls/MiscControls", used: used)
                @miscflags[ target ].each do | item |
                    next if (item.nil?)
                    content = "#{content}#{item[ 'value']} "
                end
                node.content = content.strip
            end

            def update_misc_controls_for_src(target, *args, used: true, **kargs)
                content = ''
                last_file = ''
                @miscflags_for_src[target].each do |item|
                  file_name = item['path'].split('/')[-1]
                  content = '' if last_file != file_name
                  node = @operations.create_option_node_for_src(target, "Groups/Group/Files/File[FilePath=\"#{item['path']}\"]/FileOption/FileArmAds/Cads/VariousControls/MiscControls", used: used)
                  content = "#{content}#{item[ 'value']} "
                  node.content = content.strip
                  last_file = file_name
                end
            end

        end


        class AssemblerTab < TabBase

            def initialize(*args)
                super
                @miscflags = {}
                #  key is target, value is an array contained Hash which the key is path and the value is flag
                 @miscflags_for_src = {}
            end

            private

            # Enable interworking. This checkbox might be hidden for some architecture.
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def interworking(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Aads/interw", @operations.convert_boolean(value), used: used
                )
            end

            # Add define
            # ==== arguments
            # target    - name of target
            # value     - string, format "name=value"
            def add_define(target, value, *args, used: true, **kargs)
                value = @operations.convert_string(value)
                node = @operations.create_option_node(
                    target, "TargetOption/TargetArmAds/Aads/VariousControls/Define", used: used
                )
                node.content = node.content.empty? ? value : "#{node.content}, #{value}"
            end

            # Clear all defines
            # ==== arguments
            # target    - name of target
            def clear_defines!(target, *args, used: false, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Aads/VariousControls/Define", '', used: false
                )
            end

            # Enable thumb mode
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def thumb(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Aads/thumb", @operations.convert_boolean(value), used: used
                )
            end

            # Enable no warnings
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def no_warnings(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Aads/NoWarn", @operations.convert_boolean(value), used: used
                )
            end

            # Enable split load/store multiple
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def split_load_store_multiple(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Aads/SplitLS", @operations.convert_boolean(value), used: used
                )
            end

            # Enable "no autoincludes"
            # ==== arguments
            # target    - name of target
            # value     - true/false
            def no_auto_includes(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Aads/uSurpInc", @operations.convert_boolean(value), used: used
                )
            end

            # Add include path
            # ==== arguments
            # target    - name of target
            # value     - string, path
            def add_include(target, value, *args, used: true, **kargs)
                value = @operations.convert_string(value)
                node = @operations.create_option_node(
                    target, "TargetOption/TargetArmAds/Aads/VariousControls/IncludePath",  used: used
                )
                return if !node.content.empty? && node.content.split(';').include?(value)
                node.content = node.content.empty? ? value : "#{node.content};#{value}"
            end

            # Clear all include
            # ==== arguments
            # target    - name of target
            def clear_include!(target, *args, used: false, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/Aads/VariousControls/IncludePath", '', used: false
                )
            end

            # Add misc control
            # ==== arguments
            # target    - name of target
            # value     - string
            def add_misc_control(target, value, *args, used: true, **kargs)
                @operations.logger.debug("deprecated function 'add_misc_control', use 'add_misc_flag' !")
                add_misc_flag(target, value, *args, used: used, **kargs)
            end

            # Clear all misc controls
            # ==== arguments
            # target    - name of target
            def clear_misc_controls!(target, *args, used: false, **kargs)
                @operations.logger.debug("deprecated function 'clear_misc_controls', use 'clear_misc_flags!' !")
                init_target_otherflags(target)
                @miscflags[ target ].clear
                update_misc_controls(target, used: false)
            end

            def add_misc_flag(target, value, *args, used: true, **kargs)
                init_target_otherflags(target)
                @miscflags[ target ].push({'type' => 'flag', 'value' => @operations.convert_string(value)})
                update_misc_controls(target, used: used)
            end

            def clear_misc_flags!(target, *args, used: false, **kargs)
                init_target_otherflags(target)
                @miscflags[ target ].each_with_index do | item, index |
                    @miscflags[ target ].delete_at(index) if (item[ 'type' ] == "flag")
                end
                update_misc_controls(target, used: false)
            end

            def add_cpreproc_define(target, value, *args, used: true, **kargs)
                init_target_otherflags(target)
                @miscflags[ target ].push({'type' => 'define', 'value' => value})
                update_misc_controls(target, used: used)
            end

            def clear_cpreproc_defines!(target, *args, used: true, **kargs)
                init_target_otherflags(target)
                @miscflags[ target ].each_with_index do | item, index |
                    @miscflags[ target ].delete_at(index) if (item[ 'type' ] == "define")
                end
                update_misc_controls(target, used: false)
            end

#            def add_misc_sysinclude(target, value, *args, used: true, **kargs)
#                init_target_otherflags(target)
#                # TODO: quote keyarg
#                @miscflags[ target ].push({'type' => 'sysinc', 'value' => "-J#{@operations.convert_string(value)}"})
#                update_misc_controls(target, used: used)
#            end

#            def clear_misc_sysinclude!(target, *args, used: false, **kargs)
#                init_target_otherflags(target)
#                @miscflags[ target ].each_with_index do | item, index |
#                    @miscflags[ target ].delete_at(index) if (item[ 'type' ] == "sysinc")
#                end
#                update_misc_controls(target, used: used)
#            end

            private

            def init_target_otherflags(target, *args, **kargs)
                if (@miscflags[ target ].nil?)
                    @miscflags[ target ] = []
                end
            end

            def update_misc_controls(target, *args, used: true, **kargs)
                content, defines = '', ''
                node = @operations.create_option_node(target, "TargetOption/TargetArmAds/Aads/VariousControls/MiscControls", used: used)
                # evaluate defines
                @miscflags[ target ].each do | item |
                    next if (item['type'] != 'define')
                    defines += ',' unless (defines.empty?)
                    defines += "-D#{item['value']}"
                end
                content = "--cpreproc_opts '#{defines}' " unless (defines.empty?)
                # add remaining flags
                @miscflags[ target ].each do | item |
                    next if (item.nil?)
                    next if (item['type'] == 'define')
                    content = "#{content}#{item[ 'value']} "
                end
                node.content = content.strip
            end

            def add_misc_flag_for_src(target, path, value, *args, used: true, **kargs)
              @miscflags_for_src[target] = [] if @miscflags_for_src[target].nil?
              @miscflags_for_src[target].push({'path' => path, 'value' => @operations.convert_string(value)})
              update_misc_controls_for_src(target, used: used)
            end

            def update_misc_controls_for_src(target, *args, used: true, **kargs)
              content = ''
              last_file = ''
              @miscflags_for_src[target].each do |item|
                file_name = item['path'].split('/')[-1]
                content = '' if last_file != file_name
                node = @operations.create_option_node_for_src(target, "Groups/Group/Files/File[FilePath=\"#{item['path']}\"]/FileOption/FileArmAds/Aads/VariousControls/MiscControls", used: used)
                content = "#{content}#{item['value']} "
                node.content = content.strip
                last_file = file_name
              end
            end

            def ro_independent(target, value, *args, used: true, **kargs)
              @operations.set_option_node(
                  target, "TargetOption/TargetArmAds/Aads/Ropi", @operations.convert_boolean(value), used: used
              )
            end

            def rw_independent(target, value, *args, used: true, **kargs)
              @operations.set_option_node(
                  target, "TargetOption/TargetArmAds/Aads/Rwpi", @operations.convert_boolean(value), used: used
              )
            end

        end


        class LinkerTab < TabBase

            def initialize(*args)
                super
                @miscflags = {}
            end

            private


            # Use memory layout from dialog
            # ==== arguments
            # target    - name of target
            # value     - string
            def use_memory_layout_from_dialog(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/LDads/umfTarg", @operations.convert_boolean(value), used: used
                )
            end

            # Enable "dont search standard lib"
            # ==== arguments
            # target    - name of target
            # value     - string
            def dont_search_standard_lib(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/LDads/noStLib", @operations.convert_boolean(value), used: used
                )
            end

            # Enable "report might fail"
            # ==== arguments
            # target    - name of target
            # value     - string
            def report_might_fail(target, value, *args, used: true, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/LDads/RepFail", @operations.convert_boolean(value), used: used
                )
            end

            def add_disable_warning(target, value, *args, used: true, **kargs)
                option_node = @operations.create_option_node(
                    target, "TargetOption/TargetArmAds/LDads/DisabledWarnings", used: used
                )
                if (!option_node.content || option_node.content.empty?)
                    option_node.content = @operations.convert_string(value)
                else
                    option_node.content = "#{option_node.content},#{@operations.convert_string(value)}"
                end
            end

            def clear_disable_warnings!(target, value, *args, used: false, **kargs)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/LDads/DisabledWarnings", '', used: false
                )
            end

            # Setup scatter file
            # ==== arguments
            # target    - name of target
            # value     - string, path
            def scatter_file(target, value, *args, used: true, **kargs)
                use_memory_layout_from_dialog(target, false, used: used)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/LDads/ScatterFile", @operations.convert_string(value), used: used
                )
            end

            def use_microlib(target, value, *args, used: true, **kargs)
                use_memory_layout_from_dialog(target, false, used: used)
                @operations.set_option_node(
                    target, "TargetOption/TargetArmAds/ArmAdsMisc/useUlib", @operations.convert_boolean(value), used: used
                )
            end

            # Add misc control
            # ==== arguments
            # target    - name of target
            # value     - string
            def add_misc_control(target, value, *args, used: true, **kargs)
                add_misc_flag(target, value, *args, used: used, **kargs)
                @operations.logger.debug("deprecated function 'add_misc_control', use 'add_misc_flag' !")
            end

            # Clear all misc controls
            # ==== arguments
            # target    - name of target
            # ==== note
            # do not affect libraries
            def clear_misc_controls!(target, *args, used: false, **kargs)
                @operations.logger.debug("deprecated function 'clear_misc_controls!', use 'clear_misc_flags!' !")
                init_target_otherflags(target)
                @miscflags[ target ].clear
                update_misc_controls(target, used: false)
            end

            def add_misc_flag(target, value, *args, used: true, **kargs)
                init_target_otherflags(target)
                @miscflags[ target ].push({'type' => 'flag', 'value' => @operations.convert_string(value)})
                update_misc_controls(target, used: used)
            end

            def clear_misc_flags!(target, *args, used: false, **kargs)
                init_target_otherflags(target)
                @miscflags[ target ].each_with_index do | item, index |
                    @miscflags[ target ].delete_at(index) if (item[ 'type' ] == "flag")
                end
                update_misc_controls(target, used: false)
            end

            # Virtual function (GUI) does not exist, add library
            # ==== arguments
            # target    - name of target
            # library   - library path
            def add_library(target, value, *args, used: true, **kargs)
                init_target_otherflags(target)
                @miscflags[ target ].push({'type' => 'library', 'value' => @operations.convert_string(value)})
                update_misc_controls(target, used: used)
            end

            # Virtual function (GUI) does not exist, clear libraries
            # ==== arguments
            # target    - name of target
            # library   - library path
            # ==== note
            # loops over saved libs and remove them from misc flags
            def clear_libraries!(target, *args, used: false, **kargs)
                init_target_otherflags(target)
                @miscflags[ target ].each_with_index do | item, index |
                    @miscflags[ target ].delete_at(index) if (item[ 'type' ] == "library")
                end
                update_misc_controls(target, used: false)
            end

            private

            def init_target_otherflags(target, *args, **kargs)
                if (@miscflags[ target ].nil?)
                    @miscflags[ target ] = []
                end
            end

            def update_misc_controls(target, *args, used: true, **kargs)
                content = ''
                node = @operations.create_option_node(target, "TargetOption/TargetArmAds/LDads/Misc", used: used)
                @miscflags[ target ].each do | item |
                    next if (item.nil?)
                    content = "#{content}#{item[ 'value']} "
                end
                node.content = content.strip
            end
        end

        class UtilitiesTab < TabBase
          def initialize(*args)
            super
          end

          private

          def configure_flash_program(target, path, *args, used: true, **kargs)
            @operations.set_option_node(
                target, "TargetOption/Utilities/Flash4", path, used: used
            )
          end

          def update_before_debug(target, value, *args, used: true, **kargs)
            node_value = value ? 1 : 0
            @operations.set_option_node(
                target, "TargetOption/Utilities/Flash1/UpdateFlashBeforeDebugging", node_value, used: used
            )
          end

        end

        class PropertiesTab < TabBase
          def initialize(*args)
            super
          end

          private

          def exclude_building(target, path, exclude, *args, used: true, **kargs)
            if exclude && @operations.targets.include?(target)
              node = @operations.create_option_node_for_src(target, "Groups/Group/Files/File[FilePath=\"#{path}\"]/FileOption/CommonProperty/IncludeInBuild", used: used)
              node.content = 0
            end
          end
        end
    end

end
end



