# MCX_SPC

## [2.8.1]

- Improvements
  - Fixed cert_int31_c_violation of  SPC_GetVoltageDetectStatusFlag(), SPC_GetExternalDomainsStatus()
    and SPC_SetDCDCBurstConfig.

## [2.8.0]

- New Features
  - Updated MCX_SPC driver for compatibility with SoCs without PD_STATUS[PWR_REQ_STATUS].

## [2.7.0]

- New Features
  - Added new function to unretain RAM array.

## [2.6.0]

- Bug Fixes
  - The enumeration kSPC_DeepPowerDownWithSysClockOff should be 0x8U.
- New Features
  - Added functions to get the last low-power mode that the power domain requested.

## [2.5.0]

- Improvements
  - Updated SPC_SetLowPowerModeCoreLDORegulatorConfig() with adding check that LP_CFG[CORELDO_VDD_LVL]
    only be updated when CORELDO is in normal driver strength in active mode.
  - Updated SPC_SetLowPowerModeRegulatorsConfig() with adding check the if DCDC voltage level set as retention
    mode, CORELDO low voltage detection must be disabled.
  - Updated spc_analog_module_control with adding Opamp3 support.
- New Features
  - Added functions to mask/unmask voltage detections in active mode.

## [2.4.2]

- Improvements
  - Fixed the violation of MISRA C-2012 rules.

## [2.4.1]

- Improvements
  - Fixed the violation of MISRA C-2012 rules.

## [2.4.0]

- Improvements
  - Refined APIs to set regulators, the input parameters will be check firstly before setting register.
  - Improved APIs' document.
  - Removed software check for DCDC's settings since there is not hardware restrictions for DCDC.
  - Added new APIs to check if glitch detector is enabled in active/low power mode.
  - Added new APIs for DCDC burst feature, make it more flexible to use.
  - Added new API to enable/disable DCDC bleed resistor.
  - Set functions of VD_SYS_CFG[LVSEL] configuration as deprecated,
    since this bit filed is reserved for all devices.
  - Updated details of spc_core_ldo_voltage_level_t to align with description of latest RM,
    added comments to reminder users that the retention voltage is reserved in some devices.

## [2.3.0]

- New Features
  - Updated glitch detect API to support devices which do not have aGDET

## [2.2.1]

- Bug Fixes
  - Fixed an issue of SPC_SetActiveModeRegulatorsConfig() which will cause LVD in case of setting
    DCDC and CORE LDO into higher voltage level.

## [2.2.0]

- New Features
  - Added some macros to support some devices(such as MCXA family) do not equipped DCDC, SYS_LDO and so on.
  - Added new function SPC_EnableSRAMLdOLowPowerModeIREF(), SPC_TrimSRAMLdoRefVoltage(),
    SPC_EnableSRAMLdo() to support some devices(such as MCXA family) that support control of
    SRAM_LDO.
  - Fixed violation of MISRA C-2012 rule 17.7.
  - Fixed an issue in SPC_SetLowPowerModeRegulatorsConfig() function that set ACTIVE_CFG register by mistake.

## [2.1.0]

- Improvements
  - Added new functions to set regulators' voltage level and drive strength individually.
  - Updated SPC_SetActiveModeRegulatorsConfig() and SPC_SetLowPowerModeRegulatorsConfig()
    based on new added functions.

## [2.0.1]

- Bug Fixes
  - Fixed a bug that external burst not working properly.
  - Fixed a bug that is SPC has VDD_DS the voltage is not configured correctly.

## [2.0.0]

- Initial version.
