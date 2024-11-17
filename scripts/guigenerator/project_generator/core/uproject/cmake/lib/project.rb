# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/cmake/_project'
require_relative '../../internal/_lib_project_interface'
require_relative '../common/project'

module CMake
  module Lib

    class UProject < Internal::CMake::UProject
      # consuming interface
      include Internal::LibProjectInterface
      include CMake::CommonProject

      def initialize(param)
        super(param)
      end

      def copy_binary(target, path, rootdir: nil)
        @project_file.copy_output_file(target, path)
      end

      def clear!()
        @targets.each do |target|
          clear_assembler_include!(target)
          clear_compiler_include!(target)
          clear_compiler_macros!(target)
          clear_assembler_macros!(target)
          clear_libraries!(target)
        end
      end
    end
  end
end


