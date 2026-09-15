/*
 * Copyright 2026 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "fsl_tro.h"

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/* Component ID definition, used by tools. */
#ifndef FSL_COMPONENT_ID
#define FSL_COMPONENT_ID "platform.drivers.dsc_tro"
#endif

/*******************************************************************************
 * Prototypes
 ******************************************************************************/

/*******************************************************************************
 * Code
 ******************************************************************************/

/*!
 * @brief Polls a status flag in a TRO register until hardware asserts it.
 *
 * @param reg Register carrying the flag.
 * @param mask Flag mask.
 * @param timeout Maximum loops to poll, or 0 to poll forever.
 * @retval kStatus_Success The flag is asserted.
 * @retval kStatus_Timeout The flag stayed clear for timeout loops.
 */
static inline status_t TRO_WaitFlagSet(volatile const uint32_t *reg, uint32_t mask, uint32_t timeout)
{
    status_t status = kStatus_Success;

    while ((*reg & mask) == 0UL)
    {
        if (0UL != timeout)
        {
            timeout--;
            if (0UL == timeout)
            {
                status = kStatus_Timeout;
                break;
            }
        }
    }

    return status;
}

/*!
 * brief Enables the TRO and applies a configuration.
 *
 * param base TRO peripheral base address.
 * param config Pointer to the configuration.
 * return Execution status.
 */
status_t TRO_Init(TRO_Type *base, const tro_config_t *config)
{
    assert(NULL != base);
    assert(NULL != config);

    status_t status;
    uint32_t tmp32;

#if !(defined(FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL) && FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL)
    CLOCK_EnableClock(kCLOCK_TRO);
#endif /* FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL */

    if (TRO_IsLocked(base))
    {
        return kStatus_Fail;
    }

    if (config->refClkMultiplier > TRO_REF_CLK_MULT_MAX)
    {
        return kStatus_InvalidArgument;
    }

    /* Enable first. DLY_CFG and DIV_CFG writes do not take effect until
     * CSR[TRO_CONFIG_VLD] asserts, so the order below is load-bearing. */
    base->CSR |= TRO_CSR_TROEN_MASK;

    status = TRO_WaitFlagSet(&base->CSR, TRO_CSR_TRO_CONFIG_VLD_MASK, TRO_CONFIG_VLD_TIMEOUT);
    if (kStatus_Success != status)
    {
        /* Leave the block disabled rather than half-enabled. */
        base->CSR &= ~TRO_CSR_TROEN_MASK;
        return status;
    }

    status = TRO_SetDelayLineConfig(base, &config->delayLine);
    if (kStatus_Success != status)
    {
        base->CSR &= ~TRO_CSR_TROEN_MASK;
        return status;
    }

    status = TRO_SetClockDivider(base, config->clockDivExponent);
    if (kStatus_Success != status)
    {
        base->CSR &= ~TRO_CSR_TROEN_MASK;
        return status;
    }

    /* Read-modify-write: CSR also carries TROEN, LK, and CLR_PHASE_CNTR. */
    tmp32 = base->CSR & ~TRO_CSR_REF_CLK_MULT_MASK;
    tmp32 |= TRO_CSR_REF_CLK_MULT(config->refClkMultiplier);
    base->CSR = tmp32;

    return kStatus_Success;
}

/*!
 * brief Disables the TRO.
 *
 * param base TRO peripheral base address.
 */
void TRO_Deinit(TRO_Type *base)
{
    assert(NULL != base);

    /* Hardware resets DLY_CFG and DIV_CFG when TROEN clears. */
    base->CSR &= ~TRO_CSR_TROEN_MASK;

#if !(defined(FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL) && FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL)
    CLOCK_DisableClock(kCLOCK_TRO);
#endif /* FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL */
}

/*!
 * brief Gets the default configuration.
 *
 * param config Pointer to the configuration to fill.
 */
void TRO_GetDefaultConfig(tro_config_t *config)
{
    assert(NULL != config);

    (void)memset(config, 0, sizeof(*config));

    /* Hardware reset state: all four lines at their maximum code. */
    config->delayLine.stdLineLength     = TRO_DELAY_LINE_STD_LENGTH_MAX;
    config->delayLine.longLineLength    = TRO_DELAY_LINE_LONG_LENGTH_MAX;
    config->delayLine.complexLineLength = TRO_DELAY_LINE_CPLX_LENGTH_MAX;
    config->delayLine.rcLineLength      = TRO_DELAY_LINE_RC_LENGTH_MAX;
    config->clockDivExponent            = 0U;
    config->refClkMultiplier            = 6U;
}

/*!
 * brief Gets the default window configuration.
 *
 * param config Pointer to the configuration to fill.
 */
void TRO_GetDefaultWindowConfig(tro_window_config_t *config)
{
    assert(NULL != config);

    (void)memset(config, 0, sizeof(*config));

    config->windowSize    = 4800U;
    config->maxThreshold  = TRO_WINDOW_COUNT_MAX;
    config->minThreshold  = 0U;
    config->interruptMask = (uint32_t)kTRO_WindowExpiredInterruptEnable;
}

/*!
 * brief Sets the four delay line lengths.
 *
 * param base TRO peripheral base address.
 * param config Pointer to the delay line lengths.
 * return Execution status.
 */
