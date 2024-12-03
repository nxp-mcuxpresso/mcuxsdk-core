# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require 'fileutils'
require 'tempfile'


module Internal
module CMake

    class ConfigFile

        def initialize(template, *args, logger: nil, **kwargs)
            @config_cmakelists = Tempfile.new('config_cmakelists')
            @logger = logger ? logger : Logger.new(STDOUT)
            File.open(template, 'r').each_line do |line|
              @config_cmakelists.puts line
            end            
            @all_include = Array.new()
            @as_include = Array.new()
            @cc_include = Array.new()
            @cxx_include = Array.new()
            @as_marco = Hash.new()
            @cc_marco = Hash.new()
            @cxx_marco = Hash.new()
            @ld_marco = Hash.new()
            @link_lib = Hash.new()
            @sys_link_lib = Hash.new()
            @target = Array.new()
            @source = Array.new()
            @linker_file = Hash.new()
            @tool_name = ""
            @toolchainfile_path = ""
            @binary_file_name = ""
            @build_type = "app"
            @converted_format = Hash.new()
            @cc_marco_for_src = Hash.new()
            @prebuild_cmd = []
            @postbuild_cmd = []
            @cmake_variables = {}
            @cmake_files = {}
            @cc_marco_str = {}
        end

        def set_toolchainfile_path(name,path)
            @tool_name = name
            @toolchainfile_path = path
        end

        def save(path)
            @config_cmakelists.puts ""
            # set SdkRootDirPath
            @config_cmakelists.puts "if (NOT DEFINED SdkRootDirPath)"
            @config_cmakelists.puts "    SET(SdkRootDirPath #{@root_dir})"
            @config_cmakelists.puts "endif()"
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

            @config_cmakelists.puts ""

            @as_marco.each_key do |target|
              @as_marco[target].each do |line|
                @config_cmakelists.puts "SET(CMAKE_ASM_FLAGS_#{target.upcase} \"${CMAKE_ASM_FLAGS_#{target.upcase}} #{line}\")"
                @config_cmakelists.puts ""
              end
            end
            @cc_marco.each_key do |target|
              @cc_marco[target].each do |line|
                @config_cmakelists.puts "SET(CMAKE_C_FLAGS_#{target.upcase} \"${CMAKE_C_FLAGS_#{target.upcase}} #{line}\")"
                @config_cmakelists.puts ""
              end
            end
            @cxx_marco.each_key do |target|
              @cxx_marco[target].each do |line|
                @config_cmakelists.puts "SET(CMAKE_CXX_FLAGS_#{target.upcase} \"${CMAKE_CXX_FLAGS_#{target.upcase}} #{line}\")"
                @config_cmakelists.puts ""
              end
            end

            @ld_marco.each_key do |target|
                @ld_marco[target].each do |line|
                  @config_cmakelists.puts "SET(CMAKE_EXE_LINKER_FLAGS_#{target.upcase} \"${CMAKE_EXE_LINKER_FLAGS_#{target.upcase}} #{line}\")"
                  @config_cmakelists.puts ""
                end
            end

            unless @cc_marco_str.empty?
              @cc_marco_str.each do |target, items|
                @config_cmakelists.puts "if(CMAKE_BUILD_TYPE STREQUAL #{target})"
                items.each do |item|
                  @config_cmakelists.puts "     ADD_DEFINITIONS(-D#{item})"
                end
                @config_cmakelists.puts "endif(CMAKE_BUILD_TYPE STREQUAL #{target})"
                @config_cmakelists.puts "\n"
              end
            end

            @as_include.each do |each|
                unless @all_include.include?(each)
                    @all_include.push(each)             
                end
            end
            @cc_include.each do |each|
                unless @all_include.include?(each)
                    @all_include.push(each)                    
                end
            end
            @cxx_include.each do |each|
                unless @all_include.include?(each)
                    @all_include.push(each)                    
                end
            end

            @all_include.each do |line|
                line = line.split(/\s+/)
                target_matched = line[1] && lambda {
                  line[0].split('/').each do |item|
                    return true if line[1].include? item
                  end
                  false
                }.call
                if target_matched
                    @config_cmakelists.puts "if(CMAKE_BUILD_TYPE STREQUAL #{line[1].to_s})"
                    @config_cmakelists.puts "include_directories(#{line[0].to_s})"
                    @config_cmakelists.puts "endif(CMAKE_BUILD_TYPE STREQUAL #{line[1].to_s})"
                else
                    @config_cmakelists.puts "include_directories(#{line[0].to_s})"
                end
                @config_cmakelists.puts ""
            end
                
            if @build_type == "app"
              @config_cmakelists.puts "add_executable(#{@project_name} "
            else
              @config_cmakelists.puts "add_library(#{@binary_file_name}.a STATIC"
            end
            @source.each do |line|
               @config_cmakelists.puts "\"#{line}\""
            end
            @config_cmakelists.puts ")"
            @config_cmakelists.puts ""

            # add prebuild command
            unless @prebuild_cmd.empty?
              @config_cmakelists.puts "ADD_CUSTOM_COMMAND(TARGET #{@project_name} PRE_BUILD COMMAND"
              @prebuild_cmd&.each do | cmd |
                @config_cmakelists.puts "#{cmd}"
              end
              @config_cmakelists.puts ")"
              @config_cmakelists.puts ""
            end

