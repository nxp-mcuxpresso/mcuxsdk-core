# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/codewarrior/files/_cproject_file'

module CodeWarrior
  module Common
    class CprojectFile < Internal::CodeWarrior::CprojectFile
      attr_reader :dscCompilerTab
      attr_reader :dscAssemblerTab
      attr_reader :dscLinkerTab

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
        @operations = DocumentOperations.new(@xml, 'exe', logger: @logger)
        @dscCompilerTab = DSCCompilerTab.new(@operations)
        @dscAssemblerTab = DSCAssemblerTab.new(@operations)
        @dscLinkerTab = DSCLinkerTab.new(@operations)
      end

      def save(*args, **kargs) super end
      def get_target_name(*args, **kwargs) super end
      def set_target_name(*args, **kwargs) super end
      def targets(*args, **kargs) super end
      def clear_unused_targets!(*args, **kargs) super end
      def update_cdt_build_system(*args, **kargs) super end
      def artifact_name(*args, **kargs) super end
      def artifact_extension(*args, **kargs) super end

      class DSCCompilerTab < DSCCompilerTab

        attr_reader :inputTab
        attr_reader :accessPathsTab
        attr_reader :warningsTab
        attr_reader :optimizationTab
        attr_reader :processorTab
        attr_reader :languageTab

        def initialize(operations)
          super(operations)
          @inputTab = InputTab.new(@operations)
          @accessPathsTab = AccessPathsTab.new(@operations)
          @warningsTab = WarningsTab.new(@operations)
          @optimizationTab = OptimizationTab.new(@operations)
          @processorTab = ProcessorTab.new(@operations)
          @languageTab = LanguageTab.new(@operations)
        end

        class InputTab < InputTab
          def clear_macros!(*args, **kargs) super end
          def add_macros(*args, **kargs) super end
        end

        class AccessPathsTab < AccessPathsTab
          def clear_include!(*args, **kargs) super end
          def clear_sys_search_path!(*args, **kargs) super end
          def clear_sys_path_recursively!(*args, **kargs) super end
          def add_user_paths(*args, **kargs) super end
          def add_sys_search_path(*args, **kargs) super end
          def add_sys_path_recursively(*args, **kargs) super end
        end

        class WarningsTab < WarningsTab
          def set_warn_illpragmas(*args, **kargs) super end
          def set_warn_possible(*args, **kargs) super end
          def set_warn_extended(*args, **kargs) super end
          def set_warn_extracomma(*args, **kargs) super end
          def set_warn_emptydecl(*args, **kargs) super end
          def set_warn_structclass(*args, **kargs) super end
          def set_warn_notinlined(*args, **kargs) super end
        end

        class OptimizationTab < OptimizationTab
          def optimization_level(*args, **kargs) super end
          def optimization_mode(*args, **kargs) super end
        end


        class ProcessorTab < ProcessorTab
          def small_program_model(*args, **kargs) super end
          def large_program_model(*args, **kargs) super end
          def huge_program_model(*args, **kargs) super end
          def large_data_mem_model(*args, **kargs) super end
          def set_pad_pipeline(*args, **kargs) super end
          def set_globals_live(*args, **kargs) super end
          def set_hawk_elf(*args, **kargs) super end
        end

        class LanguageTab < LanguageTab
          def add_other_flags(*args, **kargs) super end
          def set_language_c99(*args, **kargs) super end
          def set_require_protos(*args, **kargs) super end
        end
      end

      class DSCAssemblerTab < DSCAssemblerTab
        attr_reader :inputTab
        attr_reader :generalTab
        attr_reader :outputTab

        def initialize(operations)
          super(operations)
          @inputTab = InputTab.new(@operations)
          @generalTab = GeneralTab.new(@operations)
          @outputTab = OutputTab.new(@operations)
        end

        class InputTab < InputTab
          def clear_include!(*args, **kargs) super end
          def add_user_include(*args, **kargs) super end
          def set_no_syspath(*args, **kargs) super end
        end

        class GeneralTab < GeneralTab
          def set_data_mem_model(*args, **kargs) super end
          def set_program_mem_model(*args, **kargs) super end
          def set_pad_pipeline(*args, **kargs) super end
          def set_hawk_elf(*args, **kargs) super end
          def add_other_flags(*args, **kargs) super end
        end

        class OutputTab < OutputTab

        end
      end

      class DSCLinkerTab < DSCLinkerTab
        attr_reader :inputTab
        attr_reader :linkorderTab
        attr_reader :generalTab
        attr_reader :outputTab

        def initialize(operations)
          super(operations)
          @inputTab = InputTab.new(@operations)
          @linkorderTab = LinkorderTab.new(@operations)
          @generalTab = GeneralTab.new(@operations)
          @outputTab = OutputTab.new(@operations)
        end

        class InputTab < InputTab
          def clear_linker_file!(*args, **kargs) super end
          def clear_lib_path!(*args, **kargs) super end
          def clear_addl_lib!(*args, **kargs) super end
          def linker_cmd_file(*args, **kargs) super end
          def lib_search_path(*args, **kargs) super end
          def add_addl_lib(*args, **kargs) super end
          def set_no_stdlib(*args, **kargs) super end
          def set_entry_point(*args, **kargs) super end
        end

        class LinkorderTab < LinkorderTab

        end

        class GeneralTab < GeneralTab
          def large_data_mem_model(*args, **kargs) super end
          def set_hawk_elf(*args, **kargs) super end
          def add_other_flags(*args, **kargs) super end
        end

        class OutputTab < OutputTab
          def set_generate_map(*args, **kargs) super end
        end
      end
  end
  end
end
