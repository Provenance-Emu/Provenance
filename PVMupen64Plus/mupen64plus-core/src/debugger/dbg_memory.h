/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - dbg_memory.h                                            *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
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

void init_host_disassembler(void);

char* get_recompiled_opcode( uint32 address, int index );
char* get_recompiled_args( uint32 address, int index );
void* get_recompiled_addr( uint32 address, int index );
int get_num_recompiled( uint32 address );
int get_has_recompiled( uint32 address );

uint64 read_memory_64(uint32 addr);
uint64 read_memory_64_unaligned(uint32 addr);
void write_memory_64(uint32 addr, uint64 value);
void write_memory_64_unaligned(uint32 addr, uint64 value);
uint32 read_memory_32(uint32);
uint32 read_memory_32_unaligned(uint32 addr);
void write_memory_32(uint32, uint32);
void write_memory_32_unaligned(uint32 addr, uint32 value);
uint16 read_memory_16(uint32 addr);
void write_memory_16(uint32 addr, uint16 value);
uint8 read_memory_8(uint32 addr);
void write_memory_8(uint32 addr, uint8 value);
uint32 get_memory_flags(uint32);

#endif /* __DEBUGGER_MEMORY_H__ */

