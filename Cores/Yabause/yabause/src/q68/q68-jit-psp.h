/*  src/q68/q68-jit-psp.h: PSP dynamic translation header for Q68
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

#ifndef Q68_JIT_PSP_H
#define Q68_JIT_PSP_H

#include <pspuser.h>

/*************************************************************************/

/**
 * JIT_CALL:  Run translated code from the given (native) address for the
 * given number of cycles.
 *
 * [Parameters]
 *           state: Processor state block
 *          cycles: Number of clock cycles to execute
 *     address_ptr: Pointer to address of native code to execute; must be
 *                     updated on return with the next address to execute
 *                     or NULL if the end of the block was reached
 * [Return value]
 *     Number of clock cycles actually executed
 */
static inline int JIT_CALL(Q68State *state, int cycles, void **address_ptr)
{
    register Q68State *__state asm("s0") = state;
    register int      __cycles asm("s1") = cycles;
    register int  __cycles_out asm("s2");
    register void *  __address asm("v0") = *address_ptr;
    asm(".set push; .set noreorder\n"
        "jalr %[address]\n"
        "move $s2, $zero\n"
        ".set pop"
        : "=r" (__cycles), [address] "=r" (__address), "=r" (__cycles_out)
        : "r" (__state), "0" (__cycles), "1" (__address)
        : "at", "v1", "a0", "a1", "a2", "a3", "t0", "t1", "t2", "t3", "t4",
          "t5", "t6", "t7", "t8", "t9", "s3", "s4", "s5", "s6", "s7", "ra",
          "memory"
    );
    *address_ptr = __address;
    return __cycles_out;
}

/*************************************************************************/

/**
 * JIT_FIXUP_BRANCH:  Modify a branch instruction at the given offset to
 * jump to the given target.
 *
 * [Parameters]
 *      entry: Block being translated
 *     offset: Offset within entry->native_code of branch instruction
 *                (as returned in *branch_offset EMIT parameter)
 *     target: Target offset within entry->native_code
 * [Return value]
 *     None
 */
static inline void JIT_FIXUP_BRANCH(Q68JitEntry *entry, uint32_t offset,
                                    uint32_t target)
{
    int32_t disp_4 = (target - (offset + 4)) / 4;
    if (disp_4 >= -32768 && disp_4 <= 32767) {
        *(int16_t *)((uint8_t *)entry->native_code + offset) = disp_4;
    }
}

/*************************************************************************/
/*************************************************************************/

/*
 * The remaining macros are all used to insert a specific operation into
 * the native code stream.  For simplicity, we define the actual code for
 * each operation in a separate assembly file, and use memcpy() to copy
 * from the assembled code to the output code stream.  The GEN_EMIT macro
 * below is used to generate each of the JIT_EMIT_* functions; each
 * function JIT_EMIT_xxx copies JIT_PSPSIZE_xxx bytes from JIT_PSP_xxx to
 * the code stream, expanding the code buffer if necessary.
 */

/* Sub-macros: */
#define GEN_NAMESIZE(name) \
    extern const uint8_t JIT_PSP_##name[]; \
    extern const uint32_t JIT_PSPSIZE_##name;
#define GEN_PARAM(name,param) \
    extern const uint32_t JIT_PSPPARAM_##name##_##param;
