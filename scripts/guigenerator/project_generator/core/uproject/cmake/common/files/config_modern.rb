# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require_relative '../../../internal/cmake/files/_config_modern'

module CMake
  module Common

    class ConfigFileModern < Internal::CMake::ConfigFileModern

      def initialize(template, *args, logger: nil, **kwargs)
        super(template, *args, logger: nil, **kwargs)
      end

      def save(path)
        generated_files = super
        if ! File.directory?(File.dirname(path))
          FileUtils.mkdir_p File.dirname(path).gsub("\\", "/")
        end
        FileUtils.mv @config_cmakelists.path, path
        generated_files.push_uniq path
      end
    end
  end
end