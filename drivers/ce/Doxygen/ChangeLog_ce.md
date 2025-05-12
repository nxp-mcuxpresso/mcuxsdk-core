# CE

## [2.2.0]
- Bug Fixes
  - Fix the issue that eigenvectors are NaNs with triangular or square input Hermitian.

## [2.1.1]

- Improvements
  - Add checking its value before casting N from unsigned int to int.
  - Update the types of the buffer_base_ptr, next_buffer_ptr and status_buffer_ptr
    variables in the ce_cmdbuffer_t structure.

## [2.1.0]

- New Features
  - Added ZV->CM33 interrupt for non-blocking mode and updated matrix multiply
    function to handle small matrices.

## [2.0.1]

- Bug Fixes
  - Add the conditional compiling flags KW47_core0_SERIES and MCXW72_core0_SERIES
    to fix the CE driver compiling issues in Core1.

## [2.0.0]

- Initial version.
