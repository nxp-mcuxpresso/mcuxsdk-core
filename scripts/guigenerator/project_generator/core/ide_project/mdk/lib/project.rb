# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/collect_flags_mixin'
require_relative '../../../uproject/internal/_project_utils_mixin'
require_relative '../../../uproject/mdk/lib/project'
require_relative '../../../ide_flags/mdk/lib/flags'
require_relative '../../../_path_modifier'
require_relative '../../../_project_mixin'
require_relative '../../../_file'
require_relative '../common/project'

module Mdk
  module Lib

    class IDEProject < UProject

      include Mixin::CollectFlags
      include Mixin::Project
      include Mixin::ProjectUtils
      include Mdk::Project

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
        @compiler = param[:compiler]
        @flags_instance = Flags.new(@uvprojx_file, logger: @logger)
        @flags_instance.set_compiler param[:compiler]
        enable_analyze(param[:analyze_flags])
      end

      def add_archiver_flag(target, flag)
        collect_archiver_flags(target, flag)
      end

      def save(shared_projects_info, using_shared_workspace, shared_workspace, *_args)
        # clean all targets not used by "generator" class
        @uvprojx_file.clear_unused_targets!()
        @uvprojx_file.targets.each do |target|
          if (analyze_enabled?)
            @flags_instance.analyze_asflags(target, assembler_flagsline(target))
            @flags_instance.analyze_ccflags(target, compiler_flagsline(target))
            @flags_instance.analyze_cxflags(target, cpp_compiler_flagsline(target)) if @type == 'cpp'
            @flags_instance.analyze_arflags(target, archiver_flagsline(target))
            @flags_instance.analyze_devicedefines(target, chipdefines_flagsline(target))
          end
          # enable project in batchbuild
          @uvprojx_file.enable_batchbuild(target, true)
          # set compiler and assembler
          # Todo LPC55S69 use compiler v6 and assembler v5, so version are set by templates now
          # @uvprojx_file.set_compiler_assembler(target, @compiler)
        end
        generated_files = super(@modifier.fullpath(@output_dir), shared_projects_info, using_shared_workspace, shared_workspace)
        generated_files.map { |file| File.join(@output_dir, File.basename(file)) }
      end
    end
  end
end

