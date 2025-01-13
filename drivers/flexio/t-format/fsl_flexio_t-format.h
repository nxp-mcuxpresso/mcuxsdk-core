/*
 * Copyright 2025 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef _FSL_T_FORMAT_H_
#define _FSL_T_FORMAT_H_

#include "fsl_common.h"
#include "fsl_edma.h"
#include "fsl_flexio.h"

/*!
 * @addtogroup flexio_t_format
 * @{
 */

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/*! @name Driver version */
/*@{*/
/*! @brief FlexIO T_Format driver version. */
#define FSL_FLEXIO_T_FORMAT_DRIVER_VERSION (MAKE_VERSION(1, 0, 0))
/*@}*/

/*! @brief Retry times for waiting flag. */
#ifndef T_FORMAT_RETRY_TIMES
#define T_FORMAT_RETRY_TIMES 0U /* Defining to zero means to keep waiting for the flag until it is assert/deassert. */
#endif

/*! @brief Maximum number of encoders on an T-format bus. */
#define T_FORMAT_ENCODER_MAX_NUM 1U
/*! @brief The number of bits per frame without start and stop bits. */
#define T_FORMAT_BITS_PER_FRAME_DATA 8U
/*! @brief The number of bits per frame with start and stop bits. */
#define T_FORMAT_BITS_PER_FRAME_WHOLE (T_FORMAT_BITS_PER_FRAME_DATA + 2U)
/*! @brief Calculate the value of the FlexIO timer compare register. */
#define T_FORMAT_TIMER_COMPARE_VALUE(cmp) (((T_FORMAT_BITS_PER_FRAME_DATA * 2U - 1U) << 8U) | cmp)

/*! @name T-format protocol */
/*@{*/
/*! @brief The Sink code of the control field of T-format */
#define T_FORMAT_SINK_CODE_CF 2U

/*! @brief The mask of the CF sink code */
#define T_FORMAT_CF_MASK_SINK_CODE    0x07U
/*! @brief The mask of the CF data ID code */
#define T_FORMAT_CF_MASK_DATA_ID_CODE 0x78U
/*! @brief The mask of the CF ID parity */
#define T_FORMAT_CF_MASK_ID_PARITY    0x80U

/*! @brief Data ID code for the control field */
#define T_FORMAT_CF_DATA_ID_CODE(x)   (((uint8_t)(x) << 3) & T_FORMAT_CF_MASK_DATA_ID_CODE)
/*! @brief ID parity for the control field */
#define T_FORMAT_CF_ID_PARITY(x)      (((uint8_t)(x) << 7) & T_FORMAT_CF_MASK_ID_PARITY)

/*! @brief The DATA ID Code of the T-format */
#define T_FORMAT_DATA_ID(code, parity) \
        (T_FORMAT_CF_DATA_ID_CODE(code) |\
         T_FORMAT_CF_ID_PARITY(parity))

/*! @brief The control field of T-format */
#define T_FORMAT_CF(DataID)  \
        (T_FORMAT_SINK_CODE_CF | DataID)

/*! @brief List of the control field value */
#define T_FORMAT_CF_GET_ABS         T_FORMAT_CF(T_FORMAT_DATA_ID(0x0, 0))
#define T_FORMAT_CF_GET_ABM         T_FORMAT_CF(T_FORMAT_DATA_ID(0x1, 1))
#define T_FORMAT_CF_GET_ENCID       T_FORMAT_CF(T_FORMAT_DATA_ID(0x2, 1))
#define T_FORMAT_CF_GET_ALL         T_FORMAT_CF(T_FORMAT_DATA_ID(0x3, 0))
#define T_FORMAT_CF_RESET_ALL_ERROR T_FORMAT_CF(T_FORMAT_DATA_ID(0x7, 1))
#define T_FORMAT_CF_RESET_ABS       T_FORMAT_CF(T_FORMAT_DATA_ID(0x8, 1))
#define T_FORMAT_CF_RESET_ABM_ERROR T_FORMAT_CF(T_FORMAT_DATA_ID(0xC, 0))
#define T_FORMAT_CF_EEPROM_WRITE    T_FORMAT_CF(T_FORMAT_DATA_ID(0x6, 0))
#define T_FORMAT_CF_EEPROM_READOUT  T_FORMAT_CF(T_FORMAT_DATA_ID(0xD, 1))

