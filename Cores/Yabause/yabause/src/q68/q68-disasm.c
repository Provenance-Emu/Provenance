/*  src/q68/q68-disasm.c: MC68000 disassembly routines
    Copyright 2009 Andrew Church

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
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "q68.h"
#include "q68-const.h"
#include "q68-internal.h"

/*************************************************************************/
/********************** 68k instruction disassembly **********************/
/*************************************************************************/

/* Disassembly table.  The first entry matching a given instruction is used. */

static const struct {
    uint16_t mask, test;  // Entry matches when (opcode & mask) == test
    const char *format;   // Instruction format
} instructions[] = {

    /* ALU immediate */

    {0xFFFF, 0x003C, "ORI.B #<imm8>,CCR"},
    {0xFFC0, 0x0000, "ORI.B #<imm8>,<ea.b>"},
    {0xFFFF, 0x007C, "ORI.W #<imm8>,SR"},
    {0xFFC0, 0x0040, "ORI.W #<imm16>,<ea.w>"},
    {0xFFC0, 0x0080, "ORI.L #<imm16>,<ea.l>"},
    {0xFFFF, 0x023C, "ANDI.B #<imm8>,CCR"},
    {0xFFC0, 0x0200, "ANDI.B #<imm8>,<ea.b>"},
    {0xFFFF, 0x027C, "ANDI.W #<imm8>,SR"},
    {0xFFC0, 0x0240, "ANDI.W #<imm16>,<ea.w>"},
    {0xFFC0, 0x0280, "ANDI.L #<imm16>,<ea.l>"},
    {0xFFC0, 0x0400, "SUBI.B #<imm8>,<ea.b>"},
    {0xFFC0, 0x0440, "SUBI.W #<imm16>,<ea.w>"},
    {0xFFC0, 0x0480, "SUBI.L #<imm16>,<ea.l>"},
    {0xFFC0, 0x0600, "ADDI.B #<imm8>,<ea.b>"},
    {0xFFC0, 0x0640, "ADDI.W #<imm16>,<ea.w>"},
    {0xFFC0, 0x0680, "ADDI.L #<imm16>,<ea.l>"},
    {0xFFFF, 0x0A3C, "EORI.B #<imm8>,CCR"},
    {0xFFC0, 0x0A00, "EORI.B #<imm8>,<ea.b>"},
    {0xFFFF, 0x0A7C, "EORI.W #<imm8>,SR"},
    {0xFFC0, 0x0A40, "EORI.W #<imm16>,<ea.w>"},
    {0xFFC0, 0x0A80, "EORI.L #<imm16>,<ea.l>"},
    {0xFFC0, 0x0C00, "CMPI.B #<imm8>,<ea.b>"},
    {0xFFC0, 0x0C40, "CMPI.W #<imm16>,<ea.w>"},
    {0xFFC0, 0x0C80, "CMPI.L #<imm16>,<ea.l>"},

    /* Bit twiddling and MOVEP */

    {0xF1F8, 0x0108, "MOVEP.W <imm16d>(A<reg0>),D<reg>"},
    {0xF1F8, 0x0148, "MOVEP.L <imm16d>(A<reg0>),D<reg>"},
    {0xF1F8, 0x0188, "MOVEP.W D<reg>,<imm16d>(A<reg0>)"},
    {0xF1F8, 0x01C8, "MOVEP.L D<reg>,<imm16d>(A<reg0>)"},
    {0xFFC0, 0x0800, "BTST #<imm16d>,<ea.b>"},
    {0xFFC0, 0x0840, "BCHG #<imm16d>,<ea.b>"},
    {0xFFC0, 0x0880, "BCLR #<imm16d>,<ea.b>"},
    {0xFFC0, 0x08C0, "BSET #<imm16d>,<ea.b>"},
    {0xF1C0, 0x0100, "BTST D<reg>,<ea.b>"},
    {0xF1C0, 0x0140, "BCHG D<reg>,<ea.b>"},
    {0xF1C0, 0x0180, "BCLR D<reg>,<ea.b>"},
    {0xF1C0, 0x01C0, "BSET D<reg>,<ea.b>"},

    /* MOVE */

    {0xF1C0, 0x1040, "MOVEA.B <ea.b>,A<reg>"},
    {0xF000, 0x1000, "MOVE.B <ea.b>,<ea2.b>"},
    {0xF1C0, 0x2040, "MOVEA.L <ea.l>,A<reg>"},
    {0xF000, 0x2000, "MOVE.L <ea.l>,<ea2.l>"},
    {0xF1C0, 0x3040, "MOVEA.W <ea.w>,A<reg>"},
    {0xF000, 0x3000, "MOVE.W <ea.w>,<ea2.w>"},

    /* Miscellaneous */

    {0xFFC0, 0x4000, "NEGX.B <ea.b>"},
    {0xFFC0, 0x4040, "NEGX.W <ea.w>"},
    {0xFFC0, 0x4080, "NEGX.L <ea.l>"},
    {0xFFC0, 0x40C0, "MOVE.W SR,<ea.w>"},

    {0xFFC0, 0x4200, "CLR.B <ea.b>"},
    {0xFFC0, 0x4240, "CLR.W <ea.w>"},
    {0xFFC0, 0x4280, "CLR.L <ea.l>"},
    {0xFFC0, 0x42C0, "???"},

    {0xFFC0, 0x4400, "NEG.B <ea.b>"},
    {0xFFC0, 0x4440, "NEG.W <ea.w>"},
    {0xFFC0, 0x4480, "NEG.L <ea.l>"},
    {0xFFC0, 0x44C0, "MOVE.W CCR,<ea.w>"},

    {0xFFC0, 0x4600, "NOT.B <ea.b>"},
    {0xFFC0, 0x4640, "NOT.W <ea.w>"},
    {0xFFC0, 0x4680, "NOT.L <ea.l>"},
    {0xFFC0, 0x46C0, "MOVE.W <ea.w>,SR"},

    {0xFFF8, 0x4808, "???"},
    {0xFFC0, 0x4800, "NBCD.B <ea.b>"},
    {0xFFF8, 0x4840, "SWAP.W D<reg0>"},
    {0xFFF8, 0x4848, "???"},
    {0xFFC0, 0x4840, "PEA.L <ea.w>"},
    {0xFFF8, 0x4880, "EXT.W D<reg0>"},
    {0xFFF8, 0x48A0, "MOVEM.W <tsilger>,-(A<reg0>)"},
    {0xFFC0, 0x4880, "MOVEM.W <reglist>,<ea.w>"},
    {0xFFF8, 0x48C0, "EXT.L D<reg0>"},
    {0xFFF8, 0x48E0, "MOVEM.L <tsilger>,-(A<reg0>)"},
    {0xFFC0, 0x48C0, "MOVEM.L <reglist>,<ea.l>"},

    {0xFFC0, 0x4A00, "TST.B <ea.b>"},
    {0xFFC0, 0x4A40, "TST.W <ea.w>"},
    {0xFFC0, 0x4A80, "TST.L <ea.l>"},
    {0xFFFF, 0x4AFC, "ILLEGAL"},
    {0xFFC0, 0x4AC0, "TAS <ea.b>"},

    {0xFFC0, 0x4C80, "MOVEM.W <ea.w>,<reglist>"},
    {0xFFC0, 0x4CC0, "MOVEM.L <ea.l>,<reglist>"},

    {0xFFF0, 0x4E40, "TRAP #<trap>"},
    {0xFFF8, 0x4E50, "LINK #<imm16>,A<reg0>"},
    {0xFFF8, 0x4E58, "UNLK A<reg0>"},
    {0xFFF8, 0x4E60, "MOVE USP,A<reg0>"},
    {0xFFF8, 0x4E68, "MOVE A<reg0>,USP"},
    {0xFFFF, 0x4E70, "RESET"},
    {0xFFFF, 0x4E71, "NOP"},
    {0xFFFF, 0x4E72, "STOP"},
    {0xFFFF, 0x4E73, "RTE"},
    {0xFFFF, 0x4E75, "RTS"},
    {0xFFFF, 0x4E76, "TRAPV"},
    {0xFFFF, 0x4E77, "RTR"},
    {0xFFC0, 0x4E80, "JSR <ea.l>"},
    {0xFFC0, 0x4EC0, "JMP <ea.l>"},

    {0xF1C0, 0x4180, "CHK.W D<reg>,<ea.w>"},
    {0xF1C0, 0x41C0, "LEA.L <ea.w>,A<reg>"},

    /* ADDQ/SUBQ/Scc/DBcc */

    {0xF1C0, 0x5000, "ADDQ.B #<count>,<ea.b>"},
    {0xF1C0, 0x5040, "ADDQ.W #<count>,<ea.w>"},
    {0xF1C0, 0x5080, "ADDQ.L #<count>,<ea.l>"},
    {0xF1C0, 0x5100, "SUBQ.B #<count>,<ea.b>"},
    {0xF1C0, 0x5140, "SUBQ.W #<count>,<ea.w>"},
    {0xF1C0, 0x5180, "SUBQ.L #<count>,<ea.l>"},
    {0xFFF8, 0x50C8, "DBT D<reg0>,<pcrel16>"},
    {0xFFC0, 0x50C0, "ST.B <ea.b>"},
    {0xFFF8, 0x51C8, "DBRA D<reg0>,<pcrel16>"},
    {0xFFC0, 0x51C0, "SF.B <ea.b>"},
    {0xFFF8, 0x52C8, "DBHI D<reg0>,<pcrel16>"},
    {0xFFC0, 0x52C0, "SHI.B <ea.b>"},
    {0xFFF8, 0x53C8, "DBLS D<reg0>,<pcrel16>"},
    {0xFFC0, 0x53C0, "SLS.B <ea.b>"},
    {0xFFF8, 0x54C8, "DBCC D<reg0>,<pcrel16>"},
    {0xFFC0, 0x54C0, "SCC.B <ea.b>"},
    {0xFFF8, 0x55C8, "DBCS D<reg0>,<pcrel16>"},
    {0xFFC0, 0x55C0, "SCS.B <ea.b>"},
    {0xFFF8, 0x56C8, "DBNE D<reg0>,<pcrel16>"},
    {0xFFC0, 0x56C0, "SNE.B <ea.b>"},
    {0xFFF8, 0x57C8, "DBEQ D<reg0>,<pcrel16>"},
    {0xFFC0, 0x57C0, "SEQ.B <ea.b>"},
    {0xFFF8, 0x58C8, "DBVC D<reg0>,<pcrel16>"},
    {0xFFC0, 0x58C0, "SVC.B <ea.b>"},
    {0xFFF8, 0x59C8, "DBVS D<reg0>,<pcrel16>"},
    {0xFFC0, 0x59C0, "SVS.B <ea.b>"},
    {0xFFF8, 0x5AC8, "DBPL D<reg0>,<pcrel16>"},
    {0xFFC0, 0x5AC0, "SPL.B <ea.b>"},
    {0xFFF8, 0x5BC8, "DBMI D<reg0>,<pcrel16>"},
    {0xFFC0, 0x5BC0, "SMI.B <ea.b>"},
    {0xFFF8, 0x5CC8, "DBLT D<reg0>,<pcrel16>"},
    {0xFFC0, 0x5CC0, "SLT.B <ea.b>"},
    {0xFFF8, 0x5DC8, "DBGE D<reg0>,<pcrel16>"},
    {0xFFC0, 0x5DC0, "SGE.B <ea.b>"},
    {0xFFF8, 0x5EC8, "DBLE D<reg0>,<pcrel16>"},
    {0xFFC0, 0x5EC0, "SLE.B <ea.b>"},
    {0xFFF8, 0x5FC8, "DBGT D<reg0>,<pcrel16>"},
    {0xFFC0, 0x5FC0, "SGT.B <ea.b>"},

    /* BRA/BSR/Bcc */

    {0xFFFF, 0x6000, "BRA.W <pcrel16>"},
    {0xFF00, 0x6000, "BRA.S <pcrel8>"},
    {0xFFFF, 0x6100, "BSR.W <pcrel16>"},
    {0xFF00, 0x6100, "BSR.S <pcrel8>"},
    {0xFFFF, 0x6200, "BHI.W <pcrel16>"},
    {0xFF00, 0x6200, "BHI.S <pcrel8>"},
    {0xFFFF, 0x6300, "BLS.W <pcrel16>"},
    {0xFF00, 0x6300, "BLS.S <pcrel8>"},
    {0xFFFF, 0x6400, "BCC.W <pcrel16>"},
    {0xFF00, 0x6400, "BCC.S <pcrel8>"},
    {0xFFFF, 0x6500, "BCS.W <pcrel16>"},
    {0xFF00, 0x6500, "BCS.S <pcrel8>"},
    {0xFFFF, 0x6600, "BNE.W <pcrel16>"},
    {0xFF00, 0x6600, "BNE.S <pcrel8>"},
    {0xFFFF, 0x6700, "BEQ.W <pcrel16>"},
    {0xFF00, 0x6700, "BEQ.S <pcrel8>"},
    {0xFFFF, 0x6800, "BVC.W <pcrel16>"},
    {0xFF00, 0x6800, "BVC.S <pcrel8>"},
    {0xFFFF, 0x6900, "BVS.W <pcrel16>"},
    {0xFF00, 0x6900, "BVS.S <pcrel8>"},
    {0xFFFF, 0x6A00, "BPL.W <pcrel16>"},
    {0xFF00, 0x6A00, "BPL.S <pcrel8>"},
    {0xFFFF, 0x6B00, "BMI.W <pcrel16>"},
    {0xFF00, 0x6B00, "BMI.S <pcrel8>"},
    {0xFFFF, 0x6C00, "BLT.W <pcrel16>"},
    {0xFF00, 0x6C00, "BLT.S <pcrel8>"},
    {0xFFFF, 0x6D00, "BGE.W <pcrel16>"},
    {0xFF00, 0x6D00, "BGE.S <pcrel8>"},
    {0xFFFF, 0x6E00, "BLE.W <pcrel16>"},
    {0xFF00, 0x6E00, "BLE.S <pcrel8>"},
    {0xFFFF, 0x6F00, "BGT.W <pcrel16>"},
    {0xFF00, 0x6F00, "BGT.S <pcrel8>"},

    /* MOVEQ */

    {0xF100, 0x7000, "MOVEQ #<quick8>,D<reg>"},

    /* ALU non-immediate,ABCD/SBCD etc. */

    {0xF1F8, 0x8100, "SBCD.B D<reg0>,D<reg>"},
    {0xF1F8, 0x8108, "SBCD.B -(A<reg0>),-(A<reg>)"},
    {0xF1F0, 0x8140, "???"},
    {0xF1F0, 0x8180, "???"},
    {0xF1C0, 0x8000, "OR.B <ea.b>,D<reg>"},
    {0xF1C0, 0x8040, "OR.W <ea.w>,D<reg>"},
    {0xF1C0, 0x8080, "OR.L <ea.l>,D<reg>"},
    {0xF1C0, 0x80C0, "DIVU <ea.w>,D<reg>"},
    {0xF1C0, 0x8100, "OR.B D<reg>,<ea.b>"},
    {0xF1C0, 0x8140, "OR.W D<reg>,<ea.w>"},
    {0xF1C0, 0x8180, "OR.L D<reg>,<ea.l>"},
    {0xF1C0, 0x81C0, "DIVS <ea.w>,D<reg>"},

    {0xF1F8, 0x9100, "SUBX.B D<reg0>,D<reg>"},
    {0xF1F8, 0x9108, "SUBX.B -(A<reg0>),-(A<reg>)"},
    {0xF1F8, 0x9140, "SUBX.W D<reg0>,D<reg>"},
    {0xF1F8, 0x9148, "SUBX.W -(A<reg0>),-(A<reg>)"},
    {0xF1F8, 0x9180, "SUBX.L D<reg0>,D<reg>"},
    {0xF1F8, 0x9188, "SUBX.L -(A<reg0>),-(A<reg>)"},
    {0xF1C0, 0x9000, "SUB.B <ea.b>,D<reg>"},
    {0xF1C0, 0x9040, "SUB.W <ea.w>,D<reg>"},
    {0xF1C0, 0x9080, "SUB.L <ea.l>,D<reg>"},
    {0xF1C0, 0x90C0, "SUBA.W <ea.w>,A<reg>"},
    {0xF1C0, 0x9100, "SUB.B D<reg>,<ea.b>"},
    {0xF1C0, 0x9140, "SUB.W D<reg>,<ea.w>"},
    {0xF1C0, 0x9180, "SUB.L D<reg>,<ea.l>"},
    {0xF1C0, 0x91C0, "SUBA.L <ea.l>,A<reg>"},

    {0xF1F8, 0xB108, "CMPM.B -(A<reg0>),-(A<reg>)"},
    {0xF1F8, 0xB148, "CMPM.W -(A<reg0>),-(A<reg>)"},
    {0xF1F8, 0xB188, "CMPM.L -(A<reg0>),-(A<reg>)"},
    {0xF1C0, 0xB000, "CMP.B <ea.b>,D<reg>"},
    {0xF1C0, 0xB040, "CMP.W <ea.w>,D<reg>"},
    {0xF1C0, 0xB080, "CMP.L <ea.l>,D<reg>"},
    {0xF1C0, 0xB0C0, "CMPA.W <ea.w>,A<reg>"},
    {0xF1C0, 0xB100, "CMP.B D<reg>,<ea.b>"},
    {0xF1C0, 0xB140, "CMP.W D<reg>,<ea.w>"},
    {0xF1C0, 0xB180, "CMP.L D<reg>,<ea.l>"},
    {0xF1C0, 0xB1C0, "CMPA.L <ea.w>,A<reg>"},

    {0xF1F8, 0xC100, "ABCD.B D<reg0>,D<reg>"},
    {0xF1F8, 0xC108, "ABCD.B -(A<reg0>),-(A<reg>)"},
    {0xF1F8, 0xC140, "EXG.L D<reg0>,D<reg>"},
    {0xF1F8, 0xC148, "EXG.L A<reg0>,A<reg>"},
    {0xF1F8, 0xC180, "???"},
    {0xF1F8, 0xC188, "EXG.L A<reg0>,D<reg>"},
    {0xF1C0, 0xC000, "AND.B <ea.b>,D<reg>"},
    {0xF1C0, 0xC040, "AND.W <ea.w>,D<reg>"},
    {0xF1C0, 0xC080, "AND.L <ea.l>,D<reg>"},
    {0xF1C0, 0xC0C0, "MULU <ea.w>,D<reg>"},
    {0xF1C0, 0xC100, "AND.B D<reg>,<ea.b>"},
    {0xF1C0, 0xC140, "AND.W D<reg>,<ea.w>"},
    {0xF1C0, 0xC180, "AND.L D<reg>,<ea.l>"},
    {0xF1C0, 0xC1C0, "MULS <ea.w>,D<reg>"},

    {0xF1F8, 0xD100, "ADDX.B D<reg0>,D<reg>"},
    {0xF1F8, 0xD108, "ADDX.B -(A<reg0>),-(A<reg>)"},
    {0xF1F8, 0xD140, "ADDX.W D<reg0>,D<reg>"},
    {0xF1F8, 0xD148, "ADDX.W -(A<reg0>),-(A<reg>)"},
    {0xF1F8, 0xD180, "ADDX.L D<reg0>,D<reg>"},
    {0xF1F8, 0xD188, "ADDX.L -(A<reg0>),-(A<reg>)"},
    {0xF1C0, 0xD000, "ADD.B <ea.b>,D<reg>"},
    {0xF1C0, 0xD040, "ADD.W <ea.w>,D<reg>"},
    {0xF1C0, 0xD080, "ADD.L <ea.l>,D<reg>"},
    {0xF1C0, 0xD0C0, "ADDA.W <ea.w>,A<reg>"},
    {0xF1C0, 0xD100, "ADD.B D<reg>,<ea.b>"},
    {0xF1C0, 0xD140, "ADD.W D<reg>,<ea.w>"},
    {0xF1C0, 0xD180, "ADD.L D<reg>,<ea.l>"},
    {0xF1C0, 0xD1C0, "ADDA.L <ea.l>,A<reg>"},

    /* Shift/rotate instructions */

    {0xF1F8, 0xE000, "ASR.B #<count>,D<reg0>"},
    {0xF1F8, 0xE008, "LSR.B #<count>,D<reg0>"},
    {0xF1F8, 0xE010, "ROXR.B #<count>,D<reg0>"},
    {0xF1F8, 0xE018, "ROR.B #<count>,D<reg0>"},
    {0xF1F8, 0xE020, "ASR.B D<reg>,D<reg0>"},
    {0xF1F8, 0xE028, "LSR.B D<reg>,D<reg0>"},
    {0xF1F8, 0xE030, "ROXR.B D<reg>,D<reg0>"},
    {0xF1F8, 0xE038, "ROR.B D<reg>,D<reg0>"},

    {0xF1F8, 0xE040, "ASR.W #<count>,D<reg0>"},
    {0xF1F8, 0xE048, "LSR.W #<count>,D<reg0>"},
    {0xF1F8, 0xE050, "ROXR.W #<count>,D<reg0>"},
    {0xF1F8, 0xE058, "ROR.W #<count>,D<reg0>"},
    {0xF1F8, 0xE060, "ASR.W D<reg>,D<reg0>"},
    {0xF1F8, 0xE068, "LSR.W D<reg>,D<reg0>"},
    {0xF1F8, 0xE070, "ROXR.W D<reg>,D<reg0>"},
    {0xF1F8, 0xE078, "ROR.W D<reg>,D<reg0>"},

    {0xF1F8, 0xE080, "ASR.L #<count>,D<reg0>"},
    {0xF1F8, 0xE088, "LSR.L #<count>,D<reg0>"},
    {0xF1F8, 0xE090, "ROXR.L #<count>,D<reg0>"},
    {0xF1F8, 0xE098, "ROR.L #<count>,D<reg0>"},
    {0xF1F8, 0xE0A0, "ASR.L D<reg>,D<reg0>"},
    {0xF1F8, 0xE0A8, "LSR.L D<reg>,D<reg0>"},
    {0xF1F8, 0xE0B0, "ROXR.L D<reg>,D<reg0>"},
    {0xF1F8, 0xE0B8, "ROR.L D<reg>,D<reg0>"},

    {0xF1F8, 0xE100, "ASL.B #<count>,D<reg0>"},
    {0xF1F8, 0xE108, "LSL.B #<count>,D<reg0>"},
    {0xF1F8, 0xE110, "ROXL.B #<count>,D<reg0>"},
    {0xF1F8, 0xE118, "ROL.B #<count>,D<reg0>"},
    {0xF1F8, 0xE120, "ASL.B D<reg>,D<reg0>"},
    {0xF1F8, 0xE128, "LSL.B D<reg>,D<reg0>"},
    {0xF1F8, 0xE130, "ROXL.B D<reg>,D<reg0>"},
    {0xF1F8, 0xE138, "ROL.B D<reg>,D<reg0>"},

    {0xF1F8, 0xE140, "ASL.W #<count>,D<reg0>"},
    {0xF1F8, 0xE148, "LSL.W #<count>,D<reg0>"},
    {0xF1F8, 0xE150, "ROXL.W #<count>,D<reg0>"},
    {0xF1F8, 0xE158, "ROL.W #<count>,D<reg0>"},
    {0xF1F8, 0xE160, "ASL.W D<reg>,D<reg0>"},
    {0xF1F8, 0xE168, "LSL.W D<reg>,D<reg0>"},
    {0xF1F8, 0xE170, "ROXL.W D<reg>,D<reg0>"},
    {0xF1F8, 0xE178, "ROL.W D<reg>,D<reg0>"},

    {0xF1F8, 0xE180, "ASL.L #<count>,D<reg0>"},
    {0xF1F8, 0xE188, "LSL.L #<count>,D<reg0>"},
    {0xF1F8, 0xE190, "ROXL.L #<count>,D<reg0>"},
    {0xF1F8, 0xE198, "ROL.L #<count>,D<reg0>"},
    {0xF1F8, 0xE1A0, "ASL.L D<reg>,D<reg0>"},
    {0xF1F8, 0xE1A8, "LSL.L D<reg>,D<reg0>"},
    {0xF1F8, 0xE1B0, "ROXL.L D<reg>,D<reg0>"},
    {0xF1F8, 0xE1B8, "ROL.L D<reg>,D<reg0>"},

    {0xFFC0, 0xE0C0, "ASR.W <ea.w>"},
    {0xFFC0, 0xE1C0, "ASL.W <ea.w>"},
    {0xFFC0, 0xE2C0, "LSR.W <ea.w>"},
    {0xFFC0, 0xE3C0, "LSL.W <ea.w>"},
    {0xFFC0, 0xE4C0, "ROXR.W <ea.w>"},
    {0xFFC0, 0xE5C0, "ROXL.W <ea.w>"},
    {0xFFC0, 0xE6C0, "ROR.W <ea.w>"},
    {0xFFC0, 0xE7C0, "ROL.W <ea.w>"},
};

