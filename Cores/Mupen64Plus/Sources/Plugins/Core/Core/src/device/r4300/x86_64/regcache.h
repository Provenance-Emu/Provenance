/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - regcache.h                                              *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2007 Richard Goedeken (Richard42)                       *
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

#ifndef M64P_DEVICE_R4300_X86_64_REGCACHE_H
#define M64P_DEVICE_R4300_X86_64_REGCACHE_H

struct r4300_core;
struct precomp_instr;
struct precomp_block;

void init_cache(struct r4300_core* r4300, struct precomp_instr* start);
void free_registers_move_start(struct r4300_core* r4300);
void free_all_registers(struct r4300_core* r4300);
void free_register(struct r4300_core* r4300, int reg);
int is64(struct r4300_core* r4300, unsigned int *addr);
int lru_register(struct r4300_core* r4300);
int lru_base_register(struct r4300_core* r4300);
void set_register_state(struct r4300_core* r4300, int reg, unsigned int *addr, int dirty, int is64bits);
int lock_register(struct r4300_core* r4300, int reg);
void unlock_register(struct r4300_core* r4300, int reg);
int allocate_register_32(struct r4300_core* r4300, unsigned int *addr);
int allocate_register_64(struct r4300_core* r4300, unsigned long long *addr);
int allocate_register_32_w(struct r4300_core* r4300, unsigned int *addr);
int allocate_register_64_w(struct r4300_core* r4300, unsigned long long *addr);
void allocate_register_32_manually(struct r4300_core* r4300, int reg, unsigned int *addr);
void allocate_register_32_manually_w(struct r4300_core* r4300, int reg, unsigned int *addr);
void build_wrappers(struct r4300_core* r4300, struct precomp_instr*, int, int, struct precomp_block*);

#endif /* M64P_DEVICE_R4300_X86_64_REGCACHE_H */

