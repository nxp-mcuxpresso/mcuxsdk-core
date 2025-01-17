/*
 * Copyright 2025 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "fsl_flexio_a-format.h"

/*******************************************************************************
 * Definitions
 ******************************************************************************/
/* Component ID definition, used by tools. */
#ifndef FSL_COMPONENT_ID
#define FSL_COMPONENT_ID "platform.drivers.flexio_a_format"
#endif

/*<! @brief a-format transfer state. */
enum _flexio_a_format_transfer_states
{
    kFLEXIO_A_FORMAT_TxIdle, /* TX idle. */
    kFLEXIO_A_FORMAT_TxBusy, /* TX busy. */
    kFLEXIO_A_FORMAT_RxIdle, /* RX idle. */
    kFLEXIO_A_FORMAT_RxBusy  /* RX busy. */
};

/*******************************************************************************
 * Variables
 ******************************************************************************/
/*! @brief Pointers to flexio root clocks for each instance. */
static bool is_MultiTrans;
static uint8_t cmd, cmdErr, crc, nEncoder;
static uint16_t crc_data, cdf;
static CRC_Para_t crc3_para = {
    .message       = (uint8_t *)(&crc_data),
    .type          = A_FORMAT_CRC3,
    .message_len   = 2,
    .polynomial    = A_FORMAT_CRC_POLY_COMMAND_DATA,
    .inputBitSwap  = true,
    .outputBitSwap = true
};
static CRC_Para_t crc8_para = {
    .type          = A_FORMAT_CRC8,
    .polynomial    = A_FORMAT_CRC_POLY_ENCODER_DATA,
    .inputBitSwap  = true,
    .outputBitSwap = true
};
static encoder_res1_t res1[8];
static encoder_res2_t res2[8];
static encoder_res3_t res3[8];

static encoder_A_format *enc_g;
static encoder_abs_multi_single_t *abs_data_g;
static encoder_abs_single_t *single_data_g;
static encoder_abs_multi_t *multiData_g;
static encoder_status_t *statusData_g;
static float *temp_g;
static uint32_t *id_g;

/*******************************************************************************
 * Codes
 ******************************************************************************/

static uint32_t FLEXIO_A_Format_GetInstance(FLEXIO_A_FORMAT_Type *base)
{
    return FLEXIO_GetInstance(base->flexioBase);
}

static status_t FLEXIO_A_Format_CheckBaudRate(uint32_t baudRate_Bps, uint32_t srcClock_Hz, uint16_t timerDiv)
{
    uint32_t calculatedBaud, diff;

    calculatedBaud = srcClock_Hz / (((uint32_t)timerDiv + 1U) * 2U);
    diff = calculatedBaud - baudRate_Bps;
    if (diff > ((baudRate_Bps / 100U) * 5U / 3U))  //1.667%
    {
        return kStatus_FLEXIO_A_FORMAT_BaudrateNotSupport;
    }
    return kStatus_Success;
}

/*!
 *
 */
static uint16_t FLEXIO_A_Format_GetTimerCompare(FLEXIO_A_FORMAT_Type *base, flexio_a_format_baud_rate_bps_t baudrate, uint32_t srcClock_Hz)
{
    uint16_t timerCmp = 0;

    switch (baudrate)
    {
    case kFLEXIO_A_FORMAT_2_5MHZ:
        base->timerDiv = srcClock_Hz / 2500000;
        timerCmp = base->timerDiv / 2U - 1U;
        if ((timerCmp > 0xFFU) || (FLEXIO_A_Format_CheckBaudRate(2500000, srcClock_Hz, timerCmp) != kStatus_Success))
        {
            return 0xFFFFU;
        }

        timerCmp = A_FORMAT_TIMER_COMPARE_VALUE(timerCmp);
        base->TxDR_Offset = srcClock_Hz * 3 / 2000000; /* 1.5us */
        base->interval    = srcClock_Hz * 3 / 1000000; /* 3us */
        break;

    case kFLEXIO_A_FORMAT_4MHZ:
        base->timerDiv = srcClock_Hz / 4000000;
        timerCmp = base->timerDiv / 2U - 1U;
        if ((timerCmp > 0xFFU) || (FLEXIO_A_Format_CheckBaudRate(4000000, srcClock_Hz, timerCmp) != kStatus_Success))
        {
            return 0xFFFFU;
        }

        timerCmp = A_FORMAT_TIMER_COMPARE_VALUE(timerCmp);
        base->TxDR_Offset = srcClock_Hz / 1000000;     /* 1us */
        base->interval    = srcClock_Hz * 3 / 1000000; /* 3us */
        break;

    case kFLEXIO_A_FORMAT_6_67MHZ: /* Deviation = 0 */
        base->timerDiv = srcClock_Hz * 3 / 20 / 1000000;
        timerCmp = base->timerDiv / 2U - 1U;
        if ((timerCmp > 0xFFU) || (FLEXIO_A_Format_CheckBaudRate(20000000 / 3, srcClock_Hz, timerCmp) != kStatus_Success))
        {
            return 0xFFFFU;
        }

        timerCmp = A_FORMAT_TIMER_COMPARE_VALUE(timerCmp);
        base->TxDR_Offset = srcClock_Hz / 1000000;     /* 1us */
        base->interval    = srcClock_Hz * 3 / 1000000; /* 3us */
        break;

    case kFLEXIO_A_FORMAT_8MHZ: /* Deviation = 0 */
        base->timerDiv = srcClock_Hz / 8000000;
        timerCmp = base->timerDiv / 2U - 1U;
        if ((timerCmp > 0xFFU) || (FLEXIO_A_Format_CheckBaudRate(8000000, srcClock_Hz, timerCmp) != kStatus_Success))
        {
            return 0xFFFFU;
        }

        timerCmp = A_FORMAT_TIMER_COMPARE_VALUE(timerCmp);
        base->TxDR_Offset = srcClock_Hz / 10000000 * 7; /* 0.7us */
        base->interval    = srcClock_Hz * 3 / 1000000;  /* 3us */
        break;

    case kFLEXIO_A_FORMAT_16MHZ: /* Deviation = 4.17% */
        timerCmp = A_FORMAT_BITS_PER_FRAME_DATA * 2 - 1; // (CMP[15:0] + 1) / 2 = 16 for 16-bit timer
        base->timerDiv = 3;
        base->TxDR_Offset = 34;  /* 0.7us */
        base->interval    = 480; /* 10us */
        break;

    default:
        return 0xFFFFU;
    }

    return timerCmp;
}

/*!
 *
 */
void FLEXIO_A_Format_Config_DR_length(FLEXIO_A_FORMAT_Type *base, uint32_t nFrames)
{
    uint16_t timerCmp = 0;

    timerCmp = (uint16_t)(A_FORMAT_BITS_PER_FRAME_WHOLE * nFrames * base->timerDiv +
                          base->interval * (nFrames - 1) + base->TxDR_Offset) - 1;
    base->flexioBase->TIMCMP[base->timerIndex[TIMER_DR_INDEX]] = FLEXIO_TIMCMP_CMP(timerCmp);
}

/*!
 * @brief Get the length of received data in RX ring buffer.
 *
 * @param handle FLEXIO A-format handle pointer.
 * @return Length of received data in RX ring buffer.
 */
static size_t FLEXIO_A_Format_TransferGetRxRingBufferLength(flexio_a_format_handle_t *handle)
{
    size_t size;
    uint16_t rxRingBufferHead = handle->rxRingBufferHead;
    uint16_t rxRingBufferTail = handle->rxRingBufferTail;

    if (rxRingBufferTail > rxRingBufferHead)
    {
        size = (size_t)rxRingBufferHead + handle->rxRingBufferSize - (size_t)rxRingBufferTail;
    }
    else
    {
        size = (size_t)rxRingBufferHead - (size_t)rxRingBufferTail;
    }

    return size;
}

/*!
 * @brief Check whether the RX ring buffer is full.
 *
 * @param handle FLEXIO A-format handle pointer.
 * @retval true  RX ring buffer is full.
 * @retval false RX ring buffer is not full.
 */
static bool FLEXIO_A_Format_TransferIsRxRingBufferFull(flexio_a_format_handle_t *handle)
{
    bool full;

    if (FLEXIO_A_Format_TransferGetRxRingBufferLength(handle) == (handle->rxRingBufferSize - 1U))
    {
        full = true;
    }
    else
    {
        full = false;
    }

    return full;
}

/*!
 * brief Ungates the FlexIO clock, resets the FlexIO module, configures the FlexIO A-Format
 * hardware, and configures the FlexIO A-Format with FlexIO A-Format configuration.
 * The configuration structure can be filled by the user, or be set with default values
 * by the FLEXIO_A_Format_GetDefaultConfig().
 *
 * Example
   code
   FLEXIO_A_FORMAT_Type base = {
   .flexioBase = FLEXIO,
   .TxPinIndex = 0,
   .RxPinIndex = 1,
   .shifterIndex = {0,1},
   .timerIndex = {0,1}
   };
   flexio_a_format_config_t config = {
   .enableInDoze = false,
   .enableInDebug = true,
   .enableFastAccess = false,
   .baudRate_bps = 2500000
   };
   FLEXIO_A_Format_Init(&base, &config, srcClock_Hz);
   endcode
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param userConfig Pointer to the flexio_a_format_config_t structure.
 * param srcClock_Hz FlexIO source clock in Hz.
 * retval kStatus_Success Configuration success.
 * retval kStatus_FLEXIO_A_FORMAT_BaudrateNotSupport Baudrate is not supported for current clock source frequency.
 */
