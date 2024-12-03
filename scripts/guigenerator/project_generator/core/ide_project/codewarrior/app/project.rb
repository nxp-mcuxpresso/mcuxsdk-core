# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/collect_flags_mixin'
require_relative '../../../uproject/internal/_project_utils_mixin'
require_relative '../../../uproject/codewarrior/app/project'
require_relative '../../../ide_flags/codewarrior/app/flags'
require_relative '../../../_path_modifier'
require_relative '../../../_project_mixin'
require_relative '../../../_file'
require_relative '../common/project'

module CodeWarrior
  module App
    class IDEProject < UProject
      include Mixin::CollectFlags
      include Mixin::Project
      include Mixin::ProjectUtils
      include CodeWarrior::Project

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
        @flags_instance = Flags.new(@cproject_file, logger: @logger)
        enable_analyze(param[:analyze_flags])
        @linker_output_binary = false
        @ddr_script = {}
      end

      def save
        @cproject_file.clear_unused_targets!
        @all_targets.each do |target|
          # recognize flags
          next unless analyze_enabled?
          @flags_instance.analyze_asflags(target, assembler_flagsline(target))
          @flags_instance.analyze_ccflags(target, compiler_flagsline(target))
          @flags_instance.analyze_ldflags(target, linker_flagsline(target))
        end

        # save/setup .jlink launchers for valid targets
        @debug_launcher_files.each do | launcher |
          launcher.set_program_name(@project_name)
          launcher.set_debugger_type
          launcher.set_res_uuid
        end

        # update debugger management file
        @refRSESys_file.update_node(@project_name)

        generated_files = super(@modifier.fullpath(@output_dir))
        generated_files.map { |file| File.join(@output_dir, File.basename(file)) }
      end

    end
  end
end
