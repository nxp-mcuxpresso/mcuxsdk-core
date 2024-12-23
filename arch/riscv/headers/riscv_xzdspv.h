/*
 * Copyright 2023-2024 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef RISCV_XZDSPV_H_
#define RISCV_XZDSPV_H_

#include "riscv_asm.h"

/*
 * Change log:
 *
 *   1.1.0
 *     - Add definitions for DCR registers
 *     - Add API to modify the index for given AGU pointer
 * 
 *   1.0.1
 *     - Update definition for source and destination operand
 *     - Update APIs
 *
 *   1.0.0
 *     - Initial version
 */

/*!
 * @ingroup RISCV_CoreCustomExt
 * @defgroup RISCV_CoreCustomExtXzdspv DSP-V Extension (Xzdspv)
 * @details DSP-V Extension 0.1 supported.
 * @{
 */

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/*!
 * @name DSPV CSR address definition
 * @{
 */

/* AGU pointer address offset */
#define DSPV_AGU_ADDR_OFFSET   (4U)

#define CSR_DSPV_AGU_PTR0_PBASE (2112u)
#define CSR_DSPV_AGU_PTR0_STEP0 (2113u)
#define CSR_DSPV_AGU_PTR0_STEP1 (2114u)
#define CSR_DSPV_AGU_PTR0_INDEX (2115u)
#define CSR_DSPV_AGU_PTR0_INFO  (2144u)

#define CSR_DSPV_AGU_PTRn_PBASE(n) (CSR_DSPV_AGU_PTR0_PBASE + ((n) * DSPV_AGU_ADDR_OFFSET))
#define CSR_DSPV_AGU_PTRn_STEP0(n) (CSR_DSPV_AGU_PTR0_STEP0 + ((n) * DSPV_AGU_ADDR_OFFSET))
#define CSR_DSPV_AGU_PTRn_STEP1(n) (CSR_DSPV_AGU_PTR0_STEP1 + ((n) * DSPV_AGU_ADDR_OFFSET))
#define CSR_DSPV_AGU_PTRn_INDEX(n) (CSR_DSPV_AGU_PTR0_INDEX + ((n) * DSPV_AGU_ADDR_OFFSET))
#define CSR_DSPV_AGU_PTRn_INFO(n)  (CSR_DSPV_AGU_PTR0_INFO  + (n))

#define CSR_DSPV_HIST (2152u)
#define CSR_DSPV_MUX  (2153u)

/* Scaler. */
#define CSR_DSPV_SCALAR_SRC_LO  (2154u)
#define CSR_DSPV_SCALAR_SRC_HI  (2155u)
#define CSR_DSPV_SCALAR_DST_LO  (2156u)
#define CSR_DSPV_SCALAR_DST_HI  (2157u)

/* NCO */
#define CSR_DSPV_NCO_PHASE  (2158u)
#define CSR_DSPV_NCO_FREQ   (2159u)
#define CSR_DSPV_NCO_CONFIG (2160u)

/* stat and config */
#define CSR_DSPV_STAT   (2161u)
#define CSR_DSPV_CONFIG (2162u)

/* Cache */
#define CSR_DSPV_SC_CONTROL  (2163u)
#define CSR_DSPV_SC_HITS     (2164u)
#define CSR_DSPV_SC_STALLS   (2165u)

/* Scratch */
#define CSR_DSPV_SCRATCH_54  (2166u)
#define CSR_DSPV_SCRATCH_55  (2167u)
#define CSR_DSPV_SCRATCH_56  (2168u)
#define CSR_DSPV_SCRATCH_57  (2169u)
#define CSR_DSPV_SCRATCH_58  (2170u)
#define CSR_DSPV_SCRATCH_59  (2171u)
#define CSR_DSPV_SCRATCH_60  (2172u)
#define CSR_DSPV_SCRATCH_61  (2173u)
#define CSR_DSPV_SCRATCH_62  (2174u)
#define CSR_DSPV_SCRATCH_63  (2175u)

/*!
 * @}
 */

/*! @brief LIST of DSPV AGU */
typedef enum _dspv_agu_point
{
    kDSPV_AGU_P0 = 0, /*!< vcpu address generation unit pointer 0 */
    kDSPV_AGU_P1 = 1, /*!< vcpu address generation unit pointer 1 */
    kDSPV_AGU_P2 = 2, /*!< vcpu address generation unit pointer 2 */
    kDSPV_AGU_P3 = 3, /*!< vcpu address generation unit pointer 3 */
    kDSPV_AGU_P4 = 4, /*!< vcpu address generation unit pointer 4 */
    kDSPV_AGU_P5 = 5, /*!< vcpu address generation unit pointer 5 */
    kDSPV_AGU_P6 = 6, /*!< vcpu address generation unit pointer 6 */
    kDSPV_AGU_P7 = 7, /*!< vcpu address generation unit pointer 7 */
    kDSPV_AGU_Num,    /*!< Pointer number. */
} dspv_agu_point_t;

/*!
 * @brief DSPV AGU pointer descriptor(160-bit)
 * This structure holds the configuration for AGU pointer
 */
typedef struct _dspv_agu_pointer
{
    uint32_t pbase; /*!< base address for a VCPU AGU pointer */
    int32_t step0;  /*!< the step for a VCPU AGU pointer*/
    int32_t step1;  /*!< the length/alternate step for a VCPU AGU pointer */
    int32_t index;  /*!< the index for VCPU instructions which use AGU */
    uint32_t info;  /*!< AGU pointer.info */
} dspv_agu_pointer_descriptor_t;

/*! @brief definition of element size for the info register */
typedef enum _dspv_info_esz
{
    kDSPV_INFO14_eszOneByte  = 0, /*!<  element size is 8 bits  */
    kDSPV_INFO14_eszHalfWord = 1, /*!<  element size is 16 bits  */
    kDSPV_INFO14_eszWord     = 2, /*!<  element size is 32 bits  */
    kDSPV_INFO14_eszRsv      = 3, /*!<  element size is 64 bits  */
} dspv_info_esz_t;

/*! @brief definition of element type for the info register */
typedef enum _dspv_info_type
{
    kDSPV_INFO14_typeUnsigned = 0, /*!< element type is unsigned */
    kDSPV_INFO14_typeSigned   = 1, /*!< element type is signed */
    kDSPV_INFO14_typeRsv      = 2, /*!< element type is reserved */
    kDSPV_INFO14_typeFloat    = 3, /*!< element type is float */
} dspv_info_type_t;

/*! @brief definition of element real or complex  for the info register */
typedef enum _dspv_info_rc
{
    kDSPV_INFO14_rcReal      = 0, /*!< element is real number */
    kDSPV_INFO14_rcComplex   = 1, /*!< element is complex number */
} dspv_info_rc_t;

/*! @brief definition of vector size for info register */
typedef enum _dspv_info_vsize
{
    kDSPV_INFO14_vsize0xVector = 0, /*!< 0x vector, it's element. given memory alignment is 4 bytes
                                when unsigned,signed, 8-bit(u8, i8): (E0, E0, E0, E0)
                                when unsigned,signed,float,16-bit(u16, i16, f16): (E0, E0)
                                when complex,signed,float,16-bit(ci16,cf16): (E0.imag, E0.real)
                                when unsigned,signed,float,32-bit(u32,i32,f32): (E0,) */
    kDSPV_INFO14_vsize1xVector = 1, /*!< 1x vector
                                when u8 or i8, (E0, E0, E0, E0), 8-bit
                                others, not support */

    kDSPV_INFO14_vsize2xVector = 2, /*!< 2x vector
                               when u8 or i8, (e1, e0, e1, e0), 8-bit
                               when u16, i16 or f16, (E0, E0), 16-bit
                               others, not support */
    kDSPV_INFO14_vsize4xVector = 3, /*!< 4x vector
                               when u8 or i8, (E3, E2, E1, E0), 8-bit
                               when u16, i16 or f16, (E1, E0), 16-bit
                               when ci16 or cf16, (E0.imag, E0.real), 16-bit
                               when u32,i32,f32, (E0,) 32bit */
} dspv_info_vsize_t;

/*! @brief definition of address mode for info register */
typedef enum _dspv_info_addr_mode
{
    kDSPV_INFO14_addrMode0 = 0,  /*!< std: linear addressing */
    kDSPV_INFO14_addrMode1 = 1,  /*!< masked: linear addressing, but no elements will 
                                 be written when index>=step1 */
    kDSPV_INFO14_addrMode2 = 2,  /*!< modulo: next_index=modulo(index+post_inc, step1). 
                                 The modulo function only applies to the starting 
                                 index of the vector */
    kDSPV_INFO14_addrMode3 = 3,  /*!< History: positive indexes are referenced to 
                                 the pointers base address, negative indexes are
                                 referenced to the address in DCR40(history register)
                                 This allows splicing of two memory buffers together,
                                 but the data must be contiguous accross the
                                 boundary and the boundary must be aligned
                                 with a memory boundary, this is the only 
                                 addressing mode, which allows negative indexes
                                */
    kDSPV_INFO14_addrMode4 = 4,  /*!< Circular: same as modulo addressing, but the
                                 modulo operation is applied to the index of 
                                 every element in the vector, causing the data
                                 to wrap around to the beginning of the vector */
    kDSPV_INFO14_addrMode5 = 5,  /*!< FFT: the addressing is completely controlled by
                                 the hardware state machine, using parameters
                                 programed into the nco_config register. */
} dspv_info_addr_mode_t;

