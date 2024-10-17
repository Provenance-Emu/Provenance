/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - m64282fp.h                                              *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2017 Bobby Smiles                                       *
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

#ifndef M64P_DEVICE_GB_M64282FP_H
#define M64P_DEVICE_GB_M64282FP_H

#include <stdint.h>

enum m64282fp_registers
{
    /* TODO: use pretty names for registers */
    M64282FP_REGS_COUNT = 0x36
};

struct m64282fp
{
    uint8_t regs[M64282FP_REGS_COUNT];
};

void init_m64282fp(struct m64282fp* cam);
void poweron_m64282fp(struct m64282fp* cam);

uint8_t read_m64282fp_regs(struct m64282fp* cam, unsigned int reg);
void write_m64282fp_regs(struct m64282fp* cam, unsigned int reg, uint8_t value);

#endif
