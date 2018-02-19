/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - flashram.c                                              *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
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
#include "memory/memory.h"
#include "pi_controller.h"
#include "ri/ri_controller.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>


static void flashram_command(struct pi_controller* pi, uint32_t command)
{
    unsigned int i;
    struct flashram* flashram = &pi->flashram;
    uint8_t* dram = (uint8_t*)pi->ri->rdram.dram;

    switch (command & 0xff000000)
    {
    case 0x4b000000:
        flashram->erase_offset = (command & 0xffff) * 128;
        break;
    case 0x78000000:
        flashram->mode = FLASHRAM_MODE_ERASE;
        flashram->status = 0x1111800800c20000LL;
        break;
    case 0xa5000000:
        flashram->erase_offset = (command & 0xffff) * 128;
        flashram->status = 0x1111800400c20000LL;
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
            for (i=flashram->erase_offset; i<(flashram->erase_offset+128); ++i)
                flashram->data[i^S8] = 0xff;
            flashram_save(flashram);
        }
        break;
        case FLASHRAM_MODE_WRITE:
        {
            for(i = 0; i < 128; ++i)
                flashram->data[(flashram->erase_offset+i)^S8]= dram[(flashram->write_pointer+i)^S8];
            flashram_save(flashram);
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
        flashram->status = 0x1111800100c20000LL;
        break;
    case 0xf0000000:
        flashram->mode = FLASHRAM_MODE_READ;
        flashram->status = 0x11118004f0000000LL;
        break;
    default:
        DebugMessage(M64MSG_WARNING, "unknown flashram command: %" PRIX32, command);
        break;
    }
}


void init_flashram(struct flashram* flashram)
{
    flashram->mode = FLASHRAM_MODE_NOPES;
    flashram->status = 0;
    flashram->erase_offset = 0;
    flashram->write_pointer = 0;
}

void flashram_save(struct flashram* flashram)
{
    flashram->save(flashram->user_data);
}

void format_flashram(uint8_t* flash)
{
    memset(flash, 0xff, FLASHRAM_SIZE);
}

int read_flashram_status(void* opaque, uint32_t address, uint32_t* value)
{
    struct pi_controller* pi = (struct pi_controller*)opaque;

    if ((pi->use_flashram == -1) || ((address & 0xffff) != 0))
    {
        DebugMessage(M64MSG_ERROR, "unknown read in read_flashram_status()");
        return -1;
    }

    pi->use_flashram = 1;
    *value = pi->flashram.status >> 32;

    return 0;
}

int write_flashram_command(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct pi_controller* pi = (struct pi_controller*)opaque;

    if ((pi->use_flashram == -1) || ((address & 0xffff) != 0))
    {
        DebugMessage(M64MSG_ERROR, "unknown write in write_flashram_command()");
        return -1;
    }

    pi->use_flashram = 1;
    flashram_command(pi, value & mask);

    return 0;
}


void dma_read_flashram(struct pi_controller* pi)
{
    unsigned int i, length;
    struct flashram* flashram = &pi->flashram;
    uint32_t* dram = pi->ri->rdram.dram;
    uint8_t* mem = flashram->data;
    unsigned int dram_addr, cart_addr;

    switch (flashram->mode)
    {
    case FLASHRAM_MODE_STATUS:
        dram[pi->regs[PI_DRAM_ADDR_REG]/4]   = (uint32_t)(flashram->status >> 32);
        dram[pi->regs[PI_DRAM_ADDR_REG]/4+1] = (uint32_t)(flashram->status);
        break;
    case FLASHRAM_MODE_READ:
        length = (pi->regs[PI_WR_LEN_REG] & 0xffffff) + 1;
        dram_addr = pi->regs[PI_DRAM_ADDR_REG];
        cart_addr = ((pi->regs[PI_CART_ADDR_REG]-0x08000000)&0xffff)*2;

        for(i = 0; i < length; ++i)
            ((uint8_t*)dram)[(dram_addr+i)^S8] = mem[(cart_addr+i)^S8];
        break;
    default:
        DebugMessage(M64MSG_WARNING, "unknown dma_read_flashram: %x", flashram->mode);
        break;
    }
}

void dma_write_flashram(struct pi_controller* pi)
{
    struct flashram* flashram = &pi->flashram;

    switch (flashram->mode)
    {
    case FLASHRAM_MODE_WRITE:
        flashram->write_pointer = pi->regs[PI_DRAM_ADDR_REG];
        break;
    default:
        DebugMessage(M64MSG_ERROR, "unknown dma_write_flashram: %x", flashram->mode);
        break;
    }
}