/*! @brief definition of read/write mode for info register */
typedef enum _dspv_info_rwp
{
    kDSPV_INFO14_rwp0 = 0, /*!< start prefetch when info register is written */
    kDSPV_INFO14_rwp1 = 1, /*!< start prefetch when step0 register is written */
    kDSPV_INFO14_rwp2 = 2, /*!< start prefetch when step1 register is written */
    kDSPV_INFO14_rwp3 = 3, /*!< start prefetch when index register is written */
    kDSPV_INFO14_rwp4 = 4, /*!< behavior as mode6 */
    kDSPV_INFO14_rwp5 = 5, /*!< behavior as mode6 */
    kDSPV_INFO14_rwp6 = 6, /*!< writeback data will be used by future read
                           (temp variable), enable prefetch on 1st read */
    kDSPV_INFO14_rwp7 = 7, /*!< writeback data will not be reused in current scope */
} dspv_info_rwp_t;

/*! @brief definition of rounding & saturation mode in the info register */
typedef enum _dspv_info_rndsat
{
    kDSPV_INFO_rndSatRNE = 0,  /*!< round to nearest, ties to Even, then saturate */
    kDSPV_INFO_rndSatRTZ = 1,  /*!< round toward zero, then saturate */
    kDSPV_INFO_rndSatRDN = 2,  /*!< round toward -infinity, then saturate */
    kDSPV_INFO_rndSatRUP = 3,  /*!< round toward +infinity, then saturate */
    kDSPV_INFO_rndSatRMM = 4,  /*!< round to neast, ties to Max Magnitude, then saturate */
    kDSPV_INFO_rndSatRsv1= 5,  /*!< reserved */
    kDSPV_INFO_rndSatRsv2= 6,  /*!< reserved */
    kDSPV_INFO_rndSatReg = 7,  /*!< use vector rounding mode register, then saturate*/
    kDSPV_INFO_rndRNE    = 8,  /*!< round to nearest, ties to Even */
    kDSPV_INFO_rndRTE    = 9,  /*!< round toward zero */
    kDSPV_INFO_rndRDN    = 10, /*!< round toward -infinity */
    kDSPV_INFO_rndRUP    = 11, /*!< round toward +infinity */
    kDSPV_INFO_rndRMM    = 12, /*!< round to neast, ties to max magnitude */
    kDSPV_INFO_rndRsv1   = 13, /*!< reserved */
    kDSPV_INFO_rndRsv2   = 14, /*!< reserved */
    kDSPV_INFO_rndReg    = 15, /*!< use vector rounding mode register */
} dspv_info_rndsat_t;

/*! @brief definition of scaling(n) in AGU info register 
 */
 typedef enum _dspv_info_scaling
{
    kDSPV_INFO_scalingDown32 = 0x60, /*!< scaling factor is 1/2^32, scaling down by 2^32 */
    kDSPV_INFO_scalingDown31 = 0x61, /*!< scaling factor is 1/2^31, scaling down by 2^31 */
    kDSPV_INFO_scalingDown15 = 0x71, /*!< scaling factor is 1/2^15, scaling down by 2^15 */
    kDSPV_INFO_scalingDown7  = 0x79, /*!< scaling factor is 1/2^7, scaling down by 2^7 */
    kDSPV_INFO_scalingUp1    = 0x7F, /*!< scaling factor is 1/2, scaling down by 2 */
    kDSPV_INFO_scalingNone   = 0x0,  /*!< scaling factor is 1, no scaling */
    kDSPV_INFO_scalingUp7    = 0x7,  /*!< scaling factor is 2^7, scaling up by 2^7 */
    kDSPV_INFO_scalingUp31   = 0x1F, /*!< scaling factor is 2^31, scaling up by 2^31 */
} dspv_info_scaling_t;

/*! @brief definition for low 16-bit of info register(or named info14),
 * little endian
 */
typedef struct _dspv_info14
{
    uint16_t esz     : 2; /*!< bit[1:0] element size, refer to dspv_info_esz_t */
    uint16_t type    : 2; /*!< element type, refer to dspv_info_type_t*/
    uint16_t rc      : 1; /*!< element is real or complex, refer to dspv_info_rc_t */
    uint16_t vsize   : 2; /*!< vector size, refer to dspv_info_vsize_t */
    uint16_t addrMode: 4; /*!< addressing mode, refer to dspv_info_addrmode_t */
    uint16_t rwp     : 3; /*!< read/write/prefetch, refer to dspv_info_rwp_t */
    uint16_t rsv1    : 2; /*!< bit[15:14] reserved */
} dspv_info14_t;

/*! @brief definition for high 16-bit(bit[31:16] field of AGU info register,
 * little endian
 */
typedef struct _dspv_infohi
{
    uint16_t rsv2    : 4; /*!< bit[3:0] reserved */
    uint16_t rndSat  : 4; /*!< rounding and saturation, refer to dspv_info_rndsat_t */
    uint16_t scaling : 8; /*!< enable 2^(n) fixed point scaling, refer to dspv_info_scaling_t */
} dspv_infohi_t;

/*! @brief definition for the info register of AGU */
typedef struct _dspv_info
{
    dspv_info14_t info_l;
    dspv_infohi_t info_h;
} dspv_info_t;

/*! @brief definition of rounding and saturation offset in the info register */
#define DSPV_INFO_RNDSAT_OFFSET    20U
/*! @brief definition of scaling offset in the info register */
#define DSPV_INFO_SCALING_OFFSET   24U

/*! @brief definition for the stat register */
typedef struct _dspv_stat_reg
{
    uint32_t dinv  :1; /*!< this bit will be set when a destination pointer has
                            an invalid AGU configuration. writing 1 to clear */
    uint32_t s1inv :1; /*!< this bit will be set when the 1st source pointer has 
                            an invalid AGU configuration. writing 1 to clear */
    uint32_t s2inv :1; /*!< this bit will be set when the 2nd source pointer has
                            an invalid AGU configuration. writing 1 to clear */
    uint32_t s3inv :1; /*!< this bit will be set when the 3th source pointer has
                            an invalid AGU configuration. writing 1 to clear */
    uint32_t awerr :1; /*!< this be will be set when an AXI write returns an 
                            error. writing 1 to clear */
    uint32_t arerr :1; /*!< this bit will be set when an AXI read returns an
                            error. writing 1 to clear */
    uint32_t rsv   :26;
} dspv_stat_reg_t;

/*! @brief definition for the config register */
typedef struct _dspv_config_reg
{
    uint32_t nx        :1; /*!< vector inexact result */
    uint32_t uf        :1; /*!< vector underflow */
    uint32_t of        :1; /*!< vector overflow */
    uint32_t dv        :1; /*!< vector divide by zero */
    uint32_t nv        :1; /*!< vector invalid operation, i.e. NaN */
    uint32_t rnd       :3; /*!< vector global rounding mode, 0:RNE,1:RNZ,2:RDN
                                3:RUP; 4:RMM; 5-7:rsv */
    uint32_t rsv       :20;
    uint32_t log2_vlen :4; /*!< this field contains bits 3:0 of log2(VLEN),
                                read-only, it's value is 0x3 */
} dspv_config_reg_t;

/*! @brief definition for the nco config register */
typedef struct _dspv_nco_config_reg
{
    uint32_t k    : 16; /*!< this field contains the NCO k value */
    uint32_t fftn : 16; /*!< this field contains the NCO fftn value */
} dspv_nco_config_reg_t;

/*! @brief definition for the smart cache control */
typedef struct _dspv_cache_control_reg
{
    uint32_t clean     :1; /*!< write 1 to clear, all dirty cache lines will be 
                        written to memory as soon as possible.
                        if clean bit and invalidate/pf_reset are both written 1
                        in the same write, the clean will be performaned before
                        invalidate/pf_reset. */
    uint32_t invalidate:1; /*!< write 1 to invalidate, all he cache lines are
                        marked as containing no valid data. This bit will read
                        back as a 1 when there is a pending invalidate operation
                        the invalidate will not complete until all pending AXI
                        reads have completed. */
    uint32_t pf_reset  :1; /*! write 1 to reset, the prefetch state machine for
                        all smart pointers is reset, and no prefetch will occur
                        on any of them until they are reinitialized(e.g. with
                        vvbasew). no dcr values are modified, and the smart pointer
                        still have the same config. the cache allocation sub-sys
                        is also reset. and all the cache lines are marked as
                        containing no valid data. */
    uint32_t prefetch_sus:1; /*!< This is the prefetch suspend bit. No new prefetch
                        read request will be made on the AXI bus while this bit 
                        is high. prefetch read request still in process on the AXI
                        bus are not canceled. the smart pointer prefetch stat 
                        is preserved. and when this bit is cleared after being
                        set, smart pointer prefetching picks up where it left off.*/
    uint32_t zero_count:1; /*!< when this bit is written as a 1, all the status 
                        register counters(e.g. misses, hits,...) will be set 0.*/
    uint32_t hard_reset:1; /*!< this bit is not intended for use in normal operation
                        write 1 to reset, the entire smart cache and AGU sub-sys
                        are reset in a non graceful way. The reset occurs immediately,
                        and does not wait for anything. instructions in the pipeline
                        could be missed, the AXI bus protocal could be violated,
                        and all modified data in the cache will be lost.*/
    uint32_t rsv:1;
    uint32_t dirty:1;   /*!< when this bit is 1, the cache contains lines have
                        been updated but not written to memory. when this bit is
                        zero. no cache data needs to be written to memory. */
    uint32_t misses:24; /*!< the number of source pointer cache misses. One miss
                        can occur for every source pointer used in each instruction(max 3).
                        this counter is reset to zero by the zero_count bit. This
                        counter does not wrap, and will stop counting when all 1's*/
} dspv_cache_control_reg_t;

