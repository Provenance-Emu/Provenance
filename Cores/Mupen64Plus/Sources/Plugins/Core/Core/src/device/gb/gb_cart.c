/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - gb_cart.c                                               *
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

/* Most of the mappers information comes from
 * "The Cycle-Accurate Game Boy Docs" by AntonioND
 */

#include "gb_cart.h"

#include "api/m64p_types.h"
#include "api/callbacks.h"
#include "backends/api/rumble_backend.h"
#include "backends/api/storage_backend.h"

#include <assert.h>
#include <string.h>


enum gbcart_extra_devices
{
    GED_NONE          = 0x00,
    GED_RAM           = 0x01,
    GED_BATTERY       = 0x02,
    GED_RTC           = 0x04,
    GED_RUMBLE        = 0x08,
    GED_ACCELEROMETER = 0x10,
    GED_CAMERA        = 0x20,
};

/* various helper functions for ram, rom, or MBC uses */


static void read_rom(const void* rom_storage, const struct storage_backend_interface* irom_storage, uint16_t address, uint8_t* data, size_t size)
{
    assert(size > 0);

    if (address + size > irom_storage->size(rom_storage))
    {
        DebugMessage(M64MSG_WARNING, "Out of bound read from GB ROM %04x", address);
        return;
    }

    memcpy(data, irom_storage->data(rom_storage) + address, size);
}


static void read_ram(const void* ram_storage, const struct storage_backend_interface* iram_storage, unsigned int enabled, uint16_t address, uint8_t* data, size_t size, uint8_t mask)
{
    size_t i;
    assert(size > 0);

    /* RAM has to be enabled before use */
    if (!enabled) {
        DebugMessage(M64MSG_WARNING, "Trying to read from non enabled GB RAM %04x", address);
        memset(data, 0xff, size);
        return;
    }

    /* RAM must be present */
    if (iram_storage->data(ram_storage) == NULL) {
        DebugMessage(M64MSG_WARNING, "Trying to read from absent GB RAM %04x", address);
        memset(data, 0xff, size);
        return;
    }

    if (address + size > iram_storage->size(ram_storage))
    {
        DebugMessage(M64MSG_WARNING, "Out of bound read from GB RAM %04x", address);
        return;
    }

    memcpy(data, iram_storage->data(ram_storage) + address, size);

    if (mask != UINT8_C(0xff)) {
        for (i = 0; i < size; ++i) {
            data[i] &= mask;
        }
    }
}

static void write_ram(void* ram_storage, const struct storage_backend_interface* iram_storage, unsigned int enabled, uint16_t address, const uint8_t* data, size_t size, uint8_t mask)
{
    size_t i;
    uint8_t* dst;

    assert(size > 0);

    /* RAM has to be enabled before use */
    if (!enabled) {
        DebugMessage(M64MSG_WARNING, "Trying to write to non enabled GB RAM %04x", address);
        return;
    }

    /* RAM must be present */
    if (iram_storage->data(ram_storage) == NULL) {
        DebugMessage(M64MSG_WARNING, "Trying to write to absent GB RAM %04x", address);
        return;
    }

    if (address + size > iram_storage->size(ram_storage))
    {
        DebugMessage(M64MSG_WARNING, "Out of bound write to GB RAM %04x", address);
        return;
    }

    dst = iram_storage->data(ram_storage) + address;
    memcpy(dst, data, size);

    if (mask != UINT8_C(0xff)) {
        for (i = 0; i < size; ++i) {
            dst[i] &= mask;
        }
    }
}


static void set_ram_enable(struct gb_cart* gb_cart, uint8_t value)
{
    gb_cart->ram_enable = ((value & 0x0f) == 0x0a) ? 1 : 0;
    DebugMessage(M64MSG_VERBOSE, "RAM enable = %02x", gb_cart->ram_enable);
}




