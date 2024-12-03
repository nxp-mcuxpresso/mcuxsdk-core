# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../common/files/uvoptx_file'


module Mdk
  module App

    class UvoptxFile < Mdk::Common::UvoptxFile

      attr_reader :debugTab

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
        # create shared "operations" instance
        @operations = DocumentOperations.new(@xml, logger: @logger)
        # create tab instances
        @debugTab = DebugTab.new(@operations)
      end

      def save(*args, **kargs) super end
      def project_name(*args, **kargs) super end
      def clear_unused_targets!(*args, **kargs) super end
      def get_target_name(*args, **kwargs) super end
      def set_target_name(*args, **kwargs) super end
      def targets(*args, **kargs) super end

      class DebugTab < DebugTab
        def add_initialization_file(*args, **kargs) super end
        def set_load_application(*args, **kargs) super end
        def set_periodic_update(*args, **kargs) super end
      end
    end
  end
end

