/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - regcache.h                                              *
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

#ifndef M64P_DEVICE_R4300_X86_REGCACHE_H
#define M64P_DEVICE_R4300_X86_REGCACHE_H

struct r4300_core;
struct precomp_instr;
struct precomp_block;

void init_cache(struct r4300_core* r4300, struct precomp_instr* start);
void free_all_registers(struct r4300_core* r4300);
void free_register(struct r4300_core* r4300, int reg);
int allocate_register(struct r4300_core* r4300, unsigned int *addr);
int allocate_64_register1(struct r4300_core* r4300, unsigned int *addr);
int allocate_64_register2(struct r4300_core* r4300, unsigned int *addr);
int is64(struct r4300_core* r4300, unsigned int *addr);
void build_wrappers(struct r4300_core* r4300, struct precomp_instr*, int, int, struct precomp_block*);
int lru_register(struct r4300_core* r4300);
int allocate_register_w(struct r4300_core* r4300, unsigned int *addr);
int allocate_64_register1_w(struct r4300_core* r4300, unsigned int *addr);
int allocate_64_register2_w(struct r4300_core* r4300, unsigned int *addr);
void set_register_state(struct r4300_core* r4300, int reg, unsigned int *addr, int dirty);
void set_64_register_state(struct r4300_core* r4300, int reg1, int reg2, unsigned int *addr, int dirty);
void allocate_register_manually(struct r4300_core* r4300, int reg, unsigned int *addr);
void allocate_register_manually_w(struct r4300_core* r4300, int reg, unsigned int *addr, int load);
int lru_register_exc1(struct r4300_core* r4300, int exc1);
void simplify_access(struct r4300_core* r4300);

#endif /* M64P_DEVICE_R4300_X86_REGCACHE_H */

