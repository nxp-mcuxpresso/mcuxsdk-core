# SPDX-License-Identifier: Apache-2.0
#
# Originally modified from:
#   https://github.com/zephyrproject-rtos/zephyr/blame/main/cmake/modules/extensions.cmake

# Copyright 2024-2025 NXP

function(board_runner_args runner)
  string(MAKE_C_IDENTIFIER ${runner} runner_id)
  set_property(GLOBAL APPEND PROPERTY BOARD_RUNNER_ARGS_EXPLICIT_${runner_id} ${ARGN})
endfunction()

macro(board_set_flasher_ifnset runner)
  board_set_runner_ifnset(FLASH ${runner})
endmacro()

macro(board_set_runner_ifnset type runner)
  _board_check_runner_type(${type})
  set_ifndef(BOARD_${type}_RUNNER ${runner})
endmacro()

macro(board_set_debugger_ifnset runner)
  board_set_runner_ifnset(DEBUG ${runner})
endmacro()

function(board_finalize_runner_args runner)
  # If the application provided a macro to add additional runner
  # arguments, handle them.
  if(COMMAND app_set_runner_args)
    app_set_runner_args()
  endif()

  # Retrieve the list of explicitly set arguments.
  string(MAKE_C_IDENTIFIER ${runner} runner_id)
  get_property(explicit GLOBAL PROPERTY "BOARD_RUNNER_ARGS_EXPLICIT_${runner_id}")

  # Note no _EXPLICIT_ here. This property contains the final list.
  set_property(GLOBAL APPEND PROPERTY BOARD_RUNNER_ARGS_${runner_id}
    # Default arguments from the common runner file come first.
    ${ARGN}
    # Arguments explicitly given with board_runner_args() come
    # next, so they take precedence over the common runner file.
    ${explicit}
    # Arguments given via the CMake cache come last of all. Users
    # can provide variables in this way from the CMake command line.
    ${BOARD_RUNNER_ARGS_${runner_id}}
    )

  # Add the finalized runner to the global property list.
  set_property(GLOBAL APPEND PROPERTY ZEPHYR_RUNNERS ${runner})
endfunction()

function(_board_check_runner_type type) # private helper
  if (NOT (("${type}" STREQUAL "FLASH") OR ("${type}" STREQUAL "DEBUG")))
    message(FATAL_ERROR "invalid type ${type}; should be FLASH or DEBUG")
  endif()
endfunction()

function(set_ifndef variable value)
  if(NOT ${variable})
    set(${variable} ${value} ${ARGN} PARENT_SCOPE)
  endif()
endfunction()

