# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/collect_flags_mixin'
require_relative '../../../uproject/internal/_project_utils_mixin'
require_relative '../../../uproject/mcux/app/project'
require_relative '../../../uproject/mcux/app/files/mcux_project_definition_xml'
require_relative '../../../ide_flags/mcux/app/flags'
require_relative '../../../_path_modifier'
require_relative '../../../_project_mixin'
require_relative '../../../_file'
require_relative '../common/project'

module Mcux
  module App

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
        if !param[:board_kit_name].nil?
          @board_name = param[:board_kit_name]
        else
          @board_name = param[:board_name]
        end
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

      def add_toolchain(toolchains)
        return if toolchains.nil? or toolchains.empty?
        super(toolchains)
      end

      def add_linker_flag(target, flag)
        collect_linker_flags(target, flag)
      end

      #Add library to target
      def add_link_library(target, path, filetype, toolchain, virtual_dir)
        filetype = if (!filetype.nil?) && (!filetype.empty?)
                     filetype
                   else
                     get_file_type(path, toolchain)
                   end
        super(target, path, filetype, toolchain, virtual_dir)
      end

      def add_assembler_include(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
      end

      def add_linker_file(target, path, vdir, rootdir: nil)
        if vdir
          if vdir.include?(':')
            vdir = vdir.split(':').join('/')
          end
        else
          # if nil==vdir, give the default 'src' same with other IDE.
          vdir = 'src'
        end
        super(target, File.join('${ProjDirPath}', vdir, File.basename(path)))
      end

      # Add undefine symbol for mcux
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def undefine_compiler_macro(target, name, value)
        super(target, name, value)
      end

      def save()
        targets().each do |target|
          if (analyze_enabled?)
            @flags_instance.analyze_asflags(target, assembler_flagsline(target))
            @flags_instance.analyze_ccflags(target, compiler_flagsline(target))
            @flags_instance.analyze_cxflags(target, cpp_compiler_flagsline(target))
            @flags_instance.analyze_ldflags(target, linker_flagsline(target))
          end
        end

        super(@modifier.fullpath(@output_dir))
      end

      # set the prebuild cmd
      # ==== arguments
      # target    - the target of project
      # cmd       - the command
      # item      - just aligned with other toolchains, no practical effect.
      def add_prebuild_script(target, cmd, item: 1)
        super(target, cmd)
      end

      # set the postbuild cmd
      # ==== arguments
      # target    - the target of project
      # cmd       - the command
      # item      - just aligned with other toolchains, no practical effect.
      def add_postbuild_script(target, cmd, item: 1)
        super(target, cmd)
      end

      def set_jlink_script_file(target, value, *args, rootdir: nil)
        super(target, value)
      end
    end
  end
end