status_t FLEXIO_A_Format_Init(FLEXIO_A_FORMAT_Type *base, flexio_a_format_config_t *userConfig, uint32_t srcClock_Hz)
{
    assert((base != NULL) && (userConfig != NULL));

    flexio_shifter_config_t shifterConfig;
    flexio_timer_config_t timerConfig;
    uint32_t ctrlReg  = 0;
    uint16_t timerCmp = 0;
    status_t result = kStatus_Success;

    /* Clear the shifterConfig & timerConfig struct. */
    (void)memset(&shifterConfig, 0, sizeof(shifterConfig));
    (void)memset(&timerConfig, 0, sizeof(timerConfig));

#if !(defined(FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL) && FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL)
    /* Ungate flexio clock. */
    CLOCK_EnableClock(s_flexioClocks[FLEXIO_A_Format_GetInstance(base)]);
#endif /* FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL */

    /* Configure FLEXIO A_FORMAT */
    ctrlReg = base->flexioBase->CTRL;
    ctrlReg &= ~(FLEXIO_CTRL_DOZEN_MASK | FLEXIO_CTRL_DBGE_MASK | FLEXIO_CTRL_FASTACC_MASK | FLEXIO_CTRL_FLEXEN_MASK);
    ctrlReg |= (FLEXIO_CTRL_DBGE(userConfig->enableInDebug) | FLEXIO_CTRL_FASTACC(userConfig->enableFastAccess) |
                FLEXIO_CTRL_FLEXEN(userConfig->enableA_Format));
    if (!userConfig->enableInDoze)
    {
        ctrlReg |= FLEXIO_CTRL_DOZEN_MASK;
    }

    base->flexioBase->CTRL = ctrlReg;

    /* Do hardware configuration. */
    /* 1. Configure the shifter 0 for tx. */
    shifterConfig.timerSelect   = base->timerIndex[TIMER_TX_INDEX]; // Timer Index
    shifterConfig.timerPolarity = kFLEXIO_ShifterTimerPolarityOnPositive;    // Shift on positive edge of shift clock.
    shifterConfig.pinConfig     = kFLEXIO_PinConfigOutput;                   // Pin output
    shifterConfig.pinSelect     = base->TxPinIndex;                          // Pin Index
    shifterConfig.pinPolarity   = kFLEXIO_PinActiveHigh;                     // [Shifter bit value] XOR(^) [Active high(0)] = Pin level
    shifterConfig.shifterMode   = kFLEXIO_ShifterModeTransmit;               // Transmit mode.
    shifterConfig.inputSource   = kFLEXIO_ShifterInputFromPin;               // Shifter input from pin.(takes no effect)
    shifterConfig.shifterStop   = kFLEXIO_ShifterStopBitHigh;                // Set shifter stop bit to logic high level.
    shifterConfig.shifterStart  = kFLEXIO_ShifterStartBitLow;                // Set shifter start bit to logic low level.

    FLEXIO_SetShifterConfig(base->flexioBase, base->shifterIndex[0], &shifterConfig);

    /*2. Configure the timer 0 for tx. */
    timerConfig.triggerSelect   = FLEXIO_TIMER_TRIGGER_SEL_SHIFTnSTAT(base->shifterIndex[0]); // Tx Shifter(0) status flag triggers this timer
    timerConfig.triggerPolarity = kFLEXIO_TimerTriggerPolarityActiveLow;                      // Low level activates trigger (start bit is low), Timer starts
    timerConfig.triggerSource   = kFLEXIO_TimerTriggerSourceInternal;                         // Internal trigger selected
    timerConfig.pinConfig       = kFLEXIO_PinConfigOutputDisabled;                            // Timer pin output disabled.
    timerConfig.pinSelect       = base->TxPinIndex;                                           // Timer pin Index (takes no effect)
    timerConfig.pinPolarity     = kFLEXIO_PinActiveHigh;                                      // (takes no effect)
    timerConfig.timerMode       = kFLEXIO_TimerModeDual8BitBaudBit;                           // Dual 8-bit counters baud/bit mode.
    timerConfig.timerOutput     = kFLEXIO_TimerOutputOneNotAffectedByReset;                   // Timer output is logic one when enabled and is not affected by timer reset (takes no effect)
    timerConfig.timerDecrement  = kFLEXIO_TimerDecSrcOnFlexIOClockShiftTimerOutput;           // Decrement counter on FLEXIO clock. Shift clock equals timer output.
    timerConfig.timerReset      = kFLEXIO_TimerResetNever;                                    // Timer never reset.
    timerConfig.timerDisable    = kFLEXIO_TimerDisableOnTimerCompare;                         // Timer disabled on Timer compare.
    timerConfig.timerEnable     = kFLEXIO_TimerEnableOnTriggerHigh;                           // The status flag is set when SHIFTBUF data has been transferred to the shifter
    timerConfig.timerStop       = kFLEXIO_TimerStopBitEnableOnTimerDisable; // Shifters output the stop bit when the timer is disabled.
    timerConfig.timerStart      = kFLEXIO_TimerStartBitEnabled;  // Shifters output the start bit when the timer is enabled.
                                                                 // The timer counter reloads from the compare register on the first rising edge of the shift clock.

    if (userConfig->userMode == kFLEXIO_A_FORMAT_USERMODE_SYNC) {
        /*Configure the timer is triggered by FlexIO trigger signal. */
        timerConfig.triggerSelect   = base->triggerIn;
        timerConfig.triggerPolarity = kFLEXIO_TimerTriggerPolarityActiveHigh;
        timerConfig.triggerSource   = kFLEXIO_TimerTriggerSourceExternal;
    }

    timerCmp = FLEXIO_A_Format_GetTimerCompare(base, userConfig->baudRate_bps, srcClock_Hz);
    if (timerCmp == 0xFFFFU)
    {
        /* Check whether the configuared baudrate is within allowed range. */
        return kStatus_FLEXIO_A_FORMAT_BaudrateNotSupport;
    }
    timerConfig.timerCompare = timerCmp;

    if (userConfig->baudRate_bps == kFLEXIO_A_FORMAT_16MHZ) {
        timerConfig.triggerSelect   = FLEXIO_TIMER_TRIGGER_SEL_TIMn(base->timerIndex[TIMER_TX_CLOCK_INDEX]);
        timerConfig.timerMode       = kFLEXIO_TimerModeSingle16Bit;  // The compare register is used to set the number of bits in each word = (CMP[15:0] + 1) / 2
        timerConfig.timerDecrement  = kFLEXIO_TimerRisSrcOnTriggerInputShiftTriggerInput;  // Decrement counter on trigger input (rising edge). Shift clock equals trigger input.
        timerConfig.timerEnable     = kFLEXIO_TimerEnableOnTriggerRisingEdge;              //Timer enabled on Trigger rising edge.
    }
    FLEXIO_SetTimerConfig(base->flexioBase, base->timerIndex[TIMER_TX_INDEX], &timerConfig);

    /* Configure the timer 1 for tx clock (PWM mode). */
    if (userConfig->baudRate_bps == kFLEXIO_A_FORMAT_16MHZ) {
        timerConfig.triggerSelect   = FLEXIO_TIMER_TRIGGER_SEL_SHIFTnSTAT(base->shifterIndex[0]);  // Tx Shifter(0) status flag triggers this timer
        timerConfig.triggerPolarity = kFLEXIO_TimerTriggerPolarityActiveHigh;  // High level activates trigger, Timer starts immediately after enable
        timerConfig.triggerSource   = kFLEXIO_TimerTriggerSourceInternal;     // Internal trigger selected
        timerConfig.pinConfig       = kFLEXIO_PinConfigOutputDisabled;        // Timer pin output disabled.
//        timerConfig.pinSelect       = base->TxPinIndex;                       // Timer pin Index (takes no effect)
        timerConfig.pinPolarity     = kFLEXIO_PinActiveHigh;                  // Active high.
        timerConfig.timerMode       = kFLEXIO_TimerModeDual8BitPWM;           // Dual 8-bit counters PWM mode.
        timerConfig.timerOutput     = kFLEXIO_TimerOutputOneNotAffectedByReset;  // Timer output is logic one when enabled and is not affected by timer reset (takes no effect)
        timerConfig.timerDecrement  = kFLEXIO_TimerDecSrcOnFlexIOClockShiftTimerOutput; // (48MHz) Decrement counter on FlexIO clock, Shift clock equals Timer output.
        timerConfig.timerReset      = kFLEXIO_TimerResetNever;               // Timer never reset.
        timerConfig.timerDisable    = kFLEXIO_TimerDisableOnPreTimerDisable; // N-1 timer disable
        timerConfig.timerEnable     = kFLEXIO_TimerEnableOnTriggerHigh;      // The status flag is set when SHIFTBUF data has been transferred to the shifter
        timerConfig.timerStop       = kFLEXIO_TimerStopBitEnableOnTimerDisable;
        timerConfig.timerStart      = kFLEXIO_TimerStartBitEnabled;
        timerConfig.timerCompare    = 0x1U; // High(CMP[7:0] + 1)  + low(CMP[15:8] + 1) = 2 + 1 ==> CMP[7:0]=1, CMP[15:8]=0
        FLEXIO_SetTimerConfig(base->flexioBase, base->timerIndex[TIMER_TX_CLOCK_INDEX], &timerConfig);
    }

    /* 3. Configure the shifter 1 for rx. */
    shifterConfig.timerSelect   = base->timerIndex[TIMER_RX_INDEX];
    shifterConfig.timerPolarity = kFLEXIO_ShifterTimerPolarityOnNegitive;
    shifterConfig.pinConfig     = kFLEXIO_PinConfigOutputDisabled;
    shifterConfig.pinSelect     = base->RxPinIndex;
    shifterConfig.pinPolarity   = kFLEXIO_PinActiveHigh;
    shifterConfig.shifterMode   = kFLEXIO_ShifterModeReceive;
    shifterConfig.inputSource   = kFLEXIO_ShifterInputFromPin;
    shifterConfig.shifterStop   = kFLEXIO_ShifterStopBitHigh;
    shifterConfig.shifterStart  = kFLEXIO_ShifterStartBitLow;

    FLEXIO_SetShifterConfig(base->flexioBase, base->shifterIndex[1], &shifterConfig);

    /* 4. Configure the timer 2 for rx. */
    timerConfig.triggerSelect   = FLEXIO_TIMER_TRIGGER_SEL_PININPUT(base->RxPinIndex);
    timerConfig.triggerPolarity = kFLEXIO_TimerTriggerPolarityActiveHigh;
    timerConfig.triggerSource   = kFLEXIO_TimerTriggerSourceExternal;
    timerConfig.pinConfig       = kFLEXIO_PinConfigOutputDisabled;
    timerConfig.pinSelect       = base->RxPinIndex;
    timerConfig.pinPolarity     = kFLEXIO_PinActiveLow;
    timerConfig.timerMode       = kFLEXIO_TimerModeDual8BitBaudBit;
    timerConfig.timerOutput     = kFLEXIO_TimerOutputOneAffectedByReset;
    timerConfig.timerDecrement  = kFLEXIO_TimerDecSrcOnFlexIOClockShiftTimerOutput;
    timerConfig.timerReset      = kFLEXIO_TimerResetOnTimerPinRisingEdge;
    timerConfig.timerDisable    = kFLEXIO_TimerDisableOnTimerCompare;
    timerConfig.timerEnable     = kFLEXIO_TimerEnableOnPinRisingEdge;
    timerConfig.timerStop       = kFLEXIO_TimerStopBitEnableOnTimerDisable;
    timerConfig.timerStart      = kFLEXIO_TimerStartBitEnabled;
    timerConfig.timerCompare    = timerCmp;

    if (userConfig->baudRate_bps == kFLEXIO_A_FORMAT_16MHZ) {
        timerConfig.triggerSelect   = FLEXIO_TIMER_TRIGGER_SEL_TIMn(base->timerIndex[TIMER_RX_CLOCK_INDEX]);
        timerConfig.timerMode       = kFLEXIO_TimerModeSingle16Bit;
        timerConfig.timerDecrement  = kFLEXIO_TimerRisSrcOnTriggerInputShiftTriggerInput;
        timerConfig.timerReset      = kFLEXIO_TimerResetNever;
    }
    FLEXIO_SetTimerConfig(base->flexioBase, base->timerIndex[TIMER_RX_INDEX], &timerConfig);

    /* Configure the timer 3 for rx clock (PWM mode). */
    if (userConfig->baudRate_bps == kFLEXIO_A_FORMAT_16MHZ) {
        timerConfig.triggerSelect   = FLEXIO_TIMER_TRIGGER_SEL_PININPUT(base->RxPinIndex);
        timerConfig.triggerPolarity = kFLEXIO_TimerTriggerPolarityActiveHigh;
        timerConfig.triggerSource   = kFLEXIO_TimerTriggerSourceExternal;
        timerConfig.pinConfig       = kFLEXIO_PinConfigOutputDisabled;
        timerConfig.pinSelect       = base->RxPinIndex;
        timerConfig.pinPolarity     = kFLEXIO_PinActiveLow;
        timerConfig.timerMode       = kFLEXIO_TimerModeDual8BitPWM;
        timerConfig.timerOutput     = kFLEXIO_TimerOutputOneAffectedByReset;
        timerConfig.timerDecrement  = kFLEXIO_TimerDecSrcOnFlexIOClockShiftTimerOutput; // 48MHz
        timerConfig.timerReset      = kFLEXIO_TimerResetNever;
        timerConfig.timerDisable    = kFLEXIO_TimerDisableNever;
        timerConfig.timerEnable     = kFLEXIO_TimerEnabledAlways;
        timerConfig.timerStop       = kFLEXIO_TimerStopBitDisabled; // No Stop and Start bits
        timerConfig.timerStart      = kFLEXIO_TimerStartBitDisabled;
        timerConfig.timerCompare    = 0x1U; // High(CMP[7:0] + 1)  + low(CMP[15:8] + 1) = 2 + 1 ==> CMP[7:0]=1, CMP[15:8]=0
        FLEXIO_SetTimerConfig(base->flexioBase, base->timerIndex[TIMER_RX_CLOCK_INDEX], &timerConfig);
    }

    /*5. Configure the timer 2 for DR */
    timerConfig.triggerSelect   = FLEXIO_TIMER_TRIGGER_SEL_TIMn(base->timerIndex[TIMER_TX_INDEX]);
    timerConfig.triggerPolarity = kFLEXIO_TimerTriggerPolarityActiveHigh;
    timerConfig.triggerSource   = kFLEXIO_TimerTriggerSourceInternal;
    timerConfig.pinConfig       = kFLEXIO_PinConfigOutput;
    timerConfig.pinSelect       = base->DRPinIndex;
    timerConfig.pinPolarity     = kFLEXIO_PinActiveHigh;
    timerConfig.timerMode       = kFLEXIO_TimerModeSingle16Bit;
    timerConfig.timerOutput     = kFLEXIO_TimerOutputOneNotAffectedByReset;
    timerConfig.timerDecrement  = kFLEXIO_TimerDecSrcOnFlexIOClockShiftTimerOutput;
    timerConfig.timerReset      = kFLEXIO_TimerResetNever;
    timerConfig.timerDisable    = kFLEXIO_TimerDisableOnTimerCompare;
    timerConfig.timerEnable     = kFLEXIO_TimerEnableOnTriggerHigh;
    timerConfig.timerStop       = kFLEXIO_TimerStopBitDisabled;
    timerConfig.timerStart      = kFLEXIO_TimerStartBitDisabled;

    /* Calculate the DR signal length.
     * Because the number of the bytes is one for the request on sync mode,
     * the default DR signal length is for one byte transmitting.
     */

    timerCmp = (uint16_t)(A_FORMAT_BITS_PER_FRAME_WHOLE * base->timerDiv) - 1;
    timerConfig.timerCompare = timerCmp;

    FLEXIO_SetTimerConfig(base->flexioBase, base->timerIndex[TIMER_DR_INDEX], &timerConfig);
    return result;
}

