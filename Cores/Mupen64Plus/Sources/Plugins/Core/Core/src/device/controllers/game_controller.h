/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - game_controller.h                                       *
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

#ifndef M64P_DEVICE_SI_GAME_CONTROLLER_H
#define M64P_DEVICE_SI_GAME_CONTROLLER_H

#include "backends/api/joybus.h"

#include <stddef.h>
#include <stdint.h>

struct game_controller;
struct controller_input_backend_interface;

struct game_controller_flavor
{
    const char* name;
    uint16_t type;

    /* controller reset procedure */
    void (*reset)(struct game_controller* cont);
};

struct pak_interface
{
    const char* name;
    void (*plug)(void* pak);
    void (*unplug)(void* pak);
    void (*read)(void* pak, uint16_t address, uint8_t* data, size_t size);
    void (*write)(void* pak, uint16_t address, const uint8_t* data, size_t size);
};

struct game_controller
{
    uint8_t status;

    const struct game_controller_flavor* flavor;

    void* cin;
    const struct controller_input_backend_interface* icin;

    void* pak;
    const struct pak_interface* ipak;
};

void init_game_controller(struct game_controller* cont,
    const struct game_controller_flavor* flavor,
    void* cin, const struct controller_input_backend_interface* icin,
    void* pak, const struct pak_interface* ipak);


void change_pak(struct game_controller* cont,
                void* pak, const struct pak_interface* ipak);

/* Controller Joybus interface */
extern const struct joybus_device_interface
    g_ijoybus_device_controller;

/* Controller flavors */
extern const struct game_controller_flavor g_standard_controller_flavor;
extern const struct game_controller_flavor g_mouse_controller_flavor;

#endif
