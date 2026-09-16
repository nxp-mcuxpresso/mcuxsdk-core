/*
 * Copyright 2026 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "fsl_spc.h"

/* Component ID definition, used by tools. */
#ifndef FSL_COMPONENT_ID
#define FSL_COMPONENT_ID "platform.drivers.dsc_spc"
#endif

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/* The three voltage detect configuration registers place the fields they have in common at the same position, and so
 * do the two glitch detector registers. The driver relies on that to serve every domain and every detector with one
 * implementation, and the checks below fail the build if a future device ever breaks it. */
#if (SPC_VD_SYS_CFG_LVDRE_MASK != SPC_VD_CORE_CFG_LVDRE_MASK) || \
    (SPC_VD_SYS_CFG_LVDIE_MASK != SPC_VD_CORE_CFG_LVDIE_MASK) || \
    (SPC_VD_SYS_CFG_HVDRE_MASK != SPC_VD_CORE_CFG_HVDRE_MASK) || \
    (SPC_VD_SYS_CFG_HVDIE_MASK != SPC_VD_CORE_CFG_HVDIE_MASK) || \
    (SPC_VD_SYS_CFG_LOCK_MASK != SPC_VD_CORE_CFG_LOCK_MASK) ||   \
    (SPC_VD_IO_CFG_LVDIE_MASK != SPC_VD_CORE_CFG_LVDIE_MASK) || (SPC_VD_IO_CFG_LOCK_MASK != SPC_VD_CORE_CFG_LOCK_MASK)
#error "The SPC voltage detect configuration registers no longer share the layout of their common fields."
#endif

#if (SPC_GLITCH_VDD_DETECT_SC_CNT_SELECT_MASK != SPC_GLITCH_CORE_VDD_DETECT_SC_CNT_SELECT_MASK) ||                 \
    (SPC_GLITCH_VDD_DETECT_SC_TIMEOUT_MASK != SPC_GLITCH_CORE_VDD_DETECT_SC_TIMEOUT_MASK) ||                       \
    (SPC_GLITCH_VDD_DETECT_SC_RE_MASK != SPC_GLITCH_CORE_VDD_DETECT_SC_RE_MASK) ||                                 \
    (SPC_GLITCH_VDD_DETECT_SC_IE_MASK != SPC_GLITCH_CORE_VDD_DETECT_SC_IE_MASK) ||                                 \
    (SPC_GLITCH_VDD_DETECT_SC_GLITCH_DETECT_FLAG_MASK != SPC_GLITCH_CORE_VDD_DETECT_SC_GLITCH_DETECT_FLAG_MASK) || \
    (SPC_GLITCH_VDD_DETECT_SC_LOCK_MASK != SPC_GLITCH_CORE_VDD_DETECT_SC_LOCK_MASK)
#error "The SPC glitch detector registers no longer share the layout of their common fields."
#endif

/*! @brief The voltage detect fields of one voltage domain configuration register. */
#define SPC_VD_CFG_CONTROL_MASK \
    (SPC_VD_CORE_CFG_LVDRE_MASK | SPC_VD_CORE_CFG_LVDIE_MASK | SPC_VD_CORE_CFG_HVDRE_MASK | SPC_VD_CORE_CFG_HVDIE_MASK)

/*! @brief The voltage detect fields the lock bit of a voltage domain protects. */
#define SPC_VD_CFG_LOCKED_CONTROL_MASK (SPC_VD_CORE_CFG_LVDRE_MASK | SPC_VD_CORE_CFG_HVDRE_MASK)

/*! @brief The smallest timeout value a glitch detector accepts. */
#define SPC_GLITCH_RESET_TIMEOUT_MIN (1U)

/*! @brief The largest timeout value a glitch detector accepts. */
#define SPC_GLITCH_RESET_TIMEOUT_MAX \
    (uint8_t)(SPC_GLITCH_CORE_VDD_DETECT_SC_TIMEOUT_MASK >> SPC_GLITCH_CORE_VDD_DETECT_SC_TIMEOUT_SHIFT)

/*! @brief What the voltage detectors of one voltage domain are able to do. */
typedef struct _spc_voltage_domain_capability
{
    uint32_t u32SupportedControl; /*!< The bits of @ref _spc_voltage_detect_control the domain implements. */
    bool bHasLowVoltageLevel;     /*!< Whether the domain implements a low-voltage detect level selection. */
} spc_voltage_domain_capability_t;

/*******************************************************************************
 * Prototypes
 ******************************************************************************/

static uint32_t SPC_ReadVoltageDetectConfig(SPC_Type *base, spc_voltage_domain_t eDomain);
static void SPC_WriteVoltageDetectConfig(SPC_Type *base, spc_voltage_domain_t eDomain, uint32_t u32Reg);
static uint32_t SPC_PackVoltageDetectControl(uint32_t u32ControlMask);
static uint32_t SPC_UnpackVoltageDetectControl(uint32_t u32Reg);
static uint32_t SPC_ReadGlitchDetector(SPC_Type *base, spc_glitch_detector_t eDetector);
static void SPC_WriteGlitchDetector(SPC_Type *base, spc_glitch_detector_t eDetector, uint32_t u32Reg);
static void SPC_UpdateGlitchDetector(SPC_Type *base,
                                     spc_glitch_detector_t eDetector,
                                     uint32_t u32ClearMask,
                                     uint32_t u32SetMask);
static status_t SPC_WaitRegulatorBusy(SPC_Type *base);

/*******************************************************************************
 * Variables
 ******************************************************************************/