/*!
 * brief Resets the FlexIO A-Format shifter and timer config.
 *
 * note After calling this API, call the FLEXIO_A_Format_Init to use the FlexIO A_format module.
 *
 * param base Pointer to FLEXIO_A_FORMAT_Type structure
 */
void FLEXIO_A_Format_Deinit(FLEXIO_A_FORMAT_Type *base)
{
    base->flexioBase->SHIFTCFG[base->shifterIndex[0]] = 0;
    base->flexioBase->SHIFTCTL[base->shifterIndex[0]] = 0;
    base->flexioBase->SHIFTCFG[base->shifterIndex[1]] = 0;
    base->flexioBase->SHIFTCTL[base->shifterIndex[1]] = 0;
    for (int i = 0; i <= TIMER_DR_INDEX; i++)
    {
        base->flexioBase->TIMCFG[base->timerIndex[i]]     = 0;
        base->flexioBase->TIMCMP[base->timerIndex[i]]     = 0;
        base->flexioBase->TIMCTL[base->timerIndex[i]]     = 0;
    }
    /* Clear the shifter flag. */
    base->flexioBase->SHIFTSTAT = (1UL << base->shifterIndex[0]);
    base->flexioBase->SHIFTSTAT = (1UL << base->shifterIndex[1]);
    /* Clear the timer flag. */
    for (int i = 0; i <= TIMER_DR_INDEX; i++)
        base->flexioBase->TIMSTAT = (1UL << base->timerIndex[i]);
}

/*!
 * brief Gets the default configuration to configure the FlexIO A-format. The configuration
 * can be used directly for calling the FLEXIO_A_Format_Init().
 * Example:
   code
   flexio_a_format_config_t config;
   FLEXIO_A_Format_GetDefaultConfig(&userConfig);
   endcode
 * param userConfig Pointer to the flexio_a_format_config_t structure.
*/
void FLEXIO_A_Format_GetDefaultConfig(flexio_a_format_config_t *userConfig)
{
    /* Initializes the configure structure to zero. */
    (void)memset(userConfig, 0, sizeof(*userConfig));

    userConfig->enableA_Format   = true;
    userConfig->enableInDoze     = false;
    userConfig->enableInDebug    = true;
    userConfig->enableFastAccess = false;
    /* Default baud rate 2.5Mbps. */
    userConfig->baudRate_bps     = kFLEXIO_A_FORMAT_2_5MHZ;
    /* Default running mode USERMODE_ONESHOT*/
    userConfig->userMode         = kFLEXIO_A_FORMAT_USERMODE_ONESHOT;
}

/*!
 * brief Enables the FlexIO A-format interrupt.
 *
 * This function enables the FlexIO A-format interrupt.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param mask Interrupt source.
 */
