/*
 * Copyright 2026 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */
#ifndef FSL_I3C_MSG_DMA_H_
#define FSL_I3C_MSG_DMA_H_

#include "fsl_i3c_port.h"

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/*!
 * @addtogroup i3c_master_msg_dma_driver
 * @{
 */

/*! @name Driver version */
/*! @{ */
/*! @brief I3C message mode DMA driver version. */
#define FSL_I3C_MSG_DMA_DRIVER_VERSION (MAKE_VERSION(2, 0, 0))
/*! @} */

/*!
 * @brief Maximum number of bytes in one SDR message.
 *
 * MWMSG_SDR_CONTROL.LEN is a 5-bit field counting bytes, so one SDR message can carry at
 * most 31 bytes. The driver caps SDR messages at 30 bytes, the largest even size: the
 * message data ports are 16-bit and DMA moves halfwords, so odd sizes are rejected.
 */
#define I3C_MSG_SDR_MAX_LEN (30U)

/*!
 * @brief Maximum number of data bytes in one HDR-DDR message.
 *
 * MWMSG_DDR_CONTROL2.LEN counts halfwords (data + the ADDRCMD word + the read CRC word).
 * ERR052122 makes LEN[9:8] be ignored on affected devices, so the usable field is 8-bit
 * (255 halfwords); a read spends 2 of those on ADDRCMD + CRC, leaving 253 data halfwords
 * = 506 bytes. The driver applies this ERR052122-safe cap on every device.
 */
#define I3C_MSG_DDR_MAX_LEN (506U)

/*! @brief Single message descriptor, one entry of a message-mode transfer. */
typedef struct _i3c_master_msg
{
    uint8_t slaveAddress;      /*!< 7-bit target address for this message. */
    i3c_direction_t direction; /*!< Read or Write. */
    void *data;                /*!< Data buffer, 2-byte aligned. */
    size_t dataSize;           /*!< Data bytes to transfer (see #I3C_MSG_SDR_MAX_LEN /
                                    #I3C_MSG_DDR_MAX_LEN for capacity and parity limits). */
    uint8_t command;           /*!< HDR-DDR 7-bit command code (bits [6:0]); the read/write
                                    bit is set by the driver from @c direction, not here.
                                    Used only for #kI3C_TypeI3CDdr, ignored for SDR/I2C. */
} i3c_master_msg_t;

/*! @brief Message-mode transfer descriptor, a list of messages framed as one bus transaction. */
typedef struct _i3c_master_msg_transfer
{
    i3c_master_msg_t *msgList;      /*!< Message list; each entry is one message. */
    size_t msgCount;                /*!< Number of messages. */
    i3c_bus_type_t busType;         /*!< kI3C_TypeI3CSdr, kI3C_TypeI2C or kI3C_TypeI3CDdr (HDR-DDR). */
    i3c_ibi_response_t ibiResponse; /*!< IBI response while the transfer runs. */
} i3c_master_msg_transfer_t;

/* Forward declaration of the handle typedef. */
typedef struct _i3c_master_msg_dma_handle i3c_master_msg_dma_handle_t;

/*!
 * @brief I3C master message-mode DMA callback functions.
 *
 * @c transferComplete reports the end of a message-mode transfer. @c ibiCallback, when
 * non-NULL, reports a target IBI caught asynchronously (message mode keeps SlaveStart armed
 * while idle for this). It is invoked with #kI3C_IbiDataBuffNeed to request a payload buffer
 * (store it in @c handle->ibiBuff), and with #kI3C_IbiReady once @c handle->ibiPayloadSize
 * bytes have been received into it. An IBI that instead wins arbitration on a message header
 * ends that transfer as @c transferComplete with #kStatus_I3C_IBIWon.
 */
