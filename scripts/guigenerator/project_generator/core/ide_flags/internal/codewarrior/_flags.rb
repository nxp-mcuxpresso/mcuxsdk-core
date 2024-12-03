# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/_flags'

module Internal
  module CodeWarrior
    class Flags < Internal::Flags
      private

      #  compile compiler flags
      def compiler_optimization(target, line)
        Core.assert(line.is_a?(String), 'not a string')
        #-opt level=4
        pattern = /\s-opt\slevel=(1|2|3|4)\s/
        result  = line.match(pattern)
        if result
          flag = result[1]
          @file.dscCompilerTab.optimizationTab.optimization_level(target, flag)
          line.sub!(result[0], '')
        else
          @logger.debug('no optimization set!')
        end
        return line
      end

      def compiler_program_mem_model(target, line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-(sprog|hprog)\s/
        result  = line.match(pattern)
        if result
          if result[1] == "sprog"
            @file.dscCompilerTab.processorTab.small_program_model(target, true)
            @file.dscCompilerTab.processorTab.large_program_model(target, false)
            @file.dscCompilerTab.processorTab.huge_program_model(target, false)
          else
            @file.dscCompilerTab.processorTab.small_program_model(target, false)
            @file.dscCompilerTab.processorTab.large_program_model(target, false)
            @file.dscCompilerTab.processorTab.huge_program_model(target, true)
          end
          line.sub!(result[0], '')
        else
          @file.dscCompilerTab.processorTab.small_program_model(target, false)
          @file.dscCompilerTab.processorTab.large_program_model(target, true)
          @file.dscCompilerTab.processorTab.huge_program_model(target, false)
        end
        return line
      end

      def compiler_data_mem_model(target, line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-ldata\s/
        result = line.match(pattern)
        if result
          @file.dscCompilerTab.processorTab.large_data_mem_model(target, true)
          line.sub!(result[0], '')
        else
          @file.dscCompilerTab.processorTab.large_data_mem_model(target, false)
        end
        return line
      end

      def compiler_pad_pipeline(target,line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-nopadpipe\s/
        result = line.match(pattern)
        if result
          @file.dscCompilerTab.processorTab.set_pad_pipeline(target, false)
          line.sub!(result[0], '')
        else
          @file.dscCompilerTab.processorTab.set_pad_pipeline(target, true)
        end
        return line
      end

      def compiler_globals_live(target,line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-globalsInLowerMemory\s/
        result = line.match(pattern)
        if result
          @file.dscCompilerTab.processorTab.set_globals_live(target, true)
          line.sub!(result[0], '')
        else
          @file.dscCompilerTab.processorTab.set_globals_live(target, false)
        end
        return line
      end

      def compiler_hawk_elf(target,line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-v4\s/
        result = line.match(pattern)
        if result
          @file.dscCompilerTab.processorTab.set_hawk_elf(target, true)
          line.sub!(result[0], '')
        else
          @file.dscCompilerTab.processorTab.set_hawk_elf(target, false)
        end
        return line
      end

      def compiler_language_c99(target,line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-lang c99\s/
        result = line.match(pattern)
        if result
          @file.dscCompilerTab.languageTab.set_language_c99(target, true)
          line.sub!(result[0], '')
        else
          @file.dscCompilerTab.languageTab.set_language_c99(target, false)
        end
        return line
      end

      def compiler_addl_compiler(target, line)
        Core.assert(line.is_a?(String), 'not a string')
        @file.dscCompilerTab.languageTab.add_other_flags(target, line.strip) unless line.strip.empty?
        return line
      end

      def assembler_data_memory_model(target,line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-data\s(\d+)\s/
        result = line.match(pattern)
        if result
          @file.dscAssemblerTab.generalTab.set_data_mem_model(target, result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no data model set!')
        end
        return line
      end

      def assembler_program_memory_model(target,line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-prog\s(\d+)\s/
        result = line.match(pattern)
        if result
          @file.dscAssemblerTab.generalTab.set_program_mem_model(target, result[1])
          line.sub!(result[0], '')
        else
          @logger.debug('no data model set!')
        end
        return line
      end

      def assembler_pad_pipeline(target,line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-nodebug_workaround\s/
        result = line.match(pattern)
        if result
          @file.dscAssemblerTab.generalTab.set_pad_pipeline(target, false)
          line.sub!(result[0], '')
        else
          @file.dscAssemblerTab.generalTab.set_pad_pipeline(target, true)
        end
        return line
      end

      def assembler_hawk_elf(target,line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-v4\s/
        result = line.match(pattern)
        if result
          @file.dscAssemblerTab.generalTab.set_hawk_elf(target, true)
          line.sub!(result[0], '')
        else
          @file.dscAssemblerTab.generalTab.set_hawk_elf(target, false )
        end
        return line
      end

      def assembler_addl_assembler(target,line)
        Core.assert(line.is_a?(String), 'not a string')
        @file.dscAssemblerTab.generalTab.add_other_flags(target, line.strip) unless line.strip.empty?
        return line
      end

      def linker_large_data_mem_model(target, line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-ldata\s/
        result = line.match(pattern)
        if result
          @file.dscLinkerTab.generalTab.large_data_mem_model(target, true)
          line.sub!(result[0], '')
        else
          @file.dscLinkerTab.generalTab.large_data_mem_model(target, false)
        end
        return line
      end

      def linker_hawk_elf(target,line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /\s-v4\s/
        result = line.match(pattern)
        if result
          @file.dscLinkerTab.generalTab.set_hawk_elf(target, true)
          line.sub!(result[0], '')
        else
          @file.dscLinkerTab.generalTab.set_hawk_elf(target, false)
        end
        return line
      end

      def linker_addl_lib(target, line)
        Core.assert(line.is_a?(String), 'not a string')
        pattern = /-l(\S+)/
        result = line.match(pattern)
        while result
          lib = result[1].gsub!("\\\"", "")
          if lib.match(/^\$\{\S+\}\S+/)
            lib = '"' + lib + '"'
          end
          @file.dscLinkerTab.inputTab.add_addl_lib(target, lib)
          line.sub!(result[0], '')
          result = line.match(pattern)
        end
        return line
      end

      def linker_addl_linker(target, line)
        Core.assert(line.is_a?(String), 'not a string')
        @file.dscLinkerTab.generalTab.add_other_flags(target, line.strip) unless line.strip.empty?
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
