#
# Copyright 2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
#

if (CONFIG_MCUX_COMPONENT_middleware.mstp-lib)
    mcux_add_include(
        PROJECT_BASE_PATH mstp-lib
        INCLUDES src/mstp-lib
                 src/mstp-lib/internal
    )

    mcux_add_source(
        SOURCES
            src/mstp-lib/internal/stp_base_types.cpp
            src/mstp-lib/internal/stp_bpdu.cpp
            src/mstp-lib/internal/stp_conditions_and_params.cpp
            src/mstp-lib/internal/stp.cpp
            src/mstp-lib/internal/stp_log.cpp
            src/mstp-lib/internal/stp_md5.cpp
            src/mstp-lib/internal/stp_procedures.cpp
            src/mstp-lib/internal/stp_sm_bridge_detection.cpp
            src/mstp-lib/internal/stp_sm_l2g_port_receive.cpp
            src/mstp-lib/internal/stp_sm_port_information.cpp
            src/mstp-lib/internal/stp_sm_port_protocol_migration.cpp
            src/mstp-lib/internal/stp_sm_port_receive.cpp
            src/mstp-lib/internal/stp_sm_port_role_selection.cpp
            src/mstp-lib/internal/stp_sm_port_role_transitions.cpp
            src/mstp-lib/internal/stp_sm_port_state_transition.cpp
            src/mstp-lib/internal/stp_sm_port_timers.cpp
            src/mstp-lib/internal/stp_sm_port_transmit.cpp
            src/mstp-lib/internal/stp_sm_topology_change.cpp
    )

endif () # CONFIG_MCUX_COMPONENT_middleware.mstp-lib
