/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - emulate_speaker_via_audio_plugin.c                      *
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

#include "emulate_speaker_via_audio_plugin.h"

#include <stdint.h>

#include "ai/ai_controller.h"
#include "main/rom.h"
#include "plugin/plugin.h"
#include "ri/ri_controller.h"

void set_audio_format_via_audio_plugin(void* user_data, unsigned int frequency, unsigned int bits)
{
    /* not really implementable with just the zilmar spec.
     * Try a best effort approach
     */
    struct ai_controller* ai = (struct ai_controller*)user_data;
    uint32_t saved_ai_dacrate = ai->regs[AI_DACRATE_REG];
    
    ai->regs[AI_DACRATE_REG] = ROM_PARAMS.aidacrate / frequency - 1;

    audio.aiDacrateChanged(ROM_PARAMS.systemtype);

    ai->regs[AI_DACRATE_REG] = saved_ai_dacrate;
}

void push_audio_samples_via_audio_plugin(void* user_data, const void* buffer, size_t size)
{
    /* abuse core & audio plugin implementation to approximate desired effect */
    struct ai_controller* ai = (struct ai_controller*)user_data;
    uint32_t saved_ai_length = ai->regs[AI_LEN_REG];
    uint32_t saved_ai_dram = ai->regs[AI_DRAM_ADDR_REG];

    /* exploit the fact that buffer points in g_rdram to retreive dram_addr_reg value */
    ai->regs[AI_DRAM_ADDR_REG] = (uint8_t*)buffer - (uint8_t*)ai->ri->rdram.dram;
    ai->regs[AI_LEN_REG] = size;

    audio.aiLenChanged();

    ai->regs[AI_LEN_REG] = saved_ai_length;
    ai->regs[AI_DRAM_ADDR_REG] = saved_ai_dram;
}

