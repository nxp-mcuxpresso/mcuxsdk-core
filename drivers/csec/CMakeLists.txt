# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

if(CONFIG_MCUX_COMPONENT_driver.csec)
    mcux_component_version(2.0.0)

    mcux_add_source(SOURCES csec_driver.c csec_driver.h csec_hw_access.c csec_hw_access.h)

    mcux_add_include(INCLUDES .)


endif()