/*! @brief The mask bit of ALMC(Encoder error) */
#define T_FORMAT_ALMC_MASK_OVER_SPEED           ((uint8_t)(1 << 0))
#define T_FORMAT_ALMC_MASK_FULL_ABSOLUTE_STATUS ((uint8_t)(1 << 1))
#define T_FORMAT_ALMC_MASK_COUNTING_ERROR       ((uint8_t)(1 << 2))
#define T_FORMAT_ALMC_MASK_COUNTER_OVERFLOW     ((uint8_t)(1 << 3))
#define T_FORMAT_ALMC_MASK_OVERHEAT             ((uint8_t)(1 << 4))
#define T_FORMAT_ALMC_MASK_MULTITURN_ERROR      ((uint8_t)(1 << 5))
#define T_FORMAT_ALMC_MASK_BATTERY_ERROR        ((uint8_t)(1 << 6))
#define T_FORMAT_ALMC_MASK_BATTERY_ALARM        ((uint8_t)(1 << 7))

/*! @brief The mask of the SF encoder error */
#define T_FORMAT_SF_MASK_ENCODER_ERROR       0x30U
/*! @brief The mask of the SF communication alarm */
#define T_FORMAT_SF_MASK_COMMUNICATION_ALARM 0xC0U

/*! @brief Get the SF encoder error */
#define T_FORMAT_SF_GET_ENCODER_ERROR(x)       (((x) & T_FORMAT_SF_MASK_ENCODER_ERROR) >> 4)
/*! @brief Get the SF communication alarm */
#define T_FORMAT_SF_GET_COMMUNICATION_ALARM(x) (((x) & T_FORMAT_SF_MASK_COMMUNICATION_ALARM) >> 6)

/*! @brief The mask of the ADF address */
#define T_FORMAT_ADF_MASK_ADDRESS    0x7FU
/*! @brief The mask of the ADF busy status */
#define T_FORMAT_SF_MASK_BUSY_STATUS 0x80U

/*! @brief The CRC polynomial */
#define T_FORMAT_CRC_POLYNOMIAL 0x01U

/*! @brief The number of the byte in the received data */
#define T_FORMAT_ABS_BYTE        6U
#define T_FORMAT_ABM_BYTE        6U
#define T_FORMAT_ENCODER_ID_BYTE 4U
#define T_FORMAT_ALL_INFO_BYTE   11U
#define T_FORMAT_EEPROM_BYTE     4U

/*! @brief Do not cause Over-heat */
#define T_FORMAT_OVER_HEAT_NOT_CAUSE 0U
#define T_FORMAT_OVER_HEAT_TEMPERATURE(x) (0x80U | (x))
/*@}*/

#define T_FORMAT_TIMER_TX_INDEX       0
//#define T_FORMAT_TIMER_TX_CLOCK_INDEX 1
#define T_FORMAT_TIMER_RX_INDEX       1
//#define T_FORMAT_TIMER_RX_CLOCK_INDEX 3
#define T_FORMAT_TIMER_DR_INDEX       2

/*! @brief Error codes for the T_Format driver. */
enum
{
    kStatus_FLEXIO_T_FORMAT_EncErr0_CountingErr  = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 0), /*!< Transmitter is busy. */
    kStatus_FLEXIO_T_FORMAT_EncErr1_LogicOR      = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 1), /*!< Encoder error: Logic-OR of Over-heat, Multi-turn error, Battery error and Battery alarm. */
    kStatus_FLEXIO_T_FORMAT_ComAlr0_ParityErr    = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 2), /*!< Communication alarm: Parity error. */
    kStatus_FLEXIO_T_FORMAT_ComAlr1_DelimiterErr = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 3), /*!< Communication alarm: Delimiter error. */

    kStatus_FLEXIO_T_FORMAT_EncErr_OS = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 4),  /*!< Over speed. */
    kStatus_FLEXIO_T_FORMAT_EncErr_FS = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 5),  /*!< Full absolute status. */
    kStatus_FLEXIO_T_FORMAT_EncErr_CE = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 6),  /*!< Countering error. */
    kStatus_FLEXIO_T_FORMAT_EncErr_OF = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 7),  /*!< Countering overflow. */
    kStatus_FLEXIO_T_FORMAT_EncErr_OH = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 8),  /*!< Over heat. */
    kStatus_FLEXIO_T_FORMAT_EncErr_ME = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 9),  /*!< Multi-turn error. */
    kStatus_FLEXIO_T_FORMAT_EncErr_BE = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 10), /*!< Battery error. */
    kStatus_FLEXIO_T_FORMAT_EncErr_BA = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 11), /*!< Battery alarm. */

    kStatus_FLEXIO_T_FORMAT_FrameErr  = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 12), /*!< Frame format error. */
    kStatus_FLEXIO_T_FORMAT_BaudrateNotSupport = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 13),
    kStatus_FLEXIO_T_FORMAT_Timeout   = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 14), /*!< T_FORMAT times out. */
    kStatus_FLEXIO_T_FORMAT_TxBusy    = MAKE_STATUS(kStatusGroup_FLEXIO_A_FORMAT, 15), /*!< Transmitter is busy. */
    kStatus_FLEXIO_T_FORMAT_RxBusy    = MAKE_STATUS(kStatusGroup_FLEXIO_A_FORMAT, 16), /*!< Receiver is busy. */
    kStatus_FLEXIO_T_FORMAT_TxIdle    = MAKE_STATUS(kStatusGroup_FLEXIO_A_FORMAT, 17), /*!< Transmitter is idle. */
    kStatus_FLEXIO_T_FORMAT_RxIdle    = MAKE_STATUS(kStatusGroup_FLEXIO_A_FORMAT, 18), /*!< Receiver is idle. */
    kStatus_FLEXIO_T_FORMAT_RxRingBufferOverrun =
        MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 19), /*!< A-format RX software ring buffer overrun. */
    kStatus_FLEXIO_T_FORMAT_RxHardwareOverrun  = MAKE_STATUS(kStatusGroup_FLEXIO_T_FORMAT, 20), /*!< A-format RX receiver overrun. */
};