#define GEN_FUNC_TOP(name) \
        if (UNLIKELY(entry->native_size - entry->native_length  \
                         < JIT_PSPSIZE_##name)) {               \
            if (!expand_buffer(entry)) {                        \
                return;                                         \
            }                                                   \
        }                                                       \
        if (JIT_PSPSIZE_##name > 0) {                           \
            memcpy((uint8_t *)entry->native_code + entry->native_length, \
                   JIT_PSP_##name, JIT_PSPSIZE_##name);         \
        }
#define GEN_COPY_PARAM(name,type,param) \
        *(type *)((uint8_t *)entry->native_code + entry->native_length \
                  + JIT_PSPPARAM_##name##_##param) = param;
#define GEN_FUNC_BOTTOM(name) \
        entry->native_length += JIT_PSPSIZE_##name;


#define GEN_EMIT(name) \
    GEN_NAMESIZE(name)                                          \
    static void JIT_EMIT_##name(Q68JitEntry *entry) {           \
        GEN_FUNC_TOP(name)                                      \
        GEN_FUNC_BOTTOM(name)                                   \
    }

#define GEN_EMIT_1(name,type1,param1) \
    GEN_NAMESIZE(name)                                          \
    GEN_PARAM(name,param1)                                      \
    static void JIT_EMIT_##name(Q68JitEntry *entry, type1 param1) { \
        GEN_FUNC_TOP(name)                                      \
        GEN_COPY_PARAM(name, type1, param1)                     \
        GEN_FUNC_BOTTOM(name)                                   \
    }

#define GEN_EMIT_2(name,type1,param1,type2,param2) \
    GEN_NAMESIZE(name)                                          \
    GEN_PARAM(name,param1)                                      \
    GEN_PARAM(name,param2)                                      \
    static void JIT_EMIT_##name(Q68JitEntry *entry, type1 param1, \
                                type2 param2) {                 \
        GEN_FUNC_TOP(name)                                      \
        GEN_COPY_PARAM(name, type1, param1)                     \
        GEN_COPY_PARAM(name, type2, param2)                     \
        GEN_FUNC_BOTTOM(name)                                   \
    }

#define GEN_EMIT_3(name,type1,param1,type2,param2,type3,param3) \
    GEN_NAMESIZE(name)                                          \
    GEN_PARAM(name,param1)                                      \
    GEN_PARAM(name,param2)                                      \
    GEN_PARAM(name,param3)                                      \
    static void JIT_EMIT_##name(Q68JitEntry *entry, type1 param1, \
                                type2 param2, type3 param3) {   \
        GEN_FUNC_TOP(name)                                      \
        GEN_COPY_PARAM(name, type1, param1)                     \
        GEN_COPY_PARAM(name, type2, param2)                     \
        GEN_COPY_PARAM(name, type3, param3)                     \
        GEN_FUNC_BOTTOM(name)                                   \
    }

#define GEN_EMIT_4(name,type1,param1,type2,param2,type3,param3,type4,param4) \
    GEN_NAMESIZE(name)                                          \
    GEN_PARAM(name,param1)                                      \
    GEN_PARAM(name,param2)                                      \
    GEN_PARAM(name,param3)                                      \
    GEN_PARAM(name,param4)                                      \
    static void JIT_EMIT_##name(Q68JitEntry *entry, type1 param1, \
                                type2 param2, type3 param3, type4 param4) { \
        GEN_FUNC_TOP(name)                                      \
        GEN_COPY_PARAM(name, type1, param1)                     \
        GEN_COPY_PARAM(name, type2, param2)                     \
        GEN_COPY_PARAM(name, type3, param3)                     \
        GEN_COPY_PARAM(name, type4, param4)                     \
        GEN_FUNC_BOTTOM(name)                                   \
    }

#define GEN_EMIT_5(name,type1,param1,type2,param2,type3,param3,type4,param4,type5,param5) \
    GEN_NAMESIZE(name)                                          \
    GEN_PARAM(name,param1)                                      \
    GEN_PARAM(name,param2)                                      \
    GEN_PARAM(name,param3)                                      \
    GEN_PARAM(name,param4)                                      \
    GEN_PARAM(name,param5)                                      \
    static void JIT_EMIT_##name(Q68JitEntry *entry, type1 param1, \
                                type2 param2, type3 param3,     \
                                type4 param4, type5 param5) {   \
        GEN_FUNC_TOP(name)                                      \
        GEN_COPY_PARAM(name, type1, param1)                     \
        GEN_COPY_PARAM(name, type2, param2)                     \
        GEN_COPY_PARAM(name, type3, param3)                     \
        GEN_COPY_PARAM(name, type4, param4)                     \
        GEN_COPY_PARAM(name, type5, param5)                     \
        GEN_FUNC_BOTTOM(name)                                   \
    }


/* These versions include a hidden "disp_4" parameter, and pass the value of
 * disp_4_formula for that parameter. */

