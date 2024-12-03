# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../common/flags'

module CodeWarrior
  module Lib
    class Flags < CodeWarrior::Common::Flags

      def is_lib?
        return true
      end
      def is_app?
        return false
      end

      def analyze_asflags(target, line)
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("asflags line: #{line}")
        super(target, line)
      end

      def analyze_ccflags(target, line)
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("ccflags line: #{line}")
        # Common setting
        super(target, line)
      end

      def analyze_ldflags(target, line)
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("ldflags line: #{line}")
        super(target, line)
      end
    end
  end
end
