# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../_flags'

module Internal
module Mcux

    class Flags < Internal::Flags

        private

        ### assembler settings
        ###
        def assembler_family(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-mcpu=(cortex-m0|cortex-m0plus|cortex-m4|cortex-m7)\s/
            result  = line.match(pattern)
            if (result)
                convert = {
                    'cortex-m7' => 'cm7',
                    'cortex-m4' => 'cm4',
                    'cortex-m3' => 'cm3',
                    'cortex-m1' => 'cm1',
                    'cortex-m0' => 'cm0',
                    'cortex-m0plus' => 'cm0plus',
                    'cortex-m0sm' => 'cm0.smallmul',
                    'cortex-m0plussm' => 'cm0plus.smallmul',
                    'arm7tdmi' => 'a7',
                    'arm968es' => 'a968e',
                    'arm926ejs' => 'a926ej'
                }
                @logger.debug("recognize #{result[ 0 ]}")
                @file.assembler_set_architecture(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("no family set!")
            end
            return line
        end

        def assembler_fpu(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # find mfpu
            pattern = /\s-mfpu=(fpv4-sp-d16|vfp|fpv5-sp-d16|fpv5-d16)\s/
            mfpu = line.match(pattern)
            if (mfpu)
                line.sub!(mfpu[ 0 ], '')
                mfpu = mfpu[1]
            end
            # find mfloat-abi
            pattern = /\s-mfloat-abi=(hard|soft|softfp)\s/
            mfloat_abi = line.match(pattern)
            if (mfloat_abi)
                line.sub!(mfloat_abi[ 0 ], '')
                mfloat_abi = mfloat_abi[1]
            end
            convert = {
                '-'                     => 'none',
                'soft-'                 => 'none',
                'softfp-vfp'            => 'vfp',
                'softfp-fpv4-sp-d16'    => 'fpv4',
                'hard-fpv4-sp-d16'      => 'fpv4.hard',
                'hard-fpv5-sp-d16'      => 'fpv5sp.hard',
                'hard-fpv5-d16'         => 'fpv5dp.hard',
                'soft-fpv5-d16'         => 'fpv5dp'
            }
            convertkey = "#{mfloat_abi}-#{mfpu}"
            if (convert.key?(convertkey))
                value = convert[ convertkey ]
                @file.assembler_set_floating_point(target, value)
            else
                @logger.debug("invalid combination fpu '#{mfpu}' and abi '#{mfloat_abi}'")
            end
            return line
        end

        def assembler_suppress_warning(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-W\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.assembler_suppress_warnings(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.assembler_suppress_warnings(target, false)
            end
            return line
        end

        def assembler_other_flag(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            @file.assembler_add_assembler_flag(target, line.strip)
            line.clear
            return line
        end

        ### C Compiler Options
        ###

        def ccompiler_family(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-mcpu=(cortex-m0|cortex-m0plus|cortex-m4|cortex-m7)\s/
            result  = line.match(pattern)
            if (result)
                convert = {
                    'cortex-m7' => 'cm7',
                    'cortex-m4' => 'cm4',
                    'cortex-m3' => 'cm3',
                    'cortex-m1' => 'cm1',
                    'cortex-m0' => 'cm0',
                    'cortex-m0plus' => 'cm0plus',
                    'cortex-m0sm' => 'cm0.smallmul',
                    'cortex-m0plussm' => 'cm0plus.smallmul',
                    'arm7tdmi' => 'a7',
                    'arm968es' => 'a968e',
                    'arm926ejs' => 'a926ej'
                }
                @logger.debug("recognize #{result[ 0 ]}")
                @file.ccompiler_set_architecture(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("no family set!")
            end
            return line
        end

        def ccompiler_fpu(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # find mfpu
            pattern = /\s-mfpu=(fpv4-sp-d16|vfp|fpv5-sp-d16|fpv5-d16)\s/
            mfpu = line.match(pattern)
            if (mfpu)
                line.sub!(mfpu[ 0 ], '')
                mfpu = mfpu[1]
            end
            # find mfloat-abi
            pattern = /\s-mfloat-abi=(hard|soft|softfp)\s/
            mfloat_abi = line.match(pattern)
            if (mfloat_abi)
                line.sub!(mfloat_abi[ 0 ], '')
                mfloat_abi = mfloat_abi[1]
            end
            convert = {
                '-'                     => 'none',
                'soft-'                 => 'none',
                'softfp-vfp'            => 'vfp',
                'softfp-fpv4-sp-d16'    => 'fpv4',
                'hard-fpv4-sp-d16'      => 'fpv4.hard',
                'hard-fpv5-sp-d16'      => 'fpv5sp.hard',
                'hard-fpv5-d16'         => 'fpv5dp.hard',
                'soft-fpv5-d16'         => 'fpv5dp',
            }
            convertkey = "#{mfloat_abi}-#{mfpu}"
            if (convert.key?(convertkey))
                value = convert[ convertkey ]
                @file.ccompiler_set_floating_point(target, value)
            else
                @logger.debug("invalid combination fpu '#{mfpu}' and abi '#{mfloat_abi}'")
            end
            return line
        end

        def ccompiler_language(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-(ansi|std=c90|std=c99|std=c11|std=gnu90|std=gnu99|std=gnu11)\s/
            result  = line.match(pattern)
            if (result)
                convert = {
                    'ansi' => 'default',
                    'std=gnu90' => 'gnu90',
                    'std=gnu99' => 'gnu99',
                    'std=gnu11' => 'gnu11',
                    'std=c90' => 'c90',
                    'std=c99' => 'c99',
                    'std=c11' => 'c11'
                }
                @logger.debug("recognize #{result[ 0 ]}")
                @file.ccompiler_set_language_standard(target, convert[ result[1] ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("no language set!")
            end
            return line
        end

        def ccompiler_debug_level(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-(g|g1|g3|g0)\s/
            result  = line.match(pattern)
            if (result)
                convert = {'g' => 'default', 'g1' => 'minimal', 'g3' => 'max', 'g0' => 'none'}
                @logger.debug("recognize #{result[ 0 ]}")
                @file.ccompiler_set_debugging_level(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def ccompiler_inhibit_all_warnings(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-w\s/
            result  = line.match(pattern)
            if (result)
                @file.ccompiler_inhibit_all_warnings(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.ccompiler_inhibit_all_warnings(target, false)
            end
            return line
        end

        def ccompiler_warnings_wall(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-Wall\s/
            result  = line.match(pattern)
            if (result)
                @file.ccompiler_set_all_warnings(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.ccompiler_set_all_warnings(target, false)
            end
            return line
        end

        def ccompiler_enable_extra_warnings(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-Wextra\s/
            result  = line.match(pattern)
            if (result)
                @file.ccompiler_set_extra_warnings(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.ccompiler_set_extra_warnings(target, false)
            end
            return line
        end

        def ccompiler_warnings_implicit_conversion(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-Wconversion\s/
            result  = line.match(pattern)
            if (result)
                @file.ccompiler_set_implicit_conversion_warnings(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.ccompiler_set_implicit_conversion_warnings(target, false)
            end
            return line
        end

        def ccompiler_generate_errors_instead_warnings(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-Werror\s/
            result  = line.match(pattern)
            if (result)
                @file.ccompiler_set_warnings_as_errors(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.ccompiler_set_warnings_as_errors(target, false)
            end
            return line
        end

        def ccompiler_enable_link_time_optimization(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-flto\s/
            result  = line.match(pattern)
            if (result)
                @file.ccompiler_enable_link_time_optimization(target, true)
                line.sub!(result[ 0 ], '')
            end
            return line
        end


        def ccompiler_optimization_level(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-(O0|O1|O2|O3|Os|Og)\s/
            result  = line.match(pattern)
            if (result)
                convert = {
                    'O0' => 'none',
                    'O1' => 'optimize',
                    'O2' => 'more',
                    'O3' => 'most',
                    'Os' => 'size',
                    'Og' => 'general'
                }
                @file.ccompiler_optimization_level(target, convert[result[ 1 ]])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("no optimization set!")
            end
            return line
        end

        def ccompiler_optimization_flags(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-fno-common\s/
            result  = line.match(pattern)
            if (result)
                @file.ccompiler_set_ccompiler_optimization_flags(target, result[0].strip)
                line.sub!(result[0], '')
            else
                @logger.debug("no optimization set!")
            end
            return line
        end


        def ccompiler_nostdinc(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-nostdinc\+\+\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.ccompiler_do_not_search_system_directories(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.ccompiler_do_not_search_system_directories(target, false)
            end
            return line
        end

        def ccompiler_set_secure_state(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s*-((non)?secure)/
            result  = if line.match(pattern)
                          line.match(pattern)
                      else
                          line.match(/\s*-(none)/)
                      end
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.ccompiler_add_secure_state(target, result[1])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def ccompiler_other_flag(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            @file.ccompiler_add_other_flags(target, line.strip)
            line.clear
            return line
        end

        ### C linker settings
        ###

        def clinker_toram(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-toram=(true|false)\s/
            result  = line.match(pattern)
            if (result)
                if 'true' == result[1]
                    @logger.debug("recognize #{result[ 0 ]}")
                    @file.clinker_add_linker_toram(target, true)
                    line.sub!(result[ 0 ], '')
                end
            end
            return line
        end

        def clinker_memory_data(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /memorydata=(?<value>.*)/
            ana_line = line.split()
            ana_line.each do |res|
              result  = res.match(pattern)
              if (result)
                @logger.debug("recognize #{res}")
                @file.clinker_set_memory_data(target, $~[:value])
                line.sub!(res, '')
              end
            end
            return line
        end

        def clinker_family(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-mcpu=(cortex-m0|cortex-m0plus|cortex-m4|cortex-m7)\s/
            result  = line.match(pattern)
            if (result)
                convert = {
                    'cortex-m7' => 'cm7',
                    'cortex-m4' => 'cm4',
                    'cortex-m3' => 'cm3',
                    'cortex-m1' => 'cm1',
                    'cortex-m0' => 'cm0',
                    'cortex-m0plus' => 'cm0plus',
                    'cortex-m0sm' => 'cm0.smallmul',
                    'cortex-m0plussm' => 'cm0plus.smallmul',
                    'arm7tdmi' => 'a7',
                    'arm968es' => 'a968e',
                    'arm926ejs' => 'a926ej'
                }
                @logger.debug("recognize #{result[ 0 ]}")
                @file.clinker_set_architecture(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("no family set!")
            end
            return line
        end

        def clinker_fpu(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # find mfpu
            pattern = /\s-mfpu=(fpv4-sp-d16|vfp|fpv5-sp-d16|fpv5-d16)\s/
            mfpu = line.match(pattern)
            if (mfpu)
                line.sub!(mfpu[ 0 ], '')
                mfpu = mfpu[1]
            end
            # find mfloat-abi
            pattern = /\s-mfloat-abi=(hard|soft|softfp)\s/
            mfloat_abi = line.match(pattern)
            if (mfloat_abi)
                line.sub!(mfloat_abi[ 0 ], '')
                mfloat_abi = mfloat_abi[1]
            end
            convert = {
                '-'                     => 'none',
                'soft-'                 => 'none',
                'softfp-vfp'            => 'vfp',
                'softfp-fpv4-sp-d16'    => 'fpv4',
                'hard-fpv4-sp-d16'      => 'fpv4.hard',
                'hard-fpv5-sp-d16'      => 'fpv5sp.hard',
                'hard-fpv5-d16'         => 'fpv5dp.hard',
                'soft-fpv5-d16'         => 'fpv5dp'
            }
            convertkey = "#{mfloat_abi}-#{mfpu}"
            if (convert.key?(convertkey))
                value = convert[ convertkey ]
                @file.clinker_set_floating_point(target, value)
            else
                @logger.debug("invalid combination fpu '#{mfpu}' and abi '#{mfloat_abi}'")
            end
            return line
        end

        def clinker_nostartfiles(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-nostartfiles\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.clinker_set_standard_start_files(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.clinker_set_standard_start_files(target, false)
            end
            return line
        end

        def clinker_nodefaultlibs(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-nodefaultlibs\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.clinker_set_use_default_libraries(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.clinker_set_use_default_libraries(target, false)
            end
            return line
        end

        def clinker_nostdlib(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-nostdlib\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.clinker_set_no_startup_or_default_libs(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.clinker_set_no_startup_or_default_libs(target, false)
            end
            return line
        end

        def clinker_omit_all_symbols(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-s\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.clinker_omit_all_symbol_information(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.clinker_omit_all_symbol_information(target, false)
            end
            return line
        end

        def clinker_nostaticlib(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-static\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.clinker_set_nostaticlib(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.clinker_set_nostaticlib(target, false)
            end
            return line
        end

        def clinker_libraries(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /-l/
            ana_line = line.split()
            ana_line.each do |res|
              result  = res.match(pattern)
              if (result)
                @logger.debug("recognize #{res}")
                @file.armCLinkerTab.librariesTab.add_library(target, res.gsub("-l", ""), nil, true)
                line.sub!(res, '')
              end
            end
            return line
        end

        def clinker_libraries_path(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /-L/
            ana_line = line.split()
            ana_line.each do |res|
              result  = res.match(pattern)
              if (result)
                @logger.debug("recognize #{res}")
                @file.armCLinkerTab.librariesTab.add_library_search_path(target, res.gsub("-L", ""), nil, true)
                line.sub!(res, '')
              end
            end
            return line
        end

        def clinker_set_memory_load_image(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /memoryimage=(?<value>.*)/
            ana_line = line.split()
            ana_line.each do |res|
              result  = res.match(pattern)
              if (result)
                @logger.debug("recognize #{res}")
                @file.clinker_set_memory_load_image(target, $~[:value])
                line.sub!(res, '')
              end
            end
            return line
        end

        def clinker_set_memory_section(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /isd=/
            ana_line = line.split()
            ana_line.each do |res|
              result  = res.match(pattern)
              if (result)
                @logger.debug("recognize #{res}")
                @file.clinker_set_memory_section(target, res)
                line.sub!(res, '')
              end
            end
            return line
        end

        def clinker_other_linker_options(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            stack_heap_hash = Hash.new()
            stack_heap_hash['heap'] = nil
            stack_heap_hash['stack'] = nil
            pattern = /\s-Xlinker\s("[^"]+"|\S+)/
            pattern1 = /^--defsym=(?<stackorheap>__stack_size__|__heap_size__)=(?<size>\w+)/
            pattern2 = /^--defsym=(?<stackorheap>__stack_size__|__heap_size__)=(?<size>\w+)&&region=(?<region>\w+)&&location=(?<location>\w+)/
            while (true)
                result = line.match(pattern)
                break unless (result)
                @logger.debug("recognize #{result[1]}")
                testvalue = result[1].to_s.match(pattern1)
                if testvalue
                    stackandheap = result[1].to_s.match(pattern2)
                    if stackandheap
                        if stackandheap[2].to_s.start_with?('0x') or stackandheap[2].to_s.include?('Default')
                            sizenumber = stackandheap[2].to_s
                        else
                            sizenumber = "0x" + stackandheap[2].to_i.to_s(16)
                        end
                        if stackandheap[1] == '__heap_size__'
                            if stackandheap[4].to_s.downcase.include? 'post'
                                hlocation = 'Post Data'
                            else
                                hlocation = stackandheap[4]
                            end
                            stack_heap_hash['heap'] = "&Heap:#{stackandheap[3]};#{hlocation};#{sizenumber}"
                        end
                        if stackandheap[1] == '__stack_size__'
                            if stackandheap[4].to_s.downcase.include? 'post'
                                slocation = 'Post Data'
                            else
                                slocation = stackandheap[4]
                            end
                            stack_heap_hash['stack'] = "&Stack:#{stackandheap[3]};#{slocation};#{sizenumber}"
                        end
                    else
                        if testvalue[2].to_s.start_with?('0x') or testvalue[2].to_s.include?('Default')
                            sizenumber1 = testvalue[2].to_s
                        else
                            sizenumber1 = "0x" + testvalue[2].to_i.to_s(16)
                        end
                        if testvalue[1] == '__heap_size__'
                            stack_heap_hash['heap'] = "&Heap:Default;Default;#{sizenumber1}"
                        end
                        if testvalue[1] == '__stack_size__'
                            stack_heap_hash['stack'] = "&Stack:Default;Default;#{sizenumber1}"
                        end
                    end
                else
                    @file.clinker_set_other_linker_options(target, result[1])
                end
                line.sub!(result[0], '')
            end

            if stack_heap_hash['heap'] or stack_heap_hash['stack']
                unless stack_heap_hash['heap']
                    stack_heap_hash['heap'] = "&Heap:Default;Default;Default"
                end
                unless stack_heap_hash['stack']
                    stack_heap_hash['stack'] = "&Stack:Default;Default;Default"
                end
                stringfinal = stack_heap_hash['heap'] + stack_heap_hash['stack']
                if stringfinal
                    @file.clinker_set_linker_heap_stack(target, stringfinal)
                end
            end
            return line
        end

        def clinker_set_secure_state(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s*-((non)?secure)/
            result  = if line.match(pattern)
                          line.match(pattern)
                      else
                          line.match(/\s*-(none)/)
                      end
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.clinker_add_secure_state(target, result[1])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def clinker_set_other_objects(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # match Other objects linker flags
            pattern = /\${workspace_loc:\/\S+}|\${proj_loc:\s?\/\S+}/
            result  = line.match(pattern)
            while (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.clinker_add_other_objects(target, result[ 0 ])
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            return line
        end

        def clinker_undefined_symbol(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s?(-u\s\S+)\s/
            result  = line.match(pattern)
            while (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.clinker_add_linker_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            return line
        end

        def clinker_other_flag(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s(--coverage)/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.clinker_add_linker_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            end

            # handle misc flag
            pattern = /\s\{misc_flags_start\}(.*?)\{misc_flags_end\}/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.clinker_add_linker_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
            end

            line.clear
            return line
        end

        ### C++ Compiler Options
        def cpplinker_set_other_objects(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # match Other objects linker flags
            pattern = /\${workspace_loc:\/\S+}|\${proj_loc:\s?\/\S+}/
            result  = line.match(pattern)
            while (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.cpplinker_add_other_objects(target, result[ 0 ])
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            return line
        end

        def cpplinker_set_secure_state(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s*-((non)?secure)/
            result  = if line.match(pattern)
                          line.match(pattern)
                      else
                          line.match(/\s*-(none)/)
                      end
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.cpplinker_add_secure_state(target, result[1])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def cpplinker_toram(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-toram=(true|false)\s/
            result  = line.match(pattern)
            if (result)
                if true == result[1]
                    @logger.debug("recognize #{result[ 0 ]}")
                    @file.cpplinker_add_linker_toram(target, true)
                    line.sub!(result[ 0 ], '')
                end
            end
            return line
        end

        def cpplinker_memory_data(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /memorydata=(?<value>.*)/
            ana_line = line.split()
            ana_line.each do |res|
              result  = res.match(pattern)
              if (result)
                @logger.debug("recognize #{res}")
                @file.cpplinker_set_memory_data(target, $~[:value])
                line.sub!(res, '')
              end
            end
            return line
        end

        def cppcompiler_family(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-mcpu=(cortex-m0|cortex-m0plus|cortex-m4|cortex-m7)\s/
            result  = line.match(pattern)
            if (result)
                convert = {
                    'cortex-m7'     => 'cm7',
                    'cortex-m4'     => 'cm4',
                    'cortex-m3'     => 'cm3',
                    'cortex-m1'     => 'cm1',
                    'cortex-m0plus' => 'cm0plus',
                    'cortex-m0'     => 'cm0',
                    'cortex-m0plusmul' => 'cm0plus.smallmul',
                    'cortex-m0mul' => 'cm0.smallmul'
                }
                @logger.debug("recognize #{result[ 0 ]}")
                @file.cppcompiler_set_architecture(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("no family set!")
            end
            return line
        end

        def cppcompiler_fpu(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # find mfpu
            pattern = /\s-mfpu=(fpv4-sp-d16|vfp|fpv5-sp-d16|fpv5-d16)\s/
            mfpu = line.match(pattern)
            if (mfpu)
                line.sub!(mfpu[ 0 ], '')
                mfpu = mfpu[1]
            end
            # find mfloat-abi
            pattern = /\s-mfloat-abi=(hard|soft|softfp)\s/
            mfloat_abi = line.match(pattern)
            if (mfloat_abi)
                line.sub!(mfloat_abi[ 0 ], '')
                mfloat_abi = mfloat_abi[1]
            end
            convert = {
                '-'                     => 'none',
                'soft-'                 => 'none',
                'softfp-vfp'            => 'vfp',
                'softfp-fpv4-sp-d16'    => 'fpv4',
                'hard-fpv4-sp-d16'      => 'fpv4.hard',
                'hard-fpv5-sp-d16'      => 'fpv5sp.hard',
                'hard-fpv5-d16'         => 'fpv5dp.hard',
                'soft-fpv5-d16'         => 'fpv5dp'
            }
            convertkey = "#{mfloat_abi}-#{mfpu}"
            if (convert.key?(convertkey))
                value = convert[ convertkey ]
                @file.cppcompiler_set_floating_point(target, value)
            else
                @logger.debug("invalid combination fpu '#{mfpu}' and abi '#{mfloat_abi}'")
            end
            return line
        end

        def cppcompiler_language(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-(std=gnu\+\+98|std=gnu\+\+11|std=c\+\+98|std=c\+\+11|std=c\+\+1y)\s/
            result  = line.match(pattern)
            if (result)
                convert = {
                    'std=gnu++98'   => 'gnupp98',
                    'std=gnu++03'   => 'gnupp03',
                    'std=gnu++11'   => 'gnupp11',
                    'std=gnu++14'   => 'gnupp14',
                    'std=c++98' => 'cpp98',
                    'std=c++03' => 'cpp03',
                    'std=c++11' => 'cpp11',
                    'std=c++14' => 'cpp14',
                }
                @logger.debug("recognize #{result[ 0 ]}")
                @file.cppcompiler_set_language_standard(target, convert[ result[1] ])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("no language set!")
            end
            return line
        end

        def cppcompiler_debug_level(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-(g|g1|g3|g0)\s/
            result  = line.match(pattern)
            if (result)
                convert = {'g' => 'default', 'g1' => 'minimal', 'g3' => 'max', 'g0' => 'none'}
                @logger.debug("recognize #{result[ 0 ]}")
                @file.cppcompiler_set_debugging_level(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def cppcompiler_inhibit_all_warnings(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-w\s/
            result  = line.match(pattern)
            if (result)
                @file.cppcompiler_inhibit_all_warnings(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.cppcompiler_inhibit_all_warnings(target, false)
            end
            return line
        end

        def cppcompiler_warnings_wall(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-Wall\s/
            result  = line.match(pattern)
            if (result)
                @file.cppcompiler_set_all_warnings(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.cppcompiler_set_all_warnings(target, false)
            end
            return line
        end

        def cppcompiler_enable_extra_warnings(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-Wextra\s/
            result  = line.match(pattern)
            if (result)
                @file.cppcompiler_set_extra_warnings(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.cppcompiler_set_extra_warnings(target, false)
            end
            return line
        end

        def cppcompiler_warnings_implicit_conversion(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-Wconversion\s/
            result  = line.match(pattern)
            if (result)
                @file.cppcompiler_set_implicit_conversion_warnings(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.cppcompiler_set_implicit_conversion_warnings(target, false)
            end
            return line
        end

        def cppcompiler_generate_errors_instead_warnings(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-Werror\s/
            result  = line.match(pattern)
            if (result)
                @file.cppcompiler_set_warnings_as_errors(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.cppcompiler_set_warnings_as_errors(target, false)
            end
            return line
        end

        def cppcompiler_optimization_level(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-(O0|O1|O2|O3|Os|Og)\s/
            result  = line.match(pattern)
            if (result)
                convert = {
                    'O0' => 'none',
                    'O1' => 'optimize',
                    'O2' => 'more',
                    'O3' => 'most',
                    'Os' => 'size',
                    'Og' => 'general'
                }
                @file.cppcompiler_optimization_level(target, convert[result[ 1 ]])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("no optimization set!")
            end
            return line
        end

        def cppcompiler_enable_link_time_optimization(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-flto\s/
            result  = line.match(pattern)
            if (result)
                @file.cppcompiler_enable_link_time_optimization(target, true)
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def cppcompiler_optimization_flags(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-fno-common\s/
            result  = line.match(pattern)
            if (result)
                # puts result.inspect
                @file.cppcompiler_set_ccompiler_optimization_flags(target, result[0].strip)
                line.sub!(result[0], '')
            else
                @logger.debug("no optimization set!")
            end
            return line
        end

        def cppcompiler_nostdinc(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-nostdinc\+\+\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.cppcompiler_do_not_search_system_directories(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.cppcompiler_do_not_search_system_directories(target, false)
            end
            return line
        end

        def cppcompiler_set_secure_state(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s*-((non)?secure)/
            result  = if line.match(pattern)
                          line.match(pattern)
                      else
                          line.match(/\s*-(none)/)
                      end
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.cppcompiler_add_secure_state(target, result[1])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def cppcompiler_other_flag(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            @file.cppcompiler_add_other_flags(target, line.strip)
            line.clear
            return line
        end

        ### C++ linker settings
        ###

        def cpplinker_family(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-mcpu=(cortex-m0|cortex-m0plus|cortex-m4|cortex-m7)\s/
            result  = line.match(pattern)
            if (result)
                convert = {
                    'cortex-m7' => 'cm7',
                    'cortex-m4' => 'cm4',
                    'cortex-m3' => 'cm3',
                    'cortex-m1' => 'cm1',
                    'cortex-m0' => 'cm0',
                    'cortex-m0plus' => 'cm0plus',
                    'cortex-m0sm' => 'cm0.smallmul',
                    'cortex-m0plussm' => 'cm0plus.smallmul',
                    'arm7tdmi' => 'a7',
                    'arm968es' => 'a968e',
                    'arm926ejs' => 'a926ej'
                }
                @logger.debug("recognize #{result[ 0 ]}")
                @file.cpplinker_set_architecture(target, convert[result[1]])
                line.sub!(result[ 0 ], '')
            else
                @logger.debug("no family set!")
            end
            return line
        end

        def cpplinker_fpu(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            # find mfpu
            pattern = /\s-mfpu=(fpv4-sp-d16|vfp|fpv5-sp-d16|fpv5-d16)\s/
            mfpu = line.match(pattern)
            if (mfpu)
                line.sub!(mfpu[ 0 ], '')
                mfpu = mfpu[1]
            end
            # find mfloat-abi
            pattern = /\s-mfloat-abi=(hard|soft|softfp)\s/
            mfloat_abi = line.match(pattern)
            if (mfloat_abi)
                line.sub!(mfloat_abi[ 0 ], '')
                mfloat_abi = mfloat_abi[1]
            end
            convert = {
                '-'                     => 'none',
                'soft-'                 => 'none',
                'softfp-vfp'            => 'vfp',
                'softfp-fpv4-sp-d16'    => 'fpv4',
                'hard-fpv4-sp-d16'      => 'fpv4.hard',
                'hard-fpv5-sp-d16'      => 'fpv5sp.hard',
                'hard-fpv5-d16'         => 'fpv5dp.hard',
                'soft-fpv5-d16'         => 'fpv5dp'
            }
            convertkey = "#{mfloat_abi}-#{mfpu}"
            if (convert.key?(convertkey))
                value = convert[ convertkey ]
                @file.cpplinker_set_floating_point(target, value)
            else
                @logger.debug("invalid combination fpu '#{mfpu}' and abi '#{mfloat_abi}'")
            end
            return line
        end

        def cpplinker_nostartfiles(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-nostartfiles\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.cpplinker_set_standard_start_files(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.cpplinker_set_standard_start_files(target, false)
            end
            return line
        end

        def cpplinker_nodefaultlibs(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-nodefaultlibs\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.cpplinker_set_use_default_libraries(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.cpplinker_set_use_default_libraries(target, false)
            end
            return line
        end

        def cpplinker_nostdlib(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-nostdlib\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.cpplinker_set_no_startup_or_default_libs(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.cpplinker_set_no_startup_or_default_libs(target, false)
            end
            return line
        end

        def cpplinker_omit_all_symbols(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-s\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.cpplinker_omit_all_symbol_information(target, true)
                line.sub!(result[ 0 ], '')
            else
                @file.cpplinker_omit_all_symbol_information(target, false)
            end
            return line
        end

        def cpplinker_set_memory_load_image(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /memoryimage=(?<value>.*)/
            ana_line = line.split()
            ana_line.each do |res|
              result  = res.match(pattern)
              if (result)
                @logger.debug("recognize #{res}")
                @file.cpplinker_set_memory_load_image(target, $~[:value])
                line.sub!(res, '')
              end
            end
            return line
        end

        def cpplinker_set_memory_section(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /isd=/
            ana_line = line.split()
            ana_line.each do |res|
              result  = res.match(pattern)
              if (result)
                @logger.debug("recognize #{res}")
                @file.cpplinker_set_memory_section(target, res)
                line.sub!(res, '')
              end
            end
            return line
        end

        def cpplinker_other_linker_options(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            stack_heap_hash = Hash.new()
            stack_heap_hash['heap'] = nil
            stack_heap_hash['stack'] = nil
            pattern = /\s-Xlinker\s("[^"]+"|\S+)/
            pattern1 = /^--defsym=(?<stackorheap>__stack_size__|__heap_size__)=(?<size>\w+)/
            pattern2 = /^--defsym=(?<stackorheap>__stack_size__|__heap_size__)=(?<size>\w+)&&region=(?<region>\w+)&&location=(?<location>\w+)/
            while (true)
                result = line.match(pattern)
                break unless (result)
                @logger.debug("recognize #{result[1]}")
                testvalue = result[1].to_s.match(pattern1)
                if testvalue
                    stackandheap = result[1].to_s.match(pattern2)
                    if stackandheap
                        if stackandheap[2].to_s.start_with?('0x') or stackandheap[2].to_s.include?('Default')
                            sizenumber = stackandheap[2].to_s
                        else
                            sizenumber = "0x" + stackandheap[2].to_i.to_s(16)
                        end
                        if stackandheap[1] == '__heap_size__'
                            if stackandheap[4].to_s.downcase.include? 'post'
                                hlocation = 'Post Data'
                            else
                                hlocation = stackandheap[4]
                            end
                            stack_heap_hash['heap'] = "&Heap:#{stackandheap[3]};#{hlocation};#{sizenumber}"
                        end
                        if stackandheap[1] == '__stack_size__'
                            if stackandheap[4].to_s.downcase.include? 'post'
                                slocation = 'Post Data'
                            else
                                slocation = stackandheap[4]
                            end
                            stack_heap_hash['stack'] = "&Stack:#{stackandheap[3]};#{slocation};#{sizenumber}"
                        end
                    else
                        if testvalue[2].to_s.start_with?('0x') or testvalue[2].to_s.include?('Default')
                            sizenumber1 = testvalue[2].to_s
                        else
                            sizenumber1 = "0x" + testvalue[2].to_i.to_s(16)
                        end
                        if testvalue[1] == '__heap_size__'
                            stack_heap_hash['heap'] = "&Heap:Default;Default;#{sizenumber1}"
                        end
                        if testvalue[1] == '__stack_size__'
                            stack_heap_hash['stack'] = "&Stack:Default;Default;#{sizenumber1}"
                        end
                    end
                else
                    @file.cpplinker_set_other_linker_options(target, result[1])
                end
                line.sub!(result[0], '')
            end

            if stack_heap_hash['heap'] or stack_heap_hash['stack']
                unless stack_heap_hash['heap']
                    stack_heap_hash['heap'] = "&Heap:Default;Default;Default"
                end
                unless stack_heap_hash['stack']
                    stack_heap_hash['stack'] = "&Stack:Default;Default;Default"
                end
                stringfinal = stack_heap_hash['heap'] + stack_heap_hash['stack']
                if stringfinal
                    @file.cpplinker_set_linker_heap_stack(target, stringfinal)
                end
            end
            return line
        end

        def cpplinker_undefined_symbol(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s?(-u\s\S+?)\s/
            result  = line.match(pattern)
            while (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.cpplinker_add_linker_flag(target, result[ 1 ])
                line.sub!(result[ 0 ], '')
                result = line.match(pattern)
            end
            return line
        end

        def cpplinker_other_flag(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s(--coverage)/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize: #{result[ 0 ]}")
                @file.cpplinker_add_linker_flag(target, result[ 1 ])
            end
            line.clear
            return line
        end


        # Set lib head configuration will only be done once and I have chosen to ignore it in the cpplinker_libheader
        def cpplinker_libheader(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-lib=(?<compiler>\w+)\.(?<linker>\w+)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                # @file.c_cpp_linker_setlibheader(target, $~[:compiler], $~[:linker])
                line.sub!(result[ 0 ], '')
            end
            return line
        end

        def clinker_libheader(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            pattern = /\s-lib=(?<compiler>\w+)\.(?<linker>\w+)\s/
            result  = line.match(pattern)
            if (result)
                @logger.debug("recognize #{result[ 0 ]}")
                @file.c_cpp_linker_setlibheader(target, $~[:compiler], $~[:linker])
                line.sub!(result[ 0 ], '')
            end
            return line
        end
        # archiver settings
        def archiver_flags(target, line)
            Core.assert(target.is_a?(String), "not a string")
            Core.assert(line.is_a?(String), "not a string")
            if (line)
                @logger.debug("recognize line")
                @file.archiver_set_flags(target, line)
            end
            line.clear
            return line
        end

    end

end
end
