/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rumblepak.h                                             *
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

#ifndef M64P_DEVICE_SI_RUMBLEPAK_H
#define M64P_DEVICE_SI_RUMBLEPAK_H

#include <stddef.h>
#include <stdint.h>

struct rumble_backend_interface;

struct rumblepak
{
    uint8_t state;
    void* rumble;
    const struct rumble_backend_interface* irumble;
};

void init_rumblepak(struct rumblepak* rpk,
    void* rumble, const struct rumble_backend_interface* irumble);

void poweron_rumblepak(struct rumblepak* rpk);

void set_rumble_reg(struct rumblepak* rpk, uint8_t value);

extern const struct pak_interface g_irumblepak;

#endif
