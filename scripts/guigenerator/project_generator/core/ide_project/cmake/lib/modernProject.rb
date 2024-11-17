# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative './project'
require_relative '../../../uproject/cmake/lib/modernProject'
require_relative '../../../uproject/cmake/lib/files/config_modern'

module CMake
  module Lib

    class IDEProject < CMake::Lib::ModernCMakeUProject
      include CMake::Lib::CommonProject

      def add_module_path(path, rootdir: nil)
        if is_underneath(Pathname.new(@output_dir).parent.to_s, path)
          path = path_mod(path, rootdir)
          super(File.join('${ProjDirPath}', path))
        else
          super(File.join('${SdkRootDirPath}', path))
        end
      end

      def add_cmake_module(component)
        super(component)
      end

      def add_hardware_info(project_info)
        super(project_info)
      end

      def add_cmake_config(components)
        super(components)
      end

      def add_assembler_include_for_target(target, supported_targets, path, rootdir: nil)
        if is_underneath(Pathname.new(@output_dir).parent.to_s, path)
          path = path_mod(path, rootdir)
          super(target, supported_targets, File.join('${ProjDirPath}', path))
        else
          super(target, supported_targets, File.join('${SdkRootDirPath}', path))
        end
      end

      def copy_binary(target, path, rootdir: nil)
        path = path_mod(path, rootdir)
        super(target, File.join('${LIBRARY_OUTPUT_PATH}/..', path))
      end
    end
  end
end


