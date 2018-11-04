/*  src/q68/q68-jit.c: Dynamic translation support for Q68
    Copyright 2009-2010 Andrew Church

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
#include <stdlib.h>
#include <string.h>

#include "q68.h"
#include "q68-const.h"
#include "q68-internal.h"
#include "q68-jit.h"

/*************************************************************************/

/*
 * Dynamic translation of 68000 instructions into native code is performed
 * as follows:
 *
 * 1) The emulation core (q68-core.c) calls q68_jit_find() on the current
 *    PC to check whether there is a translated block starting at that
 *    address.
 *
 * 2) If no translated block exists, the emulation core calls
 *    q68_jit_translate() to translate a block beginning at the current
 *    PC.  q68_jit_translate() continues translating through the end of
 *    the block of code (determined heuristically) and returns the
 *    translated block to be passed to q68_jit_run().
 *
 * 3) If a translated block exists or was just created, the emulation core
 *    calls q68_jit_run() to begin execution of the translated code.
 *
 * 4) The translated code returns either when it reaches the end of the
 *    block, or when the number of cycles executed exceeds the requested
 *    cycle count.  (For efficiency, cycle count checks are only performed
 *    before branching instructions: BRA, BSR, Bcc, DBcc, JMP, JSR, RTS,
 *    RTE, RTR, TRAP, STOP.)
 *
 * 5) If the translated code returns before the end of the block, the core
 *    continues to call q68_jit_run() until the end of the block is
 *    reached.
 *
 * 6) If a write is made to a region of memory containing one or more
 *    translated blocks, the core deletes the translations by calling
 *    q68_jit_clear_page() so the modified code can be retranslated.
 *    Writes originating in the translated code itself (i.e. self-modifying
 *    code) are handled by the native code calling q68_jit_clear_write()
 *    when detecting a write to a page containing translations.
 *
 * The amount of translated code which can be stored at one time is
 * dependent upon two factors: the size of the hash table (set by the
 * Q68_JIT_TABLE_SIZE define in q68-const.h) and the maximum translated
 * data size (set by the Q68_JIT_DATA_LIMIT define).  If either the hash
 * table becomes full or the data size limit is reached, any subsequent
 * translation will cause the oldest existing translation to be deleted,
 * where "oldest" is defined as "last executed the greatest number of
 * q68_jit_run() calls ago".  Note that the data size limit is checked only
 * when beginning a translation, so the total data size at the end of a
 * translation may slightly exceed the specified limit.
 *
 * ========================================================================
 *
 * Native code is generated through calls to JIT_EMIT_*() routines.
 * Typically, these routines will copy a pre-assembled code fragment to the
 * native code buffer, then patch that code fragment with values specific
 * to the instruction being translated (such as register numbers or branch
 * targets).  The general sequence of operations emitted is as follows:
 *
 *     JIT_EMIT_RESOLVE_*  -- resolves an effective address to a 68000
 *                               memory location
 *     JIT_EMIT_GET_OP1_*  -- loads the first operand for an instruction
 *     JIT_EMIT_GET_OP2_*  -- loads the second operand for an instruction
 *     JIT_EMIT_TEST_*     -- tests the state of condition codes
 *     JIT_EMIT_(insn)     -- executes the instruction itself
 *     JIT_EMIT_SETCC_*    -- updates the 68000 condition codes
 *     JIT_EMIT_SET_*      -- stores the result of the instruction
 *     JIT_EMIT_ADD_CYCLES -- increments the count of clock cycles executed(*)
 *     JIT_EMIT_ADVANCE_PC -- increments the program counter register(*)
 *
 * (*) In some cases, particularly when the instruction may cause execution
 *     of the block to terminate, these operations will occur earlier in
 *     the sequence.  The code generator takes responsibility for ensuring
 *     that such updates happen in the proper order.
 *
 * The code generator guarantees that the following invariants hold:
 *
 *   - No operations which could result in a 68000 memory access will be
 *     generated between loading of the second operand (JIT_EMIT_GET_OP2_*)
 *     and execution of the instruction.
 *
 *   - A JIT_EMIT_TEST_* operation will always be followed immediately by
 *     the instruction which uses the operation (such as JIT_EMIT_Scc).
 *
 *   - A JIT_EMIT_SETCC_* operation will always immediately follow the
 *     operation which produced the result it is testing.
 *
 * The machine-dependent implementations must obey the following rules:
 *
 *   - Each write to memory must be preceded by a check for translated code
 *     at the target address (by checking state->jit_pages[]) and a call to
 *     q68_jit_clear_write() if any translations are found.
 *     (Implementations may violate this rule in circumstances considered
 *     unlikely, at the risk of incorrect behavior if such circumstances
 *     actually occur; for example, the PSP implementation does not check
 *     for a longword write overlapping the end of a JIT page, and does not
 *     check writes from the MOVEM instruction.)
 *
 *   - Any instruction which modifies the program counter (Bcc, etc.) must
 *     terminate execution of the native code block, _except for_ the
 *     following instructions:
 *         JMP, RTE, RTR, RTS
 *
 *   - Any instruction which raises an exception must do so by storing the
 *     appropriate exception number in state->exception and terminating
 *     execution of the native code block.
 *
 *   - It is the responsibility of the native code to check for a pending
 *     unmasked interrupt when modifying the status register.
 *
 * The BSR/JSR and RTS/RTR instructions may make use of a call stack
 * provided by the JIT core to allow native code to quickly return to the
 * point at which a subroutine call took place.  The BSR and JSR
 * implementations should, when they terminate execution, return a pointer
 * to the following native code (as for termination in CHECK_CYCLES), and
 * should set bit 15 of the cycle count returned from JIT_CALL();
 * q68_jit_run() will detect this as a subroutine call, and save the native
 * code pointer returned before switching to the subroutine block.  The RTS
 * and RTR implementations should set bits 15 and 14 of the cycle count
 * they return, which will cause q68_jit_run() to search the call stack
 * from top to bottom for an entry matching the new 68000 PC; if one is
 * found, the corresponding code will be immediately executed, bypassing
 * the ordinary block search and execution process (steps 1 through 3
 * above).
 *
 * See the q68-jit-*.[hS] files for implementation details.
 *
 * ========================================================================
 *
 * The JIT code generator includes a primitive optimization step (if the
 * Q68_JIT_OPTIMIZE_FLAGS preprocessor symbol is defined) which omits the
 * generation of code to set the 68000 condition flags (X, N, Z, V, and C)
 * when unnecessary for correct execution.  Specifically, the translator
 * checks both the current and the following instruction to determine if
 * there are any condition flags which are:
 *   - set by the current instruction, AND
 *       - used as input by the following instruction OR
 *       - NOT set by the following instruction
 * If there are no such flags, then it is impossible for the flag values
 * set by the current instruction to have any effect on program flow, so
 * the native code to set the condition codes can be safely omitted.
 *
 * The above logic is contained in the cc_needed() routine (and its helper
 * routine cc_info()).  For each instruction that can set the condition
 * flags, the translation routine first calls cc_needed() to determine
 * whether the condition flags need to be set or not.  If cc_needed()
 * returns zero, then there are no flags whose output is required, and the
 * relevant JIT_EMIT_SETCC_* operation will be skipped.
 *
 * In the interests of speed and code clarity, the helper routine cc_info()
 * does not check the validity of the opcode passed to it; as a result, it
 * may return invalid flag information for some invalid opcodes.  If such
 * an invalid opcode actually occurs in the instruction stream, the CCR
 * register may therefore contain an incorrect value when control is
 * transferred to the illegal instruction exception handler.  In situations
 * where this can cause undesired behavior, this optimization should be
 * disabled.
 *
 * When Q68_JIT_OPTIMIZE_FLAGS is not defined, the definitions of
 * cc_needed() and cc_info() are omitted, and cc_needed() is instead
 * defined at the preprocessor level to return 1; this has the effect of
 * always emitting code to set the condition flags.
 */

/*************************************************************************/

/* For the PSP, we need to avoid local data here sharing a cache line with
 * data in other files due to the lack of SC/ME cache coherency */
#ifdef PSP
static __attribute__((aligned(64),used)) int dummy_top;
#endif

/*----------------------------------*/

/* Entry into which translated code is currently being stored (set by
 * q68_jit_translate(), used by opcode translation functions) */
static Q68JitEntry *current_entry;

/* Address from which data is being read */
static uint32_t jit_PC;

/* Flag indicating whether the PC was updated by an instruction (e.g. jumps) */
static int PC_updated;

/* Branch target lookup table (indicates where in the native code each
 * address is located) */
static struct {
    uint32_t m68k_address;  // Address of 68000 instruction
    uint32_t native_offset; // Byte offset into current_entry->native_code
} btcache[Q68_JIT_BTCACHE_SIZE];
static unsigned int btcache_index;  // Where to store the next instruction

/* Unresolved branch list (saves locations and targets of forward branches) */
static struct {
    uint32_t m68k_target;   // Branch target (68000 address)
    uint32_t native_offset; // Offset of native branch instruction to update
} unres_branches[Q68_JIT_UNRES_BRANCH_SIZE];

/*----------------------------------*/

#ifdef PSP  // As above
static __attribute__((aligned(64),used)) int dummy_bottom;
#endif

/*-----------------------------------------------------------------------*/

/* Redefine IFETCH to reference jit_PC */

static inline uint32_t jit_IFETCH(Q68State *state) {
    uint32_t data = READU16(state, jit_PC);
    jit_PC += 2;
    return data;
}
#define IFETCH jit_IFETCH

/*************************************************************************/

/*
 * Forward declarations for helper functions and instruction implementations.
 * These are set up identically to q68-core.c so that bugfixes or other
 * changes to one can be easily ported to the other.
 *
 * Note that the return value of OpcodeFunc is taken to be the end-of-block
 * flag as returned from q68_jit_translate(), not the number of clock cycles
 * taken by the instruction.
 */

static int translate_insn(Q68State *state, Q68JitEntry *entry);
static void clear_entry(Q68State *state, Q68JitEntry *entry);
static void clear_oldest_entry(Q68State *state);
static int expand_buffer(Q68JitEntry *entry);
static int32_t btcache_lookup(uint32_t address);
static void record_unresolved_branch(uint32_t m68k_target,
                                     uint32_t native_offset);
static inline void JIT_EMIT_TEST_cc(int cond, Q68JitEntry *entry);
static void advance_PC(Q68State *state);
static int raise_exception(Q68State *state, uint8_t num);
static inline int op_ill(Q68State *state, uint32_t opcode);

#ifdef Q68_JIT_OPTIMIZE_FLAGS
static unsigned int cc_needed(Q68State *state, uint16_t opcode);
# ifdef __GNUC__
__attribute__((const))
# endif
static unsigned int cc_info(uint16_t opcode);
#else
# define cc_needed(state,opcode) 1
#endif

static int ea_resolve(Q68State *state, uint32_t opcode, int size,
                               int access_type);
static void ea_get(Q68State *state, uint32_t opcode, int size,
                   int is_rmw, int *cycles_ret, int op_num);
static void ea_set(Q68State *state, uint32_t opcode, int size);

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

/*************************************************************************/

/* Include the header appropriate to the platform (make sure to do this
 * after the local function declarations) */

#if defined(CPU_X86) || defined(CPU_X64)
# include "q68-jit-x86.h"
#elif defined(CPU_PSP)
# include "q68-jit-psp.h"
#else
# error Dynamic translation is not supported on this platform
#endif

/*************************************************************************/
/********************** External interface routines **********************/
/*************************************************************************/

/**
 * q68_jit_init:  Allocate memory for JIT data.  Must be called before any
 * other JIT function.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     Nonzero on success, zero on error
 */
int q68_jit_init(Q68State *state)
{
    state->jit_table =
        state->malloc_func(sizeof(*state->jit_table) * Q68_JIT_TABLE_SIZE);
    if (!state->jit_table) {
        DMSG("No memory for JIT table");
        goto error_return;
    }
    state->jit_hashchain =
        state->malloc_func(sizeof(*state->jit_hashchain) * Q68_JIT_TABLE_SIZE);
    if (!state->jit_hashchain) {
        DMSG("No memory for JIT hash chain table");
        goto error_free_jit_table;
    }

    /* Make sure all entries are marked as unused (so we don't try to free
     * invalid pointers in q68_jit_reset()) */
    int i;
    for (i = 0; i < Q68_JIT_TABLE_SIZE; i++) {
        state->jit_table[i].m68k_start = 0;
    }

    /* Make sure page table is clear (so writes before processor reset
     * don't trigger JIT clearing */
    memset(state->jit_pages, 0, sizeof(state->jit_pages));

    /* Default to no cache flush function */
    state->jit_flush   = NULL;

#ifdef Q68_DISABLE_ADDRESS_ERROR
    /* Hack to avoid compiler warnings about unused functions */
    if (0) {
        JIT_EMIT_CHECK_ALIGNED_EA(&state->jit_table[0], 0, 0);
        JIT_EMIT_CHECK_ALIGNED_SP(&state->jit_table[0], 0, 0);
    }
#endif

    return 1;

  error_free_jit_table:
    state->free_func(state->jit_table);
    state->jit_table = NULL;
  error_return:
    return 0;
}

