/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - mpk_file.c                                              *
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

#include "mpk_file.h"

#include <stdlib.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "si/pif.h"
#include "util.h"

void open_mpk_file(struct mpk_file* mpk, const char* filename)
{
    size_t i;

    /* ! Take ownership of filename ! */
    mpk->filename = filename;

    /* try to load mpk file content */
    switch(read_from_file(mpk->filename, mpk->mempaks, GAME_CONTROLLERS_COUNT*MEMPAK_SIZE))
    {
    case file_open_error:
        /* if no prior file exists, provide default mempaks content */
        DebugMessage(M64MSG_VERBOSE, "couldn't open mem pak file '%s' for reading", mpk->filename);
        for(i = 0; i < GAME_CONTROLLERS_COUNT; ++i)
            format_mempak(mpk->mempaks[i]);
        break;
    case file_read_error:
        DebugMessage(M64MSG_WARNING, "failed to read mem pak file '%s'", mpk->filename);
        break;
    default:
        break;
    }
}

void close_mpk_file(struct mpk_file* mpk)
{
    free((void*)mpk->filename);
}

uint8_t* mpk_file_ptr(struct mpk_file* mpk, size_t controller_idx)
{
    return &mpk->mempaks[controller_idx][0];
}

void save_mpk_file(void* opaque)
{
    /* flush mempak to disk */
    struct mpk_file* mpk = (struct mpk_file*)opaque;

    switch(write_to_file(mpk->filename, mpk->mempaks, GAME_CONTROLLERS_COUNT*MEMPAK_SIZE))
    {
    case file_open_error:
        DebugMessage(M64MSG_WARNING, "couldn't open mem pak file '%s' for writing", mpk->filename);
        break;
    case file_write_error:
        DebugMessage(M64MSG_WARNING, "failed to write mem pak file '%s'", mpk->filename);
        break;
    default:
        break;
    }
}