#define GEN_EMIT_disp(name,disp_4_formula) \
    GEN_NAMESIZE(name)                                          \
    GEN_PARAM(name,disp_4)                                      \
    static void __real_JIT_EMIT_##name(Q68JitEntry *entry, int16_t disp_4) { \
        GEN_FUNC_TOP(name)                                      \
        GEN_COPY_PARAM(name, int16_t, disp_4)                   \
        GEN_FUNC_BOTTOM(name)                                   \
    }                                                           \
    static void JIT_EMIT_##name(Q68JitEntry *entry) {           \
        __real_JIT_EMIT_##name(entry, (disp_4_formula));        \
    }

#define GEN_EMIT_1_disp(name,type1,param1,disp_4_formula) \
    GEN_NAMESIZE(name)                                          \
    GEN_PARAM(name,param1)                                      \
    GEN_PARAM(name,disp_4)                                      \
    static void __real_JIT_EMIT_##name(Q68JitEntry *entry, type1 param1, \
                                       int16_t disp_4) {        \
        GEN_FUNC_TOP(name)                                      \
        GEN_COPY_PARAM(name, type1, param1)                     \
        GEN_COPY_PARAM(name, int16_t, disp_4)                   \
        GEN_FUNC_BOTTOM(name)                                   \
    }                                                           \
    static void JIT_EMIT_##name(Q68JitEntry *entry, type1 param1) { \
        __real_JIT_EMIT_##name(entry, param1, (disp_4_formula)); \
    }

#define GEN_EMIT_2_disp(name,type1,param1,type2,param2,disp_4_formula) \
    GEN_NAMESIZE(name)                                          \
    GEN_PARAM(name,param1)                                      \
    GEN_PARAM(name,param2)                                      \
    GEN_PARAM(name,disp_4)                                      \
    static void __real_JIT_EMIT_##name(Q68JitEntry *entry, type1 param1, \
                                       type2 param2, int16_t disp_4) { \
        GEN_FUNC_TOP(name)                                      \
        GEN_COPY_PARAM(name, type1, param1)                     \
        GEN_COPY_PARAM(name, type2, param2)                     \
        GEN_COPY_PARAM(name, int16_t, disp_4)                   \
        GEN_FUNC_BOTTOM(name)                                   \
    }                                                           \
    static void JIT_EMIT_##name(Q68JitEntry *entry, type1 param1, \
                                type2 param2) {                 \
        __real_JIT_EMIT_##name(entry, param1, param2, (disp_4_formula)); \
    }

/*-----------------------------------------------------------------------*/

/* Code prologue and epilogue */
GEN_EMIT(PROLOGUE)
extern const int JIT_PSPOFS_TERMINATE;
extern const int JIT_PSPOFS_EXCEPTION;
extern const int JIT_PSPOFS_ADDRESS_ERROR_EA;
extern const int JIT_PSPOFS_ADDRESS_ERROR_SP;
GEN_EMIT(EPILOGUE)

#ifdef Q68_TRACE
/* Trace the current instruction */
GEN_EMIT(TRACE)
#endif

/* Add the specified number of cycles to the cycle counter */
GEN_EMIT_1(ADD_CYCLES, int16_t, cycles)

/* Check the cycle limit and interrupt execution if necessary */
GEN_EMIT(CHECK_CYCLES)

/* Add the specified amount to the program counter and/or check whether
 * to abort */
GEN_EMIT_1(ADVANCE_PC, int16_t, value)
GEN_EMIT_1_disp(ADVANCE_PC_CHECK_ABORT, int16_t, value,
                (JIT_PSPOFS_TERMINATE - (entry->native_length + 4)) / 4)
GEN_EMIT_disp(CHECK_ABORT,
              (JIT_PSPOFS_TERMINATE - (entry->native_length + 4)) / 4)

/* Exception raising */
GEN_EMIT_1_disp(EXCEPTION, int16_t, num,
                (JIT_PSPOFS_EXCEPTION - (entry->native_length + 4)) / 4)
GEN_EMIT_2_disp(CHECK_ALIGNED_EA, uint16_t, opcode, uint16_t, status,
                (JIT_PSPOFS_ADDRESS_ERROR_EA - (entry->native_length + 4)) / 4)
GEN_EMIT_2_disp(CHECK_ALIGNED_SP, uint16_t, opcode, uint16_t, status,
                (JIT_PSPOFS_ADDRESS_ERROR_SP - entry->native_length) / 4)
