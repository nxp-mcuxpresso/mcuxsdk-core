# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Mdk
  module Project
    def add_source(path, vdir, rootdir: nil, source_target: nil)
      path = path_mod(path, rootdir)
      super(path, vdir, source_target)
    end

    def set_source_alwaysBuild(path, vdir, targets, alwaysBuild)
      super(File.basename(path), vdir, targets, alwaysBuild)
    end

    # add assembler include path 'path' to target 'target'
    # ==== arguments
    # target    - target name
    # path      - include path
    # type      - ['project', 'runtime']
    def add_assembler_include(target, path, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, path)
    end

    # add compiler include path 'path' to target 'target'
    # ==== arguments
    # target    - target name
    # path      - include path
    # vdir      - virtual directory
    # type      - ['project', 'runtime']
    def add_compiler_include(target, path, *args, vdir: nil, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, path)
    end

    def set_preinclude_file(target, path, macro, linked_support, vdir: nil, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, path)
    end

    def add_assembler_flag(target, flag)
      collect_assembler_flags(target, flag)
    end

    def add_chipdefine_macro(target, flag)
      collect_chipdefines_flags(target, flag)
    end

    def add_compiler_flag(target, flag)
      collect_compiler_flags(target, flag)
    end

    def add_cpp_compiler_flag(target, flag)
      collect_cpp_compiler_flags(target, flag)
    end

    def binary_file(target, path, rootdir: nil)
      path = File.relpath(
          @modifier.fullpath(@output_dir),
          @modifier.fullpath(path)
      )
      # setup output of binary file
      @uvprojx_file.outputTab.folder(target, File.dirname(path))
      @uvprojx_file.outputTab.executable_name(target, File.basename(path))
    end

    def create_hex_file(target, value)
      @uvprojx_file.outputTab.create_hex_file(target, value)
    end

    def exclude_building_for_target(target, path, exclude, *args, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, path, exclude)
    end

    def add_rte_component(cmsis_info)
      @uvprojx_file.add_rte_component(cmsis_info)
    end
  end
end
