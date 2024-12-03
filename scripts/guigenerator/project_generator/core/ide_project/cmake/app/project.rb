# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/collect_flags_mixin'
require_relative '../../../_project_mixin'
require_relative '../../../uproject/internal/_project_utils_mixin'
require_relative '../common/project'
require_relative '../../../_file'
require_relative '../../../_path_modifier'
require_relative '../../../ide_flags/cmake/app/flags'

module CMake
  module App
    module CommonProject


      include Mixin::CollectFlags
      include Mixin::Project
      include Mixin::ProjectUtils
      include CMake::Project

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
        @project_name = param[:project_name]
        @board_name = param[:board_name]
        @tool_name = param[:tool_name]
        @modifier = param[:modifier]
        @output_dir = param[:output_dir]
        @flags_instance = Flags.new(@project_file, logger: @logger)
        enable_analyze(param[:analyze_flags])
        @project_file.projectname(@project_name)
        @project_file.set_sdk_root(File.join("${ProjDirPath}", Pathname.new('.').relative_path_from(Pathname.new(@output_dir)).to_s))

        toolchainfile_path = File.join('.', @templates.first_by_regex(/(?i)\.cmake$/).gsub(param[:input_dir], ''))
        set_toolchainfile_path(@tool_name, @modifier.relpath(File.join('.', @output_dir), toolchainfile_path))
      end

      def converted_output_file(target, path, rootdir: nil, cmd_param: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
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

      def add_linker_flag(target, flag)
        collect_linker_flags(target, flag)
      end

      def linker_file(target, path, rootdir: nil)
        if is_underneath(Pathname.new(@output_dir).parent.to_s, path)
          path = File.join('${ProjDirPath}', path_mod(path, rootdir))
        else
          path = File.join('${SdkRootDirPath}', path)
        end
        super(target, path)
      end

      def add_link_library(target, library, rootdir: nil, linked_project_path: nil)
        if is_underneath(Pathname.new(@output_dir).parent.to_s, library)
          path = File.join('${ProjDirPath}', path_mod(library, rootdir))
        elsif linked_project_path && is_underneath(Pathname.new(linked_project_path).parent.to_s, library)
          # If libraries is in linked project path, should also use ${ProjDirPath}
          path = File.join('${ProjDirPath}', path_mod(library, rootdir))
        else
          path = File.join('${SdkRootDirPath}', library)
        end
        super(target, path)
      end

      def save()
        # clean all targets not used by "generator" class
        @project_file.projectname(@project_name)
        @targets.each do |target|
          if (analyze_enabled?)
            @flags_instance.analyze_asflags(target, assembler_flagsline(target))
            @flags_instance.analyze_ccflags(target, compiler_flagsline(target))
            @flags_instance.analyze_cxflags(target, cpp_compiler_flagsline(target))
            @flags_instance.analyze_ldflags(target, linker_flagsline(target))
            # analyze cc flags for source
            cc_flags_for_src = compiler_flagsline_for_src(target)
            @flags_instance.analyze_ccflags_for_src(target, cc_flags_for_src) unless cc_flags_for_src.empty?
          end
        end
        generated_files = super(@modifier.fullpath(@output_dir))
        generated_files.map { |file| File.join(@output_dir, File.basename(file)) }
      end
    end
  end
end


