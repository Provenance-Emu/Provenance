/*  src/q68/q68-core.c: Q68 execution core
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

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "q68.h"
#include "q68-const.h"
#include "q68-internal.h"

/* Define this to export two tables of counters:
 *     uint32_t q68_ops[128];       // Corresponds to opcode_table[]
 *     uint32_t q68_4xxx_ops[32];   // Corresponds to opcode_4xxx_table[]
 * Each entry will be incremented each time the corresponding function is
 * called. */
// #define COUNT_OPCODES

/*************************************************************************/

/*
 * The following table maps each 68000 instruction to its implementing
 * function in this file:
 *
 * || Instruction |  Func. || Instruction |  Func. || Instruction |  Func. ||
 * ++-------------+--------++-------------+--------++-------------+--------++
 * || ABCD        | op_BCD || EOR         | op_alu || NOT         | op4alu ||
 * || ADD         | op_alu || EORI        | op_imm || OR          | op_alu ||
 * || ADDA        | op_alu || EORI to CCR | op_imm || ORI         | op_imm ||
 * || ADDI        | op_imm || EORI to SR  | op_imm || ORI to CCR  | op_imm ||
 * || ADDQ        | opADSQ || EXG         | op_EXG || ORI to SR   | op_imm ||
 * || ADDX        | opADSX || EXT         | op_EXT || PEA         | op_PEA ||
 * || AND         | op_alu || ILLEGAL     | op_TAS || RESET       | op4E7x ||
 * || ANDI        | op_imm || JMP         | opjump || ROL         | opshft ||
 * || ANDI to CCR | op_imm || JSR         | opjump || ROR         | opshft ||
 * || ANDI to SR  | op_imm || LEA         | op_LEA || ROXL        | opshft ||
 * || ASL         | opshft || LINK        | opLINK || ROXR        | opshft ||
 * || ASR         | opshft || LSL         | opshft || RTE         | op4E7x ||
 * || Bcc         | op_Bcc || LSR         | opshft || RTR         | op4E7x ||
 * || BCHG        | op_bit || MOVE        | opMOVE || RTS         | op4E7x ||
 * || BCLR        | op_bit || MOVEA       | opMOVE || SBCD        | op_BCD ||
 * || BRA         | op_Bcc || MOVE to CCR | opMVSR || Scc         | op_Scc ||
 * || BSET        | op_bit || MOVE from SR| opMVSR || STOP        | op4E7x ||
 * || BSR         | op_Bcc || MOVE to SR  | opMVSR || SUB         | op_alu ||
 * || BTST        | op_bit || MOVE USP    | opMUSP || SUBA        | op_alu ||
 * || CHK         | op_CHK || MOVEM       |  (*1)  || SUBI        | op_imm ||
 * || CLR         | op4alu || MOVEP       | opMOVP || SUBQ        | opADSQ ||
 * || CMP         | op_alu || MOVEQ       | opMOVQ || SUBX        | opADSX ||
 * || CMPA        | op_alu || MULS        | op_MUL || SWAP        | opSWAP ||
 * || CMPI        | op_imm || MULU        | op_MUL || TAS         | op_TAS ||
 * || CMPM        | opCMPM || NBCD        | opNBCD || TRAP        | opTRAP ||
 * || DBcc        | opDBcc || NEG         | op4alu || TRAPV       | op4E7x ||
 * || DIVS        | op_DIV || NEGX        | op4alu || TST         | op4alu ||
 * || DIVU        | op_DIV || NOP         | op4E7X || UNLK        | opUNLK ||
 *
 * (*1) MOVEM is implemented by two instructions, op_STM (MOVEM reglist,mem)
 *      and op_LDM (MOVEM mem,reglist).
 *
 * Cycle counts were taken from:
 *    http://linas.org/mirrors/www.nvg.ntnu.no/2002.09.16/amiga/MC680x0_Sections/mc68000timing.HTML
 */

/*************************************************************************/

/* Forward declarations for helper functions and instruction implementations */

static void set_SR(Q68State *state, uint16_t value);
static inline void check_interrupt(Q68State *state);
static int take_exception(Q68State *state, uint8_t num);
static inline int op_ill(Q68State *state, uint32_t opcode);

static int ea_resolve(Q68State *state, uint32_t opcode, int size,
                               int access_type);
/* Note: Allowing these to be inlined actually slows down the code by ~0.5%
 *       (at least on x86).  FIXME: how about PSP? */
static NOINLINE uint32_t ea_get(Q68State *state, uint32_t opcode, int size,
                                int is_rmw, int *cycles_ret);
static NOINLINE void ea_set(Q68State *state, uint32_t opcode, int size,
                            uint32_t data);

static int op_imm(Q68State *state, uint32_t opcode);
static int op_bit(Q68State *state, uint32_t opcode);
static int opMOVE(Q68State *state, uint32_t opcode);
static int op4xxx(Q68State *state, uint32_t opcode);
static int op_CHK(Q68State *state, uint32_t opcode);
static int op_LEA(Q68State *state, uint32_t opcode);
static int opADSQ(Q68State *state, uint32_t opcode);
static int op_Scc(Q68State *state, uint32_t opcode);
static int opDBcc(Q68State *state, uint32_t opcode);
static int op_Bcc(Q68State *state, uint32_t opcode);
static int opMOVQ(Q68State *state, uint32_t opcode);
static int op_alu(Q68State *state, uint32_t opcode);
static int op_DIV(Q68State *state, uint32_t opcode);
static int opAxxx(Q68State *state, uint32_t opcode);
static int op_MUL(Q68State *state, uint32_t opcode);
static int opshft(Q68State *state, uint32_t opcode);
static int opFxxx(Q68State *state, uint32_t opcode);

static int op4alu(Q68State *state, uint32_t opcode);
static int opMVSR(Q68State *state, uint32_t opcode);
static int opNBCD(Q68State *state, uint32_t opcode);
static int op_PEA(Q68State *state, uint32_t opcode);
static int opSWAP(Q68State *state, uint32_t opcode);
static int op_TAS(Q68State *state, uint32_t opcode);
static int op_EXT(Q68State *state, uint32_t opcode);
static int op_STM(Q68State *state, uint32_t opcode);
static int op_LDM(Q68State *state, uint32_t opcode);
static int opmisc(Q68State *state, uint32_t opcode);
static int opTRAP(Q68State *state, uint32_t opcode);
static int opLINK(Q68State *state, uint32_t opcode);
static int opUNLK(Q68State *state, uint32_t opcode);
static int opMUSP(Q68State *state, uint32_t opcode);
static int op4E7x(Q68State *state, uint32_t opcode);
static int opjump(Q68State *state, uint32_t opcode);

static int opMOVP(Q68State *state, uint32_t opcode);
static int opADSX(Q68State *state, uint32_t opcode);
static int op_BCD(Q68State *state, uint32_t opcode);
static int opCMPM(Q68State *state, uint32_t opcode);
static int op_EXG(Q68State *state, uint32_t opcode);

/*-----------------------------------------------------------------------*/

/* Main table of instruction implemenation functions; table index is bits
 * 15-12 and 8-6 of the opcode (ABCD ...E FG.. .... -> 0ABC DEFG). */
static OpcodeFunc * const opcode_table[128] = {
    op_imm, op_imm, op_imm, op_imm, op_bit, op_bit, op_bit, op_bit,  // 00
    opMOVE, opMOVE, opMOVE, opMOVE, opMOVE, opMOVE, opMOVE, opMOVE,  // 10
    opMOVE, opMOVE, opMOVE, opMOVE, opMOVE, opMOVE, opMOVE, opMOVE,  // 20
    opMOVE, opMOVE, opMOVE, opMOVE, opMOVE, opMOVE, opMOVE, opMOVE,  // 30

    op4xxx, op4xxx, op4xxx, op4xxx, op_ill, op_ill, op_CHK, op_LEA,  // 40
    opADSQ, opADSQ, opADSQ, op_Scc, opADSQ, opADSQ, opADSQ, op_Scc,  // 50
    op_Bcc, op_Bcc, op_Bcc, op_Bcc, op_Bcc, op_Bcc, op_Bcc, op_Bcc,  // 60
    opMOVQ, opMOVQ, opMOVQ, opMOVQ, op_ill, op_ill, op_ill, op_ill,  // 70

    op_alu, op_alu, op_alu, op_DIV, op_alu, op_alu, op_alu, op_DIV,  // 80
    op_alu, op_alu, op_alu, op_alu, op_alu, op_alu, op_alu, op_alu,  // 90
    opAxxx, opAxxx, opAxxx, opAxxx, opAxxx, opAxxx, opAxxx, opAxxx,  // A0
    op_alu, op_alu, op_alu, op_alu, op_alu, op_alu, op_alu, op_alu,  // B0

    op_alu, op_alu, op_alu, op_MUL, op_alu, op_alu, op_alu, op_MUL,  // C0
    op_alu, op_alu, op_alu, op_alu, op_alu, op_alu, op_alu, op_alu,  // D0
    opshft, opshft, opshft, opshft, opshft, opshft, opshft, opshft,  // E0
    opFxxx, opFxxx, opFxxx, opFxxx, opFxxx, opFxxx, opFxxx, opFxxx,  // F0
};

/* Subtable for instructions in the $4xxx (miscellaneous) group; table index
 * is bits 11-9 and 7-6 of the opcode (1000 ABC0 DE.. .... -> 000A BCDE). */
static OpcodeFunc * const opcode_4xxx_table[32] = {
    op4alu, op4alu, op4alu, opMVSR,  // 40xx
    op4alu, op4alu, op4alu, op_ill,  // 42xx
    op4alu, op4alu, op4alu, opMVSR,  // 44xx
    op4alu, op4alu, op4alu, opMVSR,  // 46xx
    opNBCD, op_PEA, op_STM, op_STM,  // 48xx
    op4alu, op4alu, op4alu, op_TAS,  // 4Axx
    op_ill, op_ill, op_LDM, op_LDM,  // 4Cxx
    op_ill, opmisc, opjump, opjump,  // 4Exx
};

/* Sub-subtable for instructions in the $4E40-$4E7F range, used by opmisc();
 * index is bits 5-3 of the opcode. */
static OpcodeFunc * const opcode_4E4x_table[8] = {
    opTRAP, opTRAP, opLINK, opUNLK,
    opMUSP, opMUSP, op4E7x, op_ill,
};

#ifdef COUNT_OPCODES
/* Counters for opcode groups. */
uint32_t q68_ops[128], q68_4xxx_ops[32];
#endif

/*************************************************************************/
/************************** Interface functions **************************/
/*************************************************************************/

