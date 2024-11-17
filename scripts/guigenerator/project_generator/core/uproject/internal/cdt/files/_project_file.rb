# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'nokogiri'
require_relative '../../../../../../utils/_assert'
require_relative '../../_xml_utils'
require 'logger'

module Internal
module Cdt


    # Class to manipulate structure of eclipse .cproject file
    class ProjectFile

        attr_reader :xml
        attr_reader :logger
        attr_reader :vdir_table

        def initialize(template, logger: nil)
            Core.assert(template.is_a?(String) && !template.empty?) do
                "param must be non-empty string"
            end
            Core.assert(File.exist?(template)) do
                "file does not exist '#{template}'"
            end
            @xml        = XmlUtils.load(template)
            @logger     = logger ? logger : Logger.new(STDOUT)
            @vdir_table = {}
        end

        def project_parent_path(path)
            Core.assert(path.is_a?(String)) do
                "param is not a string"
            end
            result = /^(\.\.\/)+/.match(path)
            return path unless ($&)
            dots    = "#{$&}"
            parts   = "#{$&}".split('/')
            path = path.sub(dots, "PARENT-#{parts.length}-PROJECT_LOC/")
            return path
        end

        private

        # Save xml document to file
        # ==== arguments
        # path      - output file
        def save(path)
            Core.assert(path.is_a?(String) && !path.empty?) do
                "param must be non-empty string"
            end
            @logger.info("generate file: #{path}")
            XmlUtils.save(@xml, path)
        end

        # Add new Eclipse variable
        # ==== arguments
        # name      - variable name
        # value     - value of variable
        def add_variable(name, value)
            Core.assert(name.is_a?(String) && !name.empty?) do
                "param name must be non-empty string"
            end
            Core.assert(name.is_a?(String)) do
                "param name must be string"
            end
            list_node = variableListNode
        # add '<variable>' subnode
            var_node = Nokogiri::XML::Node.new("variable", @xml)
            list_node << var_node
        # add '<name>' subnode
            name_node = Nokogiri::XML::Node.new("name", @xml)
            name_node.content = name
            var_node << name_node
        # add '<value>' subnode
            value_node = Nokogiri::XML::Node.new("value", @xml)
            value_node.content = value
            var_node << value_node
        end

        # Clear all Eclipse variables
        def clear_variables!()
            collection = variableListNode.at_xpath("./*")
            collection.remove() unless(collection.nil?)
        end

        # Setup the name of project. Calling this method is mandatory.
        # ==== arguments
        # name      - name of project
        def projectname(name)
            list_node = @xml.at_xpath("/projectDescription/name")
            Core.assert(!list_node.nil?) do
                "node does not exists"
            end
            list_node.content = name
        end

        # Create directory by 'vdirexpr' expression.
        # ==== arguments
        # vdirexpr  - colon separated path f.i 'my:subdir:subsubdir'
        def create_vdir(vdirexpr)
        # check whether node already exists if not, create new one
            vdirexpr = vdirexpr_to_slashes(vdirexpr)
            vdir_node = @vdir_table[ vdirexpr ]
            return unless (vdir_node.nil?)
        # create 'link' node
            vdir_node = Nokogiri::XML::Node.new("link", @xml)
            linkedResourcesNode << vdir_node
        # create 'name' subnode
            node = Nokogiri::XML::Node.new("name", @xml)
            node.content = vdirexpr
            vdir_node << node
        # create 'type' subnode
            node = Nokogiri::XML::Node.new("type", @xml)
            node.content = 2
            vdir_node << node
        # create 'locationURI' subnode
            node = Nokogiri::XML::Node.new("locationURI", @xml)
            node.content = 'virtual:/virtual'
            vdir_node << node
        end

        # Add new source file to project in 'vdirexpr' directory
        # ==== arguments
        # path      - source file path
        # vdirexpr  - virtual directory expression, f.i 'my:subdir:subsubdir'
        def add_source(path, vdirexpr)
            if vdirexpr.nil?
               vdirexpr = 'src'
            end
            vdirexpr = vdirexpr_to_slashes(vdirexpr)
            create_vdir(vdirexpr)
        # create link node
            link_node = Nokogiri::XML::Node.new("link", @xml)
            linkedResourcesNode << link_node
        # 'name' node
            node = Nokogiri::XML::Node.new("name", @xml)
            node.content = File.join(vdirexpr, File.basename(path))
            link_node << node
        # 'type' node
            node = Nokogiri::XML::Node.new("type", @xml)
            node.content = 1
            link_node << node
        # 'locationURI' node
            node = Nokogiri::XML::Node.new("locationURI", @xml)
            node.content = path
            link_node << node
        end

        # clear all existing source files
        def clear_sources!()
            collection = linkedResourcesNode.at_xpath("./*")
            collection.remove() unless (collection.nil?)
        end

        private

        # Get '<projectDescription>' node
        def projectDescriptionNode
            return @projectDescription unless (@projectDescription.nil?)
            @projectDescription = @xml.at_xpath('/projectDescription')
            Core.assert(!@projectDescription.nil?) do
                "no projectDescription"
            end
            return @projectDescription
        end

        # Return '<linkedResources>' node. If not exists, create one.
        def linkedResourcesNode
            return @linkedResources unless (@linkedResources_node.nil?)
            @linkedResources = @xml.at_xpath('/projectDescription/linkedResources')
            if (@linkedResources.nil?)
                @linkedResources = Nokogiri::XML::Node.new("linkedResources", @xml)
                projectDescriptionNode << @linkedResources
            end
            return @linkedResources
        end

        # Return '<variableList>' node. If not exists, create one.
        def variableListNode
            return @variableList unless (@variableList.nil?)
            @variableList = @xml.at_xpath("/projectDescription/variableList")
            if (@variableList.nil?)
                @variableList = Nokogiri::XML::Node.new("variableList", @xml)
                projectDescriptionNode << @variableList
            end
            return @variableList
        end

        # convert vdirexpr to slash format because 
        # eclipse uses this values as filesystem path
        # 1) replace colon with slash
        # 2) replace spaces with underscore
        # to avoid problems with paths in CDT plugin
        def vdirexpr_to_slashes(vdirexpr)
            vdirexpr = vdirexpr.gsub(':', '/')
            vdirexpr = vdirexpr.gsub(' ', '_')
            return vdirexpr
        end

    end


end
end
