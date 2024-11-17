# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require_relative '../../../internal/xtensa/files/_makefileInclude_file'


module Xtensa
module App

    class MakefileIncludeFile < Internal::Xtensa::MakefileIncludeFile

        def initialize(template, *args, logger: nil, **kwargs)
          super(template, *args, logger: nil, **kwargs)
        end

        def save(path)
        	super
          if ! File.directory?(File.dirname(path))
            FileUtils.mkdir_p File.dirname(path).gsub("\\", "/")
          end
          FileUtils.mv @config_makefileInclude.path, path
        end

    end
end
end