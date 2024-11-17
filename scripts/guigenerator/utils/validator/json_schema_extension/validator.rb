# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
module JSON
  class Validator
    # Build all schemas with IDs, mapping out the namespace
    def build_schemas(parent_schema)
      schema = parent_schema.schema

      # Build ref schemas if they exist
      if schema["$ref"]
        load_ref_schema(parent_schema, schema["$ref"])
      end

      case schema["extends"]
      when String
        load_ref_schema(parent_schema, schema["extends"])
      when Array
        schema['extends'].each do |type|
          handle_schema(parent_schema, type)
        end
      end

      # Check for schemas in union types
      ["type", "disallow"].each do |key|
        if schema[key].is_a?(Array)
          schema[key].each do |type|
            if type.is_a?(Hash)
              handle_schema(parent_schema, type)
            end
          end
        end
      end

      # Schema properties whose values are objects, the values of which
      # are themselves schemas.
      %w[definitions properties patternProperties].each do |key|
        next unless value = schema[key]
        value.each do |k, inner_schema|
          handle_schema(parent_schema, k, inner_schema)
        end
      end

      # Schema properties whose values are themselves schemas.
      %w[additionalProperties additionalItems dependencies extends].each do |key|
        next unless schema[key].is_a?(Hash)
        handle_schema(parent_schema, key, schema[key])
      end

      # Schema properties whose values may be an array of schemas.
      %w[allOf anyOf oneOf not].each do |key|
        next unless value = schema[key]
        Array(value).each do |inner_schema|
          handle_schema(parent_schema, key, inner_schema)
        end
      end

      # Items are always schemas
      if schema["items"]
        items = schema["items"].clone
        items = [items] unless items.is_a?(Array)

        items.each do |item|
          handle_schema(parent_schema, 'items', item)
        end
      end

      # Convert enum to a ArraySet
      if schema["enum"].is_a?(Array)
        schema["enum"] = ArraySet.new(schema["enum"])
      end

    end

    # Either load a reference schema or create a new schema
    def handle_schema(parent_schema, key=nil, obj)
      if obj.is_a?(Hash)
        schema_uri = parent_schema.uri.dup
        id = [parent_schema.schema['$id'], key].join('/') if key
        schema = JSON::Schema.new(obj, schema_uri, parent_schema.validator, id)
        if obj['id']
          self.class.add_schema(schema)
        end
        build_schemas(schema)
      end
    end
  end
end
