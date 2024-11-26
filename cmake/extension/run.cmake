# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
add_custom_target(runners_yaml_props_target)

include(${SdkRootDirPath}/cmake/extension/flash/extensions.cmake)

include(${SdkRootDirPath}/${board_root}/${board}/board_runner.cmake)

mcux_add_cmakelists(${SdkRootDirPath}/cmake/extension/flash)