static int read_gb_cart_nombc(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    switch(address >> 13)
    {
    /* 0x0000-0x7fff: ROM */
    case (0x0000 >> 13):
    case (0x2000 >> 13):
    case (0x4000 >> 13):
    case (0x6000 >> 13):
        read_rom(gb_cart->rom_storage, gb_cart->irom_storage, address, data, size);
        break;

    /* 0xa000-0xbfff: RAM */
    case (0xa000 >> 13):
        read_ram(gb_cart->ram_storage, gb_cart->iram_storage, 1, address - 0xa000, data, size, UINT8_C(0xff));
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart read (nombc): %04x", address);
    }

    return 0;
}

static int write_gb_cart_nombc(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    switch(address >> 13)
    {
    /* 0x0000-0x7fff: ROM */
    case (0x0000 >> 13):
    case (0x2000 >> 13):
    case (0x4000 >> 13):
    case (0x6000 >> 13):
        DebugMessage(M64MSG_VERBOSE, "Trying to write to GB ROM %04x", address);
        break;

    /* 0xa000-0xbfff: RAM */
    case (0xa000 >> 13):
        write_ram(gb_cart->ram_storage, gb_cart->iram_storage, 1, address - 0xa000, data, size, UINT8_C(0xff));
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart write (nombc): %04x", address);
    }

    return 0;
}


static int read_gb_cart_mbc1(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    switch(address >> 13)
    {
    /* 0x0000-0x3fff: ROM bank 00 */
    case (0x0000 >> 13):
    case (0x2000 >> 13):
        read_rom(gb_cart->rom_storage, gb_cart->irom_storage, address, data, size);
        break;

    /* 0x4000-0x7fff: ROM bank 01-7f */
    case (0x4000 >> 13):
    case (0x6000 >> 13):
        read_rom(gb_cart->rom_storage, gb_cart->irom_storage, (address - 0x4000) + (gb_cart->rom_bank * 0x4000), data, size);
        break;

    /* 0xa000-0xbfff: RAM bank 00-03 */
    case (0xa000 >> 13):
        read_ram(gb_cart->ram_storage, gb_cart->iram_storage, gb_cart->ram_enable, (address - 0xa000) + (gb_cart->ram_bank * 0x2000), data, size, UINT8_C(0xff));
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart read (MBC1): %04x", address);
    }

    return 0;
}

static int write_gb_cart_mbc1(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    uint8_t bank;
    uint8_t value = data[size-1];

    switch(address >> 13)
    {
    /* 0x0000-0x1fff: RAM enable */
    case (0x0000 >> 13):
        set_ram_enable(gb_cart, value);
        break;

    /* 0x2000-0x3fff: ROM bank select (low 5 bits) */
    case (0x2000 >> 13):
        bank = value & 0x1f;
        gb_cart->rom_bank = (gb_cart->rom_bank & ~UINT8_C(0x1f)) | (bank == 0) ? 1 : bank;
        DebugMessage(M64MSG_VERBOSE, "MBC1 set rom bank %02x", gb_cart->rom_bank);
        break;

    /* 0x4000-0x5fff: RAM bank / upper ROM bank select (2 bits) */
    case (0x4000 >> 13):
        bank = value & 0x3;
        if (gb_cart->mbc1_mode == 0) {
            /* ROM mode */
            gb_cart->rom_bank = (gb_cart->rom_bank & 0x1f) | (bank << 5);
        }
        else {
            /* RAM mode */
            gb_cart->ram_bank = bank;
        }
        DebugMessage(M64MSG_VERBOSE, "MBC1 set ram bank %02x", gb_cart->ram_bank);
        break;

    /* 0x6000-0x7fff: ROM/RAM mode (1 bit) */
    case (0x6000 >> 13):
        gb_cart->mbc1_mode = (value & 0x1);
        if (gb_cart->mbc1_mode == 0) {
            /* only RAM bank 0 is accessible in ROM mode */
            gb_cart->ram_bank = 0;
        } else {
            /* only ROM banks 0x01 - 0x1f are accessible in RAM mode */
            gb_cart->rom_bank &= 0x1f;
        }
        break;

    /* 0xa000-0xbfff: RAM bank 00-03 */
    case (0xa000 >> 13):
        write_ram(gb_cart->ram_storage, gb_cart->iram_storage, gb_cart->ram_enable, (address - 0xa000) + (gb_cart->ram_bank * 0x2000), data, size, UINT8_C(0xff));
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart write (MBC1): %04x", address);
    }

    return 0;
}

