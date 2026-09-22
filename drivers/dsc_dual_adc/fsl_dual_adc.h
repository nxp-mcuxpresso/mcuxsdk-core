/*
 * Copyright 2026 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef FSL_DUAL_ADC_H_
#define FSL_DUAL_ADC_H_

#include "fsl_common.h"

/*!
 * @addtogroup dual_adc_driver
 * @{
 */

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/*! @name Driver version */
/*! @{ */
#define FSL_DUAL_ADC_DRIVER_VERSION (MAKE_VERSION(2, 0, 0)) /*!< Version 2.0.0 */
/*! @} */

/*!
 * @brief NOP loop count used to hold CTRL[RSTA]/CTRL[RSTB] asserted long enough
 *        for the software reset to take effect.
 *
 * CTRL[RSTA] and CTRL[RSTB] are NOT self-clearing. The logic high level must be
 * sustained for more than 2 ADC functional clock cycles before the reset takes
 * effect; the bits must then be cleared explicitly by software. This macro
 * controls how many __NOP() iterations are executed between asserting and
 * releasing the reset bits in DUALADC_Init, providing a portable hold time that
 * scales with CPU clock speed.
 *
 * The required NOP count scales with the CPU-to-ADC clock frequency ratio:
 *   min_count = ceil(2 * f_CPU / f_ADC)
 * The default value of 20 covers ratios up to 10 (e.g., 150 MHz CPU with
 * 16 MHz ADC clock). Increase this value via Kconfig option
 * CONFIG_DUALADC_RESET_DELAY when the CPU clock is much faster than the
 * ADC functional clock (large f_CPU/f_ADC ratio).
 */
#ifndef DUALADC_RESET_DELAY
#ifdef CONFIG_DUALADC_RESET_DELAY
#define DUALADC_RESET_DELAY (uint32_t)CONFIG_DUALADC_RESET_DELAY
#else
#define DUALADC_RESET_DELAY (20UL)
#endif
#endif

/*!
 * @brief Max loop count waiting for each calibration step (STAT0[CAL_RDY], GCC[n][RDY]) to complete.
 *
 * Set via Kconfig option CONFIG_DUALADC_CALIBRATION_TIMEOUT. Default 0 means wait forever.
 */
#ifndef DUALADC_CALIBRATION_TIMEOUT
#ifdef CONFIG_DUALADC_CALIBRATION_TIMEOUT
#define DUALADC_CALIBRATION_TIMEOUT CONFIG_DUALADC_CALIBRATION_TIMEOUT
#else
#define DUALADC_CALIBRATION_TIMEOUT 0 /* Wait forever until calibration completes. */
#endif
#endif

/*!
 * @brief NOP loop count used to wait for at least 2 ADC functional clock cycles after
 *        STAT0[CAL_RDY] is asserted at the end of a calibration step.
 *
 * The reference manual requires software to wait 2 ADC clock cycles after polling
 * STAT0[CAL_RDY] and finding it set before proceeding. This macro controls how many
 * __NOP() iterations DUALADC_DoCalibration executes to provide a portable hold time
 * that scales with CPU clock speed.
 *
 * The required NOP count scales with the CPU-to-ADC clock frequency ratio:
 *   min_count = ceil(2 * f_CPU / f_ADC)
 * The default value of 20 covers ratios up to 10 (e.g., 150 MHz CPU with 16 MHz ADC
 * clock). Increase this value via Kconfig option CONFIG_DUALADC_CAL_RDY_DELAY when the
 * CPU clock is much faster than the ADC functional clock (large f_CPU/f_ADC ratio).
 */
#ifndef DUALADC_CAL_RDY_DELAY
#ifdef CONFIG_DUALADC_CAL_RDY_DELAY
#define DUALADC_CAL_RDY_DELAY (uint32_t)CONFIG_DUALADC_CAL_RDY_DELAY
#else
#define DUALADC_CAL_RDY_DELAY (20UL)
#endif
#endif

/*!
 * @brief DualADC conversion mode selection.
 *
 * Controls whether ADCA and ADCB share one conversion sequence (cooperation)
 * or run independent sequences (independence).
 */
typedef enum _dualadc_conversion_mode
{
    kDUALADC_CooperationMode  = 0U, /*!< Cooperation mode: ADCA and ADCB share one conversion sequence. */
    kDUALADC_IndependenceMode = 1U, /*!< Independence mode: ADCA and ADCB run independent sequences. */
} dualadc_conversion_mode_t;

/*!
 * @brief DualADC power configuration.
 *
 * Selects the power and maximum ADCK frequency trade-off.
 */
typedef enum _dualadc_power_config
{
    kDUALADC_LowPowerConfig  = 0U, /*!< Low power mode: maximum ADCK frequency 24 MHz (default). */
    kDUALADC_HighPowerConfig = 1U, /*!< High power mode: maximum ADCK frequency 64 MHz. */
} dualadc_power_config_t;

/*!
 * @brief DualADC voltage reference source selection.
 */
typedef enum _dualadc_ref_voltage_src
{
    kDUALADC_VrefH0 = 0U, /*!< VREFH0x - default reference. */
    kDUALADC_VrefH1 = 1U, /*!< VREFH1x. */
    kDUALADC_VrefH2 = 2U, /*!< VREFH2x. */
} dualadc_ref_voltage_src_t;

/*!
 * @brief DualADC tune mode selection.
 *
 * @note Consult the device-specific reference manual for the effect of each value.
 */
typedef enum _dualadc_tune_mode
{
    kDUALADC_TuneMode0 = 0U, /*!< Tune mode 0. */
    kDUALADC_TuneMode1 = 1U, /*!< Tune mode 1. */
    kDUALADC_TuneMode2 = 2U, /*!< Tune mode 2. */
} dualadc_tune_mode_t;

/*!
 * @brief Number of ADC conversions averaged during calibration routines.
 *
 * Applied to offset calibration (CTRL[CALOFS]), high-speed calibration (CTRL[CALHS]),
 * and gain calibration (CTRL[CAL_REQ]).
 * The recommended minimum is @ref kDUALADC_CalibrationAverage256.
 */
typedef enum _dualadc_calibration_averages
{
    kDUALADC_CalibrationAverageSingle = 0U,  /*!< Single conversion - no averaging. */
    kDUALADC_CalibrationAverage2      = 1U,  /*!< 2 conversions averaged. */
    kDUALADC_CalibrationAverage4      = 2U,  /*!< 4 conversions averaged. */
    kDUALADC_CalibrationAverage8      = 3U,  /*!< 8 conversions averaged. */
    kDUALADC_CalibrationAverage16     = 4U,  /*!< 16 conversions averaged. */
    kDUALADC_CalibrationAverage32     = 5U,  /*!< 32 conversions averaged. */
    kDUALADC_CalibrationAverage64     = 6U,  /*!< 64 conversions averaged. */
    kDUALADC_CalibrationAverage128    = 7U,  /*!< 128 conversions averaged. */
    kDUALADC_CalibrationAverage256    = 8U,  /*!< 256 conversions averaged (RM recommended minimum). */
    kDUALADC_CalibrationAverage512    = 9U,  /*!< 512 conversions averaged. */
    kDUALADC_CalibrationAverage1024   = 10U, /*!< 1024 conversions averaged. */
} dualadc_calibration_averages_t;

/*!
 * @brief DualADC trigger source selection for ADCA (CFG0[TRIGSEL]).
 */
typedef enum _dualadc_trig_sel
{
    kDUALADC_TrigSelTrigger0      = 0U,    /*!< Trigger0 input. */
    kDUALADC_TrigSelTriggerSyncIn = 1U,    /*!< Trigger_sync_in input. */
} dualadc_trig_sel_t;

/*!
 * @brief DualADC DMA trigger source selection (DE[DMASRCA/B]).
 */
