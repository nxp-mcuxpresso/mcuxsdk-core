# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module CodeWarrior
  module CommonProject
      def clear!
        # clear source file in .project
        clear_sources!
        targets.each do |target|
          clear_compiler_include!(target)
          clear_compiler_sys_search_path!(target)
          clear_compiler_sys_path_recursively!(target)
          clear_compiler_macros!(target)
          clear_assembler_include!(target)
          clear_linker_file!(target)
          clear_lib_path!(target)
          clear_addl_lib!(target)
        end
      end

      # get list of all available targets
      def targets
        return @cproject_file.targets
      end

      # add source file
      # ==== arguments
      # path      - source file path
      # vdirexpr  - into virtual directory
      def add_source(path, vdirexpr, *_args, **_kwargs)
        @project_file.add_source(path, vdirexpr)
      end

      def add_library(target, path, *_args, **_kwargs)
        @targetproject_files[target].addlLinkerTab.additionalOptions("#{path}\r\n")
      end

      # clear all project sources
      def clear_sources!
        @project_file.clear_sources!
      end

      # clear include paths of target
      # ==== arguments
      # target    - target name
      def clear_include!
        @cproject_file.includesTab.clear_include!
      end

      # add compiler include path 'path' to target 'target'
      # ==== arguments
      # target    - target name
      # path      - include path
      def add_compiler_include(target, path, *_args, **_kwargs)
        @cproject_file.dscCompilerTab.accessPathsTab.add_user_paths(target, path)
      end

      # add assembler include path 'path' to target 'target'
      # ==== arguments
      # target    - target name
      # path      - include path
      def add_assembler_include(target, path, *_args, **_kwargs)
        @cproject_file.dscAssemblerTab.inputTab.add_user_include(target, path)
      end


      def add_assembler_macro(target, name, value, *args, **kwargs)
        # empty implementation because codewarrior does not support as-define
      end
      # clear compiler include paths of target
      # ==== arguments
      # target    - target name
      def clear_compiler_include!(target)
        @cproject_file.dscCompilerTab.accessPathsTab.clear_include! target
      end

      def clear_compiler_sys_search_path!(target)
        @cproject_file.dscCompilerTab.accessPathsTab.clear_sys_search_path! target
      end

      def clear_compiler_sys_path_recursively!(target)
        @cproject_file.dscCompilerTab.accessPathsTab.clear_sys_path_recursively! target
      end

      def clear_compiler_macros!(target)
        @cproject_file.dscCompilerTab.inputTab.clear_macros! target
      end

      def add_sys_search_path(target, path)
        @cproject_file.dscCompilerTab.accessPathsTab.add_sys_search_path(target, path)
      end

      def add_sys_path_recursively(target, path)
        @cproject_file.dscCompilerTab.accessPathsTab.add_sys_path_recursively(target, path)
      end

      def clear_assembler_include!(target)
        @cproject_file.dscAssemblerTab.inputTab.clear_include! target
      end

      def clear_linker_file!(target)
        @cproject_file.dscLinkerTab.inputTab.clear_linker_file! target
      end

      def clear_lib_path!(target)
        @cproject_file.dscLinkerTab.inputTab.clear_lib_path! target
      end

      def clear_addl_lib!(target)
        @cproject_file.dscLinkerTab.inputTab.clear_addl_lib! target
      end

      def linker_file(target, path, rootdir: nil)
        @cproject_file.dscLinkerTab.inputTab.linker_cmd_file(target, path)
      end

      def add_lib_search_path(target, path, rootdir: nil)
        @cproject_file.dscLinkerTab.inputTab.lib_search_path(target, path)
      end

      def add_addl_lib(target, path, rootdir: nil)
        @cproject_file.dscLinkerTab.inputTab.add_addl_lib(target, path)
      end

      # add compiler 'name' macro of 'value' to target
      # ==== arguments
      # target    - target name
      # name      - name of macro
      # value     - value of macro
      def add_compiler_macro(target, name, value, *_args, **_kwargs)
        if value.nil?
          @cproject_file.dscCompilerTab.inputTab.add_macros(target, name.to_s)
        else
          @cproject_file.dscCompilerTab.inputTab.add_macros(target, "#{name}=#{value}")
        end
      end

      private

      def generate_map(name)
        random_num = name.hash.abs
        res_uuid_map = {'LDM_HPM_OSJTAG' => {'RES' => "#{random_num}.9", 'UUID' => "#{SecureRandom.uuid}"},
                        'LDM_HPM_PnE U-MultiLink' => {'RES' => "#{random_num}.8", 'UUID' => "#{SecureRandom.uuid}"},
                        'LDM_LPM_OSJTAG' => {'RES' => "#{random_num}.7", 'UUID' => "#{SecureRandom.uuid}"},
                        'LDM_LPM_PnE U-MultiLink' => {'RES' => "#{random_num}.6", 'UUID' => "#{SecureRandom.uuid}"},
                        'SDM_HPM_OSJTAG' => {'RES' => "#{random_num}.5", 'UUID' => "#{SecureRandom.uuid}"},
                        'SDM_HPM_PnE U-MultiLink' => {'RES' => "#{random_num}.4", 'UUID' => "#{SecureRandom.uuid}"},
                        'SDM_SPM_OSJTAG' => {'RES' => "#{random_num}.3", 'UUID' => "#{SecureRandom.uuid}"},
                        'SDM_SPM_PnE U-MultiLink' => {'RES' => "#{random_num}.2", 'UUID' => "#{SecureRandom.uuid}"},
                        'SDM_LPM_OSJTAG' => {'RES' => "#{random_num}.1", 'UUID' => "#{SecureRandom.uuid}"},
                        'SDM_LPM_PnE U-MultiLink' => {'RES' => "#{random_num}", 'UUID' => "#{SecureRandom.uuid}"}}
      end
  end
end
