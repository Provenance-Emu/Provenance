/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - fla_file.c                                              *
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

#include "fla_file.h"

#include <stdlib.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "pi/flashram.h"
#include "util.h"

void open_fla_file(struct fla_file* fla, const char* filename)
{
    /* ! Take ownership of filename ! */
    fla->filename = filename;

    /* try to load fla file content */
    switch(read_from_file(fla->filename, fla->flashram, FLASHRAM_SIZE))
    {
    case file_open_error:
        /* if no prior file exists, provide default flashram content */
        DebugMessage(M64MSG_VERBOSE, "couldn't open sram file '%s' for reading", fla->filename);
        format_flashram(fla->flashram);
        break;
    case file_read_error:
        DebugMessage(M64MSG_WARNING, "failed to read flashram file '%s'", fla->filename);
        break;
    default:
        break;
    }
}

void close_fla_file(struct fla_file* fla)
{
    free((void*)fla->filename);
}

uint8_t* fla_file_ptr(struct fla_file* fla)
{
    return fla->flashram;
}

void save_fla_file(void* opaque)
{
    /* flush flashram to disk */
    struct fla_file* fla = (struct fla_file*)opaque;

    switch(write_to_file(fla->filename, fla->flashram, FLASHRAM_SIZE))
    {
    case file_open_error:
        DebugMessage(M64MSG_WARNING, "couldn't open flashram file '%s' for writing", fla->filename);
        break;
    case file_write_error:
        DebugMessage(M64MSG_WARNING, "failed to write flashram file '%s'", fla->filename);
        break;
    default:
        break;
    }

}

