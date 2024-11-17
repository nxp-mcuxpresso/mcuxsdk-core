# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require_relative '../../../../../utils/sdk_utils'
require_relative '../../../../../utils/utils'

module SDKGenerator
  module ProjectGenerator
    class CMakeModulesGenerator
      def initialize(generator_options, udata, component_data, data_problems_logger, **_kwargs)
        @generator_options = generator_options
        @data_problems_logger = data_problems_logger
        @data_problems_logger.subcategory('CMake Modules Generation', 'Generate CMake modules for components required by all projects')
        @udata = udata
        @component_data = component_data
        @cmake_modules_array = []
      end

      def is_project_template(comp)
        project_type = comp.dig('component_info', 'common', 'type')
        return true if project_type && project_type == 'project_template'

        false
      end

      def get_name(comp)
        return comp.split('.').join('_')
      end

      def get_name_from_meta(component, meta)
        comp_name = ''
        component&.each do |name, content|
          if content['meta-name'] == meta
            comp_name = get_name(name)
            break
          end
        end
        comp_name
      end

      def write_components(component_content, components_array, aFile, device)
        components_array.each do |comp|
          next unless component_content.key? comp
          next if component_content[comp]['section-type'] != 'component'
          next if comp.include? 'ui_control'
          next if is_project_template(component_content[comp])

          comp_name = get_name(comp)
          aFile.write("include(#{comp_name}_#{device})\n")
          aFile.write("\n")
        end
      end

      # handle or logic
      def handle_or_logic(component_content, comp, default, aFile, device, _cmake_name)
        comp_required = component_content[comp]['__requires__']
        comp_required_array = []
        comp_required.each { |line| comp_required_array.push line.split(/\s+/) }
        common_item_in_line = comp_required_array.inject(:&)
        all_or_items = []
        default_or_items = []
        config_conditions = []

        aFile.write("#OR Logic component\n")
        comp_required_array.each do |line|
          or_items = line - common_item_in_line
          default_or_items = or_items if or_items.include? default
          or_items.each do |or_item_name|
            next unless component_content.safe_key? or_item_name

            or_item = get_name(or_item_name)
            all_or_items.push or_item
            config_conditions.push "CONFIG_USE_#{or_item}_#{device}"
            aFile.write("if(CONFIG_USE_#{or_item}_#{device})\n")
            aFile.write("     include(#{or_item}_#{device})\n")
            aFile.write("endif()")
            aFile.write("\n")
          end
        end
        aFile.write("if(NOT (#{config_conditions.join(' OR ')}))\n")
        temp_arr = []
        default_temp_arr = []
        all_or_items.each { |item| temp_arr.push_uniq("#{item}_#{device}") }
        default_or_items.each { |item| default_temp_arr.push_uniq("#{get_name(item)}_#{device}") }
        aFile.write("    message(WARNING \"Since #{temp_arr.join('/')} is not included at first or config in config.cmake file, use #{default_temp_arr.join('/')} by default.\")\n")
        default_or_items.each { |item| aFile.write("    include(#{get_name(item)}_#{device})\n") }
        aFile.write("endif()\n")
        aFile.write("\n")
        write_components(component_content, common_item_in_line, aFile, device)
      rescue StandardError => e
        raise "Error occurred when handle or logic: #{e.message}"
      end

      def add_macro_definition(component, aFile, _cmake_name)
        if component['contents'].key? 'cc-define'
          aFile.write("target_compile_definitions(${MCUX_SDK_PROJECT_NAME}  PRIVATE\n")
          component['contents']['cc-define']&.each do |key, val|
            if val
              aFile.write("    -D#{key}=#{val}\n")
            else
              aFile.write("    -D#{key}\n")
            end
          end
          aFile.write(")\n")
          aFile.write("\n")
        end
      end

      def filter_files_condition(file, corename, core_id, fpu, device_id)
        return true if %w[doc other image].include? file['type']
        return true if file.key?('hidden') && file['hidden'] == true
        return true if file.key?('exclude') && file['exclude'] == true

        if file.key?('toolchains')
          return true unless file['toolchains'].to_s.include?('armgcc')
        end
        return true if file.key?('cores') && !file['cores'].strip.split(' ').include?(corename.to_s.strip)

        if file.key?('core_ids') && !core_id.nil?
          if device_id
            return true unless file['core_ids'].to_s.include?(core_id.to_s.strip)
          else
            # For backward compatible.
            return true unless file['core_ids'].to_s.include?(core_id.split('_')[-2].to_s.strip)
          end
        end
        if file.key?('fpu') && !fpu.nil?
          return true unless file['fpu'].to_s.downcase.include?(fpu.to_s.strip.downcase)
        end
        if file.key? 'compilers'
          return true unless file['compilers'].include? 'gcc'
        end
        return false
      end

      def validate_include_path(include, tool_key, core_name, compilers)
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

      def handle_requirement(component_content, comp, aFile, cmake_name, device)
        if component_content[comp].key?('__requires__')
          comp_required = component_content[comp]['__requires__']
          default = component_content[comp]['default']
          if comp_required.length == 1
            write_components(component_content, comp_required[0].split(/\s+/), aFile, device)
          elsif comp_required.length > 1
            # handle or logic
            handle_or_logic(component_content, comp, default, aFile, device, cmake_name)
          end
        end
      rescue StandardError => e
        raise "Requirement error occurred when handle #{comp}: #{e.message}"
      end

      def write_source(cmake_name, source_file, aFile, device)
        aFile.write("target_sources(${MCUX_SDK_PROJECT_NAME} PRIVATE\n")
        source_file.each do |src|
          aFile.write("    ${CMAKE_CURRENT_LIST_DIR}/#{src}\n")
        end
        aFile.write(")\n")
      end

      def write_include_path(cmake_name, path_array, aFile, device)
        aFile.write("\n")
        aFile.write("target_include_directories(${MCUX_SDK_PROJECT_NAME} PRIVATE\n")
        path_array.each do |path|
          aFile.write("    ${CMAKE_CURRENT_LIST_DIR}/#{path}\n")
        end
        aFile.write(")\n")
        aFile.write("\n")
      end

      def get_include_path(include_path_array, contents, corename, type, release_mode)
        if contents&.safe_key? type
          contents[type].each do |path|
            next unless validate_include_path(path, 'armgcc', corename, ['gcc'])

            include_path = if release_mode
                             path['package_relative_path']
                           else
                             path['repo_relative_path']
                           end
            include_path_array.push_uniq(Pathname.new(include_path).cleanpath.to_s)
          end
        end
      end

      def get_macro(defined_macro_array, contents, type)
        if contents&.safe_key? type
          contents[type].each do |key, value|
            defined_macro_array[key] = value
          end
        end
      end

      def generate_cmake_module(cmake_modules, component_content, comp, corename, fpu, core_id, device_id, board, device)
        source_file = []
        source_file_with_meta_condition = {}
        include_path_array = []
        defined_macro_array = {}
        cmake_name = get_name(comp)
        cmake_file_name = [cmake_name, device, board].join('_')
        cmake_file_name_record = "#{[cmake_name, device, board].join('$conjunction$')}.cmake"
        contents = component_content.dig(comp, 'contents')
        release_mode = @generator_options[:stage1][:gen_release]
        dest_file = if release_mode
                      File.join(@generator_options[:msdk_path], contents['package_base_path'] || contents['repo_base_path'], "#{cmake_file_name}.cmake")
                    else
                      File.join(@generator_options[:msdk_path], contents['repo_base_path'], "#{cmake_file_name}.cmake")
                    end

        # get include path
        get_include_path(include_path_array, contents, corename, 'cc-include', release_mode)
        get_include_path(include_path_array, contents, corename, 'as-include', release_mode)
        get_include_path(include_path_array, contents, corename, 'cx-include', release_mode)

        # get macro
        get_macro(defined_macro_array, contents, 'cc-define')
        get_macro(defined_macro_array, contents, 'as-define')
        get_macro(defined_macro_array, contents, 'cx-define')

        # get source files
        if contents&.safe_key? 'files'
          contents['files'].each do |file|
            next if filter_files_condition(file, corename, core_id, fpu, device_id)

            source_path = if release_mode
                            File.join(file['package_relative_path'], File.basename(file['source']))
                          else
                            File.join(file['repo_relative_path'], File.basename(file['source']))
                          end
            source_path = Pathname.new(source_path).cleanpath.to_s

            if ['.c', '.cpp', '.s', '.S', '.cc'].include?(File.extname(file['source']))
              if file['meta-condition']
                file['meta-condition'].split(/\s+/).each do |cond|
                  source_file_with_meta_condition[cond] = [] unless source_file_with_meta_condition[cond]
                  source_file_with_meta_condition[cond].push_uniq source_path
                end
              else
                source_file.push_uniq(source_path)
              end
            end
          end
        end
        FileUtils.mkdir_p(File.dirname(dest_file)) unless File.directory?(File.dirname(dest_file))
        aFile = File.new(dest_file, 'wb')
        aFile.write("include_guard()\n")
        aFile.write("message(\"#{cmake_name} component is included.\")\n")
        aFile.write("\n")
        if !include_path_array.empty? || !defined_macro_array.empty? || !source_file.empty? || !source_file_with_meta_condition.empty?
          # if has files
          if !source_file.empty? || !source_file_with_meta_condition.empty?
            unless source_file.empty?
              write_source(cmake_name, source_file, aFile, device)
              aFile.write("\n")
            end

            unless source_file_with_meta_condition.empty?
              first = true
              source_file_with_meta_condition.each do |meta, files|
                meta_cond = get_name_from_meta(component_content, meta)
                next if meta_cond == ''

                if first
                  aFile.write("if(CONFIG_USE_#{meta_cond}_#{device})\n")
                  write_source(cmake_name, files, aFile, device)
                  first = false
                else
                  aFile.write("elseif(CONFIG_USE_#{meta_cond}_#{device})\n")
                  write_source(cmake_name, files, aFile, device)
                end
              end
              aFile.write("else()\n")
              metas = []
              source_file_with_meta_condition.keys.each do |item|
                metas.push_uniq("#{item}_#{device}")
              end
              aFile.write("    message(WARNING \"please config #{metas.join(' or ')} first.\")\n")
              aFile.write("endif()\n")
              aFile.write("\n")
            end

            write_include_path(cmake_name, include_path_array, aFile, device) unless include_path_array.empty?

            aFile.write("\n")

            # handle dependency
            handle_requirement(component_content, comp, aFile, cmake_name, device)
          elsif !include_path_array.empty?
            # libraries with header files only
            write_include_path(cmake_name, include_path_array, aFile, device)
            handle_requirement(component_content, comp, aFile, cmake_name, device)
          else
            handle_requirement(component_content, comp, aFile, cmake_name, device)
          end
        end
        aFile.close
        cmake_modules.push File.join(File.dirname(dest_file), cmake_file_name_record)
      end

      def get_device_info(udata)
        device_info = []
        udata.each do |_name, content|
          next unless content.safe_key? 'armgcc'

          document = content.dig('armgcc', 'document')
          corename = document['core']
          fpu = document['fpu']
          core_id = document['core_id']
          device_id = document['device_id']
          device_info = [corename, fpu, core_id, device_id]
          break
        end
        device_info
      end

      def process
        corename, fpu, core_id, device_id = get_device_info(@udata)
        return if corename.nil?

        device_name = if core_id
                        "#{@generator_options[:device]}_#{core_id}"
                      else
                        @generator_options[:device]
                      end
        board_name = @generator_options[:board]
        # for lib project, use device name instead of board name, but core info is not necessary
        board_name = device_name.split('_')[0] unless board_name
        required_components = []
        # get all of required components
        @udata&.each do |_name, content|
          next unless content.safe_key? 'armgcc'

          content['armgcc']['meta_component_map']&.each do |_meta_name, comp|
            required_components.push_uniq comp['name']
          end
        end
        required_components.each do |comp|
          next unless @component_data.safe_key? comp
          next if @component_data[comp]['section-type'] != 'component'
          next if comp.include? 'ui_control'
          next if is_project_template(@component_data[comp])
          next if @component_data[comp]['contents'].nil? || @component_data[comp]['contents'].empty?

          begin
            generate_cmake_module(@cmake_modules_array, @component_data, comp, corename, fpu, core_id, device_id, board_name, device_name)
          rescue StandardError => e
            @data_problems_logger.log_error(comp, "error occurred when generating component cmake modules: #{e.message}")
          end
        end
        # save all cmake modules path in root_path/cmake_modules folder
        unless @cmake_modules_array.empty?
          folder = File.join(@generator_options[:msdk_path], 'cmake_modules')
          FileUtils.mkdir_p(folder) unless File.directory?(folder)
          YAML.dump_file(File.join(folder, "#{board_name}_#{device_name}.yml"), @cmake_modules_array)
        end
      rescue StandardError => e
        @data_problems_logger.log_error("cmake modules geraration process", "error occurred when generating component cmake modules: #{e.message}")
      end
    end
  end
end
# ********************************************************************
# EOF
# ********************************************************************