typedef enum _dualadc_dma_src
{
    kDUALADC_DmaSrcEndOfScan   = 0U, /*!< DMA triggered by end-of-scan; cleared by DMA ack. */
    kDUALADC_DmaSrcResultReady = 1U, /*!< DMA triggered by result-ready; cleared by reading RSLT. */
} dualadc_dma_src_t;

/*!
 * @brief DualADC software trigger selection mask.
 *
 * Values may be OR'd together to assert Trigger0 and Trigger1 simultaneously.
 * In cooperation mode Trigger0 starts both ADCA and ADCB; Trigger1 is unused.
 * In independence mode Trigger0 starts ADCA and Trigger1 starts ADCB.
 */
typedef enum _dualadc_software_trigger
{
    kDUALADC_SoftwareTrigger0 = DUALADC_SWTRIG_SWT0_MASK, /*!< Software Trigger0: ADCA 
                                                            (ADCA+ADCB in cooperation mode). */
    kDUALADC_SoftwareTrigger1 = DUALADC_SWTRIG_SWT1_MASK, /*!< Software Trigger1: ADCB
                                                            (independence mode only). */
} dualadc_software_trigger_t;

/*!
 * @brief DualADC conversion type selection (CMD[CTYPE]).
 */
typedef enum _dualadc_conversion_type
{
    kDUALADC_ConversionSingleEndedA    = 0U, /*!< Single-ended, A-side channel only. */
    kDUALADC_ConversionSingleEndedB    = 1U, /*!< Single-ended, B-side channel only. */
    kDUALADC_ConversionDifferential    = 2U, /*!< Differential mode (A minus B). */
    kDUALADC_ConversionDualSingleEnded = 3U, /*!< Dual single-ended: A and B sides converted independently. */
} dualadc_conversion_type_t;

/*!
 * @brief DualADC conversion resolution selection (CMD[MODE]).
 */
typedef enum _dualadc_resolution
{
    kDUALADC_ResolutionStandard = 0U, /*!< Standard: 12-bit single-ended or 13-bit differential. */
    kDUALADC_ResolutionHigh     = 1U, /*!< High: 16-bit single-ended or differential. */
} dualadc_resolution_t;

/*!
 * @brief DualADC sample time selection in ADCK cycles (CMD[STS]).
 */
typedef enum _dualadc_sample_time
{
    kDUALADC_SampleTime3_5   = 0U, /*!< 3.5 ADCK cycles (minimum sample time). */
    kDUALADC_SampleTime5_5   = 1U, /*!< 5.5 ADCK cycles. */
    kDUALADC_SampleTime7_5   = 2U, /*!< 7.5 ADCK cycles. */
    kDUALADC_SampleTime11_5  = 3U, /*!< 11.5 ADCK cycles. */
    kDUALADC_SampleTime19_5  = 4U, /*!< 19.5 ADCK cycles. */
    kDUALADC_SampleTime35_5  = 5U, /*!< 35.5 ADCK cycles. */
    kDUALADC_SampleTime67_5  = 6U, /*!< 67.5 ADCK cycles. */
    kDUALADC_SampleTime131_5 = 7U, /*!< 131.5 ADCK cycles (maximum sample time). */
} dualadc_sample_time_t;

/*!
 * @brief DualADC hardware averaging count for conversions (CMD[AVGS]).
 */
typedef enum _dualadc_hardware_averages
{
    kDUALADC_HardwareAverageSingle = 0U,  /*!< Single conversion, no averaging. */
    kDUALADC_HardwareAverage2      = 1U,  /*!< 2 conversions averaged. */
    kDUALADC_HardwareAverage4      = 2U,  /*!< 4 conversions averaged. */
    kDUALADC_HardwareAverage8      = 3U,  /*!< 8 conversions averaged. */
    kDUALADC_HardwareAverage16     = 4U,  /*!< 16 conversions averaged. */
    kDUALADC_HardwareAverage32     = 5U,  /*!< 32 conversions averaged. */
    kDUALADC_HardwareAverage64     = 6U,  /*!< 64 conversions averaged. */
    kDUALADC_HardwareAverage128    = 7U,  /*!< 128 conversions averaged. */
    kDUALADC_HardwareAverage256    = 8U,  /*!< 256 conversions averaged. */
    kDUALADC_HardwareAverage512    = 9U,  /*!< 512 conversions averaged. */
    kDUALADC_HardwareAverage1024   = 10U, /*!< 1024 conversions averaged. */
} dualadc_hardware_averages_t;

/*!
 * @brief DualADC interrupt source selection mask for the IE register.
 *
 * Values may be OR'd together. ADCB interrupt sources are only generated
 * in independence mode (CFG0[INDEP]=1).
 */
typedef enum _dualadc_interrupt
{
    kDUALADC_InterruptEndOfScanA       = DUALADC_IE_EOSIEA_MASK,       /*!< End of scan sequence for ADCA. */
    kDUALADC_InterruptOverlapA         = DUALADC_IE_OVERLAPIEA_MASK,   /*!< Trigger overlap interrupt for ADCA. */
    kDUALADC_InterruptIntervalTimeErrA = DUALADC_IE_INTVTIMEERRIEA_MASK,/*!< Average-with-timer interval error for ADCA. */
    kDUALADC_InterruptEndOfScanB       = DUALADC_IE_EOSIEB_MASK,       /*!< End of scan sequence for ADCB. */
    kDUALADC_InterruptOverlapB         = DUALADC_IE_OVERLAPIEB_MASK,   /*!< Trigger overlap interrupt for ADCB. */
    kDUALADC_InterruptIntervalTimeErrB = DUALADC_IE_INTVTIMEERRIEB_MASK,/*!< Average-with-timer interval error for ADCB. */
} dualadc_interrupt_t;

/*!
 * @brief DualADC scan sequence completion status flag mask (STAT2[EOSI]).
 *
 * Used with @ref DUALADC_GetScanSequenceStatusFlags and @ref DUALADC_ClearScanSequenceStatusFlags.
 * Values may be OR'd together. kDUALADC_EndofScanBFlag is only generated in independence mode
 * (CFG0[INDEP]=1).
 */
typedef enum _dualadc_scan_seq_status_flag
{
    kDUALADC_EndofScanAFlag = DUALADC_STAT2_EOSIA_MASK, /*!< ADCA scan sequence complete. */
    kDUALADC_EndofScanBFlag = DUALADC_STAT2_EOSIB_MASK, /*!< ADCB scan sequence complete. */
} dualadc_scan_seq_status_flag_t;

/*!
 * @brief DualADC error status flag mask (STAT1).
 *
 * Used with @ref DUALADC_GetErrorStatusFlags and @ref DUALADC_ClearErrorStatusFlags.
 * Values may be OR'd together. ADCB flags are only generated in independence mode
 * (CFG0[INDEP]=1).
 */
typedef enum _dualadc_error_status_flag
{
    kDUALADC_OverlapAFlag = DUALADC_STAT1_OVERLAP_FLAGA_MASK, /*!< ADCA Trigger overlap detected. */
    kDUALADC_OverlapBFlag = DUALADC_STAT1_OVERLAP_FLAGB_MASK, /*!< ADCB Trigger overlap detected. */
    kDUALADC_IntervalErrAFlag = DUALADC_STAT1_INTVTIMEERR_FLAGA_MASK, /*!< ADCA Average-with-timer interval too short. */
    kDUALADC_IntervalErrBFlag = DUALADC_STAT1_INTVTIMEERR_FLAGB_MASK, /*!< ADCB Average-with-timer interval too short. */
} dualadc_error_status_flag_t;

/*!
 * @brief DualADC general read-only status flag mask (STAT0 and STAT2[STARTUPSTS]).
 *
 * Used with @ref DUALADC_GetStatusFlags. All flags are read-only and cannot be
 * cleared by software. Values may be OR'd together to test multiple flags at once.
 */
