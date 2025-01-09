/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - vi_controller.h                                         *
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

#ifndef M64P_DEVICE_RCP_VI_VI_CONTROLLER_H
#define M64P_DEVICE_RCP_VI_VI_CONTROLLER_H

#include <stdint.h>
#include "api/m64p_types.h"
#include "osal/preproc.h"

struct mi_controller;
struct rdp_core;

enum vi_registers
{
    VI_STATUS_REG,
    VI_ORIGIN_REG,
    VI_WIDTH_REG,
    VI_V_INTR_REG,
    VI_CURRENT_REG,
    VI_BURST_REG,
    VI_V_SYNC_REG,
    VI_H_SYNC_REG,
    VI_LEAP_REG,
    VI_H_START_REG,
    VI_V_START_REG,
    VI_V_BURST_REG,
    VI_X_SCALE_REG,
    VI_Y_SCALE_REG,
    VI_REGS_COUNT
};

struct vi_controller
{
    uint32_t regs[VI_REGS_COUNT];
    unsigned int field;
    unsigned int delay;
    unsigned int next_vi;

    unsigned int clock;
    unsigned int expected_refresh_rate;
    unsigned int count_per_scanline;

    struct mi_controller* mi;
    struct rdp_core* dp;
};

static osal_inline uint32_t vi_reg(uint32_t address)
{
    return (address & 0xffff) >> 2;
}


unsigned int vi_clock_from_tv_standard(m64p_system_type tv_standard);
unsigned int vi_expected_refresh_rate_from_tv_standard(m64p_system_type tv_standard);

void init_vi(struct vi_controller* vi, unsigned int clock, unsigned int expected_refresh_rate,
             struct mi_controller* mi, struct rdp_core* dp);

void poweron_vi(struct vi_controller* vi);

void read_vi_regs(void* opaque, uint32_t address, uint32_t* value);
void write_vi_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void vi_vertical_interrupt_event(void* opaque);

#endif
