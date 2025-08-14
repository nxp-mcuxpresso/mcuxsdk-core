/*
 * Copyright 2024-2025 NXP
 * All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/*==========================================================================
Implementation file for CE wrapper/driver FFT functions on ARM
==========================================================================*/

#include "fsl_ce_transform.h"
#include "fsl_ce_cmd.h"

/*!
 * brief Calculates the FFT for complex 16-bit floating point data.
 *
 * Computes N-point FFT of a complex 16-bit floating point data stream.
 * N must be a power of 2. Minimum N=16. Maximum N = 16384.
 *
 * Data precision and format is as defined by the argument type (except float*
 * is used for float16 data type as well to denote the pointer value)
 *
 * param pY Pointer to buffer for FFT output
 * param pX Pointer to buffer for FFT input
 * param pScratch Pointer to scratch buffer. Must be equal to or greater than size of the output buffer
 * param log2N log2(N), where N is the FFT size
 *
 * return Return 0 if succeeded, otherwise return error code.
 */
int CE_TransformCFFT_F16(float *pY, float *pX, float *pScratch, int log2N)
{
    int status;

    if (log2N < 5 || log2N > 15)
    {
        status = FFT_ERROR_SZOUTSIDERANGE;
        return status;
    }

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 1;
    cmdstruct.arg_ptr_array[0]   = (void *)pX;
    cmdstruct.arg_ptr_array[1]   = (void *)pScratch;
    cmdstruct.arg_ptr_array[2]   = (void *)pY;
    cmdstruct.arg_param_array[0] = log2N;

    status = CE_CmdAdd(kCE_Cmd_CFFT_F16, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Calculates the FFT for complex 32-bit floating point data.
 *
 * Computes N-point FFT of a complex 32-bit floating point data stream.
 * N must be a power of 2. Minimum N=32. Maximum N = 16384.
 *
 * param pY Pointer to FFT output (complex float32 data)
 * param pX Pointer to FFT input (complex float32 data)
 * param pScratch Pointer to a scratch buffer (minimum size N*8 bytes)
 * param log2N log2(N) where N is the FFT size
 *
 * return Return 0 if succeeded, otherwise return error code.
 */
int CE_TransformCFFT_F32(float *pY, float *pX, float *pScratch, int log2N)
{
    int status;

    if (log2N < 5 || log2N > 15)
    {
        status = FFT_ERROR_SZOUTSIDERANGE;
        return status;
    }

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 1;
    cmdstruct.arg_ptr_array[0]   = (void *)pX;
    cmdstruct.arg_ptr_array[1]   = (void *)pScratch;
    cmdstruct.arg_ptr_array[2]   = (void *)pY;
    cmdstruct.arg_param_array[0] = log2N;

    status = CE_CmdAdd(kCE_Cmd_CFFT_F32, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Calculates the IFFT for complex 16-bit floating point data.
 *
 * Computes N-point IFFT of a complex 16-bit floating point data stream.
 * N must be a power of 2. Minimum N=16. Maximum N = 16384.
 *
 * Data precision and format is as defined by the argument type (except float*
 * is used for float16 data type as well to denote the pointer value)
 *
 * param pY Pointer to buffer for IFFT output
 * param pX Pointer to buffer for IFFT input
 * param pScratch Pointer to scratch buffer. Must be equal to or greater than size of the output buffer
 * param log2N log2(N), where N is the IFFT size
 *
 * return Return 0 if succeeded, otherwise return error code.
 */
int CE_TransformIFFT_F16(float *pY, float *pX, float *pScratch, int log2N)
{
    int status;

    if (log2N < 5 || log2N > 15)
    {
        status = FFT_ERROR_SZOUTSIDERANGE;
        return status;
    }

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 1;
    cmdstruct.arg_ptr_array[0]   = (void *)pX;
    cmdstruct.arg_ptr_array[1]   = (void *)pScratch;
    cmdstruct.arg_ptr_array[2]   = (void *)pY;
    cmdstruct.arg_param_array[0] = log2N;

    status = CE_CmdAdd(kCE_Cmd_IFFT_F16, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Calculates the IFFT for complex 32-bit floating point data.
 *
 * Computes N-point IFFT of a complex 16-bit floating point data stream.
 * N must be a power of 2. Minimum N=16. Maximum N = 16384.
 *
 * param pY Pointer to buffer for IFFT output
 * param pX Pointer to buffer for IFFT input
 * param pScratch Pointer to scratch buffer. Must be equal to or greater than size of the output buffer
 * param log2N log2(N), where N is the IFFT size
 *
 * return Return 0 if succeeded, otherwise return error code.
 */
int CE_TransformIFFT_F32(float *pY, float *pX, float *pScratch, int log2N)
{
    int status;

    if (log2N < 5 || log2N > 15)
    {
        status = FFT_ERROR_SZOUTSIDERANGE;
        return status;
    }

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 1;
    cmdstruct.arg_ptr_array[0]   = (void *)pX;
    cmdstruct.arg_ptr_array[1]   = (void *)pScratch;
    cmdstruct.arg_ptr_array[2]   = (void *)pY;
    cmdstruct.arg_param_array[0] = log2N;

    status = CE_CmdAdd(kCE_Cmd_IFFT_F32, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}