/*-----------------------------------------------------------------------*/

/**
 * q68_jit_reset:  Reset the dynamic translation state, clearing out all
 * previously stored data.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
void q68_jit_reset(Q68State *state)
{
    int index;

    state->jit_abort = 0;
    for (index = 0; index < Q68_JIT_TABLE_SIZE; index++) {
        if (state->jit_table[index].m68k_start) {
            clear_entry(state, &state->jit_table[index]);
        }
    }
    for (index = 0; index < Q68_JIT_TABLE_SIZE; index++) {
        state->jit_hashchain[index] = NULL;
    }
    state->jit_total_data = 0;
    state->jit_timestamp = 0;
    for (index = 0; index < Q68_JIT_BLACKLIST_SIZE; index++) {
        state->jit_blacklist[index].m68k_start = 0;
        state->jit_blacklist[index].m68k_end = 0;
    }
    state->jit_in_blist = 0;
    state->jit_blist_num = 0;
    state->jit_callstack_top = 0;
    memset(state->jit_pages, 0, sizeof(state->jit_pages));
}

/*-----------------------------------------------------------------------*/

/**
 * q68_jit_cleanup:  Destroy all JIT-related data.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
void q68_jit_cleanup(Q68State *state)
{
    q68_jit_reset(state);
    state->free_func(state->jit_hashchain);
    state->jit_hashchain = NULL;
    state->free_func(state->jit_table);
    state->jit_table = NULL;
}

/*************************************************************************/

/**
 * q68_jit_translate:  Dynamically translate a block of instructions
 * starting at the given address.  If a translation already exists for the
 * given address, it is cleared.
 *
 * [Parameters]
 *       state: Processor state block
 *     address: Start address in 68000 address space
 * [Return value]
 *     Translated block to be passed to q68_jit_run(), or NULL on error
 */
Q68JitEntry *q68_jit_translate(Q68State *state, uint32_t address)
{
    int index;

    if (address == 0) {
        /* We use address 0 to indicate an unused entry, so we can't
         * translate from address 0.  But this should never happen except
         * in pathological cases (or unhandled exceptions), so just punt
         * and let the interpreter handle it */
        return NULL;
    }
    if (address & 1) {
        /* Odd addresses are invalid, so we can't translate them in the
         * first place */
         return NULL;
    }
    address &= 0xFFFFFF;

    /* Check whether we're trying to translate a blacklisted address. */

    if (state->jit_in_blist) {
        index = state->jit_blist_num;
        /* See whether we've exited the blacklisted block */
        if (address >= state->jit_blacklist[index].m68k_start
         && address <= state->jit_blacklist[index].m68k_end
        ) {
            return NULL;
        }
        state->jit_in_blist = 0;
    }  // We might have entered another blacklisted block, so no "else" here

    if (!state->jit_in_blist) {
        /* See if we're in a blacklisted block, and skip its translation
         * if so */
        for (index = 0; index < Q68_JIT_BLACKLIST_SIZE; index++) {
            if (address >= state->jit_blacklist[index].m68k_start
             && address <= state->jit_blacklist[index].m68k_end
            ) {
                uint32_t dt = state->jit_timestamp
                              - state->jit_blacklist[index].timestamp;
                if (dt < Q68_JIT_BLACKLIST_TIMEOUT) {
                    state->jit_in_blist = 1;
                    state->jit_blist_num = index;
                    return NULL;
                } else {
                    /* Entry expired, so clear it */
                    state->jit_blacklist[index].m68k_start = 0;
                    state->jit_blacklist[index].m68k_end = 0;
                }
            }
        }
    }

    /* Clear out any existing translation, then search for an empty slot in
     * the hash table.  If we've reached the data size limit, first evict
     * old entries until we're back under the limit. */
    q68_jit_clear(state, address);
    while (state->jit_total_data >= Q68_JIT_DATA_LIMIT) {
        clear_oldest_entry(state);
    }
    const int hashval = JIT_HASH(address);
    index = hashval;
    int oldest = index;
    while (state->jit_table[index].m68k_start != 0) {
        if (TIMESTAMP_COMPARE(state->jit_timestamp,
                              state->jit_table[index].timestamp,
                              state->jit_table[oldest].timestamp) < 0) {
            oldest = index;
        }
        index++;
        /* Using an if here is faster than taking the remainder with % */
        if (UNLIKELY(index >= Q68_JIT_TABLE_SIZE)) {
            index = 0;
        }
        if (UNLIKELY(index == hashval)) {
            /* Out of entries, so clear the oldest one and use it */
#ifdef Q68_JIT_VERBOSE
            DMSG("No free slots for code at $%06X, clearing oldest ($%06X)",
                 (int)address, (int)state->jit_table[oldest].m68k_start);
#endif
            clear_entry(state, &state->jit_table[oldest]);
            index = oldest;
        }
    }
    current_entry = &state->jit_table[index];

    /* Initialize the new entry */

    current_entry->native_code = state->malloc_func(Q68_JIT_BLOCK_EXPAND_SIZE);
    if (!current_entry->native_code) {
        DMSG("No memory for code at $%06X", address);
        current_entry = NULL;
        return NULL;
    }
    current_entry->next = state->jit_hashchain[hashval];
    if (state->jit_hashchain[hashval]) {
        state->jit_hashchain[hashval]->prev = current_entry;
    }
    state->jit_hashchain[hashval] = current_entry;
    current_entry->prev = NULL;
    current_entry->state = state;
    current_entry->m68k_start = address;
    current_entry->native_size = Q68_JIT_BLOCK_EXPAND_SIZE;
    current_entry->native_length = 0;
    current_entry->exec_address = NULL;
    current_entry->timestamp = state->jit_timestamp;
    current_entry->must_clear = 0;
    JIT_EMIT_PROLOGUE(current_entry);

    /* Clear out the branch target cache and unresolved branch list */
    for (index = 0; index < lenof(btcache); index++) {
        btcache[index].m68k_address = 0;
    }
    btcache_index = 0;
    for (index = 0; index < lenof(unres_branches); index++) {
        unres_branches[index].m68k_target = 0;
    }

    /* Translate a block of 68000 code */

    jit_PC = address;
    const uint32_t limit = address + Q68_JIT_MAX_BLOCK_SIZE;
    int done = 0;
    while (!done && jit_PC < limit) {
        /* Make sure we haven't entered a blacklisted block */
        for (index = 0; index < Q68_JIT_BLACKLIST_SIZE; index++) {
            if (UNLIKELY(address >= state->jit_blacklist[index].m68k_start
                      && address <= state->jit_blacklist[index].m68k_end)
            ) {
                const uint32_t age = state->jit_timestamp
                                     - state->jit_blacklist[index].timestamp;
                if (age < Q68_JIT_BLACKLIST_TIMEOUT) {
                    done = 1;
                    break;
                } else {
                    /* Entry expired, so clear it */
                    state->jit_blacklist[index].m68k_start = 0;
                    state->jit_blacklist[index].m68k_end = 0;
                }
            }
        }
        if (LIKELY(!done)) {
            done = translate_insn(state, current_entry);
        }
    }

    /* Close out the translated block */

    JIT_EMIT_EPILOGUE(current_entry);
    current_entry->m68k_end = jit_PC - 1;
    for (index =  current_entry->m68k_start >> Q68_JIT_PAGE_BITS;
         index <= current_entry->m68k_end   >> Q68_JIT_PAGE_BITS;
         index++
    ) {
        JIT_PAGE_SET(state, index);
    }
    void *newptr = state->realloc_func(current_entry->native_code,
                                       current_entry->native_length);
    if (newptr) {
        current_entry->native_code = newptr;
        current_entry->native_size = current_entry->native_length;
    }
    state->jit_total_data += current_entry->native_size;
    /* Prepare the block for execution so it can be immediately passed to
     * q68_jit_run() (see q68_jit_find() for why we do it here) */
    current_entry->exec_address = current_entry->native_code;

    Q68JitEntry *retval = current_entry;
    current_entry = NULL;
    if (state->jit_flush) {
        state->jit_flush();
    }
    return retval;
}

/*************************************************************************/

/**
 * q68_jit_find:  Find the translated block for a given address, if any.
 *
 * [Parameters]
 *       state: Processor state block
 *     address: Start address in 68000 address space
 * [Return value]
 *     Translated block to be passed to q68_jit_run(), or NULL if no such
 *     block exists
 */
Q68JitEntry *q68_jit_find(Q68State *state, uint32_t address)
{
    const int hashval = JIT_HASH(address);
    Q68JitEntry *entry = state->jit_hashchain[hashval];
    while (entry) {
        if (entry->m68k_start == address) {
            /* Prepare the block for execution.  We set exec_address here
             * both to avoid overhead in q68_jit_run(), and because
             * exec_address could be non-NULL if (for example) the native
             * code stopped due to reaching the cycle limit and the core
             * then serviced an interrupt. */
            entry->exec_address = entry->native_code;
            return entry;
        }
        entry = entry->next;
    }
    return NULL;
}

/*-----------------------------------------------------------------------*/

/**
 * q68_jit_run:  Run translated 68000 code.
 *
 * [Parameters]
 *           state: Processor state block
 *     cycle_limit: Clock cycle limit on execution (code will stop when
 *                     state->cycles >= cycles)
 *     address_ptr: Pointer to translated block to execute; will be cleared
 *                     to NULL on return if the end of the block was reached
 * [Return value]
 *     None
 */
void q68_jit_run(Q68State *state, uint32_t cycle_limit,
                 Q68JitEntry **entry_ptr)
{
    Q68JitEntry *entry = *entry_ptr;

  again:
    entry->timestamp = state->jit_timestamp;
    state->jit_timestamp++;
    entry->running = 1;
    int cycles = JIT_CALL(state, cycle_limit - state->cycles,
                          &entry->exec_address);
    entry->running = 0;
    state->jit_abort = 0;
    state->cycles += cycles & 0x3FFF;

    if (UNLIKELY(entry->must_clear)) {
        clear_entry(state, entry);
        entry = NULL;
    } else if (cycles & 0x8000) {  // BSR/JSR/RTS/RTR
        if (cycles & 0x4000) {  // RTS/RTR
            entry = NULL;
            unsigned int top = state->jit_callstack_top;
            unsigned int i;
            for (i = Q68_JIT_CALLSTACK_SIZE; i > 0; i--) {
                top = (top + Q68_JIT_CALLSTACK_SIZE-1) % Q68_JIT_CALLSTACK_SIZE;
                if (state->jit_callstack[top].return_PC == state->PC) {
                    entry = state->jit_callstack[top].return_entry;
                    entry->exec_address =
                        state->jit_callstack[top].return_native;
                    state->jit_callstack_top = top;
                    if (state->cycles < cycle_limit) {
                        goto again;
                    } else {
                        break;
                    }
                }
            }
        } else {  // BSR/JSR
            const unsigned int top = state->jit_callstack_top;
            const uint32_t return_PC = READU32(state, state->A[7]);
            state->jit_callstack[top].return_PC = return_PC;
            state->jit_callstack[top].return_entry = entry;
            state->jit_callstack[top].return_native = entry->exec_address;
            state->jit_callstack_top = (top+1) % Q68_JIT_CALLSTACK_SIZE;
            entry = NULL;
        }
    } else if (!entry->exec_address) {
        entry = NULL;
    }

    /* If we finished a block, we still have cycles to go, there's no
     * exception pending, and there's already a translated block at the
     * next PC, jump right to it so we don't incur the extra overhead of
     * returning to the caller */
    if (!entry && state->cycles < cycle_limit && !state->exception) {
        entry = q68_jit_find(state, state->PC);
        if (entry) {
            goto again;
        }
    }

    *entry_ptr = entry;
}

/*-----------------------------------------------------------------------*/

/**
 * q68_jit_clear:  Clear any translation beginning at the given address.
 *
 * [Parameters]
 *       state: Processor state block
 *     address: Start address in 68000 address space
 * [Return value]
 *     None
 */
void q68_jit_clear(Q68State *state, uint32_t address)
{
    const int hashval = JIT_HASH(address);
    Q68JitEntry *entry = state->jit_hashchain[hashval];
    while (entry) {
        if (entry->m68k_start == address) {
            clear_entry(state, entry);
            return;
        }
        entry = entry->next;
    }
}

/*-----------------------------------------------------------------------*/

/**
 * q68_jit_clear_page:  Clear any translation which occurs in the JIT page
 * containing the given address.  Intended for use on writes from external
 * sources.
 *
 * [Parameters]
 *       state: Processor state block
 *     address: Address to which data was written
 * [Return value]
 *     None
 */