GEN_EMIT_disp(CHECK_SUPER,
              (JIT_PSPOFS_EXCEPTION - (entry->native_length + 4)) / 4)

/*-----------------------------------------------------------------------*/

/* Resolve an effective address */
GEN_EMIT_1(RESOLVE_INDIRECT, int16_t, reg4)
GEN_EMIT_3(RESOLVE_POSTINC, int16_t, reg4, int16_t, size, int16_t, reg4_b)
#define JIT_EMIT_RESOLVE_POSTINC(entry,reg4,size)  do { \
    int16_t __reg4 = (reg4); \
    JIT_EMIT_RESOLVE_POSTINC((entry), __reg4, (size), __reg4); \
} while (0)
GEN_EMIT(RESOLVE_POSTINC_A7_B)
GEN_EMIT_3(RESOLVE_PREDEC, int16_t, reg4, int16_t, nsize, int16_t, reg4_b)
#define JIT_EMIT_RESOLVE_PREDEC(entry,reg4,size)  do { \
    int16_t __reg4 = (reg4); \
    JIT_EMIT_RESOLVE_PREDEC((entry), __reg4, -(size), __reg4); \
} while (0)
GEN_EMIT(RESOLVE_PREDEC_A7_B)
GEN_EMIT_2(RESOLVE_DISP, int16_t, reg4, int16_t, disp)
GEN_EMIT_3(RESOLVE_INDEX_W, int16_t, reg4, int16_t, ireg4, int16_t, disp)
GEN_EMIT_3(RESOLVE_INDEX_L, int16_t, reg4, int16_t, ireg4, int16_t, disp)
GEN_EMIT_2(RESOLVE_ABSOLUTE, uint16_t, addr_hi, uint16_t, addr_lo)
#define JIT_EMIT_RESOLVE_ABSOLUTE(entry,addr)  do { \
    uint32_t __addr = (addr); \
    JIT_EMIT_RESOLVE_ABSOLUTE((entry), __addr>>16, __addr & 0xFFFF); \
} while (0)
GEN_EMIT_3(RESOLVE_ABS_INDEX_W, int16_t, ireg4, uint16_t, addr_hi,
           uint16_t, addr_lo)
#define JIT_EMIT_RESOLVE_ABS_INDEX_W(entry,addr,ireg4)  do { \
    uint32_t __addr = (addr); \
    JIT_EMIT_RESOLVE_ABS_INDEX_W((entry), (ireg4), __addr>>16, \
                                 (addr) & 0xFFFF); \
} while (0)
GEN_EMIT_3(RESOLVE_ABS_INDEX_L, int16_t, ireg4, uint16_t, addr_hi,
           uint16_t, addr_lo)
#define JIT_EMIT_RESOLVE_ABS_INDEX_L(entry,addr,ireg4)  do { \
    uint32_t __addr = (addr); \
    JIT_EMIT_RESOLVE_ABS_INDEX_L((entry), (ireg4), __addr>>16, \
                                 __addr & 0xFFFF); \
} while (0)

/* Retrieve various things as operand 1 */
GEN_EMIT_1(GET_OP1_REGISTER, int16_t, reg4)
GEN_EMIT(GET_OP1_EA_B)
GEN_EMIT(GET_OP1_EA_W)
GEN_EMIT(GET_OP1_EA_L)
GEN_EMIT_1(GET_OP1_IMMED_16S, int16_t, value_lo)
GEN_EMIT_1(GET_OP1_IMMED_16U, uint16_t, value_lo)
GEN_EMIT_1(GET_OP1_IMMED_16HI, uint16_t, value_hi)
GEN_EMIT_2(GET_OP1_IMMED_32, uint16_t, value_hi, uint16_t, value_lo)
#define JIT_EMIT_GET_OP1_IMMEDIATE(entry,value)  do {       \
    Q68JitEntry * const __entry = (entry);                  \
    const int32_t __value = (value);                        \
    if (value >= -32768 && value <= 32767) {                \
        JIT_EMIT_GET_OP1_IMMED_16S(__entry, __value);       \
    } else if (value >= 0 && value <= 65535) {              \
        JIT_EMIT_GET_OP1_IMMED_16U(__entry, __value);       \
    } else if ((value & 0xFFFF) == 0) {                     \
        JIT_EMIT_GET_OP1_IMMED_16HI(__entry, __value>>16);  \
    } else {                                                \
        JIT_EMIT_GET_OP1_IMMED_32(__entry, __value>>16, __value & 0xFFFF); \
    }                                                       \
} while (0)
GEN_EMIT(GET_OP1_CCR)
GEN_EMIT(GET_OP1_SR)

