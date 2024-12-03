# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../common/files/uvprojx_file'


module Mdk
  module App

    class UvprojxFile < Mdk::Common::UvprojxFile

      attr_reader :utilitiesTab

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
        # create shared "operations" instance
        @operations = DocumentOperations.new(@xml, logger: @logger)
        # create tab instances
        @compilerTab = CompilerTab.new(@operations)
        @assemblerTab = AssemblerTab.new(@operations)
        @linkerTab = LinkerTab.new(@operations)
        @utilitiesTab = UtilitiesTab.new(@operations)
        # force "executable" switch
        targets.each do |target|
          @outputTab.create_executable(target, true, used: false)
        end
      end

      def add_comfiguration(*args, **kargs)
        super
      end

      def create_rte_component()
        super
      end

      def add_project_template_files(*args)
        super
      end

      def add_project_template_component(*args)
        super
      end

      def update_include_paths
        super
      end

      def files_to_remove()
        super
      end

      class CompilerTab < CompilerTab
        def add_misc_flag_for_src(*args, **kargs)
          super
        end

        def optimization_for_src(*args, **kargs)
          super
        end
      end

      class AssemblerTab < AssemblerTab
        def add_misc_flag_for_src(*args, **kargs)
          super
        end
      end

      class LinkerTab < LinkerTab
        def use_microlib(*args, **kargs)
          super
        end
      end

      class UtilitiesTab < UtilitiesTab
        def configure_flash_program(*args, **kargs)
          super
        end

        def update_before_debug(*args, **kargs)
          super
        end
      end
    end
  end
end