void q68_jit_clear_page(Q68State *state, uint32_t address)
{
    const uint32_t page = address >> Q68_JIT_PAGE_BITS;
#ifdef Q68_JIT_VERBOSE
    DMSG("WARNING: jit_clear_page($%06X)", page << Q68_JIT_PAGE_BITS);
#endif

    int index;
    for (index = 0; index < Q68_JIT_TABLE_SIZE; index++) {
        if (state->jit_table[index].m68k_start != 0
         && state->jit_table[index].m68k_start >> Q68_JIT_PAGE_BITS <= page
         && state->jit_table[index].m68k_end   >> Q68_JIT_PAGE_BITS >= page
        ) {
            if (UNLIKELY(state->jit_table[index].running)) {
                state->jit_table[index].must_clear = 1;
                state->jit_abort = 1;
            } else {
                clear_entry(state, &state->jit_table[index]);
            }
        }
    }

    JIT_PAGE_CLEAR(state, page);
}

/*-----------------------------------------------------------------------*/

/**
 * q68_jit_clear_write:  Clear any translation which includes the given
 * address, and (if there is at least one such translation) blacklist the
 * address from being translated.
 *
 * [Parameters]
 *       state: Processor state block
 *     address: Address to which data was written
 *        size: Size of data written
 * [Return value]
 *     None
 */
void q68_jit_clear_write(Q68State *state, uint32_t address, uint32_t size)
{
    int index;

    /* If the address is in a blacklisted block, we don't need to do
     * anything (but update the timestamp to extend its timeout) */
    for (index = 0; index < Q68_JIT_BLACKLIST_SIZE; index++) {
        if (address >= state->jit_blacklist[index].m68k_start
         && address <= state->jit_blacklist[index].m68k_end
        ) {
            state->jit_blacklist[index].timestamp = state->jit_timestamp;
            return;
        }
    }

    /* Clear the translations-exist flag now; we'll set it later if we
     * find a translation on the page that we don't clear */
    const uint32_t page       = address >> Q68_JIT_PAGE_BITS;
    const uint32_t page_start = page << Q68_JIT_PAGE_BITS;
    const uint32_t page_end   = ((page+1) << Q68_JIT_PAGE_BITS) - 1;
    JIT_PAGE_CLEAR(state, page);

    /* Clear any translations affected by the address, and determine
     * the range to be blacklisted.  We default to assuming the address is
     * the last byte/word of the longest possible instruction (10 bytes:
     * MOVE.L #$12345678, ($12345678).l), but do not extend backwards past
     * the beginning of a block. */
    int found = 0;
    uint32_t start = address + size, end = address + (size-1);
#ifdef Q68_JIT_VERBOSE
    DMSG("WARNING: jit_clear_write($%06X,%d)", (int)address, (int)size);
#endif
    for (index = 0; index < Q68_JIT_TABLE_SIZE; index++) {
        if (state->jit_table[index].m68k_start == 0) {
            continue;
        }
        if (state->jit_table[index].m68k_start < address + size
         && state->jit_table[index].m68k_end >= address) {
            found = 1;
            if (start > state->jit_table[index].m68k_start) {
                /* Use the earliest start address of those we see */
                start = state->jit_table[index].m68k_start;
            }
            if (UNLIKELY(state->jit_table[index].running)) {
                state->jit_table[index].must_clear = 1;
                state->jit_abort = 1;
            } else {
                clear_entry(state, &state->jit_table[index]);
            }
        } else if (state->jit_table[index].m68k_start <= page_start
                && state->jit_table[index].m68k_end   >= page_end) {
            /* No need to clear this one, so set the page bit again */
            JIT_PAGE_SET(state, page);
        }
    }
    if (!found || start < (address & ~1) - 8) {
        start = (address & ~1) - 8;
    }

    /* Add the blacklist entry */
#ifdef Q68_JIT_VERBOSE
    DMSG("Blacklisting $%06X...$%06X", (int)start, (int)end);
#endif
    /* First see if this overlaps with another entry */
    found = 0;
    for (index = 0; index < Q68_JIT_BLACKLIST_SIZE; index++) {
        if (state->jit_blacklist[index].m68k_start <= end
         && state->jit_blacklist[index].m68k_end >= start) {
#ifdef Q68_JIT_VERBOSE
            DMSG("(Merging with $%06X...%06X)",
                 (int)state->jit_blacklist[index].m68k_start,
                 (int)state->jit_blacklist[index].m68k_end);
#endif
            if (start > state->jit_blacklist[index].m68k_start) {
                start = state->jit_blacklist[index].m68k_start;
            }
            if (end < state->jit_blacklist[index].m68k_end) {
                end = state->jit_blacklist[index].m68k_end;
            }
            found = 1;
            break;
        }
    }
    /* Otherwise, add this as a new entry; if there are no free slots,
     * evict the oldest entry */
    if (!found) {
        int oldest = 0;
        for (index = 0; index < Q68_JIT_BLACKLIST_SIZE; index++) {
            if (state->jit_blacklist[index].m68k_start == 0) {
                found = 1;
                break;
            } else if (TIMESTAMP_COMPARE(state->jit_timestamp,
                           state->jit_blacklist[index].timestamp,
                           state->jit_blacklist[oldest].timestamp) < 0) {
                oldest = index;
            }
        }
        if (!found) {
            index = oldest;
        }
    }
    state->jit_blacklist[index].m68k_start = start;
    state->jit_blacklist[index].m68k_end = end;
    state->jit_blacklist[index].timestamp = state->jit_timestamp;
}

/*************************************************************************/
/************************ Local helper functions *************************/
/*************************************************************************/

/**
 * translate_insn:  Translate a single 68000 instruction.
 *
 * [Parameters]
 *     state: Processor state block
 *     entry: Q68JitEntry structure pointer
 * [Return value]
 *     Nonzero if the instruction marks the end of the block, else zero
 */
static int translate_insn(Q68State *state, Q68JitEntry *entry)
{
    /* See if there are any branches to this address we can update */
    int i;
    for (i = 0; i < lenof(unres_branches); i++) {
        if (unres_branches[i].m68k_target == jit_PC) {
            JIT_FIXUP_BRANCH(entry, unres_branches[i].native_offset,
                             current_entry->native_length);
            unres_branches[i].m68k_target = 0;
        }
    }

    /* Update the branch target cache with this address */
    btcache[btcache_index].m68k_address = jit_PC;
    btcache[btcache_index].native_offset = current_entry->native_length;
    btcache_index = (btcache_index + 1) % lenof(btcache);

    /* Fetch the next instruction */
    const unsigned int opcode = IFETCH(state);
    state->current_PC = jit_PC;

    /* Emit a cycle count check if appropriate */
#ifdef Q68_JIT_LOOSE_TIMING
    if ((opcode & 0xFF00) == 0x6100  // Bcc
     || (opcode & 0xF0F8) == 0x50C8  // DBcc
     || (opcode & 0xFFF0) == 0x4E40  // TRAP
     || (opcode & 0xFF80) == 0x4E80  // JSR/JMP
     ||  opcode           == 0x4E72  // STOP
     ||  opcode           == 0x4E73  // RTE
     ||  opcode           == 0x4E75  // RTS
     ||  opcode           == 0x4E77  // RTR
# ifdef Q68_M68K_TESTER  // Define when linking with m68k-tester
     ||  opcode           == 0x7100  // m68k-tester abort opcode
# endif
    ) {
#endif
        JIT_EMIT_CHECK_CYCLES(current_entry);
#ifdef Q68_JIT_LOOSE_TIMING
    }
#endif

    /* Add a trace call if we're tracing */
#ifdef Q68_TRACE
    JIT_EMIT_TRACE(current_entry);
#endif

    /* Translate the instruction itself and update the 68000 PC */
    PC_updated = 0;
    const unsigned int index = (opcode>>9 & 0x78) | (opcode>>6 & 0x07);
    int done = (*opcode_table[index])(state, opcode);
    /* Only update the PC if the function didn't do so itself (see e.g.
     * op_imm() to SR), but check the jit_abort flag unless we're
     * terminating anyway */
    if (!done) {
        if (!PC_updated) {
            const int32_t advance = jit_PC - (state->current_PC - 2);
            JIT_EMIT_ADVANCE_PC_CHECK_ABORT(current_entry, advance);
        } else {
            JIT_EMIT_CHECK_ABORT(current_entry);
        }
    } else {
        if (!PC_updated) {
            advance_PC(state);
        }
    }

    return done;
}

/*************************************************************************/

/**
 * clear_entry:  Clear a specific entry from the JIT table, freeing the
 * native code buffer and unlinking the entry from its references.
 *
 * [Parameters]
 *     state: Processor state block
 *     entry: Q68JitEntry structure pointer
 * [Return value]
 *     None
 */
static void clear_entry(Q68State *state, Q68JitEntry *entry)
{
    /* Clear the entry out of the call stack first */
    int i;
    for (i = 0; i < Q68_JIT_CALLSTACK_SIZE; i++) {
        if (state->jit_callstack[i].return_entry == entry) {
            state->jit_callstack[i].return_PC = 0;
        }
    }

    /* Free the native code */
    state->jit_total_data -= entry->native_size;
    state->free_func(entry->native_code);
    entry->native_code = NULL;

    /* Clear the entry from the table and hash chain */
    if (entry->next) {
        entry->next->prev = entry->prev;
    }
    if (entry->prev) {
        entry->prev->next = entry->next;
    } else {
        state->jit_hashchain[JIT_HASH(entry->m68k_start)] = entry->next;
    }

    /* Mark the entry as free */
    entry->m68k_start = 0;
}

/*-----------------------------------------------------------------------*/

/**
 * clear_oldest_entry:  Clear the oldest entry from the JIT table.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
static void clear_oldest_entry(Q68State *state)
{
    int oldest = -1;
    int index;
    for (index = 0; index < Q68_JIT_TABLE_SIZE; index++) {
        if (state->jit_table[index].m68k_start == 0) {
            continue;
        }
        if (oldest < 0
         || TIMESTAMP_COMPARE(state->jit_timestamp,
                              state->jit_table[index].timestamp,
                              state->jit_table[oldest].timestamp) < 0) {
            oldest = index;
        }
    }
    if (LIKELY(oldest >= 0)) {
        clear_entry(state, &state->jit_table[oldest]);
    } else {
        DMSG("Tried to clear oldest entry from an empty table!");
        /* Set the total size to zero, just in case something weird happened */
        state->jit_total_data = 0;
    }
}

/*************************************************************************/

/**
 * expand_buffer:  Expands the native code buffer in the given JIT entry by
 * Q68_JIT_BLOCK_EXPAND_SIZE.
 *
 * [Parameters]
 *     entry: Q68JitEntry structure pointer
 * [Return value]
 *     Nonzero on success, zero on failure (out of memory)
 */
static int expand_buffer(Q68JitEntry *entry)
{
    const uint32_t newsize = entry->native_size + Q68_JIT_BLOCK_EXPAND_SIZE;
    void *newptr = entry->state->realloc_func(entry->native_code, newsize);
    if (!newptr) {
        DMSG("Out of memory");
        return 0;
    }
    entry->native_code = newptr;
    entry->native_size = newsize;
    return 1;
}

/*************************************************************************/

/**
 * btcache_lookup:  Search the branch target cache for the given 68000
 * address.
 *
 * [Parameters]
 *     address: 68000 address to search for
 * [Return value]
 *     Corresponding byte offset into current_entry->native_code, or -1 if
 *     the address could not be found
 */
static int32_t btcache_lookup(uint32_t address)
{
    /* Search backwards from the current instruction so we can handle short
     * loops quickly; note that btcache_index is now pointing to where the
     * _next_ instruction will go */
    const int current = (btcache_index + (lenof(btcache)-1)) % lenof(btcache);
    int index = current;
    do {
        if (btcache[index].m68k_address == address) {
            return btcache[index].native_offset;
        }
        index = (index + (lenof(btcache)-1)) % lenof(btcache);
    } while (index != current);
    return -1;
}

/*-----------------------------------------------------------------------*/

/**
 * record_unresolved_branch:  Record the given branch target and native
 * offset in an empty slot in the unresolved branch table.  If there are
 * no empty slots, purge the oldest (lowest native offset) entry.
 *
 * [Parameters]
 *       m68k_target: Branch target address in 68000 address space
 *     native_offset: Offset of branch to update in native code
 * [Return value]
 *     None
 */
static void record_unresolved_branch(uint32_t m68k_target,
                                     uint32_t native_offset)
{
    int oldest = 0;
    int i;
    for (i = 0; i < lenof(unres_branches); i++) {
        if (unres_branches[i].m68k_target == 0) {
            oldest = i;
            break;
        } else if (unres_branches[i].native_offset
                   < unres_branches[oldest].native_offset) {
            oldest = i;
        }
    }
    unres_branches[oldest].m68k_target   = m68k_target;
    unres_branches[oldest].native_offset = native_offset;
}

/*************************************************************************/

/**
 * JIT_EMIT_TEST_cc:  Emit the appropriate TEST_* operation depending on
 * the specified condition.
 *
 * [Parameters]
 *      cond: Condition code
 *     entry: Q68JitEntry structure pointer
 */
