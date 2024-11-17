# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require 'fileutils'
require 'tempfile'


module Internal
module Xtensa

    class MakefileIncludeFile

        def initialize(template, *args, logger: nil, **kwargs)
            @config_makefileInclude = Tempfile.new('config_makefileInclude')
            @logger = logger ? logger : Logger.new(STDOUT)
            File.open(template, 'r').each_line do |line|
              @config_makefileInclude.puts line
            end
        end

        def save(path)
            @config_makefileInclude.close
        end

    end

end
end
