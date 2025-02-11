/*
 * Copyright 2023 NXP
 * All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */
#include <stdio.h>
#include "fsl_clock.h"
#include "fsl_flexio_t-format.h"

/*******************************************************************************
 * Definitions
 ******************************************************************************/
/* Component ID definition, used by tools. */
#ifndef FSL_COMPONENT_ID
#define FSL_COMPONENT_ID "platform.drivers.flexio_t_format"
#endif

/*******************************************************************************
 * Variables
 ******************************************************************************/
/* The default when a main power supply is turned on is page 0 */
static uint8_t eeprom_page = 0;
/* Description of Status Flag */
//static char *T_FORMAT_ALMC_OS_String = "The rotate speed is over 6000r/min in the Power-off mode";
//static char *T_FORMAT_ALMC_FS_String = "While the rotate speed is 100r/min or more, main power supply is turned on";
//static char *T_FORMAT_ALMC_CE_String = "One revolution data is deviated by any malfunction or defect at main power-on";
//static char *T_FORMAT_ALMC_OF_String = "The multi-turn counter is overflowed";
//static char *T_FORMAT_ALMC_OH_String = "The temperature of the encoder substrate exceeds overheating detection temperature";
//static char *T_FORMAT_ALMC_ME_String = "Any bit-jump occurs in the multi-turn signal";
//static char *T_FORMAT_ALMC_BE_String = "The external battery voltage is 3.1±0.1 V or less during main power-on";
//static char *T_FORMAT_ALMC_BA_String = "The external battery voltage is 2.75±0.25V or less during main power-off";
/* Description of Status Flag */
static char *T_FORMAT_SF_EA0_String   = "One revolution data is deviated by any malfunction or defect at main power-on";
static char *T_FORMAT_SF_EA1_String   = "Logic-OR of Over-heat, Multi-turn error, Battery error and Battery alarm";
static char *T_FORMAT_SF_CA0_String   = "Parity error in Request frame occurs";
static char *T_FORMAT_SF_CA1_String   = "Delimiter error in Request frame occurs";
static char *T_FORMAT_NO_ERROR_String = "No error occurs";

/*******************************************************************************
 * Codes
 ******************************************************************************/

static uint32_t FLEXIO_T_FORMAT_GetInstance(FLEXIO_T_FORMAT_Type *base)
{
    return FLEXIO_GetInstance(base->flexioBase);
}

static status_t FLEXIO_T_Format_CheckBaudRate(uint32_t baudRate_Bps, uint32_t srcClock_Hz, uint16_t timerDiv)
{
    uint32_t calculatedBaud, diff;

    calculatedBaud = srcClock_Hz / (((uint32_t)timerDiv + 1U) * 2U);
    diff = calculatedBaud - baudRate_Bps;
    if (diff > ((baudRate_Bps / 100U) * 3U))  //3%
    {
        return kStatus_FLEXIO_T_FORMAT_BaudrateNotSupport;
    }
    return kStatus_Success;
}

/*!
 *
 */
static uint16_t FLEXIO_T_FORMAT_GetTimerCompare(FLEXIO_T_FORMAT_Type *base, uint32_t srcClock_Hz)
{
    uint16_t timerCmp = 0;

    base->timerDiv    = srcClock_Hz / 2500000;
    timerCmp = base->timerDiv / 2U - 1U;
    if ((timerCmp > 0xFFU) || (FLEXIO_T_Format_CheckBaudRate(2500000, srcClock_Hz, timerCmp) != kStatus_Success))
    {
        return 0xFFFFU;
    }
    timerCmp = T_FORMAT_TIMER_COMPARE_VALUE(timerCmp);
    base->TxDR_Offset = srcClock_Hz / 2000000;  /* 0.5us */
//    base->interval    = 240; /* 3us */

    return timerCmp;
}

/*!
 *
 */
void FLEXIO_T_Format_Config_DR_length(FLEXIO_T_FORMAT_Type *base, uint32_t nFrames)
{
    uint16_t timerCmp = 0;

    timerCmp = (uint16_t)(T_FORMAT_BITS_PER_FRAME_WHOLE * nFrames * base->timerDiv +
                           base->TxDR_Offset) - 1;
    base->flexioBase->TIMCMP[base->timerIndex[T_FORMAT_TIMER_DR_INDEX]] = FLEXIO_TIMCMP_CMP(timerCmp);
}

