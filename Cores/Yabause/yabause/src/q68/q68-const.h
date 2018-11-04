/*  src/q68/q68-const.h: Constants used in MC68000 emulation
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

#ifndef Q68_CONST_H
#define Q68_CONST_H

/*************************************************************************/

/* Configuration constants */

/* Maximum size in bytes of a 68k code block for translation */
#ifndef Q68_JIT_MAX_BLOCK_SIZE
# define Q68_JIT_MAX_BLOCK_SIZE 4096
#endif

/* Size of pages used in checking for writes to already-translated code
 * (1 page = 1<<Q68_JIT_PAGE_BITS bytes) */
#ifndef Q68_JIT_PAGE_BITS
# define Q68_JIT_PAGE_BITS 8
#endif

/* Number of entries in JIT call stack */
#ifndef Q68_JIT_CALLSTACK_SIZE
# define Q68_JIT_CALLSTACK_SIZE 8
#endif

/* Maximum number of translated code segments (should be prime) */
#ifndef Q68_JIT_TABLE_SIZE
# define Q68_JIT_TABLE_SIZE 1009
#endif

/* Maximum total size of translated instructions, in bytes */
#ifndef Q68_JIT_DATA_LIMIT
# define Q68_JIT_DATA_LIMIT 2000000
#endif

/* Block size by which to expand native code buffer when translating */
#ifndef Q68_JIT_BLOCK_EXPAND_SIZE
# define Q68_JIT_BLOCK_EXPAND_SIZE 1024
#endif

/* Size of branch target cache, in instructions */
#ifndef Q68_JIT_BTCACHE_SIZE
# define Q68_JIT_BTCACHE_SIZE 128
#endif

/* Size of unresolved branch list */
#ifndef Q68_JIT_UNRES_BRANCH_SIZE
# define Q68_JIT_UNRES_BRANCH_SIZE 10
#endif

/* Number of entries in self-modifying code blacklist */
#ifndef Q68_JIT_BLACKLIST_SIZE
# define Q68_JIT_BLACKLIST_SIZE 5
#endif

/* Expiration timeout for blacklist entries (unit: q68_jit_run() calls) */
#ifndef Q68_JIT_BLACKLIST_TIMEOUT
# define Q68_JIT_BLACKLIST_TIMEOUT 100000
#endif

/*************************************************************************/

/* Status register bits */

#define SR_T    (1<<15) // Trace
#define SR_S    (1<<13) // Supervisor mode
#define SR_I2   (1<<10) // Interrupt mask level (bit 2)
#define SR_I1   (1<< 9) // Interrupt mask level (bit 2)
#define SR_I0   (1<< 8) // Interrupt mask level (bit 2)
#define SR_X    (1<< 4) // Extend
#define SR_N    (1<< 3) // Negative
#define SR_Z    (1<< 2) // Zero
#define SR_V    (1<< 1) // Overflow
#define SR_C    (1<< 0) // Carry

#define SR_T_SHIFT  15
#define SR_S_SHIFT  13
#define SR_I2_SHIFT 10
#define SR_I1_SHIFT  9
#define SR_I0_SHIFT  8
#define SR_X_SHIFT   4
#define SR_N_SHIFT   3
#define SR_Z_SHIFT   2
#define SR_V_SHIFT   1
#define SR_C_SHIFT   0

/* Macros to get and set the interrupt level bits */
#define SR_GET_I(state)     (((state)->SR >> SR_I0_SHIFT) & 7)
#define SR_SET_I(state,val)  ((state)->SR &= ~(7 << SR_I0_SHIFT), \
                              (state)->SR |= ((val) & 7) << SR_I0_SHIFT)

/*-----------------------------------------------------------------------*/

/* Exception numbers */

