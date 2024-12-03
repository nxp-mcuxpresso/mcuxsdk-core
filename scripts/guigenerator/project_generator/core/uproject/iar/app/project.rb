# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/iar/_project'
require_relative '../../internal/_app_project_interface'
require_relative 'files/ewp_file'
require_relative 'files/ewd_file'
require_relative 'files/eww_file'
require_relative '../common/project'

module Iar
  module App
    class UProject < Internal::Iar::UProject
      # consuming interface
      include Internal::AppProjectInterface
      # project function common implementation
      include Iar::CommonProject
      attr_reader :ewp_file
      attr_reader :eww_file

      attr_reader :ewd_file
      attr_reader :ewd_template

      def initialize(param)
        super(param)
        # mandatory ewp file
        @ewp_template = @templates.first_by_regex(/\.ewp$/)
        Core.assert(!@ewp_template.nil?) do
          "no '.ewp' file in templates"
        end
        @ewp_file = instance_with_version('Iar::App::EwpFile', param[:toolchain_version], @ewp_template, logger: @logger)
        # eww file
        template = @templates.first_by_regex(/\.eww$/)
        @eww_file = instance_with_version('Iar::App::EwwFile', param[:toolchain_version], template, logger: @logger)

        # optional ewd file
        @ewd_template = @templates.first_by_regex(/\.ewd$/)
        @ewd_file = @ewd_template ? instance_with_version('Iar::App::EwdFile', param[:toolchain_version], @ewd_template, logger: @logger) : nil
      end

      def add_batch_project_target(batchname, project, target)
        @eww_file.add_batch_project_target(batchname, project, target)
      end

      def clear!
        clear_sources!
        targets.each do |target|
          clear_assembler_include!(target)
          clear_compiler_include!(target)
          clear_compiler_macros!(target)
          clear_assembler_macros!(target)
          clear_libraries!(target)
        end
      end

      def set_postbuild_file(target, value, *_args, **_kwargs)
        @ewp_file.buildactionTab.configurationTab.postbuild_command(target, value)
      end

      # save project
      def save(output_dir, shared_projects_info, using_shared_workspace, add_shared_workspace, *_args)
        Core.assert(output_dir.is_a?(String)) do
          "output dir is not a string '#{output_dir}'"
        end
        @logger.debug("generate project: #{@name}")
        generated_files = []
        # save .ewp file
        path = File.join(output_dir, "#{@name}.ewp")
        @ewp_file.save(path)
        generated_files.push_uniq path
        File.delete(@ewp_template) if File.exist? @ewp_template
        @generated_hook.notify(path)
        # save .eww file
        if @eww_file
          @eww_file.add_project(File.join('$WS_DIR$', "#{@name}.ewp"))
          path = File.join(output_dir, "#{@name}.eww")
          if @name != add_shared_workspace
            @eww_file.save(path)
            generated_files.push_uniq path
            @generated_hook.notify(path)
          end
          # save additional shared workspace
          if !using_shared_workspace && add_shared_workspace
            # add other projects to workspace
            shared_projects_info&.each do |project_name, project_path|
              @eww_file.add_project(File.join('$WS_DIR$', File.join(project_path, "#{project_name}.ewp")))
            end
            path = File.join(output_dir, "#{add_shared_workspace}.eww")
            @eww_file.save(path)
            generated_files.push_uniq path
            @generated_hook.notify(path)
          end
        end
        # save .ewd file
        if @ewd_file
          path = File.join(output_dir, "#{@name}.ewd")
          @ewd_file.save(path)
          generated_files.push_uniq path
          File.delete(@ewd_template) if File.exist? @ewd_template
          @generated_hook.notify(path)
        end
        generated_files
      end

      def add_comfiguration(target, path, optlevel, *_args, **_kwargs)
        @ewp_file.add_comfiguration(target, path, optlevel)
      end

      def add_specific_ccinclude(target, folder, path, *_args, **_kwargs)
        @ewp_file.add_specific_ccinclude(target, folder, path)
      end

      # add compiler include path 'path' to target 'target'
      # ==== arguments
      # target    - target name
      # path      - include path
      def add_compiler_include(target, path, *_args, **_kwargs)
        if path =~ /--pre:/
          rpath = path.gsub('--pre:', '')
          @ewp_file.compilerTab.preprocessorTab.add_pre_include(target, rpath)
        else
          @ewp_file.compilerTab.preprocessorTab.add_include(target, path)
        end
      end

      # add library to target
      # ==== arguments
      # target    - target name
      # path      - library path
      def add_library(target, path, *_args, **_kwargs)
        @ewp_file.linkerTab.libraryTab.add_library(target, path)
      end

      # clear all libraries
      # ==== arguments
      # target    - target name
      def clear_libraries!(target)
        @ewp_file.linkerTab.libraryTab.clear_libraries!(target)
      end

      # add linker file
      # ==== arguments
      # target    - target name
      # path      - linker file path
      def linker_file(target, path, *_args, **_kwargs)
        @ewp_file.linkerTab.configTab.configuration_file(target, path)
      end

      # enable additional ouput
      # ==== arguments
      # target    - target name
      # value     - true or false
      def enable_additional_output(target, value, *_args, **_kargs)
        @ewp_file.outputConverterTab.outputTab.enable_additional_output(target, value)
      end

      # set additional output format
      # ==== arguments
      # target    - target name
      # value     - extention names of output format
      def set_output_format(*_args, **_kargs)
        @ewp_file.outputConverterTab.outputTab.set_output_format(target, value)
      end

      # enable override default output file
      # ==== arguments
      # target    - target name
      # value     - true or false
      def enable_override_default_output(*_args, **_kargs)
        @ewp_file.outputConverterTab.outputTab.enable_override_default_output(target, value)
      end

      # set override default output file
      # ==== arguments
      # target    - target name
      # path      - overrid output files pathes
      def set_override_output_file(*_args, **_kargs)
        @ewp_file.outputConverterTab.outputTab.set_override_output_file(target, value)
      end

      # add raw binary image
      # ==== arguments
      # target    - target name
      # path      - binary image relative path
      def set_raw_binary_image_file(target, path, *_args, **_kwargs)
        @ewp_file.linkerTab.inputTab.set_raw_binary_image_file(target, path)
      end

      # add raw binary image section
      # ==== arguments
      # target    - target name
      # value     - section names
      def set_raw_binary_image_section(target, value, *_args, **_kwargs)
        @ewp_file.linkerTab.inputTab.set_raw_binary_image_section(target, value)
      end

      # add raw binary image symbol
      # ==== arguments
      # target    - target name
      # value     - symbol name
      def set_raw_binary_image_symbol(target, value, *_args, **_kwargs)
        @ewp_file.linkerTab.inputTab.set_raw_binary_image_symbol(target, value)
      end

      # add raw binary image align
      # ==== arguments
      # target    - target name
      # value     - align
      def set_raw_binary_image_align(target, value, *_args, **_kwargs)
        @ewp_file.linkerTab.inputTab.set_raw_binary_image_align(target, value)
      end

      # add raw binary image
      # ==== arguments
      # target    - target name
      # value     - source
      def set_raw_binary_image(target, value, *_args, **_kwargs)
        # clear empty symbol node
        @ewp_file.linkerTab.inputTab.clear_keep_symbols!(target)
        # add symbol to keep
        @ewp_file.linkerTab.inputTab.add_keep_symbol(target, value['symbol']) if value['symbol']
        # set raw binary image
        @ewp_file.linkerTab.inputTab.set_raw_binary_image(target, value)
      end

      # use flash loader
      # ==== arguments
      # target    - target name
      # value     - value: ture/false
      def use_flash_loader(target, value, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.downloadTab.use_flash_loaders(target, value)
      end

      # use flash loader
      # ==== arguments
      # target    - target name
      # value     - value: ture/false
      def set_board_file(target, value, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.downloadTab.board_file(target, value)
      end

      # use mac file
      # ==== arguments
      # target    - target name
      # macrofile - macrofile path
      def set_macro_file(target, macrofile, choose)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.downloadTab.macro_file(target, macrofile, choose)
      end

      # set run-to
      # ==== arguments
      # target    - target name
      def set_debugger(target, content, choose, multicorecheck)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.setupTab.run_to(target, content, choose)
        @ewd_file.multicoreTab.slave_multicore_attach(target, multicorecheck)
      end

      # set cmsisdap
      # ==== arguments
      # target    - target name
      def set_debugger_cmsisdap(target, cmsisdapinterface, cmsisdapmulticpu, cmsisdapmultitarge, cmsisdapresetlist)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.debuggercmsisdapTab.interface_probeconfig(target, cmsisdapinterface)
        @ewd_file.debuggercmsisdapTab.cmsisdap_multitarget_enable(target, cmsisdapmultitarge)
        @ewd_file.debuggercmsisdapTab.cmsisdap_multicpu_enable(target, cmsisdapmulticpu)
        @ewd_file.debuggercmsisdapTab.cmsisdap_resetlist(target, cmsisdapresetlist)
      end

      # use Extra option for Debugegr
      # ==== arguments
      # target    - target name
      # commandlineoption     - command line option: string
      def set_jlink_script_file(target, commandlineoption, choose, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        if (!choose.nil?) && (choose.is_a?FalseClass)
          @ewd_file.extraoptionTab.use_command_line_options(target, false)
        else
          @ewd_file.extraoptionTab.use_command_line_options(target, true)
        end
        @ewd_file.extraoptionTab.set_command_line_options(target, commandlineoption)
      end

      # --------------------------------------------------------
      # Set debugger extra options
      # @param [String] target: target name
      # @param [Array] options: debugger extra options array
      # @return [nil]
      def set_debugger_extra_options(target, options, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.extraoptionTab.use_command_line_options(target, true)
        options&.each { |option| @ewd_file.extraoptionTab.set_debugger_extra_options(target, option) }
      end

      # enable multi-core master mode
      # ==== arguments
      # target    - target name
      # value     - value: ture/false
      def enable_multicore_master_mode(target, value, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.multicoreTab.multicore_master_mode(target, value)
      end

      # Set the slave workspace path
      # ==== arguments
      # target    - target name
      # value     - value: workspace patch of slave
      def set_slave_workspace(target, value, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.multicoreTab.slave_workspace(target, File.join('$PROJ_DIR$', value))
      end

      # Set the slave project name
      # ==== arguments
      # target    - target name
      # value     - value: slave project name
      def set_slave_project(target, value, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.multicoreTab.slave_project(target, value)
      end

      # Set the slave configuration
      # ==== arguments
      # target    - target name
      # value     - value: slave configuration
      def set_slave_configuration(target, value, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.multicoreTab.slave_configuration(target, value)
      end

      # enable download extra image
      # ==== arguments
      # target    - target name
      # value     - value: 1 or 2 or 3, enable specific download option item
      def enable_download_extra_image(target, value, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.imagesTab.download_extra_image(target, value)
      end

      # set image path
      # ==== arguments
      # target    - target name
      # value     - value: image path
      # order     - value: image order
      def set_image_path(target, value, order, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.imagesTab.image_path(target, value, order)
      end

      # set offset
      # ==== arguments
      # target    - target name
      # value     - value: offset value
      # order     - value: offset order
      def set_offset(target, value, order, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.imagesTab.offset(target, value, order)
      end

      # set debug info only option
      # ==== arguments
      # target    - target name
      # value     - value: true/false, set true to enable debug info only
      # order     - value: debug info only option order
      def set_debug_info_only(target, value, order, *_args, **_kwargs)
        Core.assert(!@ewd_file.nil?) do
          "no '.ewd' file set in templates"
        end
        @ewd_file.imagesTab.debug_info_only(target, value, order)
      end
    end
  end
end