typedef enum _dualadc_status_flag
{
    kDUALADC_AdcActiveAFlag       = DUALADC_STAT0_ADC_ACTIVEA_MASK, /*!< ADCA is actively converting. */
    kDUALADC_AdcActiveBFlag       = DUALADC_STAT0_ADC_ACTIVEB_MASK, /*!< ADCB is actively converting. */
    kDUALADC_CalibrationReadyFlag = DUALADC_STAT0_CAL_RDY_MASK,    /*!< Calibration complete. */

    kDUALADC_StartupDoneAFlag = DUALADC_STAT2_STARTUPSTSA_MASK,    /*!< ADCA analog startup complete. */
    kDUALADC_StartupDoneBFlag = DUALADC_STAT2_STARTUPSTSB_MASK,    /*!< ADCB analog startup complete. */
} dualadc_status_flag_t;

/*!
 * @brief DualADC command buffer bitmask values for RSLTRDY_IE and CMP_IE registers.
 *
 * Values may be OR'd together to address multiple command buffers simultaneously.
 */
typedef enum _dualadc_cmd_mask
{
    kDUALADC_Cmd1Mask  = (1UL << 0UL),  /*!< Command buffer 1. */
    kDUALADC_Cmd2Mask  = (1UL << 1UL),  /*!< Command buffer 2. */
    kDUALADC_Cmd3Mask  = (1UL << 2UL),  /*!< Command buffer 3. */
    kDUALADC_Cmd4Mask  = (1UL << 3UL),  /*!< Command buffer 4. */
    kDUALADC_Cmd5Mask  = (1UL << 4UL),  /*!< Command buffer 5. */
    kDUALADC_Cmd6Mask  = (1UL << 5UL),  /*!< Command buffer 6. */
    kDUALADC_Cmd7Mask  = (1UL << 6UL),  /*!< Command buffer 7. */
    kDUALADC_Cmd8Mask  = (1UL << 7UL),  /*!< Command buffer 8. */
    kDUALADC_Cmd9Mask  = (1UL << 8UL),  /*!< Command buffer 9. */
    kDUALADC_Cmd10Mask = (1UL << 9UL),  /*!< Command buffer 10. */
    kDUALADC_Cmd11Mask = (1UL << 10UL), /*!< Command buffer 11. */
    kDUALADC_Cmd12Mask = (1UL << 11UL), /*!< Command buffer 12. */
    kDUALADC_Cmd13Mask = (1UL << 12UL), /*!< Command buffer 13. */
    kDUALADC_Cmd14Mask = (1UL << 13UL), /*!< Command buffer 14. */
    kDUALADC_Cmd15Mask = (1UL << 14UL), /*!< Command buffer 15. */
    kDUALADC_Cmd16Mask = (1UL << 15UL), /*!< Command buffer 16. */
    kDUALADC_Cmd17Mask = (1UL << 16UL), /*!< Command buffer 17. */
    kDUALADC_Cmd18Mask = (1UL << 17UL), /*!< Command buffer 18. */
    kDUALADC_Cmd19Mask = (1UL << 18UL), /*!< Command buffer 19. */
    kDUALADC_Cmd20Mask = (1UL << 19UL), /*!< Command buffer 20. */
} dualadc_cmd_mask_t;

/*!
 * @brief DualADC conversion command configuration structure.
 *
 * Configure each command buffer entry and pass to @ref DUALADC_ConfigConversionCommand.
 * Use @ref DUALADC_GetDefaultConversionCommandConfig for safe defaults.
 */
typedef struct _dualadc_cmd_config
{
    /*
     * CMD register fields are implemented as bit-fields to save memory. The bit-field
     * layout intentionally mirrors the DualADC CMD register so an entire command entry fits
     * in a single 32-bit word, including the CMD[CDIS] sequence-terminator bit.
     */
    uint32_t u32EnableCompare     : 1; /*!< CMPEN, bit 0: enable hardware compare for this command. */
    uint32_t u32EnableWaitTrigger : 1; /*!< WAIT_TRIG, bit 1: require trigger re-assertion before execution. */
    uint32_t reserved0            : 2; /*!< bit 2-3: reserved. */
    uint32_t u32ConversionType    : 2; /*!< CTYPE, bit 4-5: conversion type (@ref dualadc_conversion_type_t). */
    uint32_t u32ResolutionMode    : 1; /*!< MODE, bit 6: conversion resolution (@ref dualadc_resolution_t). */
    uint32_t u32DisableCommand    : 1; /*!< CDIS, bit 7: mark this command as the sequence terminator. */
    uint32_t u32SampleTimeMode    : 3; /*!< STS, bit 8-10: input sample time (@ref dualadc_sample_time_t). */
    uint32_t reserved2            : 1; /*!< bit 11: reserved. */
    uint32_t u32HardwareAverages  : 4; /*!< AVGS, bit 12-15: conversions averaged (@ref dualadc_hardware_averages_t). */
    uint32_t u32ChannelNumber     : 5; /*!< ADCH, bit 16-20: A-side input channel select (0-31). */
    uint32_t reserved3            : 3; /*!< bit 21-23: reserved. */
    uint32_t u32AltBChannelNumber : 5; /*!< ALTB_ADCH, bit 24-28: B-side channel select (0-31). */
    uint32_t reserved4            : 2; /*!< bit 29-30: reserved. */
    uint32_t u32EnableAltBChannel : 1; /*!< ALTB_EN, bit 31: use u32AltBChannelNumber for B-side. */

    uint16_t u16CompareValueHigh; /*!< Compare value high (CVH); written to CV[n] when u32EnableCompare is set. */
    uint16_t u16CompareValueLow;  /*!< Compare value low (CVL); written to CV[n] when u32EnableCompare is set. */
} dualadc_cmd_config_t;

/*!
 * @brief DualADC trigger control configuration structure (TCTRL register).
 *
 * Pass to @ref DUALADC_ConfigTriggerControl. Applied by @ref DUALADC_Init through the
 * @ref dualadc_config_t member of the same type.
 */
typedef struct _dualadc_trigger_config
{
    bool bEnableHardwareTrigger0;    /*!< Enable hardware Trigger0 for ADCA (or both in cooperation mode). */
    bool bEnableHardwareTrigger1;    /*!< Enable hardware Trigger1 for ADCB (independence mode only). */
    uint8_t u8Trigger0Delay;    /*!< Trigger0 delay select (0-15, raw count);
                                  delay time 2^u8Trigger0Delay ADCK cycles. */
    uint8_t u8Trigger1Delay;    /*!< Trigger1 delay select (0-15, raw count);
                                  delay time 2^u8Trigger1Delay ADCK cycles. */
} dualadc_trigger_config_t;

/*!
 * @brief DualADC DMA configuration structure (DE register).
 *
 * Pass to @ref DUALADC_ConfigDma. Applied by @ref DUALADC_Init through the
 * @ref dualadc_config_t member of the same type.
 */
typedef struct _dualadc_dma_config
{
    bool bEnableDmaA;           /*!< Enable DMA request for ADCA. */
    dualadc_dma_src_t eDmaSourceA; /*!< DMA trigger source for ADCA. */
    bool bEnableDmaB;           /*!< Enable DMA request for ADCB (independence mode only). */
    dualadc_dma_src_t eDmaSourceB; /*!< DMA trigger source for ADCB (independence mode only). */
} dualadc_dma_config_t;

/*!
 * @brief DualADC conversion pause configuration structure (PAUSE register).
 *
 * Pass to @ref DUALADC_ConfigPause. Applied by @ref DUALADC_Init through the
 * @ref dualadc_config_t member of the same type.
 */
typedef struct _dualadc_pause_config
{
    bool bEnableConversionPause;        /*!< Insert a delay between consecutive conversions in a sequence. */
    uint16_t u16ConversionPauseDelay;   /*!< Pause delay count (0-511); delay = pauseDelay * 4 ADCK cycles. */
} dualadc_pause_config_t;

