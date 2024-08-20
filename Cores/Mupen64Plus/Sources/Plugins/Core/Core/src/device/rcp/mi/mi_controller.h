/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - mi_controller.h                                         *
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

#ifndef M64P_DEVICE_RCP_MI_MI_CONTROLLER_H
#define M64P_DEVICE_RCP_MI_MI_CONTROLLER_H

#include <stdint.h>

#include "osal/preproc.h"

struct r4300_core;

enum mi_registers
{
    MI_INIT_MODE_REG,
    MI_VERSION_REG,
    MI_INTR_REG,
    MI_INTR_MASK_REG,
    MI_REGS_COUNT
};


enum mi_intr
{
    MI_INTR_SP = 0x01,
    MI_INTR_SI = 0x02,
    MI_INTR_AI = 0x04,
    MI_INTR_VI = 0x08,
    MI_INTR_PI = 0x10,
    MI_INTR_DP = 0x20
};

struct mi_controller
{
    uint32_t regs[MI_REGS_COUNT];

    struct r4300_core* r4300;
};

static osal_inline uint32_t mi_reg(uint32_t address)
{
    return (address & 0xffff) >> 2;
}

void init_mi(struct mi_controller* mi, struct r4300_core* r4300);
void poweron_mi(struct mi_controller* mi);

void read_mi_regs(void* opaque, uint32_t address, uint32_t* value);
void write_mi_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void raise_rcp_interrupt(struct mi_controller* mi, uint32_t mi_intr);
void signal_rcp_interrupt(struct mi_controller* mi, uint32_t mi_intr);
void clear_rcp_interrupt(struct mi_controller* mi, uint32_t mi_intr);

#endif