/*! @brief Indexed by @ref spc_voltage_domain_t. */
static const spc_voltage_domain_capability_t s_spcVoltageDomainCapability[] = {
    /* kSPC_VoltageDomainCore: every response, no detect level selection. */
    {((uint32_t)kSPC_LowVoltageInterrupt | (uint32_t)kSPC_LowVoltageReset | (uint32_t)kSPC_HighVoltageInterrupt |
      (uint32_t)kSPC_HighVoltageReset),
     false},
    /* kSPC_VoltageDomainSystem: every response and a detect level selection. */
    {((uint32_t)kSPC_LowVoltageInterrupt | (uint32_t)kSPC_LowVoltageReset | (uint32_t)kSPC_HighVoltageInterrupt |
      (uint32_t)kSPC_HighVoltageReset),
     true},
    /* kSPC_VoltageDomainIO: a low-voltage interrupt only, the reset enable field is not implemented. */
    {(uint32_t)kSPC_LowVoltageInterrupt, false},
};

/*! @brief The bits of @ref _spc_glitch_detector_option each detector implements, indexed by
 *         @ref spc_glitch_detector_t. */
static const uint32_t s_spcGlitchDetectorOption[] = {
    /* kSPC_GlitchDetectorCoreVdd */
    ((uint32_t)kSPC_GlitchDetectorInterrupt | (uint32_t)kSPC_GlitchDetectorReset |
     (uint32_t)kSPC_GlitchDetectorHighGainMode | (uint32_t)kSPC_GlitchDetectorHighVddAmplifier),
    /* kSPC_GlitchDetectorVdd */
    ((uint32_t)kSPC_GlitchDetectorInterrupt | (uint32_t)kSPC_GlitchDetectorReset),
};

/*******************************************************************************
 * Code
 ******************************************************************************/

/*!
 * @brief Reads the voltage detect configuration register of one voltage domain.
 *
 * The registers are selected with a switch instead of a pointer computed from the peripheral structure, so that the
 * access stays a whole register access, which is the only access width the SPC accepts.
 */
static uint32_t SPC_ReadVoltageDetectConfig(SPC_Type *base, spc_voltage_domain_t eDomain)
{
    uint32_t u32Reg;

    switch (eDomain)
    {
        case kSPC_VoltageDomainCore:
        {
            u32Reg = base->VD_CORE_CFG;
            break;
        }
        case kSPC_VoltageDomainSystem:
        {
            u32Reg = base->VD_SYS_CFG;
            break;
        }
        case kSPC_VoltageDomainIO:
        default:
        {
            u32Reg = base->VD_IO_CFG;
            break;
        }
    }

    return u32Reg;
}

/*!
 * @brief Writes the voltage detect configuration register of one voltage domain.
 */
static void SPC_WriteVoltageDetectConfig(SPC_Type *base, spc_voltage_domain_t eDomain, uint32_t u32Reg)
{
    switch (eDomain)
    {
        case kSPC_VoltageDomainCore:
        {
            base->VD_CORE_CFG = u32Reg;
            break;
        }
        case kSPC_VoltageDomainSystem:
        {
            base->VD_SYS_CFG = u32Reg;
            break;
        }
        case kSPC_VoltageDomainIO:
        default:
        {
            base->VD_IO_CFG = u32Reg;
            break;
        }
    }
}

/*!
 * @brief Translates a mask of @ref _spc_voltage_detect_control into the register fields.
 */
static uint32_t SPC_PackVoltageDetectControl(uint32_t u32ControlMask)
{
    uint32_t u32Reg = (((u32ControlMask & (uint32_t)kSPC_LowVoltageInterrupt) >> 0UL) << SPC_VD_CORE_CFG_LVDIE_SHIFT) |
                      (((u32ControlMask & (uint32_t)kSPC_LowVoltageReset) >> 1UL) << SPC_VD_CORE_CFG_LVDRE_SHIFT) |
                      (((u32ControlMask & (uint32_t)kSPC_HighVoltageInterrupt) >> 2UL) << SPC_VD_CORE_CFG_HVDIE_SHIFT) |
                      (((u32ControlMask & (uint32_t)kSPC_HighVoltageReset) >> 3UL) << SPC_VD_CORE_CFG_HVDRE_SHIFT);

    return u32Reg;
}

/*!
 * @brief Translates the register fields into a mask of @ref _spc_voltage_detect_control.
 */
static uint32_t SPC_UnpackVoltageDetectControl(uint32_t u32Reg)
{
    uint32_t u32ControlMask = (((u32Reg & SPC_VD_CORE_CFG_LVDIE_MASK) >> SPC_VD_CORE_CFG_LVDIE_SHIFT) << 0UL) |
                              (((u32Reg & SPC_VD_CORE_CFG_LVDRE_MASK) >> SPC_VD_CORE_CFG_LVDRE_SHIFT) << 1UL) |
                              (((u32Reg & SPC_VD_CORE_CFG_HVDIE_MASK) >> SPC_VD_CORE_CFG_HVDIE_SHIFT) << 2UL) |
                              (((u32Reg & SPC_VD_CORE_CFG_HVDRE_MASK) >> SPC_VD_CORE_CFG_HVDRE_SHIFT) << 3UL);

    return u32ControlMask;
}

/*!
 * @brief Reads the control register of one glitch detector.
 */
static uint32_t SPC_ReadGlitchDetector(SPC_Type *base, spc_glitch_detector_t eDetector)
{
    uint32_t u32Reg;

    switch (eDetector)
    {
        case kSPC_GlitchDetectorCoreVdd:
        {
            u32Reg = base->GLITCH_CORE_VDD_DETECT_SC;
            break;
        }
        case kSPC_GlitchDetectorVdd:
        default:
        {
            u32Reg = base->GLITCH_VDD_DETECT_SC;
            break;
        }
    }

    return u32Reg;
}

/*!
 * @brief Writes the control register of one glitch detector.
 */