static inline void JIT_EMIT_TEST_cc(int cond, Q68JitEntry *entry)
{
    switch ((cond)) {
        case COND_T:  JIT_EMIT_TEST_T (entry); break;
        case COND_F:  JIT_EMIT_TEST_F (entry); break;
        case COND_HI: JIT_EMIT_TEST_HI(entry); break;
        case COND_LS: JIT_EMIT_TEST_LS(entry); break;
        case COND_CC: JIT_EMIT_TEST_CC(entry); break;
        case COND_CS: JIT_EMIT_TEST_CS(entry); break;
        case COND_NE: JIT_EMIT_TEST_NE(entry); break;
        case COND_EQ: JIT_EMIT_TEST_EQ(entry); break;
        case COND_VC: JIT_EMIT_TEST_VC(entry); break;
        case COND_VS: JIT_EMIT_TEST_VS(entry); break;
        case COND_PL: JIT_EMIT_TEST_PL(entry); break;
        case COND_MI: JIT_EMIT_TEST_MI(entry); break;
        case COND_GE: JIT_EMIT_TEST_GE(entry); break;
        case COND_LT: JIT_EMIT_TEST_LT(entry); break;
        case COND_GT: JIT_EMIT_TEST_GT(entry); break;
        case COND_LE: JIT_EMIT_TEST_LE(entry); break;
    }
}

/*************************************************************************/

/**
 * advance_PC:  Emit JIT code to advance the PC to the location indicated
 * by jit_PC, and set the PC_updated flag so that the PC is not advanced
 * again after the current instruction has been processed.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
static void advance_PC(Q68State *state)
{
    JIT_EMIT_ADVANCE_PC(current_entry, jit_PC - (state->current_PC - 2));
    PC_updated = 1;
}

/*************************************************************************/

/**
 * raise_exception:  Emit JIT code to raise an exception.
 *
 * [Parameters]
 *     state: Processor state block
 *       num: Exception number
 * [Return value]
 *     Nonzero (end translated block)
 */
static int raise_exception(Q68State *state, uint8_t num)
{
    JIT_EMIT_EXCEPTION(current_entry, num);
    return 1;
}

/*************************************************************************/

/**
 * op_ill:  Emit JIT code to handle a generic illegal opcode.
 *
 * [Parameters]
 *      state: Processor state block
 *     opcode: Instruction opcode
 * [Return value]
 *     Nonzero (end translated block)
 */
static inline int op_ill(Q68State *state, uint32_t opcode)
{
    return raise_exception(state, EX_ILLEGAL_INSTRUCTION);
}

/*************************************************************************/
/*************************************************************************/

#ifdef Q68_JIT_OPTIMIZE_FLAGS

/**
 * cc_needed:  Return whether any condition code outputs are required from
 * the current instruction, based on the instruction located at jit_PC.
 *
 * This routine assumes that the current and following instructions are
 * valid ones; certain illegal forms of instructions may be incorrectly
 * treated as valid and thus cause an incorrect result.
 *
 * [Parameters]
 *      state: Processor state block
 *     opcode: Opcode of the instruction currently being processed
 * [Return value]
 *     Nonzero if condition code outputs are required, zero otherwise
 */
static unsigned int cc_needed(Q68State *state, uint16_t opcode)
{
    const uint16_t next_opcode = READU16(state, jit_PC);
    const unsigned int this_output = cc_info(opcode) & 0x1F;
    const unsigned int next_input = (cc_info(next_opcode) >> 8) & 0x1F;
    const unsigned int next_output = cc_info(next_opcode) & 0x1F;
    /* A condition code output from this instruction is known to be
     * unneeded if the following instruction (1) does not use that
     * condition code as input and (2) also outputs to the same condition
     * code.  We want to know whether there are any condition codes in the
     * current instruction's output set for which these conditions are
     * _not_ fulfilled. */
    return this_output & ~(~next_input & next_output);
}

/*************************************************************************/

/**
 * cc_info:  Return a bitmask of which condition codes are used and which
 * are modified by the given opcode.
 *
 * [Parameters]
 *     opcode: Opcode to check
 * [Return value]
 *     Bits 12-8: Which of XNZVC are used as input by the given opcode
 *     Bits  4-0: Which of XNZVC are modified by the given opcode
 */
static unsigned int cc_info(uint16_t opcode)
{
    const unsigned int INPUT_XNZVC  = 0x1F00;
    const unsigned int INPUT_XZ     = 0x1400;
    const unsigned int INPUT_X      = 0x1000;
    const unsigned int INPUT_N      = 0x0800;
    const unsigned int INPUT_V      = 0x0200;
    const unsigned int INPUT_NONE   = 0x0000;
    const unsigned int OUTPUT_XNZVC = 0x001F;
    const unsigned int OUTPUT_XZC   = 0x0015;
    const unsigned int OUTPUT_NZVC  = 0x000F;
    const unsigned int OUTPUT_N     = 0x0008;
    const unsigned int OUTPUT_Z     = 0x0004;
    const unsigned int OUTPUT_NONE  = 0x0000;
    static const unsigned int cond_inputs[] = {
        [COND_T ] = 0x0000,
        [COND_F ] = 0x0000,
        [COND_HI] = 0x0500,
        [COND_LS] = 0x0500,
        [COND_CC] = 0x0100,
        [COND_CS] = 0x0100,
        [COND_NE] = 0x0400,
        [COND_EQ] = 0x0400,
        [COND_VC] = 0x0200,
        [COND_VS] = 0x0200,
        [COND_PL] = 0x0800,
        [COND_MI] = 0x0800,
        [COND_GE] = 0x0A00,
        [COND_LT] = 0x0A00,
        [COND_GT] = 0x0E00,
        [COND_LE] = 0x0E00,
    };

    switch (opcode>>12) {

      case 0x0:
        if (opcode & 0x100) {
            if ((opcode>>3 & 7) == 1) {  // MOVEP
                return INPUT_NONE | OUTPUT_NONE;
            } else {  // BTST, etc. (dynamic)
                return INPUT_NONE | OUTPUT_Z;
            }
        } else if ((opcode>>6 & 3) == 3) {  // Illegal (size==3)
            return 0;
        } else {
            switch (opcode>>9 & 7) {
              case 0:  // ORI
                if ((opcode & 0xBF) == 0x3C) {  // ORI to CCR/SR
                    return INPUT_XNZVC | OUTPUT_XNZVC;
                } else {
                    return INPUT_NONE | OUTPUT_NZVC;
                }
              case 1:  // ANDI
                if ((opcode & 0xBF) == 0x3C) {  // ANDI to CCR/SR
                    return INPUT_XNZVC | OUTPUT_XNZVC;
                } else {
                    return INPUT_NONE | OUTPUT_NZVC;
                }
              case 2:  // SUBI
                return INPUT_NONE | OUTPUT_XNZVC;
              case 3:  // ADDI
                return INPUT_NONE | OUTPUT_XNZVC;
              case 4:  // BTST, etc. (static)
                return INPUT_NONE | OUTPUT_Z;
              case 5:  // EORI
                if ((opcode & 0xBF) == 0x3C) {  // EORI to CCR/SR
                    return INPUT_XNZVC | OUTPUT_XNZVC;
                } else {
                    return INPUT_NONE | OUTPUT_NZVC;
                }
              case 6:  // CMPI
                return INPUT_NONE | OUTPUT_NZVC;
              case 7:  // Illegal
                return 0;
            }
        }

      case 0x1:
      case 0x2:
      case 0x3:
        if ((opcode>>6 & 7) == 1) {  // MOVEA.[LW]
            return INPUT_NONE | OUTPUT_NONE;
        } else {  // MOVE.[BLW]
            return INPUT_NONE | OUTPUT_NZVC;
        }

      case 0x4:
        if (opcode & 0x0100) {
            switch (opcode>>6 & 3) {
              case 0:  // Illegal
              case 1:  // Illegal
                return 0;
              case 2:  // CHK
                /* N is unmodified if no exception occurs, so treat as input */
                return INPUT_N | OUTPUT_N;
              case 3:  // LEA
                return INPUT_NONE | OUTPUT_NONE;
            }
        } else {
            switch (opcode & 0x0EC0) {
              case 0x0000:  // NEGX.B
              case 0x0040:  // NEGX.W
              case 0x0080:  // NEGX.L
                return INPUT_XZ | OUTPUT_XNZVC;
              case 0x00C0:  // MOVE from SR
                return INPUT_XNZVC | OUTPUT_NONE;
              case 0x0200:  // CLR.B
              case 0x0240:  // CLR.W
              case 0x0280:  // CLR.L
                return INPUT_NONE | OUTPUT_NZVC;
              case 0x02C0:  // Illegal
                return 0;
              case 0x0400:  // NEG.B
              case 0x0440:  // NEG.W
              case 0x0480:  // NEG.L
                return INPUT_NONE | OUTPUT_XNZVC;
              case 0x04C0:  // MOVE to CCR
                return INPUT_NONE | OUTPUT_XNZVC;
              case 0x0600:  // NOT.B
              case 0x0640:  // NOT.W
              case 0x0680:  // NOT.L
                return INPUT_NONE | OUTPUT_NZVC;
              case 0x06C0:  // MOVE to SR
                return INPUT_NONE | OUTPUT_XNZVC;
              case 0x0800:  // NBCD
                return INPUT_XZ | OUTPUT_XZC;
              case 0x0840:  // PEA
                if ((opcode>>3 & 7) == 0) {  // SWAP.L
                    return INPUT_NONE | OUTPUT_NZVC;
                } else {
                    return INPUT_NONE | OUTPUT_NONE;
                }
              case 0x0880:  // MOVEM.W reglist,<ea>
              case 0x08C0:  // MOVEM.L reglist,<ea>
                if ((opcode>>3 & 7) == 0) {  // EXT.*
                    return INPUT_NONE | OUTPUT_NZVC;
                } else {
                    return INPUT_NONE | OUTPUT_NONE;
                }
              case 0x0A00:  // TST.B
              case 0x0A40:  // TST.W
              case 0x0A80:  // TST.L
              case 0x0AC0:  // TAS
                return INPUT_NONE | OUTPUT_NZVC;
              case 0x0C00:  // TST.B
                return 0;
              case 0x0C40:  // Miscellaneous
                switch (opcode>>3 & 7) {
                  case 0:  // TRAP #0-7
                  case 1:  // TRAP #8-15
                  case 2:  // LINK
                  case 3:  // UNLK
                  case 4:  // MOVE from USP
                  case 5:  // MOVE to USP
                    return INPUT_NONE | OUTPUT_NONE;
                  case 6:  // Miscellaneous
                    switch (opcode & 7) {
                      case 0:  // RESET
                      case 1:  // NOP
                        return INPUT_NONE | OUTPUT_NONE;
                      case 2:  // STOP
                      case 3:  // RTE
                        return INPUT_NONE | OUTPUT_XNZVC;
                      case 4:  // Illegal
                        return 0;
                      case 5:  // RTS
                        return INPUT_NONE | OUTPUT_NONE;
                      case 6:  // TRAPV
                        return INPUT_V | OUTPUT_NONE;
                      case 7:  // RTR
                        return INPUT_NONE | OUTPUT_XNZVC;
                    }
                  case 7:  // Illegal
                    return 0;
                }
              case 0x0C80:  // MOVEM.W <ea>,reglist
              case 0x0CC0:  // MOVEM.L <ea>,reglist
                return INPUT_NONE | OUTPUT_NONE;
              case 0x0E00:  // Illegal
              case 0x0E40:  // Illegal
                return 0;
              case 0x0E80:  // JSR
              case 0x0EC0:  // JMP
                return INPUT_NONE | OUTPUT_NONE;
            }
        }

      case 0x5:
        if ((opcode>>6 & 3) == 3) {  // Scc/DBcc
            return cond_inputs[opcode>>8 & 0xF] | OUTPUT_NONE;
        } else {  // ADDQ/SUBQ
            if ((opcode>>3 & 7) == 1) {  // Address register target
                return INPUT_NONE | OUTPUT_NONE;
            } else {  // Other target
                return INPUT_NONE | OUTPUT_XNZVC;
            }
        }

      case 0x6:
        /* Bcc/BSR */
        return cond_inputs[opcode>>8 & 0xF] | OUTPUT_NONE;

      case 0x7:
        if (opcode & 0x0100) {  // Illegal
            return 0;
        } else {  // MOVEQ
            return INPUT_NONE | OUTPUT_NZVC;
        }

      case 0x8:
        if ((opcode>>6 & 3) == 3) {  // MULS/MULU
            return INPUT_NONE | OUTPUT_NZVC;
        } else if ((opcode & 0x01F0) == 0x0100) {  // SBCD
            return INPUT_XZ | OUTPUT_XZC;
        } else {  // OR
            return INPUT_NONE | OUTPUT_NZVC;
        }

      case 0x9:
        if ((opcode>>6 & 3) == 3) {  // SUBA
            return INPUT_NONE | OUTPUT_NONE;
        } else if ((opcode & 0x0130) == 0x0100) {  // SUBX
            return INPUT_XZ | OUTPUT_XNZVC;
        } else {  // SUB
            return INPUT_NONE | OUTPUT_XNZVC;
        }

      case 0xA:
        /* Nothing here */
        return 0;

      case 0xB:
        /* CMP/CMPA/CMPM/EOR */
        return INPUT_NONE | OUTPUT_NZVC;

      case 0xC:
        if ((opcode>>6 & 3) == 3) {  // DIVS/DIVD
            return INPUT_NONE | OUTPUT_NZVC;
        } else if ((opcode & 0x01F0) == 0x0100) {  // ABCD
            return INPUT_XZ | OUTPUT_XZC;
        } else if ((opcode & 0x0130) == 0x0100) {  // EXG
            return INPUT_NONE | OUTPUT_NONE;
        } else {  // AND
            return INPUT_NONE | OUTPUT_NZVC;
        }

      case 0xD:
        if ((opcode>>6 & 3) == 3) {  // ADDA
            return INPUT_NONE | OUTPUT_NONE;
        } else if ((opcode & 0x0130) == 0x0100) {  // ADDX
            return INPUT_XZ | OUTPUT_XNZVC;
        } else {  // ADD
            return INPUT_NONE | OUTPUT_XNZVC;
        }

      case 0xE:
        /* Shift/rotate */
        return INPUT_X | OUTPUT_XNZVC;

      case 0xF:
        /* Nothing here */
        return 0;

    }  // switch (opcode>>12)

    return 0;  // Should be unreachable, but just for safety
}

