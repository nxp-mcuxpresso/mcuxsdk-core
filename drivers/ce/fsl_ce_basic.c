/*
 * Copyright 2024-2025 NXP
 * All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/*==========================================================================
Implementation file for CE wrapper/driver functions on ARM
==========================================================================*/

#include "fsl_ce_basic.h"
#include "fsl_ce_cmd.h"

/*!
 * brief Execute command in command queue
 *
 * return Command execution status.
 */
int32_t CE_ExecCmd(void)
{
    int32_t status = CE_CmdLaunch(1);

    return status;
}

/*!
 * brief Simple echo test cmd
 *
 * return Command execution status.
 */
int32_t CE_NullCmd(void)
{
    int32_t status;

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args   = 0;
    cmdstruct.n_param_args = 0;

    status = CE_CmdAdd(kCE_Cmd_NULLCMD, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Copies one memory buffer to another
 *
 * Copies one memory buffer to another. Copy is in units of words. Any data type
 * can be used.
 *
 * param pDst Pointer to destination buffer
 * param pSrc Pointer to source buffer
 * param N    Number of words to copy
 *
 * return Command execution status.
 */
int32_t CE_Copy(int32_t *pDst, int32_t *pSrc, const int32_t N)
{
    int32_t status;

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 2;
    cmdstruct.n_param_args       = 1;
    cmdstruct.arg_ptr_array[0]   = (void *)pDst;
    cmdstruct.arg_ptr_array[1]   = (void *)pSrc;
    cmdstruct.arg_param_array[0] = N;

    status = CE_CmdAdd(kCE_Cmd_ZVCOPY, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}
