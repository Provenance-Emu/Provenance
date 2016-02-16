/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - sra_file.c                                              *
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

#include "sra_file.h"

#include <stdlib.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "pi/sram.h"
#include "util.h"

void open_sra_file(struct sra_file* sra, const char* filename)
{
    /* ! Take ownership of filename ! */
    sra->filename = filename;

    /* try to load sra file content */
    switch(read_from_file(sra->filename, sra->sram, SRAM_SIZE))
    {
    case file_open_error:
        /* if no prior file exists, provide default sram content */
        DebugMessage(M64MSG_VERBOSE, "couldn't open sram file '%s' for reading", sra->filename);
        format_sram(sra->sram);
        break;
    case file_read_error:
        DebugMessage(M64MSG_WARNING, "failed to read sram file '%s'", sra->filename);
        break;
    default:
        break;
    }
}

void close_sra_file(struct sra_file* sra)
{
    free((void*)sra->filename);
}

uint8_t* sra_file_ptr(struct sra_file* sra)
{
    return sra->sram;
}

void save_sra_file(void* opaque)
{
    /* flush sram to disk */
    struct sra_file* sra = (struct sra_file*)opaque;

    switch(write_to_file(sra->filename, sra->sram, SRAM_SIZE))
    {
    case file_open_error:
        DebugMessage(M64MSG_WARNING, "couldn't open sram file '%s' for writing", sra->filename);
        break;
    case file_write_error:
        DebugMessage(M64MSG_WARNING, "failed to write sram file '%s'", sra->filename);
        break;
    default:
        break;
    }
}

