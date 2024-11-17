# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative './project'
require_relative '../../../uproject/cmake/app/traditionalProject'
require_relative '../../../uproject/cmake/app/files/config'

module CMake
  module App

    class IDEProjectTraditionalCMake < CMake::App::TraditionalCMakeUProject
      include CMake::App::CommonProject
    end
  end
end


