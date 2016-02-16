/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - r4300_core.h                                            *
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

#ifndef M64P_R4300_R4300_CORE_H
#define M64P_R4300_R4300_CORE_H

#include <stddef.h>
#include <stdint.h>

#include "cp0.h"
#include "cp1.h"
#include "interupt.h"
#include "mi_controller.h"
#include "tlb.h"

struct r4300_core
{
    struct mi_controller mi;
};

void init_r4300(struct r4300_core* r4300);

int64_t* r4300_regs(void);
int64_t* r4300_mult_hi(void);
int64_t* r4300_mult_lo(void);
unsigned int* r4300_llbit(void);
uint32_t* r4300_pc(void);

uint32_t* r4300_last_addr(void);
unsigned int* r4300_next_interrupt(void);

unsigned int get_r4300_emumode(void);

/* Allow cached/dynarec r4300 implementations to invalidate
 * their cached code at [address, address+size]
 *
 * If size == 0, r4300 implementation should invalidate
 * all cached code.
 */
void invalidate_r4300_cached_code(uint32_t address, size_t size);


/* Jump to the given address. This works for all r4300 emulator, but is slower.
 * Use this for common code which can be executed from any r4300 emulator. */
void generic_jump_to(unsigned int address);

void savestates_load_set_pc(uint32_t pc);

#endif
