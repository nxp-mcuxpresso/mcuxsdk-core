# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../cdt/files/_cproject_file'
require 'logger'
require 'nokogiri'

module Internal
  module Xtensa
    class CprojectFile < Internal::Cdt::CprojectFile
      attr_reader :xml
      attr_reader :logger
      # attr_reader :operations

      def initialize(template, *_args, logger: nil, **_kwargs)
        @xml = XmlUtils.load(template)
        @logger = logger || Logger.new(STDOUT)
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

      def update_refresh_scope(project_name, used: true)
        Core.assert(project_name.is_a?(String) && !project_name.empty?) do
          'param must be a non empty string'
        end
        refresh_path = "/cproject/storageModule[\@moduleId=\"refreshScope\"]"
        refresh_node = @xml.xpath(refresh_path)
        resource_node = refresh_node.at_xpath("resource[\@resourceType=\"PROJECT\"]")
        resource_node['workspacePath'] = '/' + project_name + '/'
      end

      def update_cdt_build_system(project_name, used: true)
        Core.assert(project_name.is_a?(String) && !project_name.empty?) do
          'param must be a non empty string'
        end
        buildSystem_path = "/cproject/storageModule[\@moduleId=\"cdtBuildSystem\"]"
        buildSystem_node = @xml.xpath(buildSystem_path)
        project_node = buildSystem_node.at_xpath('project')
        project_node['id'] = project_name + '.null.' + rand(10_000_000..99_999_999).to_s
        project_node['name'] = project_name
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

      def prebuildstep_command(target, value, *_args, used: true, **_kargs)
        target_node = @operations.target_node(target, used: used)
        configuration_node = target_node.at_xpath("storageModule/configuration\[\@artifactName\]")
        Core.assert(!configuration_node.nil?) do
          '<configuration> node does not exists'
        end
        configuration_node['prebuildStep'] = value
      end

      def postbuildstep_command(target, value, *_args, used: true, **_kargs)
        target_node = @operations.target_node(target, used: used)
        configuration_node = target_node.at_xpath("storageModule/configuration\[\@artifactName\]")
        Core.assert(!configuration_node.nil?) do
          '<configuration> node does not exists'
        end
        configuration_node['postbuildStep'] = value
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
        else (value == 'external')
             builder_node['superClass'] = 'ilg.gnuarmeclipse.managedbuild.cross.builder'
        end
      end

      def create_flash_image(target, value, *_args, used: true, **_kargs)
        @operations.set_general_option(
          target, 'ilg.gnuarmeclipse.managedbuild.cross.option.addtools.createflash', 'boolean', @operations.convert_boolean(value), used: used
        )
      end

      def create_flash_choice(target, value, *_args, used: true, **_kargs)
        format_map = {
          'srec' => 'srec',
          'symbolsrec' => 'symbolsrec',
          'bin'  => 'binary',
          'hex'  => 'ihex'
        }
        Core.assert(format_map.key?(value)) do
          "type '#{value}' is not valid"
        end
        name = 'ilg.gnuarmeclipse.managedbuild.cross.option.createflash.choice'
        @operations.set_flash_image_option(
          target, name, 'enumerated', "#{name}.#{format_map[value]}", used: used
        )
      end

      def create_extended_listing(target, value, *_args, used: true, **_kargs)
        @operations.set_general_option(
          target, 'ilg.gnuarmeclipse.managedbuild.cross.option.addtools.createlisting', 'boolean', @operations.convert_boolean(value), used: used
        )
      end

      def print_size(target, value, *_args, used: true, **_kargs)
        @operations.set_general_option(
          target, 'ilg.gnuarmeclipse.managedbuild.cross.option.addtools.printsize', 'boolean', @operations.convert_boolean(value), used: used
        )
      end

      private

      # Base tab class to inherit @operations attribute
      class TabBase
        attr_reader :operations

        def initialize(operations, *_args, **_kwargs)
          @operations = operations
        end
      end

      class DocumentOperations < DocumentOperations
        attr_reader :variant
        attr_reader :xml

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
        end

        # perform trick and modify xpath according 'exe' or 'lib' type
        def xpath_variant(xpath)
          # xpath.gsub!('.lib.', ".#{@variant}.")
          # xpath.gsub!('.exe.', ".#{@variant}.")
          # xpath.gsub!('.lib', ".#{@variant}")
          # xpath.gsub!('.exe', ".#{@variant}")
          return xpath
        end

        def get_compiler_node(target, used: nil)
          xpath = xpath_variant(
            "//cproject/storageModule/cconfiguration/storageModule/configuration/folderInfo/toolChain/tool[\@name=\"GNU C\"]"
          )
          parent_node = target_node(target, used: used).at_xpath(xpath)
          Core.assert(!parent_node.nil?)
          return parent_node
        end

        def get_cpp_compiler_node(target, used: nil)
          xpath = xpath_variant(
            "//cproject/storageModule/cconfiguration/storageModule/configuration/folderInfo/toolChain/tool[\@name=\"GNU C++\"]"
          )
          parent_node = target_node(target, used: used).at_xpath(xpath)
          Core.assert(!parent_node.nil?)
          return parent_node
        end

        def create_compiler_option(target, superclass, valtype, used: nil)
          # allowed = {'boolean' => 1, 'enumerated' => 1, 'string' => 1, 'definedSymbols' => 1, 'includePath' => 1, 'stringList' => 1}
          allowed = {
            'boolean' => 1,
            'definedSymbols'        => 1,
            'includePath'           => 1,
            'undefDefinedSymbols'   => 1,
            'includeFiles'          => 1,
            'enumerated'            => 1,
            'string'                => 1
          }
          Core.assert(superclass.is_a?(String) && !superclass.empty?) do
            'param must be non empty string'
          end
          Core.assert(valtype.is_a?(String) && !valtype.empty?) do
            'param must be non empty string'
          end
          # prevent typo, check the 'valtype' against list of valid/supported types
          Core.assert(allowed.key?(valtype)) do
            "type '#{valtype}' is not valid"
          end
          # convert 'superclass' to current 'variant' type
          superclass = xpath_variant(superclass)
          # try to find superclass '<option>' node
          option_node = @xml.at_xpath(
            "//cproject/storageModule/cconfiguration/storageModule/configuration/folderInfo/toolChain/tool[\@name=\"GNU C\"]/option[\@superClass=\"#{superclass}\"]"
          )
          # if not present, create new one
          if option_node.nil?
            option_node = create_option_node(
              get_compiler_node(target, used: used), superclass, valtype
            )
          end
          return option_node
        end

        def create_cpp_compiler_option(target, superclass, valtype, used: nil)
          # allowed = {'boolean' => 1, 'enumerated' => 1, 'string' => 1, 'definedSymbols' => 1, 'includePath' => 1, 'stringList' => 1}
          allowed = {
            'boolean' => 1,
            'definedSymbols'        => 1,
            'includePath'           => 1,
            'undefDefinedSymbols'   => 1,
            'includeFiles'          => 1,
            'enumerated'            => 1,
            'string'                => 1
          }
          Core.assert(superclass.is_a?(String) && !superclass.empty?) do
            'param must be non empty string'
          end
          Core.assert(valtype.is_a?(String) && !valtype.empty?) do
            'param must be non empty string'
          end
          # prevent typo, check the 'valtype' against list of valid/supported types
          Core.assert(allowed.key?(valtype)) do
            "type '#{valtype}' is not valid"
          end
          # convert 'superclass' to current 'variant' type
          superclass = xpath_variant(superclass)
          # try to find superclass '<option>' node
          option_node = @xml.at_xpath(
            "//cproject/storageModule/cconfiguration/storageModule/configuration/folderInfo/toolChain/tool[\@name=\"GNU C++\"]/option[\@superClass=\"#{superclass}\"]"
          )
          # if not present, create new one
          if option_node.nil?
            option_node = create_option_node(
              get_cpp_compiler_node(target, used: used), superclass, valtype
            )
          end
          return option_node
        end

        def set_compiler_option(target, superclass, valtype, value, used: nil)
          option_node = create_compiler_option(target, superclass, valtype, used: used)
          option_node['value'] = value.to_s
        end

        def set_cpp_compiler_option(target, superclass, valtype, value, used: nil)
          option_node = create_cpp_compiler_option(target, superclass, valtype, used: used)
          option_node['value'] = value.to_s
        end

        def get_assembler_node(_target, used: nil)
          xpath = "//cproject/storageModule/cconfiguration/storageModule/configuration/folderInfo/toolChain/tool[\@name=\"Assembly\"]"
          parent_node = @xml.at_xpath(xpath)
          Core.assert(!parent_node.nil?)
          return parent_node
        end

        def create_assembler_option(target, superclass, valtype, used: nil)
          # allowed = {'boolean' => 1, 'enumerated' => 1, 'string' => 1, 'stringList' => 1}
          allowed = {
            'boolean' => 1,
            'definedSymbols'        => 1,
            'includePath'           => 1,
            'undefDefinedSymbols'   => 1,
            'includeFiles'          => 1,
            'enumerated'            => 1,
            'string'                => 1,
            'stringList'            => 1
          }
          Core.assert(superclass.is_a?(String) && !superclass.empty?) do
            'param must be non empty string'
          end
          Core.assert(valtype.is_a?(String) && !valtype.empty?) do
            'param must be non empty string'
          end
          # prevent typo, check the 'valtype' against list of valid/supported types
          Core.assert(allowed.key?(valtype)) do
            "type '#{valtype}' is not valid"
          end
          # convert 'superclass' to current 'variant' type
          superclass = xpath_variant(superclass)
          # try to find superclass '<option>' node
          option_node = @xml.at_xpath(
            "//cproject/storageModule/cconfiguration/storageModule/configuration/folderInfo/toolChain/tool[\@name=\"Assembly\"]/option[\@superClass=\"#{superclass}\"]"
          )

          # if not present, create new one
          if option_node.nil?
            option_node = create_option_node(
              get_assembler_node(target, used: used), superclass, valtype
            )
          end
          return option_node
        end

        def set_assembler_option(target, superclass, valtype, value, used: nil)
          option_node = create_assembler_option(target, superclass, valtype, used: used)
          option_node['value'] = value.to_s
        end

        def get_linker_node(target, used: nil)
          xpath = xpath_variant(
            "storageModule/configuration/folderInfo/toolChain/tool[\@superClass = \"ilg.gnuarmeclipse.managedbuild.cross.tool.c.linker\"]"
          )
          parent_node = target_node(target, used: used).at_xpath(xpath)
          Core.assert(!parent_node.nil?)
          return parent_node
        end

        def get_cpp_linker_node(target, used: nil)
          xpath = xpath_variant(
            "storageModule/configuration/folderInfo/toolChain/tool[\@superClass = \"ilg.gnuarmeclipse.managedbuild.cross.tool.cpp.linker\"]"
          )
          parent_node = target_node(target, used: used).at_xpath(xpath)
          Core.assert(!parent_node.nil?)
          return parent_node
        end

        def create_linker_option(target, superclass, valtype, used: nil)
          allowed = {
            'boolean' => 1,
            'userObjs'              => 1,
            'stringList'            => 1,
            'enumerated'            => 1,
            'libs'                  => 1,
            'libPaths'              => 1,
            'string'                => 1
          }
          # , 'enumerated' => 1, 'string' => 1, 'stringList' => 1}
          Core.assert(superclass.is_a?(String) && !superclass.empty?) do
            'param must be non empty string'
          end
          Core.assert(valtype.is_a?(String) && !valtype.empty?) do
            'param must be non empty string'
          end
          # prevent typo, check the 'valtype' against list of valid/supported types
          Core.assert(allowed.key?(valtype)) do
            "type '#{valtype}' is not valid"
          end
          # convert 'superclass' to current 'variant' type
          superclass = xpath_variant(superclass)
          # try to find superclass '<option>' node
          option_node = target_node(target, used: used).at_xpath(
            "storageModule/configuration/folderInfo/toolChain/tool/option[\@superClass = \"#{superclass}\"]"
          )
          # if not present, create new one
          if option_node.nil?
            option_node = create_option_node(
              get_linker_node(target, used: used), superclass, valtype
            )
          end
          return option_node
        end

        def create_cpp_linker_option(target, superclass, valtype, used: nil)
          allowed = {
            'boolean' => 1,
            'userObjs'              => 1,
            'stringList'            => 1,
            'enumerated'            => 1,
            'libs'                  => 1,
            'libPaths'              => 1,
            'string'                => 1
          }
          # , 'enumerated' => 1, 'string' => 1, 'stringList' => 1}
          Core.assert(superclass.is_a?(String) && !superclass.empty?) do
            'param must be non empty string'
          end
          Core.assert(valtype.is_a?(String) && !valtype.empty?) do
            'param must be non empty string'
          end
          # prevent typo, check the 'valtype' against list of valid/supported types
          Core.assert(allowed.key?(valtype)) do
            "type '#{valtype}' is not valid"
          end
          # convert 'superclass' to current 'variant' type
          superclass = xpath_variant(superclass)
          # try to find superclass '<option>' node
          option_node = target_node(target, used: used).at_xpath(
            "storageModule/configuration/folderInfo/toolChain/tool/option[\@superClass = \"#{superclass}\"]"
          )
          # if not present, create new one
          if option_node.nil?
            option_node = create_option_node(
              get_cpp_linker_node(target, used: used), superclass, valtype
            )
          end
          return option_node
        end

        def set_linker_option(target, superclass, valtype, value, used: nil)
          option_node = create_linker_option(target, superclass, valtype, used: used)
          option_node['value'] = value.to_s
        end

        def set_cpp_linker_option(target, superclass, valtype, value, used: nil)
          option_node = create_cpp_linker_option(target, superclass, valtype, used: used)
          option_node['value'] = value.to_s
        end

        def get_archiver_node(target, used: nil)
          xpath = xpath_variant(
            "storageModule/configuration/folderInfo/toolChain/tool[\@superClass = \"ilg.gnuarmeclipse.managedbuild.cross.tool.archiver\"]"
          )
          parent_node = target_node(target, used: used).at_xpath(xpath)
          Core.assert(!parent_node.nil?)
          return parent_node
        end

        def create_archiver_option(target, superclass, valtype, used: nil)
          allowed = { 'string' => 1, 'userObjs' => 1 }
          Core.assert(superclass.is_a?(String) && !superclass.empty?) do
            'param must be non empty string'
          end
          Core.assert(valtype.is_a?(String) && !valtype.empty?) do
            'param must be non empty string'
          end
          # prevent typo, check the 'valtype' against list of valid/supported types
          Core.assert(allowed.key?(valtype)) do
            "type '#{valtype}' is not valid"
          end
          # convert 'superclass' to current 'variant' type
          superclass = xpath_variant(superclass)
          # try to find superclass '<option>' node
          option_node = target_node(target, used: used).at_xpath(
            "storageModule/configuration/folderInfo/toolChain/tool/option[\@superClass = \"#{superclass}\"]"
          )
          # if not present, create new one
          if option_node.nil?
            option_node = create_option_node(
              get_archiver_node(target, used: used), superclass, valtype
            )
          end
          return option_node
        end

        def set_archiver_option(target, superclass, valtype, value, used: nil)
          option_node = create_archiver_option(target, superclass, valtype, used: used)
          option_node['value'] = value.to_s
        end

        def get_flash_image_node(target, used: nil)
          xpath = xpath_variant(
            "storageModule/configuration/folderInfo/toolChain/tool[\@superClass = \"ilg.gnuarmeclipse.managedbuild.cross.tool.createflash\"]"
          )
          parent_node = target_node(target, used: used).at_xpath(xpath)
          Core.assert(!parent_node.nil?)
          return parent_node
        end

        def create_flash_image_option(target, superclass, valtype, used: nil)
          superclass = xpath_variant(superclass)
          option_node = target_node(target, used: used).at_xpath(
            "storageModule/configuration/folderInfo/toolChain/tool/option[\@superClass = \"#{superclass}\"]"
          )
          if option_node.nil?
            option_node = create_option_node(
              get_flash_image_node(target, used: used), superclass, valtype
            )
          end
          return option_node
        end

        def set_flash_image_option(target, superclass, valtype, value, used: nil)
          option_node = create_flash_image_option(target, superclass, valtype, used: used)
          option_node['value'] = value.to_s
        end

        def get_general_node(target, used: nil)
          xpath = "storageModule/configuration/folderInfo/toolChain[contains(\@superClass,'ilg.gnuarmeclipse.managedbuild.cross.toolchain')]"
          parent_node = target_node(target, used: used).at_xpath(xpath)
          Core.assert(!parent_node.nil?)
          return parent_node
        end

        def create_general_option(target, superclass, valtype, used: nil)
          allowed = {
            'string' => 1,
            'enumerated'            => 1,
            'boolean'               => 1
          }
          Core.assert(superclass.is_a?(String) && !superclass.empty?) do
            'param must be non empty string'
          end
          Core.assert(valtype.is_a?(String) && !valtype.empty?) do
            'param must be non empty string'
          end
          # prevent typo, check the 'valtype' against list of valid/supported types
          Core.assert(allowed.key?(valtype)) do
            "type '#{valtype}' is not valid"
          end
          # convert 'superclass' to current 'variant' type
          superclass = xpath_variant(superclass)
          # try to find superclass '<option>' node
          option_node = target_node(target, used: used).at_xpath(
            "storageModule/configuration/folderInfo/toolChain/option[\@superClass = \"#{superclass}\"]"
          )
          # if not present, create new one
          if option_node.nil?
            option_node = create_option_node(
              get_general_node(target, used: used), superclass, valtype
            )
          end
          return option_node
        end

        def set_general_option(target, superclass, valtype, value, used: nil)
          option_node = create_general_option(target, superclass, valtype, used: used)
          option_node['value'] = value.to_s
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

        def clear_include!(*_args, used: false, **_kargs)
          # include path is target-unspecific
          target = nil
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
