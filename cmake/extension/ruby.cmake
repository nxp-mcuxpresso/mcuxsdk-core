# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

include_guard(GLOBAL)
set(RUBY_MINIMUM_REQUIRED 3.1.2)
set(ruby_install_link "https://mcuxpresso.nxp.com/mcuxsdk/latest/html/develop/build_system/IDE_Project.html#ruby-environment-setup")

if(NOT FOUND_RUBY_EXECUTABLE)
    find_program(RUBY_EXECUTABLE ruby)
    if(RUBY_EXECUTABLE)
        execute_process (COMMAND "${RUBY_EXECUTABLE}" -v
                RESULT_VARIABLE result
                OUTPUT_VARIABLE version
                OUTPUT_STRIP_TRAILING_WHITESPACE)
        message(STATUS "Found Ruby: ${version}")
        set(FOUND_RUBY_EXECUTABLE true CACHE INTERNAL "")

        # check ruby version
        string(REGEX MATCH "^ruby ([0-9]+)\\.([0-9]+)\\.([0-9]+)" _match "${version}")
        if(NOT "${_match}" STREQUAL "")
            set(RUBY_VERSION ${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3})
            if (RUBY_VERSION VERSION_LESS ${RUBY_MINIMUM_REQUIRED})
                log_status("warning: The system Ruby version ${RUBY_VERSION} is lower than the minimum version ${RUBY_MINIMUM_REQUIRED}. Please follow ${ruby_install_link} to install ruby.")
            endif()
        endif()
    else()
        log_status("warning: Ruby is not found. GUI project and standalone project generation features can not be supported. Please follow ${ruby_install_link} to install ruby.")
    endif()
endif()