/*!
 * brief Ungates the FlexIO clock, resets the FlexIO module, configures the FlexIO T-Format
 * hardware, and configures the FlexIO T-Format with FlexIO T-Format configuration.
 * The configuration structure can be filled by the user, or be set with default values
 * by the FLEXIO_T_FORMAT_GetDefaultConfig().
 *
 * Example
   code
   FLEXIO_T_FORMAT_Type base = {
   .flexioBase = FLEXIO,
   .TxPinIndex = 0,
   .RxPinIndex = 1,
   .shifterIndex = {0,1},
   .timerIndex = {0,1}
   };
   flexio_t_format_config_t config = {
   .enableInDoze = false,
   .enableInDebug = true,
   .enableFastAccess = false,
   .baudRate_bps = 2500000
   };
   FLEXIO_T_Format_Init(&base, &config);
   endcode
 *
 * param base Pointer to the FLEXIO_T_FORMAT_Type structure.
 * param userConfig Pointer to the flexio_t_format_config_t structure.
 * retval kStatus_Success Configuration success.
 */
status_t FLEXIO_T_Format_Init(FLEXIO_T_FORMAT_Type *base, flexio_t_format_config_t *userConfig, uint32_t srcClock_Hz)
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
    CLOCK_EnableClock(s_flexioClocks[FLEXIO_T_FORMAT_GetInstance(base)]);
#endif /* FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL */

    /* Configure FLEXIO T_FORMAT */
    ctrlReg = base->flexioBase->CTRL;
    ctrlReg &= ~(FLEXIO_CTRL_DOZEN_MASK | FLEXIO_CTRL_DBGE_MASK | FLEXIO_CTRL_FASTACC_MASK | FLEXIO_CTRL_FLEXEN_MASK);
    ctrlReg |= (FLEXIO_CTRL_DBGE(userConfig->enableInDebug) | FLEXIO_CTRL_FASTACC(userConfig->enableFastAccess) |
                FLEXIO_CTRL_FLEXEN(userConfig->enableT_Format));
    if (!userConfig->enableInDoze)
    {
        ctrlReg |= FLEXIO_CTRL_DOZEN_MASK;
    }

    base->flexioBase->CTRL = ctrlReg;

    /* Do hardware configuration. */
    /* 1. Configure the shifter 0 for tx. */
    shifterConfig.timerSelect   = base->timerIndex[T_FORMAT_TIMER_TX_INDEX]; // Timer Index
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

    if (userConfig->userMode == kFLEXIO_T_FORMAT_USERMODE_SYNC) {
        /*Configure the timer is triggered by FlexIO trigger signal. */
        timerConfig.triggerSelect   = base->triggerIn;
        timerConfig.triggerPolarity = kFLEXIO_TimerTriggerPolarityActiveHigh;
        timerConfig.triggerSource   = kFLEXIO_TimerTriggerSourceExternal;
    }

    timerCmp = FLEXIO_T_FORMAT_GetTimerCompare(base, srcClock_Hz);
    if (timerCmp == 0xFFFFU)
    {
        /* Check whether the configuared baudrate is within allowed range. */
        return kStatus_FLEXIO_T_FORMAT_BaudrateNotSupport;
    }
    timerConfig.timerCompare = timerCmp;

    FLEXIO_SetTimerConfig(base->flexioBase, base->timerIndex[T_FORMAT_TIMER_TX_INDEX], &timerConfig);

    /* 3. Configure the shifter 1 for rx. */
    shifterConfig.timerSelect   = base->timerIndex[T_FORMAT_TIMER_RX_INDEX];
    shifterConfig.timerPolarity = kFLEXIO_ShifterTimerPolarityOnNegitive;
    shifterConfig.pinConfig     = kFLEXIO_PinConfigOutputDisabled;
    shifterConfig.pinSelect     = base->RxPinIndex;
    shifterConfig.pinPolarity   = kFLEXIO_PinActiveHigh;
    shifterConfig.shifterMode   = kFLEXIO_ShifterModeReceive;
    shifterConfig.inputSource   = kFLEXIO_ShifterInputFromPin;
    shifterConfig.shifterStop   = kFLEXIO_ShifterStopBitHigh;
    shifterConfig.shifterStart  = kFLEXIO_ShifterStartBitLow;

    FLEXIO_SetShifterConfig(base->flexioBase, base->shifterIndex[1], &shifterConfig);

    /* 4. Configure the timer 1 for rx. */
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

    FLEXIO_SetTimerConfig(base->flexioBase, base->timerIndex[T_FORMAT_TIMER_RX_INDEX], &timerConfig);

    /*5. Configure the timer 2 for DR */
    timerConfig.triggerSelect   = FLEXIO_TIMER_TRIGGER_SEL_TIMn(base->timerIndex[T_FORMAT_TIMER_TX_INDEX]);
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

    timerCmp = (uint16_t)(T_FORMAT_BITS_PER_FRAME_WHOLE * base->timerDiv) - 1;
    timerConfig.timerCompare = timerCmp;

    FLEXIO_SetTimerConfig(base->flexioBase, base->timerIndex[T_FORMAT_TIMER_DR_INDEX], &timerConfig);
    return result;
}

