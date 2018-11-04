/*  Copyright 2003-2004 Stephane Dallongeville
    Copyright 2004 Theo Berkau

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

/*********************************************************************************
 * C68K.H :
 *
 * C68K include file
 *
 ********************************************************************************/

#ifndef _C68K_H_
#define _C68K_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "../core.h"

// setting
///////////

//#define NEOCD_HLE

//#define C68K_GEN
#define C68K_BYTE_SWAP_OPT

#ifdef WORDS_BIGENDIAN
#define C68K_BIG_ENDIAN
#endif

#ifdef C68K_BIG_ENDIAN
 #define BYTE_OFF 3
 #define WORD_OFF 1
#else
 #define BYTE_OFF 0
 #define WORD_OFF 0
#endif

//#define C68K_NO_JUMP_TABLE
//#define C68K_DEBUG
#define C68K_TAS_CAN_SET_MEMORY
//#define C68K_CONST_JUMP_TABLE
//#define C68K_AUTOVECTOR_CALLBACK

// 68K core types definitions
//////////////////////////////

#define C68K_FETCH_BITS 8   // [4-12]   default = 8
#define C68K_ADR_BITS   24

#define C68K_FETCH_SFT  (C68K_ADR_BITS - C68K_FETCH_BITS)
#define C68K_FETCH_BANK (1 << C68K_FETCH_BITS)
#define C68K_FETCH_MASK (C68K_FETCH_BANK - 1)

#define C68K_SR_C_SFT   8
#define C68K_SR_V_SFT   7
#define C68K_SR_Z_SFT   0
#define C68K_SR_N_SFT   7
#define C68K_SR_X_SFT   8

#define C68K_SR_S_SFT   13

#define C68K_SR_C       (1 << C68K_SR_C_SFT)
#define C68K_SR_V       (1 << C68K_SR_V_SFT)
#define C68K_SR_Z       0
#define C68K_SR_N       (1 << C68K_SR_N_SFT)
#define C68K_SR_X       (1 << C68K_SR_X_SFT)

#define C68K_SR_S       (1 << C68K_SR_S_SFT)

#define C68K_CCR_MASK   0x1F
#define C68K_SR_MASK    (0x2700 | C68K_CCR_MASK)

// exception defines taken from musashi core
#define C68K_RESET_EX                   1
#define C68K_BUS_ERROR_EX               2
#define C68K_ADDRESS_ERROR_EX           3
#define C68K_ILLEGAL_INSTRUCTION_EX     4
#define C68K_ZERO_DIVIDE_EX             5
#define C68K_CHK_EX                     6
#define C68K_TRAPV_EX                   7
#define C68K_PRIVILEGE_VIOLATION_EX     8
#define C68K_TRACE_EX                   9
#define C68K_1010_EX                    10
#define C68K_1111_EX                    11
#define C68K_FORMAT_ERROR_EX            14
#define C68K_UNINITIALIZED_INTERRUPT_EX 15
#define C68K_SPURIOUS_INTERRUPT_EX      24
#define C68K_INTERRUPT_AUTOVECTOR_EX    24
#define C68K_TRAP_BASE_EX               32

#define C68K_INT_ACK_AUTOVECTOR         -1

#define C68K_RUNNING    0x01
#define C68K_HALTED     0x02
#define C68K_WAITING    0x04
#define C68K_DISABLE    0x10
#define C68K_FAULTED    0x40

typedef u32 FASTCALL C68K_READ(const u32 adr);
typedef void FASTCALL C68K_WRITE(const u32 adr, u32 data);

typedef s32  FASTCALL C68K_INT_CALLBACK(s32 level);
typedef void FASTCALL C68K_RESET_CALLBACK(void);

typedef struct {
    u32 D[8];       // 32 bytes aligned
    u32 A[8];       // 16 bytes aligned

    u32 flag_C;     // 32 bytes aligned
    u32 flag_V;
    u32 flag_notZ;
    u32 flag_N;

    u32 flag_X;     // 16 bytes aligned
    u32 flag_I;
    u32 flag_S;
    
    u32 USP;

    pointer PC;         // 32 bytes aligned
    pointer BasePC;
    u32 Status;
    s32 IRQLine;
    
    s32 CycleToDo;  // 16 bytes aligned
    s32 CycleIO;
    s32 CycleSup;
    u32 dirty1;
    
    C68K_READ *Read_Byte;                   // 32 bytes aligned
    C68K_READ *Read_Word;

    C68K_WRITE *Write_Byte;
    C68K_WRITE *Write_Word;

    C68K_INT_CALLBACK *Interrupt_CallBack;  // 16 bytes aligned
    C68K_RESET_CALLBACK *Reset_CallBack;

	pointer Fetch[C68K_FETCH_BANK];             // 32 bytes aligned
} c68k_struc;


// 68K core var declaration
////////////////////////////

extern  c68k_struc C68K;


// 68K core function declaration
/////////////////////////////////

void    C68k_Init(c68k_struc *cpu, C68K_INT_CALLBACK *int_cb);

s32     FASTCALL C68k_Reset(c68k_struc *cpu);

// if <  0 --> error (cpu state returned)
// if >= 0 --> number of extras cycles done
s32	    FASTCALL C68k_Exec(c68k_struc *cpu, s32 cycle);

void    FASTCALL C68k_Set_IRQ(c68k_struc *cpu, s32 level);

s32     FASTCALL C68k_Get_CycleToDo(c68k_struc *cpu);
s32     FASTCALL C68k_Get_CycleRemaining(c68k_struc *cpu);
s32     FASTCALL C68k_Get_CycleDone(c68k_struc *cpu);
void    FASTCALL C68k_Release_Cycle(c68k_struc *cpu);
void    FASTCALL C68k_Add_Cycle(c68k_struc *cpu, s32 cycle);

void    C68k_Set_Fetch(c68k_struc *cpu, u32 low_adr, u32 high_adr, pointer fetch_adr);

void    C68k_Set_ReadB(c68k_struc *cpu, C68K_READ *Func);
void    C68k_Set_ReadW(c68k_struc *cpu, C68K_READ *Func);
void    C68k_Set_WriteB(c68k_struc *cpu, C68K_WRITE *Func);
void    C68k_Set_WriteW(c68k_struc *cpu, C68K_WRITE *Func);

u32     C68k_Get_DReg(c68k_struc *cpu, u32 num);
u32     C68k_Get_AReg(c68k_struc *cpu, u32 num);
u32     C68k_Get_PC(c68k_struc *cpu);
u32     C68k_Get_SR(c68k_struc *cpu);
u32     C68k_Get_USP(c68k_struc *cpu);
u32     C68k_Get_MSP(c68k_struc *cpu);

void    C68k_Set_DReg(c68k_struc *cpu, u32 num, u32 val);
void    C68k_Set_AReg(c68k_struc *cpu, u32 num, u32 val);
void    C68k_Set_PC(c68k_struc *cpu, u32 val);
void    C68k_Set_SR(c68k_struc *cpu, u32 val);
void    C68k_Set_USP(c68k_struc *cpu, u32 val);
void    C68k_Set_MSP(c68k_struc *cpu, u32 val);

#ifdef __cplusplus
}
#endif

#endif  // _C68K_H_