/*! @brief definition for cache stall register */
typedef struct _dspv_cache_stall_reg
{
    uint32_t wb_stalls: 12; /*!< this field reports the number clock cycles the 
                        cache waited to write data to the cache. write stalls occur
                        when a cache line allocated for ALU output data is already
                        dirty. DSP-V stalls and waits for the cache clean of that
                        line to complete. This counter is reset to 0 by zero_count
                        bit. This counter does not wrap, and will stop counting
                        when all 1's*/
    uint32_t sm_stalls: 20; /*!< this field reports the number clock cycles the smart
                        cache waited for source data. The number of cycles waited
                        depends on the number of cache misses and usage of the 
                        AXI/AHB bus. */
} dspv_cache_stall_reg_t;

/*!
 * @brief definition for Source Modifier m1 encoding
 * @note it does not get applied to SAU
 */
typedef enum _dspv_source_m1
{
    kDSPV_M1_bypass = 0, /*!< x=x, do nothing */
    kDSPV_M1_abs    = 1, /*!< abs(x) absolute operation, given 32-bit space
                        when source element is 8-bit real input(b3, b2, b1, b0), output is (|b3|,|b2|,|b1|,|b0|);
                        when source element is 16-bit real input(h1,h0), output is (|h1|,|h0|);
                        when source element is 32-bit real input(w0), output is (|w0|);
                        when source element is 16-bit complex input(h1,h0), output is (|h1|,|h0|), output type is c16;
                        */
    kDSPV_M1_conj   = 2, /*!< conj(x) conjugate operation, given 32-bit space
                        when source element is 8-bit real input(b3, b2, b1, b0), output is (-b3, b2, -b1, b0);
                        when source element is 16-bit real input(h1,h0), output is (-h1, h0);
                        when source element is 32-bit real input(w0), output is (w0);
                        when source element is 16-bit complex input(h1,h0), output is (-h1, h0)
                        */
    kDSPV_M1_rotj   = 3, /*!< rotj(a+b*j)= a*j-b, rotate operation, given 32-bit space
                        when source element is 8-bit real input(b3, b2, b1, b0), output is (b2, -b3, b0, -b1);
                        when source element is 16-bit real input(h1,h0), output is (h0, -h1);
                        when source element is 32-bit real input(w0), output is (w0);
                        when source element is 16-bit complex input(h1,h0), output is (h0, -h1);
                        */
    kDSPV_M1_pado   = 4, /*!< pad_odd(x), given 32-bit space
                        when source element is 8-bit real input(b3, b2, b1, b0), output is (0, b1, 0, b0);
                        when source element is 16-bit real input(h1,h0), output is (0, h0);
                        when source element is 32-bit real input(w0), output is (w0);
                        when source element is 16-bit complex input(h1,h0), output is (0, h0);
                        */
    kDSPV_M1_pade   = 5, /*!< pad_even(x), given 32bit space,
                        when source element is 8-bit real input(b3, b2, b1, b0), output is (b1, 0, b0, 0);
                        when source element is 16-bit real input(h1,h0), output is (h0, 0);
                        when source element is 32-bit real input(w0), output is (w0);
                        when source element is 16-bit complex input(h1,h0), output is (h0, 0);
                        */
    kDSPV_M1_even   = 6, /*!< pad_even(x), given 32bit space,
                        when source element is 8-bit real input(b3, b2, b1, b0), output is (b2, b0, b2, b0);
                        when source element is 16-bit real input(h1,h0), output is (h0, h0);
                        when source element is 32-bit real input(w0), output is (w0);
                        when source element is 16-bit complex input(h1,h0), output is (h0, h0);
                        */
    kDSPV_M1_odd    = 7, /*!< pad_odd(x), given 32bit space,
                        when source element is 8-bit real input(b3, b2, b1, b0), output is (b3, b1, b3, b1);
                        when source element is 16-bit real input(h1,h0), output is (h1, h1);
                        when source element is 32-bit real input(w0), output is (w0);
                        when source element is 16-bit complex input(h1,h0), output is (h1, h1);
                        */
} dspv_source_m1_t;

/*!
 * @brief definition for Source Modifier m2 encoding
 * @note it does not get applied to SAU
 */
typedef enum _dspv_source_m2
{
    kDSPV_M2_bypass = 0, /*!< x = x, do nothing */
    kDSPV_M2_abs    = 1, /*!< abs(x), absolute operation, given 32-bit space
                        when source element is 8-bit real input(b3, b2, b1, b0), output is (|b3|,|b2|,|b1|,|b0|);
                        when source element is 16-bit real input(h1,h0), output is (|h1|,|h0|);
                        when source element is 32-bit real input(w0), output is (|w0|);
                        when source element is 16-bit complex input(h1,h0), output is (|h1|,|h0|), output type is c16;
                        */
    kDSPV_M2_conj   = 2, /*!< conj(x) conjugate operation, given 32-bit space
                        when source element is 8-bit real input(b3, b2, b1, b0), output is (-b3, b2, -b1, b0);
                        when source element is 16-bit real input(h1,h0), output is (-h1, h0);
                        when source element is 32-bit real input(w0), output is (w0);
                        when source element is 16-bit complex input(h1,h0), output is (-h1, h0)
                        */
    kDSPV_M2_rotj   = 3, /*!< rotj(a+b*j)= a*j-b, rotate operation, given 32-bit space
                        when source element is 8-bit real input(b3, b2, b1, b0), output is (b2, -b3, b0, -b1);
                        when source element is 16-bit real input(h1,h0), output is (h0, -h1);
                        when source element is 32-bit real input(w0), output is (w0);
                        when source element is 16-bit complex input(h1,h0), output is (h0, -h1);
                        */
} dspv_source_m2_t;

/*!
 * @brief definition for Source Modifier sau2 encoding
 * @note SAU only, do nothing when element is complex input
 */
typedef enum _dspv_source_sau2
{
    kDSPV_SAU2_bypass    = 0, /*!< x=x, do nothing*/
    kDSPV_SAU2_recp      = 1, /*!< 1/(x) */
    kDSPV_SAU2_sqrt      = 2, /*!< sqrt(x) */
    kDSPV_SAU2_recp_srqt = 3, /*!< 1/sqrt(x) */ 
} dspv_source_sau2_t;

/*!
 * @brief definition for Source Modifier sau5 encoding
 * @note SAU only, do nothing when element is complex input
 */
typedef enum _dspv_source_sau5
{
    kDSPV_SAU5_bypass    = 0, /*!< x=x, do nothing*/
    kDSPV_SAU5_recp      = 1, /*!< 1/(x) */
    kDSPV_SAU5_sqrt      = 2, /*!< sqrt(x) */
    kDSPV_SAU5_recp_srqt = 3, /*!< 1/sqrt(x) */
    kDSPV_SAU5_cospi     = 8, /*!< cospi(x)= cos(pi*x) */
    kDSPV_SAU5_sinpi     = 9, /*!< sinpi(x)= sin(pi*x) */
} dspv_source_sau5_t;

/*!
 * @brief definition for NCO encoding
 */
typedef enum _dspv_nco
{
    kDSPV_NCO_cos        = 0, /*!< cos(nco)    */
    kDSPV_NCO_sin        = 1, /*!< sin(nco)    */
    kDSPV_NCO_expj       = 2, /*!< expj(nco)   */
    kDSPV_NCO_expjn      = 3, /*!< expj(-nco)  */
    kDSPV_NCO_cos_inc    = 4, /*!< cos(nco)+   */
    kDSPV_NCO_sin_inc    = 5, /*!< sin(nco)+   */
    kDSPV_NCO_expj_inc   = 6, /*!< expj(nco)+  */
    kDSPV_NCO_expjn_inc  = 7, /*!< expj(-nco)+ */
} dspv_nco_t;

/*!
 * @brief definition for source operand 5-bit field encoding
 * px     ,     *(px), x in the range from 0 to 7;
 * dcr_ru ,     real unsigned integer scalar;
 * dcr_ri ,     real signed integer scalar;
 * nco    ,     nco with no post increment of phase;
 * dcr_rf ,     real floating-point scalar;
 * dcr_ci ,     complex signed integer scalarv;
 * nco+   ,     nco with post-increment of phase;
 * dcr_cf ,     complex floating-point scalar
 * px+    ,     *(px), px += step0;
 * px-    ,     *(px), px -= step0, px += step1;
 */
