# Copyright (c) 2021-2023 Nordic Semiconductor
# Copyright 2024 NXP
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.25.0)

include(${SdkRootDirPath}/cmake/extension/logging.cmake)
include(${SdkRootDirPath}/cmake/extension/python.cmake)
include(${SdkRootDirPath}/cmake/extension/ruby.cmake)

if(NOT DEFINED APP_DIR)
  message(FATAL_ERROR "No main application specified")
endif()

# This will update the APP_DIR cache variable to PATH type and apply a comment.
# If APP_DIR is a relative path, then CMake will adjust to absolute path based
# on current working dir.
set(APP_DIR ${APP_DIR} CACHE PATH "Main Application Source Directory")

# Add sysbuild/cmake/modules to CMAKE_MODULE_PATH which allows us to integrate
# sysbuild CMake modules with general Zephyr CMake modules.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake/modules)
# List of Zephyr and sysbuild CMake modules we need for sysbuild.
# Note: sysbuild_kconfig will internally load kconfig CMake module.
#set(zephyr_modules extensions
#    sysbuild_extensions python west root zephyr_module boards shields hwm_v2
#    sysbuild_kconfig native_simulator_sb_extensions
#  )
if(NOT DEFINED APPLICATION_SOURCE_DIR)
  set(APPLICATION_SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR} CACHE PATH
          "Application Source Directory"
          )
endif ()

if(NOT DEFINED APPLICATION_BINARY_DIR)
  set(APPLICATION_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR} CACHE PATH
          "Application Binary Directory"
          )
endif()

include(${CMAKE_CURRENT_LIST_DIR}/cmake/extensions.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/modules/sysbuild_extensions.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/modules/sysbuild_kconfig.cmake)


#find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE} COMPONENTS ${zephyr_modules})

project(sysbuild LANGUAGES)

set(CACHED_BOARD ${board} CACHE STRING "Selected board: ${board}")

get_filename_component(APP_DIR  ${APP_DIR} ABSOLUTE)
get_filename_component(app_name ${APP_DIR} NAME)
set(DEFAULT_IMAGE "${app_name}")

# This is where all Zephyr applications are added to the multi-image build.
sysbuild_add_subdirectory(images)

get_property(IMAGES GLOBAL PROPERTY sysbuild_images)
sysbuild_module_call(PRE_CMAKE MODULES ${SYSBUILD_MODULE_NAMES} IMAGES ${IMAGES})
sysbuild_images_order(IMAGES_CONFIGURATION_ORDER CONFIGURE IMAGES ${IMAGES})
foreach(image ${IMAGES_CONFIGURATION_ORDER})
  sysbuild_module_call(PRE_IMAGE_CMAKE MODULES ${SYSBUILD_MODULE_NAMES} IMAGES ${IMAGES} IMAGE ${image})
  ExternalZephyrProject_Cmake(APPLICATION ${image})
  sysbuild_module_call(POST_IMAGE_CMAKE MODULES ${SYSBUILD_MODULE_NAMES} IMAGES ${IMAGES} IMAGE ${image})
endforeach()
sysbuild_module_call(POST_CMAKE MODULES ${SYSBUILD_MODULE_NAMES} IMAGES ${IMAGES})

sysbuild_module_call(PRE_DOMAINS MODULES ${SYSBUILD_MODULE_NAMES} IMAGES ${IMAGES})
include(cmake/domains.cmake)
sysbuild_module_call(POST_DOMAINS MODULES ${SYSBUILD_MODULE_NAMES} IMAGES ${IMAGES})
