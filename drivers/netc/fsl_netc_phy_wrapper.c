/*
 * Copyright 2023 NXP
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "fsl_netc_phy_wrapper.h"

void NETC_PHYWriteRegBits(
    netc_mdio_handle_t *handle, bool pcs, volatile uint16_t *reg, uint16_t mask, uint16_t val)
{
    uint8_t portAddr = pcs ? 0x0U : 0x10U;
    uint8_t devAddr  = getPhyDev(reg);
    uint16_t regAddr = getPhyReg(reg);
    uint16_t regValue;
    status_t status;

    status = NETC_MDIOC45Read(handle, portAddr, devAddr, regAddr, &regValue);
    assert(status == kStatus_Success);

    regValue &= ~mask;
    if (val != 0U)
    {
        regValue |= val;
    }

    status = NETC_MDIOC45Write(handle, portAddr, devAddr, regAddr, regValue);
    if (status != kStatus_Success)
    {
        assert(false);
    }
}

void NETC_PHYReadReg(netc_mdio_handle_t *handle, bool pcs, const volatile uint16_t *reg, uint16_t *val)
{
    uint8_t portAddr = pcs ? 0x0U : 0x10U;
    uint8_t devAddr  = getPhyDev(reg);
    uint16_t regAddr = getPhyReg(reg);
    status_t status;

    status = NETC_MDIOC45Read(handle, portAddr, devAddr, regAddr, val);
    if (status != kStatus_Success)
    {
        assert(false);
    }
}