#define kDSPV_srcOpnd_p0      0b00000 /*!< p0, *(p0), no post-increment */
#define kDSPV_srcOpnd_p1      0b00100 /*!< p1, *(p1), no post-increment */
#define kDSPV_srcOpnd_p2      0b01000 /*!< p2, *(p2), no post-increment */
#define kDSPV_srcOpnd_p3      0b01100 /*!< p3, *(p3), no post-increment */
#define kDSPV_srcOpnd_p4      0b10000 /*!< p4, *(p4), no post-increment */
#define kDSPV_srcOpnd_p5      0b10100 /*!< p5, *(p5), no post-increment */
#define kDSPV_srcOpnd_p6      0b11000 /*!< p6, *(p6), no post-increment */
#define kDSPV_srcOpnd_p7      0b11100 /*!< p7, *(p7), no post-increment */
#define kDSPV_srcOpnd_dcr_ru  0b00001 /*!< dcr_ru, real unsigned integer scalar */
#define kDSPV_srcOpnd_dcr_ri  0b00101 /*!< dcr_ri, real signed integer scalar */
#define kDSPV_srcOpnd_nco     0b01001 /*!< nco, nco with no post-increment of phase */
#define kDSPV_srcOpnd_dcr_rf  0b01101 /*!< dcr_rf, real floating-point scalar */
#define kDSPV_srcOpnd_rsv     0b10001 /*!< rsv */
#define kDSPV_srcOpnd_dcr_ci  0b10101 /*!< dcr_ci, complex signed integer scalar */
#define kDSPV_srcOpnd_nco_inc 0b11001 /*!< nco+, nco with post-increment of phase */
#define kDSPV_srcOpnd_dcr_cf  0b11101 /*!< dcr_cf, complex floating-pointer scalar */
#define kDSPV_srcOpnd_p0_inc  0b00010 /*!< p0+, *(p0), p0 += step0 */
#define kDSPV_srcOpnd_p1_inc  0b00110 /*!< p1+, *(p1), p1 += step0 */
#define kDSPV_srcOpnd_p2_inc  0b01010 /*!< p2+, *(p2), p2 += step0 */
#define kDSPV_srcOpnd_p3_inc  0b01110 /*!< p3+, *(p3), p3 += step0 */
#define kDSPV_srcOpnd_p4_inc  0b10010 /*!< p4+, *(p4), p4 += step0 */
#define kDSPV_srcOpnd_p5_inc  0b10110 /*!< p5+, *(p5), p5 += step0 */
#define kDSPV_srcOpnd_p6_inc  0b11010 /*!< p6+, *(p6), p6 += step0 */
#define kDSPV_srcOpnd_p7_inc  0b11110 /*!< p7+, *(p7), p7 += step0 */
#define kDSPV_srcOpnd_p0_dec  0b00011 /*!< p0-, *(p0), p0 -= step0, p0 += step1 */
#define kDSPV_srcOpnd_p1_dec  0b00111 /*!< p1-, *(p1), p1 -= step0, p1 += step1 */
#define kDSPV_srcOpnd_p2_dec  0b01011 /*!< p2-, *(p2), p2 -= step0, p2 += step1 */
#define kDSPV_srcOpnd_p3_dec  0b01111 /*!< p3-, *(p3), p3 -= step0, p3 += step1 */
#define kDSPV_srcOpnd_p4_dec  0b10011 /*!< p4-, *(p4), p4 -= step0, p4 += step1 */
#define kDSPV_srcOpnd_p5_dec  0b10111 /*!< p5-, *(p5), p5 -= step0, p5 += step1 */
#define kDSPV_srcOpnd_p6_dec  0b11011 /*!< p6-, *(p6), p6 -= step0, p6 += step1 */
#define kDSPV_srcOpnd_p7_dec  0b11111 /*!< p7-, *(p7), p7 -= step0, p7 += step1 */

/*!
 * @brief definition for destination operand 5-bit field encoding
 * px     ,     *(px), x in the range from 0 to 7;
 * acc_r8 ,     real 8-bit accumulator;
 * acc_r16,     real 16-bit accumulator;
 * acc_r32,     real 32-bit accumulator;
 * acc_c16,     complex 16-bit accumulator;
 * acc_c32,     complex 32-bit accumulator;
 * px+    ,     *(px), px += step0;
 * px-    ,     *(px), px -= step0 or px += step1;
 */
#define kDSPV_dstOpnd_p0      0b00000 /*!< p0, *(p0), no post-increment */
#define kDSPV_dstOpnd_p1      0b00100 /*!< p1, *(p1), no post-increment */
#define kDSPV_dstOpnd_p2      0b01000 /*!< p2, *(p2), no post-increment */
#define kDSPV_dstOpnd_p3      0b01100 /*!< p3, *(p3), no post-increment */
#define kDSPV_dstOpnd_p4      0b10000 /*!< p4, *(p4), no post-increment */
#define kDSPV_dstOpnd_p5      0b10100 /*!< p5, *(p5), no post-increment */
#define kDSPV_dstOpnd_p6      0b11000 /*!< p6, *(p6), no post-increment */
#define kDSPV_dstOpnd_p7      0b11100 /*!< p7, *(p7), no post-increment */
#define kDSPV_dstOpnd_acc_r8  0b00001 /*!< acc_r8, real 8-bit accumulator */
#define kDSPV_dstOpnd_acc_r16 0b00101 /*!< acc_r16, real 16-bit accumulator */
#define kDSPV_dstOpnd_acc_r32 0b01001 /*!< acc_r32, real 32-bit accumulator */
#define kDSPV_dstOpnd_rsv1    0b01101 /*!< rsv */
#define kDSPV_dstOpnd_rsv2    0b10001 /*!< rsv */
#define kDSPV_dstOpnd_acc_c16 0b10101 /*!< acc_c16, complex 16-bit accumulator */
#define kDSPV_dstOpnd_acc_c32 0b11001 /*!< acc_c32, complex 32-bit accumulator */
#define kDSPV_dstOpnd_rsv3    0b11101 /*!< rsv */
#define kDSPV_dstOpnd_p0_inc  0b00010 /*!< p0+, *(p0), p0 += step0 */
#define kDSPV_dstOpnd_p1_inc  0b00110 /*!< p1+, *(p1), p1 += step0 */
#define kDSPV_dstOpnd_p2_inc  0b01010 /*!< p2+, *(p2), p2 += step0 */
#define kDSPV_dstOpnd_p3_inc  0b01110 /*!< p3+, *(p3), p3 += step0 */
#define kDSPV_dstOpnd_p4_inc  0b10010 /*!< p4+, *(p4), p4 += step0 */
#define kDSPV_dstOpnd_p5_inc  0b10110 /*!< p5+, *(p5), p5 += step0 */
#define kDSPV_dstOpnd_p6_inc  0b11010 /*!< p6+, *(p6), p6 += step0 */
#define kDSPV_dstOpnd_p7_inc  0b11110 /*!< p7+, *(p7), p7 += step0 */
#define kDSPV_dstOpnd_p0_dec  0b00011 /*!< p0-, *(p0), p0 -= step0, p0 += step1 */
#define kDSPV_dstOpnd_p1_dec  0b00111 /*!< p1-, *(p1), p1 -= step0, p1 += step1 */
#define kDSPV_dstOpnd_p2_dec  0b01011 /*!< p2-, *(p2), p2 -= step0, p2 += step1 */
#define kDSPV_dstOpnd_p3_dec  0b01111 /*!< p3-, *(p3), p3 -= step0, p3 += step1 */
#define kDSPV_dstOpnd_p4_dec  0b10011 /*!< p4-, *(p4), p4 -= step0, p4 += step1 */
#define kDSPV_dstOpnd_p5_dec  0b10111 /*!< p5-, *(p5), p5 -= step0, p5 += step1 */
#define kDSPV_dstOpnd_p6_dec  0b11011 /*!< p6-, *(p6), p6 -= step0, p6 += step1 */
#define kDSPV_dstOpnd_p7_dec  0b11111 /*!< p7-, *(p7), p7 -= step0, p7 += step1 */

