# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/_flags'

module Internal
  module Xtensa
    class Flags < Internal::Flags
      private

      #  compile compiler flags
      def compiler_optomization(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-O0|-O1|-O2|-O3)\s/
        result  = line.match(pattern)
        if result
          flag = result[1][0..1]
          level = result[1][2]
          @file.optimizationTab.optimization(flag, level)
          line.sub!(result[0], '')
        else
          @logger.debug('no optimization set!')
        end
        return line
      end

      def compiler_debug(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-g|-g0|-g1|-g2|-g3)\s/
        result  = line.match(pattern)
        if result
          flag = result[1][0..1]
          level = result[1][2] || '-3'
          @file.optimizationTab.debug(flag, level)
          line.sub!(result[0], '')
        else
          @logger.debug('no debug set!')
        end
        return line
      end

      def compiler_keepIntermediateFiles(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-save-temps)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.keepIntermediateFiles(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no keepIntermediateFiles set!')
        end
        return line
      end

      def compiler_enable_interprocedural_optimization(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-ipa)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.enableInterproceduralOptimization(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no interprocedural optimization set!')
        end
        return line
      end

      def compiler_use_dsp_coprocessor(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-mcoproc)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.useDspCoprocessor(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no use dsp coprocessor set!')
        end
        return line
      end

      def compiler_not_serialize_volatile(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-mno-serialize-volatile)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.notSerializeVolatile(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no not_serialize_volatile set!')
        end
        return line
      end

      def compiler_literals(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-mtext-section-literals)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.literals(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no put literals in section set!')
        end
        return line
      end

      def compiler_use_feedback(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-fb_reorder)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.useFeedback(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no use feedback set!')
        end
        return line
      end

      def compiler_optomization_for_size(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-Os)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.optomizationForSize(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no optimization for size set!')
        end
        return line
      end

      def compiler_optomization_alias(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-OPT:alias=restrict)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.optomizationAlias(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no optimization alias set!')
        end
        return line
      end

      def compiler_auto_vectorization(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-LNO:simd)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.autoVectorization(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no auto vectorization set!')
        end
        return line
      end

      def compiler_vectorize_with_ifs(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-LNO:simd_agg_if_conv)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.vectorizeWithIfs(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no vectorize with ifs set!')
        end
        return line
      end

      def compiler_params_aligned(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-LNO:aligned_formal_pointers=on)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.paramsAligned(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no assume parameters aligned set!')
        end
        return line
      end

      def compiler_connection_box_optimization(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-mcbox)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.connectionBoxOptimization(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no connection box optimization set!')
        end
        return line
      end

      def compiler_produce_w2c_file(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-clist)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.produceW2cFile(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no produce w2c file set!')
        end
        return line
      end

      def compiler_enable_long_calls(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-mlongcalls)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.enableLongCalls(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no enable long calls set!')
        end
        return line
      end

      def compiler_create_separate_func(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-ffunction-sections)\s/
        result  = line.match(pattern)
        if result
          @file.optimizationTab.createSeparateFunc(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no create separate func set!')
        end
        return line
      end

      def compiler_generate_optimization_file(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-fopt-gen)\s/
        result  = line.match(pattern)
        if result
          @file.advancedOptimizationTab.generateOptimizationFile(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no generate optimization file set!')
        end
        return line
      end

      def compiler_use_optimization_file(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-fopt-use)=(\S+)\s/
        result  = line.match(pattern)
        if result
          @file.advancedOptimizationTab.useOptimizationFile(result[1], result[2])
          line.sub!(result[0], '')
        else
          @logger.debug('no use optimization file set!')
        end
        return line
      end

      def compiler_warning_settings(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-Wall)\s/
        result  = line.match(pattern)
        result ||= line.match(/\s(-w)\s/)
        if result
          @file.warningsTab.warningSettings(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no warning settings set!')
        end
        return line
      end

      def compiler_warning_as_errors(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-Werror)\s/
        result  = line.match(pattern)
        if result
          @file.warningsTab.warningAsErrors(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no warning as errors set!')
        end
        return line
      end

      def compiler_disable_gnu_extensions(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-ansi)\s/
        result  = line.match(pattern)
        if result
          @file.languageTab.disableGnuExtension(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no disable gnu extension set!')
        end
        return line
      end

      def compiler_signed_char_default(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-fsigned-char)\s/
        result  = line.match(pattern)
        if result
          @file.languageTab.signedCharDefault(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no make char signed default set!')
        end
        return line
      end

      def compiler_enable_strict_ansi_warning(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-pedantic)\s/
        result  = line.match(pattern)
        if result
          @file.languageTab.enableStrictAnsiWarning(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no enable strict ansi warning set!')
        end
        return line
      end

      def compiler_support_cpp_exception(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-fexceptions)\s/
        result  = line.match(pattern)
        if result
          @file.languageTab.supportCppException(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no support cpp exception set!')
        end
        return line
      end

      def compiler_language_dialect(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-std=c99)\s/
        result  = line.match(pattern)
        if result
          @file.languageTab.languageDialect(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no language dialect set!')
        end
        return line
      end

      def compiler_addl_compiler(line)
        Core.assert(line.is_a?(String), 'not a string')
        @file.addlCompilerTab.additionalOptions(line.strip.split(' ').join("\r\n")) unless line.strip.empty?
        return line
      end

      def cpp_compiler_language_dialect(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-std=c\+\+11|-std=c\+\+14)\s/
        result  = line.match(pattern)
        if result
          @file.languageTab.languageDialectCpp(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no language dialect set!')
        end
        return line
      end

      def cpp_compiler_standard_library(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(--stdlib=libc\+\+)\s/
        result  = line.match(pattern)
        if result
          @file.languageTab.standardCppLibrary(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no language dialect set!')
        end
        return line
      end

      # assemble flag
      def assembler_include_debug_info(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(--gdwarf-2)\s/
        result  = line.match(pattern)
        if result
          @file.assemblerTab.includeDebugInfo(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no language dialect set!')
        end
        return line
      end

      def assembler_supress_warnings(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-W)\s/
        result  = line.match(pattern)
        if result
          @file.assemblerTab.supressWarnings(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no supress warnings set!')
        end
        return line
      end

      def assembler_enable_long_calls(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(--longcalls)\s/
        result  = line.match(pattern)
        if result
          @file.assemblerTab.enableLongCalls(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no enable long calls set!')
        end
        return line
      end

      def assembler_place_literals(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(--text-section-literals)\s/
        result  = line.match(pattern)
        if result
          @file.assemblerTab.placeLiteralsInText(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no place literals set!')
        end
        return line
      end

      def compiler_addl_assembler(line)
        Core.assert(line.is_a?(String), 'not a string')
        @file.addlAssemblerTab.additionalOptions(line.strip.split(' ').join("\r\n")) unless line.strip.empty?
        return line
      end

      def compiler_cc_options_for_assembler(line)
        Core.assert(line.is_a?(String), 'not a string')
        @file.compilerOptionsForAssemblerTab.compilerOptions(line.strip.split(' ').join("\r\n")) unless line.strip.empty?
        return line
      end

      def linker_support_package(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-mlsp)=(\S+)\s/
        standard_support = ['sim', 'sim-local', 'sim-stacklocal', 'sim-rom',
                            'gdbio', 'gdbio-local', 'gdbio-stacklocal', 'gdbio-rom', 'ngo-sample-gdbio',
                            'linux', 'piload', 'pisplitload', 'min-rt', 'min-rt-rom', 'min-rt-local',
                            'nort', 'nort-rom', 'rtos-ram', 'rtos-ramp', 'rtos-res', 'rtos-rom', 'tiny', 'tiny-rom',
                            'xtml605-rt', 'xtml605-rt-rom', 'xtkc705-rt', 'xtkc705-rt-rom', 'xtav60-rt',
                            'xtav60-rt-rom', 'xtav110-rt', 'xtav110-rt-rom', 'xtav200-rt', 'xtav200-rt-rom']
        result = line.match(pattern)
        if result
          custom = standard_support.include?(result[2]) ? false : true
          @file.linkerTab.supportPackage(result[1], result[2], custom)
          line.sub!(result[0], '')
        else
          @logger.debug('no support package set!')
        end
        return line
      end

      def linker_embed_map_info(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(--xt-map)\s/
        result = line.match(pattern)
        if result
          @file.linkerTab.embedMapInfo(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no embed map info set!')
        end
        return line
      end

      def linker_generator_map_file(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-Wl,-Map)\s/
        result = line.match(pattern)
        if result
          @file.linkerTab.generatorMapFile(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no generator map file set!')
        end
        return line
      end

      def linker_omit_debugger_symbol(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(--strip-debug)\s/
        result = line.match(pattern)
        if result
          @file.linkerTab.omitDebuggerSymbol(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no omit debugger symbol set!')
        end
        return line
      end

      def linker_omit_all_symbol(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(--strip-all)\s/
        result = line.match(pattern)
        if result
          @file.linkerTab.omitAllSymbol(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no omit all symbol set!')
        end
        return line
      end

      def linker_enable_interprocedural_analysis(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-ipa)\s/
        result = line.match(pattern)
        if result
          @file.linkerTab.enableInterproceduralAnalysis(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no enable interprocedural analysis set!')
        end
        return line
      end

      def linker_control_linker_order(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-Wl,--sections-placement=)\s/
        result = line.match(pattern)
        if result
          @file.linkerTab.controlLinkerOrder(result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no control linker order set!')
        end
        return line
      end

      def linker_hardware_profile(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-hwpg)=?(\S+)?\s/
        result = line.match(pattern)
        if result
          @file.linkerTab.hardware_profile(result[1], result[2])
          line.sub!(result[0], '')
        else
          @logger.debug('no control linker order set!')
        end
        return line
      end

      def linker_iss_memory_debugger(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-Wl,-u\s-Wl,malloc)(\s-lferret)?\s/
        result = line.match(pattern)
        if result
          @file.memoryTab.debugMalloc(result[1]) if result[1]
          @file.memoryTab.ferret(result[2]) if result[2]
          line.sub!(result[0], '')
        else
          @logger.debug('no control linker order set!')
        end
        return line
      end

      def linker_inlude_libxmp(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-lxmp|-lxmp-debug)\s/
        result = line.match(pattern)
        if result
          @file.memoryTab.includeLibxmp(result[1]) if result[1]
          line.sub!(result[0], '')
        else
          @logger.debug('no include libxmp set!')
        end
        return line
      end

      def linker_lib_search_path(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-L)\"(\S+)\"\s/
        result = line.match(pattern)
        while result
          @file.librariesTab.libSearchPath(result[1], result[2])
          line.sub!(result[0], '')
          result = line.match(pattern)
        end
        return line
      end

      def linker_libraries(line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s(-l)(\S+)\s/
        result = line.match(pattern)
        while result
          @file.librariesTab.libraries(result[1], result[2])
          line.sub!(result[0], '')
          result = line.match(pattern)
        end
        return line
      end

      def linker_addl_linker(line)
        Core.assert(line.is_a?(String), 'not a string')
        line.strip.split(' ').each do |flag|
          @file.addlLinkerTab.additionalOptions("#{flag}\r\n") unless flag.strip.empty?
        end
        return line
      end

      def compiler_cc_options_for_linker(line)
        Core.assert(line.is_a?(String), 'not a string')
        @file.addlLinkerTab.compilerOptionsForLinker(line.strip.split(' ').join("\r\n")) unless line.strip.empty?
        return line
      end
    end
  end
end
