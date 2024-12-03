# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../common/files/mcux_project_definition_xml'

module Mcux
  module Lib

    class ProjectDefinitionXml < Mcux::Common::ProjectDefinitionXml

      def initialize(template, manifest_version, manifest_schema_dir, *args, logger: nil, **kwargs)
        super(template, manifest_version, manifest_schema_dir, *args, logger: nil, **kwargs)
        @build_type = "lib"
      end
    end
  end
end