/**
 * q68_reset:  Reset the virtual processor.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
void q68_reset(Q68State *state)
{
    int i;
    for (i = 0; i < 8; i++) {
        state->D[i] = 0;
        state->A[i] = 0;
    }
    state->PC = 0;
    state->SR = SR_S;
    SR_SET_I(state, 7);
    state->USP = 0;
    state->SSP = 0;
    state->current_PC = 0;
    state->ea_addr = 0;
    state->exception = 0;
    state->fault_addr = 0;
    state->fault_opcode = 0;
    state->fault_status = 0;
    state->jit_running = NULL;
#ifdef Q68_USE_JIT
    q68_jit_reset(state);
#endif
#ifdef Q68_TRACE
    q68_trace_init(state);
#endif

    state->A[7] = READU32(state, 0x000000);
    state->PC = READU32(state, 0x000004);
    state->halted = 0;
}

/*-----------------------------------------------------------------------*/

/**
 * q68_run:  Execute instructions for the given number of clock cycles.
 *
 * [Parameters]
 *      state: Processor state block
 *     cycles: Number of clock cycles to execute
 * [Return value]
 *     Number of clock cycles executed (may be greater than "cycles")
 */
int q68_run(Q68State *state, int cycles)
{
    /* Check for pending interrupts */
    check_interrupt(state);

    /* Run the virtual processor */
    state->cycles = 0;
    while (state->cycles < cycles) {
        if (UNLIKELY(state->halted)) {
            /* If we're halted, consume all remaining cycles */
            state->cycles = cycles;
            break;
        }
        if (UNLIKELY(state->exception)) {
            int exception = state->exception;
            state->exception = 0;
            state->cycles += take_exception(state, exception);
            if (state->cycles >= cycles) {
                break;
            }
        }
#ifdef Q68_USE_JIT
        if (!state->jit_running) {
            state->jit_running = q68_jit_find(state, state->PC);
            if (UNLIKELY(!state->jit_running)) {
                state->jit_running = q68_jit_translate(state, state->PC);
            }
        }
        if (state->jit_running) {
            q68_jit_run(state, cycles, &state->jit_running);
        } else {
#endif
#ifndef Q68_DISABLE_ADDRESS_ERROR
            if (UNLIKELY(state->PC & 1)) {
                state->fault_addr = state->PC;
                state->fault_status = FAULT_STATUS_IN_INSN
                                    | FAULT_STATUS_RW_READ;
                state->cycles += take_exception(state, EX_ADDRESS_ERROR);
                continue;
            }
#endif
#ifdef Q68_TRACE
            q68_trace();
#endif
            const unsigned int opcode = IFETCH(state);
            state->current_PC = state->PC;
#ifndef Q68_DISABLE_ADDRESS_ERROR
            state->fault_opcode = opcode;
#endif
            const unsigned int index = (opcode>>9 & 0x78) | (opcode>>6 & 0x07);
#ifdef COUNT_OPCODES
            q68_ops[index]++;
#endif
            state->cycles += (*opcode_table[index])(state, opcode);
#ifdef Q68_USE_JIT
        }
#endif
    }  // while (state->cycles < cycles && !state->halted)

#ifdef Q68_TRACE
    q68_trace_add_cycles(state->cycles);
#endif

    return state->cycles;
}

/*************************************************************************/
/************************** Instruction helpers **************************/
/*************************************************************************/

/**
 * set_SR:  Set the processor's status register, performing any necessary
 * additional actions (such as switching user/supervisor stacks).
 *
 * [Parameters]
 *     state: Processor state block
 *     value: New SR value
 * [Return value]
 *     None
 */
static void set_SR(Q68State *state, uint16_t value)
{
    const uint16_t old_value = state->SR;
    state->SR = value;
    if ((old_value ^ value) & SR_S) {
        if (value & SR_S) {  // Switched to supervisor mode
            state->USP = state->A[7];
            state->A[7] = state->SSP;
        } else {  // Switched to user mode
            state->SSP = state->A[7];
            state->A[7] = state->USP;
        }
    }
    check_interrupt(state);
}

/*************************************************************************/

/**
 * check_interrupt:  Check whether an unmasked interrupt is pending, and
 * raise the appropriate exception if so.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
static inline void check_interrupt(Q68State *state)
{
    const int irq = state->irq & 7;  // Just to be safe
    if (UNLIKELY(irq > SR_GET_I(state)
              || irq == 7  // Level 7 is the non-maskable interrupt
    )) {
        if (state->halted != Q68_HALTED_DOUBLE_FAULT) {
            state->irq = 0;
            state->halted = 0;
            state->exception = EX_LEVEL_1_INTERRUPT + (irq-1);
        }
    }
}

/*-----------------------------------------------------------------------*/

/**
 * take_exception:  Take an exception.
 *
 * [Parameters]
 *     state: Processor state block
 *       num: Exception number
 * [Return value]
 *     Clock cycles used
 */
static int take_exception(Q68State *state, uint8_t num)
{
    static const int exception_cycles[256] = {
        [EX_BUS_ERROR                ] = 50,
        [EX_ADDRESS_ERROR            ] = 50,
        [EX_ILLEGAL_INSTRUCTION      ] = 34,
        [EX_DIVIDE_BY_ZERO           ] = 42,
        [EX_CHK                      ] = 44,
        [EX_TRAPV                    ] = 34,
        [EX_PRIVILEGE_VIOLATION      ] = 34,
        [EX_TRACE                    ] = 34,
        [EX_LINE_1010                ] = 34,  // These two are assumed to be
        [EX_LINE_1111                ] = 34,  // equal to ILLEGAL_INSTRUCTION
        [EX_SPURIOUS_INTERRUPT       ] = 44,
        [EX_LEVEL_1_INTERRUPT        ] = 44,
        [EX_LEVEL_2_INTERRUPT        ] = 44,
        [EX_LEVEL_3_INTERRUPT        ] = 44,
        [EX_LEVEL_4_INTERRUPT        ] = 44,
        [EX_LEVEL_5_INTERRUPT        ] = 44,
        [EX_LEVEL_6_INTERRUPT        ] = 44,
        [EX_LEVEL_7_INTERRUPT        ] = 44,
        [EX_TRAP+ 0                  ] = 38,
        [EX_TRAP+ 1                  ] = 38,
        [EX_TRAP+ 2                  ] = 38,
        [EX_TRAP+ 3                  ] = 38,
        [EX_TRAP+ 4                  ] = 38,
        [EX_TRAP+ 5                  ] = 38,
        [EX_TRAP+ 6                  ] = 38,
        [EX_TRAP+ 7                  ] = 38,
        [EX_TRAP+ 8                  ] = 38,
        [EX_TRAP+ 9                  ] = 38,
        [EX_TRAP+10                  ] = 38,
        [EX_TRAP+11                  ] = 38,
        [EX_TRAP+12                  ] = 38,
        [EX_TRAP+13                  ] = 38,
        [EX_TRAP+14                  ] = 38,
        [EX_TRAP+15                  ] = 38,
    };

    /* Clear this out ahead of time in case we hit a double fault */
    state->jit_running = NULL;

    if (!(state->SR & SR_S)) {
        state->USP = state->A[7];
        state->A[7] = state->SSP;
    }
#ifndef Q68_DISABLE_ADDRESS_ERROR
    if (state->A[7] & 1) {
        state->halted = Q68_HALTED_DOUBLE_FAULT;  // Oops!
        return 0;
    }
#endif
    PUSH32(state, state->PC);
    PUSH16(state, state->SR);
    if (num == EX_BUS_ERROR || num == EX_ADDRESS_ERROR) {
        PUSH16(state, state->fault_opcode);
        PUSH32(state, state->fault_addr);
        PUSH16(state, state->fault_status);
    }
    state->SR |= SR_S;
    if (num >= EX_LEVEL_1_INTERRUPT && num <= EX_LEVEL_7_INTERRUPT) {
        SR_SET_I(state, (num - EX_LEVEL_1_INTERRUPT) + 1);
    }
    state->PC = READU32(state, num*4);
#ifndef Q68_DISABLE_ADDRESS_ERROR
    if (state->PC & 1) {
        /* FIXME: Does a real 68000 double fault here or just take an
         * address error exception? */
        state->halted = Q68_HALTED_DOUBLE_FAULT;
        return 0;
    }
#endif
    return exception_cycles[num];
}

/*************************************************************************/

/**
 * op_ill:  Handle a generic illegal opcode.
 *
 * [Parameters]
 *      state: Processor state block
 *     opcode: Instruction opcode
 * [Return value]
 *     Clock cycles used
 */
static inline int op_ill(Q68State *state, uint32_t opcode)
{
    state->exception = EX_ILLEGAL_INSTRUCTION;
    return 0;
}

/*************************************************************************/
/*************************************************************************/

/**
 * ea_resolve:  Resolve the address for the memory-reference EA indicated
 * by opcode[5:0], storing it in state->ea_addr.  Behavior is undefined if
 * the EA is a direct register reference.
 *
 * [Parameters]
 *             state: Processor state block
 *            opcode: Instruction opcode
 *              size: Access size (SIZE_*)
 *       access_type: Access type (ACCESS_*)
 * [Return value]
 *     Clock cycles used (negative indicates an illegal EA)
 */
static int ea_resolve(Q68State *state, uint32_t opcode, int size,
                      int access_type)
{
    const unsigned int mode  = EA_MODE(opcode);
    const unsigned int reg   = EA_REG(opcode);
    const unsigned int bytes = SIZE_TO_BYTES(size);

    static const int base_cycles[8] = {0, 0, 4, 4, 6, 8, 10, 0};
    int cycles = base_cycles[mode] + (size==SIZE_L ? 4 : 0);

    switch (mode) {
      case EA_INDIRECT:
        state->ea_addr = state->A[reg];
        break;
      case EA_POSTINCREMENT:
        state->ea_addr = state->A[reg];
        state->A[reg] += bytes;
        if (bytes == 1 && reg == 7) {  // A7 must stay even
            state->A[reg] += 1;
        }
        break;
      case EA_PREDECREMENT:
        if (access_type == ACCESS_WRITE) {
            /* 2-cycle penalty not applied to write-only accesses
             * (MOVE and MOVEM) */
            cycles -= 2;
        }
        state->A[reg] -= bytes;
        if (bytes == 1 && reg == 7) {  // A7 must stay even
            state->A[reg] -= 1;
        }
        state->ea_addr = state->A[reg];
        break;
      case EA_DISPLACEMENT:
        state->ea_addr = state->A[reg] + (int16_t)IFETCH(state);
        break;
      case EA_INDEX: {
        const uint16_t ext = IFETCH(state);
        const unsigned int ireg = ext >> 12;  // 0..15
        const int32_t index = (ext & 0x0800) ? (int32_t)state->DA[ireg]
                                             : (int16_t)state->DA[ireg];
        const int32_t disp = (int32_t)((int8_t)ext);
        state->ea_addr = state->A[reg] + index + disp;
        break;
      }
      default:  /* case EA_MISC */
        switch (reg) {
          case EA_MISC_ABSOLUTE_W:
            cycles += 8;
            state->ea_addr = (int16_t)IFETCH(state);
            break;
          case EA_MISC_ABSOLUTE_L:
            cycles += 12;
            state->ea_addr = IFETCH(state) << 16;
            state->ea_addr |= (uint16_t)IFETCH(state);
            break;
          case EA_MISC_PCREL:
            if (access_type != ACCESS_READ) {
                return -1;
            } else {
                cycles += 8;
                state->ea_addr = state->current_PC + (int16_t)IFETCH(state);
            }
            break;
          case EA_MISC_PCREL_INDEX:
            if (access_type != ACCESS_READ) {
                return -1;
            } else {
                cycles += 10;
                const uint16_t ext = IFETCH(state);
                const unsigned int ireg = ext >> 12;  // 0..15
                const int32_t index = (ext & 0x0800) ? (int32_t)state->DA[ireg]
                                                     : (int16_t)state->DA[ireg];
                const int32_t disp = (int32_t)((int8_t)ext);
                state->ea_addr = state->current_PC + index + disp;
            }
            break;
          case EA_MISC_IMMEDIATE:
            if (access_type != ACCESS_READ) {
                return -1;
            } else {
                cycles += 4;
                state->ea_addr = state->PC;
                if (size == SIZE_B) {
                    state->ea_addr++;  // Point at the lower byte
                }
                state->PC += (size==SIZE_L ? 4 : 2);
            }
            break;
          default:
            return -1;
        }
    }
    return cycles;
}