/*!
 * @brief DualADC average-with-timer interval prescaler (ITCFG[PRESCALERA/B]).
 *
 * Interval = ITCFG[INTERVAL] * ADCK_period * 2^prescaler
 */
typedef enum _dualadc_avgt_prescaler
{
    kDUALADC_AvgtPrescaler1   = 0U, /*!< Prescaled by 1. */
    kDUALADC_AvgtPrescaler2   = 1U, /*!< Prescaled by 2. */
    kDUALADC_AvgtPrescaler4   = 2U, /*!< Prescaled by 4. */
    kDUALADC_AvgtPrescaler8   = 3U, /*!< Prescaled by 8. */
    kDUALADC_AvgtPrescaler16  = 4U, /*!< Prescaled by 16. */
    kDUALADC_AvgtPrescaler32  = 5U, /*!< Prescaled by 32. */
    kDUALADC_AvgtPrescaler64  = 6U, /*!< Prescaled by 64. */
    kDUALADC_AvgtPrescaler128 = 7U, /*!< Prescaled by 128. */
} dualadc_avgt_prescaler_t;

/*!
 * @brief DualADC average-with-timer configuration structure.
 *
 * The average-with-timer feature repeats a conversion sequence automatically at a
 * configurable interval. Pass to @ref DUALADC_ConfigAverageTimer.
 * Use @ref DUALADC_GetDefaultAverageTimerConfig for safe defaults.
 *
 * In cooperation mode only the ADCA fields (A suffix) take effect; ADCB follows ADCA
 * and the ADCB fields are ignored by hardware.
 * In independence mode both sets of fields are independent.
 *
 * Interval formula: Interval = interval * ADCK_period * 2^prescaler
 */
typedef struct _dualadc_avgt_config
{
    /* ADCA - valid in both cooperation and independence modes */
    bool bEnableAvgTimerA;      /*!< Enable average-with-timer for ADCA. */
    uint16_t u16RepeatCountA;   /*!< Sequence repeat count for ADCA (1-512); stored as AVGTA_TIMES+1. */
    uint16_t u16IntervalA;      /*!< ADCA timer interval raw count (ITCFG[INTERVALA]). */
    dualadc_avgt_prescaler_t ePrescalerA;   /*!< ADCA interval timer prescaler. */

    /* ADCB - valid in independence mode only; ignored by hardware in cooperation mode */
    bool bEnableAvgTimerB;      /*!< Enable average-with-timer for ADCB (independence mode only). */
    uint16_t u16RepeatCountB;   /*!< Sequence repeat count for ADCB (1-512, independence mode only). */
    uint16_t u16IntervalB;      /*!< ADCB timer interval raw count (ITCFG[INTERVALB], independence mode only). */
    dualadc_avgt_prescaler_t ePrescalerB;   /*!< ADCB interval timer prescaler (independence mode only). */
} dualadc_avgt_config_t;

/*!
 * @brief DualADC initialization configuration structure.
 *
 * Pass a populated instance of this structure to @ref DUALADC_Init.
 * Use @ref DUALADC_GetDefaultConfig to obtain safe reset-state defaults before
 * modifying individual fields.
 *
 * @note Calibration request bits (CTRL[CAL_REQ], CTRL[CALOFS], CTRL[CALHS]) are excluded
 *       from this structure and must be triggered through @ref DUALADC_DoCalibration.
 * @note The average-with-timer, conversion-command sequence, interrupt enables and the
 *       final CTRL[ADCEN] state are all applied by @ref DUALADC_Init using the members
 *       appended at the end of this structure.
 */
typedef struct _dualadc_config
{
    /* CFG0 - Configuration 0 Register */
    dualadc_conversion_mode_t eConversionMode;      /*!< ADCA/ADCB conversion mode (cooperation or independence). */
    dualadc_power_config_t ePowerConfig;            /*!< Power and maximum ADCK frequency. */
    bool bEnableAnalogPreEnable;                    /*!< Pre-enable analog circuits for faster conversion startup. */
    dualadc_ref_voltage_src_t eRefVoltageSource;    /*!< Voltage reference source. */
    uint8_t u8PowerUpDelayCount;                    /*!< Power-up delay count; must exceed device tADCSTUP. */
    dualadc_trig_sel_t eTriggerSource;              /*!< Trigger source for ADCA (CFG0[TRIGSEL]). */

    /* CFG1 - Configuration 1 Register */
    bool bEnableLeftJustify;         /*!< Left-justify the 12-bit result in the result register. */
    bool bEnableHighSpeedMode;       /*!< Enable high-speed conversion mode. */
    bool bEnableHighSpeedExtra;      /*!< Add one extra conversion cycle in high-speed mode. */
    dualadc_tune_mode_t eTuneMode;   /*!< Tune mode; see device reference manual. */

    /* CTRL - Control Register */
    bool bEnableDoze;                        /*!< ADC finishes current scan then goes inactive on doze entry. */
    bool bEnableLongCalSampleTime;           /*!< Use long (67.5 ADCK) sample time during calibration. */
    dualadc_calibration_averages_t eCalibrationAverages;    /*!< Conversion averages during calibration routines. */

    /* PAUSE - Pause Register (see @ref dualadc_pause_config_t) */
    dualadc_pause_config_t sPauseConfig;       /*!< Conversion pause configuration applied during init. */

    /* TCTRL - Trigger Control Register (see @ref dualadc_trigger_config_t) */
    dualadc_trigger_config_t sTriggerConfig;   /*!< Trigger control configuration applied during init. */

    /* DE - DMA enable and trigger source (see @ref dualadc_dma_config_t) */
    dualadc_dma_config_t sDmaConfig;           /*!< DMA configuration applied during init. */

    /*
     * CMD[]/CV[] - Conversion command sequence configured as an array in one shot.
     * The array size is fixed by the register-header macro DUALADC_CMD_COUNT (the CMD and CV
     * register arrays always have the same count). All entries are programmed; mark the
     * terminating command via its u32DisableCommand (CDIS) bit to end the scan sequence.
     */
    dualadc_cmd_config_t sConvCmdConfig[DUALADC_CMD_COUNT]; /*!< Conversion command entries.
                                                                sConvCmdConfig[0] maps to CMD1/CV1,
                                                                sConvCmdConfig[1] to CMD2/CV2, and so on. */

    /* AVGT_CTRL/ITCFG - Average-with-timer feature */
    dualadc_avgt_config_t sAvgtConfig; /*!< Average-with-timer configuration applied during init. */

    /* IE/RSLTRDY_IE/CMP_IE - Interrupt enables */
    uint32_t u32InterruptMask;        /*!< IE mask, OR of @ref dualadc_interrupt_t values. */
    uint32_t u32ResultReadyIntMask;   /*!< RSLTRDY_IE mask, OR of @ref dualadc_cmd_mask_t values. */
    uint32_t u32CompareIntMask;       /*!< CMP_IE mask, OR of @ref dualadc_cmd_mask_t values. */

    /* CTRL[ADCEN] - Final module enable state */
    bool bEnableAdc; /*!< Assert CTRL[ADCEN] at the end of DUALADC_Init when true. */
} dualadc_config_t;

/*!
 * @brief DualADC calibration value structure.
 */
