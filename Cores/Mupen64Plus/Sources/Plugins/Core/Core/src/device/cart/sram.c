/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - sram.c                                                  *
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

#include "sram.h"

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "backends/api/storage_backend.h"
#include "device/memory/memory.h"

#define SRAM_ADDR_MASK UINT32_C(0x0000ffff)

void format_sram(uint8_t* mem)
{
    memset(mem, 0xff, SRAM_SIZE);
}

void init_sram(struct sram* sram,
               void* storage, const struct storage_backend_interface* istorage)
{
    sram->storage = storage;
    sram->istorage = istorage;
}

unsigned int sram_dma_read(void* opaque, const uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length)
{
    size_t i;
    struct sram* sram = (struct sram*)opaque;
    uint8_t* mem = sram->istorage->data(sram->storage);

    cart_addr &= SRAM_ADDR_MASK;

    for (i = 0; i < length; ++i) {
        mem[(cart_addr+i)^S8] = dram[(dram_addr+i)^S8];
    }

    sram->istorage->save(sram->storage);

    return /* length / 8 */0x1000;
}

unsigned int sram_dma_write(void* opaque, uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length)
{
    size_t i;
    struct sram* sram = (struct sram*)opaque;
    const uint8_t* mem = sram->istorage->data(sram->storage);

    cart_addr &= SRAM_ADDR_MASK;

    for (i = 0; i < length; ++i) {
        dram[(dram_addr+i)^S8] = mem[(cart_addr+i)^S8];
    }

    return /* length / 8 */0x1000;
}

void read_sram(void* opaque, uint32_t address, uint32_t* value)
{
    struct sram* sram = (struct sram*)opaque;
    const uint8_t* mem = sram->istorage->data(sram->storage);

    address &= SRAM_ADDR_MASK;

    *value = *(uint32_t*)(mem + address);
}

void write_sram(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct sram* sram = (struct sram*)opaque;
    uint8_t* mem = sram->istorage->data(sram->storage);

    address &= SRAM_ADDR_MASK;

    masked_write((uint32_t*)(mem + address), value, mask);

    sram->istorage->save(sram->storage);
}
