/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - plugins_compat.h                                          *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2017 Bobby Smiles                                       *
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

#ifndef M64P_BACKENDS_PLUGINS_COMPAT_PLUGINS_COMPAT_H
#define M64P_BACKENDS_PLUGINS_COMPAT_PLUGINS_COMPAT_H

#include "backends/api/audio_out_backend.h"
#include "backends/api/controller_input_backend.h"
#include "backends/api/rumble_backend.h"
#include "backends/api/joybus.h"

#include <stdint.h>

/* Audio Out backend interface */

extern const struct audio_out_backend_interface
    g_iaudio_out_backend_plugin_compat;

/* Controller Input backend interface */

struct controller_input_compat
{
    int control_id;

    struct game_controller* cont;
    struct transferpak* tpk;

    uint32_t last_input;
    int last_pak_type;
    void (*main_switch_pak)(int control_id);
    unsigned int pak_switch_delay;
    unsigned int gb_switch_delay;

    unsigned int gb_cart_switch_enabled;
};

extern const struct controller_input_backend_interface
    g_icontroller_input_backend_plugin_compat;

/* Rumble backend interface */

extern const struct rumble_backend_interface
    g_irumble_backend_plugin_compat;

/* PIF data processing functions */

extern const struct joybus_device_interface
    g_ijoybus_device_plugin_compat;

#endif
