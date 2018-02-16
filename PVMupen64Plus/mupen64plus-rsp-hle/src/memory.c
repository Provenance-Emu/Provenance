/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - memory.c                                        *
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

#include <string.h>

#include "memory.h"

/* Global functions */
void load_u8(uint8_t* dst, const unsigned char* buffer, unsigned address, size_t count)
{
    while (count != 0) {
        *(dst++) = *u8(buffer, address);
        address += 1;
        --count;
    }
}

void load_u16(uint16_t* dst, const unsigned char* buffer, unsigned address, size_t count)
{
    while (count != 0) {
        *(dst++) = *u16(buffer, address);
        address += 2;
        --count;
    }
}

void load_u32(uint32_t* dst, const unsigned char* buffer, unsigned address, size_t count)
{
    /* Optimization for uint32_t */
    memcpy(dst, u32(buffer, address), count * sizeof(uint32_t));
}

void store_u8(unsigned char* buffer, unsigned address, const uint8_t* src, size_t count)
{
    while (count != 0) {
        *u8(buffer, address) = *(src++);
        address += 1;
        --count;
    }
}

void store_u16(unsigned char* buffer, unsigned address, const uint16_t* src, size_t count)
{
    while (count != 0) {
        *u16(buffer, address) = *(src++);
        address += 2;
        --count;
    }
}

void store_u32(unsigned char* buffer, unsigned address, const uint32_t* src, size_t count)
{
    /* Optimization for uint32_t */
    memcpy(u32(buffer, address), src, count * sizeof(uint32_t));
}