#define EX_INITIAL_SP            0
#define EX_INITIAL_PC            1
#define EX_BUS_ERROR             2
#define EX_ADDRESS_ERROR         3
#define EX_ILLEGAL_INSTRUCTION   4
#define EX_DIVIDE_BY_ZERO        5
#define EX_CHK                   6
#define EX_TRAPV                 7
#define EX_PRIVILEGE_VIOLATION   8
#define EX_TRACE                 9
#define EX_LINE_1010            10
#define EX_LINE_1111            11

#define EX_SPURIOUS_INTERRUPT   24
#define EX_LEVEL_1_INTERRUPT    25
#define EX_LEVEL_2_INTERRUPT    26
#define EX_LEVEL_3_INTERRUPT    27
#define EX_LEVEL_4_INTERRUPT    28
#define EX_LEVEL_5_INTERRUPT    29
#define EX_LEVEL_6_INTERRUPT    30
#define EX_LEVEL_7_INTERRUPT    31
#define EX_TRAP                 32  // 16 vectors (EX_TRAP+0 .. EX_TRAP+15)

/*-----------------------------------------------------------------------*/

/* Bits in the fault status word for bus/address error exceptions */

#define FAULT_STATUS_IN (1<<3)  // Instruction/Not (0 = instruction, 1 = not)
#define FAULT_STATUS_IN_INSN  (0)
#define FAULT_STATUS_IN_DATA  (FAULT_STATUS_IN)

#define FAULT_STATUS_RW (1<<4)  // Read/Write (0 = write, 1 = read)
#define FAULT_STATUS_RW_READ  (FAULT_STATUS_RW)
#define FAULT_STATUS_RW_WRITE (0)

/*-----------------------------------------------------------------------*/

/* Condition codes for conditional instructions */

#define COND_T    0
#define COND_F    1
#define COND_HI   2
#define COND_LS   3
#define COND_CC   4  // also HS
#define COND_CS   5  // also LO
#define COND_NE   6
#define COND_EQ   7
#define COND_VC   8
#define COND_VS   9
#define COND_PL  10
#define COND_MI  11
#define COND_GE  12
#define COND_LT  13
#define COND_GT  14
#define COND_LE  15

/*-----------------------------------------------------------------------*/

/* Size codes in opcode bits 6-7 */

#define SIZE_B  0
#define SIZE_W  1
#define SIZE_L  2

/* Macro to convert size codes to equivalent byte counts */
#define SIZE_TO_BYTES(size)  ((size) + 1 + ((size) == SIZE_L))

/*-----------------------------------------------------------------------*/

/* Effective address modes */

#define EA_DATA_REG       0  // Data Register Direct
#define EA_ADDRESS_REG    1  // Address Register Direct
#define EA_INDIRECT       2  // Address Register Indirect
#define EA_POSTINCREMENT  3  // Address Register Indirect with Postincrement
#define EA_PREDECREMENT   4  // Address Register Indirect with Predecrement
#define EA_DISPLACEMENT   5  // Address Register Indirect with Displacement
#define EA_INDEX          6  // Address Register Indirect with Index
#define EA_MISC           7

#define EA_MISC_ABSOLUTE_W   0  // Absolute Short
#define EA_MISC_ABSOLUTE_L   1  // Absolute Long
#define EA_MISC_PCREL        2  // Program Counter Indirect with Displacement
#define EA_MISC_PCREL_INDEX  3  // Program Counter Indirect with Index
#define EA_MISC_IMMEDIATE    4  // Immediate

/* Macros to retrieve the mode and register number from an opcode */
#define EA_MODE(opcode) ((opcode)>>3 & 7)
#define EA_REG(opcode)  ((opcode)>>0 & 7)
    
/*************************************************************************/
/*************************************************************************/

#endif  // Q68_CONST_H

/*
 * Local variables:
 *   c-file-style: "stroustrup"
 *   c-file-offsets: ((case-label . *) (statement-case-intro . *))
 *   indent-tabs-mode: nil
 * End:
 *
 * vim: expandtab shiftwidth=4:
 */
