# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/xtensa/_project'
require_relative './files/project_file'
require_relative './files/cproject_file'
require_relative './files/xxproject_file'
require_relative './files/jlink_launcher_file'
require_relative './files/target_file'
require_relative './files/makefileInclude_file'
require_relative '../../internal/_app_project_interface'

module Xtensa
  module App
    class UProject < Internal::Xtensa::UProject
      # consuming interface
      include Internal::AppProjectInterface

      attr_reader :project_file
      attr_reader :cproject_file
      attr_reader :xxproject_file
      attr_reader :targetproject_files
      attr_reader :jlink_launcher_files
      attr_reader :makefileInclude_file

      def initialize(param)
        super(param)
        # .project
        template = @templates.first_by_regex(/\.project$/)
        Core.assert(!template.nil?) do
          "no '.project' file in templates"
        end
        @project_file = ProjectFile.new(template, logger: @logger)
        # .cproject
        template = @templates.first_by_regex(/\.cproject$/)
        Core.assert(!template.nil?) do
          "no '.cproject' file in templates"
        end
        @cproject_file = CprojectFile.new(template, logger: @logger)
        # .xxproject
        template = @templates.first_by_regex(/\.xxproject$/)
        Core.assert(!template.nil?) do
          "no '.xxproject' file in templates"
        end
        @xxproject_file = XXprojectFile.new(template, logger: @logger)
        # targets.bts
        @targetproject_files = {}
        template = @templates.first_by_regex(/\.bts$/)
        param[:targets]&.each do |target|
          @targetproject_files[target] = TargetFile.new(template, logger: @logger)
        end

        # Makefile.include
        template = @templates.first_by_regex(/\.include$/)
        @makefileInclude_file = MakefileIncludeFile.new(template, logger: @logger) if template

        # com.tensilica.xide.cdt.prefs
        template = @templates.first_by_regex(/\.cdt\.prefs$/)
        @xidePrefs_file = MakefileIncludeFile.new(template, logger: @logger) if template

        # jlink.launchers
        @jlink_launcher_files = []
        @templates.all_by_regex(/(?i)jlink\.launch$/).each do | file |
          @jlink_launcher_files.push(JlinkLauncherFile.new(file, logger: @logger))
        end

        # setup project name
        @project_file.projectname(@name)
        @cproject_file.update_refresh_scope(@name)
        @cproject_file.update_cdt_build_system(@name)
      end

      def clear!
        # clear source file in .project
        clear_sources!
        # clear .cproject include path
        clear_include!
        targets.each do |target|
          clear_compiler_include!(target)
          clear_compiler_macros!(target)
          clear_optimizations!(target)
          clear_assembler_flags!(target)
          clear_linker_flags!(target)
        end
      end

      # save project
      # do not set anything, only perform save.
      # removing invalid launchers, project specific settings
      # is responsibility of upper layer, not this one !!!
      def save(output_dir)
        Core.assert(output_dir.is_a?(String)) do
          "output dir is not a string '#{output_dir}'"
        end
        @logger.debug("generate project: #{@name}")
        generated_files = []
        # save .project
        path = File.join(output_dir, '.project')
        @project_file.save(path)
        generated_files.push_uniq path
        @generated_hook.notify(path)
        # save .cproject
        path = File.join(output_dir, '.cproject')
        @cproject_file.save(path)
        generated_files.push_uniq path
        @generated_hook.notify(path)
        # save .xxproject
        path = File.join(output_dir, '.xxproject')
        @xxproject_file.save(path)
        generated_files.push_uniq path
        @generated_hook.notify(path)
        # save Makefile.include file
        if @makefileInclude_file
          path = File.join(output_dir, 'Makefile.include')
          @makefileInclude_file.save(path)
          generated_files.push_uniq path
          @generated_hook.notify(path)
        end
        if @xidePrefs_file
          path = File.join(output_dir, '.settings', 'com.tensilica.xide.cdt.prefs')
          @xidePrefs_file.save(path)
          generated_files.push_uniq path
          @generated_hook.notify(path)
        end
        # save target file
        @targetproject_files.each do |target, targetproject_file|
          path = File.join(output_dir, '.settings', 'targets', 'xtensa', "#{target.capitalize}.bts")
          targetproject_file.save(path)
          # SDKGEN-3174 For xtensa, debug target file is must-have
          unless @targetproject_files.key?('debug')
            FileUtils.cp(path, File.join(File.dirname(path), 'Debug.bts'))
            generated_files.push_uniq File.join(File.dirname(path), 'Debug.bts')
          end
          generated_files.push_uniq path
          @generated_hook.notify(path)
        end

        # save .jlink launchers of valid targets
        @jlink_launcher_files.reverse.each do | launcher |
          path = File.join(output_dir, "#{@name} #{launcher.target} #{launcher.debugger}.launch")
          launcher.save(path)
          generated_files.push_uniq path
          @generated_hook.notify(path)
        end
        generated_files
      end

      # get list of all available targets
      def targets
        return targetproject_files.keys
      end

      # add source file
      # ==== arguments
      # path      - source file path
      # vdirexpr  - into virtual directory
      def add_source(path, vdirexpr, *_args, **_kwargs)
        @project_file.add_source(path, vdirexpr)
        targets.each do |target|
          @targetproject_files[target].add_source("#{path}", vdirexpr)
        end
      end

      def add_library(target, path, *_args, **_kwargs)
        @targetproject_files[target].addlLinkerTab.add_library("#{path}\r\n")
      end

      def set_default_target(target)
        @xxproject_file.buildTab.builderTab.internalTab.set_default_target(target)
      end

      # clear all project sources
      def clear_sources!
        @project_file.clear_sources!
      end

      # clear include paths of target
      # ==== arguments
      # target    - target name
      def clear_include!
        @cproject_file.includesTab.clear_include!
      end

      # add compiler include path 'path' to target 'target'
      # ==== arguments
      # target    - target name
      # path      - include path
      def add_compiler_include(target, path, *_args, **_kwargs)
        @targetproject_files[target].includesTab.add_include(path)
      end

      # add assembler include path 'path' to target 'target'
      # ==== arguments
      # target    - target name
      # path      - include path
      def add_assembler_include(target, path, *_args, **_kwargs)
        @targetproject_files[target].includesTab.add_include(path)
      end

      # clear compiler include paths of target
      # ==== arguments
      # target    - target name
      def clear_compiler_include!(target)
        @targetproject_files[target].includesTab.clear_include!
      end

      def clear_compiler_macros!(target)
        @targetproject_files[target].symbolsTab.clear_macros!
      end

      def clear_optimizations!(target)
        @targetproject_files[target].optimizationTab.clear_optimizations!
      end

      # clear all assembler macros of target
      # ==== arguments
      # target    - target name
      def clear_assembler_flags!(target)
        @targetproject_files[target].assemblerTab.clear_assembler_flags!(target)
      end

      # clear all linker flags of target
      # ==== arguments
      # target    - target name
      def clear_linker_flags!(target)
        @targetproject_files[target].linkerTab.clear_linker_flags!
      end

      # clear all linker flags of target
      # ==== arguments
      # target    - target name
      def set_create_minsize_object(target, value)
        @targetproject_files[target].linkerTab.createMinsize(value)
      end

      # enable shared malloc
      def enable_shared_malloc(target, value)
        @targetproject_files[target].memoryTab.enableSharedMalloc(value)
      end

      # add compiler 'name' macro of 'value' to target
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def add_compiler_macro(target, name, value, *_args, **_kwargs)
        @targetproject_files[target].symbolsTab.add_macros(name, value.to_s)
      end

      def add_assembler_macro(target, name, value, *_args, **_kwargs)
        @targetproject_files[target].symbolsTab.add_macros(name, value.to_s)
      end

      def add_prebuild_steps(path, rootdir: nil)
        path = path_mod(path, rootdir)
        @xxproject_file.buildTab.builderTab.internalTab.add_prebuild_steps(File.join('${xt_project_loc}', path))
      end

      def add_prelink_steps(path, rootdir: nil)
        path = path_mod(path, rootdir)
        @xxproject_file.buildTab.builderTab.internalTab.add_prelink_steps(File.join('${xt_project_loc}', path))
      end

      def add_postbuild_steps(path, rootdir: nil)
        path = path_mod(path, rootdir)
        @xxproject_file.buildTab.builderTab.internalTab.add_postbuild_steps(File.join('${xt_project_loc}', path))
      end

      def add_preclean_steps(path, rootdir: nil)
        path = path_mod(path, rootdir)
        @xxproject_file.buildTab.builderTab.internalTab.add_preclean_steps(File.join('${xt_project_loc}', path))
      end

      def set_export_include_path(target, value)
        value = 'off' if value == false
        @xxproject_file.buildTab.builderTab.internalTab.set_export_include_path(value)
      end
    end
  end
end
