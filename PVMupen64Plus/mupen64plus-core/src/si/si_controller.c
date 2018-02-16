/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - si_controller.c                                         *
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

#include "si_controller.h"

#include <string.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "main/main.h"
#include "memory/memory.h"
#include "r4300/r4300_core.h"
#include "ri/ri_controller.h"


static void dma_si_write(struct si_controller* si)
{
    int i;

    if (si->regs[SI_PIF_ADDR_WR64B_REG] != 0x1FC007C0)
    {
        DebugMessage(M64MSG_ERROR, "dma_si_write(): unknown SI use");
        return;
    }

    for (i = 0; i < PIF_RAM_SIZE; i += 4)
    {
        *((uint32_t*)(&si->pif.ram[i])) = sl(si->ri->rdram.dram[(si->regs[SI_DRAM_ADDR_REG]+i)/4]);
    }

    update_pif_write(si);
    update_count();

    if (g_delay_si) {
        add_interupt_event(SI_INT, /*0x100*/0x900);
    } else {
        si->regs[SI_STATUS_REG] |= 0x1000; // INTERRUPT
        signal_rcp_interrupt(si->r4300, MI_INTR_SI);
    }
}

static void dma_si_read(struct si_controller* si)
{
    int i;

    if (si->regs[SI_PIF_ADDR_RD64B_REG] != 0x1FC007C0)
    {
        DebugMessage(M64MSG_ERROR, "dma_si_read(): unknown SI use");
        return;
    }

    update_pif_read(si);

    for (i = 0; i < PIF_RAM_SIZE; i += 4)
    {
        si->ri->rdram.dram[(si->regs[SI_DRAM_ADDR_REG]+i)/4] = sl(*(uint32_t*)(&si->pif.ram[i]));
    }

    update_count();

    if (g_delay_si) {
        add_interupt_event(SI_INT, /*0x100*/0x900);
    } else {
        si->regs[SI_STATUS_REG] |= 0x1000; // INTERRUPT
        signal_rcp_interrupt(si->r4300, MI_INTR_SI);
    }
}


void connect_si(struct si_controller* si,
                struct r4300_core* r4300,
                struct ri_controller* ri)
{
    si->r4300 = r4300;
    si->ri = ri;
}

void init_si(struct si_controller* si)
{
    memset(si->regs, 0, SI_REGS_COUNT*sizeof(uint32_t));

    init_pif(&si->pif);
}


int read_si_regs(void* opaque, uint32_t address, uint32_t* value)
{
    struct si_controller* si = (struct si_controller*)opaque;
    uint32_t reg = si_reg(address);

    *value = si->regs[reg];

    return 0;
}

int write_si_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
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
        si->regs[SI_STATUS_REG] &= ~0x1000;
        clear_rcp_interrupt(si->r4300, MI_INTR_SI);
        break;
    }

    return 0;
}

void si_end_of_dma_event(struct si_controller* si)
{
    main_check_inputs();

    si->pif.ram[0x3f] = 0x0;

    /* trigger SI interrupt */
    si->regs[SI_STATUS_REG] |= 0x1000;
    raise_rcp_interrupt(si->r4300, MI_INTR_SI);
}

