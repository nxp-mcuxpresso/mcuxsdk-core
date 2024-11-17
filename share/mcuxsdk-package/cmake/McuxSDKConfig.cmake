# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

# This file provides Mcux SDK Package functionality supporting automatic Mcux SDK installation lookup through the use of find_package(McuxSDK)

# First check to see if user has provided a Mcux SDK base manually. If SdkRootDirPath is provided, use it. If not, check the environment variable MCUX_SDK_BASE. 
# If MCUX_SDK_BASE is set, use it for SdkRootDirPath. If MCUX_SDK_BASE is not set, report error and stop build.

set(MCUX_SDK_CMAKE_PACKAGE TRUE)

if (NOT DEFINED SdkRootDirPath)
    get_filename_component(SdkRootDirPath ${CMAKE_CURRENT_LIST_DIR} DIRECTORY)
    get_filename_component(SdkRootDirPath ${SdkRootDirPath} DIRECTORY)
    get_filename_component(SdkRootDirPath ${SdkRootDirPath} DIRECTORY)
endif()

set(MCUX_SDK_PROJECT_NAME McuxSDK)
add_library(${MCUX_SDK_PROJECT_NAME} STATIC)

include(${SdkRootDirPath}/cmake/extension/mcux.cmake)

if(DEFINED EXTRA_MCUX_MODULES)
    # extra module must be added first, then kconfig.cmake can add kconfig file from extra module
    include(${SdkRootDirPath}/cmake/extension/mcux_module.cmake)
endif ()

if(DEFINED SYSBUILD)
    # Since SYSBUILD has already defined these variables, we should reset them for each project
    unset(APPLICATION_SOURCE_DIR)
    unset(APPLICATION_BINARY_DIR)

    set(APPLICATION_SOURCE_DIR
            ${CMAKE_HOME_DIRECTORY}
            CACHE PATH "Application Source Directory")
    set(APPLICATION_BINARY_DIR
            ${CMAKE_CURRENT_BINARY_DIR}
            CACHE PATH "Application Binary Directory")
endif()
include(${SdkRootDirPath}/cmake/extension/kconfig.cmake)

include(${SdkRootDirPath}/CMakeLists.txt)
