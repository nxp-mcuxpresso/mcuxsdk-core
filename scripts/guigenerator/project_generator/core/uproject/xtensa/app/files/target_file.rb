# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/xtensa/files/_targetproject_file'

module Xtensa
  module App
    class TargetFile < Internal::Xtensa::TargetFile
      attr_reader :includesTab
      attr_reader :symbolsTab
      attr_reader :optimizationTab
      attr_reader :advancedOptimizationTab
      attr_reader :warningsTab
      attr_reader :languageTab
      attr_reader :addlCompilerTab
      attr_reader :assemblerTab
      attr_reader :addlAssemblerTab
      attr_reader :compilerOptionsForAssemblerTab
      attr_reader :linkerTab
      attr_reader :memoryTab
      attr_reader :librariesTab
      attr_reader :addlLinkerTab

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
        @operations = DocumentOperations.new(@xml, 'exe', logger: @logger)
        @includesTab = IncludesTab.new(@operations)
        @symbolsTab = SymbolsTab.new(@operations)
        @optimizationTab = OptimizationTab.new(@operations)
        @advancedOptimizationTab = AdvancedOptimizationTab.new(@operations)
        @warningsTab = WarningsTab.new(@operations)
        @languageTab = LanguageTab.new(@operations)
        @addlCompilerTab = AddlCompilerTab.new(@operations)
        @assemblerTab = AssemblerTab.new(@operations)
        @addlAssemblerTab = AddlAssemblerTab.new(@operations)
        @compilerOptionsForAssemblerTab = CompilerOptionsForAssemblerTab.new(@operations)
        @linkerTab = LinkerTab.new(@operations)
        @memoryTab = MemoryTab.new(@operations)
        @librariesTab = LibrariesTab.new(@operations)
        @addlLinkerTab = AddlLinkerTab.new(@operations)
      end

      def add_source(path, vdirexpr)
        super
      end

      def save(*args, **kargs)
        @addlLinkerTab.save_library
        super
      end

      class IncludesTab < IncludesTab
        def initialize(operations)
          super(operations)
        end

        def clear_include!(*args, **kargs)
          super
        end

        def add_include(*args, **kargs)
          super
        end

        def add_includefile(*args, **kargs)
          super
        end

        def clear_includefiles!(*args, **kargs)
          super
        end
      end

      class SymbolsTab < SymbolsTab
        def initialize(operations)
          super(operations)
        end

        def clear_macros!(*args, **kargs)
          super
        end

        def add_macros(*args, **kargs)
          super
        end
      end

      class OptimizationTab < OptimizationTab
        def initialize(operations)
          super(operations)
        end

        def clear_optimizations!(*args, **kargs)
          super
        end

        def optimization(*args, **kargs)
          super
        end

        def debug(*args, **kargs)
          super
        end

        def keepIntermediateFiles(*args, **kargs)
          super
        end

        def enableInterproceduralOptimization(*args, **kargs)
          super
        end

        def useDspCoprocessor(*args, **kargs)
          super
        end

        def notSerializeVolatile(*args, **kargs)
          super
        end

        def literals(*args, **kargs)
          super
        end

        def useFeedback(*args, **kargs)
          super
        end

        def optomizationForSize(*args, **kargs)
          super
        end

        def optomizationAlias(*args, **kargs)
          super
        end

        def autoVectorization(*args, **kargs)
          super
        end

        def vectorizeWithIfs(*args, **kargs)
          super
        end

        def paramsAligned(*args, **kargs)
          super
        end

        def connectionBoxOptimization(*args, **kargs)
          super
        end

        def produceW2cFile(*args, **kargs)
          super
        end

        def enableLongCalls(*args, **kargs)
          super
        end

        def createSeparateFunc(*args, **kargs)
          super
        end

        def createOptimizationFile(*args, **kargs)
          super
        end
      end

      class AdvancedOptimizationTab < AdvancedOptimizationTab
        def initialize(operations)
          super(operations)
        end

        def generateOptimizationFile(*args, **kargs)
          super
        end

        def useOptimizationFile(*args, **kargs)
          super
        end
      end

      class WarningsTab < WarningsTab
        def initialize(operations)
          super(operations)
        end

        def warningSettings(*args, **kargs)
          super
        end

        def warningAsErrors(*args, **kargs)
          super
        end
      end

      class LanguageTab < LanguageTab
        def initialize(operations)
          super(operations)
        end

        def disableGnuExtension(*args, **kargs)
          super
        end

        def signedCharDefault(*args, **kargs)
          super
        end

        def enableStrictAnsiWarning(*args, **kargs)
          super
        end

        def supportCppException(*args, **kargs)
          super
        end

        def languageDialect(*args, **kargs)
          super
        end

        def languageDialectCpp(*args, **kargs)
          super
        end

        def standardCppLibrary(*args, **kargs)
          super
        end
      end

      class AddlCompilerTab < AddlCompilerTab
        def initialize(operations)
          super(operations)
        end

        def additionalOptions(*args, **kargs)
          super
        end
      end

      class AssemblerTab < AssemblerTab
        def initialize(operations)
          super(operations)
        end

        def clear_assembler_flags!(*args, **kargs)
          super
        end

        def includeDebugInfo(*args, **kargs)
          super
        end

        def supressWarnings(*args, **kargs)
          super
        end

        def enableLongCalls(*args, **kargs)
          super
        end

        def placeLiteralsInText(*args, **kargs)
          super
        end
        end

      class AddlAssemblerTab < AddlAssemblerTab
        def initialize(operations)
          super(operations)
        end

        def additionalOptions(*args, **kargs)
          super
        end
      end

      class CompilerOptionsForAssemblerTab < CompilerOptionsForAssemblerTab
        def initialize(operations)
          super(operations)
        end

        def compilerOptions(*args, **kargs)
          super
        end
      end

      class LinkerTab < LinkerTab
        def initialize(operations)
          super(operations)
        end

        def clear_linker_flags!(*args, **kargs)
          super
        end

        def supportPackage(*args, **kargs)
          super
        end

        def createMinsize(*args, **kargs)
          super
        end

        def embedMapInfo(*args, **kargs)
          super
        end

        def generatorMapFile(*args, **kargs)
          super
        end

        def omitDebuggerSymbol(*args, **kargs)
          super
        end

        def omitAllSymbol(*args, **kargs)
          super
        end

        def enableInterproceduralAnalysis(*args, **kargs)
          super
        end

        def controlLinkerOrder(*args, **kargs)
          super
        end

        def hardware_profile(*args, **kargs)
          super
        end
      end

      class MemoryTab < MemoryTab
        def initialize(operations)
          super(operations)
        end

        def debugMalloc(*args, **kargs)
          super
        end

        def ferret(*args, **kargs)
          super
        end

        def includeLibxmp(*args, **kargs)
          super
        end

        def enableSharedMalloc(*args, **kargs)
          super
        end
      end

      class LibrariesTab < LibrariesTab
        def initialize(operations)
          super(operations)
        end

        def libSearchPath(*args, **kargs)
          super
        end

        def libraries(*args, **kargs)
          super
        end
      end

      class AddlLinkerTab < AddlLinkerTab
        def initialize(operations)
          super(operations)
        end

        def additionalOptions(*args, **kargs)
          super
        end

        def add_library(*args, **kargs)
          super
        end

        def compilerOptionsForLinker(*args, **kargs)
          super
        end
      end
    end
  end
end
