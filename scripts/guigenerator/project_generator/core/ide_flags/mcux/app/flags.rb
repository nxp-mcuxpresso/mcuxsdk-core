# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../common/flags'

module Mcux
  module App
    class Flags < Mcux::Common::Flags
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
        super(target, line)
        line = ccompiler_enable_link_time_optimization(target, line)
        line = ccompiler_optimization_flags(target, line)
        line = ccompiler_set_secure_state(target, line)
        @logger.debug("ccflags other flags: #{line}")
        line = ccompiler_other_flag(target, line)
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
        line = cppcompiler_enable_link_time_optimization(target, line)
        line = cppcompiler_set_secure_state(target, line)
        @logger.debug("ccflags other flags: #{line}")
        line = cppcompiler_other_flag(target, line)
      end

      def analyze_ldflags(target, line)
        Core.assert(target.is_a?(String)) do
          "target is not a string '#{target}'"
        end
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("ldflags line: #{line}")
        c_line = deep_copy(line)
        cpp_line = deep_copy(line)
        # The following is for cpp link
        cpp_line = cpplinker_family(target, cpp_line)
        cpp_line = cpplinker_fpu(target, cpp_line)
        cpp_line = cpplinker_nostartfiles(target, cpp_line)
        cpp_line = cpplinker_nodefaultlibs(target, cpp_line)
        cpp_line = cpplinker_nostdlib(target, cpp_line)
        # cpp_line = cpplinker_libraries(target, cpp_line)
        # cpp_line = cpplinker_libraries_path(target, cpp_line)
        cpp_line = cpplinker_omit_all_symbols(target, cpp_line)
        cpp_line = cpplinker_toram(target, cpp_line)
        cpp_line = cpplinker_memory_data(target, cpp_line)
        cpp_line = cpplinker_set_memory_load_image(target, cpp_line)
        cpp_line = cpplinker_set_memory_section(target, cpp_line)
        cpp_line = cpplinker_other_linker_options(target, cpp_line)
        cpp_line = cpplinker_libheader(target, cpp_line)
        @logger.debug("ldflags(c++) other flags: #{cpp_line}")
        cpp_line = cpplinker_undefined_symbol(target, cpp_line)
        cpp_line = cpplinker_set_secure_state(target, cpp_line)
        cpp_line = cpplinker_set_other_objects(target, cpp_line)
        cpp_line = cpplinker_other_flag(target, cpp_line)
        # The following is for c link
        c_line = clinker_family(target, c_line)
        c_line = clinker_fpu(target, c_line)
        c_line = clinker_nostartfiles(target, c_line)
        c_line = clinker_nodefaultlibs(target, c_line)
        c_line = clinker_nostdlib(target, c_line)
        c_line = clinker_omit_all_symbols(target, c_line)
        c_line = clinker_nostaticlib(target, c_line)
        # c_line = clinker_set_link_manage(target, c_line)
        # c_line = clinker_set_link_flashconfigenable(target, c_line)
        c_line = clinker_toram(target, c_line)
        c_line = clinker_memory_data(target, c_line)
        c_line = clinker_set_memory_load_image(target, c_line)
        c_line = clinker_set_memory_section(target, c_line)
        c_line = clinker_other_linker_options(target, c_line)
        c_line = clinker_set_secure_state(target, c_line)
        c_line = clinker_set_other_objects(target, c_line)
        # This is the lib head setting. Basically, for c or cpp, I will update all the c/cpp id
        c_line = clinker_libheader(target, c_line)
        c_line = clinker_undefined_symbol(target, c_line)
        c_line = clinker_other_flag(target, c_line)
      end
    end
  end
end
