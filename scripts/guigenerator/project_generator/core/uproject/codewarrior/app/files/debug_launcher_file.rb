# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'nokogiri'
require 'logger'
require_relative '../../../../../../utils/_assert'
require_relative '../../../internal/_xml_utils'


module CodeWarrior
  module App

    class DebugLauncherFile

      attr_reader :xml
      attr_reader :logger
      attr_reader :target
      attr_reader :debugger
      attr_reader :filename

      def initialize(template, name, target, map, logger: nil)
        @logger     = logger || Logger.new(STDOUT)
        @xml        = Internal::XmlUtils.load(template)
        @debugger   = File.basename(template, '.launch')
        @filename   = name
        @target = target
        @res_uuid_map = map
        @operations = DocumentOperations.new(@xml)
      end

      def save(path)
        Core.assert(path.is_a?(String) && !path.empty?) do
          'param must be non-empty string'
        end
        @logger.debug("generate file: #{path}")
        Internal::XmlUtils.save(@xml, path)
      end

      def set_program_name(name)
        @operations.set_attribute_node('org.eclipse.cdt.launch.PROGRAM_NAME', 'stringAttribute', "build/#{target}/#{name}.elf")
        @operations.set_attribute_node('org.eclipse.cdt.launch.PROJECT_ATTR', 'stringAttribute', name)
        @operations.set_attribute_node('org.eclipse.debug.core.MAPPED_RESOURCE_PATHS', 'listAttribute', "/#{name}")
      end

      def set_debugger_type
        @operations.set_attribute_node('com.freescale.cdt.debug.cw.core.settings.wizardSystemNameHint', 'stringAttribute', @debugger)
      end

      def set_res_uuid
        @res_uuid_map.each do |key, val|
          model = key.split('_')[0..1].join('_')
          debugger_if = key.split('_')[-1]
          if (@filename.downcase.include? model.downcase) && (@filename.downcase.include? debugger_if.downcase)
            @operations.set_attribute_node('com.freescale.cdt.debug.cw.core.settings.rseSystemId', 'stringAttribute', 'com.freescale.cdt.debug.cw.core.ui.rse.systemtype.bareboard.hardware.' + val['RES'])
            @operations.set_attribute_node('com.pemicro.mcu.debug.connections.pne.dsc.UUID', 'stringAttribute', val['UUID'])
            break
          end
        end
      end

      def set_debug_init_file(path)
        @operations.set_attribute_node('com.freescale.cdt.debug.cw.CW_SHADOWED_PREF.Embedded Initialization.initPath', 'stringAttribute', path)
        @operations.set_attribute_node('com.freescale.cdt.debug.cw.initPathList', 'listAttribute', path)
      end

      def set_debug_processor(chipset, chip)
        value = "com.freescale.cw.system.dsc.#{chipset}.#{chip}"
        @operations.set_attribute_node('com.freescale.cdt.debug.cw.CW_SHADOWED_PREF.DSC Debugger.processor', 'stringAttribute', chip)
        @operations.set_attribute_node('com.freescale.cdt.debug.cw.CW_SHADOWED_PREF.Embedded Initialization.systemType', 'stringAttribute', value)
        @operations.clean_attribute_node('com.freescale.cdt.debug.cw.CoreNameList', 'listAttribute')
        @operations.set_attribute_node('com.freescale.cdt.debug.cw.CoreNameList', 'listAttribute', "#{chip}#0")
      end


      def set_memory_config_file(path)
        @operations.set_attribute_node('com.freescale.cdt.debug.cw.CW_SHADOWED_PREF.Embedded Initialization.memConfigPath', 'stringAttribute', path)
        @operations.set_attribute_node('com.freescale.cdt.debug.cw.memConfigPathList', 'listAttribute', path)
      end

      private

      class DocumentOperations

        attr_reader :xml

        def initialize(xml)
          @xml = xml
        end

        def set_attribute_node(keyxpath, attrtype, value)
          valid = %w[booleanAttribute stringAttribute intAttribute listAttribute]
          Core.assert(valid.include?(attrtype)) do
            "invalid type '#{attrtype}' of '#{valid}'"
          end
          if valid == 'booleanAttribute'
            Core.assert(value.is_a?(TrueClass) || value.is_a?(FalseClass)) do
              "not a boolean type '#{value.class.name}'"
            end
            value = attrtype.to_s
          end
          xpath = "launchConfiguration/#{attrtype}[@key = \"#{keyxpath}\"]"
          node = @xml.at_xpath(xpath)
          Core.assert(node) do
            "node '#{xpath}' does not exist"
          end
          if attrtype == 'listAttribute'
            entry_node = Nokogiri::XML::Node.new('listEntry', @xml)
            entry_node['value'] = value
            node << entry_node
          else
            node['value'] = value
          end
        end

        def clean_attribute_node(keyxpath, attrtype)
          xpath = if attrtype == 'listAttribute'
                    "launchConfiguration/#{attrtype}[@key = \"#{keyxpath}\"]/listEntry"
                  else
                    "launchConfiguration/#{attrtype}[@key = \"#{keyxpath}\"]"
                  end
          node = @xml.at_xpath(xpath)
          node&.remove
        end

        def create_option_node(xpath)
          option_node = @xml.at_xpath(xpath)
          if option_node.nil?
            matched = xpath.match(%r{^(.*)/([^/]+)})
            Core.assert(!matched.nil?) do
              "corrupted xpath #{xpath}"
            end
            parent_xpath, node_name = matched.captures
            parent_node = @xml.at_xpath(parent_xpath)
            parent_node = create_option_node(parent_xpath) if parent_node.nil?
            Core.assert(!parent_node.nil?) do
              "not such a node #{parent_xpath}"
            end
            matched = node_name.match(/(\S+)\[(\S+)\]/)
            if matched
              option_node_name, sub_node, sub_node_value = matched.captures
              option_node = Nokogiri::XML::Node.new(option_node_name, @xml)
              # sub_node does not need to add if exists
              unless @xml.at_xpath(parent_xpath + '/' + node_name)
                # add attribute or value
                sub_node&.split(',')&.each do |node_value|
                  node_value.strip!
                  if result = (node_value.match /^@(\S+)=(\S+)/)
                    option_node[result[1]] = result[2].gsub!(/^\"|\"?$/, '')
                  elsif result = (node_value.match /(\S+)=(\S+)/)
                    sub_node = Nokogiri::XML::Node.new(result[1], @xml)
                    sub_node.content = result[2].gsub!(/^\"|\"?$/, '')
                    option_node << sub_node
                  end
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
      end
    end
  end
end
