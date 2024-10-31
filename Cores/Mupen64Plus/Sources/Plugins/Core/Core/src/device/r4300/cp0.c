/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - cp0.c                                                   *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2002 Hacktarux                                          *
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

#include <stdint.h>
#include <string.h>

#include "cp0.h"
#include "r4300_core.h"
#include "new_dynarec/new_dynarec.h" /* for NEW_DYNAREC_ARM */
#include "recomp.h"

#ifdef COMPARE_CORE
#include "api/debugger.h"
#endif

#ifdef DBG
#include "debugger/dbg_debugger.h"
#endif

/* global functions */
void init_cp0(struct cp0* cp0, unsigned int count_per_op, struct new_dynarec_hot_state* new_dynarec_hot_state, const struct interrupt_handler* interrupt_handlers)
{
    cp0->count_per_op = count_per_op;
#if NEW_DYNAREC == NEW_DYNAREC_ARM
    cp0->new_dynarec_hot_state = new_dynarec_hot_state;
#endif

    memcpy(cp0->interrupt_handlers, interrupt_handlers, CP0_INTERRUPT_HANDLERS_COUNT*sizeof(*interrupt_handlers));
}

void poweron_cp0(struct cp0* cp0)
{
    uint32_t* cp0_regs;
    unsigned int* cp0_next_interrupt;

    cp0_regs = r4300_cp0_regs(cp0);
    cp0_next_interrupt = r4300_cp0_next_interrupt(cp0);

    memset(cp0_regs, 0, CP0_REGS_COUNT * sizeof(cp0_regs[0]));
    cp0_regs[CP0_RANDOM_REG] = UINT32_C(31);
    cp0_regs[CP0_STATUS_REG]= UINT32_C(0x34000000);
    cp0_regs[CP0_CONFIG_REG]= UINT32_C(0x6e463);
    cp0_regs[CP0_PREVID_REG] = UINT32_C(0xb00);
    cp0_regs[CP0_COUNT_REG] = UINT32_C(0x5000);
    cp0_regs[CP0_CAUSE_REG] = UINT32_C(0x5c);
    cp0_regs[CP0_CONTEXT_REG] = UINT32_C(0x7ffff0);
    cp0_regs[CP0_EPC_REG] = UINT32_C(0xffffffff);
    cp0_regs[CP0_BADVADDR_REG] = UINT32_C(0xffffffff);
    cp0_regs[CP0_ERROREPC_REG] = UINT32_C(0xffffffff);

    /* XXX: clarify what is done on poweron, in soft_reset and in execute... */
    cp0->interrupt_unsafe_state = 0;
    *cp0_next_interrupt = 0;
    cp0->special_done = 0;
    cp0->last_addr = UINT32_C(0xbfc00000);

    init_interrupt(cp0);

    poweron_tlb(&cp0->tlb);
}


uint32_t* r4300_cp0_regs(struct cp0* cp0)
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
    return cp0->regs;
#else
/* ARM dynarec uses a different memory layout */
    return cp0->new_dynarec_hot_state->cp0_regs;
#endif
}

uint32_t* r4300_cp0_last_addr(struct cp0* cp0)
{
    return &cp0->last_addr;
}

unsigned int* r4300_cp0_next_interrupt(struct cp0* cp0)
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
    return &cp0->next_interrupt;
#else
/* ARM dynarec uses a different memory layout */
    return &cp0->new_dynarec_hot_state->next_interrupt;
#endif
}


int check_cop1_unusable(struct r4300_core* r4300)
{
    uint32_t* cp0_regs = r4300_cp0_regs(&r4300->cp0);

    if (!(cp0_regs[CP0_STATUS_REG] & CP0_STATUS_CU1))
    {
        cp0_regs[CP0_CAUSE_REG] = CP0_CAUSE_EXCCODE_CPU | CP0_CAUSE_CE1;
        exception_general(r4300);
        return 1;
    }
    return 0;
}

void cp0_update_count(struct r4300_core* r4300)
{
    struct cp0* cp0 = &r4300->cp0;
    uint32_t* cp0_regs = r4300_cp0_regs(cp0);

#ifdef NEW_DYNAREC
    if (r4300->emumode != EMUMODE_DYNAREC)
    {
#endif
        cp0_regs[CP0_COUNT_REG] += ((*r4300_pc(r4300) - cp0->last_addr) >> 2) * cp0->count_per_op;
        cp0->last_addr = *r4300_pc(r4300);
#ifdef NEW_DYNAREC
    }
#endif

#ifdef COMPARE_CORE
   if (r4300->delay_slot)
     CoreCompareCallback();
#endif
/*#ifdef DBG
   if (g_DebuggerActive && !r4300->delay_slot) update_debugger(*r4300_pc(r4300));
#endif
*/
}

