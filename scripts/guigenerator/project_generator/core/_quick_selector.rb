# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../utils/_assert'

# ********************************************************************
# Provide quick way to get data from nested hash
# can be used as static functions:
#   QuickSelector.find(data, ['path', 'by', 'keys'])
# or instance
#   instance = QuickSelector.new(data).find(['path', 'by', 'keys'])
# ********************************************************************
class QuickSelector
  def initialize(data, cached = false)
    @data   = data
    @cached = cached
    @cache  = {}
  end

  def find(keys)
    Core.assert(keys.is_a?(Array) && !keys.empty?) do
      "keys param '#{keys}' must be non-empty array"
    end
    if @cached
      expression = keys.join('/')
      unless @cache.key?(expression)
        data = QuickSelector.find(@data, keys)
        @cache[expression] = data
      end
      @cache[expression]
    else
      QuickSelector.find(@data, keys)
    end
  end

  def findcheck(keys)
    result = find(keys)
    Core.assert(!result.nil?) do
      "cannot find data for expression '#{keys.join('/')}'"
    end
    result
  end

  def self.find(data, keys)
    Core.assert(keys.is_a?(Array) && !keys.empty?) do
      "keys param '#{keys}' must be non-empty array"
    end
    keys.each_with_index do |key, _index|
      data = data[key]
      return nil unless data
    end
    data
  end

  def self.findcheck(data, keys)
    result = find(data, keys)
    Core.assert(!result.nil?) do
      "cannot find data for expression '#{keys.join('/')}'"
    end
    result
  end
end
# ********************************************************************
# EOF
# ********************************************************************
