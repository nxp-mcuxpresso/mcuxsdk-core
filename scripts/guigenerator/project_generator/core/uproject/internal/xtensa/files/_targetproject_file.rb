# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'logger'
require 'nokogiri'

module Internal
  module Xtensa
    class TargetFile
      # attr_reader :xml
      attr_reader :logger
      # attr_reader :operations

      def initialize(template, *_args, logger: nil, **_kwargs)
        @xml    = XmlUtils.load(template)
        @logger = logger || Logger.new(STDOUT)
      end

      private

      def add_source(path, vdirexpr)
        overriddenSettings_node = @operations.create_option_node('OverriddenSettings')
        proj_path = vdirexpr + '/' + File.basename(path)
        if ['.cpp', '.cc', '.cxx'].include?(File.extname(path))
          listEntry_node = Nokogiri::XML::Node.new('OverriddenSettingsEntry', @operations.xml)
          key_node = Nokogiri::XML::Node.new('key', @operations.xml)
          key_node.content = proj_path
          listEntry_node << key_node
          value_node = Nokogiri::XML::Node.new('value', @operations.xml)
          value_node['path'] = proj_path
          listEntry_node << value_node
          overriddenSettings_node << listEntry_node
        end
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

      private

      # Base tab class to inherit @operations attribute
      class TabBase
        attr_reader :operations

        def initialize(operations, *_args, **_kwargs)
          @operations = operations
        end
      end

      class IncludesTab < TabBase
        def initialize(operations)
          super
          @include_path = []
        end
        private

        def add_include(value, *_args, used: true, **_kargs)
          return if @include_path.include? value
          @include_path.push_uniq value
          value_node = @operations.create_option_node('Includes')
          value_node['flag'] = '-I'
          value_node['inheritance'] = 'donotinherit'
          listEntry_node = Nokogiri::XML::Node.new('ListEntry', @operations.xml)
          listEntry_node.content = @operations.convert_string(value)
          value_node << listEntry_node
        end

        def clear_include!(*_args, used: false, **_kargs)
          @include_path.clear
          include_path_node = @operations.create_option_node('Includes')
          collection = include_path_node.xpath('*')
          collection&.remove
        end
      end

      class SymbolsTab < TabBase
        def initialize(operations)
          super(operations)
          @macro_define = []
        end

        def clear_macros!(*_args, **_kargs)
          @macro_define.clear
          include_path_node = @operations.create_option_node('Defines')
          collection = include_path_node.xpath('*')
          collection&.remove
        end

        def add_macros(name, value, *_args, **_kargs)
          return if @macro_define.include? name
          @macro_define.push_uniq name
          value_node = @operations.create_option_node('Defines')
          listEntry_node = Nokogiri::XML::Node.new('ListEntry', @operations.xml)
          listEntry_node['key'] = name
          listEntry_node['value'] = @operations.convert_string(value)
          value_node << listEntry_node
        end
      end

      class OptimizationTab < TabBase
        def initialize(operations)
          super(operations)
        end

        def clear_optimizations!(*_args, **_kargs)
          compiler_option_node = @operations.create_option_node(nil, '/CompilerOptions')
          collection = compiler_option_node.xpath('FlagValueMapOptions/FlagValueMapEntry[key="Optimization"]')
          collection&.remove
        end

        def optimization(flag, level, *_args, used: true, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/FlagValueMapOptions/FlagValueMapEntry[key=\"Optimization\"]/value[\@use=\"true\"]")
          value_node['level'] = level
          value_node['flag'] = flag
        end

        def debug(flag, level, *_args, used: true, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/FlagValueMapOptions/FlagValueMapEntry[key=\"Debug\"]/value[\@use=\"true\"]")
          value_node['level'] = level
          value_node['flag'] = flag
        end

        def keepIntermediateFiles(flag, *_args, used: true, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"KeepIntermediateFiles\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def enableInterproceduralOptimization(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"EnableIPA\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def useDspCoprocessor(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"UseDspCoprocessor\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def notSerializeVolatile(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"NoSerializeVolMemory\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def literals(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"CompilerPlaceLiteralinText\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def useFeedback(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"fb_reorder\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def optomizationForSize(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"OptimizeSpace\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def optomizationAlias(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"OptAliasRestrict\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def autoVectorization(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"EnableSIMD\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def vectorizeWithIfs(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"VectorizeLoopHavingIf\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def paramsAligned(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"Alignedformalpointers\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def connectionBoxOptimization(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"mcbox\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def produceW2cFile(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"clist\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def enableLongCalls(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"CompilerEnableLongCall\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def createSeparateFunc(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"FunctionSections\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end
      end

      class AdvancedOptimizationTab < TabBase
        def initialize(operations)
          super(operations)
        end

        def generateOptimizationFile(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"OptFileGenerate\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def useOptimizationFile(flag, value, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/KeyValueMapOptions/KeyValueMapEntry[key=\"OptFileUse\"]/value[\@use=\"true\"]")
          value_node['key'] = flag
          value_node['value'] = value
        end
      end

      class WarningsTab < TabBase
        def initialize(operations)
          super(operations)
        end

        def warningSettings(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"WarningSetting\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def warningAsErrors(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"WarningAsError\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end
      end

      class LanguageTab < TabBase
        def initialize(operations)
          super(operations)
        end

        def disableGnuExtension(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"DisableGnuExtension\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def signedCharDefault(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"SignCharType\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def enableStrictAnsiWarning(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"EnableStrictAnsiWarning\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def supportCppException(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"SupportCPPException\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def languageDialect(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"ISOStandard\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def languageDialectCpp(flag, *_args, **_kargs)
          listEntryValue_nodes = @operations.xml.xpath('//BuildTarget/BuildSettings/OverriddenSettings/OverriddenSettingsEntry/value')
          listEntryValue_nodes.each do |listEntryValue_node|
            value_node = @operations.create_option_node('OverriddenSettings', "//OverriddenSettingsEntry/value[\@path=\"#{listEntryValue_node['path']}\"]/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"ISOStandard\"]/value[\@use=\"true\"]")
            value_node['flag'] = flag
          end
        end

        def standardCppLibrary(flag, *_args, **_kargs)
          listEntryValue_nodes = @operations.xml.xpath('//BuildTarget/BuildSettings/OverriddenSettings/OverriddenSettingsEntry/value')
          listEntryValue_nodes.each do |listEntryValue_node|
            value_node = @operations.create_option_node('OverriddenSettings', "//OverriddenSettingsEntry/value[\@path=\"#{listEntryValue_node['path']}\"]/CompilerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"UseNewCPlusPlusLib\"]/value[\@use=\"true\"]")
            value_node['flag'] = flag
          end
        end
      end

      class AddlCompilerTab < TabBase
        def initialize(operations)
          super(operations)
        end

        def additionalOptions(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/CompilerOptions/StringListMapOptions/StringListMapEntry[key=\"CompilerAdditionalOptions\"]/value[\@inheritance=\"append\"]")
          listEntry_node = Nokogiri::XML::Node.new('ListEntry', @operations.xml)
          listEntry_node.content = flag
          value_node << listEntry_node
        end
      end

      class AssemblerTab < TabBase
        def initialize(operations)
          super(operations)
        end

        def clear_assembler_flags!(_flag, *_args, **_kargs)
          assembler_option_node = @operations.create_option_node(nil, '/AssemblerOptions')
          collection = assembler_option_node.xpath('*')
          collection&.remove
        end

        def includeDebugInfo(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/AssemblerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"AssemblerIncludeDebug\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def supressWarnings(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/AssemblerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"AssemblerSuppressWarning\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def enableLongCalls(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/AssemblerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"AssemblerLongCall\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def placeLiteralsInText(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/AssemblerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"AssemblerPlaceLiteralsInText\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end
      end

      class AddlAssemblerTab < TabBase
        def initialize(operations)
          super(operations)
        end

        def additionalOptions(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/AssemblerOptions/StringListMapOptions/StringListMapEntry[key=\"AssemblerAdditionalOptions\"]/value[\@inheritance=\"append\"]")
          listEntry_node = Nokogiri::XML::Node.new('ListEntry', @operations.xml)
          listEntry_node.content = flag
          value_node << listEntry_node
        end
      end

      class CompilerOptionsForAssemblerTab < TabBase
        def initialize(operations)
          super(operations)
        end

        def compilerOptions(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/AssemblerOptions/StringListMapOptions/StringListMapEntry[key=\"CompilerOptionsforAssembler\"]/value[\@inheritance=\"append\"]")
          listEntry_node = Nokogiri::XML::Node.new('ListEntry', @operations.xml)
          listEntry_node.content = flag
          value_node << listEntry_node
        end
      end

      class LinkerTab < TabBase
        def initialize(operations)
          super(operations)
        end

        def clear_linker_flags!(*_args, **_kargs)
          linker_option_node = @operations.create_option_node(nil, '/LinkerOptions')
          collection = linker_option_node.xpath('*')
          collection&.remove
        end

        def supportPackage(key, value, custom, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/LinkerSupport[\@custom=#{@operations.convert_boolean(custom)}]")
          value_node['key'] = key
          value_node['value'] = value
        end

        def createMinsize(value, *_args, **_kargs)
          entry_node = @operations.create_option_node(nil, '/LinkerOptions/BooleanMapOptions/BooleanMapEntry[key="CreateMinsize"]')
          value_node = Nokogiri::XML::Node.new('value', @operations.xml)
          value_node['selected'] = @operations.convert_boolean(value)
          entry_node << value_node
        end

        def embedMapInfo(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"EmbedMapInfo\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def generatorMapFile(flag, *_args, **_kargs)
          if flag
            value_node = @operations.create_option_node(nil, "/LinkerOptions/BooleanMapOptions/BooleanMapEntry[key=\"GenerateMapFile\"]/value[\@selected=\"true\"]")
          end
        end

        def omitDebuggerSymbol(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"LinkerOmitDebugSymbolInfo\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def omitAllSymbol(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"LinkerOmitSymbolInfo\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def enableInterproceduralAnalysis(flag, *_args, **_kargs)
          if flag
            value_node = @operations.create_option_node(nil, "/LinkerOptions/BooleanMapOptions/BooleanMapEntry[key=\"LinkWithIPA\"]/value[\@selected=\"true\"]")
          end
        end

        def controlLinkerOrder(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"Reorder\"]/value[\@selected=\"true\"]")
          value_node['flag'] = flag
        end

        def hardware_profile(flag, level, *_args, **_kargs)
          level ||= '-2'
          value_node = @operations.create_option_node(nil, "/LinkerOptions/FlagValueMapOptions/FlagValueMapEntry[key=\"HWProfileTiming\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
          value_node['level'] = level
        end
      end

      class MemoryTab < TabBase
        def initialize(operations)
          super(operations)
        end

        def debugMalloc(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"DebugMalloc\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def ferret(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"Ferret\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def includeLibxmp(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/SingleFlagMapOptions/SingleFlagMapEntry[key=\"LibXmpLibrary\"]/value[\@use=\"true\"]")
          value_node['flag'] = flag
        end

        def enableSharedMalloc(value, *_args, **_kargs)
          entry_node = @operations.create_option_node(nil, '/LinkerOptions/BooleanMapOptions/BooleanMapEntry[key="EnableSharedMPMalloc"]')
          value_node = Nokogiri::XML::Node.new('value', @operations.xml)
          value_node['selected'] = @operations.convert_boolean(value)
          entry_node << value_node
        end
      end

      class LibrariesTab < TabBase
        def initialize(operations)
          super(operations)
        end

        def libSearchPath(flag, path, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/StringListMapOptions/StringListMapEntry[key=\"LibrarySearchPath\"]/value[\@inheritance=\"prepend\"]")
          value_node['flag'] = flag
          listEntry_node = Nokogiri::XML::Node.new('ListEntry', @operations.xml)
          listEntry_node.content = path
          value_node << listEntry_node
        end

        def libraries(flag, path, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/StringListMapOptions/StringListMapEntry[key=\"Libraries\"]/value[\@inheritance=\"prepend\"]")
          value_node['flag'] = flag
          listEntry_node = Nokogiri::XML::Node.new('ListEntry', @operations.xml)
          listEntry_node.content = path
          value_node << listEntry_node
        end
      end

      class AddlLinkerTab < TabBase
        def initialize(operations)
          @linked_libs = []
          super(operations)
        end

        def add_additionalOptions(flag)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/StringListMapOptions/StringListMapEntry[key=\"LinkerAdditionalOptions\"]/value[\@inheritance=\"append\"]")
          listEntry_node = if value_node.at_xpath('ListEntry').nil?
                                Nokogiri::XML::Node.new('ListEntry', @operations.xml)
                              else
                                value_node.at_xpath('ListEntry')
                              end
          listEntry_node.content += flag if (!listEntry_node.content.nil?) && (!listEntry_node.content.to_s.include? flag)
          value_node << listEntry_node
        end

        def additionalOptions(flag, *_args, **_kargs)
          add_additionalOptions(flag)
        end

        def add_library(flag, *_args, **_kargs)
          @linked_libs.push_uniq flag
        end

        def save_library
          add_additionalOptions("-Wl,--start-group\r\n" + @linked_libs.join('') + "-Wl,--end-group\r\n") unless @linked_libs.empty?
        end

        def compilerOptionsForLinker(flag, *_args, **_kargs)
          value_node = @operations.create_option_node(nil, "/LinkerOptions/StringListMapOptions/StringListMapEntry[key=\"CompilerOptionsForLinker\"]/value[\@inheritance=\"append\"]")
          listEntry_node = Nokogiri::XML::Node.new('ListEntry', @operations.xml)
          listEntry_node.content = flag
          value_node << listEntry_node
        end
      end

      class DocumentOperations
        attr_reader :xml
        attr_reader :targets

        def initialize(xml, *_args, logger: nil, **_kwargs)
          @xml            = xml
          @logger         = logger
        end

        def create_option_node(type, path = nil)
          baseSettings =  type == 'OverriddenSettings' ? '//BuildTarget/BuildSettings/OverriddenSettings' : '//BuildTarget/BuildSettings/BaseSettings'
          case type
          when 'Includes'
            xpath = baseSettings + "/PreprocessorOptions/StringListMapOptions/StringListMapEntry[key=\"#{type}\"]/value[\@flag=\"-I\"]"
          when 'Defines'
            xpath = baseSettings + "/PreprocessorOptions/KeyValueListMapOptions/KeyValueListMapEntry[key=\"#{type}\"]/value[\@flag=\"-D\"]"
          else
            xpath = baseSettings + (path || '')
          end
          include_path_node = @xml.at_xpath(xpath)
          include_path_node = _create_option_node(xpath) if include_path_node.nil?
          return include_path_node
        end

        # -----------------------------------------------------------------
        # Create new node recursively if node does not exist
        # @param [String] xpath: xpath expression
        # @return [Nokogiri::XML::Element]: the created node of the xpath
        def _create_option_node(xpath)
          option_node = @xml.at_xpath(xpath)
          if option_node.nil?
            matched = xpath.match(/^(.*)\/([^\/]+)/)
            Core.assert(!matched.nil?) do
              "corrupted xpath #{xpath}"
            end
            parent_xpath, node_name = matched.captures
            parent_node = @xml.at_xpath(parent_xpath)
            parent_node = _create_option_node(parent_xpath) if parent_node.nil?
            Core.assert(!parent_node.nil?) do
              "not such a node #{parent_xpath}"
            end
            matched = node_name.match(/(\S+)\[(\S+)\]/)
            if matched
              option_node_name, sub_node = matched.captures
              option_node = Nokogiri::XML::Node.new(option_node_name, @xml)
              # sub_node does not need to add if exists
              unless @xml.at_xpath(parent_xpath + '/' + node_name)
                # add attribute or value
                sub_node.strip!
                if result = (sub_node.match /^@(\S+)=(\S+)/)
                  option_node[result[1]] = result[2].gsub!(/^\"|\"?$/, '')
                elsif result = (sub_node.match /(\S+)=(\S+)/)
                  node = Nokogiri::XML::Node.new(result[1], @xml)
                  node.content = result[2].gsub!(/^\"|\"?$/, '')
                  option_node << node
                end
              end
            else
              option_node = Nokogiri::XML::Node.new(node_name, @xml)
            end
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
          Core.assert(convert.key?(value)) do
            "conversion error, value '#{value}' does not exists in enum '#{convert.keys.join(', ')}'"
          end
          return convert[value]
        end

        def convert_boolean(value)
          Core.assert(value.is_a?(TrueClass) || value.is_a?(FalseClass)) do
            "conversion error, value '#{value}' must be a 'true' or 'false'"
          end
          return value ? 'true' : 'false'
        end
      end
    end
  end
end
