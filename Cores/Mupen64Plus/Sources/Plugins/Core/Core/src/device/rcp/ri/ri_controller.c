/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - ri_controller.c                                         *
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

#include "ri_controller.h"

#include <string.h>

#include "device/memory/memory.h"

void init_ri(struct ri_controller* ri, struct rdram* rdram)
{
    ri->rdram = rdram;
}

void poweron_ri(struct ri_controller* ri)
{
    memset(ri->regs, 0, RI_REGS_COUNT*sizeof(uint32_t));
}


void read_ri_regs(void* opaque, uint32_t address, uint32_t* value)
{
    struct ri_controller* ri = (struct ri_controller*)opaque;
    uint32_t reg = ri_reg(address);

    *value = ri->regs[reg];
}

void write_ri_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct ri_controller* ri = (struct ri_controller*)opaque;
    uint32_t reg = ri_reg(address);

    masked_write(&ri->regs[reg], value, mask);
}

