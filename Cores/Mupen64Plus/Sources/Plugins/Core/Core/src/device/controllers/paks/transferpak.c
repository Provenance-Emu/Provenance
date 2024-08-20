/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - transferpak.c                                           *
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

/* This work is based on the NRage plugin source.
 * Transfer pak emulation is certainly NOT accurate
 * but without proper reverse-engineering this as good as we can get.
 */

#include "transferpak.h"

#include "api/m64p_types.h"
#include "api/callbacks.h"

#include "device/gb/gb_cart.h"
#include "device/controllers/game_controller.h"

#include <string.h>


static uint16_t gb_cart_address(unsigned int bank, uint16_t address)
{
    return (address & 0x3fff) | ((bank & 0x3) * 0x4000) ;
}

void init_transferpak(struct transferpak* tpk, struct gb_cart* gb_cart)
{
    tpk->gb_cart = gb_cart;
}

void poweron_transferpak(struct transferpak* tpk)
{
    tpk->enabled = 0;
    tpk->bank = 0;
    tpk->access_mode = (tpk->gb_cart == NULL)
        ? CART_NOT_INSERTED
        : CART_ACCESS_MODE_0;
    tpk->access_mode_changed = 0x44;

    if (tpk->gb_cart != NULL) {
        poweron_gb_cart(tpk->gb_cart);
    }
}

void change_gb_cart(struct transferpak* tpk, struct gb_cart* gb_cart)
{
    tpk->enabled = 0;

    if (gb_cart == NULL) {
        tpk->access_mode = CART_NOT_INSERTED;
    }
    else {
        tpk->access_mode = CART_ACCESS_MODE_0;
        poweron_gb_cart(gb_cart);
    }

    tpk->gb_cart = gb_cart;
}

static void plug_transferpak(void* pak)
{
    struct transferpak* tpk = (struct transferpak*)pak;
    poweron_transferpak(tpk);
}

static void unplug_transferpak(void* pak)
{
}

static void read_transferpak(void* pak, uint16_t address, uint8_t* data, size_t size)
{
    struct transferpak* tpk = (struct transferpak*)pak;
    uint8_t value;

    DebugMessage(M64MSG_VERBOSE, "tpak read: %04x", address);

    switch(address >> 12)
    {
    case 0x8:
        /* get gb cart state (enabled/disabled) */
        value = (tpk->enabled)
              ? 0x84
              : 0x00;

        DebugMessage(M64MSG_VERBOSE, "tpak get cart state: %02x", value);
        memset(data, value, size);
        break;

    case 0xb:
        /* get gb cart access mode */
        if (tpk->enabled)
        {
            DebugMessage(M64MSG_VERBOSE, "tpak get access mode: %02x", tpk->access_mode);
            memset(data, tpk->access_mode, size);
            if (tpk->access_mode != CART_NOT_INSERTED)
            {
                data[0] |= tpk->access_mode_changed;
            }
            tpk->access_mode_changed = 0;
        }
        break;

    case 0xc:
    case 0xd:
    case 0xe:
    case 0xf:
        /* read gb cart */
        if (tpk->enabled)
        {
            DebugMessage(M64MSG_VERBOSE, "tpak read cart: %04x", address);

            if (tpk->gb_cart != NULL) {
                read_gb_cart(tpk->gb_cart, gb_cart_address(tpk->bank, address), data, size);
            }
        }
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Unknown tpak read: %04x", address);
    }
}

static void write_transferpak(void* pak, uint16_t address, const uint8_t* data, size_t size)
{
    struct transferpak* tpk = (struct transferpak*)pak;
    uint8_t value = data[size-1];

    DebugMessage(M64MSG_VERBOSE, "tpak write: %04x <- %02x", address, value);

    switch(address >> 12)
    {
    case 0x8:
        /* enable / disable gb cart */
        switch(value)
        {
        case 0xfe:
            tpk->enabled = 0;
            DebugMessage(M64MSG_VERBOSE, "tpak disabled");
            break;
        case 0x84:
            tpk->enabled = 1;
            DebugMessage(M64MSG_VERBOSE, "tpak enabled");
            break;
        default:
            DebugMessage(M64MSG_WARNING, "Unknown tpak write: %04x <- %02x", address, value);
        }
        break;

    case 0xa:
        /* set gb cart bank */
        if (tpk->enabled)
        {
            tpk->bank = value;
            DebugMessage(M64MSG_VERBOSE, "tpak set bank %02x", tpk->bank);
        }
        break;

    case 0xb:
        /* set gb cart access mode */
        if (tpk->enabled)
        {
            tpk->access_mode_changed = 0x04;

            tpk->access_mode = ((value & 1) == 0)
                              ? CART_ACCESS_MODE_0
                              : CART_ACCESS_MODE_1;

            if ((value & 0xfe) != 0)
            {
                DebugMessage(M64MSG_WARNING, "Unknown tpak write: %04x <- %02x", address, value);
            }

            DebugMessage(M64MSG_VERBOSE, "tpak set access mode %02x", tpk->access_mode);
        }
        break;

    case 0xc:
    case 0xd:
    case 0xe:
    case 0xf:
        /* write gb cart */
//        if (tpk->enabled)
        {
            DebugMessage(M64MSG_VERBOSE, "tpak write gb: %04x <- %02x", address, value);

            if (tpk->gb_cart != NULL) {
                write_gb_cart(tpk->gb_cart, gb_cart_address(tpk->bank, address), data, size);
            }
        }
        break;
    default:
        DebugMessage(M64MSG_WARNING, "Unknown tpak write: %04x <- %02x", address, value);
    }
}

/* Transfer pak definition */
const struct pak_interface g_itransferpak =
{
    "Transfer pak",
    plug_transferpak,
    unplug_transferpak,
    read_transferpak,
    write_transferpak
};
