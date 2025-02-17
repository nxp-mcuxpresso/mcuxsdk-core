# frozen_string_literal: true

# ********************************************************************
# Copyright 2022, 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/cdt/files/_project_file'

module CodeWarrior
  module Common
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

      def project_parent_path(path)
          Core.assert(path.is_a?(String)) do
              "param is not a string"
          end
          result = /^(\.\.\/)+/.match(path)
          if result
            dots    = "#{$&}"
            parts   = "#{$&}".split('/')
            path = path.sub(dots, "PARENT-#{parts.length}-PROJECT_LOC/")
          else
            path = File.join('PARENT-0-PROJECT_LOC', path)
          end
          path
      end
    end
  end
end

