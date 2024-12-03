# frozen_string_literal: true

# ********************************************************************
# Copyright 2018 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

# ********************************************************************
# New class for SDK builder specific assertion exceptions
class AssertionError < StandardError
  # no code needed here
end

# ********************************************************************
# Assertion module
module Core
  # perform simple assertion like c <assert.h>
  # implementation raise an exception instead go to abort
  # two ways how use assert:
  # 1) assert(condition, "message")
  # 2) assert(condition) do "message" end
  # I would prefer use 2.nd way because 1.st way always
  # evaluate the message parameter ("like #{failed_var.some_info...}")
  # while 2.nd evaluate message only if condition fails
  def self.assert(condition, message = nil)
    return if condition

    message = yield(condition) if block_given?
    message = '' if message.nil?
    raise AssertionError, 'assertion error: ' + message
  end

  # --------------------------------------------------------
  # Shortcut for failed assertion
  # @param [String] +message+: message displayed in case of test failure
  def self.fail(message)
    assert(false, message)
  end
end
# ********************************************************************
# EOF
# ********************************************************************
