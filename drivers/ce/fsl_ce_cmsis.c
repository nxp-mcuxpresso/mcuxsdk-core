/*
 * Copyright 2024 NXP
 * All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/*==========================================================================
Implementation file for ARM API compatible FFT functions on CE
==========================================================================*/

#include "fsl_ce_cmsis.h"
#include "fsl_ce_cmd.h"
#include "fsl_ce_transform.h"

void ce_arm_cfft_f32(
    const arm_cfft_instance_f32 *S, float *p1, uint8_t ifftFlag, uint8_t bitReverseFlag, float *pOut, float *pScratch)
{
    int l2N = 0;
    uint16_t temp = S->fftLen;

    if (temp > 0U)
    {
        while ((temp & 0x1U) != 1U)
        {
            temp = temp >> 1U;
            l2N++;
        }
    }

    if (ifftFlag == 0U)
    {
        (void)CE_TransformCFFT_F32(pOut, p1, pScratch, l2N);
    }
    else
    {
        (void)CE_TransformIFFT_F32(pOut, p1, pScratch, l2N);
    }
}
