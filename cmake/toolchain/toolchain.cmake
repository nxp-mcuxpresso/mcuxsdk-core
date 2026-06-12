# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

# General
SET(CMAKE_SYSTEM_NAME Generic)

SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# SET(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_CROSSCOMPILING TRUE)
# Avoids running the linker during try_compile()
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
# list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES CONFIG_TOOLCHAIN)

# Set CMake variables for skipping compiler identification
set(CMAKE_ASM_COMPILER_FORCED TRUE)
set(CMAKE_C_COMPILER_FORCED TRUE)
set(CMAKE_C_COMPILER_WORKS TRUE)
set(CMAKE_CXX_COMPILER_ID "${CMAKE_C_COMPILER_ID}")
set(CMAKE_CXX_COMPILER_ID_RUN "${CMAKE_C_COMPILER_ID_RUN}")
set(CMAKE_CXX_COMPILER_VERSION "${CMAKE_C_COMPILER_VERSION}")
set(CMAKE_CXX_COMPILER_FORCED "${CMAKE_C_COMPILER_FORCED}")
set(CMAKE_CXX_COMPILER_WORKS "${CMAKE_C_COMPILER_WORKS}")

# TOOLCHAIN EXTENSION
# Use CMAKE_HOST_WIN32 (not WIN32): this toolchain file sets CMAKE_SYSTEM_NAME=Generic, so WIN32
# tracks the cross-compile target and becomes false when the file is processed more than once,
# wrongly clearing TOOLCHAIN_EXT. CMAKE_HOST_WIN32 always reflects the build host.
IF(CMAKE_HOST_WIN32)
    SET(TOOLCHAIN_EXT ".exe")
ELSE()
    SET(TOOLCHAIN_EXT "")
ENDIF()

# When enabled, CMake configure will not require the real toolchain binaries to
# be present (useful for IDE/standalone project generation where we only need
# build metadata, not an actual CLI build).
# Track whether the user explicitly set this cache entry (e.g. via -D...).
set(_mcux_skip_compiler_checks_user_set FALSE)
if(DEFINED CACHE{MCUX_SKIP_COMPILER_CHECKS})
    set(_mcux_skip_compiler_checks_user_set TRUE)
endif()
set(MCUX_SKIP_COMPILER_CHECKS OFF CACHE BOOL
    "Skip validating/running toolchain binaries during CMake configure (IDE-only use cases).")

# Toolchain
set(TOOLCHAIN_ARMGCC armgcc)
set(COMPILER_ARMGCC gcc)

set(TOOLCHAIN_IAR iar)
set(COMPILER_IAR iar)

set(TOOLCHAIN_MDK mdk)
# For MDK, the compiler could be armclang or armcc, the default is armclang
set(COMPILER_MDK_ARMCLANG armclang)
set(COMPILER_MDK_ARMCC armcc)

set(TOOLCHAIN_XTENSA xtensa)
set(COMPILER_XTENSA xclang)

set(TOOLCHAIN_CODEWARRIOR codewarrior)
set(COMPILER_CODEWARRIOR mwcc56800e)

set(TOOLCHAIN_RISCV riscvllvm)
set(COMPILER_RISCV riscvllvm)

if(NOT DEFINED CONFIG_TOOLCHAIN)
    set(CONFIG_TOOLCHAIN ${TOOLCHAIN_ARMGCC})
    message(WARNING "No toolchain is designated, use armgcc by default.")
endif()

log_status("Build toolchain: ${CONFIG_TOOLCHAIN}")

include(${CMAKE_CURRENT_LIST_DIR}/mcux_config.cmake)

# Auto-enable skip-mode for IDE-only project generation *only* when the
# corresponding toolchain is not installed.
#
# This logic is intentionally in CMake (not west) so that when a toolchain is
# installed (e.g., IAR_DIR is set), IDE project generation still uses the real
# compiler and normal CMake compiler identification.
set(_mcux_is_ide_generation FALSE)
if((DEFINED GENERATE_GUI_PROJECT AND GENERATE_GUI_PROJECT)
    OR (DEFINED GENERATE_STANDALONE_PROJECT AND GENERATE_STANDALONE_PROJECT)
    OR (DEFINED SYSBUILD_GENERATE_STANDALONE_PROJECT AND SYSBUILD_GENERATE_STANDALONE_PROJECT))
    set(_mcux_is_ide_generation TRUE)