/*! @brief Define FlexIO T-format interrupt mask. */
enum _flexio_t_format_interrupt_enable
{
    kFLEXIO_T_FORMAT_TxDataRegEmptyInterruptEnable = 0x1U, /*!< Transmit buffer empty interrupt enable. */
    kFLEXIO_T_FORMAT_RxDataRegFullInterruptEnable  = 0x2U, /*!< Receive buffer full interrupt enable. */
};

enum _flexio_t_format_flags
{
    kFLEXIO_T_Format_TxDataRegEmptyFlag = 1U, /*!< Transmit buffer empty flag. */
    kFLEXIO_T_Format_RxDataRegFullFlag  = 2U, /*!< Receive buffer full flag. */
    kFLEXIO_T_Format_RxOverRunFlag      = 4U, /*!< Receive buffer over run flag. */
};

/*! @brief FlexIO T_FORMAT user modes. */
typedef enum _flexio_t_format_user_modes
{
    kFLEXIO_T_FORMAT_USERMODE_ONESHOT  = 0U, /*!< User mode is oneshot */
    kFLEXIO_T_FORMAT_USERMODE_SYNC     = 1U, /*!< User mode is sync */
} flexio_t_format_user_modes_t;

/*! @brief Reset request type of T-format. */
typedef enum _reset_types
{
    T_FORMAT_RESET_ALL_ERROR = T_FORMAT_CF_RESET_ALL_ERROR,  /*!< Reset all errors. */
    T_FORMAT_RESET_ABS       = T_FORMAT_CF_RESET_ABS,  /*!< Reset one revolution data. */
    T_FORMAT_RESET_ABM_ERROR = T_FORMAT_CF_RESET_ABM_ERROR /*!< Reset multi-turn data and all errors. */
} Reset_Type_e;

/* Forward declaration of the handle typedef. */
typedef struct _flexio_t_format_handle flexio_t_format_handle_t;

/*! @brief Define FlexIO T_FORMAT access structure typedef. */
typedef struct _flexio_t_format_type
{
    FLEXIO_Type *flexioBase; /*!< FlexIO base pointer. */
    edma_handle_t rxEdmaHandle;
    flexio_t_format_handle_t *hanlde;
    uint16_t timerDiv;       /*!< srcClock_Hz / baudRate_bps */
    uint16_t TxDR_Offset;    /*!< The offset between Tx and DR pins */
    uint16_t interval;       /*!< Interval between frames */
    uint8_t TxPinIndex;      /*!< Pin select for T_FORMAT_Tx. */
    uint8_t RxPinIndex;      /*!< Pin select for T_FORMAT_Rx. */
    uint8_t DRPinIndex;      /*!< Pin select for T_FORMAT_DR. */
    uint8_t shifterIndex[2]; /*!< Shifter index used in FlexIO T_FORMAT. */
    uint8_t timerIndex[3];   /*!< Timer index used in FlexIO T_FORMAT. */
    uint8_t triggerIn;       /*!< Trigger signal for sync mode. */
} FLEXIO_T_FORMAT_Type;

