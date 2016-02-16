/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - reset.c                                                 *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
 *   Copyright (C) 2011 CasualJames                                        *
 *   Copyright (C) 2008-2009 Richard Goedeken                              *
 *   Copyright (C) 2008 Ebenblues Nmn Okaygo Tillin9                       *
 *   Hard reset based on code by hacktarux.                                *
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

#include <stdint.h>

#include "cached_interp.h"
#include "interupt.h"
#include "memory/memory.h"
#include "r4300.h"
#include "r4300_core.h"
#include "reset.h"

int reset_hard_job = 0;

void reset_hard(void)
{
    init_memory();
    r4300_reset_hard();
    r4300_reset_soft();
    last_addr = UINT32_C(0xa4000040);
    next_interupt = 624999;
    init_interupt();
    if(r4300emu != CORE_PURE_INTERPRETER)
    {
        free_blocks();
        init_blocks();
    }
    generic_jump_to(last_addr);
}

void reset_soft(void)
{
    add_interupt_event(HW2_INT, 0);  /* Hardware 2 Interrupt immediately */
    add_interupt_event(NMI_INT, 50000000);  /* Non maskable Interrupt after 1/2 second */
}
