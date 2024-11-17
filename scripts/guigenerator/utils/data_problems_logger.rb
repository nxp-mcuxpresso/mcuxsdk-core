# frozen_string_literal: true

# ********************************************************************
# Copyright 2018 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative 'utils'
require_relative 'sdk_utils'

# [String] Category for data logger used by manifest generator, CMSIS pack generator, SDK components XML generator
MAIN_CATEGORY_FILE_GENERATOR = 'Aux-Files Generator'
# [String] Category for data logger used by package builder
MAIN_CATEGORY_PKG_GENERATOR = 'Package-File Generator'

# [String] Root category of statistics
STATISTICS_ROOT_CATEGORY = 'Statistics of Problems'
# [String] Category 'Messages'
STATISTICS_MESSAGES_CATEGORY = 'Messages'
# [String] Category 'Locations'
STATISTICS_LOCATIONS_CATEGORY = 'Locations'

# [String] Problem type: ERROR
PROBLEM_TYPE_ERROR = 'ERROR'
# [String] Problem type: Warning
PROBLEM_TYPE_WARNING = 'Warning'

# [String] Problem is owned by the SDK team
PROBLEM_OWNER_SDK = 'SDK'
# [String] Problem is owned by the SDK Generator team
PROBLEM_OWNER_SDKGEN = 'SDKGEN'
# [String] Problem is owned by the user
PROBLEM_OWNER_USER = 'USER'
# [Array] Known problem owners
PROBLEM_OWNERS = [PROBLEM_OWNER_SDK, PROBLEM_OWNER_SDKGEN, PROBLEM_OWNER_USER].freeze