function(zephyr_get variable)
  cmake_parse_arguments(GET_VAR "MERGE;REVERSE" "SYSBUILD" "VAR" ${ARGN})

  if(DEFINED GET_VAR_SYSBUILD)
    if(NOT ("${GET_VAR_SYSBUILD}" STREQUAL "GLOBAL" OR
            "${GET_VAR_SYSBUILD}" STREQUAL "LOCAL")
    )
      message(FATAL_ERROR "zephyr_get(... SYSBUILD) requires GLOBAL or LOCAL.")
    endif()
  else()
    set(GET_VAR_SYSBUILD "GLOBAL")
  endif()

  if(GET_VAR_REVERSE AND NOT GET_VAR_MERGE)
    message(FATAL_ERROR "zephyr_get(... REVERSE) missing a required argument: MERGE")
  endif()

  if(NOT DEFINED GET_VAR_VAR)
    set(GET_VAR_VAR ${variable})
  endif()

  # Keep current scope variables in internal variables.
  # This is needed to properly handle cases where we want to check value against
  # environment value or when appending with the MERGE operation.
  foreach(var ${GET_VAR_VAR})
    set(current_${var} ${${var}})
    set(${var})

    if(SYSBUILD)
      get_property(sysbuild_name TARGET sysbuild_cache PROPERTY SYSBUILD_NAME)
      get_property(sysbuild_main_app TARGET sysbuild_cache PROPERTY SYSBUILD_MAIN_APP)
      get_property(sysbuild_local_${var} TARGET sysbuild_cache PROPERTY ${sysbuild_name}_${var})
      get_property(sysbuild_global_${var} TARGET sysbuild_cache PROPERTY ${var})
      if(NOT DEFINED sysbuild_local_${var} AND sysbuild_main_app)
        set(sysbuild_local_${var} ${sysbuild_global_${var}})
      endif()
      if(NOT "${GET_VAR_SYSBUILD}" STREQUAL "GLOBAL")
        set(sysbuild_global_${var})
      endif()
    else()
      set(sysbuild_local_${var})
      set(sysbuild_global_${var})
    endif()

    if(TARGET snippets_scope)
      get_property(snippets_${var} TARGET snippets_scope PROPERTY ${var})
    endif()
  endforeach()

  set(${variable} "")
  set(scopes "sysbuild_local;sysbuild_global;CACHE;snippets;ENV;current")
  if(GET_VAR_REVERSE)
    list(REVERSE scopes)
  endif()
  foreach(scope IN LISTS scopes)
    foreach(var ${GET_VAR_VAR})
      zephyr_var_name("${var}" "${scope}" expansion_var)
      if(DEFINED expansion_var)
        string(CONFIGURE "${expansion_var}" scope_value)
        if(GET_VAR_MERGE)
          list(APPEND ${variable} ${scope_value})
        else()
          set(${variable} ${scope_value} PARENT_SCOPE)

          if("${scope}" STREQUAL "ENV")
            # Set the environment variable in CMake cache, so that a build
            # invocation triggering a CMake rerun doesn't rely on the
            # environment variable still being available / have identical value.
            set(${var} $ENV{${var}} CACHE INTERNAL "Cached environment variable ${var}")
          endif()

          if("${scope}" STREQUAL "ENV" AND DEFINED current_${var}
             AND NOT "${current_${var}}" STREQUAL "$ENV{${var}}"
          )
            # Variable exists as current scoped variable, defined in a CMakeLists.txt
            # file, however it is also set in environment.
            # This might be a surprise to the user, so warn about it.
            message(WARNING "environment variable '${var}' is hiding local "
                            "variable of same name.\n"
                            "Environment value (in use): $ENV{${var}}\n"
                            "Current scope value (hidden): ${current_${var}}\n"
            )
          endif()

          return()
        endif()
      endif()
    endforeach()
  endforeach()

  if(GET_VAR_MERGE)
    if(GET_VAR_REVERSE)
      list(REVERSE ${variable})
      list(REMOVE_DUPLICATES ${variable})
      list(REVERSE ${variable})
    else()
      list(REMOVE_DUPLICATES ${variable})
    endif()
    set(${variable} ${${variable}} PARENT_SCOPE)
  endif()
endfunction(zephyr_get variable)

function(zephyr_var_name variable scope out)
  if(scope STREQUAL "ENV" OR scope STREQUAL "CACHE")
    if(DEFINED ${scope}{${variable}})
      set(${out} "$${scope}{${variable}}" PARENT_SCOPE)
    else()
      set(${out} PARENT_SCOPE)
    endif()
  else()
    if(DEFINED ${scope}_${variable})
      set(${out} "${${scope}_${variable}}" PARENT_SCOPE)
    else()
      set(${out} PARENT_SCOPE)
    endif()
  endif()
endfunction()

function(find_arm_gdb)
  set(ARMGCC_ROOT $ENV{ARMGCC_DIR})
  set(CMAKE_GDB $ENV{GDB})
  if(NOT ARMGCC_ROOT)
    message(WARNING "Cannot find 'ARMGCC_DIR' to get gdb, so west debug may not work.")
    return()
  endif()

  if(CMAKE_GDB)
    message(STATUS "Use GDB specified by envirorment variable GDB=${CMAKE_GDB}")
    set(CMAKE_GDB $ENV{GDB} PARENT_SCOPE)
    return()
  else()
    message(STATUS "GDB is not specified by envirorment variable GDB, try to use gdb provided by toolchain")
  endif()

  find_program(CMAKE_GDB     ${ARMGCC_ROOT}/bin/${CMAKE_PREFIX}gdb-py  PATHS ${ARMGCC_ROOT} NO_DEFAULT_PATH)

  if(CMAKE_GDB)
    execute_process(
      COMMAND ${CMAKE_GDB} --configuration
      RESULTS_VARIABLE GDB_CFG_ERR
      OUTPUT_QUIET
      ERROR_QUIET
      )
  endif()

  if(NOT CMAKE_GDB OR GDB_CFG_ERR)
    find_program(CMAKE_GDB_NO_PY ${ARMGCC_ROOT}/bin/${CMAKE_PREFIX}gdb PATHS ${ARMGCC_ROOT} NO_DEFAULT_PATH)

    if(CMAKE_GDB_NO_PY)
      set(CMAKE_GDB ${CMAKE_GDB_NO_PY} CACHE FILEPATH "Path to a program." FORCE)
    endif()
  endif()
endfunction()