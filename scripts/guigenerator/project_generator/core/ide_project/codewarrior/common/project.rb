# frozen_string_literal: true

# ********************************************************************
# Copyright 2022, 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module CodeWarrior
  module Project
    def add_source(path, vdir, rootdir: nil, source_target: nil)
      # For Standalone project, the root path is added automatically.
      # It will report error if added by scripts.
      if ENV['standalone'] == 'true'
          return if File.basename(path) == path
      end
      path = path_mod(path, @output_dir)
      super(@project_file.project_parent_path(path), vdir)
    end

    def add_library(target, path, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('${xt_project_loc}', path))
    end

    def add_compiler_include(target, path, *args, vdir: nil, rootdir: nil)
      if path.match(/^\$\{\S+\}\S+/)
        path = '"' + path + '"'
        super(target, path)
      else
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end
    end

    def add_assembler_include(target, path, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('${ProjDirPath}', path))
    end

    def linker_file(target, path, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, File.join('${ProjDirPath}', path))
    end

    def add_lib_search_path(target, path, rootdir: nil)
      if path.match(/^\$\{\S+\}\S+/)
        path = '"' + path + '"'
        super(target, path)
      else
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end
    end

    def add_addl_lib(target, path, rootdir: nil)
      path.gsub!("\\\"", "")
      if path.match(/^\$\{\S+\}\S+/)
        path = '"' + path + '"'
        super(target, path)
      else
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end
    end

    def add_sys_search_path(target, path, rootdir: nil)
      path.gsub!("\\\"", "")
      if path.match(/^\$\{\S+\}\S+/)
        path = '"' + path + '"'
        super(target, path)
      else
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end
    end

    def add_sys_path_recursively(target, path, rootdir: nil)
      path.gsub!("\\\"", "")
      if path.match(/^\$\{\S+\}\S+/)
        path = '"' + path + '"'
        super(target, path)
      else
        path = path_mod(path, rootdir)
        super(target, File.join('${ProjDirPath}', path))
      end
    end

    def set_target_initialization_file(target, path, *args, rootdir: nil)
      path = File.relpath(
          @modifier.fullpath(@output_dir),
          @modifier.fullpath(path)
      )
      super(target, File.join('${ProjDirPath}', path))
    end

    def set_memory_config_file(target, path, rootdir: nil)
      path = File.relpath(
          @modifier.fullpath(@output_dir),
          @modifier.fullpath(path)
      )
      super(target, File.join('${ProjDirPath}', path))
    end

    def add_assembler_flag(target, flag)
      collect_assembler_flags(target, flag)
    end

    def add_compiler_flag(target, flag)
      collect_compiler_flags(target, flag)
    end

    def add_linker_flag(target, flag)
      collect_linker_flags(target, flag)
    end

    # empty implementation, to unify the function call in generator.rb
    def converted_output_file(target, path, rootdir: nil, cmd_param: nil)
    end

    def binary_file(target, path, rootdir: nil)
    end
  end
end
