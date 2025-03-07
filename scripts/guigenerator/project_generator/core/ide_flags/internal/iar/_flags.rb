# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/_flags'

module Internal
module Iar

    class Flags < Internal::Flags

        private

        def common_device(target, line)
          @file.generalTab.targetTab.device(target, line)
          return line
        end

        def common_cmsis(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            #use cmsis
            pattern = /(?i)\s--use_cmsis\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.libraryConfigurationTab.use_cmsis(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.generalTab.libraryConfigurationTab.use_cmsis(target, false)
            end
            #use cmsis dap lib
            pattern = /(?i)\s--use_cmsis_dsp\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.libraryConfigurationTab.use_cmsis_dsp(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.generalTab.libraryConfigurationTab.use_cmsis_dsp(target, false)
            end
            return line
        end

        def library(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--dlib_config\s+([^\s\-]+)\s/
            result  = line.match(pattern)
            if result && result[0]
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.libraryConfigurationTab.library(target, result[1].downcase)
                line.sub!(result[0], '')
            end
            return line
        end

        def common_cpu_fpu(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # cpu
            pattern = /(?i)\s--cpu(=|\s+)(\S+?)\.?(no_dsp)?\.?(no_se)?\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                # dspExtension: if included "no_dsp", handle this flag
                @file.generalTab.targetTab.dspExtension(target, result[ 3 ]) if result[ 3 ]
                # trustZone: if included "no_se", handle this flag
                @file.generalTab.targetTab.trustZone(target, result[ 4 ]) if result[ 4 ]
                @file.generalTab.targetTab.core(target, result[ 2 ].downcase)
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("no --cpu flag")
            end
            # fpu
            pattern = /(?i)\s--fpu(=|\s+)(\S+)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.targetTab.fpu(target, result[ 2 ].downcase)
                line.sub!(result[ 0 ], '')
            else
               @logger.debug("no --fpu flag")
            end
            return line
        end

        def common_misra(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # misra
            pattern = /(?i)\s--misra(2004|1998)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.misraC2004Tab.enable_misra(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.generalTab.misraC2004Tab.enable_misra(target, false)
            end
            if (result && result[ 1 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.misraC2004Tab.misra_version(target, result[ 1 ])
            end
            return line
        end

        def compiler_cplus_dialect(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--(ec\+\+|eec\+\+|c\+\+)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                convert = {'ec++' => 'embedded', 'eec++' => 'extended', 'c++' => 'full'}
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.language1Tab.cpp_dialect(target, convert[ result[ 1 ] ])
                line.sub!(result[ 0 ], '')
            else
               @logger.debug("no cplus dialect")
            end
            return line
        end

        def compiler_vla(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--vla\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.language1Tab.allow_vla(target, true)
                line.sub!(result[ 0 ], '')
            else
               @file.compilerTab.language1Tab.allow_vla(target, false)
            end
            return line
        end

        def compiler_extra_option(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            @file.compilerTab.ExtraOptionTab.use_commandline(target, line.strip) unless line.empty?
            line.clear
            return line
        end
        # -------------------------------------------------------------------------------------
        # Add compiler extra option on source level
        # @param [String] target: the target of the flag
        # @param [String] path: the relative path of the flag
        # @param [String] line: all of the flags for a file which is specified by the path
        # @return [String]:the remaining flags after handled by this method
        def compiler_extra_option_for_src(target, path, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(path.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            @file.compilerTab.ExtraOptionTab.use_commandline_for_src(target, path, line.strip)
            line.clear
            return line
        end

        def compiler_c_dialect(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--c89\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.language1Tab.c_dialect(target, 'c89')
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.language1Tab.c_dialect(target, 'c99')
            end
            return line
        end

        def compiler_preinclude_file(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--preinclude\s+(\S+)/
            result  = line.match(pattern)
            if (result && result[ 1 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.preprocessorTab.add_pre_include(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_language_dialect(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--compiler_language=(auto|c|c\+\+)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.language1Tab.language(target, result[1])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_warnings_as_errors(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--warnings_are_errors\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.diagnosticTab.treat_warnings_as_errors(target, true)
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_require_prototypes(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--require_prototypes\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.language1Tab.require_prototypes(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.language1Tab.require_prototypes(target, false)
            end
            return line
        end

        def compiler_suppress_diag(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--diag_suppress\s+([^\s\-]+)\s/
            result  = line.match(pattern)
            flags = []
            while (result && result[ 0 ])
                @logger.debug("recognize #{result[ 0 ]}")
                flags.push_uniq result[1]
                line.sub!(result[ 0 ], '')
                result  = line.match(pattern)
            end
            @file.compilerTab.diagnosticTab.set_suppress(target, flags.join(",")) unless flags.empty?
            return line
        end

        def compiler_debug_info(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--debug\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.outputTab.debug_info(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.outputTab.debug_info(target, false)
            end
            return line
        end

        def compiler_inline_cpp(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--use_c\+\+_inline\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.language1Tab.cpp_inline_semantic(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.language1Tab.cpp_inline_semantic(target, false)
            end
            return line
        end

        def compiler_cpp_rtti(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--fno-rtti|--no_rtti)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.language1Tab.cpp_with_rtti(target, false)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.language1Tab.cpp_with_rtti(target, true)
            end
            return line
        end

        def compiler_cpp_exceptions(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--fno-exceptions|--no_exceptions)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.language1Tab.cpp_with_exceptions(target, false)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.language1Tab.cpp_with_exceptions(target, true)
            end
            return line
        end

        def compiler_endian(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--endian=(little|l|big|b)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.targetTab.endian(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_secure(target,line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s(--cmse)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.targetTab.secure(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_interworking(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--interwork\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.codeTab.interwork_code(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.codeTab.interwork_code(target, false)
            end
            return line
        end

        def compiler_cpu_mode(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--cpu_mode\s+(arm|thumb)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.codeTab.processor_mode(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def compiler_optimization(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s-O(n|l|m|h)(\s)/
            result  = line.to_enum(:scan,pattern).map{$&}
            if (result.count > 0)
                convert = {'n' => 'none', 'l' => 'low', 'm' => 'medium', 'h' => 'high'}
                power_level = [ 'none', 'low', 'medium', 'high']
                level = power_level[0]
                result.each do |key|
                  op = key.match(pattern)
                  @logger.debug("recognize: #{op[ 0 ]}")
                  level = convert[op[1]] if power_level.index(level) < power_level.index(convert[op[1]])
                end
                @file.compilerTab.optimizationTab.level(target, level)
                while data = line.match(pattern)
                    line.sub!(data[0], '')
                end
            else
                @logger.debug("missing flags: -On | -Ol | -Om | -Oh ")
            end
            return line
        end

        def compiler_optimization_for_src(target, path, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(path.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s-O(n|l|m|h)(\s)/
            result  = line.to_enum(:scan,pattern).map{$&}
            if (result.count > 0)
                convert = {'n' => 'none', 'l' => 'low', 'm' => 'medium', 'h' => 'high'}
                power_level = [ 'none', 'low', 'medium', 'high']
                level = power_level[0]
                result.each do |key|
                    op = key.match(pattern)
                    @logger.debug("recognize: #{op[ 0 ]}")
                    level = convert[op[1]] if power_level.index(level) < power_level.index(convert[op[1]])
                end
                @file.compilerTab.optimizationTab.level_for_src(target, path, level)
                data = line.match(pattern)
                line.sub!(data[0], '') if data
            else
                @logger.debug("missing flags: -On | -Ol | -Om | -Oh ")
            end
            return line
        end

        def compiler_optimization_strategy(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)-O(hb|hs|hz)(\s?)/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                convert = {'hb' => 'balance', 'hz' => 'size', 'hs' => 'speed'}
                @logger.debug("recognize: #{result[ 0 ]}")
                value = convert[result[ 1 ]]
                @file.compilerTab.optimizationTab.high_strategy(target, value)
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing flags: -Ohs | -Ohz")
            end
            return line
        end

        def compiler_optimization_strategy_for_src(target, path, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(path.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)-O(hb|hs|hz)(\s?)/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                convert = {'hb' => 'balance', 'hz' => 'size', 'hs' => 'speed'}
                @logger.debug("recognize: #{result[ 0 ]}")
                value = convert[result[ 1 ]]
                @file.compilerTab.optimizationTab.high_strategy_for_src(target, path, value)
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing flags: -Ohs | -Ohz")
            end
            return line
        end

        def compiler_cse(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--no_cse\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimizationTab.enable_subexp_elimination(target, false)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.optimizationTab.enable_subexp_elimination(target, true)
            end
            return line
        end

        def compiler_unroll(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--no_unroll\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimizationTab.enable_loop_unrolling(target, false)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.optimizationTab.enable_loop_unrolling(target, true)
            end
            return line
        end

        def compiler_inline(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--no_inline\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimizationTab.enable_func_inlining(target, false)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.optimizationTab.enable_func_inlining(target, true)
            end
            return line
        end

        def compiler_code_motion(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--no_code_motion\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimizationTab.enable_code_motion(target, false)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.optimizationTab.enable_code_motion(target, true)
            end
            return line
        end

        def compiler_alias_analysis(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--no_tbaa\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimizationTab.enable_alias_analysis(target, false)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.optimizationTab.enable_alias_analysis(target, true)
            end
            return line
        end

        def compiler_clustering(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--no_clustering\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimizationTab.enable_static_clustering(target, false)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.optimizationTab.enable_static_clustering(target, true)
            end
            return line
        end

        def compiler_scheduling(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--no_scheduling\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimizationTab.enable_instruction_scheduling(target, false)
                line.sub!(result[ 0 ], '')
            else
                @file.compilerTab.optimizationTab.enable_instruction_scheduling(target, true)
            end
            return line
        end

        def compiler_strategy(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)-S(size|speed|balance)(\s?)/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimizationTab.strategy(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing flags: -Ssize | -Sspeed | -Sbalance")
            end
            return line
        end

        def compiler_strategy_for_src(target, path, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(path.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)-S(size|speed|balance)(\s?)/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimizationTab.strategy_for_src(target, path, result[ 1 ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing flags: -Ssize | -Sspeed | -Sbalance")
            end
            return line
        end

        def compiler_nosize_constraints(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)--no_size_constraints(\s?)/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimizationTab.enable_nosize_constraints(target, true)
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing flags: --no_size_constraints")
            end
            return line
        end

        def compiler_nosize_constraints_for_src(target, path, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(path.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)--no_size_constraints(\s?)/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.optimizationTab.enable_nosize_constraints_for_src(target, path, true)
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing flags: --no_size_constraints")
            end
            return line
        end

        def compiler_conformance(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            is_standard = true
            # iar extension
            pattern = /(?i)\s(-e)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.language1Tab.comformance(target, 'extension')
                line.sub!(result[ 0 ], '')
                is_standard = false
            end
            # strict mode
            pattern = /(?i)\s(--strict)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.compilerTab.language1Tab.comformance(target, 'strict')
                line.sub!(result[ 0 ], '')
                is_standard = false
            end
            if (is_standard)
                @file.compilerTab.language1Tab.comformance(target, 'standard')
            end
            return line
        end

        def compiler_dropflags(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # flags which IDE force without IDE
            # silent mode depends on user preference not project settings
            pattern = /\s--silent\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("drop: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def assembler_debug_info(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s-r\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.outputTab.debug_info(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.assemblerTab.outputTab.debug_info(target, false)
            end
            return line
        end

        def assembler_alternative_names(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s-j\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.languageTab.allow_alternative_names(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.assemblerTab.languageTab.allow_alternative_names(target, false)
            end
            return line
        end

        def assembler_case_sensitivity(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s-s\+?\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.languageTab.allow_case_sensitivity(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.assemblerTab.languageTab.allow_case_sensitivity(target, false)
            end
            return line
        end

        def assembler_diagnostic(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s-w([\+\-])\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.diagnosticTab.enable_warnings(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.assemblerTab.diagnosticTab.enable_warnings(target, false)
            end
            return line
        end

        def assembler_quotechar(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # character which will be used quote
            pattern = /(?i)\s-M[\'\"]?(\(\)|\[\]|\{\}|\<\>|)[\'\"]?\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.assemblerTab.languageTab.macro_quote_character(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("missing -M[] flag")
            end
            return line
        end

        def assembler_extra_flags(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            unless line.strip.empty?
                @file.assemblerTab.extraOptionTab.use_commandline(target, line.strip)
            end
            ''
        end

        def assembler_dropflags(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # silent mode depends on user preference not project settings
            pattern = /\s-S\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("drop: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def linker_entry_symbol(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # put entry symbol
            pattern = /\s--entry(\s+|=)(\S+)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.libraryTab.entry_symbol(target, result[ 2 ]);
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def linker_redirect_symbols(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # redirect symbol to another
            pattern = /\s--redirect\s+(\S+)\s/
            result  = line.match(pattern)
            while (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.extraOptionTab.add_command_option(target, result[ 0 ]);
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            return line
        end

        def linker_place_holder(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # set --place_holder settings
            pattern = /\s(--place_holder\s+\S+)\s/
            result  = line.match(pattern)
            while (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.extraOptionTab.add_command_option(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            return line
        end

        def linker_semihosted(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # set --place_holder settings
            pattern = /\s(--semihosting)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.libraryOptionsTab.enable_semihosted(target, true)
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def linker_tz_import_lib(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s--import_cmse_lib_out(\s+|=)(\S+)\s/
            result  = line.match(pattern)
            if result && result[2]
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.outputTab.set_tz_import_lib(target, File.basename(result[2]))
                @file.generalTab.outputTab.output_dir(target, '$PROJ_DIR$')
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def linker_redirect_swo(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # set --place_holder settings
            pattern = /\s(--redirect\s__iar_sh_stdout=__iar_sh_stdout_swo)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.libraryOptionsTab.redirect_swo(target, true)
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def linker_extra_options(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")

            # remove cpu and fpu setting, because ide will provide them
            pattern = /(?i)\s--cpu(=|\s+)(\S+?)\.?(no_dsp)?\.?(no_se)?\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                @logger.debug("recognize: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            # fpu
            pattern = /(?i)\s--fpu(=|\s+)(\S+)\s/
            result  = line.match(pattern)
            if (result && result[ 0 ])
                line.sub!(result[ 0 ], '')
            end


            pattern = /\s*(--\S+)/
            result  = line.match(pattern)
            while (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.extraOptionTab.add_command_option(target, result[ 1 ]);
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            @file.linkerTab.extraOptionTab.clear_empty_command_options!(target)
            return line
        end

        def linker_keep_symbols(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # keep symbols
            pattern = /\s--keep(\s+|=)(\S+)\s/
            result  = line.match(pattern)
            while (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.inputTab.add_keep_symbol(target, result[ 2 ]);
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            return line
        end

        def linker_raw_binary_image(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s--image_input=(\S+),(\S+),(\S+),(\d+)\s/
            result  = line.match(pattern)
            order = 0
            # raw binary image support up to 2 binary files, other binary files will be kept in linker extra options
            while (result && order < 2)
                @logger.debug("recognize: #{result[ 0 ]}")
                value = {'order' => order, 'source' => result[1], 'symbol' => result[2], 'section' => result[3], 'align' => result[4]}
                @file.linkerTab.inputTab.set_raw_binary_image(target, value)
                order += 1
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            return line
        end

        def linker_dropflags(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # silent mode depends on user preference not project settings
            pattern = /\s--silent\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("drop: #{result[ 0 ]}")
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def linker_printf_formatter(target, line)
            # MUST be used before linker_redirect_symbols
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # redirect symbol to another
            pattern = /\s--redirect\s+_Printf=(_PrintfFull|_PrintfFullNoMb|_PrintfLarge|_PrintfLargeNoMb|_PrintfSmall|_PrintfSmallNoMb|_PrintfTiny)\s/
            result  = line.match(pattern)
            if (result)
                convert = {
                    '_PrintfFull'       => 'full',
                    '_PrintfFullNoMb'   => 'full_no_mb',
                    '_PrintfLarge'      => 'large',
                    '_PrintfLargeNoMb'  => 'large_no_mb',
                    '_PrintfSmall'      => 'small',
                    '_PrintfSmallNoMb'  => 'small_no_mb',
                    '_PrintfTiny'       => 'tiny',
                }
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.libraryOptionsTab.printf_formatter(target, convert[  result[ 1 ] ])
                line.sub!(result[ 0 ], '')
            else
                # full is setup as default formatter - no special linker command line option
                # peter 20140512, change default format to small
                @file.generalTab.libraryOptionsTab.printf_formatter(target, 'small')
            end
            return line
        end

        def linker_scanf_formatter(target, line)
            # MUST be used before linker_redirect_symbols
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # redirect symbol to another
            pattern = /\s--redirect\s+_Scanf=(_ScanfFull|_ScanfFullNoMb|_ScanfLarge|_ScanfLargeNoMb|_ScanfSmall|_ScanfSmallNoMb)\s/
            result  = line.match(pattern)
            if (result)
                convert = {
                    '_ScanfFull'        => 'full',
                    '_ScanfFullNoMb'    => 'full_no_mb',
                    '_ScanfLarge'       => 'large',
                    '_ScanfLargeNoMb'   => 'large_no_mb',
                    '_ScanfSmall'      => 'small',
                    '_ScanfSmallNoMb'   => 'small_no_mb',
                }
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.libraryOptionsTab.scanf_formatter(target, convert[  result[ 1 ] ])
                line.sub!(result[ 0 ], '')
            else
                # full is setup as default formatter - no special linker command line option
                # peter 20140512, change default format to small
                @file.generalTab.libraryOptionsTab.scanf_formatter(target, 'small')
            end
            return line
        end

        def linker_buffered_terminal_output(target, line)
            # MUST be used before linker_redirect_symbols
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # redirect symbol to another
            pattern = /\s--redirect\s+__write=__write_buffered\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.generalTab.libraryOptionsTab.buffered_terminal_output(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.generalTab.libraryOptionsTab.buffered_terminal_output(target, false)
            end
            return line
        end

        def linker_read_command_file(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # Read command line options from specificed file
            pattern = /\s-f\s+\S*\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.linkerTab.extraOptionTab.add_command_option(target, result[ 0 ]);
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def linker_fill_settings(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            #--fill 0xFF;0x0-0xfffb
            result = line.match(/\s--fill.+-\w+\s/)
            return line if result.nil?
            pattern = /[\s;-]/
            results = line.strip.gsub(/\s+/, ';').split(pattern)
            @file.linkerTab.checksumTab.enable_checksum(target, true)
            @file.linkerTab.checksumTab.fillerbyte(target, results[3])
            @file.linkerTab.checksumTab.fillerstart(target, results[4])
            @file.linkerTab.checksumTab.fillerend(target, results[5])
            line.sub!(result[0], '')
            return line
        end

        def linker_suppress_diag(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /(?i)\s--diag_suppress\s+([^\s\-]+)\s/
            result  = line.match(pattern)
            flags = []
            while (result && result[ 0 ])
                @logger.debug("recognize #{result[ 0 ]}")
                flags.push_uniq result[1]
                line.sub!(result[ 0 ], '')
                result  = line.match(pattern)
            end
            @file.linkerTab.diagnosticTab.set_suppress(target, flags.join(",")) unless flags.empty?
            return line
        end

        def linker_configfile_defines(target, line)
            # MUST be used before linker_redirect_symbols
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            @file.linkerTab.configTab.clear_configuration_file_defines!(target, line)
            # match linker flag such as --config_def XIP_IMAGE=1
            pattern = /\s*--config_def\s\S+/
            res = line.match(pattern)
            while (res)
                @file.linkerTab.configTab.configuration_file_defines(target, res[0].split('config_def ')[1])
                line.sub!(res[0], '')
                res = line.match(pattern)
            end

            #drop --map, because Iar can generated map file automatically and it does not accept duplicated option
            result = line.match(/\s--map\s*\S+/)
            line.sub!(result[0], '') if result

            results = line.split()
            results.each do |result|
                next if result.match(/\s*--\S+/)
                @file.linkerTab.configTab.configuration_file_defines(target, result)
            end
            return line
        end

    end
end
end

