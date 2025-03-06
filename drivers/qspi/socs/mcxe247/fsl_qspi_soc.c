/*
 * Copyright 2025 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "fsl_qspi_soc.h"

status_t QSPI_SocConfigure(QuadSPI_Type *base, qspi_soc_config_t *config)
{
    assert(config->clkDiv <= 8U);

    uint8_t div = (config->clkDiv != 0U) ? (config->clkDiv - 1U) : 0U;
    uint32_t sclkCfg;

    base->SOCCR = (uint32_t)config->delayChainFlashA | ((uint32_t)config->delayChainFlashB << 8U) |
                  ((uint32_t)config->pendingReadEnable << 16U) | ((uint32_t)config->burstReadEnable << 17U) |
                  ((uint32_t)config->burstWriteEnable << 18U) | ((uint32_t)(!config->divEnable) << 28U) |
                  (((uint32_t)div & 0x7U) << 29U);

    sclkCfg = (uint32_t)config->clkDqsFlashA | ((uint32_t)config->invertClkDqsFlashA << 1U) |
              ((uint32_t)config->clkDqsFlashB << 2U) | ((uint32_t)config->invertClkDqsFlashB << 3U) |
              ((uint32_t)config->internalClk << 4U) | ((uint32_t)config->hyperramDqsClkFlashB << 5U) |
              ((uint32_t)config->clkMode << 6U) | ((uint32_t)config->inputBufEnable << 7U);
    base->MCR |= QuadSPI_MCR_SCLKCFG(sclkCfg);

    /* Ungate the QSPI SFCK. */
    SIM->MISCTRL0 |= SIM_MISCTRL0_QSPI_CLK_SEL_MASK;

    return kStatus_Success;
}
