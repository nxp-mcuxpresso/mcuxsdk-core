/*
 * Copyright 2026 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "fsl_i3c_msg_dma.h"

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/* Component ID definition, used by tools. */
#ifndef FSL_COMPONENT_ID
#define FSL_COMPONENT_ID "platform.drivers.i3c_msg_dma"
#endif

/*! @brief States for the message-mode transfer state machine. */
enum _i3c_msg_dma_transfer_states
{
    kIdleState = 0,    /*!< Bus idle; SlaveStart is monitored for an asynchronous IBI. */
    kSlaveStartState,  /*!< A target drove SlaveStart while idle; emit the AutoIBI accept. */
    kAutoIBIRespState, /*!< AutoIBI issued; wait for the ArbitrationWon confirming the accept. */
    kTransferState,    /*!< A message-mode transfer is in flight; wait COMPLETE or an IBI win. */
    kIBIWonState,      /*!< Accepted IBI; read its payload once COMPLETE arrives. */
    kStopState,        /*!< Transfer ended by an IBI win or an error; emit the STOP the END=1
                            message never ran, unless the bus is already idle. */
    kStopCtrlDoneState /*!< STOP issued; wait its ControlDone to release the bus. */
};

/*! @brief Common sets of flags used by the driver. */
enum _i3c_msg_dma_flags
{
    kMsgIrqFlags    = kI3C_MasterSlaveStartFlag | kI3C_MasterArbitrationWonFlag | kI3C_MasterErrorFlag |
                      kI3C_MasterSlave2MasterFlag | kI3C_MasterCompleteFlag | kI3C_MasterControlDoneFlag,
    kMsgIrqAllFlags = kI3C_MasterRxReadyFlag | kI3C_MasterTxReadyFlag | kI3C_MasterSlaveStartFlag |
                      kI3C_MasterArbitrationWonFlag | kI3C_MasterErrorFlag | kI3C_MasterSlave2MasterFlag |
                      kI3C_MasterCompleteFlag | kI3C_MasterControlDoneFlag,
};

/*******************************************************************************
 * Variables
 ******************************************************************************/

/*******************************************************************************
 * Prototypes
 ******************************************************************************/

/*******************************************************************************
 * Code
 ******************************************************************************/

/*!
 * brief Checks the message-mode error conditions and maps them to a status code.
 *
 * Run at the ISR's unified checkpoint before the per-state dispatch, so a master transfer
 * error ends whatever is in flight from one place. ArbitrationWon is not handled here: it
 * is not an error and its meaning is state-dependent (an accepted AutoIBI versus an IBI
 * that won a message header), so the state machine resolves it.
 *
 * param base The I3C peripheral base address.
 * retval #kStatus_Success No error condition is pending.
 * retval #kStatus_I3C_Nak The target NACKed the message address header.
 * retval #kStatus_I3C_MsgError Message SDR/DDR mismatch or read/write message in wrong state.
 * retval #kStatus_I3C_WriteAbort The target NACKed the write data.
 */
static status_t I3C_MasterMsgCheckError(I3C_Type *base, uint32_t status)
{
    status_t result    = kStatus_Success;
    uint32_t errStatus = I3C_MasterGetErrorStatusFlags(base);

    /* NACKED cannot be enabled as an interrupt, so it is never part of the pending snapshot:
       read it live and qualify it with the latched MERRWARN NACK flag (NACKED is a level
       flag reflecting the last header on the bus). */
    if ((0UL != (I3C_MasterGetStatusFlags(base) & (uint32_t)kI3C_MasterNackDetectFlag)) &&
        (0UL != (errStatus & (uint32_t)kI3C_MasterErrorNackFlag)))
    {
        I3C_MasterClearErrorStatusFlags(base, (uint32_t)kI3C_MasterErrorNackFlag);
        result = kStatus_I3C_Nak;
    }
    else if (0UL != (status & (uint32_t)kI3C_MasterErrorFlag))
    {
        result = I3C_MasterCheckAndClearError(base, errStatus);
        if ((kStatus_Success == result) && (0UL != errStatus))
        {
            /* Clear with the raw MERRWARN read-back: bits outside the core driver's
               error set otherwise stay pending and wedge the ISR. */
            I3C_MasterClearErrorStatusFlags(base, errStatus);
        }
    }
    else
    {
        /* No error condition pending. */
    }

    return result;
}

