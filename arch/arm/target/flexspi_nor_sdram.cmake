# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

if (CONFIG_MCUX_PRJSEG_module.board.suite)
    
    mcux_add_iar_linker_script(
        TARGETS flexspi_nor_sdram_debug flexspi_nor_sdram_release
        BASE_PATH ${SdkRootDirPath}
        LINKER devices/${soc_portfolio}/${soc_series}/${device}/iar/${CONFIG_MCUX_TOOLCHAIN_LINKER_DEVICE_PREFIX}_flexspi_nor_sdram.icf
    )

    mcux_add_armgcc_linker_script(
        TARGETS flexspi_nor_sdram_debug flexspi_nor_sdram_release
        BASE_PATH ${SdkRootDirPath}
        LINKER devices/${soc_portfolio}/${soc_series}/${device}/gcc/${CONFIG_MCUX_TOOLCHAIN_LINKER_DEVICE_PREFIX}_flexspi_nor_sdram.ld
    )

    mcux_add_mdk_linker_script(
        TARGETS flexspi_nor_sdram_debug flexspi_nor_sdram_release
        BASE_PATH ${SdkRootDirPath}
        LINKER devices/${soc_portfolio}/${soc_series}/${device}/arm/${CONFIG_MCUX_TOOLCHAIN_LINKER_DEVICE_PREFIX}_flexspi_nor_sdram.scf
    )

endif()