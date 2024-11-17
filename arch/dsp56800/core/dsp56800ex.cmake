# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# dsc_common_settings => ps.config.dsc.shared
if (CONFIG_MCUX_PRJSEG_config.dsp56800.ex)
    mcux_add_codewarrior_configuration(
            AS "-v3"
            CC "-v3"
            LD "-v3"
    )
endif()