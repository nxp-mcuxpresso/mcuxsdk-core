/*
 * Copyright 2026 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "fsl_dual_adc.h"

/*******************************************************************************
 * Definitions
 ******************************************************************************/
/* Component ID definition, used by tools. */
#ifndef FSL_COMPONENT_ID
#define FSL_COMPONENT_ID "platform.drivers.dual_adc"
#endif

#if defined(ADC_RSTS)
#define DUALADC_RESETS_ARRAY ADC_RSTS
#elif defined(ADC_RSTS_N)
#define DUALADC_RESETS_ARRAY ADC_RSTS_N
#endif

/*******************************************************************************
 * Prototypes
 ******************************************************************************/
/*!
 * @brief Calculate the gain calculation result from the gain calibration value.
 *
 * Gain_Adj = 131072 / (131072 - u32GainCalValue), encoded into the 17-bit GCR register field as Q1.16.
 *
 * @param u32GainCalValue Raw gain calibration value read from the GCC register.
 * @return Gain adjustment calculation result to be written into the GCR register.
 */
static uint32_t DUALADC_CalculateGainResult(uint32_t u32GainCalValue);

/*******************************************************************************
 * Variables
 ******************************************************************************/

/*! @brief Array to map DualADC u32Instance number to base pointer. */
static DUALADC_Type *const s_dualadcBases[] = DUALADC_BASE_PTRS;

#if !(defined(FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL) && FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL)
/*! @brief Pointers to DualADC clocks for each DualADC submodule. */
static const clock_ip_name_t s_dualadcClocks[] = DUALADC_CLOCKS;
#endif /* FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL */

#if defined(DUALADC_RESETS_ARRAY)
/* Reset array */
static const reset_ip_name_t s_dualadcResets[] = DUALADC_RESETS_ARRAY;
#endif

/*******************************************************************************
 * Code
 ******************************************************************************/
/*!
 * @brief Get the u32Instance for DualADC module.
 *
 * @param base DualADC base address
 * @return Instance number if valid base address is provided, otherwise returns 0xFFFFFFFF
 */
uint32_t DUALADC_GetInstance(DUALADC_Type *base)
{
    uint32_t u32Instance;

    /* Find the u32Instance index from base address mappings. */
    for (u32Instance = 0; u32Instance < ARRAY_SIZE(s_dualadcBases); u32Instance++)
    {
        if (MSDK_REG_NONSECURE_ADDR(s_dualadcBases[u32Instance]) == MSDK_REG_NONSECURE_ADDR(base))
        {
            break;
        }
    }

    if (u32Instance == ARRAY_SIZE(s_dualadcBases))
    {
        u32Instance = 0xFFFFFFFFUL; /* Return 0xFFFFFFFF if invalid base address is provided. */
    }

    return u32Instance;
}

/*!
 * @brief Populate a dualadc_config_t with reset-state defaults.
 *
 * @param config Pointer to the configuration structure to populate.
 */
void DUALADC_GetDefaultConfig(dualadc_config_t *config)
{
    assert(NULL != config);

    /* CFG0 - Configuration 0 Register */
    config->eConversionMode          = kDUALADC_CooperationMode;
    config->ePowerConfig             = kDUALADC_LowPowerConfig;
    config->bEnableAnalogPreEnable   = false;
    config->eRefVoltageSource        = kDUALADC_VrefH0;
    config->u8PowerUpDelayCount      = 0x80U;
    config->eTriggerSource           = kDUALADC_TrigSelTrigger0;

    /* CFG1 - Configuration 1 Register */
    config->bEnableLeftJustify       = false;
    config->bEnableHighSpeedMode     = false;
    config->bEnableHighSpeedExtra    = false;
    config->eTuneMode                = kDUALADC_TuneMode1;

    /* CTRL - Control Register */
    config->bEnableDoze              = false;
    config->bEnableLongCalSampleTime = false;
    config->eCalibrationAverages     = kDUALADC_CalibrationAverage256;

    /* PAUSE - Pause Register */
    config->sPauseConfig.bEnableConversionPause = false;
    config->sPauseConfig.u16ConversionPauseDelay  = 0U;

    /* TCTRL - Trigger Control Register */
    config->sTriggerConfig.bEnableHardwareTrigger0 = false;
    config->sTriggerConfig.u8Trigger0Delay = 0U;
    config->sTriggerConfig.bEnableHardwareTrigger1 = false;
    config->sTriggerConfig.u8Trigger1Delay = 0U;

    /* DE - DMA enable and trigger source */
    config->sDmaConfig.bEnableDmaA = false;
    config->sDmaConfig.eDmaSourceA = kDUALADC_DmaSrcEndOfScan;
    config->sDmaConfig.bEnableDmaB = false;
    config->sDmaConfig.eDmaSourceB = kDUALADC_DmaSrcEndOfScan;

    /* Sequence and feature configuration applied by DUALADC_Init. */
    for (uint16_t u16CmdIndex = 0U; u16CmdIndex < (uint16_t)DUALADC_CMD_COUNT; u16CmdIndex++)
    {
        DUALADC_GetDefaultConversionCommandConfig(&config->sConvCmdConfig[u16CmdIndex]);
    }

    config->u32InterruptMask      = 0UL;
    config->u32ResultReadyIntMask = 0UL;
    config->u32CompareIntMask     = 0UL;

    config->bEnableAdc            = true;

    /* Average-with-timer defaults (disabled). */
    DUALADC_GetDefaultAverageTimerConfig(&config->sAvgtConfig);
}

