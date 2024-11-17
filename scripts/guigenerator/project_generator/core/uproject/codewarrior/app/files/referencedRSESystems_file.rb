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

    class ReferencedRSESystems

      attr_reader :xml
      attr_reader :logger
      attr_reader :target
      attr_reader :debugger
      attr_reader :filename

      def initialize(template, targets, debug_files, map, logger: nil)
        @logger     = logger || Logger.new(STDOUT)
        @xml        = Internal::XmlUtils.load(template)
        @targets = targets
        @res_uuid_map = map
        @operations = DocumentOperations.new(@xml, targets, debug_files)
      end

      def save(path)
        Core.assert(path.is_a?(String) && !path.empty?) do
          'param must be non-empty string'
        end
        xml_template = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' \
              '<APSC_Memento>' \
              '</APSC_Memento>'
        tep_xml = Nokogiri.XML(xml_template)
        @operations.hosts.each do |key, nodes|
          host_nodes = nodes.xpath('/APSC_Memento')
          host_nodes.children.each do | node|
            tep_xml.at_xpath('/APSC_Memento') << node
          end
        end
        @logger.debug("generate file: #{path}")
        Internal::XmlUtils.save(tep_xml, path)
      end

      def update_node(project_name)
        @operations.update_res_uuid(project_name, @res_uuid_map)
      end

      def set_debug_init_file(target, path)
        @operations.hosts.each do |key, nodes|
          if key.include? target
            @operations.set_attribute_node(nodes, "propertySet.[cw.dbg.ct.bareboard].initPath", 'property', path)
          end
        end
      end

      def set_debug_systemType(target, chipset, chip)
        value = "com.freescale.cw.system.dsc.#{chipset}.#{chip}"
        @operations.hosts.each do |key, nodes|
          if key.include? target
            @operations.set_attribute_node(nodes, "propertySet.[cw.dbg.main].systemType", 'property', value)
          end
        end
      end

      def set_memory_config_file(target, path)
        @operations.hosts.each do |key, nodes|
          if key.include? target
            @operations.set_attribute_node(nodes, "propertySet.[cw.dbg.ct.bareboard].memConfigPath", 'property', path)
          end
        end
      end


      private

      class DocumentOperations

        attr_reader :xml
        attr_reader :hosts

        def initialize(xml, targets, debug_files)
          @xml = xml
          @hosts = {}
          # loop over targets
          #hosts_node = @xml.xpath('/APSC_Memento')
          targets.each do |target|
            debug_files.each do |debug_file|
              key = target + ':' + debug_file
              #clone_hosts_node = hosts_node.dup
              hosts[key] = @xml.dup
            end
          end
        end

        def update_res_uuid(project_name, map)
          hosts.each do |key, nodes|
            host_nodes = nodes.xpath('/APSC_Memento')
            host_nodes.children.each do |host_node|
              node = host_node.at_xpath('properties/property')
              Core.assert(!node.nil?) do
                'no host node!'
              end
              debug_if = key.split(':')[-1]
              target =  key.split(':')[0]
              uuid_res_map = {}
              map_key = target.upcase + '_' + debug_if.upcase
              map.each do |k, v|
                model = k.split('_')[0..1].join('_')
                dbg = k.split('_')[-1]
                if dbg.downcase.include?(debug_if.downcase) && target.downcase.include?(model.downcase)
                  uuid_res_map = v
                  break
                end
              end
              update_node_id_recursively(host_node, project_name, target, debug_if, uuid_res_map)
            end
          end
        end

        def update_node_id_recursively(node, name, target, debug_if, map)
          return if node.nil?
          update_placeholder(node, 'key', name, target, debug_if, map) unless node['key'].nil?
          update_placeholder(node, 'value', name, target, debug_if, map) unless node['value'].nil?
          node.element_children.each do |element|
            update_node_id_recursively(element, name, target, debug_if, map)
          end
        end

        def update_placeholder(node, key, name, target, debug_if, map)
          if node[key].include? '${project}'
            node[key] = node[key].gsub('${project}', name)
          end
          if node[key].include? '${target}'
            node[key] = node[key].gsub('${target}', target)
          end
          if node[key].include? '${debug_interface}'
            node[key] = node[key].gsub('${debug_interface}', debug_if)
          end
          if node[key].include?('${uuid}') && map['UUID']
            node[key] = node[key].gsub('${uuid}', map['UUID'])
          end
          if node[key].include?('${res}') && map['RES']
            node[key] = node[key].gsub('${res}', map['RES'])
          end
        end

        def set_attribute_node(node, keyxpath, attrtype, value)
          valid = %w[property]
          Core.assert(valid.include?(attrtype)) do
            "invalid type '#{attrtype}' of '#{valid}'"
          end
          xpath = "APSC_Memento/host/properties/#{attrtype}[@key = \"#{keyxpath}\"]"
          node = node.at_xpath(xpath)
          Core.assert(node) do
            "node '#{xpath}' does not exist"
          end
          node['value'] = value
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
