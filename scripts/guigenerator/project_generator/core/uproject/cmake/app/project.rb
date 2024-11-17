# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/cmake/_project'
require_relative '../../internal/_app_project_interface'
require_relative '../common/project'

module CMake
  module App

    class UProject < Internal::CMake::UProject
      attr_accessor :project_file
      # consuming interface
      include Internal::AppProjectInterface
      include CMake::CommonProject

      def initialize(param)
        super(param)
      end

      # Clear compiler include paths of target
      # ==== arguments
      # target    - target name
      def clear_cpp_compiler_include!(target)
        @project_file.clear_cpp_compiler_include!(target)
      end

      # Convert the binary file to dedicated format
      # ====arguments
      # target   - target name
      # path     - binary file path
      def converted_output_file(target, path, rootdir: nil)
        @project_file.converted_output_file(target, File.join('${ProjDirPath}', path))
      end

      # undefine compiler 'name' macro of 'value' to target
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def undefine_compiler_macro(target, name, value, *args, **kwargs)
        @project_file.undefine_compiler_macro(target, name, value)
      end

      # Clear all compiler macros of target
      # ==== arguments
      # target    - target name
      def clear_cpp_compiler_macros!(target)
        @project_file.clear_cxx_marcos!(target)
      end

      def add_link_library(target, library)
        @project_file.add_link_library(target, library)
      end

      def add_sys_link_library(target, library)
        @project_file.add_sys_link_library(target, library)
      end

      def clear!()
        @targets.each do |target|
          clear_assembler_include!(target)
          clear_compiler_include!(target)
          clear_cpp_compiler_include!(target)
          clear_compiler_macros!(target)
          clear_cpp_compiler_macros!(target)
          clear_assembler_macros!(target)
          clear_libraries!(target)
        end
      end

      # add linker file
      # ==== arguments
      # target    - target name
      # path      - linker file path
      def linker_file(target, path, *args, **kwargs)
        @project_file.linker_file(target, path)
      end

      # add prebuild command
      # @param [String] target: target name
      # @param [Array] command: prebuild command
      def add_prebuild_script(target, command)
        @project_file.add_prebuild_script(command)
      end

      def add_postbuild_script(target, command)
        @project_file.add_postbuild_script(command)
      end

      def add_precompile_command(target, command)
        @project_file.add_precompile_command(command)
      end
    end

  end
end