/* Retrieve various things as operand 2 */
GEN_EMIT_1(GET_OP2_REGISTER, int16_t, reg4)
GEN_EMIT(GET_OP2_EA_B)
GEN_EMIT(GET_OP2_EA_W)
GEN_EMIT(GET_OP2_EA_L)
GEN_EMIT_1(GET_OP2_IMMED_16S, int16_t, value_lo)
GEN_EMIT_1(GET_OP2_IMMED_16U, uint16_t, value_lo)
GEN_EMIT_1(GET_OP2_IMMED_16HI, uint16_t, value_hi)
GEN_EMIT_2(GET_OP2_IMMED_32, uint16_t, value_hi, uint16_t, value_lo)
#define JIT_EMIT_GET_OP2_IMMEDIATE(entry,value)  do {       \
    Q68JitEntry * const __entry = (entry);                  \
    const int32_t __value = (value);                        \
    if (value >= -32768 && value <= 32767) {                \
        JIT_EMIT_GET_OP2_IMMED_16S(__entry, __value);       \
    } else if (value >= 0 && value <= 65535) {              \
        JIT_EMIT_GET_OP2_IMMED_16U(__entry, __value);       \
    } else if ((value & 0xFFFF) == 0) {                     \
        JIT_EMIT_GET_OP2_IMMED_16HI(__entry, __value>>16);  \
    } else {                                                \
        JIT_EMIT_GET_OP2_IMMED_32(__entry, __value>>16, __value & 0xFFFF); \
    }                                                       \
} while (0)
GEN_EMIT(GET_OP2_CCR)
GEN_EMIT(GET_OP2_SR)

/* Update various things from result */
GEN_EMIT_1(SET_REGISTER_B, int16_t, reg4)
GEN_EMIT_1(SET_REGISTER_W, int16_t, reg4)
GEN_EMIT_1(SET_REGISTER_L, int16_t, reg4)
GEN_EMIT_1(SET_AREG_W, int16_t, reg4)
GEN_EMIT(SET_EA_B)
GEN_EMIT(SET_EA_W)
GEN_EMIT(SET_EA_L)
GEN_EMIT(SET_CCR)
GEN_EMIT(SET_SR)

/* Stack operations */
GEN_EMIT(PUSH_L)
GEN_EMIT(POP_L)

/* Condition code setting */
GEN_EMIT(SETCC_ADD_B)
GEN_EMIT(SETCC_ADD_W)
GEN_EMIT(SETCC_ADD_L)
GEN_EMIT(SETCC_ADDX_B)
GEN_EMIT(SETCC_ADDX_W)
GEN_EMIT(SETCC_ADDX_L)
GEN_EMIT(SETCC_SUB_B)
GEN_EMIT(SETCC_SUB_W)
GEN_EMIT(SETCC_SUB_L)
GEN_EMIT(SETCC_SUBX_B)
GEN_EMIT(SETCC_SUBX_W)
GEN_EMIT(SETCC_SUBX_L)
GEN_EMIT(SETCC_CMP_B)
GEN_EMIT(SETCC_CMP_W)
GEN_EMIT(SETCC_CMP_L)
GEN_EMIT(SETCC_LOGIC_B)
GEN_EMIT(SETCC_LOGIC_W)
GEN_EMIT(SETCC_LOGIC_L)

/* Condition testing */
GEN_EMIT(TEST_T)
GEN_EMIT(TEST_F)
GEN_EMIT(TEST_HI)
GEN_EMIT(TEST_LS)
GEN_EMIT(TEST_CC)
GEN_EMIT(TEST_CS)
GEN_EMIT(TEST_NE)
GEN_EMIT(TEST_EQ)
GEN_EMIT(TEST_VC)
GEN_EMIT(TEST_VS)
GEN_EMIT(TEST_PL)
GEN_EMIT(TEST_MI)
GEN_EMIT(TEST_GE)
GEN_EMIT(TEST_LT)
GEN_EMIT(TEST_GT)
GEN_EMIT(TEST_LE)