/*-----------------------------------------------------------------------*/

/**
 * ea_get:  Read an unsigned value from the EA indicated by opcode[5:0].
 *
 * If the EA selector is invalid for the access size and mode, an illegal
 * instruction exception is raised.  If the EA is a memory reference, the
 * size is word or long, and the address is odd, an address error
 * exception is raised.  In either case, the error is indicated by a
 * negative value returned in *cycles_ret.
 *
 * [Parameters]
 *          state: Processor state block
 *         opcode: Instruction opcode
 *           size: Access size (SIZE_*)
 *         is_rmw: Nonzero if the operand will be modified and written back
 *     cycles_ret: Pointer to variable to receive clock cycles used
 *                     (negative indicates that an exception occurred)
 * [Return value]
 *     Value read (undefined if an exception occurs)
 */
static uint32_t ea_get(Q68State *state, uint32_t opcode, int size,
                       int is_rmw, int *cycles_ret)
{
    const unsigned int reg = EA_REG(opcode);
    switch (EA_MODE(opcode)) {
      case EA_DATA_REG:
        *cycles_ret = 0;
        return size==SIZE_B ? (uint8_t) state->D[reg] :
               size==SIZE_W ? (uint16_t)state->D[reg] : state->D[reg];
      case EA_ADDRESS_REG:
        if (size == SIZE_B) {
            /* An.b not permitted */
            state->exception = EX_ILLEGAL_INSTRUCTION;
            *cycles_ret = -1;
            return 0;
        } else {
            *cycles_ret = 0;
            return size==SIZE_W ? (uint16_t)state->A[reg] : state->A[reg];
        }
      default: {
        *cycles_ret = ea_resolve(state, opcode, size,
                                 is_rmw ? ACCESS_MODIFY : ACCESS_READ);
        if (*cycles_ret < 0) {
            state->exception = EX_ILLEGAL_INSTRUCTION;
            return 0;
        }
        if (size == SIZE_B) {
            return READU8(state, state->ea_addr);
        } else {
#ifndef Q68_DISABLE_ADDRESS_ERROR
            if (state->ea_addr & 1) {
                state->exception = EX_ADDRESS_ERROR;
                state->fault_addr = state->ea_addr;
                state->fault_status = FAULT_STATUS_IN_DATA
                                    | FAULT_STATUS_RW_READ;
                *cycles_ret = -1;
                return 0;
            }
#endif
            return size==SIZE_W ? READU16(state, state->ea_addr)
                                : READU32(state, state->ea_addr);
        }
      }
    }
}

/*-----------------------------------------------------------------------*/

/**
 * ea_set:  Update a value at the EA indicated by opcode[5:0].  If the
 * EA is a memory reference, uses the previously resolved address in
 * state->ea_addr rather than resolving the address again.  Behavior is
 * undefined if the previous ea_resolve() or ea_get() failed (or if no
 * previous call was made).
 *
 * If the EA is a memory reference, the size is word or long, and the
 * address is odd, an address error exception is raised instead.
 *
 * [Parameters]
 *      state: Processor state block
 *     opcode: Instruction opcode
 *       size: Access size (SIZE_*)
 *       data: Value to store
 * [Return value]
 *     None
 */
static void ea_set(Q68State *state, uint32_t opcode, int size, uint32_t data)
{
    const unsigned int reg = EA_REG(opcode);
    switch (EA_MODE(opcode)) {
      case EA_DATA_REG:
        switch (size) {
          case SIZE_B: *(BYTE_OFS + (uint8_t  *)&state->D[reg]) = data; break;
          case SIZE_W: *(WORD_OFS + (uint16_t *)&state->D[reg]) = data; break;
          default:     state->D[reg] = data;                            break;
        }
        return;
      case EA_ADDRESS_REG:
        if (size == SIZE_W) {
            state->A[reg] = (int16_t)data;  // Sign-extended for address regs
        } else {  // must be SIZE_L
            state->A[reg] = data;
        }
        return;
      default: {
        if (size == SIZE_B) {
            WRITE8(state, state->ea_addr, data);
        } else {
#ifndef Q68_DISABLE_ADDRESS_ERROR
            if (state->ea_addr & 1) {
                state->exception = EX_ADDRESS_ERROR;
                state->fault_addr = state->ea_addr;
                state->fault_status = FAULT_STATUS_IN_DATA
                                    | FAULT_STATUS_RW_WRITE;
                return;
            } else
#endif
            if (size == SIZE_W) {
                WRITE16(state, state->ea_addr, data);
            } else {
                WRITE32(state, state->ea_addr, data);
            }
        }
        return;
      }
    }
}

/*************************************************************************/
/*********************** Major instruction groups ************************/
/*************************************************************************/

/**
 * op_imm:  Immediate instructions (format 0000 xxx0 xxxx xxxx).
 */
static int op_imm(Q68State *state, uint32_t opcode)
{
    /* Check for bit-twiddling and illegal opcodes first */
    enum {OR = 0, AND, SUB, ADD, _BIT, EOR, CMP, _ILL} aluop;
    aluop = opcode>>9 & 7;
    if (aluop == _BIT) {
        return op_bit(state, opcode);
    } else if (aluop == _ILL) {
        return op_ill(state, opcode);
    }

    /* Get the instruction size */
    INSN_GET_SIZE;
    if (size == 3) {
        return op_ill(state, opcode);
    }
    const int bytes = SIZE_TO_BYTES(size);
    const int shift = bytes*8 - 1;
    const uint32_t valuemask = ~(~1 << shift);

    /* Fetch the immediate value */
    uint32_t imm = (uint16_t)IFETCH(state);
    if (size == SIZE_B) {
        imm &= 0xFF;
    } else if (size == SIZE_L) {
        imm = imm<<16 | (uint16_t)IFETCH(state);
    }

    /* Fetch the EA operand (which may be SR or CCR) */
    int use_SR;
    int cycles;
    uint32_t ea_val;
    if ((aluop==OR || aluop==AND || aluop==EOR) && (opcode & 0x3F) == 0x3C) {
        /* xxxI #imm,SR (or CCR) use the otherwise-invalid form of an
         * immediate value destination */
        if (size == SIZE_W && !(state->SR & SR_S)) {
            state->exception = EX_PRIVILEGE_VIOLATION;
            return 0;
        }
        use_SR = 1;
        cycles = 8;  // Total instruction time is 20 cycles
        switch (size) {
          case SIZE_B: ea_val = state->SR & 0xFF; break;
          case SIZE_W: ea_val = state->SR;        break;
          default:     return op_ill(state, opcode);
        }
    } else {
        use_SR = 0;
        ea_val = ea_get(state, opcode, size, 1, &cycles);
        if (cycles < 0) {
            return 0;
        }
    }

    /* Perform the operation */
    uint32_t result;
    if (aluop == ADD || aluop == SUB) {
        INSN_CLEAR_XCC();
    } else {
        INSN_CLEAR_CC();
    }
    switch (aluop) {
        case OR:  result = ea_val | imm;
                  break;
        case AND: result = ea_val & imm;
                  break;
        case EOR: result = ea_val ^ imm;
                  break;
        case CMP: if (size == SIZE_L) {  // CMPI takes less time in most cases
                      if (EA_MODE(opcode) != EA_DATA_REG) {
                          cycles -= 8;
                      } else {
                          cycles -= 2;
                      }
                  } else {
                      if (EA_MODE(opcode) != EA_DATA_REG) {
                          cycles -= 4;
                      }
                  }
                  /* fall through to... */
        case SUB: { result = (ea_val - imm) & valuemask;
                    if (((imm ^ ea_val) & (result ^ ea_val)) >> shift) {
                        state->SR |= SR_V;
                    }
                    if ((int)((imm >> shift) - (ea_val >> shift)
                                             + (result >> shift)) > 0) {
                        state->SR |= SR_C;
                        if (aluop != CMP) {
                            state->SR |= SR_X;
                        }
                    }
                    break;
                  }
        default:  // case ADD
                  result = (ea_val + imm) & valuemask;
                  if (((ea_val ^ result) & (imm ^ result)) >> shift) {
                      state->SR |= SR_V;
                  }
                  if ((int)((ea_val >> shift) + (imm >> shift)
                                              - (result >> shift)) > 0) {
                      state->SR |= SR_X | SR_C;
                  }
                  break;
    }
    INSN_SETNZ_SHIFT(result);

    /* Update the EA operand (if not CMPI) */
    if (aluop != CMP) {
        if (use_SR) {
            if (size == SIZE_W) {
                set_SR(state, result);
            } else {
                state->SR &= 0xFF00;
                state->SR |= result;
            }
        } else {
            ea_set(state, opcode, size, result);
        }
    }

    /* All done */
    return (size==SIZE_L ? 16 : 8)
        + (EA_MODE(opcode) == EA_DATA_REG ? 0 : 4) + cycles;
}

/*************************************************************************/

/**
 * op_bit:  Bit-twiddling instructions (formats 0000 rrr1 xxxx xxxx and
 * 0000 1000 xxxx xxxx).
 */