/*!
 * @brief Initialize the DualADC module.
 *
 * @param base   DualADC peripheral base address.
 * @param config Pointer to the initialization configuration.
 * @retval kStatus_Success           Initialization succeeded.
 * @retval kStatus_InvalidArgument   @p base is not a valid DualADC peripheral address.
 */
status_t DUALADC_Init(DUALADC_Type *base, const dualadc_config_t *config)
{
    assert(NULL != config);

    uint32_t u32Instance = DUALADC_GetInstance(base);
    uint32_t u32Reg;

    if (u32Instance >= ARRAY_SIZE(s_dualadcBases))
    {
        return kStatus_InvalidArgument;
    }

#if !(defined(FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL) && FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL)
    /* Ungate the DualADC submodule clock. */
    CLOCK_EnableClock(s_dualadcClocks[u32Instance]);
#endif

#if defined(DUALADC_RESETS_ARRAY)
    RESET_ReleasePeripheralReset(s_dualadcResets[u32Instance]);
#endif

    /* Disable the module before setting configuration. */
    base->CTRL &= ~DUALADC_CTRL_ADCEN_MASK;

    /* Assert the software reset for ADCA and ADCB. */
    base->CTRL |= (DUALADC_CTRL_RSTA_MASK | DUALADC_CTRL_RSTB_MASK);

    /* Add a short delay to ensure reset completion. */
    for (uint32_t u32Index = 0; u32Index < DUALADC_RESET_DELAY; u32Index++)
    {
        __NOP();
    }

    /* Release the software reset for ADCA and ADCB. */
    base->CTRL &= ~(DUALADC_CTRL_RSTA_MASK | DUALADC_CTRL_RSTB_MASK);

    /* Configure CFG0: conversion mode, power, analog pre-enable, voltage reference, power-up delay, trigger source. */
    u32Reg = base->CFG0;
    u32Reg &= ~(DUALADC_CFG0_INDEP_MASK | DUALADC_CFG0_TRIGSEL_MASK | DUALADC_CFG0_PWRSEL_MASK |
                DUALADC_CFG0_PWREN_MASK | DUALADC_CFG0_REFSEL_MASK | DUALADC_CFG0_PUDLY_MASK);
    u32Reg |= DUALADC_CFG0_INDEP(config->eConversionMode) |
              DUALADC_CFG0_PWRSEL(config->ePowerConfig) |
              DUALADC_CFG0_REFSEL(config->eRefVoltageSource) |
              DUALADC_CFG0_PUDLY(config->u8PowerUpDelayCount) |
              DUALADC_CFG0_TRIGSEL(config->eTriggerSource);
    u32Reg |= config->bEnableAnalogPreEnable ? DUALADC_CFG0_PWREN_MASK : 0U;
    base->CFG0 = u32Reg;

    /* Configure CFG1: result justification, high-speed mode, extra cycle, tune mode. */
    u32Reg = base->CFG1;
    u32Reg &= ~(DUALADC_CFG1_JLEFT_MASK | DUALADC_CFG1_HS_MASK | DUALADC_CFG1_HSEXTRA_MASK |
                DUALADC_CFG1_TUNE_MASK);
    u32Reg |= DUALADC_CFG1_TUNE(config->eTuneMode);
    u32Reg |= config->bEnableLeftJustify ? DUALADC_CFG1_JLEFT_MASK : 0U;
    u32Reg |= config->bEnableHighSpeedMode ? DUALADC_CFG1_HS_MASK : 0U;
    u32Reg |= config->bEnableHighSpeedExtra ? DUALADC_CFG1_HSEXTRA_MASK : 0U;
    base->CFG1 = u32Reg;

    /*
     * Configure CTRL: doze behavior, calibration sample time, calibration averages.
     * Calibration request bits (CAL_REQ, CALOFS, CALHS) are left at zero; ADCEN is excluded here.
     */
    u32Reg = base->CTRL;
    u32Reg &= ~(DUALADC_CTRL_DOZEN_MASK | DUALADC_CTRL_CST_LONG_MASK | DUALADC_CTRL_CAL_AVGS_MASK);
    u32Reg |= DUALADC_CTRL_CAL_AVGS(config->eCalibrationAverages);
    u32Reg |= config->bEnableDoze ? DUALADC_CTRL_DOZEN_MASK : 0U;
    u32Reg |= config->bEnableLongCalSampleTime ? DUALADC_CTRL_CST_LONG_MASK : 0U;
    base->CTRL = u32Reg;

    /* Configure PAUSE, trigger control and DMA through their dedicated helpers. */
    DUALADC_ConfigPause(base, &config->sPauseConfig);
    DUALADC_ConfigTriggerControl(base, &config->sTriggerConfig);
    DUALADC_ConfigDma(base, &config->sDmaConfig);

    /* Configure the average-with-timer feature. */
    DUALADC_ConfigAverageTimer(base, &config->sAvgtConfig);

    /*
     * Program the whole conversion command sequence in one shot. Every command buffer entry
     * (DUALADC_CMD_COUNT total) is written; each entry carries its own CDIS (u32DisableCommand) bit,
     * so the caller marks the terminating command directly in the array to end the scan.
     */
    for (uint16_t u16CmdIndex = 0U; u16CmdIndex < (uint16_t)DUALADC_CMD_COUNT; u16CmdIndex++)
    {
        /* Command buffer index is 1-based in DUALADC_ConfigConversionCommand. */
        DUALADC_ConfigConversionCommand(base, (uint32_t)u16CmdIndex + 1UL,
                                        &config->sConvCmdConfig[u16CmdIndex]);
    }

    /* Enable the configured interrupts. */
    if (config->u32InterruptMask != 0UL)
    {
        DUALADC_EnableInterrupts(base, config->u32InterruptMask);
    }
    if (config->u32ResultReadyIntMask != 0UL)
    {
        DUALADC_EnableResultReadyInterrupts(base, config->u32ResultReadyIntMask);
    }
    if (config->u32CompareIntMask != 0UL)
    {
        DUALADC_EnableCompareInterrupts(base, config->u32CompareIntMask);
    }

    /* Optionally enable the ADC as the final initialization step. */
    if (config->bEnableAdc)
    {
        base->CTRL |= DUALADC_CTRL_ADCEN_MASK;
    }

    return kStatus_Success;
}

