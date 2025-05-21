# Copyright (c) 2019-2024, Nordic Semiconductor ASA
# Copyright 2024 NXP

# Originally modified from:
# https://github.com/zephyrproject-rtos/zephyr/blame/main/cmake/modules/zephyr_module.cmake
# SPDX-License-Identifier: Apache-2.0

include_guard(GLOBAL)
# This cmake file provides functionality to import CMakeLists.txt and Kconfig
# files for Zephyr modules into Zephyr build system.
#
# CMakeLists.txt and Kconfig files can reside directly in the Zephyr module or
# in a MODULE_EXT_ROOT.
# The `<module>/zephyr/module.yml` file specifies whether the build files are
# located in the Zephyr module or in a MODULE_EXT_ROOT.
#
# A list of Zephyr modules can be provided to the build system using:
#   -DMCUX_MODULES=<module-path>[;<additional-module(s)-path>]
#
# It looks for: <module>/zephyr/module.yml or
#               <module>/zephyr/CMakeLists.txt
# to load the Zephyr module into Zephyr build system.
# If west is installed, it uses west's APIs to obtain a list of projects to
# search for zephyr/module.yml from the current workspace's manifest.
#
# If the module.yml file specifies that build files are located in a
# MODULE_EXT_ROOT then the variables:
# - `MCUX_<MODULE_NAME>_CMAKE_DIR` is used for inclusion of the CMakeLists.txt
# - `MCUX_<MODULE_NAME>_KCONFIG` is used for inclusion of the Kconfig
# files into the build system.

# Settings used by Zephyr module but where systems may define an alternative value.
if(NOT DEFINED KCONFIG_BINARY_DIR)
    set(KCONFIG_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/Kconfig)
endif ()

if(MCUX_MODULES)
    set(MCUX_MODULES_ARG "--modules" ${MCUX_MODULES})
endif()

if(EXTRA_MCUX_MODULES)
    set(EXTRA_MCUX_MODULES_ARG "--extra-modules" ${EXTRA_MCUX_MODULES})
endif()

file(MAKE_DIRECTORY ${KCONFIG_BINARY_DIR})
set(kconfig_modules_file ${KCONFIG_BINARY_DIR}/Kconfig.modules)
set(kconfig_sysbuild_file ${KCONFIG_BINARY_DIR}/Kconfig.sysbuild.modules)
set(cmake_modules_file ${CMAKE_BINARY_DIR}/mcux_modules.txt)
set(cmake_sysbuild_file ${CMAKE_BINARY_DIR}/sysbuild_modules.txt)
set(mcux_settings_file ${CMAKE_BINARY_DIR}/mcux_settings.txt)