static void SPC_WriteGlitchDetector(SPC_Type *base, spc_glitch_detector_t eDetector, uint32_t u32Reg)
{
    switch (eDetector)
    {
        case kSPC_GlitchDetectorCoreVdd:
        {
            base->GLITCH_CORE_VDD_DETECT_SC = u32Reg;
            break;
        }
        case kSPC_GlitchDetectorVdd:
        default:
        {
            base->GLITCH_VDD_DETECT_SC = u32Reg;
            break;
        }
    }
}

/*!
 * @brief Read-modify-writes the control register of one glitch detector.
 *
 * The ripple counter flags of that register are write-1-to-clear, so they are always written as 0 unless the caller
 * explicitly asks for them in @p u32SetMask. A plain read-modify-write would clear every flag that happens to be set.
 */
static void SPC_UpdateGlitchDetector(SPC_Type *base,
                                     spc_glitch_detector_t eDetector,
                                     uint32_t u32ClearMask,
                                     uint32_t u32SetMask)
{
    uint32_t u32Reg;

    u32Reg = SPC_ReadGlitchDetector(base, eDetector);
    u32Reg &= ~(u32ClearMask | SPC_GLITCH_CORE_VDD_DETECT_SC_GLITCH_DETECT_FLAG_MASK);
    u32Reg |= u32SetMask;

    SPC_WriteGlitchDetector(base, eDetector, u32Reg);
}

/*!
 * @brief Waits until the LDO_CORE regulator has settled.
 */
static status_t SPC_WaitRegulatorBusy(SPC_Type *base)
{
    status_t status = kStatus_Success;

#if (defined(SPC_RETRY_TIMES) && (SPC_RETRY_TIMES > 0U))
    uint32_t u32RetryTimes = SPC_RETRY_TIMES;

    while (SPC_IsRegulatorBusy(base) && (--u32RetryTimes != 0U))
    {
    }

    if (u32RetryTimes == 0U)
    {
        status = kStatus_Timeout;
    }
#else
    while (SPC_IsRegulatorBusy(base))
    {
    }
#endif

    return status;
}

/*!
 * brief Waits until the SPC has finished the voltage level transition in progress.
 *
 * param base SPC peripheral base address.
 *
 * retval kStatus_Success The SPC is no longer busy.
 * retval kStatus_Timeout The busy flag was still set after SPC_RETRY_TIMES reads.
 */
status_t SPC_WaitBusy(SPC_Type *base)
{
    status_t status = kStatus_Success;

#if (defined(SPC_RETRY_TIMES) && (SPC_RETRY_TIMES > 0U))
    uint32_t u32RetryTimes = SPC_RETRY_TIMES;

    while (SPC_IsBusy(base) && (--u32RetryTimes != 0U))
    {
    }

    if (u32RetryTimes == 0U)
    {
        status = kStatus_Timeout;
    }
#else
    while (SPC_IsBusy(base))
    {
    }
#endif

    return status;
}

/*!
 * brief Sets the bandgap mode.
 *
 * param base SPC peripheral base address.
 * param eMode The bandgap mode to program.
 *
 * retval kStatus_Success The bandgap mode has been programmed.
 * retval kStatus_InvalidArgument eMode is kSPC_BandgapReserved.
 * retval kStatus_SPC_BandgapRequired The bandgap can not be disabled because something still depends on it.
 */
status_t SPC_SetBandgapMode(SPC_Type *base, spc_bandgap_mode_t eMode)
{
    uint32_t u32Reg = base->ACTIVE_CFG;
    status_t status = kStatus_Success;

    if (eMode == kSPC_BandgapReserved)
    {
        status = kStatus_InvalidArgument;
    }
    else if (eMode == kSPC_BandgapDisabled)
    {
        /* The bandgap can only be disabled once nothing depends on it: every voltage detector must be disabled, the
         * glitch detect must be disabled and the LDO_CORE regulator must be in low drive strength. */
        if ((SPC_GetEnabledVoltageDetectors(base) != 0UL) || SPC_IsGlitchDetectEnabled(base) ||
            ((u32Reg & SPC_ACTIVE_CFG_CORELDO_VDD_DS_MASK) != 0UL))
        {
            status = kStatus_SPC_BandgapRequired;
        }
    }
    else
    {
        /* Enabling the bandgap has no precondition. */
    }

    if (status == kStatus_Success)
    {
        u32Reg &= ~SPC_ACTIVE_CFG_BGMODE_MASK;
        u32Reg |= SPC_ACTIVE_CFG_BGMODE((uint32_t)eMode);

        base->ACTIVE_CFG = u32Reg;
    }

    return status;
}

/*!
 * brief Sets the core supply voltage level the LDO_CORE regulator regulates to.
 *
 * param base SPC peripheral base address.
 * param eLevel The core supply voltage level to program.
 *
 * retval kStatus_Success The new voltage level has settled.
 * retval kStatus_Timeout The busy flag was still set after SPC_RETRY_TIMES reads.
 * retval kStatus_SPC_DriveStrengthTooLow The voltage level can only be changed while the LDO_CORE regulator is in
 *                                        normal drive strength.
 */
status_t SPC_SetCoreVoltageLevel(SPC_Type *base, spc_core_voltage_level_t eLevel)
{
    uint32_t u32Reg = base->ACTIVE_CFG;
    status_t status;

    if ((u32Reg & SPC_ACTIVE_CFG_CORELDO_VDD_DS_MASK) == 0UL)
    {
        status = kStatus_SPC_DriveStrengthTooLow;
    }
    else
    {
        u32Reg &= ~SPC_ACTIVE_CFG_CORELDO_VDD_LVL_MASK;
        u32Reg |= SPC_ACTIVE_CFG_CORELDO_VDD_LVL((uint32_t)eLevel);

        base->ACTIVE_CFG = u32Reg;

        /* The hardware clears the busy flag once the new level has settled. */
        status = SPC_WaitBusy(base);
    }

    return status;
}

