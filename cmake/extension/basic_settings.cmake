# SPDX-License-Identifier: Apache-2.0
#
# Copyright (c) 2022, Nordic Semiconductor ASA
# Copyright 2024 NXP

# Setup basic settings for a Zephyr project.
#
# Basic settings are:
# - sysbuild defined configuration settings
#
# Details for sysbuild settings:
#
# Sysbuild is a higher level build system used by Zephyr.
# Sysbuild allows users to build multiple samples for a given system.
#
# For this to work, sysbuild manages other Zephyr CMake build systems by setting
# dedicated build variables.
# This CMake modules loads the sysbuild cache variables as target properties on
# a sysbuild_cache target.
#
# This ensures that qoutes and lists are correctly preserved.

include_guard(GLOBAL)

include(${SdkRootDirPath}/cmake/extension/misc_function.cmake)
set(READ_TOOL_VERSION_PY "${SdkRootDirPath}/scripts/misc/read_tool_versions.py")
set(INTERNAL_EXAMPLE_FOLDER "examples_int")

_read_tool_versions(${READ_TOOL_VERSION_PY})

log_status("CMake version: ${CMAKE_VERSION}")
if (CMAKE_VERSION VERSION_LESS ${CMAKE_MINIMUM_VERSION})
  message("warning: The system CMake version ${CMAKE_VERSION} is lower than the recommended version ${CMAKE_MINIMUM_VERSION} which may cause unexpected build failure especially for complicated project. Please upgrade CMake to version ${CMAKE_MINIMUM_VERSION} or above.")
endif()

include(${SdkRootDirPath}/cmake/extension/python.cmake)
include(${SdkRootDirPath}/cmake/extension/ruby.cmake)
include(${SdkRootDirPath}/cmake/extension/sysbuild/cmake/extensions.cmake)
include(${SdkRootDirPath}/cmake/toolchain/toolchain.cmake)
include(${SdkRootDirPath}/cmake/extension/function.cmake)

# clean cached variable at the very beginning
set(CMAKE_ASM_FLAGS
    ""
    CACHE STRING "The Assembly compiler flags" FORCE)
set(CMAKE_C_FLAGS
    ""
    CACHE STRING "The C compiler flags" FORCE)
set(CMAKE_CXX_FLAGS
    ""
    CACHE STRING "The C++ compiler flags" FORCE)
set(CMAKE_EXE_LINKER_FLAGS
    ""
    CACHE STRING "The Linker flags" FORCE)

# Source-less library that encapsulates all the global compiler options needed
# by all source files.
add_library(mcux_build_properties INTERFACE)

list(
  APPEND
  MCUX_SOURCE_CONDITION
  COMPILERS
  TOOLCHAINS
  CORES
  CORE_IDS
  BOARDS
  DEVICE_IDS
  FPU
  DSP
  MPU
  TRUSTZONE
  COMPONENTS)
list(
  APPEND
  CMAKE_CONDITION
  CONFIG_COMPILER
  CONFIG_TOOLCHAIN
  CONFIG_MCUX_HW_CORE
  CONFIG_MCUX_HW_CORE_ID
  CONFIG_MCUX_HW_BOARD
  CONFIG_MCUX_HW_DEVICE_ID
  CONFIG_MCUX_HW_FPU
  CONFIG_MCUX_HW_DSP
  CONFIG_MCUX_HW_MPU
  CONFIG_MCUX_HW_SAU
  components)
list(APPEND LIST_CMAKE_CONDITION components)
list(
  APPEND
  HARDWARE_VARIABLES
  CONFIG_MCUX_HW_KIT
  CONFIG_MCUX_HW_BOARD
  CONFIG_MCUX_HW_DEVICE
  CONFIG_MCUX_HW_DEVICE_ID
  CONFIG_MCUX_HW_DEVICE_PART
  CONFIG_MCUX_HW_CORE
  CONFIG_MCUX_HW_CORE_ID
  CONFIG_MCUX_HW_DEVICE_CORE
  CONFIG_MCUX_HW_FPU
  CONFIG_MCUX_HW_FPU_TYPE
  CONFIG_MCUX_HW_DSP
  CONFIG_MCUX_TOOLCHAIN_MCUX_STARTUP
  CONFIG_MCUX_TOOLCHAIN_LINKER_DEVICE_PREFIX
  CONFIG_MCUX_TOOLCHAIN_IAR_CPU_IDENTIFIER
  CONFIG_MCUX_TOOLCHAIN_MDK_CPU_IDENTIFIER
  CONFIG_MCUX_TOOLCHAIN_JLINK_CPU_IDENTIFIER
  CONFIG_MCUX_HW_SOC_MULTICORE_DEVICE)

list(
  APPEND
  USED_CONFIG_SYMBOLS
  CONFIG_TOOLCHAIN)