#endif  // Q68_JIT_OPTIMIZE_FLAGS

/*************************************************************************/
/*************************************************************************/

/**
 * ea_resolve:  Emit JIT code to resolve the address for the
 * memory-reference EA indicated by opcode[5:0] and store it in
 * state->ea_addr.  Behavior is undefined if the EA is a direct register
 * reference.
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
        JIT_EMIT_RESOLVE_INDIRECT(current_entry, (8+reg)*4);
        break;
      case EA_POSTINCREMENT:
        if (bytes == 1 && reg == 7) {  // A7 must stay even
            JIT_EMIT_RESOLVE_POSTINC_A7_B(current_entry);
        } else {
            JIT_EMIT_RESOLVE_POSTINC(current_entry, (8+reg)*4, bytes);
        }
        break;
      case EA_PREDECREMENT:
        if (access_type == ACCESS_WRITE) {
            /* 2-cycle penalty not applied to write-only accesses
             * (MOVE and MOVEM) */
            cycles -= 2;
        }
        if (bytes == 1 && reg == 7) {  // A7 must stay even
            JIT_EMIT_RESOLVE_PREDEC_A7_B(current_entry);
        } else {
            JIT_EMIT_RESOLVE_PREDEC(current_entry, (8+reg)*4, bytes);
        }
        break;
      case EA_DISPLACEMENT:
        JIT_EMIT_RESOLVE_DISP(current_entry, (8+reg)*4, (int16_t)IFETCH(state));
        break;
      case EA_INDEX: {
        const uint16_t ext = IFETCH(state);
        const unsigned int ireg = ext >> 12;  // 0..15
        const int8_t disp = (int8_t)ext;
        if (ext & 0x0800) {
            JIT_EMIT_RESOLVE_INDEX_L(current_entry, (8+reg)*4, ireg*4, disp);
        } else {
            JIT_EMIT_RESOLVE_INDEX_W(current_entry, (8+reg)*4, ireg*4, disp);
        }
        break;
      }
      default:  /* case EA_MISC */
        switch (reg) {
          case EA_MISC_ABSOLUTE_W:
            cycles += 8;
            JIT_EMIT_RESOLVE_ABSOLUTE(current_entry, (int16_t)IFETCH(state));
            break;
          case EA_MISC_ABSOLUTE_L: {
            cycles += 12;
            uint32_t addr = IFETCH(state) << 16;
            addr |= (uint16_t)IFETCH(state);
            JIT_EMIT_RESOLVE_ABSOLUTE(current_entry, addr);
            break;
          }
          case EA_MISC_PCREL:
            if (access_type != ACCESS_READ) {
                return -1;
            } else {
                cycles += 8;
                JIT_EMIT_RESOLVE_ABSOLUTE(
                    current_entry, state->current_PC + (int16_t)IFETCH(state)
                );
            }
            break;
          case EA_MISC_PCREL_INDEX:
            if (access_type != ACCESS_READ) {
                return -1;
            } else {
                cycles += 10;
                const uint16_t ext = IFETCH(state);
                const unsigned int ireg = ext >> 12;  // 0..15
                const int32_t disp = (int32_t)((int8_t)ext);
                if (ext & 0x0800) {
                    JIT_EMIT_RESOLVE_ABS_INDEX_L(
                        current_entry, state->current_PC + disp, ireg*4
                    );
                } else {
                    JIT_EMIT_RESOLVE_ABS_INDEX_W(
                        current_entry, state->current_PC + disp, ireg*4
                    );
                }
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
 * ea_get:  Emit JIT code to read an unsigned value from the EA indicated
 * by opcode[5:0] and use it as either the first or the second operand to
 * an operation, as specified by the op_num parameter.
 *
 * If the EA selector is invalid for the access size and mode, an illegal
 * instruction exception is raised, and the error is indicated by a
 * negative value returned in *cycles_ret.
 *
 * [Parameters]
 *          state: Processor state block
 *         opcode: Instruction opcode
 *           size: Access size (SIZE_*)
 *         is_rmw: Nonzero if the operand will be modified and written back
 *     cycles_ret: Pointer to variable to receive clock cycles used
 *                     (negative indicates an illegal EA)
 *         op_num: Which operand to read the value into (1 or 2)
 * [Return value]
 *     None
 */
static void ea_get(Q68State *state, uint32_t opcode, int size,
                   int is_rmw, int *cycles_ret, int op_num)
{
    switch (EA_MODE(opcode)) {

      case EA_DATA_REG:
        *cycles_ret = 0;
        if (op_num == 1) {
            JIT_EMIT_GET_OP1_REGISTER(current_entry, EA_REG(opcode) * 4);
        } else {
            JIT_EMIT_GET_OP2_REGISTER(current_entry, EA_REG(opcode) * 4);
        }
        break;

      case EA_ADDRESS_REG:
        *cycles_ret = 0;
        if (size == SIZE_B) {
            /* An.b not permitted */
            raise_exception(state, EX_ILLEGAL_INSTRUCTION);
            *cycles_ret = -1;
            return;
        } else {
            if (op_num == 1) {
                JIT_EMIT_GET_OP1_REGISTER(current_entry,
                                          (8 + EA_REG(opcode)) * 4);
            } else {
                JIT_EMIT_GET_OP2_REGISTER(current_entry,
                                          (8 + EA_REG(opcode)) * 4);
            }
        }
        break;

      case EA_MISC:
        if (EA_REG(opcode) == EA_MISC_IMMEDIATE) {
            if (is_rmw) {
                raise_exception(state, EX_ILLEGAL_INSTRUCTION);
                *cycles_ret = -1;
                return;
            } else {
                *cycles_ret = (size==SIZE_L ? 8 : 4);
                uint32_t val;
                val = IFETCH(state);
                if (size == SIZE_B) {
                    val &= 0xFF;
                } else if (size == SIZE_L) {
                    val <<= 16;
                    val |= (uint16_t)IFETCH(state);
                }
                if (op_num == 1) {
                    JIT_EMIT_GET_OP1_IMMEDIATE(current_entry, val);
                } else {
                    JIT_EMIT_GET_OP1_IMMEDIATE(current_entry, val);
                }
            }
            break;
        }
        /* else fall through */

      default:
        *cycles_ret = ea_resolve(state, opcode, size,
                                 is_rmw ? ACCESS_MODIFY : ACCESS_READ);
        if (*cycles_ret < 0) {
            raise_exception(state, EX_ILLEGAL_INSTRUCTION);
            return;
        }
        if (size == SIZE_B) {
            if (op_num == 1) {
                JIT_EMIT_GET_OP1_EA_B(current_entry);
            } else {
                JIT_EMIT_GET_OP2_EA_B(current_entry);
            }
        } else if (size == SIZE_W) {
#ifndef Q68_DISABLE_ADDRESS_ERROR
            JIT_EMIT_CHECK_ALIGNED_EA(
                current_entry, opcode,
                FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_READ
            );
#endif
            if (op_num == 1) {
                JIT_EMIT_GET_OP1_EA_W(current_entry);
            } else {
                JIT_EMIT_GET_OP2_EA_W(current_entry);
            }
        } else {  // size == SIZE_L
#ifndef Q68_DISABLE_ADDRESS_ERROR
            JIT_EMIT_CHECK_ALIGNED_EA(
                current_entry, opcode,
                FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_READ
            );
#endif
            if (op_num == 1) {
                JIT_EMIT_GET_OP1_EA_L(current_entry);
            } else {
                JIT_EMIT_GET_OP2_EA_L(current_entry);
            }
        }
        break;

    }  // switch (EA_MODE(opcode))
}

/*-----------------------------------------------------------------------*/

/**
 * ea_set:  Emit JIT code to update a value at the EA indicated by
 * opcode[5:0].  If the EA is a memory reference, uses the previously
 * resolved address in state->ea_addr rather than resolving the address
 * again.  Behavior is undefined if the previous ea_resolve() or ea_get()
 * failed (or if no previous call was made).
 *
 * [Parameters]
 *      state: Processor state block
 *     opcode: Instruction opcode
 *       size: Access size (SIZE_*)
 * [Return value]
 *     None
 */
static void ea_set(Q68State *state, uint32_t opcode, int size)
{
    switch (EA_MODE(opcode)) {
      case EA_DATA_REG:
        if (size == SIZE_B) {
            JIT_EMIT_SET_REGISTER_B(current_entry, EA_REG(opcode) * 4);
        } else if (size == SIZE_W) {
            JIT_EMIT_SET_REGISTER_W(current_entry, EA_REG(opcode) * 4);
        } else {  // size == SIZE_L
            JIT_EMIT_SET_REGISTER_L(current_entry, EA_REG(opcode) * 4);
        }
        return;
      case EA_ADDRESS_REG:
        if (size == SIZE_W) {
            JIT_EMIT_SET_AREG_W(current_entry, (8 + EA_REG(opcode)) * 4);
        } else {  // size == SIZE_L
            JIT_EMIT_SET_REGISTER_L(current_entry, (8 + EA_REG(opcode)) * 4);
        }
        return;
      default: {
        if (size == SIZE_B) {
            JIT_EMIT_SET_EA_B(current_entry);
        } else if (size == SIZE_W) {
#ifndef Q68_DISABLE_ADDRESS_ERROR
            JIT_EMIT_CHECK_ALIGNED_EA(
                current_entry, opcode,
                FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_WRITE
            );
#endif
            JIT_EMIT_SET_EA_W(current_entry);
        } else {  // size == SIZE_L
#ifndef Q68_DISABLE_ADDRESS_ERROR
            JIT_EMIT_CHECK_ALIGNED_EA(
                current_entry, opcode,
                FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_WRITE
            );
#endif
            JIT_EMIT_SET_EA_L(current_entry);
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

    /* Fetch the immediate value */
    int cycles_dummy;
    ea_get(state, EA_MISC<<3 | EA_MISC_IMMEDIATE, size, 0, &cycles_dummy, 1);

    /* Fetch the EA operand (which may be SR or CCR) */
    int use_SR;
    int cycles;
    if ((aluop==OR || aluop==AND || aluop==EOR) && (opcode & 0x3F) == 0x3C) {
        /* xxxI #imm,SR (or CCR) use the otherwise-invalid form of an
         * immediate value destination */
        use_SR = 1;
        cycles = 8;  // Total instruction time is 20 cycles
        switch (size) {
          case SIZE_B:
            JIT_EMIT_GET_OP2_CCR(current_entry);
            break;
          case SIZE_W:
            JIT_EMIT_CHECK_SUPER(current_entry);
            JIT_EMIT_GET_OP2_SR(current_entry);
            break;
          default:
            return op_ill(state, opcode);
        }
    } else {
        use_SR = 0;
        ea_get(state, opcode, size, 1, &cycles, 2);
        if (cycles < 0) {
            return 1;
        }
    }

    /* Check whether we need to output condition codes */
    const int do_cc = cc_needed(state, opcode);

    /* Perform the operation */
    switch (aluop) {
        case OR:  if (size == SIZE_B) {
                      JIT_EMIT_OR_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_OR_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_OR_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
                  }
                  break;
        case AND: if (size == SIZE_B) {
                      JIT_EMIT_AND_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_AND_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_AND_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
                  }
                  break;
        case EOR: if (size == SIZE_B) {
                      JIT_EMIT_EOR_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_EOR_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_EOR_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
                  }
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
                  if (size == SIZE_B) {
                      JIT_EMIT_SUB_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_CMP_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_SUB_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_CMP_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_SUB_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_CMP_L(current_entry);
                  }
                  break;
        case SUB: if (size == SIZE_B) {
                      JIT_EMIT_SUB_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUB_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_SUB_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUB_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_SUB_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUB_L(current_entry);
                  }
                  break;
        default:  // case ADD
                  if (size == SIZE_B) {
                      JIT_EMIT_ADD_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_ADD_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_ADD_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_ADD_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_ADD_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_ADD_L(current_entry);
                  }
                  break;
    }

    /* Update the cycle counter (and PC) before writing the result, in case
     * a change to SR triggers an interrupt */
    cycles += (size==SIZE_L ? 16 : 8);
    cycles += (EA_MODE(opcode) == EA_DATA_REG ? 0 : 4);
    JIT_EMIT_ADD_CYCLES(current_entry, cycles);
    advance_PC(state);

    /* Update the EA operand (if not CMPI) */
    if (aluop != CMP) {
        if (use_SR) {
            if (size == SIZE_B) {
                JIT_EMIT_SET_CCR(current_entry);
            } else {
                JIT_EMIT_SET_SR(current_entry);
            }
        } else {
            ea_set(state, opcode, size);
        }
    }

    /* All done */
    return 0;
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
    if (opcode & 0x0100) {
        /* Bit number in register */
        INSN_GET_REG;
        JIT_EMIT_GET_OP1_REGISTER(current_entry, reg*4);
        cycles = 0;
    } else {
        unsigned int bitnum = IFETCH(state);
        JIT_EMIT_GET_OP1_IMMEDIATE(current_entry, bitnum);
        cycles = 4;
    }

    /* EA operand is 32 bits when coming from a register, 8 when from memory */
    int size = (EA_MODE(opcode)==EA_DATA_REG ? SIZE_L : SIZE_B);
    int cycles_tmp;
    ea_get(state, opcode, size, 1, &cycles_tmp, 2);
    if (cycles_tmp < 0) {
        return 1;
    }
    cycles += cycles_tmp;
    if (size == SIZE_L && (op == BCLR || op == BTST)) {
        cycles += 2;
    }

    /* Perform the operation: first test the bit, then (for non-BTST cases)
     * twiddle it as appropriate.  All size-related checking is performed
     * in BTST, so the remaining operations are unsized. */
    if (size == SIZE_B) {
        JIT_EMIT_BTST_B(current_entry);
    } else {  // size == SIZE_L
        JIT_EMIT_BTST_L(current_entry);
    }
    switch (op) {
      default:   break;  // case BTST: nothing to do
      case BCHG: JIT_EMIT_BCHG(current_entry); break;
      case BCLR: JIT_EMIT_BCLR(current_entry); break;
      case BSET: JIT_EMIT_BSET(current_entry); break;
    }

    /* Update EA operand (but not for BTST) */
    if (op != BTST) {
        ea_set(state, opcode, size);
    }

    /* Update cycle counter; note that the times for BCHG.L, BCLR.L, and
     * BSET.L are maximums (though how they vary is undocumented) */
    JIT_EMIT_ADD_CYCLES(current_entry, (op==BTST ? 4 : 8) + cycles);

    return 0;
}

/*************************************************************************/

/**
 * opMOVE:  MOVE.[bwl] instruction (format {01,10,11}xx xxxx xxxx xxxx).
 */
static int opMOVE(Q68State *state, uint32_t opcode)
{
    const int size = (opcode>>12==1 ? SIZE_B : opcode>>12==2 ? SIZE_L : SIZE_W);

    int cycles_src;
    ea_get(state, opcode, size, 0, &cycles_src, 1);
    if (cycles_src < 0) {
        return 1;
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

    /* Copy the operand to the result and set flags (if needed) */
    const int do_cc = cc_needed(state, opcode);
    if (EA_MODE(dummy_opcode) == EA_ADDRESS_REG) {
        if (size == SIZE_W) {
            JIT_EMIT_EXT_L(current_entry);
        } else {  // size == SIZE_L
            JIT_EMIT_MOVE_L(current_entry);
        }
    } else {
        if (size == SIZE_B) {
            JIT_EMIT_MOVE_B(current_entry);
            if (do_cc) JIT_EMIT_SETCC_LOGIC_B(current_entry);
        } else if (size == SIZE_W) {
            JIT_EMIT_MOVE_W(current_entry);
            if (do_cc) JIT_EMIT_SETCC_LOGIC_W(current_entry);
        } else {  // size == SIZE_L
            JIT_EMIT_MOVE_L(current_entry);
            if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
        }
    }

    /* Update the destination EA and cycle count */
    ea_set(state, dummy_opcode, size);
    JIT_EMIT_ADD_CYCLES(current_entry, 4 + cycles_src + cycles_dest);

    return 0;
}

/*************************************************************************/

/**
 * op4xxx:  Miscellaneous instructions (format 0100 xxx0 xxxx xxxx).
 */
static int op4xxx(Q68State *state, uint32_t opcode)
{
    const unsigned int index = (opcode>>7 & 0x1C) | (opcode>>6 & 3);
    return (*opcode_4xxx_table[index])(state, opcode);
}

/*************************************************************************/

/**
 * op_CHK:  CHK instruction (format 0100 rrr1 10xx xxxx).
 */
static int op_CHK(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    JIT_EMIT_GET_OP1_REGISTER(current_entry, reg*4);

    int cycles;
    if (EA_MODE(opcode) == EA_ADDRESS_REG) {
        return op_ill(state, opcode);
    }
    ea_get(state, opcode, SIZE_W, 0, &cycles, 2);
    if (cycles < 0) {
        return 1;
    }

    JIT_EMIT_ADD_CYCLES(current_entry, 10 + cycles);
    /* The JIT code takes care of adding the extra 34 cycles of exception
     * processing if necessary */
    JIT_EMIT_CHK_W(current_entry);
    return 0;
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

    JIT_EMIT_LEA(current_entry, (8+reg)*4);
    JIT_EMIT_ADD_CYCLES(current_entry, cycles);
    return 0;
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

    JIT_EMIT_GET_OP1_IMMEDIATE(current_entry, count);

    int cycles;
    ea_get(state, opcode, size, 1, &cycles, 2);
    if (cycles < 0) {
        return 1;
    }

    const int do_cc = cc_needed(state, opcode);
    if (is_sub) {
        if (EA_MODE(opcode) == EA_ADDRESS_REG) {
            JIT_EMIT_SUB_L(current_entry);
        } else {
            if (size == SIZE_B) {
                JIT_EMIT_SUB_B(current_entry);
                if (do_cc) JIT_EMIT_SETCC_SUB_B(current_entry);
            } else if (size == SIZE_W) {
                JIT_EMIT_SUB_W(current_entry);
                if (do_cc) JIT_EMIT_SETCC_SUB_W(current_entry);
            } else {  // size == SIZE_L
                JIT_EMIT_SUB_L(current_entry);
                if (do_cc) JIT_EMIT_SETCC_SUB_L(current_entry);
            }
        }
    } else {
        if (EA_MODE(opcode) == EA_ADDRESS_REG) {
            JIT_EMIT_ADD_L(current_entry);
        } else {
            if (size == SIZE_B) {
                JIT_EMIT_ADD_B(current_entry);
                if (do_cc) JIT_EMIT_SETCC_ADD_B(current_entry);
            } else if (size == SIZE_W) {
                JIT_EMIT_ADD_W(current_entry);
                if (do_cc) JIT_EMIT_SETCC_ADD_W(current_entry);
            } else {  // size == SIZE_L
                JIT_EMIT_ADD_L(current_entry);
                if (do_cc) JIT_EMIT_SETCC_ADD_L(current_entry);
            }
        }
    }

    ea_set(state, opcode, size);

    cycles += (size==SIZE_L || EA_MODE(opcode) == EA_ADDRESS_REG ? 8 : 4);
    cycles += (EA_MODE(opcode) >= EA_INDIRECT ? 4 : 0);
    JIT_EMIT_ADD_CYCLES(current_entry, cycles);
    return 0;
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
    JIT_EMIT_TEST_cc(cond, current_entry);
    JIT_EMIT_Scc(current_entry);
    if (EA_MODE(opcode) == EA_DATA_REG) {
        /* Scc Dn is a special case */
        JIT_EMIT_ADD_CYCLES_Scc_Dn(current_entry);
    } else {
        JIT_EMIT_ADD_CYCLES(current_entry, 8 + cycles);
    }
    ea_set(state, opcode, SIZE_B);
    return 0;
}

/*-----------------------------------------------------------------------*/

/**
 * op_DBcc:  DBcc instruction (format 0101 cccc 1100 1xxx).
 */
static int opDBcc(Q68State *state, uint32_t opcode)
{
    INSN_GET_COND;
    INSN_GET_REG0;
    INSN_GET_IMM16;
    uint32_t target = state->current_PC + imm16;
    int32_t offset = btcache_lookup(target);
    JIT_EMIT_TEST_cc(cond, current_entry);
    if (offset >= 0) {
        JIT_EMIT_DBcc_native(current_entry, reg0*4, target, offset);
    } else {
        JIT_EMIT_DBcc(current_entry, reg0*4, target);
    }
    return 0;
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
    uint32_t target = state->current_PC + disp;
    if (cond == COND_F) {
        /* BF is really BSR */
#ifndef Q68_DISABLE_ADDRESS_ERROR
        JIT_EMIT_CHECK_ALIGNED_SP(current_entry, opcode,
                                  FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_WRITE);
#endif
        JIT_EMIT_ADD_CYCLES(current_entry, 18);
        advance_PC(state);
        JIT_EMIT_BSR(current_entry, jit_PC, target);
        return 0;
    } else {
        int32_t offset;
#ifdef Q68_OPTIMIZE_IDLE
        /* FIXME: Temporary hack to improve PSP performance */
        if (target == 0x1066
         && ((cond == COND_EQ && state->current_PC - 2 == 0x001092)
          || (cond == COND_PL && state->current_PC - 2 == 0x0010B4))
        ) {
            /* BIOS intro animation */
            JIT_EMIT_ADD_CYCLES(current_entry,
                                468);  // Length of one loop when idle
        } else if (target == 0x10BC
                && ((cond == COND_PL && state->current_PC - 2 == 0x001122)
                 || (cond == COND_T  && state->current_PC - 2 == 0x00116A))
        ) {
            /* Azel: Panzer Dragoon RPG (JP) */
            JIT_EMIT_ADD_CYCLES(current_entry, 
                                178*4);  // Assuming a cycle_limit of 768
        }
#endif
        if (target < state->current_PC) {
            offset = btcache_lookup(target);
        } else {
            offset = -1;  // Forward jumps can't be in the cache
        }
        JIT_EMIT_TEST_cc(cond, current_entry);
        if (offset >= 0) {
            JIT_EMIT_Bcc_native(current_entry, target, offset);
        } else {
            int32_t branch_offset;
            JIT_EMIT_Bcc(current_entry, target, &branch_offset);
            if (target >= state->current_PC && branch_offset >= 0) {
                record_unresolved_branch(target, branch_offset);
            }
        }
        JIT_EMIT_ADD_CYCLES(current_entry, 8 + cycles);
        return 0;
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
    JIT_EMIT_GET_OP1_IMMEDIATE(current_entry, imm8);
    const int do_cc = cc_needed(state, opcode);
    JIT_EMIT_MOVE_L(current_entry);
    if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
    JIT_EMIT_SET_REGISTER_L(current_entry, reg*4);
    JIT_EMIT_ADD_CYCLES(current_entry, 4);
    return 0;
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

    /* Retrieve the register and EA values; make sure to load operand 1
     * first, since operand 2 may be destroyed by memory operations */
    int cycles;
    if (ea_dest) {
        JIT_EMIT_GET_OP1_REGISTER(current_entry, reg*4);
        ea_get(state, opcode, size, ea_dest, &cycles, 2);
    } else {
        ea_get(state, opcode, size, ea_dest, &cycles, 1);
        if (areg_dest) {
            JIT_EMIT_GET_OP2_REGISTER(current_entry, (8+reg)*4);
        } else {
            JIT_EMIT_GET_OP2_REGISTER(current_entry, reg*4);
        }
    }
    if (cycles < 0) {
        return 1;
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
    const int do_cc = cc_needed(state, opcode);
    switch (aluop) {
        case OR:  if (size == SIZE_B) {
                      JIT_EMIT_OR_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_OR_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_OR_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
                  }
                  break;
        case AND: if (size == SIZE_B) {
                      JIT_EMIT_AND_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_AND_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_AND_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
                  }
                  break;
        case EOR: if (size == SIZE_B) {
                      JIT_EMIT_EOR_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_EOR_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_EOR_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
                  }
                  break;
        case CMP: if (areg_dest && size == SIZE_W) {
                      JIT_EMIT_SUBA_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_CMP_W(current_entry);
                  } else if (size == SIZE_B) {
                      JIT_EMIT_SUB_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_CMP_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_SUB_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_CMP_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_SUB_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_CMP_L(current_entry);
                  }
                  break;
        case SUB: if (areg_dest && size == SIZE_W) {
                      JIT_EMIT_SUBA_W(current_entry);
                  } else if (areg_dest && size == SIZE_L) {
                      JIT_EMIT_SUB_L(current_entry);
                  } else if (size == SIZE_B) {
                      JIT_EMIT_SUB_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUB_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_SUB_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUB_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_SUB_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUB_L(current_entry);
                  }
                  break;
        default:  // case ADD
                  if (areg_dest && size == SIZE_W) {
                      JIT_EMIT_ADDA_W(current_entry);
                  } else if (areg_dest && size == SIZE_L) {
                      JIT_EMIT_ADD_L(current_entry);
                  } else if (size == SIZE_B) {
                      JIT_EMIT_ADD_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_ADD_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_ADD_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_ADD_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_ADD_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_ADD_L(current_entry);
                  }
                  break;
    }  // switch (aluop)

    /* Store the result in the proper place (if the instruction is not CMP) */
    if (aluop != CMP) {
        if (ea_dest) {
            ea_set(state, opcode, size);
        } else if (areg_dest) {
            JIT_EMIT_SET_REGISTER_L(current_entry, (8+reg)*4);
        } else if (size == SIZE_B) {
            JIT_EMIT_SET_REGISTER_B(current_entry, reg*4);
        } else if (size == SIZE_W) {
            JIT_EMIT_SET_REGISTER_W(current_entry, reg*4);
        } else {  // size == SIZE_L
            JIT_EMIT_SET_REGISTER_L(current_entry, reg*4);
        }
    }

    JIT_EMIT_ADD_CYCLES(current_entry, 4 + cycles);
    return 0;
}

/*************************************************************************/

/**
 * op_DIV:  DIVU and DIVS instructions (format 1000 rrrx 11xx xxxx).
 */
static int op_DIV(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG;
    const int sign = opcode & (1<<8);

    int cycles;
    ea_get(state, opcode, SIZE_W, 0, &cycles, 1);
    if (cycles < 0) {
        return 1;
    }
    JIT_EMIT_GET_OP2_REGISTER(current_entry, reg*4);
    /* Add the EA cycles now, in case a divide-by-zero exception occurs */
    JIT_EMIT_ADD_CYCLES(current_entry, cycles);

    if (sign) {
        JIT_EMIT_DIVS_W(current_entry);
    } else {
        JIT_EMIT_DIVU_W(current_entry);
    }
    JIT_EMIT_SET_REGISTER_L(current_entry, reg*4);

    /* The 68000 docs say that the timing difference between best and
     * worst cases is less than 10%, so we just return the worst case */
    JIT_EMIT_ADD_CYCLES(current_entry, sign ? 158 : 140);
    return 0;
}

/*************************************************************************/

/**
 * opAxxx:  $Axxx illegal instruction set (format 1010 xxxx xxxx xxxx).
 */
static int opAxxx(Q68State *state, uint32_t opcode)
{
    return raise_exception(state, EX_LINE_1010);
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
    ea_get(state, opcode, SIZE_W, 0, &cycles, 1);
    if (cycles < 0) {
        return 1;
    }
    JIT_EMIT_GET_OP2_REGISTER(current_entry, reg*4);

    const int do_cc = cc_needed(state, opcode);
    if (sign) {
        JIT_EMIT_MULS_W(current_entry);
    } else {
        JIT_EMIT_MULU_W(current_entry);
    }
    /* 16*16 -> 32 multiplication can't produce carry or overflow, so we
     * can treat it like a logical operation for setting condition codes */
    if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
    JIT_EMIT_SET_REGISTER_L(current_entry, reg*4);

    JIT_EMIT_ADD_CYCLES(current_entry, 54 + cycles);
    return 0;
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
    int cycles;

    if (size == 3) {
        /* Memory shift/rotate */
        is_memory = 1;
        if ((opcode & 0x0800) || EA_MODE(opcode) <= EA_ADDRESS_REG) {
            return op_ill(state, opcode);
        }
        size = SIZE_W;
        type = opcode>>9 & 3;
        JIT_EMIT_GET_OP1_IMMEDIATE(current_entry, 1);
        ea_get(state, opcode, size, 1, &cycles, 2);
        if (cycles < 0) {
            return 1;
        }
    } else {
        /* Register shift/rotate */
        is_memory = 0;
        type = opcode>>3 & 3;
        if (opcode & 0x0020) {
            INSN_GET_REG;
            JIT_EMIT_GET_OP1_REGISTER(current_entry, reg*4);
        } else {
            JIT_EMIT_GET_OP1_IMMEDIATE(current_entry, count);
        }
        JIT_EMIT_GET_OP2_REGISTER(current_entry, reg0*4);
        cycles = 0;
    }

    switch (type) {
      case 0:  // ASL/ASR
        if (is_left) {
            if (size == SIZE_B) {
                JIT_EMIT_ASL_B(current_entry);
            } else if (size == SIZE_W) {
                JIT_EMIT_ASL_W(current_entry);
            } else {  // size == SIZE_L
                JIT_EMIT_ASL_L(current_entry);
            }
        } else {
            if (size == SIZE_B) {
                JIT_EMIT_ASR_B(current_entry);
            } else if (size == SIZE_W) {
                JIT_EMIT_ASR_W(current_entry);
            } else {  // size == SIZE_L
                JIT_EMIT_ASR_L(current_entry);
            }
        }
        break;
      case 1:  // LSL/LSR
        if (is_left) {
            if (size == SIZE_B) {
                JIT_EMIT_LSL_B(current_entry);
            } else if (size == SIZE_W) {
                JIT_EMIT_LSL_W(current_entry);
            } else {  // size == SIZE_L
                JIT_EMIT_LSL_L(current_entry);
            }
        } else {
            if (size == SIZE_B) {
                JIT_EMIT_LSR_B(current_entry);
            } else if (size == SIZE_W) {
                JIT_EMIT_LSR_W(current_entry);
            } else {  // size == SIZE_L
                JIT_EMIT_LSR_L(current_entry);
            }
        }
        break;
      case 2:  // ROXL/ROXR
        if (is_left) {
            if (size == SIZE_B) {
                JIT_EMIT_ROXL_B(current_entry);
            } else if (size == SIZE_W) {
                JIT_EMIT_ROXL_W(current_entry);
            } else {  // size == SIZE_L
                JIT_EMIT_ROXL_L(current_entry);
            }
        } else {
            if (size == SIZE_B) {
                JIT_EMIT_ROXR_B(current_entry);
            } else if (size == SIZE_W) {
                JIT_EMIT_ROXR_W(current_entry);
            } else {  // size == SIZE_L
                JIT_EMIT_ROXR_L(current_entry);
            }
        }
        break;
      case 3:  // ROL/ROR
        if (is_left) {
            if (size == SIZE_B) {
                JIT_EMIT_ROL_B(current_entry);
            } else if (size == SIZE_W) {
                JIT_EMIT_ROL_W(current_entry);
            } else {  // size == SIZE_L
                JIT_EMIT_ROL_L(current_entry);
            }
        } else {
            if (size == SIZE_B) {
                JIT_EMIT_ROR_B(current_entry);
            } else if (size == SIZE_W) {
                JIT_EMIT_ROR_W(current_entry);
            } else {  // size == SIZE_L
                JIT_EMIT_ROR_L(current_entry);
            }
        }
        break;
    }  // switch (type)

    if (is_memory) {
        ea_set(state, opcode, size);
    } else if (size == SIZE_B) {
        JIT_EMIT_SET_REGISTER_B(current_entry, reg0*4);
    } else if (size == SIZE_W) {
        JIT_EMIT_SET_REGISTER_W(current_entry, reg0*4);
    } else {  // size == SIZE_L
        JIT_EMIT_SET_REGISTER_L(current_entry, reg0*4);
    }

    /* Cycles based on count are added in the shift/rotate processing */
    JIT_EMIT_ADD_CYCLES(current_entry, (size==SIZE_L ? 8 : 6) + cycles);
    return 0;
}

/*************************************************************************/

/**
 * opFxxx:  $Fxxx illegal instruction set (format 1111 xxxx xxxx xxxx).
 */
static int opFxxx(Q68State *state, uint32_t opcode)
{
    return raise_exception(state, EX_LINE_1111);
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
    enum {NEGX = 0, CLR = 1, NEG = 2, NOT = 3, TST = 5} aluop;
    aluop = opcode>>9 & 7;

    if (EA_MODE(opcode) == EA_ADDRESS_REG) {  // Address registers not allowed
        return op_ill(state, opcode);
    }

    /* Retrieve the EA value */
    int cycles;
    ea_get(state, opcode, size, 1, &cycles, 1);
    if (cycles < 0) {
        return 1;
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
    /* For simplicity, use the 2-argument operations with 0 or ~0 as the
     * second operand:
     *    -n =  0 - n
     *     0 =  0 & n
     *    ~n = ~0 ^ n
     *     n =  0 | n
     */
    JIT_EMIT_GET_OP2_IMMEDIATE(current_entry, aluop==NOT ? ~(uint32_t)0 : 0);
    const int do_cc = cc_needed(state, opcode);
    switch (aluop) {
        case NEGX:if (size == SIZE_B) {
                      JIT_EMIT_SUBX_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUBX_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_SUBX_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUBX_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_SUBX_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUBX_L(current_entry);
                  }
                  break;
        case NEG: if (size == SIZE_B) {
                      JIT_EMIT_SUB_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUB_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_SUB_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUB_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_SUB_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_SUB_L(current_entry);
                  }
                  break;
        case CLR: if (size == SIZE_B) {
                      JIT_EMIT_AND_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_AND_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_AND_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
                  }
                  break;
        case NOT: if (size == SIZE_B) {
                      JIT_EMIT_EOR_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_EOR_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_EOR_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
                  }
                  break;
        default:  // case TST
                  if (size == SIZE_B) {
                      JIT_EMIT_OR_B(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_B(current_entry);
                  } else if (size == SIZE_W) {
                      JIT_EMIT_OR_W(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_W(current_entry);
                  } else {  // size == SIZE_L
                      JIT_EMIT_OR_L(current_entry);
                      if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
                  }
                  break;
    }  // switch (aluop)

    /* Store the result in the proper place (if the instruction is not TST) */
    if (aluop != TST) {
        ea_set(state, opcode, size);
    }

    JIT_EMIT_ADD_CYCLES(current_entry, 4 + cycles);
    return 0;
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
        JIT_EMIT_CHECK_SUPER(current_entry);
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
    ea_get(state, opcode, SIZE_W, ea_dest, &cycles_tmp, 1);
    if (cycles_tmp < 0) {
        return 1;
    }
    cycles += cycles_tmp;

    /* Update the cycle counter (and PC) before writing the result, in case
     * a change to SR triggers an interrupt */
    JIT_EMIT_ADD_CYCLES(current_entry, cycles);
    advance_PC(state);

    if (ea_dest) {
        if (is_CCR) {
            JIT_EMIT_GET_OP1_CCR(current_entry);
        } else {
            JIT_EMIT_GET_OP1_SR(current_entry);
        }
        JIT_EMIT_MOVE_W(current_entry);
        ea_set(state, opcode, SIZE_W);
    } else {
        JIT_EMIT_MOVE_W(current_entry);
        /* No need to set condition codes--we're about to overwrite them */
        if (is_CCR) {
            JIT_EMIT_SET_CCR(current_entry);
        } else {
            JIT_EMIT_SET_SR(current_entry);
        }
    }

    return 0;
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
    ea_get(state, opcode, SIZE_B, 1, &cycles, 1);
    if (cycles < 0) {
        return 1;
    }

    /* Treat it as something like SBCD <ea>,#0 for simplicity */
    JIT_EMIT_GET_OP2_IMMEDIATE(current_entry, 0);
    JIT_EMIT_SBCD(current_entry);

    ea_set(state, opcode, SIZE_B);
    JIT_EMIT_ADD_CYCLES(current_entry,
                        (EA_MODE(opcode) == EA_DATA_REG ? 6 : 8) + cycles);
    return 0;
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
    JIT_EMIT_CHECK_ALIGNED_SP(current_entry, opcode,
                              FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_WRITE);
#endif
    JIT_EMIT_PEA(current_entry);
    JIT_EMIT_ADD_CYCLES(current_entry, 8 + cycles);
    return 0;
}

/*************************************************************************/

/**
 * opSWAP:  SWAP instruction (format 0100 1000 0100 0rrr).
 */
static int opSWAP(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG0;
    JIT_EMIT_GET_OP1_REGISTER(current_entry, reg0*4);
    const int do_cc = cc_needed(state, opcode);
    JIT_EMIT_SWAP(current_entry);
    if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
    JIT_EMIT_SET_REGISTER_L(current_entry, reg0*4);
    JIT_EMIT_ADD_CYCLES(current_entry, 4);
    return 0;
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
    ea_get(state, opcode, SIZE_B, 1, &cycles, 1);
    if (cycles < 0) {
        /* Note that the ILLEGAL instruction is coded as TAS #imm, so it
         * will be rejected as unwriteable by ea_get() */
        return 1;
    }
    JIT_EMIT_TAS(current_entry);
    ea_set(state, opcode, SIZE_B);
    JIT_EMIT_ADD_CYCLES(current_entry,
                        (EA_MODE(opcode) == EA_DATA_REG ? 4 : 10) + cycles);
    return 0;
}

/*************************************************************************/

/**
 * op_EXT:  EXT instruction (format 0100 1000 1s00 0rrr).
 */
static int op_EXT(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG0;
    JIT_EMIT_GET_OP1_REGISTER(current_entry, reg0*4);
    const int do_cc = cc_needed(state, opcode);
    if (opcode & 0x0040) {
        JIT_EMIT_EXT_L(current_entry);
        if (do_cc) JIT_EMIT_SETCC_LOGIC_L(current_entry);
        JIT_EMIT_SET_REGISTER_L(current_entry, reg0*4);
    } else {
        JIT_EMIT_EXT_W(current_entry);
        if (do_cc) JIT_EMIT_SETCC_LOGIC_W(current_entry);
        JIT_EMIT_SET_REGISTER_W(current_entry, reg0*4);
    }
    JIT_EMIT_ADD_CYCLES(current_entry, 4);
    return 0;
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
    if (regmask != 0) {  // FIXME: does a real 68000 choke even if regmask==0?
#ifndef Q68_DISABLE_ADDRESS_ERROR
        JIT_EMIT_CHECK_ALIGNED_EA(current_entry, opcode,
                                  FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_WRITE);
#endif
    }

    if (EA_MODE(opcode) == EA_PREDECREMENT) {
        /* Register order is reversed in predecrement mode */
        int reg;
        for (reg = 15; reg >= 0; reg--, regmask >>= 1) {
            if (regmask & 1) {
                if (size == SIZE_W) {
                    JIT_EMIT_STORE_DEC_W(current_entry, reg*4);
                    cycles += 4;
                } else {
                    JIT_EMIT_STORE_DEC_L(current_entry, reg*4);
                    cycles += 8;
                }
            }
        }
        JIT_EMIT_MOVEM_WRITEBACK(current_entry, (8 + EA_REG(opcode)) * 4);
    } else {
        int reg;
        for (reg = 0; reg < 16; reg++, regmask >>= 1) {
            if (regmask & 1) {
                if (size == SIZE_W) {
                    JIT_EMIT_STORE_INC_W(current_entry, reg*4);
                    cycles += 4;
                } else {
                    JIT_EMIT_STORE_INC_L(current_entry, reg*4);
                    cycles += 8;
                }
            }
        }
    }

    JIT_EMIT_ADD_CYCLES(current_entry, 4 + cycles);
    return 0;
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
    if (regmask != 0) {  // FIXME: does a real 68000 choke even if regmask==0?
#ifndef Q68_DISABLE_ADDRESS_ERROR
        JIT_EMIT_CHECK_ALIGNED_EA(current_entry, opcode,
                                  FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_READ);
#endif
    }

    int reg;
    for (reg = 0; reg < 16; reg++, regmask >>= 1) {
        if (regmask & 1) {
            if (size == SIZE_W) {
                if (reg < 8) {
                    JIT_EMIT_LOAD_INC_W(current_entry, reg*4);
                } else {
                    JIT_EMIT_LOADA_INC_W(current_entry, reg*4);
                }
                cycles += 4;
            } else {
                JIT_EMIT_LOAD_INC_L(current_entry, reg*4);
                cycles += 8;
            }
        }
    }
    if (EA_MODE(opcode) == EA_POSTINCREMENT) {
        JIT_EMIT_MOVEM_WRITEBACK(current_entry, (8 + EA_REG(opcode)) * 4);
    }

    JIT_EMIT_ADD_CYCLES(current_entry, 8 + cycles);
    return 0;
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
    return raise_exception(state, EX_TRAP + (opcode & 0x000F));
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
    JIT_EMIT_CHECK_ALIGNED_SP(current_entry, opcode,
                              FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_WRITE);
#endif
    JIT_EMIT_GET_OP1_REGISTER(current_entry, (8+reg0)*4);
    JIT_EMIT_PUSH_L(current_entry);
    JIT_EMIT_GET_OP1_REGISTER(current_entry, (8+7)*4);
    JIT_EMIT_MOVE_L(current_entry);
    JIT_EMIT_SET_REGISTER_L(current_entry, (8+reg0)*4);
    JIT_EMIT_GET_OP2_IMMEDIATE(current_entry, disp);
    JIT_EMIT_ADD_L(current_entry);
    JIT_EMIT_SET_REGISTER_L(current_entry, (8+7)*4);
    JIT_EMIT_ADD_CYCLES(current_entry, 16);
    return 0;
}

/*-----------------------------------------------------------------------*/

/**
 * opUNLK:  UNLK instruction (format 0100 1110 0101 1rrr).
 */
static int opUNLK(Q68State *state, uint32_t opcode)
{
    INSN_GET_REG0;
    JIT_EMIT_GET_OP1_REGISTER(current_entry, (8+reg0)*4);
    JIT_EMIT_MOVE_L(current_entry);
    JIT_EMIT_SET_REGISTER_L(current_entry, (8+7)*4);
#ifndef Q68_DISABLE_ADDRESS_ERROR
    JIT_EMIT_CHECK_ALIGNED_SP(current_entry, opcode,
                              FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_READ);
#endif
    JIT_EMIT_POP_L(current_entry);
    JIT_EMIT_SET_REGISTER_L(current_entry, (8+reg0)*4);
    JIT_EMIT_ADD_CYCLES(current_entry, 12);
    return 0;
}

/*-----------------------------------------------------------------------*/

/**
 * opMUSP:  MOVE An,USP and MOVE USP,An instructions (format
 * 0100 1110 0110 xrrr).
 */
static int opMUSP(Q68State *state, uint32_t opcode)
{
    JIT_EMIT_CHECK_SUPER(current_entry);
    INSN_GET_REG0;
    if (opcode & 0x0008) {
        JIT_EMIT_MOVE_TO_USP(current_entry, reg0*4);
    } else {
        JIT_EMIT_MOVE_FROM_USP(current_entry, reg0*4);
    }
    JIT_EMIT_ADD_CYCLES(current_entry, 4);
    return 0;
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
        JIT_EMIT_CHECK_SUPER(current_entry);
        JIT_EMIT_ADD_CYCLES(current_entry, 132);
        return 0;
      case 1:  // $4E71 NOP
        JIT_EMIT_ADD_CYCLES(current_entry, 4);
        return 0;
      case 2:  // $4E72 STOP
        JIT_EMIT_CHECK_SUPER(current_entry);
        JIT_EMIT_ADD_CYCLES(current_entry, 4);
        advance_PC(state);
        JIT_EMIT_STOP(current_entry, IFETCH(state));
        return 1;
      case 3: {  // $4E73 RTE
        JIT_EMIT_CHECK_SUPER(current_entry);
#ifndef Q68_DISABLE_ADDRESS_ERROR
        JIT_EMIT_CHECK_ALIGNED_SP(current_entry, opcode,
                                  FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_READ);
#endif
        JIT_EMIT_ADD_CYCLES(current_entry, 20);
        JIT_EMIT_RTE(current_entry);
        PC_updated = 1;
        return 1;
      }
      case 5:  // $4E75 RTS
#ifndef Q68_DISABLE_ADDRESS_ERROR
        JIT_EMIT_CHECK_ALIGNED_SP(current_entry, opcode,
                                  FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_READ);
#endif
        JIT_EMIT_ADD_CYCLES(current_entry, 16);
        JIT_EMIT_RTS(current_entry);
        PC_updated = 1;
        return 1;
      case 6:  // $4E76 TRAPV
        JIT_EMIT_TRAPV(current_entry);
        JIT_EMIT_ADD_CYCLES(current_entry, 4);
        return 0;
      case 7: {  // $4E77 RTR
#ifndef Q68_DISABLE_ADDRESS_ERROR
        JIT_EMIT_CHECK_ALIGNED_SP(current_entry, opcode,
                                  FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_READ);
#endif
        JIT_EMIT_ADD_CYCLES(current_entry, 20);
        JIT_EMIT_RTR(current_entry);
        PC_updated = 1;
        return 1;
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
    if (is_jsr) {
        cycles += 8;
    }
    JIT_EMIT_ADD_CYCLES(current_entry, cycles);
    advance_PC(state);

    ea_resolve(state, opcode, SIZE_W, ACCESS_READ);  // cannot fail
    if (is_jsr) {
#ifndef Q68_DISABLE_ADDRESS_ERROR
        JIT_EMIT_CHECK_ALIGNED_SP(current_entry, opcode,
                                  FAULT_STATUS_IN_DATA | FAULT_STATUS_RW_WRITE);
#endif
        JIT_EMIT_JSR(current_entry, jit_PC);
        return 0;
    } else {
        JIT_EMIT_JMP(current_entry);
        return 1;
    }
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

    if (to_memory) {
        if (is_long) {
            JIT_EMIT_MOVEP_WRITE_L(current_entry, reg0*4, disp, reg*4);
        } else {
            JIT_EMIT_MOVEP_WRITE_W(current_entry, reg0*4, disp, reg*4);
        }
    } else {
        if (is_long) {
            JIT_EMIT_MOVEP_READ_L(current_entry, reg0*4, disp, reg*4);
        } else {
            JIT_EMIT_MOVEP_READ_W(current_entry, reg0*4, disp, reg*4);
        }
    }

    JIT_EMIT_ADD_CYCLES(current_entry, is_long ? 24 : 16);
    return 0;
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

    const uint16_t src_ea =
        (is_memory ? EA_PREDECREMENT : EA_DATA_REG) << 3 | reg0;
    const uint16_t dest_ea =
        (is_memory ? EA_PREDECREMENT : EA_DATA_REG) << 3 | reg;
    int dummy;
    ea_get(state, src_ea,  size, 0, &dummy, 1);
    ea_get(state, dest_ea, size, 1, &dummy, 2);

    const int do_cc = cc_needed(state, opcode);
    if (is_add) {
        if (size == SIZE_B) {
            JIT_EMIT_ADDX_B(current_entry);
            if (do_cc) JIT_EMIT_SETCC_ADDX_B(current_entry);
        } else if (size == SIZE_W) {
            JIT_EMIT_ADDX_W(current_entry);
            if (do_cc) JIT_EMIT_SETCC_ADDX_W(current_entry);
        } else {  // size == SIZE_L
            JIT_EMIT_ADDX_L(current_entry);
            if (do_cc) JIT_EMIT_SETCC_ADDX_L(current_entry);
        }
    } else {
        if (size == SIZE_B) {
            JIT_EMIT_SUBX_B(current_entry);
            if (do_cc) JIT_EMIT_SETCC_SUBX_B(current_entry);
        } else if (size == SIZE_W) {
            JIT_EMIT_SUBX_W(current_entry);
            if (do_cc) JIT_EMIT_SETCC_SUBX_W(current_entry);
        } else {  // size == SIZE_L
            JIT_EMIT_SUBX_L(current_entry);
            if (do_cc) JIT_EMIT_SETCC_SUBX_L(current_entry);
        }
    }

    ea_set(state, dest_ea, size);
    JIT_EMIT_ADD_CYCLES(current_entry, (is_memory ? (size==SIZE_L ? 30 : 18)
                                                  : (size==SIZE_L ?  8 :  4)));
    return 0;
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
    ea_get(state, src_ea,  SIZE_B, 0, &dummy, 1);
    ea_get(state, dest_ea, SIZE_B, 1, &dummy, 2);

    if (is_add) {
        JIT_EMIT_ABCD(current_entry);
    } else {
        JIT_EMIT_SBCD(current_entry);
    }

    ea_set(state, dest_ea, SIZE_B);
    JIT_EMIT_ADD_CYCLES(current_entry, is_memory ? 18 : 6);
    return 0;
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

    const uint16_t src_ea  = EA_POSTINCREMENT<<3 | reg0;
    const uint16_t dest_ea = EA_POSTINCREMENT<<3 | reg;
    int dummy;
    ea_get(state, src_ea,  size, 0, &dummy, 1);
    ea_get(state, dest_ea, size, 0, &dummy, 2);

    const int do_cc = cc_needed(state, opcode);  // Just for consistency
    if (size == SIZE_B) {
        JIT_EMIT_SUB_B(current_entry);
        if (do_cc) JIT_EMIT_SETCC_CMP_B(current_entry);
    } else if (size == SIZE_W) {
        JIT_EMIT_SUB_W(current_entry);
        if (do_cc) JIT_EMIT_SETCC_CMP_W(current_entry);
    } else {  // size == SIZE_L
        JIT_EMIT_SUB_L(current_entry);
        if (do_cc) JIT_EMIT_SETCC_CMP_L(current_entry);
    }

    JIT_EMIT_ADD_CYCLES(current_entry, SIZE_L ? 20 : 12);
    return 0;
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
        JIT_EMIT_EXG(current_entry, reg*4, reg0*4);
    } else if (mode == 0x48) {
        JIT_EMIT_EXG(current_entry, (8+reg)*4, (8+reg0)*4);
    } else if (mode == 0x88) {
        JIT_EMIT_EXG(current_entry, reg*4, (8+reg0)*4);
    } else {
        return op_ill(state, opcode);
    }
    JIT_EMIT_ADD_CYCLES(current_entry, 6);
    return 0;
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
