# Copyright 2024-2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

if(CONFIG_MCUX_COMPONENT_driver.dsc_i3c)
    mcux_component_version(2.0.0)

    mcux_add_source(SOURCES fsl_i3c.h fsl_i3c.c)

    mcux_add_include(INCLUDES .)

endif()