/*************************************************************************/

/**
 * q68_disassemble:  Disassembles the instruction at the given address.
 * Returns "???" if the address or opcode is invalid.
 *
 * [Parameters]
 *          state: Processor state block
 *        address: Address of instruction to disassemble
 *     nwords_ret: Pointer to variable to receive length in words of the
 *                    instruction (NULL permitted)
 * [Return value]
 *     String containined disassembled instruction
 * [Notes]
 *     The returned string is only valid until the next call to this function.
 */
const char *q68_disassemble(Q68State *state, uint32_t address,
                            int *nwords_ret)
{
    const uint32_t base_address = address;
    static char outbuf[1000];

    if (address % 2 != 0) {  // Odd addresses are invalid
        if (nwords_ret) {
            *nwords_ret = 1;
        }
        return "???";
    }

    uint16_t opcode = READU16(state, address);
    address += 2;
    const char *format = NULL;
    int i;
    for (i = 0; i < lenof(instructions); i++) {
        if ((opcode & instructions[i].mask) == instructions[i].test) {
            format = instructions[i].format;
            break;
        }
    }
    if (!format) {
        if (nwords_ret) {
            *nwords_ret = 1;
        }
        return "???";
    }

    int outlen = 0;
#define APPEND_CHAR(ch)  do { \
    if (outlen < sizeof(outbuf)-1) { \
        outbuf[outlen++] = (ch); \
        outbuf[outlen] = 0; \
    } \
} while (0)
#define APPEND(fmt,...)  do { \
    outlen += snprintf(&outbuf[outlen], sizeof(outbuf)-outlen, \
                       fmt , ## __VA_ARGS__); \
    if (outlen > sizeof(outbuf)-1) { \
        outlen = sizeof(outbuf)-1; \
    } \
} while (0)

    int inpos = 0;
    while (format[inpos] != 0) {
        if (format[inpos] == '<') {
            char tagbuf[100];
            int end = inpos+1;
            for (; format[end] != 0 && format[end] != '>'; end++) {
                if (end - (inpos+1) >= sizeof(tagbuf)) {
                    break;
                }
            }
            memcpy(tagbuf, &format[inpos+1], end - (inpos+1));
            tagbuf[end - (inpos+1)] = 0;
            if (format[end] != 0) {
                end++;
            }
            inpos = end;
            if (strncmp(tagbuf,"ea",2) == 0) {
                int mode, reg;
                char size;  // 'b', 'w', or 'l'
                if (strncmp(tagbuf,"ea2",3) == 0) {  // 2nd EA of MOVE insns
                    mode = opcode>>6 & 7;
                    reg  = opcode>>9 & 7;
                    size = tagbuf[4];
                } else {
                    mode = opcode>>3 & 7;
                    reg  = opcode>>0 & 7;
                    size = tagbuf[3];
                }
                switch (mode) {
                  case 0:
                    APPEND("D%d", reg);
                    break;
                  case 1:
                    APPEND("A%d", reg);
                    break;
                  case 2:
                    APPEND("(A%d)", reg);
                    break;
                  case 3:
                    APPEND("(A%d)+", reg);
                    break;
                  case 4:
                    APPEND("-(A%d)", reg);
                    break;
                  case 5: {
                    int16_t disp = READS16(state, address);
                    address += 2;
                    APPEND("%d(A%d)", disp, reg);
                    break;
                  }
                  case 6: {
                    uint16_t ext = READU16(state, address);
                    address += 2;
                    const int iregtype = ext>>15;
                    const int ireg     = ext>>12 & 7;
                    const int iregsize = ext>>11;
                    const int8_t disp  = ext & 0xFF;
                    APPEND("%d(A%d,%c%d.%c)", disp, reg,
                           iregtype ? 'A' : 'D', ireg, iregsize ? 'l' : 'w');
                    break;
                  }
                  case 7:
                    switch (reg) {
                      case 0: {
                        const uint16_t abs = READU16(state, address);
                        address += 2;
                        APPEND("($%X).w", abs);
                        break;
                      }
                      case 1: {
                        const uint32_t abs = READU32(state, address);
                        address += 4;
                        APPEND("($%X).l", abs);
                        break;
                      }
                      case 2: {
                        int16_t disp = READS16(state, address);
                        address += 2;
                        APPEND("$%X(PC)", (base_address+2) + disp);
                        break;
                      }
                      case 3: {
                        uint16_t ext = READU16(state, address);
                        address += 2;
                        const int iregtype = ext>>15;
                        const int ireg     = ext>>12 & 7;
                        const int iregsize = ext>>11;
                        const int8_t disp  = ext & 0xFF;
                        APPEND("$%X(PC,%c%d.%c)", (base_address+2) + disp,
                               iregtype ? 'A' : 'D', ireg, iregsize ? 'l' : 'w');
                        break;
                      }
                      case 4: {
                        uint32_t imm;
                        if (size == 'l') {
                            imm = READU32(state, address);
                            address += 4;
                        } else {
                            imm = READU16(state, address);
                            address += 2;
                        }
                        APPEND("#%s%X", imm<10 ? "" : "$", imm);
                        break;
                      }
                      default:
                        APPEND("???");
                        break;
                    }
                }
            } else if (strcmp(tagbuf,"reg") == 0) {
                APPEND("%d", opcode>>9 & 7);
            } else if (strcmp(tagbuf,"reg0") == 0) {
                APPEND("%d", opcode>>0 & 7);
            } else if (strcmp(tagbuf,"count") == 0) {
                APPEND("%d", opcode>>9 & 7 ?: 8);
            } else if (strcmp(tagbuf,"trap") == 0) {
                APPEND("%d", opcode>>0 & 15);
            } else if (strcmp(tagbuf,"quick8") == 0) {
                APPEND("%d", (int8_t)(opcode & 0xFF));
            } else if (strncmp(tagbuf,"imm8",4) == 0) {
                uint8_t imm8 = READU16(state, address); // Upper 8 bits ignored
                imm8 &= 0xFF;
                address += 2;
                if (tagbuf[4] == 'd') {
                    APPEND("%d", imm8);
                } else if (tagbuf[4] == 'x') {
                    APPEND("$%02X", imm8);
                } else {
                    APPEND("%s%X", imm8<10 ? "" : "$", imm8);
                }
            } else if (strncmp(tagbuf,"imm16",5) == 0) {
                uint16_t imm16 = READU16(state, address);
                address += 2;
                if (tagbuf[5] == 'd') {
                    APPEND("%d", imm16);
                } else if (tagbuf[5] == 'x') {
                    APPEND("$%04X", imm16);
                } else {
                    APPEND("%s%X", imm16<10 ? "" : "$", imm16);
                }
            } else if (strcmp(tagbuf,"pcrel8") == 0) {
                int8_t disp8 = opcode & 0xFF;
                APPEND("$%X", (base_address+2) + disp8);
            } else if (strcmp(tagbuf,"pcrel16") == 0) {
                int16_t disp16 = READS16(state, address);
                address += 2;
                APPEND("$%X", (base_address+2) + disp16);
            } else if (strcmp(tagbuf,"reglist") == 0
                       || strcmp(tagbuf,"tsilger") == 0) {
                uint16_t reglist = READU16(state, address);
                address += 2;
                if (strcmp(tagbuf,"tsilger") == 0) {  // "reglist" backwards
                    /* Predecrement-mode register list, so flip it around */
                    uint16_t temp = reglist;
                    reglist = 0;
                    while (temp) {
                        reglist <<= 1;
                        if (temp & 1) {
                            reglist |= 1;
                        }
                        temp >>= 1;
                    }
                }
                char listbuf[3*16];  // Buffer for generating register list
                unsigned int listlen = 0;  // strlen(listbuf)
                unsigned int last = 0;     // State of the previous bit
                unsigned int regnum = 0;   // Current register number (0-15)
                while (reglist) {
                    if (reglist & 1) {
                        if (last) {
                            if (listlen >= 3 && listbuf[listlen-3] == '-') {
                                listlen -= 2;
                            } else {
                                listbuf[listlen++] = '-';
                            }
                        } else {
                            if (listlen > 0) {
                                listbuf[listlen++] = '/';
                            }
                        }
                        listbuf[listlen++] = regnum<8 ? 'D' : 'A';
                        listbuf[listlen++] = '0' + (regnum % 8);
                    }
                    last = reglist & 1;
                    regnum++;
                    reglist >>= 1;
                }
                listbuf[listlen] = 0;
                APPEND("%s", listbuf);
            } else {
                APPEND("<%s>", tagbuf);
            }
        } else {
            APPEND_CHAR(format[inpos]);
            inpos++;
        }
    }

    if (nwords_ret) {
        *nwords_ret = (address - base_address) / 2;
    }
    return outbuf;
}

