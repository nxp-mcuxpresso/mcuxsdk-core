# frozen_string_literal: true
# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require 'logger'
require_relative 'string'
require_relative 'logger/log_constants'
require_relative 'logger/log_device'
require_relative 'logger/log_helper'

# Logger for sdk generator
#
# @example setup a sdkgen logger
#   log_adapters = MultiLogDevice.new
#   terminal_dev = log_adapters.add_log_device(STD_OUT, STDOUT)
#   terminal_dev.colorize = true
#   terminal_dev.formatter = STD_OUT_FORMATTER
#
#   file_dev = log_adapters.add_log_device(LOG_FILE, 'log.txt', shift_size=0)
#   file_dev.formatter = LOG_FILE_FORMATTER
#
#   logger = SdkgenLogger.new(log_adapters, LogHelper.new(''))
#   logger.info 'test new'
#   logger.error 'error'
#   logger.warn 'warn'
#   logger.debug('lpc845') {'test'}
#   logger.fatal { 'block test' }
class SdkgenLogger < Logger
  attr_reader :contents
  attr_accessor :helper

  # @see Logger::initialize
  def initialize(logdev, helper, _shift_age = nil, _shift_size = nil, level: nil, progname: nil, formatter: nil,
                 datetime_format: nil, binmode: nil, shift_period_suffix: nil)
    # Prevent initialize log dev
    super(nil)
    return unless logdev.is_a? MultiLogDevice

    @logdev = logdev
    @helper = helper
    @contents = []
  end

  # Add a log item to log device(s)
  #
  # @param severity [Logger::Security] Constants are defined in Logger namespace: +DEBUG+, +INFO+, +WARN+, +ERROR+,
  #   +FATAL+, or +UNKNOWN+.
  # @param progname [String] Program name string. Can be omitted. Treated as a message if no +message+ and +block+ are
  #   given.
  # @param message [String/Exception] The log message.
  def add(severity, message = nil, progname = nil)
    severity ||= UNKNOWN
    return true if @logdev.nil? || (severity < level)

    progname = @progname if progname.nil?
    if message.nil?
      if block_given?
        message = yield
      else
        message = progname
        progname = @progname
      end
    end

    cont = {
      severity: severity,
      time: Time.new,
      msg: message
    }
    cont[:prog] = progname if progname
    # Collect log history for deep analysis
    @contents.append(cont)
    @logdev.log_devices.each do |sub_dev|
      sub_dev.write(sub_dev.format_message(severity, cont[:time], progname, message))
    end
    true
  end

  # Log with exist content
  #
  # @param id [String] unique id of the issue, like MIR0001
  def log_id(id, &block)
    issue = @helper.get(id)
    raise ArgumentError if issue.nil?
    add(issue[:severity], nil, issue[:overview], &block)
  end
end
