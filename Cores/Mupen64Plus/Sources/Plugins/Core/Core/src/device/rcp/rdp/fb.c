/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - fb.c                                                    *
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

#include "fb.h"

#include "api/m64p_types.h"
#include "api/callbacks.h"
#include "device/memory/memory.h"
#include "device/r4300/r4300_core.h"
#include "device/rdram/rdram.h"
#include "osal/preproc.h"
#include "plugin/plugin.h"

#include <string.h>

static osal_inline size_t fb_buffer_size(const FrameBufferInfo* fb_info)
{
    return fb_info->width * fb_info->height * fb_info->size;
}

void pre_framebuffer_read(struct fb* fb, uint32_t address)
{
    if (!fb->infos[0].addr) {
        return;
    }

    size_t i;

    for (i = 0; i < FB_INFOS_COUNT; ++i) {

        /* skip empty fb info */
        if (fb->infos[i].addr == 0) {
            continue;
        }

        /* if address in within a fb and its page is dirty,
         * notify GFX plugin and mark page as not dirty */
        uint32_t begin = fb->infos[i].addr;
        uint32_t end   = fb->infos[i].addr + fb_buffer_size(&fb->infos[i]) - 1;

        if ((address >= begin) && (address <= end) && (fb->dirty_page[address >> 12])) {
            gfx.fBRead(address);
            fb->dirty_page[address >> 12] = 0;
        }
    }
}

void post_framebuffer_write(struct fb* fb, uint32_t address, uint32_t length)
{
    if (!fb->infos[0].addr) {
        return;
    }

    size_t i, j;
    unsigned char size;
    if (length % 4 == 0)
        size = 4;
    else if (length % 2 == 0)
        size = 2;
    else
        size = 1;

    for (i = 0; i < FB_INFOS_COUNT; ++i) {

        /* skip empty fb info */
        if (fb->infos[i].addr == 0) {
            continue;
        }

        /* if address in within a fb notify GFX plugin */
        uint32_t begin = fb->infos[i].addr;
        uint32_t end   = fb->infos[i].addr + fb_buffer_size(&fb->infos[i]) - 1;

        for (j = 0; j < length; j += size) {
            if ((address + j >= begin) && (address + j <= end)) {
                gfx.fBWrite(address + j, size);
            }
        }
    }
}


void init_fb(struct fb* fb,
             struct memory* mem,
             struct rdram* rdram,
             struct r4300_core* r4300)
{
    fb->mem = mem;
    fb->rdram = rdram;
    fb->r4300 = r4300;
}

void poweron_fb(struct fb* fb)
{
    memset(fb->dirty_page, 0, FB_DIRTY_PAGES_COUNT*sizeof(fb->dirty_page[0]));
    memset(fb->infos, 0, FB_INFOS_COUNT*sizeof(fb->infos[0]));
    fb->once = 1;
}

void read_rdram_fb(void* opaque, uint32_t address, uint32_t* value)
{
    struct fb* fb = (struct fb*)opaque;
    pre_framebuffer_read(fb, address);
    read_rdram_dram(fb->rdram, address, value);
}

void write_rdram_fb(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct fb* fb = (struct fb*)opaque;
    write_rdram_dram(fb->rdram, address, value, mask);

    uint32_t addr = address & ~0x3;
    size_t size = 4;

    switch(mask)
    {
    case 0x000000ff:
        addr += (3 ^ S8);
        size = 1;
        break;

    case 0x0000ff00:
        addr += (2 ^ S8);
        size = 1;
        break;

    case 0x00ff0000:
        addr += (1 ^ S8);
        size = 1;
        break;

    case 0xff000000:
        addr += (0 ^ S8);
        size = 1;
        break;

    case 0x0000ffff:
        addr += (2 ^ S16);
        size = 2;
        break;

    case 0xffff0000:
        addr += (0 ^ S16);
        size = 2;
        break;

    case 0xffffffff:
        addr += 0;
        size = 4;
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Unknown mask %08x !!!", mask);
    }

    post_framebuffer_write(fb, addr, size);
}


#define R(x) read_ ## x
#define W(x) write_ ## x
#define RW(x) R(x), W(x)

void protect_framebuffers(struct fb* fb)
{
    size_t i, j;
    struct mem_mapping fb_mapping = { 0, 0, M64P_MEM_RDRAM, { fb, RW(rdram_fb) } };

    /* check API support */
    if (!(gfx.fBGetFrameBufferInfo && gfx.fBRead && gfx.fBWrite)) {
        return;
    }

    /* ask fb info to gfx plugin */
    gfx.fBGetFrameBufferInfo(fb->infos);

    /* return early if not FB info is present */
    if (fb->infos[0].addr == 0) {
        return;
    }

    for (i = 0; i < FB_INFOS_COUNT; ++i) {

        /* skip empty fb info */
        if (fb->infos[i].addr == 0) {
            continue;
        }

        /* map fb rw handlers */
        fb_mapping.begin = fb->infos[i].addr;
        fb_mapping.end   = fb->infos[i].addr + fb_buffer_size(&fb->infos[i]) - 1;
        apply_mem_mapping(fb->mem, &fb_mapping);

        /* mark all pages that are within a fb as dirty */
        for (j = fb_mapping.begin >> 12; j <= (fb_mapping.end >> 12); ++j) {
            fb->dirty_page[j] = 1;
        }

        /* disable dynarec "fast memory" code generation to avoid direct memory accesses */
        if (fb->once) {
            fb->once = 0;
#ifndef NEW_DYNAREC
            fb->r4300->recomp.fast_memory = 0;
#endif

            /* also need to invalidate cached code to regen non fast memory code path */
            invalidate_r4300_cached_code(fb->r4300, 0, 0);
        }
    }
}

void unprotect_framebuffers(struct fb* fb)
{
    size_t i;
    struct mem_mapping ram_mapping = { 0, 0, M64P_MEM_RDRAM, { fb->rdram, RW(rdram_dram) } };

    /* return early if FB info is not supported or empty */
    if (!fb->infos[0].addr) {
        return;
    }

    for (i = 0; i < FB_INFOS_COUNT; ++i) {

        /* skip empty fb info */
        if (fb->infos[i].addr == 0) {
            continue;
        }

        /* restore ram rw handlers */
        ram_mapping.begin = fb->infos[i].addr;
        ram_mapping.end   = fb->infos[i].addr + fb_buffer_size(&fb->infos[i]) - 1;
        apply_mem_mapping(fb->mem, &ram_mapping);
    }
}
