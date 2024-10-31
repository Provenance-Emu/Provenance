/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - si_controller.c                                         *
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

#include "si_controller.h"

#include <string.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "device/memory/memory.h"
#include "device/pif/pif.h"
#include "device/r4300/r4300_core.h"
#include "device/rcp/mi/mi_controller.h"
#include "device/rcp/ri/ri_controller.h"
#include "device/rdram/rdram.h"
#include "osal/preproc.h"

enum
{
    /* SI_STATUS - read */
    SI_STATUS_DMA_BUSY  = 0x0001,
    SI_STATUS_RD_BUSY   = 0x0002,
    SI_STATUS_DMA_ERROR = 0x0008,
    SI_STATUS_INTERRUPT = 0x1000,
};

static int validate_dma(struct si_controller* si, uint32_t reg)
{
    if ((si->regs[reg] & 0x1fffffff) != 0x1fc007c0)
    {
        DebugMessage(M64MSG_ERROR, "Unknown SI DMA PIF address: %08x", si->regs[reg]);
        return 0;
    }

    /* if DMA already busy, error, and ignore request */
    if (si->regs[SI_STATUS_REG] & SI_STATUS_DMA_BUSY) {
        si->regs[SI_STATUS_REG] |= SI_STATUS_DMA_ERROR;
        return 0;
    }

    return 1;
}

static void copy_pif_rdram(struct si_controller* si)
{
    size_t i;
    /* DRAM address must be word-aligned */
    uint32_t dram_addr = si->regs[SI_DRAM_ADDR_REG] & ~UINT32_C(3);

    uint32_t* pif_ram = (uint32_t*)si->pif->ram;
    uint32_t* dram = (uint32_t*)(&si->ri->rdram->dram[rdram_dram_address(dram_addr)]);

    if (si->dma_dir == SI_DMA_WRITE) {
        for(i = 0; i < (PIF_RAM_SIZE / 4); ++i) {
            pif_ram[i] = fromhl(dram[i]);
        }
    }
    else if (si->dma_dir == SI_DMA_READ) {
        for(i = 0; i < (PIF_RAM_SIZE / 4); ++i) {
            dram[i] = tohl(pif_ram[i]);
        }
    }
}

static void dma_si_write(struct si_controller* si)
{
    if (!validate_dma(si, SI_PIF_ADDR_WR64B_REG))
        return;

    si->dma_dir = SI_DMA_WRITE;

    copy_pif_rdram(si);

    cp0_update_count(si->mi->r4300);
    si->regs[SI_STATUS_REG] |= SI_STATUS_DMA_BUSY;
    add_interrupt_event(&si->mi->r4300->cp0, SI_INT, si->dma_duration + add_random_interrupt_time(si->mi->r4300));
}

static void dma_si_read(struct si_controller* si)
{
    if (!validate_dma(si, SI_PIF_ADDR_RD64B_REG))
        return;

    si->dma_dir = SI_DMA_READ;

    update_pif_ram(si->pif);

    cp0_update_count(si->mi->r4300);
    si->regs[SI_STATUS_REG] |= SI_STATUS_DMA_BUSY;
    add_interrupt_event(&si->mi->r4300->cp0, SI_INT, si->dma_duration + add_random_interrupt_time(si->mi->r4300));
}

void init_si(struct si_controller* si,
             unsigned int dma_duration,
             struct mi_controller* mi,
             struct pif* pif,
             struct ri_controller* ri)
{
    si->dma_duration = dma_duration;
    si->mi = mi;
    si->pif = pif;
    si->ri = ri;
}

void poweron_si(struct si_controller* si)
{
    memset(si->regs, 0, SI_REGS_COUNT*sizeof(uint32_t));
    si->dma_dir = SI_NO_DMA;
}


void read_si_regs(void* opaque, uint32_t address, uint32_t* value)
{
    struct si_controller* si = (struct si_controller*)opaque;
    uint32_t reg = si_reg(address);

    *value = si->regs[reg];
}

void write_si_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct si_controller* si = (struct si_controller*)opaque;
    uint32_t reg = si_reg(address);

    switch (reg)
    {
    case SI_DRAM_ADDR_REG:
        masked_write(&si->regs[SI_DRAM_ADDR_REG], value, mask);
        break;

    case SI_PIF_ADDR_RD64B_REG:
        masked_write(&si->regs[SI_PIF_ADDR_RD64B_REG], value, mask);
        dma_si_read(si);
        break;

    case SI_PIF_ADDR_WR64B_REG:
        masked_write(&si->regs[SI_PIF_ADDR_WR64B_REG], value, mask);
        dma_si_write(si);
        break;

    case SI_STATUS_REG:
        /* clear si interrupt */
        si->regs[SI_STATUS_REG] &= ~SI_STATUS_INTERRUPT;
        clear_rcp_interrupt(si->mi, MI_INTR_SI);
        break;
    }
}

void si_end_of_dma_event(void* opaque)
{
    struct si_controller* si = (struct si_controller*)opaque;

    /* DRAM -> PIF : start the PIF processing */
    if (si->dma_dir == SI_DMA_WRITE)
        process_pif_ram(si->pif);
    /* PIF -> DRAM : copy to RDRAM */
    else if (si->dma_dir == SI_DMA_READ)
        copy_pif_rdram(si);

    /* end DMA */
    si->dma_dir = SI_NO_DMA;
    si->regs[SI_STATUS_REG] &= ~SI_STATUS_DMA_BUSY;

    /* raise si interrupt */
    si->regs[SI_STATUS_REG] |= SI_STATUS_INTERRUPT;
    raise_rcp_interrupt(si->mi, MI_INTR_SI);
}

