# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'nokogiri'

# workspace structure is pretty simple so I don't need to use template file
# # # <?xml version="1.0" encoding="UTF-8" standalone="no" ?>
# # # <ProjectWorkspace xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="project_mpw.xsd">
# # #   <SchemaVersion>1.0</SchemaVersion>
# # #   <Header>### uVision Project, (C) Keil Software</Header>
# # #   <WorkspaceName>WorkSpace</WorkspaceName>
# # #   <project>
# # #     <PathAndName>..\..\..\git-repos\scratchgen-mqx\mqx\build\uv4\bsp_twrk60n512\bsp_twrk60n512.uvproj</PathAndName>
# # #   </project>
# # #   <project>
# # #     <PathAndName>..\..\..\git-repos\scratchgen-mqx\mqx\build\uv4\psp_twrk60n512\psp_twrk60n512.uvproj</PathAndName>
# # #     <NodeIsActive>1</NodeIsActive>
# # #   </project>
# # # </ProjectWorkspace>


module Mdk
  module Common

    class UvmpwFile

      attr_reader :xml, :projects

      def initialize()
        # created project storage
        @projects = {}
        # here is the basic template
        template =
            '<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<ProjectWorkspace xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="project_mpw.xsd">
  <SchemaVersion>2.1</SchemaVersion>
  <Header>### uVision Project, (C) Keil Software</Header>
  <WorkspaceName>WorkSpace</WorkspaceName>
</ProjectWorkspace>'
        @xml = Nokogiri::XML(template) { |x| x.noblanks }
      end

      def add_project(project_path, active = false)
        Core.assert(project_path.is_a?(String)) do
          "param is not a string #{project_path.class.name}"
        end
        Core.assert(active.is_a?(TrueClass) || active.is_a?(FalseClass)) do
          "param is not a boolean #{project_path.class.name}"
        end
        Core.assert(@projects[project_path].nil?) do
          "project '#{project_path}' already exists"
        end
        # find <ProjectWorkspace>
        workspace_node = @xml.at_xpath('/ProjectWorkspace')
        # add <project>
        project_node = Nokogiri::XML::Node.new("project", @xml)
        workspace_node << project_node
        # add <PathAndName>
        path_node = Nokogiri::XML::Node.new("PathAndName", @xml)
        path_node.content = project_path
        project_node << path_node
        # add <NodeIsActive>
        active_node = Nokogiri::XML::Node.new("NodeIsActive", @xml)
        active_node.content = active ? '1' : '0'
        project_node << active_node
        # add project into existing lists
        @projects[project_path] = project_node
      end

      def clear_project!(project_path)
        Core.assert(project_path.is_a?(String)) do
          "param is not a string #{project_path.class.name}"
        end
        Core.assert(!@projects[project_path].nil?) do
          "project '#{project_path}' does not exists exists"
        end
        @projects[project_path].remove
        @projects.delete(project_path)
      end

      def schema_version(value)
        Core.assert(value.is_a?(String)) do
          "param is not a string #{value.class.name}"
        end
        # find <SchemaVersion>
        schema_node = @xml.at_xpath('/ProjectWorkspace/SchemaVersion')
        schema_node.content = value
      end

      def header(value)
        Core.assert(value.is_a?(String)) do
          "param is not a string #{value.class.name}"
        end
        # find <Header>
        schema_node = @xml.at_xpath('/ProjectWorkspace/Header')
        schema_node.content = value
      end

      def workspace_name(value)
        Core.assert(value.is_a?(String)) do
          "param is not a string #{value.class.name}"
        end
        # find <WorkspaceName>
        schema_node = @xml.at_xpath('/ProjectWorkspace/WorkspaceName')
        schema_node.content = value
      end

      def save(path)
        Core.assert(path.is_a?(String)) do
          "param is not a string #{path.class.name}"
        end
        File.force_write(path, @xml.to_s)
      end
    end
  end
end

