/*
 * Copyright 2026 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */
#ifndef FSL_SPC_H_
#define FSL_SPC_H_

#include "fsl_common.h"

/*!
 * @defgroup dsc_spc SPC: System Power Control Driver
 * @details This document consists of sections titled with <b>Driver Overview</b>, <b>Data Structures</b>,
 *          <b>Enumerations</b>, <b>Functions</b>, etc., each with an overview list and detailed documentation.
 *          It is recommended to read the <b>Driver Overview</b> first for it includes a comprehensive description
 *          of the peripheral, driver and driver changes. Other sections give detailed information for APIs, enums,
 *          macros, etc., for your further reference.
 * @{
 */

/*! @name Driver version */
/*! @{ */
/*! @brief SPC driver version. */
#define FSL_SPC_DRIVER_VERSION (MAKE_VERSION(2, 0, 0))
/*! @} */

/*******************************************************************************
 * SPC peripheral driver Change log
 ******************************************************************************/
/*!
 * @defgroup dsc_spc_driver_log The Driver Change Log
 * @ingroup dsc_spc
 * @{
 * The current SPC driver version is 2.0.0.
 *
 * - 2.0.0
 *   - Initial version.
 * @}
 */

/*******************************************************************************
 * Introduction of peripheral and driver
 ******************************************************************************/

/*!
 * @defgroup dsc_spc_intro SPC Peripheral and Driver Overview
 * @ingroup dsc_spc
 * @brief Content including 1) peripheral features, work logic and work method; 2) driver design logic and use method;
 *        3) typical use case.
 * @{
 *
 * Peripheral features and how this peripheral works
 * ==================================================
 *  The System Power Control(SPC) module owns the on-chip LDO_CORE regulator, the reference bandgap, the voltage
 *  detectors of the CORE/SYS/IO supplies and the voltage glitch detectors. It is the single place where the core
 *  supply voltage level, the SRAM read/write timing margin and the supply supervision behaviour are programmed.
 *
 *  The settings that apply while the core is running are held in the Active mode configuration registers, and a write
 *  to them takes effect immediately.
 *
 *  Features
 *  ---------
 *  + LDO_CORE regulator
 *      The LDO_CORE regulator supplies the core logic and the SRAM. Its voltage level is selected between the normal
 *      voltage and the overdrive voltage, and its drive strength is selected between low and normal. The overdrive
 *      voltage level is only supported in normal drive strength. Changing the voltage level sets the SPC busy flag,
 *      which the hardware clears when the new level has settled. The regulator control register comes out of reset
 *      locked and with the regulator enabled, and its fields are writable only once after the lock bit has been
 *      cleared, so software has at most one opportunity to change the enable, see
 *      SPC_UnlockCoreLDORegulatorSetting().
 *
 *  + Reference bandgap
 *      The bandgap feeds the voltage detectors, the glitch detectors and the analog modules, and it is also required
 *      by the normal drive strength of the LDO_CORE regulator. It can be disabled, or enabled with its buffer
 *      disabled or enabled.
 *
 *  + Voltage detectors
 *      Three voltage domains are supervised, and they do not implement the same detectors:
 *      @verbatim
        domain  low-voltage interrupt  low-voltage reset  high-voltage interrupt  high-voltage reset  LVD level select
        CORE            yes                   yes                  yes                   yes                no
        SYS             yes                   yes                  yes                   yes                yes
        IO              yes                   no                   no                    no                 no
        @endverbatim
 *      Each domain has its own configuration register holding the interrupt and reset enables. That register carries a
 *      lock bit, which only protects the reset enables, and on the system domain the low-voltage level select as well:
 *      the interrupt enables stay writable whether the domain is locked or not. Enabling a detector is a separate step,
 *      done through the Active mode configuration register, and it requires the bandgap to be enabled and the LDO_CORE
 *      drive strength not to be low.
 *      Two kinds of information are reported: a latched flag per detector, cleared by writing 1 to it, and a
 *      real-time status bit that mirrors the current comparator output.
 *
 *  + Voltage glitch detectors
 *      Two independent glitch detectors watch for fast negative excursions, one on the CORE VDD supply and one on the
 *      VDD supply. Both are enabled after a power-on reset and are gated together by a single Active mode enable bit.
 *      Each one drives a 4-bit ripple counter; software selects which counter bit is used as the trigger, programs the
 *      timeout after which the detect logic re-arms, and chooses whether a detection raises an interrupt, asserts a
 *      reset, or is only reported through the ripple counter flags. The reset enable of each detector can be locked
 *      independently. The CORE VDD detector additionally supports a high gain mode and allows its high-VDD amplifier
 *      to be powered down; the VDD detector does not implement either option.
 *
 *  + SRAM read/write timing margin
 *      The SRAM timing margin must be programmed to match the core supply voltage. A margin update is applied through
 *      a request/acknowledge handshake, so the SPC does not change the SRAM timing while an access is in flight.
 *
 *  + Analog module control
 *      The SPC gates the high-speed comparators and their internal DACs in Active mode, so that unused analog blocks
 *      do not load the reference.
 *
 *  + External voltage domain isolation
 *      Three external voltage domains can be isolated, and the resulting isolation state is reported back.
 *
 *  How this peripheral works
 *  -------------------------
 *  All SPC registers are 32 bits wide and must be accessed with 32-bit accesses only. An 8-bit or 16-bit write to a
 *  writable SPC register causes a transfer error. Every API in this driver reads and writes whole registers, so this
 *  restriction is satisfied as long as the caller does not touch the registers directly.
 *
 *  The settings of the regulator, of the bandgap and of the detectors constrain each other:
 *  + The bandgap must be enabled before the LDO_CORE drive strength is set to normal, and it can only be disabled
 *    once the drive strength is low, all the voltage detectors are disabled and the glitch detect is disabled.
 *  + A voltage detector can only be enabled while the bandgap is enabled and the drive strength is normal.
 *  + The core voltage level can only be changed while the drive strength is normal. Raising the drive strength from
 *    low back to normal requires the voltage level to be set back, in the same write, to the level that was in effect
 *    when the drive strength was lowered.
 *  + The overdrive voltage level is not supported in low drive strength, so the level has to be brought back to the
 *    normal voltage before the drive strength is lowered.
 *  This driver checks each of these conditions before it writes a register, and reports a status code instead of
 *  programming a combination the hardware would refuse.
 *
 *  How this driver is designed to make this peripheral works.
 * ===========================================================
 *  The driver is organised around the distinctions the hardware makes:
 *  + The three voltage domains share one configuration type, @ref spc_voltage_detect_config_t, and one set of
 *    functions taking a @ref spc_voltage_domain_t selector. The driver knows which options each domain implements
 *    and returns #kStatus_InvalidArgument when an option is requested on a domain that does not have it, so the
 *    per-domain differences do not have to be rediscovered by every caller.
 *  + The two glitch detectors likewise share @ref spc_glitch_detector_config_t and a @ref spc_glitch_detector_t
 *    selector.
 *  + Both configuration types express their boolean options as one bit-mask field, so that an option can be added
 *    without changing the layout of the structure, and every option is stated in the positive: a bit that is set
 *    enables something.
 *  + Every function that the hardware can refuse returns a status code. Functions that can not fail return void.
 *  + The individual settings can be read back one by one, and the whole Active mode configuration can be read back
 *    into a @ref spc_active_mode_config_t by SPC_GetActiveModeConfig() and reapplied by SPC_SetActiveModeConfig(),
 *    which is what makes a save and restore around a critical section possible.
 *
 *  Register spins are bounded by #SPC_RETRY_TIMES, which defaults to waiting forever to preserve the behaviour of a
 *  correctly working device. Define it to a non-zero value to get #kStatus_Timeout instead of a hang.
 *
 *  Changing the core supply voltage
 *  --------------------------------
 *  The SRAM read/write timing margin, the flash read wait states and the core clock frequency all have to move with
 *  the core supply voltage. The driver provides the individual steps and leaves the sequence to the application, which
 *  owns the flash and clock settings. The order mandated by the reference manual is:
 *      @verbatim
        raise the voltage:                              lower the voltage:

        1. SPC_SetCoreVoltageLevel()                    1. reduce the core frequency
           (programs the level and waits for the        2. program the flash read wait states
            busy flag to clear)                         3. SPC_SetSRAMOperateVoltage()
        2. program the flash read wait states           4. SPC_SetCoreVoltageLevel()
        3. SPC_SetSRAMOperateVoltage()
        4. raise the core frequency
        @endverbatim
 *  Mask the voltage detections with SPC_MaskVoltageDetections() around the whole sequence, and unmask them with
 *  SPC_UnmaskVoltageDetections() once the supply has settled.
 *
 *
 * How to use this driver
 * =======================
 *  The SPC is already running when software starts: the boot ROM has enabled LDO_CORE and selected a boot voltage, so
 *  the driver adjusts individual settings rather than initialising the peripheral.
 *
 *  To supervise a supply:
 *  + Define a @ref spc_voltage_detect_config_t variable, set @c u32ControlMask to the interrupts and resets wanted,
 *    and program it with SPC_SetVoltageDetectConfig() for the domain concerned.
 *  + Invoke SPC_EnableVoltageDetectors() with the detectors to turn on.
 *  + In the SPC interrupt handler, read SPC_GetVoltageDetectFlags() to find out which detector triggered and clear it
 *    with SPC_ClearVoltageDetectFlags().
 *  + Invoke SPC_LockVoltageDetectResetControl() once the reset enables must not change any more.
 *
 *  To watch for supply glitches:
 *  + Define a @ref spc_glitch_detector_config_t variable, select the ripple counter bit, the timeout and the options,
 *    and program it with SPC_SetGlitchDetectorConfig() for the detector concerned.
 *  + Invoke SPC_EnableGlitchDetect() with true to make sure the detect hardware is running.
 *  + Read the counter with SPC_GetGlitchCounter() and clear the bits that have been handled with
 *    SPC_ClearGlitchCounter().
 *
 *
 * Typical Use Case
 * ================
 *  1. Enabling supply supervision with an interrupt.
 *      @code
            spc_voltage_detect_config_t sConfig;

            sConfig.u32ControlMask   = (uint32_t)kSPC_LowVoltageInterrupt | (uint32_t)kSPC_HighVoltageInterrupt;
            sConfig.eLowVoltageLevel = kSPC_LowVoltageLevelNormal;

            (void)SPC_SetVoltageDetectConfig(SPC, kSPC_VoltageDomainCore, &sConfig);
            (void)SPC_SetVoltageDetectConfig(SPC, kSPC_VoltageDomainSystem, &sConfig);

            (void)SPC_EnableVoltageDetectors(SPC, (uint32_t)kSPC_CoreLowVoltageDetector |
                                                     (uint32_t)kSPC_CoreHighVoltageDetector |
                                                     (uint32_t)kSPC_SystemLowVoltageDetector |
                                                     (uint32_t)kSPC_SystemHighVoltageDetector);
        @endcode
 *      From now on a supply excursion sets a flag in VD_STAT and raises the SPC interrupt.
 *
 *  2. Moving the core supply to the overdrive voltage.
 *      @code
            SPC_MaskVoltageDetections(SPC);

            if (SPC_SetCoreVoltageLevel(SPC, kSPC_CoreVoltageOverDrive) == kStatus_Success)
            {
                (* Program the flash read wait states for the new voltage here. *)

                (void)SPC_SetSRAMOperateVoltage(SPC, kSPC_SramOperateAt1P2V);

                (* Raise the core clock frequency here. *)
            }

            SPC_UnmaskVoltageDetections(SPC);
        @endcode
 *      To go back to the normal voltage, run the same steps in the reverse order: lower the frequency first, then the
 *      wait states and the SRAM margin, and change the core voltage level last.
 *
 *  3. Saving and restoring the whole Active mode configuration.
 *      @code
            spc_active_mode_config_t sSaved;

            SPC_GetActiveModeConfig(SPC, &sSaved);

            (* Change whatever is needed here. *)

            (void)SPC_SetActiveModeConfig(SPC, &sSaved);
        @endcode
 *
 *  4. Enabling a comparator through the SPC.
 *      A high-speed comparator and its internal DAC are only supplied when the SPC has been told to enable them.
 *      @code
            SPC_EnableAnalogModules(SPC, (uint32_t)kSPC_AnalogModuleHscmp0 | (uint32_t)kSPC_AnalogModuleHscmp0Dac);
        @endcode
 * @}
 */

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/*! @brief The number of times a register spin is retried before #kStatus_Timeout is reported. */
#ifndef SPC_RETRY_TIMES
#define SPC_RETRY_TIMES 0U /* Define to zero means keep waiting until the flag is assert/deassert. */
#endif

