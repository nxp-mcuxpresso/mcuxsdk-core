# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/collect_flags_mixin'
require_relative '../../../uproject/internal/_project_utils_mixin'
require_relative '../../../uproject/mcux/lib/project'
require_relative '../../../uproject/mcux/lib/files/mcux_project_definition_xml'
require_relative '../../../ide_flags/mcux/lib/flags'
require_relative '../../../_path_modifier'
require_relative '../../../_project_mixin'
require_relative '../../../_file'
require_relative '../common/project'

module Mcux
  module Lib

    class IDEProject < UProject

      include Mixin::CollectFlags
      include Mixin::Project
      include Mixin::ProjectUtils
      include Mcux::Project

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
        Core.assert(!param[:category].nil?) do
          "param 'category' is not non-empty string '#{param[:category].class.name}'"
        end
        # create default project name if params[:name] not set
        param[:name] = standardize_name(param[:name], param[:board_name], param[:project_name])
        # call parent constructor to init files
        super(param)
        @project_name = param[:project_name]
        @board_name = param[:board_name]
        @projectcategory = param[:category]
        @platform_devices_soc_name = param[:platform_devices_soc_name]
        @tool_name = param[:tool_name]
        @modifier = param[:modifier]
        @output_dir = param[:output_dir]

        project_rootpath = @output_dir.split('/' + @tool_name)[0] + '/mcux'
        @projectid = @board_name + '_' + @project_name
        @flags_instance = Flags.new(@project_file, logger: @logger)
        enable_analyze(param[:analyze_flags])
        @project_file.projectname(@projectid, @project_name, @projectcategory, @board_name)
      end

      def save()
        # clean all targets not used by "generator" class
        targets().each do |target|
          if (analyze_enabled?)
            @flags_instance.analyze_asflags(target, assembler_flagsline(target))
            @flags_instance.analyze_ccflags(target, compiler_flagsline(target))
            @flags_instance.analyze_cxflags(target, cpp_compiler_flagsline(target))
            @flags_instance.analyze_arflags(target, archiver_flagsline(target))
          end
        end
        super(@modifier.fullpath(@output_dir))
      end
    end

  end
end