/*************************************************************************/
/*********************** Execution tracing support ***********************/
/*************************************************************************/

/* Processor state block to use in tracing */
static Q68State *state;

/* File pointer for trace output */
static FILE *logfile;

/* Cycle accumulator */
static uint64_t total_cycles;

/* Range of cycles to trace */
static const uint64_t trace_start = 000000000ULL;  // First cycle to trace
static const uint64_t trace_stop  = 600000000ULL;  // Last cycle to trace + 1

/*-----------------------------------------------------------------------*/

/**
 * q68_trace_init:  Initialize the tracing code.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
void q68_trace_init(Q68State *state_)
{
    state = state_;
}

/*-----------------------------------------------------------------------*/

/**
 * q68_trace_add_cycles:  Add the given number of cycles to the global
 * accumulator.
 *
 * [Parameters]
 *     cycles: Number of cycles to add
 * [Return value]
 *     None
 */
extern void q68_trace_add_cycles(int32_t cycles)
{
    total_cycles += cycles;
}

/*-----------------------------------------------------------------------*/

#ifdef PSP
/**
 * HEXIT:  Helper routine for q68_trace() to print a value in hexadecimal.
 * See q68_trace() for why we don't just use printf().
 */
static inline void HEXIT(char * const ptr, uint32_t val, int ndigits)
{
    while (ndigits-- > 0) {
        const int digit = val & 0xF;
        val >>= 4;
        ptr[ndigits] = (digit>9 ? digit+7+'0' : digit+'0');
    }
}
#endif