/*!
 * brief Sets the LDO_CORE regulator drive strength.
 *
 * param base SPC peripheral base address.
 * param eDriveStrength The drive strength to program.
 *
 * retval kStatus_Success The drive strength has been programmed and the regulator has settled.
 * retval kStatus_Timeout The regulator busy flag was still set after SPC_RETRY_TIMES reads.
 * retval kStatus_SPC_VoltageDetectActive The drive strength can not be set to low while a voltage detector is enabled.
 * retval kStatus_SPC_CoreVoltageLevelWrong The drive strength can not be set to low while the regulator regulates to
 *                                          the overdrive voltage level.
 * retval kStatus_SPC_BandgapRequired The normal drive strength needs the bandgap to be enabled.
 */
status_t SPC_SetCoreLDODriveStrength(SPC_Type *base, spc_core_ldo_drive_strength_t eDriveStrength)
{
    uint32_t u32Reg = base->ACTIVE_CFG;
    status_t status = kStatus_Success;

    if (eDriveStrength == kSPC_CoreLDOLowDriveStrength)
    {
        if (SPC_GetEnabledVoltageDetectors(base) != 0UL)
        {
            /* A voltage detector needs more than the low drive strength can supply, so the hardware would ignore the
             * setting. */
            status = kStatus_SPC_VoltageDetectActive;
        }
        else if (SPC_GetCoreVoltageLevel(base) == kSPC_CoreVoltageOverDrive)
        {
            /* The low drive strength does not support the overdrive voltage level. */
            status = kStatus_SPC_CoreVoltageLevelWrong;
        }
        else
        {
            /* The regulator can be brought down to the low drive strength. */
        }
    }
    else
    {
        if (SPC_GetBandgapMode(base) == kSPC_BandgapDisabled)
        {
            status = kStatus_SPC_BandgapRequired;
        }
    }

    if (status == kStatus_Success)
    {
        /* Raising the drive strength from low back to normal requires the voltage level to be set back to the level
         * that was in use before the drive strength was lowered, in the same write. The voltage level can only be
         * changed while the drive strength is normal, so the level field still holds that level and the write below
         * carries it over unchanged. */
        u32Reg &= ~SPC_ACTIVE_CFG_CORELDO_VDD_DS_MASK;
        u32Reg |= SPC_ACTIVE_CFG_CORELDO_VDD_DS((uint32_t)eDriveStrength);

        base->ACTIVE_CFG = u32Reg;

        status = SPC_WaitRegulatorBusy(base);
    }

    return status;
}

/*!
 * brief Sets the operating voltage the SRAM read/write timing margin is calculated for.
 *
 * param base SPC peripheral base address.
 * param eVoltage The operating voltage to program.
 *
 * retval kStatus_Success The new margin has been acknowledged.
 * retval kStatus_Timeout The acknowledge was still not asserted after SPC_RETRY_TIMES reads.
 */
status_t SPC_SetSRAMOperateVoltage(SPC_Type *base, spc_sram_operate_voltage_t eVoltage)
{
    status_t status = kStatus_Success;
    uint32_t u32Reg;
#if (defined(SPC_RETRY_TIMES) && (SPC_RETRY_TIMES > 0U))
    uint32_t u32RetryTimes = SPC_RETRY_TIMES;
#endif

    if (SPC_GetSRAMOperateVoltage(base) != eVoltage)
    {
        /* The acknowledge bit is read-only and the request bit is driven by the handshake below, so neither of them is
         * carried over from the current register value. */
        u32Reg = base->SRAMCTL & ~(SPC_SRAMCTL_VSM_MASK | SPC_SRAMCTL_REQ_MASK | SPC_SRAMCTL_ACK_MASK);
        u32Reg |= SPC_SRAMCTL_VSM((uint32_t)eVoltage);

        base->SRAMCTL = u32Reg;

        /* Request the SRAM timing margin change. */
        base->SRAMCTL = u32Reg | SPC_SRAMCTL_REQ_MASK;

#if (defined(SPC_RETRY_TIMES) && (SPC_RETRY_TIMES > 0U))
        while (((base->SRAMCTL & SPC_SRAMCTL_ACK_MASK) == 0UL) && (--u32RetryTimes != 0U))
        {
        }

        if (u32RetryTimes == 0U)
        {
            status = kStatus_Timeout;
        }
#else
        while ((base->SRAMCTL & SPC_SRAMCTL_ACK_MASK) == 0UL)
        {
        }
#endif

        /* Withdraw the request whether it was acknowledged or not, so that the handshake is not left half done. */
        base->SRAMCTL = u32Reg;
    }
    else
    {
        /* The margin is already the requested one. The acknowledge stays asserted after an update and is asserted out
         * of reset as well, so it carries no information about a request that is not made. */
    }

    return status;
}

/*!
 * brief Configures the voltage detectors of one voltage domain.
 *
 * param base SPC peripheral base address.
 * param eDomain The voltage domain to configure.
 * param psConfig The pointer to spc_voltage_detect_config_t.
 *
 * retval kStatus_Success The domain has been configured.
 * retval kStatus_InvalidArgument eDomain is out of range, or psConfig requests a response that eDomain does not
 *                                implement.
 * retval kStatus_ReadOnly The domain is locked and psConfig requests a change to one of the locked fields.
 */
