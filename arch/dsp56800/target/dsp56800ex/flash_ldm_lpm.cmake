# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

if (CONFIG_MCUX_PRJSEG_module.board.suite)
    mcux_add_codewarrior_configuration(
            TARGETS flash_ldm_lpm_debug
            AS "-data 24 -prog 19"
            CC "-opt level=1 -ldata -D__LDM__ -D__LPM__"
            LD "-ldata -l\"${MCUToolsBaseDir}/DSP56800x_EABI_Tools/lib/lpm/ldm/o4p/librt.lib\" \
                 -l\"${MCUToolsBaseDir}/DSP56800x_EABI_Tools/lib/lpm/ldm/o4p/libc.lib\""
    )

    mcux_add_codewarrior_configuration(
            TARGETS flash_ldm_lpm_release
            AS "-data 24 -prog 19 -nodebug_workaround"
            CC "-opt level=4 -nopadpipe -ldata -D__LDM__ -D__LPM__ -DNDEBUG"
            LD "-ldata -l\"${MCUToolsBaseDir}/DSP56800x_EABI_Tools/lib/lpm/ldm/o4p/librt.lib\" \
                 -l\"${MCUToolsBaseDir}/DSP56800x_EABI_Tools/lib/lpm/ldm/o4p/libc.lib\""
    )

    mcux_add_codewarrior_linker_script(
            TARGETS flash_ldm_lpm_debug flash_ldm_lpm_release
            BASE_PATH ${SdkRootDirPath}
            LINKER devices/${soc_portfolio}/${soc_series}/${device}/codewarrior/${device}_Internal_PFlash_LDM.cmd
    )

endif()
