# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require_relative 'utils'

module SDKGenerator
  module BuildOptionUtils
    include Utils

    private

    def production_mode?
      @build_option.dig_with_default(false, :production)
    end

    def output_type
      @build_option[:output_type]
    end

    def do_csolution_generate?
      @build_option[:generators].key?(:csolution_generate)
    end

    def set_type
      @build_option[:set_type]
    end

    def board_set
      @build_option[:set][:board]
    end

    def kit_set
      @build_option[:set][:kit]
    end

    def device_set
      @build_option[:set][:device]
    end

    def toolchains
      @build_option[:toolchains]
    end

    def input_dir
      @build_option[:input_dir]
    end

    def run_os
      @build_option.dig_with_default('all', :os)
    end

    def no_sw_set?
      @build_option.dig_with_default(false, :no_sw_set)
    end

    def all_sw_sets?
      @build_option.dig_with_default(false, :all_sw_sets)
    end

    def generate_full_project_list?
      @build_option.dig_with_default(false, :full_project_list)
    end

    def build_dfp?
      return true if output_type.include?('dfp') || output_type.include?('dfp_pdsc')

      false
    end

    def build_swp?
      return true if output_type.include?('swp') || output_type.include?('swp_pdsc')

      false
    end

    def build_bsp?
      return true if output_type.include?('bsp') || output_type.include?('bsp_pdsc')

      false
    end

    def build_sbsp?
      return true if output_type.include?('sbsp') || output_type.include?('sbsp_pdsc')

      false
    end

    def only_build_dfp?
      return true if (output_type.length == 1) && output_type.include?('dfp')
      return true if (output_type.length == 1) && output_type.include?('dfp_pdsc')

      false
    end

    def only_build_swp?
      return true if (output_type.length == 1) && output_type.include?('swp')
      return true if (output_type.length == 1) && output_type.include?('swp_pdsc')

      false
    end

    def only_build_sbsp?
      return true if (output_type.length == 1) && output_type.include?('sbsp')
      return true if (output_type.length == 1) && output_type.include?('sbsp_pdsc')

      false
    end

    def build_bsp_not_build_sbsp?
      if (output_type.include?('bsp') || output_type.include?('bsp_pdsc')) && (!output_type.include?('sbsp') && !output_type.include?('sbsp_pdsc'))
        return true
      end

      false
    end

    def build_sbsp_not_build_bsp?
      if (output_type.include?('sbsp') || output_type.include?('sbsp_pdsc')) && (!output_type.include?('bsp') && !output_type.include?('bsp_pdsc'))
        return true
      end

      false
    end

    def only_build_project?
      return true if output_type.only_include?('project')

      false
    end

    # Get build product from options
    # @return [String] build product for this build
    def build_product
      @build_option.dig_with_default('kex_package', :product)
    end

    # Build CMSIS pack related product
    # @return [TrueClass, FalseClass]
    def build_CMSIS_product?
      build_product == CMSIS
    end

    # Build KEX pack related product
    # @return [TrueClass, FalseClass]
    def build_KEX_product?
      build_product == KEX
    end

    def not_build_bsp_and_build_swp_related?
      if (output_type.include?('swp') || output_type.include?('swp_pdsc') || output_type.include?('sbsp') || output_type.include?('sbsp_pdsc')) && (!output_type.include?('bsp') && !output_type.include?('bsp_pdsc'))
        true
      else
        false
      end
    end

    def device_names
      @build_option.dig_with_default(nil, :set, :device).keys
    end

    def board_names
      @build_option.dig_with_default(nil, :set, :board).keys
    end

    def kit_names
      @build_option.dig_with_default(nil, :set, :kit).keys
    end

    def dump_merged_data?
      @build_option[:output_type].include?('merged_data')
    end

    def output_dir
      @build_option[:output_dir]
    end

    def input_dir
      @build_option[:input_dir]
    end

    def no_arm_core?
      @build_option[:no_arm_core]
    end

    def generate_dependency_map?
      @build_option[:generators].key?(:dependency_map_generate)
    end

    def build_github?
      @build_option[:github_support]
    end

    def output_variable?
      @build_option[:print_variable]
    end
  end
end
