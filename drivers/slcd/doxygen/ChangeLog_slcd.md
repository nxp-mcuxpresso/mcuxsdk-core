# SLCD

## [2.2.0]

- New Features
  - Added slcd_buf_power_mode_t and the FSL_FEATURE_SLCD_HAS_BUF_POWER_MODE gated config fields,
    updated SLCD_Init and SLCD_GetDefaultConfig to support SoCs whose SLCD IP controls contrast
    via an analog buffer power mode instead of software voltage trim.

## [2.1.1]

- Improvements
  - Update slcd_duty_cycle_t, slcd_phase_type_t and slcd_phase_index_t, MCXA3xx SoCs only have
    48 pins and 4 pack plane phases.
  - Added check for front plane pin index and back plane phase index.

## [2.1.0]

- New Features
  - Added new enumerations, updated SLCD_Init and SLCD_GetDefaultConfig to support
    new low power IP on new SoCs.

## [2.0.4]

- Bug Fixes
  - Fixed violations of the MISRA C-2012 rules 10.4.

## [2.0.3]

- Bug Fixes
  - Fixed SLCD_Init bug that some bit-fileds are cleared by mistake.

## [2.0.2]

- Bug Fixes
  - Fixed violations of the MISRA C-2012 rules 3.1, 10.1, 10.3, 10.3, 10.4
    11.4, 17.7

## [2.0.1]

- Bug Fixes
  - Changed the Blink mode start setting flow.
- Other Changes
  - Added static to SLCD global variables.

## [2.0.0]

- Initial version.
