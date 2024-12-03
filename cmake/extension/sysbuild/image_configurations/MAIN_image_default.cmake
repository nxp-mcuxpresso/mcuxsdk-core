# Copyright (c) 2023 Nordic Semiconductor
# Copyright 2024 NXP
# SPDX-License-Identifier: Apache-2.0

# This sysbuild CMake file sets the sysbuild controlled settings as properties
# on the main Zephyr image.

if(SB_CONFIG_BOOTLOADER_MCUBOOT)
  if("${SB_CONFIG_SIGNATURE_TYPE}" STREQUAL "NONE")
    set_config_bool(${ZCMAKE_APPLICATION} CONFIG_MCUBOOT_GENERATE_UNSIGNED_IMAGE y)
  else()
    set_config_bool(${ZCMAKE_APPLICATION} CONFIG_MCUBOOT_GENERATE_UNSIGNED_IMAGE n)
  endif()
endif()
