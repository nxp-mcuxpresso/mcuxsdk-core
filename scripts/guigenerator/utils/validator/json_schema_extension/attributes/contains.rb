# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require 'json-schema/attribute'

module JSON
  class Schema
    class ContainsAttribute < Attribute
      def self.validate(current_schema, data, fragments, processor, validator, options = {})
        return unless data.is_a?(Array)

        contains = current_schema.schema['contains']
        schema = JSON::Schema.new(contains, current_schema.uri, validator)
        data.each_with_index do |item, i|
          schema.validate(item, fragments + [i.to_s], processor, options)
        end
      end
    end
  end
end
