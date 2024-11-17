# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/xtensa/files/_xxproject_file'

module Xtensa
  module App
    class XXprojectFile < Internal::Xtensa::XXprojectFile
      attr_reader :buildTab

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
        @operations = DocumentOperations.new(@xml, 'exe', logger: @logger)
        @buildTab = BuildTab.new(@operations)
      end

      def save(*args, **kargs)
        super
      end

      class BuildTab < BuildTab
        attr_reader :builderTab

        def initialize(*args, **kwargs)
          super(*args, **kwargs)
          @builderTab = BuilderTab.new(*args, **kwargs)
        end

        class BuilderTab < BuilderTab
          attr_reader :internalTab

          def initialize(*args, **kwargs)
            super(*args, **kwargs)
            @internalTab = InternalTab.new(*args, **kwargs)
          end

          class InternalTab < InternalTab
            def add_prebuild_steps(*args, **kargs)
              super
            end

            def add_prelink_steps(*args, **kargs)
              super
            end

            def add_postbuild_steps(*args, **kargs)
              super
            end

            def add_preclean_steps(*args, **kargs)
              super
            end
          end
        end
      end
    end
  end
end