static int read_gb_cart_mbc2(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    switch (address >> 13)
    {
    /* 0x0000-0x3fff: ROM bank 00 */
    case (0x0000 >> 13):
    case (0x2000 >> 13):
        read_rom(gb_cart->rom_storage, gb_cart->irom_storage, address, data, size);
        break;

    /* 0x4000-0x7fff: ROM bank 01-0f */
    case (0x4000 >> 13):
    case (0x6000 >> 13):
        read_rom(gb_cart->rom_storage, gb_cart->irom_storage, (address - 0x4000) + (gb_cart->rom_bank * 0x4000), data, size);
        break;

    /* 0xa000-0xa1ff: internal 512x4bit RAM */
    case (0xa000 >> 13):
        read_ram(gb_cart->ram_storage, gb_cart->iram_storage, gb_cart->ram_enable, (address - 0xa000), data, size, UINT8_C(0x0f));
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart read (MBC2): %04x", address);
    }

    return 0;
}

static int write_gb_cart_mbc2(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    uint8_t bank;
    uint8_t value = data[size-1];

    switch(address >> 13)
    {
    /* 0x0000-0x1fff: RAM enable */
    case (0x0000 >> 13):
        if ((address & 0x0100) == 0) {
            set_ram_enable(gb_cart, value);
        }
        break;

    /* 0x2000-0x3fff: ROM bank select (low 4 bits) */
    case (0x2000 >> 13):
        if ((address & 0x0100) != 0) {
            bank = value & 0x0f;
            gb_cart->rom_bank = (bank == 0) ? 1 : bank;
            DebugMessage(M64MSG_VERBOSE, "MBC2 set rom bank %02x", gb_cart->rom_bank);
        }
        break;

    /* 0xa000-0xa1ff: internal 512x4bit RAM */
    case (0xa000 >> 13):
        write_ram(gb_cart->ram_storage, gb_cart->iram_storage, gb_cart->ram_enable, (address - 0xa000), data, size, UINT8_C(0x0f));
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart write (MBC2): %04x", address);
    }

    return 0;
}


static int read_gb_cart_mbc3(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    switch(address >> 13)
    {
    /* 0x0000-0x3fff: ROM bank 00 */
    case (0x0000 >> 13):
    case (0x2000 >> 13):
        read_rom(gb_cart->rom_storage, gb_cart->irom_storage, address, data, size);
        break;

    /* 0x4000-0x7fff: ROM bank 01-7f */
    case (0x4000 >> 13):
    case (0x6000 >> 13):
        read_rom(gb_cart->rom_storage, gb_cart->irom_storage, (address - 0x4000) + (gb_cart->rom_bank * 0x4000), data, size);
        break;

    /* 0xa000-0xbfff: RAM bank 00-07 or RTC register 08-0c */
    case (0xa000 >> 13):
        switch(gb_cart->ram_bank)
        {
        /* RAM banks */
        case 0x00:
        case 0x01:
        case 0x02:
        case 0x03:
        case 0x04:
        case 0x05:
        case 0x06:
        case 0x07:
            read_ram(gb_cart->ram_storage, gb_cart->iram_storage, gb_cart->ram_enable, (address - 0xa000) + (gb_cart->ram_bank * 0x2000), data, size, UINT8_C(0xff));
            break;

        /* RTC registers */
        case 0x08:
        case 0x09:
        case 0x0a:
        case 0x0b:
        case 0x0c:
            /* RAM has to be enabled before use */
            if (!gb_cart->ram_enable) {
                DebugMessage(M64MSG_WARNING, "Trying to read from non enabled GB RAM %04x", address);
                memset(data, 0xff, size);
                break;
            }

            if (!(gb_cart->extra_devices & GED_RTC)) {
                DebugMessage(M64MSG_WARNING, "Trying to read from absent RTC %04x", address);
                memset(data, 0xff, size);
                break;
            }

            memset(data, read_mbc3_rtc_regs(&gb_cart->rtc, gb_cart->ram_bank - 0x08), size);
            break;

        default:
            DebugMessage(M64MSG_WARNING, "Unknown device mapped in RAM/RTC space: %04x", address);
        }
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart read (MBC3): %04x", address);
    }

    return 0;
}

