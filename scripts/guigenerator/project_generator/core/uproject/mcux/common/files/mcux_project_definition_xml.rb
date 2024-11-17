# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/mcux/files/_mcux_project_definition_xml'


module Mcux
  module Common

    class ProjectDefinitionXml < Internal::Mcux::ProjectDefinitionXml

      def initialize(template, manifest_version, manifest_schema_dir, *args, logger: nil, **kwargs)
        super(template, manifest_version, manifest_schema_dir, *args, logger: nil, **kwargs)
      end

      def save(path)
        if !File.directory?(File.dirname(path))
          FileUtils.mkdir_p File.dirname(path).gsub("\\", "/")
        end
        super
      end
    end
  end
end