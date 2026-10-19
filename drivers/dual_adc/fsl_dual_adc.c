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
 * Gain_Adj = 131072 / (131072 - gainCalValue), encoded into the 17-bit GCR register field as Q1.16.
 *
 * @param gainCalValue Raw gain calibration value read from the GCC register.
 * @return Gain adjustment calculation result to be written into the GCR register.
 */
static uint32_t DUALADC_CalculateGainResult(uint32_t gainCalValue);

/*******************************************************************************
 * Variables
 ******************************************************************************/

/*! @brief Array to map DualADC instance number to base pointer. */
static DUALADC_Type *const s_dualadcBases[] = DUALADC_BASE_PTRS;

#if !(defined(FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL) && FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL)
/*! @brief Pointers to DualADC clocks for each DualADC submodule. */
static const clock_ip_name_t s_dualadcClocks[] = ADC_CLOCKS;
#endif /* FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL */

#if defined(DUALADC_RESETS_ARRAY)
/* Reset array */
static const reset_ip_name_t s_dualadcResets[] = DUALADC_RESETS_ARRAY;
#endif

/*******************************************************************************
 * Code
 ******************************************************************************/
/*!
 * @brief Get the instance for DualADC module.
 *
 * @param base DualADC base address
 * @return Instance number if valid base address is provided, otherwise returns 0xFFFFFFFF
 */
uint32_t DUALADC_GetInstance(DUALADC_Type *base)
{
    uint32_t instance;

    /* Find the instance index from base address mappings. */
    for (instance = 0; instance < ARRAY_SIZE(s_dualadcBases); instance++)
    {
        if (MSDK_REG_NONSECURE_ADDR(s_dualadcBases[instance]) == MSDK_REG_NONSECURE_ADDR(base))
        {
            break;
        }
    }

    if (instance == ARRAY_SIZE(s_dualadcBases))
    {
        instance = 0xFFFFFFFFU; /* Return 0xFFFFFFFF if invalid base address is provided. */
    }

    return instance;
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
    config->conversionMode          = kDUALADC_CooperationMode;
    config->powerConfig             = kDUALADC_LowPowerConfig;
    config->enableAnalogPreEnable   = false;
    config->refVoltageSource        = kDUALADC_VrefH0;
    config->powerUpDelayCount       = 0x80U;
    config->triggerSource           = kDUALADC_TrigSelTrigger0;

    /* CFG1 - Configuration 1 Register */
    config->enableLeftJustify       = false;
    config->enableHighSpeedMode     = false;
    config->enableHighSpeedExtra    = false;
    config->tuneMode                = kDUALADC_TuneMode1;

    /* CTRL - Control Register */
    config->enableDoze              = false;
    config->enableLongCalSampleTime = false;
    config->calibrationAverages     = kDUALADC_CalibrationAverage256;

    /* PAUSE - Pause Register */
    config->enableConversionPause   = false;
    config->conversionPauseDelay    = 0U;

    /* TCTRL - Trigger Control Register */
    config->enableHardwareTrigger0  = false;
    config->hardwareTrigger0Delay   = 0U;
    config->enableHardwareTrigger1  = false;
    config->hardwareTrigger1Delay   = 0U;

    /* DE - DMA enable and trigger source */
    config->enableDmaA              = false;
    config->dmaSourceA              = kDUALADC_DmaSrcEndOfScan;
    config->enableDmaB              = false;
    config->dmaSourceB              = kDUALADC_DmaSrcEndOfScan;
}

/*!
 * @brief Initialize the DualADC module.
 *
 * @param base   DualADC peripheral base address.
 * @param config Pointer to the initialization configuration.
 * @retval kStatus_Success           Initialization succeeded.
 * @retval kStatus_InvalidArgument   @p base is not a valid DualADC peripheral address.
 * @retval kStatus_Timeout           Reset operation times out.
 */
