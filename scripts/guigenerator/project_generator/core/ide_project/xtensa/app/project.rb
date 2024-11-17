# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/collect_app_flags_mixin'
require_relative '../../../uproject/internal/_project_utils_mixin'
require_relative '../../../uproject/xtensa/app/project'
require_relative '../../../ide_flags/xtensa/app/flags'
require_relative '../../../_path_modifier'
require_relative '../../../_project_mixin'
require_relative '../../../_file'

module Xtensa
  module App
    class IDEProject < UProject
      include Mixin::CollectAppFlags
      include Mixin::Project
      include Mixin::ProjectUtils

      def initialize(param)
        Core.assert(param[:project_name].is_a?(String) && !param[:project_name].empty?) do
          "param 'project_name' is not non-empty string '#{param[:project_name].class.name}'"
        end
        Core.assert(param[:board_name].is_a?(String) && !param[:board_name].empty?) do
          "param 'board_name' is not non-empty string '#{param[:board_name].class.name}'"
        end
        Core.assert(param[:tool_name].is_a?(String) && !param[:tool_name].empty?) do
          "param 'tool_name' is not non-empty string '#{param[:tool_name].class.name}'"
        end
        Core.assert(!param[:modifier].nil?) do
          "param 'modifier' is not non-empty string '#{param[:modifier].class.name}'"
        end
        Core.assert(!param[:output_dir].nil?) do
          "param 'output_dir' is not non-empty string '#{param[:output_dir].class.name}'"
        end
        # create default project name if params[:name] not set
        param[:name] = standardize_name(param[:name], param[:board_name], param[:project_name])
        # call parent constructor to init files
        super(param)
        @name               = param[:name]
        @project_name       = param[:project_name]
        @board_name         = param[:board_name]
        @tool_name          = param[:tool_name]
        @modifier           = param[:modifier]
        @output_dir         = param[:output_dir]
        @all_targets        = param[:targets]
        @flags_instance = {}
        @all_targets.each do |each_target|
          @flags_instance[each_target] = Flags.new(@targetproject_files[each_target], logger: @logger)
        end
        enable_analyze(param[:analyze_flags])
        @linker_output_binary = false

        @ddr_script = {}
      end

      def add_source(path, vdir, rootdir: nil, source_target: nil)
        # For standalone project, xtensa will search source in project directory automatically
        # If we add it to the project, it will cause error
        return if ENV['standalone'] == 'true'
        path = path_mod(path, @output_dir)
        # xtensa does not accept ".." in virtual directory
        vdir = vdir.split('/').reject {|item| item == '..' }.join('/')
        super(@project_file.project_parent_path(path), vdir)
      end

      def add_library(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${xt_project_loc}', path))
      end

      def set_default_target()
        # debug target is defalut, no need to set
        return if @all_targets.include?('debug')
        # only set default target if no debug target
        if @all_targets.length > 0
          super(@all_targets[0])
        end
      end

      def add_compiler_include(target, path, *args, vdir: nil, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${xt_project_loc}', path))
      end

      def add_assembler_include(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${xt_project_loc}', path))
      end

      def add_assembler_flag(target, flag)
        collect_assembler_flags(target, flag)
      end

      def add_compiler_for_assembler_flag(target, flag)
        collect_compiler_for_assembler_flags(target, flag)
      end

      def add_compiler_for_linker_flag(target, flag)
        collect_compiler_for_linker_flags(target, flag)
      end

      def add_compiler_flag(target, flag)
        collect_compiler_flags(target, flag)
      end

      def add_cpp_compiler_flag(target, flag)
        collect_cpp_compiler_flags(target, flag)
      end

      def add_linker_flag(target, flag)
        collect_linker_flags(target, flag)
      end

      def save
        @all_targets.each do |target|
          # recognize flags
          next unless analyze_enabled?
          @flags_instance[target].analyze_asflags(assembler_flagsline(target))
          @flags_instance[target].analyze_ccflags(compiler_flagsline(target))
          @flags_instance[target].analyze_cxflags(cpp_compiler_flagsline(target))
          @flags_instance[target].analyze_cc_for_as_flags(compiler_for_assembler_flagsline(target))
          @flags_instance[target].analyze_ldflags(linker_flagsline(target))
          @flags_instance[target].analyze_cc_for_ld_flags(compiler_for_linker_flagsline(target))
        end

        # save/setup .jlink launchers for valid targets
        @jlink_launcher_files.reverse.each do | launcher |
          if (targets.include?(launcher.target))
            launcher.set_program_name(@project_name)
          else
            @jlink_launcher_files.delete(launcher)
          end
        end

        generated_files = super(@modifier.fullpath(@output_dir))
        generated_files.map do |file|
          if File.extname(file) == '.bts'
            File.join(@output_dir, '.settings', 'targets', 'xtensa', File.basename(file))
          elsif File.basename(file) == 'com.tensilica.xide.cdt.prefs'
            File.join(@output_dir, '.settings', File.basename(file))
          else
            File.join(@output_dir, File.basename(file))
          end
        end
      end

      # empty implementation, to unify the function call in generator.rb
      def converted_output_file(target, path, rootdir: nil, cmd_param: nil)
      end

      def binary_file(target, path, rootdir: nil)
      end
  end
    end
end