static int op_bit(Q68State *state, uint32_t opcode)
{
    /* Check early for MOVEP (coded as BTST/BCHG/BCLR/BSET Dn,An) */
    if (EA_MODE(opcode) == EA_ADDRESS_REG) {
        if (opcode & 0x0100) {
            return opMOVP(state, opcode);
        } else {
            return op_ill(state, opcode);
        }
    }

    enum {BTST = 0, BCHG = 1, BCLR = 2, BSET = 3} op = opcode>>6 & 3;
    int cycles;

    /* Get the bit number to operate on */
    unsigned int bitnum;
    if (opcode & 0x0100) {
        /* Bit number in register */
        INSN_GET_REG;
        bitnum = state->D[reg];
        cycles = 0;
    } else {
        bitnum = IFETCH(state);
        cycles = 4;
    }

    /* EA operand is 32 bits when coming from a register, 8 when from memory */
    int size;
    switch (EA_MODE(opcode)) {
      case EA_DATA_REG:
        size = SIZE_L;
        bitnum %= 32;
        break;
      default:
        size = SIZE_B;
        bitnum %= 8;
        break;
    }
    int cycles_tmp;
    uint32_t value = ea_get(state, opcode, size, 1, &cycles_tmp);
    if (cycles_tmp < 0) {
        return 0;
    }
    cycles += cycles_tmp;
    if (size == SIZE_L && (op == BCLR || op == BTST)) {
        cycles += 2;
    }

    /* Perform the operation */
    if ((value >> bitnum) & 1) {
        state->SR &= ~SR_Z;
    } else {
        state->SR |= SR_Z;
    }
    switch (op) {
      case BTST: /* Nothing to do */      break;
      case BCHG: value ^=   1 << bitnum;  break;
      case BCLR: value &= ~(1 << bitnum); break;
      case BSET: value |=   1 << bitnum;  break;
    }

    /* Update EA operand (if not BTST) */
    if (op != BTST) {
        ea_set(state, opcode, size, value);
    }

    /* Return cycle count; note that the times for BCHG.L, BCLR.L, and
     * BSET.L are maximums (though how they vary is undocumented) */
    return (op==BTST ? 4 : 8) + cycles;
}

/*************************************************************************/

/**
 * opMOVE:  MOVE.[bwl] instruction (format {01,10,11}xx xxxx xxxx xxxx).
 */
static int opMOVE(Q68State *state, uint32_t opcode)
{
    const int size = (opcode>>12==1 ? SIZE_B : opcode>>12==2 ? SIZE_L : SIZE_W);

    int cycles_src;
    const uint32_t data = ea_get(state, opcode, size, 0, &cycles_src);
    if (cycles_src < 0) {
        return 0;
    }

    /* Rearrange the opcode bits so we can pass the destination EA to
     * ea_resolve() */
    const uint32_t dummy_opcode = (opcode>>9 & 7) | (opcode>>3 & 0x38);
    int cycles_dest;
    if (EA_MODE(dummy_opcode) <= EA_ADDRESS_REG) {
        cycles_dest = 0;
    } else {
        cycles_dest = ea_resolve(state, dummy_opcode, size, ACCESS_WRITE);
        if (cycles_dest < 0) {
            return op_ill(state, opcode);
        }
    }

    /* Update condition codes if the target is not an address register */
    if (EA_MODE(dummy_opcode) != EA_ADDRESS_REG) {
        INSN_CLEAR_CC();
        INSN_SETNZ(size==SIZE_B ? (int8_t)data :
                   size==SIZE_W ? (int16_t)data : (int32_t)data);
    }

    /* Update the destination EA and return */
    ea_set(state, dummy_opcode, size, data);
    return 4 + cycles_src + cycles_dest;
}

/*************************************************************************/

/**
 * op4xxx:  Miscellaneous instructions (format 0100 xxx0 xxxx xxxx).
 */
static int op4xxx(Q68State *state, uint32_t opcode)
{
    const unsigned int index = (opcode>>7 & 0x1C) | (opcode>>6 & 3);
#ifdef COUNT_OPCODES
    q68_4xxx_ops[index]++;
#endif
    return (*opcode_4xxx_table[index])(state, opcode);
}

/*************************************************************************/

/**
 * op_CHK:  CHK instruction (format 0100 rrr1 10xx xxxx).
 */
static int op_CHK(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    int size = SIZE_W;  // Bit 7 == 0 indicates long mode on the 68020

    int cycles;
    int32_t upper;  // Yes, it's signed
    if (EA_MODE(opcode) == EA_ADDRESS_REG) {
        return op_ill(state, opcode);
    }
    upper = ea_get(state, opcode, size, 0, &cycles);
    if (cycles < 0) {
        return 0;
    }
    if (size == SIZE_W) {
        upper = (int32_t)(int16_t)upper;
    }

    int32_t value;
    if (size == SIZE_W) {
        value = (int32_t)(int16_t)state->D[reg];
    } else {
        value = (int32_t)state->D[reg];
    }
    if (value < 0) {
        state->SR |= SR_N;
        state->exception = EX_CHK;
        return cycles;
    } else if (value > upper) {
        state->SR &= ~SR_N;
        state->exception = EX_CHK;
        return cycles;
    }

    return 10 + cycles;
}

/*************************************************************************/

/**
 * op_LEA:  LEA instruction (format 0100 rrr1 11xx xxxx).
 */
static int op_LEA(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;

    /* Register, predecrement, postincrement, immediate modes are illegal */
    if (EA_MODE(opcode) == EA_DATA_REG
     || EA_MODE(opcode) == EA_ADDRESS_REG
     || EA_MODE(opcode) == EA_POSTINCREMENT
     || EA_MODE(opcode) == EA_PREDECREMENT
     || (EA_MODE(opcode) == EA_MISC && EA_REG(opcode) == EA_MISC_IMMEDIATE)
    ) {
        return op_ill(state, opcode);
    }

    int cycles = ea_resolve(state, opcode, SIZE_W, ACCESS_READ);
    if (cycles < 0) {
        return op_ill(state, opcode);
    }
    if (cycles % 4 == 2) {  // d(An,ix) and d(PC,ix) take 2 extra cycles
        cycles += 2;
    }
    state->A[reg] = state->ea_addr;
    return cycles;
}

/*************************************************************************/

/**
 * opADSQ:  ADDQ and SUBQ instructions (format 0101 iiix xxxx xxxx).
 */
static int opADSQ(Q68State *state, uint32_t opcode)
{
    const int is_sub = opcode & 0x0100;
    INSN_GET_COUNT;
    INSN_GET_SIZE;
    if (EA_MODE(opcode) == EA_ADDRESS_REG && size == 1) {
        size = 2;  // ADDQ.W #imm,An is equivalent to ADDQ.L #imm,An
    }
    const int bytes = SIZE_TO_BYTES(size);
    const int shift = bytes*8 - 1;
    const uint32_t valuemask = ~(~1 << shift);
    int cycles;
    uint32_t data = ea_get(state, opcode, size, 1, &cycles);
    if (cycles < 0) {
        return 0;
    }

    uint32_t result;
    if (is_sub) {
        result = data - count;
    } else {
        result = data + count;
    }
    result &= valuemask;
    if (EA_MODE(opcode) != EA_ADDRESS_REG) {
        INSN_CLEAR_XCC();
        INSN_SETNZ_SHIFT(result);
        if ((is_sub ? ~result & data : result & ~data) >> shift) {
            state->SR |= SR_V;
        }
        if ((is_sub ? result & ~data : ~result & data) >> shift) {
            state->SR |= SR_X | SR_C;
        }
    }
    
    ea_set(state, opcode, size, result);
    return (size==SIZE_L || EA_MODE(opcode) == EA_ADDRESS_REG ? 8 : 4)
           + (EA_MODE(opcode) >= EA_INDIRECT ? 4 : 0) + cycles;
}

/*************************************************************************/

/**
 * op_Scc:  Scc instruction (format 0101 cccc 11xx xxxx).
 */
static int op_Scc(Q68State *state, uint32_t opcode)
{
    if (EA_MODE(opcode) == EA_ADDRESS_REG) {
        /* DBcc Dn,disp is coded as Scc An with an extension word */
        return opDBcc(state, opcode);
    }

    INSN_GET_COND;
    const int is_true = INSN_COND_TRUE(cond);
    /* From the cycle counts, it looks like this is a standard read/write
     * access rather than a write-only access */
    int cycles;
    if (EA_MODE(opcode) == EA_DATA_REG) {
        cycles = 0;
    } else {
        cycles = ea_resolve(state, opcode, SIZE_B, ACCESS_MODIFY);
        if (cycles < 0) {
            return op_ill(state, opcode);
        }
    }
    ea_set(state, opcode, SIZE_B, is_true ? 0xFF : 0x00);
    if (EA_MODE(opcode) == EA_DATA_REG) {
        /* Scc Dn is a special case */
        return is_true ? 6 : 4;
    } else {
        return 8 + cycles;
    }
}

/*-----------------------------------------------------------------------*/

/**
 * op_DBcc:  DBcc instruction (format 0101 cccc 1100 1xxx).
 */
static int opDBcc(Q68State *state, uint32_t opcode)
{
    INSN_GET_COND;
    const int is_true = INSN_COND_TRUE(cond);
    INSN_GET_REG0;
    INSN_GET_IMM16;
    if (is_true) {
        return 12;
    } else if (--(*(WORD_OFS + (int16_t *)&state->D[reg0])) == -1) {
        return 14;
    } else {
        state->PC = state->current_PC + imm16;
        return 10;
    }
}

/*************************************************************************/

/**
 * op_Bcc:  Conditional branch instructions (format 0110 cccc dddd dddd).
 */
static int op_Bcc(Q68State *state, uint32_t opcode)
{
    INSN_GET_COND;
    INSN_GET_DISP8;
    int cycles = 0;
    if (disp == 0) {
        disp = (int16_t)IFETCH(state);
        cycles = 4;
    }
    if (cond == COND_F) {
        /* BF is really BSR */
#ifndef Q68_DISABLE_ADDRESS_ERROR
        if (state->A[7] & 1) {
            state->exception = EX_ADDRESS_ERROR;
            state->fault_addr = state->A[7];
            state->fault_status = FAULT_STATUS_IN_DATA
                                | FAULT_STATUS_RW_WRITE;
            return 0;
        }
#endif
        PUSH32(state, state->PC);
        state->PC = state->current_PC + disp;
        return 18;
    } else if (INSN_COND_TRUE(cond)) {
        state->PC = state->current_PC + disp;
        return 10;
    } else {
        return 8 + cycles;
    }
}

/*************************************************************************/

/**
 * opMOVQ:  MOVEQ instruction (format 0111 rrr0 iiii iiii).
 */
static int opMOVQ(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    INSN_GET_IMM8;
    state->D[reg] = imm8;
    INSN_CLEAR_CC();
    INSN_SETNZ(imm8);
    return 4;
}

/*************************************************************************/

