/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - vi_controller.c                                         *
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

#include "vi_controller.h"

#include <string.h>

#include "api/m64p_types.h"
#include "device/memory/memory.h"
#include "device/r4300/r4300_core.h"
#include "device/rcp/mi/mi_controller.h"
#include "main/main.h"
#include "plugin/plugin.h"

unsigned int vi_clock_from_tv_standard(m64p_system_type tv_standard)
{
    switch(tv_standard)
    {
    case SYSTEM_PAL:
        return 49656530;
    case SYSTEM_MPAL:
        return 48628316;
    case SYSTEM_NTSC:
    default:
        return 48681812;
    }
}

unsigned int vi_expected_refresh_rate_from_tv_standard(m64p_system_type tv_standard)
{
    switch (tv_standard)
    {
    case SYSTEM_PAL:
    case SYSTEM_MPAL:
        return 50;

    case SYSTEM_NTSC:
    default:
        return 60;
    }
}

void init_vi(struct vi_controller* vi, unsigned int clock, unsigned int expected_refresh_rate,
             struct mi_controller* mi, struct rdp_core* dp)
{
    vi->clock = clock;
    vi->expected_refresh_rate = expected_refresh_rate;
    vi->mi = mi;
    vi->dp = dp;
}

void poweron_vi(struct vi_controller* vi)
{
    memset(vi->regs, 0, VI_REGS_COUNT*sizeof(uint32_t));
    vi->field = 0;
    vi->delay = vi->next_vi = 0;
    vi->count_per_scanline = 0;
}

void read_vi_regs(void* opaque, uint32_t address, uint32_t* value)
{
    struct vi_controller* vi = (struct vi_controller*)opaque;
    uint32_t reg = vi_reg(address);
    const uint32_t* cp0_regs = r4300_cp0_regs(&vi->mi->r4300->cp0);

    if (reg == VI_CURRENT_REG)
    {
        /* XXX: update current line number */
        cp0_update_count(vi->mi->r4300);

        if (vi->regs[VI_V_SYNC_REG] != 0)
            vi->regs[VI_CURRENT_REG] = (vi->delay - (vi->next_vi - cp0_regs[CP0_COUNT_REG])) / vi->count_per_scanline;

        /* wrap around VI_CURRENT_REG if needed */
        if (vi->regs[VI_CURRENT_REG] >= vi->regs[VI_V_SYNC_REG])
            vi->regs[VI_CURRENT_REG] -= vi->regs[VI_V_SYNC_REG];

        /* update current field */
        vi->regs[VI_CURRENT_REG] = (vi->regs[VI_CURRENT_REG] & (~1)) | vi->field;
    }

    *value = vi->regs[reg];
}

void write_vi_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct vi_controller* vi = (struct vi_controller*)opaque;
    uint32_t reg = vi_reg(address);

    switch(reg)
    {
    case VI_STATUS_REG:
        if ((vi->regs[VI_STATUS_REG] & mask) != (value & mask))
        {
            masked_write(&vi->regs[VI_STATUS_REG], value, mask);
            gfx.viStatusChanged();
        }
        return;

    case VI_WIDTH_REG:
        if ((vi->regs[VI_WIDTH_REG] & mask) != (value & mask))
        {
            masked_write(&vi->regs[VI_WIDTH_REG], value, mask);
            gfx.viWidthChanged();
        }
        return;

    case VI_CURRENT_REG:
        clear_rcp_interrupt(vi->mi, MI_INTR_VI);
        return;

    case VI_V_SYNC_REG:
        masked_write(&vi->regs[reg], value, mask);
        vi->count_per_scanline = (vi->clock / vi->expected_refresh_rate) / (vi->regs[VI_V_SYNC_REG] + 1);
        vi->delay = (vi->regs[VI_V_SYNC_REG] + 1) * vi->count_per_scanline;
        if (vi->regs[VI_V_SYNC_REG] != 0 && vi->next_vi == 0)
        {
            const uint32_t* cp0_regs = r4300_cp0_regs(&vi->mi->r4300->cp0);
            cp0_update_count(vi->mi->r4300);
            vi->next_vi = cp0_regs[CP0_COUNT_REG] + vi->delay;
            add_interrupt_event_count(&vi->mi->r4300->cp0, VI_INT, vi->next_vi);
        }
        return;
    }

    masked_write(&vi->regs[reg], value, mask);
}

void vi_vertical_interrupt_event(void* opaque)
{
    struct vi_controller* vi = (struct vi_controller*)opaque;
    if (vi->dp->do_on_unfreeze & DELAY_DP_INT)
        vi->dp->do_on_unfreeze |= DELAY_UPDATESCREEN;
    else
        gfx.updateScreen();

    /* allow main module to do things on VI event */
    new_vi();

    /* toggle vi field if in interlaced mode */
    vi->field ^= (vi->regs[VI_STATUS_REG] >> 6) & 0x1;

    /* schedule next vertical interrupt */
    vi->next_vi += vi->delay;
    add_interrupt_event_count(&vi->mi->r4300->cp0, VI_INT, vi->next_vi);

    /* trigger interrupt */
    raise_rcp_interrupt(vi->mi, MI_INTR_VI);
}

