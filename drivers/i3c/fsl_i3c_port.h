/*
 * Copyright 2026 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef FSL_I3C_PORT_H_
#define FSL_I3C_PORT_H_

#include "fsl_i3c.h"

#if defined(FSL_FEATURE_SOC_EDMA_COUNT) && (FSL_FEATURE_SOC_EDMA_COUNT > 0)
#include "fsl_edma.h"
/*! @brief Platform-neutral DMA resource servicing one I3C message data port. */
typedef edma_handle_t i3c_port_dma_handle_t;
#else
#error "No I3C message-mode DMA port is available for this device yet."
#endif

/*!
 * @brief Port DMA-done notification from the backend into the message-mode state machine.
 * @param userData Parameter registered with I3C_PortDMASetCallback().
 */
typedef void (*i3c_port_dma_callback_t)(void *userData);

/*!
 * @brief Context for one I3C port DMA resource.
 *
 * The message-mode driver embeds one per direction in its handle. Driver-private; the
 * application must not touch any field.
 */
typedef struct _i3c_port_dma_ctx
{
    i3c_port_dma_handle_t *handle;    /*!< DMA handle. */
    i3c_port_dma_callback_t callback; /*!< Port DMA-done notification into the state machine. */
    void *userData;                   /*!< Parameter for the port DMA-done notification. */
    size_t transBytes;                /*!< Byte count of the most recently started port DMA transfer. */
} i3c_port_dma_ctx_t;

/*******************************************************************************
 * API
 ******************************************************************************/

#if defined(__cplusplus)
extern "C" {
#endif

/*!
 * @brief Starts one memory<->peripheral halfword DMA transfer on the context's resource.
 *
 * The DMA channel is armed to move @a bytes to/from the selected 16-bit I3C data register
 * at @a regAddr, one halfword per peripheral request; the I3C peripheral paces the requests.
 *
 * @param context The port context (its @c resource must be set) to start.
 * @param direction #kI3C_Write moves @a buffer to the peripheral write port,
 *        #kI3C_Read moves the peripheral read port to @a buffer.
 * @param regAddr Address of the I3C data register.
 * @param buffer Memory buffer, 2-byte aligned.
 * @param bytes Bytes to move, nonzero and even.
 * @retval #kStatus_Success The transfer was started.
 */
status_t I3C_PortDMAStart(
    i3c_port_dma_ctx_t *context, i3c_direction_t direction, uint32_t regAddr, void *buffer, size_t bytes);

/*!
 * @brief Aborts both active I3C port DMA movements of the transfer.
 *
 * Aborts the from-bus and to-bus contexts in one call; the to-bus direction is skipped when
 * it has no registered DMA resource (as on devices with OR'd I3C DMA requests where only one
 * channel is registered), so the caller never tests for it.
 *
 * @param rxContext Port DMA context for the from-bus direction.
 * @param txContext Port DMA context for the to-bus direction, may be NULL or contain a NULL
 *        handle on devices that service both directions from one DMA resource.
 */
void I3C_PortDMAAbort(i3c_port_dma_ctx_t *rxContext, i3c_port_dma_ctx_t *txContext);

/*!
 * @brief Returns the bytes already moved of the context's currently started transfer.
 *
 * The value is only meaningful between a start and the next abort/start; it returns 0
 * when nothing was started yet.
 *
 * @param context The port context to query.
 * @return Bytes moved so far of the currently started transfer.
 */
size_t I3C_PortDMAGetTransBytes(i3c_port_dma_ctx_t *context);

/*!
 * @brief Registers the DMA-done notification on the context.
 *
 * The @a callback is invoked from the DMA completion interrupt each time a transfer
 * started with I3C_PortDMAStart() on this context finishes moving all its bytes.
 *
 * @param context The port context to attach the notification to.
 * @param callback The notification function, NULL to disable the notification.
 * @param userData User data passed to the callback.
 */
void I3C_PortDMASetCallback(i3c_port_dma_ctx_t *context, i3c_port_dma_callback_t callback, void *userData);

#if defined(__cplusplus)
}
#endif

#endif /* FSL_I3C_PORT_H_ */
