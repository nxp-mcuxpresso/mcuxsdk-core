# Copyright 2018-2023 Nordic Semiconductor ASA and Intel Corporation
# Copyright 2024 NXP
# Originally modified from:
# https://github.com/zephyrproject-rtos/zephyr/blame/main/cmake/modules/kconfig.cmake
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
# (1) merge each proj.conf (2) kconfig entry file generation (3) call Kconfiglib
# to generate .config file (4) process .config file to generate header file or
# set compiler/linker flags

function(mcux_load_prjconf prjconf_dir conf_name)
  # if the prj.conf does not exist, return back
  if(NOT EXISTS ${prjconf_dir}/${conf_name})
    # Give a warning that prj.conf does not exist
    # message(WARNING "prj.conf does not exist in ${prjconf_dir}")
    return()
  endif()

  log_debug(
    "Load ${prjconf_dir}/${conf_name} to get depended components/project segment and variables."
  )

  file(STRINGS ${prjconf_dir}/${conf_name} prj_conf_contents)

  foreach(item ${prj_conf_contents})
    string(REGEX MATCH "^CONFIG_.*=y$" itemy ${item})
    if(NOT "${itemy}" STREQUAL "")
      string(REGEX REPLACE "[ ]" "" itemy ${itemy})
      string(REGEX REPLACE "=y" "" itemy ${itemy})

      string(FIND ${itemy} "MCUX_COMPONENT" component_substring_index)

      if(component_substring_index GREATER -1)
        string(REGEX REPLACE "^CONFIG_MCUX_COMPONENT_" ""
                             component_output_string ${itemy})
        list(APPEND components ${component_output_string})
        log_debug("Component ${component_output_string} is set to y in .config")
      endif()

      string(FIND ${itemy} "MCUX_PRJSEG" prjseg_substring_index)

      if(prjseg_substring_index GREATER -1)
        string(REGEX REPLACE "^CONFIG_MCUX_PRJSEG_" "" prjseg_output_string
                             ${itemy})
        log_debug(
          "Project segment ${prjseg_output_string} is set to y in .config")
      endif()

      set(${itemy}
              true)
      set(${itemy}
          true
          PARENT_SCOPE)
    else ()
      string(REGEX MATCH "^CONFIG_.*=n$" itemn ${item})
      if(NOT ${itemn} STREQUAL "")
        string(REGEX REPLACE "[ ]" "" itemn ${itemn})
        string(REGEX REPLACE "=n" "" itemn ${itemn})
        set(${itemn}
            false
            PARENT_SCOPE)
      else ()
        set(match_variable false)
        foreach(variable ${HARDWARE_VARIABLES})
          string(REGEX MATCH "^${variable}=.*$" value ${item})
          if(NOT ${value} STREQUAL "")
            set(match_variable true)
            string(REGEX REPLACE "\"" "" value ${value})
            string(REGEX REPLACE "${variable}=" "" value ${value})
            log_debug("Variable ${variable} is set to ${value} in .config")
            set(${variable}
                ${value})
            set(${variable}
                ${value}
                PARENT_SCOPE)
          endif()
        endforeach()

        if(NOT match_variable)
          set(item_misc_type "")
          string(REGEX MATCH "^CONFIG_.*=.*$" item_misc_type ${item})
          if (NOT ${item_misc_type} STREQUAL "")
            set(item_misc_type_key "")
            set(item_misc_type_value "")
            string(REGEX REPLACE "\"" "" item_misc_type ${item_misc_type})
            string(REGEX REPLACE "^CONFIG_[^=]*=" "" item_misc_type_value ${item_misc_type})
            string(REGEX REPLACE "=.*$" "" item_misc_type_key ${item_misc_type})
            log_debug("${item_misc_type_key} is set to ${item_misc_type_value} in .config")
            set(${item_misc_type_key}
                ${item_misc_type_value}
                PARENT_SCOPE)
          endif()
        endif()
      endif()
    endif()
  endforeach()

  # some special variable need to be set
  if (NOT DEFINED CONFIG_MCUX_HW_DSP)
    set(CONFIG_MCUX_HW_DSP "NO_DSP")
    set(CONFIG_MCUX_HW_DSP "NO_DSP" PARENT_SCOPE)
  else ()
    set(CONFIG_MCUX_HW_DSP "HAS_DSP")
    set(CONFIG_MCUX_HW_DSP "HAS_DSP" PARENT_SCOPE)
  endif()

  if (NOT DEFINED CONFIG_MCUX_HW_MPU)
    set(CONFIG_MCUX_HW_MPU "NO_MPU")
    set(CONFIG_MCUX_HW_MPU "NO_MPU" PARENT_SCOPE)
  else ()
    set(CONFIG_MCUX_HW_MPU "HAS_MPU")
    set(CONFIG_MCUX_HW_MPU "HAS_MPU" PARENT_SCOPE)
  endif()

  if (NOT DEFINED CONFIG_MCUX_HW_SAU)
    set(CONFIG_MCUX_HW_SAU "NO_TZ")
    set(CONFIG_MCUX_HW_SAU "NO_TZ" PARENT_SCOPE)
  else ()
    set(CONFIG_MCUX_HW_SAU "TZ")
    set(CONFIG_MCUX_HW_SAU "TZ" PARENT_SCOPE)
  endif()  

  set(components
      ${components}
      PARENT_SCOPE)
