# frozen_string_literal: true

# ********************************************************************
# Copyright 2018 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require 'logger'
require 'pathname'
require 'yaml'
require_relative 'utils'
require_relative '_assert'

module SDKGenerator
  # ********************************************************************
  # Helper module with constants
  # This module is designed to be used only inside YamlMetaConversions
  # ********************************************************************
  module YamlMetaConversionsConstants
    # mapping of the file extension to file type
    FILE_TYPE_MAP = {
      '.zip' => 'archive',
      '.s' => 'asm_include',
      '.S' => 'asm_include',
      '.asm' => 'asm_include',
      '.inc' => 'asm_include',
      '.bin' => 'binary',
      '.cfx' => 'binary',
      '.pyd' => 'binary',
      '.crt' => 'binary',
      '.board' => 'configuration',
      '.jlinkscript' => 'configuration',
      '.h' => 'c_include',
      '.hpp' => 'cpp_include',
      '.ini' => 'configuration',
      '.inf' => 'configuration',
      '.dni' => 'configuration',
      '.ewd' => 'debug',
      '.launch' => 'debug',
      '.svd' => 'debug',
      '.txt' => 'doc',
      '.rtf' => 'doc',
      '.html' => 'doc',
      '.htm' => 'doc',
      '.readme' => 'doc',
      '.pdf' => 'doc',
      '.Doxyfile' => 'doc',
      '.xls' => 'doc',
      '.css' => 'doc',
      '.md' => 'doc',
      '.scp' => 'driver',
      '.bmp' => 'image',
      '.gif' => 'image',
      '.jpg' => 'image',
      '.png' => 'image',
      '.a' => 'lib',
      '.lib' => 'lib',
      '.ld' => 'linker',
      '.lds' => 'linker',
      '.icf' => 'linker',
      '.scf' => 'linker',
      '.sct' => 'linker',
      '.cproject' => 'project',
      '.project' => 'project',
      '.ewp' => 'project',
      '.uvopt' => 'project',
      '.uvoptx' => 'project',
      '.uvproj' => 'project',
      '.uvprojx' => 'project',
      '.erpc' => 'script',
      '.js' => 'script',
      '.bat' => 'script',
      '.cmake' => 'script',
      '.mk' => 'script',
      '.py' => 'script',
      '.sh' => 'script',
      '.cmd' => 'script',
      '.mem' => 'script',
      '.tcl' => 'script',
      '.c' => 'src',
      '.cpp' => 'src',
      '.ldt' => 'src',
      '.def' => 'src',
      '.xml' => 'xml',
      '.meta' => 'other',
      '.o' => 'lib',
      # empty will be recognized as other
      '' => 'other'
    }.freeze
  end

  # ********************************************************************
  # Contains useful conversion functions to convert YAML to META or back
  # ********************************************************************
  module YamlMetaConversions
    # Translate the tool to manifest format name from yml format name
    # @param [String] tool: The yml format tool name
    # @return [String] The manifest format tool name
    def get_toolchain(tool)
      type_map = {
        'iar' => 'iar',
        'mdk' => 'mdk',
        'armgcc' => 'armgcc',
        'mcux' => 'mcuxpresso',
        'codewarrior' => 'cwmcu'
      }
      type_map[tool]
    end

    # translate yml toolchain strings to meta toolchain
    # @param [String] toolchain: yml toolchain
    # @return [String] the meta format toolchain
    def ymltoolchain_to_metatoolchain(toolchain)
      type_map = {
        'iar' => 'iar',
        'mdk' => 'mdk',
        'armgcc' => 'armgcc',
        'mcux' => 'mcuxpresso',
        'codewarrior' => 'cwmcu'
      }
      type_map[toolchain]
    end

    # Translate manifest core strings to yml core strings
    # @param [String] core: The manifest format core, such as 'Cortex-M0P'
    # @return [String] The yml format core
    def metacore_to_ymlcore(core)
      type_map = {
        'Cortex-M0' => 'cm0',
        'Cortex-M0P' => 'cm0p',
        'Cortex-M4' => 'cm4',
        'Cortex-M4F' => 'cm4f',
        'Cortex-M7' => 'cm7',
        'Cortex-M7F' => 'cm7f',
        'Cortex-M33' => 'cm33',
        'Cortex-M33F' => 'cm33f',
        'Cortex-A7' => 'ca7',
        'Cadence-HiFi4' => 'dsp',
        'Cadence-HiFi1' => 'dsp',
        'Cadence-FusionF1' => 'dsp',
        'DSP56800EX' => 'dsp56800ex',
        'DSP56800EF' => 'dsp56800ef'
      }
      type_map[core]
    end
  end

  # ********************************************************************
  # Contains useful functions and extensions for SDK generator
  # ********************************************************************
  module SDKUtils
    DEFAULT_DES_PATH = Pathname.new(File.dirname(__FILE__)).realpath
                               .parent.parent.parent.parent.parent.parent.to_s + '/pack/'
    ENTRANCE_SCRIPT_PATH = 'bin/generator/sdk_generator/src'
    SW_COMPONENTS_MIR_PATH = 'MIR/marketing_data/1.0/sw_components'
    SUPPORTED_TOOLCHAINS = %w[iar mdk armgcc mcux xtensa xcc riscvllvm codewarrior].freeze
    CMSIS_SUPPORTED_TOOLCHAINS = %w[iar mdk armgcc].freeze
    DEFAULT_TOOLCHAINS = %w[iar mdk armgcc mcux].freeze
    CMSIS_DEFAULT_TOOLCHAINS = %w[iar mdk armgcc].freeze
    MANIFEST_SUPPORTED_TOOLCHAINS = %w[iar mdk armgcc mcux codewarrior].freeze
    SUPPORTED_COMPILERS = %w[gcc iar armclang armcc xcc mwcc56800e].freeze
    # The supported include array
    INCLUDE_ARRAY = %w[as-include cc-include cx-include].freeze
    MANIFEST_SUPPORTED_COMPILERS = %w[gcc iar armclang armcc mwcc56800e].freeze
    # list of core types supported in YAML format
    SUPPORTED_CORES = %w[cm0 cm0p cm4 cm4f cm7 cm7f cm33 cm33f ca7 dsp dsc dsp56800ex dsp56800ef].freeze
    SUPPORTED_OS = %w[windows linux mac].freeze
    # Stage name const
    CHECK_ENVIRONMENT = 'prestage_check_environment'
    PROCESS_ARGUMENT = 'prestage_process_arguments'
    STAGE0_PROCESS = 'stage0'
    STAGE1_PROCESS = 'stage1'
    STAGE2_PROCESS = 'stage2'
    STAGE3_PROCESS = 'stage3'
    STAGE4_PROCESS = 'stage4'
    STAG0_CATEGORY = 'Stage Zero Main'
    STAG1_CATEGORY = 'Stage One Main'
    STAG2_CATEGORY = 'Stage Two Main'
    STAG3_CATEGORY = 'Stage Three Main'
    STAG4_CATEGORY = 'Stage Four Main'
    MOVE_MIR_DATA = 'Move MIR Data'
    # Doxygen new lib directory
    NEW_DOCUMENT_LIB_DIRECTORY = 'docs/doxygen/lib_dox_v1'
    RM_DOXYGEN_CONFIG_PREFIX = 'Doxyfile_lib_PDF_RM_'
    # FPU from chip-model has 3 allowed states:
    #   NO_FPU = No FPU
    #   SP_FPU = Single precision FPU
    #   DP_FPU = Double precision FPU
    # Consult with Petr Prokop (petr.prokop@nxp.com) if you need more information
    SUPPORTED_FPU = %w[SP_FPU DP_FPU NO_FPU].freeze
    MISC_CONTENT = /\w+_content$/
    PROJECT_TYPES = %w[application library].freeze
    PROJECT_RELATED_TYPES = %w[application library project_segment].freeze
    PROJECT_SEGMENT_TYPES = %w[project_segment configuration].freeze
    COMPONENT_TYPES = %w[component component_support].freeze
    SOFTWARE_FUNCTION_COMPONENT_TYPES = %w[component api].freeze
    SOFTWARE_MODULE_TYPES = %w[application library component].freeze
    COMMON_TARGET = %w[debug release].freeze
    MCUX_TARGET = %w[debug release].freeze
    MCUX_TOOLCHAIN_SETTINGS = %w[debug_configuration linker_settings].freeze
    # [Array<String>] list of directories not to be processed: '.' and '..'
    UPPER_LEVEL_FOLDERS = %w[. ..].freeze
    # Key word list
    KEY_LIST = %w[__remove__ __load__ __safe_load__ __remove_load__ __common__ __hierarchy__ __replace__].freeze
    CHECK_MAP = { 'cores' => SUPPORTED_CORES, 'toolchains' => SUPPORTED_TOOLCHAINS,
                  'os' => SUPPORTED_OS, 'fpu' => SUPPORTED_FPU }.freeze
    CHECK_LIST = %w[cores toolchains os fpu].freeze
    COMMON_COMPONENT_NAME_PREFIX = %w[driver utility component middleware docs docs_external].freeze
    RELEASE_ACTIONS = {
      gen_release: true,
      gen_readme: true,
      gen_linkerprocess: true,
      gen_hardware_app_merge: true,
      gen_config_merge: true,
      gen_config_merge_freertos: true,
      gen_config_merge_usb: true,
      gen_movefiles: true,
      gen_common_xml: true,
      gen_hook: true
    }.freeze
    MIR_DATA_PATH = 'MIR/marketing_data/1.0'
    SUPPORTED_COMPONENT_INFO_TYPES = %w[common manifest cmsis_pack container].freeze
    # TODO: Temporary solution, wait until compiler can be specified in release_config
    ARMCLANG_SUPPORTED_BOARD = %w[lpcxpresso55s69].freeze
    MANIFEST_SCHEMA_DIR = 'bin/generator/sdk_generator/src/manifest_generator/manifest_model/schema'
    EXAMPLE_EXCLUDE_COMPONENT_TYPE = %w[project_template].freeze
    SCHEMA_BASE = 'bin/generator/sdk_generator/data/sdk_data_schema'
    COMPONENT_SUPPORT_SCHEMA_FILE_NAME = 'component_support_schema.yml'

    SCHEMA_V3_BASE = 'bin/generator/sdk_generator/data/sdk_data_schema/v3'
    PROJECT_SCHEMA_FILE_NAME = 'project_schema.json'
    COMPONENT_SCHEMA_FILE_NAME = 'component_schema.json'
    SET_SCHEMA_FILE_NAME = 'set_schema.json'
    SCR_SCHEMA_FILE_NAME = 'scr_schema.json'
    PROJECT_SEGMENT_SCHEMA_FILE_NAME = 'project_segment_schema.json'
    LICENSE_SCHEMA_FILE_NAME = 'license_schema.json'
    CONTAINER_SCHEMA_FILE_NAME = 'container_schema.json'

    CONFIGURATION_SCHEMA_FILE_NAME = 'configuration_schema.yml'
    NEED_MOVE_TO_PROJECT_ROOT = %w[linker-file].freeze

    # The sections which should be bypassed when doing data validation.
    BYPASS_SECTIONS = %w[sdk_common_settings kboot_common_settings kinetis_kboot_common_setting
                         imx_kboot_common_settings lpc_kboot_common_settings].freeze

    # The gem name with minimal version which must be installed.
    GEM_MAP = {
      'deep_merge' => '1.2.1',
      'git' => '1.5.0',
      'hashie' => '4.1.0',
      'json-schema' => '2.8.1',
      'nokogiri' => '1.8.2',
      'nokogiri-happymapper' => '0.7.0',
      'rubyzip' => '1.2.1'
    }.freeze

    MIDDLEWARE_UI_CONTROL_BYPASS_LIST = ['middleware.baremetal'].freeze

    DRIVER_SUPPORT_IP_DB = 'bin/generator/records_v2/driver_suppprt_ip.db'
    CHIP_DB = 'devices/chip.db'
    MIR_DB = 'MIR/marketing_data/1.0/sqlite/mir.db'

    V3_SUPPORTED_SECTION_TYPES = %w[application library component set scr license api container project_template configuration manifest_content package_data project_segment setting]

    COMPONENT_SAME_LEVEL_SECTION_FOR_DEPENDENCY_ANALYZE = %w[component scr license api container]

    OPTIONAL_COMPONENT_SET_TYPES = %w[middleware]

    ALL_SW_COMPONENT_SET_TYPES = %w[middleware component]

    MIDDLEWARE_SET_TYPE = 'middleware'

    COMPONENT_SET_TYPE = 'component'

    SOFTWARE_SET_TYPES = %i[middleware component]

    DEVICE_FOLDER = 'devices'

    RESERVED_SET = %w[set.package_data set.license]

    MERGED_DATA_DIR = 'merged_data'

    ARM_SPECIFIC_SETS = %w[set.CMSIS set.CMSIS_DSP_Lib]

    IRREGULAR_MIDDLWARE_NAMES = %w[CMSIS_DSP_Lib]

    # ---------------------------------------------------------------------
    # Get the compilers from the toolchains
    # @param [String] toolchain: the toolchain
    # @return [String] the compiler
    def get_datatable_compilers(toolchain)
      type_map = {
        'iar' => 'iar',
        'mdk' => 'armclang', # default mdk is armclang
        'armgcc' => 'gcc',
        'mcux' => 'gcc',
        'xtensa' => 'xcc',
        'xcc' => 'xcc',
        'armds' => 'armclang',
        'codewarrior' => 'mwcc56800e',
        'riscvllvm' => 'riscvllvm'
      }
      type_map[toolchain]
    end

    # Get the file type based on the file extension
    # @param [String] src: The file name with extension
    # @return [String] The file type
    def get_file_type(src)
      return nil if src.nil?
      return 'other' unless YamlMetaConversionsConstants::FILE_TYPE_MAP.key?(File.get_extension(src))

      YamlMetaConversionsConstants::FILE_TYPE_MAP[File.get_extension(src)]
    end

    # Translate yml toolchain
    # @param [string] toolchain: yml toolchain
    # @return [string] the readme toolchain descrition
    def get_fulltoolchain(toolchain)
      type_map = {
        'iar' => 'IAR embedded Workbench ',
        'mdk' => 'Keil MDK ',
        'armgcc' => 'GCC ARM Embedded ',
        'mcux' => 'MCUXpresso ',
        'xtensa' => 'Xtensa Xplorer ',
        'xcc' => 'Xtensa C Compiler ',
        'armds' => 'Arm Development Studio',
        'codewarrior' => 'CodeWarrior Development Studio'
      }
      type_map[toolchain]
    end

    # Get project class according to toolchain name
    # @param [string] toolchain: toolchain name
    # @param [string] type: project type, applcaition or library
    # @return [string] project class
    def get_toolchain_project_class(toolchain, type)
      type = type == 'application' ? 'App' : 'Lib'
      type_map = {
        'iar' => 'Iar',
        'mdk' => 'Mdk',
        'armgcc' => 'CMake',
        'xtensa' => 'Xtensa',
        'xcc' => 'Xcc',
        'riscvllvm' => 'CMake',
        'codewarrior' => 'CodeWarrior'
      }
      if type_map.key? toolchain
        "#{type_map[toolchain]}::#{type}::IDEProject"
      else
        nil
      end
    end

    # Get the supported toolchains from the project udata
    # @param [Hash] data The project udata
    # @return [Array] Array to contain all supported toolchains
    def get_toolchain_array(data)
      # Add "toolchain" attribute
      new_tool_array = []
      data[:tool_key].each do |each|
        next if data[:ignore_mcux] == 'true' && (each == 'mcux')

        tool = YamlMetaConversions.get_toolchain(each)
        new_tool_array.push(tool)
      end
      new_tool_array
    end

    ### Produce failure log if error occurred for codes not covered by log_unit
    # @param [String] info:   the info to be put on console
    # @param [Error] error:  the error system produces
    # @param [String] dir:   the dir to store the log
    # @param [String] file_name:   the name of the log file
    # @param [String] stage:   the stage that meets failure
    def produce_fail_log(info, error, dir, file_name, stage)
      puts "############################ #{info} ############################"
      fail_log_path = File.join(dir, "sdk_generator_log_#{stage}", "#{file_name}_failure.yml")
      FileUtils.mkdir_p(File.dirname(fail_log_path)) unless File.directory?(File.dirname(fail_log_path))
      fail_log = {}
      # exception info, exception position backtrace
      fail_log.store('run_failed', true)
      fail_log.store('Failed_reason', error.message)
      fail_log.store('code backtrace(for generator developers only)', [])
      error.backtrace.each do |each_line|
        fail_log['code backtrace(for generator developers only)'].push(each_line.to_s)
      end
      File.open(fail_log_path, 'w') { |f| f.puts fail_log.to_yaml }
      puts "Please refer to the sdk_generator_log_#{stage} under #{dir}"
    end

    ### Produce failure log if error occurred for codes covered by log_unit
    # @param [GeneratorLog] log_unit: generator log_unit
    # @param [Error] err: the error system produces
    def log_unit_process_failure_msg(log_unit, err)
      log_unit.collect_data('run_failed' => true)
      log_unit.collect_data('Failed_reason' => err.message)
      log_unit.collect_data('code_backtrace (for generator developers only)' => err.backtrace)
      log_unit.process
    end

    # ---------------------------------------------------------------------
    # Check whether the require array include one require
    # @param [Array] require_array: the require array
    # @param [String] require_string: the require sting, there may be several component splited by space.
    # @return [Boolean] In:true; Not in:false
    def check_requires_include(require_array, require_string)
      require_array&.each do |each_require_line|
        return true if (require_string.split(' ') - each_require_line.split(' ')).empty?
      end
      false
    end

    # ---------------------------------------------------------------------
    # Get a new default value for complex dependency
    # @param [Array] require_array
    # @return [String] The new default element
    def get_new_default(require_array)
      default_candidate_array = require_array[0].strip.split(' ')
      return default_candidate_array[0] if default_candidate_array.length == 1

      new_default = ''
      default_candidate_array.each do |each_candidate_require|
        met = false
        require_array[1..-1].each do |each_require_line|
          each_require_line.strip.split(' ').each do |each_require_element|
            if each_require_element == each_candidate_require
              met = true
              break
            end
          end
          break if met
        end
        new_default = each_candidate_require unless met
      end
      new_default
    end

    # --------------------------------------------------------
    # Check whether some optional components specified in release_config yml are not supported by any device
    # @param [String] log_path
    # @return [nil]
    def check_optional_components(log_path, device_cont)
      # if the number of log file if smaller than the total device count
      # then not all the devices heve the log of do not support some optional componets
      return unless File.directory? log_path
      return if (Dir.new(log_path).entries.size - 2) < device_cont

      non_supported_uis_array = []
      Dir.foreach(log_path) do |file_name|
        next unless file_name.include?('log')

        dependency_log = YAML.load_file(File.join(log_path, file_name)).dig_with_default({}, 'Stage2 Process',
                                                                                         'DependenceAnalyze', 'Problems')
        # return if no error/warn is logged in dependency analyze
        return if dependency_log.empty?

        current_non_supported_uis = []
        dependency_log.each do |each_log, log_content|
          unless log_content.dig_with_default([],
                                              'Warning').include?("This optional components is not supported by #{file_name.split('_')[0]}")
            next
          end

          current_non_supported_uis.push_uniq(each_log)
        end
        non_supported_uis_array.push current_non_supported_uis
      end
      non_supported_uis = non_supported_uis_array[0]
      non_supported_uis_array.each { |x| non_supported_uis &= x }
      return if non_supported_uis.empty?

      SDKUtils.raise_abort_error('These components are not supported by any device: ' + non_supported_uis.join(','))
    end

    ### Check the thread(s)/process(es) status for stage 1 and stage 2
    # @param [Bool] production:   production code
    # @param [Integer] failure_cnt:   the number of the processes/thread(s) run failed
    # @param [String] stage:   the stage that meets failure
    def check_thread_status(production, failure_cnt, stage)
      # If production is true then program aborts when only one thread failed
      return unless failure_cnt.positive?

      if production
        msg = "One or more thread(s) in #{stage} run failed. Since you set the 'production: true', program aborted."
        SDKUtils.raise_abort_error(msg)
      else
        SDKUtils.raise_no_abort_error("There are some cases run failed in #{stage}.")
      end
    end

    ### Check the thread(s)/process(es) status for stage 1 and stage 2
    # @param [String] path: the path of the file that should be printed; nil if no print
    # @param [Integer] code: the failure code, used as an exit code
    def dump_file_and_exit(path, code)
      File.open(path, 'r').each { |each_line| puts each_line } if path
      exit(code)
    end

    # --------------------------------------------------------
    # Dump debug data after data merge and path clean
    # @param [Hash] option: Generator options
    # @param [Hash] file_structure_hash: The to be dumped file_name => content
    # @return [Nil]
    def dump_debug_file(option, file_structure_hash)
      suffix = if option[:core_id]
                 "_#{option[:core_id]}"
               else
                 ''
               end
      log_data_folder_path = File.join(option[:msdk_path], ENTRANCE_SCRIPT_PATH, 'debug_data')
      FileUtils.mkdir_p(log_data_folder_path) unless File.directory?(log_data_folder_path)
      file_structure_hash.each do |each_name, each_structure|
        log_data_file_path = File.join(log_data_folder_path, "#{option[:board]}#{suffix}_#{each_name}")
        YAML.dump_file(log_data_file_path, each_structure)
        puts "Creating '#{log_data_file_path}'"
      end
    end

    # --------------------------------------------------------
    # Check whether section content has the attribute or not
    # @param [Hash] section_content: The section content to be checked
    # @param [Hash] attribute: the attribute
    # @return [Bool]
    def component_info_has_attribute?(section_content, attribute)
      return false unless section_content.key?('component_info')

      SUPPORTED_COMPONENT_INFO_TYPES.each do |key_type|
        next unless section_content['component_info'].key? key_type
        if section_content['component_info'][key_type].key?(attribute) && !section_content['component_info'][key_type][attribute].nil?
          return true
        end
      end
      false
    end

    # --------------------------------------------------------
    # Check whether the attribute of section content component_info is true
    # @param [Hash] section_content: The section content to be checked
    # @param [Hash] attribute: the attribute
    # @return [Bool]
    def component_info_attribute_true?(section_content, attribute)
      return false unless section_content.key?('component_info')

      SUPPORTED_COMPONENT_INFO_TYPES.each do |key_type|
        next unless section_content['component_info'].key? key_type

        flag = section_content['component_info'][key_type].dig attribute
        return true if ['true', true, 'True'].include? flag
      end
      false
    end

    # ---------------------------------------------------------------------
    # Get the attribute value of section content component_info for certain output type(SUPPORTED_COMPONENT_INFO_TYPES)
    # @param [Hash] section_content: the section_content
    # @param [String] output_type: the output type, defined in SUPPORTED_COMPONENT_INFO_TYPES
    # @param [String] attribute: the attribute
    # @return [String] the attribute value
    def get_component_info_attribute(section_content, output_type = 'common', attribute)
      return '' unless section_content.safe_key? 'component_info'
      if section_content['component_info'].safe_key?(output_type) && section_content['component_info'][output_type].safe_key?(attribute)
        return section_content['component_info'].dig_with_default('', output_type, attribute).strip
      end

      section_content['component_info'].dig_with_default('', 'common', attribute).strip
    end

    # ---------------------------------------------------------------------
    # Get the attribute value of section content component_info automatically
    # @param [Hash] section_content: the section_content
    # @param [String] output_type: the output type, defined in SUPPORTED_COMPONENT_INFO_TYPES
    # @param [String] attribute: the attribute
    # @return [String] the attribute value
    def get_component_info_attribute_auto(section_content, attribute)
      return '' unless section_content.safe_key? 'component_info'

      SUPPORTED_COMPONENT_INFO_TYPES.each do |key_type|
        if section_content['component_info'].safe_key?(key_type) && section_content['component_info'][key_type].safe_key?(attribute)
          return section_content['component_info'][key_type][attribute].strip
        end
      end
      ''
    end

    # ---------------------------------------------------------------------
    # Set the attribute value of section content component_info for certain output type(SUPPORTED_COMPONENT_INFO_TYPES)
    # @param [Hash] section_content: the section_content
    # @param [String] output_type: the output type, defined in SUPPORTED_COMPONENT_INFO_TYPES
    # @param [String] attribute: the attribute
    # @param [String] value: the value
    # @return [nil]
    def set_component_info_attribute(section_content, output_type = 'common', attribute, value)
      section_content['component_info'][output_type] = {} unless section_content['component_info'].safe_key? output_type
      section_content['component_info'][output_type][attribute] = value
    end

    # ---------------------------------------------------------------------
    # Set the attribute value of section content component_info automatically. The order is:
    # common
    # manifest
    # cmsis_pack
    # container
    # @param [Hash] section_content: the section_content
    # @param [String] attribute: the attribute
    # @param [String] value: the value
    # @return [nil]
    def set_component_info_attribute_auto(section_content, attribute, value)
      SUPPORTED_COMPONENT_INFO_TYPES.each do |key_type|
        if section_content['component_info'].key? key_type
          section_content['component_info'][key_type][attribute] = value
          return
        end
      end
    end

    # --------------------------------------------------------
    # Check whether the node requires subnode
    # @param [Hash] struct: The @non_project_data
    # @param [String] node: Node name
    # @param [String] subnode: Node name
    # @return [Bool]
    def requires_component?(struct, node, subnode)
      unless struct[node].nil? || struct[node]['__requires__'].nil?
        struct[node]['__requires__'].each do |requireson_string_array|
          requireson_string_array.split(' ').each do |requireson|
            return true if requireson == subnode
          end
        end
      end
      false
    end

    def deep_copy(object)
      Marshal.load(Marshal.dump(object))
    end

    # ---------------------------------------------------------------------
    # Get the git repo HEAD commit SHA
    # @param [String] git repo path
    # @return [String] git repo head sha
    def get_git_commit(repo_path)
      require 'git'
      Git.open(repo_path).object('HEAD').sha
    rescue LoadError
      Logger.new(STDOUT).warn "You have not installed the 'git' gem, please run 'gem install git'."
      'HEAD'
    rescue Exception
      Logger.new(STDOUT).warn "Failed to get git commit SHA, using 'HEAD'."
      'HEAD'
    end

    # --------------------------------------------------------
    # Get board kit name
    # @param [String] kit: kit name
    def get_board_kit_name(_msdk_path, board_id, kit_name)
      # First, try to get the data from mir.
      mir_board_yml = File.join(@generator_options[:msdk_path], MIR_DATA_PATH, 'boards', "#{board_id}.yml")
      mir_board_content = YAML.load_file mir_board_yml
      kits = mir_board_content.fetch_raise_msg("Cannot find 'kits' data in #{mir_board_yml}", 'kits')
      kits&.each do |each_kit|
        each_kit_yml = File.join(@generator_options[:msdk_path], MIR_DATA_PATH, 'kits', "#{each_kit['id']}.yml")
        Utils.raise_fatal_error("#{each_kit_yml} does not exist.") unless File.exist? each_kit_yml
        each_kit_yml_content = YAML.load_file each_kit_yml
        if each_kit_yml_content.fetch_raise_msg("Cannot find 'name' in #{each_kit_yml}", 'name') == kit_name
          return each_kit['id']
        end
      end
      Utils.raise_fatal_error("Cannot find kit id for kit #{kit_name} in MIR.")
    end

    # Get file filter condition from configuration => document of yml setting
    # @param [Hash] project_content: project content of yml application/library section
    # @return [Hash] Filter condition hash
    def get_filter_condition(project_content)
      document = project_content.dig('contents', 'document')
      { core: document['core'],
        toolchains: document['toolchains'],
        compilers: document['compilers'],
        fpu: document['fpu'],
        core_id: document['core_id'],
        device_id: document['device_id'] }
    end

    # Determine if filter condition is met
    # @param [Hash] file: files section
    # @return [boolean]  true if filter condition is met, false otherwise
    def meet_filter_condition(file, conditions)
      if file.safe_key?('toolchains') && conditions.safe_key?(:toolchains) && (file['toolchains'].split(/\s+/) - conditions[:toolchains] == file['toolchains'].split(/\s+/))
        return false
      end

      if file.safe_key?('compilers') && conditions.safe_key?(:compilers) && (file['compilers'].split(/\s+/) - conditions[:compilers] == file['compilers'].split(/\s+/))
        return false
      end

      if file.safe_key?('cores') && conditions.safe_key?(:core) && !file['cores'].to_s.include?(conditions[:core].strip)
        return false
      end

      if file.safe_key?('fpu') && conditions.safe_key?(:fpu) && !file['fpu'].to_s.include?(conditions[:fpu].strip)
        return false
      end

      if file.safe_key?('core_ids') && conditions.safe_key?(:core_id)
        if conditions.safe_key?(:device_id)
          return false unless file['core_ids'].to_s.include?(conditions[:core_id].strip)
        else
          # For backward compatible.
          return false unless file['core_ids'].to_s.include?(conditions[:core_id].split('_')[-2].strip)
        end
      end
      true
    end

    # Translate yml toolchain
    # @param [string] toolchain: yml toolchain
    # @return [string] the readme toolchain descrition
    def get_open_CMSIS_compiler_from_V3_yml_toolchain(toolchain)
      type_map = {
        'iar' => 'IAR',
        'mdk' => 'AC6',
        'armgcc' => 'GCC',
        'mcux' => 'GCC'
      }
      type_map[toolchain]
    end

    def get_title_from_set_name(set_name)
      tmp = set_name.split('.')
      case tmp.length
      when 1
        tmp[0]
      when 2
        tmp[1]
      else
        tmp[2..-1].join('_')
      end
    end

    def check_set_name(set_name, build_option)
      if set_name.start_with? 'set.board'
        # set_name may be set.board.frdmk64f, set.board.frdmk64f.sdmmc
        board_id = set_name.split('.')[2]
        return false unless build_option[:set][:board].has_key? board_id
      elsif set_name.start_with? 'set.device'
        device_id = set_name.split('.').last
        return false unless build_option[:set][:device].has_key? device_id
      elsif set_name.start_with? 'set.kit'
        kit_id = set_name.split('.')[2]
        return false unless build_option[:set][:kit].has_key? kit_id
      elsif RESERVED_SET.include? set_name
      elsif build_option[:all_related_sw_sets]
        return false unless build_option[:all_related_sw_sets].include? set_name
      end
      true
    end

    def cmsis_target_set(option)
      option.dig_with_default(nil, :build_config, :cmsis_target_set)
    end

    def get_sw_name_from_set(set_name)
      if set_name.start_with?('set.board') || set_name.start_with?('set.device') || set_name.start_with?('set.kit')
        if set_name.split('.').length == 3
          return  ''
        else
          return set_name.split('.')[3..-1].join('.')
        end
      elsif set_name.start_with?('set.middleware') || set_name.start_with?('set.component')
        return set_name.split('.')[2..-1].join('.')
      else
        return ''
      end
    end

    def belong_to_board?(section_name, section_content)
      belong_to = get_belong_to_for_product(section_name, section_content, build_product)
      return true if belong_to.start_with?('set.board')

      false
    end

    def board_set?
      @set_type.to_s == 'board'
    end

    def kit_set?
      @set_type.to_s == 'kit'
    end

    def device_set?
      @set_type.to_s == 'device'
    end
  end
