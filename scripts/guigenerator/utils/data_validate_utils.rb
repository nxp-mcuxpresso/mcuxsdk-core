# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require_relative 'utils'
require_relative 'sdk_utils'
require_relative 'build_option_utils'
module SDKGenerator
  module DataValidateUtils
    include SDKUtils
    include BuildOptionUtils

    def get_data_schema_path
      @project_schema = File.join(input_dir, SCHEMA_V3_BASE, PROJECT_SCHEMA_FILE_NAME)
      @component_schema = File.join(input_dir, SCHEMA_V3_BASE, COMPONENT_SCHEMA_FILE_NAME)
      @project_segment_schema = File.join(input_dir, SCHEMA_V3_BASE, PROJECT_SEGMENT_SCHEMA_FILE_NAME)
      @set_schema = File.join(input_dir, SCHEMA_V3_BASE, SET_SCHEMA_FILE_NAME)
      @scr_schema = File.join(input_dir, SCHEMA_V3_BASE, SCR_SCHEMA_FILE_NAME)
      @license_schema = File.join(input_dir, SCHEMA_V3_BASE, LICENSE_SCHEMA_FILE_NAME)
      @container_schema = File.join(input_dir, SCHEMA_V3_BASE, CONTAINER_SCHEMA_FILE_NAME)
    end

    def update_data_validate_section_type
      @data_validate_section_types = []
      if only_build_project?
        @data_validate_section_types += PROJECT_TYPES
      else
        @data_validate_section_types.push('all')
      end
    end

    def validate_data(section_name, section_content)
      case section_content['section-type']
      when 'application', 'library'
        return unless @data_validate_section_types.include?('all') || @data_validate_section_types.include?('application') || @data_validate_section_types.include?('library')

        validation_project_data_with_schema(@project_schema, section_name, section_content)

      when 'project_segment', 'configuration'
        # @data_merge_logger.info(section_name, "Skip data validation for project segment #{section_name}.")
      when 'license'
        return unless @data_validate_section_types.include?('all') || @data_validate_section_types.include?('license')

        validation_with_schema(@license_schema, section_name, section_content)
      when 'set'
        return unless @data_validate_section_types.include?('all') || @data_validate_section_types.include?('set')

        validation_with_schema(@set_schema, section_name, section_content)
      when 'container'
        # next unless @data_validate_section_types.include?('all') || @data_validate_section_types.include?('container')
        #
        # validation_with_schema(@container_schema, section_name, section_content)
      when 'scr'
        return unless @data_validate_section_types.include?('all') || @data_validate_section_types.include?('scr')

        validation_with_schema(@scr_schema, section_name, section_content)
      when 'component'
        return unless @data_validate_section_types.include?('all') || @data_validate_section_types.include?('component')

        # if only generate project, then required component will be checked after project validation
        validation_with_schema(@component_schema, section_name, section_content)
      else
        # @data_merge_logger.error(section_name,
        #                             "section-type #{section_content['section-type']} is not enabled in data validation.")
      end
    end


    def validation_project_data_with_schema(schema_name, name, content)
      external_component_hash = {}
      content['contents']['modules'].delete_if do |module_name, module_content|
        if module_content.key? 'external_component'
          external_component_hash[module_name] = module_content
          true
        end
      end

      validation_with_schema(schema_name, name, content)

      # add back external_component_hash
      return if external_component_hash.empty?

      content['contents']['modules'].merge!(external_component_hash)
    end

    # ---------------------------------------------------------------------
    # Validate section with schema
    # @param [String] schema_path: schema name for specific section type
    # @param [String] name: section name
    # @param [Hash] content: section content
    def validation_with_schema(schema_path, name, content)
      single_result = JSON::Validator.fully_validate(schema_path, name => content)
      single_result&.each do |each_warning|
        @data_merge_logger.error(name, each_warning)
      end
    end

    # Remove "external_component" from application/library.
    # "external_component" are from individual driver/component/middleware which shall not be validated with project data.
    # @param [Hash] section_data: the section data of a project
    # @return [Nil]
    def remove_external_component(section_data)
      section_data['contents']['modules'].delete_if do |_module_name, module_content|
        module_content.key? 'external_component'
      end
    end

    # Check is file name exceed 100 characters, the limitation comes from ruby gem tar_writer.rb, see https://jira.sw.nxp.com/browse/SDKGEN-2720
    # @param [Hash] data_set
    # @return [Nil]
    def validate_file(data_set, logger)
      data_set.each do |set_name, set_content|
        set_content.each do |section_name, section_content|
          case section_content['section-type']
          when 'application', 'library', 'project_segment', 'configuration'
            modules = section_content.dig_with_default({}, 'contents', 'modules')
            next if modules.empty?

            modules.each do |module_name, module_content|
              next if module_content['external_component']

              validate_name_length(section_name, module_content, logger)
            end
          when 'component', 'container', 'set', 'license'
            validate_name_length(section_name, section_content['contents'], logger)
          end
        end
      end
    end

    def validate_name_length(name, content, logger)
      return if content.nil? || !content.safe_key?('files')

      content['files']&.each do |source|
        next if source.nil? || source.empty?

        if File.basename(source['source']).length > 100
          msg = "#{source['source']} has a too long file name (should be 100 or less)."
          logger.error(name, msg)
        end
      end
    end
  end
end