/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - r4300_core.c                                            *
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

#include "r4300_core.h"
#include "cached_interp.h"
#if defined(COUNT_INSTR)
#include "instr_counters.h"
#endif
#include "new_dynarec/new_dynarec.h"
#include "pure_interp.h"
#include "recomp.h"

#include "api/callbacks.h"
#include "api/debugger.h"
#include "api/m64p_types.h"
#ifdef DBG
#include "debugger/dbg_debugger.h"
#endif
#include "main/main.h"

#include <stdlib.h>
#include <string.h>
#include <time.h>

void init_r4300(struct r4300_core* r4300, struct memory* mem, struct mi_controller* mi, struct rdram* rdram, const struct interrupt_handler* interrupt_handlers,
    unsigned int emumode, unsigned int count_per_op, int no_compiled_jump, int randomize_interrupt)
{
    struct new_dynarec_hot_state* new_dynarec_hot_state =
#if NEW_DYNAREC == NEW_DYNAREC_ARM
        &r4300->new_dynarec_hot_state;
#else
        NULL;
#endif

    r4300->emumode = emumode;
    init_cp0(&r4300->cp0, count_per_op, new_dynarec_hot_state, interrupt_handlers);
    init_cp1(&r4300->cp1, new_dynarec_hot_state);

#ifndef NEW_DYNAREC
    r4300->recomp.no_compiled_jump = no_compiled_jump;
#endif

    r4300->mem = mem;
    r4300->mi = mi;
    r4300->rdram = rdram;
    r4300->randomize_interrupt = randomize_interrupt;
    srand(time(NULL));
}

void poweron_r4300(struct r4300_core* r4300)
{
    /* clear registers */
    memset(r4300_regs(r4300), 0, 32*sizeof(int64_t));
    *r4300_mult_hi(r4300) = 0;
    *r4300_mult_lo(r4300) = 0;
    r4300->llbit = 0;

    *r4300_pc_struct(r4300) = NULL;
    r4300->delay_slot = 0;
    r4300->skip_jump = 0;
    r4300->reset_hard_job = 0;


    /* recomp init */
#ifndef NEW_DYNAREC
    r4300->recomp.delay_slot_compiled = 0;
    r4300->recomp.fast_memory = 1;
    r4300->recomp.local_rs = 0;
    r4300->recomp.dyna_interp = 0;
    r4300->recomp.jumps_table = NULL;
    r4300->recomp.jumps_number = 0;
    r4300->recomp.max_jumps_number = 0;
    r4300->recomp.jump_start8 = 0;
    r4300->recomp.jump_start32 = 0;
#if defined(__x86_64__)
    r4300->recomp.riprel_table = NULL;
    r4300->recomp.riprel_number = 0;
    r4300->recomp.max_riprel_number = 0;
#endif

#if defined(__x86_64__)
    r4300->recomp.save_rsp = 0;
    r4300->recomp.save_rip = 0;
#else
    r4300->recomp.save_ebp = 0;
    r4300->recomp.save_ebx = 0;
    r4300->recomp.save_esi = 0;
    r4300->recomp.save_edi = 0;
    r4300->recomp.save_esp = 0;
    r4300->recomp.save_eip = 0;
#endif

    r4300->recomp.branch_taken = 0;
#endif /* !NEW_DYNAREC */

    /* setup CP0 registers */
    poweron_cp0(&r4300->cp0);

    /* setup CP1 registers */
    poweron_cp1(&r4300->cp1);
}


