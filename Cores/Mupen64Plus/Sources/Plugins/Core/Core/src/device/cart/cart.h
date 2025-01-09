/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - cart.h                                                  *
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

#ifndef M64P_DEVICE_CART_CART_H
#define M64P_DEVICE_CART_CART_H

#include "backends/api/joybus.h"

#include "af_rtc.h"
#include "cart_rom.h"
#include "eeprom.h"
#include "flashram.h"
#include "sram.h"

#include <stddef.h>
#include <stdint.h>

struct r4300_core;
struct clock_backend_interface;
struct storage_backend_interface;

struct cart
{
    struct af_rtc af_rtc;
    struct cart_rom cart_rom;
    struct eeprom eeprom;
    struct flashram flashram;
    struct sram sram;

    int use_flashram;
};


void init_cart(struct cart* cart,
               /* AF-RTC */
               void* af_rtc_clock, const struct clock_backend_interface* iaf_rtc_clock,
               /* cart ROM */
               uint8_t* rom, size_t rom_size,
               struct r4300_core* r4300,
               /* eeprom */
               uint16_t eeprom_type,
               void* eeprom_storage, const struct storage_backend_interface* ieeprom_storage,
               /* flashram */
               uint32_t flashram_type,
               void* flashram_storage, const struct storage_backend_interface* iflashram_storage,
               const uint8_t* dram,
               /* sram */
               void* sram_storage, const struct storage_backend_interface* isram_storage);

void poweron_cart(struct cart* cart);

void read_cart_dom2(void* opaque, uint32_t address, uint32_t* value);
void write_cart_dom2(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

unsigned int cart_dom2_dma_read(void* opaque, const uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length);
unsigned int cart_dom2_dma_write(void* opaque, uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length);
unsigned int cart_dom3_dma_read(void* opaque, const uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length);
unsigned int cart_dom3_dma_write(void* opaque, uint8_t* dram, uint32_t dram_addr, uint32_t cart_addr, uint32_t length);

extern const struct joybus_device_interface
    g_ijoybus_device_cart;

#endif
