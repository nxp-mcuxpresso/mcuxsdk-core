# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Iar
  module Project
    def add_source(path, vdir, rootdir: nil, source_target: nil)
      path = path_mod(path, rootdir)
      super(File.join('$PROJ_DIR$', path), vdir)
    end

    # add assembler include path 'path' to target 'target'
    # ==== arguments
    # target    - target name
    # path      - include path
    # type      - ['project', 'runtime']
    def add_assembler_include(target, path, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('$PROJ_DIR$', path))
    end

    # add assembler include path 'path' to target 'target'
    # ==== arguments
    # target    - target name
    # vdir      - virtual directory
    # path      - include path
    # type      - ['project', 'runtime']
    def add_compiler_include(target, path, *_args, vdir: nil, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('$PROJ_DIR$', path))
    end

    def set_preinclude_file(target, path, macro, linked_support, vdir: nil, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('$PROJ_DIR$', path))
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

    def set_dlib_config_file(target, path, absolute, rootdir: nil)
      unless absolute
        path = path_mod(path, rootdir)
        path = File.join('$PROJ_DIR$', path)
      end
      super(target, path)
    end

    def exclude_building_for_target(target, path, exclude, vdir, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('$PROJ_DIR$', path, "virtual-dir", vdir), exclude)
    end

    def add_rte_globals(name, family, variant, core_name, core_id)
      @ewp_file.add_rte_globals(name, family, variant, core_name, core_id)
    end

    def add_rte_component(cmsis_info)
      @ewp_file.add_rte_component(cmsis_info)
    end

  end
end
