# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/mdk/files/_uvoptx_file'

module Mdk
  module Common
    class UvoptxFile < Internal::Mdk::UvoptxFile
      attr_reader :deviceTab

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
      end

      def save(*args, **kargs) super end
      def get_target_name(*args, **kwargs) super end
      def set_target_name(*args, **kwargs) super end
      def clear_unused_targets!(*args, **kargs) super end
      def project_name(*args, **kargs) super end
      def targets(*args, **kargs) super end

      class DebugTab < DebugTab
      end
    end
  end
end
