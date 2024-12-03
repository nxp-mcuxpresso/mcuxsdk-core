# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/collect_app_flags_mixin'
require_relative '../../../uproject/internal/_project_utils_mixin'
require_relative '../../../uproject/xcc/app/project'
require_relative '../../../uproject/xcc/app/files/config'
require_relative '../../../ide_flags/xcc/app/flags'
require_relative '../../../_path_modifier'
require_relative '../../../_project_mixin'
require_relative '../../../_file'

module Xcc
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
        @project_name       = param[:project_name]
        @board_name         = param[:board_name]
        @tool_name          = param[:tool_name]
        @modifier           = param[:modifier]
        @output_dir         = param[:output_dir]
        @flags_instance     = Flags.new(@project_file, logger: @logger)
        enable_analyze(param[:analyze_flags])
        @project_file.projectname(@project_name)

        toolchainfile_path = File.join('.', @templates.first_by_regex(/(?i)\.cmake$/).gsub(param[:input_dir], ''))
        set_toolchainfile_path(@tool_name, @modifier.relpath(File.join('.', @output_dir), toolchainfile_path))
      end

      def add_source(path, vdir, rootdir: nil, source_target: nil)
        path = path_mod(path, rootdir)
        super(File.join('${ProjDirPath}', path), vdir)
      end

      def add_target_source(path, vdir, targets, rootdir: nil, source_target: nil)
        path = path_mod(path, rootdir)
        super(File.join('${ProjDirPath}', path), targets.strip.split(' '), vdir)
      end

      def targets(targets)
        super(targets)
      end

      def add_assembler_include(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end

      def add_compiler_include(target, path, *args, vdir: nil, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end

      def set_preinclude_file(target, path, macro, linked_support, vdir: nil, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end

      def add_cpp_compiler_include(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end

      def add_link_library(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end

      def binary_file(target, path, rootdir: nil)
        binary_path = File.relpath(
          @modifier.fullpath(@output_dir),
          @modifier.fullpath(path)
        )
        @project_file.add_target(target, binary_path)
        # artifact name
        # @cproject_file.artifact_name(target, File.join('${ProjDirPath}', File.filebase(binary_path)))
        # artifact extension
        # @cproject_file.artifact_extension(target, File.extension(binary_path))
        # setup prefix
        # @cproject_file.artifact_prefix(target, '')
        # prebuild command
        # @cproject_file.prebuildstep_command(target, "${ProjDirPath}/makedir.bat #{File.dirname(binary_path)}")
      end

      def converted_output_file(target, path, rootdir: nil, cmd_param: nil)
        binary_path = File.relpath(
          @modifier.fullpath(@output_dir),
          @modifier.fullpath(path)
        )
        super(target, binary_path.tr('%', '$'))
      end

      def add_binary_options(target, path, option, rootdir: nil)
        binary_path = File.relpath(
          @modifier.fullpath(@output_dir),
          @modifier.fullpath(path)
        )
        super(target, binary_path.tr('%', '$'), option.tr('%', '$'))
      end

      def add_assembler_flag(target, flag)
        collect_assembler_flags(target, flag)
      end

      def add_compiler_flag(target, flag)
        collect_compiler_flags(target, flag)
      end

      # -------------------------------------------------------------------------------------
      # add compiler flag on source level
      # @param [String] target: the target of the flags, could be debug, release and so on
      # @param [String] flag: compiler flags
      # @param [String] path: file's relative path
      # @param [String] rootdir: root directory path
      # @return [Nil]
      def add_compiler_flag_for_src(target, flag, path, *args, rootdir: nil)
        path = path_mod(path, rootdir)
        collect_compiler_flags_for_src(target, flag, File.join('${ProjDirPath}', path))
      end

      def add_cpp_compiler_flag(target, flag)
        collect_cpp_compiler_flags(target, flag)
      end

      def add_linker_flag(target, flag)
        collect_linker_flags(target, flag)
      end

      def linker_file(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end

      def add_library(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end

      def add_archiver_flag(target, flag)
        collect_archiver_flags(target, flag)
      end

      def add_compiler_macro(target, name, value, *_args, **_kwargs)
        @project_file.add_compiler_macro(target, name, value)
      end

      def save
        # clean all targets not used by "generator" class
        @project_file.projectname(@project_name)
        @targets.each do |target|
          next unless analyze_enabled?
          @flags_instance.analyze_asflags(target, assembler_flagsline(target))
          @flags_instance.analyze_ccflags(target, compiler_flagsline(target))
          @flags_instance.analyze_cxflags(target, cpp_compiler_flagsline(target))
          @flags_instance.analyze_ldflags(target, linker_flagsline(target))
          # analyze cc flags for source
          cc_flags_for_src = compiler_flagsline_for_src(target)
          @flags_instance.analyze_ccflags_for_src(target, cc_flags_for_src) unless cc_flags_for_src.empty?
        end
        generated_files = super(@modifier.fullpath(@output_dir))
        generated_files.map { |file| File.join(@output_dir, File.basename(file)) }
      end
    end
  end
end
