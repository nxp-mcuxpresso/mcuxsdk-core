# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require 'yaml'
require 'json'
require 'pathname'
require 'json_schemer'
require_relative 'utils'

class JsonSchema
  def self.validate_yaml(schema, data, prettry:true)
    schema = Pathname.new(schema) if schema.is_a? String
    data = YAML.load_file(data) if data.is_a? String
    data = data.stringify_keys
    schemer = JSONSchemer.schema(schema)
    result = schemer.validate(data).to_a
    result.map! {|err| JSONSchemer::Errors.pretty err } if prettry
  end
end
