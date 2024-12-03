# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
module JSON
  class Schema
    def initialize(schema,uri,parent_validator=nil,id=nil)
      @schema = schema
      @uri = uri

      # If there is an ID on this schema, use it to generate the URI
      if @schema['id'] && @schema['id'].kind_of?(String)
        temp_uri = JSON::Util::URI.parse(@schema['id'])
        if temp_uri.relative?
          temp_uri = uri.join(temp_uri)
        end
        @uri = temp_uri
      end
      @uri = JSON::Util::URI.strip_fragment(@uri)

      # THe $id is not the same object with that in schema, but only an identifier to track error location
      unless schema.key? '$id'
        schema['$id'] = id
      end

      # If there is a $schema on this schema, use it to determine which validator to use
      if @schema['$schema']
        @validator = JSON::Validator.validator_for_uri(@schema['$schema'])
      elsif parent_validator
        @validator = parent_validator
      else
        @validator = JSON::Validator.default_validator
      end
    end
  end
end
