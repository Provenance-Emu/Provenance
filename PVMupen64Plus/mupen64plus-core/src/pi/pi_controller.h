/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - pi_controller.h                                         *
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

#ifndef M64P_PI_PI_CONTROLLER_H
#define M64P_PI_PI_CONTROLLER_H

#include <stddef.h>
#include <stdint.h>

#include "cart_rom.h"
#include "flashram.h"
#include "sram.h"

struct r4300_core;
struct ri_controller;

enum pi_registers
{
    PI_DRAM_ADDR_REG,
    PI_CART_ADDR_REG,
    PI_RD_LEN_REG,
    PI_WR_LEN_REG,
    PI_STATUS_REG,
    PI_BSD_DOM1_LAT_REG,
    PI_BSD_DOM1_PWD_REG,
    PI_BSD_DOM1_PGS_REG,
    PI_BSD_DOM1_RLS_REG,
    PI_BSD_DOM2_LAT_REG,
    PI_BSD_DOM2_PWD_REG,
    PI_BSD_DOM2_PGS_REG,
    PI_BSD_DOM2_RLS_REG,
    PI_REGS_COUNT
};

struct pi_controller
{
    uint32_t regs[PI_REGS_COUNT];

    struct cart_rom cart_rom;
    struct flashram flashram;
    struct sram sram;

    int use_flashram;

    struct r4300_core* r4300;
    struct ri_controller* ri;
};

static uint32_t pi_reg(uint32_t address)
{
    return (address & 0xffff) >> 2;
}


void connect_pi(struct pi_controller* pi,
                struct r4300_core* r4300,
                struct ri_controller* ri,
                uint8_t* rom, size_t rom_size);

void init_pi(struct pi_controller* pi);

int read_pi_regs(void* opaque, uint32_t address, uint32_t* value);
int write_pi_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void pi_end_of_dma_event(struct pi_controller* pi);

#endif