/*! @brief Define FlexIO T_FORMAT user configuration structure. */
typedef struct _flexio_t_format_config
{
    bool enableT_Format;                              /*!< Enable/disable FlexIO T_FORMAT TX & RX. */
    bool enableInDoze;                                /*!< Enable/disable FlexIO operation in doze mode*/
    bool enableInDebug;                               /*!< Enable/disable FlexIO operation in debug mode*/
    bool enableFastAccess;                            /*!< Enable/disable fast access to FlexIO registers,
                                                       fast access requires the FlexIO clock to be at least
                                                       twice the frequency of the bus clock. */
//    flexio_t_format_baud_rate_bps_t baudRate_bps;     /*!< Baud rate in bps. */
    uint8_t userMode;
} flexio_t_format_config_t;

/*! @brief Define FlexIO T-format transfer structure. */
typedef struct _flexio_t_format_transfer
{
    /*
     * Use separate TX and RX data pointer, because TX data is const data.
     * The member data is kept for backward compatibility.
     */
    union
    {
        uint8_t *data;         /*!< The buffer of data to be transfer.*/
        uint8_t *rxData;       /*!< The buffer to receive data. */
        const uint8_t *txData; /*!< The buffer of data to be sent. */
    };
    size_t dataSize; /*!< Transfer size*/
} flexio_t_format_transfer_t;

/*! @brief FlexIO T-format transfer callback function. */
typedef void (*flexio_t_format_transfer_callback_t)(FLEXIO_T_FORMAT_Type *base,
                                                    flexio_t_format_handle_t *handle,
                                                    status_t status,
                                                    void *userData);

/*! @brief Define FLEXIO T-format handle structure*/
struct _flexio_t_format_handle
{
    const uint8_t *volatile txData; /*!< Address of remaining data to send. */
    volatile size_t txDataSize;      /*!< Size of the remaining data to send. */
    uint8_t *volatile rxData;       /*!< Address of remaining data to receive. */
    volatile size_t rxDataSize;      /*!< Size of the remaining data to receive. */
    size_t txDataSizeAll;            /*!< Total bytes to be sent. */
    size_t rxDataSizeAll;            /*!< Total bytes to be received. */

    uint8_t *rxRingBuffer;             /*!< Start address of the receiver ring buffer. */
    size_t rxRingBufferSize;            /*!< Size of the ring buffer. */
    volatile uint16_t rxRingBufferHead; /*!< Index for the driver to store received data into ring buffer. */
    volatile uint16_t rxRingBufferTail; /*!< Index for the user to get data from the ring buffer. */

    flexio_t_format_transfer_callback_t callback; /*!< Callback function. */
    void *userData;                               /*!< A-format callback function parameter.*/

    volatile uint8_t txState; /*!< TX transfer state. */
    volatile uint8_t rxState; /*!< RX transfer state */
};

/*! @brief T-format encoder structure. */
typedef struct _encoder_T_format
{
    uint8_t singleTurnRevolution; /*!< The number of bits for single turn revolution. */
    uint8_t multiTunrRevolution; /*!< The number of bits for multiple turn revolution. */
    uint32_t single_turn_sign_mask;
    uint32_t single_turn_sign_extend_mask;
    uint32_t multi_turn_sign_mask;
    uint32_t multi_turn_sign_extend_mask;
//    uint32_t baudRate; /*!< Baudrate for communication. */
    void *controller;
} encoder_T_format;

/*! @brief All the information of the T-format encoder. */
typedef struct _encoder_all_info
{
    uint32_t singleTurn;
    uint32_t multiTurn;
    uint8_t encID;
    uint8_t ALMC;
} encoder_all_info_t;

/*! @brief T-format encoder EEPROM data structure. */
typedef struct _encoder_access_eeprom
{
    uint8_t page;
    uint8_t address;
    uint8_t data;
} encoder_access_eeprom_t;

/*! @brief T-format encoder request data structure. */
typedef struct _encoder_req_eeprom_read
{
    uint8_t cf;
    uint8_t adf;
    uint8_t crc;
} encoder_req_eeprom_read_t;

typedef struct _encoder_req_eeprom_write
{
    uint8_t cf;
    uint8_t adf;
    uint8_t edf;
    uint8_t crc;
} encoder_req_eeprom_write_t;