static int write_gb_cart_mbc3(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    uint8_t bank;
    uint8_t value = data[size-1];

    switch(address >> 13)
    {
    /* 0x0000-0x1fff: RAM/RTC enable */
    case (0x0000 >> 13):
        set_ram_enable(gb_cart, value);
        break;

    /* 0x2000-0x3fff: ROM bank select */
    case (0x2000 >> 13):
        bank = value & 0x7f;
        gb_cart->rom_bank = (bank == 0) ? 1 : bank;
        DebugMessage(M64MSG_VERBOSE, "MBC3 set rom bank %02x", gb_cart->rom_bank);
        break;

    /* 0x4000-0x5fff: RAM bank / RTC register select */
    case (0x4000 >> 13):
        gb_cart->ram_bank = value;
        DebugMessage(M64MSG_VERBOSE, "MBC3 set ram bank %02x", gb_cart->ram_bank);
        break;

    /* 0x6000-0x7fff: latch clock registers */
    case (0x6000 >> 13):
        if (!(gb_cart->extra_devices & GED_RTC)) {
            DebugMessage(M64MSG_WARNING, "Trying to latch to absent RTC %04x", address);
            break;
        }

        latch_mbc3_rtc_regs(&gb_cart->rtc, value);
        break;

    /* 0xa000-0xbfff: RAM bank 00-07 or RTC register 08-0c */
    case (0xa000 >> 13):
        switch(gb_cart->ram_bank)
        {
        /* RAM banks */
        case 0x00:
        case 0x01:
        case 0x02:
        case 0x03:
        case 0x04:
        case 0x05:
        case 0x06:
        case 0x07:
            write_ram(gb_cart->ram_storage, gb_cart->iram_storage, gb_cart->ram_enable, (address - 0xa000) + (gb_cart->ram_bank * 0x2000), data, size, UINT8_C(0xff));
            break;

        /* RTC registers */
        case 0x08:
        case 0x09:
        case 0x0a:
        case 0x0b:
        case 0x0c:
            /* RAM has to be enabled before use */
            if (!gb_cart->ram_enable) {
                DebugMessage(M64MSG_WARNING, "Trying to write to non enabled GB RAM %04x", address);
                break;
            }

            if (!(gb_cart->extra_devices & GED_RTC)) {
                DebugMessage(M64MSG_WARNING, "Trying to write to absent RTC %04x", address);
                break;
            }

            write_mbc3_rtc_regs(&gb_cart->rtc, gb_cart->ram_bank - 0x08, value);
            break;

        default:
            DebugMessage(M64MSG_WARNING, "Unknwown device mapped in RAM/RTC space: %04x", address);
        }
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart write (MBC3): %04x", address);
    }

    return 0;
}

static int read_gb_cart_mbc5(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    switch(address >> 13)
    {
    /* 0x0000-0x3fff: ROM bank 00 */
    case (0x0000 >> 13):
    case (0x2000 >> 13):
        read_rom(gb_cart->rom_storage, gb_cart->irom_storage, address, data, size);
        break;

    /* 0x4000-0x7fff: ROM bank 00-ff (???) */
    case (0x4000 >> 13):
    case (0x6000 >> 13):
        read_rom(gb_cart->rom_storage, gb_cart->irom_storage, (address - 0x4000) + (gb_cart->rom_bank * 0x4000), data, size);
        break;

    /* 0xa000-0xbfff: RAM bank 00-07 */
    case (0xa000 >> 13):
        read_ram(gb_cart->ram_storage, gb_cart->iram_storage, gb_cart->ram_enable, (address - 0xa000) + ((gb_cart->ram_bank & 0x7) * 0x2000), data, size, UINT8_C(0xff));
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart read (MBC5): %04x", address);
    }

    return 0;
}

