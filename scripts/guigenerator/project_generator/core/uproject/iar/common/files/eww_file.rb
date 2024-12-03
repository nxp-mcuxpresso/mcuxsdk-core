# frozen_string_literal: true

# ********************************************************************
# Copyright 2019 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/iar/files/_eww_file'

module Iar
  module Common
    class EwwFile < Internal::Iar::EwwFile
      def initialize(template, logger: nil)
        super
      end

      def add_batch_project_target(batchname, project, target)
        super
      end

      def save(path)
        super
      end

      def add_project(path)
        super
      end
    end
  end
end