status_t TRO_SetDelayLineConfig(TRO_Type *base, const tro_delay_line_config_t *config)
{
    assert(NULL != base);
    assert(NULL != config);

    status_t status;

    if ((config->stdLineLength > TRO_DELAY_LINE_STD_LENGTH_MAX) ||
        (config->longLineLength > TRO_DELAY_LINE_LONG_LENGTH_MAX) ||
        (config->complexLineLength > TRO_DELAY_LINE_CPLX_LENGTH_MAX) ||
        (config->rcLineLength > TRO_DELAY_LINE_RC_LENGTH_MAX))
    {
        return kStatus_InvalidArgument;
    }

    status = TRO_WaitFlagSet(&base->DLY_CFG, TRO_DLY_CFG_TRO_DLY_DONE_MASK, TRO_DLY_DONE_TIMEOUT);
    if (kStatus_Success != status)
    {
        return status;
    }

    /* TRO_DLY_DONE is read-only at bit 31 and all writable fields sit below
     * bit 30, so a plain assignment of the four fields is safe here. */
    base->DLY_CFG = TRO_DLY_CFG_TRO_DLY_STD(config->stdLineLength) |
                    TRO_DLY_CFG_TRO_DLY_LONG(config->longLineLength) |
                    TRO_DLY_CFG_TRO_DLY_CPLX(config->complexLineLength) |
                    TRO_DLY_CFG_TRO_DLY_RC(config->rcLineLength);

    /* Poll again: the write is only accepted at this point, the shift into the
     * delay lines is still running. Returning here would let the caller measure
     * a frequency that belongs to neither the old nor the new configuration. */
    return TRO_WaitFlagSet(&base->DLY_CFG, TRO_DLY_CFG_TRO_DLY_DONE_MASK, TRO_DLY_DONE_TIMEOUT);
}

/*!
 * brief Sets the output clock divider.
 *
 * param base TRO peripheral base address.
 * param divExponent Divider exponent.
 * return Execution status.
 */
status_t TRO_SetClockDivider(TRO_Type *base, uint8_t divExponent)
{
    assert(NULL != base);

    status_t status;

    status = TRO_WaitFlagSet(&base->DIV_CFG, TRO_DIV_CFG_TRO_DIV_DONE_MASK, TRO_DIV_DONE_TIMEOUT);
    if (kStatus_Success != status)
    {
        return status;
    }

    /* TRO_DIV is the only writable field; TRO_DIV_DONE at bit 31 is read-only. */
    base->DIV_CFG = TRO_DIV_CFG_TRO_DIV(divExponent);

    /* Poll again, same reason as the delay line setter: the divider update is
     * still in flight right after the write. */
    return TRO_WaitFlagSet(&base->DIV_CFG, TRO_DIV_CFG_TRO_DIV_DONE_MASK, TRO_DIV_DONE_TIMEOUT);
}

/*!
 * brief Programs the window size, thresholds, and interrupt enables.
 *
 * param base TRO peripheral base address.
 * param config Pointer to the window configuration.
 * return Execution status.
 */
status_t TRO_SetWindowConfig(TRO_Type *base, const tro_window_config_t *config)
{
    assert(NULL != base);
    assert(NULL != config);

    uint32_t tmp32;

    if ((0UL == config->windowSize) || (config->windowSize > TRO_WINDOW_COUNT_MAX) ||
        (config->maxThreshold > TRO_WINDOW_COUNT_MAX) || (config->minThreshold > TRO_WINDOW_COUNT_MAX))
    {
        return kStatus_InvalidArgument;
    }

    /* Window mode must be off before the size and thresholds are written. */
    base->WIN_CFG &= ~TRO_WIN_CFG_TRO_WIN_EN_MASK;

    base->WIN_MAX = TRO_WIN_MAX_TRO_WIN_MAX(config->maxThreshold);
    base->WIN_MIN = TRO_WIN_MIN_TRO_WIN_MIN(config->minThreshold);

    tmp32 = TRO_WIN_CFG_TRO_WIN_SZ(config->windowSize) |
            (config->interruptMask & (uint32_t)kTRO_AllInterruptEnable);
    base->WIN_CFG = tmp32;

    return kStatus_Success;
}

/*!
 * brief Sets the window size while leaving the oscillator running.
 *
 * param base TRO peripheral base address.
 * param windowSize Window length in reference clock cycles.
 * return Execution status.
 */
status_t TRO_SetWindowSize(TRO_Type *base, uint32_t windowSize)
{
    assert(NULL != base);

    uint32_t tmp32;

    if ((0UL == windowSize) || (windowSize > TRO_WINDOW_COUNT_MAX))
    {
        return kStatus_InvalidArgument;
    }

    /* TRO_WIN_SZ should only be updated when WIN_CFG[TRO_WIN_EN] is 0. WIN_EN is not
     * restored; see the header note. call TRO_EnableWindowMode() to re-arm the window mode. */
    tmp32 = base->WIN_CFG & ~(TRO_WIN_CFG_TRO_WIN_SZ_MASK | TRO_WIN_CFG_TRO_WIN_EN_MASK);
    tmp32 |= TRO_WIN_CFG_TRO_WIN_SZ(windowSize);
    base->WIN_CFG = tmp32;

    return kStatus_Success;
}

/*!
 * brief Sets the expected integer ratio of tro_clk to the reference clock.
 *
 * param base TRO peripheral base address.
 * param multiplier Expected ratio.
 * return Execution status.
 */
status_t TRO_SetReferenceClockMultiplier(TRO_Type *base, uint8_t multiplier)
{
    assert(NULL != base);

    uint32_t tmp32;

    if (multiplier > TRO_REF_CLK_MULT_MAX)
    {
        return kStatus_InvalidArgument;
    }

    /* Read-modify-write: CSR also carries TROEN, LK, and CLR_PHASE_CNTR. */
    tmp32 = base->CSR & ~TRO_CSR_REF_CLK_MULT_MASK;
    tmp32 |= TRO_CSR_REF_CLK_MULT(multiplier);
    base->CSR = tmp32;

    return kStatus_Success;
}
