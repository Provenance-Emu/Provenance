/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - si_controller.h                                         *
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

#ifndef M64P_DEVICE_RCP_SI_SI_CONTROLLER_H
#define M64P_DEVICE_RCP_SI_SI_CONTROLLER_H

#include <stdint.h>

#include "osal/preproc.h"

struct mi_controller;
struct ri_controller;
struct pif;

enum si_dma_dir
{
    SI_NO_DMA,
    SI_DMA_READ,
    SI_DMA_WRITE
};

enum si_registers
{
    SI_DRAM_ADDR_REG,
    SI_PIF_ADDR_RD64B_REG,
    SI_R2_REG, /* reserved */
    SI_R3_REG, /* reserved */
    SI_PIF_ADDR_WR64B_REG,
    SI_R5_REG, /* reserved */
    SI_STATUS_REG,
    SI_REGS_COUNT
};

struct si_controller
{
    uint32_t regs[SI_REGS_COUNT];
    unsigned char dma_dir;

    unsigned int dma_duration;

    struct mi_controller* mi;
    struct pif* pif;
    struct ri_controller* ri;
};

static osal_inline uint32_t si_reg(uint32_t address)
{
    return (address & 0xffff) >> 2;
}


void init_si(struct si_controller* si,
             unsigned int dma_duration,
             struct mi_controller* mi,
             struct pif* pif,
             struct ri_controller* ri);

void poweron_si(struct si_controller* si);

void read_si_regs(void* opaque, uint32_t address, uint32_t* value);
void write_si_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void si_end_of_dma_event(void* opaque);

#endif