typedef struct _i3c_master_msg_dma_callback
{
    void (*slave2Master)(I3C_Type *base, void *userData); /*!< Controller request callback. */
    void (*transferComplete)(I3C_Type *base,
                             i3c_master_msg_dma_handle_t *handle,
                             status_t status,
                             void *userData); /*!< Transfer complete callback. */
    void (*ibiCallback)(I3C_Type *base,
                        i3c_master_msg_dma_handle_t *handle,
                        i3c_ibi_type_t ibiType,
                        i3c_ibi_state_t ibiState); /*!< Target IBI event callback, may be NULL. */
} i3c_master_msg_dma_callback_t;

/*!
 * @brief Driver handle for master message-mode DMA APIs.
 *
 * Holds the message-mode transfer state together with the per-direction I3C port DMA
 * contexts used to move data through the selected data ports.
 *
 * @note The contents of this structure are driver-private and subject to change -
 * the application must not touch any field.
 */
struct _i3c_master_msg_dma_handle
{
    I3C_Type *base;                     /*!< I3C base pointer. */
    uint8_t state;                      /*!< Transfer state machine current state. */
    i3c_master_msg_transfer_t transfer; /*!< Copy of the current transfer descriptor. */
    size_t msgIdx;                      /*!< Index of the message currently on the bus. */
    size_t dmaBytes;                    /*!< Bytes started on the I3C port for the current message. */
    status_t result;                    /*!< Transfer result stashed by the state machine for the completion tail. */
    volatile bool dmaDone;              /*!< Port DMA-done notification for the current message. */
    i3c_master_msg_dma_callback_t callback; /*!< Callback function pointer. */
    void *userData;                         /*!< Application data passed to callback. */
    i3c_ibi_type_t ibiType;                 /*!< Type of the IBI currently being serviced. */
    uint8_t ibiAddress;                     /*!< Dynamic address of the target that issued the IBI. */
    uint8_t *ibiBuff;            /*!< IBI payload buffer, set by the app in the kI3C_IbiDataBuffNeed callback. */
    size_t ibiPayloadSize;       /*!< IBI payload bytes received into ibiBuff. */
    i3c_port_dma_ctx_t rxDmaCtx; /*!< Port DMA context for the from-bus message data. */
    i3c_port_dma_ctx_t txDmaCtx; /*!< Port DMA context for the to-bus message data. */
};

/*******************************************************************************
 * API
 ******************************************************************************/

