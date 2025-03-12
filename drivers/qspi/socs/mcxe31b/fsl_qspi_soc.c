/*
 * Copyright 2025 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "fsl_qspi_soc.h"

/*!
 * brief Set QuadSPI Soc specific configuration.
 * note Should call it when QuadSPI is disabled.
 *
 * param base  Pointer to QuadSPI Type.
 * param config  QuadSPI Soc configuration structure.
 * return status_t
 */
status_t QSPI_SocConfigure(QuadSPI_Type *base, qspi_soc_config_t *config)
{
    base->SOCCR = (uint32_t)config->obePullTimingRelax | ((uint32_t)config->sckDummyPadInputEnable << 1U) | ((uint32_t)config->sckDummyPadOutputEnable << 2U) |
                  ((uint32_t)config->sckDummyPadDriveEnable << 3U) | ((uint32_t)config->sckDummyPadPullEnable << 4U) | ((uint32_t)config->sckDummyPadPullupEnable << 5U) |
                  ((uint32_t)config->sckDummyPadSlewRateEnable << 6U);
    
    base->MCR &= ~QuadSPI_MCR_DQS_FA_SEL_MASK;
    base->MCR |= QuadSPI_MCR_DQS_FA_SEL(config->dqsClkPadLoopEnable);

    return kStatus_Success;
}
