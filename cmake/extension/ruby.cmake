# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

include_guard(GLOBAL)
set(RUBY_MINIMUM_REQUIRED 3.1.2)
set(ruby_install_link "https://mcuxpresso.nxp.com/mcuxsdk/latest/html/develop/build_system/Build_And_Configuration_System_Based_On_CMake_And_Kconfig.html#prerequisite")

if(NOT FOUND_RUBY_EXECUTABLE)
    find_program(RUBY_EXECUTABLE ruby)
    if(RUBY_EXECUTABLE)
        execute_process (COMMAND "${RUBY_EXECUTABLE}" -v
                RESULT_VARIABLE result
                OUTPUT_VARIABLE version
                OUTPUT_STRIP_TRAILING_WHITESPACE)
        message(STATUS "Found Ruby: ${version}")
        set(FOUND_RUBY_EXECUTABLE true CACHE INTERNAL "")
    else()
        log_debug("Ruby is not found. GUI project and standalone project generation features can not be supported. Please follow ${ruby_install_link} to install ruby.")
    endif()
endif()