/*!
 * @brief SPC status enumeration.
 */
enum
{
    kStatus_SPC_Busy = MAKE_STATUS(kStatusGroup_SPC, 0U),                  /*!< The SPC instance is busy executing any
                                                                                 type of voltage level transition. */
    kStatus_SPC_VoltageDetectActive = MAKE_STATUS(kStatusGroup_SPC, 5U),   /*!< At least one voltage detector is
                                                                      enabled, so the LDO_CORE drive strength can not
                                                                      be set to low. */
    kStatus_SPC_BandgapRequired = MAKE_STATUS(kStatusGroup_SPC, 6U),       /*!< The requested setting needs the bandgap,
                                                                      so the bandgap can not be disabled or the setting
                                                                      can not be applied while it is disabled. */
    kStatus_SPC_CoreVoltageLevelWrong = MAKE_STATUS(kStatusGroup_SPC, 7U), /*!< The LDO_CORE regulator regulates to the
                                                                    overdrive voltage level, which the low drive
                                                                    strength does not support. */
    kStatus_SPC_DriveStrengthTooLow = MAKE_STATUS(kStatusGroup_SPC, 8U),   /*!< The LDO_CORE drive strength is low, so
                                                                      the core voltage level can not be changed and no
                                                                      voltage detector can be enabled. */
};

/*!
 * @brief The voltage domains supervised by the SPC.
 *
 * The domains do not implement the same set of detectors, see @ref spc_voltage_detect_config_t.
 */
typedef enum _spc_voltage_domain
{
    kSPC_VoltageDomainCore   = 0U, /*!< The core supply voltage domain. */
    kSPC_VoltageDomainSystem = 1U, /*!< The system supply voltage domain. */
    kSPC_VoltageDomainIO     = 2U, /*!< The IO supply voltage domain. */
} spc_voltage_domain_t;

/*!
 * @brief The behaviour of the voltage detectors of one voltage domain.
 *
 * Used to build the @c u32ControlMask member of @ref spc_voltage_detect_config_t. A bit that is set enables the
 * corresponding response, a bit that is cleared disables it. Requesting a response that the selected domain does not
 * implement is reported as #kStatus_InvalidArgument.
 */
enum _spc_voltage_detect_control
{
    kSPC_LowVoltageInterrupt  = 1UL << 0UL, /*!< Raise an interrupt when the supply falls below the low threshold. */
    kSPC_LowVoltageReset      = 1UL << 1UL, /*!< Assert a reset when the supply falls below the low threshold. */
    kSPC_HighVoltageInterrupt = 1UL << 2UL, /*!< Raise an interrupt when the supply rises above the high threshold. */
    kSPC_HighVoltageReset     = 1UL << 3UL, /*!< Assert a reset when the supply rises above the high threshold. */
};

/*!
 * @brief The voltage detectors that can be enabled in Active mode.
 *
 * Used to build the mask passed to SPC_EnableVoltageDetectors() and returned by
 * SPC_GetEnabledVoltageDetectors().
 */
