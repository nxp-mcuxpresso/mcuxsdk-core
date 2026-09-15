/*
 * Copyright 2026 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef FSL_TRO_H_
#define FSL_TRO_H_

#include "fsl_common.h"

/*!
 * @addtogroup dsc_tro
 * @{
 */

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/*! @name Driver version */
/*! @{ */
/*! @brief TRO driver version 2.0.0. */
#define FSL_TRO_DRIVER_VERSION (MAKE_VERSION(2, 0, 0))
/*! @} */

/*!
 * @name Poll bounds
 * @{
 */
/*!
 * @brief Max loops to wait for CSR[TRO_CONFIG_VLD] to assert.
 *
 * CSR[TRO_CONFIG_VLD] asserts after CSR[TROEN] is set and gates the DLY_CFG and
 * DIV_CFG writes that follow.
 * This parameter defines how many loops to check completion before return timeout.
 * If defined as 0, driver will wait forever until completion.
 */
#ifndef TRO_CONFIG_VLD_TIMEOUT
#ifdef CONFIG_TRO_CONFIG_VLD_TIMEOUT
#define TRO_CONFIG_VLD_TIMEOUT CONFIG_TRO_CONFIG_VLD_TIMEOUT
#else
#define TRO_CONFIG_VLD_TIMEOUT 0U
#endif
#endif

/*!
 * @brief Max loops to wait for DLY_CFG[TRO_DLY_DONE] to assert.
 *
 * DLY_CFG[TRO_DLY_DONE] reports that a delay line shift transfer completed, so it
 * is polled before a new delay line length is written and again afterwards. This
 * parameter bounds each of the two polls separately.
 * This parameter defines how many loops to check completion before return timeout.
 * If defined as 0, driver will wait forever until completion.
 */
#ifndef TRO_DLY_DONE_TIMEOUT
#ifdef CONFIG_TRO_DLY_DONE_TIMEOUT
#define TRO_DLY_DONE_TIMEOUT CONFIG_TRO_DLY_DONE_TIMEOUT
#else
#define TRO_DLY_DONE_TIMEOUT 0U
#endif
#endif

/*!
 * @brief Max loops to wait for DIV_CFG[TRO_DIV_DONE] to assert.
 *
 * DIV_CFG[TRO_DIV_DONE] reports that a divider shift transfer completed, so it is
 * polled before a new divider value is written and again afterwards. This parameter
 * bounds each of the two polls separately.
 * This parameter defines how many loops to check completion before return timeout.
 * If defined as 0, driver will wait forever until completion.
 */
#ifndef TRO_DIV_DONE_TIMEOUT
#ifdef CONFIG_TRO_DIV_DONE_TIMEOUT
#define TRO_DIV_DONE_TIMEOUT CONFIG_TRO_DIV_DONE_TIMEOUT
#else
#define TRO_DIV_DONE_TIMEOUT 0U
#endif
#endif
/*! @} */

/*!
 * @name Field limits
 * @{
 */
/*! @brief Maximum thermometer code for the standard cell delay line. */
#define TRO_DELAY_LINE_STD_LENGTH_MAX (TRO_DLY_CFG_TRO_DLY_STD_MASK >> TRO_DLY_CFG_TRO_DLY_STD_SHIFT)
/*! @brief Maximum thermometer code for the long delay line. */
#define TRO_DELAY_LINE_LONG_LENGTH_MAX (TRO_DLY_CFG_TRO_DLY_LONG_MASK >> TRO_DLY_CFG_TRO_DLY_LONG_SHIFT)
/*! @brief Maximum thermometer code for the complex gate delay line. */
#define TRO_DELAY_LINE_CPLX_LENGTH_MAX (TRO_DLY_CFG_TRO_DLY_CPLX_MASK >> TRO_DLY_CFG_TRO_DLY_CPLX_SHIFT)
/*! @brief Maximum thermometer code for the RC delay line. */
#define TRO_DELAY_LINE_RC_LENGTH_MAX (TRO_DLY_CFG_TRO_DLY_RC_MASK >> TRO_DLY_CFG_TRO_DLY_RC_SHIFT)
/*! @brief Maximum value of the 22-bit window size and threshold fields. */
#define TRO_WINDOW_COUNT_MAX (TRO_WIN_CFG_TRO_WIN_SZ_MASK >> TRO_WIN_CFG_TRO_WIN_SZ_SHIFT)
/*! @brief Maximum value of the 6-bit reference clock multiplier. */
#define TRO_REF_CLK_MULT_MAX (TRO_CSR_REF_CLK_MULT_MASK >> TRO_CSR_REF_CLK_MULT_SHIFT)
/*! @} */

