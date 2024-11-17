# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/mcux/_flags'
require_relative '../../internal/_flags_interface'
require_relative '../../../../../utils/sdk_utils'

module Mcux
  module Common
    class Flags < Internal::Mcux::Flags
      # consuming interface
      include Internal::FlagsInterface
      include SDKGenerator::SDKUtils

      def analyze_asflags(target, line)
        line = assembler_family(target, line)
        line = assembler_fpu(target, line)
        line = assembler_suppress_warning(target, line)
      end

      def analyze_ccflags(target, line)
        line = ccompiler_family(target, line)
        line = ccompiler_fpu(target, line)
        line = ccompiler_language(target, line)
        line = ccompiler_debug_level(target, line)
        line = ccompiler_inhibit_all_warnings(target, line)
        line = ccompiler_warnings_wall(target, line)
        line = ccompiler_enable_extra_warnings(target, line)
        line = ccompiler_warnings_implicit_conversion(target, line)
        line = ccompiler_generate_errors_instead_warnings(target, line)
        line = ccompiler_optimization_level(target, line)
        line = ccompiler_nostdinc(target, line)
      end

      def analyze_cxflags(target, line)
        line = cppcompiler_family(target, line)
        line = cppcompiler_fpu(target, line)
        line = cppcompiler_language(target, line)
        line = cppcompiler_debug_level(target, line)
        line = cppcompiler_inhibit_all_warnings(target, line)
        line = cppcompiler_warnings_wall(target, line)
        line = cppcompiler_enable_extra_warnings(target, line)
        line = cppcompiler_warnings_implicit_conversion(target, line)
        line = cppcompiler_generate_errors_instead_warnings(target, line)
        line = cppcompiler_optimization_level(target, line)
        line = cppcompiler_optimization_flags(target, line)
        line = cppcompiler_nostdinc(target, line)
      end

    end
  end
end
