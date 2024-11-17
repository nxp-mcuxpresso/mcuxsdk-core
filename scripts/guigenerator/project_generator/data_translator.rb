# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require 'deep_merge'
require 'rubygems'
require 'pathname'
require 'fileutils'
require 'logger'
require_relative '../utils/sdk_utils'

module SDKGenerator
  module ProjectGenerator
    # ********************************************************************
    # Translate project data into the format that project generator can process
    # ********************************************************************
    class Translator
      include SDKUtils
      include YamlMetaConversions
      attr_accessor :data_in, :data_out
      SUBCATEGORY = 'Project data translation'
      # ignore warning when project has multiple component config files with same name,
      # because project-specific config file and component config files are both for same middleware configuration
      CONFIG_FILE_INGORE_WARN_LIST = %w[usb_device_config.h usb_host_config.h ffconf.h]

      def initialize(data, option, data_problems_logger=nil)
        @data_set = data
        @option = option
        @data_problems_logger = if data_problems_logger.nil?
                                  Logger.new(STDOUT)
                                else
                                  data_problems_logger
                                end
        @translated_component_module_cache = {}
      end

      def translate(project_tag)
        translate_project(project_tag)
        @data_out
      rescue StandardError => e
        raise 'Project Data Translator found error, ' + e.message + e.backtrace.to_s
      end

      private

      def convert_rules(proj, comp = 'iar', config_file = {})
        return unless @data_in[proj].dig_with_default({}, 'contents', 'configuration', 'tools').key?(comp)
        return if ENV['toolchain'] != comp

        compiler = @data_in[proj]['contents']['configuration']['tools'][comp]
        @data_out[proj][comp] = {}
        # add the component required by or logic
        @data_out[proj][comp]['project_required_or_comp'] =  @data_in[proj]['@project_required_or_comp'] if comp == 'armgcc'
        # Add meta-component tag
        @data_out[proj][comp]['meta-component'] = []
        @data_out[proj][comp]['cmake_module_name'] = []
        @data_out[proj][comp]['component_info'] = {}
        @data_out[proj][comp]['meta-force-condition'] = @data_in[proj]['meta-force-condition'] if @data_in[proj].key?('meta-force-condition')
        @data_out[proj][comp]['targets'] = {}
        @data_out[proj][comp]['type'] = @data_in[proj]['section-type']
        @data_out[proj][comp]['templates'] = compiler['project-templates']
        @data_out[proj][comp]['shared-workspace'] = compiler['shared-workspace']
        @data_out[proj][comp]['sharing-workspace'] = compiler['sharing-workspace']
        @data_out[proj][comp]['using-shared-workspace'] = compiler['using-shared-workspace']
        @data_out[proj][comp]['secure-gateway-importlib'] = compiler['secure-gateway-importlib']
        @data_out[proj][comp]['secure-gateway-placement'] = compiler['secure-gateway-placement']
        @data_out[proj][comp]['secure-gateway-importlib-gen'] = compiler['secure-gateway-importlib-gen']
        @data_out[proj][comp]['heap_stack_placement'] = compiler['heap_stack_placement']
        @data_out[proj][comp]['ignore'] = compiler['ignore'] if compiler.key?('ignore')
        @data_out[proj][comp]['binary_packed'] = compiler['binary_packed'] if compiler.key?('binary_packed')
        # raise "Missing debugger-config for #{comp}" unless compiler.has_key?('debugger-config')
        @data_out[proj][comp]['debugger-config'] = compiler['debugger-config']
        @data_out[proj][comp]['memory-config'] = compiler['memory-config'] if compiler.key?('memory-config')
        @data_out[proj][comp]['cmake_variables'] = compiler['cmake_variables'] if compiler.key?('cmake_variables')
        @data_out[proj][comp]['cmake_command'] = compiler['cmake_command'] if compiler.key?('cmake_command')
        # Add internal tag for ignore (not release) generator project eaxmple meta
        @data_out[proj][comp]['internal'] = @data_in[proj]['internal'] if @data_in[proj].key?('internal')
        # translate project_lanaguage
        common_project_language = @data_in[proj]['contents']['configuration']['project_language']
        if compiler['project_language']
          @data_out[proj][comp]['project_language'] = compiler['project_language']
        elsif common_project_language
          @data_out[proj][comp]['project_language'] = common_project_language
        else
          @data_out[proj][comp]['project_language'] = 'c'
        end

        # MCUX debug configuration
        @data_out[proj][comp]['debug_configuration'] = compiler['debug_configuration'] if comp == 'mcux' && compiler.key?('debug_configuration')

        @data_out[proj][comp]['outdir'] = if comp == 'mcux'
                                            Pathname.new(@data_out[proj]['outdir']).cleanpath.to_s
                                          else
                                            Pathname.new(File.join(@data_out[proj]['outdir'], comp)).cleanpath.to_s
                                          end

        # SDKGEN-2731 Ensure include path in example.xml
        if comp == 'mcux'
          compiler['config']['debug'] ||= {}
        end
        compiler['config'].delete_if { |key, value| key != ENV['build_config'] }

        compiler['config'].each_key do |target|
          create_and_deep_merge(@data_out[proj][comp]['targets'], target, compiler['config'][target])
          # compiler => config => target => setting  has higher priority than compiler => setting
          %w[binary-file prebuild postbuild precompile].each do |setting|
            @data_out[proj][comp]['targets'][target][setting] = compiler['config'][target][setting] if compiler['config'][target].key? setting
            unless @data_out[proj][comp]['targets'][target][setting]
              @data_out[proj][comp]['targets'][target][setting] = compiler[setting] if compiler.key?(setting)
            end
          end
        end
        return unless @data_in[proj]['contents'].key?('modules')
        @data_in[proj]['contents']['modules'].each do |name, component_content|
          next unless component_content.class == Hash
          next if component_content['product_output']
          component = get_component_content(name, component_content)
          if component.empty?
            @data_problems_logger.error("#{name} is not found!")
          end
          # component['external_component'] = component_content['external_component'] if component_content.key? 'external_component'
          @data_out[proj][comp]['cmake_module_name'].push_uniq(component['cmake_module_name']) if component.key?('cmake_module_name')
          if component.key?('external_component')
            # Add meta-component
            meta_name = component['meta-name'] || name
            @data_out[proj][comp]['meta-component'].push_uniq(meta_name)
            # add component-meta
            @data_out[proj][comp]['meta-component'].push_uniq(meta_name)
            @data_out[proj][comp]['component_info'][name] = {} unless @data_out[proj][comp]['component_info'][meta_name]
            @data_out[proj][comp]['component_info'][name]['meta-name'] = meta_name
            @data_out[proj][comp]['component_info'][name]['repo_base_path'] = component['repo_base_path']
            @data_out[proj][comp]['component_info'][name]['package_base_path'] = component['package_base_path'] || component['repo_base_path']
            @data_out[proj][comp]['component_info'][name]['section_info'] = component['section_info'].dup
          else
            # add config attribute for project file if missing
            if !config_file.empty? && component.safe_key?('files')
              component['files']&.each do |item|
                next if item.nil? || item.empty?
                source_file = File.basename(item['source'])
                if config_file.key?(source_file) && !item.key?('replace_config')
                  item['replace_config'] = config_file[source_file].map { |comp| "#{comp}@#{source_file}" }.join(' ')
                  item['config'] = true
                end
              end
            end
          end
          # component configuration will not be added into cmsis project
          # module configuration example:
          #  configuration:
          #    cc-define:
          #      SDK_OS_FREE_RTOS:
          #    tools:
          #      armgcc:
          #        cc-define:
          #          LWIP_TIMEVAL_PRIVATE: 0
          if component.safe_key?('configuration') && component['external_component']
            if @option[:gen_cmsis_project]
              @data_out[proj][comp]['has_component_config'] = true if comp == 'iar'
            else
              component['configuration'].each do |item, content|
                if item == 'tools'
                  content.each do |tool_key, tool_config|
                    @data_out[proj][comp]['targets'].each {|target, target_content| target_content.deep_merge!(tool_config)} if tool_key == comp
                  end
                else
                  compiler['config'].each_key do |target|
                    create_and_deep_merge(@data_out[proj][comp]['targets'][target], item, content)
                  end
                end
              end
            end
          end
          # TODO remove mcux-include
          if component.key?('mcux-include')
            mcux_include_clone = deep_copy(component['mcux-include'])
            # Add cc-include path of modules
            compiler['config'].each_key do |target|
              create_and_deep_merge(@data_out[proj][comp]['targets'][target], 'mcux-include', mcux_include_clone)
            end
          end
          if component.key?('cc-include')
            cc_include_clone = deep_copy(component['cc-include'])
            # If there is a meta-component tag parallel with cc-include
            # then it would be prefix to all meta-component under cc-include:
            if component.key? 'external_component'
              cc_include_meta_component = component['meta-name'] || name
              cc_include_clone.each do |cc_include|
                cc_include['meta-component'] = cc_include_meta_component
                cc_include['component_name'] = name
              end
            end
            # Add cc-include path of modules
            compiler['config'].each_key do |target|
              create_and_deep_merge(@data_out[proj][comp]['targets'][target], 'cc-include', cc_include_clone)
            end
          end
          if component.key?('cx-include')
            cx_include_clone = deep_copy(component['cx-include'])
            # If there is a meta-component tag parallel with cx-include
            # then it would be prefix to all meta-component under cx-include:
            if component.key? 'external_component'
              cx_include_meta_component = component['meta-name'] || name
              cx_include_clone.each do |cx_include|
                cx_include['meta-component'] = cx_include_meta_component
                cx_include['component_name'] = name
              end
            end
            # Add cx-include path of modules
            compiler['config'].each_key do |target|
              create_and_deep_merge(@data_out[proj][comp]['targets'][target], 'cx-include', cx_include_clone)
            end
          end
          if component.key?('as-include')
            as_include_clone = deep_copy(component['as-include'])
            # If there is a meta-component tag parallel with as-include
            # then it would be prefix to all meta-component under as-include:
            if component.key? 'external_component'
              as_include_meta_component = component['meta-name'] || name
              as_include_clone.each do |as_include|
                as_include['meta-component'] = as_include_meta_component
                as_include['component_name'] = name
              end
            end
            # Add as-include path of modules
            compiler['config'].each_key do |target|
              create_and_deep_merge(@data_out[proj][comp]['targets'][target], 'as-include', as_include_clone)
            end
          end
          next unless component.key?('files')
          # Add sources in modules
          # If there is a virtual-dir tag parallel with files, it would be prefix to all virtual-dir under files:
          # If there is a meta-component tag parallel with files, it would be prefix to all meta-component under files:
          # get the meta-name if needed
          source_meta_component = component['meta-name'] || name if component.key? 'external_component'
          # Process the source under files
          sources_clone = deep_copy(component['files'])
          sources_clone.each do |source|
            if source.empty?
              sources_clone.delete(source)
              next
            end
            unless source_meta_component.nil?
              source['meta-component'] = source_meta_component
              source['component_name'] = name
              source['processed'] = 'true'
            end
            # TODO remove virtual-dir
            # mdk is different
            # source['virtual-dir'] = source['virtual-dir'].tr(':', '-') if comp.match('mdk') && source['virtual-dir']
          end
          create_and_deep_merge(@data_out[proj][comp], 'source', sources_clone)
        end

        # align the project name with the one in generator yaml file
        return unless @data_in[proj]['contents'].key?('document')
        if @data_in[proj]['contents']['document'].key?('category')
          @data_in[proj]['contents']['document']['category'] = @data_in[proj]['contents']['document']['category'].tr('\\', '/').split('/')[0..-1].join('/')
        end
        create_and_deep_merge(@data_out[proj][comp], 'document', @data_in[proj]['contents']['document'])
        SDKUtils.raise_nonfatal_error("Project translate error, please check whether provide example #{proj} in common YAML file or whether the name tag is missing under document tag.") unless @data_in[proj]['contents']['document']['name']
      end

      def get_component_content(comp_name, content)
        if @translated_component_module_cache.safe_key? comp_name
          return @translated_component_module_cache[comp_name]
        end
        belong_to = content['belong_to']
        component_content = content
        if belong_to && component_content['external_component']
          tmp_content = @data_set.dig_with_default({}, belong_to, comp_name)
          unless tmp_content.empty?
            component_content['section_info'] = tmp_content['section_info']
            contents = deep_copy(tmp_content['contents'])

            repo_base_path = contents.delete('repo_base_path')
            package_base_path = contents.safe_delete('package_base_path')
            project_base_path = contents.delete('project_base_path')

            INCLUDE_ARRAY.each do |each_type_include|
              next unless contents.key?(each_type_include)

              contents[each_type_include]&.each do |each_include|
                ## Get new include hash
                new_include = deep_copy(each_include)
                new_include.delete('repo_relative_path')
                new_include.delete('package_relative_path')
                new_include.delete('project_relative_path')

                repo_relative_path = each_include['repo_relative_path']
                # path
                new_include['path'] = Pathname.new(File.join(repo_base_path, repo_relative_path)).cleanpath.to_s

                # package, project
                update_package_project_path(each_include, new_include, package_base_path, project_base_path,
                                            repo_relative_path)

                each_include.clear
                each_include.merge!(new_include)
              end
            end
            contents['files']&.each do |each_file|
              ## Get new file
              new_file = deep_copy(each_file)
              new_file.delete('source')
              new_file.delete('repo_relative_path')
              new_file.delete('package_relative_path')
              new_file.delete('project_relative_path')

              source_path = File.dirname(each_file['source'])

              new_file['source'] = Pathname.new(each_file['source']).cleanpath.to_s

              update_package_project_path(each_file, new_file, package_base_path, project_base_path, source_path)

              each_file.clear
              each_file.merge!(new_file)
            end
            component_content.merge!(contents)
          end
          @translated_component_module_cache[comp_name] = component_content
        end
        component_content
      end

      def update_package_project_path(old_data, new_data, package_base_path, project_base_path, repo_relative_path)
        # package_path optional, use path if not provided
        if package_base_path
          package_relative_path = old_data.key?('package_relative_path') ? old_data['package_relative_path'] : repo_relative_path
          new_data['package_path'] =
            Pathname.new(File.join(package_base_path, package_relative_path)).cleanpath.to_s
        end

        # project path, required
        project_relative_path = if old_data.key?('project_relative_path')
                                  old_data['project_relative_path']
                                else
                                  (old_data.key?('package_relative_path') ? old_data['package_relative_path'] : repo_relative_path)
                                end
        new_data['project_path'] =
          Pathname.new(File.join(project_base_path, project_relative_path)).cleanpath.to_s
      end

      def create_and_deep_merge(a, b, c)
        return if c.nil?
        if c.class == Array
          a[b] = [] if a[b].nil?
          a[b] = a[b] + c.dup
        else
          a[b] = {} if a[b].nil?
          a[b].deep_merge(c)
        end
      end

      def translate_project(project_tag)
        @data_out = {}
        @data_in = {project_tag => @data_set[@option[:entry_set]][project_tag]}
        @data_in.each_key do |proj|
          next if @data_in[proj].nil?
          @data_out[proj] = {}
          if @data_in[proj]['section-type'] == 'virtual-library'
            @data_out[proj] = @data_in[proj]
            next
          end
          @data_out[proj]['type'] = @data_in[proj]['section-type'] if @data_in[proj].key?('section-type')
          @data_out[proj]['internal'] = @data_in[proj]['internal'] if @data_in[proj].key?('internal')
          @data_out[proj]['project_tag'] = @data_in[proj]['project_tag'] if @data_in[proj].key?('project_tag')
          @data_out[proj]['ui_control_requires'] = @data_in[proj]['ui_control_requires'] if @data_in[proj].key?('ui_control_requires')
          ### prepare for binary-file and readme file
          unless @data_in[proj].dig_with_default('', 'contents', 'project-root-path').empty?
            @data_out[proj]['outdir'] = Pathname.new(@data_in[proj]['contents']['project-root-path']).cleanpath.to_s
          end
          unless @data_in[proj].dig_with_default([], 'contents', 'document', 'readme').empty?
            @data_out[proj]['readme'] = Pathname.new(File.join(@data_out[proj]['outdir'], 'readme.txt')).cleanpath.to_s
          end

          disabled_toolchains = @data_in[proj].dig_with_default([], 'contents', 'configuration', 'disabled_toolchains') & SUPPORTED_TOOLCHAINS
          if @option[:gen_cmsis_project]
            @data_in[proj].dig_with_default({}, 'contents', 'configuration', 'tools').each {|tool_key, content| disabled_toolchains.push_uniq(tool_key) if content['support_open_CMSIS_devtool'] == false }
          end
          # add mcux => ignore for backward compatibility
          if  @data_in[proj].dig_with_default({}, 'contents', 'configuration', 'tools').safe_key?('mcux') &&  disabled_toolchains.include?('mcux')
            @data_in[proj]['contents']['configuration']['tools']['mcux']['ignore'] = true
          end
          @data_out[proj]['supported_toolchains'] = @data_in[proj].dig_with_default({}, 'contents', 'configuration', 'tools').keys & SUPPORTED_TOOLCHAINS - disabled_toolchains
          # mcux must be kept for  backward compatibility
          @data_out[proj]['supported_toolchains'].push_uniq 'mcux'

          @data_out[proj]['supported_toolchains'].each {|toolchain| convert_rules(proj, toolchain, get_config_file_from_component(proj, @data_in[proj]['contents']['modules']))}

          unless @data_in[proj].dig_with_default({}, 'belong_to').empty?
            @data_out[proj]['belong_to'] = @data_in[proj]['belong_to']
          end
        end
      end

      def get_config_file_from_component(proj, modules)
        config_file = {}
        modules.each do |comp_name, comp_content|
          if comp_content.key?('external_component')
            belong_to = comp_content['belong_to']
            content = @data_set.dig_with_default({}, belong_to, comp_name, 'contents')
            content['files']&.each do |file|
              next if file.nil? || file.empty?
              if file['config']
                file_name = File.basename(file['source'])
                if config_file.key?(file_name) && (!CONFIG_FILE_INGORE_WARN_LIST.include? file_name)
                  @data_problems_logger.warn("#{proj}: DataTranslator found duplicated name for config file #{file_name} in #{comp_name} and #{config_file[file_name].join(' ')}") unless config_file[file_name].include?(comp_name)
                end
                config_file[file_name] = [] unless config_file[file_name]
                config_file[file_name].push_uniq comp_name
              end
            end
          end
        end
        config_file
      end
    end
  end
end
# ********************************************************************
# EOF
# ********************************************************************