void FLEXIO_A_Format_EnableInterrupts(FLEXIO_A_FORMAT_Type *base, uint32_t mask)
{
    if ((mask & (uint32_t)kFLEXIO_A_FORMAT_TxDataRegEmptyInterruptEnable) != 0U)
    {
        FLEXIO_EnableShifterStatusInterrupts(base->flexioBase, 1UL << base->shifterIndex[0]);
    }
    if ((mask & (uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullInterruptEnable) != 0U)
    {
        FLEXIO_EnableShifterStatusInterrupts(base->flexioBase, 1UL << base->shifterIndex[1]);
    }
}

/*!
 * brief Disables the FlexIO A-format interrupt.
 *
 * This function disables the FlexIO A-format interrupt.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param mask Interrupt source.
 */
void FLEXIO_A_Format_DisableInterrupts(FLEXIO_A_FORMAT_Type *base, uint32_t mask)
{
    if ((mask & (uint32_t)kFLEXIO_A_FORMAT_TxDataRegEmptyInterruptEnable) != 0U)
    {
        FLEXIO_DisableShifterStatusInterrupts(base->flexioBase, 1UL << base->shifterIndex[0]);
    }
    if ((mask & (uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullInterruptEnable) != 0U)
    {
        FLEXIO_DisableShifterStatusInterrupts(base->flexioBase, 1UL << base->shifterIndex[1]);
    }
}

/*!
 * brief Gets the FlexIO A-format status flags.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * return FlexIO A-format status flags.
 */
uint32_t FLEXIO_A_Format_GetStatusFlags(FLEXIO_A_FORMAT_Type *base)
{
    uint32_t status = 0U;
    status =
        ((FLEXIO_GetShifterStatusFlags(base->flexioBase) & (1UL << base->shifterIndex[0])) >> base->shifterIndex[0]);
    status |=
        (((FLEXIO_GetShifterStatusFlags(base->flexioBase) & (1UL << base->shifterIndex[1])) >> (base->shifterIndex[1]))
         << 1U);
    status |=
        (((FLEXIO_GetShifterErrorFlags(base->flexioBase) & (1UL << base->shifterIndex[1])) >> (base->shifterIndex[1]))
         << 2U);
    return status;
}

/*!
 * brief Clears the FlexIO A-format status flags.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param mask Status flag.
 *      The parameter can be any combination of the following values:
 *          arg kFLEXIO_A_FORMAT_TxDataRegEmptyFlag
 *          arg kFLEXIO_A_FORMAT_RxDataRegFullFlag
 *          arg kFLEXIO_A_FORMAT_RxOverRunFlag
 */
void FLEXIO_A_Format_ClearStatusFlags(FLEXIO_A_FORMAT_Type *base, uint32_t mask)
{
    if ((mask & (uint32_t)kFLEXIO_A_FORMAT_TxDataRegEmptyFlag) != 0U)
    {
        FLEXIO_ClearShifterStatusFlags(base->flexioBase, 1UL << base->shifterIndex[0]);
    }
    if ((mask & (uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullFlag) != 0U)
    {
        FLEXIO_ClearShifterStatusFlags(base->flexioBase, 1UL << base->shifterIndex[1]);
    }
    if ((mask & (uint32_t)kFLEXIO_A_FORMAT_RxOverRunFlag) != 0U)
    {
        FLEXIO_ClearShifterErrorFlags(base->flexioBase, 1UL << base->shifterIndex[1]);
    }
}

/*!
 * brief Sends a buffer of data bytes.
 *
 * note This function blocks using the polling method until all bytes have been sent.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param txData The data bytes to send.
 * param txSize The number of data bytes to send.
 * retval kStatus_FLEXIO_A_FORMAT_Timeout Transmission timed out and was aborted.
 * retval kStatus_Success Successfully wrote all data.
 */
status_t FLEXIO_A_Format_WriteBlocking(FLEXIO_A_FORMAT_Type *base, const uint16_t *txData, size_t txSize)
{
    assert(txData != NULL);
    assert(txSize != 0U);
#if A_FORMAT_RETRY_TIMES
    uint32_t waitTimes = A_FORMAT_RETRY_TIMES;
#endif

    while (0U != txSize--)
    {
        /* Wait until data transfer complete. */
        while ((0U == (FLEXIO_GetShifterStatusFlags(base->flexioBase) & (1UL << base->shifterIndex[0])))
#if A_FORMAT_RETRY_TIMES
               && (0U != --waitTimes)
#endif
	       );
#if A_FORMAT_RETRY_TIMES
        if (0U == waitTimes)
        {
            return kStatus_FLEXIO_A_FORMAT_Timeout;
        }
#endif

        base->flexioBase->SHIFTBUF[base->shifterIndex[0]] = *txData;
        txData++;
    }
    return kStatus_Success;
}

/*!
 * brief Receives a buffer of bytes.
 *
 * note This function blocks using the polling method until all bytes have been received.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param rxData The buffer to store the received bytes.
 * param rxSize The number of data bytes to be received.
 * retval kStatus_FLEXIO_A_FORMAT_Timeout Transmission timed out and was aborted.
 * retval kStatus_Success Successfully received all data.
 */
status_t FLEXIO_A_Format_ReadBlocking(FLEXIO_A_FORMAT_Type *base, uint16_t *rxData, size_t rxSize)
{
    assert(rxData != NULL);
    assert(rxSize != 0U);
#if A_FORMAT_RETRY_TIMES
    uint32_t waitTimes = A_FORMAT_RETRY_TIMES;
#endif

    while (0U != rxSize--)
    {
        /* Wait until data transfer complete. */
        while ((0U == (FLEXIO_A_Format_GetStatusFlags(base) & (uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullFlag))
#if A_FORMAT_RETRY_TIMES
               && (0U != --waitTimes)
#endif
              );
#if A_FORMAT_RETRY_TIMES
        if (0U == waitTimes)
        {
            return kStatus_FLEXIO_A_FORMAT_Timeout;
        }
#endif

        *rxData = (uint16_t)(base->flexioBase->SHIFTBUFHWS[base->shifterIndex[1]]);
        rxData++;
    }

    return kStatus_Success;
}

/*!
 * brief Initializes the A-format handle.
 *
 * This function initializes the FlexIO A-format handle, which can be used for other FlexIO
 * A-format transactional APIs. Call this API once to get the initialized handle.
 *
 * The A-format driver supports the "background" receiving, which means that users can set up
 * a RX ring buffer optionally. Data received is stored into the ring buffer even when
 * the user doesn't call the FLEXIO_A_Format_TransferReceiveNonBlocking() API. If there is already
 * data received in the ring buffer, users can get the received data from the ring buffer
 * directly. The ring buffer is disabled if passing NULL as p ringBuffer.
 *
 * param base to FLEXIO_A_FORMAT_Type structure.
 * param handle Pointer to the flexio_a_format_handle_t structure to store the transfer state.
 * param callback The callback function.
 * param userData The parameter of the callback function.
 * retval kStatus_Success Successfully create the handle.
 * retval kStatus_OutOfRange The FlexIO type/handle/ISR table out of range.
 */
status_t FLEXIO_A_Format_TransferCreateHandle(FLEXIO_A_FORMAT_Type *base,
                                          flexio_a_format_handle_t *handle,
                                          flexio_a_format_transfer_callback_t callback,
                                          void *userData)
{
    assert(handle != NULL);

    IRQn_Type flexio_irqs[] = FLEXIO_IRQS;

    /* Zero the handle. */
    (void)memset(handle, 0, sizeof(*handle));

    /* Set the TX/RX state. */
    handle->rxState = (uint8_t)kFLEXIO_A_FORMAT_RxIdle;
    handle->txState = (uint8_t)kFLEXIO_A_FORMAT_TxIdle;

    /* Set the callback and user data. */
    handle->callback = callback;
    handle->userData = userData;

    base->hanlde = handle;

    /* Clear pending NVIC IRQ before enable NVIC IRQ. */
    NVIC_ClearPendingIRQ(flexio_irqs[FLEXIO_A_Format_GetInstance(base)]);
    /* Enable interrupt in NVIC. */
    (void)EnableIRQ(flexio_irqs[FLEXIO_A_Format_GetInstance(base)]);

    /* Save the context in global variables to support the double weak mechanism. */
    return FLEXIO_RegisterHandleIRQ(base, handle, FLEXIO_A_Format_TransferHandleIRQ);
}

/*!
 * brief Sets up the RX ring buffer.
 *
 * This function sets up the RX ring buffer to a specific A-format handle.
 *
 * When the RX ring buffer is used, data received is stored into the ring buffer even when
 * the user doesn't call the A_Format_ReceiveNonBlocking() API. If there is already data received
 * in the ring buffer, users can get the received data from the ring buffer directly.
 *
 * note When using the RX ring buffer, one byte is reserved for internal use. In other
 * words, if p ringBufferSize is 32, only 31 bytes are used for saving data.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param handle Pointer to the flexio_a_format_handle_t structure to store the transfer state.
 * param ringBuffer Start address of ring buffer for background receiving. Pass NULL to disable the ring buffer.
 * param ringBufferSize Size of the ring buffer.
 */
void FLEXIO_A_Format_TransferStartRingBuffer(FLEXIO_A_FORMAT_Type *base,
                                         flexio_a_format_handle_t *handle,
                                         uint16_t *ringBuffer,
                                         size_t ringBufferSize)
{
    assert(handle != NULL);

    /* Setup the ringbuffer address */
    if (ringBuffer != NULL)
    {
        handle->rxRingBuffer     = ringBuffer;
        handle->rxRingBufferSize = ringBufferSize;
        handle->rxRingBufferHead = 0U;
        handle->rxRingBufferTail = 0U;

        /* Enable the interrupt to accept the data when user need the ring buffer. */
        FLEXIO_A_Format_EnableInterrupts(base, (uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullInterruptEnable);
    }
}

/*!
 * brief Aborts the background transfer and uninstalls the ring buffer.
 *
 * This function aborts the background transfer and uninstalls the ring buffer.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param handle Pointer to the flexio_a_format_handle_t structure to store the transfer state.
 */
void FLEXIO_A_Format_TransferStopRingBuffer(FLEXIO_A_FORMAT_Type *base, flexio_a_format_handle_t *handle)
{
    assert(handle != NULL);

    if (handle->rxState == (uint8_t)kFLEXIO_A_FORMAT_RxIdle)
    {
        FLEXIO_A_Format_DisableInterrupts(base, (uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullInterruptEnable);
    }

    handle->rxRingBuffer     = NULL;
    handle->rxRingBufferSize = 0U;
    handle->rxRingBufferHead = 0U;
    handle->rxRingBufferTail = 0U;
}

/*!
 * brief Transmits a buffer of data using the interrupt method.
 *
 * This function sends data using an interrupt method. This is a non-blocking function,
 * which returns directly without waiting for all data to be written to the TX register. When
 * all data is written to the TX register in ISR, the FlexIO A-format driver calls the callback
 * function and passes the ref kStatus_FLEXIO_A_FORMAT_TxIdle as status parameter.
 *
 * note The kStatus_FLEXIO_A_FORMAT_TxIdle is passed to the upper layer when all data is written
 * to the TX register. However, it does not ensure that all data is sent out.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param handle Pointer to the flexio_a_format_handle_t structure to store the transfer state.
 * param xfer FlexIO A-format transfer structure. See #flexio_a_format_transfer_t.
 * retval kStatus_Success Successfully starts the data transmission.
 * retval kStatus_A_FORMAT_TxBusy Previous transmission still not finished, data not written to the TX register.
 */
status_t FLEXIO_A_Format_TransferSendNonBlocking(FLEXIO_A_FORMAT_Type *base,
                                             flexio_a_format_handle_t *handle,
                                             flexio_a_format_transfer_t *xfer)
{
    status_t status;

    /* Return error if xfer invalid. */
    if ((0U == xfer->dataSize) || (NULL == xfer->txData))
    {
        return kStatus_InvalidArgument;
    }

    /* Return error if current TX busy. */
    if ((uint8_t)kFLEXIO_A_FORMAT_TxBusy == handle->txState)
    {
        status = kStatus_FLEXIO_A_FORMAT_TxBusy;
    }
    else
    {
        handle->txData        = xfer->txData;
        handle->txDataSize    = xfer->dataSize;
        handle->txDataSizeAll = xfer->dataSize;
        handle->txState       = (uint8_t)kFLEXIO_A_FORMAT_TxBusy;

        /* Enable transmiter interrupt. */
        FLEXIO_A_Format_EnableInterrupts(base, (uint32_t)kFLEXIO_A_FORMAT_TxDataRegEmptyInterruptEnable);

        status = kStatus_Success;
    }

    return status;
}

/*!
 * brief Aborts the interrupt-driven data transmit.
 *
 * This function aborts the interrupt-driven data sending. Get the remainHalfwords to find out
 * how many half-words are still not sent out.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param handle Pointer to the flexio_a_format_handle_t structure to store the transfer state.
 */
void FLEXIO_A_Format_TransferAbortSend(FLEXIO_A_FORMAT_Type *base, flexio_a_format_handle_t *handle)
{
    /* Disable the transmitter and disable the interrupt. */
    FLEXIO_A_Format_DisableInterrupts(base, (uint32_t)kFLEXIO_A_FORMAT_TxDataRegEmptyInterruptEnable);

    handle->txDataSize = 0U;
    handle->txState    = (uint8_t)kFLEXIO_A_FORMAT_TxIdle;
}

/*!
 * brief Gets the number of half-words sent.
 *
 * This function gets the number of half-words sent driven by interrupt.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param handle Pointer to the flexio_a_format_handle_t structure to store the transfer state.
 * param count Number of half-words sent so far by the non-blocking transaction.
 * retval kStatus_NoTransferInProgress transfer has finished or no transfer in progress.
 * retval kStatus_Success Successfully return the count.
 */
status_t FLEXIO_A_Format_TransferGetSendCount(FLEXIO_A_FORMAT_Type *base, flexio_a_format_handle_t *handle, size_t *count)
{
    assert(handle != NULL);
    assert(count != NULL);

    if ((uint8_t)kFLEXIO_A_FORMAT_TxIdle == handle->txState)
    {
        return kStatus_NoTransferInProgress;
    }

    *count = handle->txDataSizeAll - handle->txDataSize;

    return kStatus_Success;
}

/*!
 * brief Receives a buffer of data using the interrupt method.
 *
 * This function receives data using the interrupt method. This is a non-blocking function,
 * which returns without waiting for all data to be received.
 * If the RX ring buffer is used and not empty, the data in ring buffer is copied and
 * the parameter p receivedHalfWords shows how many half-words are copied from the ring buffer.
 * After copying, if the data in ring buffer is not enough to read, the receive
 * request is saved by the A-format driver. When new data arrives, the receive request
 * is serviced first. When all data is received, the A-format driver notifies the upper layer
 * through a callback function and passes the status parameter ref kStatus_A_FORMAT_RxIdle.
 * For example, if the upper layer needs 10 half-words but there are only 5 half-words in the ring buffer,
 * the 5 half-words are copied to xfer->data. This function returns with the
 * parameter p receivedHalfWords set to 5. For the last 5 half-words, newly arrived data is
 * saved from the xfer->data[5]. When 5 half-words are received, the A-format driver notifies upper layer.
 * If the RX ring buffer is not enabled, this function enables the RX and RX interrupt
 * to receive data to xfer->data. When all data is received, the upper layer is notified.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param handle Pointer to the flexio_a_format_handle_t structure to store the transfer state.
 * param xfer A-format transfer structure. See #flexio_a_format_transfer_t.
 * param receivedHalfWords Half-words received from the ring buffer directly.
 * retval kStatus_Success Successfully queue the transfer into the transmit queue.
 * retval kStatus_FLEXIO_A_FORMAT_RxBusy Previous receive request is not finished.
 */
status_t FLEXIO_A_Format_TransferReceiveNonBlocking(FLEXIO_A_FORMAT_Type *base,
                                                flexio_a_format_handle_t *handle,
                                                flexio_a_format_transfer_t *xfer,
                                                size_t *receivedHalfWords)
{
    uint32_t i;
    status_t status;
    /* How many half-words to copy from ring buffer to user memory. */
    size_t halfwordsToCopy = 0U;
    /* How many half-words to receive. */
    size_t halfwordsToReceive;
    /* How many half-words currently have received. */
    size_t halfwordsCurrentReceived;

    /* Return error if xfer invalid. */
    if ((0U == xfer->dataSize) || (NULL == xfer->rxData))
    {
        return kStatus_InvalidArgument;
    }

    /* How to get data:
       1. If RX ring buffer is not enabled, then save xfer->data and xfer->dataSize
          to A-format handle, enable interrupt to store received data to xfer->data.
          When all data received, trigger callback.
       2. If RX ring buffer is enabled and not empty, get data from ring buffer first.
          If there are enough data in ring buffer, copy them to xfer->data and return.
          If there are not enough data in ring buffer, copy all of them to xfer->data,
          save the xfer->data remained empty space to A-format handle, receive data
          to this empty space and trigger callback when finished. */

    if ((uint8_t)kFLEXIO_A_FORMAT_RxBusy == handle->rxState)
    {
        status = kStatus_FLEXIO_A_FORMAT_RxBusy;
    }
    else
    {
        halfwordsToReceive       = xfer->dataSize;
        halfwordsCurrentReceived = 0U;

        /* If RX ring buffer is used. */
        if (handle->rxRingBuffer != NULL)
        {
            /* Disable FLEXIO_A_Format RX IRQ, protect ring buffer. */
            FLEXIO_A_Format_DisableInterrupts(base, (uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullInterruptEnable);

            /* How many bytes in RX ring buffer currently. */
            halfwordsToCopy = FLEXIO_A_Format_TransferGetRxRingBufferLength(handle);

            if (halfwordsToCopy != 0U)
            {
                halfwordsToCopy = MIN(halfwordsToReceive, halfwordsToCopy);

                halfwordsToReceive -= halfwordsToCopy;

                /* Copy data from ring buffer to user memory. */
                for (i = 0U; i < halfwordsToCopy; i++)
                {
                    xfer->rxData[halfwordsCurrentReceived++] = handle->rxRingBuffer[handle->rxRingBufferTail];

                    /* Wrap to 0. Not use modulo (%) because it might be large and slow. */
                    if ((uint32_t)handle->rxRingBufferTail + 1U == handle->rxRingBufferSize)
                    {
                        handle->rxRingBufferTail = 0U;
                    }
                    else
                    {
                        handle->rxRingBufferTail++;
                    }
                }
            }

            /* If ring buffer does not have enough data, still need to read more data. */
            if (halfwordsToReceive != 0U)
            {
                /* No data in ring buffer, save the request to A-format handle. */
                handle->rxData        = xfer->rxData + halfwordsCurrentReceived;
                handle->rxDataSize    = halfwordsToReceive;
                handle->rxDataSizeAll = xfer->dataSize;
                handle->rxState       = (uint8_t)kFLEXIO_A_FORMAT_RxBusy;
            }

            /* Enable FLEXIO_A_FORMAT RX IRQ if previously enabled. */
            FLEXIO_A_Format_EnableInterrupts(base, (uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullInterruptEnable);

            /* Call user callback since all data are received. */
            if (0U == halfwordsToReceive)
            {
                if (handle->callback != NULL)
                {
                    handle->callback(base, handle, kStatus_FLEXIO_A_FORMAT_RxIdle, handle->userData);
                }
            }
        }
        /* Ring buffer not used. */
        else
        {
            handle->rxData        = xfer->rxData + halfwordsCurrentReceived;
            handle->rxDataSize    = halfwordsToReceive;
            handle->rxDataSizeAll = halfwordsToReceive;
            handle->rxState       = (uint8_t)kFLEXIO_A_FORMAT_RxBusy;

            /* Enable RX interrupt. */
            FLEXIO_A_Format_EnableInterrupts(base, (uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullInterruptEnable);
        }

        /* Return the how many half-words have read. */
        if (receivedHalfWords != NULL)
        {
            *receivedHalfWords = halfwordsCurrentReceived;
        }

        status = kStatus_Success;
    }

    return status;
}

/*!
 * brief Aborts the receive data which was using IRQ.
 *
 * This function aborts the receive data which was using IRQ.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param handle Pointer to the flexio_a_format_handle_t structure to store the transfer state.
 */
void FLEXIO_A_Format_TransferAbortReceive(FLEXIO_A_FORMAT_Type *base, flexio_a_format_handle_t *handle)
{
    /* Only abort the receive to handle->rxData, the RX ring buffer is still working. */
    if (NULL == handle->rxRingBuffer)
    {
        /* Disable RX interrupt. */
        FLEXIO_A_Format_DisableInterrupts(base, (uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullInterruptEnable);
    }

    handle->rxDataSize = 0U;
    handle->rxState    = (uint8_t)kFLEXIO_A_FORMAT_RxIdle;
}

/*!
 * brief Gets the number of half-words received.
 *
 * This function gets the number of half-words received driven by interrupt.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param handle Pointer to the flexio_a_format_handle_t structure to store the transfer state.
 * param count Number of half-words received so far by the non-blocking transaction.
 * retval kStatus_NoTransferInProgress transfer has finished or no transfer in progress.
 * retval kStatus_Success Successfully return the count.
 */
status_t FLEXIO_A_Format_TransferGetReceiveCount(FLEXIO_A_FORMAT_Type *base, flexio_a_format_handle_t *handle, size_t *count)
{
    assert(handle != NULL);
    assert(count != NULL);

    if ((uint8_t)kFLEXIO_A_FORMAT_RxIdle == handle->rxState)
    {
        return kStatus_NoTransferInProgress;
    }

    *count = handle->rxDataSizeAll - handle->rxDataSize;

    return kStatus_Success;
}

status_t A_Format_CMD_Parse(void)
{
    switch (cmd)
    {
    case A_FORMAT_REQ_IT_ABS_FULL_40BIT:
    case A_FORMAT_REQ_MT_ABS_FULL_40BIT:
        return A_Format_ABS_Readout_Multi_Single_Parse(enc_g, res3, abs_data_g);

    case A_FORMAT_REQ_IT_ABS_LOWER_24BIT:
    case A_FORMAT_REQ_MT_ABS_LOWER_24BIT:
        return A_Format_ABS_Readout_Single_Parse(enc_g, res2, single_data_g);

    case A_FORMAT_REQ_IT_ABS_UPPER_24BIT:
    case A_FORMAT_REQ_MT_ABS_UPPER_24BIT:
        return A_Format_ABS_Readout_Multi_Parse(enc_g, res2, multiData_g);
    
    case A_FORMAT_REQ_IT_ENCODER_STAT:
    case A_FORMAT_REQ_MT_ENCODER_STAT:
        return A_Format_Readout_Encoder_status_Parse(enc_g, res2, statusData_g);

    case A_FORMAT_REQ_IT_TEMPERATURE_10BIT:
	return A_Format_Get_Temperature_Parse(enc_g, res2, temp_g);

    case A_FORMAT_REQ_IT_ID_CODE_READ1:
        return A_Format_Get_ID_Parse(enc_g, res2, id_g);

    default:
        return kStatus_Fail;
    }
}

/*!
 * brief FlexIO A-format IRQ handler function.
 *
 * This function processes the FlexIO A-format transmit and receives the IRQ request.
 *
 * param uartType Pointer to the FLEXIO_A_FORMAT_Type structure.
 * param uartHandle Pointer to the flexio_a_format_handle_t structure to store the transfer state.
 */
void FLEXIO_A_Format_TransferHandleIRQ(void *uartType, void *uartHandle)
{
    uint8_t count                    = 1;
    FLEXIO_A_FORMAT_Type *base       = (FLEXIO_A_FORMAT_Type *)uartType;
    flexio_a_format_handle_t *handle = (flexio_a_format_handle_t *)uartHandle;
    uint16_t rxRingBufferHead;

    /* Read the status back. */
    uint32_t status     = FLEXIO_A_Format_GetStatusFlags(base);
    status_t cmd_status = kStatus_Success;

    /* If RX overrun. */
    if (((uint32_t)kFLEXIO_A_FORMAT_RxOverRunFlag & status) != 0U)
    {
        /* Clear Overrun flag. */
        FLEXIO_A_Format_ClearStatusFlags(base, (uint32_t)kFLEXIO_A_FORMAT_RxOverRunFlag);

        /* Trigger callback. */
        if (handle->callback != NULL)
        {
            handle->callback(base, handle, kStatus_FLEXIO_A_FORMAT_RxHardwareOverrun, handle->userData);
        }
    }

    /* Receive data register full */
    if ((((uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullFlag & status) != 0U) &&
        ((base->flexioBase->SHIFTSIEN & (1UL << base->shifterIndex[1])) != 0U))
    {
        /* If handle->rxDataSize is not 0, first save data to handle->rxData. */
        if (handle->rxDataSize != 0U)
        {
            /* Using non block API to read the data from the registers. */
            FLEXIO_A_Format_ReadHalfWord(base, handle->rxData);
            handle->rxDataSize--;
            handle->rxData++;
            count--;

            /* If all the data required for upper layer is ready, trigger callback. */
            if (0U == handle->rxDataSize)
            {
                handle->rxState = (uint8_t)kFLEXIO_A_FORMAT_RxIdle;
                cmd_status = A_Format_CMD_Parse();

                if (handle->callback != NULL)
                {
                    if (cmd_status != kStatus_Success)
                    {
                        cmd = 0xFF;
                    //    handle->userData = (void *)cmd;
                    }
                    //else
                    //{
                    //    handle->userData = (void *)0xFF;
                    //}

                    handle->userData = (void *)&cmd;
                    handle->callback(base, handle, kStatus_FLEXIO_A_FORMAT_RxIdle, handle->userData);
                }
            }
        }

        if (handle->rxRingBuffer != NULL)
        {
            if (count != 0U)
            {
                /* If RX ring buffer is full, trigger callback to notify over run. */
                if (FLEXIO_A_Format_TransferIsRxRingBufferFull(handle))
                {
                    if (handle->callback != NULL)
                    {
                        handle->callback(base, handle, kStatus_FLEXIO_A_FORMAT_RxRingBufferOverrun, handle->userData);
                    }
                }

                /* If ring buffer is still full after callback function, the oldest data is overridden. */
                if (FLEXIO_A_Format_TransferIsRxRingBufferFull(handle))
                {
                    /* Increase handle->rxRingBufferTail to make room for new data. */
                    if ((uint32_t)handle->rxRingBufferTail + 1U == handle->rxRingBufferSize)
                    {
                        handle->rxRingBufferTail = 0U;
                    }
                    else
                    {
                        handle->rxRingBufferTail++;
                    }
                }

                /* Read data. */
                rxRingBufferHead = handle->rxRingBufferHead;
                handle->rxRingBuffer[rxRingBufferHead] =
                    (uint16_t)(base->flexioBase->SHIFTBUFHWS[base->shifterIndex[1]]);

                /* Increase handle->rxRingBufferHead. */
                if ((uint32_t)handle->rxRingBufferHead + 1U == handle->rxRingBufferSize)
                {
                    handle->rxRingBufferHead = 0U;
                }
                else
                {
                    handle->rxRingBufferHead++;
                }
            }
        }
        /* If no receive requst pending, stop RX interrupt. */
        else if (0U == handle->rxDataSize)
        {
            FLEXIO_A_Format_DisableInterrupts(base, (uint32_t)kFLEXIO_A_FORMAT_RxDataRegFullInterruptEnable);
        }
        else
        {
        }
    }

    /* Send data register empty and the interrupt is enabled. */
    if ((((uint32_t)kFLEXIO_A_FORMAT_TxDataRegEmptyFlag & status) != 0U) &&
        ((base->flexioBase->SHIFTSIEN & (1UL << base->shifterIndex[0])) != 0U))
    {
        if (handle->txDataSize != 0U)
        {
            /* Using non block API to write the data to the registers. */
            FLEXIO_A_Format_WriteHalfWord(base, handle->txData);
            handle->txData++;
            handle->txDataSize--;

            /* If all the data are written to data register, TX finished. */
            if (0U == handle->txDataSize)
            {
                handle->txState = (uint8_t)kFLEXIO_A_FORMAT_TxIdle;

                /* Disable TX register empty interrupt. */
                FLEXIO_A_Format_DisableInterrupts(base, (uint32_t)kFLEXIO_A_FORMAT_TxDataRegEmptyInterruptEnable);

                /* Trigger callback. */
                if (handle->callback != NULL)
                {
                    handle->callback(base, handle, kStatus_FLEXIO_A_FORMAT_TxIdle, handle->userData);
                }
            }
        }
    }
}

/*!
 * brief Flush tx/rx shifters.
 *
 * param base Pointer to the FLEXIO_A_FORMAT_Type structure.
 */
void FLEXIO_A_Format_FlushShifters(FLEXIO_A_FORMAT_Type *base)
{
    /* Disable then re-enable to flush the tx shifter. */
    base->flexioBase->SHIFTCTL[base->shifterIndex[0]] &= ~FLEXIO_SHIFTCTL_SMOD_MASK;
    base->flexioBase->SHIFTCTL[base->shifterIndex[0]] |= FLEXIO_SHIFTCTL_SMOD(kFLEXIO_ShifterModeTransmit);
    /* Read to flush the rx shifter. */
    (void)base->flexioBase->SHIFTBUF[base->shifterIndex[1]];
}

/*!
 * brief Receives data using eDMA.
 *
 * This function receives data using eDMA. This is a non-blocking function, which returns
 * right away. When all data is received, the receive callback function is called.
 *
 * param base Pointer to FLEXIO_A_FORMAT_Type
 * param rxData Pointer to receive buffer
 * param dataSize Pointer to the size of receive buffer
 * retval kStatus_Success if succeed, others failed.
 */
status_t FLEXIO_A_Format_TransferReceiveEDMA(FLEXIO_A_FORMAT_Type *base,
                                             void *rxData, size_t dataSize)
{
    edma_handle_t *rxEdmaHandle = &base->rxEdmaHandle;
    edma_transfer_config_t xferConfig;

    /* Return error if data invalid. */
    if ((0U == dataSize) || (NULL == rxData))
    {
        return kStatus_InvalidArgument;
    }

    /* Prepare transfer. */
    EDMA_PrepareTransfer(&xferConfig, (uint32_t *)FLEXIO_A_Format_GetRxDataRegisterAddress(base), sizeof(uint16_t),
                         rxData, sizeof(uint16_t), sizeof(uint16_t), dataSize, kEDMA_PeripheralToMemory);

    /* Submit transfer. */
    (void)EDMA_SubmitTransfer(rxEdmaHandle, &xferConfig);
    EDMA_StartTransfer(rxEdmaHandle);

    /* Enable A-Format RX EDMA. */
    FLEXIO_A_Format_EnableRxDMA(base, true);

    return kStatus_Success;
}

/*!
 * brief Checks receive eDMA status.
 *
 * This function check whether the receive eDMA is completed. This is a non-blocking function, which returns
 * right away.
 *
 * param base Pointer to FLEXIO_A_FORMAT_Type
 * retval kStatus_Success if succeed, others failed.
 */
status_t FLEXIO_A_Format_ReceiveEDMA_isCompleted(FLEXIO_A_FORMAT_Type *base)
{
    edma_handle_t *rxEdmaHandle = &base->rxEdmaHandle;

    if (rxEdmaHandle->channelBase->CH_CSR & DMA_CH_CSR_DONE_MASK)
    {
        rxEdmaHandle->channelBase->CH_CSR |= DMA_CH_CSR_DONE_MASK;
        return kStatus_Success;
    }

    return kStatus_NoTransferInProgress;
}

/*******************************************************************************
 * A-format function APIs
 ******************************************************************************/
static uint8_t Swap_Byte(uint8_t data)
{
    data = (data << 4) | (data >> 4);
    data = ((data << 2) & 0xCC) | ((data >> 2) & 0x33);
    data = ((data << 1) & 0xAA) | ((data >> 1) & 0x55);
    return data;
}

static uint8_t CRC_Calc(CRC_Para_t *crc)
{
    uint8_t remainder = 0;
    uint8_t i = 0, j = 0;
    uint8_t poly = crc->polynomial << (8 - crc->type);

    for (j = 0; j < crc->message_len; j++) {
        remainder ^= (crc->inputBitSwap ? Swap_Byte(crc->message[j]) : crc->message[j]);

        for (i = 0; i < 8; i++) {
            if (remainder & 0x80)
                remainder = (remainder << 1) ^ poly;
            else
                remainder <<= 1;
        }
    }

    return crc->outputBitSwap ? Swap_Byte(remainder) : (remainder >> (8 - crc->type));
}

status_t FLEXIO_A_Format_SendSyncReq(FLEXIO_A_FORMAT_Type *base, uint8_t enc_addr, uint8_t cmd)
{
    switch (cmd)
    {
        case A_FORMAT_REQ_IT_MEMORY_READ:
        case A_FORMAT_REQ_IT_MEMORY_WRITE:
        case A_FORMAT_REQ_IT_ID_CODE_WRITE1:
        case A_FORMAT_REQ_IT_ID_CODE_WRITE2:
            return kStatus_FLEXIO_A_FORMAT_NotSyncCMD;
        default:
            break;
    }

    if (ENCODER_ADDRESS(enc_addr) >= A_FORMAT_ENCODER_MAX_NUM)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    cdf = A_FORMAT_PACK_CDF(ENCODER_ADDRESS(enc_addr), cmd, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    FLEXIO_A_Format_Config_DR_length(base, 1);
    base->flexioBase->SHIFTBUF[base->shifterIndex[0]] = cdf;
    return kStatus_Success;
}

void A_Format_PrintfES(logFunc logES, uint8_t es)
{
    if (es == A_Format_ES_NoErr)
    {
        logES("No error in the ES field\r\n");
    }
    else
    {
        for (uint8_t i = 0; i < 6; i++)
        {
            switch (es & (0x1 << i))
            {
            case A_Format_ES_Busy_MemBusy:
                logES("Encoder or memory is busy!\r\n");
                break;
            case A_Format_ES_Batt:
                logES("The battery is error!\r\n");
                break;
            case A_Format_ES_OvSpd_MemErr_OvTemp_OvFlow:
                logES("Over speed or memory error or emperature warning or Over Flow!\r\n");
                break;
            case A_Format_ES_STErr_PSErr_MTErr_INCErr:
                logES("ST error or PS error or MT error or incremental signal Error\r\n");
                break;
            case A_Format_ES_FrameErr:
                logES("Encoder frame is error!\r\n");
                break;
            case A_Format_ES_Anyone:
                logES("One or more of all errors!\r\n");
                break;
            default:
                break;
            }
        }
    }
}

status_t A_Format_ABS_Readout_Multi_Single_Parse(encoder_A_format *enc, encoder_res3_t *res,
                                                 encoder_abs_multi_single_t *abs_data)
{
    cmdErr = 0;

    crc8_para.message_len = 8;
    for (uint8_t i = 0; i < nEncoder; i++)
    {
        crc8_para.message = (uint8_t const *)&res[i];
        if ((A_FORMAT_GET_CMD_CODE_IF(res[i].IF) != cmd) || (CRC_Calc(&crc8_para) != 0))
        {
            cmdErr++;
            abs_data[i].es = A_Format_ES_FrameErr;
            continue;
        }

        abs_data[i].encID = A_FORMAT_GET_ENC_ADDR_IF(res[i].IF);
        abs_data[i].es    = A_FORMAT_GET_ENC_STAT_IF(res[i].IF);
        if (abs_data[i].es != A_Format_ES_NoErr)
        {
            cmdErr++;
        }

        abs_data[i].singleTurn = *(uint32_t *)res[i].DF & enc->single_turn_sign_mask;
        abs_data[i].multiTurn  = (uint16_t)((*(uint32_t *)&(res[i].DF[1]) >> (enc->singleTurnRevolution - 16)) & enc->multi_turn_sign_mask);
    }

    return cmdErr ? kStatus_Fail : kStatus_Success;
}

status_t A_Format_ABS_Readout_Multi_Single_CMD(uint8_t enc_addr)
{
    if (ENCODER_ADDRESS(enc_addr) >= A_FORMAT_ENCODER_MAX_NUM)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    is_MultiTrans = ENCODER_ADDRESS_IS_MT(enc_addr);
    enc_addr &= 0x7;

    cmd = is_MultiTrans ? A_FORMAT_REQ_MT_ABS_FULL_40BIT : A_FORMAT_REQ_IT_ABS_FULL_40BIT;
    cdf = A_FORMAT_PACK_CDF(enc_addr, cmd, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    nEncoder = is_MultiTrans ? (enc_addr + 1) : 1;
    memset(res3, 0, sizeof(encoder_res3_t) * nEncoder);

    return kStatus_Success;
}

status_t A_Format_ABS_Readout_Multi_Single(encoder_A_format *enc, uint8_t enc_addr,
                                           encoder_abs_multi_single_t *abs_data)
{
    if (A_Format_ABS_Readout_Multi_Single_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)res3,
                                 HALFWORD_NUM(encoder_res3_t) * nEncoder);

    return A_Format_ABS_Readout_Multi_Single_Parse(enc, res3, abs_data);
}

status_t A_Format_ABS_Readout_Multi_Single_IRQ(encoder_A_format *enc, uint8_t enc_addr,
                                               encoder_abs_multi_single_t *abs_data)
{
    if (A_Format_ABS_Readout_Multi_Single_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    flexio_a_format_transfer_t xfer = {
        .rxData   = (uint16_t *)res3,
        .dataSize = HALFWORD_NUM(encoder_res3_t) * nEncoder
    };

    enc_g      = enc;
    abs_data_g = abs_data;
    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_TransferReceiveNonBlocking(enc->controller, ((FLEXIO_A_FORMAT_Type *)enc->controller)->hanlde,
                                               &xfer, NULL);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);

    return kStatus_Success;
}

status_t A_Format_ABS_Readout_Single_CMD(uint8_t enc_addr)
{
    if (ENCODER_ADDRESS(enc_addr) >= A_FORMAT_ENCODER_MAX_NUM)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    is_MultiTrans = ENCODER_ADDRESS_IS_MT(enc_addr);
    enc_addr &= 0x7;

    cmd = is_MultiTrans ? A_FORMAT_REQ_MT_ABS_LOWER_24BIT : A_FORMAT_REQ_IT_ABS_LOWER_24BIT;
    cdf = A_FORMAT_PACK_CDF(enc_addr, cmd, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    nEncoder = is_MultiTrans ? (enc_addr + 1) : 1;
    memset(res2, 0, sizeof(encoder_res2_t) * nEncoder);

    return kStatus_Success;
}

status_t A_Format_ABS_Readout_Single_Parse(encoder_A_format *enc, encoder_res2_t *res,
                                           encoder_abs_single_t *single_data)
{
    cmdErr = 0;

    crc8_para.message_len = 6;
    for (uint8_t i = 0; i < nEncoder; i++)
    {
        crc8_para.message = (uint8_t const *)&res[i];
        if ((A_FORMAT_GET_CMD_CODE_IF(res[i].IF) != cmd) || (CRC_Calc(&crc8_para) != 0))
        {
            cmdErr++;
            single_data[i].es = A_Format_ES_FrameErr;
            continue;
        }

        single_data[i].encID = A_FORMAT_GET_ENC_ADDR_IF(res[i].IF);
        single_data[i].es    = A_FORMAT_GET_ENC_STAT_IF(res[i].IF);
        if (single_data[i].es != A_Format_ES_NoErr)
        {
            cmdErr++;
        }

        single_data[i].singleTurn = *(uint32_t *)res[i].DF & enc->single_turn_sign_mask;
    }

    return cmdErr ? kStatus_Fail : kStatus_Success;
}

status_t A_Format_ABS_Readout_Single(encoder_A_format *enc, uint8_t enc_addr, encoder_abs_single_t *singleData)
{
    if (A_Format_ABS_Readout_Single_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)res2,
                                 HALFWORD_NUM(encoder_res2_t) * nEncoder);

    return A_Format_ABS_Readout_Single_Parse(enc, res2, singleData);
}

status_t A_Format_ABS_Readout_Single_IRQ(encoder_A_format *enc, uint8_t enc_addr,
                                         encoder_abs_single_t *single_data)
{
    if (A_Format_ABS_Readout_Single_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    flexio_a_format_transfer_t xfer = {
        .rxData   = (uint16_t *)res2,
        .dataSize = HALFWORD_NUM(encoder_res2_t) * nEncoder
    };

    enc_g         = enc;
    single_data_g = single_data;
    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_TransferReceiveNonBlocking(enc->controller, ((FLEXIO_A_FORMAT_Type *)enc->controller)->hanlde,
                                               &xfer, NULL);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);

    return kStatus_Success;
}

status_t A_Format_ABS_Readout_Multi_CMD(uint8_t enc_addr)
{
    if (ENCODER_ADDRESS(enc_addr) >= A_FORMAT_ENCODER_MAX_NUM)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    is_MultiTrans = ENCODER_ADDRESS_IS_MT(enc_addr);
    enc_addr &= 0x7;

    cmd = is_MultiTrans ? A_FORMAT_REQ_MT_ABS_UPPER_24BIT : A_FORMAT_REQ_IT_ABS_UPPER_24BIT;
    cdf = A_FORMAT_PACK_CDF(enc_addr, cmd, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    nEncoder = is_MultiTrans ? (enc_addr + 1) : 1;
    memset(res2, 0, sizeof(encoder_res2_t) * nEncoder);

    return kStatus_Success;
}

status_t A_Format_ABS_Readout_Multi_Parse(encoder_A_format *enc, encoder_res2_t *res,
                                          encoder_abs_multi_t *multiData)
{
    cmdErr = 0;

    crc8_para.message_len = 6;
    for (uint8_t i = 0; i < nEncoder; i++)
    {
        crc8_para.message = (uint8_t const *)&res[i];
        if ((A_FORMAT_GET_CMD_CODE_IF(res[i].IF) != cmd) || (CRC_Calc(&crc8_para) != 0))
        {
            cmdErr++;
            multiData[i].es = A_Format_ES_FrameErr;
            continue;
        }

        multiData[i].encID = A_FORMAT_GET_ENC_ADDR_IF(res[i].IF);
        multiData[i].es    = A_FORMAT_GET_ENC_STAT_IF(res[i].IF);
        if (multiData[i].es != A_Format_ES_NoErr)
        {
            cmdErr++;
        }

        multiData[i].multiTurn = (uint16_t)((*(uint32_t *)res[i].DF >> (enc->singleTurnRevolution - 16)) & enc->multi_turn_sign_mask);
    }

    return cmdErr ? kStatus_Fail : kStatus_Success;
}

status_t A_Format_ABS_Readout_Multi(encoder_A_format *enc, uint8_t enc_addr, encoder_abs_multi_t *multiData)
{
    if (A_Format_ABS_Readout_Multi_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)res2,
                                 HALFWORD_NUM(encoder_res2_t) * nEncoder);

    return A_Format_ABS_Readout_Multi_Parse(enc, res2, multiData);
}

status_t A_Format_ABS_Readout_Multi_IRQ(encoder_A_format *enc, uint8_t enc_addr,
                                        encoder_abs_multi_t *multiData)
{
    if (A_Format_ABS_Readout_Multi_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    flexio_a_format_transfer_t xfer = {
        .rxData   = (uint16_t *)res2,
        .dataSize = HALFWORD_NUM(encoder_res2_t) * nEncoder
    };

    enc_g       = enc;
    multiData_g = multiData;
    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_TransferReceiveNonBlocking(enc->controller, ((FLEXIO_A_FORMAT_Type *)enc->controller)->hanlde,
                                               &xfer, NULL);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);

    return kStatus_Success;
}

status_t A_Format_Readout_Encoder_status_CMD(uint8_t enc_addr)
{
    if (ENCODER_ADDRESS(enc_addr) >= A_FORMAT_ENCODER_MAX_NUM)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    is_MultiTrans = ENCODER_ADDRESS_IS_MT(enc_addr);
    enc_addr &= 0x7;

    cmd = is_MultiTrans ? A_FORMAT_REQ_MT_ENCODER_STAT : A_FORMAT_REQ_IT_ENCODER_STAT;
    cdf = A_FORMAT_PACK_CDF(enc_addr, cmd, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    nEncoder = is_MultiTrans ? (enc_addr + 1) : 1;
    memset(res2, 0, sizeof(encoder_res2_t) * nEncoder);

    return kStatus_Success;
}

status_t A_Format_Readout_Encoder_status_Parse(encoder_A_format *enc, encoder_res2_t *res,
                                               encoder_status_t *statusData)
{
    cmdErr = 0;

    crc8_para.message_len = 6;
    for (uint8_t i = 0; i < nEncoder; i++)
    {
        crc8_para.message = (uint8_t const *)&res[i];
        if ((A_FORMAT_GET_CMD_CODE_IF(res[i].IF) != cmd) || (CRC_Calc(&crc8_para) != 0))
        {
            cmdErr++;
            statusData[i].es = A_Format_ES_FrameErr;
            continue;
        }

        statusData[i].encID = A_FORMAT_GET_ENC_ADDR_IF(res[i].IF);
        statusData[i].es    = A_FORMAT_GET_ENC_STAT_IF(res[i].IF);
        if (statusData[i].es != A_Format_ES_NoErr)
        {
            cmdErr++;
        }

        statusData[i].status = res[i].DF[0];
    }

    return cmdErr ? kStatus_Fail : kStatus_Success;
}

status_t A_Format_Readout_Encoder_status(encoder_A_format *enc, uint8_t enc_addr,
                                         encoder_status_t *statusData)
{
    if (A_Format_Readout_Encoder_status_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)res2,
                                 HALFWORD_NUM(encoder_res2_t) * nEncoder);

    return A_Format_Readout_Encoder_status_Parse(enc, res2, statusData);
}

status_t A_Format_Readout_Encoder_status_IRQ(encoder_A_format *enc, uint8_t enc_addr,
                                             encoder_status_t *statusData)
{
    if (A_Format_Readout_Encoder_status_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    flexio_a_format_transfer_t xfer = {
        .rxData   = (uint16_t *)res2,
        .dataSize = HALFWORD_NUM(encoder_res2_t) * nEncoder
    };

    enc_g        = enc;
    statusData_g = statusData;
    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_TransferReceiveNonBlocking(enc->controller, ((FLEXIO_A_FORMAT_Type *)enc->controller)->hanlde,
                                               &xfer, NULL);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);

    return kStatus_Success;
}

status_t A_Format_Clear_Request(encoder_A_format *enc, uint8_t enc_addr, Clear_Type_e clear)
{
    status_t status = kStatus_Success;
    encoder_res2_t res;

    cmd = clear;
    cdf = A_FORMAT_PACK_CDF((enc_addr & 0x7), cmd, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);

    crc8_para.message_len = 6;
    crc8_para.message     = (uint8_t const *)&res;

    for (uint8_t i = 0; i < 8; i++)
    {
        FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
        FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)&res, HALFWORD_NUM(encoder_res2_t));

        if ((A_FORMAT_GET_CMD_CODE_IF(res.IF) != cmd) || (CRC_Calc(&crc8_para) != 0))
        {
            return kStatus_FLEXIO_A_FORMAT_FrameErr;
        }
    }
    return status;
}

status_t A_Format_Set_Encoder_Address_1to1(encoder_A_format *enc, uint8_t enc_addr)
{
    status_t status = kStatus_Success;
    encoder_res2_t res;

    cmd = A_FORMAT_REQ_IT_SET_ENCODER_ADDR1;
    cdf = A_FORMAT_PACK_CDF((enc_addr & 0x7), A_FORMAT_REQ_IT_SET_ENCODER_ADDR1, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);

    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);

    crc8_para.message_len = 6;
    crc8_para.message     = (uint8_t const *)&res;

    for (uint8_t i = 0; i < 8; i++)
    {
        FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
        FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)&res, HALFWORD_NUM(encoder_res2_t));

        if ((A_FORMAT_GET_CMD_CODE_IF(res.IF) != cmd) || (CRC_Calc(&crc8_para) != 0))
        {
            return kStatus_FLEXIO_A_FORMAT_FrameErr;
        }
    }
    return status;
}

status_t A_Format_Memory_Read(encoder_A_format *enc, uint8_t enc_addr, encoder_eeprom_t *eeprom)
{
    encoder_res2_t res;
    uint16_t mdf = A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF2, eeprom->address, 0);

    cmd = A_FORMAT_REQ_IT_MEMORY_READ;
    cdf = A_FORMAT_PACK_CDF((enc_addr & 0x7), A_FORMAT_REQ_IT_MEMORY_READ, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    crc_data = A_FORMAT_GET_CRC_DATA_MDF(mdf);
    crc = CRC_Calc(&crc3_para);
    mdf = A_FORMAT_SET_CRC_CODE_MDF(mdf, crc);

    FLEXIO_A_Format_Config_DR_length(enc->controller, 2);

    crc8_para.message_len = 6;
    crc8_para.message     = (uint8_t const *)&res;

    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);//10us(17)
    FLEXIO_A_Format_WriteBlocking(enc->controller, &mdf, 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)&res, HALFWORD_NUM(encoder_res2_t));

    if ((A_FORMAT_GET_CMD_CODE_IF(res.IF) != cmd) || (CRC_Calc(&crc8_para) != 0) ||
        ((res.DF[1] & 0x00FF) != eeprom->address))
    {
        return kStatus_FLEXIO_A_FORMAT_FrameErr;
    }

    eeprom->data = res.DF[0];
    return kStatus_Success;
}

status_t A_Format_Memory_Write(encoder_A_format *enc, uint8_t enc_addr, encoder_eeprom_t *eeprom)
{
    encoder_res2_t res;
    uint16_t mdf[3] = {
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF0, eeprom->data & 0x00FF, 0),
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF1, (eeprom->data & 0xFF00) >> 8, 0),
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF2, eeprom->address, 0)
    };

    cmd = A_FORMAT_REQ_IT_MEMORY_WRITE;
    cdf = A_FORMAT_PACK_CDF((enc_addr & 0x7), A_FORMAT_REQ_IT_MEMORY_WRITE, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    for (uint8_t i = 0; i < 3; i++)
    {
        crc_data = A_FORMAT_GET_CRC_DATA_MDF(mdf[i]);
        crc = CRC_Calc(&crc3_para);
        mdf[i] = A_FORMAT_SET_CRC_CODE_MDF(mdf[i], crc);
    }

    FLEXIO_A_Format_Config_DR_length(enc->controller, 4);

    crc8_para.message_len = 6;
    crc8_para.message     = (uint8_t const *)&res;

    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);//10us(17)
    FLEXIO_A_Format_WriteBlocking(enc->controller, mdf, 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &mdf[1], 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &mdf[2], 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)&res, HALFWORD_NUM(encoder_res2_t));

    if ((A_FORMAT_GET_CMD_CODE_IF(res.IF) != cmd) || (CRC_Calc(&crc8_para) != 0) ||
        (res.DF[0] != eeprom->data) || ((res.DF[1] & 0x00FF) != eeprom->address))
    {
        return kStatus_FLEXIO_A_FORMAT_FrameErr;
    }

    return kStatus_Success;
}

status_t A_Format_Get_Temperature_CMD(uint8_t enc_addr)
{
    if (ENCODER_ADDRESS(enc_addr) >= A_FORMAT_ENCODER_MAX_NUM)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    nEncoder = 1;
    enc_addr &= 0x7;
    cmd = A_FORMAT_REQ_IT_TEMPERATURE_10BIT;
    cdf = A_FORMAT_PACK_CDF(enc_addr, A_FORMAT_REQ_IT_TEMPERATURE_10BIT, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    memset(res2, 0, sizeof(encoder_res2_t));

    return kStatus_Success;
}

status_t A_Format_Get_Temperature_Parse(encoder_A_format *enc, encoder_res2_t *res, float *temp)
{
    crc8_para.message_len = 6;
    crc8_para.message     = (uint8_t const *)res;
    if ((A_FORMAT_GET_CMD_CODE_IF(res->IF) != cmd) || (CRC_Calc(&crc8_para) != 0))
    {
        return kStatus_FLEXIO_A_FORMAT_FrameErr;
    }

    *temp = GET_TEMPERATURE_VALUE(res->DF[0]);
    return kStatus_Success;
}

status_t A_Format_Get_Temperature(encoder_A_format *enc, uint8_t enc_addr, float *temp)
{
    if (A_Format_Get_Temperature_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }
    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);

    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)res2, HALFWORD_NUM(encoder_res2_t));

    return A_Format_Get_Temperature_Parse(enc, res2, temp);
}