status_t SPC_SetVoltageDetectConfig(SPC_Type *base,
                                    spc_voltage_domain_t eDomain,
                                    const spc_voltage_detect_config_t *psConfig)
{
    assert(psConfig != NULL);

    status_t status = kStatus_Success;
    uint32_t u32Reg;
    uint32_t u32Requested;
    uint32_t u32Locked;
    bool bHasLowVoltageLevel;

    if ((uint32_t)eDomain >= (uint32_t)ARRAY_SIZE(s_spcVoltageDomainCapability))
    {
        status = kStatus_InvalidArgument;
    }
    else if ((psConfig->u32ControlMask & ~s_spcVoltageDomainCapability[(uint32_t)eDomain].u32SupportedControl) != 0UL)
    {
        /* The domain does not implement one of the requested responses. */
        status = kStatus_InvalidArgument;
    }
    else
    {
        bHasLowVoltageLevel = s_spcVoltageDomainCapability[(uint32_t)eDomain].bHasLowVoltageLevel;

        u32Reg       = SPC_ReadVoltageDetectConfig(base, eDomain);
        u32Requested = SPC_PackVoltageDetectControl(psConfig->u32ControlMask);

        /* The lock bit only covers the reset enables of the domain, and the low-voltage detect level of the domains
         * that have one. The interrupt enables stay writable. */
        u32Locked = SPC_VD_CFG_LOCKED_CONTROL_MASK;

        if (bHasLowVoltageLevel)
        {
            u32Locked |= SPC_VD_SYS_CFG_LVSEL_MASK;
            u32Requested |= SPC_VD_SYS_CFG_LVSEL((uint32_t)psConfig->eLowVoltageLevel);
        }

        if (((u32Reg & SPC_VD_CORE_CFG_LOCK_MASK) != 0UL) && (((u32Reg ^ u32Requested) & u32Locked) != 0UL))
        {
            /* A locked field ignores the write, so the whole configuration is rejected. */
            status = kStatus_ReadOnly;
        }
        else
        {
            u32Reg &= ~SPC_VD_CFG_CONTROL_MASK;

            if (bHasLowVoltageLevel)
            {
                /* The low-voltage detect level can only be changed while the low-voltage reset and interrupt are
                 * disabled, which is what the value written here does, and the responses are enabled by the write
                 * below. */
                u32Reg &= ~SPC_VD_SYS_CFG_LVSEL_MASK;
                u32Reg |= SPC_VD_SYS_CFG_LVSEL((uint32_t)psConfig->eLowVoltageLevel);

                SPC_WriteVoltageDetectConfig(base, eDomain, u32Reg);
            }

            u32Reg |= (u32Requested & SPC_VD_CFG_CONTROL_MASK);

            SPC_WriteVoltageDetectConfig(base, eDomain, u32Reg);
        }
    }

    return status;
}

/*!
 * brief Gets the voltage detect configuration of one voltage domain.
 *
 * param base SPC peripheral base address.
 * param eDomain The voltage domain to read.
 * param psConfig The pointer to spc_voltage_detect_config_t the configuration is written to.
 */
void SPC_GetVoltageDetectConfig(SPC_Type *base, spc_voltage_domain_t eDomain, spc_voltage_detect_config_t *psConfig)
{
    assert(psConfig != NULL);
    assert((uint32_t)eDomain < (uint32_t)ARRAY_SIZE(s_spcVoltageDomainCapability));

    uint32_t u32Reg = SPC_ReadVoltageDetectConfig(base, eDomain);

    /* The responses the domain does not implement read back as 0 anyway, masking them keeps that true even for a
     * reserved bit that reads back as 1. */
    psConfig->u32ControlMask =
        SPC_UnpackVoltageDetectControl(u32Reg) & s_spcVoltageDomainCapability[(uint32_t)eDomain].u32SupportedControl;

    if (s_spcVoltageDomainCapability[(uint32_t)eDomain].bHasLowVoltageLevel)
    {
        psConfig->eLowVoltageLevel =
            (spc_low_voltage_level_t)(uint32_t)((u32Reg & SPC_VD_SYS_CFG_LVSEL_MASK) >> SPC_VD_SYS_CFG_LVSEL_SHIFT);
    }
    else
    {
        psConfig->eLowVoltageLevel = kSPC_LowVoltageLevelNormal;
    }
}

/*!
 * brief Locks the voltage detect reset control of one voltage domain.
 *
 * param base SPC peripheral base address.
 * param eDomain The voltage domain to lock.
 */
void SPC_LockVoltageDetectResetControl(SPC_Type *base, spc_voltage_domain_t eDomain)
{
    SPC_WriteVoltageDetectConfig(base, eDomain, SPC_ReadVoltageDetectConfig(base, eDomain) | SPC_VD_CORE_CFG_LOCK_MASK);
}

/*!
 * brief Unlocks the voltage detect reset control of one voltage domain.
 *
 * param base SPC peripheral base address.
 * param eDomain The voltage domain to unlock.
 */
void SPC_UnlockVoltageDetectResetControl(SPC_Type *base, spc_voltage_domain_t eDomain)
{
    SPC_WriteVoltageDetectConfig(base, eDomain,
                                 SPC_ReadVoltageDetectConfig(base, eDomain) & ~SPC_VD_CORE_CFG_LOCK_MASK);
}

/*!
 * brief Checks whether the voltage detect reset control of one voltage domain is locked.
 *
 * param base SPC peripheral base address.
 * param eDomain The voltage domain to check.
 *
 * retval true Writes to the reset enables of the domain are ignored.
 * retval false Writes to the reset enables of the domain are allowed.
 */
bool SPC_IsVoltageDetectResetControlLocked(SPC_Type *base, spc_voltage_domain_t eDomain)
{
    return ((SPC_ReadVoltageDetectConfig(base, eDomain) & SPC_VD_CORE_CFG_LOCK_MASK) != 0UL);
}

