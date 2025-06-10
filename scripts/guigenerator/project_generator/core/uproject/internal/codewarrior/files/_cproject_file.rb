# frozen_string_literal: true

# ********************************************************************
# Copyright 2022, 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../cdt/files/_cproject_file'
require 'logger'
require 'nokogiri'

module Internal
  module CodeWarrior
    class CprojectFile < Internal::Cdt::CprojectFile
      attr_reader :xml
      attr_reader :logger
      attr_reader :operations

      def initialize(template, *_args, logger: nil, **_kwargs)
        @xml = XmlUtils.load(template)
        @logger = logger || Logger.new(STDOUT)
        @targets = {}
      end

      private

      # Save file
      # ==== arguments
      # path      - string, file path to save
      def save(path, *_args, **_kargs)
        Core.assert(path.is_a?(String) && !path.empty?) do
          'param must be non-empty string'
        end
        @logger.debug("generate file: #{path}")
        @operations.update_node_id
        XmlUtils.save(@xml, path)
      end


      def get_target_name(*args, **kwargs)
        return @operations.get_target_name(*args, **kwargs)
      end

      def set_target_name(*args, **kwargs)
        @operations.set_target_name(*args, **kwargs)
      end

      # Return list of all targets found in xml file
      def targets(*_args, **_kargs)
        return @operations.targets
      end

      def clear_unused_targets!(*_args, **_kargs)
        @operations.clear_unused_targets!
      end

      def update_cdt_build_system(project_name, used: true)
        Core.assert(project_name.is_a?(String) && !project_name.empty?) do
          'param must be a non empty string'
        end
        buildSystem_path = "/cproject/storageModule[\@moduleId=\"cdtBuildSystem\"]"
        project_type = 'com.freescale.dsc.cdt.toolchain.project.executable'
        buildSystem_node = @xml.xpath(buildSystem_path)
        project_node = buildSystem_node.at_xpath('project')
        project_node['id'] = project_name + '.' + project_type + '.' + rand(1_000_000_000..1_999_999_999).to_s
        project_node['name'] = 'Freescale DSC Project'
        project_node['projectType'] = project_type
      end

      def add_variable(target, name, value, used: true)
        Core.assert(name.is_a?(String) && !name.empty?) do
          'param must be non empty string'
        end
        Core.assert(value.is_a?(String) && !value.empty?) do
          'param must be non empty string'
        end
        target_node = @operations.target_node(target, used: used)
        parent_node = target_node.at_xpath("storageModule[\@moduleId=\"org.eclipse.cdt.core.settings\"]/macros")
        if parent_node.nil?
          storage_node = target_node.at_xpath("storageModule[\@moduleId=\"org.eclipse.cdt.core.settings\"]")
          Core.assert(!storage_node.nil?) do
            'no <storageModule>'
          end
          parent_node = Nokogiri::XML::Node.new('macros', @operations.xml)
          storage_node << parent_node
        end
        macro_node = Nokogiri::XML::Node.new('stringMacro', @operations.xml)
        macro_node['name'] = name
        macro_node['value'] = value
        parent_node << macro_node
      end

      def clear_variables!(target, *_args, used: false, **_kargs)
        target_node = @operations.target_node(target, used: used)
        collection = target_node.xpath("storageModule[\@moduleId=\"org.eclipse.cdt.core.settings\"]/macros/*")
        collection&.remove
      end

      def artifact_name(target, value, *_args, used: true, **_kargs)
        target_node = @operations.target_node(target, used: used)
        configuration_node = target_node.at_xpath("storageModule/configuration\[\@artifactName\]")
        Core.assert(!configuration_node.nil?) do
          '<configuration> node does not exists'
        end
        configuration_node['artifactName'] = value
      end

      def artifact_extension(target, value, *_args, used: true, **_kargs)
        target_node = @operations.target_node(target, used: used)
        configuration_node = target_node.at_xpath("storageModule/configuration\[\@artifactName\]")
        Core.assert(!configuration_node.nil?) do
          '<configuration> node does not exists'
        end
        configuration_node['artifactExtension'] = value
      end

      def artifact_prefix_archiver(target, value, *_args, used: true, **_kargs)
        superclass = 'cdt.managedbuild.tool.gnu.archiver.output'
        xpath = @operations.xpath_variant("storageModule/configuration/folderInfo/toolChain/tool/outputType[\@superClass = \"#{superclass}\"]")
        output_type_node = @operations.target_node(target, used: used).at_xpath(xpath)
        if output_type_node.nil?
          xpath = @operations.xpath_variant("storageModule/configuration/folderInfo/toolChain/tool[\@superClass = \"ilg.gnuarmeclipse.managedbuild.cross.tool.archiver\"]")
          tool_node = @operations.target_node(target, used: used).at_xpath(xpath)
          Core.assert(!tool_node.nil?) { 'missing tool node' }
          output_type_node = Nokogiri::XML::Node.new('outputType', @xml)
          output_type_node['id'] = "#{superclass}.#{@operations.uid}"
          output_type_node['superClass'] = superclass.to_s
          tool_node << output_type_node
        end
        output_type_node['outputPrefix'] = value
      end

      def artifact_prefix_linker(target, value, *_args, used: true, **_kargs)
        xpath = @operations.xpath_variant("storageModule/configuration/folderInfo/toolChain/tool[\@superClass = \"ilg.gnuarmeclipse.managedbuild.cross.tool.c.linker\"]")
        tool_node = @operations.target_node(target, used: used).at_xpath(xpath)
        Core.assert(!tool_node.nil?) do
          'missing tool node'
        end
        tool_node['outputPrefix'] = value
      end

      def builder(target, value, *_args, used: true, **_kargs)
        Core.assert(%w[external internal].include?(value)) do
          "invalud vaue '#{value}' use one of 'external, internal'"
        end
        builder_node = @operations.get_general_node(target, used: used).at_xpath('builder[@superClass="org.eclipse.cdt.build.core.internal.builder"]')
        builder_node ||= @operations.get_general_node(target, used: used).at_xpath('builder[@superClass="ilg.gnuarmeclipse.managedbuild.cross.builder"]')
        builder_node ||= @operations.get_general_node(target, used: used).at_xpath('builder')
        Core.assert(builder_node, 'builder node does not exists')
        if value == 'internal'
          builder_node['superClass'] = 'org.eclipse.cdt.build.core.internal.builder'
        else
          (value == 'external')
          builder_node['superClass'] = 'ilg.gnuarmeclipse.managedbuild.cross.builder'
        end
      end

      private

      # Base tab class to inherit @operations attribute
      class TabBase
        XML_CONFIG_BASE_PATH = "./storageModule[\@moduleId=\"cdtBuildSystem\"]/configuration/folderInfo/toolChain"
        attr_reader :operations

        def initialize(operations, *_args, **_kwargs)
          @operations = operations
        end
      end

      class DocumentOperations < DocumentOperations
        attr_reader :variant
        attr_reader :xml
        attr_reader :targets

        def initialize(xml, variant, *args, **kwargs)
          Core.assert(!xml.nil?) do
            'param cannot be nil'
          end
          Core.assert(variant.is_a?(String)) do
            'param must be string'
          end
          Core.assert(%w[lib exe].include?(variant)) do
            "invalid variant '#{variant}'"
          end
          super
          @xml = xml
          @variant = variant
          # loop over targets
          nodes = @xml.xpath('/cproject/storageModule').first
          nodes.children.each do |target_node|
            name_node = target_node.at_xpath('storageModule')
            Core.assert(!name_node.nil?) do
              'no <cconfiguration> node!'
            end
            next if name_node['name'].include? 'Target Template'

            # and use downcase stripped version of target name
            target = name_node['name'].strip.downcase
            @targets[target] = {
                'node' => target_node,
                'used' => false
            }
          end
        end

        def targets()
          return @targets.keys
        end

        def update_node_id
          num = 1
          @targets.each do |target, target_node|
            next if target_node['used'] == false
            update_node_id_recursively(target_node['node'], num)
            num += 1
          end
        end

        def update_node_id_recursively(target_node, num)
          return if target_node.nil?

          unless target_node['id'].nil?
            res = target_node['id'].match(/(^com\S+\.)(\d+$)/)
            target_node['id'] = res[1] + "#{res[2].to_i + num}" if res
          end
          target_node.element_children.each do |element|
            update_node_id_recursively(element, num)
          end
        end

        def target_node(target, used: nil)
          Core.assert(target.is_a?(String) && !target.empty?) do
            'param must be non-empty string'
          end
          Core.assert(!used.nil?) do
            'used cannot be a nil'
          end
          target = target.strip.downcase
          Core.assert(@targets.has_key?(target)) do
            "target '#{target}' is not present. use one of: #{@targets.keys}"
          end
          Core.assert(!@targets[ target ][ 'node' ].nil?) do
            "name '#{target}' does not exist"
          end
          @targets[ target ][ 'used' ] = true if (used)
          return @targets[ target ][ 'node' ]
        end

        def set_target_name(target, *args, used: false, **kwargs)
          target_node = target_node(target, used: used)
          core_setting_node = target_node.at_xpath("./storageModule[\@moduleId=\"org.eclipse.cdt.core.settings\"]")
          core_setting_node['name'] = target

          configuration_node = target_node.at_xpath("./storageModule[\@moduleId=\"cdtBuildSystem\"]/configuration")
          configuration_node['name'] = target

          builder_node = configuration_node.at_xpath('./folderInfo/toolChain/builder')
          builder_node['buildPath'] = "${ProjDirPath}/build/#{target}"
        end

        def create_option_state_node(target, xpath, value, used: nil)
          Core.assert(target.is_a?(String) && !target.empty?) do
            'param must be non-empty string'
          end
          Core.assert(xpath.is_a?(String) && !xpath.empty?) do
            'param must be non-empty string'
          end
          option_node = target_node(target, used: used).at_xpath(xpath)
          Core.assert(!option_node.nil?) do
            "nodeset does not exist '#{xpath}'"
          end
          state_node = Nokogiri::XML::Node.new('listOptionValue', @xml)
          state_node['builtIn'] = false
          state_node['value'] = value.to_s
          option_node << state_node
        end

        def clear_unused_targets!
          @targets.each do | target_key, target_item |
            if (target_item[ 'used' ] == false)
              target_item[ 'node' ].remove
              @targets.delete(target_key)
            end
          end
        end

        def create_option_node(target, xpath, valueType, used:nil)
          option_node = target_node(target, used: used).at_xpath(xpath)
          if (option_node.nil?)
            matched = xpath.match(/^(.*)\/([^\/]+)/)
            Core.assert(!matched.nil?) do
              "corrupted xpath #{xpath}"
            end
            parent_xpath, node_name = matched.captures
            parent_node = target_node(target, used: used).at_xpath(parent_xpath)
            Core.assert(!parent_node.nil?) do
              "not such a node #{parent_xpath}"
            end
            matched = node_name.match(/(\S+)\[@(\S+)=(\S+)\]/)
            node, attr_id, attr_val = matched.captures
            option_node = Nokogiri::XML::Node.new(node, @xml)
            option_node[attr_id] = attr_val.split('"')[1]
            option_node['id'] = option_node[attr_id] + '.' + rand(1_000_000_000..1_999_999_999).to_s
            option_node['valueType'] = valueType
            parent_node << option_node
          end
          Core.assert(!option_node.nil?) do
            "node of '#{xpath}' does not exist"
          end
          return option_node
        end

        def set_state_node(target, xpath, value, valueType, used: nil)
          Core.assert(target.is_a?(String) && !target.empty?) do
            'param must be non-empty string'
          end
          Core.assert(xpath.is_a?(String) && !xpath.empty?) do
            'param must be non-empty string'
          end
          state_node = create_option_node(target, xpath, valueType, used: used)
          state_node['value'] = value.to_s
        end

        def get_state_node(target, xpath, used: nil)
          target_node(target, used: used).at_xpath(xpath) || nil
        end

        def get_template_version(target, used: nil)
          # Judge template version according to c99 option, which is must-have and newly added for codewarrior 11.2
          xpath = "./storageModule[\@moduleId=\"cdtBuildSystem\"]/configuration/folderInfo/toolChain/tool[\@name=\"DSC Compiler\"]/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.language.c99\"]"
          if target_node(target, used: used).at_xpath(xpath)
            return "v4"
          else
            return "v3"
          end
        end

        ########################################################################################

        # perform trick and modify xpath according 'exe' or 'lib' type
        def xpath_variant(xpath)
          # xpath.gsub!('.lib.', ".#{@variant}.")
          # xpath.gsub!('.exe.', ".#{@variant}.")
          # xpath.gsub!('.lib', ".#{@variant}")
          # xpath.gsub!('.exe', ".#{@variant}")
          return xpath
        end
      end

      class DSCCompilerTab < TabBase
        COMPILER_CONFIG_BASE_PATH = XML_CONFIG_BASE_PATH + "/tool[\@name=\"DSC Compiler\"]"

        class InputTab < TabBase

          private

          def clear_macros!(target, *args, used: false, **kargs)
            collection = @operations.target_node(target, used: used).xpath(COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.macros.definedMacros\"]/listOptionValue")
            collection&.remove
          end

          def add_macros(target, value, *args, used: true, **kargs)
            @operations.create_option_state_node(
                target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.macros.definedMacros\"]", value, used: used
            )
          end

        end

        class AccessPathsTab < TabBase

          private

          # clear include path
          def clear_include!(target, *args, used: false, **kargs)
            collection = @operations.target_node(target, used: used).xpath(COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.input.include\"]/listOptionValue")
            collection&.remove
          end

          def clear_sys_search_path!(target, *args, used: false, **kargs)
            collection = @operations.target_node(target, used: used).xpath(COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.input.sysInclude\"]/listOptionValue")
            collection&.remove
          end

          def clear_sys_path_recursively!(target, *args, used: false, **kargs)
            collection = @operations.target_node(target, used: used).xpath(COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.input.sysIncludeRecursive\"]/listOptionValue")
            collection&.remove
          end

          def add_user_paths(target, value, *args, used: true, **kargs)
            if value.match(/^\$\{\S+\}\S+/)
              value = '"' + value + '"'
            end
            collection = @operations.target_node(target, used: used).xpath(COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.input.include\"]")
            # filter duplicated compiler include path
            collection.children.each do |node|
              return if node['value'] == value
            end
            @operations.create_option_state_node(
                target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.input.include\"]", value, used: used
            )
          end

          def add_sys_search_path(target, value, *args, used: true, **kargs)
            if value.match(/^\$\{\S+\}\S+/)
              value = '"' + value + '"'
            end
            @operations.create_option_state_node(
                target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.input.sysInclude\"]", value, used: used
            )

            def add_sys_path_recursively(target, value, *args, used: true, **kargs)
              if value.match(/^\$\{\S+\}\S+/)
                value = '"' + value + '"'
              end
              @operations.create_option_state_node(
                  target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.input.sysIncludeRecursive\"]", value, used: used
              )
            end
          end

        end

        class WarningsTab < TabBase

        end

        # Contains operations of "OptimizationTab"
        class OptimizationTab < TabBase

          private

          # Select optimization level
          def optimization_level(target, value, *args, used: true, **kargs)
            value = "com.freescale.dsc.cdt.toolchain.compiler.optimization.level.level#{value}"
            @operations.set_state_node(
                target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.optimization.level\"]", value, "enumerated", used: used
            )
          end

          def optimization_mode(target, value, *args, used: true, **kargs)
            value = "com.freescale.dsc.cdt.toolchain.compiler.optimization.mode.#{value}"
            @operations.set_state_node(
                target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.optimization.mode\"]", value, "enumerated", used: used
            )
          end
        end

        class ProcessorTab < TabBase

          private

          def small_program_model(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.processor.progModel\"]", value, "boolean", used: used
            )
          end

          def large_program_model(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.processor.progModelLarge\"]", value, "boolean", used: used
            )
          end

          def huge_program_model(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.processor.progModelHuge\"]", value, "boolean", used: used
            )
          end

          def large_data_mem_model(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.processor.dataModel\"]", value, "boolean", used: used
            )
          end

          def set_pad_pipeline(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.processor.padpipe\"]", value, "boolean", used: used
            )
          end

          def set_globals_live(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.processor.globals\"]", value, "boolean", used: used
            )
          end

          def set_hawk_elf(target, value, *args, used: true, **kargs)
            if @operations.get_template_version(target, used: used) == "v4"
              @operations.set_state_node(target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.processor.generates56800EF\"]", value, "boolean", used: used)
              @operations.set_state_node(target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.processor.generates56800EX\"]", !value, "boolean", used: used)
            end
          end

        end

        class LanguageTab < TabBase

          private

          def set_language_c99(target, value, *args, used: true, **kargs)
            if @operations.get_template_version(target, used: used) == "v4"
              @operations.set_state_node(target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.language.c99\"]", value, "boolean", used: used)
            elsif value == true
              add_other_flags(target, " -lang c99 ")
            end
          end

          def add_other_flags(target, value, *args, used: true, **kargs)
            xpath = COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.language.otherFlags\"]"
            node = @operations.get_state_node(target, xpath, used: used)
            value += node['value'] if node
            @operations.set_state_node(
                target, xpath, value, "string", used: used
            )
          end

          def set_require_protos(target, value, *args, used: true, **kargs)
            @operations.set_state_node(target, COMPILER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.compiler.language.prototypes\"]", value, "boolean", used: used)
          end
        end

      end

      class DSCAssemblerTab < TabBase
        ASM_CONFIG_BASE_PATH = XML_CONFIG_BASE_PATH + "/tool[\@name=\"DSC Assembler\"]"

        class InputTab < TabBase

          private

          def clear_include!(target, *args, used: false, **kargs)
            collection = @operations.target_node(target, used: used).xpath(ASM_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.asm.input.include\"]/listOptionValue")
            collection&.remove
          end

          def add_user_include(target, value, *args, used: true, **kargs)
            if value.match(/^\$\{\S+\}\S+/)
              value = '"' + value + '"'
            end
            @operations.create_option_state_node(
                target, ASM_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.asm.input.include\"]", value, used: used
            )
          end

          def set_no_syspath(target, value, *args, used: true, **kargs)
            @operations.set_state_node(target, ASM_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.asm.input.nosyspath\"]", value, "boolean", used: used)
          end
        end

        class GeneralTab < TabBase

          private

          def set_data_mem_model(target, value, *args, used: true, **kargs)
            value = "com.freescale.dsc.cdt.toolchain.asm.general.dataModel.#{value}bit"
            @operations.set_state_node(
                target, ASM_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.asm.general.dataModel\"]", value, "enumerated", used: used
            )
          end

          def set_program_mem_model(target, value, *args, used: true, **kargs)
            value = "com.freescale.dsc.cdt.toolchain.asm.general.progModel.#{value}bit"
            @operations.set_state_node(
                target, ASM_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.asm.general.progModel\"]", value, "enumerated", used: used
            )
          end

          def set_pad_pipeline(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, ASM_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.asm.general.padPipe\"]", value, "boolean", used: used
            )
          end

          def set_hawk_elf(target, value, *args, used: true, **kargs)
            if @operations.get_template_version(target, used: used) == "v4"
              @operations.set_state_node(target, ASM_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.asm.general.generates56800EF\"]", value, "boolean", used: used)
              @operations.set_state_node(target, ASM_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.asm.general.generates56800EX\"]", !value, "boolean", used: used)
            end
          end

          def add_other_flags(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, ASM_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.asm.general.otherFlags\"]", value, "string", used: used
            )
          end

        end

        class OutputTab < TabBase

        end

      end

      class DSCLinkerTab < TabBase
        LINKER_CONFIG_BASE_PATH = XML_CONFIG_BASE_PATH + "/tool[\@name=\"DSC Linker\"]"

        class InputTab < TabBase

          private

          def clear_linker_file!(target, *args, used: false, **kargs)
            node = @operations.target_node(target, used: used).at_xpath(LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.input.commandFile\"]")
            node['value'] = ''
          end

          def clear_lib_path!(target, *args, used: false, **kargs)
            collection = @operations.target_node(target, used: used).xpath(LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.input.libSearch\"]/listOptionValue")
            collection&.remove
          end

          def clear_addl_lib!(target, *args, used: false, **kargs)
            collection = @operations.target_node(target, used: used).xpath(LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.input.libs\"]/listOptionValue")
            collection&.remove
          end

          def linker_cmd_file(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.input.commandFile\"]", value, "string", used: used
            )
            entry_value = value
            entry_node = @operations.target_node(target, used: used).at_xpath("./storageModule[\@moduleId=\"cdtBuildSystem\"]/configuration/sourceEntries/entry")
            entry_node['excluding'] = entry_value
          end

          def lib_search_path(target, value, *args, used: true, **kargs)
            @operations.create_option_state_node(
                target, LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.input.libSearch\"]", value, used: used
            )
          end

          def add_addl_lib(target, value, *args, used: true, **kargs)
            @operations.create_option_state_node(
                target, LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.input.libs\"]", value, used: used
            )
          end

          def set_no_stdlib(target, value, *args, used: true, **kargs)
            @operations.set_state_node(target, LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.input.nostdlib\"]", value, "boolean", used: used)
          end

          def set_entry_point(target, value, *args, used: true, **kargs)
            @operations.set_state_node(target, LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.input.entryPoint\"]", value, "string", used: used)
          end
        end

        class LinkorderTab < TabBase

        end

        class GeneralTab < TabBase

          private

          def large_data_mem_model(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.general.dataModel\"]", value, "boolean", used: used
            )
          end

          def set_hawk_elf(target, value, *args, used: true, **kargs)
            if @operations.get_template_version(target, used: used) == "v4"
              @operations.set_state_node(target, LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.general.generates56800EF\"]", value, "boolean", used: used)
              @operations.set_state_node(target, LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.general.generates56800EX\"]", !value, "boolean", used: used)
            end
          end

          def add_other_flags(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.general.otherFlags\"]", value, "string", used: used
            )
          end

        end

        class OutputTab < TabBase

          private

          def set_generate_map(target, value, *args, used: true, **kargs)
            @operations.set_state_node(target, LINKER_CONFIG_BASE_PATH + "/option[\@superClass=\"com.freescale.dsc.cdt.toolchain.linker.output.mapFile\"]", value, "boolean", used: used)
          end
        end

      end
      class IncludesTab < TabBase

        private

        def add_include(target, value, *_args, used: true, **_kargs)
          option_node = @operations.create_assembler_option(
              target, 'ilg.gnuarmeclipse.managedbuild.cross.option.assembler.include.paths', 'includePath', used: used
          )
          listopt_node = Nokogiri::XML::Node.new('listOptionValue', @operations.xml)
          listopt_node['builtIn'] = 'false'
          listopt_node['value'] = @operations.convert_string(value)
          option_node << listopt_node
        end

        def clear_include!(target, *_args, used: false, **_kargs)
          # clear assembeler include path
          option_node = @operations.create_assembler_option(
              target, 'org.eclipse.cdt.build.core.settings.holder.incpaths', 'includePath', used: used
          )
          collection = option_node.xpath('*')
          collection&.remove
          # clear GNU C include path
          option_node = @operations.create_compiler_option(
              target, 'org.eclipse.cdt.build.core.settings.holder.incpaths', 'includePath', used: used
          )
          collection = option_node.xpath('*')
          collection&.remove
          # clear GNU C++ include path
          option_node = @operations.create_cpp_compiler_option(
              target, 'org.eclipse.cdt.build.core.settings.holder.incpaths', 'includePath', used: used
          )
          collection = option_node.xpath('*')
          collection&.remove
        end

        def add_includefile(target, value, *_args, used: true, **_kargs)
          option_node = @operations.create_assembler_option(
              target, 'ilg.gnuarmeclipse.managedbuild.cross.option.assembler.include.files', 'includeFiles', used: used
          )
          listopt_node = Nokogiri::XML::Node.new('listOptionValue', @operations.xml)
          listopt_node['builtIn'] = 'false'
          listopt_node['value'] = @operations.convert_string(value)
          option_node << listopt_node
        end

        def clear_includefiles!(target, *_args, used: false, **_kargs)
          option_node = @operations.create_assembler_option(
              target, 'ilg.gnuarmeclipse.managedbuild.cross.option.assembler.include.files', 'includeFiles', used: used
          )
          collection = option_node.xpath('*')
          collection&.remove
        end
      end
    end
  end
end
