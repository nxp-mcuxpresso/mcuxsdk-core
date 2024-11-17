# frozen_string_literal: true
# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# @!visibility private
module Color
  refine String do
    # Add color for string in terminal
    #
    # @param color_code [Object] color code in terminal
    # @return [String (frozen)] colorized string
    def colorize(color_code)
      $stdout.isatty ? "\e[#{color_code}m#{self}\e[0m" : self
    end

    # @!macro color
    #   Return string in $0
    # @macro color
    def red
      colorize(31)
    end

    # @macro color
    def green
      colorize(32)
    end

    # @macro color
    def yellow
      colorize(33)
    end

    # @macro color
    # def blue
    #   colorize(34)
    # end

    # @macro color
    def pink
      colorize(35)
    end

    # @macro color
    # def light_blue
    #   colorize(36)
    # end

    def bg_red
      colorize(41)
    end

    def bg_green
      colorize(42)
    end

    def bg_yellow
      colorize(43)
    end
  end
end