/**
 * op_alu:  Non-immediate ALU instructions (format 1ooo rrrx xxxx xxxx for
 * ooo = 000, 001, 011, 100, 101).
 */
static int op_alu(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    INSN_GET_SIZE;

    /* Pass off special and invalid instructions early */
    if (size != 3) {
        if ((opcode & 0xB130) == 0x9100) {
            /* ADDX/SUBX are coded as ADD/SUB.* Dn,<ea:Rn> */
            return opADSX(state, opcode);
        }
        if ((opcode & 0xB1F0) == 0x8100) {
            /* ABCD/SBCD are coded as AND/OR.b Dn,<ea:Rn> */
            return op_BCD(state, opcode);
        }
        if ((opcode & 0xF130) == 0xC100) {
            /* EXG is coded as AND.[wl] Dn,<ea:Rn> */
            return op_EXG(state, opcode);
        }
        if ((opcode & 0xF130) == 0x8100) {
            /* OR.[wl] Dn,<ea:Rn> is invalid on the 68000 (later PACK/UNPK) */
            return op_ill(state, opcode);
        }
        if ((opcode & 0xF138) == 0xB108 && (opcode>>6 & 3) != 3) {
            /* CMPM is coded as EOR.* Dn,<ea:An> */
            return opCMPM(state, opcode);
        }
    }

    const int bytes = SIZE_TO_BYTES(size);
    const int shift = bytes*8 - 1;
    const uint32_t valuemask = ~(~1 << shift);
    int ea_dest = opcode & 0x100;
    int areg_dest = 0;  // For ADDA/SUBA/CMPA
    enum {OR, AND, EOR, CMP, SUB, ADD} aluop;

    /* Find the instruction for the opcode group */
    switch (opcode>>12) {
        case 0x8: aluop = OR;  break;
        case 0x9: aluop = SUB; break;
        case 0xB: aluop = (((opcode>>6)+1) & 7) <= 4 ? CMP : EOR; break;
        case 0xC: aluop = AND; break;
        default:  aluop = ADD; break;  // case 0xD
    }

    /* Handle the special formats of ADDA/SUBA/CMPA */
    if ((aluop == ADD || aluop == SUB || aluop == CMP) && size == 3) {
        size = ea_dest ? SIZE_L : SIZE_W;
        ea_dest = 0;
        areg_dest = 1;
    }

    /* Retrieve the register and EA values */
    uint32_t reg_val = areg_dest ? state->A[reg] : (state->D[reg] & valuemask);
    int cycles;
    uint32_t ea_val = ea_get(state, opcode, size, ea_dest, &cycles);
    if (cycles < 0) {
        return 0;
    }
    if (size == SIZE_L || areg_dest) {
        cycles += 4;
    }
    if (ea_dest) {
        cycles += 4;
    } else if ((aluop == CMP && areg_dest)
               || (size == SIZE_L
                   && (EA_MODE(opcode) <= EA_ADDRESS_REG
                       || (EA_MODE(opcode) == EA_MISC
                           && EA_REG(opcode) == EA_MISC_IMMEDIATE)))) {
        cycles -= 2;
    }

    /* Perform the actual computation */
    uint32_t result;
    if (!areg_dest || aluop == CMP) {
        if (aluop == ADD || aluop == SUB) {
            INSN_CLEAR_XCC();
        } else {
            INSN_CLEAR_CC();
        }
    }
    switch (aluop) {
        case OR:  result = reg_val | ea_val;
                  break;
        case AND: result = reg_val & ea_val;
                  break;
        case EOR: result = reg_val ^ ea_val;
                  break;
        case CMP: /* fall through to... */
        case SUB: { uint32_t src, dest;
                    if (areg_dest) {
                        /* CMPA/SUBA keep all 32 bits, and SUBA doesn't
                         * touch flags */
                        src = ea_val;
                        dest = reg_val;
                        result = reg_val - ea_val;
                        if (aluop == SUB) {
                            break;
                        }
                    } else {
                        if (ea_dest) {
                            src = reg_val;
                            dest = ea_val;
                        } else {
                            src = ea_val;
                            dest = reg_val;
                        }
                        result = (dest - src) & valuemask;
                    }
                    if (((src ^ dest) & (result ^ dest)) >> shift) {
                        state->SR |= SR_V;
                    }
                    if ((int)((src >> shift) - (dest >> shift)
                                             + (result >> shift)) > 0) {
                        state->SR |= SR_C;
                        if (aluop != CMP) {
                            state->SR |= SR_X;
                        }
                    }
                    break;
                  }
        default:  // case ADD
                  if (areg_dest) {
                      /* ADDA keeps all 32 bits and doesn't touch flags */
                      result = reg_val + ea_val;
                      break;
                  }
                  result = (reg_val + ea_val) & valuemask;
                  if (((reg_val ^ result) & (ea_val ^ result)) >> shift) {
                      state->SR |= SR_V;
                  }
                  if ((int)((reg_val >> shift) + (ea_val >> shift)
                                               - (result >> shift)) > 0) {
                      state->SR |= SR_X | SR_C;
                  }
                  break;
    }  // switch (aluop)
    if (!areg_dest || aluop == CMP) {
        INSN_SETNZ_SHIFT(result);
    }

    /* Store the result in the proper place (if the instruction is not CMP) */
    if (aluop != CMP) {
        if (ea_dest) {
            ea_set(state, opcode, size, result);
        } else if (areg_dest) {
            state->A[reg] = result;
        } else if (size == SIZE_B) {
            *(BYTE_OFS + (uint8_t  *)&state->D[reg]) = result;
        } else if (size == SIZE_W) {
            *(WORD_OFS + (uint16_t *)&state->D[reg]) = result;
        } else {  // size == SIZE_L
            state->D[reg] = result;
        }
    }

    return 4 + cycles;
}

/*************************************************************************/

/**
 * op_DIV:  DIVU and DIVS instructions (format 1000 rrrx 11xx xxxx).
 */
static int op_DIV(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    const int sign = opcode & (1<<8);

    state->SR &= ~SR_C;  // Always cleared, even on exception

    int cycles;
    const uint16_t divisor = ea_get(state, opcode, SIZE_W, 0, &cycles);
    if (cycles < 0) {
        return 0;
    }
    if (divisor == 0) {
        state->exception = EX_DIVIDE_BY_ZERO;
        return cycles;
    }

    int32_t quotient, remainder;
    if (sign) {
        quotient  = (int32_t)state->D[reg] / (int16_t)divisor;
        remainder = (int32_t)state->D[reg] % (int16_t)divisor;
        if (quotient < -0x8000 || quotient > 0x7FFF) {
            state->SR |= SR_V;
        } else {
            state->SR &= ~SR_V;
        }
    } else {
        quotient  = state->D[reg] / divisor;
        remainder = state->D[reg] % divisor;
        if (quotient & 0xFFFF0000) {
            state->SR |= SR_V;
        } else {
            state->SR &= ~SR_V;
        }
    }

    if (!(state->SR & SR_V)) {
        state->D[reg] = (quotient & 0xFFFF) | (remainder << 16);
        if (quotient & 0x8000) {
            state->SR |= SR_N;
        } else {
            state->SR &= ~SR_N;
        }
        if (quotient == 0) {
            state->SR |= SR_Z;
        } else {
            state->SR &= ~SR_Z;
        }
    }
    /* The 68000 docs say that the timing difference between best and
     * worst cases is less than 10%, so we just return the worst case */
    return (sign ? 158 : 140) + cycles;
}

/*************************************************************************/

/**
 * opAxxx:  $Axxx illegal instruction set (format 1010 xxxx xxxx xxxx).
 */
static int opAxxx(Q68State *state, uint32_t opcode)
{
    state->exception = EX_LINE_1010;
    return 0;
}

/*************************************************************************/

/**
 * op_MUL:  MULU and MULS instructions (format 1100 rrrx 11xx xxxx).
 */
static int op_MUL(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    const int sign = opcode & (1<<8);

    int cycles;
    const uint16_t data = ea_get(state, opcode, SIZE_W, 0, &cycles);
    if (cycles < 0) {
        return 0;
    }

    if (sign) {
        state->D[reg] = (int16_t)state->D[reg] * (int16_t)data;
    } else {
        state->D[reg] = (uint16_t)state->D[reg] * data;
    }
    INSN_CLEAR_CC();
    INSN_SETNZ(state->D[reg]);

    /* Precise timing varies with the effective address; the algorithm is
     * implemented below for reference, but for typical usage it's probably
     * not important to be exact */
#ifdef MUL_PRECISE_TIMING  // not normally defined
    if (sign) {
        uint32_t temp;
        for (temp = (uint32_t)data << 1; temp != 0; temp >>= 1) {
            if ((temp & 3) == 1 || (temp & 3) == 2) {
                cycles += 2;
            }
        }
    } else {
        unsigned int temp;
        for (temp = data; temp != 0; temp >>= 1) {
            if (temp & 1) {
                cycles += 2;
            }
        }
    }
    return 38 + cycles;
#else  // !MUL_PRECISE_TIMING
    return 54 + cycles;
#endif
}

/*************************************************************************/

/**
 * opshft:  Shift and rotate instructions (format 1110 xxxx xxxx xxxx).
 */