#            @config_cmakelists.puts "IF(USE_SPLINT)"
#            @config_cmakelists.puts ""
#            if @build_type == "app"
#              @source.each do |line|
#                @config_cmakelists.puts "add_splint (#{@project_name} #{line})"
#              end
#            else
#              @source.each do |line|
#                @config_cmakelists.puts "add_splint (#{@binary_file_name}.a #{line})"
#              end
#            end
#            @config_cmakelists.puts "ENDIF(USE_SPLINT)"

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

            @config_cmakelists.puts ""
            if @build_type == "app"
              @linker_file.each_key do |target|
                @linker_file[target].each do |line|
                  @config_cmakelists.puts "set(CMAKE_EXE_LINKER_FLAGS_#{target.upcase} \"${CMAKE_EXE_LINKER_FLAGS_#{target.upcase}} -T#{line} -static\")"
                  @config_cmakelists.puts ""
                end
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

              @config_cmakelists.puts "TARGET_LINK_LIBRARIES(#{@project_name} -Wl,--start-group)"
              @sys_link_lib.each_key do |target|
                @sys_link_lib[target].each do |line|
                  if target.upcase == "DEBUG"
                    @config_cmakelists.puts "target_link_libraries(#{@project_name} debug #{line})"
                  else
                    @config_cmakelists.puts "target_link_libraries(#{@project_name} optimized #{line})"
                  end
                  @config_cmakelists.puts ""
                end
              end
              @link_lib.each_key do |target|
                @link_lib[target].each do |line|
                  @config_cmakelists.puts "link_directories(#{File.dirname(line)})"
                  @config_cmakelists.puts ""
                  if target.upcase == "DEBUG"
                    @config_cmakelists.puts "target_link_libraries(#{@project_name} debug #{line})"
                  else
                    @config_cmakelists.puts "target_link_libraries(#{@project_name} optimized #{line})"
                  end
                  @config_cmakelists.puts ""
                end
              end

              @config_cmakelists.puts "TARGET_LINK_LIBRARIES(#{@project_name} -Wl,--end-group)"
              @config_cmakelists.puts ""
              # Converted output file
              @converted_format.each do | format, file_name |
                  @config_cmakelists.puts "ADD_CUSTOM_COMMAND(TARGET #{@project_name} POST_BUILD COMMAND ${CMAKE_OBJCOPY}"
                  @config_cmakelists.puts "-O#{format} ${EXECUTABLE_OUTPUT_PATH}/#{@project_name} ${EXECUTABLE_OUTPUT_PATH}/#{file_name})"
              end
            end
            @config_cmakelists.puts ""
            # add postbuild command
            unless @postbuild_cmd.empty?
              @config_cmakelists.puts "ADD_CUSTOM_COMMAND(TARGET #{@project_name} POST_BUILD COMMAND"
              @postbuild_cmd&.each do | cmd |
                @config_cmakelists.puts "#{cmd}"
              end
              @config_cmakelists.puts ")"
              @config_cmakelists.puts ""
            end
            @config_cmakelists.close

            #@config_cmakelists.puts "add_library(#{@project_name} STATIC"
            #@source.each do |line|
            #  @config_cmakelists.puts "\"#{line}\""
            #end
            #@config_cmakelists.puts ")"
            #@config_cmakelists.close
            #FileUtils.mv @config_cmakelists.path, path

            directory_path = File.dirname(path)
            @target.each do |target|
                if target == "debug"
                    content  = "cmake -DCMAKE_TOOLCHAIN_FILE=\"#{@toolchainfile_path}\" -G \"MinGW Makefiles\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n"
                    content += "mingw32-make -j 2> build_log.txt \nIF \"%1\" == \"\" ( pause ) \n"
                else
                    content  = "cmake -DCMAKE_TOOLCHAIN_FILE=\"#{@toolchainfile_path}\" -G \"MinGW Makefiles\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n"
                    content += "mingw32-make -j 2> build_log.txt \nIF \"%1\" == \"\" ( pause ) \n"
                end
                File.force_write("#{directory_path}/build_#{target}.bat", content)

                aFile = File.new("#{directory_path}/build_#{target}.sh","wb")
                aFile.chmod(0777)
                aFile.write("#!/bin/sh\n")
                aFile.write("cmake -DCMAKE_TOOLCHAIN_FILE=\"#{@toolchainfile_path}\" -G \"Unix Makefiles\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n")
                aFile.write("make -j 2>&1 | tee build_log.txt\n")
                aFile.close()
            end

            content = ""
            @target.each do |target|
                content += "cmake -DCMAKE_TOOLCHAIN_FILE=\"#{@toolchainfile_path}\" -G \"MinGW Makefiles\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n"
                content += "mingw32-make -j\n"
            end
            content += "IF \"%1\" == \"\" ( pause )\n"
            File.force_write("#{directory_path}/build_all.bat", content)

            aFile = File.new("#{directory_path}/build_all.sh","wb")
            aFile.chmod(0777)
            aFile.write("#!/bin/sh\n")
            @target.each do |target|
                aFile.write("cmake -DCMAKE_TOOLCHAIN_FILE=\"#{@toolchainfile_path}\" -G \"Unix Makefiles\" -DCMAKE_BUILD_TYPE=#{target.downcase}  .\n")
                aFile.write("make -j\n")
            end
            aFile.close()

            all_target = "#{@linker_file.keys.join(" ")}"
            content = "RD \/s \/Q #{all_target} CMakeFiles\nDEL \/s \/Q \/F Makefile cmake_install.cmake CMakeCache.txt\npause\n"
            File.force_write("#{directory_path}/clean.bat", content)

            aFile = File.new("#{directory_path}/clean.sh","wb")
            aFile.chmod(0777)
            aFile.write("#!/bin/sh\nrm -rf #{all_target} CMakeFiles\nrm -rf Makefile cmake_install.cmake CMakeCache.txt\n")
            aFile.close()

            #reference from http://www.vtk.org/Wiki/PC-Lint
            #sFile = File.new("#{directory_path}/splint.cmake","wb")
            #sFile.write("
            #function(add_splint NAME FILE)\n
            #    get_directory_property(lint_include_directories INCLUDE_DIRECTORIES)\n
            #    get_directory_property(lint_defines COMPILE_DEFINITIONS)\n
            #    message(STATUS \"Adding split for ${NAME}, ${FILE}.\")\n
            #    # prepend each include directory with \"-i\"; also quotes the directory \n
            #    set(lint_include_directories_transformed)\n
            #    foreach(include_dir ${lint_include_directories})\n
            #      list(APPEND lint_include_directories_transformed -I\"${include_dir}\")\n
            #    endforeach(include_dir)\n
            #    # prepend each definition with \"-d\" \n
            #    set(lint_defines_transformed)\n
            #    foreach(definition ${lint_defines})\n
            #      list(APPEND lint_defines_transformed -D${definition})\n
            #    endforeach(definition)\n
            #    if( FILE MATCHES \\\\.c$ )\n
            #        get_filename_component(sourcefile_abs ${FILE} ABSOLUTE)\n
            #        add_custom_command(TARGET ${NAME}\n
            #        POST_BUILD WORKING_DIRECTORY \n
            #        COMMAND -splint +posixlib -D__builtin_va_list=va_list -D__gnuc_va_list=va_list -unrecog -varuse -warnflags \n
            #        -sysunrecog \n
            #        -weak +skip-sys-headers -preproc +posixlib -unrecogdirective \n
            #        -type -unrecogcomments \n
            #        ${lint_include_directories_transformed} \n
            #        ${lint_defines} \n
            #        ${sourcefile_abs}\n
            #    VERBATIM )\n
            #    endif()\n
            #endfunction(add_splint)\n"
            #)
            #sFile.close()


        end

        # Add assembler include path 'path' to target 'target'
        # ==== arguments
        # target    - target name
        # path      - include path
        def add_assembler_include(target, path, *args, **kwargs)
            unless @as_include.include?("#{path.gsub("\\", "/")}")
                @as_include.push("#{path.gsub("\\", "/")} #{target}")
            end
        end

        # Clear assembler include paths of target
        # ==== arguments
        # target    - target name
        def clear_assembler_include!(target)
            @as_include.clear
        end

        # Add compiler include path 'path' to target 'target'
        # ==== arguments
        # target    - target name
        # path      - include path
        def add_compiler_include(target, path, *args, **kwargs)
            unless @cc_include.include?("#{path.gsub("\\", "/")}")
                @cc_include.push("#{path.gsub("\\", "/")}")
            end
        end

        # Clear compiler include paths of target
        # ==== arguments
        # target    - target name
        def clear_compiler_include!(target)
            @cc_include.clear
        end

        # Add compiler include path 'path' to target 'target'
        # ==== arguments
        # target    - target name
        # path      - include path
        def add_cpp_compiler_include(target, path, *args, **kwargs)
            unless @cxx_include.include?("#{path.gsub("\\", "/")}")
                @cxx_include.push("#{path.gsub("\\", "/")}")
            end
        end

        # Clear compiler include paths of target
        # ==== arguments
        # target    - target name
        def clear_cpp_compiler_include!(target)
            @cxx_include.clear
        end

        # Add assembler 'name' macro of 'value' to target
        # ==== arguments
        # target    - target name
        # name      - name of macro
        # value     - value of macro
        def add_assembler_macro(target, name, value)
            @as_marco[target] = Array.new unless(@as_marco[target])
            if value.nil?
              @as_marco[target].push("-D#{name}")
            else
              @as_marco[target].push("-D#{name}=#{value}")
            end
            # @uvproj_file.assemblerTab.add_define(target, "#{name}=#{value}")
        end

        # Clear all assembler macros of target
        # ==== arguments
        # target    - target name
        def clear_assembler_macros!(target)
            @as_marco[target].clear if @as_marco.has_key?(target)
        end

        # Add compiler 'name' macro of 'value' to target
        # ==== arguments
        # target    - target name
        # name      - name of macro
        # value     - value of macro
        def add_compiler_macro(target, name, value)
            @cc_marco[target] = Array.new unless(@cc_marco[target])
            if value.nil?
              @cc_marco[target].push("-D#{name}")
            else
              result = value.to_s.match(/\\"(\S+)\\"/)
              if result && result[1]
                @cc_marco_str[target] = [] unless @cc_marco_str[target]
                @cc_marco_str[target].push_uniq "#{name}=\"#{result[1]}\""
              else
                @cc_marco[target].push("-D#{name}=#{value}")
              end
            end
        end

        # undefine compiler 'name' macro of 'value' to target
        # ==== arguments
        # target    - target name
        # name      - name of macro
        # value     - value of macro
        def undefine_compiler_macro(target, name, value)
            @cc_marco[target] = Array.new unless(@cc_marco[target])
            if value.nil?
              @cc_marco[target].push("-U#{name}")
            else
              @cc_marco[target].push("-U#{name}=#{value}")
            end
        end

        # Clear all compiler macros of target
        # ==== arguments
        # target    - target name
        def clear_compiler_macros!(target)
            @cc_marco[target].clear if @cc_marco.has_key?(target)
        end

        def add_cxx_marco(target, name,value, *args, **kwargs)
            @cxx_marco[target] = Array.new unless(@cxx_marco[target])
            if value.nil?
              @cxx_marco[target].push("-D#{name}")
            else
              @cxx_marco[target].push("-D#{name}=#{value}")
            end
        end

        def clear_cxx_marcos!(target)
           @cxx_marco[target].clear if @cxx_marco.has_key?(target)
        end

        def add_as_flags(target, value)
            @as_marco[target] = Array.new unless(@as_marco[target])
            @as_marco[target].push("#{value}")
        end

        def add_cc_flags(target, value)
            @cc_marco[target] = Array.new unless(@cc_marco[target])
            @cc_marco[target].push("#{value}")
        end

        def add_cc_flags_for_src(target, path, flag)
          @cc_marco_for_src[target] = Array.new unless(@cc_marco_for_src[target])
          @cc_marco_for_src[target].push({'path' => path, 'flag' => flag})
        end

        def add_cxx_flags(target, value)
            @cxx_marco[target] = Array.new unless(@cxx_marco[target])
            @cxx_marco[target].push("#{value}")
        end

        def add_linker_flags(target, value)
            @ld_marco[target] = Array.new unless(@ld_marco[target])
            @ld_marco[target].push("#{value}")
        end

        def add_link_library(target, value)
            @link_lib[target] = Array.new unless(@link_lib[target])
            @link_lib[target].push(value)
        end

        def add_sys_link_library(target,value)
            @sys_link_lib[target] = Array.new unless(@sys_link_lib[target])
            @sys_link_lib[target].push(value)
        end

        # Add library to target
        def add_library(target, library, *args, **kwargs)
            # @uvproj_file.linkerTab.add_library(target, library)
 
        end

        # Clear all libraries
        def clear_libraries!(target)
            # @uvproj_file.linkerTab.clear_libraries!(target)
        end

        def add_variable(*args)

        end
        
        def clear_variables!(*args) 

        end
        
        def projectname(proj_name)
           @project_name = "#{proj_name}.elf"
        end

        def set_sdk_root(rootdir)
          @root_dir = rootdir
        end

        def add_target(target, binary_path)
            #@config_cmakelists.puts "set_target_properties( #{target} PROPERTIES LIBRARY_OUTPUT_DIRECTORY #{binary_path.gsub("\\","/")})"
            @target << target
            @target.uniq!
            @binary_file_name = File.basename(binary_path,".*")
        end
        
        def converted_output_file(target, path, rootdir: nil)
            format_map = {
                'bin' => 'binary',
                'hex' => 'ihex',
                'srec' => 'srec',
                'symbolsrec' => 'symbolsrec'
            }
            output_name = File.basename(path)
            format = output_name.split('.')[1]
            
            @converted_format[format_map[format]] = output_name
        end
        
        def add_source(path) 
           @source.push(path)
        end
        
        def clear_sources!(*args) 
           @source.clear
        end

        def linker_file(target, path)
           #@config_cmakelists.puts "set(CMAKE_EXE_LINKER_FLAGS_#{target.upcase} \"${CMAKE_EXE_LINKER_FLAGS_#{target.upcase}} \"-T#{path}\"  -static)"
            @linker_file[target] = Array.new unless(@linker_file[target])
            @linker_file[target].push("#{path}")
        end

        def add_prebuild_script(command)
          command&.each { |cmd| @prebuild_cmd.push_uniq cmd unless cmd.nil? || cmd.strip.empty? }
        end

        def add_postbuild_script(command)
          command&.each { |cmd| @postbuild_cmd.push_uniq cmd unless cmd.nil? || cmd.strip.empty? }
        end

        def set_cmake_variables(variables)
          @cmake_variables = variables
        end

        def add_cmake_file(path, cache_dir)
          @cmake_files[path] = cache_dir
        end
        # empty implementation for old-school cmake
        def copy_output_file(target, path)
        end
    end

end
end
