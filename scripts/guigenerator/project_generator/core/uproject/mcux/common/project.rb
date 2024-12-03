# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Mcux
  module CommonProject

    # Add meta-componet
    # ==== arguments
    # meta_componet    - meta component for each example
    def add_meta_component(meta_componet)
      @project_file.add_meta_component(meta_componet)
    end

    # Add source file
    # ==== arguments
    # path      - source file path
    # vdirexpr  - into virtual directory
    def add_source(path, vdir, filetype, toolchain, exclude)
      @project_file.add_source(path, vdir, filetype, toolchain, exclude)
    end

    # Clear all project sources
    def clear_sources!
      @project_file.clear_sources!
    end

    # Add compiler include path 'path' to target 'target'
    # ==== arguments
    # target    - target name
    # path      - include path
    def add_compiler_include(target, path, macro, *args, **kwargs)
      cmd = unless macro.nil? || macro
              "-include " + %Q{"#{path}"}
            else
              "-imacros " + %Q{"#{path}"}
            end
      @project_file.add_c_preinclude(target, cmd)
    end

    def add_mcux_include(target, path)
      @project_file.add_mcux_include(target, path)
    end

    # Add compiler include path 'path' to target 'target'
    # ==== arguments
    # target    - target name
    # path      - include path
    def add_cpp_compiler_include(target, path, *args, **kwargs)
      cmd = "-imacros " + %Q{"#{path}"}
      @project_file.add_cpp_preinclude(target, cmd)
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
      @project_file.add_cpp_compiler_macro(target, name, value)
    end

    # Set using c++ compiler
    def set_cpp_compiler(target, value)
      @project_file.set_project_ccnature()
    end

    # Add core info
    def add_core_info(corename, coreid)
      @project_file.add_core_info(corename, coreid)
    end

    def set_preinclude_file(target, path, macro, *args, **kwargs)
      cmd = unless macro.nil? || macro
              "-include " + %Q{"#{path}"}
            else
              "-imacros " + %Q{"#{path}"}
            end
      @project_file.add_c_preinclude(target, cmd)
    end
  end
end