end

# ###########################################################
# extend standard Hash class for generator purpose
class Hash
  # Check whether is this section type
  # @param [String] type: the section type to be checked
  def section_type?(type)
    key?('section-type') && self['section-type'] == type
  end

  def section_type
    return self['section-type'] if key?('section-type')

    nil
  end

  def only_key?(key)
    return false if nil?
    return true if key?(key) && keys.length == 1

    false
  end
end

module Psych
  # Workaround for JRuby's SnakeYAML lib's 3MB limitation, see https://hub.spigotmc.org/jira/browse/SPIGOT-7161
  def self.parse_stream yaml, filename: nil, &block
    if block_given?
      parser = Psych::Parser.new(Handlers::DocumentStream.new(&block))
      parser.code_point_limit = 50_000_000
      parser.parse yaml, filename
    else
      parser = self.parser
      parser.parse yaml, filename
      parser.code_point_limit = 50_000_000
      parser.handler.root
    end
  end if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
end

module YAML
  # Dump hash object to yaml file with ruby default internal encoding UTF-8 since ruby 2.0
  # NOTE THis will ignore the Encoding.default_external
  def self.dump_file(filename, content, options = {})
    File.open(filename, 'w:utf-8') do |f|
      f.write(YAML.dump(content, options))
    end
  end
end
# ********************************************************************
# EOF
# ********************************************************************