endif()

if(_mcux_is_ide_generation AND NOT _mcux_skip_compiler_checks_user_set)
    # Only these toolchains are supported for IDE-only generation in this update.
    set(_mcux_toolchain_installed FALSE)
    if(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_IAR})
        string(STRIP "$ENV{IAR_DIR}" _mcux_dir)
        if(_mcux_dir)
            set(_mcux_toolchain_installed TRUE)
        endif()
    elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_MDK})
        string(STRIP "$ENV{MDK_DIR}" _mcux_dir)
        if(NOT _mcux_dir)
            string(STRIP "$ENV{ARMCLANG_DIR}" _mcux_dir)
        endif()
        if(_mcux_dir)
            set(_mcux_toolchain_installed TRUE)
        endif()
    elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_XTENSA})
        string(STRIP "$ENV{XCC_DIR}" _mcux_dir)
        if(_mcux_dir)
            set(_mcux_toolchain_installed TRUE)
        endif()
    elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_CODEWARRIOR})
        string(STRIP "$ENV{CW_DIR}" _mcux_dir)
        if(_mcux_dir)
            set(_mcux_toolchain_installed TRUE)
        endif()
    endif()

    if(_mcux_toolchain_installed)
        set(MCUX_SKIP_COMPILER_CHECKS OFF CACHE BOOL "" FORCE)
    else()
        set(MCUX_SKIP_COMPILER_CHECKS ON CACHE BOOL "" FORCE)
    endif()

    unset(_mcux_dir)
    unset(_mcux_toolchain_installed)
endif()
unset(_mcux_is_ide_generation)
unset(_mcux_skip_compiler_checks_user_set)

include("${CMAKE_CURRENT_LIST_DIR}/${CONFIG_TOOLCHAIN}.cmake")
# TOOLCHAIN_DIR is used in most pre/post command
set(TOOLCHAIN_DIR ${TOOLCHAIN_ROOT})

if (${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_ARMGCC})
    set(CONFIG_COMPILER ${COMPILER_ARMGCC})
elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_IAR})
    set(CONFIG_COMPILER ${COMPILER_IAR})
elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_MDK})
    if (NOT DEFINED CONFIG_COMPILER)
        set(CONFIG_COMPILER ${COMPILER_MDK_ARMCLANG})
    endif()
elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_XTENSA})
    set(CONFIG_COMPILER ${COMPILER_XTENSA})
elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_CODEWARRIOR})
    set(CONFIG_COMPILER ${COMPILER_CODEWARRIOR})
elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_RISCV})
    set(CONFIG_COMPILER ${COMPILER_RISCV})
endif()

if (${CONFIG_COMPILER} STREQUAL ${COMPILER_MDK_ARMCC})
    log_fatal("The designated compiler is ${COMPILER_MDK_ARMCC}, in the build system, MDK toolchain now only supports armclang compiler.")
endif()