/* ALU operations */
GEN_EMIT(MOVE_B)
GEN_EMIT(MOVE_W)
GEN_EMIT(MOVE_L)
GEN_EMIT(ADD_B)
GEN_EMIT(ADD_W)
GEN_EMIT(ADD_L)
GEN_EMIT(ADDA_W)
GEN_EMIT(ADDX_B)
GEN_EMIT(ADDX_W)
GEN_EMIT(ADDX_L)
GEN_EMIT(SUB_B)
GEN_EMIT(SUB_W)
GEN_EMIT(SUB_L)
GEN_EMIT(SUBA_W)
GEN_EMIT(SUBX_B)
GEN_EMIT(SUBX_W)
GEN_EMIT(SUBX_L)
GEN_EMIT(MULS_W)
GEN_EMIT(MULU_W)
GEN_EMIT(DIVS_W)
GEN_EMIT(DIVU_W)
GEN_EMIT(AND_B)
GEN_EMIT(AND_W)
GEN_EMIT(AND_L)
GEN_EMIT(OR_B)
GEN_EMIT(OR_W)
GEN_EMIT(OR_L)
GEN_EMIT(EOR_B)
GEN_EMIT(EOR_W)
GEN_EMIT(EOR_L)
GEN_EMIT(EXT_W)
GEN_EMIT(EXT_L)
GEN_EMIT(SWAP)

/* BCD operations */
GEN_EMIT(ABCD)
GEN_EMIT(SBCD)

/* Bit-twiddling operations */
GEN_EMIT(BTST_B)
GEN_EMIT(BTST_L)
GEN_EMIT(BCHG)
GEN_EMIT(BCLR)
GEN_EMIT(BSET)

/* Shift/rotate operations */
GEN_EMIT(ASL_B)
GEN_EMIT(ASL_W)
GEN_EMIT(ASL_L)
GEN_EMIT(ASR_B)
GEN_EMIT(ASR_W)
GEN_EMIT(ASR_L)
GEN_EMIT(LSL_B)
GEN_EMIT(LSL_W)
GEN_EMIT(LSL_L)
GEN_EMIT(LSR_B)
GEN_EMIT(LSR_W)
GEN_EMIT(LSR_L)
GEN_EMIT(ROXL_B)
GEN_EMIT(ROXL_W)
GEN_EMIT(ROXL_L)
GEN_EMIT(ROXR_B)
GEN_EMIT(ROXR_W)
GEN_EMIT(ROXR_L)
GEN_EMIT(ROL_B)
GEN_EMIT(ROL_W)
GEN_EMIT(ROL_L)
GEN_EMIT(ROR_B)
GEN_EMIT(ROR_W)
GEN_EMIT(ROR_L)

/* Conditional and branch operations ("branch_offset" parameter receives
 * the native offset of the branch to update when resolving, or -1 if not
 * supported) */
GEN_EMIT(Scc)
GEN_EMIT(ADD_CYCLES_Scc_Dn)
GEN_EMIT_4(DBcc, int16_t, reg4, int16_t, reg4_b, uint16_t, target_hi,
           uint16_t, target_lo)
#define JIT_EMIT_DBcc(entry,reg4,target)  do { \
    int16_t __reg4 = (reg4); \
    uint32_t __target = (target); \
    JIT_EMIT_DBcc((entry), __reg4, __reg4, __target>>16, __target & 0xFFFF); \
} while (0)
GEN_EMIT_5(DBcc_native, int16_t, reg4, int16_t, reg4_b, uint16_t, target_hi,
           uint16_t, target_lo, int16_t, native_disp_4_4)
