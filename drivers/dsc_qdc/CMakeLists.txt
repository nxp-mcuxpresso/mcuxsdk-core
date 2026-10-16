# Copyright 2024, 2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

if(CONFIG_MCUX_COMPONENT_driver.dsc_qdc)
    mcux_component_version(2.1.1)

    mcux_add_source(SOURCES fsl_qdc.h fsl_qdc.c)

    mcux_add_include(INCLUDES .)

endif()
