# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/mcux/_project'
require_relative '../../mcux/app/files/mcux_project_definition_xml'
require_relative '../../internal/_app_project_interface'
require_relative '../common/project'

module Mcux
  module App

    class UProject < Internal::Mcux::UProject
      attr_accessor :project_file
      # consuming interface
      include Internal::AppProjectInterface
      include Mcux::CommonProject

      def initialize(param)
        super(param)
        template = @templates.first_by_regex(/mcux_template.xml$/)
        @project_file = ProjectDefinitionXml.new(template, param[:manifest_version], param[:manifest_schema_dir])
      end

      # Save project
      def save(output_dir)
        Core.assert(output_dir.is_a?(String)) do
          "output dir is not a string '#{output_dir}'"
        end
        @logger.debug("generate project: #{@name}")

        project_definition_xml_name = @name + '.xml'
        path = File.join(output_dir, project_definition_xml_name)
        @project_file.save(path)
      end

      # Get list of all available targets
      def targets
        return @project_file.targets
      end

      def add_toolchain(toolchains)
        @project_file.add_toolchain(toolchains)
      end

      def add_linker_file(target, path)
        @project_file.add_linker_file(target, path)
      end

      def add_sys_link_library(target, library)
        @project_file.clinker_set_option_lib(target, library)
        @project_file.cpplinker_set_option_lib(target, library)
      end

      # Clear compiler include paths of target
      # ==== arguments
      # target    - target name
      def clear_compiler_include!(target)
        @project_file.clear_compiler_include!(target)
      end

      # Clear core info
      # ==== arguments
      def clear_core_info!()
        @project_file.clear_core_info!()
      end

      # Clear linked project
      # ==== arguments
      def clear_linked_project!()
        @project_file.clear_linked_project!()
      end

      # Clear all compiler macros of target
      # ==== arguments
      # target    - target name
      def clear_cpp_compiler_macros!(target)
        @project_file.clear_cxx_marcos!(target)
      end

      #Add library to target
      def add_link_library(target, path, filetype, toolchain, virtual_dir)
        @project_file.add_link_library(target, path, filetype, toolchain, virtual_dir)
      end

      # Add linked project infro
      def add_linked_project(linked_project)
        @project_file.add_linked_project(linked_project)
      end

      def add_trustzone_preprogram(trustzone_preprogram)
        @project_file.add_trustzone_preprogram(trustzone_preprogram)
      end

      def add_secure_gateway_importlib(secure_gateway_importlib)
        @project_file.add_secure_gateway_importlib(secure_gateway_importlib)
      end

      def set_secure_gateway_placement(secure_gateway_placement)
        @project_file.set_secure_gateway_placement(secure_gateway_placement)
      end

      def gen_secure_gateway_importlib(secure_gateway_importlib_gen)
        @project_file.gen_secure_gateway_importlib(secure_gateway_importlib_gen)
      end

      def set_heap_stack_placement(gen_cpp, heap_stack_placement)
        @project_file.set_heap_stack_placement(gen_cpp, heap_stack_placement)
      end

      def enable_crp_in_image(target, enable_crp)
        @project_file.enable_crp_in_image(target, enable_crp)
      end

      # Set multicore configuration
      def configure_slaves(target, configuration)
        mastervalue = configuration
        masteruserobjs = configuration.split(',')[1]
        @project_file.configure_slaves(target, mastervalue, masteruserobjs)
      end

      # Set cpp multicore configuration for master device
      def configure_cpp_slaves(target, configuration)
        mastervalue = configuration
        masteruserobjs = configuration.split(',')[1]
        @project_file.configure_cpp_slaves(target, mastervalue, masteruserobjs)
      end

      # Set multicore configuration for master device
      def set_multicore_configuration(target, configuration)
        @project_file.set_multicore_configuration(target, configuration)
      end

      # Set cpp multicore configuration for master device
      def set_cpp_multicore_configuration(target, configuration)
        @project_file.set_cpp_multicore_configuration(target, configuration)
      end

      # Set memory sections
      def set_memory_sections(section_configs)
        @project_file.set_memory_sections(section_configs)
      end

      # Set memory configuration
      def set_debug_configuration(flash_id, driver_path)
        @project_file.set_debug_configuration(flash_id, driver_path)
      end

      # Add undefine symbol for mcux
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def undefine_compiler_macro(target, name, value)
        @project_file.undefine_compiler_macro(target, name, value)
      end

      def set_jlink_script_file(target, value)
        @project_file.set_jlink_script_file(target, value)
      end

      def clear_undefine_macro!(target)
        @project_file.clear_undefine_macro!(target)
      end

      def clear!()
        targets.each do |target|
          clear_compiler_macros!(target)
          clear_cpp_compiler_macros!(target)
          clear_assembler_macros!(target)
          clear_compiler_include!(target)
          clear_undefine_macro!(target)
        end
        clear_core_info!()
        clear_linked_project!()
      end

      def add_prebuild_script(target, cmd)
        @project_file.add_prebuild_script(target, cmd)
      end

      def add_postbuild_script(target, cmd)
        @project_file.add_postbuild_script(target, cmd)
      end
    end
  end
end

