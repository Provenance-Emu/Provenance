/*  src/q68/q68-internal.h: Internal declarations/definitions used by Q68
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

#ifndef Q68_INTERNAL_H
#define Q68_INTERNAL_H

#ifndef Q68_CONST_H
# include "q68-const.h"
#endif

/*************************************************************************/
/******************** Defines controlling compilation ********************/
/*************************************************************************/

/**
 * Q68_USE_JIT:  When defined, enables the use of dynamic translation.
 * Defining this on a CPU without dynamic translation support will result
 * in a compilation error.
 *
 * See q68-jit.h for additional settings specific to dynamic translation.
 */
// #define Q68_USE_JIT

/**
 * Q68_JIT_OPTIMIZE_FLAGS:  When defined, allows the dynamic translator to
 * skip setting the condition flags (XNZVC) after an instruction when it
 * can prove that doing so will have no effect on program execution (e.g.
 * because the following instruction overwrites the flags).  This will
 * cause an instruction-by-instruction execution trace to differ from an
 * actual 68000, though the program behavior will remain unchanged
 * (barring any bugs in the optimization).
 */
#define Q68_JIT_OPTIMIZE_FLAGS

/**
 * Q68_JIT_LOOSE_TIMING:  When defined, allows the dynamic translator to
 * take some leeway in checking execution timing, such that instructions
 * may continue to be executed even after the cycle limit has been reached.
 * This allows the translated code to execute more quickly, but will
 * slightly alter the timing of responses to external events such as
 * interrupts.
 */
#define Q68_JIT_LOOSE_TIMING

/**
 * Q68_OPTIMIZE_IDLE:  When defined, optimizes certain idle loops to
 * improve performance in JIT mode.  Enabling this option slightly alters
 * execution timing.
 */
#define Q68_OPTIMIZE_IDLE

/**
 * Q68_JIT_VERBOSE:  When defined, outputs some status messages considered
 * useful in debugging or optimizing the JIT core.
 */
// #define Q68_JIT_VERBOSE

/**
 * Q68_DISABLE_ADDRESS_ERROR:  When defined, disables the generation of
 * address error exceptions for unaligned word/longword accesses.  The
 * behavior for such an access will depend on how the host system handles
 * unaligned accesses, and may include the host program itself crashing.
 */
// #define Q68_DISABLE_ADDRESS_ERROR

/**
 * Q68_TRACE:  When defined, the execution of every instruction will be
 * traced to the file "q68.log" in the current directory.  (On Linux, the
 * trace will be written in compressed form to "q68.log.gz".)
 */
// #define Q68_TRACE

/*************************************************************************/
/************************* Generic helper macros *************************/
/*************************************************************************/

/* Offset of a byte and word within a native long */
#ifdef WORDS_BIGENDIAN
# define BYTE_OFS  3
# define WORD_OFS  1
#else
# define BYTE_OFS  0
# define WORD_OFS  0
#endif

/* Return the length of an array */
#define lenof(a)  (sizeof((a)) / sizeof(*(a)))

/* Compiler attribute to mark functions as not to be inlined */
#ifdef __GNUC__
# define NOINLINE  __attribute__((noinline))
#else
# define NOINLINE  /*nothing*/
#endif

/* Macro to tell the compiler that a certain condition is likely or
 * unlikely to occur */
#ifdef __GNUC__
# define LIKELY(x)   (__builtin_expect(!!(x), 1))
# define UNLIKELY(x) (__builtin_expect(!!(x), 0))
#else
# define LIKELY(x)   (x)
# define UNLIKELY(x) (x)
#endif

/* Debug/error message macro.  DMSG("message",...) prints to stderr a line
 * in the form:
 *     func_name(file:line): message
 * printf()-style format tokens and arguments are allowed, and no newline
 * is required at the end.  The format string must be a literal string
 * constant. */