status_t A_Format_Get_Temperature_IRQ(encoder_A_format *enc, uint8_t enc_addr, float *temp)
{
    if (A_Format_Get_Temperature_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    flexio_a_format_transfer_t xfer = {
        .rxData   = (uint16_t *)res2,
        .dataSize = HALFWORD_NUM(encoder_res2_t)
    };

    enc_g  = enc;
    temp_g = temp;
    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_TransferReceiveNonBlocking(enc->controller, ((FLEXIO_A_FORMAT_Type *)enc->controller)->hanlde,
                                               &xfer, NULL);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);

    return kStatus_Success;
}

status_t A_Format_Get_ID_CMD(uint8_t enc_addr)
{
    if (ENCODER_ADDRESS(enc_addr) >= A_FORMAT_ENCODER_MAX_NUM)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    nEncoder = 1;
    enc_addr &= 0x7;
    cmd = A_FORMAT_REQ_IT_ID_CODE_READ1;
    cdf = A_FORMAT_PACK_CDF(enc_addr, A_FORMAT_REQ_IT_ID_CODE_READ1, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    memset(res2, 0, sizeof(encoder_res2_t));

    return kStatus_Success;
}

status_t A_Format_Get_ID_Parse(encoder_A_format *enc, encoder_res2_t *res, uint32_t *id)
{
    crc8_para.message_len = 6;
    crc8_para.message     = (uint8_t const *)res;
    if ((A_FORMAT_GET_CMD_CODE_IF(res->IF) != cmd) || (CRC_Calc(&crc8_para) != 0))
    {
        return kStatus_FLEXIO_A_FORMAT_FrameErr;
    }

    *id = GET_ENCODER_ID(*(uint32_t *)res->DF);
    return kStatus_Success;
}

status_t A_Format_Get_ID(encoder_A_format *enc, uint8_t enc_addr, uint32_t *id)
{
    if (A_Format_Get_ID_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);

    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)res2, HALFWORD_NUM(encoder_res2_t));

    return A_Format_Get_ID_Parse(enc, res2, id);
}