static int write_gb_cart_mbc5(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    uint8_t value = data[size-1];

    switch(address >> 13)
    {
    /* 0x0000-0x1fff: RAM enable */
    case (0x0000 >> 13):
        set_ram_enable(gb_cart, value);
        break;

    /* 0x2000-0x3fff: ROM bank select */
    case (0x2000 >> 13):
        if (address < 0x3000)
        {
            gb_cart->rom_bank &= 0xff00;
            gb_cart->rom_bank |= value;
        }
        else
        {
            gb_cart->rom_bank &= 0x00ff;
            gb_cart->rom_bank |= (value & 0x01) << 8;
        }
        DebugMessage(M64MSG_VERBOSE, "MBC5 set rom bank %04x", gb_cart->rom_bank);
        break;

    /* 0x4000-0x5fff: RAM bank select */
    case (0x4000 >> 13):
        gb_cart->ram_bank = value & 0x0f;
        if (gb_cart->extra_devices & GED_RUMBLE) {
            gb_cart->irumble->exec(gb_cart->rumble, ((gb_cart->ram_bank & 0x8) == 0) ? RUMBLE_STOP : RUMBLE_START);
        }
        DebugMessage(M64MSG_VERBOSE, "MBC5 set ram bank %02x", gb_cart->ram_bank);
        break;

    /* 0xa000-0xbfff: RAM bank 00-0f */
    case (0xa000 >> 13):
        write_ram(gb_cart->ram_storage, gb_cart->iram_storage, gb_cart->ram_enable, (address - 0xa000) + ((gb_cart->ram_bank & 0x07)* 0x2000), data, size, UINT8_C(0xff));
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart write (MBC5): %04x", address);
    }

    return 0;
}

static int read_gb_cart_mbc6(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    return 0;
}

static int write_gb_cart_mbc6(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    return 0;
}

static int read_gb_cart_mbc7(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    return 0;
}

static int write_gb_cart_mbc7(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    return 0;
}

static int read_gb_cart_mmm01(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    return 0;
}

static int write_gb_cart_mmm01(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    return 0;
}

static int read_gb_cart_pocket_cam(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    switch(address >> 13)
    {
    /* 0x0000-0x3fff: ROM bank 00 */
    case (0x0000 >> 13):
    case (0x2000 >> 13):
        read_rom(gb_cart->rom_storage, gb_cart->irom_storage, address, data, size);
        break;

    /* 0x4000-0x7fff: ROM bank 00-3f */
    case (0x4000 >> 13):
    case (0x6000 >> 13):
        read_rom(gb_cart->rom_storage, gb_cart->irom_storage, (address - 0x4000) + (gb_cart->rom_bank * 0x4000), data, size);
        break;

    /* 0xa000-0xbfff: RAM bank 00-0f, Camera registers & 0x10 */
    case (0xa000 >> 13):
        if (gb_cart->ram_bank & 0x10) {
            memset(data, read_m64282fp_regs(&gb_cart->cam, (address & 0x7f)), size);
        }
        else {
            read_ram(gb_cart->ram_storage, gb_cart->iram_storage, 1, (address - 0xa000) + (gb_cart->ram_bank * 0x2000), data, size, UINT8_C(0xff));
        }
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart read (cam): %04x", address);
    }

    return 0;
}

static int write_gb_cart_pocket_cam(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    uint8_t value = data[size-1];

    switch(address >> 13)
    {
    /* 0x0000-0x1fff: RAM write enable */
    case (0x0000 >> 13):
        set_ram_enable(gb_cart, value);
        break;

    /* 0x2000-0x3fff: ROM bank select */
    case (0x2000 >> 13):
        gb_cart->rom_bank = (value & 0x3f);
        DebugMessage(M64MSG_VERBOSE, "CAM set rom bank %04x", gb_cart->rom_bank);
        break;

    /* 0x4000-0x5fff: RAM bank select */
    case (0x4000 >> 13):
        if (value & 0x10) {
            gb_cart->ram_bank = value;
            DebugMessage(M64MSG_VERBOSE, "CAM set register bank %02x", gb_cart->ram_bank);
        }
        else {
            gb_cart->ram_bank = (value & 0x0f);
            DebugMessage(M64MSG_VERBOSE, "CAM set ram bank %02x", gb_cart->ram_bank);
        }
        break;

    /* 0xa000-0xbfff: RAM bank 00-0f, Camera registers & 0x10 */
    case (0xa000 >> 13):
        if (gb_cart->ram_bank & 0x10) {
            write_m64282fp_regs(&gb_cart->cam, (address & 0x7f), value);
        }
        else {
            write_ram(gb_cart->ram_storage, gb_cart->iram_storage, gb_cart->ram_enable, (address - 0xa000) + (gb_cart->ram_bank * 0x2000), data, size, UINT8_C(0xff));
        }
        break;

    default:
        DebugMessage(M64MSG_WARNING, "Invalid cart write (cam): %04x", address);
    }

    return 0;
}

