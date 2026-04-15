# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/codewarrior/_project'
require_relative './files/project_file'
require_relative './files/cproject_file'
require_relative '../../internal/_app_project_interface'
require_relative './files/debug_launcher_file'
require_relative './files/referencedRSESystems_file'
require_relative '../common/project'
require 'securerandom'

module CodeWarrior
  module App
    class UProject < Internal::CodeWarrior::UProject
      # consuming interface
      include Internal::AppProjectInterface
      include CodeWarrior::CommonProject
      attr_reader :project_file
      attr_reader :cproject_file
      attr_reader :debug_launcher_files
      attr_reader :refRSESys_file

      def initialize(param)
        super(param)
        # .project
        template = @templates.first_by_regex(/\.project$/)
        Core.assert(!template.nil?) do
          "no '.project' file in templates"
        end
        @project_file = ProjectFile.new(template, logger: @logger)
        # .cproject
        @cproject_template = @templates.first_by_regex(/\.cproject\S+$/)
        Core.assert(!template.nil?) do
          "no '.cproject' file in templates"
        end
        @cproject_file = CprojectFile.new(@cproject_template, logger: @logger)

        # setup project name
        @project_file.projectname(@name)
        @cproject_file.update_cdt_build_system(@name)

        param[:targets].each do |target|
          # setup targets
          @cproject_file.set_target_name target
          # setup artifact
          @cproject_file.artifact_name(target, @name)
          @cproject_file.artifact_extension(target, 'elf')
        end

        # generate res id and uuid map for debug files
        res_uuid_map =  generate_map(param[:project_name])
        # debug scripts
        @debug_launcher_files = []
        @templates.all_by_regex(/(?i)\S+\.launch$/).each do | file |
          param[:targets].each do |target|
            file_name = @name + '_' + target + '_' + File.basename(file)
            @debug_launcher_files.push(DebugLauncherFile.new(file, file_name, target, res_uuid_map, logger: @logger))
          end
        end

        # debug management file
        template = @templates.first_by_regex(/ReferencedRSESystems.xml$/)
        Core.assert(!template.nil?) do
          "no 'ReferencedRSESystems.xml' file in templates"
        end
        debug_files = @debug_launcher_files.map { |file| file.debugger}.uniq
        @refRSESys_file = ReferencedRSESystems.new(template, param[:targets], debug_files, res_uuid_map, logger: @logger)

        # state for per-core init/mem properties in ReferencedRSESystems.xml
        corename = param[:corename].to_s
        @core_arch = corename.sub(/^dsp/i, '').upcase
        @chip_info_per_target = {}
        @init_file_per_target = {}
        @initialize_targets_flags = {}
        @mem_file_per_target = {}
        @mem_config_targets_flags = {}
      end

      # save project
      def save(output_dir)
        Core.assert(output_dir.is_a?(String)) do
          "output dir is not a string '#{output_dir}'"
        end
        @logger.debug("generate project: #{@name}")
        generated_files = []
        # save .project
        path = File.join(output_dir, '.project')
        @project_file.save(path)
        generated_files.push_uniq path
        @generated_hook.notify(path)
        # save .cproject
        path = File.join(output_dir, '.cproject')
        @cproject_file.save(path)
        generated_files.push_uniq path
        # remove template file
        File.delete(@cproject_template) if File.exist? @cproject_template
        @generated_hook.notify(path)
        # save debugger launcher file
        @debug_launcher_files.each do | launcher |
          path = File.join(output_dir, launcher.filename)
          launcher.save(path)
          generated_files.push_uniq path
          @generated_hook.notify(path)
        end
        # save debug management file
        path = File.join(output_dir, 'ReferencedRSESystems.xml')
        @refRSESys_file.save path
        generated_files.push_uniq path
        @generated_hook.notify(path)
        generated_files
      end

      def set_chip_for_debug_launcher(target, chipset, chip, rootdir: nil)
        @chip_info_per_target[target] = { chipset: chipset, chip: chip }
        @debug_launcher_files.each { |file| file.set_debug_processor(chipset, chip) if file.target == target }
        @refRSESys_file.set_debug_systemType(target, chipset, chip)
      end

      def set_target_initialization_file(target, path, rootdir: nil)
        @init_file_per_target[target] = path
        @debug_launcher_files.each { |file| file.set_debug_init_file(path) if file.target == target }
        @refRSESys_file.set_debug_init_file(target, path)
      end

      def set_memory_config_file(target, path, rootdir: nil)
        @mem_file_per_target[target] = path
        @debug_launcher_files.each { |file| file.set_memory_config_file(path) if file.target == target }
        @refRSESys_file.set_memory_config_file(target, path)
      end

      def add_chipdefine_macro(target, chip_info)
        chipset, chip = chip_info.split(/\s+/)
        set_chip_for_debug_launcher(target, chipset, chip)
      end

      def add_sharing_project(path)
        project_name = File.basename(path)
        # Replace the toolchain folder (parent of project name) with 'codewarrior'
        location_dir = File.join(File.dirname(File.dirname(path)), 'codewarrior')
        location_dir = @project_file.project_parent_path(location_dir)
        @project_file.add_project_reference(project_name, "file:/#{location_dir}")
      end

      def flag_apply_targets(target, apply_targets_str, attribute_type)
        case attribute_type
        when 'target_initialization_file'
          @initialize_targets_flags[target] = apply_targets_str
        when 'memory_config_file'
          @mem_config_targets_flags[target] = apply_targets_str
        end
      end

      def set_connected_targets(target, connected_targets_str)
        core_indices = connected_targets_str.split(/\s+/)
                                            .filter_map { |id| id[/_core(\d+)$/i, 1]&.to_i }
                                            .sort
        @debug_launcher_files.each do |file|
          next unless file.target == target
          if core_indices.length > 1
            file.set_smp(true)
            file.set_core_index(core_indices.first)
            file.set_smp_cores(core_indices)
          elsif core_indices.length == 1
            file.set_core_index(core_indices.first)
            file.set_smp_cores(core_indices)
          end
        end
        if @chip_info_per_target[target]
          chip_info = @chip_info_per_target[target]
          if @initialize_targets_flags[target] && @init_file_per_target[target]
            @refRSESys_file.set_per_core_init_properties(
              target, @initialize_targets_flags[target],
              @init_file_per_target[target],
              chip_info[:chipset], chip_info[:chip],
              @core_arch
            )
          end
          if @mem_config_targets_flags[target] && @mem_file_per_target[target]
            @refRSESys_file.set_per_core_mem_config_properties(
              target, @mem_config_targets_flags[target],
              @mem_file_per_target[target],
              chip_info[:chipset], chip_info[:chip],
              @core_arch
            )
          end
        end
      end

    end
  end
end
