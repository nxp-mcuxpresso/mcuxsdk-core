# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

if(CONFIG_MCUX_COMPONENT_driver.flexio_t-format_edma)
    mcux_component_version(2.4.1)

    mcux_add_source(SOURCES fsl_flexio_t-format_edma.c fsl_flexio_t-format_edma.h)

    mcux_add_include(INCLUDES .)

endif()

if(CONFIG_MCUX_COMPONENT_driver.flexio_t-format)
    mcux_component_version(2.5.0)

    mcux_add_source(SOURCES fsl_flexio_t-format.c fsl_flexio_t-format.h)

    mcux_add_include(INCLUDES .)

endif()
