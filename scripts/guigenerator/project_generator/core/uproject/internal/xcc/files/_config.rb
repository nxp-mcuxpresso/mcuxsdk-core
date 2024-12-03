# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require 'fileutils'
require 'tempfile'
require_relative '../../cmake/files/_config'

module Internal
  module Xcc
    include Internal::CMake
    class ConfigFile < Internal::CMake::ConfigFile
      def initialize(template, targets, *_args, logger: nil, **_kwargs)
        super(template, logger: logger)
        @source_for_target = {}
        # save special options for creating binary file
        @binary_file_option = {}
        @link_lib = {}
        @source = []
        @all_targets = targets
        @generated_files = []
    end

      def save(path)
        @config_cmakelists.puts ''
        @config_cmakelists.puts ''

        @config_cmakelists.puts("project(#{File.basename(@project_name, ".*")})\n")
        @config_cmakelists.puts ""

        @as_marco.each_key do |target|
          @as_marco[target].each do |line|
            @config_cmakelists.puts "SET(CMAKE_ASM_FLAGS_#{target.upcase} \"${CMAKE_ASM_FLAGS_#{target.upcase}} #{line}\")"
            @config_cmakelists.puts ''
          end
        end
        @cc_marco.each_key do |target|
          @cc_marco[target].each do |line|
            @config_cmakelists.puts "SET(CMAKE_C_FLAGS_#{target.upcase} \"${CMAKE_C_FLAGS_#{target.upcase}} #{line}\")"
            @config_cmakelists.puts ''
          end
        end

        @cxx_marco.each_key do |target|
          @cxx_marco[target].each do |line|
            @config_cmakelists.puts "SET(CMAKE_CXX_FLAGS_#{target.upcase} \"${CMAKE_CXX_FLAGS_#{target.upcase}} #{line}\")"
            @config_cmakelists.puts ''
          end
        end

        @ld_marco.each_key do |target|
          @ld_marco[target].each do |line|
            @config_cmakelists.puts "SET(CMAKE_EXE_LINKER_FLAGS_#{target.upcase} \"${CMAKE_EXE_LINKER_FLAGS_#{target.upcase}} #{line}\")"
            @config_cmakelists.puts ''
          end
        end

        @as_include.each do |each|
          @all_include.push(each) unless @all_include.include?(each)
        end
        @cc_include.each do |each|
          @all_include.push(each) unless @all_include.include?(each)
        end
        @cxx_include.each do |each|
          @all_include.push(each) unless @all_include.include?(each)
        end

        @all_include.each do |line|
          line = line.split(/\s+/)
          if line[1] && line[0].split('/').include?(line[1])
            @config_cmakelists.puts "if(CMAKE_BUILD_TYPE STREQUAL #{line[1]})"
            @config_cmakelists.puts "include_directories(#{line[0]})"
            @config_cmakelists.puts "endif(CMAKE_BUILD_TYPE STREQUAL #{line[1]})"
          else
            @config_cmakelists.puts "include_directories(#{line[0]})"
          end
          @config_cmakelists.puts ''
        end

        unless @source_for_target.empty?
          @all_targets.each do | target |
            @config_cmakelists.puts "IF(${CMAKE_BUILD_TYPE} STREQUAL #{target})"
            if @build_type == 'app'
              @config_cmakelists.puts "add_executable(#{@project_name} "
            else
              @config_cmakelists.puts "add_library(#{@binary_file_name}.a STATIC"
            end
            @source.each do |line|
              @config_cmakelists.puts "\"#{line}\""
            end
            @source_for_target[target].each { |line| @config_cmakelists.puts "\"#{line}\"" } unless @source_for_target[target].nil? || @source_for_target[target].empty?
            @config_cmakelists.puts ')'
            @config_cmakelists.puts "ENDIF()"
            @config_cmakelists.puts ''
          end
        else
          if @build_type == 'app'
            @config_cmakelists.puts "add_executable(#{@project_name} "
          else
            @config_cmakelists.puts "add_library(#{@binary_file_name}.a STATIC"
          end
          @source.each do |line|
            @config_cmakelists.puts "\"#{line}\""
          end
          @config_cmakelists.puts ')'
          @config_cmakelists.puts ''
        end

        # set compiler flag for file
        unless @cc_marco_for_src.nil? || @cc_marco_for_src.empty?
          # this flag is used to control the adding of IF and ELSEIF statement
          judge_flag = 1
          @cc_marco_for_src.each do |target, value|
            if judge_flag == 1
              @config_cmakelists.puts "IF(CMAKE_BUILD_TYPE MATCHES #{target})"
              judge_flag = 0
            else
              @config_cmakelists.puts "ELSEIF(CMAKE_BUILD_TYPE MATCHES #{target})"
            end
            value.each do |item|
              @config_cmakelists.puts "  set_source_files_properties(#{item['path']} PROPERTIES COMPILE_FLAGS \"#{item['flag']}\")"
            end
          end
          @config_cmakelists.puts 'ENDIF()'
        end

        @config_cmakelists.puts ''
        if @build_type == 'app'
          @linker_file.each_key do |target|
            @linker_file[target].each do |line|
              @config_cmakelists.puts "set(CMAKE_EXE_LINKER_FLAGS_#{target.upcase} \"${CMAKE_EXE_LINKER_FLAGS_#{target.upcase}} -T#{line} -static\")"
              @config_cmakelists.puts ''
            end
          end
          unless @sys_link_lib.empty? && @link_lib.empty?
            @config_cmakelists.puts "TARGET_LINK_LIBRARIES(#{@project_name} -Wl,--start-group)"
            @sys_link_lib.each_key do |target|
              @sys_link_lib[target].each do |line|
                if target.casecmp('DEBUG').zero?
                  @config_cmakelists.puts "target_link_libraries(#{@project_name} debug #{line})"
                else
                  @config_cmakelists.puts "target_link_libraries(#{@project_name} optimized #{line})"
                end
                @config_cmakelists.puts ''
              end
            end
            @link_lib.each_key do |target|
              @link_lib[target].each do |line|
                @config_cmakelists.puts ''
                if target.casecmp('DEBUG').zero?
                  @config_cmakelists.puts "target_link_libraries(#{@project_name} debug #{line})"
                else
                  @config_cmakelists.puts "target_link_libraries(#{@project_name} optimized #{line})"
                end
                @config_cmakelists.puts ''
              end
            end
            @config_cmakelists.puts "TARGET_LINK_LIBRARIES(#{@project_name} -Wl,--end-group)"
          end
          @config_cmakelists.puts ''
          # Converted output file
          @converted_format.each do |file_name, format|
            @config_cmakelists.puts "ADD_CUSTOM_COMMAND(TARGET #{@project_name} POST_BUILD COMMAND ${CMAKE_OBJCOPY}"
            @config_cmakelists.puts "--xtensa-params= -O#{format} ${EXECUTABLE_OUTPUT_PATH}/#{@project_name} ${EXECUTABLE_OUTPUT_PATH}/../#{file_name}"
            @binary_file_option[file_name]&.each do |option|
              @config_cmakelists.puts option
            end
            @config_cmakelists.puts ')'
            @config_cmakelists.puts ''
          end
        end
        @config_cmakelists.close

        directory_path = File.dirname(path)
        @target.each do |target|
          if target == 'debug'
            content  = "cmake -DCMAKE_TOOLCHAIN_FILE=\"#{@toolchainfile_path}\" -G \"MinGW Makefiles\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n"
            content += "mingw32-make -j 2> build_log.txt \nIF \"%1\" == \"\" ( pause ) \n"
          else
            content  = "cmake -DCMAKE_TOOLCHAIN_FILE=\"#{@toolchainfile_path}\" -G \"MinGW Makefiles\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n"
            content += "mingw32-make -j\nIF \"%1\" == \"\" ( pause ) \n"
          end
          File.force_write("#{directory_path}/build_#{target}.bat", content)
          @generated_files.push_uniq "build_#{target}.bat"

          aFile = File.new("#{directory_path}/build_#{target}.sh", 'wb')
          aFile.chmod(0o777)
          aFile.write("#!/bin/sh\n")
          aFile.write("cmake -DCMAKE_TOOLCHAIN_FILE=\"#{@toolchainfile_path}\" -G \"Unix Makefiles\" -DCMAKE_BUILD_TYPE=#{target.downcase} .\n")
          aFile.write("make -j\n")
          aFile.close
          @generated_files.push_uniq "build_#{target}.sh"
        end

        content = ''
        @target.each do |target|
          content += "cmake -DCMAKE_TOOLCHAIN_FILE=\"#{@toolchainfile_path}\" -G \"MinGW Makefiles\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n"
          content += "mingw32-make -j\n"
        end
        content += "IF \"%1\" == \"\" ( pause )\n"
        File.force_write("#{directory_path}/build_all.bat", content)
        @generated_files.push_uniq "build_all.bat"

        aFile = File.new("#{directory_path}/build_all.sh", 'wb')
        aFile.chmod(0o777)
        aFile.write("#!/bin/sh\n")
        @target.each do |target|
          aFile.write("cmake -DCMAKE_TOOLCHAIN_FILE=\"#{@toolchainfile_path}\" -G \"Unix Makefiles\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n")
          aFile.write("make -j\n")
        end
        aFile.close
        @generated_files.push_uniq "build_all.sh"

        all_target = @all_targets.join(' ').to_s.downcase
        content = "RD \/s \/Q #{all_target} CMakeFiles\nDEL \/s \/Q \/F Makefile cmake_install.cmake CMakeCache.txt\npause\n"
        File.force_write("#{directory_path}/clean.bat", content)
        @generated_files.push_uniq "clean.bat"

        aFile = File.new("#{directory_path}/clean.sh", 'wb')
        aFile.chmod(0o777)
        aFile.write("#!/bin/sh\nrm -rf #{all_target} CMakeFiles\nrm -rf Makefile cmake_install.cmake CMakeCache.txt\n")
        aFile.close
        @generated_files.push_uniq "clean.sh"
        end

      def add_binary_options(_target, path, option)
        @binary_file_option[path] = [] unless @binary_file_option[path]
        @binary_file_option[path].push_uniq option
      end

      def add_link_library(target, value)
        @link_lib[target] = Array.new unless(@link_lib[target])
        @link_lib[target].push(value)
      end

      def add_source(path)
        @source.push_uniq(path)
      end

      def add_target_source(path, targets)
        targets&.each do | target |
          @source_for_target[target] = [] unless @source_for_target[target]
          @source_for_target[target].push_uniq path
        end
      end

      def converted_output_file(_target, path, rootdir: nil)
        format_map = {
          'bin' => 'binary',
          'hex' => 'ihex',
          'srec' => 'srec',
          'symbolsrec' => 'symbolsrec'
        }
        output_name = File.basename(path)
        format = output_name.split('.')[1]

        @converted_format[path] = format_map[format]
      end
      end
    end
end