endfunction()

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/kconfig)

set_ifndef(AUTOCONF_H
           ${CMAKE_CURRENT_BINARY_DIR}/kconfig/include/generated/autoconf.h)

set(SPLITCONFIG_DIR ${CMAKE_CURRENT_BINARY_DIR})
# Re-configure (Re-execute all CMakeLists.txt code) when autoconf.h changes
set_property(
  DIRECTORY
  APPEND
  PROPERTY CMAKE_CONFIGURE_DEPENDS ${AUTOCONF_H})

set_ifndef(KCONFIG_NAMESPACE "CONFIG")
set(DOTCONFIG ${CMAKE_CURRENT_BINARY_DIR}/.config)
set(PARSED_KCONFIG_SOURCES_TXT ${CMAKE_CURRENT_BINARY_DIR}/kconfig/sources.txt)
set(GENERATED_HEADERS_TXT ${CMAKE_CURRENT_BINARY_DIR}/kconfig/headers.txt)
set_ifndef(MCUX_SDK_PROJECT_NAME "sysbuild")
# Only defined KCONFIG_ROOT if not set, because SYSBUILD has defined
# KCONFIG_ROOT before
if(NOT DEFINED KCONFIG_ROOT)
  if(EXISTS ${APPLICATION_SOURCE_DIR}/Kconfig)
    set(KCONFIG_ROOT ${APPLICATION_SOURCE_DIR}/Kconfig)
  else()
    set(KCONFIG_ROOT ${SdkRootDirPath}/Kconfig)
  endif()
endif()

set(COMMON_KCONFIG_ENV_SETTINGS
    project_board_port_path=${project_board_port_path}
    PYTHON_EXECUTABLE=${PYTHON_EXECUTABLE}
    CONFIG_=${KCONFIG_NAMESPACE}_
    KCONFIG_CONFIG=${DOTCONFIG}
    board=${board}
    shield=${shield}
    device=${device}
    soc_series=${soc_series}
    SdkRootDirPath=${SdkRootDirPath}
    KCONFIG_BINARY_DIR=${KCONFIG_BINARY_DIR}
    # The variables below is for sysbuild kconfig
    core_id=${core_id}
    config=${CMAKE_BUILD_TYPE}
    toolchain=${CONFIG_TOOLCHAIN}
    MCUX_SDK_PROJECT_NAME=${MCUX_SDK_PROJECT_NAME})

if(NOT DEFINED SB_CONF_FILE)
  # VARIABLE_FROM_CMAKE does not work for sysbuild
  mcux_get_property(_VARIABLE_FROM_CMAKE VARIABLE_FROM_CMAKE)
  list(APPEND COMMON_KCONFIG_ENV_SETTINGS ${_VARIABLE_FROM_CMAKE})
endif ()

