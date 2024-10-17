/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - flashram.c                                              *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2014 Bobby Smiles                                       *
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

#include "flashram.h"

#include <string.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "backends/api/storage_backend.h"
#include "device/memory/memory.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>


static void flashram_command(struct flashram* flashram, uint32_t command)
{
    unsigned int i;
    const uint8_t* dram = flashram->dram;
    uint8_t* mem = flashram->istorage->data(flashram->storage);

    switch (command & 0xff000000)
    {
    case 0x4b000000:
        flashram->erase_offset = (command & 0xffff) * 128;
        break;
    case 0x78000000:
        flashram->mode = FLASHRAM_MODE_ERASE;
        flashram->status[0] = 0x11118008;
        break;
    case 0xa5000000:
        flashram->erase_offset = (command & 0xffff) * 128;
        flashram->status[0] = 0x11118004;
        break;
    case 0xb4000000:
        flashram->mode = FLASHRAM_MODE_WRITE;
        break;
    case 0xd2000000:  // execute
        switch (flashram->mode)
        {
        case FLASHRAM_MODE_NOPES:
        case FLASHRAM_MODE_READ:
            break;
        case FLASHRAM_MODE_ERASE:
        {
            for (i = flashram->erase_offset; i < (flashram->erase_offset+128); ++i) {
                mem[i^S8] = 0xff;
            }
            flashram->istorage->save(flashram->storage);
        }
        break;
        case FLASHRAM_MODE_WRITE:
        {
            for (i = 0; i < 128; ++i) {
                mem[(flashram->erase_offset+i)^S8] = dram[(flashram->write_pointer+i)^S8];
            }
            flashram->istorage->save(flashram->storage);
        }
        break;
        case FLASHRAM_MODE_STATUS:
            break;
        default:
            DebugMessage(M64MSG_WARNING, "unknown flashram command with mode:%x", flashram->mode);
            break;
        }
        flashram->mode = FLASHRAM_MODE_NOPES;
        break;
    case 0xe1000000:
        flashram->mode = FLASHRAM_MODE_STATUS;
        flashram->status[0] = 0x11118001;
        break;
    case 0xf0000000:
        flashram->mode = FLASHRAM_MODE_READ;
        flashram->status[0] = 0x11118004;
        break;
    case 0x00000000:
        break;
    default:
        DebugMessage(M64MSG_WARNING, "unknown flashram command: %" PRIX32, command);
        break;
    }
}


void init_flashram(struct flashram* flashram,
                   uint32_t flashram_type,
                   void* storage, const struct storage_backend_interface* istorage,
                   const uint8_t* dram)
{
    flashram->status[1] = flashram_type;
    flashram->storage = storage;
    flashram->istorage = istorage;
    flashram->dram = dram;
}

void poweron_flashram(struct flashram* flashram)
{
    flashram->mode = FLASHRAM_MODE_NOPES;
    flashram->status[0] = 0;
    flashram->erase_offset = 0;
    flashram->write_pointer = 0;
}

void format_flashram(uint8_t* flash)
{
    memset(flash, 0xff, FLASHRAM_SIZE);
}

void read_flashram_status(void* opaque, uint32_t address, uint32_t* value)
{
    struct flashram* flashram = (struct flashram*)opaque;

    *value = flashram->status[0];
}

void write_flashram_command(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct flashram* flashram = (struct flashram*)opaque;

    flashram_command(flashram, value & mask);
}


unsigned int flashram_dma_write(void* opaque, uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length)
{
    size_t i;
    struct flashram* flashram = (struct flashram*)opaque;
    const uint8_t* mem = flashram->istorage->data(flashram->storage);

    switch (flashram->mode)
    {
    case FLASHRAM_MODE_STATUS:
        ((uint32_t*)dram)[dram_addr/4+0] = flashram->status[0];
        ((uint32_t*)dram)[dram_addr/4+1] = flashram->status[1];
        break;

    case FLASHRAM_MODE_READ:
        cart_addr = (cart_addr & 0xffff) * 2; // ???

        for(i = 0; i < length; ++i) {
            dram[(dram_addr+i)^S8] = mem[(cart_addr+i)^S8];
        }
        break;
    default:
        DebugMessage(M64MSG_WARNING, "unknown dma_read_flashram: %x", flashram->mode);
        break;
    }

    return /* length / 8 */0x1000;
}

unsigned int flashram_dma_read(void* opaque, const uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length)
{
    struct flashram* flashram = (struct flashram*)opaque;

    switch (flashram->mode)
    {
    case FLASHRAM_MODE_WRITE:
        flashram->write_pointer = dram_addr;
        break;
    default:
        DebugMessage(M64MSG_ERROR, "unknown dma_write_flashram: %x", flashram->mode);
        break;
    }

    return /* length / 8 */0x1000;
}

