/*
 * Copyright 2024-2025 NXP
 * All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef FSL_CE_TRANSFORM_H
#define FSL_CE_TRANSFORM_H

#include <stdint.h>

// define FFT Error Codes
#define FFT_ERROR_SZOUTSIDERANGE 0xE00B

/*!
 * @ingroup ce
 * @defgroup ce_transform CE Transform Functions
 * @brief Functional API definitions for CE FFT functions.
 * @{
 */

/*******************************************************************************
 * Variables
 ******************************************************************************/

/*******************************************************************************
 * API
 ******************************************************************************/

#ifdef __cplusplus
extern "C" {
#endif

/*!
 * @brief Calculates the FFT for complex 16-bit floating point data.
 *
 * Computes N-point FFT of a complex 16-bit floating point data stream.
 * N must be a power of 2. Minimum N=16. Maximum N = 16384.
 *
 * Data precision and format is as defined by the argument type (except float*
 * is used for float16 data type as well to denote the pointer value)
 *
 * @param pY Pointer to buffer for FFT output
 * @param pX Pointer to buffer for FFT input
 * @param pScratch Pointer to scratch buffer. Must be equal to or greater than size of the output buffer
 * @param log2N log2(N), where N is the FFT size
 *
 * @return Command execution status.
 */
int32_t CE_TransformCFFT_F16(float *pY, float *pX, float *pScratch, int32_t log2N);

/*!
 * @brief Calculates the FFT for complex 32-bit floating point data.
 *
 * Computes N-point FFT of a complex 32-bit floating point data stream.
 * N must be a power of 2. Minimum N=32. Maximum N = 16384.
 *
 * @param pY Pointer to FFT output (complex float32 data)
 * @param pX Pointer to FFT input (complex float32 data)
 * @param pScratch Pointer to a scratch buffer (minimum size N*8 bytes)
 * @param log2N log2(N) where N is the FFT size
 *
 * @return Command execution status.
 */
int32_t CE_TransformCFFT_F32(float *pY, float *pX, float *pScratch, int32_t log2N);

/*!
 * @brief Calculates the IFFT for complex 16-bit floating point data.
 *
 * Computes N-point IFFT of a complex 16-bit floating point data stream.
 * N must be a power of 2. Minimum N=16. Maximum N = 16384.
 *
 * Data precision and format is as defined by the argument type (except float*
 * is used for float16 data type as well to denote the pointer value)
 *
 * @param pY Pointer to buffer for IFFT output
 * @param pX Pointer to buffer for IFFT input
 * @param pScratch Pointer to scratch buffer. Must be equal to or greater than size of the output buffer
 * @param log2N log2(N), where N is the IFFT size
 *
 * @return Command execution status.
 */
int32_t CE_TransformIFFT_F16(float *pY, float *pX, float *pScratch, int32_t log2N);

/*!
 * @brief Calculates the IFFT for complex 32-bit floating point data.
 *
 * Computes N-point IFFT of a complex 16-bit floating point data stream.
 * N must be a power of 2. Minimum N=16. Maximum N = 16384.
 *
 * @param pY Pointer to buffer for IFFT output
 * @param pX Pointer to buffer for IFFT input
 * @param pScratch Pointer to scratch buffer. Must be equal to or greater than size of the output buffer
 * @param log2N log2(N), where N is the IFFT size
 *
 * @return Command execution status.
 */
int32_t CE_TransformIFFT_F32(float *pY, float *pX, float *pScratch, int32_t log2N);

#ifdef __cplusplus
}
#endif

/*!
 * @}
 */

#endif /*FSL_CE_TRANSFORM_H*/