/*!
 * brief Checks a message-mode transfer descriptor.
 *
 * param transfer Pointer to the message-mode transfer descriptor.
 * retval #kStatus_Success The descriptor is valid.
 * retval #kStatus_InvalidArgument The descriptor failed one of the checks.
 */
static status_t I3C_MasterMsgCheck(const i3c_master_msg_transfer_t *transfer)
{
    assert(NULL != transfer);
    assert(NULL != transfer->msgList);

    status_t result = kStatus_Success;
    /* HDR-DDR carries more per message than SDR; the cap is direction-independent here. */
    size_t maxLen = (transfer->busType == kI3C_TypeI3CDdr) ? (size_t)I3C_MSG_DDR_MAX_LEN : (size_t)I3C_MSG_SDR_MAX_LEN;

    if (transfer->msgCount == 0UL)
    {
        result = kStatus_InvalidArgument;
    }
    else
    {
        for (size_t msgIdx = 0UL; msgIdx < transfer->msgCount; msgIdx++)
        {
            size_t dataSize = transfer->msgList[msgIdx].dataSize;

            assert(NULL != transfer->msgList[msgIdx].data);

            if ((dataSize == 0UL) || (dataSize > maxLen))
            {
                result = kStatus_InvalidArgument;
                break;
            }
            /* The message data ports are 16-bit and DMA moves halfwords (DDR data is
               halfword-native), so odd sizes - which would straddle the caller buffer
               boundary on the last halfword - are rejected. */
            if ((dataSize % 2UL) != 0UL)
            {
                result = kStatus_InvalidArgument;
                break;
            }
        }
    }

    return result;
}

/*!
 * brief Writes one message.
 *
 * SDR needs one MWMSG_SDR_CONTROL word. HDR-DDR needs two writes: the control word
 * (LEN in halfwords + END) followed by the address/command word issued as the first
 * data write. END makes the controller emit STOP (SDR) or the HDR exit (DDR).
 *
 * param base The I3C peripheral base address.
 * param msg Pointer to the message descriptor to issue.
 * param busType The bus type of the transfer, #kI3C_TypeI3CSdr, #kI3C_TypeI2C or #kI3C_TypeI3CDdr.
 * param end Pass true for the last message of the list, false to continue with a repeated START.
 */
static void I3C_MasterMsgWrite(I3C_Type *base, const i3c_master_msg_t *msg, i3c_bus_type_t busType, bool end)
{
    assert(NULL != msg);

    if (busType == kI3C_TypeI3CDdr)
    {
        uint32_t len = ((uint32_t)msg->dataSize / 2UL) + ((msg->direction == kI3C_Read) ? 2UL : 1UL);

        /* MWMSG_DDR_CONTROL, _CONTROL2 and _DATA all alias offset 0xD8, the write order
           selects the interpretation. Per RM the first control word is LEN + END and the
           second is the ADDRCMD. */
        base->MWMSG_DDR_CONTROL2 = I3C_MWMSG_DDR_CONTROL2_LEN(len) | I3C_MWMSG_DDR_CONTROL2_END(end ? 1UL : 0UL);
        base->MWMSG_DDR_CONTROL  = I3C_MWMSG_DDR_CONTROL_ADDRCMD(((uint32_t)msg->slaveAddress << 9UL) |
                                                                 ((msg->direction == kI3C_Read) ? (1UL << 7UL) : 0UL) |
                                                                 ((uint32_t)msg->command & 0x7FUL));
    }
    else
    {
        base->MWMSG_SDR_CONTROL = I3C_MWMSG_SDR_CONTROL_DIR((uint32_t)msg->direction) |
                                  I3C_MWMSG_SDR_CONTROL_ADDR((uint32_t)msg->slaveAddress) |
                                  I3C_MWMSG_SDR_CONTROL_LEN((uint32_t)msg->dataSize) |
                                  I3C_MWMSG_SDR_CONTROL_I2C((busType == kI3C_TypeI2C) ? 1UL : 0UL) |
                                  I3C_MWMSG_SDR_CONTROL_END(end ? 1UL : 0UL);
    }
}

