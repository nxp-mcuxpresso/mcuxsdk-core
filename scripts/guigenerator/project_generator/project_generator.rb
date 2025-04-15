# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require 'json'
require 'optparse'
require 'logger'
require_relative './generator'
require_relative './ninja_parser'
require_relative 'core/_fileutils'
require 'rubygems'

PACKAGE_YML_PATH = 'yml_data/shared/misc/package.yml'
SCRIPT_SUPPORTED_TOOLCHAIN = %w[iar mdk armgcc xtensa codewarrior]
CMAKE_LOG_LEVEL_MAP = { 'TRACE' => Logger::DEBUG,
                        'DEBUG' => Logger::DEBUG,
                        'VERBOSE' => Logger::INFO,
                        'STATUS' => Logger::INFO,
                        'NOTICE' => Logger::INFO,
                        'WARNING' => Logger::WARN,
                        'ERROR' => Logger::ERROR }
RUBY_MINIMUM_REQUIRED = '3.1.2'

def make_up_build_option(project, toolchain, config, outdir)
  build_option = {}
  build_option[:set_name] = "set.board.#{ENV['board']}"
  build_option[:entry_set] = "set.board.#{ENV['board']}"
  build_option[:project_list] = [project]
  build_option[:title] = ENV['board']
  build_option[:input_dir] = ENV['SdkRootDirPath']
  if toolchain == 'mcux'
    build_option[:output_dir] = ENV['SdkRootDirPath']
  else
    # for iar/mdk, support out-of-tree build, so we can specifiy build dir
    build_option[:output_dir] = ENV['build_dir']
  end
  build_option[:toolchains] = [toolchain]
  build_option[:projects] = [project]
  build_option[:output_type] = 'project'
  build_option[:sdk_data_version] = 'v3'
  build_option[:package_data_path] = File.join(ENV["SdkRootDirPath"], PACKAGE_YML_PATH)
  build_option[:generators] = {:project_generate => {}}
  build_option[:set] = {
                              board: {
                                ENV['board'] => {
                                  device: ENV['device'],
                                  device_id: ENV['device_id']
                                }
                              },
                              device: {
                                ENV['device'] => {
                                  full_name: {
                                    ENV['device_id'] => {
                                      board_id: [ENV['board']]
                                    }
                                  }
                                }
                              }
                            }
  # if File.exists?(build_option[:package_data_path])
  #   package_data = YAML.load_file(build_option[:package_data_path])
  #   build_option[:toolchains_version] = {}
  #   package_data.dig('package_data.general', 'contents', 'toolchains')&.each do |k, v|
  #     build_option[:toolchains_version][k] = v['version']
  #   end
  #   build_option[:manifest_versions] = package_data.dig('package_data.general', 'contents', 'manifest_version')
  # else
  #   build_option[:toolchains_version] = {'armgcc' => '12.3.1', 'mdk' => '5.38.1', 'iar' => '9.50.1', 'mcux' => '11.9.0'}
  #   build_option[:manifest_versions] = ['3.14']
  # end
  build_option[:toolchains_version] = {'armgcc' => '12.3.1', 'mdk' => '5.38.1', 'iar' => '9.50.1', 'mcux' => '11.9.0'}
  build_option[:manifest_versions] = ['3.14']
  build_option
end

if $PROGRAM_NAME == __FILE__
  begin
    ninja = nil
    toolchain = nil
    outdir = nil
    project = nil
    config = nil
    msg = 'This script is for generating GUI project.'
    opt_parser = OptionParser.new do |opts|
      # help option - print help and ends
      opts.on('-h', '--help', msg) do
        puts(opts)
        exit(0)
      end
      opts.on('-i', '--input [ninja_file]', String, 'Path for build.ninja') do |value|
        ninja = value
      end
      opts.on('-t', '--toolchain [iar mdk]', String, 'Set toolchain') do |value|
        toolchain = value
      end
      opts.on('-o', '--output_directory [output dir]', String, 'output dir') do |value|
        outdir = value.tr('\\', '/')
      end
      opts.on('-p', '--project [project name]', String, 'project name') do |value|
        project = value.tr('\\', '/')
      end
      opts.on('-c', '--config [debug release]', String, 'build configuration') do |value|
        config = value.tr('\\', '/')
      end
    end
    opt_parser.parse!

    unless SCRIPT_SUPPORTED_TOOLCHAIN.include? toolchain
        puts "Currently supported toolchain: #{SCRIPT_SUPPORTED_TOOLCHAIN}, but script get #{toolchain}, please check --toolchain in west command, or try run with -p always to prevent setting by cache."
        return
    end

    puts "Generate GUI project"
    logger = Logger.new(STDOUT)
    logger.level = CMAKE_LOG_LEVEL_MAP[ENV['log_level']]

    # validate ruby version
    if (Gem::Version.new(RUBY_MINIMUM_REQUIRED) > Gem::Version.new(RUBY_VERSION))
        logger.warn("The system Ruby version #{RUBY_VERSION} is lower than the minimum version #{RUBY_MINIMUM_REQUIRED}.")
    end

    build_data = NinjaParser.new(ninja, project, toolchain, config, outdir, logger).process
    build_option = make_up_build_option(project, toolchain, config, outdir)

    if logger.level == Logger::DEBUG
      dump_file = File.join(ENV['build_dir'], 'build_data.yml')
      logger.debug("Dump ninja parsed data into #{dump_file}")
      YAML.dump_file(dump_file, build_data)
    end

    @generator = SDKGenerator::ProjectGenerator::Generator.new(build_data, logger, generate_options: build_option)
    # For armgcc project, build/mcux_config.h is forbidden because it will be removed by clean script,
    # so we need to copy it to project root dir and then update build data before generating project
    @generator.copy_files(build_data) if ENV['standalone'] == 'true'
    @generator.generate_project_for_tool

    if ENV['standalone'] == 'true'
      # copy project to final build dir
      if ENV['FINAL_BUILD_DIR'] && ENV['TEMP_BUILD_DIR']
        if Dir.exist?(ENV['FINAL_BUILD_DIR'])
          FileUtils.rm_rf(ENV['FINAL_BUILD_DIR'])
        else
          FileUtils.mkdir_p(ENV['FINAL_BUILD_DIR'])
        end
        FileUtils.cp_r(File.join(ENV['TEMP_BUILD_DIR'], toolchain), ENV['FINAL_BUILD_DIR'])
      end
    end
  rescue StandardError => e
    puts e.message
    puts e.backtrace if logger.level == Logger::DEBUG
  end
end

