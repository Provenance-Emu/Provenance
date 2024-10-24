/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - audio_plugin_compat.c                                   *
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

#include <stdint.h>

#include "backends/api/audio_out_backend.h"
#include "device/rcp/ai/ai_controller.h"
#include "device/rcp/ri/ri_controller.h"
#include "device/rcp/vi/vi_controller.h"
#include "device/rdram/rdram.h"
#include "main/rom.h"
#include "plugin/plugin.h"

static void audio_plugin_set_format(void* aout, unsigned int frequency, unsigned int bits)
{
    /* not really implementable with just the zilmar spec.
     * Try a best effort approach
     */
    struct ai_controller* ai = (struct ai_controller*)aout;
    uint32_t saved_ai_dacrate = ai->regs[AI_DACRATE_REG];

    ai->regs[AI_DACRATE_REG] = ai->vi->clock / frequency - 1;

    audio.aiDacrateChanged(ROM_PARAMS.systemtype);

    ai->regs[AI_DACRATE_REG] = saved_ai_dacrate;
}

static void audio_plugin_push_samples(void* aout, const void* buffer, size_t size)
{
    /* abuse core & audio plugin implementation to approximate desired effect */
    struct ai_controller* ai = (struct ai_controller*)aout;
    uint32_t saved_ai_length = ai->regs[AI_LEN_REG];
    uint32_t saved_ai_dram = ai->regs[AI_DRAM_ADDR_REG];

    /* exploit the fact that buffer points in g_dev.rdram.dram to retreive dram_addr_reg value */
    ai->regs[AI_DRAM_ADDR_REG] = (uint32_t)((uint8_t*)buffer - (uint8_t*)ai->ri->rdram->dram);
    ai->regs[AI_LEN_REG] = (uint32_t)size;

    audio.aiLenChanged();

    ai->regs[AI_LEN_REG] = saved_ai_length;
    ai->regs[AI_DRAM_ADDR_REG] = saved_ai_dram;
}

const struct audio_out_backend_interface g_iaudio_out_backend_plugin_compat =
{
    audio_plugin_set_format,
    audio_plugin_push_samples
};
