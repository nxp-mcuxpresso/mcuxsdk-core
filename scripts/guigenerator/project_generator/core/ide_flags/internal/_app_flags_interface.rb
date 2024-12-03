# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Internal
module AppFlagsInterface

    def is_lib?() return false end
    def is_app?() return true end

    def analyze_asflags(target, line)
        line = line.strip()
        unless (line.empty?)
            @logger.error("unrecognized '#{target}' asflags '#{line}' ")
        end
    end

    def analyze_ccflags(target, line)
        line = line.strip()
        unless (line.empty?)
            @logger.error("unrecognized '#{target}' ccflags '#{line}' ")
        end
    end

    def analyze_cxflags(target, line)
        line = line.strip()
        unless (line.empty?)
            @logger.error("unrecognized '#{target}' cxflags '#{line}' ")
        end
    end

    def analyze_ldflags(target, line)
        line = line.strip()
        unless (line.empty?)
            @logger.error("unrecognized '#{target}' ldflags '#{line}' ")
        end
    end

end
end