/*!
 * @brief The enumeration of window interrupt status flags.
 *
 * All three flags are write-1-to-clear and all three drive the single TRO
 * interrupt vector, so an ISR must read the status to tell them apart.
 * @anchor _tro_interrupt_status_flags
 */
enum _tro_interrupt_status_flags
{
    kTRO_WindowExpiredMinFlag = TRO_WIN_ST_TRO_WIN_EXPI_MIN_IRQ_MASK, /*!< The last window count was below
                                                                          WIN_MIN. */
    kTRO_WindowExpiredMaxFlag = TRO_WIN_ST_TRO_WIN_EXPI_MAX_IRQ_MASK, /*!< The last window count was above
                                                                          WIN_MAX. */
    kTRO_WindowExpiredFlag    = TRO_WIN_ST_TRO_WIN_EXPI_IRQ_MASK,     /*!< A measurement window expired and
                                                                          CNT_SNAPSHOT was updated. */
    kTRO_AllInterruptStatusFlags = TRO_WIN_ST_TRO_WIN_EXPI_MIN_IRQ_MASK | TRO_WIN_ST_TRO_WIN_EXPI_MAX_IRQ_MASK |
                                   TRO_WIN_ST_TRO_WIN_EXPI_IRQ_MASK, /*!< All window interrupt status flags. */
};

/*!
 * @brief The enumeration of window interrupt enables.
 * @anchor _tro_interrupt_enable
 */
enum _tro_interrupt_enable
{
    kTRO_WindowExpiredMinInterruptEnable = TRO_WIN_CFG_TRO_WIN_EXPI_MIN_IE_MASK, /*!< Interrupt when the count is
                                                                                     below WIN_MIN. */
    kTRO_WindowExpiredMaxInterruptEnable = TRO_WIN_CFG_TRO_WIN_EXPI_MAX_IE_MASK, /*!< Interrupt when the count is
                                                                                     above WIN_MAX. */
    kTRO_WindowExpiredInterruptEnable    = TRO_WIN_CFG_TRO_WIN_EXPI_IE_MASK,     /*!< Interrupt when a window
                                                                                     expires. */
    kTRO_AllInterruptEnable = TRO_WIN_CFG_TRO_WIN_EXPI_MIN_IE_MASK | TRO_WIN_CFG_TRO_WIN_EXPI_MAX_IE_MASK |
                              TRO_WIN_CFG_TRO_WIN_EXPI_IE_MASK, /*!< All window interrupts. */
};

/*!
 * @brief Delay line lengths.
 *
 * Each field is a 6-bit thermometer code that hardware expands into a 64-bit
 * shift pattern, selecting how many stages of that cell type sit in the
 * oscillator loop. The four cell types track voltage and temperature
 * differently, which is what lets the loop be matched to a real critical path
 * rather than to an absolute delay.
 */
typedef struct _tro_delay_line_config
{
    uint8_t stdLineLength;     /*!< Standard cell delay line, 0 to TRO_DELAY_LINE_STD_LENGTH_MAX. */
    uint8_t longLineLength;    /*!< Long delay line, 0 to TRO_DELAY_LINE_LONG_LENGTH_MAX. */
    uint8_t complexLineLength; /*!< Complex gate delay line, 0 to TRO_DELAY_LINE_CPLX_LENGTH_MAX. */
    uint8_t rcLineLength;      /*!< RC delay line, 0 to TRO_DELAY_LINE_RC_LENGTH_MAX. */
} tro_delay_line_config_t;