enum _spc_voltage_detector
{
    kSPC_CoreLowVoltageDetector    = SPC_ACTIVE_CFG_CORE_LVDE_MASK, /*!< The core supply low-voltage detector. */
    kSPC_CoreHighVoltageDetector   = SPC_ACTIVE_CFG_CORE_HVDE_MASK, /*!< The core supply high-voltage detector. */
    kSPC_SystemLowVoltageDetector  = SPC_ACTIVE_CFG_SYS_LVDE_MASK,  /*!< The system supply low-voltage detector. */
    kSPC_SystemHighVoltageDetector = SPC_ACTIVE_CFG_SYS_HVDE_MASK,  /*!< The system supply high-voltage detector. */
    kSPC_IOLowVoltageDetector      = SPC_ACTIVE_CFG_IO_LVDE_MASK,   /*!< The IO supply low-voltage detector. */
    kSPC_AllVoltageDetectors       = SPC_ACTIVE_CFG_CORE_LVDE_MASK | SPC_ACTIVE_CFG_CORE_HVDE_MASK |
                               SPC_ACTIVE_CFG_SYS_LVDE_MASK | SPC_ACTIVE_CFG_SYS_HVDE_MASK |
                               SPC_ACTIVE_CFG_IO_LVDE_MASK, /*!< All the detectors above. */
};

/*!
 * @brief The latched voltage detect flags.
 *
 * These flags are set by the hardware and stay set until they are cleared by SPC_ClearVoltageDetectFlags().
 */
enum _spc_voltage_detect_flag
{
    kSPC_CoreLowVoltageFlag    = SPC_VD_STAT_COREVDD_LVDF_MASK, /*!< The core supply fell below the low threshold. */
    kSPC_SystemLowVoltageFlag  = SPC_VD_STAT_SYSVDD_LVDF_MASK,  /*!< The system supply fell below the low threshold. */
    kSPC_IOLowVoltageFlag      = SPC_VD_STAT_IOVDD_LVDF_MASK,   /*!< The IO supply fell below the low threshold. */
    kSPC_CoreHighVoltageFlag   = SPC_VD_STAT_COREVDD_HVDF_MASK, /*!< The core supply rose above the high threshold. */
    kSPC_SystemHighVoltageFlag = SPC_VD_STAT_SYSVDD_HVDF_MASK,  /*!< The system supply rose above the high
                                                                     threshold. */
    kSPC_AllVoltageDetectFlags = SPC_VD_STAT_COREVDD_LVDF_MASK | SPC_VD_STAT_SYSVDD_LVDF_MASK |
                                 SPC_VD_STAT_IOVDD_LVDF_MASK | SPC_VD_STAT_COREVDD_HVDF_MASK |
                                 SPC_VD_STAT_SYSVDD_HVDF_MASK, /*!< All the flags above. */
};

/*!
 * @brief The real time voltage detect states.
 *
 * Unlike the flags of @ref _spc_voltage_detect_flag, these bits are not latched: they mirror the current output of
 * each detector and can not be cleared.
 */
enum _spc_voltage_detect_state
{
    kSPC_CoreLowVoltageState = SPC_VD_STAT_COREVDD_LVD_STATUS_MASK,   /*!< The core supply is below the low
                                                                           threshold. */
    kSPC_SystemLowVoltageState = SPC_VD_STAT_SYSVDD_LVD_STATUS_MASK,  /*!< The system supply is below the low
                                                                           threshold. */
    kSPC_IOLowVoltageState = SPC_VD_STAT_IOVDD_LVD_STATUS_MASK,       /*!< The IO supply is below the low
                                                                           threshold. */
    kSPC_CoreHighVoltageState = SPC_VD_STAT_COREVDD_HVD_STATUS_MASK,  /*!< The core supply is above the high
                                                                           threshold. */
    kSPC_SystemHighVoltageState = SPC_VD_STAT_SYSVDD_HVD_STATUS_MASK, /*!< The system supply is above the high
                                                                           threshold. */
    kSPC_AllVoltageDetectStates = SPC_VD_STAT_COREVDD_LVD_STATUS_MASK | SPC_VD_STAT_SYSVDD_LVD_STATUS_MASK |
                                  SPC_VD_STAT_IOVDD_LVD_STATUS_MASK | SPC_VD_STAT_COREVDD_HVD_STATUS_MASK |
                                  SPC_VD_STAT_SYSVDD_HVD_STATUS_MASK, /*!< All the states above. */
};

/*!
 * @brief The voltage glitch detectors of the SPC.
 */
typedef enum _spc_glitch_detector
{
    kSPC_GlitchDetectorCoreVdd = 0U, /*!< The glitch detector of the core VDD/VSS supply. */
    kSPC_GlitchDetectorVdd     = 1U, /*!< The glitch detector of the VDD/VSS supply. */
} spc_glitch_detector_t;

/*!
 * @brief The options of one voltage glitch detector.
 *
 * Used to build the @c u32OptionMask member of @ref spc_glitch_detector_config_t. A bit that is set enables the
 * corresponding option. Requesting an option that the selected detector does not implement is reported as
 * #kStatus_InvalidArgument.
 */
enum _spc_glitch_detector_option
{
    kSPC_GlitchDetectorInterrupt    = 1UL << 0UL,     /*!< Raise an interrupt when the selected counter bit is set. */
    kSPC_GlitchDetectorReset        = 1UL << 1UL,     /*!< Assert a reset when the selected counter bit is set. */
    kSPC_GlitchDetectorHighGainMode = 1UL << 2UL,     /*!< Run the detector in high gain mode. Only implemented by
                                                           #kSPC_GlitchDetectorCoreVdd. */
    kSPC_GlitchDetectorHighVddAmplifier = 1UL << 3UL, /*!< Keep the high VDD amplifier of the detector powered. Only
                                                           implemented by #kSPC_GlitchDetectorCoreVdd, where it is
                                                           powered after reset. */
};

/*!
 * @brief The bits of the 4-bit ripple counter of a glitch detector.
 *
 * Used to build the mask returned by SPC_GetGlitchCounter() and passed to SPC_ClearGlitchCounter().
 */
enum _spc_glitch_counter_flag
{
    kSPC_GlitchCounterBit0Flag = 1UL << 0UL, /*!< Bit 0 of the ripple counter is set. */
    kSPC_GlitchCounterBit1Flag = 1UL << 1UL, /*!< Bit 1 of the ripple counter is set. */
    kSPC_GlitchCounterBit2Flag = 1UL << 2UL, /*!< Bit 2 of the ripple counter is set. */
    kSPC_GlitchCounterBit3Flag = 1UL << 3UL, /*!< Bit 3 of the ripple counter is set. */
    kSPC_AllGlitchCounterFlags = 0xFUL,      /*!< All the bits of the ripple counter. */
};

/*!
 * @brief The analog modules that the SPC can enable in Active mode.
 *
 * The available modules are the high-speed comparators and the internal DAC of each comparator. Refer to the chip
 * reference manual for the number of comparators that are actually implemented.
 */
enum _spc_analog_module
{
    kSPC_AnalogModuleHscmp0    = 1UL << 0UL,  /*!< HSCMP0. */
    kSPC_AnalogModuleHscmp1    = 1UL << 1UL,  /*!< HSCMP1. */
    kSPC_AnalogModuleHscmp2    = 1UL << 2UL,  /*!< HSCMP2. */
    kSPC_AnalogModuleHscmp3    = 1UL << 3UL,  /*!< HSCMP3. */
    kSPC_AnalogModuleHscmp4    = 1UL << 4UL,  /*!< HSCMP4. */
    kSPC_AnalogModuleHscmp5    = 1UL << 5UL,  /*!< HSCMP5. */
    kSPC_AnalogModuleHscmp6    = 1UL << 6UL,  /*!< HSCMP6. */
    kSPC_AnalogModuleHscmp7    = 1UL << 7UL,  /*!< HSCMP7. */
    kSPC_AnalogModuleHscmp0Dac = 1UL << 8UL,  /*!< The internal DAC of HSCMP0. */
    kSPC_AnalogModuleHscmp1Dac = 1UL << 9UL,  /*!< The internal DAC of HSCMP1. */
    kSPC_AnalogModuleHscmp2Dac = 1UL << 10UL, /*!< The internal DAC of HSCMP2. */
    kSPC_AnalogModuleHscmp3Dac = 1UL << 11UL, /*!< The internal DAC of HSCMP3. */
    kSPC_AnalogModuleHscmp4Dac = 1UL << 12UL, /*!< The internal DAC of HSCMP4. */
    kSPC_AnalogModuleHscmp5Dac = 1UL << 13UL, /*!< The internal DAC of HSCMP5. */
    kSPC_AnalogModuleHscmp6Dac = 1UL << 14UL, /*!< The internal DAC of HSCMP6. */
    kSPC_AnalogModuleHscmp7Dac = 1UL << 15UL, /*!< The internal DAC of HSCMP7. */
    kSPC_AllAnalogModules      = 0xFFFFUL,    /*!< All the modules above. */
};

