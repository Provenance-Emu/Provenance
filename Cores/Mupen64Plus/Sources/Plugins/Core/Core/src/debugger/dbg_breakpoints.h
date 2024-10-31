/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - dbg_breakpoints.h                                       *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2008 DarkJeztr HyperHacker                              *
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

#ifndef __BREAKPOINTS_H__
#define __BREAKPOINTS_H__

#include "../api/m64p_types.h"

#include <stdint.h>

struct memory;

extern int g_NumBreakpoints;
extern m64p_breakpoint g_Breakpoints[];

int add_breakpoint(struct memory* mem, uint32_t address);
int add_breakpoint_struct(struct memory* mem, m64p_breakpoint *newbp);
void remove_breakpoint_by_address(struct memory* mem, uint32_t address);
void remove_breakpoint_by_num(struct memory* mem, int bpt);
void enable_breakpoint(struct memory* mem, int breakpoint);
void disable_breakpoint(struct memory* mem, int breakpoint);
int check_breakpoints(uint32_t address);
int check_breakpoints_on_mem_access(uint32_t pc, uint32_t address, uint32_t size, uint32_t flags);
int lookup_breakpoint(uint32_t address, uint32_t size, uint32_t flags);
int log_breakpoint(uint32_t PC, uint32_t Flag, uint32_t Access);
void replace_breakpoint_num(struct memory* mem, int, m64p_breakpoint*);

#endif  /* __BREAKPOINTS_H__ */

