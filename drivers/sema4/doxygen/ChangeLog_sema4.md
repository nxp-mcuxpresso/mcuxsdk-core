# SEMA4

## [2.1.0]

- Improvements
  - Changed mask parameter type in SEMA4_EnableGateNotifyInterrupt() and SEMA4_DisableGateNotifyInterrupt() functions 
    to avoid casting from unsigned long to unsigned short in the code when modifying the 16bits CPINE register.

## [2.0.3]

- Improvements
  - Changed to implement SEMA4_Lock base on SEMA4_TryLock.

## [2.0.2]

- Improvements:
  - Supported the SEMA4_Type structure whose gate registers are
    defined as an array.

## [2.0.1]

- Bug Fixes
  - Fixed violations of the MISRA C-2012 rules 10.3, 10.4, 15.5, 18.1, 18.4.

## [2.0.0]

- Initial version.
