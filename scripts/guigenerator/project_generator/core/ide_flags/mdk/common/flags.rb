# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/mdk/_flags'
require_relative '../../internal/_flags_interface'

module Mdk
  module Common

    class Flags < Internal::Mdk::Flags

      # consuming interface
      include Internal::FlagsInterface

      def analyze_devicedefines(target, line)
        line = common_device(target, line)
      end

      def analyze_asflags(target, line)
        line = common_debug_info(target, line)
        line = common_endian(target, line)
        line = assembler_interworking(target, line)
        line = assembler_split_ldm(target, line)
        line = assembler_xref(target, line)
        # armcc specific
        line = assembler_cpreproc(target, line)
        line = assembler_suppress(target, line)
        line = assembler_dropflags(target, line)
        # armclang specific
        line = assembler_preprocess_input(target, line)
        line = assembler_ro_independent(target, line)
        line = assembler_rw_independent(target, line)
        line = assembler_secure_mode(target, line)
        line = assembler_extra_option(target, line)
        line = line.strip()
        unless (line.empty?)
          @logger.error("unrecognized '#{target}' asflags '#{line}' ")
        end
      end

      def analyze_ccflags(target, line)
        line = common_browse_info(target, line)
        line = common_cpu_type(target, line)
        line = common_debug_info(target, line)
        line = compiler_preinclude_file(target, line)
        line = common_endian(target, line)
        line = compiler_secure(target, line)
        line = compiler_optimization(target, line)
        line = compiler_split_section(target, line)
        line = compiler_signed_char(target, line)
        line = compiler_split_ldm(target, line)
        # line = compile_library_type(target, line)
        line = compiler_interworking(target, line)
        line = compiler_standard_select(target, line)
        # armcc specific
        line = compiler_enum_is_int(target, line)
        line = compiler_library_interface(target, line)
        line = compiler_standard(target, line)
        line = compiler_suppress(target, line)
        line = compiler_dropflags(target, line)
        # armclang specific
        line = compiler_lto(target, line)
        line = compiler_ro_independent(target, line)
        line = compiler_rw_independent(target, line)
        line = compiler_short_enums_wchar(target, line)
        line = compiler_use_rtti(target, line)
        line = compiler_standard_cpp(target, line)
        line = compiler_warnings(target, line)
        line = compiler_warnings_as_errors(target, line)
        line = compiler_cpu_fpu_armclang(target, line)
        # move all other settings to Misc
        line = compiler_add_to_misc(target,line)
        # line = line.strip()
        # unless (line.empty?)
        # @logger.error("unrecognized '#{target}' ccflags '#{line}' ")
        # end
      end

      def analyze_cxflags(target, line)
        Core.assert(target.is_a?(String)) do
          "target is not a string '#{target}'"
        end
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("cxflags line: #{line}")
        # The comment lines has been set by cc-flags, no need to set again
        #line = common_browse_info(target, line)
        #line = common_cpu_type(target, line)
        #line = common_debug_info(target, line)
        #line = common_endian(target, line)
        #line = compiler_optimization(target, line)
        #line = compiler_split_section(target, line)
        #line = compiler_enum_is_int(target, line)
        #line = compiler_signed_char(target, line)
        #line = compiler_interworking(target, line)
        #line = compiler_standard(target, line)
        #line = compiler_suppress(target, line)
        #line = compiler_cpu_fpu_armclang(target, line)
        line = compiler_split_ldm(target, line)
        line = compiler_library_interface(target, line)
        line = compile_library_type(target, line)
        line = compiler_dropflags(target, line)
        # armclang specific
        line = compiler_lto(target, line)
        line = compiler_ro_independent(target, line)
        line = compiler_rw_independent(target, line)
        line = compiler_short_enums_wchar(target, line)
        line = compiler_use_rtti(target, line)
        line = compiler_standard_cpp(target, line)
        line = compiler_warnings(target, line)
        line = compiler_warnings_as_errors(target, line)
        line = compiler_exceptions(target, line)

        unless (line.empty?)
            @logger.debug("unrecognized '#{target}' cxflags '#{line}' ")
        end
      end
    end
  end
end