/*!
 * brief Resets the FlexIO T-Format shifter and timer config.
 *
 * note After calling this API, call the FLEXIO_T_Format_Init to use the FlexIO T_format module.
 *
 * param base Pointer to FLEXIO_T_FORMAT_Type structure
 */
void FLEXIO_T_Format_Deinit(FLEXIO_T_FORMAT_Type *base)
{
    base->flexioBase->SHIFTCFG[base->shifterIndex[0]] = 0;
    base->flexioBase->SHIFTCTL[base->shifterIndex[0]] = 0;
    base->flexioBase->SHIFTCFG[base->shifterIndex[1]] = 0;
    base->flexioBase->SHIFTCTL[base->shifterIndex[1]] = 0;
    for (int i = 0; i <= T_FORMAT_TIMER_DR_INDEX; i++)
    {
        base->flexioBase->TIMCFG[base->timerIndex[i]]     = 0;
        base->flexioBase->TIMCMP[base->timerIndex[i]]     = 0;
        base->flexioBase->TIMCTL[base->timerIndex[i]]     = 0;
    }
    /* Clear the shifter flag. */
    base->flexioBase->SHIFTSTAT = (1UL << base->shifterIndex[0]);
    base->flexioBase->SHIFTSTAT = (1UL << base->shifterIndex[1]);
    /* Clear the timer flag. */
    for (int i = 0; i <= T_FORMAT_TIMER_DR_INDEX; i++)
        base->flexioBase->TIMSTAT = (1UL << base->timerIndex[i]);
}

/*!
 * brief Gets the default configuration to configure the FlexIO T-format. The configuration
 * can be used directly for calling the FLEXIO_T_Format_Init().
 * Example:
   code
   flexio_t_format_config_t config;
   FLEXIO_T_Format_GetDefaultConfig(&userConfig);
   endcode
 * param userConfig Pointer to the flexio_t_format_config_t structure.
*/
void FLEXIO_T_Format_GetDefaultConfig(flexio_t_format_config_t *userConfig)
{
    /* Initializes the configure structure to zero. */
    (void)memset(userConfig, 0, sizeof(*userConfig));

    userConfig->enableT_Format   = true;
    userConfig->enableInDoze     = false;
    userConfig->enableInDebug    = true;
    userConfig->enableFastAccess = false;
    /* Default baud rate 2.5Mbps. */
//    userConfig->baudRate_bps     = kFLEXIO_T_FORMAT_2_5MHZ;
    /* Default running mode USERMODE_ONESHOT*/
    userConfig->userMode         = kFLEXIO_T_FORMAT_USERMODE_ONESHOT;
}

/*!
 * brief Gets the FlexIO T-format status flags.
 *
 * param base Pointer to the FLEXIO_T_FORMAT_Type structure.
 * return FlexIO T-format status flags.
 */