/*----------------------------------*/

/**
 * q68_trace:  Output a trace for the instruction at the current PC.
 *
 * [Parameters]
 *     None
 * [Return value]
 *     None
 */
void q68_trace(void)
{
    const uint64_t cycles = total_cycles + state->cycles;

    if (cycles < trace_start) {

        /* Before first instruction: do nothing */

    } else if (cycles >= trace_stop) {

        /* After last instruction: close log file if it's open */
        if (logfile) {
#ifdef __linux__
            pclose(logfile);
#else
            fclose(logfile);
#endif
            logfile = NULL;
        }

    } else {

        if (!logfile) {
#ifdef __linux__
            logfile = popen("gzip -3 >q68.log.gz", "w");
#else
            logfile = fopen("q68.log", "w");
#endif
            if (UNLIKELY(!logfile)) {
                perror("Failed to open trace logfile");
                return;
            }
            setvbuf(logfile, NULL, _IOFBF, 65536);
        }

        int nwords = 1, i;
        const char *disassembled = q68_disassemble(state, state->PC, &nwords);

#ifdef PSP  // because the cleaner fprintf() version is just too slow
        int dislen = strlen(disassembled);
        static char buf1[] =
            "......: .... .... ....  ..........................  SR=.... .....  [..........]\n";
        static char buf2[] =
            "    D: ........ ........ ........ ........ ........ ........ ........ ........\n"
            "    A: ........ ........ ........ ........ ........ ........ ........ ........\n";

        if (nwords > 3) {  // We can only fit 3 words on the line
            nwords = 3;
        }
        HEXIT(&buf1[0], state->PC, 6);
        for (i = 0; i < nwords; i++) {
            HEXIT(&buf1[8+5*i], READU16(state, state->PC+2*i), 4);
        }
        if (i < 3) {
            memset(&buf1[8+5*i], ' ', 4+5*(2-i));
        }
        if (dislen > 26) {  // Pathologically long text needs special handling
            fprintf(logfile, "%.22s  %-26s  SR=%04X %c%c%c%c%c  [%10lld]\n",
                    buf1, disassembled, (int)state->SR,
                    state->SR & SR_X ? 'X' : '.', state->SR & SR_N ? 'N' : '.',
                    state->SR & SR_Z ? 'Z' : '.', state->SR & SR_V ? 'V' : '.',
                    state->SR & SR_C ? 'C' : '.', (unsigned long long)cycles);
        } else {
            memcpy(&buf1[24], disassembled, dislen);
            if (dislen < 26) {
                memset(&buf1[24+dislen], ' ', 26-dislen);
            }
            HEXIT(&buf1[55], state->SR, 4);
            buf1[60] = state->SR & SR_X ? 'X' : '.';
            buf1[61] = state->SR & SR_N ? 'N' : '.';
            buf1[62] = state->SR & SR_Z ? 'Z' : '.';
            buf1[63] = state->SR & SR_V ? 'V' : '.';
            buf1[64] = state->SR & SR_C ? 'C' : '.';
            snprintf(&buf1[68], sizeof(buf1)-68, "%10lld]\n",
                     (unsigned long long)cycles);
            fwrite(buf1, 1, strlen(buf1), logfile);
        }
        for (i = 0; i < 8; i++) {
            HEXIT(&buf2[ 7+9*i], state->D[i], 8);
            HEXIT(&buf2[86+9*i], state->A[i], 8);
        }
        fwrite(buf2, 1, sizeof(buf2)-1, logfile);
#else  // !PSP
        char hexbuf[100];
        int hexlen = 0;

        if (nwords > 3) {  // We can only fit 3 words on the line
            nwords = 3;
        }
        for (i = 0; i < nwords && hexlen < sizeof(hexbuf)-5; i++) {
            hexlen += snprintf(hexbuf+hexlen, sizeof(hexbuf)-hexlen,
                               "%s%04X", hexlen==0 ? "" : " ",
                               (int)READU16(state, state->PC+2*i));
        }

        fprintf(logfile, "%06X: %-14s  %-26s  SR=%04X %c%c%c%c%c  [%10llu]\n"
                         "    D: %08X %08X %08X %08X %08X %08X %08X %08X\n"
                         "    A: %08X %08X %08X %08X %08X %08X %08X %08X\n",
                (int)state->PC, hexbuf, disassembled, (int)state->SR,
                state->SR & SR_X ? 'X' : '.', state->SR & SR_N ? 'N' : '.',
                state->SR & SR_Z ? 'Z' : '.', state->SR & SR_V ? 'V' : '.',
                state->SR & SR_C ? 'C' : '.', (unsigned long long)cycles,
                (int)state->D[0], (int)state->D[1], (int)state->D[2],
                (int)state->D[3], (int)state->D[4], (int)state->D[5],
                (int)state->D[6], (int)state->D[7],
                (int)state->A[0], (int)state->A[1], (int)state->A[2],
                (int)state->A[3], (int)state->A[4], (int)state->A[5],
                (int)state->A[6], (int)state->A[7]
            );
#endif  // PSP

    }  // current_cycles >= trace_start && current_cycles < trace_stop
}

/*************************************************************************/
/*************************************************************************/


/*
 * Local variables:
 *   c-file-style: "stroustrup"
 *   c-file-offsets: ((case-label . *) (statement-case-intro . *))
 *   indent-tabs-mode: nil
 * End:
 *
 * vim: expandtab shiftwidth=4:
 */
