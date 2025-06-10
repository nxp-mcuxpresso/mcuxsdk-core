# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/codewarrior/_flags'
require_relative '../../internal/_flags_interface'

module CodeWarrior
  module Common

    class Flags < Internal::CodeWarrior::Flags

      # consuming interface
      include Internal::FlagsInterface

      def analyze_asflags(target, line)
        line = assembler_no_syspath(target, line)
        line = assembler_data_memory_model(target, line)
        line = assembler_program_memory_model(target, line)
        line = assembler_pad_pipeline(target, line)
        line = assembler_hawk_elf(target, line)
        line = assembler_addl_assembler(target, line)
      end

      def analyze_ccflags(target, line)
        # Common setting
        line = compiler_optimization(target, line)
        line = compiler_program_mem_model(target, line)
        line = compiler_data_mem_model(target, line)
        line = compiler_pad_pipeline(target, line)
        line = compiler_globals_live(target, line)
        line = compiler_hawk_elf(target, line)
        line = compiler_language_c99(target, line)
        line = compiler_require_protos(target, line)
        line = compiler_addl_compiler(target, line)
      end

      def analyze_ldflags(target, line)
        line = linker_no_stdlib(target, line)
        line = linker_generate_map(target, line)
        line = linker_entry_point(target, line)
        line = linker_large_data_mem_model(target, line)
        line = linker_hawk_elf(target, line)
        line = linker_addl_lib(target, line)
        line = linker_addl_linker(target, line)
      end

    end
  end
end