/*!
 * brief Selects the port context servicing one message direction.
 *
 * param handle Pointer to the I3C master message-mode DMA driver handle.
 * param direction Direction of the message to service.
 * return The port context to use for the message.
 */
static i3c_port_dma_ctx_t *I3C_MasterMsgGetContext(i3c_master_msg_dma_handle_t *handle, i3c_direction_t direction)
{
    /* On devices where the I3C send and receive DMA requests are OR'd together no TX
       resource is registered, the RX context then services both directions. */
    if ((direction == kI3C_Write) && (NULL != handle->txDmaCtx.handle))
    {
        return &handle->txDmaCtx;
    }

    return &handle->rxDmaCtx;
}

/*!
 * @brief The current message's data movement is finished.
 *
 * @param userData Pointer to the I3C master message-mode DMA driver handle.
 */
static void I3C_MasterMsgDmaDoneCallback(void *userData)
{
    i3c_master_msg_dma_handle_t *handle = (i3c_master_msg_dma_handle_t *)userData;

    handle->dmaDone = true;
}

/*!
 * brief Issues one message.
 *
 * param base The I3C peripheral base address.
 * param handle Pointer to the I3C master message-mode DMA driver handle.
 * retval #kStatus_Success The message was issued.
 * retval #kStatus_I3C_Busy The port could not start the data movement.
 */
static status_t I3C_MasterMsgDmaPrepare(I3C_Type *base, i3c_master_msg_dma_handle_t *handle)
{
    assert(handle->msgIdx < handle->transfer.msgCount);
    assert(NULL != handle->transfer.msgList);

    const i3c_master_msg_t *msg = &handle->transfer.msgList[handle->msgIdx];
    i3c_port_dma_ctx_t *context = I3C_MasterMsgGetContext(handle, msg->direction);
    bool end                    = ((handle->msgIdx + 1UL) == handle->transfer.msgCount);
    bool ddr                    = (handle->transfer.busType == kI3C_TypeI3CDdr);
    size_t dataSize             = msg->dataSize;
    status_t result;
    uint32_t reg;

    handle->dmaDone = false;

    I3C_MasterMsgWrite(base, msg, handle->transfer.busType, end);

    if (msg->direction == kI3C_Write)
    {
        reg            = ddr ? (uint32_t)(uintptr_t)&base->MWMSG_DDR_DATA : (uint32_t)(uintptr_t)&base->MWMSG_SDR_DATA;
        base->MDMACTRL = I3C_MDMACTRL_DMAWIDTH(2UL) | I3C_MDMACTRL_DMATB(1UL);
        result         = I3C_PortDMAStart(context, kI3C_Write, reg, msg->data, dataSize);
    }
    else
    {
#if defined(FSL_FEATURE_I3C_HAS_ERRATA_052086) && (FSL_FEATURE_I3C_HAS_ERRATA_052086)
        /* ERRATA052086: SoC integration issue results in the last DMA request of a
           multi-request read getting missed. Resolution: shorten the data movement by
           one halfword; the ISR fetches the trailing halfword from the 16-bit message
           read port after the message completes. */
        if (dataSize > 2UL)
        {
            dataSize -= 2UL;
        }
#endif
        /* Halfword requests from the 16-bit message read port, armed for one bus frame. */
        reg            = ddr ? (uint32_t)(uintptr_t)&base->MRMSG_DDR : (uint32_t)(uintptr_t)&base->MRMSG_SDR;
        base->MDMACTRL = I3C_MDMACTRL_DMAWIDTH(2UL) | I3C_MDMACTRL_DMAFB(1UL);
        result         = I3C_PortDMAStart(context, kI3C_Read, reg, msg->data, dataSize);
    }

    if (kStatus_Success == result)
    {
        handle->dmaBytes = dataSize;
    }

    return result;
}