/*!
 * @brief Deinitialize the DualADC module.
 *
 * @param base DualADC peripheral base address.
 * @retval kStatus_Success           Deinitialization succeeded.
 * @retval kStatus_InvalidArgument   @p base is not a valid DualADC peripheral address.
 */
status_t DUALADC_DeInit(DUALADC_Type *base)
{
    uint32_t u32Instance = DUALADC_GetInstance(base);

    if (u32Instance >= ARRAY_SIZE(s_dualadcBases))
    {
        /* Invalid u32Instance, do not attempt to deinitialize */
        return kStatus_InvalidArgument;
    }

#if !(defined(FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL) && FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL)
    /* Gate the DualADC submodule clock. */
    CLOCK_DisableClock(s_dualadcClocks[u32Instance]);
#endif

#if defined(DUALADC_RESETS_ARRAY)
    RESET_PeripheralReset(s_dualadcResets[u32Instance]);
#endif

    return kStatus_Success;
}

/*!
 * @brief Populate a dualadc_cmd_config_t with reset-state defaults.
 *
 * @param config Pointer to the command configuration structure to populate.
 */
void DUALADC_GetDefaultConversionCommandConfig(dualadc_cmd_config_t *config)
{
    assert(NULL != config);

    config->u32ConversionType    = (uint32_t)kDUALADC_ConversionSingleEndedA;
    config->u32ResolutionMode    = (uint32_t)kDUALADC_ResolutionStandard;
    config->u32SampleTimeMode    = (uint32_t)kDUALADC_SampleTime3_5;
    config->u32HardwareAverages  = (uint32_t)kDUALADC_HardwareAverageSingle;
    config->u32ChannelNumber     = 0U;
    config->u32EnableAltBChannel = (uint32_t)false;
    config->u32AltBChannelNumber = 0U;
    config->u32EnableCompare     = (uint32_t)false;
    config->u32EnableWaitTrigger = (uint32_t)false;
    config->u32DisableCommand    = (uint32_t)false;
    config->u16CompareValueHigh  = 0U;
    config->u16CompareValueLow   = 0U;
}

