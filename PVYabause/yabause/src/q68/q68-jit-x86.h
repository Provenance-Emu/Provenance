/*  src/q68/q68-jit-x86.h: x86 (32/64-bit) dynamic translation header for Q68
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

#ifndef Q68_JIT_X86_H
#define Q68_JIT_X86_H

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
    asm(
#ifdef CPU_X64
        /* GCC doesn't know we're actually calling a function here, so make
         * sure we don't accidentally overwrite the x64 redzone */
        "sub $128, %%rsp; call *%[address]; add $128, %%rsp"
#else
        /* x86 doesn't have a redzone, so we can just do a direct call */
        "call *%[address]"
#endif
        : [cycles] "=S" (cycles), [address] "=D" (*address_ptr)
        : [state] "b" (state), "0" (cycles), "1" (*address_ptr)
#ifdef CPU_X64
        : "rax", "rcx", "rdx", "r8", "r9", "r10", "r11"
#else
        : "eax", "ecx", "edx"
#endif
          , "memory"
    );
    return cycles;
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
    /* Not supported on x86/x64 */
}

/*************************************************************************/

/*
 * The remaining macros are all used to insert a specific operation into
 * the native code stream.  For simplicity, we define the actual code for
 * each operation in a separate assembly file, and use memcpy() to copy
 * from the assembled code to the output code stream.  The GEN_EMIT macro
 * below is used to generate each of the JIT_EMIT_* functions; each
 * function JIT_EMIT_xxx copies JIT_X86SIZE_xxx bytes from JIT_X86_xxx to
 * the code stream, expanding the code buffer if necessary.
 */

/* Sub-macros (platform-dependent): */

#ifdef CPU_X64

#define GEN_NAMESIZE(name) \
    extern const uint8_t JIT_X64_##name[]; \
    extern const uint32_t JIT_X64SIZE_##name;
#define GEN_PARAM(name,param) \
    extern const uint32_t JIT_X64PARAM_##name##_##param;
