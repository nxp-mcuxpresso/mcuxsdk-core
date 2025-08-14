/*
 * Copyright 2024-2025 NXP
 * All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/*==========================================================================
Implementation file for Low level drivers for CM33-CE Driver
==========================================================================*/

#include "fsl_common.h"
#include "fsl_ce_cmd.h"
#include "fsl_mu.h"

#define CE_MU           MUA
#define CE_COMPUTE_DONE 0xD09EU

static ce_cmdbuffer_t *s_ce_cmdbuffer;

#define NOP1  __asm("NOP");
#define NOP4  NOP1 NOP1 NOP1 NOP1
#define NOP16 NOP4 NOP4 NOP4 NOP4
#define NOP32 NOP16 NOP16

/*!
 * brief Inserts a small delay using a NOP instruction.
 */
static inline void CE_CmdDelay(void)
{
    NOP32
}

/*!
 * brief Initalizes the ARM-CE command buffer
 *
 * Initalizes the ARM-CE command buffer. Needs to called on power-up or reset
 * or if the command mode needs to be changed.
 * param[in] psCmdBuffer  Pointer to the command buffer structure, application shall
 * allocate it, and it shall be in CE memory.
 * param[in] cmdbuffer    The command buffer memory. Size of the buffer should be 256.
 * param[in] statusbuffer The status buffer memory. Size of the buffer should be 134.
 * param[in] cmdmode Whether one command or multi command queue, and, blocking or non-blocking
 * call
 *
 * return Currently only return 0.
 */
int CE_CmdInitBuffer(ce_cmdbuffer_t *psCmdBuffer,
                     volatile uint32_t cmdbuffer[],
                     volatile int statusbuffer[],
                     ce_cmd_mode_t cmdmode)
{
    s_ce_cmdbuffer = psCmdBuffer;

    s_ce_cmdbuffer->cmdmode           = cmdmode;
    s_ce_cmdbuffer->buffer_base_ptr   = cmdbuffer;
    s_ce_cmdbuffer->status_buffer_ptr = statusbuffer;
    (void)CE_CmdReset();

    return 0;
}

/*!
 * brief Resets the command queue
 *
 * Any pending commands in the queue will be flushed.
 *
 * return Currently only return 0.
 */
int CE_CmdReset(void)
{
    volatile uint32_t *cmd_base     = s_ce_cmdbuffer->buffer_base_ptr;
    *cmd_base                       = 0xCCCC;
    s_ce_cmdbuffer->next_buffer_ptr = cmd_base + 1;
    s_ce_cmdbuffer->n_cmd           = 0;

    return 0;
}

/*!
 * brief Adds a command to the command queue
 *
 * param cmd Specifies the command name
 * param cmdargs Defines all arguments for the command
 * retval 0  Command added successfully
 * retval -1 Command not added since command queue is at maximum limit
 */
int CE_CmdAdd(ce_cmd_t cmd, ce_cmdstruct_t *cmdargs)
{
    int addstatus;
    volatile unsigned short *nargsbase;
    unsigned short i;
    unsigned int size;
    volatile uint32_t *cmdbase;
    void **ptrargbase;
    int *ptrparambase;

    if (s_ce_cmdbuffer->n_cmd < CE_CMD_MAX_CMDS_ZVQ)
    {
        size    = sizeof(void *) * cmdargs->n_ptr_args + sizeof(int) * ((unsigned int)cmdargs->n_param_args + 1U) + sizeof(short) * 2U;
        cmdbase = s_ce_cmdbuffer->next_buffer_ptr;

        *cmdbase = (unsigned int)cmd;

        nargsbase  = (volatile unsigned short *)(cmdbase + 1U);
        *nargsbase = cmdargs->n_ptr_args;
        nargsbase += 1;
        *nargsbase = cmdargs->n_param_args;
        nargsbase += 1;

        ptrargbase = (void **)nargsbase;
        for (i = 0; i < cmdargs->n_ptr_args; i++)
        {
            *ptrargbase = cmdargs->arg_ptr_array[i];
            ptrargbase += 1;
        }

        ptrparambase = (int *)ptrargbase;
        for (i = 0; i < cmdargs->n_param_args; i++)
        {
            *ptrparambase = cmdargs->arg_param_array[i];
            ptrparambase += 1;
        }

        s_ce_cmdbuffer->n_cmd++;

        cmdbase += (size / sizeof(int));
        s_ce_cmdbuffer->next_buffer_ptr = cmdbase;

        addstatus = 0;
    }
    else
    {
        addstatus = -1;
    }

    return addstatus;
}