if(${CMAKE_VERSION} VERSION_GREATER_EQUAL "3.25.0")
    # Get log level, can be ERROR, WARNING, NOTICE, STATUS (default), VERBOSE, DEBUG, or TRACE.
    # Note it only support CMake >= 3.25. https://cmake.org/cmake/help/latest/command/cmake_language.html#query-message-log-level
    cmake_language(GET_MESSAGE_LOG_LEVEL CMAKE_LOG_LEVEL)
endif ()

# if defined board, load board variables
if(DEFINED board)
  if (DEFINED CUSTOM_BOARD_ROOT)
    get_filename_component(
      board_variable_path "${CUSTOM_BOARD_ROOT}/${board}/variable.cmake"
      ABSOLUTE)
    if(NOT EXISTS ${board_variable_path})
      log_fatal("Board variable file ${board_variable_path} does not exist, please prepare it or check the correctness of board name and CUSTOM_BOARD_ROOT")
    endif ()
  else ()
    get_filename_component(
      board_variable_path "${SdkRootDirPath}/examples/_boards/${board}/variable.cmake"
      ABSOLUTE)
    if(NOT EXISTS ${board_variable_path})
      log_debug("Board variable file ${board_variable_path} does not exist, build system will search the internal repo to get board variable.cmake")
      get_filename_component(
        board_variable_path "${SdkRootDirPath}/examples_int/_boards/${board}/variable.cmake" ABSOLUTE
      )
      if (NOT EXISTS ${board_variable_path})
        log_fatal("There is no board variable.cmake file in either ${SdkRootDirPath}/examples/_boards/${board} or ${SdkRootDirPath}/examples_int/_boards/${board}, please provide the board variable cmake file or check whether board ${board} has been supported or not, make sure it is not a typo" ${CMAKE_CURRENT_LIST_FILE} ${CMAKE_CURRENT_LIST_LINE})
      endif()
    endif()
  endif()

  # check the existense of board_variable_path
  log_debug("Include ${board_variable_path}" ${CMAKE_CURRENT_LIST_FILE}
            ${CMAKE_CURRENT_LIST_LINE})
  include(${board_variable_path} OPTIONAL)
else()
  _get_subfolder_file(device_variable_path "${SdkRootDirPath}/devices" "${device}/variable.cmake" 2)
  if(NOT device_variable_path)
    log_debug("Cannot find device variable file for ${device} under 'devices' folder, build system will search the internal repo to get device variable.cmake")
    _get_subfolder_file(device_variable_path "${SdkRootDirPath}/devices_int" "${device}/variable.cmake" 2)
    if(NOT device_variable_path)
      log_fatal("Cannot find device variable file for ${device} under 'devices' or 'devices_int' folders, please check whether ${device} is supported or not" ${CMAKE_CURRENT_LIST_FILE} ${CMAKE_CURRENT_LIST_LINE})
    endif()
  endif()
  log_debug("Include ${device_variable_path}" ${CMAKE_CURRENT_LIST_FILE} ${CMAKE_CURRENT_LIST_LINE})
  include(${device_variable_path} OPTIONAL)
endif()

# check device is defined
# device must be speicified for a project build.
if(NOT DEFINED device)
  log_error("Device is not defined" ${CMAKE_CURRENT_LIST_FILE} ${CMAKE_CURRENT_LIST_LINE})
endif()

if (NOT DEFINED multicore_foldername)
  if(NOT core_id_suffix_name)
    set(multicore_foldername ".")
  else()
    string(REGEX REPLACE "^_" "" multicore_foldername
            ${core_id_suffix_name})
  endif()
endif()

if(SYSBUILD)
  add_custom_target(sysbuild_cache)
  file(STRINGS "${SYSBUILD_CACHE}" sysbuild_cache_strings)
  foreach(str ${sysbuild_cache_strings})
    # Using a regex for matching whole 'VAR_NAME:TYPE=VALUE' will strip semi-colons
    # thus resulting in lists to become strings.
    # Therefore we first fetch VAR_NAME and TYPE, and afterwards extract
    # remaining of string into a value that populates the property.
    # This method ensures that both quoted values and ;-separated list stays intact.
    string(REGEX MATCH "([^:]*):([^=]*)=" variable_identifier ${str})
    string(LENGTH ${variable_identifier} variable_identifier_length)
    string(SUBSTRING "${str}" ${variable_identifier_length} -1 variable_value)
    set_property(TARGET sysbuild_cache APPEND PROPERTY "SYSBUILD_CACHE:VARIABLES" "${CMAKE_MATCH_1}")
    set_property(TARGET sysbuild_cache PROPERTY "${CMAKE_MATCH_1}:TYPE" "${CMAKE_MATCH_2}")
    set_property(TARGET sysbuild_cache PROPERTY "${CMAKE_MATCH_1}" "${variable_value}")
  endforeach()

  mcux_load_sysbuild_config()
endif()

list(
    APPEND
    iar_CC_IGNORE_LIST
    --use_cmsis_dsp
)
list(
    APPEND
    iar_CX_IGNORE_LIST
    --use_cmsis_dsp
)
