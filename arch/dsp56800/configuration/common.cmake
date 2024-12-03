# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

# dsc_common_settings => ps.config.dsc.shared
if (CONFIG_MCUX_PRJSEG_config.dsp56800.shared)
    mcux_add_codewarrior_configuration(
            CC "-msgstyle parseable -lang c99 -nostrict-align -globalsInLowerMemory -g -requireprotos"
            LD "-msgstyle parseable -map -main F_EntryPoint -nostdlib -g"
    )

    mcux_add_codewarrior_sys_include(
        SYS_SEARCH_PATH "\"${MCUToolsBaseDir}/DSP56800x_EABI_Tools/M56800E Support/runtime_56800E/include\""
                                "\"${MCUToolsBaseDir}/DSP56800x_EABI_Tools/M56800E Support/msl/MSL_C/MSL_Common/Include\""
                                "\"${MCUToolsBaseDir}/DSP56800x_EABI_Tools/M56800E Support/msl/MSL_C/DSP_56800E/prefix\""
        SYS_PATH_RECURSIVELY "\"${MCUToolsBaseDir}/DSP56800x_EABI_Tools/M56800E Support\""
    )
endif()