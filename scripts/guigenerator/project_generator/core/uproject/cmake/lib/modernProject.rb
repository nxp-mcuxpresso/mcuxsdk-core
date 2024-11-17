# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative './project'
require_relative 'files/config_modern'

module CMake
  module Lib

    class ModernCMakeUProject < CMake::Lib::UProject
      def initialize(param)
        super(param)
        template = @templates.first_by_regex(/CMakeLists.txt$/)
        @project_file = ConfigFileModern.new(template)
      end

      def add_module_path(path)
        @project_file.add_module_path(path)
      end

      def add_cmake_module(component)
        @project_file.add_cmake_module(component)
      end

      def add_hardware_info(project_info)
        @project_file.add_hardware_info(project_info)
      end

      def add_cmake_config(components)
        @project_file.add_cmake_config(components)
      end

      def add_assembler_include_for_target(target, supported_target, path, *args, **kwargs)
        @project_file.add_assembler_include_for_target(target, supported_target, path)
      end

    end

  end
end


