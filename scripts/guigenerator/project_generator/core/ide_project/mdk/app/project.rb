# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require_relative '../../internal/collect_flags_mixin'
require_relative '../../../uproject/internal/_project_utils_mixin'
require_relative '../../../uproject/mdk/app/project'
require_relative '../../../ide_flags/mdk/app/flags'
require_relative '../../../_path_modifier'
require_relative '../../../_project_mixin'
require_relative '../../../_file'
require_relative '../../../../modify_template'
require_relative '../common/project'

module Mdk
  module App
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
        @output_rootdir = param[:output_rootdir]
        @compiler = param[:compiler]
        @flags_instance = Flags.new(@uvprojx_file, logger: @logger)
        @flags_instance.set_compiler @compiler
        @cmsis = param[:cmsis]
        enable_analyze(param[:analyze_flags])
      end

      def add_comfiguration(target, path, optlevel)
        target = target.capitalize if target == 'debug' || target == 'release'
        super(target, path, optlevel)
      end

      def linker_file(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, path)
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
        collect_compiler_flags_for_src(target, flag, path)
      end

      # add assemblerflag on source level
      def add_assembler_flag_for_src(target, flag, path, rootdir: nil)
        path = path_mod(path, rootdir)
        collect_assembler_flags_for_src(target, flag, path)
      end

      def add_linker_flag(target, flag)
        collect_linker_flags(target, flag)
      end

      def add_library(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, path)
      end

      def linker_file(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, path)
      end

      def converted_output_file(target, path, rootdir: nil, cmd_param: nil)
        format = File.extname(path).split('.')[1]
        format_map = {
            'srec' => "\"$L#{File.basename(path)}\" --m32combined",
            'bin'  => "\"$L#{File.basename(path)}\" --bincombined",
            'hex'  => "\"$L#{File.basename(path)}\" --i32combined"
        }
        Core.assert(format_map.key?(format)) do
          "type '#{format}' is not valid"
        end
        before_compilation_cmd = if cmd_param.nil?
                                   format('fromelf.exe --output %s "#L"', format_map[format])
                                 else
                                   format('fromelf.exe --output %s "#L"', format_map[format])
                                 end
        @uvprojx_file.userTab.after_make_command_1(target, before_compilation_cmd)
        @uvprojx_file.userTab.after_make_run_1(target, true)
      end

      def add_initialization_file(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, path)
      end

      def add_flash_programming_file(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, path)
      end

      def set_load_application(target, result)
        if result
          super(target, 1)
        else
          super(target, 0)
        end
      end

      def set_periodic_update(target, result)
        if result
          super(target, 1)
        else
          super(target, 0)
        end
      end


      def save(shared_projects_info, using_shared_workspace, shared_workspace, *_args)
        # clean all targets not used by "generator" class
        @uvprojx_file.clear_unused_targets!
        @uvoptx_files&.each { |file| file.clear_unused_targets! }
        @uvprojx_file.targets.each do |target|
          if analyze_enabled?
            # analyze flags for project
            @flags_instance.analyze_asflags(target, assembler_flagsline(target))
            @flags_instance.analyze_ccflags(target, compiler_flagsline(target))
            @flags_instance.analyze_cxflags(target, cpp_compiler_flagsline(target)) if @type == 'cpp'
            @flags_instance.analyze_ldflags(target, linker_flagsline(target))
            @flags_instance.analyze_devicedefines(target, chipdefines_flagsline(target))
          end
          # analyze cc flags for source
          cc_flags_for_src = compiler_flagsline_for_src(target)
          @flags_instance.analyze_ccflags_for_src(target, cc_flags_for_src) unless cc_flags_for_src.empty?
          # analyze as flags for source
          as_flags_for_src = assembler_flagsline_for_src(target)
          @flags_instance.analyze_asflags_for_src(target, as_flags_for_src) unless as_flags_for_src.empty?
          # enable project in batchbuild
          @uvprojx_file.enable_batchbuild(target, true)
          # set compiler and assembler version
          # Todo LPC55S69 use compiler v6 and assembler v5, so version are set by templates now
          # @uvprojx_file.set_compiler_assembler(target, @compiler)
        end
        # and now setup MQX specific settings for all used targets
        generated_files = super(@modifier.fullpath(@output_dir), @uvprojx_file.targets, shared_projects_info, using_shared_workspace, shared_workspace)

        if @cmsis && !@cmsis.empty?
          project_path = File.join(@output_rootdir, @output_dir, "#{@project_name}.uvprojx")
          rte = SDKGenerator::ProjectGenerator::CmsisRteTemplate.new(@project_name, project_path, @output_rootdir)
          rte.add_cmsis_component(@cmsis)
          rte.save
        end
        generated_files.map { |file| File.join(@output_dir, File.basename(file)) }
      end
    end
  end
end
