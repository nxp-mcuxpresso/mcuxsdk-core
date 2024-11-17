# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../ide_project/internal/collect_flags_mixin'
require_relative '../../../uproject/internal/_project_utils_mixin'
require_relative '../../../uproject/iar/lib/project'
require_relative '../../../ide_flags/iar/lib/flags'
require_relative '../../../_path_modifier'
require_relative '../../../_project_mixin'
require_relative '../../../_file'
require_relative '../common/project'

module Iar
  module Lib
    class IDEProject < UProject
      include Mixin::CollectFlags
      include Mixin::Project
      include Mixin::ProjectUtils
      include Iar::Project

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
        @flags_instance     = instance_with_version('Iar::Lib::Flags', @toolchain_version, @ewp_file, logger: @logger)
        enable_analyze(param[:analyze_flags])
      end

      def add_archiver_flag(target, flag)
        collect_archiver_flags(target, flag)
      end

      def binary_file(target, path, rootdir: nil)
        binary_path = File.relpath(
          @modifier.fullpath(@output_dir),
          @modifier.fullpath(path)
        )
        # output binary file
        @ewp_file.libraryBuilderTab.outputTab.output_file(target, File.join('$PROJ_DIR$', binary_path))
        # output binary directory
        @ewp_file.generalTab.outputTab.output_dir(target, File.dirname(File.join('$PROJ_DIR$', binary_path)))
        # object-files directory
        @ewp_file.generalTab.outputTab.object_files_dir(target, "$PROJ_DIR$/#{target.downcase}/obj")
        # list-files directory
        @ewp_file.generalTab.outputTab.list_files_dir(target, "$PROJ_DIR$/#{target.downcase}/list")
      end

      def save(shared_projects_info, using_shared_workspace, shared_workspace, *_args)
        # clean all targets not used by "generator" class
        # and perform additional setup
        @ewp_file.clear_unused_targets!
        # setup Project settings
        @ewp_file.targets.each do |target|
          next unless analyze_enabled?

          @flags_instance.analyze_asflags(target, assembler_flagsline(target))
          @flags_instance.analyze_ccflags(target, compiler_flagsline(target))
          @flags_instance.analyze_cxflags(target, cpp_compiler_flagsline(target))
          @flags_instance.analyze_arflags(target, archiver_flagsline(target))
          @flags_instance.analyze_devicedefines(target, chipdefines_flagsline(target))
        end
        generated_files = super(@modifier.fullpath(@output_dir), shared_projects_info, using_shared_workspace, shared_workspace)
        generated_files.map { |file| File.join(@output_dir, File.basename(file)) }
      end
    end

    class IDEProject_9_32_1 < IDEProject
      def set_project_version(target, version)
        @ewp_file.set_project_version(target, version)
      end
    end

    class IDEProject_9_32_2 < IDEProject_9_32_1
    end

    class IDEProject_9_40_1 < IDEProject_9_32_2
    end

  end
end