/*!
 * brief Create a new handle for the I3C master message-mode DMA APIs.
 *
 * param base The I3C peripheral base address.
 * param handle Pointer to the I3C master message-mode DMA driver handle.
 * param callback User provided pointer to the asynchronous callback structure.
 * param userData User provided pointer to the application callback data.
 * param rxDmaRes DMA resource for the receive direction.
 * param txDmaRes DMA resource for the transmit direction, NULL on devices with
 *        OR'd I3C DMA requests.
 */
void I3C_MasterMsgTransferCreateHandleDMA(I3C_Type *base,
                                          i3c_master_msg_dma_handle_t *handle,
                                          const i3c_master_msg_dma_callback_t *callback,
                                          void *userData,
                                          i3c_port_dma_handle_t *rxDmaHandle,
                                          i3c_port_dma_handle_t *txDmaHandle)
{
    uint32_t instance = I3C_GetInstance(base);

    assert(NULL != handle);
    assert(NULL != callback);
    assert(NULL != callback->transferComplete);
    assert(NULL != rxDmaHandle);

    (void)memset(handle, 0, sizeof(*handle));

    handle->base            = base;
    handle->callback        = *callback;
    handle->userData        = userData;
    handle->rxDmaCtx.handle = rxDmaHandle;
    handle->txDmaCtx.handle = txDmaHandle;

    s_i3cMasterHandle[instance] = handle;
    s_i3cMasterIsr              = I3C_MasterMsgTransferDMAHandleIRQ;
    I3C_PortDMASetCallback(&handle->rxDmaCtx, I3C_MasterMsgDmaDoneCallback, (void *)handle);

    /* Disable and clear legacy flags. */
    I3C_MasterDisableInterrupts(base, (uint32_t)kMsgIrqAllFlags);
    I3C_MasterClearErrorStatusFlags(base, I3C_MasterGetErrorStatusFlags(base));
    I3C_MasterClearStatusFlags(base, (uint32_t)kMsgIrqAllFlags);

    /* Reset FIFOs. These flags clear automatically. */
    base->MDATACTRL |= I3C_MDATACTRL_FLUSHTB_MASK | I3C_MDATACTRL_FLUSHFB_MASK;

    /* Enable IRQ. */
    (void)EnableIRQ(kI3cIrqs[instance]);
    I3C_MasterEnableInterrupts(base, (uint32_t)kMsgIrqFlags);
}

/*!
 * brief Performs a non-blocking SDR message-mode transfer using DMA.
 *
 * note The API returns right after the first message is issued; the callback
 * specified when the handle was created is invoked with the final status once the
 * last message completes or an error terminates the transfer.
 *
 * param base The I3C peripheral base address.
 * param handle Pointer to the I3C master message-mode DMA driver handle.
 * param transfer Pointer to the message-mode transfer descriptor.
 * retval #kStatus_Success The transfer was started successfully.
 * retval #kStatus_I3C_Busy A transfer is already in progress on this handle, another
 *        master is currently utilizing the bus, or the DMA resource cannot accept a
 *        new transfer.
 * retval #kStatus_InvalidArgument The transfer descriptor failed validation.
 */
