/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - assemble.c                                              *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
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

#include <stdio.h>
#include <stdlib.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "assemble.h"
#include "assemble_struct.h"
#include "regcache.h"
#include "device/r4300/recomp.h"
#include "osal/preproc.h"

void init_assembler(struct r4300_core* r4300, void *block_jumps_table, int block_jumps_number, void *block_riprel_table, int block_riprel_number)
{
    if (block_jumps_table)
    {
        r4300->recomp.jumps_table = (struct jump_table *) block_jumps_table;
        r4300->recomp.jumps_number = block_jumps_number;
        r4300->recomp.max_jumps_number = r4300->recomp.jumps_number;
    }
    else
    {
        r4300->recomp.jumps_table = (struct jump_table *) malloc(1000*sizeof(struct jump_table));
        r4300->recomp.jumps_number = 0;
        r4300->recomp.max_jumps_number = 1000;
    }
}

void free_assembler(struct r4300_core* r4300, void **block_jumps_table, int *block_jumps_number, void **block_riprel_table, int *block_riprel_number)
{
    *block_jumps_table = r4300->recomp.jumps_table;
    *block_jumps_number = r4300->recomp.jumps_number;
    *block_riprel_table = NULL;  /* RIP-relative addressing is only for x86-64 */
    *block_riprel_number = 0;
}

void add_jump(struct r4300_core* r4300, unsigned int pc_addr, unsigned int mi_addr)
{
    if (r4300->recomp.jumps_number == r4300->recomp.max_jumps_number)
    {
        r4300->recomp.max_jumps_number += 1000;
        r4300->recomp.jumps_table = (struct jump_table *) realloc(r4300->recomp.jumps_table, r4300->recomp.max_jumps_number*sizeof(struct jump_table));
    }
    r4300->recomp.jumps_table[r4300->recomp.jumps_number].pc_addr = pc_addr;
    r4300->recomp.jumps_table[r4300->recomp.jumps_number].mi_addr = mi_addr;
    r4300->recomp.jumps_number++;
}

void passe2(struct r4300_core* r4300, struct precomp_instr *dest, int start, int end, struct precomp_block *block)
{
    unsigned int real_code_length, addr_dest;
    size_t i;
    build_wrappers(r4300, dest, start, end, block);
    real_code_length = r4300->recomp.code_length;

    for (i=0; i < r4300->recomp.jumps_number; i++)
    {
        r4300->recomp.code_length = r4300->recomp.jumps_table[i].pc_addr;
        if (dest[(r4300->recomp.jumps_table[i].mi_addr - dest[0].addr)/4].reg_cache_infos.need_map)
        {
            addr_dest = (unsigned int)dest[(r4300->recomp.jumps_table[i].mi_addr - dest[0].addr)/4].reg_cache_infos.jump_wrapper;
            put32(addr_dest-((unsigned int)block->code+r4300->recomp.code_length)-4);
        }
        else
        {
            addr_dest = dest[(r4300->recomp.jumps_table[i].mi_addr - dest[0].addr)/4].local_addr;
            put32(addr_dest-r4300->recomp.code_length-4);
        }
    }
    r4300->recomp.code_length = real_code_length;
}

void jump_start_rel8(struct r4300_core* r4300)
{
    r4300->recomp.jump_start8 = r4300->recomp.code_length;
}

void jump_start_rel32(struct r4300_core* r4300)
{
    r4300->recomp.jump_start32 = r4300->recomp.code_length;
}

void jump_end_rel8(struct r4300_core* r4300)
{
    unsigned int jump_end = r4300->recomp.code_length;
    int jump_vec = jump_end - r4300->recomp.jump_start8;

    if (jump_vec > 127 || jump_vec < -128)
    {
        DebugMessage(M64MSG_ERROR, "8-bit relative jump too long! From %x to %x", r4300->recomp.jump_start8, jump_end);
        OSAL_BREAKPOINT_INTERRUPT;
    }

    r4300->recomp.code_length = r4300->recomp.jump_start8 - 1;
    put8(jump_vec);
    r4300->recomp.code_length = jump_end;
}

void jump_end_rel32(struct r4300_core* r4300)
{
    unsigned int jump_end = r4300->recomp.code_length;
    int jump_vec = jump_end - r4300->recomp.jump_start32;

    r4300->recomp.code_length = r4300->recomp.jump_start32 - 4;
    put32(jump_vec);
    r4300->recomp.code_length = jump_end;
}