static int opshft(Q68State *state, uint32_t opcode)
{
    const int is_left = opcode & 0x0100;
    INSN_GET_SIZE;
    INSN_GET_COUNT;
    INSN_GET_REG0;
    int is_memory;
    int type;  // Shift/rotate type (0=ASL/ASR, 1=LSL/LSR, ...)
    uint32_t data;
    int cycles;

    if (size == 3) {
        /* Memory shift/rotate */
        is_memory = 1;
        if ((opcode & 0x0800) || EA_MODE(opcode) <= EA_ADDRESS_REG) {
            return op_ill(state, opcode);
        }
        size = SIZE_W;
        type = opcode>>9 & 3;
        count = 1;
        data = ea_get(state, opcode, size, 1, &cycles);
        if (cycles < 0) {
            return 0;
        }
    } else {
        /* Register shift/rotate */
        is_memory = 0;
        type = opcode>>3 & 3;
        if (opcode & 0x0020) {
            INSN_GET_REG;
            count = state->D[reg] & 63;
        }
        data = size==SIZE_B ? (uint8_t) state->D[reg0] :
               size==SIZE_W ? (uint16_t)state->D[reg0] : state->D[reg0];
        cycles = 0;
    }
    cycles += count*2;

    INSN_CLEAR_CC();
    if (count > 0) {
        const int nbits = (size==SIZE_B ? 8 : size==SIZE_W ? 16 : 32);
        switch (type) {
          case 0:  // ASL/ASR
            state->SR &= ~SR_X;
            if (is_left) {
                int V = 0, C;
                /* Have to shift bit by bit to detect overflow */
                for (; count > 0; count--) {
                    C = (data >> (nbits-1)) & 1;
                    data <<= 1;
                    V |= (C ^ (data >> (nbits-1))) & 1;
                }
                if (V) {
                    state->SR |= SR_V;
                }
                if (C) {
                    state->SR |= SR_X | SR_C;
                }
            } else {
                if (size == SIZE_B) {  // Sign extend if necessary
                    data = (int8_t)data;
                } else if (size == SIZE_W) {
                    data = (int16_t)data;
                }
                if (count > nbits) {
                    count = 32;  // Some systems break with a shift count >32
                }
                data = (int32_t)data >> (count-1);
                if (data & 1) {
                    state->SR |= SR_X | SR_C;
                }
                data = (int32_t)data >> 1;
            }
            break;
          case 1:  // LSL/LSR
            state->SR &= ~SR_X;
            if (count > nbits) {
                data = 0;
            } else if (is_left) {
                data <<= count-1;
                if ((data >> (nbits-1)) & 1) {
                    state->SR |= SR_X | SR_C;
                }
                data <<= 1;
            } else {
                data = (int32_t)data >> (count-1);
                if (data & 1) {
                    state->SR |= SR_X | SR_C;
                }
                data = (int32_t)data >> 1;
            }
            break;
          case 2: {  // ROXL/ROXR
            uint32_t X = (state->SR >> SR_X_SHIFT) & 1;
            state->SR &= ~SR_X;
            if (is_left) {
                for (; count > 0; count--) {
                    const int new_X = (data >> (nbits-1)) & 1;
                    data = (data << 1) | X;
                    X = new_X;
                }
            } else {
                for (; count > 0; count--) {
                    const int new_X = data & 1;
                    data = (data >> 1) | (X << (nbits-1));
                    X = new_X;
                }
            }
            if (X) {
                state->SR |= SR_C | SR_X;
            }
            break;
          }
          default: {  // (case 3) ROL/ROR
            count %= nbits;
            if (is_left) {
                data = (data << count) | (data >> (nbits - count));
                if ((data >> (nbits-1)) & 1) {
                    state->SR |= SR_C;
                }
                data <<= 1;
            } else {
                data = (data >> count) | (data << (nbits - count));
                if (data & 1) {
                    state->SR |= SR_C;
                }
                data = (int32_t)data >> 1;
            }
            break;
          }
        }  // switch (type)
    } else {  // count == 0
        if (type == 2 && (state->SR & SR_X)) {
            state->SR |= SR_C;
        }
    }
    INSN_SETNZ(size==SIZE_B ? (int8_t) data : 
               size==SIZE_W ? (int16_t)data : data);

    if (is_memory) {
        ea_set(state, opcode, size, data);
    } else {
        switch (size) {
          case SIZE_B: *(BYTE_OFS + (uint8_t  *)&state->D[reg0]) = data; break;
          case SIZE_W: *(WORD_OFS + (uint16_t *)&state->D[reg0]) = data; break;
          default:     state->D[reg0] = data;                            break;
        }
    }
    return (size==SIZE_L ? 8 : 6) + cycles;
}

/*************************************************************************/

/**
 * opFxxx:  $Fxxx illegal instruction set (format 1111 xxxx xxxx xxxx).
 */
static int opFxxx(Q68State *state, uint32_t opcode)
{
    state->exception = EX_LINE_1111;
    return 0;
}

/*************************************************************************/
/*********************** $4xxx group instructions ************************/
/*************************************************************************/

/**
 * op4alu:  Single-operand ALU instructions in the $4xxx opcode range
 * (format 0100 ooo0 ssxx xxxx for ooo = 000, 001, 010, 011, 101).
 */
static int op4alu(Q68State *state, uint32_t opcode)
{
    INSN_GET_SIZE;
    const int bytes = SIZE_TO_BYTES(size);
    const int shift = bytes*8 - 1;
    const uint32_t valuemask = ~(~1 << shift);
    enum {NEGX = 0, CLR = 1, NEG = 2, NOT = 3, TST = 5} aluop;
    aluop = opcode>>9 & 7;

    if (EA_MODE(opcode) == EA_ADDRESS_REG) {  // Address registers not allowed
        return op_ill(state, opcode);
    }

    /* Retrieve the EA value */
    int cycles;
    uint32_t value = ea_get(state, opcode, size, 1, &cycles);
    if (cycles < 0) {
        return 0;
    }
    if (aluop != TST) {
        if (EA_MODE(opcode) == EA_DATA_REG) {
            if (size == SIZE_L) {
                cycles += 2;
            }
        } else {
            cycles += (size == SIZE_L) ? 8 : 4;
        }
    }

    /* Perform the actual computation */
    uint32_t result;
    if (aluop == NEGX) {
        state->SR &= ~(SR_N | SR_V | SR_C);  // Z is never set, only cleared
    } else {
        INSN_CLEAR_CC();
    }
    switch (aluop) {
        case NEGX: { int X = (state->SR >> SR_X_SHIFT) & 1;
                     result = (0 - value - X) & valuemask;
                     if (result != 0) {
                         state->SR &= ~SR_Z;
                     }
                     goto NEG_common;
                   }
        case NEG:  result = (0 - value) & valuemask;
                   if (result == 0) {
                       state->SR |= SR_Z;
                   } else {
                       state->SR &= ~SR_Z;
                   }
                 NEG_common:
                   if (result >> shift) {
                       state->SR |= SR_N;
                   }
                   if ((value & result) >> shift) {
                       state->SR |= SR_V;
                   }
                   if ((value | result) != 0) {
                       state->SR |= SR_X | SR_C;
                   } else {
                       state->SR &= ~SR_X;
                   }
                   break;
        case CLR:  result = 0;
                   state->SR |= SR_Z;
                   break;
        case NOT:  result = ~value & valuemask;
                   INSN_SETNZ_SHIFT(result);
                   break;
        default:   // case TST
                   result = value;  // Avoid a compiler warning
                   INSN_SETNZ_SHIFT(value);
                   break;
    }  // switch (aluop)

    /* Store the result in the proper place (if the instruction is not TST) */
    if (aluop != TST) {
        ea_set(state, opcode, size, result);
    }

    return 4 + cycles;
}

/*************************************************************************/

/**
 * opMVSR:  MOVE to/from SR/CCR instructions (format 0100 0xx0 11xx xxxx).
 */
static int opMVSR(Q68State *state, uint32_t opcode)
{
    int is_CCR;
    int ea_dest;
    int cycles;
    switch (opcode>>9 & 3) {
      case 0:  // MOVE SR,<ea>
        is_CCR = 0;
        ea_dest = 1;
        cycles = (EA_MODE(opcode) == EA_DATA_REG) ? 6 : 8;
        break;
      case 1:  // Undefined (MOVE CCR,<ea> on 68010)
        return op_ill(state, opcode);
      case 2:  // MOVE <ea>,CCR
        is_CCR = 1;
        ea_dest = 0;
        cycles = 12;
        break;
      default: // MOVE <ea>,SR (case 3)
        if (!(state->SR & SR_S)) {
            state->exception = EX_PRIVILEGE_VIOLATION;
            return 0;
        }
        is_CCR = 0;
        ea_dest = 0;
        cycles = 12;
        break;
    }

    if (EA_MODE(opcode) == EA_ADDRESS_REG) {  // Address registers not allowed
        return op_ill(state, opcode);
    }

    /* Motorola docs say the address is read before being written, even
     * for the SR,<ea> format; also, the access size is a word even for
     * CCR operations. */
    int cycles_tmp;
    uint16_t value = ea_get(state, opcode, SIZE_W, ea_dest, &cycles_tmp);
    if (cycles_tmp < 0) {
        return 0;
    }
    cycles += cycles_tmp;

    if (ea_dest) {
        uint16_t value = state->SR;
        if (is_CCR) {
            value &= 0x00FF;
        }
        ea_set(state, opcode, SIZE_W, value);
    } else {
        if (!is_CCR) {
            set_SR(state, value);
        }
    }
    return cycles;
}

/*************************************************************************/

/**
 * opNBCD:  NBCD instruction (format 0100 1000 00xx xxxx).
 */
static int opNBCD(Q68State *state, uint32_t opcode)
{
    if (EA_MODE(opcode) == EA_ADDRESS_REG) {  // Address registers not allowed
        return op_ill(state, opcode);
    }

    int cycles;
    int value = ea_get(state, opcode, SIZE_B, 1, &cycles);
    if (cycles < 0) {
        return 0;
    }

    int result;
    int X = (state->SR >> SR_X_SHIFT) & 1;
    state->SR &= ~(SR_X | SR_C);  // Z is never set, only cleared
    /* Slightly convoluted to match what a real 68000 does (see SBCD) */
    int res_low = 0 - (value & 0x0F) - X;
    int borrow = 0;
    if (res_low < 0) {
        res_low += 10;
        borrow = 1<<4;
    }
    int res_high = 0 - (value & 0xF0) - borrow;
    if (res_high < 0) {
        res_high += 10<<4;
        state->SR |= SR_X | SR_C;
    }
    result = res_high + res_low;
    if (result < 0) {
        state->SR |= SR_X | SR_C;
    }
    result &= 0xFF;
    if (result != 0) {
        state->SR &= ~SR_Z;
    }

    ea_set(state, opcode, SIZE_B, result);
    return (EA_MODE(opcode) == EA_DATA_REG ? 6 : 8) + cycles;
}

/*************************************************************************/

/**
 * op_PEA:  PEA instruction (format 0100 1000 01xx xxxx).
 */
static int op_PEA(Q68State *state, uint32_t opcode)
{
    /* SWAP is coded as PEA Dn */
    if (EA_MODE(opcode) == EA_DATA_REG) {
        return opSWAP(state, opcode);
    }

    if (EA_MODE(opcode) == EA_DATA_REG
     || EA_MODE(opcode) == EA_ADDRESS_REG
     || EA_MODE(opcode) == EA_POSTINCREMENT
     || EA_MODE(opcode) == EA_PREDECREMENT
     || (EA_MODE(opcode) == EA_MISC && EA_REG(opcode) == EA_MISC_IMMEDIATE)
    ) {
        return op_ill(state, opcode);
    }

    int cycles = ea_resolve(state, opcode, SIZE_W, ACCESS_READ);
    if (cycles < 0) {
        return op_ill(state, opcode);
    }
    if (cycles % 4 == 2) {  // d(An,ix) and d(PC,ix) take 2 extra cycles
        cycles += 2;
    }
#ifndef Q68_DISABLE_ADDRESS_ERROR
    if (state->A[7] & 1) {
        state->exception = EX_ADDRESS_ERROR;
        state->fault_addr = state->A[7];
        state->fault_status = FAULT_STATUS_IN_DATA
                            | FAULT_STATUS_RW_WRITE;
        return 0;
    }
#endif
    PUSH32(state, state->ea_addr);
    return 8 + cycles;
}