/*! @brief T-format encoder response data structure. */
typedef struct _encoder_res_data
{
    uint8_t CF;
    uint8_t SF;
    union {
        uint8_t ABS[3];
        uint8_t ABM[3];
    };
    uint8_t CRC;
} encoder_res_data_t;

typedef struct _encoder_res_id
{
    uint8_t CF;
    uint8_t SF;
    uint8_t ENCID;
    uint8_t CRC;
} encoder_res_id_t;

typedef struct _encoder_res_all_info
{
    uint8_t CF;
    uint8_t SF;
    uint8_t ABS[3];
    uint8_t ENCID;
    uint8_t ABM[3];
    uint8_t ALMC;
    uint8_t CRC;
} encoder_res_all_info_t;

typedef struct _encoder_res_eeprom
{
    uint8_t CF;
    uint8_t ADF;
    uint8_t EDF;
    uint8_t CRC;
} encoder_res_eeprom_t;

/*******************************************************************************
 * APIs
 ******************************************************************************/
#if defined(__cplusplus)
extern "C" {
#endif /* __cplusplus */

/*!
 * @brief Gets the FlexIO T-Format receive data register address.
 *
 * This function returns the T-Format data register address, which is mainly used by DMA/eDMA.
 *
 * @param base Pointer to the FLEXIO_T_FORMAT_Type structure.
 * @return FlexIO T-Format receive data register address.
 */
static inline uint32_t FLEXIO_T_Format_GetRxDataRegisterAddress(FLEXIO_T_FORMAT_Type *base)
{
    return FLEXIO_GetShifterBufferAddress(base->flexioBase, kFLEXIO_ShifterBufferByteSwapped, base->shifterIndex[1]);
}

/*!
 * @brief Enables/disables the FlexIO T-Format receive DMA.
 * This function enables/disables the FlexIO T-Format Rx DMA,
 * which means asserting kFLEXIO_T_Format_RxDataRegFullFlag does/doesn't trigger the DMA request.
 *
 * @param base Pointer to the FLEXIO_T_FORMAT_Type structure.
 * @param enable True to enable, false to disable.
 */
static inline void FLEXIO_T_Format_EnableRxDMA(FLEXIO_T_FORMAT_Type *base, bool enable)
{
    FLEXIO_EnableShifterStatusDMA(base->flexioBase, 1UL << base->shifterIndex[1], enable);
}

/*!
 * @brief Writes one byte of data.
 *
 * @note This is a non-blocking API, which returns directly after the data is put into the
 * data register. Ensure that the TxEmptyFlag is asserted before calling this API.
 *
 * @param base Pointer to the FLEXIO_T_FORMAT_Type structure.
 * @param buffer The data bytes to send.
 */
static inline void FLEXIO_T_Format_WriteByte(FLEXIO_T_FORMAT_Type *base, const uint8_t *buffer)
{
    base->flexioBase->SHIFTBUF[base->shifterIndex[0]] = *buffer;
}

/*!
 * @brief Reads one byte of data.
 *
 * @note This is a non-blocking API, which returns directly after the data is read from the
 * data register. Ensure that the RxFullFlag is asserted before calling this API.
 *
 * @param base Pointer to the FLEXIO_T_FORMAT_Type structure.
 * @param buffer The buffer to store the received bytes.
 */
static inline void FLEXIO_T_Format_ReadByte(FLEXIO_T_FORMAT_Type *base, uint8_t *buffer)
{
    *buffer = (uint8_t)(base->flexioBase->SHIFTBUFBYS[base->shifterIndex[1]]);
}

status_t FLEXIO_T_Format_Init(FLEXIO_T_FORMAT_Type *base, flexio_t_format_config_t *userConfig, uint32_t srcClock_Hz);
void FLEXIO_T_Format_Deinit(FLEXIO_T_FORMAT_Type *base);
void FLEXIO_T_Format_GetDefaultConfig(flexio_t_format_config_t *userConfig);
void FLEXIO_T_Format_EnableInterrupts(FLEXIO_T_FORMAT_Type *base, uint32_t mask);
void FLEXIO_T_Format_DisableInterrupts(FLEXIO_T_FORMAT_Type *base, uint32_t mask);
uint32_t FLEXIO_T_Format_GetStatusFlags(FLEXIO_T_FORMAT_Type *base);
void FLEXIO_T_Format_ClearStatusFlags(FLEXIO_T_FORMAT_Type *base, uint32_t mask);
status_t FLEXIO_T_Format_WriteBlocking(FLEXIO_T_FORMAT_Type *base, const uint8_t *txData, size_t txSize);
status_t FLEXIO_T_Format_ReadBlocking(FLEXIO_T_FORMAT_Type *base, uint8_t *rxData, size_t rxSize);
status_t FLEXIO_T_Format_TransferCreateHandle(FLEXIO_T_FORMAT_Type *base,
                                              flexio_t_format_handle_t *handle,
                                              flexio_t_format_transfer_callback_t callback,
                                              void *userData);
void FLEXIO_T_Format_TransferStartRingBuffer(FLEXIO_T_FORMAT_Type *base,
                                             flexio_t_format_handle_t *handle,
                                             uint8_t *ringBuffer,
                                             size_t ringBufferSize);
void FLEXIO_T_Format_TransferStopRingBuffer(FLEXIO_T_FORMAT_Type *base, flexio_t_format_handle_t *handle);
status_t FLEXIO_T_Format_TransferSendNonBlocking(FLEXIO_T_FORMAT_Type *base,
                                                 flexio_t_format_handle_t *handle,
                                                 flexio_t_format_transfer_t *xfer);
void FLEXIO_T_Format_TransferAbortSend(FLEXIO_T_FORMAT_Type *base, flexio_t_format_handle_t *handle);
status_t FLEXIO_T_Format_TransferGetSendCount(FLEXIO_T_FORMAT_Type *base, flexio_t_format_handle_t *handle, size_t *count);
status_t FLEXIO_T_Format_TransferReceiveNonBlocking(FLEXIO_T_FORMAT_Type *base,
                                                    flexio_t_format_handle_t *handle,
                                                    flexio_t_format_transfer_t *xfer,
                                                    size_t *receivedBytes);
void FLEXIO_T_Format_TransferAbortReceive(FLEXIO_T_FORMAT_Type *base, flexio_t_format_handle_t *handle);
status_t FLEXIO_T_Format_TransferGetReceiveCount(FLEXIO_T_FORMAT_Type *base, flexio_t_format_handle_t *handle, size_t *count);
void FLEXIO_T_Format_FlushShifters(FLEXIO_T_FORMAT_Type *base);
status_t FLEXIO_T_Format_TransferReceiveEDMA(FLEXIO_T_FORMAT_Type *base, void *rxData, size_t dataSize);
status_t FLEXIO_T_Format_ReceiveEDMA_isCompleted(FLEXIO_T_FORMAT_Type *base);
status_t FLEXIO_T_Format_SendSyncReq(FLEXIO_T_FORMAT_Type *base, const uint8_t cf);

char *T_Format_GetStatusFlag(status_t status);
status_t T_Format_Check_SF(uint8_t sf);
status_t T_Format_Readout_ABS_ABM_Parse(encoder_T_format *enc, encoder_res_all_info_t *res, encoder_all_info_t *all_info);
status_t T_Format_Readout_ABS_ABM(encoder_T_format *enc, encoder_all_info_t *all_info);
status_t T_Format_Readout_ABS_ABM_IRQ(encoder_T_format *enc, encoder_all_info_t *all_info);
status_t T_Format_Readout_ABS(encoder_T_format *enc, uint32_t *singleData);
status_t T_Format_Readout_ABM(encoder_T_format *enc, uint32_t *multiData);
status_t T_Format_Readout_Encoder_status(encoder_T_format *enc, uint8_t *statusData);
status_t T_Format_Reset_Request(encoder_T_format *enc, Reset_Type_e reset, uint32_t *abs);
status_t T_Format_Get_Encoder_ID_Parse(encoder_T_format *enc, encoder_res_id_t *res, uint8_t *encID);
status_t T_Format_Get_Encoder_ID(encoder_T_format *enc, uint8_t *encID);
status_t T_Format_Get_Encoder_ID_IRQ(encoder_T_format *enc, uint8_t *encID);
status_t T_Format_Memory_Set_Page(encoder_T_format *enc, uint8_t page);
status_t T_Format_Memory_Write(encoder_T_format *enc, encoder_access_eeprom_t eeprom);
status_t T_Format_Memory_Read(encoder_T_format *enc, encoder_access_eeprom_t *eeprom);
status_t T_Format_Set_Over_Heat(encoder_T_format *enc, uint8_t temperature);
status_t T_Format_Get_Temperature(encoder_T_format *enc, int8_t *temperature);

#if defined(__cplusplus)
}
#endif /* __cplusplus */

/* @} */

#endif