# Optionally avoid CMake compiler detection and toolchain existence checks.
# This keeps configure fast and allows IDE project generation on machines that
# don't have the toolchain installed.
if(MCUX_SKIP_COMPILER_CHECKS)
    # Use a known-existing executable as a placeholder compiler.
    set(_mcux_fake_compiler "${CMAKE_COMMAND}")
    # Set both normal and cache vars to ensure we override any toolchain file
    # assignments (some toolchain files don't use CACHE).
    set(CMAKE_C_COMPILER "${_mcux_fake_compiler}")
    set(CMAKE_CXX_COMPILER "${_mcux_fake_compiler}")
    set(CMAKE_ASM_COMPILER "${_mcux_fake_compiler}")
    set(CMAKE_C_COMPILER "${_mcux_fake_compiler}" CACHE FILEPATH "" FORCE)
    set(CMAKE_CXX_COMPILER "${_mcux_fake_compiler}" CACHE FILEPATH "" FORCE)
    set(CMAKE_ASM_COMPILER "${_mcux_fake_compiler}" CACHE FILEPATH "" FORCE)

    # Provide synthetic compiler-id/version for downstream logic without
    # requiring the real toolchain.
    # Keep it numeric so VERSION_* comparisons don't break, but make it
    # obviously not a real tool version.
    set(_mcux_compiler_version "99.99.99")
    set(_mcux_compiler_arch "")
    if(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_IAR})
        # CMake's built-in IAR compiler modules require both VERSION and
        # ARCHITECTURE_ID; also, version must be >= 5 for ARM.
        set(_mcux_compiler_id "IAR")
        set(_mcux_compiler_arch "ARM")
        # Prevent CMake's IAR-CXX module from relying on computed default
        # language standard (which can be unset when we skip detection).
        set(CMAKE_IAR_CXX_FLAG "--c++")
        set(CMAKE_IAR_CXX_FLAG "--c++" CACHE STRING "" FORCE)
    elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_ARMGCC})
        set(_mcux_compiler_id "GNU")
        set(_mcux_compiler_arch "ARM")
    elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_MDK})
        # Treat as Clang-family; avoids needing proprietary probe logic.
        set(_mcux_compiler_id "Clang")
        set(_mcux_compiler_arch "ARM")
    elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_XTENSA})
        set(_mcux_compiler_id "Clang")
    elseif(${CONFIG_TOOLCHAIN} STREQUAL ${TOOLCHAIN_RISCV})
        set(_mcux_compiler_id "Clang")
        set(_mcux_compiler_arch "RISCV")
    else()
        set(_mcux_compiler_id "GNU")
    endif()

    foreach(_lang IN ITEMS C CXX ASM)
        set(CMAKE_${_lang}_COMPILER_ID "${_mcux_compiler_id}")
        set(CMAKE_${_lang}_COMPILER_ID "${_mcux_compiler_id}" CACHE STRING "" FORCE)
        set(CMAKE_${_lang}_COMPILER_VERSION "${_mcux_compiler_version}")
        set(CMAKE_${_lang}_COMPILER_VERSION "${_mcux_compiler_version}" CACHE STRING "" FORCE)
        set(CMAKE_${_lang}_COMPILER_VERSION_INTERNAL "${_mcux_compiler_version}")
        set(CMAKE_${_lang}_COMPILER_VERSION_INTERNAL "${_mcux_compiler_version}" CACHE STRING "" FORCE)
        set(CMAKE_${_lang}_COMPILER_ID_RUN TRUE CACHE BOOL "" FORCE)
        set(CMAKE_${_lang}_COMPILER_FORCED TRUE CACHE BOOL "" FORCE)
        set(CMAKE_${_lang}_COMPILER_WORKS TRUE CACHE BOOL "" FORCE)
    endforeach()

    # Seed required architecture IDs for compiler modules that insist on them.
    if(_mcux_compiler_arch)
        set(CMAKE_C_COMPILER_ARCHITECTURE_ID "${_mcux_compiler_arch}")
        set(CMAKE_C_COMPILER_ARCHITECTURE_ID "${_mcux_compiler_arch}" CACHE STRING "" FORCE)
        set(CMAKE_CXX_COMPILER_ARCHITECTURE_ID "${_mcux_compiler_arch}")
        set(CMAKE_CXX_COMPILER_ARCHITECTURE_ID "${_mcux_compiler_arch}" CACHE STRING "" FORCE)
        set(CMAKE_ASM_COMPILER_ARCHITECTURE_ID "${_mcux_compiler_arch}")
        set(CMAKE_ASM_COMPILER_ARCHITECTURE_ID "${_mcux_compiler_arch}" CACHE STRING "" FORCE)
    endif()

    message(STATUS "MCUX_SKIP_COMPILER_CHECKS=ON: skipping compiler identification and toolchain binary checks (IDE-only project generation mode)")

    unset(_mcux_fake_compiler)
    unset(_mcux_compiler_id)
    unset(_mcux_compiler_version)
    unset(_mcux_compiler_arch)
endif()

if(DEFINED FPU_TYPE AND DEFINED FPU_ABI)
    set_floating_point(${FPU_TYPE} ${FPU_ABI})
endif()

set(CMAKE_UNRECOGNIZED_TOOLCHAIN codewarrior xtensa)
# For CMake unknown toolchains, only warnings, errors, and fatal errors are displayed by default to avoid
# invalid message about toolchain recognization
if(${CONFIG_TOOLCHAIN} IN_LIST CMAKE_UNRECOGNIZED_TOOLCHAIN)
    if(NOT DEFINED CMAKE_MESSAGE_LOG_LEVEL)
        set(CMAKE_MESSAGE_LOG_LEVEL WARNING)
    endif()
endif()
