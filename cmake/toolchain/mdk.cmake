# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

set(CMAKE_EXECUTABLE_SUFFIX ".elf")

set(TOOLCHAIN_ROOT $ENV{MDK_DIR})
string(REGEX REPLACE "\\\\" "/" TOOLCHAIN_ROOT "${TOOLCHAIN_ROOT}")

if(NOT TOOLCHAIN_ROOT)
    message(WARNING "'MDK_DIR' is not set in environment variables, check ARMCLANG_DIR.")
    set(TOOLCHAIN_ROOT $ENV{ARMCLANG_DIR})
    string(REGEX REPLACE "\\\\" "/" TOOLCHAIN_ROOT "${TOOLCHAIN_ROOT}")
    if(NOT TOOLCHAIN_ROOT)
        message(FATAL_ERROR "***Please set MDK_DIR or ARMCLANG_DIR in environment variables***")
    endif()
endif()

if(WIN32)
    SET(TARGET_TRIPLET "ARM/ARMCLANG/bin")
elseif(APPLE)
    SET(TARGET_TRIPLET "bin")
elseif(UNIX)
    SET(TARGET_TRIPLET "bin")
endif()

set(AS "armclang")
set(CC "armclang")
set(CXX "armclang")
set(LD "armlink")
set(AR "armar")
set(CPP "armclang")
set(OC "fromelf")
# set(OD "objdump")
set(AS ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${AS}${TOOLCHAIN_EXT})
set(CC ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${CC}${TOOLCHAIN_EXT})
set(CXX ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${CXX}${TOOLCHAIN_EXT})
set(LD ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${LD}${TOOLCHAIN_EXT})
set(AR ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${AR}${TOOLCHAIN_EXT})
set(CPP ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${CPP}${TOOLCHAIN_EXT})
set(OC ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${OC}${TOOLCHAIN_EXT})
set(OD ${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}/${OD}${TOOLCHAIN_EXT})

set(CMAKE_ASM_COMPILER "${AS}")
set(CMAKE_C_COMPILER "${CC}")
set(CMAKE_CXX_COMPILER "${CXX}")
set(CMAKE_OBJCOPY "${OC}")
# SET(CMAKE_OBJDUMP "${OD}")
set(OBJDUMP_OUT_CMD "--output")
set(OBJDUMP_BIN_CMD "--bincombined")