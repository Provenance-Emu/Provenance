/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - ai_controller.c                                         *
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

#include "ai_controller.h"

#include <string.h>
#include <stdlib.h>

#include "backends/api/audio_out_backend.h"
#include "device/memory/memory.h"
#include "device/r4300/r4300_core.h"
#include "device/rcp/mi/mi_controller.h"
#include "device/rcp/ri/ri_controller.h"
#include "device/rcp/vi/vi_controller.h"
#include "device/rdram/rdram.h"
#include "main/rom.h"


#define AI_STATUS_BUSY UINT32_C(0x40000000)
#define AI_STATUS_FULL UINT32_C(0x80000000)


static uint32_t get_remaining_dma_length(struct ai_controller* ai)
{
    unsigned int next_ai_event;
    unsigned int remaining_dma_duration;
    const uint32_t* cp0_regs;

    if (ai->fifo[0].duration == 0)
        return 0;

    cp0_update_count(ai->mi->r4300);
    next_ai_event = get_event(&ai->mi->r4300->cp0.q, AI_INT);
    if (next_ai_event == 0)
        return 0;

    cp0_regs = r4300_cp0_regs(&ai->mi->r4300->cp0);
    if (next_ai_event <= cp0_regs[CP0_COUNT_REG])
        return 0;

    remaining_dma_duration = next_ai_event - cp0_regs[CP0_COUNT_REG];

    uint64_t dma_length = (uint64_t)remaining_dma_duration * ai->fifo[0].length / ai->fifo[0].duration;
    return dma_length&~7;
}

static unsigned int get_dma_duration(struct ai_controller* ai)
{
    unsigned int samples_per_sec = ai->vi->clock / (1 + ai->regs[AI_DACRATE_REG]);
    unsigned int bytes_per_sample = 4; /* XXX: assume 16bit stereo - should depends on bitrate instead */
    unsigned int cpu_counts_per_sec = ai->vi->delay * ai->vi->expected_refresh_rate; /* estimate cpu counts/sec using VI */

    return ai->regs[AI_LEN_REG] * (cpu_counts_per_sec / (bytes_per_sample * samples_per_sec));
}


static void do_dma(struct ai_controller* ai, struct ai_dma* dma)
{
    /* lazy initialization of sample format */
    if (ai->samples_format_changed)
    {
        /// Get native frequency from VI clock
        unsigned int frequency = ai->vi->clock / (1 + ai->regs[AI_DACRATE_REG]);

        /// Pass through native frequency - resampling happens in bridge
        ai->iaout->set_format(ai->aout, frequency, 16);
        ai->samples_format_changed = 0;
    }

    ai->last_read = dma->length;

    if (ai->delayed_carry) dma->address += 0x2000;

    if (((dma->address + dma->length) & 0x1FFF) == 0)
        ai->delayed_carry = 1;
    else
        ai->delayed_carry = 0;

    /* schedule end of dma event */
    cp0_update_count(ai->mi->r4300);
    add_interrupt_event(&ai->mi->r4300->cp0, AI_INT, dma->duration);
}

static void fifo_push(struct ai_controller* ai)
{
    unsigned int duration = get_dma_duration(ai);

    if (ai->regs[AI_STATUS_REG] & AI_STATUS_BUSY)
    {
        ai->fifo[1].address = ai->regs[AI_DRAM_ADDR_REG];
        ai->fifo[1].length = ai->regs[AI_LEN_REG];
        ai->fifo[1].duration = duration;
        ai->regs[AI_STATUS_REG] |= AI_STATUS_FULL;
    }
    else
    {
        ai->fifo[0].address = ai->regs[AI_DRAM_ADDR_REG];
        ai->fifo[0].length = ai->regs[AI_LEN_REG];
        ai->fifo[0].duration = duration;
        ai->regs[AI_STATUS_REG] |= AI_STATUS_BUSY;

        do_dma(ai, &ai->fifo[0]);
    }
}

static void fifo_pop(struct ai_controller* ai)
{
    if (ai->regs[AI_STATUS_REG] & AI_STATUS_FULL)
    {
        ai->fifo[0].address = ai->fifo[1].address;
        ai->fifo[0].length = ai->fifo[1].length;
        ai->fifo[0].duration = ai->fifo[1].duration;
        ai->regs[AI_STATUS_REG] &= ~AI_STATUS_FULL;

        do_dma(ai, &ai->fifo[0]);
    }
    else
    {
        ai->regs[AI_STATUS_REG] &= ~AI_STATUS_BUSY;
        ai->delayed_carry = 0;
    }
}


