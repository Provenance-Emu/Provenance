/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rumblepak.h                                             *
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

#ifndef M64P_SI_RUMBLEPAK_H
#define M64P_SI_RUMBLEPAK_H

#include <stdint.h>

enum rumble_action
{
    RUMBLE_STOP,
    RUMBLE_START
};

struct rumblepak
{
    /* external rumble sink */
    void* user_data;
    void (*rumble)(void*,enum rumble_action);
};

void rumblepak_rumble(struct rumblepak* rpk, enum rumble_action action);

void rumblepak_read_command(struct rumblepak* rpk, uint8_t* cmd);
void rumblepak_write_command(struct rumblepak* rpk, uint8_t* cmd);

#endif
