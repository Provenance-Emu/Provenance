/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - eep_file.h                                              *
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

#ifndef M64P_MAIN_EEP_FILE_H
#define M64P_MAIN_EEP_FILE_H

#include <stdint.h>

/* Note: EEP files are all EEPROM_MAX_SIZE bytes long,
 * whatever the real EEPROM size is.
 */

enum { EEPROM_MAX_SIZE = 0x800 };

struct eep_file
{
    uint8_t eeprom[EEPROM_MAX_SIZE];
    const char* filename;
};

void open_eep_file(struct eep_file* eep, const char* filename);
void close_eep_file(struct eep_file* eep);

uint8_t* eep_file_ptr(struct eep_file* eep);

void save_eep_file(void* opaque);

#endif
