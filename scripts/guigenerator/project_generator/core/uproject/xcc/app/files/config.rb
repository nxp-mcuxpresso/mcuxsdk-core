# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require_relative '../../../internal/xcc/files/_config'


module Xcc
module App

    class ConfigFile < Internal::Xcc::ConfigFile

        def initialize(template, *args, logger: nil, **kwargs)
          super(template, *args, logger: nil, **kwargs)
          @build_type = "app"
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