status_t A_Format_Get_ID_IRQ(encoder_A_format *enc, uint8_t enc_addr, uint32_t *id)
{
    if (A_Format_Get_ID_CMD(enc_addr) == kStatus_FLEXIO_A_FORMAT_OutOfIDRange)
    {
        return kStatus_FLEXIO_A_FORMAT_OutOfIDRange;
    }

    flexio_a_format_transfer_t xfer = {
        .rxData   = (uint16_t *)res2,
        .dataSize = HALFWORD_NUM(encoder_res2_t)
    };

    enc_g = enc;
    id_g  = id;
    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_TransferReceiveNonBlocking(enc->controller, ((FLEXIO_A_FORMAT_Type *)enc->controller)->hanlde,
                                               &xfer, NULL);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);

    return kStatus_Success;
}

status_t A_Format_Get_ID_1to1(encoder_A_format *enc, uint32_t *id)
{
    encoder_res2_t res;

    cmd = A_FORMAT_REQ_IT_ID_CODE_READ2;
    cdf = A_FORMAT_PACK_CDF(0, A_FORMAT_REQ_IT_ID_CODE_READ2, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);

    crc8_para.message_len = 6;
    crc8_para.message     = (uint8_t const *)&res;

    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)&res, HALFWORD_NUM(encoder_res2_t));

    if ((A_FORMAT_GET_CMD_CODE_IF(res.IF) != cmd) || (CRC_Calc(&crc8_para) != 0))
    {
        return kStatus_FLEXIO_A_FORMAT_FrameErr;
    }

    *id = GET_ENCODER_ID(*(uint32_t *)res.DF);
    return kStatus_Success;
}