status_t I3C_MasterMsgTransferDMA(I3C_Type *base,
                                  i3c_master_msg_dma_handle_t *handle,
                                  i3c_master_msg_transfer_t *transfer)
{
    assert(NULL != handle);
    assert(NULL != transfer);
    assert(NULL != transfer->msgList);

    i3c_master_state_t masterState = I3C_MasterGetState(base);
    status_t result;

    /* Check if bus is already in use. */
    if ((masterState != kI3C_MasterStateIdle) && (masterState != kI3C_MasterStateNormAct))
    {
        return kStatus_I3C_Busy;
    }

    /* Disable IRQ while the transfer is being set up. */
    I3C_MasterDisableInterrupts(
        base, (uint32_t)kMsgIrqFlags | (uint32_t)kI3C_MasterRxReadyFlag | (uint32_t)kI3C_MasterTxReadyFlag);

    result = I3C_MasterMsgCheck(transfer);
    if (kStatus_Success != result)
    {
        return result;
    }

    /* Return busy if another transaction is in progress. */
    if (handle->state != (uint8_t)kIdleState)
    {
        return kStatus_I3C_Busy;
    }

    handle->state    = (uint8_t)kTransferState;
    handle->transfer = *transfer;
    handle->msgIdx   = 0UL;
    handle->dmaBytes = 0UL;
    base->MCTRL &= ~I3C_MCTRL_IBIRESP_MASK;
    base->MCTRL |= I3C_MCTRL_IBIRESP(transfer->ibiResponse);
    I3C_MasterClearErrorStatusFlags(base, I3C_MasterGetErrorStatusFlags(base));
    I3C_MasterClearStatusFlags(base, (uint32_t)kI3C_MasterClearFlags);
    I3C_MasterSetWatermarks(handle->base, kI3C_TxTriggerUntilOneHalfOrLess, kI3C_RxTriggerUntilOneQuarterOrMore, true,
                            true);
    result = I3C_MasterMsgDmaPrepare(base, handle);
    I3C_MasterEnableInterrupts(base, (uint32_t)kMsgIrqFlags);

    return result;
}

/*!
 * brief Terminates a non-blocking I3C message-mode DMA transfer early.
 *
 * Stops the DMA data movement, disables the message-mode interrupt sources, clears the
 * controller status / error flags, flushes both FIFOs and returns the handle to idle.
 *
 * param base The I3C peripheral base address.
 * param handle Pointer to the I3C master message-mode DMA driver handle.
 */
void I3C_MasterMsgTransferAbortDMA(I3C_Type *base, i3c_master_msg_dma_handle_t *handle)
{
    assert(NULL != handle);

    if (handle->state == (uint8_t)kIdleState)
    {
        return;
    }

    I3C_MasterDisableInterrupts(base, (uint32_t)kMsgIrqFlags);
    I3C_PortDMAAbort(&handle->rxDmaCtx, &handle->txDmaCtx);
    base->MDMACTRL &= ~(I3C_MDMACTRL_DMAFB_MASK | I3C_MDMACTRL_DMATB_MASK);
    I3C_MasterClearErrorStatusFlags(base, I3C_MasterGetErrorStatusFlags(base));
    I3C_MasterClearStatusFlags(base, (uint32_t)kI3C_MasterClearFlags);
    base->MDATACTRL |= I3C_MDATACTRL_FLUSHTB_MASK | I3C_MDATACTRL_FLUSHFB_MASK;
    handle->state = (uint8_t)kIdleState;
}

/*!
 * brief Reads the IBI payload from the from-bus FIFO into the caller's ibiBuff.
 *
 * Requests a buffer through the ibiCallback when none is registered yet, then drains the
 * FIFO byte by byte (bytes are dropped when no buffer is provided). Records the IBI type
 * and address. The caller sets ibiPayloadSize to 0 before the first read of a payload.
 */
static void I3C_MasterMsgReadIBIPayload(I3C_Type *base, i3c_master_msg_dma_handle_t *handle)
{
    size_t rxCount = (base->MDATACTRL & I3C_MDATACTRL_RXCOUNT_MASK) >> I3C_MDATACTRL_RXCOUNT_SHIFT;

    if ((rxCount != 0UL) && (handle->ibiBuff == NULL) && (handle->callback.ibiCallback != NULL))
    {
        handle->callback.ibiCallback(base, handle, kI3C_IbiNormal, kI3C_IbiDataBuffNeed);
    }
    while (rxCount-- != 0UL)
    {
        uint8_t byte = (uint8_t)(base->MRDATAB & 0xFFUL);
        if (handle->ibiBuff != NULL)
        {
            handle->ibiBuff[handle->ibiPayloadSize++] = byte;
        }
    }

    handle->ibiType    = I3C_GetIBIType(base);
    handle->ibiAddress = I3C_GetIBIAddress(base);
}