set(EXTRA_KCONFIG_TARGET_COMMAND_FOR_menuconfig
    ${SdkRootDirPath}/scripts/kconfig/menuconfig.py)

set(EXTRA_KCONFIG_TARGET_COMMAND_FOR_guiconfig
    ${SdkRootDirPath}/scripts/kconfig/guiconfig.py)

set_ifndef(KCONFIG_TARGETS menuconfig guiconfig hardenconfig)

foreach(kconfig_target ${KCONFIG_TARGETS} ${EXTRA_KCONFIG_TARGETS})
  add_custom_target(
    ${kconfig_target}
    ${CMAKE_COMMAND}
    -E
    env
    ZEPHYR_BASE=${SdkRootDirPath}
    ${COMMON_KCONFIG_ENV_SETTINGS}
    "SHIELD_AS_LIST=${SHIELD_AS_LIST_ESCAPED}"
    DTS_POST_CPP=${DTS_POST_CPP}
    DTS_ROOT_BINDINGS=${DTS_ROOT_BINDINGS}
    ${PYTHON_EXECUTABLE}
    ${EXTRA_KCONFIG_TARGET_COMMAND_FOR_${kconfig_target}}
    ${KCONFIG_ROOT}
    WORKING_DIRECTORY ${SdkRootDirPath}
    USES_TERMINAL COMMAND_EXPAND_LISTS)
endforeach()

if(DEFINED SB_CONF_FILE)
  list(APPEND merge_config_files ${BOARD_DEFCONFIG})
elseif (NOT NO_DEFAULT_CONFIG)

  # All prj.conf shall be sorted by the order device, device/<core_id>, board, board/<core_id>
  # If PROJECT_BOARD_PORT_PATH is provide in project macro which means it is a repository project, then example, example category, board example, board example category shall be searched.
  # 1. Repository project
  #    device
  #    device/<core_id>
  #    board
  #    board/<core_id>
  #    example category, like src/demo_apps
  #    example, like src/demo_apps/hello_world
  #    board example category, like examples/frdmk64f/demo_apps
  #    board example, like examples/frdmk64f/demo_apps/hello_world
  #    prj.conf provided by CUSTOM_PRJ_CONF_PATHS
  #    prj.conf provided by CONF_FILE
  # 2. Freestanding project
  #    device
  #    device/<core_id>
  #    board
  #    board/<core_id>
  #    prj.conf provided by CUSTOM_PRJ_CONF_PATHS
  #    prj.conf provided by CONF_FILE
  if(NOT DEFINED core_id)
    foreach(
      f
      ${SdkRootDirPath}/devices/prj.conf
      ${SdkRootDirPath}/devices/${soc_portfolio}/prj.conf
      ${SdkRootDirPath}/devices/${soc_portfolio}/${soc_series}/prj.conf
      ${SdkRootDirPath}/devices/${soc_portfolio}/${soc_series}/${device}/prj.conf
      ${SdkRootDirPath}/examples/prj.conf
      ${SdkRootDirPath}/examples/_boards/prj.conf
      ${SdkRootDirPath}/examples/_boards/${board}/prj.conf)
      if(EXISTS ${f})
        list(APPEND merge_config_files ${f})
      endif()
    endforeach()
  else()
    foreach(
      f
      ${SdkRootDirPath}/devices/prj.conf
      ${SdkRootDirPath}/devices/${soc_portfolio}/prj.conf
      ${SdkRootDirPath}/devices/${soc_portfolio}/${soc_series}/prj.conf
      ${SdkRootDirPath}/devices/${soc_portfolio}/${soc_series}/${device}/prj.conf
      ${SdkRootDirPath}/devices/${soc_portfolio}/${soc_series}/${device}/${core_id}/prj.conf
      ${SdkRootDirPath}/examples/prj.conf
      ${SdkRootDirPath}/examples/_boards/prj.conf
      ${SdkRootDirPath}/examples/_boards/${board}/prj.conf
      ${SdkRootDirPath}/examples/_boards/${board}/${core_id}/prj.conf)
      if(EXISTS ${f})
        list(APPEND merge_config_files ${f})
      endif()
    endforeach()
  endif()
  
  if (DEFINED project_board_port_path)
    if (DEFINED INTERNAL_EXAMPLE)
      get_target_source_in_sub_folders(${APPLICATION_SOURCE_DIR} ${INTERNAL_EXAMPLE_FOLDER} "prj.conf")
    else ()
      get_target_source_in_sub_folders(${APPLICATION_SOURCE_DIR} "examples" "prj.conf")
    endif ()
    list(APPEND merge_config_files ${GET_TARGET_SOURCE_IN_SUB_FOLDERS_OUTPUT})

    get_target_source_in_sub_folders(${full_project_board_port_path} "${board}" "prj.conf")
    list(APPEND merge_config_files ${GET_TARGET_SOURCE_IN_SUB_FOLDERS_OUTPUT})
  else()
    if (EXISTS ${APPLICATION_SOURCE_DIR}/prj.conf)
      list(APPEND merge_config_files ${APPLICATION_SOURCE_DIR}/prj.conf)
    endif()
  endif()
