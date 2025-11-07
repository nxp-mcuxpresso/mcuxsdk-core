#
# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Generate mcuxsdk_version.h and pre-include it.

# Ensure variables are available
if(NOT DEFINED MCUXSDK_MAIN_VERSION)
  include("${CMAKE_CURRENT_LIST_DIR}/mcux_version.cmake")
endif()

if(DEFINED MCUXSDK_VERSION_HEADER_DIR)
  set(_ver_hdr "${MCUXSDK_VERSION_HEADER_DIR}/mcuxsdk_version.h")
else()
  set(_ver_hdr "${CMAKE_CURRENT_BINARY_DIR}/mcuxsdk_version.h")
endif()

# Normalize and ensure directory exists
get_filename_component(_ver_hdr "${_ver_hdr}" ABSOLUTE)
get_filename_component(_ver_dir "${_ver_hdr}" DIRECTORY)
if(NOT IS_DIRECTORY "${_ver_dir}")
  file(MAKE_DIRECTORY "${_ver_dir}")
endif()

# Optional PVW define (only when prerelease matches pvwN)
set(_pvw_define "")
if(DEFINED MCUXSDK_PVW_NUMBER AND NOT MCUXSDK_PVW_NUMBER STREQUAL "")
  set(_pvw_define "#define MCUXSDK_VERSION_PVW       ${MCUXSDK_PVW_NUMBER}")
endif()

# Dynamic copyright year
string(TIMESTAMP _copyright_year "%Y")

# Remove leading zeros in MCUXSDK_VERSION_MAJOR, MCUXSDK_VERSION_MINOR, in case of
# violating MISRA C 2012 rule 7.1: Octal constrains shall not be used.
math(EXPR MCUXSDK_VERSION_MAJOR_NUM "${MCUXSDK_VERSION_MAJOR}")
math(EXPR MCUXSDK_VERSION_MINOR_NUM "${MCUXSDK_VERSION_MINOR}")

file(
  WRITE "${_ver_hdr}"
  "/*\n * Copyright ${_copyright_year} NXP\n *\n * SPDX-License-Identifier: BSD-3-Clause\n */\n
#ifndef MCUXSDK_VERSION_H_
#define MCUXSDK_VERSION_H_

#define MCUXSDK_VERSION_YEAR      ${MCUXSDK_VERSION_YEAR}
#define MCUXSDK_VERSION_MAJOR     ${MCUXSDK_VERSION_MAJOR_NUM}
#define MCUXSDK_VERSION_MINOR     ${MCUXSDK_VERSION_MINOR_NUM}
${_pvw_define}

#define MCUXSDK_VERSION_NUM       (MCUXSDK_VERSION_YEAR * 10000 + MCUXSDK_VERSION_MAJOR * 100 + MCUXSDK_VERSION_MINOR)
#define MCUXSDK_VERSION_FULL_STR  \"${MCUXSDK_VERSION_FULL}\"

#endif /* MCUXSDK_VERSION_H_ */
")

# Add as preinclude (same pattern as kconfig.cmake)
if(COMMAND mcux_add_source)
  mcux_add_source(PREINCLUDE TRUE BASE_PATH ${_ver_dir} SOURCES
                  "mcuxsdk_version.h")
else()
  # Fallback: ensure the header is discoverable
  if(DEFINED MCUX_SDK_PROJECT_NAME AND TARGET ${MCUX_SDK_PROJECT_NAME})
    target_include_directories(${MCUX_SDK_PROJECT_NAME} PUBLIC ${_ver_dir})
  endif()
endif()

if(COMMAND log_status)
  log_status("Generated ${_ver_hdr}")
else()
  message(STATUS "Generated ${_ver_hdr}")
endif()

# Cleanup locals
unset(_ver_dir)
unset(_ver_hdr)
unset(_pvw_define)
