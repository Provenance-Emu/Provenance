/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - pi_controller.h                                         *
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

#ifndef M64P_DEVICE_RCP_PI_PI_CONTROLLER_H
#define M64P_DEVICE_RCP_PI_PI_CONTROLLER_H

#include <stddef.h>
#include <stdint.h>

#include "osal/preproc.h"

struct device;
struct mi_controller;
struct ri_controller;
struct rdp_core;

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

struct pi_dma_handler
{
    unsigned int (*dma_read)(void* opaque, const uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length);
    unsigned int (*dma_write)(void* opaque, uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length);
};

typedef void (*pi_dma_handler_getter)(struct device* dev, uint32_t address, void** opaque, const struct pi_dma_handler** handler);

struct pi_controller
{
    uint32_t regs[PI_REGS_COUNT];

    struct device* dev;
    pi_dma_handler_getter get_pi_dma_handler;

    struct mi_controller* mi;
    struct ri_controller* ri;
    struct rdp_core* dp;
};

static osal_inline uint32_t pi_reg(uint32_t address)
{
    return (address & 0xffff) >> 2;
}



void init_pi(struct pi_controller* pi,
             struct device* dev, pi_dma_handler_getter get_pi_dma_handler,
             struct mi_controller* mi,
             struct ri_controller* ri,
             struct rdp_core* dp);

void poweron_pi(struct pi_controller* pi);

void read_pi_regs(void* opaque, uint32_t address, uint32_t* value);
void write_pi_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void pi_end_of_dma_event(void* opaque);

#endif
