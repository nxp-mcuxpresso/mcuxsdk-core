# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../_flags'

module Internal
module CMake

    class Flags < Internal::Flags

        attr_reader :file

        def initialize(file, logger: nil)
            @file   = file
            @logger = logger ? logger : Logger.new(STDOUT)
        end

        private

        ###
        ### generic settings
        ###
        def linker_system_libraries(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            system_libraries = %w[-lm -lc -lgcc -lnosys -lc_nano -lcr_c -lcr_eabihelpers -lstdc++ -lstdc++_nano crti.o crtn.o crtbegin.o crtend.o -lcr_semihost -lcr_semihost_nf -lcr_semihost_mb -lcr_semihost_mb_nf -lcr_nohost_nf -lcr_newlib_semihost -lcr_newlib_nohost -lcr_newlib_none]
            matched_libs = []
            pattern = /\s-Wl,--start-group(\s.*|\S.*)-Wl,--end-group/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                libraries = result[1].lstrip.rstrip.split(/\s+/)
                libraries.each { |lib| matched_libs.push_uniq(lib) if system_libraries.include? lib }

                @file.add_linker_system_libraries(matched_libs) unless matched_libs.empty?

                no_matched_lib = libraries - matched_libs
                @file.add_linker_non_system_libraries(no_matched_lib) unless no_matched_lib.empty?

                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def linker_flags(target, line)
            line.split().each do |v|
                @file.add_linker_flags(target, v)
            end
        end
    end
end
end