#define DMSG(msg,...) \
    fprintf(stderr, "%s(%s:%d): " msg "\n", __FUNCTION__, __FILE__, __LINE__ \
            , ## __VA_ARGS__)

/*************************************************************************/
/******************* Processor state block definition ********************/
/*************************************************************************/

typedef struct Q68JitEntry_ Q68JitEntry;  // For JIT code
typedef struct Q68JitBlacklist_ Q68JitBlacklist;  // For JIT code

struct Q68State_ {

    /**** Data directly reflecting the current CPU state ****/

    /* Registers */
    union {
        struct {
            uint32_t D[8];
            uint32_t A[8];
        };
        uint32_t DA[16];  // For fast accessing (A0 = D8, A1 = D9, etc.)
    };
    uint32_t PC;
    uint32_t SR;
    uint32_t USP, SSP;

    /* "Current PC" for this instruction (address of opcode + 2) */
    uint32_t current_PC;

    /* Effective address used by the current instruction */
    uint32_t ea_addr;

    /* Pending exception, to be taken after the current instruction has
     * been processed (zero if none) */
    unsigned int exception;
    /* Auxiliary exception data used for a bus error or address error */
    uint32_t fault_addr;
    uint16_t fault_opcode;
    uint16_t fault_status;

    /* Nonzero if virtual processor is halted (due to either a STOP
     * instruction or a double fault); see Q68_HALTED_* */
    unsigned int halted;

    /* Current interrupt request level */
    unsigned int irq;

    /* Number of clock cycles executed so far */
    uint32_t cycles;

    /**** Environment settings ****/

    /* Native memory allocation functions */
    void *(*malloc_func)(size_t size);
    void *(*realloc_func)(void *ptr, size_t size);
    void (*free_func)(void *ptr);

    /* 68k memory read/write functions */
    Q68ReadFunc *readb_func, *readw_func;
    Q68WriteFunc *writeb_func, *writew_func;

    /* Native cache flushing function (for JIT) */
    void (*jit_flush)(void);

    /**** JIT-related data ****/

    /* Currently executing JIT block (NULL = none) */
    Q68JitEntry *jit_running;

    /* Nonzero if JIT routine needs to abort because the underlying 68000
     * code was modified (e.g. by a self-modifying routine) */
    unsigned int jit_abort;

    /* Hash table of translated code segments, hashed by 68000 start address */
    Q68JitEntry *jit_table;  // Record buffer
    Q68JitEntry **jit_hashchain;  // Hash collision chains

    /* Total size of translated data */
    int32_t jit_total_data;  // Signed to protect against its going negative

    /* Internal timestamp used by JIT LRU logic */
    uint32_t jit_timestamp;

    /* List of self-modifying blocks not to be translated (zero in both
     * address fields indicates a free entry) */
    struct {
        uint32_t m68k_start;  // Code start address in 68000 address space
        uint32_t m68k_end;    // Code end address in 68000 address space
        uint32_t timestamp;   // Time this entry was added
    } jit_blacklist[Q68_JIT_BLACKLIST_SIZE];

    /* Nonzero if the current PC is inside a blacklisted block */
    unsigned int jit_in_blist;

    /* When jit_in_blacklist != 0, indicates the relevant jit_blacklist[]
     * array entry index */
    unsigned int jit_blist_num;

    /* Call stack for efficient handling of subroutine calls */
    unsigned int jit_callstack_top; // Index of next entry to write
    struct {
        uint32_t return_PC;         // PC on return from subroutine (0 = free)
        Q68JitEntry *return_entry;  // JIT block containing native code
        void *return_native;        // Native address to jump to
    } jit_callstack[Q68_JIT_CALLSTACK_SIZE];

    /* Buffer for tracking translated code blocks */
    uint8_t jit_pages[1<<(24-(Q68_JIT_PAGE_BITS+3))];

};

/*-----------------------------------------------------------------------*/

/* Constants used in the Q68State.halted field */

enum {
    Q68_HALTED_NONE = 0,     // Processor is running normally
    Q68_HALTED_STOP,         // Processor halted because of a STOP instruction
    Q68_HALTED_DOUBLE_FAULT, // Processor halted because of a double fault
};

/*-----------------------------------------------------------------------*/

/* Macros for accessing Q68State.jit_pages[] (page is assumed to be valid) */

#define JIT_PAGE_SET(state,page) \
    ((state)->jit_pages[(page)>>3] |= 1<<((page)&7))
#define JIT_PAGE_CLEAR(state,page) \
    ((state)->jit_pages[(page)>>3] &= ~(1<<((page)&7)))
#define JIT_PAGE_TEST(state,page) \
    ((state)->jit_pages[(page)>>3] & 1<<((page)&7))

/*************************************************************************/
/************************ JIT interface functions ************************/
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
extern int q68_jit_init(Q68State *state);

/**
 * q68_jit_reset:  Reset the dynamic translation state, clearing out all
 * previously stored data.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
extern void q68_jit_reset(Q68State *state);

/**
 * q68_jit_cleanup:  Destroy all JIT-related data.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     None
 */
extern void q68_jit_cleanup(Q68State *state);

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
extern Q68JitEntry *q68_jit_translate(Q68State *state, uint32_t address);

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
extern Q68JitEntry *q68_jit_find(Q68State *state, uint32_t address);

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
extern void q68_jit_run(Q68State *state, uint32_t cycle_limit,
                        Q68JitEntry **entry_ptr);

/**
 * q68_jit_clear:  Clear any translation beginning at the given address.
 *
 * [Parameters]
 *       state: Processor state block
 *     address: Start address in 68000 address space
 * [Return value]
 *     None
 */
extern void q68_jit_clear(Q68State *state, uint32_t address);

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
extern void q68_jit_clear_page(Q68State *state, uint32_t address);

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
extern void q68_jit_clear_write(Q68State *state, uint32_t address, uint32_t size);

/*************************************************************************/
/************************ Internal-use constants *************************/
/*************************************************************************/

/* Effective address types for ea_type() */
enum {
    EA_xREG,  // Data/address register
    EA_MEM,   // Memory reference
    EA_IMM,   // Immediate value
};

/* Effective address access types for ea_resolve() */
enum {
    ACCESS_READ = 0,
    ACCESS_WRITE,
    ACCESS_MODIFY,      // For the read access of a read-write operation
};

/*************************************************************************/
/*************** Opcode implementation function prototype ****************/
/*************************************************************************/

/**
 * OpcodeFunc:  Type of a function implementing one or a group of
 * instructions.
 *
 * [Parameters]
 *      state: Processor state block
 *     opcode: Instruction opcode
 * [Return value]
 *     Clock cycles used
 */
typedef int OpcodeFunc(Q68State *state, uint32_t opcode);

/*************************************************************************/
/******************* Memory access functions (inline) ********************/
/*************************************************************************/

/**
 * READ[SU]{8,16,32}:  Read a value from memory.
 *
 * [Parameters]
 *     state: Processor state block
 *      addr: Address to read or write
 * [Return value]
 *     Value read
 */

static inline int32_t READS8(Q68State *state, uint32_t addr) {
    return (int8_t) state->readb_func(addr & 0xFFFFFF);
}
static inline uint32_t READU8(Q68State *state, uint32_t addr) {
    return state->readb_func(addr & 0xFFFFFF);
}

static inline int32_t READS16(Q68State *state, uint32_t addr) {
    return (int16_t) state->readw_func(addr & 0xFFFFFF);
}
static inline uint32_t READU16(Q68State *state, uint32_t addr) {
    return state->readw_func(addr & 0xFFFFFF);
}

static inline int32_t READS32(Q68State *state, uint32_t addr) {
    addr &= 0xFFFFFF;
    int32_t value = (int32_t) state->readw_func(addr) << 16;
    addr += 2;
    addr &= 0xFFFFFF;
    value |= state->readw_func(addr);
    return value;
}
static inline uint32_t READU32(Q68State *state, uint32_t addr) {
    addr &= 0xFFFFFF;
    uint32_t value = state->readw_func(addr) << 16;
    addr += 2;
    addr &= 0xFFFFFF;
    value |= state->readw_func(addr);
    return value;
}

/*-----------------------------------------------------------------------*/

/**
 * WRITE{8,16,32}:  Write a value to memory.
 *
 * [Parameters]
 *     state: Processor state block
 *      addr: Address to read or write
 *      data: Value to write
 * [Return value]
 *     None
 */

static inline void WRITE8(Q68State *state, uint32_t addr, uint8_t data) {
    addr &= 0xFFFFFF;
#ifdef Q68_USE_JIT
    if (UNLIKELY(JIT_PAGE_TEST(state, addr >> Q68_JIT_PAGE_BITS))) {
        q68_jit_clear_write(state, addr, 1);
    }
#endif
    state->writeb_func(addr, data);
}

static inline void WRITE16(Q68State *state, uint32_t addr, uint16_t data) {
    addr &= 0xFFFFFF;
#ifdef Q68_USE_JIT
    if (UNLIKELY(JIT_PAGE_TEST(state, addr >> Q68_JIT_PAGE_BITS))) {
        q68_jit_clear_write(state, addr, 2);
    }
#endif
    state->writew_func(addr, data);
}

static inline void WRITE32(Q68State *state, uint32_t addr, uint32_t data) {
    WRITE16(state, addr, data>>16);
    WRITE16(state, addr+2, data);
}

/*-----------------------------------------------------------------------*/

/**
 * IFETCH:  Retrieve and return the 16-bit word at the PC, incrementing the
 * PC by 2.
 *
 * [Parameters]
 *     state: Processor state block
 * [Return value]
 *     16-bit value read
 */

static inline uint32_t IFETCH(Q68State *state) {
    uint32_t data = READU16(state, state->PC);
    state->PC += 2;
    return data;
}

/*-----------------------------------------------------------------------*/

/**
 * PUSH{16,32}, POP{16,32}:  Push values onto or pop them off the stack.
 *
 * [Parameters]
 *     state: Processor state block
 *      data: Value to push (PUSH only)
 * [Return value]
 *     Value popped (unsigned, POP only)
 */

static inline void PUSH16(Q68State *state, uint16_t data) {
    state->A[7] -= 2;
    WRITE16(state, state->A[7], data);
}
static inline void PUSH32(Q68State *state, uint32_t data) {
    state->A[7] -= 4;
    WRITE32(state, state->A[7], data);
}

static inline uint32_t POP16(Q68State *state) {
    const uint32_t data = READU16(state, state->A[7]);
    state->A[7] += 2;
    return data;
}
static inline uint32_t POP32(Q68State *state) {
    const uint32_t data = READU32(state, state->A[7]);
    state->A[7] += 4;
    return data;
}

/*************************************************************************/
/******************* Instruction implementation macros *******************/
/*************************************************************************/

/* INSN_GET_REG: uint32_t reg = opcode[11:9] */
#define INSN_GET_REG \
    uint32_t reg = (opcode>>9) & 7

/* INSN_GET_COUNT: uint32_t count = opcode[11:9] || 8 */
#define INSN_GET_COUNT \
    uint32_t count = (opcode>>9) & 7 ?: 8

/* INSN_GET_COND: uint32_t cond = opcode[11:8] */
#define INSN_GET_COND \
    uint32_t cond = (opcode>>8) & 15

/* INSN_GET_SIZE: uint32_t size = opcode[7:6] */
#define INSN_GET_SIZE \
    uint32_t size = (opcode>>6) & 3

/* INSN_GET_REG0: uint32_t reg0 = opcode[2:0] */
#define INSN_GET_REG0 \
    uint32_t reg0 = opcode & 7

/* INSN_GET_IMM8: const int32_t imm8 = SIGN_EXTEND(opcode[7:0]) */
#define INSN_GET_IMM8 \
    const int32_t imm8 = (int32_t)(int8_t)opcode

/* INSN_GET_IMM16: const int32_t imm16 = *++PC; */
#define INSN_GET_IMM16 \
    const int32_t imm16 = (int16_t)IFETCH(state)

/* INSN_GET_DISP8: int32_t disp = SIGN_EXTEND(opcode[7:0]) */
#define INSN_GET_DISP8 \
    int32_t disp = (int32_t)(int8_t)opcode

/*-----------------------------------------------------------------------*/

/* INSN_COND_TRUE: Evaluate whether the given condition code is satisfied. */
#define INSN_COND_TRUE(cond)  __extension__({                           \
    const unsigned int __cond = (cond);                                 \
    const unsigned int group = __cond >> 1;                             \
    const unsigned int onoff = __cond & 1;                              \
    (group==COND_LS>>1 ? (state->SR & SR_C) >> SR_C_SHIFT               \
                         | (state->SR & SR_Z) >> SR_Z_SHIFT :           \
     group==COND_CS>>1 ? (state->SR & SR_C) >> SR_C_SHIFT :             \
     group==COND_EQ>>1 ? (state->SR & SR_Z) >> SR_Z_SHIFT :             \
     group==COND_VS>>1 ? (state->SR & SR_V) >> SR_V_SHIFT :             \
     group==COND_MI>>1 ? (state->SR & SR_N) >> SR_N_SHIFT :             \
     group==COND_LT>>1 ? (state->SR & SR_N) >> SR_N_SHIFT               \
                         ^ (state->SR & SR_V) >> SR_V_SHIFT :           \
     group==COND_LE>>1 ? (state->SR & SR_Z) >> SR_Z_SHIFT               \
                         | ((state->SR & SR_N) >> SR_N_SHIFT            \
                            ^ (state->SR & SR_V) >> SR_V_SHIFT) :       \
     0  /* COND_T or COND_F */                                          \
    ) == onoff;                                                         \
})

