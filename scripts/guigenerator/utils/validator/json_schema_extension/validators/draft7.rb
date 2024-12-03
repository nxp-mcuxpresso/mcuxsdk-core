# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require 'json-schema/schema/validator'

module JSON
  class Schema
    class Draft7 < Validator
      def initialize
        super
        @attributes = {
            "type" => JSON::Schema::TypeV4Attribute,
            "allOf" => JSON::Schema::AllOfAttribute,
            "anyOf" => JSON::Schema::AnyOfAttribute,
            "oneOf" => JSON::Schema::OneOfAttribute,
            "not" => JSON::Schema::NotAttribute,
            "contains" => JSON::Schema::ContainsAttribute,
            "disallow" => JSON::Schema::DisallowAttribute,
            "format" => JSON::Schema::FormatAttribute,
            "maximum" => JSON::Schema::MaximumAttribute,
            "minimum" => JSON::Schema::MinimumAttribute,
            "minItems" => JSON::Schema::MinItemsAttribute,
            "maxItems" => JSON::Schema::MaxItemsAttribute,
            "minProperties" => JSON::Schema::MinPropertiesAttribute,
            "maxProperties" => JSON::Schema::MaxPropertiesAttribute,
            "uniqueItems" => JSON::Schema::UniqueItemsAttribute,
            "minLength" => JSON::Schema::MinLengthAttribute,
            "maxLength" => JSON::Schema::MaxLengthAttribute,
            "multipleOf" => JSON::Schema::MultipleOfAttribute,
            "const" => JSON::Schema::ConstAttribute,
            "enum" => JSON::Schema::EnumAttribute,
            "properties" => JSON::Schema::PropertiesV4Attribute,
            "propertyNames" => JSON::Schema::PropertyNamesAttribute,
            "required" => JSON::Schema::RequiredAttribute,
            "pattern" => JSON::Schema::PatternAttribute,
            "patternProperties" => JSON::Schema::PatternPropertiesAttribute,
            "additionalProperties" => JSON::Schema::AdditionalPropertiesAttribute,
            "items" => JSON::Schema::ItemsAttribute,
            "additionalItems" => JSON::Schema::AdditionalItemsAttribute,
            "dependencies" => JSON::Schema::DependenciesV4Attribute,
            "extends" => JSON::Schema::ExtendsAttribute,
            "$ref" => JSON::Schema::RefAttribute
        }
        @default_formats = {
            'date-time' => DateTimeV4Format,
            'ipv4' => IP4Format,
            'ipv6' => IP6Format,
            'uri' => UriFormat
        }
        @formats = @default_formats.clone
        @uri = JSON::Util::URI.parse("http://json-schema.org/draft-07/schema#")
        @names = ["draft7", "http://json-schema.org/draft-07/schema#"]
        @metaschema_name = "draft-07.json"
      end

      JSON::Validator.register_validator(self.new)
      JSON::Validator.register_default_validator(self.new)
    end
  end
end
