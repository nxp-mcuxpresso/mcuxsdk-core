# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/iar/_project'
require_relative '../../internal/_lib_project_interface'
require_relative 'files/ewp_file'
require_relative 'files/eww_file'
require_relative '../common/project'

module Iar
  module Lib
    class UProject < Internal::Iar::UProject
      # consuming interface
      include Internal::LibProjectInterface
      # project function common implementation
      include Iar::CommonProject
      attr_reader :ewp_file
      attr_reader :eww_file

      def initialize(param)
        super(param)
        @ewp_template = @templates.first_by_regex(/\.ewp$/)
        Core.assert(!@ewp_template.nil?) do
          "no '.ewp' file in templates"
        end
        @ewp_file = instance_with_version('Iar::Lib::EwpFile', param[:toolchain_version], @ewp_template, logger: @logger)
        template = @templates.first_by_regex(/\.eww$/)
        @eww_file = template ? instance_with_version('Iar::Lib::EwwFile', param[:toolchain_version], template, logger: @logger) : nil
      end

      def clear!
        clear_sources!
        targets.each do |target|
          clear_assembler_include!(target)
          clear_compiler_include!(target)
          clear_compiler_macros!(target)
          clear_assembler_macros!(target)
        end
      end

      # save project
      def save(output_dir, shared_projects_info, using_shared_workspace, add_shared_workspace, *_args)
        Core.assert(output_dir.is_a?(String)) do
          "output dir is not a string '#{output_dir}'"
        end
        @logger.debug("generate project: #{@name}")
        generated_files = []
        # save ewp file
        path = File.join(output_dir, "#{@name}.ewp")
        @ewp_file.save(path)
        generated_files.push_uniq path
        File.delete(@ewp_template) if File.exist? @ewp_template
        @generated_hook.notify(path)

        # save .eww file
        # not implemented
        unless @eww_file.nil?
          @eww_file.add_project(File.join('$WS_DIR$', "#{@name}.ewp"))
          path = File.join(output_dir, "#{@name}.eww")
          @eww_file.save(path)
          generated_files.push_uniq path
          @generated_hook.notify(path)

          # save additional shared workspace
          if !using_shared_workspace && add_shared_workspace
            # add other projects to workspace
            shared_projects_info&.each do |project_name, project_path|
              @eww_file.add_project(File.join('$WS_DIR$', File.join(project_path, "#{project_name}.ewp")))
            end
            path = File.join(output_dir, "#{add_shared_workspace}.eww")
            @eww_file.save(path)
            @generated_hook.notify(path)
            generated_files.push_uniq path
          end
          generated_files
        end
      end

      # use c++ compiler
      # ==== arguments
      # target    - target name
      # value     - value: compiler string
      def use_cpp_compiler(target, value, *_args, **_kwargs)
        @ewp_file.compilerTab.language1Tab.language(target, value)
      end

      # add compiler include path 'path' to target 'target'
      # ==== arguments
      # target    - target name
      # path      - include path
      def add_compiler_include(target, path, *_args, **_kwargs)
        @ewp_file.compilerTab.preprocessorTab.add_include(target, path)
      end
    end
  end
end