#define GEN_FUNC_TOP(name) \
        if (UNLIKELY(entry->native_size - entry->native_length  \
                         < JIT_X64SIZE_##name)) {               \
            if (!expand_buffer(entry)) {                        \
                return;                                         \
            }                                                   \
        }                                                       \
        if (JIT_X64SIZE_##name > 0) {                           \
            memcpy((uint8_t *)entry->native_code + entry->native_length, \
                   JIT_X64_##name, JIT_X64SIZE_##name);         \
        }
#define GEN_COPY_PARAM(name,type,param) \
        *(type *)((uint8_t *)entry->native_code + entry->native_length \
                  + JIT_X64PARAM_##name##_##param) = param;
#define GEN_FUNC_BOTTOM(name) \
        entry->native_length += JIT_X64SIZE_##name;

#else  // CPU_X86

#define GEN_NAMESIZE(name) \
    extern const uint8_t JIT_X86_##name[]; \
    extern const uint32_t JIT_X86SIZE_##name;
#define GEN_PARAM(name,param) \
    extern const uint32_t JIT_X86PARAM_##name##_##param;
#define GEN_FUNC_TOP(name) \
        if (UNLIKELY(entry->native_size - entry->native_length  \
                         < JIT_X86SIZE_##name)) {               \
            if (!expand_buffer(entry)) {                        \
                return;                                         \
            }                                                   \
        }                                                       \
        if (JIT_X86SIZE_##name > 0) {                           \
            memcpy((uint8_t *)entry->native_code + entry->native_length, \
                   JIT_X86_##name, JIT_X86SIZE_##name);         \
        }
#define GEN_COPY_PARAM(name,type,param) \
        *(type *)((uint8_t *)entry->native_code + entry->native_length \
                  + JIT_X86PARAM_##name##_##param) = param;
#define GEN_FUNC_BOTTOM(name) \
        entry->native_length += JIT_X86SIZE_##name;

#endif  // X64/X86

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

/*-----------------------------------------------------------------------*/

/* Code prologue and epilogue */
GEN_EMIT(PROLOGUE)
GEN_EMIT(EPILOGUE)

#ifdef Q68_TRACE
/* Trace the current instruction */
GEN_EMIT(TRACE)
#endif

/* Add the specified number of cycles to the cycle counter */
GEN_EMIT_1(ADD_CYCLES, int32_t, cycles)

/* Check the cycle limit and interrupt execution if necessary */
GEN_EMIT(CHECK_CYCLES)

/* Add the specified amount to the program counter and/or check whether
 * to abort */
GEN_EMIT_1(ADVANCE_PC, int32_t, value)
GEN_EMIT_1(ADVANCE_PC_CHECK_ABORT, int32_t, value)
GEN_EMIT(CHECK_ABORT)

/* Exception raising */
GEN_EMIT_1(EXCEPTION, uint32_t, num)
GEN_EMIT_2(CHECK_ALIGNED_EA, uint16_t, opcode, uint16_t, status)
GEN_EMIT_2(CHECK_ALIGNED_SP, uint16_t, opcode, uint16_t, status)
GEN_EMIT(CHECK_SUPER)

/*-----------------------------------------------------------------------*/

/* Resolve an effective address */
GEN_EMIT_1(RESOLVE_INDIRECT, uint8_t, reg4)
GEN_EMIT_2(RESOLVE_POSTINC, uint8_t, reg4, uint8_t, size)
GEN_EMIT(RESOLVE_POSTINC_A7_B)
GEN_EMIT_2(RESOLVE_PREDEC, uint8_t, reg4, uint8_t, size)
GEN_EMIT(RESOLVE_PREDEC_A7_B)
GEN_EMIT_2(RESOLVE_DISP, uint8_t, reg4, uint32_t, disp)
GEN_EMIT_3(RESOLVE_INDEX_W, uint8_t, reg4, uint8_t, ireg4, uint8_t, disp)
GEN_EMIT_3(RESOLVE_INDEX_L, uint8_t, reg4, uint8_t, ireg4, uint8_t, disp)
GEN_EMIT_1(RESOLVE_ABSOLUTE, uint32_t, addr)
GEN_EMIT_2(RESOLVE_ABS_INDEX_W, uint32_t, addr, uint8_t, ireg4)
GEN_EMIT_2(RESOLVE_ABS_INDEX_L, uint32_t, addr, uint8_t, ireg4)

/* Retrieve various things as operand 1 */
GEN_EMIT_1(GET_OP1_REGISTER, uint8_t, reg4)
GEN_EMIT(GET_OP1_EA_B)
GEN_EMIT(GET_OP1_EA_W)
GEN_EMIT(GET_OP1_EA_L)
GEN_EMIT_1(GET_OP1_IMMEDIATE, uint32_t, value)
GEN_EMIT(GET_OP1_CCR)
GEN_EMIT(GET_OP1_SR)

/* Retrieve various things as operand 2 */
GEN_EMIT_1(GET_OP2_REGISTER, uint8_t, reg4)
GEN_EMIT(GET_OP2_EA_B)
GEN_EMIT(GET_OP2_EA_W)
GEN_EMIT(GET_OP2_EA_L)
GEN_EMIT_1(GET_OP2_IMMEDIATE, uint32_t, value)
GEN_EMIT(GET_OP2_CCR)
GEN_EMIT(GET_OP2_SR)

/* Update various things from result */
GEN_EMIT_1(SET_REGISTER_B, uint8_t, reg4)
GEN_EMIT_1(SET_REGISTER_W, uint8_t, reg4)
GEN_EMIT_1(SET_REGISTER_L, uint8_t, reg4)
GEN_EMIT_1(SET_AREG_W, uint8_t, reg4)
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
GEN_EMIT_2(DBcc, uint8_t, reg4, int32_t, target)
GEN_EMIT_3(DBcc_native, uint8_t, reg4, int32_t, target, int32_t, native_disp)
#ifdef CPU_X64
# define SIZE_DBcc_native JIT_X64SIZE_DBcc_native
#else
# define SIZE_DBcc_native JIT_X86SIZE_DBcc_native
#endif
#define JIT_EMIT_DBcc_native(entry,reg4,target,offset)  do {            \
    Q68JitEntry *__entry = (entry);                                     \
    int32_t __fragment_end = __entry->native_length + SIZE_DBcc_native; \
    JIT_EMIT_DBcc_native(__entry, (reg4), (target),                     \
                         (offset) - __fragment_end);                    \
} while (0)
GEN_EMIT_1(Bcc, int32_t, target)
#define JIT_EMIT_Bcc(entry,target,branch_offset)  do {                  \
    JIT_EMIT_Bcc((entry), (target));                                    \
    *(branch_offset) = -1;                                              \
} while (0)
GEN_EMIT_2(Bcc_native, int32_t, target, int32_t, native_disp)
#ifdef CPU_X64
# define SIZE_Bcc_native JIT_X64SIZE_Bcc_native
#else
# define SIZE_Bcc_native JIT_X86SIZE_Bcc_native
#endif
#define JIT_EMIT_Bcc_native(entry,target,native)  do {                  \
    Q68JitEntry *__entry = (entry);                                     \
    int32_t __fragment_end = __entry->native_length + SIZE_Bcc_native;  \
    JIT_EMIT_Bcc_native(__entry, (target), (offset) - __fragment_end);  \
} while (0)
GEN_EMIT_2(BSR, uint32_t, return_addr, int32_t, target)
GEN_EMIT(JMP)
GEN_EMIT_1(JSR, uint32_t, return_addr)

/* MOVEM-related operations */
GEN_EMIT_1(STORE_DEC_W, uint8_t, reg4)
GEN_EMIT_1(STORE_DEC_L, uint8_t, reg4)
GEN_EMIT_1(STORE_INC_W, uint8_t, reg4)
GEN_EMIT_1(STORE_INC_L, uint8_t, reg4)
GEN_EMIT_1(LOAD_INC_W, uint8_t, reg4)
GEN_EMIT_1(LOAD_INC_L, uint8_t, reg4)
GEN_EMIT_1(LOADA_INC_W, uint8_t, reg4)
GEN_EMIT_1(MOVEM_WRITEBACK, uint8_t, reg4)

/* Miscellaneous operations */
GEN_EMIT(CHK_W)
GEN_EMIT_1(LEA, uint8_t, reg4)
GEN_EMIT(PEA)
GEN_EMIT(TAS)
GEN_EMIT_1(MOVE_FROM_USP, uint8_t, reg4)
GEN_EMIT_1(MOVE_TO_USP, uint8_t, reg4)
GEN_EMIT_1(STOP, uint16_t, newSR)
GEN_EMIT(TRAPV)
GEN_EMIT(RTS)
GEN_EMIT(RTR)
GEN_EMIT(RTE)
GEN_EMIT_3(MOVEP_READ_W, uint8_t, areg4, int32_t, disp, uint8_t, dreg4)
GEN_EMIT_3(MOVEP_READ_L, uint8_t, areg4, int32_t, disp, uint8_t, dreg4)
GEN_EMIT_3(MOVEP_WRITE_W, uint8_t, areg4, int32_t, disp, uint8_t, dreg4)
GEN_EMIT_3(MOVEP_WRITE_L, uint8_t, areg4, int32_t, disp, uint8_t, dreg4)
GEN_EMIT_2(EXG, uint8_t, reg1_4, uint8_t, reg2_4)

/*************************************************************************/

#endif  // Q68_JIT_X86_H

/*
 * Local variables:
 *   c-file-style: "stroustrup"
 *   c-file-offsets: ((case-label . *) (statement-case-intro . *))
 *   indent-tabs-mode: nil
 * End:
 *
 * vim: expandtab shiftwidth=4:
 */