static int read_gb_cart_bandai_tama5(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    return 0;
}

static int write_gb_cart_bandai_tama5(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    return 0;
}

static int read_gb_cart_huc1(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    return 0;
}

static int write_gb_cart_huc1(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    return 0;
}

static int read_gb_cart_huc3(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    return 0;
}

static int write_gb_cart_huc3(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    return 0;
}



struct parsed_cart_type
{
    const char* mbc;
    int (*read_gb_cart)(struct gb_cart*,uint16_t,uint8_t*,size_t);
    int (*write_gb_cart)(struct gb_cart*,uint16_t,const uint8_t*,size_t);
    unsigned int extra_devices;
};

static const struct parsed_cart_type* parse_cart_type(uint8_t cart_type)
{
#define MBC(x) #x, read_gb_cart_ ## x, write_gb_cart_ ## x
    static const struct parsed_cart_type nombc_none           = { MBC(nombc),        GED_NONE };
    static const struct parsed_cart_type nombc_ram            = { MBC(nombc),        GED_RAM };
    static const struct parsed_cart_type nombc_ram_batt       = { MBC(nombc),        GED_RAM | GED_BATTERY };

    static const struct parsed_cart_type mbc1_none            = { MBC(mbc1),         GED_NONE };
    static const struct parsed_cart_type mbc1_ram             = { MBC(mbc1),         GED_RAM  };
    static const struct parsed_cart_type mbc1_ram_batt        = { MBC(mbc1),         GED_RAM | GED_BATTERY };

    static const struct parsed_cart_type mbc2_none            = { MBC(mbc2),         GED_NONE };
    static const struct parsed_cart_type mbc2_ram_batt        = { MBC(mbc2),         GED_RAM | GED_BATTERY };

    static const struct parsed_cart_type mmm01_none           = { MBC(mmm01),        GED_NONE };
    static const struct parsed_cart_type mmm01_ram            = { MBC(mmm01),        GED_RAM  };
    static const struct parsed_cart_type mmm01_ram_batt       = { MBC(mmm01),        GED_RAM | GED_BATTERY };

    static const struct parsed_cart_type mbc3_none            = { MBC(mbc3),         GED_NONE };
    static const struct parsed_cart_type mbc3_ram             = { MBC(mbc3),         GED_RAM  };
    static const struct parsed_cart_type mbc3_ram_batt        = { MBC(mbc3),         GED_RAM | GED_BATTERY };
    static const struct parsed_cart_type mbc3_batt_rtc        = { MBC(mbc3),         GED_BATTERY | GED_RTC };
    static const struct parsed_cart_type mbc3_ram_batt_rtc    = { MBC(mbc3),         GED_RAM | GED_BATTERY | GED_RTC };

    static const struct parsed_cart_type mbc5_none            = { MBC(mbc5),         GED_NONE };
    static const struct parsed_cart_type mbc5_ram             = { MBC(mbc5),         GED_RAM  };
    static const struct parsed_cart_type mbc5_ram_batt        = { MBC(mbc5),         GED_RAM | GED_BATTERY };
    static const struct parsed_cart_type mbc5_rumble          = { MBC(mbc5),         GED_RUMBLE };
    static const struct parsed_cart_type mbc5_ram_rumble      = { MBC(mbc5),         GED_RAM | GED_RUMBLE };
    static const struct parsed_cart_type mbc5_ram_batt_rumble = { MBC(mbc5),         GED_RAM | GED_BATTERY | GED_RUMBLE };

    static const struct parsed_cart_type mbc6                 = { MBC(mbc6),         GED_RAM | GED_BATTERY };

    static const struct parsed_cart_type mbc7                 = { MBC(mbc7),         GED_RAM | GED_BATTERY | GED_ACCELEROMETER };

    static const struct parsed_cart_type pocket_cam           = { MBC(pocket_cam),   GED_RAM | GED_CAMERA };

    static const struct parsed_cart_type bandai_tama5         = { MBC(bandai_tama5), GED_NONE };

    static const struct parsed_cart_type huc3                 = { MBC(huc3),         GED_NONE };

    static const struct parsed_cart_type huc1                 = { MBC(huc1),         GED_RAM | GED_BATTERY };
#undef MBC

    switch(cart_type)
    {
    case 0x00: return &nombc_none;
    case 0x01: return &mbc1_none;
    case 0x02: return &mbc1_ram;
    case 0x03: return &mbc1_ram_batt;
    /* 0x04 is unused */
    case 0x05: return &mbc2_none;
    case 0x06: return &mbc2_ram_batt;
    /* 0x07 is unused */
    case 0x08: return &nombc_ram;
    case 0x09: return &nombc_ram_batt;
    /* 0x0a is unused */
    case 0x0b: return &mmm01_none;
    case 0x0c: return &mmm01_ram;
    case 0x0d: return &mmm01_ram_batt;
    /* 0x0e is unused */
    case 0x0f: return &mbc3_batt_rtc;
    case 0x10: return &mbc3_ram_batt_rtc;
    case 0x11: return &mbc3_none;
    case 0x12: return &mbc3_ram;
    case 0x13: return &mbc3_ram_batt;
    /* 0x14-0x18 are unused */
    case 0x19: return &mbc5_none;
    case 0x1a: return &mbc5_ram;
    case 0x1b: return &mbc5_ram_batt;
    case 0x1c: return &mbc5_rumble;
    case 0x1d: return &mbc5_ram_rumble;
    case 0x1e: return &mbc5_ram_batt_rumble;
    /* 0x1f is unused */
    case 0x20: return &mbc6;
    /* 0x21 is unused */
    case 0x22: return &mbc7;
    /* 0x23-0xfb are unused */
    case 0xfc: return &pocket_cam;
    case 0xfd: return &bandai_tama5;
    case 0xfe: return &huc3;
    case 0xff: return &huc1;
    default:   return NULL;
    }
}


