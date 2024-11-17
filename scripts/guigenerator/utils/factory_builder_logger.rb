# frozen_string_literal: true

# ####################################################################
# Copyright 2023 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ####################################################################
require_relative '../utils/utils'
require_relative '../utils/_assert'
require_relative '../utils/sdk_utils'
require 'yaml'
require_relative '../utils/sdk_consts'
module SDKGenerator
  # Logger for SDKGEN factor builder
  #
  # HOW TO USE
  #   # Create logger
  #   logger = Logger.new(STDOUT)
  #   logger.level = Logger::WARNING
  #   # builder here is the builder like SDKSupersetProductBuilder
  #   @product_builder_logger = FactoryBuilderLogger.new(builder.name, builder::DESCRIPTION, logger: @logger)
  #   @product_builder_logger.error_as_failure = true
  #   # frequently used info/info_nostd/warn/warn_nostd/error/fatal
  #   @product_builder_logger.warn('frdmk64f', 'This is an warn')
  #   @product_builder_logger.fatal('frdmk66f', 'This is an fatal')
  #   @product_builder_logger.merge_sub(sub_data)
  #   @product_builder_logger.update_status
  #   # return log data
  #   @product_builder_logger.product_builder_log
  class FactoryBuilderLogger
    include Utils
    include SDKUtils
    # [Boolean] flag whether error shall be logged as failure
    # Designed for strict error messages on production
    attr_writer :error_as_failure
    # [Boolean] flag whether same message should be logged to console as well
    attr_writer :log_to_std_logger

    # [Object] logger, exposed
    attr_reader :logger

    # Constructor
    # @param [String] log_title
    # @param [String] log_description
    # @param [Logger] logger
    def initialize(log_title, log_description, *_args, logger: nil, production: false, log_dir: nil, **_kwargs)
      @logger = logger ? logger : Logger.new($stdout)
      @log_title = log_title
      @log_description = log_description
      @log_data = {}
      @log_dir = log_dir
      @error_as_failure = production
      @logger_level = @logger.level
      creat_log_arch
    end

    def self.define_log_message(name)
      define_method(name) do |location = nil, message|
        name = :fatal if @error_as_failure && (name.to_s == 'error')
        message = location.nil? ? message : "#{location}: #{message}"
        # fatal should be recorded in rescue so that backtrace can be got
        record_issue(message, name.to_s.gsub(/_nostd/, '')) if name.to_sym != :fatal && record_issue?(name)
        @logger.send(name, message) unless name.to_s.end_with?('_nostd')
        update_fatal(message) if name.to_sym == :fatal
      end
    end

    define_log_message :info
    define_log_message :info_nostd
    define_log_message :debug
    define_log_message :debug_nostd
    define_log_message :warn
    define_log_message :warn_nostd
    define_log_message :error
    define_log_message :fatal

    def record_issue?(log_name)
      log_level = case log_name
                  when :debug, :debug_nostd
                    0
                  when :info, :info_nostd
                    1
                  when :warn, :warn_nostd
                    2
                  when :error
                    3
                  when :fatal
                    4
                  end

      @logger_level <= log_level
    end

    def dump_log_data
      log_dir = Pathname.new(log_file_path).dirname.to_s
      FileUtils.mkdir_p(log_dir) unless File.exist?(log_dir)
      File.open(log_file_path, 'w') do |f|
        f.puts @log_data.to_yaml
      end
    end

    def status_unknown?
      update_status
      log_data_content['status'].to_const == UNKNOWN
    end

    def status_warn?
      update_status
      log_data_content['status'].to_const == WARN
    end

    def status_error?
      update_status
      log_data_content['status'].to_const == ERROR
    end

    def status_fatal?
      update_status
      log_data_content['status'].to_const == FATAL
    end

    def run_abort?
      update_status
      log_data_content['status'].to_const == ABORT
    end

    def product_builder_log
      update_status
      @log_data
    end

    # Update log data status: SUCCESS/WARN/ERROR/FATAL/ABORT
    def update_status
      # If no fatal, abort, sub, then return original status
      if log_data_content['fatal'].nil? && log_data_content['abort'].nil? && log_data_content['sub'].nil? && log_data_content['logs'].nil?
        return log_data_content['status']
      end

      main_status = main_part_status
      sub_status = sub_part_status
      log_data_content['status'] = main_status.to_const > sub_status.to_const ? main_status : sub_status
    end

    # Update exception into log data
    #
    # @param [SDKGENException] exception
    # @return [String (frozen)] log status
    def update_exception(exception)
      Core.assert exception.is_a? Exception do
        'For generator developers: expect an exception instance to be passed as an argument. Please check generator code.'
      end
      # FIXME: incorrect output format
      @logger.fatal(exception.message)
      @logger.fatal("  backtrace: #{exception.backtrace}")
      sub_array(log_data_content, 'abort').push({ 'message' => exception.message, 'backtrace' => exception.backtrace })
      # abort results in failed
      log_data_content['status'] = 'ABORT'
    end

    # Merge sub log data
    #
    # @param [Hash] data: sub log data
    def merge_sub(data)
      Core.assert(data.is_a?(Hash)) do
        'Sub process return status log must be a hash type.'
      end
      data.each do |_key, sub_data_content|
        if sub_data_content.safe_key? 'abort'
          sub_array(log_data_content,
                    'abort').concat(deep_copy(sub_data_content['abort']))
        end

        if sub_data_content.safe_key? 'fatal'
          sub_array(log_data_content,
                    'fatal').concat(deep_copy(sub_data_content['fatal']))
        end

        sub_hash(log_data_content, 'sub').merge!(data.dup)
      end
      update_status
      true
    end

    # Dump fatal/abort message
    #
    # @param [String] level: fatal or abort
    def dump_fatal_abort_message(level)
      fatals = log_data_content.fetch_raise_msg("#{level} is not found in log file", level)
      puts "***************#{level}***************"
      fatals.each do |fatal|
        puts "message: #{fatal['message']}"
        next unless fatal.safe_key? 'backtrace'

        puts 'backtrace:'
        fatal['backtrace'].each do |each|
          puts "  #{each}"
        end
      end
    end

    private

    def update_fatal(message)
      sub_array(log_data_content, 'fatal').push({ 'message' => message })
    end

    def main_part_status
      return 'ABORT' unless log_data_content['abort'].nil?
      return 'FATAL' unless log_data_content['fatal'].nil?
      return 'ERROR' unless log_data_content.dig('logs', 'error').nil?
      return 'WARN' unless log_data_content.dig('logs', 'warn').nil?

      'SUCCESS'
    end

    def sub_part_status
      return 'SUCCESS' unless log_data_content.safe_key? 'sub'

      status = 'SUCCESS'
      log_data_content['sub'].each do |_key, value|
        status = value['status'].to_const > status.to_const ? value['status'] : status
      end
      status
    end

    def log_data_content
      @log_data[@log_title]
    end

    # Logs an issue
    # @param [String] message: issue message
    # @param [String] level: logger level: debug, info, warning, error
    def record_issue(message, level)
      Core.assert(!message.nil?) do
        'The issue content cannot be nil'
      end
      sub_array(sub_hash(log_data_content, 'logs'), level).push(message)
      true
    end

    def creat_log_arch
      Core.assert(@log_title) do
        'Generator cannot find log title for product logger'
      end
      @log_data[@log_title] = {}
      @log_data[@log_title]['description'] = @log_description if @log_description
      @log_data[@log_title]['status'] = 'SUCCESS'
    end

    def log_file_path
      if @log_dir
        if @log_dir.end_with? '.yml'
          @log_dir
        else
          File.join(@log_dir, "#{@log_title}.yml")
        end
      else
        File.join(Pathname.new(__dir__).parent.parent.to_s, "#{@log_title}.yml")
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  logger = Logger.new($stdout)
  logger.level = Logger::DEBUG
  logger.formatter = proc do |_severity, _datetime, _progname, msg|
    "#{msg}\n"
  end
  @factory_builder_logger = SDKGenerator::FactoryBuilderLogger.new('ProjectGeneration', 'Generate SDK Project',
                                                                   logger: logger)
  @factory_builder_logger.debug('frdmk64f', 'This is an debug')
  @factory_builder_logger.info('frdmk64f', 'This is an info')
  @factory_builder_logger.warn('frdmk64f', 'This is an warn')
  @factory_builder_logger.error('frdmk66f', 'This is an error')
  puts 'Run warning' if @factory_builder_logger.status_warn?
  puts 'Run error' if @factory_builder_logger.status_error?
  @factory_builder_logger.fatal('frdmk66f', 'This is an fatal')
  @factory_builder_logger.info_nostd('frdmk64f', 'This is an info_nostd')
  @factory_builder_logger.warn_nostd('frdmk66f', 'This is an warn_nostd')
  @factory_builder_logger.merge_sub({ 'frdmkl02z' => { 'status' => 'ABORT', 'abort' => [{ 'message' => 'Unexpected happes.',
                                                                                          'backtrace' => ["D:/git_misc/ruby_practice/exceptionType/exceptiontype.rb:5:in `<main>'"] }] } })
  # puts "Run failed: #{@factory_builder_logger.run_failed?}"
  # puts "Run abort: #{@factory_builder_logger.run_abort?}"
  # @factory_builder_logger.dump_log_data
  @factory_builder_logger.update_status
  true
end
