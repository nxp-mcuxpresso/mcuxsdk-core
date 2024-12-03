# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

module Iar
  module CommonProject
    def add_postbuild_script(target, value, item: 1)
      value.each {|cmd| ewp_file.buildactionTab.configurationTab.postbuild_command(target, cmd) }
    end

    def add_prebuild_script(target, value, item: 1)
      value.each {|cmd| ewp_file.buildactionTab.configurationTab.prebuild_command(target, cmd) }
    end

    def add_precompile_command(target, value, item: 1)
      value.each {|cmd| ewp_file.buildactionTab.configurationTab.prebuild_command(target, cmd) }
    end

    # get list of all available targets
    def targets
      return @ewp_file.targets
    end

    # add source file
    # ==== arguments
    # path      - source file path
    # vdirexpr  - into virtual directory
    def add_source(path, vdirexpr, *_args, **_kwargs)
      @ewp_file.add_source(path, vdirexpr)
    end

    # clear all project sources
    def clear_sources!
      @ewp_file.clear_sources!
    end

    # use c++ compiler
    # ==== arguments
    # target    - target name
    # value     - value: compiler string
    def set_cpp_compiler(target, value, *_args, **_kwargs)
      @ewp_file.compilerTab.language1Tab.language(target, value)
    end

    # add assembler include path 'path' to target 'target'
    # ==== arguments
    # target    - target name
    # path      - include path
    def add_assembler_include(target, path, *_args, **_kwargs)
      @ewp_file.assemblerTab.preprocessorTab.add_include(target, path)
    end

    # clear assembler include paths of target
    # ==== arguments
    # target    - target name
    def clear_assembler_include!(target)
      @ewp_file.assemblerTab.preprocessorTab.clear_include!(target)
    end

    # clear compiler include paths of target
    # ==== arguments
    # target    - target name
    def clear_compiler_include!(target)
      @ewp_file.compilerTab.preprocessorTab.clear_include!(target)
    end

    # add assembler 'name' macro of 'value' to target
    # ==== arguments
    # target    - target name
    # name      - name of macro
    # value     - value of macro
    def add_assembler_macro(target, name, value, *_args, **_kwargs)
      if value.nil?
        @ewp_file.assemblerTab.preprocessorTab.add_define(target, name.to_s)
      else
        @ewp_file.assemblerTab.preprocessorTab.add_define(target, "#{name}=#{value}")
      end
    end

    # clear all assembler macros of target
    # ==== arguments
    # target    - target name
    def clear_assembler_macros!(target)
      @ewp_file.assemblerTab.preprocessorTab.clear_defines!(target)
    end

    # add compiler 'name' macro of 'value' to target
    # ==== arguments
    # target    - target name
    # name      - name of macro
    # value     - value of macro
    def add_compiler_macro(target, name, value, *_args, **_kwargs)
      if value.nil?
        @ewp_file.compilerTab.preprocessorTab.add_define(target, name.to_s)
      else
        @ewp_file.compilerTab.preprocessorTab.add_define(target, "#{name}=#{value}")
      end
    end

    # clear all compiler macros of target
    # ==== arguments
    # target    - target name
    def clear_compiler_macros!(target)
      @ewp_file.compilerTab.preprocessorTab.clear_defines!(target)
    end

    def set_dlib_config_file(target, value, *_args, **_kwargs)
      @ewp_file.generalTab.libraryConfigurationTab.library_configuration_file(target, value)
    end

    def use_core_variant(target, value, *_args, **_kwargs)
      @ewp_file.generalTab.targetTab.use_core_variant(target, value)
    end

    def set_preinclude_file(target, path, *_args, **_kwargs)
      @ewp_file.compilerTab.preprocessorTab.add_pre_include(target, path)
    end

    def exclude_building_for_target(target, path, exclude)
      @ewp_file.exclude_building(target, path, exclude)
    end

    def init_output_dir(target)
      @ewp_file.generalTab.outputTab.output_dir(target, '$PROJ_DIR$')
    end
  end
end
