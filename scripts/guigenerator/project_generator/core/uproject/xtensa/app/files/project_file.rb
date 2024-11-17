# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/cdt/files/_project_file'

module Xtensa
  module App
    class ProjectFile < Internal::Cdt::ProjectFile
      def save(*args)
        super
    end

      def add_variable(*args)
        super
    end

      def clear_variables!(*args)
        super
    end

      def projectname(*args)
        super
    end

      def create_vdir(*args)
        super
    end

      def add_source(*args)
        super
    end

      def clear_sources!(*args)
        super
    end
  end
    end
end
