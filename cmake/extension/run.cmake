# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
add_custom_target(runners_yaml_props_target)

include(${SdkRootDirPath}/cmake/extension/flash/extensions.cmake)

if (DEFINED CUSTOM_BOARD_ROOT AND NOT CUSTOM_BOARD_ROOT STREQUAL "")
include(${CUSTOM_BOARD_ROOT}/${board}/board_runner.cmake OPTIONAL)
else()
include(${SdkRootDirPath}/${board_root}/${board}/board_runner.cmake OPTIONAL)
endif()

mcux_add_cmakelists(${SdkRootDirPath}/cmake/extension/flash)
