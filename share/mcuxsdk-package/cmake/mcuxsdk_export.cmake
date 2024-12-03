# Copyright 2020-2023 Nordic Semiconductor
# Copyright 2024 NXP
# Originally modified from:
# https://github.com/zephyrproject-rtos/zephyr/blob/main/share/zephyr-package/cmake/zephyr_export.cmake
# SPDX-License-Identifier: Apache-2.0

# Purpose of this CMake file is to install a McuxSDKConfig package reference in:
# Unix/Linux/MacOS: ~/.cmake/packages/McuxSDK
# Windows         : HKEY_CURRENT_USER
#
# Having McuxSDKConfig package allows for find_package(McuxSDK) to work when ZEPHYR_BASE is not defined.
#
# Create the reference by running `cmake -P mcuxsdk_export.cmake` in this directory.

string(MD5 MD5_SUM ${CMAKE_CURRENT_LIST_DIR})
if(WIN32)
  execute_process(COMMAND ${CMAKE_COMMAND}
                  -E  write_regv
                 "HKEY_CURRENT_USER\\Software\\Kitware\\CMake\\Packages\\McuxSDK\;${MD5_SUM}" "${CMAKE_CURRENT_LIST_DIR}"
)
else()
  file(WRITE $ENV{HOME}/.cmake/packages/McuxSDK/${MD5_SUM} ${CMAKE_CURRENT_LIST_DIR})
endif()

message("McuxSDK (${CMAKE_CURRENT_LIST_DIR})")
message("has been added to the user package registry in:")
if(WIN32)
  message("HKEY_CURRENT_USER\\Software\\Kitware\\CMake\\Packages\\McuxSDK\n")
else()
  message("~/.cmake/packages/McuxSDK\n")
endif()

file(REMOVE ${CMAKE_CURRENT_LIST_DIR}/${MD5_INFILE})
