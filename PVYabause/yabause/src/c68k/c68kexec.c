/*  Copyright 2003-2004 Stephane Dallongeville

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

/*! \file c68kexec.c
    \brief C68K emulation execution and instruction functions.
*/

#include "../core.h"
#include "c68k.h"

// #define TRACE_WITH_Q68  // Define to use Q68 tracing code to trace insns
                           // (requires Q68 built in, of course)

#ifdef NEOCD_HLE
void    cdrom_load_files(void);
void    neogeo_cdda_control(void);
void    neogeo_prio_switch(void);
void    neogeo_upload(void);
#endif

// exception cycle table (taken from musashi core)
static const s32 c68k_exception_cycle_table[256] =
{
	  4, //  0: Reset - Initial Stack Pointer
	  4, //  1: Reset - Initial Program Counter
	 50, //  2: Bus Error
	 50, //  3: Address Error
	 34, //  4: Illegal Instruction
	 38, //  5: Divide by Zero
	 40, //  6: CHK
	 34, //  7: TRAPV
	 34, //  8: Privilege Violation
	 34, //  9: Trace
	  4, // 10:
	  4, // 11:
	  4, // 12: RESERVED
	  4, // 13: Coprocessor Protocol Violation
	  4, // 14: Format Error
	 44, // 15: Uninitialized Interrupt
	  4, // 16: RESERVED
	  4, // 17: RESERVED
	  4, // 18: RESERVED
	  4, // 19: RESERVED
	  4, // 20: RESERVED
	  4, // 21: RESERVED
	  4, // 22: RESERVED
	  4, // 23: RESERVED
	 44, // 24: Spurious Interrupt
	 44, // 25: Level 1 Interrupt Autovector
	 44, // 26: Level 2 Interrupt Autovector
	 44, // 27: Level 3 Interrupt Autovector
	 44, // 28: Level 4 Interrupt Autovector
	 44, // 29: Level 5 Interrupt Autovector
	 44, // 30: Level 6 Interrupt Autovector
	 44, // 31: Level 7 Interrupt Autovector
	 34, // 32: TRAP #0
	 34, // 33: TRAP #1
	 34, // 34: TRAP #2
	 34, // 35: TRAP #3
	 34, // 36: TRAP #4
	 34, // 37: TRAP #5
	 34, // 38: TRAP #6
	 34, // 39: TRAP #7
	 34, // 40: TRAP #8
	 34, // 41: TRAP #9
	 34, // 42: TRAP #10
	 34, // 43: TRAP #11
	 34, // 44: TRAP #12
	 34, // 45: TRAP #13
	 34, // 46: TRAP #14
	 34, // 47: TRAP #15
	  4, // 48: FP Branch or Set on Unknown Condition
	  4, // 49: FP Inexact Result
	  4, // 50: FP Divide by Zero
	  4, // 51: FP Underflow
	  4, // 52: FP Operand Error
	  4, // 53: FP Overflow
	  4, // 54: FP Signaling NAN
	  4, // 55: FP Unimplemented Data Type
	  4, // 56: MMU Configuration Error
	  4, // 57: MMU Illegal Operation Error
	  4, // 58: MMU Access Level Violation Error
	  4, // 59: RESERVED
	  4, // 60: RESERVED
	  4, // 61: RESERVED
	  4, // 62: RESERVED
	  4, // 63: RESERVED
	     // 64-255: User Defined
	  4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
	  4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
	  4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
	  4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
	  4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
	  4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4
};

// global variable
///////////////////

#ifndef C68K_GEN

#ifndef C68K_NO_JUMP_TABLE
#ifndef C68K_CONST_JUMP_TABLE
static void *JumpTable[0x10000];
#endif
#endif

static u32 C68k_Initialised = 0;

#endif  // C68K_GEN

#ifdef NEOCD_HLE
extern int img_display;
#endif

// include macro file
//////////////////////

#include "c68kmac.inc"

#ifndef C68K_GEN
# ifdef TRACE_WITH_Q68
#include "../q68/q68.h"
static c68k_struc *TRACE_CPU;
static uint32_t readw(uint32_t address) {
    return TRACE_CPU->Read_Word(address);
}
/* Make our own version of the structure to avoid the overhead of dozens of
 * function calls every instruction */
static struct {
    u32 D[8], A[8], PC, SR, USP, SSP, dummy[7];
    void *readb, *readw, *writeb, *writew;
} state = {.readw = readw};
void TRACE(int PC,c68k_struc *CPU,int Opcode,int CCnt) {
    static FILE *f;
    if (!f) f = fopen("c68k.log", "w");
    TRACE_CPU = CPU;
    memcpy(state.D, CPU->D, 16*4);
    state.PC = PC - 2 - CPU->BasePC;
    state.SR = GET_SR;
    if (f) q68_trace((Q68State *)&state, f,
                     CPU->CycleToDo - CCnt, CPU->CycleToDo);
}
# endif  // TRACE_WITH_Q68
#endif  // !C68K_GEN