/*!
 * brief Reads the accepted IBI's payload on COMPLETE.
 *
 * On error the in-flight IBI is dropped and the block returns to idle silently (no
 * callback). When the controller is still holding the bus after the payload a STOP is
 * emitted and the state machine hands off to kStopState to finish on its CTRLDONE. The
 * IBI teardown itself (flush, callback, back to idle) is done by the unified completion
 * tail once this returns true.
 *
 * return true when the IBI payload is ready for the completion tail, false when there is
 *        nothing to finish yet.
 */
static bool I3C_MasterMsgServiceIBI(I3C_Type *base, i3c_master_msg_dma_handle_t *handle, uint32_t status)
{
    if (0UL != (status & (uint32_t)kI3C_MasterCompleteFlag))
    {
        I3C_MasterMsgReadIBIPayload(base, handle);
        return true;
    }

    return false;
}

/*!
 * brief Drains a completed read message from the port into the caller buffer.
 *
 * COMPLETE means the last message byte arrived in the from-bus FIFO; wait until the port
 * drained its share into memory before touching the channel and the FIFOs. Waiting only
 * helps while DMAFB still generates requests - the one-frame arming drops it at frame end,
 * stranding bytes that lost the final request race, which are then fetched through the
 * 16-bit message read port. If the target delivered fewer bytes than requested the FIFO
 * runs empty with the movement unfinished (ERR052343) and the loop exits; the caller's
 * port abort releases the channel.
 *
 * param base The I3C peripheral base address.
 * param handle Pointer to the I3C master message-mode DMA driver handle.
 * param msg The read message that just completed.
 */
static void I3C_MasterMsgReadDrain(I3C_Type *base, i3c_master_msg_dma_handle_t *handle, const i3c_master_msg_t *msg)
{
    assert(NULL != msg->data);

    i3c_port_dma_ctx_t *context = &handle->rxDmaCtx;
    bool ddr                    = (handle->transfer.busType == kI3C_TypeI3CDdr);
    size_t transBytes;
    size_t rxCount;

    do
    {
        transBytes = I3C_PortDMAGetTransBytes(context);
        I3C_MasterGetFifoCounts(base, &rxCount, NULL);
        if (handle->dmaDone || (transBytes >= handle->dmaBytes))
        {
            transBytes = handle->dmaBytes;
            break;
        }
        if (0UL == (base->MDMACTRL & I3C_MDMACTRL_DMAFB_MASK))
        {
            break;
        }
#if defined(FSL_FEATURE_I3C_HAS_ERRATA_052086) && (FSL_FEATURE_I3C_HAS_ERRATA_052086)
    } while (rxCount > 2UL);
#else
    } while (rxCount > 0UL);
#endif

    /* Fetch the stranded bytes through the 16-bit message read port. */
    while ((transBytes < handle->dmaBytes) && (rxCount >= 2UL))
    {
        uint8_t *buffer = (uint8_t *)msg->data;
        uint32_t rxData = (ddr ? base->MRMSG_DDR : base->MRMSG_SDR) & I3C_MRMSG_SDR_DATA_MASK;

        buffer[transBytes]       = (uint8_t)(rxData & 0xFFUL);
        buffer[transBytes + 1UL] = (uint8_t)((rxData >> 8UL) & 0xFFUL);
        transBytes += 2UL;
        I3C_MasterGetFifoCounts(base, &rxCount, NULL);
    }

#if defined(FSL_FEATURE_I3C_HAS_ERRATA_052086) && (FSL_FEATURE_I3C_HAS_ERRATA_052086)
    /* ERRATA052086: the data movement was shortened by one halfword, fetch the
       trailing halfword from the 16-bit message read port with the CPU. */
    if ((msg->dataSize > 2UL) && (rxCount > 0UL))
    {
        uint8_t *buffer  = (uint8_t *)msg->data;
        uint32_t rxData  = (ddr ? base->MRMSG_DDR : base->MRMSG_SDR) & I3C_MRMSG_SDR_DATA_MASK;
        size_t endOffset = msg->dataSize - (handle->dmaBytes - transBytes);

        /* Unpack the halfword little-endian, matching the port's memory order. */
        buffer[endOffset - 2UL] = (uint8_t)(rxData & 0xFFUL);
        buffer[endOffset - 1UL] = (uint8_t)((rxData >> 8UL) & 0xFFUL);
    }
