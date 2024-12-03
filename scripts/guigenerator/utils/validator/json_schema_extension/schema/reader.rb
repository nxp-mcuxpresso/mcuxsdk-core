# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
module JSON
  class Schema
    class Reader
      # @param location [#to_s] The location from which to read the schema
      # @return [JSON::Schema]
      # @raise [JSON::Schema::ReadRefused] if +accept_uri+ or +accept_file+
      #   indicated the schema could not be read
      # @raise [JSON::Schema::ParseError] if the schema was not a valid JSON object
      # @raise [JSON::Schema::ReadFailed] if reading the location was acceptable but the
      #   attempt to retrieve it failed
      def read(location)
        uri  = JSON::Util::URI.parse(location.to_s)
        body = if uri.scheme.nil? || uri.scheme == 'file'
                 uri = JSON::Util::URI.file_uri(uri)
                 read_file(Pathname.new(uri.path).expand_path)
               else
                 read_uri(uri)
               end

        # If the uri path targets to yaml file, use yaml libarary to parse the file.
        schema = if uri.path.include? '.yml'
                   YAML.load_file(Pathname.new(uri.path).expand_path)
                 else
                   JSON::Validator.parse(body)
                 end
        JSON::Schema.new(schema, uri)
      end
    end
  end
end
