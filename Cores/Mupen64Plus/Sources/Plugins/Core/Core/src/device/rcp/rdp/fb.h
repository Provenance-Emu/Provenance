/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - fb.h                                                    *
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

#ifndef M64P_DEVICE_RCP_RDP_FB_H
#define M64P_DEVICE_RCP_RDP_FB_H

#include <stdint.h>

#include "api/m64p_plugin.h"

struct memory;
struct rdram;
struct r4300_core;

enum { FB_INFOS_COUNT = 6 };
enum { FB_DIRTY_PAGES_COUNT = 0x800 };

struct fb
{
    struct memory* mem;
    struct rdram* rdram;
    struct r4300_core* r4300;

    unsigned char dirty_page[FB_DIRTY_PAGES_COUNT];
    FrameBufferInfo infos[FB_INFOS_COUNT];
    unsigned int once;
};

void init_fb(struct fb* fb,
             struct memory* mem,
             struct rdram* rdram,
             struct r4300_core* r4300);

void poweron_fb(struct fb* fb);

void read_rdram_fb(void* opaque, uint32_t address, uint32_t* value);
void write_rdram_fb(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void protect_framebuffers(struct fb* fb);
void unprotect_framebuffers(struct fb* fb);

void pre_framebuffer_read(struct fb* fb, uint32_t address);
void post_framebuffer_write(struct fb* fb, uint32_t address, uint32_t length);

#endif