void init_gb_cart(struct gb_cart* gb_cart,
        void* rom_opaque, void (*init_rom)(void* user_data, void** rom_storage, const struct storage_backend_interface** irom_storage), void (*release_rom)(void* user_data),
        void* ram_opaque, void (*init_ram)(void* user_data, size_t ram_size, void** ram_storage, const struct storage_backend_interface** iram_storage), void (*release_ram)(void* user_data),
        void* clock, const struct clock_backend_interface* iclock,
        void* rumble, const struct rumble_backend_interface* irumble)
{
    const struct parsed_cart_type* type;
    void* rom_storage = NULL;
    const struct storage_backend_interface* irom_storage = NULL;
    void* ram_storage = NULL;
    const struct storage_backend_interface* iram_storage = NULL;
    struct mbc3_rtc rtc;
    struct m64282fp cam;

    memset(&rtc, 0, sizeof(rtc));
    memset(&cam, 0, sizeof(cam));

    /* ask to load rom and initialize rom storage backend */
    init_rom(rom_opaque, &rom_storage, &irom_storage);

    /* handle no cart case */
    if (irom_storage == NULL) {
        goto no_cart;
    }

    /* check rom size */
    const uint8_t* rom_data = irom_storage->data(rom_storage);
    if (rom_data == NULL || irom_storage->size(rom_storage) < 0x8000)
    {
        DebugMessage(M64MSG_ERROR, "Invalid GB ROM file size (< 32k)");
        goto error_release_rom;
    }

    /* get and parse cart type */
    uint8_t cart_type = rom_data[0x147];
    type = parse_cart_type(cart_type);
    if (type == NULL)
    {
        DebugMessage(M64MSG_ERROR, "Invalid GB cart type (%02x)", cart_type);
        goto error_release_rom;
    }

    DebugMessage(M64MSG_INFO, "GB cart type (%02x) %s%s%s%s%s%s",
            cart_type,
            type->mbc,
            (type->extra_devices & GED_RAM)            ? " RAM" : "",
            (type->extra_devices & GED_BATTERY)        ? " BATT" : "",
            (type->extra_devices & GED_RTC)            ? " RTC" : "",
            (type->extra_devices & GED_RUMBLE)         ? " RUMBLE" : "",
            (type->extra_devices & GED_ACCELEROMETER)  ? " ACCEL" : "",
            (type->extra_devices & GED_CAMERA)         ? " CAM" : "");

    /* load ram (if present) */
    if (type->extra_devices & GED_RAM)
    {
        size_t ram_size = 0;
        switch(rom_data[0x149])
        {
        case 0x00: ram_size = (strcmp(type->mbc, "mbc2") == 0)
                            ? 0x200 /* MBC2 have an integrated 512x4bit RAM */
                            : 0;
                   break;
        case 0x01: ram_size =  1*0x800; break;
        case 0x02: ram_size =  4*0x800; break;
        case 0x03: ram_size = 16*0x800; break;
        case 0x04: ram_size = 64*0x800; break;
        case 0x05: ram_size = 32*0x800; break;
        }

        if (ram_size != 0)
        {
            init_ram(ram_opaque, ram_size, &ram_storage, &iram_storage);

            /* check that init_ram succeeded */
            if (iram_storage == NULL) {
                DebugMessage(M64MSG_ERROR, "Failed to initialize GB RAM");
                goto error_release_ram;
            }

            if (iram_storage->data(ram_storage) == NULL || iram_storage->size(ram_storage) != ram_size)
            {
                DebugMessage(M64MSG_ERROR, "Cannot get GB RAM (%d bytes)", ram_size);
                goto error_release_ram;
            }

            DebugMessage(M64MSG_INFO, "Using a %d bytes GB RAM", ram_size);
        }
    }

    /* set RTC clock (if present) */
    if (type->extra_devices & GED_RTC) {
        init_mbc3_rtc(&rtc, clock, iclock);
    }

    if (type->extra_devices & GED_CAMERA) {
        init_m64282fp(&cam);
    }

    /* update gb_cart */
    gb_cart->rom_storage = rom_storage;
    gb_cart->irom_storage = irom_storage;
    gb_cart->ram_storage = ram_storage;
    gb_cart->iram_storage = iram_storage;
    gb_cart->extra_devices = type->extra_devices;
    gb_cart->rtc = rtc;
    gb_cart->cam = cam;
    gb_cart->rumble = rumble;
    gb_cart->irumble = irumble;
    gb_cart->read_gb_cart = type->read_gb_cart;
    gb_cart->write_gb_cart = type->write_gb_cart;

    return;

error_release_ram:
    release_ram(ram_opaque);
error_release_rom:
    release_rom(rom_opaque);
no_cart:
    memset(gb_cart, 0, sizeof(*gb_cart));
}

void poweron_gb_cart(struct gb_cart* gb_cart)
{
    gb_cart->rom_bank = 1;
    gb_cart->ram_bank = 0;
    gb_cart->ram_enable = 0;
    gb_cart->mbc1_mode = 0;

    if (gb_cart->extra_devices & GED_RTC) {
        poweron_mbc3_rtc(&gb_cart->rtc);
    }

    if (gb_cart->extra_devices & GED_CAMERA) {
        poweron_m64282fp(&gb_cart->cam);
    }

    if (gb_cart->extra_devices & GED_RUMBLE) {
        gb_cart->irumble->exec(gb_cart->rumble, RUMBLE_STOP);
    }
}

int read_gb_cart(struct gb_cart* gb_cart, uint16_t address, uint8_t* data, size_t size)
{
    return gb_cart->read_gb_cart(gb_cart, address, data, size);
}

int write_gb_cart(struct gb_cart* gb_cart, uint16_t address, const uint8_t* data, size_t size)
{
    return gb_cart->write_gb_cart(gb_cart, address, data, size);
}