uint32_t FLEXIO_T_Format_GetStatusFlags(FLEXIO_T_FORMAT_Type *base)
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
 * brief Clears the FlexIO T-format status flags.
 *
 * param base Pointer to the FLEXIO_T_FORMAT_Type structure.
 * param mask Status flag.
 *      The parameter can be any combination of the following values:
 *          arg kFLEXIO_T_Format_TxDataRegEmptyFlag
 *          arg kFLEXIO_T_Format_RxDataRegFullFlag
 *          arg kFLEXIO_T_Format_RxOverRunFlag
 */
void FLEXIO_T_Format_ClearStatusFlags(FLEXIO_T_FORMAT_Type *base, uint32_t mask)
{
    if ((mask & (uint32_t)kFLEXIO_T_Format_TxDataRegEmptyFlag) != 0U)
    {
        FLEXIO_ClearShifterStatusFlags(base->flexioBase, 1UL << base->shifterIndex[0]);
    }
    if ((mask & (uint32_t)kFLEXIO_T_Format_RxDataRegFullFlag) != 0U)
    {
        FLEXIO_ClearShifterStatusFlags(base->flexioBase, 1UL << base->shifterIndex[1]);
    }
    if ((mask & (uint32_t)kFLEXIO_T_Format_RxOverRunFlag) != 0U)
    {
        FLEXIO_ClearShifterErrorFlags(base->flexioBase, 1UL << base->shifterIndex[1]);
    }
}

/*!
 * brief Sends a buffer of data bytes.
 *
 * note This function blocks using the polling method until all bytes have been sent.
 *
 * param base Pointer to the FLEXIO_T_FORMAT_Type structure.
 * param txData The data bytes to send.
 * param txSize The number of data bytes to send.
 * retval kStatus_FLEXIO_T_FORMAT_Timeout Transmission timed out and was aborted.
 * retval kStatus_Success Successfully wrote all data.
 */
