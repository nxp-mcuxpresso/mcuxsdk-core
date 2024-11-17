# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/iar/files/_ewp_file'

module Iar
  module Common
    # Wrapper of application .ewp file. Provide tabs:
    # * generalTab
    # * compilerTab
    # * assemblerTab
    # * buildActionTab
    # * linkerTab
    class EwpFile < Internal::Iar::EwpFile
      attr_reader :generalTab
      attr_reader :compilerTab
      attr_reader :assemblerTab
      attr_reader :buildactionTab

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
        # create shared "operations" instance
        @operations = DocumentOperations.new(@xml, logger: @logger)
        @assemblerTab = AssemblerTab.new(@operations)
        @buildactionTab = BuildActionTab.new(@operations)
      end

      def save(*args, **kargs)
        super
      end

      def add_source(*args, **kargs)
        super
      end

      def clear_sources!(*args, **kargs)
        super
      end

      def get_target_name(*args, **kwargs)
        super
      end

      def set_target_name(*args, **kwargs)
        super
      end

      def targets(*args, **kargs)
        super
      end

      def clear_unused_targets!(*args, **kargs)
        super
      end

      def exclude_building(*args, **kargs)
        super
      end

      def add_rte_globals(*args)
        super
      end

      def add_rte_component(*args)
        super
      end

      # Provide tabs:
      # * targetTab
      # * outputTab
      class GeneralTab < GeneralTab
        attr_reader :targetTab
        attr_reader :outputTab
        attr_reader :misraC2004Tab

        def initialize(operations)
          super(operations)
          @targetTab = TargetTab.new(@operations)
          @outputTab = OutputTab.new(@operations)
          @misraC2004Tab = MisraC2004Tab.new(@operations)
        end

        class TargetTab < TargetTab
          def fpu(*args, **kargs)
            super
          end

          def core(*args, **kargs)
            super
          end

          def endian(*args, **kargs)
            super
          end

          def device(*args, **kargs)
            super
          end

          def trustZone(*args, **kargs)
            super
          end

          def secure(*args, **kargs)
            super
          end

          def dspExtension(*args, **kargs)
            super
          end

          def use_core_variant(*args, **kargs)
            super
          end
        end

        class OutputTab < OutputTab
          def output_type(*args, **kargs)
            super
          end

          def output_dir(*args, **kargs)
            super
          end

          def object_files_dir(*args, **kargs)
            super
          end

          def list_files_dir(*args, **kargs)
            super
          end
        end

        class LibraryConfigurationTab < LibraryConfigurationTab
          def library_configuration_file(*args, **kargs)
            super
          end
        end

        class MisraC2004Tab < MisraC2004Tab
          def enable_misra(*args, **kargs)
            super
          end

          def misra_version(*args, **kargs)
            super
          end
        end
      end

      # Provide tabs:
      # * language1Tab
      # * language2Tab
      # * codeTab
      # * optimizationTab
      # * outputTab
      # * preprocessorTab
      # * diagnosticTab
      class CompilerTab < CompilerTab
        attr_reader :language1Tab
        attr_reader :language2Tab
        attr_reader :codeTab
        attr_reader :outputTab
        attr_reader :diagnosticTab
        attr_reader :ExtraOptionTab

        def initialize(operations)
          super(operations)
          @language1Tab = Language1Tab.new(@operations)
          @language2Tab = Language2Tab.new(@operations)
          @codeTab = CodeTab.new(@operations)
          @outputTab = OutputTab.new(@operations)
          @diagnosticTab = DiagnosticTab.new(@operations)
          @ExtraOptionTab = ExtraOptionTab.new(@operations)
        end

        class Language1Tab < Language1Tab
          def language(*args, **kargs)
            super
          end

          def c_dialect(*args, **kargs)
            super
          end

          def cpp_inline_semantic(*args, **kargs)
            super
          end

          def allow_vla(*args, **kargs)
            super
          end

          def require_prototypes(*args, **kargs)
            super
          end

          def comformance(*args, **kargs)
            super
          end

          def cpp_dialect(*args, **kargs)
            super
          end

          def cpp_with_exceptions(*args, **kargs)
            super
          end

          def cpp_with_rtti(*args, **kargs)
            super
          end

          def destroy_static_objects(*args, **kargs)
            super
          end
        end

        class Language2Tab < Language2Tab
          def plain_char(*args, **kargs)
            super
          end

          def float_semantic(*args, **kargs)
            super
          end

          def mutlibyte(*args, **kargs)
            super
          end
        end

        class CodeTab < CodeTab
          def interwork_code(*args, **kargs)
            super
          end

          def processor_mode(*args, **kargs)
            super
          end
        end

        class OptimizationTab < OptimizationTab
          def level(*args, **kargs)
            super
          end

          def strategy(*args, **kargs)
            super
          end

          def high_strategy(*args, **kargs)
            super
          end

          def enable_no_size_constraints(*args, **kargs)
            super
          end

          def enable_subexp_elimination(*args, **kargs)
            super
          end

          def enable_loop_unrolling(*args, **kargs)
            super
          end

          def enable_func_inlining(*args, **kargs)
            super
          end

          def enable_code_motion(*args, **kargs)
            super
          end

          def enable_alias_analysis(*args, **kargs)
            super
          end

          def enable_static_clustering(*args, **kargs)
            super
          end

          def enable_instruction_scheduling(*args, **kargs)
            super
          end

          def enable_vectorization(*args, **kargs)
            super
          end

          def enable_nosize_constraints(*args, **kargs)
            super
          end
        end

        class OutputTab < OutputTab
          def debug_info(*args, **kargs)
            super
          end

          def codesection_name(*args, **kargs)
            super
          end
        end

        class PreprocessorTab < PreprocessorTab
          def add_include(*args, **kargs)
            super
          end

          def clear_include!(*args, **kargs)
            super
          end

          def add_define(*args, **kargs)
            super
          end

          def clear_defines!(*args, **kargs)
            super
          end

          def ignore_standard_include(*args, **kargs)
            super
          end

          def add_pre_include(*args, **kargs)
            super
          end
        end

        class DiagnosticTab < DiagnosticTab
          def add_suppress(*args, **kargs)
            super
          end

          def set_suppress(*args, **kargs)
            super
          end

          def treat_warnings_as_errors(*args, **kargs)
            super
          end
        end

        class ExtraOptionTab < ExtraOptionTab
          def use_commandline(*args, **kargs)
            super
          end

          # Set suppression code on source level
          def use_commandline_for_src(*args, **kargs)
            super
          end
        end
      end

      # Provide tabs:
      # * languageTab
      # * outputTab
      # * preprocessorTab
      # * diagnosticTab
      class AssemblerTab < AssemblerTab
        attr_reader :languageTab
        attr_reader :outputTab
        attr_reader :preprocessorTab
        attr_reader :diagnosticTab
        attr_reader :extraOptionTab

        def initialize(operations)
          super(operations)
          @languageTab = LanguageTab.new(@operations)
          @outputTab = OutputTab.new(@operations)
          @preprocessorTab = PreprocessorTab.new(@operations)
          @diagnosticTab = DiagnosticTab.new(@operations)
          @extraOptionTab = ExtraOptionTab.new(@operations)
        end

        class LanguageTab < LanguageTab
          def allow_case_sensitivity(*args, **kargs)
            super
          end

          def enable_multibyte(*args, **kargs)
            super
          end

          def macro_quote_character(*args, **kargs)
            super
          end

          def allow_alternative_names(*args, **kargs)
            super
          end
        end

        class OutputTab < OutputTab
          def debug_info(*args, **kargs)
            super
          end
        end

        class PreprocessorTab < PreprocessorTab
          def add_include(*args, **kargs)
            super
          end

          def clear_include!(*args, **kargs)
            super
          end

          def ignore_standard_include(*args, **kargs)
            super
          end

          def add_define(*args, **kargs)
            super
          end

          def clear_defines!(*args, **kargs)
            super
          end
        end

        class DiagnosticTab < DiagnosticTab
          def enable_warnings(*args, **kargs)
            super
          end
        end

        class ExtraOptionTab < ExtraOptionTab
          def use_commandline(*args, **kargs)
            super
          end
        end
      end

      # Provide tabs:
      # * configurationTab
      class BuildActionTab < BuildActionTab
        attr_reader :configurationTab

        def initialize(operations)
          super(operations)
          @configurationTab = ConfigurationTab.new(@operations)
        end

        class ConfigurationTab < ConfigurationTab
          def prebuild_command(*args, **kargs)
            super
          end

          def postbuild_command(*args, **kargs)
            super
          end
        end
      end
    end
  end
end
