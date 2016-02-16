/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - mpk_file.h                                              *
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

#ifndef M64P_MAIN_MPK_FILE_H
#define M64P_MAIN_MPK_FILE_H

#include <stddef.h>
#include <stdint.h>

#include "si/mempak.h"
#include "si/pif.h"

struct mpk_file
{
    uint8_t mempaks[GAME_CONTROLLERS_COUNT][MEMPAK_SIZE];
    const char* filename;
};

void open_mpk_file(struct mpk_file* mpk, const char* filename);
void close_mpk_file(struct mpk_file* mpk);

uint8_t* mpk_file_ptr(struct mpk_file* mpk, size_t controller_idx);

void save_mpk_file(void* opaque);

#endif