/*************************************************************************/

/**
 * opSWAP:  SWAP instruction (format 0100 1000 0100 0rrr).
 */
static int opSWAP(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG0;
    state->D[reg0] = state->D[reg0]>>16 | state->D[reg0]<<16;
    INSN_CLEAR_CC();
    INSN_SETNZ(state->D[reg0]);
    return 4;
}

/*************************************************************************/

/**
 * op_TAS:  TAS instruction (format 0100 1010 11xx xxxx).  Also covers the
 * ILLEGAL instruction (format 0100 1010 1111 1100).
 */
static int op_TAS(Q68State *state, uint32_t opcode)
{
    if (EA_MODE(opcode) == EA_ADDRESS_REG) {  // Address registers not allowed
        return op_ill(state, opcode);
    }

    int cycles;
    int8_t value = ea_get(state, opcode, SIZE_B, 1, &cycles);
    if (cycles < 0) {
        /* Note that the ILLEGAL instruction is coded as TAS #imm, so it
         * will be rejected as unwriteable by ea_get() */
        return 0;
    }

    INSN_CLEAR_CC();
    INSN_SETNZ(value);
    ea_set(state, opcode, SIZE_B, value | 0x80);
    return (EA_MODE(opcode) == EA_DATA_REG ? 4 : 10) + cycles;
}

/*************************************************************************/

/**
 * op_EXT:  EXT instruction (format 0100 1000 1s00 0rrr).
 */
static int op_EXT(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG0;
    INSN_CLEAR_CC();
    if (opcode & 0x0040) {
        int16_t value = (int16_t)state->D[reg0];
        state->D[reg0] = (int32_t)value;
        INSN_SETNZ(value);
    } else {
        int8_t value = (int16_t)state->D[reg0];
        *(WORD_OFS + (int16_t *)&state->D[reg0]) = (int16_t)value;
        INSN_SETNZ(value);
    }
    return 4;
}

/*************************************************************************/

/**
 * op_STM:  MOVEM reglist,<ea> (i.e. STore Multiple) instruction (format
 * 0100 1000 1sxx xxxx).
 */
static int op_STM(Q68State *state, uint32_t opcode)
{
    /* EXT.* is coded as MOVEM.* reglist,Dn */
    if (EA_MODE(opcode) == EA_DATA_REG) {
        return op_EXT(state, opcode);
    }

    unsigned int regmask = IFETCH(state);
    int size = (opcode & 0x0040) ? SIZE_L : SIZE_W;
    if (EA_MODE(opcode) <= EA_ADDRESS_REG
     || EA_MODE(opcode) == EA_POSTINCREMENT  // Not allowed for store
    ) {
        return op_ill(state, opcode);
    }

    /* Avoid modifying the register during address resolution */
    uint16_t safe_ea;
    if (EA_MODE(opcode) == EA_PREDECREMENT) {
        safe_ea = EA_INDIRECT<<3 | EA_REG(opcode);
    } else {
        safe_ea = opcode;
    }
    int cycles = ea_resolve(state, safe_ea, SIZE_W, ACCESS_WRITE);
    if (cycles < 0) {
        return op_ill(state, opcode);
    }
#ifndef Q68_DISABLE_ADDRESS_ERROR
    if (state->ea_addr & 1) {
        state->exception = EX_ADDRESS_ERROR;
        state->fault_addr = state->ea_addr;
        state->fault_status = FAULT_STATUS_IN_DATA
                            | FAULT_STATUS_RW_WRITE;
        return 0;
    }
#endif

    if (EA_MODE(opcode) == EA_PREDECREMENT) {
        /* Register order is reversed in predecrement mode */
        int reg;
        for (reg = 15; reg >= 0; reg--, regmask >>= 1) {
            if (regmask & 1) {
                if (size == SIZE_W) {
                    state->ea_addr -= 2;
                    WRITE16(state, state->ea_addr, state->DA[reg]);
                    cycles += 4;
                } else {
                    state->ea_addr -= 4;
                    WRITE32(state, state->ea_addr, state->DA[reg]);
                    cycles += 8;
                }
            }
        }
        state->A[EA_REG(opcode)] = state->ea_addr;
    } else {
        int reg;
        for (reg = 0; reg < 16; reg++, regmask >>= 1) {
            if (regmask & 1) {
                if (size == SIZE_W) {
                    WRITE16(state, state->ea_addr, state->DA[reg]);
                    state->ea_addr += 2;
                    cycles += 4;
                } else {
                    WRITE32(state, state->ea_addr, state->DA[reg]);
                    state->ea_addr += 4;
                    cycles += 8;
                }
            }
        }
    }

    return 4 + cycles;
}

/*-----------------------------------------------------------------------*/

/**
 * op_LDM:  MOVEM <ea>,reglist (i.e. LoaD Multiple) instruction (format
 * 0100 1100 1sxx xxxx).
 */
static int op_LDM(Q68State *state, uint32_t opcode)
{
    unsigned int regmask = IFETCH(state);
    int size = (opcode & 0x0040) ? SIZE_L : SIZE_W;
    if (EA_MODE(opcode) <= EA_ADDRESS_REG
     || EA_MODE(opcode) == EA_PREDECREMENT  // Not allowed for load
    ) {
        return op_ill(state, opcode);
    }

    /* Avoid modifying the register during address resolution */
    uint16_t safe_ea;
    if (EA_MODE(opcode) == EA_POSTINCREMENT) {
        safe_ea = EA_INDIRECT<<3 | EA_REG(opcode);
    } else {
        safe_ea = opcode;
    }
    int cycles = ea_resolve(state, safe_ea, SIZE_W, ACCESS_READ);
    if (cycles < 0) {
        return op_ill(state, opcode);
    }
#ifndef Q68_DISABLE_ADDRESS_ERROR
    if (state->ea_addr & 1) {
        state->exception = EX_ADDRESS_ERROR;
        state->fault_addr = state->ea_addr;
        state->fault_status = FAULT_STATUS_IN_DATA
                            | FAULT_STATUS_RW_READ;
        return 0;
    }
#endif

    int reg;
    for (reg = 0; reg < 16; reg++, regmask >>= 1) {
        if (regmask & 1) {
            if (size == SIZE_W) {
                int16_t value = READS16(state, state->ea_addr);
                if (reg < 8) {
                    *(WORD_OFS + (uint16_t *)&state->D[reg]) = value;
                } else {
                    state->A[reg-8] = (int32_t)value;
                }
                state->ea_addr += 2;
                cycles += 4;
            } else {
                state->DA[reg] = READU32(state, state->ea_addr);
                state->ea_addr += 4;
                cycles += 8;
            }
        }
    }
    if (EA_MODE(opcode) == EA_POSTINCREMENT) {
        state->A[EA_REG(opcode)] = state->ea_addr;
    }

    return 8 + cycles;
}

/*************************************************************************/

/**
 * opmisc:  $4xxx-group misc. instructions (format 0100 1110 01xx xxxx).
 */
static int opmisc(Q68State *state, uint32_t opcode)
{
    const unsigned int index = (opcode>>3 & 7);
    return (*opcode_4E4x_table[index])(state, opcode);
}

/*-----------------------------------------------------------------------*/

/**
 * opTRAP:  TRAP #n instruction (format 0100 1110 0100 nnnn).
 */
static int opTRAP(Q68State *state, uint32_t opcode)
{
    state->exception = EX_TRAP + (opcode & 0x000F);
    return 0;
}

/*-----------------------------------------------------------------------*/

/**
 * opLINK:  LINK instruction (format 0100 1110 0101 0rrr).
 */
static int opLINK(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG0;
    int16_t disp = IFETCH(state);
#ifndef Q68_DISABLE_ADDRESS_ERROR
    if (state->A[7] & 1) {
        state->exception = EX_ADDRESS_ERROR;
        state->fault_addr = state->A[7];
        state->fault_status = FAULT_STATUS_IN_DATA
                            | FAULT_STATUS_RW_WRITE;
        return 0;
    }
#endif
    PUSH32(state, state->A[reg0]);
    state->A[reg0] = state->A[7];
    state->A[7] += disp;
    return 16;
}

/*-----------------------------------------------------------------------*/

/**
 * opUNLK:  UNLK instruction (format 0100 1110 0101 1rrr).
 */
static int opUNLK(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG0;
    /* FIXME: What happens if A7 is used as the register?  I.e. does the
     *        postincrement happen before or after the value is written to
     *        the destination register?  The Motorola docs could be read
     *        both ways, so going by the literal operation sequence here. */
    state->A[7] = state->A[reg0];
#ifndef Q68_DISABLE_ADDRESS_ERROR
    if (state->A[7] & 1) {
        state->exception = EX_ADDRESS_ERROR;
        state->fault_addr = state->A[7];
        state->fault_status = FAULT_STATUS_IN_DATA
                            | FAULT_STATUS_RW_READ;
        return 0;
    }
#endif
    state->A[reg0] = READU32(state, state->A[7]);
    state->A[7] += 4;
    return 12;
}

/*-----------------------------------------------------------------------*/

/**
 * opMUSP:  MOVE An,USP and MOVE USP,An instructions (format
 * 0100 1110 0110 xrrr).
 */
static int opMUSP(Q68State *state, uint32_t opcode)
{
    if (!(state->SR & SR_S)) {
        state->exception = EX_PRIVILEGE_VIOLATION;
        return 0;
    }

    INSN_GET_REG0;
    if (opcode & 0x0008) {
        state->USP = state->A[reg0];
    } else {
        state->A[reg0] = state->USP;
    }
    return 4;
}

/*-----------------------------------------------------------------------*/

/**
 * op4E7x:  Instructions with opcodes $4E70-$4E77 that don't fit anywhere
 * else.
 */
