# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/xcc/_flags'
require_relative '../../internal/_app_flags_interface'


module Xcc
    module App

        class Flags < Internal::Xcc::Flags

            # consuming interface
            include Internal::AppFlagsInterface

            def analyze_asflags(target, line)
                Core.assert(target.is_a?(String)) do
                    "target is not a string '#{target}'"
                end
                Core.assert(line.is_a?(String)) do
                    "line is not a string '#{line}'"
                end
                @logger.debug("asflags line: #{line}")
                lists = line.split()
                lists.each do |v|
                    v.gsub!('%','$') if v.match(/\%{\w+}/)
                    @file.add_as_flags(target, v)
                end
                #line = line.strip()
                #unless (line.empty?)
                #    @logger.error("unrecognized '#{target}' asflags '#{line}' ")
                #end
            end

            def analyze_ccflags(target, line)
                Core.assert(target.is_a?(String)) do
                    "target is not a string '#{target}'"
                end
                Core.assert(line.is_a?(String)) do
                    "line is not a string '#{line}'"
                end
                @logger.debug("ccflags line: #{line}")
                lists = line.split()
                lists.each do |v|
                    v.gsub!('%','$') if v.match(/\%{\w+}/)
                    @file.add_cc_flags(target, v)
                end
                #line = line.strip()
                #unless (line.empty?)
                #    @logger.error("unrecognized '#{target}' ccflags '#{line}' ")
                #end
            end
            # -------------------------------------------------------------------------------------
            # Analyze compiler flags for source file
            # @param [String] target: target
            # @param [Hash] cc_flags_for_src: key is target,value is a Hash which uses path as key and a string contains all flags as value
            # @return [nil]
            def analyze_ccflags_for_src(target, cc_flags_for_src)
                Core.assert(target.is_a?(String)) do
                    "target is not a string '#{target}'"
                end
                Core.assert(cc_flags_for_src.is_a?(Hash)) do
                    "cc_flags_for_src is not a Hash '#{cc_flags_for_src}'"
                end
                @logger.debug("ccflags: #{cc_flags_for_src}")
                cc_flags_for_src[target].each do |path, flag|
                    lists = flag.split()
                    lists.each do |v|
                        v.gsub!('%','$') if v.match(/\%{\w+}/)
                        @file.add_cc_flags_for_src(target, path, v)
                    end
                end
            end

            def analyze_cxflags(target, line)
                Core.assert(target.is_a?(String)) do
                    "target is not a string '#{target}'"
                end
                Core.assert(line.is_a?(String)) do
                    "line is not a string '#{line}'"
                end
                @logger.debug("cxflags line: #{line}")
                lists = line.split()
                lists.each do |v|
                    v.gsub!('%','$') if v.match(/\%{\w+}/)
                    @file.add_cxx_flags(target, v)
                end
                #line = line.strip()
                #unless (line.empty?)
                #    @logger.error("unrecognized '#{target}' cxflags '#{line}' ")
                #end
            end

            def analyze_ldflags(target, line)
                Core.assert(target.is_a?(String)) do
                    "target is not a string '#{target}'"
                end
                Core.assert(line.is_a?(String)) do
                    "line is not a string '#{line}'"
                end
                @logger.debug("ldflags line: #{line}")
                lists = line.split()
                lists.each do |v|
                    v.gsub!('%','$') if v.match(/\%{\w+}/)
                    @file.add_linker_flags(target, v)
                end
                #line = line.strip()
                #unless (line.empty?)
                #    @logger.error("unrecognized '#{target}' ldflags '#{line}' ")
                #end
            end
        end
    end
end

