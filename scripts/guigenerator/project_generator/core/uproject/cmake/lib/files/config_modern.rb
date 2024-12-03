# ********************************************************************
# Copyright 2022 NXP
# ********************************************************************
require_relative '../../common/files/config_modern'

module CMake
  module Lib

    class ConfigFileModern < CMake::Common::ConfigFileModern

      def initialize(template, *args, logger: nil, **kwargs)
        super(template, *args, logger: nil, **kwargs)
        @build_type = "library"
      end
    end
  end
end