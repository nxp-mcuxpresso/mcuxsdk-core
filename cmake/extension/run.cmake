# Copyright 2024-2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
add_custom_target(runners_yaml_props_target)

include(${SdkRootDirPath}/cmake/extension/flash/extensions.cmake)

if (DEFINED CUSTOM_BOARD_ROOT AND NOT CUSTOM_BOARD_ROOT STREQUAL "")
include(${CUSTOM_BOARD_ROOT}/${board}/board_runner.cmake OPTIONAL)
else()
include(${SdkRootDirPath}/${board_root}/${board}/board_runner.cmake OPTIONAL)
endif()

# Global hex/bin conversion, gated by Kconfig (Zephyr-style).
#
# The conversion is deferred to the end of the directory scope so that it
# runs AFTER the example body (including any reconfig.cmake files).  This
# guarantees that mcux_convert_binary() call sites in the example have
# already stamped MCUX_BINARY_CONVERSION_REGISTERED on the target before the
# helper below executes.  If the target already registered its own conversion
# (e.g. wireless examples that produce a .bin or multicore examples that
# produce a core1_image.bin for linking) we skip the global step entirely so
# we do not disrupt POST_BUILD ordering or the IDE guigenerator's binary-file
# selection (ninja_parser.rb picks the first matching artifact from the
# POST_BUILD string and breaks -- inserting a .hex before an existing .bin
# would make it pick the wrong artifact and break IAR multicore builds).
#
# Guard with TARGET check so library projects and find_package flows are skipped.
if(TARGET "${MCUX_SDK_PROJECT_NAME}")
  function(_mcux_add_global_output_conversion target_name bin_dir bin_name)
    get_target_property(_already "${target_name}" MCUX_BINARY_CONVERSION_REGISTERED)
    if(_already STREQUAL "TRUE")
      return()
    endif()
    if(CONFIG_MCUX_BUILD_OUTPUT_HEX)
      mcux_convert_binary(
        TARGET "${target_name}"
        BINARY "${bin_dir}/${bin_name}.hex"
      )
    endif()
    if(CONFIG_MCUX_BUILD_OUTPUT_BIN)
      mcux_convert_binary(
        TARGET "${target_name}"
        BINARY "${bin_dir}/${bin_name}.bin"
      )
    endif()
  endfunction()
  cmake_language(DEFER CALL _mcux_add_global_output_conversion
    "${MCUX_SDK_PROJECT_NAME}"
    "${APPLICATION_BINARY_DIR}"
    "${APPLICATION_BINARY_NAME}"
  )
endif()

mcux_add_cmakelists(${SdkRootDirPath}/cmake/extension/flash)