/*!
 * brief Launches the command queue for execution on CE
 *
 * param force_launch Specifies the mode
 *    - 1: executes the queue regardless of the command mode
 *    - 0: executes the queue only if in ONE cmd mode. Otherwise, does nothing
 *
 * return Return 0 if succeeded, otherwise return error code.
 */
int CE_CmdLaunch(int force_launch)
{
    if (force_launch == 1)
    {
        if (s_ce_cmdbuffer->cmdmode > kCE_CmdModeMultipleNonBlocking)
        {
            return CE_CmdLaunchBlocking();
        }
        else
        {
            return CE_CmdLaunchNonBlocking();
        }
    }

    if (s_ce_cmdbuffer->cmdmode == kCE_CmdModeOneNonBlocking)
    {
        return CE_CmdLaunchNonBlocking();
    }

    if (s_ce_cmdbuffer->cmdmode == kCE_CmdModeOneBlocking)
    {
        return CE_CmdLaunchBlocking();
    }

    return 0;
}

/*!
 * brief Launches the current command queue and returns upon completion of the queue on CE
 *
 * return Return 0 if succeeded, otherwise return error code.
 */
int CE_CmdLaunchBlocking(void)
{
    unsigned int n_cmd;
    status_t status = kStatus_Fail;

#if CE_COMPUTE_TIMEOUT
    uint32_t timeout = CE_COMPUTE_TIMEOUT;
#endif

    if (s_ce_cmdbuffer->n_cmd == 0U)
    {
        return -2; /* no commands to send */
    }

    /* write number of commands via TX2 reg */
    status = MU_SendMsg((MU_Type *)DSP0_MU_BASE_ADDR, 2U, s_ce_cmdbuffer->n_cmd);
    if (kStatus_Success != status)
    {
        assert(false);
    }

    CE_CmdDelay();
    /* launch CE by sending MU interrupt */
    status = MU_TriggerInterrupts((MU_Type *)DSP0_MU_BASE_ADDR, (uint32_t)kMU_GenInt0InterruptTrigger);
    if (kStatus_Success != status)
    {
        assert(false);
    }

    /* blocking: so poll till completion */
    /* completion is signaled when ZV2117 writes "D09E"to top of cmd buffer */
    n_cmd = *(s_ce_cmdbuffer->buffer_base_ptr);

    while (n_cmd != CE_COMPUTE_DONE)
    {
#if CE_COMPUTE_TIMEOUT
        if (--timeout == 0U)
        {
            return kStatus_Timeout;
        }
#endif
        CE_CmdDelay();
        n_cmd = *(s_ce_cmdbuffer->buffer_base_ptr);
    }

    (void)CE_CmdReset();

    /* read the status register */
    return *(s_ce_cmdbuffer->status_buffer_ptr + 1U);
}

/*!
 * brief Launches the current command queue and returns without waiting for completion on CE
 *
 * CE Will send an interrupt via MUA->GCR to ARM upon completion of task. User can also poll to check for completion.
 * User has to call CE_CmdReset() in the IRQ handler. IRQ::DSP_IRQn needs to be enabled.
 *
 * return Currently only return 0.
 */
int CE_CmdLaunchNonBlocking(void)
{
    status_t status = kStatus_Fail;

    /* Launches non-blocking */
    if (s_ce_cmdbuffer->n_cmd == 0U)
    {
        return -2; /* no commands to send */
    }
    /* Write number of commands via TX2 reg,
     * set MSb to indicate non-blocking mode to ZENV: ZENV will send interrupt back in this case. */
    status = MU_SendMsg((MU_Type *)DSP0_MU_BASE_ADDR, 2U, 0x80000000U | s_ce_cmdbuffer->n_cmd);
    if (kStatus_Success != status)
    {
        assert(false);
    }

    CE_CmdDelay();

    /* launch CE by sending MU interrupt */
    status = MU_TriggerInterrupts((MU_Type *)DSP0_MU_BASE_ADDR, (uint32_t)kMU_GenInt0InterruptTrigger);
    if (kStatus_Success != status)
    {
        assert(false);
    }

    /* non-blocking: so return and the ARM core can resume other tasks */
    return 0;
}

/*!
 * brief Checks the command queue execution status on CE
 *
 * retval 0 Task completed and CE is ready for next command(s)
 * retval 1 Task still running; CE is busy
 */
int CE_CmdCheckStatus(void)
{
    int status         = -1;
    unsigned int n_cmd = *(s_ce_cmdbuffer->buffer_base_ptr);

    if (n_cmd != CE_COMPUTE_DONE)
    {
        status = CE_STATUS_BUSY; /* still running */
    }
    else
    {
        status = CE_STATUS_IDLE; /* completed */
        (void)CE_CmdReset();
    }

    return status;
}