# Search modules by using west, so only call it if west is installed
if(DEFINED WEST)
    execute_process(
            COMMAND
            ${PYTHON_EXECUTABLE} ${SdkRootDirPath}/scripts/misc/mcux_module.py
            --mcux-base=${SdkRootDirPath}
            ${MCUX_MODULES_ARG}
            ${EXTRA_MCUX_MODULES_ARG}
            --kconfig-out ${kconfig_modules_file}
            --cmake-out ${cmake_modules_file}
            --sysbuild-kconfig-out ${kconfig_sysbuild_file}
            --sysbuild-cmake-out ${cmake_sysbuild_file}
            --settings-out ${mcux_settings_file}
            WORKING_DIRECTORY ${SdkRootDirPath}
            ERROR_VARIABLE
            mcux_module_error_text
            RESULT_VARIABLE
            mcux_module_return
    )

    if(${mcux_module_return})
        message(FATAL_ERROR "${mcux_module_error_text}")
    endif()

    if(EXISTS ${mcux_settings_file})
        file(STRINGS ${mcux_settings_file} mcux_settings_txt ENCODING UTF-8 REGEX "^[^#]")
        foreach(setting ${mcux_settings_txt})
            # Match <key>:<value> for each line of file, each corresponding to
            # a setting.  The use of quotes is required due to CMake not supporting
            # lazy regexes (it supports greedy only).
            string(REGEX REPLACE "\"(.*)\":\".*\"" "\\1" key ${setting})
            string(REGEX REPLACE "\".*\":\"(.*)\"" "\\1" value ${setting})
            list(APPEND ${key} ${value})
        endforeach()
    endif()

    # Append MCUX_BASE as a default ext root at lowest priority
    list(APPEND MODULE_EXT_ROOT ${MCUX_BASE})

    if(EXISTS ${cmake_modules_file})
        file(STRINGS ${cmake_modules_file} mcux_modules_txt ENCODING UTF-8)
    endif()

    set(MCUX_MODULE_NAMES)
    foreach(module ${mcux_modules_txt})
        # Match "<name>":"<path>" for each line of file, each corresponding to
        # one module. The use of quotes is required due to CMake not supporting
        # lazy regexes (it supports greedy only).
        string(REGEX REPLACE "\"(.*)\":\".*\":\".*\"" "\\1" module_name ${module})
        list(APPEND MCUX_MODULE_NAMES ${module_name})
    endforeach()

    if(EXISTS ${cmake_sysbuild_file})
        file(STRINGS ${cmake_sysbuild_file} sysbuild_modules_txt ENCODING UTF-8)
    endif()

    set(SYSBUILD_MODULE_NAMES)
    foreach(module ${sysbuild_modules_txt})
        # Match "<name>":"<path>" for each line of file, each corresponding to
        # one module. The use of quotes is required due to CMake not supporting
        # lazy regexes (it supports greedy only).
        string(REGEX REPLACE "\"(.*)\":\".*\":\".*\"" "\\1" module_name ${module})
        list(APPEND SYSBUILD_MODULE_NAMES ${module_name})
    endforeach()

    # MODULE_EXT_ROOT is process order which means Zephyr module roots processed
    # later wins. therefore we reverse the list before processing.
    list(REVERSE MODULE_EXT_ROOT)
    foreach(root ${MODULE_EXT_ROOT})
        set(module_cmake_file_path modules/modules.cmake)
        if(NOT EXISTS ${root}/${module_cmake_file_path})
            message(FATAL_ERROR "No `${module_cmake_file_path}` found in module root `${root}`.")
        endif()

        include(${root}/${module_cmake_file_path})
    endforeach()

    foreach(module ${mcux_modules_txt})
        # Match "<name>":"<path>" for each line of file, each corresponding to
        # one Zephyr module. The use of quotes is required due to CMake not
        # supporting lazy regexes (it supports greedy only).
        string(CONFIGURE ${module} module)
        string(REGEX REPLACE "\"(.*)\":\".*\":\".*\"" "\\1" module_name ${module})
        string(REGEX REPLACE "\".*\":\"(.*)\":\".*\"" "\\1" module_path ${module})
        string(REGEX REPLACE "\".*\":\".*\":\"(.*)\"" "\\1" cmake_path ${module})

        mcux_string(SANITIZE TOUPPER MODULE_NAME_UPPER ${module_name})
        if(NOT ${MODULE_NAME_UPPER} STREQUAL CURRENT)
            set(MCUX_${MODULE_NAME_UPPER}_MODULE_NAME ${module_name})
            set(MCUX_${MODULE_NAME_UPPER}_MODULE_DIR ${module_path})
            set(MCUX_${MODULE_NAME_UPPER}_CMAKE_DIR ${cmake_path})
        else()
            message(FATAL_ERROR "Found Zephyr module named: ${module_name}\n\
${MODULE_NAME_UPPER} is a restricted name for Mcux modules as it is used for \
\${MCUX_${MODULE_NAME_UPPER}_MODULE_DIR} CMake variable.")
        endif()
    endforeach()

    foreach(module ${sysbuild_modules_txt})
        # Match "<name>":"<path>" for each line of file, each corresponding to
        # one Zephyr module. The use of quotes is required due to CMake not
        # supporting lazy regexes (it supports greedy only).
        string(CONFIGURE ${module} module)
        string(REGEX REPLACE "\"(.*)\":\".*\":\".*\"" "\\1" module_name ${module})
        string(REGEX REPLACE "\".*\":\"(.*)\":\".*\"" "\\1" module_path ${module})
        string(REGEX REPLACE "\".*\":\".*\":\"(.*)\"" "\\1" cmake_path ${module})

        mcux_string(SANITIZE TOUPPER MODULE_NAME_UPPER ${module_name})
        if(NOT ${MODULE_NAME_UPPER} STREQUAL CURRENT)
            set(SYSBUILD_${MODULE_NAME_UPPER}_MODULE_DIR ${module_path})
            set(SYSBUILD_${MODULE_NAME_UPPER}_CMAKE_DIR ${cmake_path})
        else()
            message(FATAL_ERROR "Found Zephyr module named: ${module_name}\n\
${MODULE_NAME_UPPER} is a restricted name for Zephyr modules as it is used for \
\${SYSBUILD_${MODULE_NAME_UPPER}_MODULE_DIR} CMake variable.")
        endif()
    endforeach()
