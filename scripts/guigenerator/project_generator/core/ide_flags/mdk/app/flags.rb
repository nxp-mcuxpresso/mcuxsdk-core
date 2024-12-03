# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../common/flags'

module Mdk
module App

    class Flags < Mdk::Common::Flags

        def is_lib?
            return false
        end
        def is_app?
            return true
        end

        def analyze_asflags(target, line)
            Core.assert(target.is_a?(String)) do
                "target is not a string '#{target}'"
            end
            Core.assert(line.is_a?(String)) do
                "line is not a string '#{line}'"
            end
            @logger.debug("asflags line: #{line}")
            line = assembler_cpreproc_opts(target, line)
            super(target, line)
        end

        def analyze_ccflags(target, line)
            Core.assert(target.is_a?(String)) do
                "target is not a string '#{target}'"
            end
            Core.assert(line.is_a?(String)) do
                "line is not a string '#{line}'"
            end
            @logger.debug("ccflags line: #{line}")
            super(target, line)
        end

        def analyze_cxflags(target, line)
            Core.assert(target.is_a?(String)) do
                "target is not a string '#{target}'"
            end
            Core.assert(line.is_a?(String)) do
                "line is not a string '#{line}'"
            end
            @logger.debug("cxflags line: #{line}")
            super(target, line)
        end

        def analyze_ldflags(target, line)
            Core.assert(target.is_a?(String)) do
                "target is not a string '#{target}'"
            end
            Core.assert(line.is_a?(String)) do
                "line is not a string '#{line}'"
            end
            @logger.debug("ldflags line: #{line}")
            line = linker_keep_symbols(target, line)
            line = linker_suppress(target, line)
            line = linker_remove_unused(target, line)
            line = linker_library_type(target, line)
            line = linker_auto_at(target, line)
            line = linker_memory_map(target, line)
            line = linker_list_callgraph(target, line)
            line = linker_list_symbols(target, line)
            line = linker_list_cross_reference(target, line)
            line = linker_list_size(target, line)
            line = linker_list_total(target, line)
            line = linker_list_unused(target, line)
            line = linker_list_veneers(target, line)
            line = linker_might_failed(target, line)
            line = linker_tz_import_lib(target, line)
            line = linker_dropflags(target, line)
            #move all other settings to Misc
            line = linker_add_to_misc(target,line)
            #line = line.strip()
            #unless (line.empty?)
            #    @logger.error("unrecognized '#{target}' ldflags '#{line}' ")
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
            @logger.debug("ccflags line: #{cc_flags_for_src}")
            cc_flags_for_src[target].each do |path, line|
                line = compiler_optimization_for_src(target, path, line)
                line = compiler_suppress_for_src(target, path, line)
                line = compiler_library_interface_for_src(target, path, line)
                line = compiler_standard_for_src(target, path, line)
            end
        end

        def analyze_asflags_for_src(target, as_flags_for_src)
            Core.assert(target.is_a?(String)) do
                "target is not a string '#{target}'"
            end
            Core.assert(as_flags_for_src.is_a?(Hash)) do
                "line is not a Hash '#{as_flags_for_src}'"
            end
            @logger.debug("asflags line: #{as_flags_for_src}")
            as_flags_for_src[target].each do |path, line|
                # add as misc flags
                line = assembler_misc_flags_for_src(target, path, line)
            end
        end
    end
end
end

