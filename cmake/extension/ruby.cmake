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
        if (GENERATE_GUI_PROJECT OR GENERATE_STANDALONE_PROJECT)
            # only disable warning
        endif ()
    else()
        if (GENERATE_GUI_PROJECT OR GENERATE_STANDALONE_PROJECT)
            log_fatal("GUI project or standalone project generation depends on ruby environment to work, but ruby is not found in your system. Please follow ${ruby_install_link} to install ruby.")
        else ()
            log_debug("Ruby is not found. GUI project or standalone project generation depends on ruby environment to work. If you need to generate GUI project or standalone project, please follow ${ruby_install_link} to install ruby.")
        endif ()
    endif ()
endif()

