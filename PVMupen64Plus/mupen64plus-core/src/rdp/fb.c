/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - fb.c                                                    *
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

#include "fb.h"

#include "api/m64p_types.h"
#include "memory/memory.h"
#include "plugin/plugin.h"
#include "r4300/r4300_core.h"
#include "rdp_core.h"
#include "ri/ri_controller.h"

extern int fast_memory;

#include <string.h>

void init_fb(struct fb* fb)
{
    memset(fb, 0, sizeof(*fb));
    fb->once = 1;
}


static void pre_framebuffer_read(struct fb* fb, uint32_t address)
{
    size_t i;

    for(i = 0; i < FB_INFOS_COUNT; ++i)
    {
        if (fb->infos[i].addr)
        {
            unsigned int start = fb->infos[i].addr & 0x7FFFFF;
            unsigned int end = start + fb->infos[i].width*
                               fb->infos[i].height*
                               fb->infos[i].size - 1;
            if ((address & 0x7FFFFF) >= start && (address & 0x7FFFFF) <= end &&
                    fb->dirty_page[(address & 0x7FFFFF)>>12])
            {
                gfx.fBRead(address);
                fb->dirty_page[(address & 0x7FFFFF)>>12] = 0;
            }
        }
    }
}

static void pre_framebuffer_write(struct fb* fb, uint32_t address)
{
    size_t i;

    for(i = 0; i < FB_INFOS_COUNT; ++i)
    {
        if (fb->infos[i].addr)
        {
            unsigned int start = fb->infos[i].addr & 0x7FFFFF;
            unsigned int end = start + fb->infos[i].width*
                               fb->infos[i].height*
                               fb->infos[i].size - 1;
            if ((address & 0x7FFFFF) >= start && (address & 0x7FFFFF) <= end)
                gfx.fBWrite(address, 4);
        }
    }
}

int read_rdram_fb(void* opaque, uint32_t address, uint32_t* value)
{
    struct rdp_core* dp = (struct rdp_core*)opaque;
    pre_framebuffer_read(&dp->fb, address);
    return read_rdram_dram(dp->ri, address, value);
}

int write_rdram_fb(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct rdp_core* dp = (struct rdp_core*)opaque;
    pre_framebuffer_write(&dp->fb, address);
    return write_rdram_dram(dp->ri, address, value, mask);
}


#define R(x) read_ ## x ## b, read_ ## x ## h, read_ ## x, read_ ## x ## d
#define W(x) write_ ## x ## b, write_ ## x ## h, write_ ## x, write_ ## x ## d
#define RW(x) R(x), W(x)

void protect_framebuffers(struct rdp_core* dp)
{
    struct fb* fb = &dp->fb;

    if (gfx.fBGetFrameBufferInfo && gfx.fBRead && gfx.fBWrite)
        gfx.fBGetFrameBufferInfo(fb->infos);
    if (gfx.fBGetFrameBufferInfo && gfx.fBRead && gfx.fBWrite
            && fb->infos[0].addr)
    {
        size_t i;
        for(i = 0; i < FB_INFOS_COUNT; ++i)
        {
            if (fb->infos[i].addr)
            {
                int j;
                int start = fb->infos[i].addr & 0x7FFFFF;
                int end = start + fb->infos[i].width*
                          fb->infos[i].height*
                          fb->infos[i].size - 1;
                int start1 = start;
                int end1 = end;
                start >>= 16;
                end >>= 16;
                for (j=start; j<=end; j++)
                {
                    map_region(0x8000+j, M64P_MEM_RDRAM, RW(rdramFB));
                    map_region(0xa000+j, M64P_MEM_RDRAM, RW(rdramFB));
                }
                start <<= 4;
                end <<= 4;
                for (j=start; j<=end; j++)
                {
                    if (j>=start1 && j<=end1) fb->dirty_page[j]=1;
                    else fb->dirty_page[j] = 0;
                }

                if (fb->once != 0)
                {
                    fb->once = 0;
                    fast_memory = 0;
                    invalidate_r4300_cached_code(0, 0);
                }
            }
        }
    }
}

void unprotect_framebuffers(struct rdp_core* dp)
{
    struct fb* fb = &dp->fb;

    if (gfx.fBGetFrameBufferInfo && gfx.fBRead && gfx.fBWrite &&
            fb->infos[0].addr)
    {
        size_t i;
        for(i = 0; i < FB_INFOS_COUNT; ++i)
        {
            if (fb->infos[i].addr)
            {
                int j;
                int start = fb->infos[i].addr & 0x7FFFFF;
                int end = start + fb->infos[i].width*
                          fb->infos[i].height*
                          fb->infos[i].size - 1;
                start = start >> 16;
                end = end >> 16;

                for (j=start; j<=end; j++)
                {
                    map_region(0x8000+j, M64P_MEM_RDRAM, RW(rdram));
                    map_region(0xa000+j, M64P_MEM_RDRAM, RW(rdram));
                }
            }
        }
    }
}