/*!
 * @brief Configure a DualADC conversion command buffer entry.
 *
 * @param base DualADC peripheral base address.
 * @param index Command buffer index, range 1-20 (maps to CMD[0]-CMD[19]).
 * @param config Pointer to the command configuration.
 */
void DUALADC_ConfigConversionCommand(DUALADC_Type *base, uint32_t index, const dualadc_cmd_config_t *config)
{
    assert(NULL != config);
    assert(index >= 1U && index <= DUALADC_CMD_COUNT);

    uint32_t u32Reg;

    index--; /* Convert to zero-based index for CMD/CV arrays. */

    /*
     * Configure CMD register via read-modify-write, including the CDIS sequence-terminator bit.
     * The command configuration structure uses bit-fields that mirror the CMD register layout,
     * so each field is read directly from the structure and re-encoded through the register macros.
     */
    u32Reg = base->CMD[index];
    u32Reg &= ~(DUALADC_CMD_CMPEN_MASK | DUALADC_CMD_WAIT_TRIG_MASK | DUALADC_CMD_CTYPE_MASK |
                DUALADC_CMD_MODE_MASK | DUALADC_CMD_CDIS_MASK | DUALADC_CMD_STS_MASK |
                DUALADC_CMD_AVGS_MASK | DUALADC_CMD_ADCH_MASK | DUALADC_CMD_ALTB_ADCH_MASK |
                DUALADC_CMD_ALTB_EN_MASK);
    u32Reg |= DUALADC_CMD_CTYPE(config->u32ConversionType) |
              DUALADC_CMD_MODE(config->u32ResolutionMode) |
              DUALADC_CMD_STS(config->u32SampleTimeMode) |
              DUALADC_CMD_AVGS(config->u32HardwareAverages) |
              DUALADC_CMD_ADCH(config->u32ChannelNumber) |
              DUALADC_CMD_ALTB_ADCH(config->u32AltBChannelNumber);
    u32Reg |= (config->u32EnableAltBChannel != 0U) ? DUALADC_CMD_ALTB_EN_MASK : 0UL;
    u32Reg |= (config->u32EnableCompare != 0U) ? DUALADC_CMD_CMPEN_MASK : 0UL;
    u32Reg |= (config->u32EnableWaitTrigger != 0U) ? DUALADC_CMD_WAIT_TRIG_MASK : 0UL;
    u32Reg |= (config->u32DisableCommand != 0U) ? DUALADC_CMD_CDIS_MASK : 0UL;
    base->CMD[index] = u32Reg;

    /* Write compare values to the corresponding CV register when compare is enabled. */
    if (config->u32EnableCompare != 0U)
    {
        assert(index < DUALADC_CV_COUNT);
        base->CV[index] = DUALADC_CV_CVL(config->u16CompareValueLow) | DUALADC_CV_CVH(config->u16CompareValueHigh);
    }
}

/*!
 * @brief Populate a dualadc_avgt_config_t with reset-state defaults.
 *
 * @param config Pointer to the configuration structure to populate.
 */
void DUALADC_GetDefaultAverageTimerConfig(dualadc_avgt_config_t *config)
{
    assert(NULL != config);

    config->bEnableAvgTimerA = false;
    config->u16RepeatCountA  = 1U;
    config->u16IntervalA     = 0U;
    config->ePrescalerA      = kDUALADC_AvgtPrescaler1;
    config->bEnableAvgTimerB = false;
    config->u16RepeatCountB  = 1U;
    config->u16IntervalB     = 0U;
    config->ePrescalerB      = kDUALADC_AvgtPrescaler1;
}

/*!
 * @brief Configure the average-with-timer feature.
 *
 * @param base   DualADC peripheral base address.
 * @param config Pointer to the average-with-timer configuration.
 */