/*!
 * @brief The external voltage domains the SPC can isolate.
 *
 * Used to build the mask passed to SPC_SetExternalDomainIsolation() and returned by
 * SPC_GetExternalDomainIsolation() and SPC_GetExternalDomainStatus().
 */
enum _spc_external_domain
{
    kSPC_ExternalDomainVdd = 1UL << 0UL,    /*!< The VDD supply. This domain supplies the SPC itself, so it must not
                                                 be isolated. */
    kSPC_ExternalDomainVddUsb = 1UL << 1UL, /*!< The VDD_USB supply. */
    kSPC_ExternalDomainVddP2  = 1UL << 2UL, /*!< The VDD_P2/VDDA supply. */
};

/*!
 * @brief SPC Bandgap mode enumeration in Active mode.
 */
typedef enum _spc_bandgap_mode
{
    kSPC_BandgapDisabled              = 0x0U, /*!< Bandgap disabled. */
    kSPC_BandgapEnabledBufferDisabled = 0x1U, /*!< Bandgap enabled with Buffer disabled. */
    kSPC_BandgapEnabledBufferEnabled  = 0x2U, /*!< Bandgap enabled with Buffer enabled. */
    kSPC_BandgapReserved              = 0x3U, /*!< Reserved, can be read back but not programmed. */
} spc_bandgap_mode_t;

/*!
 * @brief The core supply voltage levels the LDO_CORE regulator can regulate to.
 */
typedef enum _spc_core_voltage_level
{
    kSPC_CoreVoltageNormal    = 0x2U, /*!< Regulate the core supply to the normal voltage. */
    kSPC_CoreVoltageOverDrive = 0x3U, /*!< Regulate the core supply to the overdrive voltage. */
} spc_core_voltage_level_t;

/*!
 * @brief LDO_CORE regulator drive strength enumeration in Active mode.
 */
typedef enum _spc_core_ldo_drive_strength
{
    kSPC_CoreLDOLowDriveStrength    = 0x0U, /*!< LDO_CORE drive strength set to low. */
    kSPC_CoreLDONormalDriveStrength = 0x1U, /*!< LDO_CORE drive strength set to normal. */
} spc_core_ldo_drive_strength_t;

/*!
 * @brief The low-voltage detect levels of a voltage domain.
 *
 * Refer to the chip data sheet for the trip point each level stands for.
 */
typedef enum _spc_low_voltage_level
{
    kSPC_LowVoltageLevelNormal = 0x0U, /*!< Use the normal low-voltage detect level. */
    kSPC_LowVoltageLevelSafe   = 0x1U, /*!< Use the safe low-voltage detect level. */
} spc_low_voltage_level_t;

/*!
 * @brief The bit of the 4-bit ripple counter a glitch detector triggers on.
 *
 * Selecting a higher bit means more glitches have to be counted within the timeout window before the detector
 * triggers its interrupt or its reset.
 */
typedef enum _spc_glitch_ripple_counter
{
    kSPC_GlitchRippleCounterBit0 = 0x0U, /*!< Trigger on bit 0 of the 4-bit ripple counter. */
    kSPC_GlitchRippleCounterBit1 = 0x1U, /*!< Trigger on bit 1 of the 4-bit ripple counter. */
    kSPC_GlitchRippleCounterBit2 = 0x2U, /*!< Trigger on bit 2 of the 4-bit ripple counter. */
    kSPC_GlitchRippleCounterBit3 = 0x3U, /*!< Trigger on bit 3 of the 4-bit ripple counter. */
} spc_glitch_ripple_counter_t;

/*!
 * @brief The list of the operating voltages for the SRAM's read/write timing margin.
 */
typedef enum _spc_sram_operate_voltage
{
    kSPC_SramOperateAt1P1V = 0x2U, /*!< SRAM configured for 1.1V operation. */
    kSPC_SramOperateAt1P2V = 0x3U, /*!< SRAM configured for 1.2V operation. */
} spc_sram_operate_voltage_t;

/*!
 * @brief The voltage detect configuration of one voltage domain.
 *
 * The same type describes all three domains. A domain that does not implement an option rejects it:
 * + #kSPC_VoltageDomainCore accepts every bit of @ref _spc_voltage_detect_control, and ignores @c eLowVoltageLevel.
 * + #kSPC_VoltageDomainSystem accepts every bit of @ref _spc_voltage_detect_control and uses @c eLowVoltageLevel.
 * + #kSPC_VoltageDomainIO accepts #kSPC_LowVoltageInterrupt only, and ignores @c eLowVoltageLevel.
 */
typedef struct _spc_voltage_detect_config
{
    uint32_t u32ControlMask;                  /*!< The responses to enable, a mask of @ref
                                                   _spc_voltage_detect_control. */
    spc_low_voltage_level_t eLowVoltageLevel; /*!< The low-voltage detect level, only used by the domains that
                                                   implement it. */
} spc_voltage_detect_config_t;

/*!
 * @brief The configuration of one voltage glitch detector.
 *
 * The same type describes both detectors. #kSPC_GlitchDetectorVdd only accepts #kSPC_GlitchDetectorInterrupt and
 * #kSPC_GlitchDetectorReset in @c u32OptionMask.
 */
typedef struct _spc_glitch_detector_config
{
    uint32_t u32OptionMask;                     /*!< The options to enable, a mask of @ref
                                                     _spc_glitch_detector_option. */
    spc_glitch_ripple_counter_t eRippleCounter; /*!< The ripple counter bit the detector triggers on. */
    uint8_t u8ResetTimeout;                     /*!< The timeout, in the range 1 to 15, after which the glitch detect
                                                     and compare logic is reset once an initial glitch has been
                                                     detected. The hardware does not accept a timeout of 0. */
} spc_glitch_detector_config_t;

/*!
 * @brief The whole Active mode configuration of the SPC.
 *
 * Read back by SPC_GetActiveModeConfig() and applied by SPC_SetActiveModeConfig(), which programs the members in the
 * order the hardware requires.
 */
typedef struct _spc_active_mode_config
{
    spc_bandgap_mode_t eBandgapMode;                     /*!< The bandgap mode. */
    spc_core_voltage_level_t eCoreVoltageLevel;          /*!< The core supply voltage level. */
    spc_core_ldo_drive_strength_t eCoreLDODriveStrength; /*!< The LDO_CORE regulator drive strength. */
    uint16_t u16VoltageTrimDelay;                        /*!< The delay applied when the regulator changes voltage
                                                              level, in cycles of the SPC clock. Set it to 0 to keep
                                                              the delay the hardware is using, which is the
                                                              recommended value NXP trims for the device. */
    uint32_t u32EnabledDetectors;                        /*!< The voltage detectors to enable, a mask of @ref
                                                              _spc_voltage_detector. */
    bool bEnableGlitchDetect;                            /*!< Whether the voltage glitch detect hardware runs. */
} spc_active_mode_config_t;

/*******************************************************************************
 * API
 ******************************************************************************/
