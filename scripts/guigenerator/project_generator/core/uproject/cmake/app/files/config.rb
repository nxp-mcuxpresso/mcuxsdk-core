# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-ClauseS
# ********************************************************************

require_relative '../../common/files/config'

module CMake
  module App

    class ConfigFile < CMake::Common::ConfigFile

      def initialize(template, *args, logger: nil, **kwargs)
        super(template, *args, logger: nil, **kwargs)
        @build_type = "app"
      end
    end
  end
end