status_t FLEXIO_T_Format_WriteBlocking(FLEXIO_T_FORMAT_Type *base, const uint8_t *txData, size_t txSize)
{
    assert(txData != NULL);
    assert(txSize != 0U);
#if T_FORMAT_RETRY_TIMES
    uint32_t waitTimes = T_FORMAT_RETRY_TIMES;
#endif

    while (0U != txSize--)
    {
        /* Wait until data transfer complete. */
        while ((0U == (FLEXIO_GetShifterStatusFlags(base->flexioBase) & (1UL << base->shifterIndex[0])))
#if T_FORMAT_RETRY_TIMES
               && (0U != --waitTimes)
#endif
	       );
#if T_FORMAT_RETRY_TIMES
        if (0U == waitTimes)
        {
            return kStatus_FLEXIO_T_FORMAT_Timeout;
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
 * param base Pointer to the FLEXIO_T_FORMAT_Type structure.
 * param rxData The buffer to store the received bytes.
 * param rxSize The number of data bytes to be received.
 * retval kStatus_FLEXIO_T_FORMAT_Timeout Transmission timed out and was aborted.
 * retval kStatus_Success Successfully received all data.
 */
status_t FLEXIO_T_Format_ReadBlocking(FLEXIO_T_FORMAT_Type *base, uint8_t *rxData, size_t rxSize)
{
    assert(rxData != NULL);
    assert(rxSize != 0U);
#if T_FORMAT_RETRY_TIMES
    uint32_t waitTimes = T_FORMAT_RETRY_TIMES;
#endif

    while (0U != rxSize--)
    {
        /* Wait until data transfer complete. */
        while ((0U == (FLEXIO_T_Format_GetStatusFlags(base) & (uint32_t)kFLEXIO_T_Format_RxDataRegFullFlag))
#if T_FORMAT_RETRY_TIMES
               && (0U != --waitTimes)
#endif
              );
#if T_FORMAT_RETRY_TIMES
        if (0U == waitTimes)
        {
            return kStatus_FLEXIO_T_FORMAT_Timeout;
        }
#endif

        *rxData = (uint8_t)(base->flexioBase->SHIFTBUFBYS[base->shifterIndex[1]]);
        rxData++;
    }

    return kStatus_Success;
}

/*!
 * brief Receives data using eDMA.
 *
 * This function receives data using eDMA. This is a non-blocking function, which returns
 * right away. When all data is received, the receive callback function is called.
 *
 * param base Pointer to FLEXIO_T_FORMAT_Type
 * param rxData Pointer to receive buffer
 * param dataSize Pointer to the size of receive buffer
 * retval kStatus_Success if succeed, others failed.
 */
status_t FLEXIO_T_Format_TransferReceiveEDMA(FLEXIO_T_FORMAT_Type *base,
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
    EDMA_PrepareTransfer(&xferConfig, (uint32_t *)FLEXIO_T_Format_GetRxDataRegisterAddress(base), sizeof(uint8_t),
                         rxData, sizeof(uint8_t), sizeof(uint8_t), dataSize, kEDMA_PeripheralToMemory);

    /* Submit transfer. */
    (void)EDMA_SubmitTransfer(rxEdmaHandle, &xferConfig);
    EDMA_StartTransfer(rxEdmaHandle);

    /* Enable T-Format RX EDMA. */
    FLEXIO_T_Format_EnableRxDMA(base, true);

    return kStatus_Success;
}

/*!
 * brief Checks receive eDMA status.
 *
 * This function check whether the receive eDMA is completed. This is a non-blocking function, which returns
 * right away.
 *
 * param base Pointer to FLEXIO_T_FORMAT_Type
 * retval kStatus_Success if succeed, others failed.
 */
status_t FLEXIO_T_Format_ReceiveEDMA_isCompleted(FLEXIO_T_FORMAT_Type *base)
{
    edma_handle_t *rxEdmaHandle = &base->rxEdmaHandle;

    if (rxEdmaHandle->channelBase->CH_CSR & DMA_CH_CSR_DONE_MASK)
    {
        rxEdmaHandle->channelBase->CH_CSR |= DMA_CH_CSR_DONE_MASK;
        return kStatus_Success;
    }

    return kStatus_NoTransferInProgress;
}

static uint8_t CRC_Calc(const uint8_t *message, uint8_t message_len)
{
    uint8_t remainder = 0;
    uint8_t i = 0, j = 0;
    uint8_t poly = T_FORMAT_CRC_POLYNOMIAL;

    for (j = 0; j < message_len; j++) {
        remainder ^= message[j];

        for (i = 0; i < 8; i++) {
            if (remainder & 0x80)
                remainder = (remainder << 1) ^ poly;
            else
                remainder <<= 1;
        }
    }

    return remainder;
}

status_t FLEXIO_T_Format_SendSyncReq(FLEXIO_T_FORMAT_Type *base, const uint8_t cf)
{
    FLEXIO_T_Format_Config_DR_length(base, 1);
    base->flexioBase->SHIFTBUF[base->shifterIndex[0]] = cf;
    return kStatus_Success;
}

char *T_Format_GetStatusFlag(status_t status)
{
    switch (status)
    {
    case kStatus_FLEXIO_T_FORMAT_EncErr0_CountingErr:
        return T_FORMAT_SF_EA0_String;
    case kStatus_FLEXIO_T_FORMAT_EncErr1_LogicOR:
        return T_FORMAT_SF_EA1_String;
    case kStatus_FLEXIO_T_FORMAT_ComAlr0_ParityErr:
        return T_FORMAT_SF_CA0_String;
    case kStatus_FLEXIO_T_FORMAT_ComAlr1_DelimiterErr:
        return T_FORMAT_SF_CA1_String;
    default:
        return T_FORMAT_NO_ERROR_String;
    }
}

status_t T_Format_Check_SF(uint8_t sf)
{
    uint8_t temp;

    if (sf)
    {
        temp = T_FORMAT_SF_GET_COMMUNICATION_ALARM(sf);
        if (temp)
        {
            if (temp & 0x01)
            {
                return kStatus_FLEXIO_T_FORMAT_ComAlr0_ParityErr;
            }
            else
            {
                return kStatus_FLEXIO_T_FORMAT_ComAlr1_DelimiterErr;
            }
        }
        temp = T_FORMAT_SF_GET_ENCODER_ERROR(sf);
        if (temp)
        {
            if (temp & 0x01)
            {
                return kStatus_FLEXIO_T_FORMAT_EncErr0_CountingErr;
            }
            else
            {
                return kStatus_FLEXIO_T_FORMAT_EncErr1_LogicOR;
            }
        }
    }
    return kStatus_Success;
}

status_t T_Format_Readout_ABS_ABM(encoder_T_format *enc, encoder_all_info_t *all_info)
{
    encoder_res_all_info_t res;
    uint8_t cf = T_FORMAT_CF_GET_ALL;

    FLEXIO_T_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_T_Format_WriteBlocking(enc->controller, &cf, 1);
    FLEXIO_T_Format_ReadBlocking(enc->controller, (uint8_t *)&res, T_FORMAT_ALL_INFO_BYTE);

    if (CRC_Calc((uint8_t *)&res, T_FORMAT_ALL_INFO_BYTE) != 0)
    {
        return kStatus_FLEXIO_T_FORMAT_FrameErr;
    }

    all_info->ALMC  = res.ALMC;
    all_info->encID = res.ENCID;
    memcpy(&all_info->singleTurn, &res.ABS, 3);
    all_info->singleTurn &= enc->single_turn_sign_mask;
    memcpy(&all_info->multiTurn, &res.ABM, 3);
    all_info->multiTurn &= enc->multi_turn_sign_mask;

    return T_Format_Check_SF(res.SF);
}

status_t T_Format_Readout_ABS_ABM_Sync(encoder_T_format *enc, encoder_res_all_info_t *res,
                                                encoder_all_info_t *all_info)
{
    status_t status = kStatus_Success;

    if (CRC_Calc((uint8_t *)res, T_FORMAT_ALL_INFO_BYTE) != 0)
    {
        return kStatus_FLEXIO_T_FORMAT_FrameErr;
    }

    all_info->ALMC = res->ALMC;
    status = T_Format_Check_SF(res->SF);
    if (status != kStatus_Success)
    {
        return status;
    }

    all_info->encID = res->ENCID;
    memcpy(&all_info->singleTurn, &res->ABS, 3);
    all_info->singleTurn &= enc->single_turn_sign_mask;
    memcpy(&all_info->multiTurn, &res->ABM, 3);
    all_info->multiTurn &= enc->multi_turn_sign_mask;

    return kStatus_Success;
}

status_t T_Format_Readout_ABS(encoder_T_format *enc, uint32_t *singleData)
{
    encoder_res_data_t res;
    uint8_t cf = T_FORMAT_CF_GET_ABS;
    status_t status = kStatus_Success;

    FLEXIO_T_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_T_Format_WriteBlocking(enc->controller, &cf, 1);
    FLEXIO_T_Format_ReadBlocking(enc->controller, (uint8_t *)&res, T_FORMAT_ABS_BYTE);

    if (CRC_Calc((uint8_t *)&res, T_FORMAT_ABS_BYTE) != 0)
    {
        return kStatus_FLEXIO_T_FORMAT_FrameErr;
    }

    status = T_Format_Check_SF(res.SF);
    if (status != kStatus_Success)
    {
        return status;
    }

    memcpy(singleData, &res.ABS, 3);
    *singleData &= enc->single_turn_sign_mask;

    return kStatus_Success;
}

status_t T_Format_Readout_ABM(encoder_T_format *enc, uint32_t *multiData)
{
    encoder_res_data_t res;
    uint8_t cf = T_FORMAT_CF_GET_ABM;
    status_t status = kStatus_Success;

    FLEXIO_T_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_T_Format_WriteBlocking(enc->controller, &cf, 1);
    FLEXIO_T_Format_ReadBlocking(enc->controller, (uint8_t *)&res, T_FORMAT_ABM_BYTE);

    if (CRC_Calc((uint8_t *)&res, T_FORMAT_ABM_BYTE) != 0)
    {
        return kStatus_FLEXIO_T_FORMAT_FrameErr;
    }

    status = T_Format_Check_SF(res.SF);
    if (status != kStatus_Success)
    {
        return status;
    }

    memcpy(multiData, &res.ABM, 3);
    *multiData &= enc->multi_turn_sign_mask;

    return kStatus_Success;
}

status_t T_Format_Readout_Encoder_status(encoder_T_format *enc, uint8_t *statusData)
{
    encoder_res_all_info_t res;
    uint8_t cf = T_FORMAT_CF_GET_ALL;
    status_t status = kStatus_Success;

    FLEXIO_T_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_T_Format_WriteBlocking(enc->controller, &cf, 1);
    FLEXIO_T_Format_ReadBlocking(enc->controller, (uint8_t *)&res, T_FORMAT_ALL_INFO_BYTE);

    if (CRC_Calc((uint8_t *)&res, T_FORMAT_ALL_INFO_BYTE) != 0)
    {
        return kStatus_FLEXIO_T_FORMAT_FrameErr;
    }

    *statusData = res.ALMC;
    status = T_Format_Check_SF(res.SF);
    if (status != kStatus_Success)
    {
        return status;
    }

    return kStatus_Success;
}

status_t T_Format_Reset_Request(encoder_T_format *enc, Reset_Type_e reset, uint32_t *abs)
{
    encoder_res_data_t res;
    uint8_t cf;
    status_t status = kStatus_Success;

    switch (reset)
    {
    case T_FORMAT_RESET_ALL_ERROR:
    case T_FORMAT_RESET_ABS:
    case T_FORMAT_RESET_ABM_ERROR:
        cf = (uint8_t)reset;
        break;

    default:
        return kStatus_InvalidArgument;
    }

    for (int i = 0; i < 0; i ++)
    {
        FLEXIO_T_Format_Config_DR_length(enc->controller, 1);
        FLEXIO_T_Format_WriteBlocking(enc->controller, &cf, 1);
        FLEXIO_T_Format_ReadBlocking(enc->controller, (uint8_t *)&res, T_FORMAT_ABS_BYTE);
        SDK_DelayAtLeastUs(40, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);
    }

    if (CRC_Calc((uint8_t *)&res, T_FORMAT_ABS_BYTE) != 0)
    {
        return kStatus_FLEXIO_T_FORMAT_FrameErr;
    }

    status = T_Format_Check_SF(res.SF);
    if (status != kStatus_Success)
    {
        return status;
    }

    memcpy(abs, &res.ABS, 3);
    *abs &= enc->single_turn_sign_mask;

    return kStatus_Success;
}

status_t T_Format_Get_Encoder_ID(encoder_T_format *enc, uint8_t *encID)
{
    encoder_res_id_t res;
    uint8_t cf = T_FORMAT_CF_GET_ENCID;

    FLEXIO_T_Format_Config_DR_length(enc->controller, 1);
    FLEXIO_T_Format_WriteBlocking(enc->controller, &cf, 1);
    FLEXIO_T_Format_ReadBlocking(enc->controller, (uint8_t *)&res, T_FORMAT_ENCODER_ID_BYTE);

    if (CRC_Calc((uint8_t *)&res, T_FORMAT_ENCODER_ID_BYTE) != 0)
    {
        return kStatus_FLEXIO_T_FORMAT_FrameErr;
    }

    *encID = res.ENCID;

    return T_Format_Check_SF(res.SF);
}

status_t T_Format_Memory_Set_Page(encoder_T_format *enc, uint8_t page)
{
    encoder_res_eeprom_t res;
    encoder_req_eeprom_write_t req = {
        .cf  = T_FORMAT_CF_EEPROM_WRITE,
        .adf = 127,
        .edf = page
    };

    req.crc = CRC_Calc((uint8_t *)&req, 3);
    FLEXIO_T_Format_Config_DR_length(enc->controller, 4);
    FLEXIO_T_Format_WriteBlocking(enc->controller, (uint8_t *)&req, 4);
    FLEXIO_T_Format_ReadBlocking(enc->controller, (uint8_t *)&res, T_FORMAT_EEPROM_BYTE);

    if (CRC_Calc((uint8_t *)&res, T_FORMAT_EEPROM_BYTE) != 0)
    {
        return kStatus_FLEXIO_T_FORMAT_FrameErr;
    }

    if (res.ADF & T_FORMAT_SF_MASK_BUSY_STATUS)
    {
        /* EEPROM is in busy status */
        return kStatus_Busy;
    }

    eeprom_page = page;
    return kStatus_Success;
}

status_t T_Format_Memory_Write(encoder_T_format *enc, encoder_access_eeprom_t eeprom)
{
    encoder_res_eeprom_t res;
    encoder_req_eeprom_write_t req = {
        .cf  = T_FORMAT_CF_EEPROM_WRITE,
        .adf = eeprom.address & T_FORMAT_ADF_MASK_ADDRESS,
        .edf = eeprom.data
    };
    status_t status = kStatus_Success;

    if (eeprom.page != eeprom_page)
    {
        status = T_Format_Memory_Set_Page(enc, eeprom.page);
        if (status != kStatus_Success)
        {
            return status;
        }
        /* After the page is changed, it is not possible to access EEPROM between 18ms. */
        SDK_DelayAtLeastUs(18000, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);
    }

    req.crc = CRC_Calc((uint8_t *)&req, 3);
    FLEXIO_T_Format_Config_DR_length(enc->controller, 4);
    FLEXIO_T_Format_WriteBlocking(enc->controller, (uint8_t*)&req, 4);
    FLEXIO_T_Format_ReadBlocking(enc->controller, (uint8_t *)&res, T_FORMAT_EEPROM_BYTE);

    if (CRC_Calc((uint8_t *)&res, T_FORMAT_EEPROM_BYTE) != 0)
    {
        return kStatus_FLEXIO_T_FORMAT_FrameErr;
    }

    if (res.ADF & T_FORMAT_SF_MASK_BUSY_STATUS)
    {
        /* EEPROM is in busy status */
        return kStatus_Busy;
    }

    return kStatus_Success;
}

status_t T_Format_Memory_Read(encoder_T_format *enc, encoder_access_eeprom_t *eeprom)
{
    encoder_res_eeprom_t res;
    encoder_req_eeprom_read_t req = {
        .cf  = T_FORMAT_CF_EEPROM_READOUT,
        .adf = eeprom->address & T_FORMAT_ADF_MASK_ADDRESS
    };
    status_t status = kStatus_Success;

    if (eeprom->page != eeprom_page)
    {
        status = T_Format_Memory_Set_Page(enc, eeprom->page);
        if (status != kStatus_Success)
        {
            return status;
        }
        /* After the page is changed, it is not possible to access EEPROM between 18ms. */
        SDK_DelayAtLeastUs(18000, SDK_DEVICE_MAXIMUM_CPU_CLOCK_FREQUENCY);
    }

    req.crc = CRC_Calc((uint8_t *)&req, 2);
    FLEXIO_T_Format_Config_DR_length(enc->controller, 3);
    FLEXIO_T_Format_WriteBlocking(enc->controller, (uint8_t *)&req, 3);
    FLEXIO_T_Format_ReadBlocking(enc->controller, (uint8_t *)&res, T_FORMAT_EEPROM_BYTE);

    if (CRC_Calc((uint8_t *)&res, T_FORMAT_EEPROM_BYTE) != 0)
    {
        return kStatus_FLEXIO_T_FORMAT_FrameErr;
    }

    if (res.ADF & T_FORMAT_SF_MASK_BUSY_STATUS)
    {
        /* EEPROM is in busy status */
        return kStatus_Busy;
    }

    eeprom->data = res.EDF;

    return kStatus_Success;
}

status_t T_Format_Set_Over_Heat(encoder_T_format *enc, uint8_t temperature)
{
    encoder_access_eeprom_t eeprom = {
        .page = 7,
        .address = 4,
        .data = temperature != T_FORMAT_OVER_HEAT_NOT_CAUSE ?
                T_FORMAT_OVER_HEAT_TEMPERATURE(temperature) : 0U
    };

    return T_Format_Memory_Write(enc, eeprom);
}

status_t T_Format_Get_Temperature(encoder_T_format *enc, int8_t *temperature)
{
    encoder_access_eeprom_t eeprom = {
        .page = 7,
        .address = 5
    };
    status_t status = kStatus_Success;

    status = T_Format_Memory_Read(enc, &eeprom);
    if (status == kStatus_Success)
    {
        *temperature = (int8_t)eeprom.data;
    }
    return status;
}