#endif
}

/*!
 * brief Advances the transfer state on one master interrupt.
 *
 * An error or an IBI arbitration win ends the transfer; otherwise COMPLETE drains the
 * finished message and either issues the next one or reports the transfer done. No teardown
 * is performed here - the terminal event is returned for the unified completion tail.
 *
 * param base The I3C peripheral base address.
 * param handle Pointer to the I3C master message-mode DMA driver handle.
 * param status The acknowledged interrupt snapshot for this pass.
 * return true when the transfer finished/failed (result stashed in handle->result),
 *        false to wait for the next interrupt.
 */
static bool I3C_MasterMsgAdvanceTransfer(I3C_Type *base, i3c_master_msg_dma_handle_t *handle, uint32_t status)
{
    assert(handle->msgIdx < handle->transfer.msgCount);
    assert(NULL != handle->transfer.msgList);

    const i3c_master_msg_t *msg;
    status_t result;

    if (0UL != (status & (uint32_t)kI3C_MasterArbitrationWonFlag))
    {
        base->MDMACTRL &= ~(I3C_MDMACTRL_DMAFB_MASK | I3C_MDMACTRL_DMATB_MASK);
        I3C_MasterMsgReadIBIPayload(base, handle);
        handle->result = kStatus_I3C_IBIWon;
        return true;
    }

    /* Errors are resolved at the ISR's unified checkpoint; wait for COMPLETE to advance. */
    if (0UL == (status & (uint32_t)kI3C_MasterCompleteFlag))
    {
        return false;
    }

    msg = &handle->transfer.msgList[handle->msgIdx];

    if (msg->direction == kI3C_Read)
    {
        I3C_MasterMsgReadDrain(base, handle, msg);
    }

    /* Make the channels reusable for the next message; safe when the movement already
       finished on its own, and the unused direction is skipped inside the abort. */
    I3C_PortDMAAbort(&handle->rxDmaCtx, &handle->txDmaCtx);

    handle->msgIdx++;
    if (handle->msgIdx < handle->transfer.msgCount)
    {
        result = I3C_MasterMsgDmaPrepare(base, handle);
        if (kStatus_Success != result)
        {
            handle->result = result;
            return true;
        }
        /* Next message issued; wait for its COMPLETE. */
        return false;
    }

    /* The END=1 message completed. */
    handle->result = kStatus_Success;

    return true;
}

/*!
 * brief Routine to handle master interrupts.
 *
 * Acknowledges the interrupt snapshot, then runs one pass of the message-mode state machine
 * as a pure dispatcher: it only reads the acknowledged flags and jumps between states, the
 * interrupt sources are gated exclusively at the coarse transfer boundaries (create / start /
 * teardown / abort). Both terminal kinds funnel through a single tail - a finished or failed
 * transfer settles the bus and reports via transferComplete, a ready IBI reports via
 * ibiCallback. The long per-state logic lives in static helpers.
 *
 * param base The I3C peripheral base address.
 * param i3cHandle Pointer to the I3C master message mode DMA driver handle.
 */
