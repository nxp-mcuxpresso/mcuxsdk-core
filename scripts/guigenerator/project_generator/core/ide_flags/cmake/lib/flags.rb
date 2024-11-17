# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../common/flags'

module CMake
  module Lib

    class Flags < CMake::Common::Flags

      def is_lib?
        return false
      end

      def is_app?
        return true
      end

      def analyze_asflags(target, line)
        Core.assert(target.is_a?(String)) do
          "target is not a string '#{target}'"
        end
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("asflags line: #{line}")
        super(target, line)
      end

      def analyze_ccflags(target, line)
        Core.assert(target.is_a?(String)) do
          "target is not a string '#{target}'"
        end
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("ccflags line: #{line}")
        super(target, line)
      end

      def analyze_cxflags(target, line)
        Core.assert(target.is_a?(String)) do
          "target is not a string '#{target}'"
        end
        Core.assert(line.is_a?(String)) do
          "line is not a string '#{line}'"
        end
        @logger.debug("cxflags line: #{line}")
        super(target, line)
      end
    end
  end
end

