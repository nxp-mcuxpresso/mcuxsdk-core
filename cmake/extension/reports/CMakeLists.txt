# SPDX-License-Identifier: Apache-2.0

set(flag_for_ram_report ram)
set(flag_for_rom_report rom)
set(flag_for_footprint all)
set(report_depth 99)

if(DEFINED SdkRootDirPath)
  set(workspace_arg "--workspace=${SdkRootDirPath}")
elseif(DEFINED WEST_TOPDIR)
  set(workspace_arg "--workspace=${WEST_TOPDIR}")
endif()

foreach(report ram_report rom_report)
  add_custom_target(
    ${report}
    ${PYTHON_EXECUTABLE}
    ${SdkRootDirPath}/scripts/footprint/size_report
    -k ${APPLICATION_BINARY_DIR}/${APPLICATION_BINARY_NAME}.elf
    -z ${SdkRootDirPath}
    -o ${CMAKE_BINARY_DIR}
    ${workspace_arg}
    -d ${report_depth}
    ${flag_for_${report}}
    DEPENDS ${APPLICATION_BINARY_NAME}
            $<TARGET_PROPERTY:mcux_build_properties,${report}_DEPENDENCIES>
    USES_TERMINAL
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
endforeach()

add_custom_target(
  footprint
  DEPENDS ram_report rom_report
  )

if(CONFIG_BUILD_WITH_TFM)
  foreach(report ram rom)
    add_custom_target(
      tfm_${report}_report
      ${PYTHON_EXECUTABLE}
      ${SdkRootDirPath}/scripts/footprint/size_report
      -k $<TARGET_PROPERTY:tfm,TFM_S_ELF_FILE>
      -z ${SdkRootDirPath}
      -o ${CMAKE_BINARY_DIR}
      ${workspace_arg}
      -d ${report_depth}
      --json tfm_${report}.json
      ${flag_for_${report}_report}
      DEPENDS tfm
      USES_TERMINAL
      WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
      )
  endforeach()

  add_custom_target(
    tfm_footprint
    DEPENDS tfm_ram_report tfm_rom_report
    )
endif()

if(CONFIG_TFM_BL2)
  foreach(report ram rom)
    add_custom_target(
      bl2_${report}_report
      ${PYTHON_EXECUTABLE}
      ${SdkRootDirPath}/scripts/footprint/size_report
      -k $<TARGET_PROPERTY:tfm,BL2_ELF_FILE>
      -z ${SdkRootDirPath}
      -o ${CMAKE_BINARY_DIR}
      ${workspace_arg}
      -d ${report_depth}
      --json bl2_${report}.json
      ${flag_for_${report}_report}
      DEPENDS tfm
      USES_TERMINAL
      WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
      )
  endforeach()

  add_custom_target(
    bl2_footprint
    DEPENDS bl2_ram_report bl2_rom_report
    )
endif()

find_program(PUNCOVER puncover)

if(NOT ${PUNCOVER} STREQUAL PUNCOVER-NOTFOUND)
  add_custom_target(
    puncover
    ${PUNCOVER}
    --elf_file       ${APPLICATION_BINARY_DIR}/${APPLICATION_BINARY_NAME}.elf
    --gcc_tools_base ${CROSS_COMPILE}
    --src_root       ${SdkRootDirPath}
    --build_dir      ${CMAKE_BINARY_DIR}
    DEPENDS ${APPLICATION_BINARY_NAME}
            $<TARGET_PROPERTY:mcux_build_properties,${report}_DEPENDENCIES>
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    USES_TERMINAL
    )
endif()

find_program(PAHOLE pahole)

if(NOT ${PAHOLE} STREQUAL PAHOLE-NOTFOUND)
  add_custom_target(
    pahole
    ${PAHOLE}
    --anon_include
    --nested_anon_include
    --show_decl_info
    $<$<BOOL:${CMAKE_VERBOSE_MAKEFILE}>:--verbose>
    ${APPLICATION_BINARY_DIR}/${APPLICATION_BINARY_NAME}.elf
    DEPENDS ${APPLICATION_BINARY_NAME}
            $<TARGET_PROPERTY:mcux_build_properties,${report}_DEPENDENCIES>
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    USES_TERMINAL
    )
endif()
