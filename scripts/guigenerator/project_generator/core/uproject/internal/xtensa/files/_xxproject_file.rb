# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../cdt/files/_cproject_file'
require 'logger'
require 'nokogiri'

module Internal
  module Xtensa
    class XXprojectFile
      # attr_reader :xml
      attr_reader :logger
      # attr_reader :operations

      def initialize(template, *_args, logger: nil, **_kwargs)
        @xml    = XmlUtils.load(template)
        @logger = logger || Logger.new(STDOUT)
      end

      private

      # Save file
      # ==== arguments
      # path      - string, file path to save
      def save(path, *_args, **_kargs)
        Core.assert(path.is_a?(String) && !path.empty?) do
          'param must be non-empty string'
        end
        @logger.debug("generate file: #{path}")
        XmlUtils.save(@xml, path)
      end

      private

      # Base tab class to inherit @operations attribute
      class TabBase
        attr_reader :operations

        def initialize(operations, *_args, **_kwargs)
          @operations = operations
        end
      end

      class DocumentOperations
        attr_reader :xml
        attr_reader :targets

        def initialize(xml, *_args, logger: nil, **_kwargs)
          @xml            = xml
          @logger         = logger
        end

        # -----------------------------------------------------------------
        # Create new node recursively if node does not exist
        # @param [String] xpath: xpath expression
        # @return [Nokogiri::XML::Element]: the created node of the xpath
        def create_option_node(xpath)
          option_node = @xml.at_xpath(xpath)
          if option_node.nil?
            matched = xpath.match(/^(.*)\/([^\/]+)/)
            Core.assert(!matched.nil?) do
              "corrupted xpath #{xpath}"
            end
            parent_xpath, node_name = matched.captures
            parent_node = @xml.at_xpath(parent_xpath)
            parent_node = create_option_node(parent_xpath) if parent_node.nil?
            Core.assert(!parent_node.nil?) do
              "not such a node #{parent_xpath}"
            end
            matched = node_name.match(/(\S+)\[(\S+)\]/)
            if matched
              option_node_name, sub_node, sub_node_value = matched.captures
              option_node = Nokogiri::XML::Node.new(option_node_name, @xml)
              # sub_node does not need to add if exists
              unless @xml.at_xpath(parent_xpath + '/' + node_name)
                # add attribute or value
                sub_node&.split(',')&.each do |node_value|
                  node_value.strip!
                  if result = (node_value.match /^@(\S+)=(\S+)/)
                    option_node[result[1]] = result[2].gsub!(/^\"|\"?$/, '')
                  elsif result = (node_value.match /(\S+)=(\S+)/)
                    sub_node = Nokogiri::XML::Node.new(result[1], @xml)
                    sub_node.content = result[2].gsub!(/^\"|\"?$/, '')
                    option_node << sub_node
                  end
                end
              end
            else
              option_node = Nokogiri::XML::Node.new(node_name, @xml)
            end
            parent_node << option_node
          end
          Core.assert(!option_node.nil?) do
            "node of '#{xpath}' does not exist"
          end
          return option_node
        end

        def convert_string(value)
          Core.assert(value.is_a?(String)) do
            "conversion error, value '#{value}' is not a String type"
          end
          return value
        end

        def convert_enum(value, convert)
          Core.assert(convert.key?(value)) do
            "conversion error, value '#{value}' does not exists in enum '#{convert.keys.join(', ')}'"
          end
          return convert[value]
        end

        def convert_boolean(value)
          Core.assert(value.is_a?(TrueClass) || value.is_a?(FalseClass)) do
            "conversion error, value '#{value}' must be a 'true' or 'false'"
          end
          return value ? 'true' : 'false'
        end
      end

      class BuildTab < TabBase
        private

        class BuilderTab < TabBase
          private

          class InternalTab < TabBase
            @@buildCustomSteps = "//xxProperties/propertyGroup[\@name=\"build.custom.steps\"]"

            def add_prebuild_steps(value, *_args, **_kargs)
              content_node = @operations.create_option_node(@@buildCustomSteps + "/pre-build[\@enable=\"true\"]/content")
              content_node.content = value
            end

            def add_prelink_steps(value, *_args, **_kargs)
              content_node = @operations.create_option_node(@@buildCustomSteps + "/pre-link[\@enable=\"true\"]/content")
              content_node.content = value
            end

            def add_postbuild_steps(value, *_args, **_kargs)
              content_node = @operations.create_option_node(@@buildCustomSteps + "/post-build[\@enable=\"true\"]/content")
              content_node.content = value
            end

            def add_preclean_steps(value, *_args, **_kargs)
              content_node = @operations.create_option_node(@@buildCustomSteps + "/pre-clean[\@enable=\"true\"]/content")
              content_node.content = value
            end

            def set_default_target(target)
              content_node = @operations.create_option_node("//xxProperties/propertyGroup[\@name=\"build.property\"]")
              content_node.content = nil
              content_node = @operations.create_option_node("//xxProperties/propertyGroup[\@name=\"build.property\"]" + "/buildTarget[\@defaultTarget=\"#{target.capitalize }\"]")
            end
          end
        end
      end
    end
  end
end
