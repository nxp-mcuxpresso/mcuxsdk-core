# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require_relative '../../internal/collect_flags_mixin'
require_relative '../../../uproject/internal/_project_utils_mixin'
require_relative '../../../uproject/iar/app/project'
require_relative '../../../ide_flags/iar/app/flags'
require_relative '../../../_path_modifier'
require_relative '../../../_project_mixin'
require_relative '../../../_file'
require_relative '../common/project'

module Iar
  module App
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
        @output_rootdir     = param[:output_rootdir]
        @osjtag             = param[:osjtag]
        @flags_instance     = instance_with_version('Iar::App::Flags', @toolchain_version, @ewp_file, logger: @logger)
        enable_analyze(param[:analyze_flags])
      end

      def add_batch_project_target(batchname, project, target)
        super
      end

      def add_comfiguration(target, path, optlevel)
        super(target, path, optlevel)
      end

      def add_specific_ccinclude(target, folder, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, folder, File.join('$PROJ_DIR$', path))
      end

      def linker_file(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('$PROJ_DIR$', path))
      end

      # -------------------------------------------------------------------------------------
      # add compiler flag on source level
      # @param [String] target: the target of the flags, could be debug, release and so on
      # @param [String] flag: compiler flags
      # @param [String] path: file's relative path
      # @param [String] rootdir: root directory path
      # @return [Nil]
      def add_compiler_flag_for_src(target, flag, path, vdir, rootdir: nil)
        path = path_mod(path, rootdir)
        collect_compiler_flags_for_src(target, flag, File.join('$PROJ_DIR$', path, "virtual-dir", vdir))
      end

      def add_linker_flag(target, flag)
        collect_linker_flags(target, flag)
      end

      def add_library(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('$PROJ_DIR$', path))
        # @eww_file.add_proj(File.join('$WS_DIR$', path))
      end

      def binary_file(target, path, rootdir: nil)
        binary_path = File.relpath(
          @modifier.fullpath(@output_dir),
          @modifier.fullpath(path)
        )
        # output binary file
        @ewp_file.linkerTab.outputTab.output_filename(target, File.basename(File.join('$PROJ_DIR$', binary_path)))
        # output binary directory
        # For meta build system, it only has one target, we can save elf/bin/lib in $PROJ_DIR$, it can simply path setting for different targets
        @ewp_file.generalTab.outputTab.output_dir(target, '$PROJ_DIR$')
        # object-files directory
        @ewp_file.generalTab.outputTab.object_files_dir(target, File.join('$PROJ_DIR$', File.dirname(binary_path), 'obj'))
        # list-files directory
        @ewp_file.generalTab.outputTab.list_files_dir(target, File.join('$PROJ_DIR$', File.dirname(binary_path), 'list'))
      end

      def converted_output_file(target, path, rootdir: nil, cmd_param: nil)
        filename, extention = File.basename(path).split('.')
        is_overrided = filename != @project_name
        Core.assert(filename && extention) do
          "make sure the converted output file of project #{@project_name} has the correct file and extention name"
        end
        # Enable additional output
        @ewp_file.outputConverterTab.outputTab.enable_additional_output(target, true)
        # Set output format, by analyzing the extention of additional output file
        @ewp_file.outputConverterTab.outputTab.set_output_format(target, extention)
        # Check if the output file was overrided
        if is_overrided
          # Enable default file overrided
          @ewp_file.outputConverterTab.outputTab.enable_override_default_output(target, true)
          # Set override file name
          @ewp_file.outputConverterTab.outputTab.set_override_output_file(target, File.basename(path))
        end
      end

      def linker_file(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        path = File.join('$PROJ_DIR$', path)
        super(target, path)
      end

      def set_raw_binary_image_file(target, path, rootdir: nil)
        super(target, File.join('$PROJ_DIR$', path))
      end

      def set_raw_binary_image_symbol(target, value)
        super(target, value)
        @ewp_file.linkerTab.inputTab.add_keep_symbol(target, value)
      end

      def set_raw_binary_image_section(target, value)
        super
      end

      def set_raw_binary_image_align(target, value)
        super
      end

      def use_flash_loader(target, value)
        super(target, value)
      end

      def set_board_file(target, path, absolute, rootdir: nil)
        unless absolute
          path = path_mod(path, rootdir)
          path = File.join('$PROJ_DIR$', path)
        end
        super(target, path)
      end

      def set_postbuild_file(target, path, absolute, extra_cmd, rootdir: nil)
        unless absolute
          path = path_mod(path, rootdir)
          path = File.join('$PROJ_DIR$', path)
        end
        super(target, (path + ' ' + extra_cmd).strip)
      end

      def set_macro_file(target, macrofile, absolute, choose, rootdir: nil)
        unless absolute
          path = path_mod(macrofile, rootdir)
          macrofile = File.join('$PROJ_DIR$', path)
        end
        super(target, macrofile, choose)
      end

      def set_debugger(target, textbox, checkbox, multicorecheck)
        super(target, textbox, checkbox, multicorecheck)
      end

      def set_debugger_download(target, checkbox)
        super(target, checkbox)
      end

      def set_debugger_cmsisdap(target, cmsisdapinterface, cmsisdapmulticpu, cmsisdapmultitarget, cmsisdapresetlist)
        super(target, cmsisdapinterface, cmsisdapmulticpu, cmsisdapmultitarget, cmsisdapresetlist)
      end

      def set_jlink_script_file(target, path, choose, rootdir: nil)
        path = path_mod(path, rootdir)
        path = File.join('$PROJ_DIR$', path)
        commandlineoption = "--jlink_script_file=#{path}"
        super(target, commandlineoption, choose)
      end

      def set_debugger_extra_options(target, options, rootdir: nil)
        super(target, options)
      end

      def set_image_path(target, path, args)
        path = File.join('$PROJ_DIR$', path)
        super(target, path, args)
      end

      def set_offset(target, value, args)
        value = '0x' + value.to_s(16)
        super(target, value, args)
      end

      # ----------------------------------------------------------
      # Set raw binary image according to file attribute, this is new api
      # which include function of set_raw_binary_image_file, set_raw_binary_image_symbol,
      # set_raw_binary_image_section, set_raw_binary_image_align
      # @param [String] target: The target for the file
      # @param [Hash] source: Source record for image
      def set_raw_binary_image(target, source, rootdir: nil)
        # if path is not relative path, tranfer to relative path at first
        if !source['source'].start_with?('../') && !source['source'].start_with?('./')
          source['source'] = File.relpath(
            @modifier.fullpath(@output_dir),
            @modifier.fullpath(source['source'])
          )
        end
        source['source'] = File.join('$PROJ_DIR$', source['source'])
        super(target, source)
      end

      def save(shared_projects_info, using_shared_workspace, shared_workspace, *_args)
        # clean all targets not used by "generator" class
        # and perform additional setup
        @ewp_file.clear_unused_targets!
        # setup project settings
        @ewp_file.targets.each do |target|
          next unless analyze_enabled?

          @flags_instance.analyze_asflags(target, assembler_flagsline(target))
          @flags_instance.analyze_ccflags(target, compiler_flagsline(target))
          @flags_instance.analyze_cxflags(target, cpp_compiler_flagsline(target))
          @flags_instance.analyze_ldflags(target, linker_flagsline(target))
          @flags_instance.analyze_devicedefines(target, chipdefines_flagsline(target))
          # analyze cc flags for source
          cc_flags_for_src = compiler_flagsline_for_src(target)
          @flags_instance.analyze_ccflags_for_src(target, cc_flags_for_src) unless cc_flags_for_src.empty?
        end
        generated_files = super(@modifier.fullpath(@output_dir), shared_projects_info, using_shared_workspace, shared_workspace)
        # Copy dni/dnx file for PE debugger in IAR
        project_dir = File.join(@output_rootdir, @output_dir)
        @templates.each do |template|
          next unless template.include?('.dni') || template.include?('.dnx')
          raise 'dni or dnx file not exist' unless File.exist? template

          file_data = IO.read(template)

          unless @osjtag
            @logger.error("Since *.dni/*.dnx file is set in project-templates for PE debugger, please set debugger-config => osjtag in IDE.yml")
            next
          end
          file_data.gsub!('device_name', @osjtag)
          setting_path = File.join(project_dir, 'settings')
          FileUtils.mkdir_p(setting_path) unless Dir.exist?(setting_path)
          if template.include? '.dni'
            dni_file = File.join(setting_path, "#{@project_name}.dni")
          elsif template.include? '.dnx'
            dni_file = File.join(setting_path, "#{@project_name}.dnx")
          end
          IO.write(dni_file, file_data)
          generated_files.push_uniq dni_file
        end
        generated_files.map do |file|
          if %w[.dni .dnx].include? File.extname(file)
            File.join(@output_dir, 'settings', File.basename(file))
          else
            File.join(@output_dir, File.basename(file))
          end
        end
      end
    end

    class IDEProject_9_32_1 < IDEProject
      def set_project_version(target, version)
        @ewp_file.set_project_version(target, version)
        # ewd file is optional
        @ewd_file&.set_project_version(target, version)
      end
    end

    class IDEProject_9_32_2 < IDEProject_9_32_1
    end

    class IDEProject_9_40_1 < IDEProject_9_32_2
    end
  end
end
