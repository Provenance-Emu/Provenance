/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rumblepak.c                                             *
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

#include "rumblepak.h"

#include <string.h>


void rumblepak_rumble(struct rumblepak* rpk, enum rumble_action action)
{
    rpk->rumble(rpk->user_data, action);
}

void rumblepak_read_command(struct rumblepak* rpk, uint8_t* cmd)
{
    uint8_t data;
    uint16_t address = (cmd[3] << 8) | (cmd[4] & 0xe0);

    if ((address >= 0x8000) && (address < 0x9000))
    {
        data = 0x80;
    }
    else
    {
        data = 0x00;
    }

    memset(&cmd[5], data, 0x20);
}

void rumblepak_write_command(struct rumblepak* rpk, uint8_t* cmd)
{
    enum rumble_action action;
    uint16_t address = (cmd[3] << 8) | (cmd[4] & 0xe0);

    if (address == 0xc000)
    {
        action = (cmd[5] == 0)
                ? RUMBLE_STOP
                : RUMBLE_START;

        rumblepak_rumble(rpk, action);
    }
}