static void exception_epilog(struct r4300_core* r4300)
{
#ifndef NO_ASM
    if (r4300->emumode == EMUMODE_DYNAREC)
    {
#ifndef NEW_DYNAREC
        dyna_jump();
        if (!r4300->recomp.dyna_interp) { r4300->delay_slot = 0; }
#else
        /* ??? for new_dynarec dyna_interp is always 0 so that means delay_slot = 0 path is always taken */
        r4300->delay_slot = 0;
#endif
    }
#endif

#ifndef NEW_DYNAREC
    if (r4300->emumode != EMUMODE_DYNAREC || r4300->recomp.dyna_interp)
    {
        r4300->recomp.dyna_interp = 0;
#else
    if (r4300->emumode != EMUMODE_DYNAREC)
    {
#endif
        if (r4300->delay_slot)
        {
            r4300->skip_jump = *r4300_pc(r4300);
            *r4300_cp0_next_interrupt(&r4300->cp0) = 0;
        }
    }
}


void TLB_refill_exception(struct r4300_core* r4300, uint32_t address, int w)
{
    uint32_t* cp0_regs = r4300_cp0_regs(&r4300->cp0);
    int usual_handler = 0, i;

    if (r4300->emumode != EMUMODE_DYNAREC && w != 2) {
        cp0_update_count(r4300);
    }

    cp0_regs[CP0_CAUSE_REG] = (w == 1)
        ? CP0_CAUSE_EXCCODE_TLBS
        : CP0_CAUSE_EXCCODE_TLBL;

    cp0_regs[CP0_BADVADDR_REG] = address;
    cp0_regs[CP0_CONTEXT_REG] = (cp0_regs[CP0_CONTEXT_REG] & UINT32_C(0xFF80000F))
        | ((address >> 9) & UINT32_C(0x007FFFF0));
    cp0_regs[CP0_ENTRYHI_REG] = address & UINT32_C(0xFFFFE000);

    if (cp0_regs[CP0_STATUS_REG] & CP0_STATUS_EXL)
    {
        generic_jump_to(r4300, UINT32_C(0x80000180));


        if (r4300->delay_slot == 1 || r4300->delay_slot == 3) {
            cp0_regs[CP0_CAUSE_REG] |= CP0_CAUSE_BD;
        }
        else {
            cp0_regs[CP0_CAUSE_REG] &= ~CP0_CAUSE_BD;
        }
    }
    else
    {
        if (r4300->emumode != EMUMODE_PURE_INTERPRETER)
        {
            cp0_regs[CP0_EPC_REG] = (w != 2)
                ? *r4300_pc(r4300)
                : address;
        }
        else {
            cp0_regs[CP0_EPC_REG] = *r4300_pc(r4300);
        }

        cp0_regs[CP0_CAUSE_REG] &= ~CP0_CAUSE_BD;
        cp0_regs[CP0_STATUS_REG] |= CP0_STATUS_EXL;

        if (address >= UINT32_C(0x80000000) && address < UINT32_C(0xc0000000)) {
            usual_handler = 1;
        }

        for (i = 0; i < 32; i++)
        {
            if (/*r4300->cp0.tlb.entries[i].v_even &&*/ address >= r4300->cp0.tlb.entries[i].start_even &&
                    address <= r4300->cp0.tlb.entries[i].end_even) {
                usual_handler = 1;
            }
            if (/*r4300->cp0.tlb.entries[i].v_odd &&*/ address >= r4300->cp0.tlb.entries[i].start_odd &&
                    address <= r4300->cp0.tlb.entries[i].end_odd) {
                usual_handler = 1;
            }
        }

        generic_jump_to(r4300, (usual_handler)
                ? UINT32_C(0x80000180)
                : UINT32_C(0x80000000));
    }

    if (r4300->delay_slot == 1 || r4300->delay_slot == 3)
    {
        cp0_regs[CP0_CAUSE_REG] |= CP0_CAUSE_BD;
        cp0_regs[CP0_EPC_REG] -= 4;
    }
    else
    {
        cp0_regs[CP0_CAUSE_REG] &= ~CP0_CAUSE_BD;
    }
    if (w != 2) {
        cp0_regs[CP0_EPC_REG] -= 4;
    }

    r4300->cp0.last_addr = *r4300_pc(r4300);

    exception_epilog(r4300);
}

void exception_general(struct r4300_core* r4300)
{
    uint32_t* cp0_regs = r4300_cp0_regs(&r4300->cp0);

    cp0_update_count(r4300);
    cp0_regs[CP0_STATUS_REG] |= CP0_STATUS_EXL;

    cp0_regs[CP0_EPC_REG] = *r4300_pc(r4300);

    if (r4300->delay_slot == 1 || r4300->delay_slot == 3)
    {
        cp0_regs[CP0_CAUSE_REG] |= CP0_CAUSE_BD;
        cp0_regs[CP0_EPC_REG] -= 4;
    }
    else
    {
        cp0_regs[CP0_CAUSE_REG] &= ~CP0_CAUSE_BD;
    }

    generic_jump_to(r4300, UINT32_C(0x80000180));

    r4300->cp0.last_addr = *r4300_pc(r4300);

    exception_epilog(r4300);
}

