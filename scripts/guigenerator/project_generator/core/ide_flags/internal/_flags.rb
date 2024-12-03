# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Internal

    class Flags

        attr_reader :file

        def initialize(file, *args, type: nil, logger: nil, **kwargs)
            @file   = file
            @type   = type.nil? ? 'c' : type
            if logger
                @logger = logger
            else
                @logger = Logger.new(STDOUT)
                @logger.level = Logger::WARN
            end
        end

        def is_cpp_type?
            return @type == 'cpp'
        end

        def is_c_type?
            return @type == 'c'
        end
    end

end

