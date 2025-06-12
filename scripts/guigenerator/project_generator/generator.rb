# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require_relative 'core/_array'
require_relative 'core/_generator'
require_relative 'core/_quick_selector'
require_relative 'core/_path_modifier'
require_relative 'core/ide_project/iar/lib/project'
require_relative 'core/ide_project/iar/app/project'
require_relative 'core/ide_project/mdk/lib/project'
require_relative 'core/ide_project/mdk/app/project'
require_relative 'core/ide_project/cmake/app/modernProject'
require_relative 'core/ide_project/cmake/lib/modernProject'
require_relative 'core/ide_project/cmake/cmake_module/cmake_modules_generator'
require_relative 'core/ide_project/mcux/app/project'
require_relative 'core/ide_project/mcux/lib/project'
require_relative 'core/ide_project/xtensa/app/project'
require_relative 'core/ide_project/xcc/app/project'
require_relative 'core/ide_project/codewarrior/app/project'
require_relative 'core/ide_project/codewarrior/lib/project'
require_relative 'modify_template'
require_relative 'data_translator'
require_relative '../utils/utils'
require_relative '../utils/factory_builder_logger'
require_relative '../utils/exceptions'
require 'yaml'
require 'fileutils'
require 'logger'

module SDKGenerator
  module ProjectGenerator
    # ********************************************************************
    # The entrance for core codes
    # ********************************************************************
    class Generator < Core::Generator
      include SDKUtils
      include Utils
      include YamlMetaConversions
      include CMSISHelper
      attr_accessor :release, :json_array, :generator_options, :generator_logger
      DESCRIPTION = 'CMSIS Project Generation'
      # --------------------------------------------------------
      # Initialize the class
      # @param [Hash] generate_options: the options of the generator
      # @return [nil]
      def initialize(data, logger, generate_options: nil, **kwargs)
        super(**kwargs)
        @data = data
        @generator_options        = generate_options
        @output_rootdir           = generate_options[:output_dir]
        @generator_options[:msdk_path] = generate_options[:output_dir]
        @json_array               = []
        @generator_logger = FactoryBuilderLogger.new("ProjectGenerator@#{@generator_options[:title]}", DESCRIPTION, logger: logger)
        @hardware_info = {}
        # @chip_db = ChipDB.new(generate_options[:database][:chip])
      end

      # --------------------------------------------------------
      # Generate project for each tool
      # @param [String] project_tag: the project name consist of the board name and the example name
      # @param [String] project_name: the project name that records under the document
      # @param [String] tool_key: tool name
      # @param [Hash] project_data: project unify data
      # @return [nil]
      def generate_project_for_tool(toolchains=nil)
        translator = Translator.new(@data, @generator_options, @generator_logger)
        current_project = ''
        @data[@generator_options[:entry_set]].each do |each_key, each_data|
          next unless @generator_options[:project_list].include? each_key
          next unless PROJECT_TYPES.include? each_data['section-type']
          current_project = each_key

          generated_files = {}
          unify_data = translator.translate(each_key)
          project_section_name, project_data = unify_data.first
          Core.assert(!project_data.nil?) do
            "no '#{project_section_name}', please check project name.\n"
          end
          if toolchains
            tool_name_array = toolchains & SUPPORTED_TOOLCHAINS
          else
            tool_name_array = project_data['supported_toolchains']
          end
          binary_packed = {}

          tool_name_array.each do |tool_key|
            next unless project_data[tool_key]
            next unless @generator_options[:toolchains].include? tool_key
            generated_files[tool_key] ||= []
            current_project = "#{current_project}:#{tool_key}"
            project_info = get_project_info(project_section_name, project_data, tool_key)

            binary_packed[tool_key] = project_info[:binary_packed] if project_info.safe_key?(:binary_packed)

            # Example.xml for mcuxpresso is generated in example xml generator
            project_instance = project_factory(project_section_name, tool_key, project_info)
            next unless project_instance
            # Generate application and lib project
            generate_project(project_section_name, tool_key, project_instance, project_data, project_info, generated_files)
          end
          # GC.start
        end
      rescue NoMethodError => e
        # Support up to 200 characters error message to prevent too much call stack info
        @generator_logger.error(current_project, "Method is not implemented in generator, please contact SDK Generator team to fix the issue. Details: " + e.message.to_s[0,200])
        puts e.backtrace
      rescue StandardError => e
        if @generator_options[:production] == true
          @generator_logger.fatal(current_project, e.message)
        else
          @generator_logger.error(current_project, e.message)
        end
        # only show backtrace when debug
        @generator_logger.error(current_project, e.backtrace.to_s) if @generator_logger.logger.level <= Logger::INFO
      ensure
        return [@generator_logger.product_builder_log, @json_array]
      end

      def copy_files(data)
        toolchain = @generator_options[:toolchains][0]
        data.each do |set_name, set_data|
          set_data.each do |section_name, section_data|
            section_data['contents']['modules']&.each do |name, content|
              content['files'].each_with_index do |file, index|
                if File.exist?(File.join(@generator_options[:input_dir], file['source']))
                  src_path = File.join(@generator_options[:input_dir], file['source'])
                  relative_path = Pathname.new(src_path).relative_path_from(Pathname.new(@generator_options[:output_dir])).to_s
                  if relative_path.start_with?('..')
                    dest_path = File.join(@generator_options[:output_dir], toolchain, file['package_path'] || file['repo_path'], File.basename(file['source']))
                    FileUtils.cp_f(src_path, dest_path) unless File.exist?(dest_path)
                  else
                    # if the file is in build dir, copy it to build dir/toolchain folder
                    FileUtils.cp_f(src_path, File.join(@generator_options[:output_dir],toolchain, relative_path))
                    content['files'][index] = {
                      'source' => relative_path,
                      'package_path' => File.dirname(relative_path),
                      'project_path' => File.dirname(relative_path)
                    }
                  end
                end
              end
              %w[cc-include cx-include as-include].each do |path_type|
                content[path_type]&.each_with_index do |item, index|
                  Dir.glob("#{File.join(@generator_options[:input_dir], item['path'])}/*.{h,hpp}").each do |file|
                    relative_path = Pathname.new(file).relative_path_from(Pathname.new(@generator_options[:output_dir])).to_s
                    if relative_path.start_with?('..')
                      dest_path = File.join(@generator_options[:output_dir],toolchain, item['package_path'] || item['path'], File.basename(file))
                      FileUtils.cp_f(file, dest_path) unless File.exist?(dest_path)
                    else
                      # if the file is in build dir, copy it to build dir/toolchain folder
                      FileUtils.cp_f(file, File.join(@generator_options[:output_dir],toolchain, relative_path))
                      content[path_type][index] = {
                        'path' => File.dirname(relative_path),
                        'package_path' => File.dirname(relative_path),
                        'project_path' => File.dirname(relative_path)
                      }
                    end
                  end
                end
              end
            end
          end
        end
      end

      def iar_project_with_rte(project_info)
        rte_folder = File.join(@generator_options[:output_dir], project_info[:outdir], 'RTE')
        return true if File.exist?(rte_folder)
        return false
      end

      def get_project_info(section_name, project_data, tool_key)
        project_info = {}
        project_info[:section_name] = section_name
        project_info[:board]                     = project_data[tool_key]['document']['board']
        project_info[:board_kit]                 = project_data[tool_key]['document']['board_kit'] || project_info[:board]
        project_info[:board_kit_component]       = project_data[tool_key]['document']['board_kit_component']
        project_info[:pcategory]                = project_data[tool_key]['document']['category']
        project_info[:platform_devices_soc_name] = project_data[tool_key]['document']['platform_devices_soc_name']
        project_info[:posjtag]                   = project_data[tool_key]['debugger-config']['osjtag'] if project_data[tool_key]['debugger-config']&.key?('osjtag')
        project_info[:language] = 'cpp' if @generator_options[:gen_cpp] || project_data[tool_key]['project_language'] == 'cpp'
        project_info[:type] = project_data[tool_key]['type']
        project_info[:readme] = project_data['readme']
        project_info[:board_mounted_device_id]   = ENV['device_id']
        project_info[:corename]                = project_data[tool_key]['document']['core']
        project_info[:fpu]                     = project_data[tool_key]['document']['fpu']
        project_info[:dsp]                  = project_data[tool_key]['document']['dsp']
        project_info[:trustzone]           = get_trustzone(project_data[tool_key]['document']['trustzone'])
        project_info[:device_id] = device_id              = project_data[tool_key]['document']['device_id'] || project_info[:board_mounted_device_id]
        project_info[:core_id] = core_id                = project_data[tool_key]['document']['core_id']

        project_info[:compilers]               = project_data[tool_key]['document']['compilers'] || SUPPORTED_COMPILERS
        project_info[:pname] = pname          = project_data[tool_key]['document']['name']
        project_info[:project_tag]           = project_data['project_tag']
        project_info[:internal]                = project_data[tool_key].key?('internal') && project_data[tool_key]['internal'].to_s == 'true' ? true : false
        project_info[:ignore]                  = project_data['supported_toolchains'].include?(tool_key) ? false : true
        project_info[:outdir]                  = project_data[tool_key]['outdir']
        project_info[:all_targets]             = project_data[tool_key]['targets'].keys
        project_info[:shared_workspace]        = project_data[tool_key]['shared-workspace']
        project_info[:sharing_workspace]       = project_data[tool_key]['sharing-workspace']
        project_info[:linked_project]  = project_data[tool_key]['document']['linked_project']
        project_info[:cmake_variables]         =  project_data[tool_key]['cmake_variables']
        project_info[:cmake_command]         =  project_data[tool_key]['cmake_command']
        project_info[:project_file_name]       = case tool_key
                                                 when 'iar'
                                                   "#{pname}.ewp"
                                                 when 'mdk'
                                                   "#{pname}.uvprojx"
                                                 when 'armds'
                                                   '.project'
                                                 when 'armgcc'
                                                   'CMakeLists.txt'
                                                 when 'xcc'
                                                   'CMakeLists.txt'
                                                 when 'mcux'
                                                   "#{pname}.xml"
                                                 when 'xtensa', 'codewarrior'
                                                   '.cproject'
                                                 end
        project_info[:meta_component]          = project_data[tool_key]['meta-component']
        project_info[:cmake_module_name]          = project_data[tool_key]['cmake_module_name']
        project_info[:project_language]        = project_data[tool_key]['project_language']
        project_info[:project_required_or_comp] = project_data[tool_key]['project_required_or_comp']
        project_info[:component_info] = project_data[tool_key]['component_info']
        project_info[:component]          = project_info[:component_info].keys
        project_info[:templates] = project_data[tool_key]['templates']
        project_info[:binary_packed] = project_data[tool_key]['binary_packed']
        project_info[:ui_control_requires] = project_data['ui_control_requires']
        project_info[:replaced_component_config_file] = {}
        project_info[:component_template_file] = {}
        project_info[:sdk_data_version] = @generator_options[:sdk_data_version]
        project_info[:toolchain_version] = @generator_options[:toolchains_version].dig_with_default(nil, tool_key)
        project_info
      end

      def parse_replace_config(content)
        return [] if content.nil?
        config_result = []
        content.split(/\s+/)&.each do |item|
          result = item&.match(/(\S+)@(\S+)/)
          if result
            config_result.push [result[1], result[2]]
          else
            @generator_logger.error("#{item} does not match the format: component@file.")
          end
        end
        config_result
      end

      private

      def get_hardware_info_from_db(device_id, type)
        return nil if device_id == 'TBD'

        if @hardware_info.key? device_id
          @hardware_info[device_id][type] || nil
        else
          @hardware_info[device_id] = {}
          @hardware_info[device_id]['core_ids'] = ENV['core_id']
          @hardware_info[device_id]['core'] = ENV['core']
          @hardware_info[device_id]['fpu'] = ENV['fpu']
          @hardware_info[device_id]['dsp'] = ENV['dsp'] == 'true' ? 'DSP' : 'NO_DSP'
          # @hardware_info[device_id]['core_ids'] = @chip_db.device_core.where(id: device_id).map(:core_id)
          # @hardware_info[device_id]['core'] = @chip_db.device_core.where(id: device_id).get(:core_type)
          # @hardware_info[device_id]['fpu'] = @chip_db.device_core.where(id: device_id).get(:fpu)
          # @hardware_info[device_id]['dsp'] = @chip_db.device_core.where(id: device_id).get(:dsp) == 'true' ? 'DSP' : 'NO_DSP'
          @hardware_info[device_id][type]
        end
      end

      def get_trustzone(attr)
        case attr
        when 'secure'
          return 'TZ'
        when 'nonsecure'
          return 'NO_TZ'
        else
          return nil
        end
      end

      # --------------------------------------------------------
      # Generate project
      # @param [String] project_tag: the project name consist of the board name and the example name
      # @param [String] project_name: the project name under document
      # @param [String] tool_key: tool name
      # @param [Hash] project_data: project unify data
      # @return [nil]
      def generate_project(project_tag, tool_key, project_instance, project_data, project_info, generated_files)
        project_name =  project_info[:pname]

        # Get all targets for cmake
        # Get targets for source do not have targets tag.
        project_instance.targets(project_info[:all_targets]) if %w[armgcc xcc].include? tool_key
        # Clear project first, armgcc need to get all targets then clear!
        project_instance.clear!
        # init output dir for each target
        project_data[tool_key]['targets']&.each { |target, content| project_instance.init_output_dir(target) } if project_instance.methods.include?(:init_output_dir)
        # Add sources
        project_data[tool_key]['source']&.each do |source|
          # filter file at first
          next unless filter_source(source, project_info, tool_key, project_data)
          # Clear the source path
          source['source'].tr!('\\', '/')
          if ([:release_action_process, :file_copy] - @generator_options[:generators].keys).empty?
            source['source'] = File.join(source['package_path'], File.basename(source['source']))
          end
          # should identify custom config file in cmakelists.txt
          if tool_key == 'armgcc' && source.safe_key?('replace_config') && source['config']
            config_res = parse_replace_config(source['replace_config'])
            unless config_res.empty?
              config_res.each do |config_item|
                comp_name = config_item[0]
                project_instance.set_config_file_property(source['source'], get_cmake_module_name(comp_name, project_info), rootdir: 'default_path') if !comp_name.nil? && project_instance.methods.include?(:set_config_file_property)
                add_source_file(project_instance, source, tool_key, project_info)
              end
            end
          end
          # handle files with specific attributes
          if source.safe_key?('attribute')
            add_files_by_attr(project_instance, source, tool_key, project_info)
          else
            add_source_file(project_instance, source, tool_key, project_info)
          end
          # set source level configuration
          add_source_configuration(project_instance, source, tool_key)
        end

        # Add project settings
        project_data[tool_key]['targets']&.each do |target, content|
          add_project_settings(project_instance, target, content, tool_key, project_info, project_data)
        end
        # armgcc specific settings
        add_armgcc_misc_settings(project_instance, project_info) if tool_key == 'armgcc'

        # armds launcher need core info
        project_instance.add_core_info(corename, core_device_id) if tool_key == 'armds'

        # set default target
        project_instance.set_default_target if project_instance.methods.include?(:set_default_target)
        # save project
        save_project_definition_files(project_instance, tool_key, project_info, project_tag, project_name, generated_files)
      end

      # --------------------------------------------------------
      # Generate project
      # @param [String] project_tag: the project name consist of the board name and the example name
      # @param [String] project_name: the project name under the document hash
      # @param [String] tool_key: the tool name
      # @return [nil]
      def project_factory(project_tag, tool_key, project_info)
        manifest_schema_dir = @generator_options[:manifest_schema_dir] || File.join(@output_rootdir, MANIFEST_SCHEMA_DIR)

        specific_compiler = if tool_key == 'mdk' && project_info[:compilers].include?('armcc')
                              'armcc'
                            else
                              get_datatable_compilers(tool_key)
                            end
        # Add project path to relpath table
        unless project_info[:templates]
          @generator_logger.error("No project-templates found for #{project_tag} #{tool_key} project， please set project-templates in yml")
          return
        end
        project_templates = project_info[:templates].comprehend do |template|
          File.to_slashpath(File.join(@generator_options[:input_dir], template.strip.to_s))
        end
        project_templates.each do |tmp|
          unless File.exist? tmp
            @generator_logger.error("For #{project_tag} #{tool_key} project, template file #{tmp} does not exist, please check whether template file exist or there is typo in project-templates of yml record.")
            return
          end
        end
        # check mdk .uvoptx file
        if tool_key == 'mdk' && !project_templates.to_s.include?('.uvoptx') && project_info[:type] == 'application'
          msg = "No .uvoptx template file provided for #{project_info[:pname]} mdk project."
          if @generator_options[:production]
            @generator_logger.error(msg)
          else
            @generator_logger.warn(msg)
          end
        end

        # Modify template
        if %w[iar mdk codewarrior].include? tool_key
          compiler_template = XMLTemplate.new(project_templates, project_info[:all_targets], project_info[:section_name])
          project_templates = compiler_template.modify_template(tool_key)
        end
        # This is a workaround for armgcc for mcux tool
        params = {
          name: project_info[:pname],
          project_name: project_info[:pname],
          category: project_info[:pcategory],
          platform_devices_soc_name: project_info[:platform_devices_soc_name],
          board_name: project_info[:board],
          board_kit_name: project_info[:board_kit],
          board_kit_component: project_info[:board_kit_component],
          output_dir: File.to_slashpath(project_info[:outdir]),
          output_rootdir: @output_rootdir,
          input_dir: @generator_options[:input_dir],
          templates: project_templates,
          logger: @generator_logger.logger,
          modifier: PathModifier.new(@generator_options[:msdk_path]),
          tool_name: tool_key,
          osjtag: project_info[:posjtag],
          # Enable flag analysis/recognition. set "-l 0" to see debug output
          analyze_flags: true,
          targets: project_info[:all_targets],
          manifest_version: @generator_options[:manifest_version],
          manifest_schema_dir: manifest_schema_dir,
          compiler: specific_compiler,
          type: project_info[:language],
          toolchain_version: project_info[:toolchain_version]
        }

        if project_class_name = get_toolchain_project_class(tool_key, project_info[:type])
          instance = instance_with_version(project_class_name, project_info[:toolchain_version], params)
        else
          msg = "#{tool_key} #{project_info[:type]} project has not been supported."
          internal = project_info[:internal]
          if internal && (%w[true True].include? internal.to_s)
            @generator_logger.warn(project_tag, msg)
          else
            @generator_logger.error(project_tag, msg)
            return nil
          end
        end
        GC.start
        instance
      end

      # --------------------------------------------------------
      # Validate include tag
      # @param [Hash] include: include content
      # @param [String] tool_key: the tool name
      # @param [String] core_name: the core name
      # @param [Array] compilers: the compliers array
      # @return [Boolen] True|false: true for include all the tool, core, compiler and false for one of the them not include
      def validate_include_path(include, tool_key, core_name, compilers, include_data, project_info={})
        # For source project, do not add include path of replaced_component_config_file
        if include.safe_key?('target_file') && include.safe_key?('component_name') && !@generator_options[:gen_cmsis_project]
          if project_info[:replaced_component_config_file].safe_key?(include['component_name'])
            return false unless (project_info[:replaced_component_config_file][include['component_name']] & include['target_file']).empty?
          end
          if project_info[:component_template_file].safe_key?(include['component_name'])
            return false unless (project_info[:component_template_file][include['component_name']] & include['target_file']).empty?
          end
        end

        include_tool = true
        include_core = true
        include_compiler = true
        # check the "toolchains" tag
        include_tool = false if include.safe_key?('toolchains') && !include['toolchains'].to_s.include?(tool_key)
        # check the "cores" tag
        include_core = false if include.safe_key?('cores') && !include['cores'].to_s.include?(core_name.to_s.strip)
        # check the "compilers" tag
        if include.safe_key? 'compilers'
          compiler_array = include['compilers'].split(' ')
          include_compiler = false if compilers == compilers - compiler_array
        end
        include_tool && include_core && include_compiler
      end

      # --------------------------------------------------------
      # Add libraries for linker
      # @param [Hash] project_instance: project instance for specific toolchain
      # @param [Array] targets: project build target
      # @param [Hash] source: source file path
      # @param [String] tool_key: project toolchain
      # @param [String] outdir: output directory for toolchain project definition file
      def add_libraries(project_instance, target, source, tool_key, project_info)
        if tool_key == 'xcc'
          project_instance.add_link_library(target.downcase, source['source']) if project_instance.methods.include?(:add_link_library)
        elsif tool_key == 'codewarrior'
          # for code warrior, extra libraries are added into addl-libraries to differ with system libraries which are added in ld-flags
          project_instance.add_addl_lib(target.downcase, source['source'], rootdir: 'default_path') if project_instance.methods.include?(:add_addl_lib)
        elsif tool_key == 'armgcc'
          project_instance.add_link_library(target.downcase, source['source'], linked_project_path: linked_project_path(project_info, tool_key)) if project_instance.methods.include?(:add_link_library)
        else
          project_instance.add_library(target.downcase, source['source'], rootdir: 'default_path') if project_instance.methods.include?(:add_library)
          project_instance.add_cpp_library(target.downcase, source['source'], rootdir: 'default_path') if project_instance.methods.include?(:add_cpp_library)
        end
      end

      def linked_project_path(project_info, tool_key)
        if project_info.safe_key? :linked_project
          linked_project = project_info[:linked_project].split(' ')
          @data[@generator_options[:entry_set]].each do |name, content|
            if linked_project.include? content.dig_with_default('', 'contents', 'document', 'name')
              return File.join(@data[@generator_options[:entry_set]][name]['contents']['project-root-path'], tool_key)
            end
          end
        end
        nil
      end

      # --------------------------------------------------------
      # Filter source file which does not comply with project
      # @param [Hash] source:source item
      # @param [Hash] project_info: project
      # @param [String] tool_key: project toolchain
      # @return [Boolean] true means the file pass filter and will be used in project
      def filter_source(source, project_info, tool_key, project_data)
        return false if source.nil? || source.empty?
        # The doc file like readme cannot be set to the armgcc cmakelist
        return false if %w[armgcc xcc xtensa].include?(tool_key) && source['type'] == 'doc'
        # CMakeLists.txt does not record files from software component
        return false if source.safe_key?('meta-component') && tool_key == 'armgcc'
        # won't copy sources which has 'hidden: true' attribute
        if (source.key?('hidden') && source['hidden'] == true) || (source.key?('exclude') && source['exclude'] == true)
          # For armgcc project, config file must be added into CMakeLists.txt, then cmake can use it to replace the file from template
          return false if tool_key != 'armgcc' || source['config'] != true
        end

        # check the "toolchains" tag
        if source.safe_key?('toolchains')
          return false unless source['toolchains'].to_s.include?(tool_key)
        end
        # check the "cores" tag
        return false if source.safe_key?('cores') && !source['cores'].strip.split(' ').include?(project_info[:corename].to_s.strip)

        # check the "core_ids" tag
        if source.safe_key?('core_ids') && !project_info[:core_id].nil?
          if project_info[:device_id]
            return false unless source['core_ids'].strip.split(' ').include?(project_info[:core_id].to_s.strip)
          else
            # For backward compatible.
            return false unless source['core_ids'].to_s.include?(project_info[:core_id].split('_')[-2].to_s.strip)
          end
        end
        # check the "fpu" tag
        if source.safe_key?('fpu') && !project_info[:fpu].nil?
          return false unless source['fpu'].to_s.downcase.split(/\s+/).include?(project_info[:fpu].to_s.strip.downcase)
        end
        # check "dsp" tag
        if source.safe_key?('dsp') && !project_info[:dsp].nil?
          return false unless source['dsp'].to_s.downcase.split(/\s+/).include?(project_info[:dsp].to_s.strip.downcase)
        end
        # check "trustzone" tag
        if source.safe_key?('trustzone') && !project_info[:trustzone].nil?
          return false unless source['trustzone'].to_s.downcase.split(/\s+/).include?(project_info[:trustzone].to_s.strip.downcase)
        end
        # check the "compilers" tag
        if source.safe_key? 'compilers'
          toolchain_compiler = if tool_key == 'mdk' && project_info[:compilers].include?('armcc')
                                 'armcc'
                               else
                                 get_datatable_compilers(tool_key)
                               end
          return false unless source['compilers'].split(/\s+/).include? toolchain_compiler
        end
        # process the "condition" tag, meta-condotion must be in meta_component array
        if source.safe_key?('components')
          return false unless (source['components'].strip.split(/\s+/) - project_info[:component]).empty?
        end

        # get the source targets if source not the targets tag mean the source for all targets.
        if source.safe_key?('targets')
          return false if (source['targets'].split(/\s+/) & project_info[:all_targets]).empty?
        end
        # template file is only as reference for user to implement, it's different with config file,so we  will add it.
        if source['template'] && source.key?('component_name') && !@generator_options[:gen_cmsis_project]
          project_info[:component_template_file][source['component_name']] = [] unless project_info[:component_template_file][source['component_name']]
          project_info[:component_template_file][source['component_name']].push_uniq File.basename(source['source'])
          return false
        end
        # filter replace_config source
        if source['config'] && source.key?('component_name') && !@generator_options[:gen_cmsis_project]
          return false if has_prepared_config_file?(source, project_data, tool_key, project_info)
        end
        true
      end

      # check if user has prepared config file or template file
      # @param [Hash] source: component source file to be check
      # @param [Hash] project_data:
      # @param [String] tool_key:
      # @param [Hash] project_info:
      def has_prepared_config_file?(source, project_data, tool_key, project_info)
        project_data[tool_key]['source'].each do |item|
          next if item.key? 'component_name'

          if item.key?('replace_config')
            config_res = parse_replace_config(item['replace_config'])
            return false if config_res.empty?

            config_res.each do |config_item|
              comp_name = config_item[0]
              config_file = config_item[1]
              raise DataDefinitionError if comp_name.nil?

              if comp_name == source['component_name'] && File.basename(source['source']) == config_file
                project_info[:replaced_component_config_file][comp_name] = [] unless project_info[:replaced_component_config_file][comp_name]
                project_info[:replaced_component_config_file][comp_name].push_uniq config_file
                return true
              end
            end
          end
        end
        false
      end

      # --------------------------------------------------------
      # Add files into project according to attribute
      # @param [IDEProject] project_instance: project instance for specific toolchain
      # @param [Hash] source:source item
      # @param [String] tool_key: project toolchain
      # @param [Hash] project_info: project
      # @return [NilClass]
      def add_files_by_attr(project_instance, source, tool_key, project_info)
        # all files be record under source tag, under configuration tag not record any file.
        # mcux process the following attributes in a different way. It regards them just as file with different types.
        return if tool_key == 'mcux'
        return unless source.safe_key? 'attribute'

        file_supported_targets = if source.safe_key?('targets')
                                   source['targets'].split(/\s+/) & project_info[:all_targets]
                                 else
                                   project_info[:all_targets]
                                 end

        case source['attribute']
          # set linker file
        when 'linker-file'
          file_supported_targets.each do |target|
            source['source'] = source['preprocessed'] if source.safe_key? 'preprocessed'
            project_instance.linker_file(target.downcase, source['source'], rootdir: 'outroot')
            project_instance.cpp_linker_file(target.downcase, source['source'], rootdir: 'outroot') if project_instance.methods.include?(:cpp_linker_file)
          end
          # set initialization file for mdk
        when 'initialization_file'
          file_supported_targets.each do |target|
            identifier = target.downcase
            initialization_file = source['source']
            project_instance.add_initialization_file(identifier, initialization_file, rootdir: 'outroot') if project_instance.methods.include?(:add_initialization_file)
          end
          # set flash programming file for mdk
        when 'flash_programming_file'
          file_supported_targets.each do |target|
            identifier = target.downcase
            flash_programming_file = source['source']
            project_instance.add_flash_programming_file(identifier, flash_programming_file, rootdir: 'outroot') if project_instance.methods.include?(:add_flash_programming_file)
          end
          # Project specific - set board-file
        when 'board-file'
          file_supported_targets.each do |target|
            absolute = source.key?('absolute') ? source['absolute'] : false
            project_instance.use_flash_loader(target.downcase, true) if project_instance.methods.include?(:use_flash_loader)
            project_instance.set_board_file(target.downcase, source['source'], absolute, rootdir: 'default_path') if project_instance.methods.include?(:set_board_file)
          end
          # Project specific - set dlib-config-file
          # This is for IAR now
        when 'dlib-config-file'
          file_supported_targets.each do |target|
            absolute = source.key?('absolute') ? source['absolute'] : false
            project_instance.set_dlib_config_file(target.downcase, source['source'], absolute, rootdir: 'default_path') if project_instance.methods.include?(:set_dlib_config_file)
          end
        when 'raw_binary_image'
          file_supported_targets.each do |target|
            project_instance.set_raw_binary_image(target.downcase, source.dup, rootdir: 'default_path') if project_instance.methods.include?(:set_raw_binary_image)
          end
        when 'postbuild-file'
          if tool_key == 'xtensa'
            # postbuild step scripts for xtensa toolchain
            project_instance.add_postbuild_steps(source['source'], rootdir: 'default_path') if project_instance.methods.include?(:add_postbuild_steps)
          else
            # This is for IAR postbuild command file
            file_supported_targets.each do |target|
              absolute = source.safe_key?('absolute') ? source['absolute'] : false
              extra_cmd = source.safe_key?('extra-cmd') ? source['extra-cmd'] : ''
              project_instance.set_postbuild_file(target.downcase, source['source'], absolute, extra_cmd, rootdir: 'default_path') if project_instance.methods.include?(:set_postbuild_file)
            end
          end
          # preclean step scripts for xtensa toolchain
        when 'preclean-file'
          project_instance.add_preclean_steps(source['source'], rootdir: 'default_path') if project_instance.methods.include?(:add_preclean_steps)
          # prebuild step scripts for xtensa toolchain
        when 'prebuild-file'
          project_instance.add_prebuild_steps(source['source'], rootdir: 'default_path') if project_instance.methods.include?(:add_prebuild_steps)
          # prelink step scripts for xtensa toolchain
        when 'prelink-file'
          project_instance.add_prelink_steps(source['source'], rootdir: 'default_path') if project_instance.methods.include?(:add_prelink_steps)
          # Project specific - set macro-file
          # choose: True MacOverride
        when 'macro-file'
          file_supported_targets.each do |target|
            absolute = source.key?('absolute') ? source['absolute'] : false
            choose = source.key?('choose') ? source['choose'] : true
            project_instance.set_macro_file(target.downcase, source['source'], absolute, choose, rootdir: 'default_path') if project_instance.methods.include?(:set_macro_file)
          end
          # project specific - set cmake file
        when 'cmake_file'
          project_instance.add_cmake_file(source['source'], source['cache_dir'], rootdir: 'default_path') if project_instance.methods.include?(:add_cmake_file)
          # add extra libraries
        when 'extra-libraries'
          file_supported_targets.each do |target|
            add_libraries(project_instance, target, source, tool_key, project_info)
          end
          # Add jlink script file
          # This is for IAR, ARMDS, MCUX, Code Warrior
        when 'jlink_script_file'
          file_supported_targets.each do |target|
            next if tool_key == 'mcux' && source.safe_key?('meta-component')

            # Currently, it is just for ultra ddr
            project_instance.set_jlink_script_file(target.downcase, source['source'], source['choose'], rootdir: 'default_path') if project_instance.methods.include?(:set_jlink_script_file)
          end
          # set memory config file
        when 'memory_config_file'
          file_supported_targets.each do |target|
            project_instance.set_memory_config_file(target.downcase, source['source'], rootdir: 'default_path') if project_instance.methods.include?(:set_memory_config_file)
          end
          add_source_file(project_instance, source, tool_key, project_info)
          # set target initialization file
        when 'target_initialization_file'
          file_supported_targets.each do |target|
            project_instance.set_target_initialization_file(target.downcase, source['source'], rootdir: 'default_path')  if project_instance.methods.include?(:set_target_initialization_file)
          end
          add_source_file(project_instance, source, tool_key, project_info)
          # set preinclude file
        when 'preinclude_file'
          file_supported_targets.each do |target|
            project_instance.set_preinclude_file(target.downcase, source['source'], source['macro'], source['linked_support'], vdir: source['project_path'], rootdir: 'default_path') if project_instance.methods.include?(:set_preinclude_file)
          end
          add_source_file(project_instance, source, tool_key, project_info)
        else
          # in case of file with attribute not covered
          add_source_file(project_instance, source, tool_key, project_info)
        end
      end

      def get_cmake_module_name(comp_name, project_info)
        raw_name = comp_name.split('.').join('_')
        device = project_info[:platform_devices_soc_name]
        project_info[:cmake_module_name].each do |mod_name|
          if raw_name == mod_name
            return  mod_name
          elsif raw_name == mod_name.split('.')[0]
            return "#{raw_name}.#{device}"
          end
        end
        @generator_logger.error("Can not get cmake module file name for #{comp_name}, please check if it has been removed by dependency analysis.")
        comp_name
      end

      def add_source_file(project_instance, source, tool_key, project_info)
        if source['targets'] && project_instance.methods.include?(:add_target_source)
          project_instance.add_target_source(source['source'], source['project_path'], source['targets'], rootdir: source['rootdir'], source_target: nil)
        else
          project_instance.add_source(source['source'], source['project_path'], rootdir: source['rootdir'], source_target: nil)
        end
        # set file AlwaysBuild attribute
        file_supported_targets = if source.safe_key?('targets')
                                   source['targets'].split(/\s+/) & project_info[:all_targets]
                                 else
                                   project_info[:all_targets]
                                 end
        project_instance.set_source_alwaysBuild(source['source'], source['project_path'], file_supported_targets, source['AlwaysBuild']) if source.key?('AlwaysBuild') &&  project_instance.methods.include?(:set_source_alwaysBuild)

      end

      # --------------------------------------------------------
      # Add source configuration
      # @param [IDEProject] project_instance: project instance for specific toolchain
      # @param [Hash] source:source item
      # @param [String] tool_key: project toolchain
      # @return [NilClass]
      def add_source_configuration(project_instance, source, tool_key)
        # Handle configuration in source level
        return unless source.key?('configuration')
        return unless source.dig('configuration', 'tools', tool_key, 'config')
        QuickSelector.findcheck(source['configuration'], ['tools', tool_key, 'config']).each do |target, content|
          # Project specific - add compiler flags
          diag_suppress_flags_array = []
          # add compiler flags on source level
          if content.key?('cc-flags')
            content['cc-flags']&.each do |flag|
              # iar specific
              if tool_key == 'iar' && flag =~ /--diag_suppress\s+([^\s\-]+)/
                diag_suppress_flags_array += $+.split(',')
                next
              end
              # add compiler flag for iar, mdk and armgcc except the flags prefixed with --diag_suppress for iar
              project_instance.add_compiler_flag_for_src(target, flag, source['source'], source['project_path']) if project_instance.methods.include?(:add_compiler_flag_for_src)
            end
            # add compiler flags prefixed with --diag_suppress for iar
            project_instance.add_compiler_flag_for_src(target, "--diag_suppress #{diag_suppress_flags_array.join(' ')}", source['source'], source['project_path']) if tool_key == 'iar' && !diag_suppress_flags_array.empty?
          end
          # add assembler flags on source level
          if content.key?('as-flags')
            content['as-flags']&.each { |flag| project_instance.add_assembler_flag_for_src(target, flag, source['source']) } if project_instance.methods.include?(:add_assembler_flag_for_src)
          end
          if content.key?('exclude') && !source.key?('meta-component')
            # exclude file from building for specific target, it only support project level files
            project_instance.exclude_building_for_target(target, source['source'], content['exclude'], source['project_path']) if project_instance.methods.include?(:exclude_building_for_target)
          end
        end
      end

      # Add assembler/c/cpp include path
      # @param [IDEProject] project_instance: project instance for specific toolchain
      # @param [String] identifier:target identifier
      # @param [Hash] content: target-specific toolchain configuration content
      # @param [String] tool_key: project toolchain
      # @param [Hash] project_info: project information
      # @return [NilClass]
      def add_include_path(project_instance, identifier, content, tool_key, project_info, project_data)
        # Add assembler include paths
        if content.key?('as-include')
          content['as-include']&.each do |include|
            if tool_key != 'mcux'
              next unless validate_include_path(include, tool_key, project_info[:corename], project_info[:compilers],  content['as-include'], project_info)
              next if tool_key == 'armgcc' && include.key?('meta-component')
              if ([:release_action_process, :file_copy] - @generator_options[:generators].keys).empty?
                include['path'] = include['package_path'] if include.key? 'package_path'
              end
              if include.key?('targets') && project_instance.methods.include?(:add_assembler_include_for_target)
                # support target-specific as-include path
                project_instance.add_assembler_include_for_target(identifier, include['targets'], include['path'], rootdir: 'default_path')
              else
                project_instance.add_assembler_include(identifier, include['path'], rootdir: 'default_path')
              end
            end
          end
        end
        # Add compiler include paths
        if content.key?('cc-include')
          content['cc-include']&.each do |include|
            next unless validate_include_path(include, tool_key, project_info[:corename], project_info[:compilers], content['cc-include'], project_info)
            next if tool_key == 'armgcc' && include.key?('meta-component')
            if ([:release_action_process, :file_copy] - @generator_options[:generators].keys).empty?
              include['path'] = include['package_path']
            end
            project_instance.add_compiler_include(identifier, include['path'], include['macro'], include['linked_support'], vdir: include['project_path'], rootdir: 'default_path')
          end
        end
        # Add cpp compiler include paths
        if content.key?('cx-include')
          content['cx-include']&.each do |include|
            unless tool_key == 'mcux'
              next unless validate_include_path(include, tool_key, project_info[:corename], project_info[:compilers], content['cx-include'], project_info)
              next if tool_key == 'armgcc' && include.key?('meta-component')
              if ([:release_action_process, :file_copy] - @generator_options[:generators].keys).empty?
                include['path'] = include['package_path']
              end
              project_instance.add_cpp_compiler_include(identifier, include['path'], rootdir: 'default_path') if project_instance.methods.include?(:add_cpp_compiler_include)
            end
          end
        end
      end

      # Add project settings
      # @param [IDEProject] project_instance: project instance for specific toolchain
      # @param [String] identifier:target identifier
      # @param [Hash] content: target-specific toolchain configuration content
      # @param [String] tool_key: project toolchain
      # @param [Hash] project_info: project information
      # @return [NilClass]
      def add_project_settings(project_instance, identifier, content, tool_key, project_info, project_data)
        add_include_path(project_instance, identifier, content, tool_key, project_info, project_data)
        # Add cpp compiler define
        if content.key?('cx-define')
          content['cx-define']&.each do |define_name, define_value|
            project_instance.add_cpp_compiler_macro(identifier, define_name, define_value) if project_instance.methods.include?(:add_cpp_compiler_macro)
          end
        end
        # Add c compiler define
        if content.key?('cc-define')
          content['cc-define']&.each do |define_name, define_value|
            if %w[armgcc mdk mcux armds xcc codewarrior].include?(tool_key)
              if define_value && define_value.class == String && define_value.match(/\"(.*)\"/)
                define_value = '\\"' + Regexp.last_match(1) + '\\"' unless tool_key == 'mcux'
                define_value = '\'' + define_value + '\''
              end
            end
            project_instance.add_compiler_macro(identifier, define_name, define_value)
          end
        end
        # Add c compiler define
        if content.key?('cc-undefine')
          content['cc-undefine']&.each do |define_name, define_value|
            project_instance.add_compiler_undef_macro(identifier, define_name, define_value) if project_instance.methods.include?(:add_compiler_undef_macro)
          end
        end
        # Add assembler macros
        if content.key?('as-define')
          content['as-define']&.each do |define_name, define_value|
            if %w[armgcc mdk mcux armds xcc codewarrior].include?(tool_key)
              if define_value && define_value.class == String && define_value.match(/\"(.*)\"/)
                define_value = '\\"' + Regexp.last_match(1) + '\\"' unless tool_key == 'mcux'
                define_value = '\'' + define_value + '\''
              end
            end
            project_instance.add_assembler_macro(identifier, define_name, define_value)
          end
        end

        # Add compiler macros for iar mdk
        if content.safe_key?('cp-define')
          content['cp-define']&.each do |define_name, define_value|
            project_instance.add_chipdefine_macro(identifier, "#{define_name}\t#{define_value}") if project_instance.methods.include?(:add_chipdefine_macro)
            # armds launcher need cpu info
            project_instance.set_cmsis_pack(define_name.split('_')[0]) if tool_key == 'armds'
          end
        else
          # For device without cp-define, set core instead
          project_instance.use_core_variant(identifier, 0) if project_instance.methods.include?(:use_core_variant)
          project_instance.set_device_vendor(identifier, content['cc-flags']) if project_instance.methods.include?(:set_device_vendor)
        end
        # Add rteconfig for armds
        if content.key?('rteconfig')
          content['rteconfig']&.each do |each_content|
            project_instance.rteconfig_dcoreversion_set(each_content) if project_instance.methods.include?(:rteconfig_dcoreversion_set)
          end
        end
        # Add user object files for armds
        if content.key?('user-object')
          content['user-object']&.each do |each_content|
            project_instance.add_user_object(target, each_content, rootdir: 'outroot') if project_instance.methods.include?(:add_user_object)
          end
        end
        # Add library search path for code warrior
        if content.key?('lib-search-path')
          content['lib-search-path']&.each do |include|
            next unless validate_include_path(include, tool_key, project_info[:corename], project_info[:compilers], content['lib-search-path'])

            project_instance.add_lib_search_path(identifier, include['path'], rootdir: 'default_path') if project_instance.methods.include?(:add_lib_search_path)
          end
        end
        # Add additional library for code warrior
        if content.key?('addl-lib')
          content['addl-lib']&.each do |include|
            next unless validate_include_path(include, tool_key, project_info[:corename], project_info[:compilers], content['addl-lib'])

            project_instance.add_addl_lib(identifier, include['path'], rootdir: 'default_path') if project_instance.methods.include?(:add_addl_lib)
          end
        end
        # Add compiler system search path for code warrior
        if content.key?('sys-search-path')
          content['sys-search-path']&.each do |include|
            next unless validate_include_path(include, tool_key, project_info[:corename], project_info[:compilers], content['sys-search-path'])

            project_instance.add_sys_search_path(identifier, include['path'], rootdir: 'default_path') if project_instance.methods.include?(:add_sys_search_path)
          end
        end
        # Add compiler system search path recursively for code warrior
        if content.key?('sys-path-recursively')
          content['sys-path-recursively']&.each do |include|
            next unless validate_include_path(include, tool_key, project_info[:corename], project_info[:compilers], content['sys-path-recursively'])

            project_instance.add_sys_path_recursively(identifier, include['path'], rootdir: 'default_path') if project_instance.methods.include?(:add_sys_search_path)
          end
        end

        # Add binary-file
        if content.key?('binary-file') && content['binary-file']
          if project_instance.is_app?
            # For application projects (not lib project)
            # the binary-file should be the runable image but not toolchain output file.
            # binary-file had only one file before. However, cmake support create multi binary file with special options
            # save binary-file in array to unify data structure for compatibility
            content['binary-file'] = [content['binary-file']] if content['binary-file'].is_a?(String)
            content['binary-file'].each do |item|
              binary_name = item.is_a?(Hash) ? item['file'].strip : File.join(project_info[:outdir], identifier, item.strip)
              project_instance.converted_output_file(identifier, binary_name, rootdir: 'outroot')
              output_name = File.join(project_info[:outdir], identifier, "#{project_info[:pname]}.out")
              project_instance.binary_file(identifier, output_name, rootdir: 'outroot')
              item['options']&.each { |option| project_instance.add_binary_options(identifier, binary_name, option, rootdir: 'outroot') } if item.is_a?(Hash) && project_instance.methods.include?(:add_binary_options)
            end
          elsif project_instance.is_lib?
            binary_name = File.join(project_info[:outdir], identifier, content['binary-file'].strip)
            project_instance.binary_file(identifier, binary_name, rootdir: 'outroot')
            # For armgcc library project, copy the library if set other path for that file or file name is different with project name
            if content['binary-file'] != File.basename(content['binary-file']) || File.basename(content['binary-file'], '.*') != project_info[:pname]
              project_instance.copy_binary(identifier, binary_name, rootdir: 'outroot') if project_instance.methods.include?(:copy_binary)
            end
          end
        else
          binary_name = File.join(project_info[:outdir], identifier, "#{project_info[:pname]}#{project_info[:type] == 'application' ? '.out' : '.a'}")
          project_instance.binary_file(identifier, binary_name, rootdir: 'outroot')
        end

        # enable automatic placement of crp feeld in image
        if content.key?('enable_crp')
          enable_crp = content['enable_crp']
          project_instance.enable_crp_in_image(identifier, enable_crp) if enable_crp
        end

        if content.key?('build_dir')
          build_dir = content['build_dir']
          project_instance.set_build_dir(identifier, build_dir) if build_dir
        end

        # Add system libraries for armgcc mcux
        if content.key?('system-libraries')
          content['system-libraries']&.each do |lib|
            project_instance.add_sys_link_library(identifier, lib) if project_instance.methods.include?(:add_sys_link_library)
          end
        end
        # Set specific_optimization for folder
        if content.key?('specific_optimization')
          content['specific_optimization'].each do |specific_optimization|
            if specific_optimization && !specific_optimization.empty?
              project_instance.add_comfiguration(identifier, specific_optimization['project_path'], specific_optimization['optlevel'])
            end
          end
        end
        # Set Load Application at Starup for mdk
        if content.key?('load_application')
          project_instance.set_load_application(identifier, content['load_application']) if project_instance.methods.include?(:set_load_application)
        end
        # Set Load Application at Starup for mdk
        if content.key?('periodic_update')
          project_instance.set_periodic_update(identifier, content['periodic_update']) if project_instance.methods.include?(:set_periodic_update)
        end
        # Set input raw binary image
        if content.key?('raw-binary-image')
          project_instance.set_raw_binary_image_file(identifier, content['raw-binary-image']['path'], rootdir: nil)
          project_instance.set_raw_binary_image_symbol(identifier, content['raw-binary-image']['symbol'])
          project_instance.set_raw_binary_image_section(identifier, content['raw-binary-image']['section'])
          project_instance.set_raw_binary_image_align(identifier, content['raw-binary-image']['align'])
        end
        # Set debugger for asymmetric multicore debugging
        if content.key?('asym-multicore-debugger')
          project_instance.enable_multicore_master_mode(identifier, content['asym-multicore-debugger']['enable']) if content['asym-multicore-debugger'].key?('enable')
          project_instance.set_slave_workspace(identifier, content['asym-multicore-debugger']['slave-workspace']) if content['asym-multicore-debugger'].key?('slave-workspace')
          project_instance.set_slave_project(identifier, content['asym-multicore-debugger']['slave-project']) if content['asym-multicore-debugger'].key?('slave-project')
          project_instance.set_slave_configuration(identifier, content['asym-multicore-debugger']['slave-configuration']) if content['asym-multicore-debugger'].key?('slave-configuration')
        end
        if content.key?('download-extra-image')
          content['download-extra-image'].each do |each_image_config|
            project_instance.enable_download_extra_image(identifier, each_image_config['item'])
            project_instance.set_image_path(identifier, each_image_config['path'], each_image_config['item'])
            project_instance.set_offset(identifier, each_image_config['offset'], each_image_config['item'])
            project_instance.set_debug_info_only(identifier, each_image_config['debug_info_only'], each_image_config['item'])
          end
        end
        # Configure the multicore debugging for lpcx and mcux
        if content.key?('multicore-configuration')
          project_instance.set_multicore_configuration(identifier, content['multicore-configuration'])
          project_instance.set_cpp_multicore_configuration(identifier, content['multicore-configuration']) if project_instance.methods.include?(:set_cpp_multicore_configuration)
        end
        if content.key?('multicore-slave-config')
          project_instance.configure_slaves(identifier, content['multicore-slave-config'])
          project_instance.configure_cpp_slaves(identifier, content['multicore-slave-config']) if project_instance.methods.include?(:configure_cpp_slaves)
        end
        # Project specific - add assembler flags
        if content.key?('as-flags')
          content['as-flags']&.each { |flag| project_instance.add_assembler_flag(identifier, flag) }
        end
        # Add compiler flag for assembler, Xtensa specified
        if content.key?('ccflags-for-as')
          content['ccflags-for-as']&.each do |flag|
            project_instance.add_compiler_for_assembler_flag(identifier, flag) if project_instance.methods.include?(:add_compiler_for_assembler_flag)
          end
        end
        # Enable shared malloc, Xtensa specified
        if content.safe_key?('enable-shared-malloc')
          project_instance.enable_shared_malloc(identifier, content['enable-shared-malloc']) if project_instance.methods.include?(:enable_shared_malloc)
        end
        # Set CreateMinsize, Xtensa specified
        if content.key?('createMinsize')
          project_instance.set_create_minsize_object(identifier, content['createMinsize']) if project_instance.methods.include?(:set_create_minsize_object)
        end
        # Set export include path, Xtensa specified
        if content.key?('export_include_path')
          project_instance.set_export_include_path(identifier, content['export_include_path']) if project_instance.methods.include?(:set_export_include_path)
        end

        if content.key?('link-generated-lib')
          content['link-generated-lib']&.each do |source|
            add_libraries(project_instance, identifier, { 'source' => source }, tool_key, project_info)
          end
        end
        # Add compiler flag for linker, Xtensa specified
        if content.key?('ccflags-for-ld')
          content['ccflags-for-ld']&.each do |flag|
            project_instance.add_compiler_for_linker_flag(identifier, flag) if project_instance.methods.include?(:add_compiler_for_assembler_flag)
          end
        end
        # Project specific - add compiler flags
        @diag_suppress_flags_array = []
        if content.key?('cc-flags')
          content['cc-flags']&.each do |flag|
            if tool_key == 'iar' && flag =~ /--diag_suppress\s+([^\s\-]+)/
              @diag_suppress_flags_array += $+.split(',')
              next
            end
            project_instance.add_compiler_flag(identifier, flag)
          end
          project_instance.add_compiler_flag(identifier, "--diag_suppress #{@diag_suppress_flags_array.join(',')}") if tool_key == 'iar' && !@diag_suppress_flags_array.empty?
        end
        # Project specific - add cx flags
        if content.key?('cx-flags')
          content['cx-flags']&.each do |flag|
            project_instance.add_cpp_compiler_flag(identifier, flag) if project_instance.methods.include?(:add_cpp_compiler_flag)
          end
        end
        # Project specific - add linker flags
        if content.key?('ld-flags')
          content['ld-flags']&.each do |flag|
            project_instance.add_linker_flag(identifier, flag) if project_instance.methods.include?(:add_linker_flag)
          end
        end
        # Project specific - add additional flags: mainly for stack/heap size
        if content.key?('ad-flags')
          content['ad-flags']&.each do |flag|
            project_instance.add_linker_flag(identifier, flag) if project_instance.methods.include?(:add_linker_flag)
          end
        end
        # Add prebuild and postbuild
        if content.key?('prebuild')
          project_instance.add_prebuild_script(identifier, content['prebuild']) if project_instance.methods.include?(:add_prebuild_script)
        end
        if content.key?('postbuild')
          # project_instance.add_postbuild_script(target, @ustruct[project_tag][tool_key]['targets'][target]['postbuild'])
          post_build = content['postbuild']
          if project_instance.methods.include?(:add_postbuild_script)
            if tool_key == 'mdk' && content.safe_key?('binary-file')
              # for mdk, binary-file will be added as after make command 1
              project_instance.add_postbuild_script(identifier, post_build, item: 2)
            else
              project_instance.add_postbuild_script(identifier, post_build)
            end
          end
        end
        if content.key?('precompile')
          project_instance.add_precompile_command(identifier, content['precompile']) if project_instance.methods.include?(:add_precompile_command)
        end
        # mdk update target before debugging option
        if content.key?('update-before-debug')
          project_instance.update_before_debug(identifier, content['update-before-debug']) if project_instance.methods.include?(:update_before_debug)
        end
        # set createHexFile for mdk
        if content.key?('createHexFile')
          project_instance.create_hex_file(identifier, content['createHexFile']) if project_instance.methods.include?(:create_hex_file)
        end
        # set debugger extra options for IAR
        if content.key?('debugger_extra_options')
          project_instance.set_debugger_extra_options(identifier, content['debugger_extra_options']) if project_instance.methods.include?(:set_debugger_extra_options)
        end
        # Set cpp compiler for iar and mcux
        if @generator_options[:gen_cpp] || (!project_info[:project_language].nil? && project_info[:project_language] != 'c')
          project_instance.set_cpp_compiler(identifier, project_info[:project_language] || 'cpp') if project_instance.methods.include?(:set_cpp_compiler)
        end
        # Update project file for specific version toolchain
        project_instance.set_project_version(identifier, project_info[:toolchain_version]) if project_instance.methods.include?(:set_project_version)
        return unless tool_key == 'iar'

        # Add each target of each project into all batch build
        project_instance.add_batch_project_target('all', project_info[:pname], identifier) if project_instance.methods.include?(:add_batch_project_target)
        # Separate targets by name to same batch build configuration
        # debug targets of each project will be included in debug batch build
        project_instance.add_batch_project_target(identifier, project_info[:pname], identifier) if project_instance.methods.include?(:add_batch_project_target)
        # Project specific - use flash loader
        project_instance.use_flash_loader(identifier, true) if identifier =~ /intflash/

        return unless content['debugger_setting'] && !content['debugger_setting'].empty?

        textbox = content['debugger_setting'].key?('runto_text') ? content['debugger_setting']['runto_text'] : 'main'
        checkbox = content['debugger_setting'].key?('runto_check') ? content['debugger_setting']['runto_check'] : false
        multicore_check = content['debugger_setting'].key?('multicore_attach') ? content['debugger_setting']['multicore_attach'] : false
        cmsisdap_interface = content['debugger_setting'].key?('cmsisdap_interface') ? content['debugger_setting']['cmsisdap_interface'] : 'auto'
        cmsisdap_multitarget = content['debugger_setting'].key?('cmsisdap_multitarget') ? content['debugger_setting']['cmsisdap_multitarget'] : false
        cmsisdap_multicpu = content['debugger_setting'].key?('cmsisdap_multicpu') ? content['debugger_setting']['cmsisdap_multicpu'] : false
        cmsisdap_resetlist = content['debugger_setting'].key?('cmsisdap_resetlist') ? content['debugger_setting']['cmsisdap_resetlist'] : 'custom'

        if content['debugger_setting'].key?('suppress_download')
          suppress_download = content['debugger_setting']['suppress_download']
          project_instance.set_debugger_download(identifier, suppress_download) if project_instance.methods.include?(:set_debugger_download)
        end
        if content['debugger_setting'].key?('verify_download')
          verify_download = content['debugger_setting']['verify_download']
          project_instance.set_verify_download(identifier, verify_download) if project_instance.methods.include?(:set_verify_download)
        end

        if project_instance.methods.include?(:set_debugger)
          project_instance.set_debugger(identifier, textbox, checkbox, multicore_check) if content['debugger_setting'].key?('runto_check') || content['debugger_setting'].key?('runto_text') || content['debugger_setting'].key?('multicore_attach')
        end
        if project_instance.methods.include?(:set_debugger_cmsisdap)
          project_instance.set_debugger_cmsisdap(identifier, cmsisdap_interface, cmsisdap_multicpu, cmsisdap_multitarget, cmsisdap_resetlist) if content['debugger_setting'].key?('cmsisdap_interface') || content['debugger_setting'].key?('cmsisdap_multitarget') || content['debugger_setting'].key?('cmsisdap_multicpu') || content['debugger_setting'].key?('cmsisdap_resetlist')
        end
      end

      # Add armgcc misc settings
      # @param [IDEProject] project_instance: project instance for specific toolchain
      # @param [Hash] project_info: project information
      # @return [NilClass]
      def add_armgcc_misc_settings(project_instance, project_info)
        # set cmake variables
        project_instance.set_cmake_variables(project_info[:cmake_variables]) if project_info[:cmake_variables]
        project_instance.set_cmake_command(project_info[:cmake_command]) if project_info[:cmake_command]
        # add all_lib_device_${device}.cmake
        project_instance.add_module_path("devices/#{project_info[:platform_devices_soc_name]}/all_lib_device.cmake")
        # TODO Don't add board/kit cmake entry, currently there is gap in cmake and manifest
        # if project_info[:platform_devices_soc_name] != project_info[:board]
        #   if project_info[:board_kit] == project_info[:board]
        #     project_instance.add_module_path("boards/#{project_info[:board_kit]}/all_lib_board.cmake")
        #   else
        #     project_instance.add_module_path("boards/#{project_info[:board_kit]}/all_lib_kit.cmake")
        #   end
        # end
        # add dependent component in config.cmake
        project_instance.add_cmake_config(project_info[:component])
        # add hardware info
        project_instance.add_hardware_info(project_info)
      end

      def save_project_definition_files(project_instance, tool_key, project_info, project_tag, project_name, generated_files)
        if ENV['standalone']
          project_type = 'Standalone'
        else
          project_type = 'GUI'
        end
        if %w[iar mdk].include?(tool_key)
          #TODO save solution workspace
          # Key is project sharing the same workspace, value is relative out dir path
          shared_projects_info = {}
          if project_info[:sharing_workspace]
            # save project for debug and release version
            project_info[:all_targets].each do |identifier|
              project_info[:sharing_workspace]&.each do |project_item|
                slave_project_outdir = File.dirname(project_item)
                slave_project_name = File.basename(project_item, ".*")

                # Add projects to batchDefinition node if support multi-projects in one workspace
                project_instance.add_batch_project_target('all', slave_project_name, identifier) if project_instance.methods.include?(:add_batch_project_target)
                project_instance.add_batch_project_target(identifier, slave_project_name, identifier) if project_instance.methods.include?(:add_batch_project_target)
                shared_projects_info[slave_project_name] = slave_project_outdir
              end
            end
          end
          # save project for IAR or Keil platform, arguments is for adding shared projects in the same workspace
          generated_files[tool_key] |= project_instance.save(shared_projects_info, project_info[:using_shared_workspace], project_info[:shared_workspace] || project_name)
        else
          # save project for other platform
          generated_files[tool_key] |= project_instance.save
        end
        if tool_key == 'armgcc'
          generated_files[tool_key].push_uniq("devices/#{project_info[:platform_devices_soc_name]}/all_lib_device.cmake")
        end
        if ENV['FINAL_BUILD_DIR']
          if ENV['SYSBUILD']
            final_output_rootdir = File.join(ENV['FINAL_BUILD_DIR'], File.basename(@output_rootdir))
          else
            final_output_rootdir = ENV['FINAL_BUILD_DIR']
          end
          puts "\r\nGenerate #{project_type} project: #{project_info[:internal] ? 'internal' : ''} [#{project_info[:all_targets].join(' ')}] [#{project_name}]" + ' [' + File.join(final_output_rootdir, project_info[:outdir], project_info[:project_file_name]) + ']'
        else
          puts "\r\nGenerate #{project_type} project: #{project_info[:internal] ? 'internal' : ''} [#{project_info[:all_targets].join(' ')}] [#{project_name}]" + ' [' + File.join(@output_rootdir, project_info[:outdir], project_info[:project_file_name]) + ']'
        end
      end

      def add_generated_files(project_tag, generated_files)
        tmp_hash = {'product_output' => true, 'files'=>[]}
        generated_files.each do |tool_key, files|
          if tool_key == 'mcux'
            files.each { |file| tmp_hash['files'].push({'source' => file, 'example_xml' => true, 'type' => 'workspace'}) }
          else
            files.each { |file| tmp_hash['files'].push({'source' => file, 'toolchains' => tool_key, 'type' => 'workspace'}) }
          end
        end
        @data[@generator_options[:entry_set]][project_tag]['contents']['modules']['product_output_project_files'] = tmp_hash
      end

      def post_process_data(project_tag, binary_packed)
        @data[@generator_options[:entry_set]][project_tag]['contents']['document']['binary_packed'] = binary_packed unless binary_packed.empty?
        @data[@generator_options[:entry_set]][project_tag]['contents'].delete('configuration')
        @data[@generator_options[:entry_set]][project_tag]['contents']['modules'].each do |module_name, module_content|
          if module_content['external_component']
            @data[@generator_options[:entry_set]][project_tag]['contents']['modules'].delete module_name
          end
        end
      end
    end
  end
end
# ********************************************************************
# EOF
# ********************************************************************
