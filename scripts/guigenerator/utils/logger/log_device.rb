# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# frozen_string_literal: true
require 'logger'
require_relative '../string'
# Device used for logging messages.
# This class inherits from rubylogger's +LogDevice+ and it supports specific log formatter.
class LogDevice < Logger::LogDevice
  # @return [String] name of the log device
  attr_reader :name
  # @return [Boolean] whether generate colorful output (only valid when using +STDOUT+)
  attr_accessor :colorize
  # @return [Logger::Formatter] log formatter
  attr_accessor :formatter

  # @param name [Object] name of the log device.
  # @param log [String/IO] The log device. Can be a filename or IO object (typically  +STDOUT+, +STDERR+.
  # @param shift_age [Integer/String] Number of old log files to keep, *or* frequency of rotation (+daily+, +weekly+ or
  #   +monthly+). Default value is 0, which disables log file rotation.
  # @param shift_size [Integer] Maximum logfile size in bytes (only applies when +shift_age+ is a positive Integer).
  #   Defaults to +1048576+ (1MB).
  # @param shift_period_suffix [String] The log file suffix format for +daily+, +weekly+ or +monthly+ rotation.
  #   Default is '%Y%m%d'.
  # @param binmode [true, false] Use binary mode on the log device. Default value is false.
  def initialize(name, log = nil, shift_age: nil, shift_size: nil, shift_period_suffix: nil, binmode: false)
    super(log, shift_age: shift_age, shift_size: shift_size, shift_period_suffix: shift_period_suffix, binmode: binmode)
    @name = name
    @colorize = false
    @formatter = Logger::Formatter.new
  end

  # Format a log message.
  #
  # @param severity [Logger::Security] Constants are defined in Logger namespace: +DEBUG+, +INFO+, +WARN+, +ERROR+,
  #   +FATAL+, or +UNKNOWN+.
  # @param datetime [Time] log time.
  # @param progname [String] Program name string. Can be omitted. Treated as a message if no +message+ and +block+ are
  #   given.
  # @param msg [String/Exception] The log message.
  def format_message(severity, datetime, progname, msg)
    fmt_msg = msg.dup
    if @colorize
      case severity
      when Logger::WARN
        fmt_msg = fmt_msg
      when Logger::ERROR
        fmt_msg = fmt_msg
      when Logger::FATAL
        fmt_msg = fmt_msg
      when Logger::DEBUG
        fmt_msg = fmt_msg
      else
        # type code here
      end
    end
    @formatter.call(format_severity(severity), datetime, progname, fmt_msg)
  end

  private

  # Severity label for logging (max 5 chars).
  SEV_LABEL = %w[DEBUG INFO WARN ERROR FATAL ANY].freeze

  def format_severity(severity)
    SEV_LABEL[severity] || 'ANY'
  end

  def add_log_header(file)
    if file.size.zero?
      file.write(
        '# Logfile created by SDK Generator'
      )
    end
  end
end

# Adapter to support log to different +LogDevice+
class MultiLogDevice
  # @return [Array(LogDevice)] the list of valid log devices
  attr_reader :log_devices

  def initialize
    @log_devices = []
  end

  # Create a {LogDevice}
  #
  # @param (see LogDevice#initialize)
  def new_log_device(name, logdev, shift_age = 0, shift_size = 1_048_576, binmode: false, shift_period_suffix: '%Y%m%d')
    instance = LogDevice.new(name, logdev, shift_age: shift_age,
                             shift_size: shift_size,
                             shift_period_suffix: shift_period_suffix,
                             binmode: binmode)
    @log_devices.append(instance)
    instance
  end

  # Add a {LogDevice}
  #
  # @param logdev [LogDevice] log device instance
  def add_log_device(logdev)
    raise 'The input parameter is not a valid LogDevice' unless logdev.is_a?(LogDevice)

    @log_devices.append(logdev)
  end

  # Call each {LogDevice}'s write API
  def write(*args)
    @log_devices.each { |logdev| logdev.write(*args) }
  end

  # Call each {LogDevice}'s close API
  def close
    @log_devices.each(&:close)
  end
end
