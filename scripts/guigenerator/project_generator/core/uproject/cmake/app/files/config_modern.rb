# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require_relative '../../common/files/config_modern'

module CMake
  module App

    class ConfigFileModern < CMake::Common::ConfigFileModern

      def initialize(template, *args, logger: nil, **kwargs)
        super(template, *args, logger: nil, **kwargs)
        @build_type = "app"
      end
    end
  end
end