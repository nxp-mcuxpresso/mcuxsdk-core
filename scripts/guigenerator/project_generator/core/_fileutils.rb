# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'fileutils'


module FileUtils

    def self.cp_f(source, target)
        target_dir = File.dirname(target)
        unless File.directory?(target_dir)
            FileUtils.mkdir_p(target_dir)
        end
        FileUtils.cp(source, target)
    end

end