/*!
 * @brief TRO basic configuration.
 */
typedef struct _tro_config
{
    tro_delay_line_config_t delayLine; /*!< Delay line lengths. */
    uint8_t clockDivExponent;          /*!< Output divider: tro_clk is the ring frequency divided by
                                            2 raised to this value. */
    uint8_t refClkMultiplier;          /*!< CSR[REF_CLK_MULT], 0 to TRO_REF_CLK_MULT_MAX. Set this to the
                                            expected integer ratio of tro_clk to the reference clock when
                                            the phase comparator is used. */
} tro_config_t;

/*!
 * @brief Window mode configuration.
 *
 * @note The window must span at least 1 microsecond; this driver cannot check
 * that because it does not know the reference frequency. The size field resets to
 * 4800 rather than 0, so arming without setting a size gives a 4800-cycle window
 * instead of an error.
 */
typedef struct _tro_window_config
{
    uint32_t windowSize;    /*!< Window length in reference clock cycles, 1 to TRO_WINDOW_COUNT_MAX. */
    uint32_t maxThreshold;  /*!< Upper snapshot threshold, 0 to TRO_WINDOW_COUNT_MAX. */
    uint32_t minThreshold;  /*!< Lower snapshot threshold, 0 to TRO_WINDOW_COUNT_MAX. */
    uint32_t interruptMask; /*!< Interrupts to enable, an OR of @ref _tro_interrupt_enable. */
} tro_window_config_t;

/*******************************************************************************
 * API
 ******************************************************************************/

