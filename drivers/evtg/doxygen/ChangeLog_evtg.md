# EVTG

## [2.0.4]

- Improvements
  - Enabled the EVTG peripheral clock inside EVTG_Init() (guarded by FSL_SDK_DISABLE_DRIVER_CLOCK_CONTROL),
    so the driver no longer relies on the application to ungate the clock.

## [2.0.3]

- Bug Fixes
  - Fixed coverity issues with CERT INT30-C, CERT INT31-C compliance.

## [2.0.2]

- Bug Fixes
  - MISRA C-2012 issue fixed: rule 10.8.

## [2.0.1]

- Bug Fixes
  - MISRA C-2012 issue fixed: rule 10.7,15.7,10.1,10.4,10.8,10.3,16.1,16.3 .

## [2.0.0]

- Initial version.