static int op4E7x(Q68State *state, uint32_t opcode)
{
    switch (opcode & 7) {
      case 0:  // $4E70 RESET
        if (!(state->SR & SR_S)) {
            state->exception = EX_PRIVILEGE_VIOLATION;
            return 0;
        }
        return 132;
      case 1:  // $4E71 NOP
        return 4;
      case 2:  // $4E72 STOP
        if (!(state->SR & SR_S)) {
            state->exception = EX_PRIVILEGE_VIOLATION;
            return 0;
        }
        state->halted = 1;
        set_SR(state, IFETCH(state));
        return 4;
      case 3: {  // $4E73 RTE
        if (!(state->SR & SR_S)) {
            state->exception = EX_PRIVILEGE_VIOLATION;
            return 0;
        }
#ifndef Q68_DISABLE_ADDRESS_ERROR
        if (state->A[7] & 1) {
            state->exception = EX_ADDRESS_ERROR;
            state->fault_addr = state->A[7];
            state->fault_status = FAULT_STATUS_IN_DATA
                                | FAULT_STATUS_RW_READ;
            return 0;
        }
#endif
        uint16_t new_SR = POP16(state);
        state->PC = POP32(state);
        set_SR(state, new_SR);
        return 20;
      }
      case 5:  // $4E75 RTS
#ifndef Q68_DISABLE_ADDRESS_ERROR
        if (state->A[7] & 1) {
            state->exception = EX_ADDRESS_ERROR;
            state->fault_addr = state->A[7];
            state->fault_status = FAULT_STATUS_IN_DATA
                                | FAULT_STATUS_RW_READ;
            return 0;
        }
#endif
        state->PC = POP32(state);
        return 16;
      case 6:  // $4E76 TRAPV
        if (state->SR & SR_V) {
            state->exception = EX_TRAPV;
            return 0;
        }
        return 4;
      case 7: {  // $4E77 RTR
#ifndef Q68_DISABLE_ADDRESS_ERROR
        if (state->A[7] & 1) {
            state->exception = EX_ADDRESS_ERROR;
            state->fault_addr = state->A[7];
            state->fault_status = FAULT_STATUS_IN_DATA
                                | FAULT_STATUS_RW_READ;
            return 0;
        }
#endif
        state->SR &= 0xFF00;
        state->SR |= POP16(state) & 0x00FF;
        state->PC = POP32(state);
        return 20;
      }
      default: // $4E74 RTD is 68010 only
        return op_ill(state, opcode);
    }
}

/*************************************************************************/

/**
 * opjump:  JSR and JMP instructions (format 0100 1110 1xxx xxxx).
 */
static int opjump(Q68State *state, uint32_t opcode)
{
    int is_jsr = ~opcode & 0x0040;

    /* JMP is essentially identical to LEA PC,<ea> and has the same
     * constraints.  JSR is equivalent to MOVE.L PC,-(A7) followed by a
     * JMP to the address.  Both use a separate timing table, however. */

    int cycles;
    switch (EA_MODE(opcode)) {
      case EA_INDIRECT:
        cycles = 8;
        break;
      case EA_DISPLACEMENT:
        cycles = 10;
        break;
      case EA_INDEX:
        cycles = 14;
        break;
      case EA_MISC:
        switch (EA_REG(opcode)) {
          case EA_MISC_ABSOLUTE_W:
            cycles = 10;
            break;
          case EA_MISC_ABSOLUTE_L:
            cycles = 12;
            break;
          case EA_MISC_PCREL:
            cycles = 10;
            break;
          case EA_MISC_PCREL_INDEX:
            cycles = 14;
            break;
          default:
            return op_ill(state, opcode);
        }
        break;
      default:
        return op_ill(state, opcode);
    }

    ea_resolve(state, opcode, SIZE_W, ACCESS_READ);  // cannot fail
    if (is_jsr) {
#ifndef Q68_DISABLE_ADDRESS_ERROR
        if (state->A[7] & 1) {
            state->exception = EX_ADDRESS_ERROR;
            state->fault_addr = state->A[7];
            state->fault_status = FAULT_STATUS_IN_DATA
                                | FAULT_STATUS_RW_WRITE;
            return 0;
        }
#endif
        cycles += 8;
        PUSH32(state, state->PC);
    }
    state->PC = state->ea_addr;
    return cycles;
}

/*************************************************************************/
/******************* Other miscellaneous instructions ********************/
/*************************************************************************/

/**
 * opMOVP:  MOVEP instruction (0000 rrr1 xx00 1rrr).
 */
static int opMOVP(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    INSN_GET_REG0;
    int to_memory = opcode & 0x0080;
    int is_long   = opcode & 0x0040;
    int16_t disp  = IFETCH(state);
    uint32_t addr = state->A[reg0] + disp;

    if (to_memory) {
        uint32_t data = state->D[reg];
        if (is_long) {
            WRITE8(state, addr+0, data>>24);
            WRITE8(state, addr+2, data>>16);
            WRITE8(state, addr+4, data>> 8);
            WRITE8(state, addr+6, data>> 0);
        } else {
            WRITE8(state, addr+0, data>> 8);
            WRITE8(state, addr+2, data>> 0);
        }
    } else {
        uint32_t data;
        if (is_long) {
            data  = READU8(state, addr+0) << 24;
            data |= READU8(state, addr+2) << 16;
            data |= READU8(state, addr+4) <<  8;
            data |= READU8(state, addr+6) <<  0;
        } else {
            data  = READU8(state, addr+0) <<  8;
            data |= READU8(state, addr+2) <<  0;
        }
        state->D[reg] = data;
    }

    return is_long ? 24 : 16;
}

/*************************************************************************/

/**
 * opADSX:  ADDX/SUBX instructions (1x01 rrr1 ss00 xrrr).
 */
static int opADSX(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    INSN_GET_SIZE;
    INSN_GET_REG0;
    const int is_add = opcode & 0x4000;
    const int is_memory = opcode & 0x0008;
    const int bytes = SIZE_TO_BYTES(size);
    const int shift = bytes*8 - 1;
    const uint32_t valuemask = ~(~1 << shift);

    const uint16_t src_ea =
        (is_memory ? EA_PREDECREMENT : EA_DATA_REG) << 3 | reg0;
    const uint16_t dest_ea =
        (is_memory ? EA_PREDECREMENT : EA_DATA_REG) << 3 | reg;
    int dummy;
    uint32_t src  = ea_get(state, src_ea,  size, 0, &dummy);
    uint32_t dest = ea_get(state, dest_ea, size, 1, &dummy);

    uint32_t result;
    int X = (state->SR >> SR_X_SHIFT) & 1;
    state->SR &= ~(SR_X | SR_N | SR_V | SR_C);  // Z is never set, only cleared
    if (is_add) {
        result = (dest + src + X) & valuemask;
        if (((src ^ result) & (dest ^ result)) >> shift) {
            state->SR |= SR_V;
        }
        if ((int)((src >> shift) + (dest >> shift) - (result >> shift)) > 0) {
            state->SR |= SR_X | SR_C;
        }
    } else {
        result = (dest - src - X) & valuemask;
        if (((src ^ dest) & (result ^ dest)) >> shift) {
            state->SR |= SR_V;
        }
        if ((int)((src >> shift) - (dest >> shift) + (result >> shift)) > 0) {
            state->SR |= SR_X | SR_C;
        }
    }
    if (result >> shift) {
        state->SR |= SR_N;
    }
    if (result != 0) {
        state->SR &= ~SR_Z;
    }

    ea_set(state, dest_ea, size, result);
    return (is_memory ? (size==SIZE_L ? 30 : 18) : (size==SIZE_L ? 8 : 4));
}

/*-----------------------------------------------------------------------*/

/**
 * op_BCD:  ABCD/SBCD instructions (1x00 rrr1 0000 xrrr).
 */
static int op_BCD(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    INSN_GET_REG0;
    const int is_add = opcode & 0x4000;
    const int is_memory = opcode & 0x0008;

    const uint16_t src_ea =
        (is_memory ? EA_PREDECREMENT : EA_DATA_REG) << 3 | reg0;
    const uint16_t dest_ea =
        (is_memory ? EA_PREDECREMENT : EA_DATA_REG) << 3 | reg;
    int dummy;
    uint8_t src  = ea_get(state, src_ea,  SIZE_B, 0, &dummy);
    uint8_t dest = ea_get(state, dest_ea, SIZE_B, 1, &dummy);

    int result;
    int X = (state->SR >> SR_X_SHIFT) & 1;
    state->SR &= ~(SR_X | SR_C);  // Z is never set, only cleared
    if (is_add) {
        result = (dest & 0x0F) + (src & 0x0F) + X;
        if (result >= 10) {
            /* This seems to be correct w.r.t. a real 68000 and invalid data
             * (e.g. 0x0F + 0x0F): it only checks for a carry of 1 */
            result += 6;
        }
        result += (dest & 0xF0) + (src & 0xF0);
        if (result >= 10<<4) {
            result -= 10<<4;
            state->SR |= SR_X | SR_C;
        }
    } else {
        /* Slightly convoluted to match what a real 68000 does */
        int res_low = (dest & 0x0F) - (src & 0x0F) - X;
        int borrow = 0;
        if (res_low < 0) {
            res_low += 10;
            borrow = 1<<4;
        }
        int res_high = (dest & 0xF0) - (src & 0xF0) - borrow;
        if (res_high < 0) {
            res_high += 10<<4;
            state->SR |= SR_X | SR_C;
        }
        result = res_high + res_low;
        if (result < 0) {
            state->SR |= SR_X | SR_C;
        }
    }
    result &= 0xFF;
    if (result != 0) {
        state->SR &= ~SR_Z;
    }

    ea_set(state, dest_ea, SIZE_B, result);
    return is_memory ? 18 : 6;
}

/*-----------------------------------------------------------------------*/

/**
 * opCMPM:  CMPM instructions (1011 rrr1 ss00 1rrr).
 */
static int opCMPM(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    INSN_GET_SIZE;
    INSN_GET_REG0;
    const int bytes = SIZE_TO_BYTES(size);
    const int shift = bytes*8 - 1;
    const uint32_t valuemask = ~(~1 << shift);

    const uint16_t src_ea  = EA_POSTINCREMENT<<3 | reg0;
    const uint16_t dest_ea = EA_POSTINCREMENT<<3 | reg;
    int dummy;
    uint32_t src  = ea_get(state, src_ea,  size, 0, &dummy);
    uint32_t dest = ea_get(state, dest_ea, size, 0, &dummy);

    uint32_t result = (dest - src) & valuemask;
    INSN_CLEAR_XCC();
    INSN_SETNZ_SHIFT(result);
    if (((src ^ dest) & (result ^ dest)) >> shift) {
        state->SR |= SR_V;
    }
    if ((int)((src >> shift) - (dest >> shift) + (result >> shift)) > 0) {
        state->SR |= SR_C;
    }

    return size==SIZE_L ? 20 : 12;
}

/*************************************************************************/

/**
 * op_EXG:  EXG instruction (1100 rrr1 xx00 1rrr).
 */
static int op_EXG(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    INSN_GET_REG0;
    const int mode = opcode & 0xF8;

    if (mode == 0x40) {
        const uint32_t tmp = state->D[reg];
        state->D[reg] = state->D[reg0];
        state->D[reg0] = tmp;
    } else if (mode == 0x48) {
        const uint32_t tmp = state->A[reg];
        state->A[reg] = state->A[reg0];
        state->A[reg0] = tmp;
    } else if (mode == 0x88) {
        const uint32_t tmp = state->D[reg];
        state->D[reg] = state->A[reg0];
        state->A[reg0] = tmp;
    } else {
        return op_ill(state, opcode);
    }
    return 6;
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