void I3C_MasterMsgTransferDMAHandleIRQ(I3C_Type *base, void *i3cHandle)
{
    i3c_master_msg_dma_handle_t *handle = (i3c_master_msg_dma_handle_t *)i3cHandle;
    bool stateDone                      = false;
    bool transDone                      = false;
    uint32_t status;
    status_t result;

    if (NULL == handle)
    {
        return;
    }

    status = I3C_MasterGetPendingInterrupts(base);

    /* Interrupt delay workaround: In MCTRL.TYPE = 0 (I3C) mode, SLVSTART only sets once by SDA low.
       When bus isn't idle, must ignore SLVSTART to ensure final STOP CTRLDONE can be handled then
       handle SLVSTART. Meanwhile can't clear register's SLVSTART cause it will not set back by SDA low. */
    if ((handle->state != (uint8_t)kIdleState) && (0UL != (status & (uint32_t)kI3C_MasterSlaveStartFlag)))
    {
        I3C_MasterClearStatusFlags(base, (uint32_t)kI3C_MasterSlaveStartFlag);
        status &= ~(uint32_t)kI3C_MasterSlaveStartFlag;
    }
    I3C_MasterClearStatusFlags(base, status);

    if (0UL != (status & (uint32_t)kI3C_MasterSlave2MasterFlag))
    {
        if (handle->callback.slave2Master != NULL)
        {
            handle->callback.slave2Master(base, handle->userData);
        }
    }

    if ((handle->state == (uint8_t)kIdleState) && (NULL != handle->callback.ibiCallback) &&
        (0UL != (status & (uint32_t)kI3C_MasterSlaveStartFlag)) && (I3C_MasterGetState(base) == kI3C_MasterStateSlvReq))
    {
        handle->state = (uint8_t)kSlaveStartState;
    }

    result = I3C_MasterMsgCheckError(base, status);
    if (kStatus_Success != result)
    {
        handle->state  = (uint8_t)kStopState;
        handle->result = result;
    }

    if (handle->state == (uint8_t)kIdleState)
    {
        return;
    }

    while (!stateDone)
    {
        switch (handle->state)
        {
            case (uint8_t)kSlaveStartState:
                base->MCTRL =
                    (base->MCTRL & ~I3C_MCTRL_IBIRESP_MASK) | I3C_MCTRL_IBIRESP((uint32_t)kI3C_IbiRespAckMandatory);
                I3C_MasterEmitRequest(base, kI3C_RequestAutoIbi);
                handle->state = (uint8_t)kAutoIBIRespState;
                stateDone     = true;
                break;

            case (uint8_t)kAutoIBIRespState:
                if (0UL != (status & (uint32_t)kI3C_MasterArbitrationWonFlag))
                {
                    handle->state = (uint8_t)kIBIWonState;
                }
                else
                {
                    /* Handle non-existent IBI requests caused by signal glitch. */
                    handle->state = (uint8_t)kIdleState;
                    stateDone     = true;
                }
                break;

            case (uint8_t)kIBIWonState:
                if (I3C_MasterMsgServiceIBI(base, handle, status))
                {
                    handle->result = kStatus_I3C_IBIWon;
                    handle->state  = (uint8_t)kStopState;
                }
                else
                {
                    stateDone = true;
                }
                break;

            case (uint8_t)kStopState:
            {
                i3c_master_state_t masterState = I3C_MasterGetState(base);

                if (masterState != kI3C_MasterStateIdle)
                {
                    I3C_MasterEmitRequest(
                        base, (masterState == kI3C_MasterStateDdr) ? kI3C_RequestForceExit : kI3C_RequestEmitStop);
                    handle->state = (uint8_t)kStopCtrlDoneState;
                }
                else
                {
                    transDone = true;
                }
                stateDone = true;
                break;
            }

            case (uint8_t)kStopCtrlDoneState:
                if (0UL != (status & (uint32_t)kI3C_MasterControlDoneFlag))
                {
                    transDone = true;
                }
                stateDone = true;
                break;

            case (uint8_t)kTransferState:
                transDone = I3C_MasterMsgAdvanceTransfer(base, handle, status);
                stateDone = true;
                break;

            default:
                /* Should not get here. */
                assert(false);
                break;
        }
    }

    if (transDone)
    {
        I3C_MasterEnableDMA(base, false, false, 0);
        base->MDATACTRL |= I3C_MDATACTRL_FLUSHTB_MASK | I3C_MDATACTRL_FLUSHFB_MASK;
        handle->state = (uint8_t)kIdleState;

        if ((handle->result == kStatus_I3C_IBIWon) && (handle->callback.ibiCallback != NULL))
        {
            handle->callback.ibiCallback(base, handle, handle->ibiType, kI3C_IbiReady);
            handle->ibiPayloadSize = 0;
        }

        if (NULL != handle->callback.transferComplete)
        {
            handle->callback.transferComplete(base, handle, handle->result, handle->userData);
        }
        I3C_PortDMAAbort(&handle->rxDmaCtx, &handle->txDmaCtx);
        handle->result = kStatus_Success;
    }
}
