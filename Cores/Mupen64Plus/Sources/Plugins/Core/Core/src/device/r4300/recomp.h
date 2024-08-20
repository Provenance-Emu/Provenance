/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - recomp.h                                                *
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

#ifndef M64P_DEVICE_R4300_RECOMP_H
#define M64P_DEVICE_R4300_RECOMP_H

#include <stddef.h>
#include <stdint.h>

struct r4300_core;
struct precomp_block;

void dynarec_init_block(struct r4300_core* r4300, uint32_t address);
void dynarec_free_block(struct precomp_block* block);
void dynarec_recompile_block(struct r4300_core* r4300, const uint32_t* source, struct precomp_block* block, uint32_t func);
void recompile_opcode(struct r4300_core* r4300);
void dyna_jump(void);
void dyna_start(void (*code)(void));
void dyna_stop(struct r4300_core* r4300);
void *realloc_exec(void *ptr, size_t oldsize, size_t newsize);

void (*const recomp_ops[64])(struct r4300_core* r4300);

void dynarec_jump_to(struct r4300_core* r4300, uint32_t address);

void dynarec_fin_block(void);
void dynarec_notcompiled(void);
void dynarec_notcompiled2(void);
void dynarec_setup_code(void);
void dynarec_jump_to_recomp_address(void);
void dynarec_exception_general(void);
int dynarec_check_cop1_unusable(void);
void dynarec_cp0_update_count(void);
void dynarec_gen_interrupt(void);
int dynarec_read_aligned_word(void);
int dynarec_write_aligned_word(void);
int dynarec_read_aligned_dword(void);
int dynarec_write_aligned_dword(void);


#if defined(PROFILE_R4300)
void profile_write_end_of_code_blocks(struct r4300_core* r4300);
#endif

#endif /* M64P_DEVICE_R4300_RECOMP_H */

