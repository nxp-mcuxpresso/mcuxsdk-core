# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# transfer to cmake path to error caused by "\"
file(TO_CMAKE_PATH ${SdkRootDirPath} SdkRootDirPath)

# load modules
include(${SdkRootDirPath}/cmake/extension/logging.cmake)
include(${SdkRootDirPath}/cmake/extension/basic_settings.cmake)

# using an underscore prefixed function of the same name. The following lines
# make sure that __project  calls the original project(). See
# https://cmake.org/pipermail/cmake/2015-October/061751.html. Ensure that
# _project points to the original version
function(project)
endfunction()

# Ensure that __project points to the original version
function(_project)
endfunction()

macro(project project_name)
  set(CMAKE_SYSTEM_NAME Generic)

  __project(${project_name} LANGUAGES C CXX ASM)
  # Restore the original implementation
  function(project)
    set(project_ARGV ARGV)

    __project(${${project_ARGV}})

    set(PROJECT_NAME
        "${PROJECT_NAME}"
        PARENT_SCOPE)
    set(PROJECT_BINARY_DIR
        "${PROJECT_BINARY_DIR}"
        PARENT_SCOPE)
    set(PROJECT_SOURCE_DIR
        "${PROJECT_SOURCE_DIR}"
        PARENT_SCOPE)

    set(${PROJECT_NAME}_BINARY_DIR
        "${${PROJECT_NAME}_BINARY_DIR}"
        PARENT_SCOPE)
    set(${PROJECT_NAME}_SOURCE_DIR
        "${${PROJECT_NAME}_SOURCE_DIR}"
        PARENT_SCOPE)
  endfunction()

  # valiate compiler version
  # The reason to validate compiler version here is that cmake engine code will get CMAKE_C_COMPILER_VERSION and CMAKE_CXX_COMPILER_VERSION just in "project" macro invocation.
  _validate_compiler_version()
  clear_default_added_compiler_flags()
  # parse arguments
  set(options NO_DEFAULT_CONFIG)
  set(single_value PROJECT_BOARD_PORT_PATH PROJECT_DEVICE_PORT_PATH PROJECT_TYPE CUSTOM_LINKER)
  set(multi_value CUSTOM_PRJ_CONF_PATH)

  cmake_parse_arguments(_ "${options}" "${single_value}" "${multi_value}"
                        ${ARGN})

  log_and_validate_generator()

  # clean SdkRootDirPath
  get_filename_component(SdkRootDirPath "${SdkRootDirPath}" ABSOLUTE)
    
  # unset variable to avoid side effect by sysbuild beacuse it has been set in
  # sysbuild.cmake
  unset(APPLICATION_SOURCE_DIR)
  unset(APPLICATION_BINARY_DIR)

  set(APPLICATION_SOURCE_DIR
      ${CMAKE_CURRENT_LIST_DIR}
      CACHE PATH "Application Source Directory")
  set(APPLICATION_BINARY_DIR
      ${CMAKE_CURRENT_BINARY_DIR}
      CACHE PATH "Application Binary Directory")

  if(NOT CMAKE_EXECUTABLE_SUFFIX)
    set(CMAKE_EXECUTABLE_SUFFIX ".elf")
  endif()

  if (__NO_DEFAULT_CONFIG)
    set(NO_DEFAULT_CONFIG TRUE)
  endif()

  add_custom_target(
    pristine
    COMMAND
      ${CMAKE_COMMAND} -DBINARY_DIR=${APPLICATION_BINARY_DIR}
      -DSOURCE_DIR=${APPLICATION_SOURCE_DIR} -P
      ${SdkRootDirPath}/cmake/extension/pristine.cmake
    # Equivalent to rm -rf build/*
  )

  # check whether it is an internal example
  # Internal examples are put in INTERNAL_EXAMPLE_FOLDER
  string(FIND ${APPLICATION_SOURCE_DIR} ${INTERNAL_EXAMPLE_FOLDER} INDEX)

  if(${INDEX} GREATER -1)
    set(INTERNAL_EXAMPLE TRUE)
    set(EXAMPLE_FOLDER "examples_int")
  else()
    set(INTERNAL_EXAMPLE FALSE)
    set(EXAMPLE_FOLDER "examples")
  endif()

  # If using find_package McuxSDK
  if (MCUX_SDK_CMAKE_PACKAGE)
    # declare CMake project
    if (NOT DEFINED __PROJECT_TYPE)
      add_executable(app)
    elseif (${__PROJECT_TYPE} STREQUAL "EXECUTABLE")
      add_executable(app)
    elseif (${__PROJECT_TYPE} STREQUAL "LIBRARY")
      add_library(app)
    elseif (${__PROJECT_TYPE} STREQUAL "LIBRARY_OBJECT")
      add_library(app OBJECT)
    else()
      log_fatal("Unsupported project type: ${__PROJECT_TYPE}, EXECUTABLE, LIBRARY or LIBRARY_OBJECT")
    endif ()

    target_link_libraries(app PRIVATE McuxSDK)
    set(APPLICATION_BINARY_NAME app)

    reset_app_link_order()

    # create a dummy file in case there is no source for app
    set(dummy_file mcux_dummy_file.c)
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E touch ${dummy_file}
      WORKING_DIRECTORY ${APPLICATION_BINARY_DIR}
    )
    target_sources(app PRIVATE ${APPLICATION_BINARY_DIR}/${dummy_file})
    
    if (__CUSTOM_LINKER)
      remove_defined_linker()
    endif()
  else ()
    # check wether core_id_suffix_name is empty
    if(NOT core_id_suffix_name)
      set(MCUX_SDK_PROJECT_NAME ${PROJECT_NAME})
    else()
      set(MCUX_SDK_PROJECT_NAME ${PROJECT_NAME}${core_id_suffix_name})
    endif()

    ########################################################
    # region Check the availability of the app project
    ########################################################
    file(RELATIVE_PATH APP_SOURCE_REL_DIR ${SdkRootDirPath} ${APPLICATION_SOURCE_DIR})
    if (DEFINED core_id)
      set(board_core "${board}@${core_id}")
    else()
      set(board_core "${board}")
    endif()

    set(EXTRA_ARGS --cmake_invoke -l none --validate)
    if ((DEFINED shield) AND (NOT ${shield} STREQUAL None))
      list(APPEND EXTRA_ARGS --shield ${shield})
    endif()

    if(HINT)
      execute_process(
        COMMAND ${CMAKE_COMMAND} -E env ${EXAMPLE_EXISTENCE_CHECK_ENV_SETTINGS}
                  west list_project -p ${APP_SOURCE_REL_DIR} -b ${board_core} --toolchain ${CONFIG_TOOLCHAIN} --config ${CMAKE_BUILD_TYPE} ${EXTRA_ARGS}
        WORKING_DIRECTORY ${SdkRootDirPath}
        OUTPUT_VARIABLE EXAMPLE_LIST
        RESULT_VARIABLE ret)

      # Do not set any return value for the build process
      if(ret EQUAL -2)
        # log_warn(
        #   "Failed to run scripts/misc/example_list.py, the exception is ${EXAMPLE_LIST}"
        # )
      elseif(ret EQUAL -1)
        # log_warn("${EXAMPLE_LIST}")
      endif()
    endif()

    ########################################################
    # endregion
    ########################################################

    # declare CMake project
    if (NOT DEFINED __PROJECT_TYPE)
      add_executable(${MCUX_SDK_PROJECT_NAME})
    elseif (${__PROJECT_TYPE} STREQUAL "EXECUTABLE")
      add_executable(${MCUX_SDK_PROJECT_NAME})
    elseif (${__PROJECT_TYPE} STREQUAL "LIBRARY")
      add_library(${MCUX_SDK_PROJECT_NAME})
    elseif (${__PROJECT_TYPE} STREQUAL "LIBRARY_OBJECT")
      add_library(${MCUX_SDK_PROJECT_NAME} OBJECT)
    else()
      log_fatal("Unsupported project type: ${__PROJECT_TYPE}, it should be EXECUTABLE, LIBRARY or LIBRARY_OBJECT")
    endif ()

    # get full_project_board_port_path
    set(project_board_port_path ${__PROJECT_BOARD_PORT_PATH})
    set(project_device_port_path ${__PROJECT_DEVICE_PORT_PATH})

    if (DEFINED project_board_port_path)
      if (DEFINED core_id)
        cmake_path(APPEND full_project_port_path ${SdkRootDirPath} ${project_board_port_path} ${core_id})
      else()
        cmake_path(APPEND full_project_port_path ${SdkRootDirPath} ${project_board_port_path})
      endif()
      # remain the full_project_board_port_path for backward compatible
      set(full_project_board_port_path ${full_project_port_path})
      set(board_device_folder "${board}")
      log_debug("full_project_port_path: ${full_project_port_path}")
    elseif (DEFINED project_device_port_path)
      if (DEFINED core_id)
        cmake_path(APPEND full_project_port_path ${SdkRootDirPath} ${project_device_port_path} ${core_id})
      else()
        cmake_path(APPEND full_project_port_path ${SdkRootDirPath} ${project_device_port_path})
      endif()
      set(board_device_folder "${device}")
      log_debug("full_project_port_path: ${full_project_port_path}")
    endif ()

    # Get custom prj.conf
    if (DEFINED __CUSTOM_PRJ_CONF_PATH)
      foreach(path ${__CUSTOM_PRJ_CONF_PATH})
        if(IS_ABSOLUTE ${path})
          cmake_path(APPEND full_prj_conf_path ${path} "prj.conf")
        else ()
          cmake_path(APPEND full_prj_conf_path ${SdkRootDirPath} ${path} "prj.conf")
        endif ()

        if (EXISTS ${full_prj_conf_path})
          list(APPEND CUSTOM_PRJ_CONF_PATHS ${full_prj_conf_path})
        else ()
          log_warn("${path} in project CUSTOM_PRJ_CONF_PATH does not have a prj.conf inside" ${CMAKE_CURRENT_LIST_FILE})
        endif ()
      endforeach()
      if (NOT CUSTOM_PRJ_CONF_PATHS)
        log_warn("There is no prj.conf in any path of CUSTOM_PRJ_CONF_PATH" ${CMAKE_CURRENT_LIST_FILE})
      endif()
    endif()
    if(DEFINED EXTRA_MCUX_MODULES)
      # extra module must be added first, then kconfig.cmake can add kconfig file from extra module
      include(${SdkRootDirPath}/cmake/extension/mcux_module.cmake)
    endif ()

    # kconfig process
    include(${SdkRootDirPath}/cmake/extension/kconfig.cmake)
  endif ()

  # run / debug support
  include(${SdkRootDirPath}/cmake/extension/run.cmake)

  # load ide data
  mcux_load_project_ide_data()

  #load extra modules
  if(DEFINED EXTRA_MCUX_MODULES)
    mcux_load_extra_module()
  endif()

  # gui project generation
  include(${SdkRootDirPath}/cmake/extension/guigenerator.cmake)
