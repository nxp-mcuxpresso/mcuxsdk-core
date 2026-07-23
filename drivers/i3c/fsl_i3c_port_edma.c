/*
 * Copyright 2026 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "fsl_i3c_port.h"

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/* Component ID definition, used by tools. */
#ifndef FSL_COMPONENT_ID
#define FSL_COMPONENT_ID "platform.drivers.i3c_port_edma"
#endif

/*! @brief Bytes moved per DMA request, fixed by the 16-bit I3C data ports. */
#define I3C_PORT_BYTES_PER_REQUEST (2UL)

/*******************************************************************************
 * Prototypes
 ******************************************************************************/

/*******************************************************************************
 * Code
 ******************************************************************************/

/*!
 * brief Generic eDMA completion callback.
 *
 * param dmaHandle The eDMA handle that finished.
 * param param The port context registered with EDMA_SetCallback().
 * param done Whether the major loop finished.
 * param tcds Unused, scatter/gather is not used by this port.
 */
static void I3C_PortDmaCallback(edma_handle_t *dmaHandle, void *param, bool done, uint32_t tcds)
{
    i3c_port_dma_ctx_t *context = (i3c_port_dma_ctx_t *)param;

    if (done && (NULL != context->callback))
    {
        context->callback(context->userData);
    }
}

/*!
 * brief Starts one halfword DMA transfer on the context's resource.
 *
 * param context The port context; its resource must be set.
 * param direction #kI3C_Write for memory to peripheral, #kI3C_Read for peripheral to memory.
 * param regAddr Address of the 16-bit I3C data register.
 * param buffer Memory buffer, 2-byte aligned.
 * param bytes Bytes to move, nonzero and even.
 * retval #kStatus_Success The transfer was started.
 */
status_t I3C_PortDMAStart(
    i3c_port_dma_ctx_t *context, i3c_direction_t direction, uint32_t regAddr, void *buffer, size_t bytes)
{
    assert(NULL != context);
    assert(NULL != context->handle);
    assert(NULL != buffer);
    assert((0UL != bytes) && (0UL == (bytes % I3C_PORT_BYTES_PER_REQUEST)));
    assert(0UL == (((uint32_t)(uintptr_t)(const uint8_t *)buffer) % I3C_PORT_BYTES_PER_REQUEST));

    edma_transfer_config_t xferConfig;

    context->transBytes = bytes;

    if (direction == kI3C_Write)
    {
        EDMA_PrepareTransfer(&xferConfig, buffer, sizeof(uint16_t), (uint32_t *)regAddr, sizeof(uint16_t),
                             I3C_PORT_BYTES_PER_REQUEST, bytes, kEDMA_MemoryToPeripheral);
    }
    else
    {
        EDMA_PrepareTransfer(&xferConfig, (uint32_t *)regAddr, sizeof(uint16_t), buffer, sizeof(uint16_t),
                             I3C_PORT_BYTES_PER_REQUEST, bytes, kEDMA_PeripheralToMemory);
    }
    (void)EDMA_SubmitTransfer(context->handle, &xferConfig);
    EDMA_StartTransfer(context->handle);

    return kStatus_Success;
}

/*!
 * brief Aborts both active I3C port DMA movements of the transfer.
 *
 * Aborts the from-bus and to-bus contexts in one call; the to-bus direction is skipped when
 * it has no registered DMA resource (its handle is NULL, as on devices with OR'd I3C DMA
 * requests where only one channel is registered), so the caller never tests for it.
 *
 * param rxContext Port DMA context for the from-bus direction.
 * param txContext Port DMA context for the to-bus direction.
 */
void I3C_PortDMAAbort(i3c_port_dma_ctx_t *rxContext, i3c_port_dma_ctx_t *txContext)
{
    assert(NULL != rxContext);
    assert(NULL != rxContext->handle);

    EDMA_AbortTransfer(rxContext->handle);
    rxContext->transBytes = 0UL;

    if ((NULL != txContext) && (NULL != txContext->handle))
    {
        EDMA_AbortTransfer(txContext->handle);
        txContext->transBytes = 0UL;
    }
}

/*!
 * brief Returns the bytes already moved of the context's currently started transfer.
 *
 * param context The port context.
 * return Bytes moved so far, 0 when nothing was started yet.
 */
size_t I3C_PortDMAGetTransBytes(i3c_port_dma_ctx_t *context)
{
    assert(NULL != context);
    assert(NULL != context->handle);

    size_t remainingBytes;

    if (0UL == context->transBytes)
    {
        return 0UL;
    }

    /* The remaining major loop count is the number of outstanding peripheral requests,
       one halfword each; the engine reports 0 once the major loop completed. */
    remainingBytes =
        (size_t)EDMA_GetRemainingMajorLoopCount(context->handle->base, (uint32_t)context->handle->channel) *
        I3C_PORT_BYTES_PER_REQUEST;
    if (remainingBytes > context->transBytes)
    {
        /* An aborted channel can report its reloaded beginning count - clamp it. */
        remainingBytes = context->transBytes;
    }

    return context->transBytes - remainingBytes;
}

/*!
 * brief Registers the DMA-done notification on the context.
 *
 * The callback is invoked from the DMA completion interrupt each time a transfer
 * started with I3C_PortDMAStart() on this context finishes moving all its bytes.
 *
 * param context The port context to attach the notification to.
 * param callback The notification function, NULL to disable the notification.
 * param userData User data passed to the callback.
 */
void I3C_PortDMASetCallback(i3c_port_dma_ctx_t *context, i3c_port_dma_callback_t callback, void *userData)
{
    assert(NULL != context);
    assert(NULL != context->handle);

    context->callback = callback;
    context->userData = userData;

    EDMA_SetCallback(context->handle, I3C_PortDmaCallback, (void *)context);
}
