# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Mdk
  module CommonProject

    def add_postbuild_script(target, value, item: 1)
      value.each_with_index do |cmd, index|
        if index == 0
          uvprojx_file.userTab.after_make_run_1(target, true)
          uvprojx_file.userTab.after_make_command_1(target, cmd)
        else
          uvprojx_file.userTab.after_make_run_2(target, true)
          uvprojx_file.userTab.after_make_command_2(target, cmd)
        end
      end
    end

    def add_prebuild_script(target, value, item: 1)
      value.each_with_index do |cmd, index|
        if index == 0
          uvprojx_file.userTab.before_make_run_1(target, true)
          uvprojx_file.userTab.before_make_command_1(target, cmd)
        else
          uvprojx_file.userTab.before_make_run_2(target, true)
          uvprojx_file.userTab.before_make_command_2(target, cmd)
        end
      end
    end

    def add_precompile_command(target, value, item: 1)
      value.each_with_index do |cmd, index|
        if index == 0
          uvprojx_file.userTab.before_compile_run_1(target, true)
          uvprojx_file.userTab.before_compile_command_1(target, cmd)
        else
          uvprojx_file.userTab.before_compile_run_2(target, true)
          uvprojx_file.userTab.before_compile_command_2(target, cmd)
        end
      end
    end

    # get list of all available targets
    def targets
      return @uvprojx_file.targets
    end

    # add source file
    # ==== arguments
    # path      - source file path
    # vdirexpr  - into virtual directory
    def add_source(path, vdirexpr, source_target, *args, **kwargs)
      @uvprojx_file.add_source(path, vdirexpr, source_target)
    end

    def set_source_alwaysBuild(file, vdir, targets, alwaysBuild, *args, **kwargs)
      @uvprojx_file.set_source_alwaysBuild(file, vdir, targets, alwaysBuild)
    end

    # clear all project sources
    def clear_sources!
      @uvprojx_file.clear_sources!
    end

    # clear all FlashDriver info
    def clear_flashDriver!
      @uvprojx_file.clear_flashDriver!
    end

    # add assembler include path 'path' to target 'target'
    # ==== arguments
    # target    - target name
    # path      - include path
    def add_assembler_include(target, path, *args, **kwargs)
      @uvprojx_file.assemblerTab.add_include(target, path)
    end

    # clear assembler include paths of target
    # ==== arguments
    # target    - target name
    def clear_assembler_include!(target)
      @uvprojx_file.assemblerTab.clear_include!(target)
    end

    # add compiler include path 'path' to target 'target'
    # ==== arguments
    # target    - target name
    # path      - include path
    def add_compiler_include(target, path, *_args, **_kwargs)
      if path =~ /--pre:/
        prefix =  @compiler == 'armcc' ? '--preinclude ' : '-include '
        rpath = prefix + path.gsub('--pre:', '')
        @uvprojx_file.compilerTab.add_misc_flag(target, rpath)
      else
        @uvprojx_file.compilerTab.add_include(target, path)
      end
    end

    def set_preinclude_file(target, path, *_args, **_kwargs)
      prefix = @compiler == 'armcc' ? '--preinclude ' : '-include '
      path = prefix + path.gsub('--pre:', '')
      @uvprojx_file.compilerTab.add_misc_flag(target, path)
    end

    # clear compiler include paths of target
    # ==== arguments
    # target    - target name
    def clear_compiler_include!(target)
      @uvprojx_file.compilerTab.clear_include!(target)
    end

    # add assembler 'name' macro of 'value' to target
    # ==== arguments
    # target    - target name
    # name      - name of macro
    # value     - value of macro
    def add_assembler_macro(target, name, value, *args, **kwargs)
      if @compiler == 'armcc'
        if value.nil?
          @uvprojx_file.assemblerTab.add_cpreproc_define(target, "#{name}")
        else
          @uvprojx_file.assemblerTab.add_cpreproc_define(target, "#{name}=#{value}")
        end
      else
        if value.nil?
          @uvprojx_file.assemblerTab.add_define(target, name.to_s)
        else
          @uvprojx_file.assemblerTab.add_define(target, "#{name}=#{value}")
        end
      end
    end

    # clear all assembler macros of target
    # ==== arguments
    # target    - target name
    def clear_assembler_macros!(target)
      @uvprojx_file.assemblerTab.clear_cpreproc_defines!(target)
    end

    # add compiler 'name' macro of 'value' to target
    # ==== arguments
    # target    - target name
    # name      - name of macro
    # value     - value of macro
    def add_compiler_macro(target, name, value, *args, **kwargs)
      if value.nil?
        @uvprojx_file.compilerTab.add_define(target, "#{name}")
      else
        @uvprojx_file.compilerTab.add_define(target, "#{name}=#{value}")
      end
    end

    # clear all compiler macros of target
    # ==== arguments
    # target    - target name
    def clear_compiler_macros!(target)
      @uvprojx_file.compilerTab.clear_defines!(target)
    end

    # add misc control
    # ==== arguments
    # target    - target name
    # value     - misc control strings
    def add_misc_control(target, value, *args, **kwargs)
      @uvprojx_file.compilerTab.add_misc_control(target, value)
    end

    def set_device_vendor(target, value, *_args, **_kwargs)
      if value
        cpu_convert = { 'cortex-m0plus' => 'ARMCM0P', 'cortex-m4' => 'ARMCM4', 'cortex-m7' => 'ARMCM7', 'cortex-m33' => 'ARMCM33' }
        device = []
        compiler_flags = value.join(' ').to_s
        pattern_cpu = /(?i)\s-mcpu=(\S+?)\+?(nodsp)?\s/
        result = compiler_flags.match(pattern_cpu)
        if result && result[1]
          # add cpu info
          cpu = result[1]
          device.push cpu_convert[cpu]
          # add dsp info
          has_dsp = (result[2] != 'nodsp')
          device.push('DSP') if has_dsp && cpu == 'cortex-m33'
          # add float type
          pattern_fpu = /(?i)\s-mfpu=(\S+)\s/
          result_fpu = compiler_flags.match(pattern_fpu)
          if result_fpu
            if cpu == 'cortex-m4'
              device.push('FP')
            elsif cpu == 'cortex-m33'
              device.push('FP') if device.include?('DSP')
            elsif cpu == 'cortex-m7'
              device.push('DP') if result_fpu[1] == 'fpv5-d16'
              device.push('SP') if result_fpu[1] == 'fpv5-sp-d16'
            end
          end
          # add trustzone support
          device.push('TZ') if compiler_flags.match(/\s-mcmse\s/)
        end
        unless device.empty?
          @uvprojx_file.deviceTab.device(target, device.join('_'))
          @uvprojx_file.deviceTab.vendor(target, 'ARM')
        end
      end
    end

    def exclude_building_for_target(target, path, exclude)
      @uvprojx_file.propertiesTab.exclude_building(target, path, exclude)
    end

    def init_output_dir(target)
      @uvprojx_file.outputTab.folder(target, '')
    end
  end
end


