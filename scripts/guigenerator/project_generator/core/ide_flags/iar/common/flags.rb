# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/iar/_flags'
require_relative '../../internal/_flags_interface'
module Iar
  module Common
    class Flags < Internal::Iar::Flags
      # consuming interface
      include Internal::FlagsInterface

      def analyze_devicedefines(target, line)
        line = common_device(target, line)
      end

      def analyze_asflags(target, line)
        line = common_cpu_fpu(target, line)
        line = assembler_debug_info(target, line)
        line = assembler_alternative_names(target, line)
        line = assembler_case_sensitivity(target, line)
        line = assembler_diagnostic(target, line)
        line = assembler_quotechar(target, line)
        line = assembler_dropflags(target, line)
        line = assembler_extra_flags(target, line)
        line = line.strip
        @logger.error("unrecognized '#{target}' asflags '#{line}' ") unless line.empty?
      end

      def analyze_ccflags(target, line)
        line = common_cpu_fpu(target, line)
        line = common_misra(target, line)
        line = library(target, line)
        line = compiler_c_dialect(target, line)
        line = compiler_preinclude_file(target, line)
        line = compiler_require_prototypes(target, line)
        line = compiler_suppress_diag(target, line)
        line = compiler_debug_info(target, line)
        line = compiler_inline_cpp(target, line)
        line = compiler_endian(target, line)
        line = compiler_secure(target, line)
        line = compiler_interworking(target, line)
        line = compiler_cpu_mode(target, line)
        line = compiler_optimization(target, line)
        line = compiler_strategy(target, line)
        line = compiler_optimization_strategy(target, line)
        line = compiler_nosize_constraints(target, line)
        line = compiler_cse(target, line)
        line = compiler_unroll(target, line)
        line = compiler_inline(target, line)
        line = compiler_code_motion(target, line)
        line = compiler_alias_analysis(target, line)
        line = compiler_clustering(target, line)
        line = compiler_scheduling(target, line)
        line = compiler_conformance(target, line)
        line = compiler_dropflags(target, line)
        line = compiler_vla(target, line)
        line = compiler_language_dialect(target, line)
        line = compiler_warnings_as_errors(target, line)
        line = compiler_extra_option(target, line)
        line = line.strip
        @logger.error("unrecognized '#{target}' ccflags '#{line}' ") unless line.empty?
      end

      def analyze_cxflags(target, line)
        line = common_cpu_fpu(target, line)
        line = compiler_cpp_rtti(target, line)
        line = compiler_cpp_exceptions(target, line)
        line = compiler_cplus_dialect(target, line)
        line = compiler_require_prototypes(target, line)
        line = compiler_suppress_diag(target, line)
        line = compiler_debug_info(target, line)
        line = compiler_inline_cpp(target, line)
        line = compiler_endian(target, line)
        line = compiler_interworking(target, line)
        line = compiler_cpu_mode(target, line)
        line = compiler_optimization(target, line)
        line = compiler_cse(target, line)
        line = compiler_unroll(target, line)
        line = compiler_inline(target, line)
        line = compiler_code_motion(target, line)
        line = compiler_alias_analysis(target, line)
        line = compiler_clustering(target, line)
        line = compiler_scheduling(target, line)
        line = compiler_conformance(target, line)
        line = compiler_dropflags(target, line)
        line = compiler_warnings_as_errors(target, line)
        line = compiler_extra_option(target, line)
        line = line.strip
        @logger.error("unrecognized '#{target}' cxflags '#{line}' ") unless line.empty?
      end

      def analyze_ldflags(target, line)
        line = line.strip
        @logger.error("unrecognized '#{target}' ldflags '#{line}' ") unless line.empty?
      end

      def analyze_arflags(target, line)
        line = line.strip
        @logger.error("unrecognized '#{target}' arflags '#{line}' ") unless line.empty?
      end
    end
  end
end
