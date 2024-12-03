# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../common/files/ewp_file'

module Iar
  module Lib
    # Wrapper of library .ewp file. Provide tabs:
    # * generalTab
    # * compilerTab
    # * assemblerTab
    # * buildActionTab
    # * libraryBuilderTab
    class EwpFile < Iar::Common::EwpFile
      attr_reader :libraryBuilderTab

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
        # create tab instances
        @generalTab = GeneralTab.new(@operations)
        @compilerTab = CompilerTab.new(@operations)
        @libraryBuilderTab = LibraryBuilderTab.new(@operations)
        # force "library" switch
        targets.each do |target|
          @generalTab.outputTab.output_type(target, 'library', used: false)
        end
      end

      class GeneralTab < GeneralTab
        attr_reader :libraryConfigurationTab
        def initialize(operations)
          super(operations)
          @libraryConfigurationTab = LibraryConfigurationTab.new(@operations)
        end

        class LibraryConfigurationTab < LibraryConfigurationTab
        end
      end

      class CompilerTab < CompilerTab
        attr_reader :optimizationTab
        attr_reader :preprocessorTab

        def initialize(operations)
          super(operations)
          @optimizationTab = OptimizationTab.new(@operations)
          @preprocessorTab = PreprocessorTab.new(@operations)
        end

        class OptimizationTab < OptimizationTab
        end

        class PreprocessorTab < PreprocessorTab
        end
      end
      # Provide tabs:
      # * outputTab
      class LibraryBuilderTab < LibraryBuilderTab
        attr_reader :outputTab

        def initialize(operations)
          super(operations)
          @outputTab = OutputTab.new(@operations)
        end

        class OutputTab < OutputTab
          def override_default(*args, **kargs)
            super
          end

          def output_file(*args, **kargs)
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
