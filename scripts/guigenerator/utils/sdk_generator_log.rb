# frozen_string_literal: true

# ********************************************************************
# Copyright 2018 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative 'utils'
require_relative 'sdk_utils'
require_relative 'sdk_consts'

module SDKGenerator
  # ********************************************************************
  # Process the log for each stage, collects data and saves to the disk
  # ********************************************************************
  class GeneratorLog
    include SDKUtils
    attr_reader :udata
    # --------------------------------------------------------
    # Constructor
    # @param [Hash] option: global options for generation
    # @param [Logger] logger:
    # @param [String] stage: name of the stage being processed
    def initialize(option: nil, logger: nil, stage: 'stage?')
      # the log data hash
      @udata = {}
      @generator_option = option
      @logger = logger
      @stage = stage
      @log_file = ''
      init_log_file_name
    end

    # --------------------------------------------------------
    # Add logged data
    # @param [Hash] data: logged data to be added
    # @return [Nil]
    def collect_data(data)
      return if data.nil? || data.empty?

      Core.assert(data.instance_of?(Hash)) do
        'The log data must be a Hash object.'
      end
      @udata.deep_merge(data)
    end

    # --------------------------------------------------------
    # Process all data, print the status
    # @return [Nil]
    def process
      if @udata.empty?
        if @stage == 'stage0' || @stage == 'stage1' || @stage == 'stage2' || @stage == 'stage3' || @stage == 'stage4'
          puts "In #{@stage}, all cases in all steps of #{@name} run passed."
        end
      end
      create_log_file(File.join(output_directory, "sdk_generator_log_#{@stage}"))
    end

    # ---------------------------------------------------------------------
    # Check whether there is any errors in the stage log
    # @return [Boolean] true for no errors
    def no_error?
      return true if @udata.empty?
      @udata.values.each do |each_subcategory|
        next if Hash != each_subcategory.class
        return true if each_subcategory['Statistics of Problems']['ERRORs'].empty?
      end
      return false
    end

    private

    # --------------------------------------------------------
    # @return [Boolean] true if execution is before stage3, e.g. stage1,stage2 or make_stage3_options
    def before_stage3?
      %w[prestage_check_environment prestage_process_arguments stage0 stage1 stage2 post_stage1 post_stage2
         make_stage1_options make_stage2_options make_stage3_options].include?@stage
    end

    # --------------------------------------------------------
    # make up the absolute dir for log file
    # @return [string] output directory - the absolute log file path; never nil
    def output_directory
      if before_stage3?
        outdir = @generator_option[:log_file_location]
      else
        outdir = @generator_option.dig(:release_configuration, RELCFG_OUTPUT_ATTR, RELCFG_LOG_ATTR)
        outdir = @generator_option.dig(:release_configuration, RELCFG_OUTPUT_ATTR, RELCFG_DIRECTORY_ATTR) if outdir.nil?
      end
      Utils.assert !outdir.nil?, 'Output directory not specified in options'
      outdir
    end

    # --------------------------------------------------------
    # Creates a log file in specified directory
    # @param [Symbol] root_dir: path to create log file
    def create_log_file(root_dir)
      FileUtils.mkdir_p(root_dir) unless File.directory?(root_dir)
      log_file = File.join(root_dir, @log_file)
      File.open(log_file, 'w') do |f|
        if @udata.empty?
          f.puts({ 'failed' => false }.to_yaml)
        else
          f.puts @udata.to_yaml
        end
        puts '*' * 78
        puts "Please review the #{log_file} to see the detailed log."
      end
    end

    # @param [Symbol] symb: key for the option
    # @return [String] name from option, empty string if option not specified
    def name_from_option(symb)
      return @generator_option[symb] + '_' if @generator_option.key?(symb) && @generator_option[symb]
      ''
    end

    # --------------------------------------------------------
    # Get the log file name
    # @return [Nil]
    def init_log_file_name
      if @stage == 'stage0' || @stage == 'stage1' || @stage == 'stage2'
        @log_file += name_from_option(:device)
        @log_file += name_from_option(:board)
        @log_file += name_from_option(:core_id)
        @name = @log_file.split('_').join('_')
        @log_file += '_'
      else
        @name = 'manifest generation/prevalidation' if @stage == 'stage3'
        @name = 'package builder' if @stage == 'stage4'
      end
      @log_file += "#{@stage}_log.yml"
    end
  end
end
# ********************************************************************
# EOF
# ********************************************************************
