# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../common/files/ewp_file'

module Iar
  module App
    # Wrapper of application .ewp file. Provide tabs:
    # * generalTab
    # * compilerTab
    # * assemblerTab
    # * buildActionTab
    # * linkerTab
    class EwpFile < Iar::Common::EwpFile
      attr_reader :outputConverterTab
      attr_reader :linkerTab

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
        @generalTab = GeneralTab.new(@operations)
        @compilerTab = CompilerTab.new(@operations)
        @outputConverterTab = OutputConverterTab.new(@operations)
        @linkerTab = LinkerTab.new(@operations)
        # force "executable" switch
        targets.each do |target|
          @generalTab.outputTab.output_type(target, 'executable', used: false)
        end
      end

      def add_comfiguration(*args, **kargs)
        super
      end

      def add_specific_ccinclude(*args, **kargs)
        super
      end

      def add_rte_package_and_component(*args)
        super
      end

      def create_rte_component
        super
      end

      def add_cmsis_pack_component(*args)
        super
      end

      def add_project_template_component(*args)
        super
      end

      def files_to_remove
        super
      end
      # Provide tabs:
      # * targetTab
      # * outputTab
      class GeneralTab < GeneralTab
        attr_reader :libraryOptionsTab
        attr_reader :libraryConfigurationTab
        def initialize(operations)
          super(operations)
          @libraryOptionsTab = LibraryOptionsTab.new(@operations)
          @libraryConfigurationTab = LibraryConfigurationTab.new(@operations)
        end

        class LibraryConfigurationTab < LibraryConfigurationTab
          def library(*args, **kargs)
            super
          end

          def use_cmsis(*args, **kargs)
            super
          end

          def use_cmsis_dsp(*args, **kargs)
            super
          end
        end

        class LibraryOptionsTab < LibraryOptionsTab
          def printf_formatter(*args, **kargs)
            super
          end

          def scanf_formatter(*args, **kargs)
            super
          end

          def buffered_terminal_output(*args, **kargs)
            super
          end

          def enable_semihosted(*args, **kargs)
            super
          end

          def redirect_swo(*args, **kargs)
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
        attr_reader :optimizationTab
        attr_reader :preprocessorTab

        def initialize(operations)
          super(operations)
          @optimizationTab = OptimizationTab.new(@operations)
          @preprocessorTab = PreprocessorTab.new(@operations)
        end

        class OptimizationTab < OptimizationTab
          def level_for_src(*args, **kargs)
            super
          end

          def strategy_for_src(*args, **kargs)
            super
          end

          def high_strategy_for_src(*args, **kargs)
            super
          end

          def enable_nosize_constraints_for_src(*args, **kargs)
            super
          end
        end

        class PreprocessorTab < PreprocessorTab
        end
      end

      # Provide tabs:
      # * outputTab
      class OutputConverterTab < OutputConverterTab
        attr_reader :outputTab

        def initialize(operations)
          super(operations)
          @outputTab = OutputTab.new(@operations)
        end

        class OutputTab < OutputTab
          def enable_additional_output(*args, **kargs)
            super
          end

          def set_output_format(*args, **kargs)
            super
          end

          def enable_override_default_output(*args, **kargs)
            super
          end

          def set_override_output_file(*args, **kargs)
            super
          end
        end
      end

      # Provide tabs:
      # * configTab
      # * libraryTab
      # * outputTab
      class LinkerTab < LinkerTab
        attr_reader :configTab
        attr_reader :libraryTab
        attr_reader :inputTab
        attr_reader :outputTab
        attr_reader :checksumTab
        attr_reader :extraOptionTab
        attr_reader :diagnosticTab

        def initialize(operations)
          super(operations)
          @configTab = ConfigTab.new(@operations)
          @libraryTab = LibraryTab.new(@operations)
          @inputTab = InputTab.new(@operations)
          @outputTab = OutputTab.new(@operations)
          @checksumTab = ChecksumTab.new(@operations)
          @extraOptionTab = ExtraOptionTab.new(@operations)
          @diagnosticTab = DiagnosticTab.new(@operations)
        end

        class ConfigTab < ConfigTab
          def override_default(*args, **kargs)
            super
          end

          def configuration_file(*args, **kargs)
            super
          end

          def configuration_file_defines(*args, **kargs)
            super
          end

          def clear_configuration_file_defines!(*args, **kargs)
            super
          end
        end

        class LibraryTab < LibraryTab
          def add_library(*args, **kargs)
            super
          end

          def clear_libraries!(*args, **kargs)
            super
          end

          def override_default_program_entry(*args, **kargs)
            super
          end

          def entry_symbol(*args, **kargs)
            super
          end

          def defined_by_application(*args, **kargs)
            super
          end
        end

        class InputTab < InputTab
          def add_keep_symbol(*args, **kargs)
            super
          end

          def clear_keep_symbols!(*args, **kargs)
            super
          end

          def set_raw_binary_image_file(*args, **kargs)
            super
          end

          def set_raw_binary_image_symbol(*args, **kargs)
            super
          end

          def set_raw_binary_image_section(*args, **kargs)
            super
          end

          def set_raw_binary_image_align(*args, **kargs)
            super
          end

          def set_raw_binary_image(*args, **kargs)
            super
          end
        end

        class OutputTab < OutputTab
          def output_filename(*args, **kargs)
            super
          end

          def debug_info(*args, **kargs)
            super
          end

          def set_tz_import_lib(*args, **kargs)
            super
          end
        end

        class ChecksumTab < ChecksumTab
          def enable_checksum(*args, **kargs)
            super
          end

          def fillerbyte(*args, **kargs)
            super
          end

          def fillerstart(*args, **kargs)
            super
          end

          def fillerend(*args, **kargs)
            super
          end
        end

        class ExtraOptionTab < ExtraOptionTab
          def add_command_option(*args, **kargs)
            super
          end

          def clear_command_options!(*args, **kargs)
            super
          end

          def clear_empty_command_options!(*args, **kargs)
            super
          end
        end

        class DiagnosticTab < DiagnosticTab
          def set_suppress(*args, **kargs)
            super
          end
        end
      end
    end

    class EwpFile_9_32_1 < EwpFile
      def set_project_version(*args, **kargs)
        super
      end
    end

    class EwpFile_9_32_2 < EwpFile_9_32_1
    end

    class EwpFile_9_40_1 < EwpFile_9_32_2
      def initialize(*args, **kwargs)
        super
        @version_map.each {|k,v| @version_map[k] = v+1}
      end
    end
  end
end
