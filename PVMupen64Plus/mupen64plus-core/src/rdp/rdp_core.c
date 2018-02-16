/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rdp_core.c                                              *
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

#include "rdp_core.h"

#include <string.h>

#include "memory/memory.h"
#include "plugin/plugin.h"
#include "r4300/r4300_core.h"
#include "rsp/rsp_core.h"

static int update_dpc_status(struct rdp_core* dp, uint32_t w)
{
    /* see do_SP_Task for more info */
    int do_sp_task_on_unfreeze = 0;

    /* clear / set xbus_dmem_dma */
    if (w & 0x1) dp->dpc_regs[DPC_STATUS_REG] &= ~0x1;
    if (w & 0x2) dp->dpc_regs[DPC_STATUS_REG] |= 0x1;

    /* clear / set freeze */
    if (w & 0x4)
    {
        dp->dpc_regs[DPC_STATUS_REG] &= ~0x2;

        if (!(dp->sp->regs[SP_STATUS_REG] & 0x3)) // !halt && !broke
            do_sp_task_on_unfreeze = 1;
    }
    if (w & 0x8) dp->dpc_regs[DPC_STATUS_REG] |= 0x2;

    /* clear / set flush */
    if (w & 0x10) dp->dpc_regs[DPC_STATUS_REG] &= ~0x4;
    if (w & 0x20) dp->dpc_regs[DPC_STATUS_REG] |= 0x4;

    return do_sp_task_on_unfreeze;
}


void connect_rdp(struct rdp_core* dp,
                 struct r4300_core* r4300,
                 struct rsp_core* sp,
                 struct ri_controller* ri)
{
    dp->r4300 = r4300;
    dp->sp = sp;
    dp->ri = ri;
}

void init_rdp(struct rdp_core* dp)
{
    memset(dp->dpc_regs, 0, DPC_REGS_COUNT*sizeof(uint32_t));
    memset(dp->dps_regs, 0, DPS_REGS_COUNT*sizeof(uint32_t));

    init_fb(&dp->fb);
}


int read_dpc_regs(void* opaque, uint32_t address, uint32_t* value)
{
    struct rdp_core* dp = (struct rdp_core*)opaque;
    uint32_t reg = dpc_reg(address);

    *value = dp->dpc_regs[reg];

    return 0;
}

int write_dpc_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct rdp_core* dp = (struct rdp_core*)opaque;
    uint32_t reg = dpc_reg(address);

    switch(reg)
    {
    case DPC_STATUS_REG:
        if (update_dpc_status(dp, value & mask) != 0)
            do_SP_Task(dp->sp);
    case DPC_CURRENT_REG:
    case DPC_CLOCK_REG:
    case DPC_BUFBUSY_REG:
    case DPC_PIPEBUSY_REG:
    case DPC_TMEM_REG:
        return 0;
    }

    masked_write(&dp->dpc_regs[reg], value, mask);

    switch(reg)
    {
    case DPC_START_REG:
        dp->dpc_regs[DPC_CURRENT_REG] = dp->dpc_regs[DPC_START_REG];
        break;
    case DPC_END_REG:
        gfx.processRDPList();
        signal_rcp_interrupt(dp->r4300, MI_INTR_DP);
        break;
    }

    return 0;
}


int read_dps_regs(void* opaque, uint32_t address, uint32_t* value)
{
    struct rdp_core* dp = (struct rdp_core*)opaque;
    uint32_t reg = dps_reg(address);

    *value = dp->dps_regs[reg];

    return 0;
}

int write_dps_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct rdp_core* dp = (struct rdp_core*)opaque;
    uint32_t reg = dps_reg(address);

    masked_write(&dp->dps_regs[reg], value, mask);

    return 0;
}

void rdp_interrupt_event(struct rdp_core* dp)
{
    dp->dpc_regs[DPC_STATUS_REG] &= ~2;
    dp->dpc_regs[DPC_STATUS_REG] |= 0x81;

    raise_rcp_interrupt(dp->r4300, MI_INTR_DP);
}