# ********************************************************************
# Logger for problems found in input data
# HOW TO USE
#
#   # Create logger
#   logger = Logger.new(STDOUT)
#   logger.level = Logger::WARNING
#   data_logger = DataProblemsLogger.new(logger, 'name-of-main-category')
#   data_logger.error_as_failure = true # set error as failure
#
#   # Set a category for all reported issues
#   data_logger.subcategory('Manifest Generator', 'Manifest Generator generates manifest.xml file(s)')
#
#   # Log failure/error/warning
#   data_logger.log_failure('release_config.yml', 'Missing manifest version')
#   data_logger.log_error('release_config.yml', 'Duplicate manifest format version')
#   data_logger.log_warning('release_config.yml', 'Manifest format version no more supported: 3.2')
#
#   # Retrieve result
#   result = data_logger.summary
#
#   # Check whether any failure was logged
#   if result['failed']
#     puts 'Generation failed'
#   end
class DataProblemsLogger < BaseClassWithLogger
  include Utils

  # [Boolean] flag whether error shall be logged as failure
  # Designed for strict error messages on production
  attr_writer :error_as_failure
  # [Boolean] flag whether same message should be logged to console as well
  attr_writer :log_to_std_logger
  # [Array] The message array, save all the stage process internal function error message
  attr_accessor :message_array

  # --------------------------------------------------------
  # Constructor
  # @param [Logger] logger: logger
  def initialize(logger, main_category)
    super(logger)
    @failed_summary = {}
    @subcategory_with_description = {}
    @category = main_category
    @log_to_std_logger = true
    @error_as_failure = false

    # add use for log error message function
    @message_array = []
  end

  # --------------------------------------------------------
  # Sets current subcategory
  # @param [String] name: of the sub-category, name split by slip line or space, without '.'
  # @param [String] description: of the sub-category
  def subcategory(name, description)
    @subcategory = name
    @subcategory_with_description[name] = description
  end

  # --------------------------------------------------------
  # Logs a failure
  # The generation process file and resulting file is not stored on the disk
  # @param [String] location: name of file or object, where the problem is located
  # @param [String] error: message
  # @param [String] subcategory: name of the sub-category
  # @param [Array/String] owners: owners of the failure
  def log_failure(location, error, subcategory = nil, owners = nil)
    @failed_summary['failed'] = true
    log_issue(location, error, subcategory || @subcategory, true,  owners)
    raise FatalError, location + ': ' + error
  end

  # --------------------------------------------------------
  # Logs a error
  # This error does not stop the generation process with failure
  # @param [String] location: name of file or object, where the problem is located
  # @param [String] error: message
  # @param [String] subcategory: name of the sub-category
  # @param [Array/String] owners: owners of the error
  def log_non_failing_error(location, error, subcategory = nil, owners = nil)
    log_issue(location, error, subcategory || @subcategory, true, owners)
  end

  # --------------------------------------------------------
  # Logs a error
  # It is logged same as failure, but the generation process does not fail
  # @param [String] location: name of file or object, where the problem is located
  # @param [String] error: message
  # @param [String] subcategory: name of the sub-category
  # @param [Array/String] owners: owners of the error
  def log_error(location, error, subcategory = nil, owners = nil)
    @failed_summary['failed'] = true
    if @error_as_failure
      log_failure(location, error, subcategory || @subcategory, owners)
      return
    end
    log_non_failing_error(location, error, subcategory || @subcategory, owners)
  end

  # --------------------------------------------------------
  # Logs a warning
  # @param [String] location: name of file or object, where the problem is located
  # @param [String] warning: message
  # @param [String] subcategory: name of the sub-category
  # @param [Array/String] owners: owners of the warning
  def log_warning(location, warning, subcategory = nil, owners = nil)
    log_issue(location, warning, subcategory || @subcategory, false, owners)
  end

  # --------------------------------------------------------
  # Logs a warning but not log to std
  # @param [String] location: name of file or object, where the problem is located
  # @param [String] warning: message
  # @param [String] subcategory: name of the sub-category
  # @param [Array/String] owners: owners of the warning
  def log_warning_no_std(location, warning, subcategory = nil, owners = nil)
    log_issue(location, warning, subcategory || @subcategory, false, owners, true)
  end

  # --------------------------------------------------------
  # @return [Hash] summary of found problems; empty hash is no problems
  #         The hash contains 'failed' key with boolean value, whether any failure was logged
  def summary
    # add 'failed' key if not there and hash not empty
    @failed_summary['failed'] = false if @failed_summary.dig('failed').nil? && !@failed_summary.empty?
    unless @failed_summary.empty?
      sort_statistics(PROBLEM_TYPE_ERROR) # Sort error messages in statistics
      sort_statistics(PROBLEM_TYPE_WARNING) # Sort warning messages in statistics
      # 'Statistics of Problems' should be set at the ending of the @failed_summary
      statistics_content = statistics_root
      sub_hash(@failed_summary, @category).delete(STATISTICS_ROOT_CATEGORY)
      @failed_summary[@category].store(STATISTICS_ROOT_CATEGORY, statistics_content)
    end
    # return result
    return @failed_summary
  end

  # --------------------------------------------------------
  # Logs a error
  # The error generate at stage main process
  # @param [String] location: name of file or object, where the problem is located
  # @param [String] error: message
  # @param [String] subcategory: name of the sub-category
  def log_stage_error(location, error, subcategory = nil)
    @failed_summary['failed'] = true
    log_issue(location, error, subcategory || @subcategory, true, nil)
  end

  # :nodoc:
  def info(progname = nil, &block)
    @logger.info(progname, &block)
  end

  #
  # Log a +WARN+ message.
  #
  # See #info for more information.
  #
  def warn(progname = nil, &block)
    @logger.warn(progname, &block)
  end

  #
  # Log an +ERROR+ message.
  #
  # See #info for more information.
  #
  def error(progname = nil, &block)
    @logger.error(progname, &block)
  end

  #
  # Log a +FATAL+ message.
  #
  # See #info for more information.
  #
  def fatal(progname = nil, &block)
    @logger.fatal(progname, &block)
  end

  #
  # Log an +UNKNOWN+ message.  This will be printed no matter what the logger's
  # level is.
  #
  # See #info for more information.
  #
  def unknown(progname = nil, &block)
    @logger.unknown(progname, &block)
  end

  private

  # --------------------------------------------------------
  # @return [Hash] root category where statistics is located
  def statistics_root
    return sub_hash(sub_hash(@failed_summary, @category), STATISTICS_ROOT_CATEGORY)
  end

  # --------------------------------------------------------
  # Updates @failed_summary with sorted statistics
  # @param [String] problem_type: either 'ERROR' or 'Warning' category to be sorted
  def sort_statistics(problem_type)
    problems = sub_hash(statistics_root, problem_type + 's')
    return if problems.empty?

    # Messages
    messages = sub_hash(problems, STATISTICS_MESSAGES_CATEGORY)
    msgs_arr = []
    messages.each { |msg, count| msgs_arr.push(count.to_s.rjust(4, ' ') + ': ' + msg) }
    problems[STATISTICS_MESSAGES_CATEGORY] = msgs_arr.sort
    # Locations
    messages = sub_hash(problems, STATISTICS_LOCATIONS_CATEGORY)
    msgs_arr = []
    messages.each { |msg, count| msgs_arr.push(count.to_s.rjust(4, ' ') + ': ' + msg) }
    problems[STATISTICS_LOCATIONS_CATEGORY] = msgs_arr.sort
  end

  # --------------------------------------------------------
  # Ensure hash contains key with sub-hash
  # @param [Hash] hash: that should contains key
  # @param [String] key: to identify hash in the hash above
  def sub_hash(hash, key)
    hash.store(key, {}) unless hash.key?(key)
    return hash[key]
  end

  # --------------------------------------------------------
  # Update error statistics: increments selected value
  # @param [Hash] hash: category, where the value should be incremented
  # @param [String] key: value to be incremented
  def increment_key(hash, key)
    cur_value = hash[key]
    new_value = if cur_value.nil?
                  1
                else
                  cur_value + 1
                end
    hash[key] = new_value
  end

  # --------------------------------------------------------
  # Update error statistics
  # @param [String] problem_type: either ERROR or Warning
  # @param [String] message: description of the problem
  # @param [String] location: name of file or object, where the problem is located
  def update_statistics(problem_type, message, location)
    p = message.index('::')
    message = message[0..p] + ' {...}' unless p.nil?
    type_category = sub_hash(statistics_root, problem_type + 's')
    increment_key(type_category, 'TOTAL COUNT')
    increment_key(sub_hash(type_category, STATISTICS_MESSAGES_CATEGORY), message.to_s)
    increment_key(sub_hash(type_category, STATISTICS_LOCATIONS_CATEGORY), location)
  end

  # --------------------------------------------------------
  # Logs an issue message, either error or warning
  # @param [Hash] problems: target group of issues in the Hash structure
  # @param [Boolean] is_error: true if error, false if warning
  # @param [String] location: path and name of file or object, where the problem is located
  # @param [String] message: description of the problem
  # @param [Boolean] no_std: flag to tell whether log to std
  def log_msg(problems, is_error, location, message, no_std = false, owners = nil)
    # add issue to Hash
    category = sub_hash(problems, location)
    problem_type = if is_error
                     PROBLEM_TYPE_ERROR
                   else
                     PROBLEM_TYPE_WARNING
                   end
    category.store(problem_type, []) unless category.key? problem_type
    msgs_arr = category[problem_type]
    if msgs_arr.include? message
      logger.debug('((DUPLICATED ' + problem_type + ')):' + location + ': ' + message)
      return
    end

    msgs_arr.push message
    update_statistics(problem_type, message, location)
    # log using logger to console
    return true unless @log_to_std_logger

    owners = if owners.class == String
               PROBLEM_OWNERS.include?(owners.upcase) ? owners.upcase : nil
             elsif owners.class == Array
               owners.select { |owner| PROBLEM_OWNERS.include?(owner.upcase) }&.map { |owner| owner.upcase }&.join('/')
             else
               nil
             end
    # TODO ZJW research in CI scripts to find the best seperator here.
    location = "[#{owners}]: #{location}" if owners
    if is_error
      logger.error(location + ': ' + message)
    elsif !no_std
      logger.warn(location + ': ' + message)
    end
  end

  # --------------------------------------------------------
  # Logs an issue
  # @param [String] location: name of file or object, where the problem is located
  # @param [String] issue: issue message
  # @param [String] category: name of the sub-category
  # @param [Boolean] is_error: true if error, false if warning
  # @param [Array/String] owners: owners of the issue
  # @param [Boolean] no_std: flag to tell whether log to std
  def log_issue(location, issue, category, is_error, owners = nil, no_std = false)
    Utils.assert !issue.nil?, 'the issue content cannot be nil'
    main_cat = sub_hash(@failed_summary, @category)
    sub_cat = sub_hash(main_cat, category)
    sub_cat.store('Description', @subcategory_with_description[category]) unless sub_cat.key?('Description')
    problems = sub_hash(sub_cat, 'Problems')

    # log all the error message, without the error location
    @message_array.push_uniq(issue) if is_error
    log_msg(problems, is_error, location, issue, no_std, owners)
  end
end
# ********************************************************************
# EOF
# ********************************************************************