/*! @brief definitions for DSPV DCR registers */
#define kDSPV_DCR_p0Base       0  /*!< base address of AGU p0 */
#define kDSPV_DCR_p0Step0      1  /*!< primary step of AGU p0 */
#define kDSPV_DCR_p0Step1      2  /*!< length or alternate step of AGU p0 */
#define kDSPV_DCR_p0Index      3  /*!< index of AGU p0 */
#define kDSPV_DCR_p1Base       4  /*!< base address of AGU p1 */
#define kDSPV_DCR_p1Step0      5  /*!< primary step of AGU p1 */
#define kDSPV_DCR_p1Step1      6  /*!< length or alternate step of AGU p1 */
#define kDSPV_DCR_p1Index      7 /*!< index of AGU p1 */
#define kDSPV_DCR_p2Base       8  /*!< base address of AGU p2 */
#define kDSPV_DCR_p2Step0      9  /*!< primary step of AGU p2 */
#define kDSPV_DCR_p2Step1      10 /*!< length or alternate step of AGU p2 */
#define kDSPV_DCR_p2Index      11 /*!< index of AGU p2 */
#define kDSPV_DCR_p3Base       12 /*!< base address of AGU p3 */
#define kDSPV_DCR_p3Step0      13 /*!< primary step  of AGU p3 */
#define kDSPV_DCR_p3Step1      14 /*!< length or alternate step of AGU p3 */
#define kDSPV_DCR_p3Index      15 /*!< index of AGU p3 */
#define kDSPV_DCR_p4Base       16 /*!< base address of AGU p4 */
#define kDSPV_DCR_p4Step0      17 /*!< primary step of AGU p4 */
#define kDSPV_DCR_p4Step1      18 /*!< length or alternate step  of AGU p4 */
#define kDSPV_DCR_p4Index      19 /*!< index of AGU p4 */
#define kDSPV_DCR_p5Base       20 /*!< base address of AGU p5 */
#define kDSPV_DCR_p5Step0      21 /*!< primary step of AGU p5 */
#define kDSPV_DCR_p5Step1      22 /*!< length or alternate step  of AGU p5 */
#define kDSPV_DCR_p5Index      23 /*!< index of AGU p5 */
#define kDSPV_DCR_p6Base       24 /*!< base address of AGU p6 */
#define kDSPV_DCR_p6Step0      25 /*!< primary step of AGU p6 */
#define kDSPV_DCR_p6Step1      26 /*!< length or alternate step  of AGU p6 */
#define kDSPV_DCR_p6Index      27 /*!< index of AGU p6 */
#define kDSPV_DCR_p7Base       28 /*!< base address of AGU p7 */
#define kDSPV_DCR_p7Step0      29 /*!< primary step of AGU p7 */
#define kDSPV_DCR_p7Step1      20, /*!< length or alternate step of AGU p7  */
#define kDSPV_DCR_p7Index      31 /*!< index of AGU p7 */
#define kDSPV_DCR_p0Info       32 /*!< info f AGU p0 */
#define kDSPV_DCR_p1Info       33 /*!< info of AGU p1 */
#define kDSPV_DCR_p2Info       34 /*!< info of AGU p2 */
#define kDSPV_DCR_p3Info       35 /*!< info of AGU p3 */
#define kDSPV_DCR_p4Info       36 /*!< info of AGU p4 */
#define kDSPV_DCR_p5Info       37 /*!< info of AGU p5 */
#define kDSPV_DCR_p6Info       38 /*!< info of AGU p6 */
#define kDSPV_DCR_p7Info       39 /*!< info f AGU p7 */
#define kDSPV_DCR_histroy      40 /*!< history about operand size and rounding */
#define kDSPV_DCR_mux          41 /*!< mux mode */
#define kDSPV_DCR_scalarSrcLo  42 /*!< scalar source bits 31:0  */
#define kDSPV_DCR_scalarSrcHi  43 /*!< scalar source bits 63:32 */
#define kDSPV_DCR_scalarDstLo  44 /*!< scalar destination bits 31:0  */
#define kDSPV_DCR_scalarDstHi  45 /*!< scalar destination bits 63:32 */
#define kDSPV_DCR_ncoPhase     46 /*!< NCO phase */
#define kDSPV_DCR_ncoFreq      47 /*!< NCO frequency */
#define kDSPV_DCR_ncoConfig    48 /*!< NCO fftn and k configure */
#define kDSPV_DCR_stat         49 /*!< various error status of VCPU */
#define kDSPV_DCR_config       50 /*!< config of VCPU */
#define kDSPV_DCR_cacheContrl  51 /*!< smart cache control */
#define kDSPV_DCR_cacheHits    52 /*!< contains the number of cache hits */
#define kDSPV_DCR_cacheStalls  53 /*!< the cache stall */
#define kDSPV_DCR_scratch54    54 /*!< scratch 54  */
#define kDSPV_DCR_scratch55    55 /*!< scratch 55  */
#define kDSPV_DCR_scratch56    56 /*!< scratch 56  */
#define kDSPV_DCR_scratch57    57 /*!< scratch 57  */
#define kDSPV_DCR_scratch58    58 /*!< scratch 58  */
#define kDSPV_DCR_scratch59    59 /*!< scratch 59  */
#define kDSPV_DCR_scratch60    60 /*!< scratch 60  */
#define kDSPV_DCR_scratch61    61 /*!< scratch 61  */
#define kDSPV_DCR_scratch62    62 /*!< scratch 62  */
#define kDSPV_DCR_scratch63    63 /*!< scratch 63  */

/*******************************************************************************
 * API
 ******************************************************************************/

