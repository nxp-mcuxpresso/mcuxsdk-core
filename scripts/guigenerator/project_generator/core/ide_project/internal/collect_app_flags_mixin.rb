# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Mixin
  module CollectAppFlags
    def analyze_enabled?
      return !(!@analyze_enabled)
  end

    def enable_analyze(value)
      # ensure for boolean value
      @analyze_enabled = value ? true : false
    end

    def collect_chipdefines_flags(target, flag)
      return unless analyze_enabled?
      @chipdefines_flags ||= {}
      @chipdefines_flags[target] = [] unless @chipdefines_flags[target]
      @chipdefines_flags[target].push(flag)
    end

    def collect_assembler_flags(target, flag)
      return unless analyze_enabled?
      @assembler_flags ||= {}
      @assembler_flags[target] = [] unless @assembler_flags[target]
      @assembler_flags[target].push(flag)
    end

    def collect_compiler_for_assembler_flags(target, flag)
      return unless analyze_enabled?
      @compiler_for_assembler_flags ||= {}
      @compiler_for_assembler_flags[target] = [] unless @compiler_for_assembler_flags[target]
      @compiler_for_assembler_flags[target].push(flag)
    end

    def collect_compiler_for_linker_flags(target, flag)
      return unless analyze_enabled?
      @compiler_for_linker_flags ||= {}
      @compiler_for_linker_flags[target] = [] unless @compiler_for_linker_flags[target]
      @compiler_for_linker_flags[target].push(flag)
    end

    def collect_compiler_flags(target, flag)
      return unless analyze_enabled?
      @compiler_flags ||= {}
      @compiler_flags[target] = [] unless @compiler_flags[target]
      @compiler_flags[target].push(flag)
    end

    # -------------------------------------------------------------------------------------
    # collect compiler flags on source level
    # @param [String] target: the target of the flags, could be debug, release and so on
    # @param [String] flag: compiler flags
    # @param [String] path: file's relative path
    # @return [Nil]
    def collect_compiler_flags_for_src(target, flag, path)
      return unless analyze_enabled?
      # @cc_flags_for_src is a Hash,key is target, value is a Hash which uses path as key and an array which contains the flags as value
      @cc_flags_for_src ||= {}
      @cc_flags_for_src[target] = {} unless @cc_flags_for_src[target]
      @cc_flags_for_src[target][path] = [] unless @cc_flags_for_src[target][path]
      @cc_flags_for_src[target][path].push(flag)
    end

    def collect_assembler_flags_for_src(target, flag, path)
      return unless analyze_enabled?
      # @as_flags_for_src is a Hash,key is target, value is a Hash which uses path as key and an array which contains the flags as value
      @as_flags_for_src ||= {}
      @as_flags_for_src[target] = {} unless @as_flags_for_src[target]
      @as_flags_for_src[target][path] = [] unless @as_flags_for_src[target][path]
      @as_flags_for_src[target][path].push(flag)
    end

    def collect_cpp_compiler_flags(target, flag)
      return unless analyze_enabled?
      @cpp_compiler_flags ||= {}
      @cpp_compiler_flags[target] = [] unless @cpp_compiler_flags[target]
      @cpp_compiler_flags[target].push(flag)
    end

    def collect_linker_flags(target, flag)
      return unless analyze_enabled?
      @linker_flags ||= {}
      @linker_flags[target] = [] unless @linker_flags[target]
      @linker_flags[target].push(flag)
    end

    def chipdefines_flagsline(target)
      return '' unless analyze_enabled?
      return '' unless @chipdefines_flags
      return '' unless @chipdefines_flags[target]
      return @chipdefines_flags[target].join(' ').to_s
    end

    def assembler_flagsline(target)
      return '' unless analyze_enabled?
      return '' unless @assembler_flags
      return '' unless @assembler_flags[target]
      return " #{@assembler_flags[target].join('  ')} "
    end

    def compiler_for_assembler_flagsline(target)
      return '' unless analyze_enabled?
      return '' unless @compiler_for_assembler_flags
      return '' unless @compiler_for_assembler_flags[target]
      return " #{@compiler_for_assembler_flags[target].join('  ')} "
    end

    def compiler_for_linker_flagsline(target)
      return '' unless analyze_enabled?
      return '' unless @compiler_for_linker_flags
      return '' unless @compiler_for_linker_flags[target]
      return " #{@compiler_for_linker_flags[target].join('  ')} "
    end

    def compiler_flagsline(target)
      return '' unless analyze_enabled?
      return '' unless @compiler_flags
      return '' unless @compiler_flags[target]
      return " #{@compiler_flags[target].join('  ')} "
    end

    # -------------------------------------------------------------------------------------
    # Assemble flags of the same file to a string
    # @param [String] name: the target of the flags
    # @return [Hash] @cc_flags_for_src: file's compiler flags, key is target,value is a Hash which uses path as key and a string contains all flags as value
    def compiler_flagsline_for_src(target)
      return '' unless analyze_enabled?
      return '' unless @cc_flags_for_src
      return '' unless @cc_flags_for_src[target]
      @cc_flags_for_src[target].each do |path, line|
        @cc_flags_for_src[target][path] = " #{line.join(' ')} "
      end
      return @cc_flags_for_src
    end

    def assembler_flagsline_for_src(target)
      return '' unless analyze_enabled?
      return '' unless @as_flags_for_src
      return '' unless @as_flags_for_src[target]
      @as_flags_for_src[target].each do |path, line|
        @as_flags_for_src[target][path] = " #{line.join(' ')} "
      end
      return @as_flags_for_src
    end

    def cpp_compiler_flagsline(target)
      return '' unless analyze_enabled?
      return '' unless @cpp_compiler_flags
      return '' unless @cpp_compiler_flags[target]
      return " #{@cpp_compiler_flags[target].join('  ')} "
    end

    def linker_flagsline(target)
      return '' unless analyze_enabled?
      return '' unless @linker_flags
      return '' unless @linker_flags[target]
      return " #{@linker_flags[target].join('  ')} "
    end
    end
end
