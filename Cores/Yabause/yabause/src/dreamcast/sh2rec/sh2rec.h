/*  Copyright 2010 Lawrence Sebald

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
*/

#ifndef SH2REC_H
#define SH2REC_H

#define SH2CORE_DYNAREC         10

#define INSTRUCTION_A(x) ((x & 0xF000) >> 12)
#define INSTRUCTION_B(x) ((x & 0x0F00) >> 8)
#define INSTRUCTION_C(x) ((x & 0x00F0) >> 4)
#define INSTRUCTION_D(x) (x & 0x000F)
#define INSTRUCTION_CD(x) (x & 0x00FF)
#define INSTRUCTION_BCD(x) (x & 0x0FFF)

typedef struct sh2rec_block {
    u16 *block;
    u32 start_pc;
    int cycles;
    int length;

    u16 *ptr;
    u32 pc;
} sh2rec_block_t;

/* Recompile a single instruction */
int sh2rec_rec_inst(sh2rec_block_t *b, int isdelay);

/* Recompile a block at the PC specified in the block */
int sh2rec_rec_block(sh2rec_block_t *b);

extern SH2Interface_struct SH2Dynarec;

#endif /* !SH2REC_H */
