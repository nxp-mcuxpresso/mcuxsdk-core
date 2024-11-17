# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative './project'
require_relative '../../../uproject/cmake/lib/traditionalProject'
require_relative '../../../uproject/cmake/lib/files/config'

module CMake
  module Lib

    class IDEProjectTraditionalCMake < CMake::Lib::TraditionalCMakeUProject
      include CMake::Lib::CommonProject
    end
  end
end


