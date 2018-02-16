/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rdram.c                                                 *
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

#include "rdram.h"

#include <string.h>

#include "memory/memory.h"
#include "ri_controller.h"

void connect_rdram(struct rdram* rdram,
                   uint32_t* dram,
                   size_t dram_size)
{
    rdram->dram = dram;
    rdram->dram_size = dram_size;
}

void init_rdram(struct rdram* rdram)
{
    memset(rdram->regs, 0, RDRAM_REGS_COUNT*sizeof(uint32_t));
    memset(rdram->dram, 0, rdram->dram_size);
}


int read_rdram_regs(void* opaque, uint32_t address, uint32_t* value)
{
    struct ri_controller* ri = (struct ri_controller*)opaque;
    uint32_t reg = rdram_reg(address);

    *value = ri->rdram.regs[reg];

    return 0;
}

int write_rdram_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct ri_controller* ri = (struct ri_controller*)opaque;
    uint32_t reg = rdram_reg(address);

    masked_write(&ri->rdram.regs[reg], value, mask);

    return 0;
}


int read_rdram_dram(void* opaque, uint32_t address, uint32_t* value)
{
    struct ri_controller* ri = (struct ri_controller*)opaque;
    uint32_t addr = rdram_dram_address(address);

    *value = ri->rdram.dram[addr];

    return 0;
}

int write_rdram_dram(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct ri_controller* ri = (struct ri_controller*)opaque;
    uint32_t addr = rdram_dram_address(address);

    masked_write(&ri->rdram.dram[addr], value, mask);

    return 0;
}

