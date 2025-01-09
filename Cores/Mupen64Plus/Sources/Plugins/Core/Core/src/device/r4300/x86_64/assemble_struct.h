/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - assemble_struct.h                                       *
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

#ifndef M64P_DEVICE_R4300_X86_64_ASSEMBLE_STRUCT_H
#define M64P_DEVICE_R4300_X86_64_ASSEMBLE_STRUCT_H

struct precomp_instr;

struct regcache_state {
    unsigned long long * reg_content[8];
    struct precomp_instr* last_access[8];
    struct precomp_instr* free_since[8];
    int dirty[8];
    int is64bits[8];
    unsigned long long *r0;
};

struct reg_cache
{
    int need_map;
    void *needed_registers[8];
    unsigned char jump_wrapper[84];
    int need_cop1_check;
};

struct jump_table
{
    unsigned int mi_addr;
    unsigned int pc_addr;
    unsigned int absolute64;
};

struct riprelative_table
{
    unsigned int   pc_addr;     /* index in bytes from start of x86_64 code block to the displacement value to write */
    unsigned int   extra_bytes; /* number of remaining instruction bytes (immediate data) after 4-byte displacement */
    unsigned char *global_dst;  /* 64-bit pointer to the data object */
};


#endif /* M64P_DEVICE_R4300_X86_64_ASSEMBLE_STRUCT_H */
