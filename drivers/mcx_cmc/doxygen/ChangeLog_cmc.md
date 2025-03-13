# MCX_CMC

## [2.2.3]

- Improvements
  - Clear SCB SCR[SLEEPDEEP] bitfield after wakeup.

## [2.2.2]

- Improvements
  - Fixed the violation of MISRA C-2012 rules.

## [2.2.1]

- Improvements

  - Updated _cmc_system_reset_interrupt_enable, _cmc_system_reset_interrupt_flag
    and _cmc_system_reset_sources to support new added bit field.

- Bug Fixes

  - Fixed issue in CMC_PowerOffSRAMAllMode() and CMC_PowerOffSRAMLowPowerOnly() which
    overwrite reserved bit fields.

## [2.2.0]

- Improvements
  - Added feature macro "FSL_FEATURE_MCX_CMC_HAS_NO_FLASHCR_WAKE" to support some
    devices where FLASHCR[WAKE] is reserved.

## [2.1.0]

- Improvements
  - Added macros to support some devices(such as MCXA family) that only support one power domain.

## [2.0.0]

- Initial version.
