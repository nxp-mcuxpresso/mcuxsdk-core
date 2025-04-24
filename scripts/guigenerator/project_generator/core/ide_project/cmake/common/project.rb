# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module CMake
  module Project

    def add_source(path, vdir, rootdir: nil, source_target: nil)
      path = path_mod(path, rootdir)
      super(File.join('${ProjDirPath}', path), vdir)
    end

    def set_config_file_property(path, comp_name, rootdir: nil)
      path = path_mod(path, rootdir)
      super(File.join('${ProjDirPath}', path), comp_name)
    end

    def add_cmake_file(path, cache_dir, rootdir: nil)
      path = path_mod(path, rootdir)
      super(File.join('${ProjDirPath}', path), cache_dir)
    end

    def set_build_dir(target, path, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, path)
    end

    def targets(targets)
      super(targets)
    end

    def add_assembler_include(target, path, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('${ProjDirPath}', path))
    end

    def add_compiler_include(target, path, *args, vdir: nil, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('${ProjDirPath}', path))
    end

    def set_preinclude_file(target, path, macro, linked_support, vdir: nil, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('${ProjDirPath}', path))
    end

    def add_postbuild_script(target, cmd)
      super(target, cmd)
    end

    def add_prebuild_script(target, cmd)
      super(target, cmd)
    end

    def add_cpp_compiler_include(target, path, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('${ProjDirPath}', path))
    end

    def binary_file(target, path, rootdir: nil)
      binary_path = File.relpath(
          @modifier.fullpath(@output_dir),
          @modifier.fullpath(path)
      )
      @project_file.add_target(target, binary_path)
    end

    def add_assembler_flag(target, flag)
      collect_assembler_flags(target, flag)
    end

    def add_compiler_flag(target, flag)
      collect_compiler_flags(target, flag)
    end

    def add_cpp_compiler_flag(target, flag)
      collect_cpp_compiler_flags(target, flag)
    end

    def add_archiver_flag(target, flag)
      collect_archiver_flags(target, flag)
    end

    def exclude_building_for_target(target, path, exclude, *args, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('${ProjDirPath}',path), exclude)
    end
  end
end


