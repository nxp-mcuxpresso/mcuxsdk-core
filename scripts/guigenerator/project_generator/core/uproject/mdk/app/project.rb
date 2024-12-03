# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
# frozen_string_literal: true

require_relative '../../internal/mdk/_project'
require_relative 'files/uvmpw_file'
require_relative 'files/uvprojx_file'
require_relative 'files/uvoptx_file'
require_relative '../../internal/_app_project_interface'
require_relative '../../internal/_xml_utils'
require_relative '../common/project'
module Mdk
  module App
    class UProject < Internal::Mdk::UProject
      # consuming interface
      include Internal::AppProjectInterface
      include Mdk::CommonProject
      attr_reader :uvprojx_file
      attr_reader :ini_files
      attr_reader :uvoptx_files
      attr_reader :uvprojx_template
      attr_reader :uvoptx_template

      def initialize(param)
        super(param)
        # .uvprojx
        @uvprojx_template = @templates.first_by_regex(/\.uvprojx$/)
        Core.assert(!@uvprojx_template.nil?) do
          "no '.uvprojx' file in templates"
        end
        @uvmpw_file = UvmpwFile.new
        @uvprojx_file = UvprojxFile.new(@uvprojx_template, logger: @logger)
        # setup new target name - otherwise project cannot be used in workspace
        @uvprojx_file.targets.each do |target|
          target_name = target.split(' ').map(&:downcase).join(' ')
          @uvprojx_file.project_name(target, "#{@name} #{target_name}")
        end

        @ini_files = []
        @templates.all_by_regex(/\.ini$/).each do |file|
          @ini_files.push(file)
        end
        # save .JLinkScript file
        @jlinkScript = []
        @templates.all_by_regex(/\.JLinkScript$/).each do |file|
          @jlinkScript.push(file)
        end

        @uvoptx_files = []
        @uvoptx_template = []
        @templates.all_by_regex(/\.uvoptx$/).each do |file|
          uvoptx_file = UvoptxFile.new(file, logger: @logger)
          # setup new target name
          uvoptx_file.targets.each do |target|
            target_name = target.split(' ').map(&:downcase).join(' ')
            uvoptx_file.project_name(target, "#{@name} #{target_name}")
          end
          @uvoptx_files.push(uvoptx_file)
          @uvoptx_template.push file
        end
        @all_target = {}
        @application_target = []
        # save option of load application at startup
        @application_check = {}
      end

      def add_initialization_file(target, path)
        @uvoptx_files&.each { |file| file.debugTab.add_initialization_file(target, path) }
      end

      def set_load_application(target, result)
        @uvoptx_files&.each { |file| file.debugTab.set_load_application(target, result) }
      end

      def set_periodic_update(target, result)
        @uvoptx_files&.each { |file| file.debugTab.set_periodic_update(target, result) }
      end

      # add assembler 'name' macro of 'value' to target
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def add_assembler_macro(target, name, value, *_args, **_kwargs)
        if value.nil?
          @uvprojx_file.assemblerTab.add_define(target, name.to_s)
        else
          @uvprojx_file.assemblerTab.add_define(target, "#{name}=#{value}")
        end
      end

      def clear!
        clear_sources!
        clear_flashDriver!
        targets.each do |target|
          clear_assembler_include!(target)
          clear_compiler_include!(target)
          clear_compiler_macros!(target)
          clear_assembler_macros!(target)
          clear_libraries!(target)
        end
      end

      # save project
      def save(output_dir, targets, shared_projects_info, using_shared_workspace, shared_workspace, *_args)
        Core.assert(output_dir.is_a?(String)) do
          "output dir is not a string '#{output_dir}'"
        end
        @logger.debug("generate project: #{@name}")
        generated_files = []
        # save .uvprojx file
        path = File.join(output_dir, "#{@name}.uvprojx")
        @uvprojx_file.save(path)
        generated_files.push_uniq path
        # delete temp file of template
        File.delete(@uvprojx_template) if File.exist? @uvprojx_template

        @generated_hook.notify(path)

        # save .ini files for default debuger settings
        @ini_files&.each do |ini|
          path = File.join(output_dir, File.basename(ini))
          FileUtils.mkdir_p(output_dir) unless File.directory?(output_dir)
          FileUtils.cp ini, path
          @generated_hook.notify(path)
          generated_files.push_uniq path
        end

        # save .JLinkScript files for default debuger settings
        @jlinkScript&.each do |script|
          path = File.join(output_dir, File.basename(script))
          FileUtils.mkdir_p(output_dir) unless File.directory?(output_dir)
          FileUtils.cp script, path
          @generated_hook.notify(path)
          generated_files.push_uniq path
        end
        targets.each do |each|
          each = each.downcase
        end
        # save .uvprojx file
        @uvoptx_files&.each do |uvoptx|
          path = File.join(output_dir, "#{@name}.uvoptx")
          uvoptx.save path
          @generated_hook.notify(path)
          generated_files.push_uniq path
        end
        # delete temp file of uvoptx template
        @uvoptx_template&.each { |file| File.delete(file) if File.exist? file }

        @uvmpw_file.add_project(@name + '.uvprojx', true)
        # save project .uvmpw
       unless @name == shared_workspace
         path = File.join(output_dir, "#{@name}.uvmpw")
         @uvmpw_file.save(path)
         generated_files.push_uniq path
       end
        # save the additional shared .uvmpw
        if !using_shared_workspace && shared_workspace
          # add other projects to workspace
          shared_projects_info&.each do |project_name, project_path|
            @uvmpw_file.add_project(File.join(File.join(project_path, "#{project_name}.uvprojx")).to_s)
          end
          @uvmpw_file.save(File.join(output_dir, "#{shared_workspace}.uvmpw"))
          generated_files.push_uniq File.join(output_dir, "#{shared_workspace}.uvmpw")
        end
        generated_files
      end

      def add_comfiguration(target, path, optlevel, *_args, **_kwargs)
        project_name = "#{@name} #{target}"
        @uvprojx_file.add_comfiguration(project_name, path, optlevel)
      end

      # empty, do nothing
      # ==== arguments
      # target    - target name
      def add_library(target, library, *_args, **_kwargs)
        @uvprojx_file.linkerTab.add_library(target, library)
      end

      # empty, do nothing
      # ==== arguments
      # target    - target name
      def clear_libraries!(target)
        @uvprojx_file.linkerTab.clear_libraries!(target)
      end

      # empty, do nothing
      # ==== arguments
      # target    - target name
      # path      - linker file path
      def linker_file(target, path, *_args, **_kwargs)
        @uvprojx_file.linkerTab.scatter_file(target, path)
      end

      # -------------------------------------------------------------------------------------
      # Add misc control on source level
      # @param [String] target: the target of flag
      # @param [String] path: the relative path of file
      # @param [String] value: flag
      # @return [Nil]
      def add_misc_flag_for_src(target, path, value, *_args, **_kwargs)
        @uvprojx_file.compilerTab.add_misc_flag_for_src(target, path, value)
        end

      # -------------------------------------------------------------------------------------
      # Add flash programming file
      # @param [String] target: target
      # @param [String] path: file's relative path
      # @return [Nil]
      def add_flash_programming_file(target, path)
        @uvprojx_file.utilitiesTab.configure_flash_program(target, path)
      end

      def update_before_debug(target, value)
        @uvprojx_file.utilitiesTab.update_before_debug(target, value)
      end

  end
  end
end
