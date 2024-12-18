# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../_flags'

module Internal
module Mdk

    class Flags < Internal::Flags

        @compiler = 'armcc'

        def set_compiler(comp)
            @compiler = comp
        end

        private

        def common_browse_info(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s-b\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.outputTab.browse_info(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.outputTab.browse_info(target, false)
            end
            return line
        end

        def common_device(target, line)
            result = line.split("\t")[0]
            @file.deviceTab.device(target, result) if result
            result = line.split("\t")[1]
            @file.deviceTab.vendor(target, result) if result
            return line
        end

        def common_cpu_type(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # cpu
            pattern = /(?i)\s--cpu(=|\s+)(\S+)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.deviceTab.cpu_type(target, result[ 2 ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("no --cpu flag")
            end
            return line
        end

        def common_debug_info(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s-g\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.outputTab.debug_info(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.outputTab.debug_info(target, false)
            end
            return line
        end

        def compiler_preinclude_file(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s-include\s+(\S+)/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.add_misc_flag(target, result[ 0 ])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def common_endian(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--(li|bi)\s|(?i)\s-m(little|big)-endian\s/
            result  = line.match(pattern)
            if (result)
                convert = {'li' => false, 'bi' => true, 'little' => false, 'big' => true }
                @logger.debug("recognize: #{result[ 0 ]}")
                order = @compiler == 'armcc' ? result[1] : result[2]
                @file.targetTab.big_endian(target, convert[ order ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing common flags: --li | --bi")
            end
            return line
        end

        def compiler_secure(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s-(mcmse)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.targetTab.secure(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.targetTab.secure(target, false)
                @logger.debug("missing flags: -mcmse ")
            end
            return line
        end

        def compiler_lto(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            return line unless @compiler == 'armclang'
            pattern = /(?i)\s-f(lto|no-lto)\s/
            result  = line.match(pattern)
            if (result)
                convert = { 'lto' => 1, 'no-lto' => 0 }
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.lto(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_optimization(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern =  if @compiler == 'armcc'
                           /(?i)\s-(O[0123]+)\s/
                       else
                           /(?i)\s-(O(0|1|2|3|fast|s|z))\s/
                       end
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimization(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            elsif @compiler == 'armclang'
                # Set armclang optimization level as O1 by default
                @file.compilerTab.optimization(target, 'O1')
            else
                @logger.debug("missing flags: -O0 | -O1 | -O2 | -O3 ")
            end
            return line
        end

        def compiler_split_section(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--split_sections|-ffunction-sections)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.one_elf_section_per_function(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.one_elf_section_per_function(target, false)
            end
            return line
        end

        def compiler_ro_independent(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            return line unless @compiler == 'armclang'
            pattern = /(?i)\s-f(ropi|no-ropi)\s/
            result  = line.match(pattern)
            if (result)
                convert = { 'ropi' => true, 'no-ropi' => false }
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.ro_independent(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_rw_independent(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            return line unless @compiler == 'armclang'
            pattern = /(?i)\s-f(rwpi|no-rwpi)\s/
            result  = line.match(pattern)
            if (result)
                convert = { 'rwpi' => true, 'no-rwpi' => false }
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.rw_independent(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_enum_is_int(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--enum_is_int\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.enum_is_always_int(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.enum_is_always_int(target, false)
            end
            return line
        end

        def compiler_short_enums_wchar(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            return line unless @compiler == 'armclang'
            pattern_enum = /(?i)\s-fshort-enums\s/
            pattern_char = /(?i)\s-fshort-wchar\s/
            result_enum = line.match(pattern_enum)
            result_char = line.match(pattern_char)
            if (result_enum && result_char)
                @file.compilerTab.short_enums_wchar(target, true, true)
                line.sub!(result_enum[ 0 ], '')
                line.sub!(result_char[ 0 ], '')
            elsif result_enum
                @file.compilerTab.short_enums_wchar(target, true, false)
                line.sub!(result_enum[ 0 ], '')
            elsif result_char
                @file.compilerTab.short_enums_wchar(target, false, true)
                line.sub!(result_char[ 0 ], '')
            end
            return line
        end

        def compiler_use_rtti(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            return line unless @compiler == 'armclang'
            pattern = /(?i)\s-f(rtti|no-rtti)\s/
            result = line.match(pattern)
            if result
                convert = { 'rtti' => true, 'no-rtti' => false}
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.use_rtti(target, convert[result[ 1 ]])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_signed_char(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--signed_chars|-fsigned-char\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.plain_char_is_signed(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.plain_char_is_signed(target, false)
            end
            return line
        end

        def compiler_split_ldm(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            if @compiler == 'armcc'
                pattern = /(?i)\s--split_ldm\s/
                result  = line.match(pattern)
                if (result)
                    @logger.debug("recognize: #{result[ 0 ]}")
                    @file.compilerTab.split_load_store_multiple(target, true)
                    line.sub!(result[ 0 ], '')
                else
                    @file.compilerTab.plain_char_is_signed(target, false)
                end
            else
                pattern = /(?i)\s-f(ldm-stm|no-ldm-stm)\s/
                result  = line.match(pattern)
                convert = { 'ldm-stm' => true, 'no-ldm-stm' => false}
                if (result)
                    @logger.debug("recognize: #{result[ 0 ]}")
                    @file.compilerTab.split_load_store_multiple(target, convert[result[1]])
                    line.sub!(result[ 0 ], '')
                end
            end
            return line
        end

        def compiler_library_interface(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--library_interface=(none|armcc|armcc_c90))\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.add_misc_flag(target, result[ 1 ]) if @compiler == 'armcc'
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing flag: --library_interface")
            end
            return line
        end

        def compile_library_type(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--library_type=(standardlib|microlib))\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.add_misc_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing flag: --library_type")
            end
            return line
        end

        def compiler_interworking(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--apcs=interwork\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.interworking(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.interworking(target, false)
            end
            return line
        end

        def compiler_standard(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # found --c99?
            pattern = /(?i)\s(--c99)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.c99_mode(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.c99_mode(target, false)
            end
            # found --cpp
            pattern = /(?i)\s(--cpp)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.add_misc_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            end
            # found --strict - ansi c
            pattern = /(?i)\s--strict\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.strict_ansi(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.strict_ansi(target, false)
            end
            return line
        end

        def compiler_standard_select(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = if @compiler == 'armcc'
                          /(?i)\s(-xc=default|-xc=c90|-xc=gnu90|-xc=c99|-xc=gnu99|-xc=c11|-xc=gnull)\s/
                      else
                          /(?i)\s(-std=c90|-std=gnu90|-std=c99|-std=gnu99|-std=c11|-std=gnu11)\s/
                      end
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.all_mode(target, result[1])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_standard_cpp(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # armclang specific
            return line unless @compiler == 'armclang'
            pattern = /(?i)\s(-std=c\+\+98|-std=gnu\+\+98|-std=c\+\+11|-std=gnu\+\+11|-std=c\+\+03|-std=c\+\+14|-std=gnu\+\+14|-std=c\+\+17|-std=gnu\+\+17)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.all_mode_cpp(target, result[1])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_warnings(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # armclang specific
            return line unless @compiler == 'armclang'
            pattern = /(?i)\s-(w|Wall|Weverything)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                if result[1] == 'Wall'
                    @file.compilerTab.warnings(target, result[1], @compiler)
                    @file.compilerTab.add_misc_flag(target, result[ 0 ].strip)
                else
                    @file.compilerTab.warnings(target, result[1], @compiler)
                end
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.warnings(target, 'default', @compiler)
            end
            return line
        end

        def compiler_warnings_as_errors(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # armclang specific
            return line unless @compiler == 'armclang'
            pattern = /(?i)\s-Werror\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.turn_warnings_into_errors(target, true, @compiler)
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_exceptions(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(-fno-exceptions|-fexceptions)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.add_misc_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_cpu_fpu_armclang(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # armclang specific
            return line unless @compiler == 'armclang'
            # set fpu
            pattern_fpu = /(?i)\s-mfpu=(\S+)\s/
            result = line.match(pattern_fpu)
            if result
                @logger.debug("recognize: #{result[ 0 ]}")
                fpu = result[1]
                line.sub!(result[ 0 ], '')
            end
            # set cpu
            pattern_cpu = /(?i)\s-mcpu=(\S+?)\+?(nodsp)?\s/
            result = line.match(pattern_cpu)
            if result && result[1]
                @logger.debug("recognize: #{result[ 0 ]}")
                dsp = result[2] ? false : true
                @file.deviceTab.set_cpu_fpu(target, result[1], fpu, dsp)
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_suppress(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--diag_suppress=\S+)\s/
            result  = line.match(pattern)
            while (result && result[ 1 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.add_misc_flag(target, result[ 1 ]) if @compiler == 'armcc'
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            return line
        end
        # -------------------------------------------------------------------------------------
        # Add optimization flag on source level
        # @param [String] target: the target of the flag
        # @param [String] path: the relative path of the flag
        # @param [String] line: all of the flags for a file which is specified by the path
        # @return [String]:the remaining flags after handled by this method
        def compiler_optimization_for_src(target, path, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(path.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s-(O[0123]+)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimization_for_src(target, path, result[ 1 ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing flag: --library_interface")
            end
            return line
        end
        # -------------------------------------------------------------------------------------
        # Add diag_suppress flag on source level
        # @param [String] target: the target of the flag
        # @param [String] path: the relative path of the flag
        # @param [String] line: all of the flags for a file which is specified by the path
        # @return [String]:the remaining flags after handled by this method
        def compiler_suppress_for_src(target, path, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(path.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s?(--diag_suppress=\S+)\s/
            result  = line.match(pattern)
            while (result && result[ 1 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.add_misc_flag_for_src(target, path, result[ 1 ]) if @compiler == 'armcc'
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            return line
        end

        # Add assembler misc control flags on source level
        def assembler_misc_flags_for_src(target, path, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(path.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            @file.assemblerTab.add_misc_flag_for_src(target, path, line)
            line.sub!(line, '')
            return line
        end

        # -------------------------------------------------------------------------------------
        # Add library_interface on source level
        # @param [String] target: the target of the flag
        # @param [String] path: the relative path of the flag
        # @param [String] line: all of the flags for a file which is specified by the path
        # @return [String]:the remaining flags after handled by this method
        def compiler_library_interface_for_src(target, path, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(path.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s?(--library_interface=(none|armcc|armcc_c90))\s?/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.add_misc_flag_for_src(target, path, result[ 1 ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing flag: --library_interface")
            end
            return line
        end

        def compiler_standard_for_src(target, path, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(path.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # found --cpp
            pattern = /(?i)\s?(--cpp)\s?/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.add_misc_flag_for_src(target, path, result[ 1 ])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_dropflags(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # we cannot set CPU
            pattern = /(?i)\s--cpu\s+(\S+)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("drop: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_add_to_misc(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            @file.compilerTab.add_misc_control(target, line.strip)
            line.clear
            return line
        end

        def assembler_interworking(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--apcs=interwork\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.interworking(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.assemblerTab.interworking(target, false)
            end
            return line
        end

        def assembler_split_ldm(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = if @compiler == 'armcc'
                          /(?i)\s--(split_ldm)\s/
                      else
                          /(?i)\s-f(ldm-stm|no-ldm-stm)\s/
                      end
            result  = line.match(pattern)
            if (result)
                convert = { 'split_ldm' => true, 'ldm-stm' => true, 'no-ldm-stm' => false}
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.split_load_store_multiple(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            else
                @file.assemblerTab.split_load_store_multiple(target, false)
            end
            return line
        end

        def assembler_xref(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--xref\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.listingTab.assembler_cross_reference(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.listingTab.assembler_cross_reference(target, false)
            end
            return line
        end

        def assembler_cpreproc(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--cpreproc)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.add_misc_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def assembler_cpreproc_opts(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--cpreproc_opts\s+(\S+)\s/
            result  = line.match(pattern)
            while (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.add_cpreproc_define(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
                result  = line.match(pattern)
            end
            return line
        end

        def assembler_suppress(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--diag_suppress=\S+)\s/
            result  = line.match(pattern)
            while (result && result[ 1 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.add_misc_flag(target, result[ 1 ]) if @compiler == 'armcc'
                line.sub!(result[ 0 ], '')
                result  = line.match(pattern)
            end
            return line
        end

        def assembler_dropflags(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # we cannot set CPU
            pattern = /(?i)\s--cpu\s+(\S+)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("drop: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            pattern = /(?i)\s-mcpu=(\S+?)\+?(nodsp)?\s/
            result = line.match(pattern)
            if result && result[1]
                @logger.debug("recognize: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end

            # fpu is set by cc-flags, no need to set by as-flags
            pattern_fpu = /(?i)\s-mfpu=(\S+)\s/
            result = line.match(pattern_fpu)
            if result
                @logger.debug("recognize: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            # GUI project will add it automatically, no need to add it manually
            pattern_target = /(?i)\s--target=arm-arm-none-eabi\s/
            result = line.match(pattern_target)
            if result
                @logger.debug("recognize: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end

            return line
        end

        def assembler_preprocess_input(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            return line unless @compiler == 'armclang'
            pattern = /\s(-x\sassembler-with-cpp)\s/
            result  = line.match(pattern)
            if (result)
                @file.assemblerTab.add_misc_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def assembler_ro_independent(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            return line unless @compiler == 'armclang'
            pattern = /(?i)\s-f(ropi|no-ropi)\s/
            result  = line.match(pattern)
            if (result)
                convert = { 'ropi' => true, 'no-ropi' => false }
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.ro_independent(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def assembler_rw_independent(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            return line unless @compiler == 'armclang'
            pattern = /(?i)\s-f(rwpi|no-rwpi)\s/
            result  = line.match(pattern)
            if (result)
                convert = { 'rwpi' => true, 'no-rwpi' => false }
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.rw_independent(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def assembler_secure_mode(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            return line unless @compiler == 'armclang'
            pattern = /\s-mcmse\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.add_misc_flag(target, result[0])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def assembler_extra_option(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            unless line.strip.empty?
                @file.assemblerTab.add_misc_flag(target, line.strip)
            end
            ''
        end

        def linker_keep_symbols(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--keep\s+\S+)\s/
            result  = line.match(pattern)
            while (result && result[ 1 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.add_misc_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            return line
        end

        def linker_suppress(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--diag_suppress=(\S+)\s/
            result  = line.match(pattern)
            while (result && result[ 1 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.add_disable_warning(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
                result  = line.match(pattern)
            end
            return line
        end

        def linker_remove_unused(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--remove|--no_remove)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.add_misc_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing linker flag: --remove | --no_remove")
            end
            return line
        end

        def linker_library_type(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--library_type=(standardlib|microlib|nomicrolib))\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                if result[ 2 ] == "standardlib"
                    @file.linkerTab.use_microlib(target,false)
                elsif result[ 2 ] == "nomicrolib"
                    @file.linkerTab.use_microlib(target,false)
                else
                    @file.linkerTab.use_microlib(target,true)
                end
                line.sub!(result[ 0 ], '')
            else
                @file.linkerTab.use_microlib(target,true)
                @logger.debug("missing flag: --library_type")
            end
            return line
        end

        def linker_auto_at(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--autoat|--no_autoat)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.add_misc_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing linker flag: --autoat | --no_autoat")
            end
            return line
        end

        def linker_memory_map(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--map\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.listingTab.linker_memory_map(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.listingTab.linker_memory_map(target, false)
            end
            return line
        end

        def linker_list_callgraph(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--callgraph\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.listingTab.linker_callgraph(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.listingTab.linker_callgraph(target, false)
            end
            return line
        end

        def linker_list_symbols(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--symbols\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.listingTab.linker_symbols(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.listingTab.linker_symbols(target, false)
            end
            return line
        end

        def linker_list_cross_reference(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--xref\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.listingTab.linker_cross_reference(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.listingTab.linker_cross_reference(target, false)
            end
            return line
        end

        def linker_list_size(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--info\s+sizes\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.listingTab.linker_size_info(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.listingTab.linker_size_info(target, false)
            end
            return line
        end

        def linker_list_total(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--info\s+totals\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.listingTab.linker_total_info(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.listingTab.linker_total_info(target, false)
            end
            return line
        end

        def linker_list_unused(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--info\s+unused\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.listingTab.linker_unused_sections(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.listingTab.linker_unused_sections(target, false)
            end
            return line
        end

        def linker_list_veneers(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--info\s+veneers\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.listingTab.linker_veneers_info(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.listingTab.linker_veneers_info(target, false)
            end
            return line
        end

        def linker_might_failed(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--strict\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.report_might_fail(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.linkerTab.report_might_fail(target, false)
            end
            return line
        end

        def linker_dropflags(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # flags that IDE put automatically without any GUI
            # --summary_stderr
            pattern = /(?i)\s--summary_stderr\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("drop: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            # --info summarysizes
            pattern = /(?i)\s--info summarysizes\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("drop: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            # cpu/fpu has been identified by cc-flags, no need to set it again in linker tab
            # --cpu Cortex-M4
            pattern = /(?i)\s--cpu(\s+|=)(\S+)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("drop: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            # --fpu
            pattern = /(?i)\s--fpu(\s+|=)(\S+)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("drop: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            # -mcpu=cortex-m7
            pattern = /(?i)\s-mcpu(\s+|=)(\S+)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("drop: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            # -mfpu=fpv4-sp-d16
            pattern = /(?i)\s-mfpu(\s+|=)(\S+)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("drop: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def linker_tz_import_lib(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s--import-cmse-lib-out(\s+|=)(\S+)\s/
            result  = line.match(pattern)
            if result && result[2]
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.add_misc_flag(target, "--import-cmse-lib-out=#{File.basename(result[2].gsub('"', ''))}")
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def linker_add_to_misc(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            results = line.split()
            results.each do |result|
              @file.linkerTab.add_misc_flag(target, result)
            end
            line.clear
        end
    end
end
end

