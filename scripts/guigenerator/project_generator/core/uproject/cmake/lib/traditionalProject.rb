# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative './project'
require_relative 'files/config'

module CMake
  module Lib

    class TraditionalCMakeUProject < CMake::Lib::UProject
      def initialize(param)
        super(param)
        template = @templates.first_by_regex(/CMakeLists.txt$/)
        @project_file = ConfigFile.new(template)
      end

    end

  end
end