#if defined(__cplusplus)
extern "C" {
#endif

/*! @name Master message mode DMA */
/*! @{ */

/*!
 * @brief Create a new handle for the I3C master message-mode DMA APIs.
 *
 * There is no corresponding destroy: to terminate a transfer call
 * I3C_MasterMsgTransferAbortDMA(). Creating the handle registers this driver as the
 * instance's master interrupt handler, so it is mutually exclusive with any other
 * master transactional handle (interrupt, EDMA or DMA) on the same instance.
 *
 * The DMA resources must be created by the application, with the channels muxed to this
 * instance's I3C RX/TX DMA requests, before this function is called. On devices where
 * the I3C send and receive DMA requests are OR'd together, @a txDmaHandle may be NULL;
 * @a rxDmaHandle then services both directions.
 *
 * @note ERR052343: on affected devices a target's early termination of a transfer is
 * invisible to the DMA request logic. Do not rely on target early termination under
 * DMA - size each message to what the target actually delivers.
 *
 * @param base The I3C peripheral base address.
 * @param handle Pointer to the I3C master message-mode DMA driver handle.
 * @param callback User provided pointer to the asynchronous callback structure.
 * @param userData User provided pointer to the application callback data.
 * @param rxDmaHandle DMA resource for the receive direction. Created by the user
 *        prior to calling this function.
 * @param txDmaHandle DMA resource for the transmit direction. Created by the user
 *        prior to calling this function; NULL on devices with OR'd I3C DMA requests.
 */
void I3C_MasterMsgTransferCreateHandleDMA(I3C_Type *base,
                                          i3c_master_msg_dma_handle_t *handle,
                                          const i3c_master_msg_dma_callback_t *callback,
                                          void *userData,
                                          i3c_port_dma_handle_t *rxDmaHandle,
                                          i3c_port_dma_handle_t *txDmaHandle);

/*!
 * @brief Performs a non-blocking SDR or HDR-DDR message-mode transfer using DMA.
 *
 * Each @c msgList entry is framed by hardware as one message: a header write makes the
 * controller emit START (or repeated START between messages), the address with the
 * direction, and - after the last message - the closing STOP. The 16-bit message data
 * ports are serviced by DMA and the state machine advances message-by-message on the
 * completion interrupt. This function returns right after the first message is issued; the
 * callback registered at handle creation is invoked with the final status once the last
 * message completes or an error terminates the transfer.
 *
 * @c busType selects SDR (#kI3C_TypeI3CSdr), legacy I2C (#kI3C_TypeI2C) or HDR-DDR
 * (#kI3C_TypeI3CDdr); for HDR-DDR each message @c command is the 7-bit command code (the
 * read/write bit is set by the driver from the direction). Each
 * @c slaveAddress must be a dynamic address already assigned through the CCC APIs
 * (SETDASA/ENTDAA). Each message @c data buffer must be 2-byte aligned (the ports are
 * serviced with halfword DMA transfers).
 *
 * Call context: task context only, one caller per handle.
 *
 * @note The transfer descriptor and the message list must stay valid and untouched
 * until the @c transferComplete callback fires.
 * @note Messages after a failing @c msgList entry are not issued, messages already
 * completed stay on the wire, and the callback status does not identify the failing
 * entry.
 *
 * Callback status set: #kStatus_Success, #kStatus_I3C_Nak, #kStatus_I3C_WriteAbort,
 * #kStatus_I3C_MsgError, #kStatus_I3C_IBIWon (IBI payload discarded), #kStatus_I3C_Term
 * (target ended a read early). On error the bus is stopped and the block recovered.
 *
 * @param base The I3C peripheral base address.
 * @param handle Pointer to the I3C master message-mode DMA driver handle.
 * @param transfer Pointer to the message-mode transfer descriptor.
 * @retval #kStatus_Success The transfer was started successfully.
 * @retval #kStatus_I3C_Busy A transfer is already in progress on this handle, another
 *         master is currently utilizing the bus, or the DMA resource cannot accept a
 *         new transfer.
 * @retval #kStatus_InvalidArgument @c msgCount is 0, or any message @c dataSize is 0, odd,
 *         or greater than the cap for @c busType (#I3C_MSG_SDR_MAX_LEN for SDR/I2C,
 *         #I3C_MSG_DDR_MAX_LEN for HDR-DDR).
 */
status_t I3C_MasterMsgTransferDMA(I3C_Type *base,
                                  i3c_master_msg_dma_handle_t *handle,
                                  i3c_master_msg_transfer_t *transfer);

/*!
 * @brief Terminates a non-blocking I3C message-mode DMA transfer early.
 *
 * Stops the DMA data movement, disables the peripheral DMA requests, clears the
 * controller status / error flags, flushes both FIFOs and returns the handle to idle.
 *
 * @param base The I3C peripheral base address.
 * @param handle Pointer to the I3C master message-mode DMA driver handle.
 */
void I3C_MasterMsgTransferAbortDMA(I3C_Type *base, i3c_master_msg_dma_handle_t *handle);

/*!
 * @brief Reusable routine to handle master interrupts.
 *
 * @note This function does not need to be called unless you are reimplementing the
 *  nonblocking API's interrupt handler routines to add special functionality. The
 *  signature matches the driver's master interrupt handler type (i3c_master_isr_t).
 *
 * @param base The I3C peripheral base address.
 * @param i3cHandle Pointer to the I3C master message-mode DMA driver handle.
 */
void I3C_MasterMsgTransferDMAHandleIRQ(I3C_Type *base, void *i3cHandle);

/*! @} */

#if defined(__cplusplus)
}
#endif

/*! @} */

#endif /* FSL_I3C_MSG_DMA_H_ */
