/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - dbg_memory.h                                            *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2008 DarkJeztr                                          *
 *   Copyright (C) 2002 davFr                                              *
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

#ifndef __DEBUGGER_MEMORY_H__
#define __DEBUGGER_MEMORY_H__

#define MAX_DISASSEMBLY 64

#include <stdint.h>

struct device;
struct r4300_core;

void init_host_disassembler(void);

char* get_recompiled_opcode(struct r4300_core* r4300, uint32_t address, int index);
char* get_recompiled_args(struct r4300_core* r4300, uint32_t address, int index);
void* get_recompiled_addr(struct r4300_core* r4300, uint32_t address, int index);
int get_num_recompiled(struct r4300_core* r4300, uint32_t address );
int get_has_recompiled(struct r4300_core* r4300, uint32_t address );

uint64_t read_memory_64(struct device* dev, uint32_t addr);
uint64_t read_memory_64_unaligned(struct device* dev, uint32_t addr);
void write_memory_64(struct device* dev, uint32_t addr, uint64_t value);
void write_memory_64_unaligned(struct device* dev, uint32_t addr, uint64_t value);
uint32_t read_memory_32(struct device* dev, uint32_t addr);
uint32_t read_memory_32_unaligned(struct device* dev, uint32_t addr);
void write_memory_32(struct device* dev, uint32_t addr, uint32_t value);
void write_memory_32_unaligned(struct device* dev, uint32_t addr, uint32_t value);
uint16_t read_memory_16(struct device* dev, uint32_t addr);
void write_memory_16(struct device* dev, uint32_t addr, uint16_t value);
uint8_t read_memory_8(struct device* dev, uint32_t addr);
void write_memory_8(struct device* dev, uint32_t addr, uint8_t value);
uint32_t get_memory_flags(struct device* dev, uint32_t addr);

#endif /* __DEBUGGER_MEMORY_H__ */

