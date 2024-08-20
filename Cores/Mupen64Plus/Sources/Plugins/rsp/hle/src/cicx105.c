/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - cicx105.c                                       *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2012 Bobby Smiles                                       *
 *   Copyright (C) 2009 Richard Goedeken                                   *
 *   Copyright (C) 2002 Hacktarux                                          *
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

#include <string.h>

#include "hle_internal.h"

/**
 * During IPL3 stage of CIC x105 games, the RSP performs some checks and transactions
 * necessary for booting the game.
 *
 * We only implement the needed DMA transactions for booting.
 *
 * Found in Banjo-Tooie, Zelda, Perfect Dark, ...)
 **/
void cicx105_ucode(struct hle_t* hle)
{
    /* memcpy is okay to use because access constrains are met (alignment, size) */
    unsigned int i;
    unsigned char *dst = hle->dram + 0x2fb1f0;
    unsigned char *src = hle->imem + 0x120;

    /* dma_read(0x1120, 0x1e8, 0x1e8) */
    memcpy(hle->imem + 0x120, hle->dram + 0x1e8, 0x1f0);

    /* dma_write(0x1120, 0x2fb1f0, 0xfe817000) */
    for (i = 0; i < 24; ++i) {
        memcpy(dst, src, 8);
        dst += 0xff0;
        src += 0x8;

    }

    rsp_break(hle, 0);
}

