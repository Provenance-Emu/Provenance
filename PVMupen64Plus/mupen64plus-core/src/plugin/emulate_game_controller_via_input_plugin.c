/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - emulate_game_controller_via_input_plugin.c              *
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

#include "emulate_game_controller_via_input_plugin.h"

#include "api/m64p_plugin.h"
#include "plugin.h"
#include "si/game_controller.h"

int egcvip_is_connected(void* opaque, enum pak_type* pak)
{
    int channel = *(int*)opaque;

    CONTROL* c = &Controls[channel];

    switch(c->Plugin)
    {
    case PLUGIN_NONE: *pak = PAK_NONE; break;
    case PLUGIN_MEMPAK: *pak = PAK_MEM; break;
    case PLUGIN_RUMBLE_PAK: *pak = PAK_RUMBLE; break;
    case PLUGIN_TRANSFER_PAK: *pak = PAK_TRANSFER; break;

    case PLUGIN_RAW:
        /* historically PLUGIN_RAW has been mostly (exclusively ?) used for rumble,
         * so we just reproduce that behavior */
        *pak = PAK_RUMBLE; break;
    }

    return c->Present;
}

uint32_t egcvip_get_input(void* opaque)
{
    BUTTONS keys = { 0 };
    int channel = *(int*)opaque;

    if (input.getKeys)
        input.getKeys(channel, &keys);

    return keys.Value;

}

