# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

# dsc_common_settings => ps.config.dsc.shared
if (CONFIG_MCUX_PRJSEG_config.dsp56800.ef)
    mcux_add_codewarrior_configuration(
            AS "-v4"
            CC "-v4"
            LD "-v4"
    )
endif()