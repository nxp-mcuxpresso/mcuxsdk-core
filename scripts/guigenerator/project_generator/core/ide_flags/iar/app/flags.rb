# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../common/flags'

module Iar
  module App
    class Flags < Iar::Common::Flags
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
        line = common_cmsis(target, line)
        super(target, line)
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
          line = compiler_strategy_for_src(target, path, line)
          line = compiler_optimization_strategy_for_src(target, path, line)
          line = compiler_nosize_constraints_for_src(target, path, line)
          line = compiler_extra_option_for_src(target, path, line)
          line = line.strip
          @logger.error("unrecognized '#{target}' ccflags '#{line}' ") unless line.empty?
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
        return if line.strip.empty?
        line = compiler_strategy(target, line)
        line = compiler_optimization_strategy(target, line)
        line = compiler_nosize_constraints(target, line)
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
        line = linker_entry_symbol(target, line)
        line = linker_keep_symbols(target, line)
        line = linker_raw_binary_image(target, line)
        line = linker_printf_formatter(target, line)
        line = linker_scanf_formatter(target, line)
        line = linker_buffered_terminal_output(target, line)
        line = linker_redirect_swo(target, line)
        line = linker_redirect_symbols(target, line)
        line = linker_place_holder(target, line)
        line = linker_dropflags(target, line)
        line = linker_read_command_file(target, line)
        line = linker_fill_settings(target, line)
        line = linker_suppress_diag(target, line)
        line = linker_configfile_defines(target, line)
        line = linker_semihosted(target, line)
        line = linker_tz_import_lib(target, line)
        line = linker_extra_options(target, line)
      end
  end
  end
end