#if defined(__cplusplus)
extern "C" {
#endif /* __cplusplus */

/*!
 * @name SPC Status Interfaces
 * @{
 */

/*!
 * @brief Gets the version of the SPC peripheral.
 *
 * @param base SPC peripheral base address.
 * @return The raw content of the version ID register.
 */
static inline uint32_t SPC_GetVersionId(SPC_Type *base)
{
    return base->VERID;
}

/*!
 * @brief Checks whether the SPC is executing a voltage level transition.
 *
 * @param base SPC peripheral base address.
 * @retval true The SPC is busy.
 * @retval false The SPC is not busy.
 */
static inline bool SPC_IsBusy(SPC_Type *base)
{
    return ((base->SC & SPC_SC_BUSY_MASK) != 0UL);
}

/*!
 * @brief Checks whether the LDO_CORE regulator is settling after a drive strength or voltage level change.
 *
 * @param base SPC peripheral base address.
 * @retval true The regulator is busy.
 * @retval false The regulator is not busy.
 */
static inline bool SPC_IsRegulatorBusy(SPC_Type *base)
{
    return ((base->SC & SPC_SC_REG_BUSY_MASK) != 0UL);
}

/*!
 * @brief Waits until the SPC has finished the voltage level transition in progress.
 *
 * @param base SPC peripheral base address.
 *
 * @retval kStatus_Success The SPC is no longer busy.
 * @retval kStatus_Timeout The busy flag was still set after #SPC_RETRY_TIMES reads.
 */
status_t SPC_WaitBusy(SPC_Type *base);

/*! @} */

/*!
 * @name Bandgap Control Interfaces
 * @{
 */

/*!
 * @brief Gets the bandgap mode.
 *
 * @param base SPC peripheral base address.
 * @return The bandgap mode, see @ref spc_bandgap_mode_t.
 */
static inline spc_bandgap_mode_t SPC_GetBandgapMode(SPC_Type *base)
{
    return (spc_bandgap_mode_t)(uint32_t)((base->ACTIVE_CFG & SPC_ACTIVE_CFG_BGMODE_MASK) >>
                                          SPC_ACTIVE_CFG_BGMODE_SHIFT);
}

/*!
 * @brief Sets the bandgap mode.
 *
 * @note The bandgap can only be disabled once nothing depends on it: all the voltage detectors must be disabled, the
 *       voltage glitch detect must be disabled and the LDO_CORE regulator must be in low drive strength. Other system
 *       resources such as the PLL and the comparators also need the bandgap, and the SPC does not know about them.
 *
 * @param base SPC peripheral base address.
 * @param eMode The bandgap mode to program.
 *
 * @retval kStatus_Success The bandgap mode has been programmed.
 * @retval kStatus_InvalidArgument @p eMode is #kSPC_BandgapReserved.
 * @retval kStatus_SPC_BandgapRequired The bandgap can not be disabled because something still depends on it.
 */
status_t SPC_SetBandgapMode(SPC_Type *base, spc_bandgap_mode_t eMode);

/*! @} */

/*!
 * @name LDO_CORE Regulator Control Interfaces
 * @{
 */

/*!
 * @brief Enables/Disables the LDO_CORE regulator.
 *
 * @note The regulator control register comes out of reset locked, and it only resets again on a power-on reset or on a
 *       low or high voltage detect event. Invoke SPC_UnlockCoreLDORegulatorSetting() first, otherwise the hardware
 *       ignores this write. Once unlocked, the register accepts a single write, so the value programmed here is the
 *       value the regulator keeps until the next such reset.
 *
 * @note The regulator is enabled out of reset. Disabling it requires the core supply to be provided from outside the
 *       chip, refer to the PMIC_MODE field of the customer configuration area.
 *
 * @param base SPC peripheral base address.
 * @param bEnable Used to control the behaviour of the LDO_CORE regulator.
 *                - \b true Enable the LDO_CORE regulator.
 *                - \b false Disable the LDO_CORE regulator.
 */
static inline void SPC_EnableCoreLDORegulator(SPC_Type *base, bool bEnable)
{
    if (bEnable)
    {
        base->CNTRL |= SPC_CNTRL_CORELDO_EN_MASK;
    }
    else
    {
        base->CNTRL &= ~SPC_CNTRL_CORELDO_EN_MASK;
    }
}

/*!
 * @brief Checks whether the LDO_CORE regulator is enabled.
 *
 * @param base SPC peripheral base address.
 * @retval true The LDO_CORE regulator is enabled.
 * @retval false The LDO_CORE regulator is disabled.
 */
static inline bool SPC_IsCoreLDORegulatorEnabled(SPC_Type *base)
{
    return ((base->CNTRL & SPC_CNTRL_CORELDO_EN_MASK) != 0UL);
}

/*!
 * @brief Locks the LDO_CORE regulator enable setting.
 *
 * After invoking this function, writes to the regulator enable are ignored until the register is unlocked again or the
 * chip takes a power-on reset or a voltage detect reset.
 *
 * @param base SPC peripheral base address.
 */
static inline void SPC_LockCoreLDORegulatorSetting(SPC_Type *base)
{
    base->CNTRL |= SPC_CNTRL_LOCK_MASK;
}

/*!
 * @brief Unlocks the LDO_CORE regulator enable setting.
 *
 * The setting comes out of reset locked, so this function has to be invoked before SPC_EnableCoreLDORegulator() can
 * have any effect. The enable accepts one write only once it is unlocked.
 *
 * @param base SPC peripheral base address.
 */
static inline void SPC_UnlockCoreLDORegulatorSetting(SPC_Type *base)
{
    base->CNTRL &= ~SPC_CNTRL_LOCK_MASK;
}

/*!
 * @brief Checks whether the LDO_CORE regulator enable setting is locked.
 *
 * @param base SPC peripheral base address.
 * @retval true Writes to the regulator enable are ignored.
 * @retval false Writes to the regulator enable are allowed.
 */
static inline bool SPC_IsCoreLDORegulatorSettingLocked(SPC_Type *base)
{
    return ((base->CNTRL & SPC_CNTRL_LOCK_MASK) != 0UL);
}

/*!
 * @brief Gets the core supply voltage level the LDO_CORE regulator regulates to.
 *
 * @param base SPC peripheral base address.
 * @return The core supply voltage level, see @ref spc_core_voltage_level_t.
 */
static inline spc_core_voltage_level_t SPC_GetCoreVoltageLevel(SPC_Type *base)
{
    return (spc_core_voltage_level_t)(uint32_t)((base->ACTIVE_CFG & SPC_ACTIVE_CFG_CORELDO_VDD_LVL_MASK) >>
                                                SPC_ACTIVE_CFG_CORELDO_VDD_LVL_SHIFT);
}

/*!
 * @brief Sets the core supply voltage level the LDO_CORE regulator regulates to.
 *
 * The function returns once the hardware has cleared the busy flag, so the new level has settled when it returns
 * successfully.
 *
 * @note This is one step of a longer sequence: the SRAM read/write timing margin, the flash read wait states and the
 *       core clock frequency have to move with the core supply. See the driver overview for the required order.
 *
 * @note The overdrive voltage level is only supported in normal drive strength, which this function enforces by
 *       refusing to program any level while the drive strength is low.
 *
 * @param base SPC peripheral base address.
 * @param eLevel The core supply voltage level to program.
 *
 * @retval kStatus_Success The new voltage level has settled.
 * @retval kStatus_Timeout The busy flag was still set after #SPC_RETRY_TIMES reads.
 * @retval kStatus_SPC_DriveStrengthTooLow The voltage level can only be changed while the LDO_CORE regulator is in
 *                                         normal drive strength.
 */
status_t SPC_SetCoreVoltageLevel(SPC_Type *base, spc_core_voltage_level_t eLevel);

/*!
 * @brief Gets the LDO_CORE regulator drive strength.
 *
 * @param base SPC peripheral base address.
 * @return The drive strength, see @ref spc_core_ldo_drive_strength_t.
 */
static inline spc_core_ldo_drive_strength_t SPC_GetCoreLDODriveStrength(SPC_Type *base)
{
    return (spc_core_ldo_drive_strength_t)(uint32_t)((base->ACTIVE_CFG & SPC_ACTIVE_CFG_CORELDO_VDD_DS_MASK) >>
                                                     SPC_ACTIVE_CFG_CORELDO_VDD_DS_SHIFT);
}

/*!
 * @brief Sets the LDO_CORE regulator drive strength.
 *
 * The function returns once the hardware has cleared the regulator busy flag.
 *
 * @note The low drive strength does not support the overdrive voltage level, so bring the core supply back to the
 *       normal voltage level with SPC_SetCoreVoltageLevel() before lowering the drive strength.
 *
 * @param base SPC peripheral base address.
 * @param eDriveStrength The drive strength to program.
 *
 * @retval kStatus_Success The drive strength has been programmed and the regulator has settled.
 * @retval kStatus_Timeout The regulator busy flag was still set after #SPC_RETRY_TIMES reads.
 * @retval kStatus_SPC_VoltageDetectActive The drive strength can not be set to low while a voltage detector is
 *                                         enabled.
 * @retval kStatus_SPC_CoreVoltageLevelWrong The drive strength can not be set to low while the regulator regulates to
 *                                           the overdrive voltage level.
 * @retval kStatus_SPC_BandgapRequired The normal drive strength needs the bandgap to be enabled.
 */
status_t SPC_SetCoreLDODriveStrength(SPC_Type *base, spc_core_ldo_drive_strength_t eDriveStrength);

/*!
 * @brief Sets the delay applied when the regulator changes voltage level.
 *
 * @note The hardware loads this register from IFR or fuse after every reset with the wait time NXP has trimmed for the
 *       device, so there is normally no reason to program it. Only override it against a figure taken from the chip
 *       data sheet, because too short a delay releases the core before the new voltage has settled.
 *
 * @param base SPC peripheral base address.
 * @param u16Delay The delay value, in cycles of the SPC clock.
 */
static inline void SPC_SetVoltageTrimDelay(SPC_Type *base, uint16_t u16Delay)
{
    base->ACTIVE_VDELAY = SPC_ACTIVE_VDELAY_ACTIVE_VDELAY(u16Delay);
}

/*!
 * @brief Gets the delay applied when the regulator changes voltage level.
 *
 * @param base SPC peripheral base address.
 * @return The delay value, in cycles of the SPC clock.
 */
static inline uint16_t SPC_GetVoltageTrimDelay(SPC_Type *base)
{
    return (uint16_t)((base->ACTIVE_VDELAY & SPC_ACTIVE_VDELAY_ACTIVE_VDELAY_MASK) >>
                      SPC_ACTIVE_VDELAY_ACTIVE_VDELAY_SHIFT);
}

/*! @} */

/*!
 * @name SRAM Timing Margin Interfaces
 * @{
 */

/*!
 * @brief Sets the operating voltage the SRAM read/write timing margin is calculated for.
 *
 * The new margin is applied through the request/acknowledge handshake the hardware requires, so this function
 * returns only once the SRAM has acknowledged the update. Requesting the margin that is already programmed does
 * nothing, because the acknowledge of the previous update is still asserted and there would be no edge to wait for.
 *
 * @note The SRAM timing margin must match the core supply voltage level. When raising the core voltage, program the
 *       margin after the new voltage has settled. When lowering it, program the margin before changing the voltage.
 *
 * @param base SPC peripheral base address.
 * @param eVoltage The operating voltage to program.
 *
 * @retval kStatus_Success The new margin has been acknowledged.
 * @retval kStatus_Timeout The acknowledge was still not asserted after #SPC_RETRY_TIMES reads.
 */
status_t SPC_SetSRAMOperateVoltage(SPC_Type *base, spc_sram_operate_voltage_t eVoltage);

/*!
 * @brief Gets the operating voltage the SRAM read/write timing margin is set for.
 *
 * @param base SPC peripheral base address.
 * @return The operating voltage, see @ref spc_sram_operate_voltage_t.
 */
static inline spc_sram_operate_voltage_t SPC_GetSRAMOperateVoltage(SPC_Type *base)
{
    return (spc_sram_operate_voltage_t)(uint32_t)((base->SRAMCTL & SPC_SRAMCTL_VSM_MASK) >> SPC_SRAMCTL_VSM_SHIFT);
}

/*! @} */

/*!
 * @name Voltage Detect Interfaces
 * @{
 */

/*!
 * @brief Configures the voltage detectors of one voltage domain.
 *
 * @note Enabling both the interrupt and the reset of one detector causes an interrupt to be generated on exit from
 *       the reset it asserts. If that is not desired, enable only one of them.
 *
 * @note Configuring a domain does not enable its detectors, use SPC_EnableVoltageDetectors() for that.
 *
 * @note The low-voltage detect level of the system domain can only be changed while the low-voltage reset and interrupt
 *       are disabled. This function programs the level with those responses disabled and enables the requested
 *       responses afterwards.
 *
 * @note The reset enables, and the low-voltage detect level of the system domain, are only writable while the domain is
 *       unlocked. This function changes nothing and reports #kStatus_ReadOnly when @p psConfig asks for a locked field
 *       to change, so that a locked configuration is never partially applied.
 *
 * @param base SPC peripheral base address.
 * @param eDomain The voltage domain to configure.
 * @param psConfig The pointer to @ref spc_voltage_detect_config_t.
 *
 * @retval kStatus_Success The domain has been configured.
 * @retval kStatus_InvalidArgument @p eDomain is out of range, or @p psConfig requests a response that @p eDomain does
 *                                 not implement.
 * @retval kStatus_ReadOnly The domain is locked and @p psConfig requests a change to one of the locked fields.
 */
status_t SPC_SetVoltageDetectConfig(SPC_Type *base,
                                    spc_voltage_domain_t eDomain,
                                    const spc_voltage_detect_config_t *psConfig);

/*!
 * @brief Gets the voltage detect configuration of one voltage domain.
 *
 * The members that @p eDomain does not implement are reported as disabled.
 *
 * @param base SPC peripheral base address.
 * @param eDomain The voltage domain to read.
 * @param psConfig The pointer to @ref spc_voltage_detect_config_t the configuration is written to.
 */
void SPC_GetVoltageDetectConfig(SPC_Type *base, spc_voltage_domain_t eDomain, spc_voltage_detect_config_t *psConfig);

/*!
 * @brief Locks the voltage detect reset control of one voltage domain.
 *
 * After invoking this function, writes to the low and high voltage reset enables of @p eDomain, and to the low-voltage
 * detect level of the system domain, are ignored. The interrupt enables stay writable, and the configuration register
 * only resets on a power-on reset.
 *
 * @param base SPC peripheral base address.
 * @param eDomain The voltage domain to lock.
 */
void SPC_LockVoltageDetectResetControl(SPC_Type *base, spc_voltage_domain_t eDomain);

/*!
 * @brief Unlocks the voltage detect reset control of one voltage domain.
 *
 * @param base SPC peripheral base address.
 * @param eDomain The voltage domain to unlock.
 */
void SPC_UnlockVoltageDetectResetControl(SPC_Type *base, spc_voltage_domain_t eDomain);

/*!
 * @brief Checks whether the voltage detect reset control of one voltage domain is locked.
 *
 * @param base SPC peripheral base address.
 * @param eDomain The voltage domain to check.
 * @retval true Writes to the reset enables of @p eDomain are ignored.
 * @retval false Writes to the reset enables of @p eDomain are allowed.
 */
bool SPC_IsVoltageDetectResetControlLocked(SPC_Type *base, spc_voltage_domain_t eDomain);

/*!
 * @brief Enables voltage detectors.
 *
 * This is the only place where the hardware preconditions of the voltage detectors are checked, so a detector is
 * either enabled or the reason why it can not be is reported.
 *
 * @param base SPC peripheral base address.
 * @param u32Detectors The detectors to enable, should be the OR'ed value of @ref _spc_voltage_detector.
 *
 * @retval kStatus_Success The detectors have been enabled.
 * @retval kStatus_InvalidArgument @p u32Detectors contains a bit that is not a detector.
 * @retval kStatus_SPC_BandgapRequired The voltage detectors need the bandgap to be enabled.
 * @retval kStatus_SPC_DriveStrengthTooLow The voltage detectors need the LDO_CORE regulator to be in normal drive
 *                                         strength.
 */
status_t SPC_EnableVoltageDetectors(SPC_Type *base, uint32_t u32Detectors);

/*!
 * @brief Disables voltage detectors.
 *
 * @param base SPC peripheral base address.
 * @param u32Detectors The detectors to disable, should be the OR'ed value of @ref _spc_voltage_detector.
 */
static inline void SPC_DisableVoltageDetectors(SPC_Type *base, uint32_t u32Detectors)
{
    base->ACTIVE_CFG &= ~(u32Detectors & (uint32_t)kSPC_AllVoltageDetectors);
}

/*!
 * @brief Gets the voltage detectors that are enabled.
 *
 * @param base SPC peripheral base address.
 * @return The enabled detectors, the OR'ed value of @ref _spc_voltage_detector, 0 if none of them is enabled.
 */
static inline uint32_t SPC_GetEnabledVoltageDetectors(SPC_Type *base)
{
    return (base->ACTIVE_CFG & (uint32_t)kSPC_AllVoltageDetectors);
}

/*!
 * @brief Masks the response of every voltage detector.
 *
 * While the detections are masked the detectors keep reporting their state, but they no longer raise an interrupt or
 * assert a reset. Mask them around a core supply voltage change, and unmask them with
 * SPC_UnmaskVoltageDetections() once the supply has settled.
 *
 * @param base SPC peripheral base address.
 */
static inline void SPC_MaskVoltageDetections(SPC_Type *base)
{
    /* VDD_VD_DISABLE reads 0 out of reset, where the detectors respond: 0 enables the response of the voltage
     * detectors, 1 disables it. */
    base->ACTIVE_CFG |= SPC_ACTIVE_CFG_VDD_VD_DISABLE_MASK;
}

/*!
 * @brief Unmasks the response of every voltage detector.
 *
 * @param base SPC peripheral base address.
 */
static inline void SPC_UnmaskVoltageDetections(SPC_Type *base)
{
    base->ACTIVE_CFG &= ~SPC_ACTIVE_CFG_VDD_VD_DISABLE_MASK;
}

/*!
 * @brief Checks whether the response of the voltage detectors is masked.
 *
 * @param base SPC peripheral base address.
 * @retval true The detectors do not raise an interrupt and do not assert a reset.
 * @retval false The detectors respond as configured.
 */
static inline bool SPC_AreVoltageDetectionsMasked(SPC_Type *base)
{
    return ((base->ACTIVE_CFG & SPC_ACTIVE_CFG_VDD_VD_DISABLE_MASK) != 0UL);
}

/*!
 * @brief Gets the latched voltage detect flags.
 *
 * These flags only reset on a power-on reset, so a flag read after any other reset reports an event that happened
 * before that reset.
 *
 * @param base SPC peripheral base address.
 * @return The set flags, the OR'ed value of @ref _spc_voltage_detect_flag.
 */
static inline uint32_t SPC_GetVoltageDetectFlags(SPC_Type *base)
{
    return (base->VD_STAT & (uint32_t)kSPC_AllVoltageDetectFlags);
}

/*!
 * @brief Clears the latched voltage detect flags.
 *
 * Only the flags in @p u32Flags are cleared, the others keep their value.
 *
 * @param base SPC peripheral base address.
 * @param u32Flags The flags to clear, should be the OR'ed value of @ref _spc_voltage_detect_flag.
 */
static inline void SPC_ClearVoltageDetectFlags(SPC_Type *base, uint32_t u32Flags)
{
    /* Every flag of this register is write-1-to-clear, so writing the flags on their own clears exactly the requested
     * ones. A read-modify-write would clear every flag that happens to be set. */
    base->VD_STAT = (u32Flags & (uint32_t)kSPC_AllVoltageDetectFlags);
}

/*!
 * @brief Gets the real time state of the voltage detectors.
 *
 * Unlike the flags returned by SPC_GetVoltageDetectFlags(), these bits are not latched: they mirror the current
 * output of each detector.
 *
 * @param base SPC peripheral base address.
 * @return The current states, the OR'ed value of @ref _spc_voltage_detect_state.
 */
static inline uint32_t SPC_GetVoltageDetectStates(SPC_Type *base)
{
    return (base->VD_STAT & (uint32_t)kSPC_AllVoltageDetectStates);
}

/*! @} */

/*!
 * @name Voltage Glitch Detect Interfaces
 * @{
 */

/*!
 * @brief Configures one voltage glitch detector.
 *
 * @note Configuring a detector does not start the glitch detect hardware, use SPC_EnableGlitchDetect() for that.
 *
 * @note The reset enable of a detector is only writable while the detector is unlocked. This function changes nothing
 *       and reports #kStatus_ReadOnly when @p psConfig asks the reset enable of a locked detector to change, so that a
 *       locked detector is never partially reconfigured.
 *
 * @param base SPC peripheral base address.
 * @param eDetector The glitch detector to configure.
 * @param psConfig The pointer to @ref spc_glitch_detector_config_t.
 *
 * @retval kStatus_Success The detector has been configured.
 * @retval kStatus_InvalidArgument @p eDetector is out of range, @p psConfig requests an option that @p eDetector does
 *                                 not implement, or @c u8ResetTimeout is 0 or larger than 15.
 * @retval kStatus_ReadOnly The detector is locked and @p psConfig requests a change to its reset enable.
 */
status_t SPC_SetGlitchDetectorConfig(SPC_Type *base,
                                     spc_glitch_detector_t eDetector,
                                     const spc_glitch_detector_config_t *psConfig);

/*!
 * @brief Gets the configuration of one voltage glitch detector.
 *
 * The options that @p eDetector does not implement are reported as disabled.
 *
 * @param base SPC peripheral base address.
 * @param eDetector The glitch detector to read.
 * @param psConfig The pointer to @ref spc_glitch_detector_config_t the configuration is written to.
 */
void SPC_GetGlitchDetectorConfig(SPC_Type *base,
                                 spc_glitch_detector_t eDetector,
                                 spc_glitch_detector_config_t *psConfig);

/*!
 * @brief Gets the 4-bit ripple counter of one voltage glitch detector.
 *
 * @param base SPC peripheral base address.
 * @param eDetector The glitch detector to read.
 * @return The set counter bits, the OR'ed value of @ref _spc_glitch_counter_flag.
 */
uint32_t SPC_GetGlitchCounter(SPC_Type *base, spc_glitch_detector_t eDetector);

/*!
 * @brief Clears bits of the 4-bit ripple counter of one voltage glitch detector.
 *
 * Only the bits in @p u32Flags are cleared, the others keep their value.
 *
 * @param base SPC peripheral base address.
 * @param eDetector The glitch detector to update.
 * @param u32Flags The counter bits to clear, should be the OR'ed value of @ref _spc_glitch_counter_flag.
 */
void SPC_ClearGlitchCounter(SPC_Type *base, spc_glitch_detector_t eDetector, uint32_t u32Flags);

/*!
 * @brief Locks the reset enable of one voltage glitch detector.
 *
 * After invoking this function, writes to the reset enable of @p eDetector are ignored.
 *
 * @param base SPC peripheral base address.
 * @param eDetector The glitch detector to lock.
 */
void SPC_LockGlitchDetectorResetControl(SPC_Type *base, spc_glitch_detector_t eDetector);

/*!
 * @brief Unlocks the reset enable of one voltage glitch detector.
 *
 * @param base SPC peripheral base address.
 * @param eDetector The glitch detector to unlock.
 */
void SPC_UnlockGlitchDetectorResetControl(SPC_Type *base, spc_glitch_detector_t eDetector);

/*!
 * @brief Checks whether the reset enable of one voltage glitch detector is locked.
 *
 * @param base SPC peripheral base address.
 * @param eDetector The glitch detector to check.
 * @retval true Writes to the reset enable of @p eDetector are ignored.
 * @retval false Writes to the reset enable of @p eDetector are allowed.
 */
bool SPC_IsGlitchDetectorResetControlLocked(SPC_Type *base, spc_glitch_detector_t eDetector);

/*!
 * @brief Enables/Disables the voltage glitch detect hardware.
 *
 * This gates both glitch detectors at once. They are enabled after a power-on reset.
 *
 * @param base SPC peripheral base address.
 * @param bEnable Used to control the behaviour of the voltage glitch detect hardware.
 *                - \b true Let the glitch detectors run.
 *                - \b false Stop the glitch detectors.
 */
static inline void SPC_EnableGlitchDetect(SPC_Type *base, bool bEnable)
{
    if (bEnable)
    {
        base->ACTIVE_CFG &= ~SPC_ACTIVE_CFG_GLITCH_DETECT_DISABLE_MASK;
    }
    else
    {
        base->ACTIVE_CFG |= SPC_ACTIVE_CFG_GLITCH_DETECT_DISABLE_MASK;
    }
}

/*!
 * @brief Checks whether the voltage glitch detect hardware is running.
 *
 * @param base SPC peripheral base address.
 * @retval true The glitch detectors are enabled.
 * @retval false The glitch detectors are disabled.
 */
static inline bool SPC_IsGlitchDetectEnabled(SPC_Type *base)
{
    return ((base->ACTIVE_CFG & SPC_ACTIVE_CFG_GLITCH_DETECT_DISABLE_MASK) == 0UL);
}

/*! @} */

/*!
 * @name Analog Modules Control Interfaces
 * @{
 */

/*!
 * @brief Enables analog modules in Active mode.
 *
 * @param base SPC peripheral base address.
 * @param u32Modules The modules to enable, should be the OR'ed value of @ref _spc_analog_module.
 */
static inline void SPC_EnableAnalogModules(SPC_Type *base, uint32_t u32Modules)
{
    base->ACTIVE_CFG1 |= SPC_ACTIVE_CFG1_SOC_CNTRL(u32Modules);
}

/*!
 * @brief Disables analog modules in Active mode.
 *
 * @param base SPC peripheral base address.
 * @param u32Modules The modules to disable, should be the OR'ed value of @ref _spc_analog_module.
 */
static inline void SPC_DisableAnalogModules(SPC_Type *base, uint32_t u32Modules)
{
    base->ACTIVE_CFG1 &= ~SPC_ACTIVE_CFG1_SOC_CNTRL(u32Modules);
}

/*!
 * @brief Gets the analog modules that are enabled in Active mode.
 *
 * @param base SPC peripheral base address.
 * @return The enabled modules, the OR'ed value of @ref _spc_analog_module.
 */
static inline uint32_t SPC_GetEnabledAnalogModules(SPC_Type *base)
{
    return ((base->ACTIVE_CFG1 & SPC_ACTIVE_CFG1_SOC_CNTRL_MASK) >> SPC_ACTIVE_CFG1_SOC_CNTRL_SHIFT);
}

/*! @} */

/*!
 * @name External Voltage Domain Interfaces
 * @{
 */

/*!
 * @brief Isolates the selected external voltage domains.
 *
 * Isolate a domain when the board leaves it unpowered, so that the signals crossing into it are driven to a defined
 * state. Isolating a domain also resets the logic it supplies, which is the I/O pads and the analog components of that
 * domain, and never the core power domains.
 *
 * @note #kSPC_ExternalDomainVdd must not be isolated, because VDD is the supply of the SPC itself.
 *
 * @param base SPC peripheral base address.
 * @param u32Domains The external domains to isolate, should be the OR'ed value of @ref _spc_external_domain. The
 *                   domains that are not in the mask are taken out of isolation.
 */
static inline void SPC_SetExternalDomainIsolation(SPC_Type *base, uint32_t u32Domains)
{
    base->EVD_CFG = (base->EVD_CFG & ~SPC_EVD_CFG_EVDISO_MASK) | SPC_EVD_CFG_EVDISO(u32Domains);
}

/*!
 * @brief Gets the external voltage domains that are isolated.
 *
 * @param base SPC peripheral base address.
 * @return The isolated external domains, the OR'ed value of @ref _spc_external_domain.
 */
static inline uint32_t SPC_GetExternalDomainIsolation(SPC_Type *base)
{
    return ((base->EVD_CFG & SPC_EVD_CFG_EVDISO_MASK) >> SPC_EVD_CFG_EVDISO_SHIFT);
}

/*!
 * @brief Gets the external voltage domains that are not isolated.
 *
 * The status of a domain reads back as 0 when the domain is isolated or is not powered, and as 1 when it is powered and
 * not isolated. The reset value therefore depends on the voltages the board applies.
 *
 * @param base SPC peripheral base address.
 * @return The external domains that are powered and not isolated, the OR'ed value of @ref _spc_external_domain.
 */
static inline uint32_t SPC_GetExternalDomainStatus(SPC_Type *base)
{
    return ((base->EVD_CFG & SPC_EVD_CFG_EVDSTAT_MASK) >> SPC_EVD_CFG_EVDSTAT_SHIFT);
}

/*! @} */

/*!
 * @name Aggregate Active Mode Configuration Interfaces
 * @{
 */

/*!
 * @brief Reads back the whole Active mode configuration.
 *
 * @param base SPC peripheral base address.
 * @param psConfig The pointer to @ref spc_active_mode_config_t the configuration is written to.
 */
void SPC_GetActiveModeConfig(SPC_Type *base, spc_active_mode_config_t *psConfig);

/*!
 * @brief Applies a whole Active mode configuration.
 *
 * This function programs the bandgap, the LDO_CORE regulator, the voltage glitch detect and the voltage detectors in
 * the order the hardware requires, so it is the simplest way to restore a configuration read back by
 * SPC_GetActiveModeConfig().
 *
 * @note The voltage detectors and the glitch detect are turned off while the regulator settings are applied, and
 *       turned back on afterwards as requested by @p psConfig.
 *
 * @note The core supply voltage level is programmed, but the SRAM read/write timing margin, the flash read wait
 *       states and the core clock frequency are not. See the driver overview for the required order when the level
 *       being restored differs from the current one.
 *
 * @note The voltage trim delay is only programmed when @c u16VoltageTrimDelay is not 0, so that a configuration built
 *       from scratch keeps the delay NXP has trimmed for the device.
 *
 * @note A configuration that disables the bandgap and changes the core voltage level at the same time is applied by
 *       enabling the bandgap for the duration of the level change, because the level can only be programmed in normal
 *       drive strength, which needs the bandgap.
 *
 * @param base SPC peripheral base address.
 * @param psConfig The pointer to @ref spc_active_mode_config_t.
 *
 * @retval kStatus_Success The configuration has been applied.
 * @retval kStatus_InvalidArgument @p psConfig is not a combination the hardware supports, for example a disabled
 *                                 bandgap together with an enabled voltage detector, or the overdrive voltage level
 *                                 together with the low drive strength.
 * @retval kStatus_Timeout A register spin did not complete within #SPC_RETRY_TIMES reads.
 * @retval kStatus_SPC_Busy The SPC is executing a voltage level transition.
 */
status_t SPC_SetActiveModeConfig(SPC_Type *base, const spc_active_mode_config_t *psConfig);

/*! @} */

#if defined(__cplusplus)
}
#endif /* __cplusplus */

/*! @} */

#endif /* FSL_SPC_H_ */
