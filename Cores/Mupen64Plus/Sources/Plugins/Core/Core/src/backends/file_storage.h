/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - file_storage.h                                          *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2016 Bobby Smiles                                       *
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

#ifndef M64P_MAIN_FILE_STORAGE_H
#define M64P_MAIN_FILE_STORAGE_H

#include <stddef.h>
#include <stdint.h>

struct file_storage
{
    uint8_t* data;
    size_t size;
    const char* filename;
};


int open_file_storage(struct file_storage* storage, size_t size, const char* filename);
int open_rom_file_storage(struct file_storage* storage, const char* filename);
void close_file_storage(struct file_storage* storage);

extern const struct storage_backend_interface g_ifile_storage;
extern const struct storage_backend_interface g_ifile_storage_ro;
extern const struct storage_backend_interface g_isubfile_storage;

#endif