void DUALADC_ConfigAverageTimer(DUALADC_Type *base, const dualadc_avgt_config_t *config)
{
    assert(NULL != config);
    assert(config->u16RepeatCountA >= 1U && config->u16RepeatCountA <= 512U);
    assert(config->u16RepeatCountB >= 1U && config->u16RepeatCountB <= 512U);

    uint32_t u32Reg;

    /* Configure AVGT_CTRL: enable flags and repeat counts for ADCA and ADCB. */
    u32Reg = base->AVGT_CTRL;
    u32Reg &= ~(DUALADC_AVGT_CTRL_AVGTA_EN_MASK | DUALADC_AVGT_CTRL_AVGTA_TIMES_MASK |
                DUALADC_AVGT_CTRL_AVGTB_EN_MASK | DUALADC_AVGT_CTRL_AVGTB_TIMES_MASK);
    u32Reg |= DUALADC_AVGT_CTRL_AVGTA_TIMES((uint32_t)config->u16RepeatCountA - 1UL) |
              DUALADC_AVGT_CTRL_AVGTB_TIMES((uint32_t)config->u16RepeatCountB - 1UL);
    u32Reg |= config->bEnableAvgTimerA ? DUALADC_AVGT_CTRL_AVGTA_EN_MASK : 0U;
    u32Reg |= config->bEnableAvgTimerB ? DUALADC_AVGT_CTRL_AVGTB_EN_MASK : 0U;
    base->AVGT_CTRL = u32Reg;

    /* Configure ITCFG: interval counts and prescalers for ADCA and ADCB. */
    u32Reg = base->ITCFG;
    u32Reg &= ~(DUALADC_ITCFG_PRESCALERA_MASK | DUALADC_ITCFG_INTERVALA_MASK |
                DUALADC_ITCFG_PRESCALERB_MASK | DUALADC_ITCFG_INTERVALB_MASK);
    u32Reg |= DUALADC_ITCFG_PRESCALERA(config->ePrescalerA) |
              DUALADC_ITCFG_INTERVALA(config->u16IntervalA) |
              DUALADC_ITCFG_PRESCALERB(config->ePrescalerB) |
              DUALADC_ITCFG_INTERVALB(config->u16IntervalB);
    base->ITCFG = u32Reg;
}

/*!
 * @brief Configure the conversion pause register (PAUSE).
 *
 * @param base     DualADC peripheral base address.
 * @param psConfig Pointer to the pause configuration.
 */
void DUALADC_ConfigPause(DUALADC_Type *base, const dualadc_pause_config_t *psConfig)
{
    assert(NULL != psConfig);

    uint32_t u32Reg;

    /* Configure PAUSE; this must be done before CTRL[ADCEN] is asserted. */
    u32Reg = base->PAUSE;
    u32Reg &= ~(DUALADC_PAUSE_PAUSEEN_MASK | DUALADC_PAUSE_PAUSEDLY_MASK);
    u32Reg |= psConfig->bEnableConversionPause ? DUALADC_PAUSE_PAUSEEN_MASK : 0UL;
    u32Reg |= DUALADC_PAUSE_PAUSEDLY(psConfig->u16ConversionPauseDelay);
    base->PAUSE = u32Reg;
}

/*!
 * @brief Configure the trigger control register (TCTRL).
 *
 * @param base     DualADC peripheral base address.
 * @param psConfig Pointer to the trigger control configuration.
 */
void DUALADC_ConfigTriggerControl(DUALADC_Type *base, const dualadc_trigger_config_t *psConfig)
{
    assert(NULL != psConfig);

    uint32_t u32Reg;

    /* Configure TCTRL: hardware trigger enable and trigger delay for Trigger0 and Trigger1. */
    u32Reg = base->TCTRL;
    u32Reg &= ~(DUALADC_TCTRL_HTEN0_MASK | DUALADC_TCTRL_TDLY0_MASK |
                DUALADC_TCTRL_HTEN1_MASK | DUALADC_TCTRL_TDLY1_MASK);
    u32Reg |= DUALADC_TCTRL_TDLY0(psConfig->u8Trigger0Delay) |
              DUALADC_TCTRL_TDLY1(psConfig->u8Trigger1Delay);
    u32Reg |= psConfig->bEnableHardwareTrigger0 ? DUALADC_TCTRL_HTEN0_MASK : 0UL;
    u32Reg |= psConfig->bEnableHardwareTrigger1 ? DUALADC_TCTRL_HTEN1_MASK : 0UL;
    base->TCTRL = u32Reg;
}

/*!
 * @brief Configure the DMA enable and DMA trigger source register (DE).
 *
 * @param base     DualADC peripheral base address.
 * @param psConfig Pointer to the DMA configuration.
 */