status_t DUALADC_Init(DUALADC_Type *base, const dualadc_config_t *config)
{
    assert(NULL != config);

    uint32_t instance = DUALADC_GetInstance(base);
    uint32_t reg;

    if (instance >= ARRAY_SIZE(s_dualadcBases))
    {
        return kStatus_InvalidArgument;
    }

#if !(defined(FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL) && FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL)
    /* Ungate the DualADC submodule clock. */
    CLOCK_EnableClock(s_dualadcClocks[instance]);
#endif

#if defined(DUALADC_RESETS_ARRAY)
    RESET_ReleasePeripheralReset(s_dualadcResets[instance]);
#endif

    base->CTRL |= (DUALADC_CTRL_RSTA_MASK | DUALADC_CTRL_RSTB_MASK);

    /* Add a short delay to ensure reset completion. */
    for (uint32_t i = 0; i < DUALADC_RESET_TIMEOUT; i++)
    {
        __NOP();
    }

    base->CTRL &= ~(DUALADC_CTRL_RSTA_MASK | DUALADC_CTRL_RSTB_MASK);

    /* Disable the module before setting configuration. */
    base->CTRL &= ~DUALADC_CTRL_ADCEN_MASK;

    /* Configure CFG0: conversion mode, power, analog pre-enable, voltage reference, power-up delay, trigger source. */
    reg = base->CFG0;
    reg &= ~(DUALADC_CFG0_INDEP_MASK | DUALADC_CFG0_TRIGSEL_MASK | DUALADC_CFG0_PWRSEL_MASK |
             DUALADC_CFG0_PWREN_MASK | DUALADC_CFG0_REFSEL_MASK | DUALADC_CFG0_PUDLY_MASK);
    reg |= DUALADC_CFG0_INDEP(config->conversionMode) |
           DUALADC_CFG0_PWRSEL(config->powerConfig) |
           DUALADC_CFG0_REFSEL(config->refVoltageSource) |
           DUALADC_CFG0_PUDLY(config->powerUpDelayCount) |
           DUALADC_CFG0_TRIGSEL(config->triggerSource);
    reg |= config->enableAnalogPreEnable ? DUALADC_CFG0_PWREN_MASK : 0U;
    base->CFG0 = reg;

    /* Configure CFG1: result justification, high-speed mode, extra cycle, tune mode. */
    reg = base->CFG1;
    reg &= ~(DUALADC_CFG1_JLEFT_MASK | DUALADC_CFG1_HS_MASK | DUALADC_CFG1_HSEXTRA_MASK | DUALADC_CFG1_TUNE_MASK);
    reg |= DUALADC_CFG1_TUNE(config->tuneMode);
    reg |= config->enableLeftJustify ? DUALADC_CFG1_JLEFT_MASK : 0U;
    reg |= config->enableHighSpeedMode ? DUALADC_CFG1_HS_MASK : 0U;
    reg |= config->enableHighSpeedExtra ? DUALADC_CFG1_HSEXTRA_MASK : 0U;
    base->CFG1 = reg;

    /*
     * Configure CTRL: doze behavior, calibration sample time, calibration averages.
     * Calibration request bits (CAL_REQ, CALOFS, CALHS) are left at zero; ADCEN is excluded here.
     */
    reg = base->CTRL;
    reg &= ~(DUALADC_CTRL_DOZEN_MASK | DUALADC_CTRL_CST_LONG_MASK | DUALADC_CTRL_CAL_AVGS_MASK);
    reg |= DUALADC_CTRL_CAL_AVGS(config->calibrationAverages);
    reg |= config->enableDoze ? DUALADC_CTRL_DOZEN_MASK : 0U;
    reg |= config->enableLongCalSampleTime ? DUALADC_CTRL_CST_LONG_MASK : 0U;
    base->CTRL = reg;

    /* Configure PAUSE before ADCEN is asserted. */
    reg = base->PAUSE;
    reg &= ~(DUALADC_PAUSE_PAUSEEN_MASK | DUALADC_PAUSE_PAUSEDLY_MASK);
    reg |= config->enableConversionPause ? DUALADC_PAUSE_PAUSEEN_MASK : 0U;
    reg |= DUALADC_PAUSE_PAUSEDLY(config->conversionPauseDelay);
    base->PAUSE = reg;

    /* Configure TCTRL: hardware trigger enable and trigger delay for Trigger0 and Trigger1. */
    reg = base->TCTRL;
    reg &= ~(DUALADC_TCTRL_HTEN0_MASK | DUALADC_TCTRL_TDLY0_MASK |
             DUALADC_TCTRL_HTEN1_MASK | DUALADC_TCTRL_TDLY1_MASK);
    reg |= DUALADC_TCTRL_TDLY0(config->hardwareTrigger0Delay) |
           DUALADC_TCTRL_TDLY1(config->hardwareTrigger1Delay);
    reg |= config->enableHardwareTrigger0 ? DUALADC_TCTRL_HTEN0_MASK : 0U;
    reg |= config->enableHardwareTrigger1 ? DUALADC_TCTRL_HTEN1_MASK : 0U;
    base->TCTRL = reg;

    /* Configure DE: DMA enable and trigger source for ADCA and ADCB. */
    reg = base->DE;
    reg &= ~(DUALADC_DE_DMAENAA_MASK | DUALADC_DE_DMASRCA_MASK |
             DUALADC_DE_DMAENAB_MASK | DUALADC_DE_DMASRCB_MASK);
    reg |= DUALADC_DE_DMASRCA(config->dmaSourceA) | DUALADC_DE_DMASRCB(config->dmaSourceB);
    reg |= config->enableDmaA ? DUALADC_DE_DMAENAA_MASK : 0U;
    reg |= config->enableDmaB ? DUALADC_DE_DMAENAB_MASK : 0U;
    base->DE = reg;

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
    uint32_t instance = DUALADC_GetInstance(base);

    if (instance >= ARRAY_SIZE(s_dualadcBases))
    {
        /* Invalid instance, do not attempt to deinitialize */
        return kStatus_InvalidArgument;
    }

#if !(defined(FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL) && FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL)
    /* Gate the DualADC submodule clock. */
    CLOCK_DisableClock(s_dualadcClocks[instance]);
#endif

#if defined(DUALADC_RESETS_ARRAY)
    RESET_PeripheralReset(s_dualadcResets[instance]);
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

    config->conversionType    = kDUALADC_ConversionSingleEndedA;
    config->resolutionMode    = kDUALADC_ResolutionStandard;
    config->sampleTimeMode    = kDUALADC_SampleTime3_5;
    config->hardwareAverages  = kDUALADC_HardwareAverageSingle;
    config->channelNumber     = 0U;
    config->enableAltBChannel = false;
    config->altBChannelNumber = 0U;
    config->enableCompare     = false;
    config->compareValueHigh  = 0U;
    config->compareValueLow   = 0U;
    config->enableWaitTrigger = false;
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

    uint32_t reg;

    index--; /* Convert to zero-based index for CMD/CV arrays. */

    /* Configure CMD register via read-modify-write; CDIS is excluded and managed separately. */
    reg = base->CMD[index];
    reg &= ~(DUALADC_CMD_CMPEN_MASK | DUALADC_CMD_WAIT_TRIG_MASK | DUALADC_CMD_CTYPE_MASK |
             DUALADC_CMD_MODE_MASK | DUALADC_CMD_STS_MASK | DUALADC_CMD_AVGS_MASK |
             DUALADC_CMD_ADCH_MASK | DUALADC_CMD_ALTB_ADCH_MASK | DUALADC_CMD_ALTB_EN_MASK);
    reg |= DUALADC_CMD_CTYPE(config->conversionType) |
           DUALADC_CMD_MODE(config->resolutionMode) |
           DUALADC_CMD_STS(config->sampleTimeMode) |
           DUALADC_CMD_AVGS(config->hardwareAverages) |
           DUALADC_CMD_ADCH(config->channelNumber) |
           DUALADC_CMD_ALTB_ADCH(config->altBChannelNumber);
    reg |= config->enableAltBChannel ? DUALADC_CMD_ALTB_EN_MASK : 0U;
    reg |= config->enableCompare ? DUALADC_CMD_CMPEN_MASK : 0U;
    reg |= config->enableWaitTrigger ? DUALADC_CMD_WAIT_TRIG_MASK : 0U;
    base->CMD[index] = reg;

    /* Write compare values to the corresponding CV register when compare is enabled. */
    if (config->enableCompare)
    {
        assert(index < DUALADC_CV_COUNT);
        base->CV[index] = DUALADC_CV_CVL(config->compareValueLow) | DUALADC_CV_CVH(config->compareValueHigh);
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

    config->enableAvgTimerA = false;
    config->repeatCountA    = 1U;
    config->intervalA       = 0U;
    config->prescalerA      = kDUALADC_AvgtPrescaler1;
    config->enableAvgTimerB = false;
    config->repeatCountB    = 1U;
    config->intervalB       = 0U;
    config->prescalerB      = kDUALADC_AvgtPrescaler1;
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
    assert(config->repeatCountA >= 1U && config->repeatCountA <= 512U);
    assert(config->repeatCountB >= 1U && config->repeatCountB <= 512U);

    uint32_t reg;

    /* Configure AVGT_CTRL: enable flags and repeat counts for ADCA and ADCB. */
    reg = base->AVGT_CTRL;
    reg &= ~(DUALADC_AVGT_CTRL_AVGTA_EN_MASK | DUALADC_AVGT_CTRL_AVGTA_TIMES_MASK |
             DUALADC_AVGT_CTRL_AVGTB_EN_MASK | DUALADC_AVGT_CTRL_AVGTB_TIMES_MASK);
    reg |= DUALADC_AVGT_CTRL_AVGTA_TIMES((uint32_t)config->repeatCountA - 1UL) |
           DUALADC_AVGT_CTRL_AVGTB_TIMES((uint32_t)config->repeatCountB - 1UL);
    reg |= config->enableAvgTimerA ? DUALADC_AVGT_CTRL_AVGTA_EN_MASK : 0U;
    reg |= config->enableAvgTimerB ? DUALADC_AVGT_CTRL_AVGTB_EN_MASK : 0U;
    base->AVGT_CTRL = reg;

    /* Configure ITCFG: interval counts and prescalers for ADCA and ADCB. */
    reg = base->ITCFG;
    reg &= ~(DUALADC_ITCFG_PRESCALERA_MASK | DUALADC_ITCFG_INTERVALA_MASK |
             DUALADC_ITCFG_PRESCALERB_MASK | DUALADC_ITCFG_INTERVALB_MASK);
    reg |= DUALADC_ITCFG_PRESCALERA(config->prescalerA) |
           DUALADC_ITCFG_INTERVALA(config->intervalA) |
           DUALADC_ITCFG_PRESCALERB(config->prescalerB) |
           DUALADC_ITCFG_INTERVALB(config->intervalB);
    base->ITCFG = reg;
}

/*!
 * @brief Calculate the gain calculation result from the gain calibration value.
 *
 * Gain_Adj = 131072 / (131072 - gainCalValue), encoded into the 17-bit GCR register field as Q1.16.
 *
 * @param gainCalValue Raw gain calibration value read from the GCC register.
 * @return Gain adjustment calculation result to be written into the GCR register.
 */
static uint32_t DUALADC_CalculateGainResult(uint32_t gainCalValue)
{
    uint32_t gainConvResult;
    int32_t denominator;
    int32_t signedGainCalValue;
    uint32_t unsignedGainCalValue;

    /*
     * Sign-extend bit 15 to fill bits [31:16]. Perform the sign-extend arithmetic entirely in
     * unsigned domain first, store the result in a single unsigned object, then cast that single
     * object (not a composite expression) to signed.
     */
    unsignedGainCalValue = (gainCalValue ^ 0x8000UL) - 0x8000UL;
    signedGainCalValue   = (int32_t)unsignedGainCalValue;
    denominator = 131072 - signedGainCalValue;

    /*
     * Fixed point formula equivalent to 131072.0 / (131072.0 - gainCalValue).
     * Numerator is 131072 * 16384 = 2147483648 exactly; uint32_t division yields Q17.14.
     * Shifting left by 2 converts it to the Q1.16 encoding of the 17-bit GCR field; its two
     * LSBs stay zero.
     */
    gainConvResult = 2147483648UL / (uint32_t)denominator; /* Q17.14 */

    return ((gainConvResult << 2UL) & 0x1FFFFUL);   /* Q1.16 */
}

/*!
 * @brief Perform all DualADC calibration routines.
 *
 * Must be called after @ref DUALADC_Enable to ensure ADC enabled.
 *
 * @param base DualADC peripheral base address.
 * @retval kStatus_Success  All calibration steps completed successfully.
 * @retval kStatus_Timeout  A calibration poll loop exceeded @ref DUALADC_CALIBRATION_TIMEOUT
 *                          iterations (only possible when the timeout is non-zero).
 */
status_t DUALADC_DoCalibration(DUALADC_Type *base)
{
    uint32_t GCCa;
    uint32_t GCCb;
    uint32_t GCRa;
    uint32_t GCRb;
#if DUALADC_CALIBRATION_TIMEOUT
    uint32_t timeout;
#endif
    bool adcEnabled = ((base->CTRL & DUALADC_CTRL_ADCEN_MASK) != 0U);

    /* Enable ADC before calibration routines. */
    if (!adcEnabled)
    {
        base->CTRL |= DUALADC_CTRL_ADCEN_MASK;
    }

    /* Step 1: Offset calibration - hardware updates OFSTRIM automatically. */
    base->CTRL |= DUALADC_CTRL_CALOFS_MASK;
#if DUALADC_CALIBRATION_TIMEOUT
    timeout = DUALADC_CALIBRATION_TIMEOUT;
#endif
    while ((base->STAT0 & DUALADC_STAT0_CAL_RDY_MASK) == 0U)
    {
#if DUALADC_CALIBRATION_TIMEOUT
        if (--timeout == 0U)
        {
            return kStatus_Timeout;
        }
#endif
    }

    /* Wait 2 ADC clock cycles after STAT0[CAL_RDY] is set. */
    for (uint32_t i = 0; i < DUALADC_CAL_RDY_DELAY; i++)
    {
        __NOP();
    }

    /* Step 2: High-speed calibration - only required when CFG1[HS] is set. */
    if ((base->CFG1 & DUALADC_CFG1_HS_MASK) != 0U)
    {
        base->CTRL |= DUALADC_CTRL_CALHS_MASK;
#if DUALADC_CALIBRATION_TIMEOUT
        timeout = DUALADC_CALIBRATION_TIMEOUT;
#endif
        while ((base->STAT0 & DUALADC_STAT0_CAL_RDY_MASK) == 0U)
        {
#if DUALADC_CALIBRATION_TIMEOUT
            if (--timeout == 0U)
            {
                return kStatus_Timeout;
            }
#endif
        }
    }

    /* Wait 2 ADC clock cycles after STAT0[CAL_RDY] is set. */
    for (uint32_t i = 0; i < DUALADC_CAL_RDY_DELAY; i++)
    {
        __NOP();
    }

    /* Step 3: Gain and linearity calibration. */
    /* Initiate calibration; CAL_REQ auto-clears when accepted by hardware. */
    base->CTRL |= DUALADC_CTRL_CAL_REQ_MASK;

    /* Wait for hardware to complete ADCA and ADCB gain calibration. */
#if DUALADC_CALIBRATION_TIMEOUT
    timeout = DUALADC_CALIBRATION_TIMEOUT;
#endif
    while (((base->GCC[0] & DUALADC_GCC_RDY_MASK) == 0U) || ((base->GCC[1] & DUALADC_GCC_RDY_MASK) == 0U))
    {
#if DUALADC_CALIBRATION_TIMEOUT
        if (--timeout == 0U)
        {
            return kStatus_Timeout;
        }
#endif
    }

    /* Read raw GAIN_CAL from the GCC register. */
    GCCa = (base->GCC[0] & DUALADC_GCC_GAIN_CAL_MASK) >> DUALADC_GCC_GAIN_CAL_SHIFT;
    GCCb = (base->GCC[1] & DUALADC_GCC_GAIN_CAL_MASK) >> DUALADC_GCC_GAIN_CAL_SHIFT;

    GCRa = DUALADC_CalculateGainResult(GCCa);
    GCRb = DUALADC_CalculateGainResult(GCCb);

    /* Calculate gain adjustment and write 17-bit fixed-point result to GCR. */
    base->GCR[0] = (GCRa | DUALADC_GCR_RDY_MASK);
    base->GCR[1] = (GCRb | DUALADC_GCR_RDY_MASK);

    /* Wait for final CAL_RDY to confirm full calibration is complete. */
#if DUALADC_CALIBRATION_TIMEOUT
    timeout = DUALADC_CALIBRATION_TIMEOUT;
#endif
    while ((base->STAT0 & DUALADC_STAT0_CAL_RDY_MASK) == 0U)
    {
#if DUALADC_CALIBRATION_TIMEOUT
        if (--timeout == 0U)
        {
            return kStatus_Timeout;
        }
#endif
    }

    /* Wait 2 ADC clock cycles after STAT0[CAL_RDY] is set. */
    for (uint32_t i = 0; i < DUALADC_CAL_RDY_DELAY; i++)
    {
        __NOP();
    }

    /* Restore ADC enable state after calibration routines. */
    if (!adcEnabled)
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

    uint32_t i;
    bool adcEnabled = ((base->CTRL & DUALADC_CTRL_ADCEN_MASK) != 0U);

    /* Disable ADC during calibration register writes to prevent instability. */
    if (adcEnabled)
    {
        base->CTRL &= ~DUALADC_CTRL_ADCEN_MASK;
    }

    /* Restore offset trim values for ADCA and ADCB. */
    base->OFSTRIM = DUALADC_OFSTRIM_OFSTRIMA(ptrCalibrationValue->offsetTrimA) |
                    DUALADC_OFSTRIM_OFSTRIMB(ptrCalibrationValue->offsetTrimB);

    /* Restore high-speed trim values for ADCA and ADCB. */
    base->HSTRIM = DUALADC_HSTRIM_HSTRIMA(ptrCalibrationValue->highSpeedTrimA) |
                   DUALADC_HSTRIM_HSTRIMB(ptrCalibrationValue->highSpeedTrimB);

    /* Restore linearity calibration tables for ADCA and ADCB. */
    for (i = 0U; i < DUALADC_CAL_GAR_COUNT; i++)
    {
        base->CAL_GAR[i] = ptrCalibrationValue->calGar[i];
        base->CAL_GBR[i] = ptrCalibrationValue->calGbr[i];
    }

    /* Restore gain calibration results and mark them valid so hardware uses them. */
    base->GCR[0] = DUALADC_GCR_GCALR(ptrCalibrationValue->gcalr[0]) | DUALADC_GCR_RDY_MASK;
    base->GCR[1] = DUALADC_GCR_GCALR(ptrCalibrationValue->gcalr[1]) | DUALADC_GCR_RDY_MASK;

    if (adcEnabled)
    {
        base->CTRL |= DUALADC_CTRL_ADCEN_MASK;
    }
}
