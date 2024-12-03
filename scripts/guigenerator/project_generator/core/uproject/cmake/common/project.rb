# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module CMake
  module CommonProject

    # Save project
    def save(output_dir)
      Core.assert(output_dir.is_a?(String)) do
        "output dir is not a string '#{output_dir}'"
      end
      @logger.debug("generate project: #{@name}")

      path = File.join(output_dir, "CMakeLists.txt")
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
    def add_source(path, vdir)
      @project_file.add_source(path)
    end

    def set_config_file_property(path, comp_name)
      @project_file.set_config_file_property(path, comp_name)
    end

    # add cmake file
    def add_cmake_file(path, cache_dir)
      @project_file.add_cmake_file(path, cache_dir)
    end

    def set_build_dir(target, build_dir)
      @project_file.set_build_dir(target, build_dir)
    end

    # Clear all project sources
    def clear_sources!
      @project_file.clear_sources!
    end

    # Add assembler include path 'path' to target 'target'
    # ==== arguments
    # target    - target name
    # path      - include path
    def add_assembler_include(target, path, *args, **kwargs)
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
    def add_compiler_include(target, path, *args, **kwargs)
      if path =~ /--pre:/
        rpath = "-include " + path.gsub("--pre:", '')
        @project_file.add_cc_flags(target, rpath)
      else
        @project_file.add_compiler_include(target, path)
      end
    end

    def set_preinclude_file(target, path, *_args, **_kwargs)
      path = "-include " + path
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
    def add_cpp_compiler_include(target, path, *args, **kwargs)
      if path =~ /--pre:/
        rpath = "-include " + path.gsub("--pre:", '')
        @project_file.add_cxx_flags(target, rpath)
      else
        @project_file.add_cpp_compiler_include(target, path)
      end
    end

    # Add assembler 'name' macro of 'value' to target
    # ==== arguments
    # target    - target name
    # name      - name of macro
    # value     - value of macro
    def add_assembler_macro(target, name, value, *args, **kwargs)
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
    def add_compiler_macro(target, name, value, *args, **kwargs)
      @project_file.add_compiler_macro(target, name, value)
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
    def add_cpp_compiler_macro(target, name, value, *args, **kwargs)
      @project_file.add_cxx_marco(target, name, value)
    end

    # Add library to target
    def add_library(target, library, *args, **kwargs)
      @project_file.add_library(target, library)
    end

    # Clear all libraries
    def clear_libraries!(target)
      @project_file.clear_libraries!(target)
    end

    # set cmake variables
    def set_cmake_variables(variables)
      @project_file.set_cmake_variables variables
    end

    # set cmake variables
    def set_cmake_command(command)
      @project_file.set_cmake_command command
    end

    # exclude from building for specific target
    def exclude_building_for_target(target, path, exclude)
      @project_file.exclude_building(target, path, exclude)
    end
  end
end


