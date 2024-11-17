# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
# frozen_string_literal: true

require_relative '../../_xml_utils'
require_relative '../../../../../../utils/_assert'
require 'nokogiri'
require 'logger'
require_relative '../../../../_file'

module Internal
  module Iar
    # Common class to manipulate with .ewp xml file
    # Subclasses and methods respond to GUI elements
    # Code/method inspection is pretty usefull
    class EwwFile
      attr_reader :xml

      private

      def initialize(template, logger: nil)
        @xml = XmlUtils.load(template)
        @xml.css('/workspace').children.each(&:remove)
        @logger = logger ? logger : Logger.new(STDOUT)
        @projects = {}
      end

      # Save file
      # ==== arguments
      # path      - string, file path to save
      def save(path)
        Core.assert(path.is_a?(String) && !path.empty?) do
          "param must be non-empty string #{path.class.name}"
        end
        @logger.debug("generate file: #{path}")
        XmlUtils.save(@xml, path)
      end

      def add_batch_project_target(batchname, project, target)
        definition_node = @xml.at_xpath("/workspace/batchBuild/batchDefinition[name[text()='#{batchname}']]")
        unless definition_node
          build_node = @xml.at_xpath('/workspace/batchBuild')
          unless build_node
            workspace_node = @xml.at_xpath('/workspace')
            Core.assert(workspace_node, 'no <workspace> present')
            # <batchBuild>
            build_node = Nokogiri::XML::Node.new('batchBuild', @xml)
            workspace_node << build_node
          end
          # <batchDefinition>
          definition_node = Nokogiri::XML::Node.new('batchDefinition', @xml)
          build_node << definition_node
          # <name>
          name_node = Nokogiri::XML::Node.new('name', @xml)
          name_node.content = batchname
          definition_node << name_node
        end
        # <member>
        member_node = Nokogiri::XML::Node.new('member', @xml)
        definition_node << member_node
        # <project>
        project_node = Nokogiri::XML::Node.new('project', @xml)
        project_node.content = project
        member_node << project_node
        # <configuration>
        configuration_node = Nokogiri::XML::Node.new('configuration', @xml)
        configuration_node.content = target
        member_node << configuration_node
      end

      def add_project(project_path)
        Core.assert(project_path.is_a?(String)) do
          "param is not a string #{project_path.class.name}"
        end
        Core.assert(@projects[project_path].nil?) do
          "project '#{project_path}' already exists"
        end
        # find <ProjectWorkspace>
        workspace_node = @xml.at_xpath('/workspace')
        # add <project>
        project_node = Nokogiri::XML::Node.new('project', @xml)
        workspace_node << project_node
        # add <PathAndName>
        path_node = Nokogiri::XML::Node.new('path', @xml)
        path_node.content = project_path
        project_node << path_node
        # add project into existing lists
        @projects[project_path] = project_node
      end
    end
  end
end