/*!
 * brief Enables voltage detectors.
 *
 * param base SPC peripheral base address.
 * param u32Detectors The detectors to enable, a mask of _spc_voltage_detector.
 *
 * retval kStatus_Success The detectors have been enabled.
 * retval kStatus_InvalidArgument u32Detectors contains a bit that is not a detector.
 * retval kStatus_SPC_BandgapRequired The voltage detectors need the bandgap to be enabled.
 * retval kStatus_SPC_DriveStrengthTooLow The voltage detectors need the LDO_CORE regulator to be in normal drive
 *                                        strength.
 */
status_t SPC_EnableVoltageDetectors(SPC_Type *base, uint32_t u32Detectors)
{
    status_t status = kStatus_Success;

    if ((u32Detectors & ~(uint32_t)kSPC_AllVoltageDetectors) != 0UL)
    {
        status = kStatus_InvalidArgument;
    }
    else if (u32Detectors == 0UL)
    {
        /* Nothing to enable, so none of the preconditions applies. */
    }
    else if (SPC_GetBandgapMode(base) == kSPC_BandgapDisabled)
    {
        /* The detectors compare against the bandgap reference. */
        status = kStatus_SPC_BandgapRequired;
    }
    else if (SPC_GetCoreLDODriveStrength(base) == kSPC_CoreLDOLowDriveStrength)
    {
        /* The hardware ignores an enabled detector while the regulator is in low drive strength. */
        status = kStatus_SPC_DriveStrengthTooLow;
    }
    else
    {
        base->ACTIVE_CFG |= u32Detectors;
    }

    return status;
}

/*!
 * brief Configures one voltage glitch detector.
 *
 * param base SPC peripheral base address.
 * param eDetector The glitch detector to configure.
 * param psConfig The pointer to spc_glitch_detector_config_t.
 *
 * retval kStatus_Success The detector has been configured.
 * retval kStatus_InvalidArgument eDetector is out of range, psConfig requests an option that eDetector does not
 *                                implement, or u8ResetTimeout is 0 or larger than 15.
 * retval kStatus_ReadOnly The detector is locked and psConfig requests a change to its reset enable.
 */
status_t SPC_SetGlitchDetectorConfig(SPC_Type *base,
                                     spc_glitch_detector_t eDetector,
                                     const spc_glitch_detector_config_t *psConfig)
{
    assert(psConfig != NULL);

    status_t status = kStatus_Success;
    uint32_t u32Reg;
    uint32_t u32ClearMask;
    uint32_t u32SetMask;

    if ((uint32_t)eDetector >= (uint32_t)ARRAY_SIZE(s_spcGlitchDetectorOption))
    {
        status = kStatus_InvalidArgument;
    }
    else if ((psConfig->u32OptionMask & ~s_spcGlitchDetectorOption[(uint32_t)eDetector]) != 0UL)
    {
        /* The detector does not implement one of the requested options. */
        status = kStatus_InvalidArgument;
    }
    else if ((psConfig->u8ResetTimeout < SPC_GLITCH_RESET_TIMEOUT_MIN) ||
             (psConfig->u8ResetTimeout > SPC_GLITCH_RESET_TIMEOUT_MAX))
    {
        /* The hardware does not accept a timeout of 0, the detect logic would never re-arm. */
        status = kStatus_InvalidArgument;
    }
    else
    {
        u32ClearMask = SPC_GLITCH_CORE_VDD_DETECT_SC_CNT_SELECT_MASK | SPC_GLITCH_CORE_VDD_DETECT_SC_TIMEOUT_MASK |
                       SPC_GLITCH_CORE_VDD_DETECT_SC_RE_MASK | SPC_GLITCH_CORE_VDD_DETECT_SC_IE_MASK;

        u32SetMask = SPC_GLITCH_CORE_VDD_DETECT_SC_CNT_SELECT((uint32_t)psConfig->eRippleCounter) |
                     SPC_GLITCH_CORE_VDD_DETECT_SC_TIMEOUT((uint32_t)psConfig->u8ResetTimeout);

        if ((psConfig->u32OptionMask & (uint32_t)kSPC_GlitchDetectorInterrupt) != 0UL)
        {
            u32SetMask |= SPC_GLITCH_CORE_VDD_DETECT_SC_IE_MASK;
        }
        if ((psConfig->u32OptionMask & (uint32_t)kSPC_GlitchDetectorReset) != 0UL)
        {
            u32SetMask |= SPC_GLITCH_CORE_VDD_DETECT_SC_RE_MASK;
        }

        if (eDetector == kSPC_GlitchDetectorCoreVdd)
        {
            /* Only this detector implements the two analog options, so the bits are left alone for the other one. */
            u32ClearMask |=
                SPC_GLITCH_CORE_VDD_DETECT_SC_HIGH_GAIN_MODE_MASK | SPC_GLITCH_CORE_VDD_DETECT_SC_HVDD_AMP_DISABLE_MASK;

            if ((psConfig->u32OptionMask & (uint32_t)kSPC_GlitchDetectorHighGainMode) != 0UL)
            {
                u32SetMask |= SPC_GLITCH_CORE_VDD_DETECT_SC_HIGH_GAIN_MODE_MASK;
            }
            if ((psConfig->u32OptionMask & (uint32_t)kSPC_GlitchDetectorHighVddAmplifier) == 0UL)
            {
                /* The register field powers the amplifier down, the option keeps it powered. */
                u32SetMask |= SPC_GLITCH_CORE_VDD_DETECT_SC_HVDD_AMP_DISABLE_MASK;
            }
        }

        u32Reg = SPC_ReadGlitchDetector(base, eDetector);

        /* The lock bit of a glitch detector only covers its reset enable, everything else stays writable. A locked
         * reset enable ignores the write, so the whole configuration is rejected. */
        if (((u32Reg & SPC_GLITCH_CORE_VDD_DETECT_SC_LOCK_MASK) != 0UL) &&
            (((u32Reg ^ u32SetMask) & SPC_GLITCH_CORE_VDD_DETECT_SC_RE_MASK) != 0UL))
        {
            status = kStatus_ReadOnly;
        }
        else
        {
            SPC_UpdateGlitchDetector(base, eDetector, u32ClearMask, u32SetMask);
        }
    }

    return status;
}

