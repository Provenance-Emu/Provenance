/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - r4300.h                                                 *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
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

#ifndef M64P_R4300_R4300_H
#define M64P_R4300_R4300_H

#include <stdint.h>

#include "ops.h"
#include "r4300_core.h"
#include "recomp.h"

extern precomp_instr *PC;

extern int stop, rompause;
extern unsigned int llbit;
extern int64_t reg[32], hi, lo;
extern long long int local_rs;
extern unsigned int delay_slot;
extern uint32_t skip_jump;
extern unsigned int dyna_interp;
extern unsigned int r4300emu;
extern uint32_t next_interupt;
extern uint32_t last_addr;
#define COUNT_PER_OP_DEFAULT 2
extern unsigned int count_per_op;
extern cpu_instruction_table current_instruction_table;

void r4300_reset_hard(void);
void r4300_reset_soft(void);
void r4300_execute(void);

// r4300 emulators
#define CORE_PURE_INTERPRETER 0
#define CORE_INTERPRETER      1
#define CORE_DYNAREC          2

#endif /* M64P_R4300_R4300_H */

