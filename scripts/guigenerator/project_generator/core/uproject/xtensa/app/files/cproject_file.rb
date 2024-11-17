# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/xtensa/files/_cproject_file'

module Xtensa
  module App
    class CprojectFile < Internal::Xtensa::CprojectFile
      attr_reader :includesTab
      attr_reader :genericTab
      attr_reader :armCCompilerTab
      attr_reader :armCppCompilerTab
      attr_reader :armAssemblerTab
      attr_reader :armCLinkerTab
      attr_reader :armCppLinkerTab

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
        @operations = DocumentOperations.new(@xml, 'exe', logger: @logger)
        @includesTab = IncludesTab.new(@operations)
      end

      def save(*args, **kargs)
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

      def add_variable(*args, **kargs)
        super
    end

      def clear_variables!(*args, **kargs)
        super
    end

      def artifact_name(*args, **kargs)
        super
    end

      def artifact_extension(*args, **kargs)
        super
    end

      def artifact_prefix(*args, **kargs)
        artifact_prefix_linker(*args, **kargs)
    end

      def prebuildstep_command(*args, **kargs)
        super
    end

      def postbuildstep_command(*args, **kargs)
        super
    end

      def builder(*args, **kargs)
        super
    end

      def create_flash_image(*args, **kargs)
        super
    end

      def create_flash_choice(*args, **kargs)
        super
    end

      def create_extended_listing(*args, **kargs)
        super
    end

      def print_size(*args, **kargs)
        super
    end

      def update_refresh_scope(*args, **kargs)
        super
      end

      def update_cdt_build_system(*args, **kargs)
        super
      end

      class IncludesTab < IncludesTab
        def initialize(operations)
          super(operations)
        end

        def add_include(*args, **kargs)
          super
      end

        def clear_include!(*args, **kargs)
          super
      end

        def add_includefile(*args, **kargs)
          super
      end

        def clear_includefiles!(*args, **kargs)
          super
      end
      end

  end
  end
end