else()

    file(WRITE ${kconfig_modules_file}
            "# No west and no Mcux modules\n"
            )

    file(WRITE ${kconfig_sysbuild_file}
            "# No west and no Mcux modules\n"
            )

endif()

function(mcux_load_extra_module)
    if(DEFINED MCUX_MODULE_NAMES)
        set(interface_lib_list)
        foreach(module_name ${MCUX_MODULE_NAMES})
            mcux_string(SANITIZE TOUPPER MODULE_NAME_UPPER ${module_name})
            if(NOT ${MCUX_${MODULE_NAME_UPPER}_CMAKE_DIR} STREQUAL "")
                set(MCUX_CURRENT_MODULE_NAME ${MCUX_${MODULE_NAME_UPPER}_MODULE_NAME})
                set(MCUX_CURRENT_MODULE_DIR ${MCUX_${MODULE_NAME_UPPER}_MODULE_DIR})
                set(MCUX_CURRENT_CMAKE_DIR ${MCUX_${MODULE_NAME_UPPER}_CMAKE_DIR})
                if(CONFIG_MCUX_COMPONENT_${MODULE_NAME_UPPER}_MODULE)
                    log_status("Add external module ${module_name} from ${MCUX_CURRENT_CMAKE_DIR}")
                    add_subdirectory(${MCUX_CURRENT_CMAKE_DIR} ${CMAKE_BINARY_DIR}/modules/${module_name})
                    # link external module to SDK project
                    if(TARGET ${module_name})
                        get_target_property(target_type ${module_name} TYPE)
                        if(target_type STREQUAL "STATIC_LIBRARY" OR target_type STREQUAL "INTERFACE_LIBRARY")
                            # get interface linked libraries to add them into group
                            if(target_type STREQUAL "INTERFACE_LIBRARY")
                                get_property(
                                        SDK_LIB_FILES
                                        TARGET ${module_name}
                                        PROPERTY INTERFACE_LINK_LIBRARIES)
                                list(APPEND interface_lib_list ${SDK_LIB_FILES})
                            endif()

                            if (MCUX_SDK_CMAKE_PACKAGE)
                                target_link_libraries(McuxSDK PUBLIC ${module_name})
                            else()
                                target_link_libraries(${MCUX_SDK_PROJECT_NAME} PUBLIC ${module_name})
                            endif()
                        endif()
                    else()
                        # Since we have enabled automatic module loading feature, it's common for loaded modules not to be used. 
                        # No need to give warning message.
                        log_debug("Module ${module_name} is not found, please check:
                        1. The module is enabled in prj.conf or by kconfig
                        2. Whether module folder name is same as module name, if not, set \"name\" in module.yml which aligns with name in add_library() function " ${CMAKE_CURRENT_LIST_FILE})
                    endif()
                endif ()
            endif()
        endforeach()
        if (MCUX_SDK_CMAKE_PACKAGE)
            reset_app_link_order(LIBS ${interface_lib_list})
        endif()
    endif()
endfunction()