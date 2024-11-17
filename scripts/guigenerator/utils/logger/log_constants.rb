# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# frozen_string_literal: true
require_relative '../string'

# Name for stdout log device
STD_OUT_DEV = 'stdout'
# Name for IO object log device
LOG_FILE_DEV = 'logfile'
# Format in user terminal
STD_OUT_FORMATTER = proc do |severity, datetime, progname, msg|
  using Color
  date_format = datetime.strftime('%H:%M:%S')
  level = severity[0..0]
  case level
  when 'W'
    level = level.yellow
    msg = msg.yellow
  when 'E' || 'F'
    level = level.red
    msg = msg.red
  end
  if progname
    "#{level}, [#{date_format}]: (#{progname}) #{msg}\n"
  else
    "#{level}, [#{date_format}]: #{msg}\n"
  end
end

# Format in log file
LOG_FILE_FORMATTER = proc do |severity, datetime, progname, msg|
  date_format = datetime.strftime('%Y-%m-%dT%H:%M:%S.%6N')
  if progname
    "[#{date_format}##{$PROCESS_ID}] #{severity.rjust(5)}: (#{progname}) #{msg}\n"
  else
    "[#{date_format}##{$PROCESS_ID}] #{severity.rjust(5)}: #{msg}\n"
  end
end