void run_r4300(struct r4300_core* r4300)
{
    *r4300_stop(r4300) = 0;
    g_rom_pause = 0;

    /* clear instruction counters */
#if defined(COUNT_INSTR)
    memset(instr_count, 0, 131*sizeof(instr_count[0]));
#endif

    if (r4300->emumode == EMUMODE_PURE_INTERPRETER)
    {
        DebugMessage(M64MSG_INFO, "Starting R4300 emulator: Pure Interpreter");
        r4300->emumode = EMUMODE_PURE_INTERPRETER;
        run_pure_interpreter(r4300);
    }
#if defined(DYNAREC)
    else if (r4300->emumode >= 2)
    {
        DebugMessage(M64MSG_INFO, "Starting R4300 emulator: Dynamic Recompiler");
        r4300->emumode = EMUMODE_DYNAREC;
#ifdef NEW_DYNAREC
        new_dynarec_init();
        new_dyna_start();
        new_dynarec_cleanup();
#else
        r4300->cached_interp.fin_block = dynarec_fin_block;
        r4300->cached_interp.not_compiled = dynarec_notcompiled;
        r4300->cached_interp.not_compiled2 = dynarec_notcompiled2;
        r4300->cached_interp.init_block = dynarec_init_block;
        r4300->cached_interp.free_block = dynarec_free_block;
        r4300->cached_interp.recompile_block = dynarec_recompile_block;

        init_blocks(&r4300->cached_interp);
        dyna_start(dynarec_setup_code);
        (*r4300_pc_struct(r4300))++;
#if defined(PROFILE_R4300)
        profile_write_end_of_code_blocks(r4300);
#endif
        free_blocks(&r4300->cached_interp);
#endif
    }
#endif
    else /* if (r4300->emumode == EMUMODE_INTERPRETER) */
    {
        DebugMessage(M64MSG_INFO, "Starting R4300 emulator: Cached Interpreter");
        r4300->emumode = EMUMODE_INTERPRETER;
        r4300->cached_interp.fin_block = cached_interp_FIN_BLOCK;
        r4300->cached_interp.not_compiled = cached_interp_NOTCOMPILED;
        r4300->cached_interp.not_compiled2 = cached_interp_NOTCOMPILED2;
        r4300->cached_interp.init_block = cached_interp_init_block;
        r4300->cached_interp.free_block = cached_interp_free_block;
        r4300->cached_interp.recompile_block = cached_interp_recompile_block;

        init_blocks(&r4300->cached_interp);
        cached_interpreter_jump_to(r4300, UINT32_C(0xa4000040));

        /* Prevent segfault on failed cached_interpreter_jump_to */
        if (!r4300->cached_interp.actual->block) {
            return;
        }

        r4300->cp0.last_addr = *r4300_pc(r4300);

        run_cached_interpreter(r4300);

        free_blocks(&r4300->cached_interp);
    }

    DebugMessage(M64MSG_INFO, "R4300 emulator finished.");

    /* print instruction counts */
#if defined(COUNT_INSTR)
    if (r4300->emumode == EMUMODE_DYNAREC)
        instr_counters_print();
#endif
}

int64_t* r4300_regs(struct r4300_core* r4300)
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    return r4300->regs;
#else
    return r4300->new_dynarec_hot_state.regs;
#endif
}

int64_t* r4300_mult_hi(struct r4300_core* r4300)
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    return &r4300->hi;
#else
    return &r4300->new_dynarec_hot_state.hi;
#endif
}

int64_t* r4300_mult_lo(struct r4300_core* r4300)
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    return &r4300->lo;
#else
    return &r4300->new_dynarec_hot_state.lo;
#endif
}

unsigned int* r4300_llbit(struct r4300_core* r4300)
{
    return &r4300->llbit;
}

uint32_t* r4300_pc(struct r4300_core* r4300)
{
#ifdef NEW_DYNAREC
    return (r4300->emumode == EMUMODE_DYNAREC)
        ? (uint32_t*)&r4300->new_dynarec_hot_state.pcaddr
        : &(*r4300_pc_struct(r4300))->addr;
#else
    return &(*r4300_pc_struct(r4300))->addr;
#endif
}

struct precomp_instr** r4300_pc_struct(struct r4300_core* r4300)
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    return &r4300->pc;
#else
    return &r4300->new_dynarec_hot_state.pc;
#endif
}

int* r4300_stop(struct r4300_core* r4300)
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    return &r4300->stop;
#else
    return &r4300->new_dynarec_hot_state.stop;
#endif
}

unsigned int get_r4300_emumode(struct r4300_core* r4300)
{
    return r4300->emumode;
}

uint32_t *fast_mem_access(struct r4300_core* r4300, uint32_t address)
{
    /* This code is performance critical, specially on pure interpreter mode.
     * Removing error checking saves some time, but the emulator may crash. */

    if ((address & UINT32_C(0xc0000000)) != UINT32_C(0x80000000)) {
        address = virtual_to_physical_address(r4300, address, 2);
        if (address == 0) // TLB exception
            return NULL;
    }

    address &= UINT32_C(0x1ffffffc);

    return mem_base_u32(r4300->mem->base, address);
}

/* Read aligned word from memory.
 * address may not be word-aligned for byte or hword accesses.
 * Alignment is taken care of when calling mem handler.
 */
int r4300_read_aligned_word(struct r4300_core* r4300, uint32_t address, uint32_t* value)
{
    if ((address & UINT32_C(0xc0000000)) != UINT32_C(0x80000000)) {
        address = virtual_to_physical_address(r4300, address, 0);
        if (address == 0) {
            return 0;
        }
    }

    address &= UINT32_C(0x1ffffffc);

    mem_read32(mem_get_handler(r4300->mem, address), address & ~UINT32_C(3), value);

    return 1;
}

