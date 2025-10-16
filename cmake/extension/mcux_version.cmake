#
# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Exports (in caller scope after include): - MCUXSDK_ROOT_DIR -
# MCUXSDK_MAIN_VERSION     : "YY.MM.NN" (numeric, no suffix) -
# MCUXSDK_VERSION_FULL     : "YYYY.MM.NN[-pvwX]" - MCUXSDK_PRERELEASE       :
# "pvwX" if present - MCUXSDK_VERSION_YEAR     : YYYY (number) -
# MCUXSDK_VERSION_MAJOR    : MM   (number) - MCUXSDK_VERSION_MINOR    : NN
# (number) - MCUXSDK_PVW_NUMBER       : N    (number, optional) -
# MCUXSDK_HAS_VERSION      : TRUE/FALSE

# Resolve SDK root
if(DEFINED SdkRootDirPath)
  set(MCUXSDK_ROOT_DIR "${SdkRootDirPath}")
else()
  get_filename_component(_ext_dir "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY
  )# .../cmake
  get_filename_component(MCUXSDK_ROOT_DIR "${_ext_dir}" DIRECTORY) # .../<root>
endif()
file(TO_CMAKE_PATH "${MCUXSDK_ROOT_DIR}" MCUXSDK_ROOT_DIR)

set(_mcux_version_file "${MCUXSDK_ROOT_DIR}/MCUX_VERSION")
if(EXISTS "${_mcux_version_file}")
  set_property(
    DIRECTORY
    APPEND
    PROPERTY CMAKE_CONFIGURE_DEPENDS "${_mcux_version_file}")
endif()

unset(MCUXSDK_MAIN_VERSION)
unset(MCUXSDK_VERSION_FULL)
unset(MCUXSDK_PRERELEASE)
unset(MCUXSDK_PVW_NUMBER)
unset(MCUXSDK_VERSION_YEAR)
unset(MCUXSDK_VERSION_MAJOR)
unset(MCUXSDK_VERSION_MINOR)
set(MCUXSDK_HAS_VERSION FALSE)

set(_yy "0") # year (YY)
set(_mm "0") # major (MM)
set(_nn "0") # minor (NN)
set(_suffix "")

if(EXISTS "${_mcux_version_file}")
  file(READ "${_mcux_version_file}" _mcux_ver_text)

  string(REGEX MATCH "CURRENT_YEAR[ \t]*=[ \t]*([0-9]+)" _m_year
               "${_mcux_ver_text}")
  if(CMAKE_MATCH_1)
    set(_yy "${CMAKE_MATCH_1}")
  endif()

  string(REGEX MATCH "VERSION_MAJOR[ \t]*=[ \t]*([0-9]+)" _m_major
               "${_mcux_ver_text}")
  if(CMAKE_MATCH_1)
    set(_mm "${CMAKE_MATCH_1}")
  endif()

  string(REGEX MATCH "VERSION_MINOR[ \t]*=[ \t]*([0-9]+)(-[A-Za-z0-9_.+-]+)?"
               _m_minor "${_mcux_ver_text}")
  if(CMAKE_MATCH_1)
    set(_nn "${CMAKE_MATCH_1}")
  endif()
  if(CMAKE_MATCH_2)
    set(_suffix "${CMAKE_MATCH_2}") # e.g. "-pvw1"
    string(REGEX REPLACE "^-" "" MCUXSDK_PRERELEASE "${_suffix}") # "pvw1"
    if(MCUXSDK_PRERELEASE MATCHES "^pvw([0-9]+)$")
      set(MCUXSDK_PVW_NUMBER "${CMAKE_MATCH_1}")
    endif()
  endif()

  # Compose numeric main version YY.MM.NN
  set(MCUXSDK_MAIN_VERSION "${_yy}.${_mm}.${_nn}")

  # Map YY to YYYY (assume 2000+YY unless already 4 digits)
  if(_yy MATCHES "^[0-9]+$" AND _yy LESS 1000)
    math(EXPR MCUXSDK_VERSION_YEAR "2000 + ${_yy}")
  else()
    set(MCUXSDK_VERSION_YEAR "${_yy}")
  endif()

  set(MCUXSDK_VERSION_MAJOR "${_mm}")
  set(MCUXSDK_VERSION_MINOR "${_nn}")

  if(DEFINED MCUXSDK_PRERELEASE AND NOT MCUXSDK_PRERELEASE STREQUAL "")
    set(MCUXSDK_VERSION_FULL
        "${MCUXSDK_VERSION_YEAR}.${_mm}.${_nn}-${MCUXSDK_PRERELEASE}")
  else()
    set(MCUXSDK_VERSION_FULL "${MCUXSDK_VERSION_YEAR}.${_mm}.${_nn}")
  endif()

  set(MCUXSDK_HAS_VERSION TRUE)
else()
  if(COMMAND log_warn)
    log_warn("MCUX_VERSION file not found at ${_mcux_version_file}"
             ${CMAKE_CURRENT_LIST_FILE})
  else()
    message(WARNING "MCUX_VERSION file not found at ${_mcux_version_file}")
  endif()
  # Sensible defaults for consumers
  set(MCUXSDK_MAIN_VERSION "0.0.0")
  set(MCUXSDK_VERSION_FULL "0.0.0")
  set(MCUXSDK_VERSION_YEAR 0)
  set(MCUXSDK_VERSION_MAJOR 0)
  set(MCUXSDK_VERSION_MINOR 0)
endif()

# Cleanup locals
unset(_mcux_ver_text)
unset(_m_year)
unset(_m_major)
unset(_m_minor)
unset(_yy)
unset(_mm)
unset(_nn)
unset(_suffix)
unset(_ext_dir)
