/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rdp_core.h                                              *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
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

#ifndef M64P_RDP_RDP_CORE_H
#define M64P_RDP_RDP_CORE_H

#include <stdint.h>

#include "fb.h"

struct r4300_core;
struct ri_controller;
struct rsp_core;

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


struct rdp_core
{
    uint32_t dpc_regs[DPC_REGS_COUNT];
    uint32_t dps_regs[DPS_REGS_COUNT];

    struct fb fb;

    struct r4300_core* r4300;
    struct rsp_core* sp;
    struct ri_controller* ri;
};

static uint32_t dpc_reg(uint32_t address)
{
    return (address & 0xffff) >> 2;
}

static uint32_t dps_reg(uint32_t address)
{
    return (address & 0xffff) >> 2;
}

void connect_rdp(struct rdp_core* dp,
                 struct r4300_core* r4300,
                 struct rsp_core* sp,
                 struct ri_controller* ri);

void init_rdp(struct rdp_core* dp);

int read_dpc_regs(void* opaque, uint32_t address, uint32_t* value);
int write_dpc_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

int read_dps_regs(void* opaque, uint32_t address, uint32_t* value);
int write_dps_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void rdp_interrupt_event(struct rdp_core* dp);

#endif
