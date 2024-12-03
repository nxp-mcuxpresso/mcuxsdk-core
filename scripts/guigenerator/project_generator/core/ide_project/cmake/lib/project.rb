# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/collect_flags_mixin'
require_relative '../../../uproject/internal/_project_utils_mixin'
require_relative '../../../ide_flags/cmake/lib/flags'
require_relative '../../../_path_modifier'
require_relative '../../../_project_mixin'
require_relative '../common/project'

module CMake
  module Lib
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
        @project_file.set_sdk_root(File.join("${ProjDirPath}", Pathname.new('.').relative_path_from(Pathname.new(@output_dir)).to_s))

        toolchainfile_path = File.join('.', @templates.first_by_regex(/(?i)\.cmake$/).gsub(param[:input_dir], ''))
        set_toolchainfile_path(@tool_name, @modifier.relpath(File.join('.', @output_dir), toolchainfile_path))
      end

      def save()
        # clean all targets not used by "generator" class
        @project_file.projectname(@project_name)
        @targets.each do |target|
          if (analyze_enabled?)
            @flags_instance.analyze_asflags(target, assembler_flagsline(target))
            @flags_instance.analyze_ccflags(target, compiler_flagsline(target))
            @flags_instance.analyze_cxflags(target, cpp_compiler_flagsline(target))
            @flags_instance.analyze_arflags(target, archiver_flagsline(target))
          end
        end
        generated_files =  super(@modifier.fullpath(@output_dir))
        generated_files.map { |file| File.join(@output_dir, File.basename(file)) }
      end
    end
  end
end


