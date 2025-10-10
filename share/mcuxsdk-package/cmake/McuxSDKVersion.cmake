# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

# Parse mcuxsdk/MCUX_VERSION and provide:
# - MCUXSDK_MAIN_VERSION: numeric "YY.MM.NN" (minor drops any "-suffix")
# - MCUXSDK_VERSION_FULL: full string with suffix if present, e.g. "25.12.00-pvw1"
# - MCUXSDK_PRERELEASE: suffix without leading dash, e.g. "pvw1" (optional)
# - MCUXSDK_ROOT_DIR: SDK root directory

# Locate SDK root from this module path: <root>/share/mcuxsdk-package/cmake
get_filename_component(_mcux_pkg_dir "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY)   # .../share/mcuxsdk-package
get_filename_component(_mcux_share_dir "${_mcux_pkg_dir}" DIRECTORY)          # .../share
get_filename_component(MCUXSDK_ROOT_DIR "${_mcux_share_dir}" DIRECTORY)       # .../<sdk root>

set(_mcux_version_file "${MCUXSDK_ROOT_DIR}/MCUX_VERSION")
unset(MCUXSDK_MAIN_VERSION)
unset(MCUXSDK_VERSION_FULL)
unset(MCUXSDK_PRERELEASE)

if(EXISTS "${_mcux_version_file}")
  file(READ "${_mcux_version_file}" _mcux_ver_text)

  string(REGEX MATCH "CURRENT_YEAR[ \t]*=[ \t]*([0-9]+)" _m_year "${_mcux_ver_text}")
  if(CMAKE_MATCH_1)
    set(_mcux_year "${CMAKE_MATCH_1}")
  endif()

  string(REGEX MATCH "VERSION_MAJOR[ \t]*=[ \t]*([0-9]+)" _m_major "${_mcux_ver_text}")
  if(CMAKE_MATCH_1)
    set(_mcux_major "${CMAKE_MATCH_1}")
  endif()

  # VERSION_MINOR may be "00" or "00-pvw1" — keep only numeric for MAIN, capture suffix for FULL
  string(REGEX MATCH "VERSION_MINOR[ \t]*=[ \t]*([0-9]+)(-[A-Za-z0-9_.+-]+)?" _m_minor "${_mcux_ver_text}")
  if(CMAKE_MATCH_1)
    set(_mcux_minor "${CMAKE_MATCH_1}")
  endif()
  if(CMAKE_MATCH_2)
    set(_mcux_suffix "${CMAKE_MATCH_2}")                                   # e.g. "-pvw1"
    string(REGEX REPLACE "^-" "" MCUXSDK_PRERELEASE "${_mcux_suffix}")     # "pvw1"
  endif()

  if(_mcux_year AND _mcux_major AND _mcux_minor)
    set(MCUXSDK_MAIN_VERSION "${_mcux_year}.${_mcux_major}.${_mcux_minor}")
    if(DEFINED _mcux_suffix)
      set(MCUXSDK_VERSION_FULL "${MCUXSDK_MAIN_VERSION}${_mcux_suffix}")
    else()
      set(MCUXSDK_VERSION_FULL "${MCUXSDK_MAIN_VERSION}")
    endif()
  endif()
endif()

# Fallbacks
if(NOT DEFINED MCUXSDK_MAIN_VERSION)
  set(MCUXSDK_MAIN_VERSION "3.0.0")
  set(MCUXSDK_VERSION_FULL "${MCUXSDK_MAIN_VERSION}")
endif()

# Clean locals
unset(_mcux_pkg_dir)
unset(_mcux_share_dir)
unset(_mcux_version_file)
unset(_mcux_ver_text)
unset(_m_year)
unset(_m_major)
unset(_m_minor)
unset(_mcux_year)
unset(_mcux_major)
unset(_mcux_minor)
unset(_mcux_suffix)