#ifdef __cplusplus
extern "C" {
#endif

/* ----------------------------------------------------------------------------
   -- DSP-V DCR register mofication instruction
   ---------------------------------------------------------------------------- */
/*!
 * @addtogroup DSPV_Common_DCR_Modification_Instruction
 * @{
 */

/*!
 * @brief write single dcr register
 *
 * @param n   DCR register, (kDSPV_DCR_p0Base, and so on.)
 * @param rs1 Source General Purpose Register containing value to write
 * 
 * @result  dcr(n) = rs1
 */
#define dspv_dcr_write(n, rs1)                             \
({                                                         \
    __asm__ __volatile__("vdcrw dcr" __ASM_STR(n) ", %0"   \
                : : "r" (rs1) : "memory");                 \
})

/*!
 * @brief write two dcr registers
 *
 * @param n   even number(n%2==0), (kDSPV_DCR_p0Base, and so on.)
 * @param rs1 General Purpose Register containing value  to write into dcr(n)
 * @param rs2 General Purpose Register containing value  to write dcr(n+1)
 * 
 * @result dcr(n)=rs1, dcr(n+1) = rs2
 */
#define dspv_dcr_write2(n, rs1, rs2)                          \
({                                                            \
    __asm__ __volatile__("vdcrw2 dcr" __ASM_STR(n) ", %0, %1" \
                : : "r" (rs1), "r" (rs2) : "memory");         \
})

/*!
 * @brief add a value to given dcr register
 *
 * @param n   DCR register, (kDSPV_DCR_p0Base, and so on.)
 * @param rs1 value to add to dcr(n)
 * 
 * @result  dcr(n) += rs1
 */
#define dspv_dcr_add(n, rs1)                                  \
({                                                            \
    __asm__ __volatile__("vdcra dcr" __ASM_STR(n) ", %0"      \
                : : "r" (rs1) : "memory");                    \
})

/*!
 * @brief sub a value to given dcr register
 *
 * @param n   DCR register, (kDSPV_DCR_p0Base, and so on.)
 * @param rs1 value to sub to dcr(n)
 * 
 * @result  dcr(n) -= rs1
 */
#define dspv_dcr_sub(n, rs1)                                  \
({                                                            \
    __asm__ __volatile__("vdcrs dcr" __ASM_STR(n) ", %0"      \
                : : "r" (rs1) : "memory");                    \
})

/*!
 * @brief write an unsigned 16-bit immediate to given dcr register
 *
 * @param n   DCR register, (kDSPV_DCR_p0Base, and so on.)
 * @param uimm16 it is an unsigned 16-bit immediate number
 * 
 * @result  dcr(n) = zero_extend(uimm16)
 */
#define dspv_dcr_write_uimm16(n, uimm16)                     \
({                                                           \
    __asm__ __volatile__("vdcrwi dcr" __ASM_STR(n) ", %0"    \
                : : "i" (uimm16) : "memory");                \
})

/*!
 * @brief write a signed 16-bit immediate to given dcr register
 *
 * @param n   DCR register, (kDSPV_DCR_p0Base, and so on.)
 * @param simm16 it is a signed 16-bit immediate number
 * 
 * @result  dcr(n) = sign_extend(simm16)
 */
#define dspv_dcr_write_simm16(n, simm16)                     \
({                                                           \
    __asm__ __volatile__("vdcrwi dcr" __ASM_STR(n) ", %0"    \
                : : "i" (simm16) : "memory");                \
})

/*!
 * @brief write an un-signed 16-bit immediate to the high 16-bit field 
 *        of given dcr register
 *
 * @param n   DCR register, (kDSPV_DCR_p0Base, and so on.)
 * @param uimm16 it is an unsigned 16-bit immediate number
 * 
 * @result dcr(n)[31:16] = uimm16, dcr(n)[15:0] remain unchanged
 */
#define dspv_dcr_writeh_uimm16(n, uimm16)                    \
({                                                           \
    __asm__ __volatile__("vdcrwhi dcr" __ASM_STR(n) ", %0"   \
                : : "i" (uimm16) : "memory");                \
})

/*!
 * @brief add a signed 16-bit immediate to given dcr register
 *
 * @param n   DCR register, (kDSPV_DCR_p0Base, and so on.)
 * @param simm16 it is a signed 16-bit immediate number
 * 
 * @result  dcr(n) += sign_extend(simm16)
 */
#define dspv_dcr_add_simm16(n, simm16)                       \
({                                                           \
    __asm__ __volatile__("vdcrai dcr" __ASM_STR(n) ", %0"    \
                : : "i" (simm16) : "memory");                \
})

/*!
 * @}
 */ /* end of group DSPV_Common_DCR_Modification_Instruction */

/*!
 * @addtogroup DSPV_AGU_Pointer_Description_Instruction
 * @{
 */

/*!
 * @brief Initialize base and info of AGU Pointer 
 *
 * @param px, pointer , like p0, p1, p2, p3, p4, p5, p6, p7
 * @param base, GPR register which will be copied into the pointer base register
 * @param info14, 14-bit Unsigned Immediate value, refer to enum type: dspv_info14_t
 * 
 * @note this is typically the 1st instruction executed to initialize a pointer
 *       descriptor and default the registers to commonly used values
 * @result px.base = base; 
 *         px.step0=value is depenant on info14; 
 *         px.step1=0;
 *         px.index=0; 
 *         px.info=zero_extend(info14)
 */
#define dspv_agu_init(px, base, info14)                                  \
({                                                                       \
    __asm__ __volatile__("vvbasew " __ASM_STR(px) ", %0 , %1"            \
            : : "r" (base), "i" (info14)                                 \
            : "memory");                                                 \
})

/*!
 * @brief write step0 for given AGU pointer
 *
 * @param px, pointer , like p0, p1, p2, p3, p4, p5, p6, p7
 * @param step it is a Signed 21-bit immediate
 * 
 * @result px.step0 = signed_extend(step)
 */
#define dspv_agu_step0_write(px, step)                                  \
({                                                                      \
    __asm__ __volatile__("vstep0wi " __ASM_STR(px) ", %0"               \
            : : "i" (step) : "memory");                                 \
})

/*!
 * @brief write step1 for given AGU pointer
 *
 * @param px, pointer , like p0, p1, p2, p3, p4, p5, p6, p7
 * @param step it is a signed 21-bit immediate
 * 
 * @result px.step1 = signed_extend(step)
 */
#define dspv_agu_step1_write(px, step)                                  \
({                                                                      \
    __asm__ __volatile__("vstep1wi " __ASM_STR(px) ", %0"               \
            : : "i" (step) : "memory");                                 \
})

/*!
 * @brief write index for given AGU pointer
 *
 * @param px, pointer , like p0, p1, p2, p3, p4, p5, p6, p7
 * @param simm21 21-bit Signed Immediate value
 * 
 * @result px.index = signed_extend(simm21)
 */
#define dspv_agu_index_write(px, simm21)                               \
({                                                                     \
    __asm__ __volatile__("vindexwi " __ASM_STR(px) ", %0"              \
            : : "i" (simm21) : "memory");                              \
})

/*!
 * @brief Modify index for given AGU pointer
 *
 * @param px, pointer , like p0, p1, p2, p3, p4, p5, p6, p7
 * @param delta it is a Signed 21-bit immediate
 * 
 * @result px.index += signed_extend(delta)
 */
#define dspv_agu_index_add(px, delta)                                  \
({                                                                     \
    __asm__ __volatile__("vindexai " __ASM_STR(px) ", %0"              \
            : : "i" (delta) : "memory");                               \
})

/*!
 * @}
 */ /* end of group DSPV_AGU_Pointer_Description_Instruction */

/*!
 * @addtogroup DSPV_mux_instruction
 * @{
 */
/*!
 * @brief Modify index for given AGU pointer
 *
 * @param d : 6-bit mux index for destination operandmux
 * @param s1 : 6-bit mux index for s1 source operand
 * @param s2 : 6-bit mux index for s1 source operand
 * @param s3 : 6-bit mux index for s1 source operand
 * 
 * @result dcr(41) = {d,s1,s2,s3}
 */
#define dspv_vmuxwi(s3, s2, s1, d)                                     \
({                                                                     \
    __asm__ __volatile__("vmuxwi %0, %1, %2, %3"                       \
            : : "i" (s3), "i" (s2), "i" (s1),"i" (d) : "memory");      \
})

/*!
 * @}
 */ /* end of group DSPV_mux_instruction */

/* ----------------------------------------------------------------------------
   -- DSP-V Vector Instructions with 0 Source Operands
   ---------------------------------------------------------------------------- */
/*!
 * @addtogroup DSPV_instruction_without_source_operation
 * @{
 */

/*!
 * @brief synchronize operations between the scalar and vector datapath
 */
#define dspv_sync()                \
({                                 \
    __asm__ __volatile__("vnop");  \
})

/*!
 * @brief store the accumulator into memory
 * 
 * @param px pointer , like
 *           px, px+, px-, range from p0 to p7; p0+ to p7+; p0- to p7-
 */
#define dspv_acc_store(px)                                  \
({                                                          \
    __asm__ __volatile__("vmva " __ASM_STR(px)              \
                 : : : "memory" );                          \
})

/*!
 * @}
 */ /* end of group DSPV_instruction_without_source_operation */

/* ----------------------------------------------------------------------------
   -- DSP-V Vector Instructions with 1 Source Operands
   ---------------------------------------------------------------------------- */
/*!
 * @addtogroup DSPV_instruction_with_one_source_operation
 * @{
 */
/*!
 * @brief vector move source to destion with modifier m1
 * 
 * @param vd vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, it is uimm3, refer to dspv_source_m1_t
 * 
 * @result vd = vs1.m1
 */
#define dspv_vmv(vd, vs1, m1)                                                 \
({                                                                            \
    __asm__ __volatile__("vmv " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0"      \
                 : : "i" (m1) : "memory" );                                   \
})

/*!
 * @brief vector negative move source to destion with modifier m1
 * 
 * @param vd vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, it is uimm3, 
 *        refer to dspv_source_m1_t
 * 
 * @result vd = -vs1.m1
 */
#define dspv_vnmv(vd, vs1, m1)                                                \
({                                                                            \
    __asm__ __volatile__("vnmv " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0"     \
                 : : "i" (m1) : "memory" );                                   \
})

/*!
 * @brief vector move with sau operation
 * 
 * @param vd    vector destination operand
 * @param vs1   vector source operand
 * @param sau5  index for SAU operation applied to the vs1, 
 *        it is uimm5, refer to dspv_source_sau5_t
 * 
 * @result vd = vs1.sau5
 */
#define dspv_vmvs(vd, vs1, sau5)                                              \
({                                                                            \
    __asm__ __volatile__("vmvs " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0"     \
                 : : "i" (sau5) : "memory" );                                 \
})

/*!
 * @brief negative vector move with sau5 operation
 * 
 * @param vd vector destination operand
 * @param vs1 vector source operand
 * @param sau5  index for SAU operation applied to the vs1, 
 *        it is uimm5, refer to dspv_source_sau5_t
 * 
 * @result vd = -vs1.sau5
 */
#define dspv_vnmvs(vd, vs1, sau5)                                             \
({                                                                            \
    __asm__ __volatile__("vnmvs " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0"    \
                 : : "i" (sau5) : "memory" );                                 \
})

/*!
 * @brief vector accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, 
 *        it is uimm3, refer to dspv_source_m1_t
 * 
 * @result vd = vs1.m1 + accumulator
 */
#define dspv_vacc(vd, vs1, m1)                                                \
({                                                                            \
    __asm__ __volatile__("vacc " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0"     \
                 : : "i" (m1) : "memory" );                                   \
})

/*!
 * @brief vector negative accumulate
 * 
 * @param vd vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, 
 *        it is uimm3, refer to dspv_source_m1_t
 * 
 * @result vd = -vs1.m1 + accumulator
 */
#define dspv_vnacc(vd, vs1, m1)                                               \
({                                                                            \
    __asm__ __volatile__("vnacc " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0"    \
                 : : "i" (m1) : "memory" );                                   \
})

/*!
 * @brief vector accumulate(SAU5)
 * 
 * @param vd vector destination operand
 * @param vs1 vector source operand
 * @param sau5  index for SAU operation applied to the vs1, 
 *        it is uimm5, refer to dspv_source_sau5_t
 * 
 * @result dest = vs1.sau5 + accumulator
 */
#define dspv_vaccs(vd, vs1, sau5)                                             \
({                                                                            \
    __asm__ __volatile__("vaccs " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0"    \
                 : : "i" (sau5) : "memory" );                                 \
})

/*!
 * @brief vector negative accumulate(SAU5)
 * 
 * @param vd vector destination operand
 * @param vs1 vector source operand
 * @param sau5  index for SAU operation applied to the vs1, 
 *        it is uimm5, refer to dspv_source_sau5_t
 * 
 * @result vd = -vs1.sau5 + accumulator
 */
#define dspv_vnaccs(vd, vs1, sau5)                                            \
({                                                                            \
    __asm__ __volatile__("vnaccs " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0"   \
                 : : "i" (sau5) : "memory" );                                 \
})

/*!
 * @brief vector magnitude squared(vabs2)
 * 
 * @param vd vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, 
 *        it is uimm3, refer to dspv_source_m1_t
 * 
 * @result vd = abs2(vs1.m1), for example, abs2(a+b*i) = a^2 + b^2
 */
#define dspv_vabs2(vd, vs1, m1)                                               \
({                                                                            \
    __asm__ __volatile__("vabs2 " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0"    \
                 : : "i" (m1) : "memory" );                                   \
})

/*!
 * @brief vector negative magnitude squared(vabs2)
 * 
 * @param vd vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, 
 *        it is uimm3, refer to dspv_source_m1_t
 * 
 * @result vd = -abs2(vs1.m1), for example, -abs2(a+b*i) = -(a^2 + b^2)
 */
#define dspv_vnabs2(vd, vs1, m1)                                              \
({                                                                            \
    __asm__ __volatile__("vnabs2 " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0"   \
                 : : "i" (m1) : "memory" );                                   \
})

/*!
 * @brief vector magnitude squared accumulate(vabs2a)
 * 
 * @param vd vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, 
 *        it is uimm3, refer to dspv_source_m1_t
 * 
 * @result vd = abs2(vs1.m1) + accumulator
 */
#define dspv_vabs2a(vd, vs1, m1)                                              \
({                                                                            \
    __asm__ __volatile__("vabs2a " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0"   \
                 : : "i" (m1) : "memory" );                                   \
})

/*!
 * @brief vector negative magnitude squared accumulate(vnabs2a)
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, it is uimm3, 
 *            refer to dspv_source_m1_t
 * 
 * @result vd = -abs2(vs1.m1) + accumulator
 */
#define dspv_vnabs2a(vd, vs1, m1)                                            \
({                                                                           \
    __asm__ __volatile__("vnabs2a " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0" \
                 : : "i" (m1) : "memory" );                                  \
})

/*!
 * @brief vector index udpate(vindexu)
 * 
 * @param px vector source operand
 *        it could be one of p0- to p7- or p0+ to p7+
 * 
 * @result vindexu px+, px.index += px.step0, same as ptr++ in C++
 *         vindexu px-, px.index += px.step1, same as ptr-- in c++
 */
#define dspv_vindexu(px)                                            \
({                                                                  \
    __asm__ __volatile__("vindexu " __ASM_STR(px) : : : "memory" ); \
})

/*!
 * @brief vector multiply NCO(vmul_nco)
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, it is uimm3, 
 *            refer to dspv_source_m1_t
 * @param nco numerically controlled oscillator, it is uimm3, refer to dspv_nco_t
 * 
 * @result vd = vs1.m1 * nco
 */
#define dspv_vmul_nco(vd, vs1, m1, nco)                                \
({                                                                     \
    __asm__ __volatile__("vmul_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) \
                 ", %0, %1" : : "i" (m1), "i" (nco) : "memory" );      \
})

/*!
 * @brief vector negative multiply NCO(vnmul_nco)
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, it is uimm3
 *            refer to dspv_source_m1_t
 * @param nco numerically controlled oscillator, it is uimm3, refer to dspv_nco_t
 * 
 * @result vd = -(vs1.m1 * nco)
 */
#define dspv_vnmul_nco(vd, vs1, m1, nco)                                \
({                                                                      \
    __asm__ __volatile__("vnmul_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) \
                ", %0, %1" : : "i" (m1), "i" (nco) : "memory" );        \
})

/*!
 * @brief vector multiply accumulate NCO(vmula_nco)
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, it is uimm3,
 *            refer to dspv_source_m1_t
 * @param nco numerically controlled oscillator, it is uimm3, refer to dspv_nco_t
 * 
 * @result vd = vs1.m1 * nco + accumulator
 */
#define dspv_vmula_nco(vd, vs1, m1, nco)                                \
({                                                                      \
    __asm__ __volatile__("vmula_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) \
                ", %0, %1" : : "i" (m1), "i" (nco) : "memory" );        \
})

/*!
 * @brief vector negative multiply accumulate NCO(vnmula_nco)
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand
 * @param m1  index for modifier applied to the vs1, it is uimm3, 
 *            refer to dspv_source_m1_t
 * @param nco numerically controlled oscillator, it is uimm3, refer to dspv_nco_t
 * 
 * @result vd = -(vs1.m1 * nco) + accumulator
 */
#define dspv_vnmula_nco(vd, vs1, m1, nco)                                \
({                                                                       \
    __asm__ __volatile__("vnmula_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) \
                  ", %0, %1" : : "i" (m1), "i" (nco) : "memory" );       \
})
/*!
 * @}
 */ /* end of group DSPV_instruction_with_one_source_operation */

/* ----------------------------------------------------------------------------
   -- DSP-V Vector Instructions with 2 Source Operands
   ---------------------------------------------------------------------------- */
/*!
 * @addtogroup DSPV_instruction_with_two_source_operation
 * @{
 */
/*!
 * @brief vector add
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3, 
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3,
 *            refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands 
 *       before the math operation
 * 
 * @result vd = vs1.m1 + vs2.m2
 */
#define dspv_vadd(vd, vs1, m1, vs2, m2)                                     \
({                                                                          \
    __asm__ __volatile__("vadd " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, " \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");    \
})

/*!
 * @brief vector negative subtract
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3,
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3,
 *            refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands before the math operation
 * @result vd = -(vs1.m1 - vs2.m2)
 */
#define dspv_vnsub(vd, vs1, m1, vs2, m2)                                     \
({                                                                           \
    __asm__ __volatile__("vnsub " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, " \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");     \
})

/*!
 * @brief vector subtract
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3,
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3,
 *            refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands 
 *       before the math operation
 * 
 * @result vd = (vs1.m1 - vs2.m2)
 */
#define dspv_vsub(vd, vs1, m1, vs2, m2)                                     \
({                                                                          \
    __asm__ __volatile__("vsub " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, " \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");    \
})

/*!
 * @brief vector negative add
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3,
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3,
 *        refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands
 *       before the math operation
 * @result vd = -(vs1.m1 + vs2.m2)
 */
#define dspv_vnadd(vd, vs1, m1, vs2, m2)                                     \
({                                                                           \
    __asm__ __volatile__("vnadd " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, " \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");     \
})

/*!
 * @brief vector add accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3,
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3,
 *            refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands
 *       before the math operation
 * @result vd = (vs1.m1 + vs2.m2) + accumulator
 */
#define dspv_vadda(vd, vs1, m1, vs2, m2)                                      \
({                                                                            \
    __asm__ __volatile__("vadda " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, "  \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");      \
})

/*!
 * @brief vector negative subtract accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3,
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3,
 *            refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands
 *       before the math operation
 * 
 * @result vd = -(vs1.m1 - vs2.m2) + accumulator
 */
#define dspv_vnsuba(vd, vs1, m1, vs2, m2)                                     \
({                                                                            \
    __asm__ __volatile__("vnsuba " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, " \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");      \
})

/*!
 * @brief vector subtract accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3,
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3,
 *            refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands
 *       before the math operation
 * 
 * @result vd = (vs1.m1 - vs2.m2) + accumulator
 */
#define dspv_vsuba(vd, vs1, m1, vs2, m2)                                      \
({                                                                            \
    __asm__ __volatile__("vsuba " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, "  \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");      \
})

/*!
 * @brief vector negative add accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3,
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3,
 *            refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands
 *       before the math operation
 * 
 * @result vd = -(vs1.m1 + vs2.m2) + accumulator
 */
#define dspv_vnadda(vd, vs1, m1, vs2, m2)                                     \
({                                                                            \
    __asm__ __volatile__("vnadda " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, " \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");      \
})

/*!
 * @brief vector multipy
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3,
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3,
 *            refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands
 *       before the math operation
 * 
 * @result vd = vs1.m1 * vs2.m2
 */
#define dspv_vmul(vd, vs1, m1, vs2, m2)                                       \
({                                                                            \
    __asm__ __volatile__("vmul " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, "   \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");      \
})

/*!
 * @brief vector negative multipy
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3,
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3,
 *            refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands
 *       before the math operation
 * @result vd = -(vs1.m1 * vs2.m2)
 */
#define dspv_vnmul(vd, vs1, m1, vs2, m2)                                      \
({                                                                            \
    __asm__ __volatile__("vnmul " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, "  \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");      \
})

/*!
 * @brief vector multipy accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3,
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3,
 *            refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands
 *       before the math operation
 * @result vd = (vs1.m1 * vs2.m2) + accumulator
 */
#define dspv_vmula(vd, vs1, m1, vs2, m2)                                      \
({                                                                            \
    __asm__ __volatile__("vmula " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, "  \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");      \
})

/*!
 * @brief vector negative multipy accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3, 
 *            refer to dspv_source_m1_t
 * @param m2  index for modifier applied to the vs2, it is uimm3, 
 *            refer to dspv_source_m2_t
 * 
 * @note modifers m1 and m2 are applied to the source operands before the math operation
 * @result vd = -(vs1.m1 * vs2.m2) + accumulator
 */
#define dspv_vnmula(vd, vs1, m1, vs2, m2)                                     \
({                                                                            \
    __asm__ __volatile__("vnmula " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, " \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (m2) : "memory");      \
})

/*!
 * @brief vector multiply with sau2
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, it is uimm3, 
 *            refer to dspv_source_m1_t
 * @param sau2  Index for SAU operation applied to the vs2 source operand, 
 *            uimm2, refer to dspv_source_sau2_t
 * 
 * @note modifers m1 and sau2 are applied to the source operands 
 *       before the math operation
 * @result vd = vs1.m1 * vs2.sau2
 */
#define dspv_vmuls(vd, vs1, m1, vs2, sau2)                                    \
({                                                                            \
    __asm__ __volatile__("vmuls " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, "  \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (sau2) : "memory");    \
})

/*!
 * @brief vector negative multiply with sau2
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, uimm3, 
 *            refer to dspv_source_m1_t
 * @param sau2  Index for SAU operation applied to the vs2 source operand, 
 *            uimm2, refer to dspv_source_sau2_t
 * 
 * @note modifers m1 and sau2 are applied to the source operands 
 *       before the math operation
 * @result vd = -(vs1.m1 * vs2.sau2)
 */
#define dspv_vnmuls(vd, vs1, m1, vs2, sau2)                                   \
({                                                                            \
    __asm__ __volatile__("vnmuls " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, " \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (sau2) : "memory");    \
})

/*!
 * @brief vector multiply with sau2 accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, uimm3, 
 *            refer to dspv_source_m1_t
 * @param sau2  Index for SAU operation applied to the vs2 source operand, 
 *            uimm2, refer to dspv_source_sau2_t
 * 
 * @note modifers m1 and sau2 are applied to the source operands 
 *       before the math operation
 * @result vd = (vs1.m1 * vs2.sau2) + accumulator
 */
#define dspv_vmulsa(vd, vs1, m1, vs2, sau2)                                   \
({                                                                            \
    __asm__ __volatile__("vmulsa " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, " \
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (sau2) : "memory");    \
})

/*!
 * @brief vector negative multiply with sau2 accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param m1  index for modifier applied to the vs1, uimm3, 
 *            refer to dspv_source_m1_t
 * @param sau2  Index for SAU operation applied to the vs2 source operand, 
 *            uimm2, refer to dspv_source_sau2_t
 * 
 * @note modifers m1 and sau2 are applied to the source operands 
 *       before the math operation
 * @result vd = -(vs1.m1 * vs2.sau2) + accumulator
 */
#define dspv_vnmulsa(vd, vs1, m1, vs2, sau2)                                  \
({                                                                            \
    __asm__ __volatile__("vnmulsa " __ASM_STR(vd) ", " __ASM_STR(vs1) ", %0, "\
               __ASM_STR(vs2) ", %1" : : "i" (m1), "i" (sau2) : "memory");    \
})

/*!
 * @brief vector fused add-multiply NCO
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param nco index for NCO operand, uimm3, refer to dspv_nco_t
 * 
 * @result vd = (vs1 * vs2) * nco
 */
#define dspv_vfam_nco(vd, vs1, vs2, nco)                                      \
({                                                                            \
    __asm__ __volatile__("vfam_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "   \
               __ASM_STR(vs2) ", %0" : : "i" (nco) : "memory");               \
})

/*!
 * @brief vector negative fused subtract-multiply NCO
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param nco index for NCO operand, uimm3, refer to dspv_nco_t
 * 
 * @result vd = -(vs1 - vs2) * nco
 */
#define dspv_vnfsm_nco(vd, vs1, vs2, nco)                                     \
({                                                                            \
    __asm__ __volatile__("vnfsm_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "  \
               __ASM_STR(vs2) ", %0" : : "i" (nco) : "memory");               \
})

/*!
 * @brief vector fused subtract-multiply NCO
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param nco index for NCO operand, uimm3, refer to dspv_nco_t
 * 
 * @result vd = (vs1 - vs2) * nco
 */
#define dspv_vfsm_nco(vd, vs1, vs2, nco)                                      \
({                                                                            \
    __asm__ __volatile__("vfsm_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "   \
               __ASM_STR(vs2) ", %0" : : "i" (nco) : "memory");               \
})

/*!
 * @brief vector negative fused add-multiply NCO
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param nco index for NCO operand, uimm3, refer to dspv_nco_t
 * 
 * @result vd = -(vs1 + vs2) * nco
 */
#define dspv_vnfam_nco(vd, vs1, vs2, nco)                                     \
({                                                                            \
    __asm__ __volatile__("vnfam_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "  \
               __ASM_STR(vs2) ", %0" : : "i" (nco) : "memory");               \
})

/*!
 * @brief vector fused add-multiply accumulate NCO
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param nco index for NCO operand, uimm3, refer to dspv_nco_t
 * 
 * @result vd = (vs1 + vs2) * nco + accumulator
 */
#define dspv_vfama_nco(vd, vs1, vs2, nco)                                     \
({                                                                            \
    __asm__ __volatile__("vfama_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "  \
               __ASM_STR(vs2) ", %0" : : "i" (nco) : "memory");               \
})

/*!
 * @brief vector negative fused subtract-multiply accumulate NCO
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param nco index for NCO operand, uimm3, refer to dspv_nco_t
 * 
 * @result vd = -(vs1 - vs2) * nco + accumulator
 */
#define dspv_vnfsma_nco(vd, vs1, vs2, nco)                                    \
({                                                                            \
    __asm__ __volatile__("vnfsma_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) ", " \
               __ASM_STR(vs2) ", %0" : : "i" (nco) : "memory");               \
})

/*!
 * @brief vector fused subtract-multiply accumulate NCO
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param nco index for NCO operand, uimm3, refer to dspv_nco_t
 * 
 * @result vd = (vs1 - vs2) * nco + accumulator
 */
#define dspv_vfsma_nco(vd, vs1, vs2, nco)                                     \
({                                                                            \
    __asm__ __volatile__("vfsma_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "  \
               __ASM_STR(vs2) ", %0" : : "i" (nco) : "memory");               \
})

/*!
 * @brief vector negative fused add-multiply accumulate NCO
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param nco index for NCO operand, uimm3, refer to dspv_nco_t
 * 
 * @result vd = -(vs1 + vs2) * nco + accumulator
 */
#define dspv_vnfama_nco(vd, vs1, vs2, nco)                                    \
({                                                                            \
    __asm__ __volatile__("vnfama_nco " __ASM_STR(vd) ", " __ASM_STR(vs1) ", " \
               __ASM_STR(vs2) ", %0" : : "i" (nco) : "memory");               \
})

/*!
 * @}
 */ /* end of group DSPV_instruction_with_two_source_operation */

/* ----------------------------------------------------------------------------
   -- DSP-V Vector Instructions with 3 Source Operands
   ---------------------------------------------------------------------------- */
/*!
 * @addtogroup DSPV_instruction_with_three_source_operation
 * @{
 */

/*!
 * @brief vector fused add-multiply
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = (vs1 + vs2) * vs3
 */
#define dspv_vfam(vd, vs1, vs2, vs3)                                          \
({                                                                            \
    __asm__ __volatile__("vfam " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "       \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @brief vector negative fused subtract-multiply
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = -(vs1 - vs2) * vs3
 */
#define dspv_vnfsm(vd, vs1, vs2, vs3)                                         \
({                                                                            \
    __asm__ __volatile__("vnfsm " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "      \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @brief vector fused subtract-multiply
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = (vs1 - vs2) * vs3
 */
#define dspv_vfsm(vd, vs1, vs2, vs3)                                          \
({                                                                            \
    __asm__ __volatile__("vfsm " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "       \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @brief vector negative fused add-multiply
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = -(vs1 + vs2) * vs3
 */
#define dspv_vnfam(vd, vs1, vs2, vs3)                                         \
({                                                                            \
    __asm__ __volatile__("vnfam " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "      \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @brief vector fused add-multiply accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = (vs1 + vs2) * vs3 + accumulator
 */
#define dspv_vfama(vd, vs1, vs2, vs3)                                         \
({                                                                            \
    __asm__ __volatile__("vfama " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "      \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @brief vector negative fused subtract-multiply accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = -(vs1 - vs2) * vs3 + accumulator
 */
#define dspv_vnfsma(vd, vs1, vs2, vs3)                                        \
({                                                                            \
    __asm__ __volatile__("vnfsma " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "     \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @brief vector fused subtract-multiply accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = (vs1 - vs2) * vs3 + accumulator
 */
#define dspv_vfsma(vd, vs1, vs2, vs3)                                         \
({                                                                            \
    __asm__ __volatile__("vfsma " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "      \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @brief vector negative fused add-multiply accumulate
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = -(vs1 + vs2) * vs3 + accumulator
 */
#define dspv_vnfama(vd, vs1, vs2, vs3)                                        \
({                                                                            \
    __asm__ __volatile__("vnfama " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "     \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @brief vector multiply-add
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = (vs1 * vs2) + vs3
 */
#define dspv_vmad(vd, vs1, vs2, vs3)                                          \
({                                                                            \
    __asm__ __volatile__("vmad " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "       \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @brief vector negative multiply-sub
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = -(vs1*vs2 - vs3)
 */
#define dspv_vnmsub(vd, vs1, vs2, vs3)                                        \
({                                                                            \
    __asm__ __volatile__("vnmsub " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "     \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @brief vector multiply-sub
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = (vs1*vs2 - vs3)
 */
#define dspv_vmsub(vd, vs1, vs2, vs3)                                         \
({                                                                            \
    __asm__ __volatile__("vmsub " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "      \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @brief vector negative multiply-add
 * 
 * @param vd  vector destination operand
 * @param vs1 vector source operand1
 * @param vs2 vector source operand2
 * @param vs3 vector source operand3
 * 
 * @result vd = -(vs1*vs2 + vs3)
 */
#define dspv_vnmad(vd, vs1, vs2, vs3)                                         \
({                                                                            \
    __asm__ __volatile__("vnmad " __ASM_STR(vd) ", " __ASM_STR(vs1) ", "      \
                __ASM_STR(vs2) ", " __ASM_STR(vs3) : : : "memory");           \
})

/*!
 * @}
 */ /* end of group DSPV_instruction_with_three_source_operation */

#ifdef __cplusplus
}
#endif

/*! @} */

#endif /* RISCV_XZDSPV_H_ */
