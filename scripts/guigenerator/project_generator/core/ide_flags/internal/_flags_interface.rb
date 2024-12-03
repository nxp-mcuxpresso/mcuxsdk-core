# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Internal
  module FlagsInterface
    def analyze_asflags(target, line)
      line = line.strip
      @logger.error("unrecognized '#{target}' asflags '#{line}' ") unless line.empty?
    end

    def analyze_ccflags(target, line)
      line = line.strip
      @logger.error("unrecognized '#{target}' ccflags '#{line}' ") unless line.empty?
    end

    def analyze_cxflags(target, line)
      line = line.strip
      @logger.error("unrecognized '#{target}' cxflags '#{line}' ") unless line.empty?
    end

    def analyze_ldflags(target, line)
      line = line.strip
      @logger.error("unrecognized '#{target}' ldflags '#{line}' ") unless line.empty?
    end

    def analyze_arflags(target, line)
      line = line.strip
      @logger.error("unrecognized '#{target}' arflags '#{line}' ") unless line.empty?
    end
  end
end