typedef struct _dualadc_calibration_value
{
    uint16_t u16OffsetTrimA;       /*!< OFSTRIM[OFSTRIMA]: ADCA offset trim (10-bit). */
    uint16_t u16OffsetTrimB;       /*!< OFSTRIM[OFSTRIMB]: ADCB offset trim (10-bit). */
    uint16_t u16HighSpeedTrimA;    /*!< HSTRIM[HSTRIMA]: ADCA high-speed trim (5-bit). */
    uint16_t u16HighSpeedTrimB;    /*!< HSTRIM[HSTRIMB]: ADCB high-speed trim (5-bit). */
    uint32_t u32Gcalr[DUALADC_GCR_COUNT];   /*!< GCR[n].GCALR: 17-bit gain calibration result (RDY bit excluded). */
    uint16_t u16CalGar[DUALADC_CAL_GAR_COUNT];    /*!< CAL_GAR[0..32]: linearity calibration values for ADCA. */
    uint16_t u16CalGbr[DUALADC_CAL_GBR_COUNT];    /*!< CAL_GBR[0..32]: linearity calibration values for ADCB. */
} dualadc_calibration_value_t;

/*!
 * @brief DualADC conversion result structure.
 *
 * All three members are derived from a single RSLT register read. Use the member
 * that matches the conversion configuration.
 *
 * @note The raw values are not final ADC codes. In standard 12-bit mode (CMD[MODE]=0) the ADC
 *       code does not start at bit 0:
 *       - CFG1[JLEFT]=0: 12-bit code at bit[14:3]; right-shift by 3 to obtain the value.
 *       - CFG1[JLEFT]=1: 12-bit code at bit[15:4]; right-shift by 4 to obtain the value.
 *       In high-resolution 16-bit mode (CMD[MODE]=1) the result fills bit[15:0] and no shift
 *       is needed.
 *       When average-with-timer is enabled u32Result32 holds the sum of raw register values;
 *       apply the same right-shift before dividing by the repeat count.
 */
typedef struct _dualadc_conversion_result
{
    uint16_t u16ResultLow;  /*!< bit[15:0]: single-ended or differential result;
                                 A-side result in dual single-ended mode. */
    uint16_t u16ResultHigh; /*!< bit[31:16]: B-side result in dual single-ended mode (CTYPE=3). */
    uint32_t u32Result32;   /*!< bit[31:0]: full 32-bit summed result when average-with-timer is enabled. */
} dualadc_conversion_result_t;

/*******************************************************************************
 * API
 ******************************************************************************/

