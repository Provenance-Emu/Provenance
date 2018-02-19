/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - pif.h                                                   *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
 *   Copyright (C) 2002 Hacktarux                                          *
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

#ifndef M64P_SI_PIF_H
#define M64P_SI_PIF_H

#include <stdint.h>

#include "af_rtc.h"
#include "cic.h"
#include "eeprom.h"
#include "game_controller.h"

enum { GAME_CONTROLLERS_COUNT = 4 };

struct si_controller;

enum { PIF_RAM_SIZE = 0x40 };

enum pif_commands
{
    PIF_CMD_STATUS = 0x00,
    PIF_CMD_CONTROLLER_READ = 0x01,
    PIF_CMD_PAK_READ = 0x02,
    PIF_CMD_PAK_WRITE = 0x03,
    PIF_CMD_EEPROM_READ = 0x04,
    PIF_CMD_EEPROM_WRITE = 0x05,
    PIF_CMD_AF_RTC_STATUS = 0x06,
    PIF_CMD_AF_RTC_READ = 0x07,
    PIF_CMD_AF_RTC_WRITE = 0x08,
    PIF_CMD_RESET = 0xff,
};

struct pif
{
    uint8_t ram[PIF_RAM_SIZE];

    struct game_controller controllers[GAME_CONTROLLERS_COUNT];
    struct eeprom eeprom;
    struct af_rtc af_rtc;

    struct cic cic;
};

static uint32_t pif_ram_address(uint32_t address)
{
    return ((address & 0xfffc) - 0x7c0);
}


void init_pif(struct pif* pif);

int read_pif_ram(void* opaque, uint32_t address, uint32_t* value);
int write_pif_ram(void* opaque, uint32_t address, uint32_t value, uint32_t mask);

void update_pif_write(struct si_controller* si);
void update_pif_read(struct si_controller* si);

#endif