endif()
 
# if CUSTOM_PRJ_CONF_PATHS is not empty, append it to merge_config_files
if(CUSTOM_PRJ_CONF_PATHS)
  foreach(path ${CUSTOM_PRJ_CONF_PATHS})
    list(APPEND merge_config_files ${path})
  endforeach()
endif()

if(CONF_FILE)
  string(CONFIGURE "${CONF_FILE}" CONF_FILE_EXPANDED)
  string(REPLACE " " ";" CONF_FILE_AS_LIST "${CONF_FILE_EXPANDED}")
  list(APPEND merge_config_files ${CONF_FILE_AS_LIST})
endif()

# merge_config_files can be empty
if (merge_config_files)
  # Calculate a checksum of merge_config_files to determine if we need to
  # re-generate .config
  set(merge_config_files_checksum "")
  foreach(f ${merge_config_files})
    file(MD5 ${f} checksum)
    set(merge_config_files_checksum "${merge_config_files_checksum}${checksum}")
  endforeach()

  # Create a new .config if it does not exists, or if the checksum of the
  # dependencies has changed
  set(merge_config_files_checksum_file
      ${CMAKE_CURRENT_BINARY_DIR}/.cmake.dotconfig.checksum)
  set(CREATE_NEW_DOTCONFIG 1)
  # Check if the checksum file exists too before trying to open it, though it
  # should under normal circumstances
  if(EXISTS ${DOTCONFIG} AND EXISTS ${merge_config_files_checksum_file})
    # Read out what the checksum was previously
    file(READ ${merge_config_files_checksum_file}
        merge_config_files_checksum_prev)
    if(${merge_config_files_checksum} STREQUAL
      ${merge_config_files_checksum_prev})
      # Checksum is the same as before
      set(CREATE_NEW_DOTCONFIG 0)
    endif()
  endif()
endif()

if(CREATE_NEW_DOTCONFIG)
  set(input_configs_flags --handwritten-input-configs)
  set(input_configs ${merge_config_files} ${FORCED_CONF_FILE})
else()
  set(input_configs ${DOTCONFIG} ${FORCED_CONF_FILE})
endif()
# set(FORCED_CONF_FILE)
if(DEFINED FORCED_CONF_FILE)
  list(APPEND input_configs_flags --forced-input-configs)
endif()

cmake_path(GET AUTOCONF_H PARENT_PATH autoconf_h_path)
if(NOT EXISTS ${autoconf_h_path})
  file(MAKE_DIRECTORY ${autoconf_h_path})
endif()

execute_process(
  COMMAND
    ${CMAKE_COMMAND} -E env ${COMMON_KCONFIG_ENV_SETTINGS}
    SHIELD_AS_LIST=${SHIELD_AS_LIST_ESCAPED_COMMAND} ${PYTHON_EXECUTABLE}
    ${SdkRootDirPath}/scripts/kconfig/kconfig.py --zephyr-base=${ZEPHYR_BASE}
    ${input_configs_flags} ${KCONFIG_ROOT} ${DOTCONFIG}
    # ${AUTOCONF_H}
    "" ${SPLITCONFIG_DIR} ${PARSED_KCONFIG_SOURCES_TXT} ${GENERATED_HEADERS_TXT}
    ${input_configs}
  WORKING_DIRECTORY ${SdkRootDirPath}
  # The working directory is set to the app dir such that the user can use
  # relative paths in CONF_FILE, e.g. CONF_FILE=nrf5.conf
  RESULT_VARIABLE ret)