/* Read aligned dword from memory */
int r4300_read_aligned_dword(struct r4300_core* r4300, uint32_t address, uint64_t* value)
{
    uint32_t w[2];

    /* XXX: unaligned dword accesses should trigger a address error,
     * but inaccurate timing of the core can lead to unaligned address on reset
     * so just emit a warning and keep going */
    if ((address & 0x7) != 0) {
        DebugMessage(M64MSG_WARNING, "Unaligned dword read %08x", address);
    }

    if ((address & UINT32_C(0xc0000000)) != UINT32_C(0x80000000)) {
        address = virtual_to_physical_address(r4300, address, 0);
        if (address == 0) {
            return 0;
        }
    }

    address &= UINT32_C(0x1ffffffc);

    const struct mem_handler* handler = mem_get_handler(r4300->mem, address);
    mem_read32(handler, address + 0, &w[0]);
    mem_read32(handler, address + 4, &w[1]);

    *value = ((uint64_t)w[0] << 32) | w[1];

    return 1;
}

/* Write aligned word to memory.
 * address may not be word-aligned for byte or hword accesses.
 * Alignment is taken care of when calling mem handler.
 */
int r4300_write_aligned_word(struct r4300_core* r4300, uint32_t address, uint32_t value, uint32_t mask)
{
    if ((address & UINT32_C(0xc0000000)) != UINT32_C(0x80000000)) {

        invalidate_r4300_cached_code(r4300, address, 4);

        address = virtual_to_physical_address(r4300, address, 1);
        if (address == 0) {
            return 0;
        }
    }

    invalidate_r4300_cached_code(r4300, address, 4);

    address &= UINT32_C(0x1ffffffc);

    mem_write32(mem_get_handler(r4300->mem, address), address & ~UINT32_C(3), value, mask);

    return 1;
}

/* Write aligned dword to memory */
int r4300_write_aligned_dword(struct r4300_core* r4300, uint32_t address, uint64_t value, uint64_t mask)
{
    /* XXX: unaligned dword accesses should trigger a address error,
     * but inaccurate timing of the core can lead to unaligned address on reset
     * so just emit a warning and keep going */
    if ((address & 0x7) != 0) {
        DebugMessage(M64MSG_WARNING, "Unaligned dword write %08x", address);
    }

    if ((address & UINT32_C(0xc0000000)) != UINT32_C(0x80000000)) {

        invalidate_r4300_cached_code(r4300, address, 8);

        address = virtual_to_physical_address(r4300, address, 1);
        if (address == 0) {
            return 0;
        }
    }

    invalidate_r4300_cached_code(r4300, address, 8);

    address &= UINT32_C(0x1ffffffc);

    const struct mem_handler* handler = mem_get_handler(r4300->mem, address);
    mem_write32(handler, address + 0, value >> 32, mask >> 32);
    mem_write32(handler, address + 4, value      , mask      );

    return 1;
}

void invalidate_r4300_cached_code(struct r4300_core* r4300, uint32_t address, size_t size)
{
    if (r4300->emumode != EMUMODE_PURE_INTERPRETER)
    {
#ifdef NEW_DYNAREC
        if (r4300->emumode == EMUMODE_DYNAREC)
        {
            invalidate_cached_code_new_dynarec(r4300, address, size);
        }
        else
#endif
        {
            invalidate_cached_code_hacktarux(r4300, address, size);
        }
    }
}


void generic_jump_to(struct r4300_core* r4300, uint32_t address)
{
    switch(r4300->emumode)
    {
    case EMUMODE_PURE_INTERPRETER:
        *r4300_pc(r4300) = address;
        break;

    case EMUMODE_INTERPRETER:
        cached_interpreter_jump_to(r4300, address);
        break;

#ifndef NO_ASM
    case EMUMODE_DYNAREC:
#ifdef NEW_DYNAREC
        r4300->new_dynarec_hot_state.pcaddr = address;
        r4300->new_dynarec_hot_state.pending_exception = 1;
#else
        dynarec_jump_to(r4300, address);
#endif
        break;
#endif

    default:
        /* should not happen */
        break;
    }
}


/* XXX: not really a good interface but it gets the job done... */
void savestates_load_set_pc(struct r4300_core* r4300, uint32_t pc)
{
    generic_jump_to(r4300, pc);
    invalidate_r4300_cached_code(r4300, 0, 0);
}