#if defined(__cplusplus)
extern "C" {
#endif

/*!
 * @name Initialization and deinitialization
 * @{
 */

/*!
 * @brief Get the instance for DualADC module.
 *
 * @param base DualADC base address
 * @return Instance number if valid base address is provided, otherwise returns 0xFFFFFFFF
 */
uint32_t DUALADC_GetInstance(DUALADC_Type *base);

/*!
 * @brief Populate a @ref dualadc_config_t with reset-state defaults.
 *
 * Defaults applied:
 * - Cooperation mode
 * - Low power (max 24 MHz ADCK)
 * - Analog pre-enable disabled
 * - VREFH0x reference voltage
 * - Power-up delay count: 0x80 (adjust per device tADCSTUP specification)
 * - Right-justified result
 * - High-speed mode disabled
 * - Tune mode 1
 * - Doze: ADC continues converting through system low-power entry (DOZEN = 0)
 * - Normal calibration sample time (3.5 ADCK cycles)
 * - 256-average calibration (RM recommended minimum)
 *
 * @param config Pointer to the configuration structure to populate. Must not be NULL.
 */
void DUALADC_GetDefaultConfig(dualadc_config_t *config);

/*!
 * @brief Initialize the DualADC module.
 *
 * Initialization sequence:
 * 1. Enable the peripheral clock.
 * 2. Release the peripheral reset (if supported by the platform).
 * 3. Assert then release software reset for ADCA and ADCB (CTRL[RSTA]/CTRL[RSTB]).
 * 4. Configure CFG0 via read-modify-write.
 * 5. Configure CFG1 via read-modify-write.
 * 6. Configure CTRL fields (DOZEN, CST_LONG, CAL_AVGS) via read-modify-write.
 *
 * On return the ADC is enabled and ready for calibration or conversion.
 *
 * @param base   DualADC peripheral base address.
 * @param config Pointer to the initialization configuration. Must not be NULL.
 * @retval kStatus_Success           Initialization succeeded.
 * @retval kStatus_InvalidArgument   @p base is not a valid DualADC peripheral address.
 */
status_t DUALADC_Init(DUALADC_Type *base, const dualadc_config_t *config);

/*!
 * @brief Deinitialize the DualADC module.
 *
 * Clears CTRL[ADCEN] to terminate any active conversion, gates the peripheral
 * clock, and asserts the peripheral reset (if supported by the platform).
 *
 * @param base DualADC peripheral base address.
 * @retval kStatus_Success           Deinitialization succeeded.
 * @retval kStatus_InvalidArgument   @p base is not a valid DualADC peripheral address.
 */
status_t DUALADC_DeInit(DUALADC_Type *base);

/*! @} */

/*!
 * @name Calibration
 * @{
 */

/*!
 * @brief Perform all DualADC calibration routines.
 *
 * Executes in order:
 * 1. Offset calibration (CTRL[CALOFS]) - updates OFSTRIM.
 * 2. High-speed calibration (CTRL[CALHS]) - only when CFG1[HS] is set; updates HSTRIM.
 * 3. Gain and linearity calibration (CTRL[CAL_REQ]) - polls GCC[0/1].RDY, computes
 *    the 17-bit fixed-point gain result, writes GCR[0/1], and waits for STAT0[CAL_RDY].
 *
 * Must be called after @ref DUALADC_Enable to ensure ADC enabled.
 * CTRL[CAL_AVGS] (set in @ref DUALADC_Init) applies to all three calibration steps.
 *
 * @param base DualADC peripheral base address.
 * @retval kStatus_Success  All calibration steps completed successfully.
 * @retval kStatus_Timeout  A calibration poll loop exceeded @ref DUALADC_CALIBRATION_TIMEOUT
 *                          iterations (only possible when the timeout is non-zero).
 */
status_t DUALADC_DoCalibration(DUALADC_Type *base);

/*!
 * @brief Restore calibration registers from a previously saved @ref dualadc_calibration_value_t.
 *
 * Writes OFSTRIM, HSTRIM, CAL_GAR[0..32], CAL_GBR[0..32], GCR[0], and GCR[1] from the
 * supplied structure. GCR[n].RDY is set automatically so the hardware uses the restored values.
 * CTRL[ADCEN] is cleared before writing and restored afterwards. No CAL_RDY polling is performed.
 *
 * @param base DualADC peripheral base address.
 * @param ptrCalibrationValue Pointer to the calibration value structure to restore. Must not be NULL.
 */
void DUALADC_SetCalibrationValue(DUALADC_Type *base, const dualadc_calibration_value_t *ptrCalibrationValue);

/*!
 * @brief Read back the current calibration registers into a @ref dualadc_calibration_value_t.
 *
 * Reads OFSTRIM, HSTRIM, CAL_GAR[0..32], CAL_GBR[0..32], GCR[0], and GCR[1] into the supplied
 * structure so the values can be stored and later restored with @ref DUALADC_SetCalibrationValue.
 * The GCR[n].RDY bit is excluded; only the 17-bit GCALR field is captured. CTRL[ADCEN] is
 * cleared before reading and restored afterwards.
 *
 * @param base DualADC peripheral base address.
 * @param ptrCalibrationValue Pointer to the calibration value structure to populate. Must not be NULL.
 */
void DUALADC_GetCalibrationValue(DUALADC_Type *base, dualadc_calibration_value_t *ptrCalibrationValue);

/*! @} */

/*!
 * @name Configuration
 * @{
 */

/*!
 * @brief Populate a @ref dualadc_cmd_config_t with reset-state defaults.
 *
 * Defaults applied:
 * - Single-ended A-side conversion
 * - Standard resolution (12-bit)
 * - Minimum sample time (3.5 ADCK)
 * - No hardware averaging
 * - Channel 0, no alternate B-channel
 * - Compare disabled, wait-trigger disabled
 *
 * @param config Pointer to the command configuration structure. Must not be NULL.
 */
void DUALADC_GetDefaultConversionCommandConfig(dualadc_cmd_config_t *config);

/*!
 * @brief Configure a DualADC conversion command buffer entry.
 *
 * The command's CDIS (sequence terminator) bit is programmed from
 * @ref dualadc_cmd_config_t::u32DisableCommand together with the other CMD fields.
 *
 * @param base DualADC peripheral base address.
 * @param index Command buffer index, range 1-20 (maps to CMD[0]-CMD[19]).
 * @param config Pointer to the command configuration.
 */
void DUALADC_ConfigConversionCommand(DUALADC_Type *base, uint32_t index, const dualadc_cmd_config_t *config);

/*!
 * @brief Populate a @ref dualadc_avgt_config_t with reset-state defaults.
 *
 * Defaults: average-with-timer disabled for both ADCA and ADCB; repeat count 1;
 * interval 0; prescaler *1.
 *
 * @param config Pointer to the configuration structure to populate. Must not be NULL.
 */
void DUALADC_GetDefaultAverageTimerConfig(dualadc_avgt_config_t *config);

/*!
 * @brief Configure the average-with-timer feature.
 *
 * Writes AVGT_CTRL and ITCFG registers via read-modify-write.
 * In cooperation mode the ADCB fields in @p config are written to hardware but ignored;
 * in independence mode both sets are independent.
 *
 * @param base   DualADC peripheral base address.
 * @param config Pointer to the average-with-timer configuration. Must not be NULL.
 */
void DUALADC_ConfigAverageTimer(DUALADC_Type *base, const dualadc_avgt_config_t *config);

/*!
 * @brief Configure the conversion pause register (PAUSE).
 *
 * Programs the pause enable bit and the pause-delay field from @p psConfig. Must be
 * configured before CTRL[ADCEN] is asserted. Called internally by @ref DUALADC_Init.
 *
 * @param base     DualADC peripheral base address.
 * @param psConfig Pointer to the pause configuration. Must not be NULL.
 */
void DUALADC_ConfigPause(DUALADC_Type *base, const dualadc_pause_config_t *psConfig);

/*!
 * @brief Configure the trigger control register (TCTRL).
 *
 * Programs hardware Trigger0/Trigger1 enable bits and their delay-select fields from
 * @p psConfig. Called internally by @ref DUALADC_Init and exposed for dynamic update.
 *
 * @param base     DualADC peripheral base address.
 * @param psConfig Pointer to the trigger control configuration. Must not be NULL.
 */
void DUALADC_ConfigTriggerControl(DUALADC_Type *base, const dualadc_trigger_config_t *psConfig);

/*!
 * @brief Configure the DMA enable and DMA trigger source register (DE).
 *
 * Programs the ADCA/ADCB DMA enable bits and their DMA trigger source selects from
 * @p psConfig. Called internally by @ref DUALADC_Init and exposed for dynamic update.
 *
 * @param base     DualADC peripheral base address.
 * @param psConfig Pointer to the DMA configuration. Must not be NULL.
 */
void DUALADC_ConfigDma(DUALADC_Type *base, const dualadc_dma_config_t *psConfig);

/*! @} */

/*!
 * @name Dynamic Update
 * @{
 */

/*!
 * @brief Enable the DualADC module.
 *
 * Call this after @ref DUALADC_Init when the application is ready to start the ADC.
 *
 * @param base DualADC peripheral base address.
 */
static inline void DUALADC_Enable(DUALADC_Type *base)
{
    base->CTRL |= DUALADC_CTRL_ADCEN_MASK;
}

/*!
 * @brief Disable the DualADC module.
 *
 * The peripheral clock and configuration registers are preserved; call
 * @ref DUALADC_Enable to restart the ADC without re-initializing.
 *
 * @param base DualADC peripheral base address.
 */
static inline void DUALADC_Disable(DUALADC_Type *base)
{
    base->CTRL &= ~DUALADC_CTRL_ADCEN_MASK;
}

/*!
 * @brief Read the conversion result for a command buffer entry.
 *
 * Reads RSLT[index-1] once and populates all three members of @p result.
 * Reading the result register automatically clears the corresponding
 * RSLTRDY_STAT bit.
 *
 * @param base   DualADC peripheral base address.
 * @param index  Command buffer index, range 1-20.
 * @param result Pointer to the result structure to populate. Must not be NULL.
 */
static inline void DUALADC_GetConversionResult(DUALADC_Type *base, uint32_t index, dualadc_conversion_result_t *result)
{
    assert(NULL != result);
    assert(index >= 1U && index <= DUALADC_RSLT_RSLT_32B_RSLT_COUNT);

    uint32_t u32Raw = base->RSLT[index - 1U];
    result->u32Result32   = u32Raw;
    result->u16ResultLow  = (uint16_t)(u32Raw & 0xFFFFUL);
    result->u16ResultHigh = (uint16_t)((u32Raw >> 16U) & 0xFFFFUL);

}

/*!
 * @brief Read the full 32-bit raw conversion result for a command buffer entry.
 *
 * Returns RSLT[index-1] as a single uint32_t. This is the most efficient path
 * when the average-with-timer summed value is required.
 * Reading the result register automatically clears the corresponding RSLTRDY_STAT bit.
 *
 * @param base  DualADC peripheral base address.
 * @param index Command buffer index, range 1-20.
 * @return Raw 32-bit RSLT register value.
 */
static inline uint32_t DUALADC_GetConversionResult32(DUALADC_Type *base, uint32_t index)
{
    assert(index >= 1U && index <= DUALADC_RSLT_RSLT_32B_RSLT_COUNT);
    return base->RSLT[index - 1U];
}

/*!
 * @brief Read the low 16-bit conversion result for a command buffer entry.
 *
 * Returns RSLT_16B[index-1].RSLT_L directly as a uint16_t, equivalent to
 * bit[15:0] of the RSLT register.
 * Reading the result register automatically clears the corresponding
 * RSLTRDY_STAT bit.
 *
 * @param base  DualADC peripheral base address.
 * @param index Command buffer index, range 1-20.
 * @return Low 16-bit result (bit[15:0] of RSLT).
 */
static inline uint16_t DUALADC_GetConversionResultLow(DUALADC_Type *base, uint32_t index)
{
    assert(index >= 1U && index <= DUALADC_RSLT_RSLT_16B_RSLT_16B_COUNT);
    return base->RSLT_16B[index - 1U].RSLT_L;
}

/*!
 * @brief Read the high 16-bit conversion result for a command buffer entry.
 *
 * Returns RSLT_16B[index-1].RSLT_H directly as a uint16_t, equivalent to
 * bit[31:16] of the RSLT register.
 * Reading the result register automatically clears the corresponding
 * RSLTRDY_STAT bit.
 *
 * @param base  DualADC peripheral base address.
 * @param index Command buffer index, range 1-20.
 * @return High 16-bit result (bit[31:16] of RSLT).
 */
static inline uint16_t DUALADC_GetConversionResultHigh(DUALADC_Type *base, uint32_t index)
{
    assert(index >= 1U && index <= DUALADC_RSLT_RSLT_16B_RSLT_16B_COUNT);
    return base->RSLT_16B[index - 1U].RSLT_H;
}

/*!
 * @brief Assert one or both software triggers.
 *
 * @param base DualADC peripheral base address.
 * @param mask OR combination of @ref dualadc_software_trigger_t values.
 */
static inline void DUALADC_SetSoftwareTrigger(DUALADC_Type *base, uint32_t mask)
{
    base->SWTRIG = mask;
}

/*!
 * @brief Enable the DMA request for ADCA.
 *
 * @param base DualADC peripheral base address.
 */
static inline void DUALADC_EnableDmaA(DUALADC_Type *base)
{
    base->DE |= DUALADC_DE_DMAENAA_MASK;
}

/*!
 * @brief Disable the DMA request for ADCA.
 * @param base DualADC peripheral base address.
 */
static inline void DUALADC_DisableDmaA(DUALADC_Type *base)
{
    base->DE &= ~DUALADC_DE_DMAENAA_MASK;
}

/*!
 * @brief Enable the DMA request for ADCB (independence mode only).
 *
 * @param base DualADC peripheral base address.
 */
static inline void DUALADC_EnableDmaB(DUALADC_Type *base)
{
    base->DE |= DUALADC_DE_DMAENAB_MASK;
}

/*!
 * @brief Disable the DMA request for ADCB.
 * @param base DualADC peripheral base address.
 */
static inline void DUALADC_DisableDmaB(DUALADC_Type *base)
{
    base->DE &= ~DUALADC_DE_DMAENAB_MASK;
}

/*!
 * @brief Assert the software reset for ADCA (CTRL[RSTA]).
 *
 * @note CTRL[RSTA] is NOT self-clearing. After asserting reset, the logic high level
 *       must be held for more than 2 ADC functional clock cycles before invoking
 *       @ref DUALADC_ReleaseResetADCA to release it explicitly.
 *
 * @param base DualADC peripheral base address.
 */
static inline void DUALADC_ResetADCA(DUALADC_Type *base)
{
    base->CTRL |= DUALADC_CTRL_RSTA_MASK;
}

/*!
 * @brief Release the software reset for ADCA by clearing CTRL[RSTA].
 *
 * @note Must be called after the reset has been held for more than 2 ADC functional
 *       clock cycles, see @ref DUALADC_ResetADCA.
 *
 * @param base DualADC peripheral base address.
 */
static inline void DUALADC_ReleaseResetADCA(DUALADC_Type *base)
{
    base->CTRL &= ~DUALADC_CTRL_RSTA_MASK;
}

/*!
 * @brief Assert the software reset for ADCB (CTRL[RSTB]).
 *
 * @note CTRL[RSTB] is NOT self-clearing. After asserting reset, the logic high level
 *       must be held for more than 2 ADC functional clock cycles before invoking
 *       @ref DUALADC_ReleaseResetADCB to release it explicitly.
 *
 * @param base DualADC peripheral base address.
 */
static inline void DUALADC_ResetADCB(DUALADC_Type *base)
{
    base->CTRL |= DUALADC_CTRL_RSTB_MASK;
}

/*!
 * @brief Release the software reset for ADCB by clearing CTRL[RSTB].
 *
 * @note Must be called after the reset has been held for more than 2 ADC functional
 *       clock cycles, see @ref DUALADC_ResetADCB.
 *
 * @param base DualADC peripheral base address.
 */
static inline void DUALADC_ReleaseResetADCB(DUALADC_Type *base)
{
    base->CTRL &= ~DUALADC_CTRL_RSTB_MASK;
}

/*! @} */

/*!
 * @name Interrupt and Status
 * @{
 */

/*!
 * @brief Enable DualADC interrupts in the IE register.
 *
 * @param base DualADC peripheral base address.
 * @param mask OR combination of @ref dualadc_interrupt_t values.
 */
static inline void DUALADC_EnableInterrupts(DUALADC_Type *base, uint32_t mask)
{
    base->IE |= mask;
}

/*!
 * @brief Disable DualADC interrupts in the IE register.
 *
 * @param base DualADC peripheral base address.
 * @param mask OR combination of @ref dualadc_interrupt_t values.
 */
static inline void DUALADC_DisableInterrupts(DUALADC_Type *base, uint32_t mask)
{
    base->IE &= ~mask;
}

/*!
 * @brief Enable result-ready interrupts for one or more command buffers.
 *
 * @param base DualADC peripheral base address.
 * @param mask OR combination of @ref dualadc_cmd_mask_t values.
 */
static inline void DUALADC_EnableResultReadyInterrupts(DUALADC_Type *base, uint32_t mask)
{
    base->RSLTRDY_IE |= mask;
}

/*!
 * @brief Disable result-ready interrupts for one or more command buffers.
 *
 * @param base DualADC peripheral base address.
 * @param mask OR combination of @ref dualadc_cmd_mask_t values.
 */
static inline void DUALADC_DisableResultReadyInterrupts(DUALADC_Type *base, uint32_t mask)
{
    base->RSLTRDY_IE &= ~mask;
}

/*!
 * @brief Enable compare interrupts for one or more command buffers.
 *
 * The compare interrupt fires when a command's conversion result satisfies the
 * compare condition (CMD[CMPEN] must also be set for that command buffer).
 *
 * @param base DualADC peripheral base address.
 * @param mask OR combination of @ref dualadc_cmd_mask_t values.
 */
static inline void DUALADC_EnableCompareInterrupts(DUALADC_Type *base, uint32_t mask)
{
    base->CMP_IE |= mask;
}

/*!
 * @brief Disable compare interrupts for one or more command buffers.
 *
 * @param base DualADC peripheral base address.
 * @param mask OR combination of @ref dualadc_cmd_mask_t values.
 */
static inline void DUALADC_DisableCompareInterrupts(DUALADC_Type *base, uint32_t mask)
{
    base->CMP_IE &= ~mask;
}

/*!
 * @brief Get scan sequence completion status flags for ADCA and ADCB (STAT2[EOSI]).
 *
 * Returns the OR-combination of STAT2[EOSIA] and STAT2[EOSIB].
 * Test the return value against @ref kDUALADC_EndofScanAFlag and @ref kDUALADC_EndofScanBFlag.
 *
 * @param base DualADC peripheral base address.
 * @return OR combination of asserted end-of-scan flag bits from @ref dualadc_scan_seq_status_flag_t.
 */
static inline uint32_t DUALADC_GetScanSequenceStatusFlags(DUALADC_Type *base)
{
    return base->STAT2 & (DUALADC_STAT2_EOSIA_MASK | DUALADC_STAT2_EOSIB_MASK);
}

/*!
 * @brief Clear scan sequence completion status flags for ADCA and ADCB (STAT2[EOSI]).
 *
 * Writes 1 to the selected STAT2[EOSIA/B] bits to clear them.
 * Bits not present in @p mask are not affected.
 *
 * @param base DualADC peripheral base address.
 * @param mask OR combination of @ref kDUALADC_EndofScanAFlag and/or @ref kDUALADC_EndofScanBFlag.
 */
static inline void DUALADC_ClearScanSequenceStatusFlags(DUALADC_Type *base, uint32_t mask)
{
    base->STAT2 = mask & (DUALADC_STAT2_EOSIA_MASK | DUALADC_STAT2_EOSIB_MASK);
}

/*!
 * @brief Get the result-ready flags for all command buffers.
 *
 * Each bit indicates a conversion result is available in the corresponding RSLT register.
 * Flags clear automatically when the associated RSLT register is read by @ref DUALADC_GetConversionResult.
 *
 * @param base DualADC peripheral base address.
 * @return Bitmask of ready results; use @ref dualadc_cmd_mask_t to check individual commands.
 */
static inline uint32_t DUALADC_GetResultReadyFlags(DUALADC_Type *base)
{
    return base->RSLTRDY_STAT;
}

/*!
 * @brief Get the compare status flags for all command buffers.
 * @param base DualADC peripheral base address.
 * @return Bitmask of compare results; use @ref dualadc_cmd_mask_t to check individual commands.
 */
static inline uint32_t DUALADC_GetCompareStatusFlags(DUALADC_Type *base)
{
    return base->CMP_STAT;
}

/*!
 * @brief Clear compare status flags for one or more command buffers.
 * @param base DualADC peripheral base address.
 * @param mask OR combination of @ref dualadc_cmd_mask_t values to clear.
 */
static inline void DUALADC_ClearCompareStatusFlags(DUALADC_Type *base, uint32_t mask)
{
    base->CMP_STAT = mask;
}

/*!
 * @brief Get error status flags for ADCA and ADCB (STAT1).
 *
 * Returns the OR-combination of STAT1[INTVTIMEERR_FLAGA/B] and STAT1[OVERLAP_FLAGA/B].
 * Test the return value against @ref kDUALADC_OverlapAFlag, @ref kDUALADC_OverlapBFlag,
 * @ref kDUALADC_IntervalErrAFlag, and @ref kDUALADC_IntervalErrBFlag.
 *
 * @param base DualADC peripheral base address.
 * @return OR combination of asserted error flag bits from @ref dualadc_error_status_flag_t.
 */
static inline uint32_t DUALADC_GetErrorStatusFlags(DUALADC_Type *base)
{
    return base->STAT1 & (DUALADC_STAT1_INTVTIMEERR_FLAGA_MASK | DUALADC_STAT1_OVERLAP_FLAGA_MASK |
                          DUALADC_STAT1_INTVTIMEERR_FLAGB_MASK  | DUALADC_STAT1_OVERLAP_FLAGB_MASK);
}

/*!
 * @brief Clear error status flags for ADCA and ADCB (STAT1).
 *
 * Writes 1 to the selected STAT1[INTVTIMEERR_FLAG] and STAT1[OVERLAP_FLAG] bits to clear them.
 * Bits not present in @p mask are not affected.
 *
 * @param base DualADC peripheral base address.
 * @param mask OR combination of @ref dualadc_error_status_flag_t values.
 */
static inline void DUALADC_ClearErrorStatusFlags(DUALADC_Type *base, uint32_t mask)
{
    base->STAT1 = mask & (DUALADC_STAT1_INTVTIMEERR_FLAGA_MASK | DUALADC_STAT1_OVERLAP_FLAGA_MASK |
                          DUALADC_STAT1_INTVTIMEERR_FLAGB_MASK  | DUALADC_STAT1_OVERLAP_FLAGB_MASK);
}

/*!
 * @brief Get general read-only status flags for ADCA and ADCB (STAT0 and STAT2[STARTUPSTS]).
 *
 * Returns the OR-combination of:
 *   - STAT0[ADC_ACTIVEA], STAT0[ADC_ACTIVEB]  - conversion in progress indicators
 *   - STAT0[CAL_RDY]                          - calibration complete
 *   - STAT2[STARTUPSTSA], STAT2[STARTUPSTSB]  - analog startup complete
 *
 * All flags are read-only; none can be cleared by software.
 * Test the return value against @ref kDUALADC_AdcActiveAFlag, @ref kDUALADC_AdcActiveBFlag,
 * @ref kDUALADC_CalibrationReadyFlag, @ref kDUALADC_StartupDoneAFlag, and @ref kDUALADC_StartupDoneBFlag.
 *
 * @param base DualADC peripheral base address.
 * @return OR combination of asserted general status flag bits from @ref dualadc_status_flag_t.
 */
static inline uint32_t DUALADC_GetStatusFlags(DUALADC_Type *base)
{
    /* STAT0: ADC_ACTIVEA, ADC_ACTIVEB, and CAL_RDY at natural bit positions. */
    uint32_t u32Reg = base->STAT0 & (DUALADC_STAT0_ADC_ACTIVEA_MASK | DUALADC_STAT0_ADC_ACTIVEB_MASK |
                                     DUALADC_STAT0_CAL_RDY_MASK);

    /* STAT2: STARTUPSTSA and STARTUPSTSB at natural bit positions. */
    u32Reg |= base->STAT2 & (DUALADC_STAT2_STARTUPSTSA_MASK | DUALADC_STAT2_STARTUPSTSB_MASK);

    return u32Reg;
}

/*!
 * @brief Get the command buffer index currently executing in ADCA (0 = idle).
 * @param base DualADC peripheral base address.
 * @return Active command index for ADCA (0~20).
 */
static inline uint32_t DUALADC_GetActiveCommandA(DUALADC_Type *base)
{
    return (base->STAT0 & DUALADC_STAT0_CMDACTA_MASK) >> DUALADC_STAT0_CMDACTA_SHIFT;
}

/*!
 * @brief Get the command buffer index currently executing in ADCB (0 = idle).
 * @param base DualADC peripheral base address.
 * @return Active command index for ADCB (0~20).
 */
static inline uint32_t DUALADC_GetActiveCommandB(DUALADC_Type *base)
{
    return (base->STAT0 & DUALADC_STAT0_CMDACTB_MASK) >> DUALADC_STAT0_CMDACTB_SHIFT;
}

/*!
 * @brief Get the average-with-timer remaining repeat count for ADCA.
 * @param base DualADC peripheral base address.
 * @return Remaining sequence repeat count for ADCA.
 */
static inline uint32_t DUALADC_GetAvgTimerStatusA(DUALADC_Type *base)
{
    return (base->STAT0 & DUALADC_STAT0_AVGTSTSA_MASK) >> DUALADC_STAT0_AVGTSTSA_SHIFT;
}

/*!
 * @brief Get the average-with-timer remaining repeat count for ADCB.
 * @param base DualADC peripheral base address.
 * @return Remaining sequence repeat count for ADCB.
 */
static inline uint32_t DUALADC_GetAvgTimerStatusB(DUALADC_Type *base)
{
    return (base->STAT0 & DUALADC_STAT0_AVGTSTSB_MASK) >> DUALADC_STAT0_AVGTSTSB_SHIFT;
}

/*!
 * @brief Get the command index that was executing when a trigger overlap occurred for ADCA.
 * @note Valid only when @ref kDUALADC_OverlapAFlag is asserted.
 * @param base DualADC peripheral base address.
 * @return Command index that was active during the overlap event (1~20).
 */
static inline uint32_t DUALADC_GetOverlapCommandA(DUALADC_Type *base)
{
    return (base->STAT1 & DUALADC_STAT1_OVERLAP_CMDA_MASK) >> DUALADC_STAT1_OVERLAP_CMDA_SHIFT;
}

/*!
 * @brief Get the command index that was executing when a trigger overlap occurred for ADCB.
 * @note Valid only when @ref kDUALADC_OverlapBFlag is asserted.
 * @param base DualADC peripheral base address.
 * @return Command index that was active during the overlap event (1~20).
 */
static inline uint32_t DUALADC_GetOverlapCommandB(DUALADC_Type *base)
{
    return (base->STAT1 & DUALADC_STAT1_OVERLAP_CMDB_MASK) >> DUALADC_STAT1_OVERLAP_CMDB_SHIFT;
}

/*!
 * @brief Get the command index executing when an interval timer error occurred for ADCA.
 * @note Valid only when @ref kDUALADC_IntervalErrAFlag is asserted.
 * @param base DualADC peripheral base address.
 * @return Command index that was active during the interval error (1~20).
 */
static inline uint32_t DUALADC_GetIntervalErrCommandA(DUALADC_Type *base)
{
    return (base->STAT1 & DUALADC_STAT1_INTVTIMEERR_CMDA_MASK) >> DUALADC_STAT1_INTVTIMEERR_CMDA_SHIFT;
}

/*!
 * @brief Get the command index executing when an interval timer error occurred for ADCB.
 * @note Valid only when @ref kDUALADC_IntervalErrBFlag is asserted.
 * @param base DualADC peripheral base address.
 * @return Command index that was active during the interval error (1~20).
 */
static inline uint32_t DUALADC_GetIntervalErrCommandB(DUALADC_Type *base)
{
    return (base->STAT1 & DUALADC_STAT1_INTVTIMEERR_CMDB_MASK) >> DUALADC_STAT1_INTVTIMEERR_CMDB_SHIFT;
}

/*! @} */

#if defined(__cplusplus)
}
#endif

/*! @}*/

#endif /* FSL_DUAL_ADC_H_ */