/*!
 * brief Gets the configuration of one voltage glitch detector.
 *
 * param base SPC peripheral base address.
 * param eDetector The glitch detector to read.
 * param psConfig The pointer to spc_glitch_detector_config_t the configuration is written to.
 */
void SPC_GetGlitchDetectorConfig(SPC_Type *base,
                                 spc_glitch_detector_t eDetector,
                                 spc_glitch_detector_config_t *psConfig)
{
    assert(psConfig != NULL);
    assert((uint32_t)eDetector < (uint32_t)ARRAY_SIZE(s_spcGlitchDetectorOption));

    uint32_t u32Reg        = SPC_ReadGlitchDetector(base, eDetector);
    uint32_t u32OptionMask = 0UL;

    if ((u32Reg & SPC_GLITCH_CORE_VDD_DETECT_SC_IE_MASK) != 0UL)
    {
        u32OptionMask |= (uint32_t)kSPC_GlitchDetectorInterrupt;
    }
    if ((u32Reg & SPC_GLITCH_CORE_VDD_DETECT_SC_RE_MASK) != 0UL)
    {
        u32OptionMask |= (uint32_t)kSPC_GlitchDetectorReset;
    }

    if (eDetector == kSPC_GlitchDetectorCoreVdd)
    {
        if ((u32Reg & SPC_GLITCH_CORE_VDD_DETECT_SC_HIGH_GAIN_MODE_MASK) != 0UL)
        {
            u32OptionMask |= (uint32_t)kSPC_GlitchDetectorHighGainMode;
        }
        if ((u32Reg & SPC_GLITCH_CORE_VDD_DETECT_SC_HVDD_AMP_DISABLE_MASK) == 0UL)
        {
            u32OptionMask |= (uint32_t)kSPC_GlitchDetectorHighVddAmplifier;
        }
    }

    psConfig->u32OptionMask = u32OptionMask;
    psConfig->eRippleCounter =
        (spc_glitch_ripple_counter_t)(uint32_t)((u32Reg & SPC_GLITCH_CORE_VDD_DETECT_SC_CNT_SELECT_MASK) >>
                                                SPC_GLITCH_CORE_VDD_DETECT_SC_CNT_SELECT_SHIFT);
    psConfig->u8ResetTimeout =
        (uint8_t)((u32Reg & SPC_GLITCH_CORE_VDD_DETECT_SC_TIMEOUT_MASK) >> SPC_GLITCH_CORE_VDD_DETECT_SC_TIMEOUT_SHIFT);
}

/*!
 * brief Gets the 4-bit ripple counter of one voltage glitch detector.
 *
 * param base SPC peripheral base address.
 * param eDetector The glitch detector to read.
 *
 * return The set counter bits, a mask of _spc_glitch_counter_flag.
 */
uint32_t SPC_GetGlitchCounter(SPC_Type *base, spc_glitch_detector_t eDetector)
{
    return ((SPC_ReadGlitchDetector(base, eDetector) & SPC_GLITCH_CORE_VDD_DETECT_SC_GLITCH_DETECT_FLAG_MASK) >>
            SPC_GLITCH_CORE_VDD_DETECT_SC_GLITCH_DETECT_FLAG_SHIFT);
}

/*!
 * brief Clears bits of the 4-bit ripple counter of one voltage glitch detector.
 *
 * param base SPC peripheral base address.
 * param eDetector The glitch detector to update.
 * param u32Flags The counter bits to clear, a mask of _spc_glitch_counter_flag.
 */
void SPC_ClearGlitchCounter(SPC_Type *base, spc_glitch_detector_t eDetector, uint32_t u32Flags)
{
    SPC_UpdateGlitchDetector(
        base, eDetector, 0UL,
        SPC_GLITCH_CORE_VDD_DETECT_SC_GLITCH_DETECT_FLAG(u32Flags & (uint32_t)kSPC_AllGlitchCounterFlags));
}

/*!
 * brief Locks the reset enable of one voltage glitch detector.
 *
 * param base SPC peripheral base address.
 * param eDetector The glitch detector to lock.
 */
void SPC_LockGlitchDetectorResetControl(SPC_Type *base, spc_glitch_detector_t eDetector)
{
    SPC_UpdateGlitchDetector(base, eDetector, 0UL, SPC_GLITCH_CORE_VDD_DETECT_SC_LOCK_MASK);
}

/*!
 * brief Unlocks the reset enable of one voltage glitch detector.
 *
 * param base SPC peripheral base address.
 * param eDetector The glitch detector to unlock.
 */
void SPC_UnlockGlitchDetectorResetControl(SPC_Type *base, spc_glitch_detector_t eDetector)
{
    SPC_UpdateGlitchDetector(base, eDetector, SPC_GLITCH_CORE_VDD_DETECT_SC_LOCK_MASK, 0UL);
}

/*!
 * brief Checks whether the reset enable of one voltage glitch detector is locked.
 *
 * param base SPC peripheral base address.
 * param eDetector The glitch detector to check.
 *
 * retval true Writes to the reset enable of the detector are ignored.
 * retval false Writes to the reset enable of the detector are allowed.
 */
bool SPC_IsGlitchDetectorResetControlLocked(SPC_Type *base, spc_glitch_detector_t eDetector)
{
    return ((SPC_ReadGlitchDetector(base, eDetector) & SPC_GLITCH_CORE_VDD_DETECT_SC_LOCK_MASK) != 0UL);
}