void DUALADC_ConfigDma(DUALADC_Type *base, const dualadc_dma_config_t *psConfig)
{
    assert(NULL != psConfig);

    uint32_t u32Reg;

    /* Configure DE: DMA enable and trigger source for ADCA and ADCB. */
    u32Reg = base->DE;
    u32Reg &= ~(DUALADC_DE_DMAENAA_MASK | DUALADC_DE_DMASRCA_MASK |
                DUALADC_DE_DMAENAB_MASK | DUALADC_DE_DMASRCB_MASK);
    u32Reg |= DUALADC_DE_DMASRCA(psConfig->eDmaSourceA) | DUALADC_DE_DMASRCB(psConfig->eDmaSourceB);
    u32Reg |= psConfig->bEnableDmaA ? DUALADC_DE_DMAENAA_MASK : 0UL;
    u32Reg |= psConfig->bEnableDmaB ? DUALADC_DE_DMAENAB_MASK : 0UL;
    base->DE = u32Reg;
}

/*!
 * @brief Calculate the gain calculation result from the gain calibration value.
 *
 * Gain_Adj = 131072 / (131072 - u32GainCalValue), encoded into the 17-bit GCR register field as Q1.16.
 *
 * @param u32GainCalValue Raw gain calibration value read from the GCC register.
 * @return Gain adjustment calculation result to be written into the GCR register.
 */
static uint32_t DUALADC_CalculateGainResult(uint32_t u32GainCalValue)
{
    uint32_t u32GainConvResult;
    int32_t i32Denominator;
    int32_t i32SignedGainCalValue;
    uint32_t u32SignedGainCalValue;

    /*
     * Sign-extend bit 15 to fill bits [31:16]. Perform the sign-extend arithmetic entirely in
     * unsigned domain first, store the result in a single unsigned object, then cast that single
     * object (not a composite expression) to signed.
     */
    u32SignedGainCalValue = (u32GainCalValue ^ 0x8000UL) - 0x8000UL;
    i32SignedGainCalValue = (int32_t)u32SignedGainCalValue;
    i32Denominator = 131072L - i32SignedGainCalValue;

    /*
     * Fixed point formula equivalent to 131072.0 / (131072.0 - gainCalValue).
     * Numerator is 131072 * 16384 = 2147483648 exactly; uint32_t division yields Q17.14.
     * Shifting left by 2 converts it to the Q1.16 encoding of the 17-bit GCR field; its two
     * LSBs stay zero.
     */
    u32GainConvResult = 2147483648UL / (uint32_t)i32Denominator; /* Q17.14 */

    return ((u32GainConvResult << 2UL) & 0x1FFFFUL);   /* Q1.16 */
}

/*!
 * @brief Perform all DualADC calibration routines.
 *
 * Must be called after @ref DUALADC_Enable to ensure ADC enabled.
 *
 * @param base DualADC peripheral base address.
 * @retval kStatus_Success  All calibration steps completed successfully.
 * @retval kStatus_Timeout  A calibration poll loop exceeded @ref DUALADC_CALIBRATION_TIMEOUT
 *                          iterations (only possible when the u32Timeout is non-zero).
 */
