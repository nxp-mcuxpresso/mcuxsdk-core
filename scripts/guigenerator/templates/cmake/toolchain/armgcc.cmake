# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

#set(CMAKE_EXECUTABLE_SUFFIX ".elf")

if(${ZEPHYR_SDK})
    find_package(Zephyr-sdk 0.15 REQUIRED)
    set(TOOLCHAIN_ROOT ${ZEPHYR_SDK_INSTALL_DIR}/arm-zephyr-eabi)
    set(PREFIX arm-zephyr-eabi-)
else()
    # Only use to generate ninja file, no actual usage for mcuxpresso
    if((${MCUXPRESSO}) AND (DEFINED $ENV{MCUX_DIR}))
        set(TOOLCHAIN_ROOT $ENV{MCUX_DIR}/ide/tools)
    else()
        set(TOOLCHAIN_ROOT $ENV{ARMGCC_DIR})
    endif()
    set(PREFIX arm-none-eabi-)
endif()

string(REGEX REPLACE "\\\\" "/" TOOLCHAIN_ROOT "${TOOLCHAIN_ROOT}")

if(NOT TOOLCHAIN_ROOT)
    message(FATAL_ERROR "***Please set ARMGCC_DIR in environment variables***")
endif()

SET(TARGET_TRIPLET "bin")


set(AS "as")
set(CC "gcc")
set(CXX "g++")
set(CPP "gcc")
set(OC "objcopy")
set(OD "objdump")

set(AS ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${PREFIX}${AS}${TOOLCHAIN_EXT})
set(CC ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${PREFIX}${CC}${TOOLCHAIN_EXT})
set(CXX ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${PREFIX}${CXX}${TOOLCHAIN_EXT})
set(CPP ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${PREFIX}${CPP}${TOOLCHAIN_EXT})
set(OC ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${PREFIX}${OC}${TOOLCHAIN_EXT})
set(OD ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${PREFIX}${OD}${TOOLCHAIN_EXT})

# Set CMake variables for toolchain initialization
set(CMAKE_ASM_COMPILER "${CC}")
# set(CMAKE_AS_LEG_COMPILER "${AS}")
# set(CMAKE_AS_GNU_COMPILER "${CC}")
set(CMAKE_C_COMPILER "${CC}")
set(CMAKE_CXX_COMPILER "${CXX}")
set(CMAKE_OBJCOPY "${OC}")
set(CMAKE_OBJDUMP "${OD}")
set(OBJDUMP_OUT_CMD "")
set(OBJDUMP_BIN_CMD "-Obinary")

if(${MCUXPRESSO})
  return()
endif()

set(LINKERFLAGPREFIX -Wl)

# Ignore warnings about rwx segments introduced in binutils 2.39
execute_process(COMMAND ${CMAKE_C_COMPILER} -print-prog-name=ld RESULT_VARIABLE RUN_C_RESULT OUTPUT_VARIABLE FULL_LD_PATH OUTPUT_STRIP_TRAILING_WHITESPACE)
if (${RUN_C_RESULT} EQUAL 0)
    execute_process(COMMAND ${FULL_LD_PATH} --help RESULT_VARIABLE RUN_LD_RESULT OUTPUT_VARIABLE LD_HELP_OUTPUT OUTPUT_STRIP_TRAILING_WHITESPACE)
    if (${RUN_LD_RESULT} EQUAL 0)
        string(FIND "${LD_HELP_OUTPUT}" "no-warn-rwx-segments" LD_RWX_WARNING_SUPPORTED)
        if (${LD_RWX_WARNING_SUPPORTED} GREATER -1)
            add_link_options("-Wl,--no-warn-rwx-segments")
        endif()
    endif()
endif()

if(DEFINED LIBRARY_TYPE)
    if(DEFINED LANGUAGE)
        set_library(${LIBRARY_TYPE} ${LANGUAGE})
    endif()
    if(DEFINED DEBUG_CONSOLE)
        set_debug_console(${DEBUG_CONSOLE} ${LIBRARY_TYPE})
    endif()
endif()
