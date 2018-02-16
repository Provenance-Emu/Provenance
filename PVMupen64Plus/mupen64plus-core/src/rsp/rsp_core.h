/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rsp_core.h                                              *
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

#ifndef M64P_RSP_RSP_CORE_H
#define M64P_RSP_RSP_CORE_H

#include <stdint.h>

struct r4300_core;
struct rdp_core;
struct ri_controller;

enum { SP_MEM_SIZE = 0x2000 };

enum sp_registers
{
    SP_MEM_ADDR_REG,
    SP_DRAM_ADDR_REG,
    SP_RD_LEN_REG,
    SP_WR_LEN_REG,
    SP_STATUS_REG,
    SP_DMA_FULL_REG,
    SP_DMA_BUSY_REG,
    SP_SEMAPHORE_REG,
    SP_REGS_COUNT
};

enum sp_registers2
{
    SP_PC_REG,
    SP_IBIST_REG,
    SP_REGS2_COUNT
};


struct rsp_core
{
    uint32_t mem[SP_MEM_SIZE/4];
    uint32_t regs[SP_REGS_COUNT];
    uint32_t regs2[SP_REGS2_COUNT];

    struct r4300_core* r4300;
    struct rdp_core* dp;
    struct ri_controller* ri;
};

static uint32_t rsp_mem_address(uint32_t address)
{
    return (address & 0x1fff) >> 2;
}

static uint32_t rsp_reg(uint32_t address)
{
    return (address & 0xffff) >> 2;
}

static uint32_t rsp_reg2(uint32_t address)
{
    return (address & 0xffff) >> 2;
}

void connect_rsp(struct rsp_core* sp,
                 struct r4300_core* r4300,
                 struct rdp_core* dp,
                 struct ri_controller* ri);

void init_rsp(struct rsp_core* sp);

int read_rsp_mem(void* opaque, uint32_t address, uint32_t* value);
int write_rsp_mem(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

int read_rsp_regs(void* opaque, uint32_t address, uint32_t* value);
int write_rsp_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

int read_rsp_regs2(void* opaque, uint32_t address, uint32_t* value);
int write_rsp_regs2(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void do_SP_Task(struct rsp_core* sp);

void rsp_interrupt_event(struct rsp_core* sp);

#endif
