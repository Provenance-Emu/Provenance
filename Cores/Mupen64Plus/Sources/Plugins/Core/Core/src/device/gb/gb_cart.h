/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - gb_cart.h                                               *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2015 Bobby Smiles                                       *
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

#ifndef M64P_DEVICE_GB_GB_CART_H
#define M64P_DEVICE_GB_GB_CART_H

#include <stddef.h>
#include <stdint.h>

#include "m64282fp.h"
#include "mbc3_rtc.h"

struct storage_backend_interface;
struct rumble_backend_interface;

struct gb_cart
{
    void* rom_storage;
    const struct storage_backend_interface* irom_storage;

    void* ram_storage;
    const struct storage_backend_interface* iram_storage;

    unsigned int rom_bank;
    unsigned int ram_bank;

    unsigned int ram_enable;
    unsigned int mbc1_mode;

    unsigned int extra_devices;

    struct mbc3_rtc rtc;
    struct m64282fp cam;

    void* rumble;
    const struct rumble_backend_interface* irumble;

    int (*read_gb_cart)(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size);
    int (*write_gb_cart)(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size);
};

void init_gb_cart(struct gb_cart* gb_cart,
        void* rom_opaque, void (*init_rom)(void* user_data, void** rom_storage, const struct storage_backend_interface** irom_storage), void (*release_rom)(void* user_data),
        void* ram_opaque, void (*init_ram)(void* user_data, size_t ram_size, void** ram_storage, const struct storage_backend_interface** iram_storage), void (*release_ram)(void* user_data),
        void* clock, const struct clock_backend_interface* iclock,
        void* rumble, const struct rumble_backend_interface* irumble);

void poweron_gb_cart(struct gb_cart* gb_cart);

int read_gb_cart(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size);
int write_gb_cart(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size);

#endif
