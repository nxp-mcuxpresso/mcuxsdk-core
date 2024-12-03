# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/xcc/_project'
require_relative 'files/config'
require_relative '../../internal/_app_project_interface'

module Xcc
  module App
    class UProject < Internal::Xcc::UProject
      attr_accessor :project_file

      # consuming interface
      include Internal::AppProjectInterface

      def initialize(param)
        super(param)
        template = @templates.first_by_regex(/CMakeLists.txt$/)
        @project_file = ConfigFile.new(template, param[:targets])
      end

      # Save project
      def save(output_dir)
        Core.assert(output_dir.is_a?(String)) do
          "output dir is not a string '#{output_dir}'"
        end
        @logger.debug("generate project: #{@name}")

        path = File.join(output_dir, 'CMakeLists.txt')
        @project_file.save(path)
      end

      def set_toolchainfile_path(tool_name, path)
        @project_file.set_toolchainfile_path(tool_name, path)
      end

      def targets(target)
        @targets = target
      end

      # Add source file
      # ==== arguments
      # path      - source file path
      # vdirexpr  - into virtual directory
      def add_source(path, _vdir)
        @project_file.add_source(path)
      end

      def add_target_source(path, targets, _vdir)
        @project_file.add_target_source(path, targets)
      end

      # Clear all project sources
      def clear_sources!
        @project_file.clear_sources!
      end

      # Add assembler include path 'path' to target 'target'
      # ==== arguments
      # target    - target name
      # path      - include path
      def add_assembler_include(target, path, *_args, **_kwargs)
        @project_file.add_assembler_include(target, path)
      end

      # Clear assembler include paths of target
      # ==== arguments
      # target    - target name
      def clear_assembler_include!(target)
        @project_file.clear_assembler_include!(target)
      end

      # Add compiler include path 'path' to target 'target'
      # ==== arguments
      # target    - target name
      # path      - include path
      def add_compiler_include(target, path, *_args, **_kwargs)
        if path =~ /--pre:/
          rpath = '-include ' + path.gsub('--pre:', '')
          @project_file.add_cc_flags(target, rpath)
        else
          @project_file.add_compiler_include(target, path)
        end
      end

      def set_preinclude_file(target, path, *_args, **_kwargs)
        path = '-include ' + path
        @project_file.add_cc_flags(target, path)
      end

      # Clear compiler include paths of target
      # ==== arguments
      # target    - target name
      def clear_compiler_include!(target)
        @project_file.clear_compiler_include!(target)
      end

      # Add compiler include path 'path' to target 'target'
      # ==== arguments
      # target    - target name
      # path      - include path
      def add_cpp_compiler_include(target, path, *_args, **_kwargs)
        if path =~ /--pre:/
          rpath = '-include ' + path.gsub('--pre:', '')
          @project_file.add_cxx_flags(target, rpath)
        else
          @project_file.add_cpp_compiler_include(target, path)
        end
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
        @project_file.converted_output_file(target, path)
      end

      def add_binary_options(target, path, option)
        @project_file.add_binary_options(target, path, option)
      end

      # Add assembler 'name' macro of 'value' to target
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def add_assembler_macro(target, name, value, *_args, **_kwargs)
        @project_file.add_assembler_macro(target, name, value)
      end

      # Clear all assembler macros of target
      # ==== arguments
      # target    - target name
      def clear_assembler_macros!(target)
        @project_file.clear_assembler_macros!(target)
      end

      # Add compiler 'name' macro of 'value' to target
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def add_compiler_macro(target, name, value, *_args, **_kwargs)
        @project_file.add_compiler_macro(target, name, value)
      end

      # undefine compiler 'name' macro of 'value' to target
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def undefine_compiler_macro(target, name, value, *_args, **_kwargs)
        @project_file.undefine_compiler_macro(target, name, value)
      end

      # Clear all compiler macros of target
      # ==== arguments
      # target    - target name
      def clear_compiler_macros!(target)
        @project_file.clear_compiler_macros!(target)
      end

      # Add compiler 'name' macro of 'value' to target
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def add_cpp_compiler_macro(target, name, value, *_args, **_kwargs)
        @project_file.add_cxx_marco(target, name, value)
      end

      # Clear all compiler macros of target
      # ==== arguments
      # target    - target name
      def clear_cpp_compiler_macros!(target)
        @project_file.clear_cxx_marcos!(target)
      end

      # Add library to target
      def add_link_library(target, library)
        @project_file.add_link_library(target, library)
      end

      def add_sys_link_library(target, library)
        @project_file.add_sys_link_library(target, library)
      end

      # Add library to target
      def add_library(target, library, *_args, **_kwargs)
        @project_file.add_library(target, library)
      end

      # Clear all libraries
      def clear_libraries!(target)
        @project_file.clear_libraries!(target)
      end

      def clear!
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
      def linker_file(target, path, *_args, **_kwargs)
        @project_file.linker_file(target, path)
      end
    end
  end
end
