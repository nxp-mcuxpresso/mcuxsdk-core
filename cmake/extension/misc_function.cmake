# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

function(_read_tool_versions read_tool_version_py)
    set(TOOL_YML ${SdkRootDirPath}/tool.yml)
    set(TOOL_YML_SCHEMA ${SdkRootDirPath}/mcusdk/script/data_schema/tool.json)
    set(DEFAULT_TOOL_VERSION_CMAKE ${SdkRootDirPath}/cmake/extension/default_tool_version.cmake)
    # Execute the Python script and capture the output
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E env python ${read_tool_version_py}
        OUTPUT_VARIABLE tool_versions_output
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE result
    )

    # Check if the command ran successfully
    if(NOT result EQUAL 0)
        message("Warning: Fail to validate ${TOOL_YML} against ${TOOL_YML_SCHEMA}. Failed reasons are: ${tool_versions_output}. ${TOOL_YML} data is used by build system to validate installed tools and toolchain versions, please fix data issue in tool.yml.")
        message("Warning: Build system will use designated versions in ${DEFAULT_TOOL_VERSION_CMAKE} to do installed tools and toolchain version validation.")
        include(${DEFAULT_TOOL_VERSION_CMAKE})
        return()
    endif()
    
    # replace \n to ; in tool_versions_output
    string(REPLACE "\n" ";" tool_versions_output "${tool_versions_output}")

    # Parse the output and set CMake variables
    foreach(line IN LISTS tool_versions_output)
        string(REGEX MATCH "([^=]+_MINIMUM_VERSION)=(.+)" _ ${line})
        set(${CMAKE_MATCH_1} ${CMAKE_MATCH_2} PARENT_SCOPE)
    endforeach()
endfunction()

function(_validate_compiler_version)
    # Determine the compiler version to compare
    if(CONFIG_TOOLCHAIN STREQUAL "armgcc")
        set(MIN_VERSION ${ARMGCC_COMPILER_MINIMUM_VERSION})
    elseif(CONFIG_TOOLCHAIN STREQUAL "iar")
        set(MIN_VERSION ${IAR_COMPILER_MINIMUM_VERSION})
    elseif(CONFIG_TOOLCHAIN STREQUAL "mdk" OR CONFIG_TOOLCHAIN STREQUAL "armclang")
        set(MIN_VERSION ${MDK_COMPILER_MINIMUM_VERSION})
    elseif(CONFIG_TOOLCHAIN STREQUAL "riscvllvm")
        set(MIN_VERSION ${RISCVLLVM_COMPILER_MINIMUM_VERSION})
    else()
        # now only support iar, armgcc, mdk, armclang, riscvllvm compiler version check
        return()
    endif()
    
    set(COMPILER_VERSION ${CMAKE_C_COMPILER_VERSION})

    # Compare the versions
    if(COMPILER_VERSION VERSION_LESS MIN_VERSION)
        message("warning: ${CONFIG_TOOLCHAIN} version ${MIN_VERSION} or higher is recommended. Found version: ${COMPILER_VERSION}")
    endif()

endfunction()
