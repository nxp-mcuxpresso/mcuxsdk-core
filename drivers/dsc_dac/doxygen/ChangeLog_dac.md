# DAC

## [2.1.0]

- Improvements
  - Update the driver for compatibility with MC56F85xxx.
- Bug Fixes
  - Fixed the issue that DAC_Init() and DAC_SetGlitchFilterCount() wrote the whole CTRL1 register,
    which cleared the reserved bit field that has to keep its reset value.

## [2.0.1]

- Improvements
- Supported MC56F82xxx and MC56F84xxx.
  - Bug Fixes
- Fixed violations of the MISRA C-2012 rules.

## [2.0.0]

- Initial version.
