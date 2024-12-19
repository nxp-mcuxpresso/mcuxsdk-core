# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
include_guard(GLOBAL)
set(GUI_PROJECT_SUPPORTED_TOOLCHAIN "iar" "mdk" "xtensa" "codewarrior")
set(STANDALONE_PROJECT_SUPPORTED_TOOLCHAIN "armgcc" "iar" "mdk" "xtensa")

mcux_get_property(IDE_YML_LIST INTERFACE_IDE_YML_LIST)
string(REPLACE ";" " " IDE_YML_LIST "${IDE_YML_LIST}")

if(NOT core_id_suffix_name)
  set(yml_core_id_suffix_name '')
else()
  set(yml_core_id_suffix_name ${core_id_suffix_name})
endif()

if(NOT CMAKE_LOG_LEVEL)
    set(CMAKE_LOG_LEVEL STATUS)
endif ()

set(COMMON_ENV_SETTINGS
    device=${device}
    platform_devices_soc_name=${device}
    soc_series=${soc_series}
    SdkRootDirPath=${SdkRootDirPath}
    device_id=${CONFIG_MCUX_HW_DEVICE_ID}
    core_id_suffix_name=${yml_core_id_suffix_name}
    core=${CONFIG_MCUX_HW_CORE}
    core_id=${CONFIG_MCUX_HW_CORE_ID}
    fpu=${CONFIG_MCUX_HW_FPU}
    dsp=${dsp}
    trustzone=${trustzone}
    build_dir=${CMAKE_CURRENT_BINARY_DIR}
    APPLICATION_SOURCE_DIR=${APPLICATION_SOURCE_DIR}
    # project_root_path=${project_board_port_path}
    CONFIG_MCUX_TOOLCHAIN_IAR_CPU_IDENTIFIER=${CONFIG_MCUX_TOOLCHAIN_IAR_CPU_IDENTIFIER}
    CONFIG_MCUX_TOOLCHAIN_MDK_CPU_IDENTIFIER=${CONFIG_MCUX_TOOLCHAIN_MDK_CPU_IDENTIFIER}
    CONFIG_MCUX_TOOLCHAIN_CODEWARRIOR_CPU_IDENTIFIER=${CONFIG_MCUX_TOOLCHAIN_CODEWARRIOR_CPU_IDENTIFIER}
    is_multicore_device=${CONFIG_MCUX_HW_SOC_MULTICORE_DEVICE}
    board_mounted_device_part=${CONFIG_MCUX_HW_DEVICE_PART}
    toolchain=${CONFIG_TOOLCHAIN}
    build_config=${CMAKE_BUILD_TYPE}
    IDE_YML_LIST=${IDE_YML_LIST}
    log_level=${CMAKE_LOG_LEVEL}
    project_type=${__PROJECT_TYPE})
if(NOT DEFINED board)
    # for platformlib
    list(APPEND COMMON_ENV_SETTINGS board=${device})
else()
    list(APPEND COMMON_ENV_SETTINGS board=${board})
endif()

if(NOT DEFINED SB_CONF_FILE)
    # VARIABLE_FROM_CMAKE does not work for sysbuild
    mcux_get_property(_VARIABLE_FROM_CMAKE VARIABLE_FROM_CMAKE)
    list(APPEND COMMON_ENV_SETTINGS ${_VARIABLE_FROM_CMAKE})
endif ()

set(PROJECT_GENERATOR
    ${SdkRootDirPath}/scripts/guigenerator/project_generator/project_generator.rb
)
if (${CONFIG_TOOLCHAIN} IN_LIST GUI_PROJECT_SUPPORTED_TOOLCHAIN AND FOUND_RUBY_EXECUTABLE)
    add_custom_target(
            guiproject
            ${CMAKE_COMMAND}
            -E
            env
            ${COMMON_ENV_SETTINGS}
            ruby
            ${PROJECT_GENERATOR}
            -t
            ${CONFIG_TOOLCHAIN}
            -i
            ${CMAKE_CURRENT_BINARY_DIR}/build.ninja
            -o
            ${CMAKE_CURRENT_BINARY_DIR}
            -p
            ${MCUX_SDK_PROJECT_NAME}
            -c
            ${CMAKE_BUILD_TYPE}
            WORKING_DIRECTORY ${SdkRootDirPath}
            USES_TERMINAL COMMAND_EXPAND_LISTS)
else ()
    add_custom_target(
            guiproject
            COMMAND ${CMAKE_COMMAND} -E echo "Program has stopped without project generation. Please check if ruby is installed, or if the specified toolchain is one of ${GUI_PROJECT_SUPPORTED_TOOLCHAIN}."
            VERBATIM)
endif ()

if (${CONFIG_TOOLCHAIN} IN_LIST STANDALONE_PROJECT_SUPPORTED_TOOLCHAIN AND FOUND_RUBY_EXECUTABLE)
add_custom_target(
        standalone_project
        ${CMAKE_COMMAND}
        -E
        env
        ${COMMON_ENV_SETTINGS} standalone=true
        ruby
        ${PROJECT_GENERATOR}
        -t
        ${CONFIG_TOOLCHAIN}
        -i
        ${CMAKE_CURRENT_BINARY_DIR}/build.ninja
        -o
        ${CMAKE_CURRENT_BINARY_DIR}
        -p
        ${MCUX_SDK_PROJECT_NAME}
        -c
        ${CMAKE_BUILD_TYPE}
        WORKING_DIRECTORY ${SdkRootDirPath}
        USES_TERMINAL COMMAND_EXPAND_LISTS)
else ()
    add_custom_target(
            standalone_project
            COMMAND ${CMAKE_COMMAND} -E echo "Program has stopped without standalone project generation. Please check if ruby is installed, or if the specified toolchain is one of ${STANDALONE_PROJECT_SUPPORTED_TOOLCHAIN}."
            VERBATIM)
endif ()

add_custom_target(
  manifest ${CMAKE_COMMAND} -E env ${COMMON_ENV_SETTINGS} ${PYTHON_EXECUTABLE}
           ${SdkRootDirPath}/scripts/mcux_manifest/mcux_manifest.py)

function(dump_gui_project_data)
    get_property(
            SOURCE_FILES
            TARGET ${MCUX_SDK_PROJECT_NAME}
            PROPERTY SOURCES)
    mcux_get_property(linker_file ${MCUX_SDK_PROJECT_NAME}_LINKER_PATH linker_path)
    list(APPEND SOURCE_FILES ${linker_file})
    file(WRITE "${APPLICATION_BINARY_DIR}/${MCUX_SDK_PROJECT_NAME}_source_list.txt" "${SOURCE_FILES}")
endfunction()