#define JIT_EMIT_DBcc_native(entry,reg4,target,offset)  do {            \
    Q68JitEntry *__entry = (entry);                                     \
    int16_t __reg4 = (reg4);                                            \
    uint32_t __target = (target);                                       \
    int32_t __fragment_end = __entry->native_length + JIT_PSPSIZE_DBcc_native; \
    JIT_EMIT_DBcc_native(__entry, __reg4, __reg4,                       \
                         __target>>16,  __target & 0xFFFF,              \
                         ((offset) - __fragment_end + 4) / 4);          \
} while (0)
GEN_EMIT_3(Bcc_common, uint16_t, target_hi, uint16_t, target_lo, int16_t, disp_4)
static void JIT_EMIT_Bcc(Q68JitEntry *entry, uint32_t target,
                         int32_t *branch_offset) {
    *branch_offset = entry->native_length + JIT_PSPPARAM_Bcc_common_disp_4;
    int32_t disp_4 = (JIT_PSPOFS_TERMINATE - (*branch_offset + 4)) / 4;
    JIT_EMIT_Bcc_common(entry, target>>16, target & 0xFFFF, disp_4);
}
static void JIT_EMIT_Bcc_native(Q68JitEntry *entry, uint32_t target,
                                int32_t offset) {
    uint32_t branch_offset =
        entry->native_length + JIT_PSPPARAM_Bcc_common_disp_4;
    int32_t disp_4 = (offset - (branch_offset + 4)) / 4;
    /* Displacement is assumed to be within range (+/-128k) */
    JIT_EMIT_Bcc_common(entry, target>>16, target & 0xFFFF, disp_4);
}
GEN_EMIT_4(BSR, uint16_t, return_addr_hi, uint16_t, return_addr_lo,
           uint16_t, target_hi, uint16_t, target_lo)
#define JIT_EMIT_BSR(entry,return_addr,target)  do { \
    uint32_t __return_addr = (return_addr); \
    uint32_t __target = (target); \
    JIT_EMIT_BSR((entry), __return_addr>>16, __return_addr & 0xFFFF, \
                 __target>>16, __target & 0xFFFF); \
} while (0)
GEN_EMIT(JMP)
GEN_EMIT_2(JSR, uint16_t, return_addr_hi, uint16_t, return_addr_lo)
#define JIT_EMIT_JSR(entry,return_addr)  do { \
    uint32_t __return_addr = (return_addr); \
    JIT_EMIT_JSR((entry), __return_addr>>16, __return_addr & 0xFFFF); \
} while (0)

/* MOVEM-related operations */
GEN_EMIT_1(STORE_DEC_W, int16_t, reg4)
GEN_EMIT_1(STORE_DEC_L, int16_t, reg4)
GEN_EMIT_1(STORE_INC_W, int16_t, reg4)
GEN_EMIT_1(STORE_INC_L, int16_t, reg4)
GEN_EMIT_1(LOAD_INC_W, int16_t, reg4)
GEN_EMIT_1(LOAD_INC_L, int16_t, reg4)
GEN_EMIT_1(LOADA_INC_W, int16_t, reg4)
GEN_EMIT_1(MOVEM_WRITEBACK, int16_t, reg4)

/* Miscellaneous operations */
GEN_EMIT(CHK_W)
GEN_EMIT_1(LEA, int16_t, reg4)
GEN_EMIT(PEA)
GEN_EMIT(TAS)
GEN_EMIT_1(MOVE_FROM_USP, int16_t, reg4)
GEN_EMIT_1(MOVE_TO_USP, int16_t, reg4)
GEN_EMIT_1(STOP, uint16_t, newSR)
GEN_EMIT(TRAPV)
GEN_EMIT(RTS)
GEN_EMIT(RTR)
GEN_EMIT(RTE)
GEN_EMIT_3(MOVEP_READ_W, int16_t, areg4, int16_t, disp, int16_t, dreg4)
GEN_EMIT_3(MOVEP_READ_L, int16_t, areg4, int16_t, disp, int16_t, dreg4)
GEN_EMIT_3(MOVEP_WRITE_W, int16_t, areg4, int16_t, disp, int16_t, dreg4)
GEN_EMIT_3(MOVEP_WRITE_L, int16_t, areg4, int16_t, disp, int16_t, dreg4)
GEN_EMIT_2(EXG, int16_t, reg1_4, int16_t, reg2_4)

/*************************************************************************/

#endif  // Q68_JIT_PSP_H

/*
 * Local variables:
 *   c-file-style: "stroustrup"
 *   c-file-offsets: ((case-label . *) (statement-case-intro . *))
 *   indent-tabs-mode: nil
 * End:
 *
 * vim: expandtab shiftwidth=4:
 */
