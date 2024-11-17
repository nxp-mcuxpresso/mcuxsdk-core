# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'nokogiri'
require 'logger'
require_relative '../../../../../../utils/_assert'
require_relative '../../../internal/_xml_utils'


module Xtensa
module App

    class JlinkLauncherFile

        attr_reader :xml
        attr_reader :logger
        attr_reader :target
        attr_reader :debugger

        def initialize(template, logger: nil)
            @logger     = logger ? logger : Logger.new(STDOUT)
            @xml        = Internal::XmlUtils.load(template)
            @debugger   = 'jlink'
            filename    = File.basename(template, File.extname(template))
            # template filename MUST be standardized, last word represent debugger
            # everything else from begining is target name
            # case sensitivity does not matter, all names are coverted to lowercase
            Core.assert(filename =~ /(?i)#{@debugger}$/) do
                return  "invalid filename convention, please use 'Int Flash Debug Jlink', where \n" +
                        "'Int Flash Debug' is targe name, 'Jlink' launcher type"
            end
            # use lowercase standard target name
            @target     = filename.gsub(/(?i)#{@debugger}$/, '').gsub!(' ', '')
            @target.downcase!.strip! if @target.downcase != @target
            # tabs
            @operations = DocumentOperations.new(@xml)
        end

        def save(path)
            Core.assert(path.is_a?(String) && !path.empty?) do
                "param must be non-empty string"
            end
            @logger.debug("generate file: #{path}")
            Internal::XmlUtils::save(@xml, path)
        end

        def set_program_name(name)
            node = @operations.create_option_node("//launchConfiguration/stringAttribute[\@key = \"org.eclipse.cdt.launch.DEBUGGER_REGISTER_GROUPS\"]")
            node['value'] = node['value'].gsub('{project_place_holder}', name)
        end

        private

        class DocumentOperations

            attr_reader :xml

            def initialize(xml)
                @xml = xml
            end

            def set_attribute_node(keyxpath, attrtype, value)
                valid = ['booleanAttribute', 'stringAttribute', 'intAttribute']
                Core.assert(valid.include?(attrtype)) do
                    "invalid type '#{attrtype}' of '#{valid}'"
                end
                if (valid == 'booleanAttribute')
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
                node[ 'value' ] = value
            end

            def create_option_node(xpath)
                option_node = @xml.at_xpath(xpath)
                if option_node.nil?
                    matched = xpath.match(/^(.*)\/([^\/]+)/)
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

        class TabBase
            def initialize(operations)
                @operations = operations
            end
        end

        public

        class Trace < TabBase
            def sync_for_all_cores(value, *args, **kwargs)
                listEntry = @operations.create_option_node("//launchConfiguration/listAttribute[@key = \"targets_list\"]/listEntry")
                listEntry.content = listEntry.content.gsub('sync off', 'sync on') if value ==true
            end
        end

    end

end
end