status_t DUALADC_DoCalibration(DUALADC_Type *base)
{
    uint32_t u32Gcca;
    uint32_t u32Gccb;
    uint32_t u32Gcra;
    uint32_t u32Gcrb;
#if DUALADC_CALIBRATION_TIMEOUT
    uint32_t u32Timeout;
#endif
    bool bAdcEnabled = ((base->CTRL & DUALADC_CTRL_ADCEN_MASK) != 0U);

    /* Enable ADC before calibration routines. */
    if (!bAdcEnabled)
    {
        base->CTRL |= DUALADC_CTRL_ADCEN_MASK;
    }

    /* Step 1: Offset calibration - hardware updates OFSTRIM automatically. */
    base->CTRL |= DUALADC_CTRL_CALOFS_MASK;
#if DUALADC_CALIBRATION_TIMEOUT
    u32Timeout = DUALADC_CALIBRATION_TIMEOUT;
#endif
    while ((base->STAT0 & DUALADC_STAT0_CAL_RDY_MASK) == 0U)
    {
#if DUALADC_CALIBRATION_TIMEOUT
        if (--u32Timeout == 0U)
        {
            return kStatus_Timeout;
        }
#endif
    }

    /* Wait 2 ADC clock cycles after STAT0[CAL_RDY] is set. */
    for (uint32_t u32Index = 0; u32Index < DUALADC_CAL_RDY_DELAY; u32Index++)
    {
        __NOP();
    }

    /* Step 2: High-speed calibration - only required when CFG1[HS] is set. */
    if ((base->CFG1 & DUALADC_CFG1_HS_MASK) != 0U)
    {
        base->CTRL |= DUALADC_CTRL_CALHS_MASK;
#if DUALADC_CALIBRATION_TIMEOUT
        u32Timeout = DUALADC_CALIBRATION_TIMEOUT;
#endif
        while ((base->STAT0 & DUALADC_STAT0_CAL_RDY_MASK) == 0U)
        {
#if DUALADC_CALIBRATION_TIMEOUT
            if (--u32Timeout == 0U)
            {
                return kStatus_Timeout;
            }
#endif
        }
    }

    /* Wait 2 ADC clock cycles after STAT0[CAL_RDY] is set. */
    for (uint32_t u32Index = 0; u32Index < DUALADC_CAL_RDY_DELAY; u32Index++)
    {
        __NOP();
    }

    /* Step 3: Gain and linearity calibration. */
    /* Initiate calibration; CAL_REQ auto-clears when accepted by hardware. */
    base->CTRL |= DUALADC_CTRL_CAL_REQ_MASK;

    /* Wait for hardware to complete ADCA and ADCB gain calibration. */
#if DUALADC_CALIBRATION_TIMEOUT
    u32Timeout = DUALADC_CALIBRATION_TIMEOUT;
#endif
    while (((base->GCC[0] & DUALADC_GCC_RDY_MASK) == 0U) || ((base->GCC[1] & DUALADC_GCC_RDY_MASK) == 0U))
    {
#if DUALADC_CALIBRATION_TIMEOUT
        if (--u32Timeout == 0U)
        {
            return kStatus_Timeout;
        }
#endif
    }

    /* Read u32Raw GAIN_CAL from the GCC register. */
    u32Gcca = (base->GCC[0] & DUALADC_GCC_GAIN_CAL_MASK) >> DUALADC_GCC_GAIN_CAL_SHIFT;
    u32Gccb = (base->GCC[1] & DUALADC_GCC_GAIN_CAL_MASK) >> DUALADC_GCC_GAIN_CAL_SHIFT;

    u32Gcra = DUALADC_CalculateGainResult(u32Gcca);
    u32Gcrb = DUALADC_CalculateGainResult(u32Gccb);

    /* Calculate gain adjustment and write 17-bit fixed-point result to GCR. */
    base->GCR[0] = (u32Gcra | DUALADC_GCR_RDY_MASK);
    base->GCR[1] = (u32Gcrb | DUALADC_GCR_RDY_MASK);

    /* Wait for final CAL_RDY to confirm full calibration is complete. */
#if DUALADC_CALIBRATION_TIMEOUT
    u32Timeout = DUALADC_CALIBRATION_TIMEOUT;
#endif
    while ((base->STAT0 & DUALADC_STAT0_CAL_RDY_MASK) == 0U)
    {
#if DUALADC_CALIBRATION_TIMEOUT
        if (--u32Timeout == 0U)
        {
            return kStatus_Timeout;
        }
#endif
    }

    /* Wait 2 ADC clock cycles after STAT0[CAL_RDY] is set. */
    for (uint32_t u32Index = 0; u32Index < DUALADC_CAL_RDY_DELAY; u32Index++)
    {
        __NOP();
    }

    /* Restore ADC enable state after calibration routines. */
    if (!bAdcEnabled)
    {
        base->CTRL &= ~DUALADC_CTRL_ADCEN_MASK;
    }

    return kStatus_Success;
}

/*!
 * @brief Restore calibration registers from a previously saved calibration value structure.
 *
 * @param base DualADC peripheral base address.
 * @param ptrCalibrationValue Pointer to the calibration value structure.
 */
