# XSPI EDMA Driver

## [2.0.5]

- Bug Fixes
  - Fixed XSPI_TransferEDMA() read transfer completing short of the configured watermark on unoptimized builds. Reordered the read branch to clear the RX buffer and arm the eDMA transfer before issuing the IP read command, matching the write branch and XSPI_TransferBlocking()'s read path.

## [2.0.4]
- Bug Fixes
  - Fixed violations in XSPI_TransferEDMACallback() function, avoid warning of unused parameters.

## [2.0.3]

- Bug Fixes
  - Fixed violations of MSG.

## [2.0.2]

- Bug Fixes
  - Fixed violations of MISRA C-2012 rules.

## [2.0.1]

- Improvements
  - Invoked new defined interface of xspi driver.
  - In callback function, disable RX/TX DMA.

## [2.0.0]

- Initial version.
