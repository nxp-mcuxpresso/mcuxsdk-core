# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/mcux/_project'
require_relative 'files/mcux_project_definition_xml'
require_relative '../../internal/_lib_project_interface'
require_relative '../common/project'

module Mcux
  module Lib

    class UProject < Internal::Mcux::UProject
      # consuming interface
      include Internal::LibProjectInterface
      include Mcux::CommonProject

      def initialize(param)
        super(param)
        template = @templates.first_by_regex(/mcux_template.xml$/)
        @project_file = ProjectDefinitionXml.new(template, param[:manifest_version], param[:manifest_schema_dir])
      end

      # Save project
      def save(output_dir)
        Core.assert(output_dir.is_a?(String)) do
          "output dir is not a string '#{output_dir}'"
        end
        @logger.debug("generate project: #{@name}")

        project_definition_xml_name = @name + '.xml'
        path = File.join(output_dir, project_definition_xml_name)
        @project_file.save(path)
      end

      # Get list of all available targets
      def targets
        return ["debug"]
      end

      # Add assembler 'name' macro of 'value' to target
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def add_assembler_macro(target, name, value)
        @project_file.add_assembler_macro(target, name, value)
      end

      def clear!()
        targets.each do |target|
          clear_compiler_macros!(target)
          clear_assembler_macros!(target)
        end
      end
    end

  end
end