status_t A_Format_Set_ID(encoder_A_format *enc, uint8_t enc_addr, uint32_t id)
{
    encoder_res2_t res;
    uint16_t mdf[3] = {
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF0, id & 0x000000FF, 0),
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF1, (id & 0x0000FF00) >> 8, 0),
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF2, (id & 0x00FF0000) >> 16, 0)
    };

    cmd = A_FORMAT_REQ_IT_ID_CODE_WRITE1;
    cdf = A_FORMAT_PACK_CDF((enc_addr & 0x7), A_FORMAT_REQ_IT_ID_CODE_WRITE1, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    for (uint8_t i = 0; i < 3; i++)
    {
        crc_data = A_FORMAT_GET_CRC_DATA_MDF(mdf[i]);
        crc = CRC_Calc(&crc3_para);
        mdf[i] = A_FORMAT_SET_CRC_CODE_MDF(mdf[i], crc);
    }

    FLEXIO_A_Format_Config_DR_length(enc->controller, 4);

    crc8_para.message_len = 6;
    crc8_para.message     = (uint8_t const *)&res;

    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);//2.7us
    FLEXIO_A_Format_WriteBlocking(enc->controller, mdf, 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &mdf[1], 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &mdf[2], 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)&res, HALFWORD_NUM(encoder_res2_t));

    if ((A_FORMAT_GET_CMD_CODE_IF(res.IF) != cmd) || (CRC_Calc(&crc8_para) != 0) ||
        (GET_ENCODER_ID(*(uint32_t *)res.DF) != id))
    {
        return kStatus_FLEXIO_A_FORMAT_FrameErr;
    }

    return kStatus_Success;
}

