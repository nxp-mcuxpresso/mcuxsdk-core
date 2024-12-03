# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/xtensa/_flags'
require_relative '../../internal/_app_flags_interface'

module Xtensa
  module App
    class Flags < Internal::Xtensa::Flags
      # consuming interface
      include Internal::AppFlagsInterface
      def analyze_asflags(line)
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("asflags line: #{line}")
        line = line.tr('%', '$')
        line = assembler_include_debug_info(line)
        line = assembler_supress_warnings(line)
        line = assembler_enable_long_calls(line)
        line = assembler_place_literals(line)
        line = compiler_addl_assembler(line)
      end

      def analyze_ccflags(line)
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("ccflags line: #{line}")
        line = line.tr('%', '$')
        # Common setting
        line = compiler_optomization(line)
        line = compiler_debug(line)
        line = compiler_keepIntermediateFiles(line)
        line = compiler_enable_interprocedural_optimization(line)
        line = compiler_use_dsp_coprocessor(line)
        line = compiler_not_serialize_volatile(line)
        line = compiler_literals(line)
        line = compiler_use_feedback(line)
        line = compiler_optomization_for_size(line)
        line = compiler_optomization_alias(line)
        line = compiler_auto_vectorization(line)
        line = compiler_vectorize_with_ifs(line)
        line = compiler_params_aligned(line)
        line = compiler_connection_box_optimization(line)
        line = compiler_produce_w2c_file(line)
        line = compiler_enable_long_calls(line)
        line = compiler_create_separate_func(line)
        line = compiler_generate_optimization_file(line)
        line = compiler_use_optimization_file(line)
        line = compiler_warning_settings(line)
        line = compiler_warning_as_errors(line)
        line = compiler_disable_gnu_extensions(line)
        line = compiler_signed_char_default(line)
        line = compiler_enable_strict_ansi_warning(line)
        line = compiler_support_cpp_exception(line)
        line = compiler_language_dialect(line)
        line = compiler_addl_compiler(line)
      end

      def analyze_cxflags(line)
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("cxflags line: #{line}")
        line = line.tr('%', '$')
        # Common setting
        line = cpp_compiler_language_dialect(line)
        line = cpp_compiler_standard_library(line)
      end

      def analyze_cc_for_as_flags(line)
        line = line.tr('%', '$')
        line = compiler_cc_options_for_assembler(line)
      end

      def analyze_ldflags(line)
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("ldflags line: #{line}")
        line = line.tr('%', '$')
        line = linker_support_package(line)
        line = linker_embed_map_info(line)
        line = linker_generator_map_file(line)
        line = linker_omit_debugger_symbol(line)
        line = linker_omit_all_symbol(line)
        line = linker_enable_interprocedural_analysis(line)
        line = linker_control_linker_order(line)
        line = linker_hardware_profile(line)
        line = linker_iss_memory_debugger(line)
        line = linker_inlude_libxmp(line)
        line = linker_lib_search_path(line)
        line = linker_libraries(line)
        line = linker_addl_linker(line)
      end

      def analyze_cc_for_ld_flags(line)
        line = line.tr('%', '$')
        line = compiler_cc_options_for_linker(line)
      end
  end
  end
end
