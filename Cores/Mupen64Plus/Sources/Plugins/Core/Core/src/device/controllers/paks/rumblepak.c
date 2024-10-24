/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rumblepak.c                                             *
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

#include "rumblepak.h"

#include "backends/api/rumble_backend.h"
#include "device/controllers/game_controller.h"

#include <string.h>

void set_rumble_reg(struct rumblepak* rpk, uint8_t value)
{
    rpk->state = value;
    rpk->irumble->exec(rpk->rumble, (rpk->state == 0) ? RUMBLE_STOP : RUMBLE_START);
}

void init_rumblepak(struct rumblepak* rpk,
    void* rumble, const struct rumble_backend_interface* irumble)
{
    rpk->rumble = rumble;
    rpk->irumble = irumble;
}

void poweron_rumblepak(struct rumblepak* rpk)
{
    set_rumble_reg(rpk, 0x00);
}

static void plug_rumblepak(void* pak)
{
    struct rumblepak* rpk = (struct rumblepak*)pak;

    poweron_rumblepak(rpk);
}

static void unplug_rumblepak(void* pak)
{
    struct rumblepak* rpk = (struct rumblepak*)pak;

    /* Stop rumbling if pak gets disconnected */
    set_rumble_reg(rpk, 0x00);
}

static void read_rumblepak(void* pak, uint16_t address, uint8_t* data, size_t size)
{
    uint8_t value;

    if ((address >= 0x8000) && (address < 0x9000))
    {
        value = 0x80;
    }
    else
    {
        value = 0x00;
    }

    memset(data, value, size);
}

static void write_rumblepak(void* pak, uint16_t address, const uint8_t* data, size_t size)
{
    struct rumblepak* rpk = (struct rumblepak*)pak;

    if (address == 0xc000)
    {
        set_rumble_reg(rpk, data[size - 1]);
    }
}

/* Rumble pak definition */
const struct pak_interface g_irumblepak =
{
    "Rumble pak",
    plug_rumblepak,
    unplug_rumblepak,
    read_rumblepak,
    write_rumblepak
};