// main exec function
//////////////////////

s32 FASTCALL C68k_Exec(c68k_struc *cpu, s32 cycle)
{
#ifndef C68K_GEN
#if 0
    register c68k_struc *CPU asm ("ebx");
    register pointer PC asm ("esi");
    register s32 CCnt asm ("edi");
//    register u32 Opcode asm ("edi");
//    c68k_struc *CPU;
//    u32 PC;
//    s32 CCnt;
    u32 Opcode;
#else
//    register c68k_struc *CPU asm ("r10");
//    register u32 PC asm ("r11");
//    register s32 CCnt asm ("r12");
//    register u32 Opcode asm ("r13");
    c68k_struc *CPU;
    pointer PC;
    s32 CCnt;
    u32 Opcode;
#endif
#endif

#ifndef C68K_GEN

#ifndef C68K_NO_JUMP_TABLE
#ifdef C68K_CONST_JUMP_TABLE
    #include "c68k_ini.inc"
#endif
#else
    C68k_Initialised = 1;
#endif

    CPU = cpu;
    PC = CPU->PC;

    if (CPU->Status & (C68K_RUNNING | C68K_DISABLE | C68K_FAULTED))
    {
#ifndef C68K_NO_JUMP_TABLE
#ifndef C68K_CONST_JUMP_TABLE
        if (!C68k_Initialised) goto C68k_Init;
#endif
#endif
        return (CPU->Status | 0x80000000);
    }

    if (cycle <= 0) return -cycle;
    
    CPU->CycleToDo = CCnt = cycle;

#ifndef C68K_DEBUG
    CHECK_INT
#else
    {
        s32 line, vect;

        line = CPU->IRQLine;

        if ((line == 7) || (line > CPU->flag_I))
        {
            PRE_IO

            /* get vector */
            CPU->IRQLine = 0;
            vect = CPU->Interrupt_CallBack(line);
            if (vect == C68K_INT_ACK_AUTOVECTOR)
                vect = C68K_INTERRUPT_AUTOVECTOR_EX + (line & 7);

            /* adjust CCnt */
            CCnt -= c68k_exception_cycle_table[vect];

            /* swap A7 and USP */
            if (!CPU->flag_S)
            {
                u32 tmpSP;

                tmpSP = CPU->USP;
                CPU->USP = CPU->A[7];
                CPU->A[7] = tmpSP;
            }

            /* push PC and SR */
            PUSH_32_F(PC - CPU->BasePC)
            PUSH_16_F(GET_SR)

            /* adjust SR */
            CPU->flag_S = C68K_SR_S;
            CPU->flag_I = line;

            /* fetch new PC */
            READ_LONG_F(vect * 4, PC)
            SET_PC(PC)

            POST_IO
        }
    }
#endif

    if (CPU->Status & (C68K_HALTED | C68K_WAITING)) return CPU->CycleToDo;

    CPU->CycleSup = 0;
    CPU->Status |= C68K_RUNNING;

#ifndef C68K_DEBUG
    NEXT
#else
#ifdef C68K_NO_JUMP_TABLE
    NEXT
#else
    Opcode = FETCH_WORD;
    PC += 2;
    goto *JumpTable[Opcode];
#endif
#endif

#ifdef C68K_NO_JUMP_TABLE
SwitchTable:
    switch(Opcode)
    {
#endif
    #include "c68k_op0.inc"
    #include "c68k_op1.inc"
    #include "c68k_op2.inc"
    #include "c68k_op3.inc"
    #include "c68k_op4.inc"
    #include "c68k_op5.inc"
    #include "c68k_op6.inc"
    #include "c68k_op7.inc"
    #include "c68k_op8.inc"
    #include "c68k_op9.inc"
    #include "c68k_opA.inc"
    #include "c68k_opB.inc"
    #include "c68k_opC.inc"
    #include "c68k_opD.inc"
    #include "c68k_opE.inc"
    #include "c68k_opF.inc"
#ifdef C68K_NO_JUMP_TABLE
    }
#endif

C68k_Exec_End:
    CHECK_INT
    if ((CCnt += CPU->CycleSup) > 0)
    {
        CPU->CycleSup = 0;
        NEXT;
    }

C68k_Exec_Really_End:
    CPU->Status &= ~C68K_RUNNING;
    CPU->PC = PC;
    
    return (CPU->CycleToDo - CCnt);

#ifndef C68K_CONST_JUMP_TABLE
#ifndef C68K_NO_JUMP_TABLE
C68k_Init:
    {
        u32 i, j;

        #include "c68k_ini.inc"
        
        C68k_Initialised = 1;
    }
    
    return 0;
#endif
#endif
#else
    return 0;
#endif
}

