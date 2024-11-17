# frozen_string_literal: true

# ####################################################################
# Copyright 2023 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ####################################################################

module SDKGenerator
  module ProductBuilderUtils
    BUILDER_SOURCE_MAP = {
      'SDKPackProductBuilder' => 'kex_pack_product_builder',
      'SDKSupersetProductBuilder' => 'kex_superset_product_builder',
      'CMSISPackProductBuilder' => 'cmsis_pack_product_builder',
      'SupersetToPackProductBuilder' => 'superset_to_pack_product_builder'
    }.freeze

    BUILDER_GENERATORS_MAP = {
      'SDKPackProductBuilder' => %i[doc_generate component_data_process data_process data_validate dependency_map_generate dependency_process database_dump data_dump
                  check_list_generate integrity_check release_action_process file_copy project_generate
                  process_hook_script cmake_generate manifest_generate SCR_generate SDKPack_build],
      'SDKSupersetProductBuilder' => %i[doc_generate data_process data_validate dependency_process
                  release_action_process file_copy project_generate process_hook_script cmake_generate
                  manifest_generate component_xml_generate webdata_generate misc_generators_run data_dump superset_build],
      'CMSISPackProductBuilder' => %i[doc_generate data_process data_validate data_dump dependency_process post_data_process check_list_generate integrity_check
                  release_action_process file_copy csolution_generate project_generate process_hook_script
                  PDSC_generate SCR_generate CMSISPack_build],
      'SupersetToPackProductBuilder' => %i[load_data dependency_process file_copy manifest_generate SCR_generate webdata_generate SDKPack_build]
    }

    # Get class from class name constant
    # @param [String] class_name
    # @return [Class] Class
    def product_builder_class(class_name)
      Object.const_get(class_name.to_s)
    rescue NameError
      Utils.raise_fatal_error("Undefined class #{class_name.to_s}")
    end
  end
end
