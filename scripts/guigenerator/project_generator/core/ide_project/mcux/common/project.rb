# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Mcux
  module Project

    def add_meta_component(meta_component)
      # Should check whether is nil first
      if @platform_devices_soc_name
        meta_component = (meta_component + '.' + @platform_devices_soc_name)
      end
      super(meta_component)
    end

    def add_source(path, vdir, toolchain, exclude, type, rootdir: nil)
      path = path_mod(path, rootdir)
      if vdir
        if vdir.include?(':')
          vdir = vdir.split(':').join('/')
        end
      else
        # if nil==vdir, give the default 'src' same with other IDE.
        vdir = 'src'
      end
      if type.nil?
        filetype = get_file_type(path, toolchain)
      else
        filetype = type
      end
      super(path, vdir, filetype, toolchain, exclude)
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

    def add_mcux_include(target, path, rootdir: nil)
      path = path_mod(path, rootdir)
      super(target, path)
    end

    def add_compiler_include(target, path, macro, linked, vdir: nil, rootdir: nil)
      if path =~ /--pre:/
        if linked
          super(target, File.basename(path), macro)
        else
          vdir = "source" unless vdir
          super(target, File.join('${ProjDirPath}', vdir, File.basename(path)), macro)
        end
      end
    end

    def set_preinclude_file(target, path, macro, linked_support, vdir: nil, rootdir: nil)
      if linked_support
        super(target, File.basename(path), macro)
      else
        vdir = "source" unless vdir
        super(target, File.join('${ProjDirPath}', vdir, File.basename(path)), macro)
      end
    end

    def add_cpp_compiler_include(target, path, vdir, rootdir: nil)
      if path =~ /--pre:/
        super(target, File.join('${ProjDirPath}', vdir, File.basename(path)))
      end
    end

    # Set the type of source files:
    # xpath: /examples/example/source[@type=VALUE]
    def path_mod(path, rootdir)
      if rootdir == 'project-path'
        path = File.join(@output_dir, path)
        path = Pathname.new(path).cleanpath.to_s
      end
      return path
    end

    # set the postbuild cmd
    # ==== arguments
    # target    - the target of project
    # cmd       - the command
    # item      - just aligned with other toolchains, no practical effect.
    def add_postbuild_script(target, cmd, item: 1)
      super(target, cmd)
    end

    # Just keep the following interface
    def binary_file(target, path, rootdir: nil)
    end

    def converted_output_file(target, path, rootdir: nil, cmd_param: nil)
    end

    def add_library(target, path, rootdir: nil)
    end

  end
end

