/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - instr_counters.c                                        *
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

#include "instr_counters.h"

#include <stdio.h>
#include <string.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"

/* various constants */
static char instr_name[][10] =
{
    "reserved", "NI",     "J",      "JAL",    "BEQ",    "BNE",     "BLEZ",    "BGTZ",
    "ADDI",     "ADDIU",  "SLTI",   "SLTIU",  "ANDI",   "ORI",     "XORI",    "LUI",
    "BEQL",     "BNEL",   "BLEZL",  "BGTZL",  "DADDI",  "DADDIU",  "LDL",     "LDR",
    "LB",       "LH",     "LW",     "LWL",    "LBU",    "LHU",     "LWU",     "LWR",
    "SB",       "SH",     "SW",     "SWL",    "SWR",    "SDL",     "SDR",     "LWC1",
    "LDC1",     "LD",     "LL",     "SWC1",   "SDC1",   "SD",      "SC",      "BLTZ",
    "BGEZ",     "BLTZL",  "BGEZL",  "BLTZAL", "BGEZAL", "BLTZALL", "BGEZALL", "SLL",
    "SRL",      "SRA",    "SLLV",   "SRLV",   "SRAV",   "JR",      "JALR",    "SYSCALL",
    "MFHI",     "MTHI",   "MFLO",   "MTLO",   "DSLLV",  "DSRLV",   "DSRAV",   "MULT",
    "MULTU",    "DIV",    "DIVU",   "DMULT",  "DMULTU", "DDIV",    "DDIVU",   "ADD",
    "ADDU",     "SUB",    "SUBU",   "AND",    "OR",     "XOR",     "NOR",     "SLT",
    "SLTU",     "DADD",   "DADDU",  "DSUB",   "DSUBU",  "DSLL",    "DSRL",    "DSRA",
    "TEQ",      "DSLL32", "DSRL32", "DSRA32", "BC1F",   "BC1T",    "BC1FL",   "BC1TL",
    "TLBWI",    "TLBP",   "TLBR",   "TLBWR",  "ERET",   "MFC0",    "MTC0",    "MFC1",
    "DMFC1",    "CFC1",   "MTC1",   "DMTC1",  "CTC1",   "f.CVT",   "f.CMP",   "f.ADD",
    "f.SUB",    "f.MUL",  "f.DIV",  "f.SQRT", "f.ABS",  "f.MOV",   "f.NEG",   "f.ROUND",
    "f.TRUNC",  "f.CEIL", "f.FLOOR"
};

static unsigned int instr_type[131] =
{
    9, 10,  6,  6,  7,  7,  7,  7,  3,  3,  4,  4,  3,  4,  4,  0,
    7,  7,  7,  7,  4,  4,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
    1,  1,  1,  1,  1,  1,  1,  0,  0,  0,  0,  1,  1,  1,  1,  7,
    7,  7,  7,  7,  7,  7,  7,  3,  3,  3,  3,  3,  3,  6,  6, 10,
    2,  2,  2,  2,  4,  4,  4,  3,  3,  3,  3,  4,  4,  4,  4,  3,
    3,  3,  3,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
    8,  4,  4,  4,  7,  7,  7,  7, 10, 10, 10, 10,  8,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  5,  5,  5,  5,  5,  5,  5,  2,  5,  5,
    5,  5,  5
};

static char instr_typename[][20] =
{
    "Load", "Store", "Data move/convert",
    "32-bit math", "64-bit math", "Float Math",
    "Jump", "Branch", "Exceptions",
    "Reserved", "Other"
};

/* global variable */
unsigned int instr_count[132];

/* global function */
void instr_counters_print(void)
{
    size_t i;
    unsigned int iTypeCount[11] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    unsigned int iTotal = 0;
    char line[128], param[24];
    DebugMessage(M64MSG_INFO, "Instruction counters:");
    line[0] = 0;
    for (i = 0; i < 131; i++)
    {
        sprintf(param, "%8s: %08i  ", instr_name[i], instr_count[i]);
        strcat(line, param);
        if (i % 5 == 4)
        {
            DebugMessage(M64MSG_INFO, "%s", line);
            line[0] = 0;
        }
        iTypeCount[instr_type[i]] += instr_count[i];
        iTotal += instr_count[i];
    }
    DebugMessage(M64MSG_INFO, "Instruction type summary (total instructions = %i)", iTotal);
    for (i = 0; i < 11; i++)
    {
        DebugMessage(M64MSG_INFO, "%20s: %04.1f%% (%i)", instr_typename[i], (float) iTypeCount[i] * 100.0 / iTotal, iTypeCount[i]);
    }
}