#if defined(__cplusplus)
extern "C" {
#endif

/*!
 * @name Initialization
 * @{
 */

/*!
 * @brief Enables the TRO and applies a configuration.
 *
 * @note The caller must already have selected a reference clock that is actually
 * running (SIM_PERIPH_CLKSEL0[TRO_CLK_SEL]) and, on a dual-core device, set bus
 * ownership (kSIM_AIPS_SEL_TRO). The TRO bus clock is not a prerequisite: this
 * function enables it itself, unless FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL is set.
 *
 * @note kStatus_Timeout usually means a dead ref_clk, not a broken TRO. Three
 * clocks must run: bus_clk (enabled here), tro_clk (CSR[TROEN]), ref_clk (the
 * board's, so the only one left to get wrong).
 *
 * @param base TRO peripheral base address.
 * @param config Pointer to the configuration, see @ref tro_config_t.
 * @retval kStatus_Success TRO is enabled and configured, with the delay line and
 *         divider transfers already completed.
 * @retval kStatus_Fail CSR[LK] was already set, so every write would have been
 *         silently ignored. No register was written.
 * @retval kStatus_InvalidArgument tro_config_t::refClkMultiplier exceeds
 *         TRO_REF_CLK_MULT_MAX. No register was written.
 * @retval kStatus_Timeout CSR[TRO_CONFIG_VLD] did not assert within
 *         TRO_CONFIG_VLD_TIMEOUT loops, or a shift transfer did not complete.
 *         CSR[TROEN] is cleared again before returning. Only returned when the
 *         relevant poll bound is non-zero.
 */
status_t TRO_Init(TRO_Type *base, const tro_config_t *config);

/*!
 * @brief Disables the TRO.
 *
 * @note Clearing CSR[TROEN] makes hardware reset DLY_CFG and DIV_CFG. This
 * driver does not cache and restore them, so a later TRO_Init() must supply the
 * configuration again; hiding that would misrepresent the hardware.
 *
 * @note This also gates the TRO bus clock off, after clearing CSR[TROEN], unless
 * FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL is set. **No TRO register is accessible
 * afterwards** - not even the read-only counters - until the next TRO_Init().
 *
 * @param base TRO peripheral base address.
 */
void TRO_Deinit(TRO_Type *base);

/*!
 * @brief Gets the default configuration.
 *
 * @code
 *      config->delayLine.stdLineLength     = TRO_DELAY_LINE_STD_LENGTH_MAX;
 *      config->delayLine.longLineLength    = TRO_DELAY_LINE_LONG_LENGTH_MAX;
 *      config->delayLine.complexLineLength = TRO_DELAY_LINE_CPLX_LENGTH_MAX;
 *      config->delayLine.rcLineLength      = TRO_DELAY_LINE_RC_LENGTH_MAX;
 *      config->clockDivExponent            = 0U;
 *      config->refClkMultiplier            = 6U;
 * @endcode
 *
 * The delay line and divider values are the hardware reset state. The multiplier
 * is 6 as RM worked-example ratio and 0 would make the phase counter accumulate the
 * whole TRO count each cycle.
 *
 * @param config Pointer to the configuration to fill, see @ref tro_config_t.
 */
void TRO_GetDefaultConfig(tro_config_t *config);

/*!
 * @brief Gets the default window configuration.
 *
 * @code
 *      config->windowSize    = 4800U;
 *      config->maxThreshold  = TRO_WINDOW_COUNT_MAX;
 *      config->minThreshold  = 0U;
 *      config->interruptMask = (uint32_t)kTRO_WindowExpiredInterruptEnable;
 * @endcode
 *
 * @param config Pointer to the configuration to fill, see @ref tro_window_config_t.
 */
void TRO_GetDefaultWindowConfig(tro_window_config_t *config);

/*! @} */

/*!
 * @name Oscillator configuration
 * @{
 */

/*!
 * @brief Sets the four delay line lengths.
 *
 * Polls DLY_CFG[TRO_DLY_DONE] first: the 64-bit shift transfer takes time and
 * writes issued during it are discarded. Polls it again after the write, so a
 * successful return means the new lengths are already driving the ring, not just
 * accepted by the register.
 *
 * @param base TRO peripheral base address.
 * @param config Pointer to the delay line lengths, see @ref tro_delay_line_config_t.
 * @retval kStatus_Success The four fields were written and the shift transfer completed.
 * @retval kStatus_Timeout TRO_DLY_DONE did not assert within
 *         TRO_DLY_DONE_TIMEOUT loops. Before the write, DLY_CFG was left
 *         untouched; after the write, DLY_CFG holds the new lengths but the
 *         transfer is unconfirmed. Only returned when TRO_DLY_DONE_TIMEOUT is
 *         non-zero.
 */
status_t TRO_SetDelayLineConfig(TRO_Type *base, const tro_delay_line_config_t *config);

/*!
 * @brief Sets the output clock divider.
 *
 * tro_clk becomes the ring frequency divided by 2 raised to @p divExponent.
 * Polls DIV_CFG[TRO_DIV_DONE] before and after the write, for the same reason as
 * the delay line setter.
 *
 * @param base TRO peripheral base address.
 * @param divExponent Divider exponent written to DIV_CFG[TRO_DIV].
 * @retval kStatus_Success The divider was written and the update completed.
 * @retval kStatus_Timeout TRO_DIV_DONE did not assert within
 *         TRO_DIV_DONE_TIMEOUT loops. Before the write, DIV_CFG was left
 *         untouched; after the write, DIV_CFG holds the new divider but the
 *         update is unconfirmed. Only returned when TRO_DIV_DONE_TIMEOUT is
 *         non-zero.
 */
status_t TRO_SetClockDivider(TRO_Type *base, uint8_t divExponent);

/*!
 * @brief Reads the TRO version ID.
 *
 * @param base TRO peripheral base address.
 * @return Contents of the VER_ID register.
 */
static inline uint32_t TRO_GetVersionId(TRO_Type *base)
{
    return base->VER_ID;
}

/*!
 * @brief Checks whether the read/write registers are locked.
 *
 * While locked, hardware ignores writes to the read/write registers and the
 * setters in this driver cannot detect it, so they still report success.
 *
 * @param base TRO peripheral base address.
 * @retval true Registers are locked; writes have no effect.
 * @retval false Registers are writable.
 */
static inline bool TRO_IsLocked(TRO_Type *base)
{
    return ((base->CSR & TRO_CSR_LK_MASK) != 0UL);
}

/*!
 * @brief Locks or unlocks the read/write registers.
 *
 * @note Locking makes every other write API in this driver silently ineffective
 * while it stays set. Hardware allows it to be cleared again, so it is not a fuse.
 *
 * @param base TRO peripheral base address.
 * @param lock true to lock, false to unlock.
 */
static inline void TRO_LockRegisters(TRO_Type *base, bool lock)
{
    if (lock)
    {
        base->CSR |= TRO_CSR_LK_MASK;
    }
    else
    {
        base->CSR &= ~TRO_CSR_LK_MASK;
    }
}

/*! @} */

/*!
 * @name Window mode
 * @{
 */

/*!
 * @brief Programs the window size, thresholds, and interrupt enables.
 *
 * @param base TRO peripheral base address.
 * @param config Pointer to the window configuration, see @ref tro_window_config_t.
 * @retval kStatus_Success The window registers were written.
 * @retval kStatus_InvalidArgument windowSize is 0, or a size or threshold
 *         exceeds TRO_WINDOW_COUNT_MAX. No register was written.
 */
status_t TRO_SetWindowConfig(TRO_Type *base, const tro_window_config_t *config);

/*!
 * @brief Sets the window size while leaving the oscillator running.
 *
 * Clears WIN_CFG[TRO_WIN_EN] and does not restore it, so the caller must re-arm
 * with TRO_EnableWindowMode(); silently re-enabling would hide a window boundary
 * discontinuity. DLY_CFG, DIV_CFG and CSR[TROEN] are untouched.
 *
 * @param base TRO peripheral base address.
 * @param windowSize Window length in reference clock cycles, 1 to TRO_WINDOW_COUNT_MAX.
 * @retval kStatus_Success The window size was written and window mode is disabled.
 * @retval kStatus_InvalidArgument windowSize is 0 or exceeds
 *         TRO_WINDOW_COUNT_MAX. WIN_CFG was not written.
 */
status_t TRO_SetWindowSize(TRO_Type *base, uint32_t windowSize);

/*!
 * @brief Enables or disables window mode.
 *
 * @param base TRO peripheral base address.
 * @param enable true to start measuring windows, false to stop.
 */
static inline void TRO_EnableWindowMode(TRO_Type *base, bool enable)
{
    if (enable)
    {
        base->WIN_CFG |= TRO_WIN_CFG_TRO_WIN_EN_MASK;
    }
    else
    {
        base->WIN_CFG &= ~TRO_WIN_CFG_TRO_WIN_EN_MASK;
    }
}

/*!
 * @brief Reads the tro_clk cycle count captured by the last completed window.
 *
 * @note This reads 0 whenever CSR[TROEN] or WIN_CFG[TRO_WIN_EN] is 0, so 0 does
 * not distinguish "not measured yet" from "disabled" and is not evidence of a
 * fault. Gate on kTRO_WindowExpiredFlag, not on a non-zero result. Valid only
 * while the peripheral is clocked.
 *
 * @param base TRO peripheral base address.
 * @return Cycle count for the last completed window, 22 bits.
 */
static inline uint32_t TRO_GetWindowSnapshot(TRO_Type *base)
{
    return (base->CNT_SNAPSHOT & TRO_CNT_SNAPSHOT_CNTSNAPSHOT_MASK);
}

/*!
 * @brief Reads the free-running tro_clk cycle counter.
 *
 * @note This reads 0 whenever CSR[TROEN] is 0. The counter wraps at 22 bits.
 * Valid only while the peripheral is clocked.
 *
 * @param base TRO peripheral base address.
 * @return Current counter value, 22 bits.
 */
static inline uint32_t TRO_GetClockCounter(TRO_Type *base)
{
    return (base->TRO_CNT & TRO_TRO_CNT_TROCNT_MASK);
}

/*! @} */

/*!
 * @name Interrupts and status
 * @{
 */

/*!
 * @brief Enables window interrupts.
 *
 * @param base TRO peripheral base address.
 * @param mask Interrupts to enable, an OR of @ref _tro_interrupt_enable.
 */
static inline void TRO_EnableInterrupts(TRO_Type *base, uint32_t mask)
{
    base->WIN_CFG |= (mask & (uint32_t)kTRO_AllInterruptEnable);
}

/*!
 * @brief Disables window interrupts.
 *
 * @param base TRO peripheral base address.
 * @param mask Interrupts to disable, an OR of @ref _tro_interrupt_enable.
 */
static inline void TRO_DisableInterrupts(TRO_Type *base, uint32_t mask)
{
    base->WIN_CFG &= ~(mask & (uint32_t)kTRO_AllInterruptEnable);
}

/*!
 * @brief Gets the window interrupt status flags.
 *
 * @param base TRO peripheral base address.
 * @return Asserted flags, an OR of @ref _tro_interrupt_status_flags.
 */
static inline uint32_t TRO_GetInterruptStatusFlags(TRO_Type *base)
{
    return (base->WIN_ST & (uint32_t)kTRO_AllInterruptStatusFlags);
}

/*!
 * @brief Clears window interrupt status flags.
 *
 * @param base TRO peripheral base address.
 * @param mask Flags to clear, an OR of @ref _tro_interrupt_status_flags.
 */
static inline void TRO_ClearInterruptStatusFlags(TRO_Type *base, uint32_t mask)
{
    base->WIN_ST = (mask & (uint32_t)kTRO_AllInterruptStatusFlags);
}

/*! @} */

/*!
 * @name Phase comparator
 * @{
 */

/*!
 * @brief Sets the expected integer ratio of tro_clk to the reference clock.
 *
 * The phase counter accumulates, once per reference clock period, the difference
 * between the observed tro_clk count and this value. With the correct ratio it
 * stays near 0; a systematic deviation integrates instead of averaging out, which
 * is what lets it catch a small persistent drift that every individual window
 * reports as in tolerance.
 *
 * @note The field is 6 bits, so only integer ratios are expressible. A
 * non-integer ratio makes the counter walk to saturation.
 *
 * @param base TRO peripheral base address.
 * @param multiplier Expected ratio, 0 to TRO_REF_CLK_MULT_MAX.
 * @retval kStatus_Success The multiplier was written.
 * @retval kStatus_InvalidArgument multiplier exceeds TRO_REF_CLK_MULT_MAX. CSR
 *         was not written.
 */
status_t TRO_SetReferenceClockMultiplier(TRO_Type *base, uint8_t multiplier);

/*!
 * @brief Clears the phase counter.
 *
 * @param base TRO peripheral base address.
 */
static inline void TRO_ClearPhaseCounter(TRO_Type *base)
{
    base->CSR |= TRO_CSR_CLR_PHASE_CNTR_MASK;
}

/*!
 * @brief Reads the phase counter as a signed value.
 *
 * The register presents a sign-extended two's-complement value: PHASECNT is bits
 * 21 to 0, SIGN_EXTENSION is bits 31 to 22. It saturates at +2097151 and
 * -2097152, and reads 0 whenever CSR[TROEN] is 0. Valid only while the peripheral
 * is clocked.
 *
 * @note Deliberately not masked with TRO_PHASE_CNT_PHASECNT_MASK: masking would
 * strip the sign extension and turn every negative reading into a large positive
 * one.
 *
 * @param base TRO peripheral base address.
 * @return Accumulated phase error, signed.
 */
static inline int32_t TRO_GetPhaseCounter(TRO_Type *base)
{
    return (int32_t)base->PHASE_CNT;
}

/*! @} */

/*! @} */

#if defined(__cplusplus)
}
#endif

/*!
 * @}
 */
#endif /* FSL_TRO_H_ */