void DUALADC_SetCalibrationValue(DUALADC_Type *base, const dualadc_calibration_value_t *ptrCalibrationValue)
{
    assert(NULL != ptrCalibrationValue);

    uint32_t u32Index;
    bool bAdcEnabled = ((base->CTRL & DUALADC_CTRL_ADCEN_MASK) != 0U);

    /* Disable ADC to make calibration registers read write accessible. */
    if (bAdcEnabled)
    {
        base->CTRL &= ~DUALADC_CTRL_ADCEN_MASK;
    }

    /* Restore offset trim values for ADCA and ADCB. */
    base->OFSTRIM = DUALADC_OFSTRIM_OFSTRIMA(ptrCalibrationValue->u16OffsetTrimA) |
                    DUALADC_OFSTRIM_OFSTRIMB(ptrCalibrationValue->u16OffsetTrimB);

    /* Restore high-speed trim values for ADCA and ADCB. */
    base->HSTRIM = DUALADC_HSTRIM_HSTRIMA(ptrCalibrationValue->u16HighSpeedTrimA) |
                   DUALADC_HSTRIM_HSTRIMB(ptrCalibrationValue->u16HighSpeedTrimB);

    /* Restore linearity calibration tables for ADCA and ADCB. */
    for (u32Index = 0U; u32Index < (uint32_t)DUALADC_CAL_GAR_COUNT; u32Index++)
    {
        base->CAL_GAR[u32Index] = ptrCalibrationValue->u16CalGar[u32Index];
        base->CAL_GBR[u32Index] = ptrCalibrationValue->u16CalGbr[u32Index];
    }

    /* Restore gain calibration results and mark them valid so hardware uses them. */
    base->GCR[0] = DUALADC_GCR_GCALR(ptrCalibrationValue->u32Gcalr[0]) | DUALADC_GCR_RDY_MASK;
    base->GCR[1] = DUALADC_GCR_GCALR(ptrCalibrationValue->u32Gcalr[1]) | DUALADC_GCR_RDY_MASK;

    if (bAdcEnabled)
    {
        base->CTRL |= DUALADC_CTRL_ADCEN_MASK;
    }
}

/*!
 * @brief Read back the current calibration registers into a calibration value structure.
 *
 * @param base DualADC peripheral base address.
 * @param ptrCalibrationValue Pointer to the calibration value structure to populate.
 */
void DUALADC_GetCalibrationValue(DUALADC_Type *base, dualadc_calibration_value_t *ptrCalibrationValue)
{
    assert(NULL != ptrCalibrationValue);

    uint32_t u32Index;
    bool bAdcEnabled = ((base->CTRL & DUALADC_CTRL_ADCEN_MASK) != 0U);

    /* Disable ADC to make calibration registers read write accessible. */
    if (bAdcEnabled)
    {
        base->CTRL &= ~DUALADC_CTRL_ADCEN_MASK;
    }

    /* Read back offset trim values for ADCA and ADCB. */
    ptrCalibrationValue->u16OffsetTrimA =
        (uint16_t)((base->OFSTRIM & DUALADC_OFSTRIM_OFSTRIMA_MASK) >> DUALADC_OFSTRIM_OFSTRIMA_SHIFT);
    ptrCalibrationValue->u16OffsetTrimB =
        (uint16_t)((base->OFSTRIM & DUALADC_OFSTRIM_OFSTRIMB_MASK) >> DUALADC_OFSTRIM_OFSTRIMB_SHIFT);

    /* Read back high-speed trim values for ADCA and ADCB. */
    ptrCalibrationValue->u16HighSpeedTrimA =
        (uint16_t)((base->HSTRIM & DUALADC_HSTRIM_HSTRIMA_MASK) >> DUALADC_HSTRIM_HSTRIMA_SHIFT);
    ptrCalibrationValue->u16HighSpeedTrimB =
        (uint16_t)((base->HSTRIM & DUALADC_HSTRIM_HSTRIMB_MASK) >> DUALADC_HSTRIM_HSTRIMB_SHIFT);

    /* Read back linearity calibration tables for ADCA and ADCB. */
    for (u32Index = 0U; u32Index < (uint32_t)DUALADC_CAL_GAR_COUNT; u32Index++)
    {
        ptrCalibrationValue->u16CalGar[u32Index] =
            (uint16_t)(base->CAL_GAR[u32Index] & DUALADC_CAL_GAR_CAL_GAR_VAL_MASK);
        ptrCalibrationValue->u16CalGbr[u32Index] =
            (uint16_t)(base->CAL_GBR[u32Index] & DUALADC_CAL_GBR_CAL_GBR_VAL_MASK);
    }

    /* Read back gain calibration results; the RDY bit is excluded, only GCALR is kept. */
    ptrCalibrationValue->u32Gcalr[0] = (base->GCR[0] & DUALADC_GCR_GCALR_MASK) >> DUALADC_GCR_GCALR_SHIFT;
    ptrCalibrationValue->u32Gcalr[1] = (base->GCR[1] & DUALADC_GCR_GCALR_MASK) >> DUALADC_GCR_GCALR_SHIFT;

    if (bAdcEnabled)
    {
        base->CTRL |= DUALADC_CTRL_ADCEN_MASK;
    }
}