/*-----------------------------------------------------------------------*/

/* INSN_CLEAR_XCC, INSN_CLEAR_CC: Clear all condition codes, or all except
 * the X flag. */
#define INSN_CLEAR_XCC()  (state->SR &= ~(SR_X|SR_N|SR_Z|SR_V|SR_C))
#define INSN_CLEAR_CC()   (state->SR &= ~(     SR_N|SR_Z|SR_V|SR_C))


/* INSN_SETNZ: Set the N and Z flags according to the given 32-bit result.
 * Assumes the flags are currently cleared. */
#define INSN_SETNZ(result)  do {        \
    const int32_t __result = (result);  \
    if (__result < 0) {                 \
        state->SR |= SR_N;              \
    } else if (__result == 0) {         \
        state->SR |= SR_Z;              \
    }                                   \
} while (0)
    
/* INSN_SETNZ_SHIFT: Like INSN_SETNZ, but assumes the presence of a "shift"
 * variable containing the number of bits of "result" less one. */
#define INSN_SETNZ_SHIFT(result)  do {  \
    const int32_t __result = (result);  \
    if (__result >> shift) {            \
        state->SR |= SR_N;              \
    } else if (__result == 0) {         \
        state->SR |= SR_Z;              \
    }                                   \
} while (0)
    
/*************************************************************************/
/*************************************************************************/

#endif  // Q68_INTERNAL_H

/*
 * Local variables:
 *   c-file-style: "stroustrup"
 *   c-file-offsets: ((case-label . *) (statement-case-intro . *))
 *   indent-tabs-mode: nil
 * End:
 *
 * vim: expandtab shiftwidth=4:
 */