if(NOT "${ret}" STREQUAL "0")
  log_fatal("Kconfig process command run failed with return code: ${ret}")
endif()

if(NOT ${MCUX_SDK_PROJECT_NAME} STREQUAL sysbuild)
  if (PREINCLUDE)
    # Add headers in ${GENERATED_HEADERS_TXT} into preinclude(s)
    file(STRINGS ${GENERATED_HEADERS_TXT} GENERATED_HEADERS_LIST)
    foreach(h ${GENERATED_HEADERS_LIST})
      get_filename_component(file_name ${h} NAME)
      mcux_add_source(PREINCLUDE TRUE
                      BASE_PATH ${CMAKE_CURRENT_BINARY_DIR}
                      SOURCES "${file_name}")
    endforeach()
  else ()
    # For mcux_config.h, include it with preinclude way.
    # We shall not always open the include for mcux_config.h because the same fsl_common_arm.h is still used in SDK 2.0, so for mcux_config.h, it shall be included into build tree with preinclude way.
    # For other generated headers, they must be included in advance, so that they can both work for 2.0 and 3.0. In 3.0, to support manifest customized component configuration header replacing default component configuration headers, the headers shall be included in advance anyway.
    set(ADD_BINARY_DIR_INCLUDE FALSE)
    file(STRINGS ${GENERATED_HEADERS_TXT} GENERATED_HEADERS_LIST)
    foreach(h ${GENERATED_HEADERS_LIST})
      get_filename_component(file_name ${h} NAME)
      if ("${file_name}" STREQUAL "mcux_config.h")
        mcux_add_source(PREINCLUDE TRUE
                BASE_PATH ${CMAKE_CURRENT_BINARY_DIR}
                SOURCES "${file_name}")
      else ()
        mcux_add_source(
                BASE_PATH ${CMAKE_CURRENT_BINARY_DIR}
                SOURCES "${file_name}")
        if (NOT ADD_BINARY_DIR_INCLUDE)
          # add SPLITCONFIG_DIR into project include
          target_include_directories(${MCUX_SDK_PROJECT_NAME} PUBLIC ${SPLITCONFIG_DIR}/.)
          set(ADD_BINARY_DIR_INCLUDE TRUE)
        endif ()
      endif ()
    endforeach()
  endif()
endif()

if(CREATE_NEW_DOTCONFIG)
  # Write the new configuration fragment checksum. Only do this if kconfig.py
  # succeeds, to avoid marking zephyr/.config as up-to-date when it hasn't been
  # regenerated.
  file(WRITE ${merge_config_files_checksum_file} ${merge_config_files_checksum})
endif()

# Read out the list of 'Kconfig' sources that were used by the engine.
file(STRINGS ${PARSED_KCONFIG_SOURCES_TXT} PARSED_KCONFIG_SOURCES_LIST)
file(STRINGS ${GENERATED_HEADERS_TXT} GENERATED_HEADERS_LIST)

# Force CMAKE configure when the Kconfig sources or configuration files changes.
foreach(kconfig_input ${merge_config_files} ${DOTCONFIG}
                      ${PARSED_KCONFIG_SOURCES_LIST} ${GENERATED_HEADERS_LIST})
  set_property(
    DIRECTORY
    APPEND
    PROPERTY CMAKE_CONFIGURE_DEPENDS ${kconfig_input})
endforeach()

# sysbuild config need to be imported for sub project
if(DEFINED SB_CONF_FILE)
  import_kconfig(${KCONFIG_NAMESPACE} ${DOTCONFIG})
else()
  mcux_load_prjconf(${CMAKE_CURRENT_BINARY_DIR} .config)
endif()
