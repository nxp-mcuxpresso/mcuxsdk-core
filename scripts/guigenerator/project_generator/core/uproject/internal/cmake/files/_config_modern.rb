# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require 'fileutils'
require 'tempfile'
require_relative '_config'

module Internal
  module CMake
    GCC_COMPILER_SYS_LIBRARIES = %w[c c_nano gcc nosys m
                           stdc++ stdc++_nano
                           crti.o crtn.o crtbegin.o crtend.o
                           cr_c cr_eabihelpers
                           cr_newlib_semihost cr_newlib_nohost cr_newlib_none cr_semihost cr_semihost_nf cr_semihost_mb cr_semihost_mb_nf cr_nohost_nf
                          ].freeze
    GCC_DEFAULT_SYS_LIBRARIES = %w[m c gcc nosys].freeze

    class ConfigFileModern < Internal::CMake::ConfigFile

      def initialize(template, *args, logger: nil, **kwargs)
        @template =  template
        @config_cmakelists = Tempfile.new('config_cmakelists')
        @logger = logger ? logger : Logger.new(STDOUT)
        @all_include = Array.new()
        @as_include = Array.new()
        @cc_include = Array.new()
        @cxx_include = Array.new()
        @include_path = []
        @as_marco = Hash.new()
        @cc_marco = Hash.new()
        @cxx_marco = Hash.new()
        @ld_marco = Hash.new()
        @link_lib = Hash.new()
        @sys_link_lib = Array.new()
        @non_sys_link_lib = Array.new()
        @target = Array.new()
        @source = Array.new()
        @linker_file = Hash.new()
        @tool_name = ""
        @toolchainfile_path = ""
        @binary_file_name = ""
        @build_type = "app"
        @converted_format = Hash.new()
        @build_artifacts = ['output.map']
        @cc_marco_for_src = Hash.new()
        @prebuild_cmd = []
        @postbuild_cmd = []
        @cmake_modules = []
        @cmake_modules_entry_path = []
        @cmake_files = {}
        @cmake_variables = {}
        @cmake_command = []
        @as_include_for_target = {}
        @cc_marco_str = {}
        @exclude_building = {}
        @output_files_copied = {}
        @fpu = []
        @specs = []
        @debug_console = ""
        @config_info = {'CONFIG_COMPILER' => 'gcc', 'CONFIG_TOOLCHAIN' => 'armgcc', 'CONFIG_USE_COMPONENT_CONFIGURATION' => 'false'}
        @generated_files = []
        @config_file = {}
        @cmake_major_version = 1
        @cmake_minor_version = 0
        @build_dir = {}
      end

      def save(path)

        File.open(@template, 'r').each_line do |line|
          if line.include?('Tutorial_VERSION_MAJOR')
            @config_cmakelists.puts("SET (MCUXPRESSO_CMAKE_FORMAT_MAJOR_VERSION #{@cmake_major_version})")
          elsif line.include?('Tutorial_VERSION_MINOR')
              @config_cmakelists.puts("SET (MCUXPRESSO_CMAKE_FORMAT_MINOR_VERSION #{@cmake_minor_version})")
              @config_cmakelists.puts ""
              @config_cmakelists.puts "include(ide_overrides.cmake OPTIONAL)"
              @config_cmakelists.puts ""
              @config_cmakelists.puts "if(CMAKE_SCRIPT_MODE_FILE)"
              @config_cmakelists.puts "  message(\"${MCUXPRESSO_CMAKE_FORMAT_MAJOR_VERSION}\")"
              @config_cmakelists.puts "  return()"
              @config_cmakelists.puts "endif()"
              @config_cmakelists.puts ""
          elsif line.include?('cmake_minimum_required')
            @config_cmakelists.puts line
            @config_cmakelists.puts ""
            # set SdkRootDirPath
            @config_cmakelists.puts "if (NOT DEFINED SdkRootDirPath)"
            if ENV['standalone'] == 'true'
              @config_cmakelists.puts "    SET(SdkRootDirPath ${CMAKE_CURRENT_LIST_DIR})"
            else
              sdk_path = Pathname.new(ENV['SdkRootDirPath']).relative_path_from(Pathname.new(File.join(ENV['build_dir'], @tool_name))).to_s
              @config_cmakelists.puts "    SET(SdkRootDirPath ${CMAKE_CURRENT_LIST_DIR}/#{sdk_path})"
            end
            @config_cmakelists.puts "endif()"
            @config_cmakelists.puts ""
            @config_cmakelists.puts("include(${CMAKE_CURRENT_LIST_DIR}/config.cmake)\n")
            @config_cmakelists.puts "include(${SdkRootDirPath}/cmake/toolchain/toolchain.cmake)"
          else
            @config_cmakelists.puts line
          end
        end
        flags_cmake = ''
        @config_cmakelists.puts ""
        @config_cmakelists.puts ""

        @config_cmakelists.puts("project(#{File.basename(@project_name, ".*")})\n")
        @config_cmakelists.puts ""

        @config_cmakelists.puts "enable_language(ASM)"
        @config_cmakelists.puts ""

        # add build target info for vscode plugin
        @config_cmakelists.puts "set(MCUX_BUILD_TYPES #{@target.join(' ')})"
        @config_cmakelists.puts ""

        if @build_type == "app"
          @config_cmakelists.puts "set(MCUX_SDK_PROJECT_NAME #{@project_name})"
        else
          @config_cmakelists.puts "set(MCUX_SDK_PROJECT_NAME #{File.basename(@project_name, '.elf')}.a)"
        end
        @config_cmakelists.puts ""

        # set cmake variables
        @cmake_variables.each do |key, val|
          if val
            @config_cmakelists.puts "SET(#{key} #{val})"
          else
            @config_cmakelists.puts "SET(#{key})"
          end
          @config_cmakelists.puts ""
        end

        @config_cmakelists.puts("include(${ProjDirPath}/flags.cmake)\n")
        @config_cmakelists.puts ""

        # prepare flags.cmake content
        if @fpu.length > 0
          flags_cmake += "IF(NOT DEFINED FPU)  \n"
          flags_cmake += "    SET(FPU \"#{@fpu.join(' ')}\")  \n"
          flags_cmake += "ENDIF()  \n"
          flags_cmake += "\n"
        end
        if @specs.length > 0
          flags_cmake += "IF(NOT DEFINED SPECS)  \n"
          flags_cmake += "    SET(SPECS \"#{@specs.join(' ')}\")  \n"
          flags_cmake += "ENDIF()  \n"
          flags_cmake += "\n"
        end
        @debug_console = "-DSDK_DEBUGCONSOLE=1" if @debug_console == ''
        flags_cmake += "IF(NOT DEFINED DEBUG_CONSOLE_CONFIG)  \n"
        flags_cmake += "    SET(DEBUG_CONSOLE_CONFIG \"#{@debug_console}\")  \n"
        flags_cmake += "ENDIF()  \n"
        flags_cmake += "\n"

        @as_marco.each_key do |target|
          flags_cmake += "SET(CMAKE_ASM_FLAGS_#{target.upcase} \" \\\n"
          flags_cmake += "    ${CMAKE_ASM_FLAGS_#{target.upcase}} \\\n"
          @as_marco[target].each do |line|
            flags_cmake += "    #{line} \\\n"
          end
          flags_cmake += "    ${FPU} \\\n"
          flags_cmake += "\")\n"
        end
        @cc_marco.each_key do |target|
          flags_cmake += "SET(CMAKE_C_FLAGS_#{target.upcase} \" \\\n"
          flags_cmake += "    ${CMAKE_C_FLAGS_#{target.upcase}} \\\n"
          @cc_marco[target].each do |line|
            flags_cmake += "    #{line} \\\n"
          end
          flags_cmake += "    ${FPU} \\\n"
          flags_cmake += "    ${DEBUG_CONSOLE_CONFIG} \\\n"
          flags_cmake += "\")\n"
        end
        @cxx_marco.each_key do |target|
          flags_cmake += "SET(CMAKE_CXX_FLAGS_#{target.upcase} \" \\\n"
          flags_cmake += "    ${CMAKE_CXX_FLAGS_#{target.upcase}} \\\n"
          @cxx_marco[target].each do |line|
            flags_cmake += "    #{line} \\\n"
          end
          flags_cmake += "    ${FPU} \\\n"  if @fpu.length > 0
          flags_cmake += "    ${DEBUG_CONSOLE_CONFIG} \\\n"
          flags_cmake += "\")\n"
        end

        @ld_marco.each_key do |target|
          flags_cmake += "SET(CMAKE_EXE_LINKER_FLAGS_#{target.upcase} \" \\\n"
          flags_cmake += "    ${CMAKE_EXE_LINKER_FLAGS_#{target.upcase}} \\\n"
          @ld_marco[target].each do |line|
            flags_cmake += "    #{line} \\\n"
            add_build_artifacts(line)
          end
          flags_cmake += "    ${FPU} \\\n"
          flags_cmake += "    ${SPECS} \\\n"
          @linker_file[target]&.each do |line|
            flags_cmake += "    -T\\\"#{line}\\\" -static \\\n"
          end
          flags_cmake += "\")\n"
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

        if @build_type == "app"
          @config_cmakelists.puts "add_executable(${MCUX_SDK_PROJECT_NAME} "
        else
          @config_cmakelists.puts "add_library(${MCUX_SDK_PROJECT_NAME} STATIC"
        end
        # target specific file should be added separately
        @exclude_building&.keys.each { |file| @source.delete file }
        @source.each do |line|
          @config_cmakelists.puts "\"#{line}\""
        end
        @config_cmakelists.puts ")"
        @config_cmakelists.puts ""

        unless @exclude_building.empty?
          @exclude_building.each do |file, exclude_targets|
            statement = []
            build_targets = @target - exclude_targets
            next if build_targets.empty?

            build_targets.each { |target| statement.concat(["CMAKE_BUILD_TYPE STREQUAL #{target}"]) }
            @config_cmakelists.puts "if(#{statement.join(' OR ')})"
            @config_cmakelists.puts("    target_sources(${MCUX_SDK_PROJECT_NAME} PRIVATE\n")
            @config_cmakelists.puts("        \"#{file}\"")
            @config_cmakelists.puts("    )\n")
            @config_cmakelists.puts "endif(#{statement.join(' OR ')})"
          end
          @config_cmakelists.puts ""
        end

        @config_cmakelists.puts "target_include_directories(${MCUX_SDK_PROJECT_NAME} PRIVATE\n"
        @include_path.each do |path|
          @config_cmakelists.puts "    #{path}\n"
        end
        @config_cmakelists.puts ")\n"
        @config_cmakelists.puts "\n"

        # set config file properties
        @config_file&.each do |path, comp_name|
          @config_cmakelists.puts "set_source_files_properties(\"#{path}\" PROPERTIES COMPONENT_CONFIG_FILE \"#{comp_name.join(' ')}\")\n"
        end
        @config_cmakelists.puts "\n"

        unless @cc_marco_str.empty?
          @cc_marco_str.each do |target, items|
            @config_cmakelists.puts "if(CMAKE_BUILD_TYPE STREQUAL #{target})"
            @config_cmakelists.puts "     target_compile_definitions(${MCUX_SDK_PROJECT_NAME}  PRIVATE #{items.join(' ')})"
            @config_cmakelists.puts "endif(CMAKE_BUILD_TYPE STREQUAL #{target})"
            @config_cmakelists.puts "\n"
          end
        end

        unless @as_include_for_target.empty?
          @as_include_for_target.each do |path, targets|
            next if targets.nil? || targets.empty?

            targets.each do |target|
              @config_cmakelists.puts "if(CMAKE_BUILD_TYPE STREQUAL #{target})"
              @config_cmakelists.puts "    target_include_directories(${MCUX_SDK_PROJECT_NAME} PRIVATE #{path})"
              @config_cmakelists.puts "endif(CMAKE_BUILD_TYPE STREQUAL #{target})"
              @config_cmakelists.puts "\n"
            end
          end
        end

        # add prebuild command
        unless @prebuild_cmd.empty?
          @config_cmakelists.puts "ADD_CUSTOM_TARGET(MCUX_PREBUILD"
          @prebuild_cmd&.each do | cmd |
            @config_cmakelists.puts "COMMAND #{cmd}"
          end
          @config_cmakelists.puts ")"
          @config_cmakelists.puts ""
          @config_cmakelists.puts "ADD_DEPENDENCIES(${MCUX_SDK_PROJECT_NAME} MCUX_PREBUILD)"
          @config_cmakelists.puts ""
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
          @config_cmakelists.puts "ENDIF()"
        end
        # add cmake files
        @cmake_files.each do |path, cache_dir|
          if File.basename(path) == "CMakeLists.txt"
            if cache_dir
              @config_cmakelists.puts "add_subdirectory(#{File.dirname(path)} #{cache_dir})"
            else
              @config_cmakelists.puts "add_subdirectory(#{File.dirname(path)})"
            end
          elsif File.extname(path) == ".cmake"
            @config_cmakelists.puts "include(#{path})"
          end
          @config_cmakelists.puts ""
        end

        # copy files after building
        unless @output_files_copied.empty?
          @output_files_copied&.each do | target, path |
            @config_cmakelists.puts "if(CMAKE_BUILD_TYPE STREQUAL #{target})"
            @config_cmakelists.puts "    ADD_CUSTOM_COMMAND(TARGET ${MCUX_SDK_PROJECT_NAME} POST_BUILD COMMAND"
            @config_cmakelists.puts "    ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${MCUX_SDK_PROJECT_NAME}> #{path}"
            @config_cmakelists.puts "    )"
            @config_cmakelists.puts "endif(CMAKE_BUILD_TYPE STREQUAL #{target})"
          end
          @config_cmakelists.puts ""
        end

        # add user-defined cmake command
        unless @cmake_command.empty?
          @cmake_command.each do |line|
            @config_cmakelists.puts line
            @config_cmakelists.puts ""
          end
        end

        if @build_type == "app"
          if @sys_link_lib.empty?
            @sys_link_lib = GCC_DEFAULT_SYS_LIBRARIES
          end
          @config_cmakelists.puts "IF(NOT DEFINED TARGET_LINK_SYSTEM_LIBRARIES)  \n"
          @config_cmakelists.puts "    SET(TARGET_LINK_SYSTEM_LIBRARIES \"#{@sys_link_lib.map{|item|"-l#{item}"}.join(' ')}\")  \n"
          @config_cmakelists.puts "ENDIF()  \n"
          @config_cmakelists.puts ""

          @config_cmakelists.puts "TARGET_LINK_LIBRARIES(${MCUX_SDK_PROJECT_NAME} PRIVATE -Wl,--start-group)"
          @config_cmakelists.puts ""
          if @non_sys_link_lib.length > 0
            @non_sys_link_lib.each {|lib| @config_cmakelists.puts "target_link_libraries(${MCUX_SDK_PROJECT_NAME} PRIVATE #{lib})"}
            @config_cmakelists.puts ""
          end
          @config_cmakelists.puts "target_link_libraries(${MCUX_SDK_PROJECT_NAME} PRIVATE ${TARGET_LINK_SYSTEM_LIBRARIES})"
          @config_cmakelists.puts ""

          @link_lib.each_key do |target|
            @link_lib[target].each do |line|
              @config_cmakelists.puts "if(CMAKE_BUILD_TYPE STREQUAL #{target})"
              @config_cmakelists.puts "    target_link_libraries(${MCUX_SDK_PROJECT_NAME} PRIVATE #{line})"
              @config_cmakelists.puts "endif(CMAKE_BUILD_TYPE STREQUAL #{target})"
              @config_cmakelists.puts ""
            end
          end

          @config_cmakelists.puts "TARGET_LINK_LIBRARIES(${MCUX_SDK_PROJECT_NAME} PRIVATE -Wl,--end-group)"
          @config_cmakelists.puts ""
          # Converted output file
          @converted_format.each do | format, file_name |
            @config_cmakelists.puts "ADD_CUSTOM_COMMAND(TARGET ${MCUX_SDK_PROJECT_NAME} POST_BUILD COMMAND ${CMAKE_OBJCOPY}"
            @config_cmakelists.puts "-O#{format} ${EXECUTABLE_OUTPUT_PATH}/${MCUX_SDK_PROJECT_NAME} ${EXECUTABLE_OUTPUT_PATH}/#{file_name})"
          end
          @config_cmakelists.puts "" unless @converted_format.empty?
          @config_cmakelists.puts "set_target_properties(${MCUX_SDK_PROJECT_NAME} PROPERTIES ADDITIONAL_CLEAN_FILES \"#{@build_artifacts.join(';')}\")"
        end
        @config_cmakelists.puts ""
        # add postbuild command
        unless @postbuild_cmd.empty?
          @config_cmakelists.puts "ADD_CUSTOM_COMMAND(TARGET ${MCUX_SDK_PROJECT_NAME} POST_BUILD COMMAND"
          @postbuild_cmd&.each do | cmd |
            @config_cmakelists.puts "#{cmd}"
          end
          @config_cmakelists.puts ")"
          @config_cmakelists.puts ""
        end
        @config_cmakelists.close

        directory_path = File.dirname(path)
        @target.each do |target|
          if @build_dir.key? target
            content = "set batch_dir=%~dp0\n"
            content += "if exist \"#{@build_dir[target]}\" (\n"
            content += "  cd #{Pathname.new(@build_dir[target]).parent.to_s}\n"
            content += "  RD /s /Q #{File.basename(@build_dir[target])}\n"
            content += ")\n"
            content += "cd %batch_dir%\n"
            content += "md \"#{@build_dir[target]}\"\n"
            content += "cmake  -G \"Ninja\" -S . -B \"#{@build_dir[target]}\" -DCMAKE_BUILD_TYPE=#{target.downcase} \"#{@build_dir[target]}\"\n"
            content += "cd %batch_dir%/#{@build_dir[target]}\n"
            content += "ninja -j8 2> build_log.txt \n"
          else
            content = "if exist CMakeFiles (RD /s /Q CMakeFiles)\n"
            content += "if exist Makefile (DEL /s /Q /F Makefile)\n"
            content += "if exist cmake_install.cmake (DEL /s /Q /F cmake_install.cmake)\n"
            content += "if exist CMakeCache.txt (DEL /s /Q /F CMakeCache.txt)\n"
            content += "cmake  -G \"Ninja\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n"
            content += "ninja -j8 2> build_log.txt \n"
          end
          File.force_write("#{directory_path}/build_#{target}.bat", content)
          @generated_files.push_uniq "build_#{target}.bat"

          aFile = File.new("#{directory_path}/build_#{target}.sh","wb")
          aFile.chmod(0777)
          aFile.write("#!/bin/sh\n")
          if @build_dir.key? target
            aFile.write("script_dir=$(dirname \"$0\")\n")
            aFile.write("if [ -d \"$script_dir/#{@build_dir[target]}\" ];then rm -rf \"$script_dir/#{@build_dir[target]}\"; fi\n")
            aFile.write("mkdir -p \"$script_dir/#{@build_dir[target]}\"\n")
            aFile.write("cmake  -G \"Ninja\" -S $script_dir -B \"$script_dir/#{@build_dir[target]}\" -DCMAKE_BUILD_TYPE=#{target.downcase}  \"$script_dir/#{@build_dir[target]}\"\n")
            aFile.write("cd $script_dir/#{@build_dir[target]}\n")
            aFile.write("ninja -j 2>&1 | tee build_log.txt\n")
          else
            aFile.write("if [ -d \"CMakeFiles\" ];then rm -rf CMakeFiles; fi\n")
            aFile.write("if [ -f \"Makefile\" ];then rm -f Makefile; fi\n")
            aFile.write("if [ -f \"cmake_install.cmake\" ];then rm -f cmake_install.cmake; fi\n")
            aFile.write("if [ -f \"CMakeCache.txt\" ];then rm -f CMakeCache.txt; fi\n")
            aFile.write("cmake  -G \"Ninja\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n")
            aFile.write("ninja -j 2>&1 | tee build_log.txt\n")
          end
          @generated_files.push_uniq "build_#{target}.sh"
          aFile.close()
        end

        content = ""
        @target.each do |target|
          if @build_dir.key? target
            content += "set batch_dir=%~dp0\n"
            content += "if exist \"#{@build_dir[target]}\" (\n"
            content += "  cd #{Pathname.new(@build_dir[target]).parent.to_s}\n"
            content += "  RD /s /Q #{File.basename(@build_dir[target])}\n"
            content += ")\n"
            content += "cd %batch_dir%\n"
            content += "md \"#{@build_dir[target]}\"\n"
            content += "cmake  -G \"Ninja\" -S . -B \"#{@build_dir[target]}\" -DCMAKE_BUILD_TYPE=#{target.downcase}  \"#{@build_dir[target]}\"\n"
            content += "cd %batch_dir%/#{@build_dir[target]}\n"
            content += "ninja -j8\n"
            content += "\n"
          else
            content += "if exist CMakeFiles (RD /s /Q CMakeFiles)\n"
            content += "if exist Makefile (DEL /s /Q /F Makefile)\n"
            content += "if exist cmake_install.cmake (DEL /s /Q /F cmake_install.cmake)\n"
            content += "if exist CMakeCache.txt (DEL /s /Q /F CMakeCache.txt)\n"
            content += "cmake  -G \"Ninja\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n"
            content += "ninja -j8\n"
            content += "\n"
          end
        end
        content += "IF \"%1\" == \"\" ( pause )\n"
        File.force_write("#{directory_path}/build_all.bat", content)
        @generated_files.push_uniq "build_all.bat"

        aFile = File.new("#{directory_path}/build_all.sh","wb")
        aFile.chmod(0777)
        aFile.write("#!/bin/sh\n")
        @target.each do |target|
          if @build_dir.key? target
            aFile.write("script_dir=$(dirname \"$0\")\n")
            aFile.write("if [ -d \"$script_dir/#{@build_dir[target]}\" ];then rm -rf \"$script_dir/#{@build_dir[target]}\"; fi\n")
            aFile.write("mkdir -p \"$script_dir/#{@build_dir[target]}\"\n")
            aFile.write("cmake  -G \"Ninja\" -S $script_dir -B \"$script_dir/#{@build_dir[target]}\" -DCMAKE_BUILD_TYPE=#{target.downcase}  \"$script_dir/#{@build_dir[target]}\"\n")
            aFile.write("cd $script_dir/#{@build_dir[target]}\n")
            aFile.write("ninja -j\n")
            aFile.write("\n")
          else
            aFile.write("if [ -d \"CMakeFiles\" ];then rm -rf CMakeFiles; fi\n")
            aFile.write("if [ -f \"Makefile\" ];then rm -f Makefile; fi\n")
            aFile.write("if [ -f \"cmake_install.cmake\" ];then rm -f cmake_install.cmake; fi\n")
            aFile.write("if [ -f \"CMakeCache.txt\" ];then rm -f CMakeCache.txt; fi\n")
            aFile.write("cmake  -G \"Ninja\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n")
            aFile.write("ninja -j\n")
            aFile.write("\n")
          end
        end
        aFile.close()
        @generated_files.push_uniq "build_all.sh"

        all_target = "#{@linker_file.keys.join(" ")}"
        unless @build_dir.empty?
          content = "RD \/s \/Q #{all_target}\n"
          @build_dir.values.uniq.each do |path|
            content += "set batch_dir=%~dp0\n"
            content += "if exist \"#{path}\" (\n"
            content += "  cd #{Pathname.new(path).parent.to_s}\n"
            content += "  RD /s /Q #{File.basename(path)}\n"
            content += ")\n"
            content += "cd %batch_dir%\n"
          end
        else
          content = "RD \/s \/Q #{all_target} CMakeFiles\nDEL \/s \/Q \/F Makefile cmake_install.cmake CMakeCache.txt\npause\n"
        end
        File.force_write("#{directory_path}/clean.bat", content)
        @generated_files.push_uniq "clean.bat"

        aFile = File.new("#{directory_path}/clean.sh","wb")
        aFile.chmod(0777)
        unless @build_dir.empty?
          aFile.write("#!/bin/sh\nrm -rf #{all_target} #{@build_dir.values.uniq.join(' ')}\n")
        else
          aFile.write("#!/bin/sh\nrm -rf #{all_target} CMakeFiles\nrm -rf Makefile cmake_install.cmake CMakeCache.txt\n")
        end
        aFile.close()
        @generated_files.push_uniq "clean.sh"

        flags_cmake_module = File.new("#{File.dirname(path)}/flags.cmake","wb")
        flags_cmake_module.chmod(0777)
        flags_cmake_module.write flags_cmake
        flags_cmake_module.close
        @generated_files.push_uniq "flags.cmake"
        # create config.cmake
        unless @config_info.empty?
          config_cmake_module = File.new("#{File.dirname(path)}/config.cmake","wb")
          config_cmake_module.chmod(0777)
          config_cmake_module.write "# config to select component, the format is CONFIG_USE_${component}\n"
          config_cmake_module.write "# Please refer to cmake files below to get available components:\n"
          @cmake_modules_entry_path.each do |path|
            config_cmake_module.write "#  #{path}\n"
          end
          config_cmake_module.write "\n"
          @config_info.each do |key, value|
            config_cmake_module.write "set(#{key} #{value})\n"
          end
          config_cmake_module.close
          @generated_files.push_uniq "config.cmake"
        end
        @generated_files
      end

      # Add assembler include path 'path' to target 'target'
      # ==== arguments
      # target    - target name
      # path      - include path
      def add_assembler_include(target, path, *args, **kwargs)
        @include_path.push("#{path.gsub("\\", "/")}") unless @include_path.include?("#{path.gsub("\\", "/")}")
      end

      def add_compiler_include(target, path, *args, **kwargs)
        @include_path.push("#{path.gsub("\\", "/")}") unless @include_path.include?("#{path.gsub("\\", "/")}")
      end

      def add_cpp_compiler_include(target, path, *args, **kwargs)
        @include_path.push("#{path.gsub("\\", "/")}") unless @include_path.include?("#{path.gsub("\\", "/")}")
      end

      def add_assembler_include_for_target(target, supported_targets, path, *args, **kwargs)
        include_path = path.gsub("\\", "/")
        @as_include_for_target[include_path] = [] unless @as_include_for_target[include_path]
        supported_targets&.split(/\s+/)&.each { |item| @as_include_for_target[include_path].push_uniq item }
      end

      def add_link_library(target, value)
        @link_lib[target] = Array.new unless(@link_lib[target])
        @link_lib[target].push(value)
      end

      def add_sys_link_library(target,value)
        if GCC_COMPILER_SYS_LIBRARIES.include? value
          flag = File.extname(value) == '.o' ? value : "-l#{value}"
          @sys_link_lib.push_uniq(flag)
        else
          @non_sys_link_lib.push_uniq value
        end
      end

      def add_source(path)
        @source.push_uniq(path)
      end

      def add_cmake_module(component)
        @cmake_modules.push_uniq component
      end

      def add_module_path(path)
        @cmake_modules_entry_path.push_uniq path
      end

      def add_cmake_config(components)
        components&.each do |comp|
          @config_info["CONFIG_USE_#{comp.split('.').join('_')}"] = 'true'
        end
      end

      def set_cmake_variables(variables)
        @cmake_variables = variables
      end

      def set_cmake_command(command)
        @cmake_command = command
      end

      def exclude_building(target, path, exclude)
        if exclude
          @exclude_building[path] = [] unless @exclude_building[path]
          @exclude_building[path].push_uniq target
        end
      end

      def copy_output_file(target, path)
        @output_files_copied[target] = path
      end

      def add_as_flags(target, value)
        if value.match(/-mfloat-abi=\S+/) || value.match(/-mfpu=\S+/)
          @fpu.push_uniq value.strip
          Core.assert(@fpu.length <= 2) { "More than one floating point/FPU setting: #{@fpu}" }
          return
        end
        super(target, value)
      end

      def add_cc_flags(target, value)
        if value.match(/-mfloat-abi=\S+/) || value.match(/-mfpu=\S+/)
          @fpu.push_uniq value
          Core.assert(@fpu.length <= 2) { "More than one floating point/FPU setting: #{@fpu}" }
          return
        end
        super(target, value)
      end

      def add_cxx_flags(target, value)
        if value.match(/-mfloat-abi=\S+/) || value.match(/-mfpu=\S+/)
          @fpu.push_uniq value
          Core.assert(@fpu.length <= 2) { "More than one floating point/FPU setting: #{@fpu}" }
          return
        end
        super(target, value)
      end

      def add_linker_flags(target, value)
        if value.match(/-mfloat-abi=\S+/) || value.match(/-mfpu=\S+/)
          @fpu.push_uniq value
          Core.assert(@fpu.length <= 2) { "More than one floating point/FPU setting: #{@fpu}" }
          return
        end
        if value.match(/--specs=\S+/)
          @specs.push_uniq value
          return
        end
        super(target, value)
      end

      def add_linker_system_libraries(libraries)
        libraries&.each { |lib| @sys_link_lib.push_uniq(lib) }
      end

      def add_linker_non_system_libraries(libraries)
        libraries&.each { |lib| @non_sys_link_lib.push_uniq(lib) }
      end

      def add_compiler_macro(target, name, value)
        if name.match(/SDK_DEBUGCONSOLE/)
          if value.nil?
            @debug_console = "-D#{name}"
          else
            @debug_console = "-D#{name}=#{value}"
          end
          return
        end
        super(target, name, value)
      end

      def add_cxx_marco(target, name, value)
        if name.match(/SDK_DEBUGCONSOLE/)
          if value.nil?
            @debug_console = "-D#{name}"
          else
            @debug_console = "-D#{name}=#{value}"
          end
          return
        end
        super(target, name, value)
      end

      def add_hardware_info(project_info)
        @config_info['CONFIG_CORE'] = project_info[:corename]
        @config_info['CONFIG_DEVICE'] = project_info[:platform_devices_soc_name]
        @config_info['CONFIG_BOARD'] = project_info[:board]
        @config_info['CONFIG_KIT'] = project_info[:board_kit] if project_info[:board_kit]
        @config_info['CONFIG_DEVICE_ID'] = project_info[:board_mounted_device_id]
        @config_info['CONFIG_FPU'] = project_info[:fpu] if project_info.safe_key?(:fpu)
        @config_info['CONFIG_DSP'] = project_info[:dsp] if project_info.safe_key?(:dsp)
        @config_info['CONFIG_CORE_ID'] = project_info[:core_id] if project_info.safe_key?(:core_id)
        @config_info['CONFIG_TRUSTZONE'] = project_info[:trustzone] if project_info.safe_key?(:trustzone)
        get_cmake_version(project_info[:sdk_data_version])
      end

      def set_config_file_property(path, comp_name)
        @config_file[path] = [] unless @config_file[path]
        @config_file[path].push_uniq comp_name
      end

      def get_cmake_version(data_version)
        res = data_version.match(/^v(\d+)\.?(\d+)?/)
        if res
          @cmake_major_version = res[1].to_s.to_i - 1
          @cmake_minor_version = res[2] || 0
        end
      end

      def converted_output_file(target, path, rootdir: nil)
        super
        # add converted binary file as build artifact
        @build_artifacts.push_uniq("${EXECUTABLE_OUTPUT_PATH}/#{File.basename(path)}")
      end

      # add trustzone project generated library as build artifact
      def add_build_artifacts(line)
        res = line.match(/-Wl,--out-implib=(\S+)/)
        @build_artifacts.push_uniq(Pathname.new(File.join('${ProjDirPath}', res[1])).cleanpath.to_s) if res
      end

      def add_precompile_command(command)
        add_prebuild_script(command)
      end
    end
  end
end