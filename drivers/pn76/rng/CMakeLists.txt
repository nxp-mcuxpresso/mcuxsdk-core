# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

if(CONFIG_MCUX_COMPONENT_driver.pn76_rng)

    mcux_add_source(SOURCES fsl_rng.h)

    mcux_add_include(INCLUDES .)

endif()
