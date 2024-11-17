# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

if(CONFIG_MCUX_COMPONENT_driver.pn76_crc)

    mcux_add_source(SOURCES fsl_crc.c fsl_crc.h)

    mcux_add_include(INCLUDES .)

endif()