/*!
 * brief Reads back the whole Active mode configuration.
 *
 * param base SPC peripheral base address.
 * param psConfig The pointer to spc_active_mode_config_t the configuration is written to.
 */
void SPC_GetActiveModeConfig(SPC_Type *base, spc_active_mode_config_t *psConfig)
{
    assert(psConfig != NULL);

    psConfig->eBandgapMode          = SPC_GetBandgapMode(base);
    psConfig->eCoreVoltageLevel     = SPC_GetCoreVoltageLevel(base);
    psConfig->eCoreLDODriveStrength = SPC_GetCoreLDODriveStrength(base);
    psConfig->u16VoltageTrimDelay   = SPC_GetVoltageTrimDelay(base);
    psConfig->u32EnabledDetectors   = SPC_GetEnabledVoltageDetectors(base);
    psConfig->bEnableGlitchDetect   = SPC_IsGlitchDetectEnabled(base);
}

/*!
 * brief Applies a whole Active mode configuration.
 *
 * param base SPC peripheral base address.
 * param psConfig The pointer to spc_active_mode_config_t.
 *
 * retval kStatus_Success The configuration has been applied.
 * retval kStatus_InvalidArgument psConfig is not a combination the hardware supports.
 * retval kStatus_Timeout A register spin did not complete within SPC_RETRY_TIMES reads.
 * retval kStatus_SPC_Busy The SPC is executing a voltage level transition.
 */
status_t SPC_SetActiveModeConfig(SPC_Type *base, const spc_active_mode_config_t *psConfig)
{
    assert(psConfig != NULL);

    status_t status = kStatus_Success;
    bool bBandgapEnabled;
    bool bLevelChange;

    bBandgapEnabled = (psConfig->eBandgapMode != kSPC_BandgapDisabled);
    bLevelChange    = (SPC_GetCoreVoltageLevel(base) != psConfig->eCoreVoltageLevel);

    /* Reject the combinations the hardware would refuse, so that the sequence below can not stop half way through
     * because of the caller's input. */
    if ((psConfig->eBandgapMode == kSPC_BandgapReserved) ||
        ((psConfig->u32EnabledDetectors & ~(uint32_t)kSPC_AllVoltageDetectors) != 0UL))
    {
        status = kStatus_InvalidArgument;
    }
    else if (!bBandgapEnabled && ((psConfig->u32EnabledDetectors != 0UL) || psConfig->bEnableGlitchDetect ||
                                  (psConfig->eCoreLDODriveStrength != kSPC_CoreLDOLowDriveStrength)))
    {
        /* The voltage detectors, the glitch detect and the normal drive strength all need the bandgap. */
        status = kStatus_InvalidArgument;
    }
    else if ((psConfig->u32EnabledDetectors != 0UL) &&
             (psConfig->eCoreLDODriveStrength == kSPC_CoreLDOLowDriveStrength))
    {
        /* The hardware ignores an enabled detector while the regulator is in low drive strength. */
        status = kStatus_InvalidArgument;
    }
    else if ((psConfig->eCoreVoltageLevel == kSPC_CoreVoltageOverDrive) &&
             (psConfig->eCoreLDODriveStrength == kSPC_CoreLDOLowDriveStrength))
    {
        /* The low drive strength does not support the overdrive voltage level. */
        status = kStatus_InvalidArgument;
    }
    else if (SPC_IsBusy(base))
    {
        status = kStatus_SPC_Busy;
    }
    else
    {
        /* Detach everything that constrains the regulator, so that the drive strength and the voltage level below can
         * be programmed whatever the current configuration is. */
        SPC_DisableVoltageDetectors(base, (uint32_t)kSPC_AllVoltageDetectors);
        SPC_EnableGlitchDetect(base, false);

        /* The bandgap has to be enabled before anything that needs it, and disabled after everything that needed it,
         * hence the two halves of this function. */
        if (bBandgapEnabled)
        {
            status = SPC_SetBandgapMode(base, psConfig->eBandgapMode);
        }
        else if (bLevelChange)
        {
            /* The voltage level can only be programmed in normal drive strength, which needs the bandgap even though
             * the configuration being applied ends up with the bandgap disabled. The tail of this function turns it
             * back off. */
            status = SPC_SetBandgapMode(base, kSPC_BandgapEnabledBufferDisabled);
        }
        else
        {
            /* Nothing that is being programmed needs the bandgap. */
        }

        if (status == kStatus_Success)
        {
            if (psConfig->u16VoltageTrimDelay != 0U)
            {
                /* The hardware loads this delay from IFR or fuse with the value NXP has trimmed for the device, so a
                 * configuration that does not carry a delay of its own keeps the trimmed one. */
                SPC_SetVoltageTrimDelay(base, psConfig->u16VoltageTrimDelay);
            }
        }

        if ((status == kStatus_Success) && bLevelChange)
        {
            /* The voltage level can only be changed in normal drive strength. */
            status = SPC_SetCoreLDODriveStrength(base, kSPC_CoreLDONormalDriveStrength);

            if (status == kStatus_Success)
            {
                status = SPC_SetCoreVoltageLevel(base, psConfig->eCoreVoltageLevel);
            }
        }

        if (status == kStatus_Success)
        {
            status = SPC_SetCoreLDODriveStrength(base, psConfig->eCoreLDODriveStrength);
        }

        if (status == kStatus_Success)
        {
            SPC_EnableGlitchDetect(base, psConfig->bEnableGlitchDetect);

            status = SPC_EnableVoltageDetectors(base, psConfig->u32EnabledDetectors);
        }

        if ((status == kStatus_Success) && !bBandgapEnabled)
        {
            status = SPC_SetBandgapMode(base, psConfig->eBandgapMode);
        }
    }

    return status;
}