void init_ai(struct ai_controller* ai,
             struct mi_controller* mi,
             struct ri_controller* ri,
             struct vi_controller* vi,
             void* aout,
             const struct audio_out_backend_interface* iaout)
{
    ai->mi = mi;
    ai->ri = ri;
    ai->vi = vi;
    ai->aout = aout;
    ai->iaout = iaout;
}

void poweron_ai(struct ai_controller* ai)
{
    /// Keep the DAC rate we set in ai_init
    uint32_t saved_dacrate = ai->regs[AI_DACRATE_REG];
    memset(ai->regs, 0, AI_REGS_COUNT * sizeof(uint32_t));
    ai->regs[AI_DACRATE_REG] = saved_dacrate;

    memset(ai->fifo, 0, 2 * sizeof(struct ai_dma));
    ai->samples_format_changed = 0;
    ai->last_read = 0;
    ai->delayed_carry = 0;
}

void read_ai_regs(void* opaque, uint32_t address, uint32_t* value)
{
    struct ai_controller* ai = (struct ai_controller*)opaque;
    uint32_t reg = ai_reg(address);

    if (reg == AI_LEN_REG)
    {
        *value = get_remaining_dma_length(ai);
        if (*value < ai->last_read)
        {
            unsigned int diff = ai->fifo[0].length - ai->last_read;
            unsigned char *p = (unsigned char*)&ai->ri->rdram->dram[ai->fifo[0].address/4];
            ai->iaout->push_samples(ai->aout, p + diff, ai->last_read - *value);
            ai->last_read = *value;
        }
    }
    else
    {
        *value = ai->regs[reg];
    }
}

void write_ai_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct ai_controller* ai = (struct ai_controller*)opaque;
    uint32_t reg = ai_reg(address);

    switch (reg)
    {
    case AI_LEN_REG:
        masked_write(&ai->regs[AI_LEN_REG], value, mask);
        if (ai->regs[AI_LEN_REG] != 0) {
            fifo_push(ai);
        }
        else {
            /* stop sound */
        }
        return;

    case AI_STATUS_REG:
        clear_rcp_interrupt(ai->mi, MI_INTR_AI);
        return;

    case AI_BITRATE_REG:
    case AI_DACRATE_REG:
        /* lazy audio format setting */
        if ((ai->regs[reg]) != (value & mask))
            ai->samples_format_changed = 1;

        masked_write(&ai->regs[reg], value, mask);
        return;
    }

    masked_write(&ai->regs[reg], value, mask);
}

void ai_end_of_dma_event(void* opaque)
{
    struct ai_controller* ai = (struct ai_controller*)opaque;

    if (ai->last_read != 0)
    {
        unsigned int diff = ai->fifo[0].length - ai->last_read;
        unsigned char *p = (unsigned char*)&ai->ri->rdram->dram[ai->fifo[0].address/4];
        ai->iaout->push_samples(ai->aout, p + diff, ai->last_read);
    }

    fifo_pop(ai);
    raise_rcp_interrupt(ai->mi, MI_INTR_AI);
}

void ai_init(struct ai_controller* ai)
{
    /// Initialize base registers
    memset(ai->regs, 0, AI_REGS_COUNT * sizeof(uint32_t));
    memset(ai->fifo, 0, 2 * sizeof(struct ai_dma));

    /// Calculate DAC rate for 44.1kHz
    uint32_t dacrate;

    if (ROM_PARAMS.systemtype == SYSTEM_PAL) {
        /// PAL: 49656530 / (x + 1) = 44100
        dacrate = 1126;  /// This gives us ~44.1kHz for PAL
    } else {
        /// NTSC: 48681812 / (x + 1) = 44100
        dacrate = 1103;  /// This gives us ~44.1kHz for NTSC
    }

    ai->regs[AI_DACRATE_REG] = dacrate;
    ai->regs[AI_BITRATE_REG] = 0;
    ai->regs[AI_STATUS_REG] = 0;
    ai->samples_format_changed = 0;
    ai->last_read = 0;
    ai->delayed_carry = 0;
}
