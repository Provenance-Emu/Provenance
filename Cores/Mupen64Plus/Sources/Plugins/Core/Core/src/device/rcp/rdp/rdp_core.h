/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rdp_core.h                                              *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2014 Bobby Smiles                                       *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef M64P_DEVICE_RCP_RDP_RDP_CORE_H
#define M64P_DEVICE_RCP_RDP_RDP_CORE_H

#include <stdint.h>

#include "fb.h"
#include "osal/preproc.h"

struct mi_controller;
struct rsp_core;

enum
{
    /* DPC status - read */
    DPC_STATUS_XBUS_DMEM_DMA = 0x001,
    DPC_STATUS_FREEZE        = 0x002,
    DPC_STATUS_FLUSH         = 0x004,
    DPC_STATUS_START_GCLK    = 0x008,
    DPC_STATUS_CBUF_READY    = 0x080,
    DPC_STATUS_END_VALID     = 0x200,
    DPC_STATUS_START_VALID   = 0x400,
    /* DPC status - write */
    DPC_CLR_XBUS_DMEM_DMA        = 0x001,
    DPC_SET_XBUS_DMEM_DMA        = 0x002,
    DPC_CLR_FREEZE               = 0x004,
    DPC_SET_FREEZE               = 0x008,
    DPC_CLR_FLUSH                = 0x010,
    DPC_SET_FLUSH                = 0x020,
    DPC_CLR_TMEM_CTR             = 0x040,
    DPC_CLR_PIPE_CTR             = 0x080,
    DPC_CLR_CMD_CTR              = 0x100,
    DPC_CLR_CLOCK_CTR            = 0x200
};

enum dpc_registers
{
    DPC_START_REG,
    DPC_END_REG,
    DPC_CURRENT_REG,
    DPC_STATUS_REG,
    DPC_CLOCK_REG,
    DPC_BUFBUSY_REG,
    DPC_PIPEBUSY_REG,
    DPC_TMEM_REG,
    DPC_REGS_COUNT
};

enum dps_registers
{
    DPS_TBIST_REG,
    DPS_TEST_MODE_REG,
    DPS_BUFTEST_ADDR_REG,
    DPS_BUFTEST_DATA_REG,
    DPS_REGS_COUNT
};

enum
{
    DELAY_DP_INT = 0x001,
    DELAY_UPDATESCREEN = 0x002
};

struct rdp_core
{
    uint32_t dpc_regs[DPC_REGS_COUNT];
    uint32_t dps_regs[DPS_REGS_COUNT];
    unsigned char do_on_unfreeze;

    struct fb fb;

    struct rsp_core* sp;
    struct mi_controller* mi;
};

static osal_inline uint32_t dpc_reg(uint32_t address)
{
    return (address & 0xffff) >> 2;
}

static osal_inline uint32_t dps_reg(uint32_t address)
{
    return (address & 0xffff) >> 2;
}

void init_rdp(struct rdp_core* dp,
              struct rsp_core* sp,
              struct mi_controller* mi,
              struct memory* mem,
              struct rdram* rdram,
              struct r4300_core* r4300);

void poweron_rdp(struct rdp_core* dp);

void read_dpc_regs(void* opaque, uint32_t address, uint32_t* value);
void write_dpc_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void read_dps_regs(void* opaque, uint32_t address, uint32_t* value);
void write_dps_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void rdp_interrupt_event(void* opaque);

#endif
