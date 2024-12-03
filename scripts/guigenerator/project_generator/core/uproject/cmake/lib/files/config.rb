# ********************************************************************
# Copyright 2022 NXP
# ********************************************************************
require_relative '../../common/files/config'

module CMake
  module Lib

    class ConfigFile < CMake::Common::ConfigFile

      def initialize(template, *args, logger: nil, **kwargs)
        super(template, *args, logger: nil, **kwargs)
        @build_type = "library"
      end
    end
  end
end