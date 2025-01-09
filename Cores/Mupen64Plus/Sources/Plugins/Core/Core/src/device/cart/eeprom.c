/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - eeprom.c                                                *
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

#include "eeprom.h"

#include <stdint.h>
#include <string.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "backends/api/storage_backend.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

enum { EEPROM_BLOCK_SIZE = 8 };

void format_eeprom(uint8_t* mem, size_t size)
{
    memset(mem, 0xff, size);
}


void init_eeprom(struct eeprom* eeprom,
    uint16_t type,
    void* storage,
    const struct storage_backend_interface* istorage)
{
    eeprom->type = type;
    eeprom->storage = storage;
    eeprom->istorage = istorage;
}

void eeprom_read_block(struct eeprom* eeprom,
    uint8_t block, uint8_t* data)
{
    unsigned int address = block * EEPROM_BLOCK_SIZE;

    if (address < eeprom->istorage->size(eeprom->storage))
    {
        memcpy(data, eeprom->istorage->data(eeprom->storage) + address, EEPROM_BLOCK_SIZE);
    }
    else
    {
        DebugMessage(M64MSG_WARNING, "Invalid access to eeprom address=%04" PRIX16, address);
    }
}

void eeprom_write_block(struct eeprom* eeprom,
    uint8_t block, const uint8_t* data, uint8_t* status)
{
    unsigned int address = block * EEPROM_BLOCK_SIZE;

    if (address < eeprom->istorage->size(eeprom->storage))
    {
        memcpy(eeprom->istorage->data(eeprom->storage) + address, data, EEPROM_BLOCK_SIZE);
        eeprom->istorage->save(eeprom->storage);
        *status = 0x00;
    }
    else
    {
        DebugMessage(M64MSG_WARNING, "Invalid access to eeprom address=%04" PRIX16, address);
    }
}

