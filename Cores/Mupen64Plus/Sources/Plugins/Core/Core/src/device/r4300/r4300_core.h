/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - r4300_core.h                                            *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2014 Bobby Smiles                                       *
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

#ifndef M64P_DEVICE_R4300_R4300_CORE_H
#define M64P_DEVICE_R4300_R4300_CORE_H

#include <stddef.h>
#include <stdint.h>

#if defined(PROFILE_R4300)
#include <stdio.h>
#endif

#include "cp0.h"
#include "cp1.h"

#include "recomp_types.h" /* for precomp_instr, regcache_state */

#include "new_dynarec/new_dynarec.h" /* for NEW_DYNAREC_ARM */

#include "osal/preproc.h"

struct memory;
struct mi_controller;
struct rdram;

struct jump_table;
struct cached_interp
{
    char invalid_code[0x100000];
    struct precomp_block* blocks[0x100000];
    struct precomp_block* actual;

    void (*fin_block)(void);
    void (*not_compiled)(void);
    void (*not_compiled2)(void);

    void (*init_block)(struct r4300_core* r4300, uint32_t address);
    void (*free_block)(struct precomp_block* block);

    void (*recompile_block)(struct r4300_core* r4300,
        const uint32_t* source, struct precomp_block* block, uint32_t func);
};

enum {
    EMUMODE_PURE_INTERPRETER = 0,
    EMUMODE_INTERPRETER      = 1,
    EMUMODE_DYNAREC          = 2,
};


struct r4300_core
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    int64_t regs[32];
    int64_t hi;
    int64_t lo;
#endif
    unsigned int llbit;

    struct precomp_instr* pc;

    unsigned int delay_slot;
    uint32_t skip_jump;

#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    int stop;
#endif

    /* When reset_hard_job is set, next interrupt will cause hard reset */
    int reset_hard_job;

    /* from pure_interp.c */
    struct precomp_instr interp_PC;

    /* from cached_interp.c.
     * XXX: more work is needed to correctly encapsulate these */
    struct cached_interp cached_interp;

#ifndef NEW_DYNAREC
    /* from recomp.c.
     * XXX: more work is needed to correctly encapsulate these */
    struct recomp {
        int init_length;
        int code_length;                                /* current real recompiled code length */
        struct precomp_block *dst_block;                /* the current block that we are recompiling */
        struct precomp_instr* dst;                      /* destination structure for the recompiled instruction */
        const uint32_t *SRC;                            /* currently recompiled instruction in the input stream */
        uint32_t src;                                   /* the current recompiled instruction */
        int delay_slot_compiled;

        struct regcache_state regcache_state;

        struct jump_table* jumps_table;
        size_t jumps_number;
        size_t max_jumps_number;

        unsigned int jump_start8;
        unsigned int jump_start32;

#if defined(__x86_64__)
        struct riprelative_table* riprel_table;
        size_t riprel_number;
        size_t max_riprel_number;
#endif

#if defined(__x86_64__)
        long long save_rsp;
        long long save_rip;

        /* that's where the dynarec will restart when going back from a C function */
        unsigned long long* return_address;
#else
        long save_ebp;
        long save_ebx;
        long save_esi;
        long save_edi;
        long save_esp;
        long save_eip;

        /* that's where the dynarec will restart when going back from a C function */
        unsigned long* return_address;
#endif

        int branch_taken;
        struct precomp_instr fake_instr;
#ifdef COMPARE_CORE
#if defined(__x86_64__)
        long long debug_reg_storage[8];
#else
        int eax, ebx, ecx, edx, esp, ebp, esi, edi;
#endif
#endif
        unsigned char **inst_pointer;                   /* output buffer for recompiled code */
        int max_code_length;                            /* current recompiled code's buffer length */
        int fast_memory;
        int no_compiled_jump;                           /* use cached interpreter instead of recompiler for jumps */
        uint32_t jump_to_address;
        int64_t local_rs;
        unsigned int dyna_interp;

#if defined(__x86_64__)
        unsigned long long shift;
#else
        unsigned int shift;
#endif

#if defined(PROFILE_R4300)
        FILE* pfProfile;
#endif

        /* Memory accesses variables */
        uint64_t* rdword;
        uint32_t wmask;
        uint32_t address;
        union {
            uint32_t wword;
            uint64_t wdword;
        };
    } recomp;
#else
#if NEW_DYNAREC == NEW_DYNAREC_ARM
    /* FIXME: better put that near linkage_arm code
     * to help generate call beyond the +/-32MB range.
     */
    ALIGN(4096, char extra_memory[33554432]);
#endif
    struct new_dynarec_hot_state new_dynarec_hot_state;
#endif /* NEW_DYNAREC */

    unsigned int emumode;

    struct cp0 cp0;

    struct cp1 cp1;

    struct memory* mem;
    struct mi_controller* mi;
    struct rdram* rdram;

    uint32_t randomize_interrupt;
};

#define R4300_KSEG0 UINT32_C(0x80000000)
#define R4300_KSEG1 UINT32_C(0xa0000000)

#if NEW_DYNAREC != NEW_DYNAREC_ARM
#define R4300_REGS_OFFSET \
    offsetof(struct r4300_core, regs)
#else
#define R4300_REGS_OFFSET (\
    offsetof(struct r4300_core, new_dynarec_hot_state) + \
    offsetof(struct new_dynarec_hot_state, regs))
#endif

void init_r4300(struct r4300_core* r4300, struct memory* mem, struct mi_controller* mi, struct rdram* rdram, const struct interrupt_handler* interrupt_handlers, unsigned int emumode, unsigned int count_per_op, int no_compiled_jump, int randomize_interrupt);
void poweron_r4300(struct r4300_core* r4300);

void run_r4300(struct r4300_core* r4300);

int64_t* r4300_regs(struct r4300_core* r4300);
int64_t* r4300_mult_hi(struct r4300_core* r4300);
int64_t* r4300_mult_lo(struct r4300_core* r4300);
unsigned int* r4300_llbit(struct r4300_core* r4300);
uint32_t* r4300_pc(struct r4300_core* r4300);
struct precomp_instr** r4300_pc_struct(struct r4300_core* r4300);
int* r4300_stop(struct r4300_core* r4300);

unsigned int get_r4300_emumode(struct r4300_core* r4300);

/* Returns a pointer to a block of contiguous memory
 * Can access RDRAM, SP_DMEM, SP_IMEM and ROM, using TLB if necessary
 * Useful for getting fast access to a zone with executable code. */
uint32_t *fast_mem_access(struct r4300_core* r4300, uint32_t address);

int r4300_read_aligned_word(struct r4300_core* r4300, uint32_t address, uint32_t* value);
int r4300_read_aligned_dword(struct r4300_core* r4300, uint32_t address, uint64_t* value);
int r4300_write_aligned_word(struct r4300_core* r4300, uint32_t address, uint32_t value, uint32_t mask);
int r4300_write_aligned_dword(struct r4300_core* r4300, uint32_t address, uint64_t value, uint64_t mask);

/* Allow cached/dynarec r4300 implementations to invalidate
 * their cached code at [address, address+size]
 *
 * If size == 0, r4300 implementation should invalidate
 * all cached code.
 */
void invalidate_r4300_cached_code(struct r4300_core* r4300, uint32_t address, size_t size);


/* Jump to the given address. This works for all r4300 emulator, but is slower.
 * Use this for common code which can be executed from any r4300 emulator. */
void generic_jump_to(struct r4300_core* r4300, unsigned int address);

void savestates_load_set_pc(struct r4300_core* r4300, uint32_t pc);

#endif
