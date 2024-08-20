/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - cart_rom.c                                              *
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

#include "cart_rom.h"

#define M64P_CORE_PROTOTYPES 1
#include "api/callbacks.h"
#include "api/m64p_types.h"

#include "device/memory/memory.h"
#include "device/r4300/r4300_core.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

#define CART_ROM_ADDR_MASK UINT32_C(0x03ffffff);


void init_cart_rom(struct cart_rom* cart_rom,
                   uint8_t* rom, size_t rom_size,
                   struct r4300_core* r4300)
{
    cart_rom->rom = rom;
    cart_rom->rom_size = rom_size;

    cart_rom->r4300 = r4300;
}

void poweron_cart_rom(struct cart_rom* cart_rom)
{
    cart_rom->last_write = 0;
    cart_rom->rom_written = 0;
}


void read_cart_rom(void* opaque, uint32_t address, uint32_t* value)
{
    struct cart_rom* cart_rom = (struct cart_rom*)opaque;
    uint32_t addr = rom_address(address);

    if (cart_rom->rom_written)
    {
        *value = cart_rom->last_write;
        cart_rom->rom_written = 0;
    }
    else
    {
        *value = *(uint32_t*)(cart_rom->rom + addr);
    }
}

void write_cart_rom(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct cart_rom* cart_rom = (struct cart_rom*)opaque;
    cart_rom->last_write = value & mask;
    cart_rom->rom_written = 1;
}

unsigned int cart_rom_dma_read(void* opaque, const uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length)
{
    cart_addr &= CART_ROM_ADDR_MASK;

    DebugMessage(M64MSG_WARNING, "DMA Writing to CART_ROM: 0x%" PRIX32 " -> 0x%" PRIX32 " (0x%" PRIX32 ")", dram_addr, cart_addr, length);

    return /* length / 8 */0x1000;
}

unsigned int cart_rom_dma_write(void* opaque, uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length)
{
    size_t i;
    struct cart_rom* cart_rom = (struct cart_rom*)opaque;
    const uint8_t* mem = cart_rom->rom;

    cart_addr &= CART_ROM_ADDR_MASK;

    if (cart_addr + length < cart_rom->rom_size)
    {
        for(i = 0; i < length; ++i) {
            dram[(dram_addr+i)^S8] = mem[(cart_addr+i)^S8];
        }
    }
    else
    {
        unsigned int diff = (cart_rom->rom_size <= cart_addr)
            ? 0
            : cart_rom->rom_size - cart_addr;

        for (i = 0; i < diff; ++i) {
            dram[(dram_addr+i)^S8] = mem[(cart_addr+i)^S8];
        }
        for (; i < length; ++i) {
            dram[(dram_addr+i)^S8] = 0;
        }
    }

    /* invalidate cached code */
    invalidate_r4300_cached_code(cart_rom->r4300, 0x80000000 + dram_addr, length);
    invalidate_r4300_cached_code(cart_rom->r4300, 0xa0000000 + dram_addr, length);

    return (length / 8) + add_random_interrupt_time(cart_rom->r4300);
}

