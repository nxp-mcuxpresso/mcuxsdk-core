# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

if(CONFIG_MCUX_COMPONENT_driver.dsc_cop)
    mcux_component_version(1.0.0)

    mcux_add_source(SOURCES fsl_cop.h fsl_cop.c)

    mcux_add_include(INCLUDES .)

endif()
