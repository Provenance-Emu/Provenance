/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - fb.h                                                    *
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

#ifndef M64P_RDP_FB_H
#define M64P_RDP_FB_H

#include <stdint.h>

#include "api/m64p_plugin.h"

struct rdp_core;

enum { FB_INFOS_COUNT = 6 };
enum { FB_DIRTY_PAGES_COUNT = 0x800 };

struct fb
{
    unsigned char dirty_page[FB_DIRTY_PAGES_COUNT];
    FrameBufferInfo infos[FB_INFOS_COUNT];
    unsigned int once;
};

void init_fb(struct fb* fb);

int read_rdram_fb(void* opaque, uint32_t address, uint32_t* value);
int write_rdram_fb(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void protect_framebuffers(struct rdp_core* dp);
void unprotect_framebuffers(struct rdp_core* dp);

#endif