status_t A_Format_Set_ID_1to1(encoder_A_format *enc, uint32_t id)
{
    encoder_res2_t res;
    uint16_t mdf[3] = {
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF0, id & 0x000000FF, 0),
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF1, (id & 0x0000FF00) >> 8, 0),
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF2, (id & 0x00FF0000) >> 16, 0)
    };

    cmd = A_FORMAT_REQ_IT_ID_CODE_WRITE2;
    cdf = A_FORMAT_PACK_CDF(0, A_FORMAT_REQ_IT_ID_CODE_WRITE2, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    for (uint8_t i = 0; i < 3; i++)
    {
        crc_data = A_FORMAT_GET_CRC_DATA_MDF(mdf[i]);
        crc = CRC_Calc(&crc3_para);
        mdf[i] = A_FORMAT_SET_CRC_CODE_MDF(mdf[i], crc);
    }

    FLEXIO_A_Format_Config_DR_length(enc->controller, 4);

    crc8_para.message_len = 6;
    crc8_para.message     = (uint8_t const *)&res;

    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);//2.7us
    FLEXIO_A_Format_WriteBlocking(enc->controller, mdf, 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &mdf[1], 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &mdf[2], 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)&res, HALFWORD_NUM(encoder_res2_t));

    if ((A_FORMAT_GET_CMD_CODE_IF(res.IF) != cmd) || (CRC_Calc(&crc8_para) != 0) ||
        (GET_ENCODER_ID(*(uint32_t *)res.DF) != id))
    {
        return kStatus_FLEXIO_A_FORMAT_FrameErr;
    }

    return kStatus_Success;
}

status_t A_Format_Set_Encoder_Address_MATCH_ID(encoder_A_format *enc, uint32_t id, uint8_t enc_addr)
{
    encoder_res2_t res;
    uint16_t mdf[3] = {
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF0, id & 0x000000FF, 0),
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF1, (id & 0x0000FF00) >> 8, 0),
        A_FORMAT_PACK_MDF(A_FORMAT_FRAME_CODE_MDF2, (id & 0x00FF0000) >> 16, 0)
    };

    cmd = A_FORMAT_REQ_IT_SET_ENCODER_ADDR2;
    cdf = A_FORMAT_PACK_CDF((enc_addr & 0x7), A_FORMAT_REQ_IT_SET_ENCODER_ADDR2, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    for (uint8_t i = 0; i < 3; i++)
    {
        crc_data = A_FORMAT_GET_CRC_DATA_MDF(mdf[i]);
        crc = CRC_Calc(&crc3_para);
        mdf[i] = A_FORMAT_SET_CRC_CODE_MDF(mdf[i], crc);
    }

    FLEXIO_A_Format_Config_DR_length(enc->controller, 4);

    crc8_para.message_len = 6;
    crc8_para.message     = (uint8_t const *)&res;

    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);//2.7us
    FLEXIO_A_Format_WriteBlocking(enc->controller, mdf, 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &mdf[1], 1);
    SDK_DelayAtLeastUs(7, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &mdf[2], 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)&res, HALFWORD_NUM(encoder_res2_t));

    if ((A_FORMAT_GET_CMD_CODE_IF(res.IF) != cmd) || (CRC_Calc(&crc8_para) != 0) ||
        (GET_ENCODER_ID(*(uint32_t *)res.DF) != id))
    {
        return kStatus_FLEXIO_A_FORMAT_FrameErr;
    }

    return kStatus_Success;
}

status_t A_Format_ABS_Readout_Single_17bit(encoder_A_format *enc, uint8_t enc_addr, encoder_abs_single_t *singleData)
{
    encoder_res1_t *res = res1;

    cmdErr = 0;
    is_MultiTrans = ENCODER_ADDRESS_IS_MT(enc_addr);

    cmd = is_MultiTrans ? A_FORMAT_REQ_MT_ABS_LOWER_17BIT : A_FORMAT_REQ_IT_ABS_LOWER_17BIT;
    cdf = A_FORMAT_PACK_CDF((enc_addr & 0x7), cmd, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    nEncoder = is_MultiTrans ? ((enc_addr & 0x7) + 1) : 1;
    memset(res, 0, sizeof(encoder_res1_t) * nEncoder);

    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)res,
                                 HALFWORD_NUM(encoder_res1_t) * nEncoder);

    crc8_para.message_len = 4;
    for (uint8_t i = 0; i < nEncoder; i++)
    {
        crc8_para.message = (uint8_t const *)&res[i];
        if (CRC_Calc(&crc8_para) != 0)
       	{
            cmdErr++;
            singleData[i].es = A_Format_ES_FrameErr;
            continue;
        }

        singleData[i].encID = A_FORMAT_GET_ENC_ADDR_IF(res[i].IF);
        if (res[i].IF & 0x0040)
        {
            cmdErr++;
            singleData[i].es = A_Format_ES_Anyone;
        }

        singleData[i].singleTurn = (((uint32_t)res[i].DF << 9) | (res[i].IF >> 7)) & enc->single_turn_sign_mask;
    }

    return cmdErr ? kStatus_Fail : kStatus_Success;
}

status_t A_Format_ABS_Readout_Single_with_status(encoder_A_format *enc, uint8_t enc_addr, encoder_single_stat_t *singleStat)
{
    encoder_res3_t *res = res3;

    cmdErr = 0;
    is_MultiTrans = ENCODER_ADDRESS_IS_MT(enc_addr);

    cmd = is_MultiTrans ? A_FORMAT_REQ_MT_ABS_LOWER_24BIT_STAT : A_FORMAT_REQ_IT_ABS_LOWER_24BIT_STAT;
    cdf = A_FORMAT_PACK_CDF((enc_addr & 0x7), cmd, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    nEncoder = is_MultiTrans ? ((enc_addr & 0x7) + 1) : 1;
    memset(res, 0, sizeof(encoder_res3_t) * nEncoder);

    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)res,
                                 HALFWORD_NUM(encoder_res3_t) * nEncoder);

    crc8_para.message_len = 8;
    for (uint8_t i = 0; i < nEncoder; i++)
    {
        crc8_para.message = (uint8_t const *)&res[i];
        if ((A_FORMAT_GET_CMD_CODE_IF(res[i].IF) != cmd) || (CRC_Calc(&crc8_para) != 0))
       	{
            cmdErr++;
            singleStat[i].es = A_Format_ES_FrameErr;
            continue;
        }

        singleStat[i].encID = A_FORMAT_GET_ENC_ADDR_IF(res[i].IF);
        singleStat[i].es    = A_FORMAT_GET_ENC_STAT_IF(res[i].IF);
        if (singleStat[i].es != A_Format_ES_NoErr)
        {
            cmdErr++;
        }

        singleStat[i].singleTurn = *(uint32_t *)res[i].DF & enc->single_turn_sign_mask;
        singleStat[i].ALM = (res[i].DF[2] << 8) | (res[i].DF[1] >> 8);
    }

    return cmdErr ? kStatus_Fail : kStatus_Success;
}

status_t A_Format_ABS_Readout_Single_with_temperature(encoder_A_format *enc, uint8_t enc_addr, encoder_single_temp_t *singleTemp)
{
    encoder_res3_t *res = res3;
    uint16_t temp;

    cmdErr = 0;
    is_MultiTrans = ENCODER_ADDRESS_IS_MT(enc_addr) ? true : false;

    cmd = is_MultiTrans ? A_FORMAT_REQ_MT_ABS_LOWER_24BIT_TEMP : A_FORMAT_REQ_IT_ABS_LOWER_24BIT_TEMP;
    cdf = A_FORMAT_PACK_CDF((enc_addr & 0x7), cmd, 0);
    crc_data = A_FORMAT_GET_CRC_DATA_CDF(cdf);
    crc = CRC_Calc(&crc3_para);
    cdf = A_FORMAT_SET_CRC_CODE_CDF(cdf, crc);

    nEncoder = is_MultiTrans ? ((enc_addr & 0x7) + 1) : 1;
    memset(res, 0, sizeof(encoder_res3_t) * nEncoder);

    FLEXIO_A_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_A_Format_WriteBlocking(enc->controller, &cdf, 1);
    FLEXIO_A_Format_ReadBlocking(enc->controller, (uint16_t *)res,
                                 HALFWORD_NUM(encoder_res3_t) * nEncoder);

    crc8_para.message_len = 8;
    for (uint8_t i = 0; i < nEncoder; i++)
    {
        crc8_para.message = (uint8_t const *)&res[i];
        if ((A_FORMAT_GET_CMD_CODE_IF(res[i].IF) != cmd) || (CRC_Calc(&crc8_para) != 0))
       	{
            cmdErr++;
            singleTemp[i].es = A_Format_ES_FrameErr;
            continue;
        }

        singleTemp[i].encID = A_FORMAT_GET_ENC_ADDR_IF(res[i].IF);
        singleTemp[i].es    = A_FORMAT_GET_ENC_STAT_IF(res[i].IF);
        if (singleTemp[i].es != A_Format_ES_NoErr)
        {
            cmdErr++;
        }

        singleTemp[i].singleTurn = *(uint32_t *)res[i].DF & enc->single_turn_sign_mask;
        temp = (res[i].DF[2] << 8) | (res[i].DF[1] >> 8);
        singleTemp[i].temperature = GET_TEMPERATURE_VALUE(temp);
    }

    return cmdErr ? kStatus_Fail : kStatus_Success;
}
