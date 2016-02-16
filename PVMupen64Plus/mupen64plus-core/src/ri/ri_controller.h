/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - ri_controller.h                                         *
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

#ifndef M64P_RI_RI_CONTROLLER_H
#define M64P_RI_RI_CONTROLLER_H

#include <stddef.h>
#include <stdint.h>

#include "rdram.h"

enum ri_registers
{
    RI_MODE_REG,
    RI_CONFIG_REG,
    RI_CURRENT_LOAD_REG,
    RI_SELECT_REG,
    RI_REFRESH_REG,
    RI_LATENCY_REG,
    RI_ERROR_REG,
    RI_WERROR_REG,
    RI_REGS_COUNT
};

struct ri_controller
{
    uint32_t regs[RI_REGS_COUNT];

    struct rdram rdram;
};

static uint32_t ri_reg(uint32_t address)
{
    return (address & 0xffff) >> 2;
}

void connect_ri(struct ri_controller* ri,
                uint32_t* dram,
                size_t dram_size);

void init_ri(struct ri_controller* ri);

int read_ri_regs(void* opaque, uint32_t address, uint32_t* value);
int write_ri_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

#endif
