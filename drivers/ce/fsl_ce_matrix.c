/*
 * Copyright 2024-2025 NXP
 * All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/*==========================================================================
Implementation file for CE wrapper/driver functions on ARM
==========================================================================*/

#include "fsl_ce_matrix.h"
#include "fsl_ce_cmd.h"

/*!
 * brief Calculates the sum of 2 real 16-bit integer (Q15) matrices.
 *
 * Computes C = A+B where A, B, C are an MxN real int16 matrices.
 * The matrices A, B, and C are assumed to be in the same formats.
 *
 * param pDst Pointer to real output matrix C (size MxN)
 * param pA Pointer to real input matrix A (size MxN)
 * param pB Pointer to real input matrix B (size MxN)
 * param M Number of rows of matrices A, B, C
 * param N Number of columns of matrices A, B, C
 *
 * return Command execution status.
 */
int32_t CE_MatrixAdd_Q15(int16_t *pDst, int16_t *pA, int16_t *pB, int32_t M, int32_t N)
{
    int32_t status;

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 2;
    cmdstruct.arg_ptr_array[0]   = (void *)pDst;
    cmdstruct.arg_ptr_array[1]   = (void *)pA;
    cmdstruct.arg_ptr_array[2]   = (void *)pB;
    cmdstruct.arg_param_array[0] = M;
    cmdstruct.arg_param_array[1] = N;

    status = CE_CmdAdd(kCE_Cmd_MAT_ADD_Q15, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Calculates the sum of 2 real 32-bit integer (Q31) matrices
 *
 * Computes C = A+B where A, B, C are an MxN real int32 matrices.
 * The matrices A, B, and C are assumed to be in the same formats.
 *
 * param pDst Pointer to real output matrix C (size MxN)
 * param pA Pointer to real input matrix A (size MxN)
 * param pB Pointer to real input matrix B (size MxN)
 * param M Number of rows of matrices A, B, C
 * param N Number of columns of matrices A, B, C
 *
 * return Command execution status.
 */
int32_t CE_MatrixAdd_Q31(int32_t *pDst, int32_t *pA, int32_t *pB, int32_t M, int32_t N)
{
    int32_t status;

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 2;
    cmdstruct.arg_ptr_array[0]   = (void *)pDst;
    cmdstruct.arg_ptr_array[1]   = (void *)pA;
    cmdstruct.arg_ptr_array[2]   = (void *)pB;
    cmdstruct.arg_param_array[0] = M;
    cmdstruct.arg_param_array[1] = N;

    status = CE_CmdAdd(kCE_Cmd_MAT_ADD_Q31, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Calculates the sum of 2 real 32-bit floating point matrices.
 *
 * Computes C = A+B where A, B, C are an MxN real float32 matrices.
 * The matrices A, B, and C are assumed to be in the same formats.
 *
 * param pDst Pointer to real output matrix C (size MxN)
 * param pA Pointer to real input matrix A (size MxN)
 * param pB Pointer to real input matrix B (size MxN)
 * param M Number of rows of matrices A, B, C
 * param N Number of columns of matrices A, B, C
 *
 * return Command execution status.
 */
int32_t CE_MatrixAdd_F32(float *pDst, float *pA, float *pB, int32_t M, int32_t N)
{
    int32_t status;

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 2;
    cmdstruct.arg_ptr_array[0]   = (void *)pDst;
    cmdstruct.arg_ptr_array[1]   = (void *)pA;
    cmdstruct.arg_ptr_array[2]   = (void *)pB;
    cmdstruct.arg_param_array[0] = M;
    cmdstruct.arg_param_array[1] = N;

    status = CE_CmdAdd(kCE_Cmd_MAT_ADD_F32, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Element wise multiply between two MxN matrices
 *
 * Elementwise multiplies two MxN matrices; matrices can be in either of row or
 * columns major formats.
 *
 * Data precision and format is as defined by the argument type
 *
 * param pDst Pointer to buffer for output matrix
 * param pA   Pointer to buffer for input matrix A
 * param pB   Pointer to buffer for input matrix B
 * param M    Number of rows for each input matrix
 * param N    Number of columns for each input matrix
 *
 * return Command execution status.
 */
int32_t CE_MatrixElemMul_F32(float *pDst, float *pA, float *pB, int32_t M, int32_t N)
{
    int32_t status;

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 2;
    cmdstruct.arg_ptr_array[0]   = (void *)pDst;
    cmdstruct.arg_ptr_array[1]   = (void *)pA;
    cmdstruct.arg_ptr_array[2]   = (void *)pB;
    cmdstruct.arg_param_array[0] = M;
    cmdstruct.arg_param_array[1] = N;

    status = CE_CmdAdd(kCE_Cmd_MAT_HADAMARDMULT_F32, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Matrix multiply between two MxN matrices
 *
 * Computes C = A*B where A is an MxN real float32 matrix, B is an NxP real float32
 * matrix and C is a MxP real float32 matrix. All matrices are assumed to be in row-major format.
 *
 * param pDst Pointer to buffer for output matrix [MxP]
 * param pA   Pointer to buffer for input matrix A [MxN]
 * param pB   Pointer to buffer for input matrix B [NxP]
 * param M    Number of rows for input matrix A
 * param N    Number of columns for input matrix A, or, Number of rows for input matrix B
 * param P    Number of columns for input matrix B
 *
 * Data precision and format is as defined by the argument type
 * note Limits on max value of N: For F32: N < 128; For CF32: N < 64
 *
 * return Command execution status.
 */
int32_t CE_MatrixMul_F32(float *pDst, float *pA, float *pB, int32_t M, int32_t N, int32_t P)
{
    int32_t status;

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 3;
    cmdstruct.arg_ptr_array[0]   = (void *)pDst;
    cmdstruct.arg_ptr_array[1]   = (void *)pA;
    cmdstruct.arg_ptr_array[2]   = (void *)pB;
    cmdstruct.arg_param_array[0] = M;
    cmdstruct.arg_param_array[1] = N;
    cmdstruct.arg_param_array[2] = P;

    status = CE_CmdAdd(kCE_Cmd_MAT_MULT_F32, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Calculates the product 2 complex 32-bit floating point matrices.
 *
 * Computes C = A*B where A is an MxN complex float32 matrix, B is an NxP complex
 * float32 matrix and C is a MxP complex float32 matrix. All matrices are assumed
 * to be in row-major format.
 *
 * param pDst Pointer to buffer for output matrix [MxP]
 * param pA   Pointer to buffer for input matrix A [MxN]
 * param pB   Pointer to buffer for input matrix B [NxP]
 * param M    Number of rows of matrix A
 * param N    Number of columns (rows) of matrix A (B)
 * param P    Number of columns of matrix B
 *
 * Data precision and format is as defined by the argument type
 * note Limits on max value of N: For F32: N < 128; For CF32: N < 64
 *
 * return Command execution status.
 */
int32_t CE_MatrixMul_CF32(float *pDst, float *pA, float *pB, int32_t M, int32_t N, int32_t P)
{
    int32_t status;

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 3;
    cmdstruct.arg_ptr_array[0]   = (void *)pDst;
    cmdstruct.arg_ptr_array[1]   = (void *)pA;
    cmdstruct.arg_ptr_array[2]   = (void *)pB;
    cmdstruct.arg_param_array[0] = M;
    cmdstruct.arg_param_array[1] = N;
    cmdstruct.arg_param_array[2] = P;

    status = CE_CmdAdd(kCE_Cmd_MAT_MULT_CF32, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Matrix Inversion
 *
 * Based on an user specified flag, calculates either
 *   \li Ainv = inv(A), or,
 *   \li Linv = inv(chol(A)),
 *
 * where chol() is the lower triangular Cholesky Decomposition of A.
 * A is a MxM complex Hermitian matrix.
 * A is expected to be in row major format and can either be packed (only
 * upper traingular elements) or full
 *
 * param[out] pAinv Pointer to buffer for output inverse matrix.
 * Only the upper triangular elements of the output matrix are written out. The
 * output is written in row major order. Output size is Mc*8 bytes.
 * Mc = *((1+M)*M)/2.
 * param[in] pA Pointer to buffer for input matrix A. If flag_packedInput=0,
 * MxM matrix expected in row major format. If flag_packedInput=1, Only
 * upper triangular part of A is expected in row major format (Mc CF32 elements).
 * param[in] pScratch Scratch memory of size (Mc*3)*8 bytes.
 * param M   Number of rows or columns of A
 * param flag_packedInput Flag indicating input matrix format.
 *   - 0: full matrix
 *   - 1: upper triangular part only
 * param flag_cholInv Flag indicating inverse type.
 *   - 0: Out = inv(A)
 *   - 1: Out = inv(chol(A))
 *
 * return Command execution status.
 */
int32_t CE_MatrixInvHerm_CF32(
    float *pAinv, float *pA, float *pScratch, int32_t M, uint8_t flag_packedInput, uint8_t flag_cholInv)
{
    int32_t status;

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 3;
    cmdstruct.arg_ptr_array[0]   = (void *)pAinv;
    cmdstruct.arg_ptr_array[1]   = (void *)pA;
    cmdstruct.arg_ptr_array[2]   = (void *)pScratch;
    cmdstruct.arg_param_array[0] = M;
    cmdstruct.arg_param_array[1] = (int32_t)flag_packedInput;
    cmdstruct.arg_param_array[2] = (int32_t)flag_cholInv;

    status = CE_CmdAdd(kCE_Cmd_MAT_INV_HERM_CF32, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Calculates the Cholesky Decomposition of a complex Hermitian matrix (in float32 precision).
 *
 * Computes the Cholesky Decomposition of a complex Hermitian 32-bit floating point MxM input matrix, that is:
 * L = chol(A), L is lower triangular matrix such that A = L*LH.
 * Input matrix is expected to be row major format and can either be packed (that is, only the upper
 * triangular elements are part of the input structure), or, as a full MxM matrix.
 * Only the lower diagonal part of the output matrix is written (since the output matrix is triangular).
 * The output format is also row major. Thus, total number of output elements is given by Mc, where:
 * Mc = (M+1)*M/2. The input, output and scratch buffers must be unique allocations.
 *
 * param pL Pointer to the Cholesky Decomposition output triangular matrix. Mc elements are written. (complex float32 data) in row major format
 * param pA Pointer to the MxM input matrix (or Mc element packed matrix) in row major format (complex float32 data)
 * param pScratch Pointer to a scratch buffer (minimum size Mc*8 bytes)
 * param M Number of rows or columns of input matrix A
 * param flag_packedInput Set to 0 if the input is a full matrix, or, set to 1 if the input is a packed upper triangular matrix.
 *
 * return Command execution status.
 */
int32_t CE_MatrixChol_CF32(float *pL, float *pA, float *pScratch, int32_t M, uint8_t flag_packedInput)
{
    int32_t status;

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 3;
    cmdstruct.n_param_args       = 2;
    cmdstruct.arg_ptr_array[0]   = (void *)pL;
    cmdstruct.arg_ptr_array[1]   = (void *)pA;
    cmdstruct.arg_ptr_array[2]   = (void *)pScratch;
    cmdstruct.arg_param_array[0] = M;
    cmdstruct.arg_param_array[1] = (int32_t)flag_packedInput;

    status = CE_CmdAdd(kCE_Cmd_MAT_CHOL_CF32, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}

/*!
 * brief Eigen Value Decompositions
 *
 * Calculates Eigen Value Decompositions of a MxM matrix.
 * Calculates [U, T] = evd(A) where A is a MxM complex Hermitian matrix, U is
 * the output matrix of eigen vectors, and T is the diagonal matrix of eigen
 * values.
 *
 * param pLambdaOut Pointer to buffer for output Eigen Vectors (MxM)
 * param pUout      Pointer to buffer with output Eigen Values (Mx1)
 * param pUin       Pointer to buffer for input matrix A
 * param M          Number of rows or columns of A
 * param pScratch   Scratch memory, the minimum scratch size required is (M x M x 4 + 360) x 4 bytes.
 * param tol        Tolerance specifying exit condition for the iterative computation
 * param max_iter   Upper bound on number of iterations for convergence of each Eigen value
 * param flag_packedInput Flag indicating input matrix format.
 *   - 0: full matrix
 *   - 1: upper triangular part only
 *
 * return Command execution status. Return the number of QR iterations executed in status[3] register.
 */
int32_t CE_MatrixEvdHerm_CF32(float *pLambdaOut,
                          float *pUout,
                          float *pUin,
                          float *pScratch,
                          int32_t M,
                          float tol,
                          int32_t max_iter,
                          uint8_t flag_packedInput)
{
    int32_t status;
    int32_t *ptemp = (int32_t *)&tol;

    ce_cmdstruct_t cmdstruct;
    cmdstruct.n_ptr_args         = 4;
    cmdstruct.n_param_args       = 4;
    cmdstruct.arg_ptr_array[0]   = (void *)pLambdaOut;
    cmdstruct.arg_ptr_array[1]   = (void *)pUout;
    cmdstruct.arg_ptr_array[2]   = (void *)pScratch;
    cmdstruct.arg_ptr_array[3]   = (void *)pUin;
    cmdstruct.arg_param_array[0] = M;
    cmdstruct.arg_param_array[1] = *ptemp;
    cmdstruct.arg_param_array[2] = max_iter;
    cmdstruct.arg_param_array[3] = (int32_t)flag_packedInput;

    status = CE_CmdAdd(kCE_Cmd_MAT_EVD_HERM_CF32, &cmdstruct);

    if (status == 0)
    {
        status = CE_CmdLaunch(0);
    }

    return status;
}