endmacro()

cmake_language(DEFER DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} CALL hook_end_configure())

function(hook_end_configure)
  dump_gui_project_data()
endfunction()

macro(log_and_validate_generator)
  log_status("CMake Generator: ${CMAKE_GENERATOR}")
  log_status("CMake Generator location: ${CMAKE_MAKE_PROGRAM}")

  if (CMAKE_GENERATOR STREQUAL "Ninja")
    set(NINJA "ninja")
    set(NINJA_FLAG "--version")
    execute_process(
            COMMAND ${NINJA} ${NINJA_FLAG}
            WORKING_DIRECTORY ${SdkRootDirPath}
            OUTPUT_VARIABLE NINJA_VERSION
            RESULT_VARIABLE ret)
    if (ret EQUAL 0)
      string(STRIP ${NINJA_VERSION} NINJA_VERSION)
      log_status("Ninja version: ${NINJA_VERSION}")
      if (NINJA_VERSION VERSION_LESS ${NINJA_MINIMUM_VERSION})
        message("warning: The system Ninja version ${NINJA_VERSION} is lower than the recommended version ${NINJA_MINIMUM_VERSION} which may cause unexpected build failure especially for complicated project. Please upgrade Ninja to version ${NINJA_MINIMUM_VERSION} or above.")
      endif()
    else ()
      log_fatal("Failed to get Ninja version with '${NINJA} ${NINJA_FLAG}'")
    endif ()
  endif ()
endmacro()

# clear default added compiler flags
macro(clear_default_added_compiler_flags)
  string(TOUPPER ${CMAKE_BUILD_TYPE} CMAKE_BUILD_TYPE_UPPER_CASE)

  set(CMAKE_ASM_FLAGS_${CMAKE_BUILD_TYPE_UPPER_CASE} "")
  set(CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE_UPPER_CASE} "")
  set(CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE_UPPER_CASE} "")
  set(CMAKE_EXE_LINKER_FLAGS_${CMAKE_BUILD_TYPE_UPPER_CASE} "")
endmacro()