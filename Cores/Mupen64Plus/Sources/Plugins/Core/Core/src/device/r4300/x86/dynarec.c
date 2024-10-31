/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - dynarec.c                                               *
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

#include "assemble.h"
#include "interpret.h"
#include "regcache.h"

#include "api/callbacks.h"
#include "api/debugger.h"
#include "api/m64p_types.h"
#include "device/memory/memory.h"
#include "device/r4300/cached_interp.h"
#include "device/r4300/cp0.h"
#include "device/r4300/cp1.h"
#include "device/r4300/interrupt.h"
#include "device/r4300/recomp.h"
#include "device/rdram/rdram.h"
#include "main/main.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>


/* These are constants with addresses so that FLDCW can read them */
static const uint16_t trunc_mode = 0xf3f;
static const uint16_t round_mode = 0x33f;
static const uint16_t ceil_mode  = 0xb3f;
static const uint16_t floor_mode = 0x73f;

static const unsigned int precomp_instr_size = sizeof(struct precomp_instr);

/* Dynarec control functions */

void dyna_jump(void)
{
    struct r4300_core* r4300 = &g_dev.r4300;

    if (*r4300_stop(r4300) == 1)
    {
        dyna_stop(r4300);
        return;
    }

    if ((*r4300_pc_struct(r4300))->reg_cache_infos.need_map)
    {
        *r4300->recomp.return_address = (unsigned long) ((*r4300_pc_struct(r4300))->reg_cache_infos.jump_wrapper);
    }
    else
    {
        *r4300->recomp.return_address = (unsigned long) (r4300->cached_interp.actual->code + (*r4300_pc_struct(r4300))->local_addr);
    }
}

void dyna_stop(struct r4300_core* r4300)
{
    if (r4300->recomp.save_eip == 0)
    {
        DebugMessage(M64MSG_WARNING, "instruction pointer is 0 at dyna_stop()");
    }
    else
    {
        *r4300->recomp.return_address = (unsigned long)r4300->recomp.save_eip;
    }
}


/* M64P Pseudo instructions */

static void gencallinterp(struct r4300_core* r4300, uintptr_t addr, int jump)
{
    free_all_registers(r4300);
    simplify_access(r4300);

    if (jump) {
        mov_m32_imm32((unsigned int*)(&r4300->recomp.dyna_interp), 1);
    }

    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst));
    mov_reg32_imm32(EAX, addr);
    call_reg32(EAX);

    if (jump)
    {
        mov_m32_imm32((unsigned int*)(&r4300->recomp.dyna_interp), 0);
        mov_reg32_imm32(EAX, (unsigned int)dyna_jump);
        call_reg32(EAX);
    }
}

static void gencheck_cop1_unusable(struct r4300_core* r4300)
{
    free_all_registers(r4300);
    simplify_access(r4300);
    test_m32_imm32((unsigned int*)&r4300_cp0_regs(&r4300->cp0)[CP0_STATUS_REG], CP0_STATUS_CU1);
    jne_rj(0);

    jump_start_rel8(r4300);

    gencallinterp(r4300, (unsigned int)dynarec_check_cop1_unusable, 0);

    jump_end_rel8(r4300);
}

static void gencp0_update_count(struct r4300_core* r4300, unsigned int addr)
{
#if !defined(COMPARE_CORE) && !defined(DBG)
    mov_reg32_imm32(EAX, addr);
    sub_reg32_m32(EAX, (unsigned int*)(&r4300->cp0.last_addr));
    shr_reg32_imm8(EAX, 2);
    mov_reg32_m32(EDX, &r4300->cp0.count_per_op);
    mul_reg32(EDX);
    add_m32_reg32((unsigned int*)(&r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]), EAX);
#else
    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1));
    mov_reg32_imm32(EAX, (unsigned int)dynarec_cp0_update_count);
    call_reg32(EAX);
#endif
}

static void gencheck_interrupt(struct r4300_core* r4300, unsigned int instr_structure)
{
    mov_eax_memoffs32(r4300_cp0_next_interrupt(&r4300->cp0));
    cmp_reg32_m32(EAX, &r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]);
    ja_rj(17);
    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), instr_structure); // 10
    mov_reg32_imm32(EAX, (unsigned int)dynarec_gen_interrupt); // 5
    call_reg32(EAX); // 2
}

static void gencheck_interrupt_out(struct r4300_core* r4300, unsigned int addr)
{
    mov_eax_memoffs32(r4300_cp0_next_interrupt(&r4300->cp0));
    cmp_reg32_m32(EAX, &r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]);
    ja_rj(27);
    mov_m32_imm32((unsigned int*)(&r4300->recomp.fake_instr.addr), addr);
    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(&r4300->recomp.fake_instr));
    mov_reg32_imm32(EAX, (unsigned int)dynarec_gen_interrupt);
    call_reg32(EAX);
}

static void gencheck_interrupt_reg(struct r4300_core* r4300) // addr is in EAX
{
    mov_reg32_m32(EBX, r4300_cp0_next_interrupt(&r4300->cp0));
    cmp_reg32_m32(EBX, &r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]);
    ja_rj(22);
    mov_memoffs32_eax((unsigned int*)(&r4300->recomp.fake_instr.addr)); // 5
    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(&r4300->recomp.fake_instr)); // 10
    mov_reg32_imm32(EAX, (unsigned int)dynarec_gen_interrupt); // 5
    call_reg32(EAX); // 2
}

static void gendelayslot(struct r4300_core* r4300)
{
    mov_m32_imm32(&r4300->delay_slot, 1);
    recompile_opcode(r4300);

    free_all_registers(r4300);
    gencp0_update_count(r4300, r4300->recomp.dst->addr+4);

    mov_m32_imm32(&r4300->delay_slot, 0);
}

#ifdef COMPARE_CORE
extern unsigned int op; /* api/debugger.c */

void gendebug(struct r4300_core* r4300)
{
    free_all_registers(r4300);

    mov_m32_reg32((unsigned int*)&r4300->recomp.eax, EAX);
    mov_m32_reg32((unsigned int*)&r4300->recomp.ebx, EBX);
    mov_m32_reg32((unsigned int*)&r4300->recomp.ecx, ECX);
    mov_m32_reg32((unsigned int*)&r4300->recomp.edx, EDX);
    mov_m32_reg32((unsigned int*)&r4300->recomp.esp, ESP);
    mov_m32_reg32((unsigned int*)&r4300->recomp.ebp, EBP);
    mov_m32_reg32((unsigned int*)&r4300->recomp.esi, ESI);
    mov_m32_reg32((unsigned int*)&r4300->recomp.edi, EDI);

    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst));
    mov_m32_imm32((unsigned int*)(&op), (unsigned int)(r4300->recomp.src));
    mov_reg32_imm32(EAX, (unsigned int) CoreCompareCallback);
    call_reg32(EAX);

    mov_reg32_m32(EAX, (unsigned int*)&r4300->recomp.eax);
    mov_reg32_m32(EBX, (unsigned int*)&r4300->recomp.ebx);
    mov_reg32_m32(ECX, (unsigned int*)&r4300->recomp.ecx);
    mov_reg32_m32(EDX, (unsigned int*)&r4300->recomp.edx);
    mov_reg32_m32(ESP, (unsigned int*)&r4300->recomp.esp);
    mov_reg32_m32(EBP, (unsigned int*)&r4300->recomp.ebp);
    mov_reg32_m32(ESI, (unsigned int*)&r4300->recomp.esi);
    mov_reg32_m32(EDI, (unsigned int*)&r4300->recomp.edi);
}
#endif

void genni(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_NI, 0);
}

void gennotcompiled(struct r4300_core* r4300)
{
    free_all_registers(r4300);
    simplify_access(r4300);

    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst));
    mov_reg32_imm32(EAX, (unsigned int)dynarec_notcompiled);
    call_reg32(EAX);
}

void genlink_subblock(struct r4300_core* r4300)
{
    free_all_registers(r4300);
    jmp(r4300->recomp.dst->addr+4);
}

void genfin_block(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)dynarec_fin_block, 0);
}

/* Reserved */

void gen_RESERVED(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_RESERVED, 0);
}

/* Load instructions */

void gen_LB(struct r4300_core* r4300)
{
#ifdef INTERPRET_LB
    gencallinterp(r4300, (unsigned int)cached_interp_LB, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    add_eax_imm32((int)r4300->recomp.dst->f.i.immediate);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].read32);
        cmp_reg32_imm32(EAX, (unsigned int)read_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(95);

    mov_m32_imm32((unsigned int *)&(*r4300_pc_struct(r4300)), (unsigned int)(r4300->recomp.dst+1)); // 10
    /* if non RDRAM read,
     * compute shift (ECX) and address (EBX) to perform a regular read
     * Save ECX content to memory as ECX can be overwritten when calling read32 function */
    mov_reg32_reg32(ECX, EBX); // 2
    and_reg32_imm32(ECX, 3); // 6
    xor_reg32_imm32(ECX, 3); // 6
    shl_reg32_imm8(ECX, 3); // 3
    mov_m32_reg32((unsigned int *)&r4300->recomp.shift, ECX); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_m32_imm32((unsigned int *)(&r4300->recomp.rdword), (unsigned int)r4300->recomp.dst->f.i.rt); // 10
    mov_reg32_imm32(EBX, (unsigned int)dynarec_read_aligned_word); // 5
    call_reg32(EBX); // 2
    and_reg32_reg32(EAX, EAX); // 2
    je_rj(51); // 2

    mov_reg32_m32(EAX, (unsigned int *)r4300->recomp.dst->f.i.rt); // 6
    mov_reg32_m32(ECX, (unsigned int *)&r4300->recomp.shift); // 6
    shr_reg32_cl(EAX); // 2
    and_reg32_imm32(EAX, 0xff); // 6
    mov_m32_reg32((unsigned int*)r4300->recomp.dst->f.i.rt, EAX); // 6
    movsx_reg32_m8(EAX, (unsigned char *)r4300->recomp.dst->f.i.rt); // 7
    jmp_imm_short(16); // 2

    /* else (RDRAM read), read byte */
    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    xor_reg8_imm8(BL, 3); // 3
    movsx_reg32_8preg32pimm32(EAX, EBX, (unsigned int)r4300->rdram->dram); // 7

    set_register_state(r4300, EAX, (unsigned int*)r4300->recomp.dst->f.i.rt, 1);
#endif
}

void gen_LBU(struct r4300_core* r4300)
{
#ifdef INTERPRET_LBU
    gencallinterp(r4300, (unsigned int)cached_interp_LBU, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);
    /* get address in both EAX and EBX */
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    add_eax_imm32((int)r4300->recomp.dst->f.i.immediate);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].read32);
        cmp_reg32_imm32(EAX, (unsigned int)read_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(76);

    mov_m32_imm32((unsigned int *)&(*r4300_pc_struct(r4300)), (unsigned int)(r4300->recomp.dst+1)); // 10
    /* if non RDRAM read,
     * compute shift (ECX) and address (EBX) to perform a regular read
     * Save ECX content to memory as ECX can be overwritten when calling read32 function */
    mov_reg32_reg32(ECX, EBX); // 2
    and_reg32_imm32(ECX, 3); // 6
    xor_reg32_imm32(ECX, 3); // 6
    shl_reg32_imm8(ECX, 3); // 3
    mov_m32_reg32((unsigned int *)&r4300->recomp.shift, ECX); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_m32_imm32((unsigned int *)(&r4300->recomp.rdword), (unsigned int)r4300->recomp.dst->f.i.rt); // 10
    mov_reg32_imm32(EBX, (unsigned int)dynarec_read_aligned_word); // 5
    call_reg32(EBX); // 2
    and_reg32_reg32(EAX, EAX); // 2
    je_rj(31); // 2

    mov_reg32_m32(EAX, (unsigned int *)r4300->recomp.dst->f.i.rt); // 6
    mov_reg32_m32(ECX, (unsigned int *)&r4300->recomp.shift); // 6
    shr_reg32_cl(EAX); // 2
    jmp_imm_short(15); // 2

    /* else (RDRAM read), read byte */
    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    xor_reg8_imm8(BL, 3); // 3
    mov_reg32_preg32pimm32(EAX, EBX, (unsigned int)r4300->rdram->dram); // 6

    and_eax_imm32(0xFF);

    set_register_state(r4300, EAX, (unsigned int*)r4300->recomp.dst->f.i.rt, 1);
#endif
}

void gen_LH(struct r4300_core* r4300)
{
#ifdef INTERPRET_LH
    gencallinterp(r4300, (unsigned int)cached_interp_LH, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    add_eax_imm32((int)r4300->recomp.dst->f.i.immediate);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].read32);
        cmp_reg32_imm32(EAX, (unsigned int)read_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(95);

    mov_m32_imm32((unsigned int *)&(*r4300_pc_struct(r4300)), (unsigned int)(r4300->recomp.dst+1)); // 10
    /* if non RDRAM read,
     * compute shift (ECX) and address (EBX) to perform a regular read
     * Save ECX content to memory as ECX can be overwritten when calling read32 function */
    mov_reg32_reg32(ECX, EBX); // 2
    and_reg32_imm32(ECX, 2); // 6
    xor_reg32_imm32(ECX, 2); // 6
    shl_reg32_imm8(ECX, 3); // 3
    mov_m32_reg32((unsigned int *)&r4300->recomp.shift, ECX); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_m32_imm32((unsigned int *)(&r4300->recomp.rdword), (unsigned int)r4300->recomp.dst->f.i.rt); // 10
    mov_reg32_imm32(EBX, (unsigned int)dynarec_read_aligned_word); // 5
    call_reg32(EBX); // 2
    and_reg32_reg32(EAX, EAX); // 2
    je_rj(51); // 2

    mov_reg32_m32(EAX, (unsigned int *)r4300->recomp.dst->f.i.rt); // 6
    mov_reg32_m32(ECX, (unsigned int *)&r4300->recomp.shift); // 6
    shr_reg32_cl(EAX); // 2
    and_reg32_imm32(EAX, 0xffff); // 6
    mov_m32_reg32((unsigned int*)r4300->recomp.dst->f.i.rt, EAX); // 6
    movsx_reg32_m16(EAX, (unsigned short *)r4300->recomp.dst->f.i.rt); // 7
    jmp_imm_short(16); // 2

    /* else (RDRAM read), read hword */
    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    xor_reg8_imm8(BL, 2); // 3
    movsx_reg32_16preg32pimm32(EAX, EBX, (unsigned int)r4300->rdram->dram); // 7

    set_register_state(r4300, EAX, (unsigned int*)r4300->recomp.dst->f.i.rt, 1);
#endif
}

void gen_LHU(struct r4300_core* r4300)
{
#ifdef INTERPRET_LHU
    gencallinterp(r4300, (unsigned int)cached_interp_LHU, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);
    /* get address in both EAX and EBX */
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    add_eax_imm32((int)r4300->recomp.dst->f.i.immediate);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].read32);
        cmp_reg32_imm32(EAX, (unsigned int)read_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(76);

    mov_m32_imm32((unsigned int *)&(*r4300_pc_struct(r4300)), (unsigned int)(r4300->recomp.dst+1)); // 10
    /* if non RDRAM read,
     * compute shift (ECX) and address (EBX) to perform a regular read
     * Save ECX content to memory as ECX can be overwritten when calling read32 function */
    mov_reg32_reg32(ECX, EBX); // 2
    and_reg32_imm32(ECX, 2); // 6
    xor_reg32_imm32(ECX, 2); // 6
    shl_reg32_imm8(ECX, 3); // 3
    mov_m32_reg32((unsigned int *)&r4300->recomp.shift, ECX); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_m32_imm32((unsigned int *)(&r4300->recomp.rdword), (unsigned int)r4300->recomp.dst->f.i.rt); // 10
    mov_reg32_imm32(EBX, (unsigned int)dynarec_read_aligned_word); // 5
    call_reg32(EBX); // 2
    and_reg32_reg32(EAX, EAX); // 2
    je_rj(31); // 2

    mov_reg32_m32(EAX, (unsigned int *)r4300->recomp.dst->f.i.rt); // 6
    mov_reg32_m32(ECX, (unsigned int *)&r4300->recomp.shift); // 6
    shr_reg32_cl(EAX); // 2
    jmp_imm_short(15); // 2

    /* else (RDRAM read), read hword */
    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    xor_reg8_imm8(BL, 2); // 3
    mov_reg32_preg32pimm32(EAX, EBX, (unsigned int)r4300->rdram->dram); // 6

    and_eax_imm32(0xFFFF);

    set_register_state(r4300, EAX, (unsigned int*)r4300->recomp.dst->f.i.rt, 1);
#endif
}

void gen_LL(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_LL, 0);
}

void gen_LW(struct r4300_core* r4300)
{
#ifdef INTERPRET_LW
    gencallinterp(r4300, (unsigned int)cached_interp_LW, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    add_eax_imm32((int)r4300->recomp.dst->f.i.immediate);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].read32);
        cmp_reg32_imm32(EAX, (unsigned int)read_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(40);

    mov_m32_imm32((unsigned int *)&(*r4300_pc_struct(r4300)), (unsigned int)(r4300->recomp.dst+1)); // 10
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_m32_imm32((unsigned int *)(&r4300->recomp.rdword), (unsigned int)r4300->recomp.dst->f.i.rt); // 10
    mov_reg32_imm32(EBX, (unsigned int)dynarec_read_aligned_word); // 5
    call_reg32(EBX); // 2
    mov_eax_memoffs32((unsigned int *)(r4300->recomp.dst->f.i.rt)); // 5
    jmp_imm_short(12); // 2

    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    mov_reg32_preg32pimm32(EAX, EBX, (unsigned int)r4300->rdram->dram); // 6

    set_register_state(r4300, EAX, (unsigned int*)r4300->recomp.dst->f.i.rt, 1);
#endif
}

void gen_LWU(struct r4300_core* r4300)
{
#ifdef INTERPRET_LWU
    gencallinterp(r4300, (unsigned int)cached_interp_LWU, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    add_eax_imm32((int)r4300->recomp.dst->f.i.immediate);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].read32);
        cmp_reg32_imm32(EAX, (unsigned int)read_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(40);

    mov_m32_imm32((unsigned int *)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1)); // 10
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_m32_imm32((unsigned int *)(&r4300->recomp.rdword), (unsigned int)r4300->recomp.dst->f.i.rt); // 10
    mov_reg32_imm32(EBX, (unsigned int)dynarec_read_aligned_word); // 5
    call_reg32(EBX); // 2
    mov_eax_memoffs32((unsigned int *)(r4300->recomp.dst->f.i.rt)); // 5
    jmp_imm_short(12); // 2

    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    mov_reg32_preg32pimm32(EAX, EBX, (unsigned int)r4300->rdram->dram); // 6

    xor_reg32_reg32(EBX, EBX);

    set_64_register_state(r4300, EAX, EBX, (unsigned int*)r4300->recomp.dst->f.i.rt, 1);
#endif
}

void gen_LWL(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_LWL, 0);
}

void gen_LWR(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_LWR, 0);
}

void gen_LD(struct r4300_core* r4300)
{
#ifdef INTERPRET_LD
    gencallinterp(r4300, (unsigned int)cached_interp_LD, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    add_eax_imm32((int)r4300->recomp.dst->f.i.immediate);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].read32);
        cmp_reg32_imm32(EAX, (unsigned int)read_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(46);

    mov_m32_imm32((unsigned int *)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1)); // 10
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_m32_imm32((unsigned int *)(&r4300->recomp.rdword), (unsigned int)r4300->recomp.dst->f.i.rt); // 10
    mov_reg32_imm32(EBX, (unsigned int)dynarec_read_aligned_dword); // 5
    call_reg32(EBX); // 2
    mov_eax_memoffs32((unsigned int *)(r4300->recomp.dst->f.i.rt)); // 5
    mov_reg32_m32(ECX, (unsigned int *)(r4300->recomp.dst->f.i.rt)+1); // 6
    jmp_imm_short(18); // 2

    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    mov_reg32_preg32pimm32(EAX, EBX, ((unsigned int)r4300->rdram->dram)+4); // 6
    mov_reg32_preg32pimm32(ECX, EBX, ((unsigned int)r4300->rdram->dram)); // 6

    set_64_register_state(r4300, EAX, ECX, (unsigned int*)r4300->recomp.dst->f.i.rt, 1);
#endif
}

void gen_LDL(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_LDL, 0);
}

void gen_LDR(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_LDR, 0);
}

/* Store instructions */

void gen_SB(struct r4300_core* r4300)
{
#ifdef INTERPRET_SB
    gencallinterp(r4300, (unsigned int)cached_interp_SB, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);

    /* get value in EDX */
    xor_reg32_reg32(EDX, EDX);
    mov_reg8_m8(DL, (unsigned char *)r4300->recomp.dst->f.i.rt);
    /* get address in both EAX and EBX */
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    add_eax_imm32((int)r4300->recomp.dst->f.i.immediate);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].write32);
        cmp_reg32_imm32(EAX, (unsigned int)write_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(68);

    mov_m32_imm32((unsigned int *)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1)); // 10
    /* if non RDRAM write,
     * compute shift (ECX), word (EDX), wmask (EDX) and address (EBX) to perform a regular write */
    mov_reg32_reg32(ECX, EBX); // 2
    and_reg32_imm32(ECX, 3); // 6
    xor_reg32_imm32(ECX, 3); // 6
    shl_reg32_imm8(ECX, 3); // 3
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    shl_reg32_cl(EDX); // 2
    mov_m32_reg32((unsigned int *)(&r4300->recomp.wword), EDX); // 6
    mov_reg32_imm32(EDX, 0xff); // 5
    shl_reg32_cl(EDX); // 2
    mov_m32_reg32((unsigned int *)(&r4300->recomp.wmask), EDX); // 6
    mov_reg32_imm32(EBX, (unsigned int)dynarec_write_aligned_word); // 5
    call_reg32(EBX); // 2
    mov_eax_memoffs32((unsigned int *)(&r4300->recomp.address)); // 5
    jmp_imm_short(17); // 2

    /* else (RDRAM write), write byte */
    mov_reg32_reg32(EAX, EBX); // 2
    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    xor_reg8_imm8(BL, 3); // 3
    mov_preg32pimm32_reg8(EBX, (unsigned int)r4300->rdram->dram, DL); // 6

    mov_reg32_reg32(EBX, EAX);
    shr_reg32_imm8(EBX, 12);
    cmp_preg32pimm32_imm8(EBX, (unsigned int)r4300->cached_interp.invalid_code, 0);
    jne_rj(54);

    mov_reg32_reg32(ECX, EBX); // 2
    shl_reg32_imm8(EBX, 2); // 3
    mov_reg32_preg32pimm32(EBX, EBX, (unsigned int)r4300->cached_interp.blocks); // 6
    mov_reg32_preg32pimm32(EBX, EBX, (int)&r4300->cached_interp.actual->block - (int)r4300->cached_interp.actual); // 6
    and_eax_imm32(0xFFF); // 5
    shr_reg32_imm8(EAX, 2); // 3
    mov_reg32_imm32(EDX, sizeof(struct precomp_instr)); // 5
    mul_reg32(EDX); // 2
    mov_reg32_preg32preg32pimm32(EAX, EAX, EBX, (int)&r4300->recomp.dst->ops - (int)r4300->recomp.dst); // 7
    cmp_reg32_imm32(EAX, (unsigned int)dynarec_notcompiled); // 6
    je_rj(7); // 2
    mov_preg32pimm32_imm8(ECX, (unsigned int)r4300->cached_interp.invalid_code, 1); // 7
#endif
}

void gen_SH(struct r4300_core* r4300)
{
#ifdef INTERPRET_SH
    gencallinterp(r4300, (unsigned int)cached_interp_SH, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);

    /* get value in EDX */
    xor_reg32_reg32(EDX, EDX);
    mov_reg16_m16(DX, (unsigned short *)r4300->recomp.dst->f.i.rt);
    /* get address in both EAX and EBX */
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    add_eax_imm32((int)r4300->recomp.dst->f.i.immediate);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].write32);
        cmp_reg32_imm32(EAX, (unsigned int)write_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(68);

    mov_m32_imm32((unsigned int *)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1)); // 10
    /* if non RDRAM write,
     * compute shift (ECX), word (EDX), wmask (EDX) and address (EBX) to perform a regular write */
    mov_reg32_reg32(ECX, EBX); // 2
    and_reg32_imm32(ECX, 2); // 6
    xor_reg32_imm32(ECX, 2); // 6
    shl_reg32_imm8(ECX, 3); // 3
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    shl_reg32_cl(EDX); // 2
    mov_m32_reg32((unsigned int *)(&r4300->recomp.wword), EDX); // 6
    mov_reg32_imm32(EDX, 0xffff); // 5
    shl_reg32_cl(EDX); // 2
    mov_m32_reg32((unsigned int *)(&r4300->recomp.wmask), EDX); // 6
    mov_reg32_imm32(EBX, (unsigned int)dynarec_write_aligned_word); // 5
    call_reg32(EBX); // 2
    mov_eax_memoffs32((unsigned int *)(&r4300->recomp.address)); // 5
    jmp_imm_short(18); // 2

    /* else (RDRAM write), write hword */
    mov_reg32_reg32(EAX, EBX); // 2
    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    xor_reg8_imm8(BL, 2); // 3
    mov_preg32pimm32_reg16(EBX, (unsigned int)r4300->rdram->dram, DX); // 7

    mov_reg32_reg32(EBX, EAX);
    shr_reg32_imm8(EBX, 12);
    cmp_preg32pimm32_imm8(EBX, (unsigned int)r4300->cached_interp.invalid_code, 0);
    jne_rj(54);
    mov_reg32_reg32(ECX, EBX); // 2
    shl_reg32_imm8(EBX, 2); // 3
    mov_reg32_preg32pimm32(EBX, EBX, (unsigned int)r4300->cached_interp.blocks); // 6
    mov_reg32_preg32pimm32(EBX, EBX, (int)&r4300->cached_interp.actual->block - (int)r4300->cached_interp.actual); // 6
    and_eax_imm32(0xFFF); // 5
    shr_reg32_imm8(EAX, 2); // 3
    mov_reg32_imm32(EDX, sizeof(struct precomp_instr)); // 5
    mul_reg32(EDX); // 2
    mov_reg32_preg32preg32pimm32(EAX, EAX, EBX, (int)&r4300->recomp.dst->ops - (int)r4300->recomp.dst); // 7
    cmp_reg32_imm32(EAX, (unsigned int)dynarec_notcompiled); // 6
    je_rj(7); // 2
    mov_preg32pimm32_imm8(ECX, (unsigned int)r4300->cached_interp.invalid_code, 1); // 7
#endif
}

void gen_SC(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_SC, 0);
}

void gen_SW(struct r4300_core* r4300)
{
#ifdef INTERPRET_SW
    gencallinterp(r4300, (unsigned int)cached_interp_SW, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);
    mov_reg32_m32(ECX, (unsigned int *)r4300->recomp.dst->f.i.rt);
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    add_eax_imm32((int)r4300->recomp.dst->f.i.immediate);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].write32);
        cmp_reg32_imm32(EAX, (unsigned int)write_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(46);

    mov_m32_imm32((unsigned int *)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1)); // 10
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.wword), ECX); // 6
    mov_m32_imm32((unsigned int *)(&r4300->recomp.wmask), ~UINT32_C(0)); // 10
    mov_reg32_imm32(EBX, (unsigned int)dynarec_write_aligned_word); // 5
    call_reg32(EBX); // 2
    mov_eax_memoffs32((unsigned int *)(&r4300->recomp.address)); // 5
    jmp_imm_short(14); // 2

    mov_reg32_reg32(EAX, EBX); // 2
    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    mov_preg32pimm32_reg32(EBX, (unsigned int)r4300->rdram->dram, ECX); // 6

    mov_reg32_reg32(EBX, EAX);
    shr_reg32_imm8(EBX, 12);
    cmp_preg32pimm32_imm8(EBX, (unsigned int)r4300->cached_interp.invalid_code, 0);
    jne_rj(54);
    mov_reg32_reg32(ECX, EBX); // 2
    shl_reg32_imm8(EBX, 2); // 3
    mov_reg32_preg32pimm32(EBX, EBX, (unsigned int)r4300->cached_interp.blocks); // 6
    mov_reg32_preg32pimm32(EBX, EBX, (int)&r4300->cached_interp.actual->block - (int)r4300->cached_interp.actual); // 6
    and_eax_imm32(0xFFF); // 5
    shr_reg32_imm8(EAX, 2); // 3
    mov_reg32_imm32(EDX, sizeof(struct precomp_instr)); // 5
    mul_reg32(EDX); // 2
    mov_reg32_preg32preg32pimm32(EAX, EAX, EBX, (int)&r4300->recomp.dst->ops - (int)r4300->recomp.dst); // 7
    cmp_reg32_imm32(EAX, (unsigned int)dynarec_notcompiled); // 6
    je_rj(7); // 2
    mov_preg32pimm32_imm8(ECX, (unsigned int)r4300->cached_interp.invalid_code, 1); // 7
#endif
}

void gen_SWL(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_SWL, 0);
}

void gen_SWR(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_SWR, 0);
}

void gen_SD(struct r4300_core* r4300)
{
#ifdef INTERPRET_SD
    gencallinterp(r4300, (unsigned int)cached_interp_SD, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);

    mov_reg32_m32(ECX, (unsigned int *)r4300->recomp.dst->f.i.rt);
    mov_reg32_m32(EDX, ((unsigned int *)r4300->recomp.dst->f.i.rt)+1);
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    add_eax_imm32((int)r4300->recomp.dst->f.i.immediate);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].write32);
        cmp_reg32_imm32(EAX, (unsigned int)write_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(42);

    mov_m32_imm32((unsigned int *)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1)); // 10
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.wdword), ECX); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.wdword)+1, EDX); // 6
    mov_reg32_imm32(EBX, (unsigned int)dynarec_write_aligned_dword); // 5
    call_reg32(EBX); // 2
    mov_eax_memoffs32((unsigned int *)(&r4300->recomp.address)); // 5
    jmp_imm_short(20); // 2

    mov_reg32_reg32(EAX, EBX); // 2
    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    mov_preg32pimm32_reg32(EBX, ((unsigned int)r4300->rdram->dram)+4, ECX); // 6
    mov_preg32pimm32_reg32(EBX, ((unsigned int)r4300->rdram->dram)+0, EDX); // 6

    mov_reg32_reg32(EBX, EAX);
    shr_reg32_imm8(EBX, 12);
    cmp_preg32pimm32_imm8(EBX, (unsigned int)r4300->cached_interp.invalid_code, 0);
    jne_rj(54);
    mov_reg32_reg32(ECX, EBX); // 2
    shl_reg32_imm8(EBX, 2); // 3
    mov_reg32_preg32pimm32(EBX, EBX, (unsigned int)r4300->cached_interp.blocks); // 6
    mov_reg32_preg32pimm32(EBX, EBX, (int)&r4300->cached_interp.actual->block - (int)r4300->cached_interp.actual); // 6
    and_eax_imm32(0xFFF); // 5
    shr_reg32_imm8(EAX, 2); // 3
    mov_reg32_imm32(EDX, sizeof(struct precomp_instr)); // 5
    mul_reg32(EDX); // 2
    mov_reg32_preg32preg32pimm32(EAX, EAX, EBX, (int)&r4300->recomp.dst->ops - (int)r4300->recomp.dst); // 7
    cmp_reg32_imm32(EAX, (unsigned int)dynarec_notcompiled); // 6
    je_rj(7); // 2
    mov_preg32pimm32_imm8(ECX, (unsigned int)r4300->cached_interp.invalid_code, 1); // 7
#endif
}

void gen_SDL(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_SDL, 0);
}

void gen_SDR(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_SDR, 0);
}

/* Computational instructions */

void gen_ADD(struct r4300_core* r4300)
{
#ifdef INTERPRET_ADD
    gencallinterp(r4300, (unsigned int)cached_interp_ADD, 0);
#else
    int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt != rd && rs != rd)
    {
        mov_reg32_reg32(rd, rs);
        add_reg32_reg32(rd, rt);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs);
        add_reg32_reg32(temp, rt);
        mov_reg32_reg32(rd, temp);
    }
#endif
}

void gen_ADDU(struct r4300_core* r4300)
{
#ifdef INTERPRET_ADDU
    gencallinterp(r4300, (unsigned int)cached_interp_ADDU, 0);
#else
    int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt != rd && rs != rd)
    {
        mov_reg32_reg32(rd, rs);
        add_reg32_reg32(rd, rt);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs);
        add_reg32_reg32(temp, rt);
        mov_reg32_reg32(rd, temp);
    }
#endif
}

void gen_ADDI(struct r4300_core* r4300)
{
#ifdef INTERPRET_ADDI
    gencallinterp(r4300, (unsigned int)cached_interp_ADDI, 0);
#else
    int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rt = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

    mov_reg32_reg32(rt, rs);
    add_reg32_imm32(rt,(int)r4300->recomp.dst->f.i.immediate);
#endif
}

void gen_ADDIU(struct r4300_core* r4300)
{
#ifdef INTERPRET_ADDIU
    gencallinterp(r4300, (unsigned int)cached_interp_ADDIU, 0);
#else
    int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rt = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

    mov_reg32_reg32(rt, rs);
    add_reg32_imm32(rt,(int)r4300->recomp.dst->f.i.immediate);
#endif
}

void gen_DADD(struct r4300_core* r4300)
{
#ifdef INTERPRET_DADD
    gencallinterp(r4300, (unsigned int)cached_interp_DADD, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt1 != rd1 && rs1 != rd1)
    {
        mov_reg32_reg32(rd1, rs1);
        mov_reg32_reg32(rd2, rs2);
        add_reg32_reg32(rd1, rt1);
        adc_reg32_reg32(rd2, rt2);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs1);
        add_reg32_reg32(temp, rt1);
        mov_reg32_reg32(rd1, temp);
        mov_reg32_reg32(temp, rs2);
        adc_reg32_reg32(temp, rt2);
        mov_reg32_reg32(rd2, temp);
    }
#endif
}

void gen_DADDU(struct r4300_core* r4300)
{
#ifdef INTERPRET_DADDU
    gencallinterp(r4300, (unsigned int)cached_interp_DADDU, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt1 != rd1 && rs1 != rd1)
    {
        mov_reg32_reg32(rd1, rs1);
        mov_reg32_reg32(rd2, rs2);
        add_reg32_reg32(rd1, rt1);
        adc_reg32_reg32(rd2, rt2);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs1);
        add_reg32_reg32(temp, rt1);
        mov_reg32_reg32(rd1, temp);
        mov_reg32_reg32(temp, rs2);
        adc_reg32_reg32(temp, rt2);
        mov_reg32_reg32(rd2, temp);
    }
#endif
}

void gen_DADDI(struct r4300_core* r4300)
{
#ifdef INTERPRET_DADDI
    gencallinterp(r4300, (unsigned int)cached_interp_DADDI, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rt1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
    int rt2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

    mov_reg32_reg32(rt1, rs1);
    mov_reg32_reg32(rt2, rs2);
    add_reg32_imm32(rt1, r4300->recomp.dst->f.i.immediate);
    adc_reg32_imm32(rt2, (int)r4300->recomp.dst->f.i.immediate>>31);
#endif
}

void gen_DADDIU(struct r4300_core* r4300)
{
#ifdef INTERPRET_DADDIU
    gencallinterp(r4300, (unsigned int)cached_interp_DADDIU, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rt1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
    int rt2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

    mov_reg32_reg32(rt1, rs1);
    mov_reg32_reg32(rt2, rs2);
    add_reg32_imm32(rt1, r4300->recomp.dst->f.i.immediate);
    adc_reg32_imm32(rt2, (int)r4300->recomp.dst->f.i.immediate>>31);
#endif
}

void gen_SUB(struct r4300_core* r4300)
{
#ifdef INTERPRET_SUB
    gencallinterp(r4300, (unsigned int)cached_interp_SUB, 0);
#else
    int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt != rd && rs != rd)
    {
        mov_reg32_reg32(rd, rs);
        sub_reg32_reg32(rd, rt);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs);
        sub_reg32_reg32(temp, rt);
        mov_reg32_reg32(rd, temp);
    }
#endif
}

void gen_SUBU(struct r4300_core* r4300)
{
#ifdef INTERPRET_SUBU
    gencallinterp(r4300, (unsigned int)cached_interp_SUBU, 0);
#else
    int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt != rd && rs != rd)
    {
        mov_reg32_reg32(rd, rs);
        sub_reg32_reg32(rd, rt);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs);
        sub_reg32_reg32(temp, rt);
        mov_reg32_reg32(rd, temp);
    }
#endif
}

void gen_DSUB(struct r4300_core* r4300)
{
#ifdef INTERPRET_DSUB
    gencallinterp(r4300, (unsigned int)cached_interp_DSUB, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt1 != rd1 && rs1 != rd1)
    {
        mov_reg32_reg32(rd1, rs1);
        mov_reg32_reg32(rd2, rs2);
        sub_reg32_reg32(rd1, rt1);
        sbb_reg32_reg32(rd2, rt2);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs1);
        sub_reg32_reg32(temp, rt1);
        mov_reg32_reg32(rd1, temp);
        mov_reg32_reg32(temp, rs2);
        sbb_reg32_reg32(temp, rt2);
        mov_reg32_reg32(rd2, temp);
    }
#endif
}

void gen_DSUBU(struct r4300_core* r4300)
{
#ifdef INTERPRET_DSUBU
    gencallinterp(r4300, (unsigned int)cached_interp_DSUBU, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt1 != rd1 && rs1 != rd1)
    {
        mov_reg32_reg32(rd1, rs1);
        mov_reg32_reg32(rd2, rs2);
        sub_reg32_reg32(rd1, rt1);
        sbb_reg32_reg32(rd2, rt2);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs1);
        sub_reg32_reg32(temp, rt1);
        mov_reg32_reg32(rd1, temp);
        mov_reg32_reg32(temp, rs2);
        sbb_reg32_reg32(temp, rt2);
        mov_reg32_reg32(rd2, temp);
    }
#endif
}

void gen_SLT(struct r4300_core* r4300)
{
#ifdef INTERPRET_SLT
    gencallinterp(r4300, (unsigned int)cached_interp_SLT, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    cmp_reg32_reg32(rs2, rt2);
    jl_rj(13);
    jne_rj(4); // 2
    cmp_reg32_reg32(rs1, rt1); // 2
    jl_rj(7); // 2
    mov_reg32_imm32(rd, 0); // 5
    jmp_imm_short(5); // 2
    mov_reg32_imm32(rd, 1); // 5
#endif
}

void gen_SLTU(struct r4300_core* r4300)
{
#ifdef INTERPRET_SLTU
    gencallinterp(r4300, (unsigned int)cached_interp_SLTU, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    cmp_reg32_reg32(rs2, rt2);
    jb_rj(13);
    jne_rj(4); // 2
    cmp_reg32_reg32(rs1, rt1); // 2
    jb_rj(7); // 2
    mov_reg32_imm32(rd, 0); // 5
    jmp_imm_short(5); // 2
    mov_reg32_imm32(rd, 1); // 5
#endif
}

void gen_SLTI(struct r4300_core* r4300)
{
#ifdef INTERPRET_SLTI
    gencallinterp(r4300, (unsigned int)cached_interp_SLTI, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rt = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
    long long imm = (long long)r4300->recomp.dst->f.i.immediate;

    cmp_reg32_imm32(rs2, (unsigned int)(imm >> 32));
    jl_rj(17);
    jne_rj(8); // 2
    cmp_reg32_imm32(rs1, (unsigned int)imm); // 6
    jl_rj(7); // 2
    mov_reg32_imm32(rt, 0); // 5
    jmp_imm_short(5); // 2
    mov_reg32_imm32(rt, 1); // 5
#endif
}

void gen_SLTIU(struct r4300_core* r4300)
{
#ifdef INTERPRET_SLTIU
    gencallinterp(r4300, (unsigned int)cached_interp_SLTIU, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rt = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
    long long imm = (long long)r4300->recomp.dst->f.i.immediate;

    cmp_reg32_imm32(rs2, (unsigned int)(imm >> 32));
    jb_rj(17);
    jne_rj(8); // 2
    cmp_reg32_imm32(rs1, (unsigned int)imm); // 6
    jb_rj(7); // 2
    mov_reg32_imm32(rt, 0); // 5
    jmp_imm_short(5); // 2
    mov_reg32_imm32(rt, 1); // 5
#endif
}

void gen_AND(struct r4300_core* r4300)
{
#ifdef INTERPRET_AND
    gencallinterp(r4300, (unsigned int)cached_interp_AND, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt1 != rd1 && rs1 != rd1)
    {
        mov_reg32_reg32(rd1, rs1);
        mov_reg32_reg32(rd2, rs2);
        and_reg32_reg32(rd1, rt1);
        and_reg32_reg32(rd2, rt2);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs1);
        and_reg32_reg32(temp, rt1);
        mov_reg32_reg32(rd1, temp);
        mov_reg32_reg32(temp, rs2);
        and_reg32_reg32(temp, rt2);
        mov_reg32_reg32(rd2, temp);
    }
#endif
}

void gen_ANDI(struct r4300_core* r4300)
{
#ifdef INTERPRET_ANDI
    gencallinterp(r4300, (unsigned int)cached_interp_ANDI, 0);
#else
    int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rt = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

    mov_reg32_reg32(rt, rs);
    and_reg32_imm32(rt, (unsigned short)r4300->recomp.dst->f.i.immediate);
#endif
}

void gen_OR(struct r4300_core* r4300)
{
#ifdef INTERPRET_OR
    gencallinterp(r4300, (unsigned int)cached_interp_OR, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt1 != rd1 && rs1 != rd1)
    {
        mov_reg32_reg32(rd1, rs1);
        mov_reg32_reg32(rd2, rs2);
        or_reg32_reg32(rd1, rt1);
        or_reg32_reg32(rd2, rt2);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs1);
        or_reg32_reg32(temp, rt1);
        mov_reg32_reg32(rd1, temp);
        mov_reg32_reg32(temp, rs2);
        or_reg32_reg32(temp, rt2);
        mov_reg32_reg32(rd2, temp);
    }
#endif
}

void gen_ORI(struct r4300_core* r4300)
{
#ifdef INTERPRET_ORI
    gencallinterp(r4300, (unsigned int)cached_interp_ORI, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rt1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
    int rt2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

    mov_reg32_reg32(rt1, rs1);
    mov_reg32_reg32(rt2, rs2);
    or_reg32_imm32(rt1, (unsigned short)r4300->recomp.dst->f.i.immediate);
#endif
}

void gen_XOR(struct r4300_core* r4300)
{
#ifdef INTERPRET_XOR
    gencallinterp(r4300, (unsigned int)cached_interp_XOR, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt1 != rd1 && rs1 != rd1)
    {
        mov_reg32_reg32(rd1, rs1);
        mov_reg32_reg32(rd2, rs2);
        xor_reg32_reg32(rd1, rt1);
        xor_reg32_reg32(rd2, rt2);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs1);
        xor_reg32_reg32(temp, rt1);
        mov_reg32_reg32(rd1, temp);
        mov_reg32_reg32(temp, rs2);
        xor_reg32_reg32(temp, rt2);
        mov_reg32_reg32(rd2, temp);
    }
#endif
}

void gen_XORI(struct r4300_core* r4300)
{
#ifdef INTERPRET_XORI
    gencallinterp(r4300, (unsigned int)cached_interp_XORI, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rt1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
    int rt2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

    mov_reg32_reg32(rt1, rs1);
    mov_reg32_reg32(rt2, rs2);
    xor_reg32_imm32(rt1, (unsigned short)r4300->recomp.dst->f.i.immediate);
#endif
}

void gen_NOR(struct r4300_core* r4300)
{
#ifdef INTERPRET_NOR
    gencallinterp(r4300, (unsigned int)cached_interp_NOR, 0);
#else
    int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rs);
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rt1 != rd1 && rs1 != rd1)
    {
        mov_reg32_reg32(rd1, rs1);
        mov_reg32_reg32(rd2, rs2);
        or_reg32_reg32(rd1, rt1);
        or_reg32_reg32(rd2, rt2);
        not_reg32(rd1);
        not_reg32(rd2);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rs1);
        or_reg32_reg32(temp, rt1);
        mov_reg32_reg32(rd1, temp);
        mov_reg32_reg32(temp, rs2);
        or_reg32_reg32(temp, rt2);
        mov_reg32_reg32(rd2, temp);
        not_reg32(rd1);
        not_reg32(rd2);
    }
#endif
}

void gen_LUI(struct r4300_core* r4300)
{
#ifdef INTERPRET_LUI
    gencallinterp(r4300, (unsigned int)cached_interp_LUI, 0);
#else
    int rt = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

    mov_reg32_imm32(rt, (unsigned int)r4300->recomp.dst->f.i.immediate << 16);
#endif
}

/* Shift instructions */

void gen_NOP(struct r4300_core* r4300)
{
}

void gen_SLL(struct r4300_core* r4300)
{
#ifdef INTERPRET_SLL
    gencallinterp(r4300, (unsigned int)cached_interp_SLL, 0);
#else
    int rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    mov_reg32_reg32(rd, rt);
    shl_reg32_imm8(rd, r4300->recomp.dst->f.r.sa);
#endif
}

void gen_SLLV(struct r4300_core* r4300)
{
#ifdef INTERPRET_SLLV
    gencallinterp(r4300, (unsigned int)cached_interp_SLLV, 0);
#else
    int rt, rd;
    allocate_register_manually(r4300, ECX, (unsigned int *)r4300->recomp.dst->f.r.rs);

    rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rd != ECX)
    {
        mov_reg32_reg32(rd, rt);
        shl_reg32_cl(rd);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rt);
        shl_reg32_cl(temp);
        mov_reg32_reg32(rd, temp);
    }
#endif
}

void gen_DSLL(struct r4300_core* r4300)
{
#ifdef INTERPRET_DSLL
    gencallinterp(r4300, (unsigned int)cached_interp_DSLL, 0);
#else
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    mov_reg32_reg32(rd1, rt1);
    mov_reg32_reg32(rd2, rt2);
    shld_reg32_reg32_imm8(rd2, rd1, r4300->recomp.dst->f.r.sa);
    shl_reg32_imm8(rd1, r4300->recomp.dst->f.r.sa);
    if (r4300->recomp.dst->f.r.sa & 0x20)
    {
        mov_reg32_reg32(rd2, rd1);
        xor_reg32_reg32(rd1, rd1);
    }
#endif
}

void gen_DSLLV(struct r4300_core* r4300)
{
#ifdef INTERPRET_DSLLV
    gencallinterp(r4300, (unsigned int)cached_interp_DSLLV, 0);
#else
    int rt1, rt2, rd1, rd2;
    allocate_register_manually(r4300, ECX, (unsigned int *)r4300->recomp.dst->f.r.rs);

    rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rd1 != ECX && rd2 != ECX)
    {
        mov_reg32_reg32(rd1, rt1);
        mov_reg32_reg32(rd2, rt2);
        shld_reg32_reg32_cl(rd2,rd1);
        shl_reg32_cl(rd1);
        test_reg32_imm32(ECX, 0x20);
        je_rj(4);
        mov_reg32_reg32(rd2, rd1); // 2
        xor_reg32_reg32(rd1, rd1); // 2
    }
    else
    {
        int temp1, temp2;
        temp1 = lru_register(r4300);
        temp2 = lru_register_exc1(r4300, temp1);
        free_register(r4300, temp1);
        free_register(r4300, temp2);

        mov_reg32_reg32(temp1, rt1);
        mov_reg32_reg32(temp2, rt2);
        shld_reg32_reg32_cl(temp2, temp1);
        shl_reg32_cl(temp1);
        test_reg32_imm32(ECX, 0x20);
        je_rj(4);
        mov_reg32_reg32(temp2, temp1); // 2
        xor_reg32_reg32(temp1, temp1); // 2

        mov_reg32_reg32(rd1, temp1);
        mov_reg32_reg32(rd2, temp2);
    }
#endif
}

void gen_DSLL32(struct r4300_core* r4300)
{
#ifdef INTERPRET_DSLL32
    gencallinterp(r4300, (unsigned int)cached_interp_DSLL32, 0);
#else
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    mov_reg32_reg32(rd2, rt1);
    shl_reg32_imm8(rd2, r4300->recomp.dst->f.r.sa);
    xor_reg32_reg32(rd1, rd1);
#endif
}

void gen_SRL(struct r4300_core* r4300)
{
#ifdef INTERPRET_SRL
    gencallinterp(r4300, (unsigned int)cached_interp_SRL, 0);
#else
    int rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    mov_reg32_reg32(rd, rt);
    shr_reg32_imm8(rd, r4300->recomp.dst->f.r.sa);
#endif
}

void gen_SRLV(struct r4300_core* r4300)
{
#ifdef INTERPRET_SRLV
    gencallinterp(r4300, (unsigned int)cached_interp_SRLV, 0);
#else
    int rt, rd;
    allocate_register_manually(r4300, ECX, (unsigned int *)r4300->recomp.dst->f.r.rs);

    rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rd != ECX)
    {
        mov_reg32_reg32(rd, rt);
        shr_reg32_cl(rd);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rt);
        shr_reg32_cl(temp);
        mov_reg32_reg32(rd, temp);
    }
#endif
}

void gen_DSRL(struct r4300_core* r4300)
{
#ifdef INTERPRET_DSRL
    gencallinterp(r4300, (unsigned int)cached_interp_DSRL, 0);
#else
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    mov_reg32_reg32(rd1, rt1);
    mov_reg32_reg32(rd2, rt2);
    shrd_reg32_reg32_imm8(rd1, rd2, r4300->recomp.dst->f.r.sa);
    shr_reg32_imm8(rd2, r4300->recomp.dst->f.r.sa);
    if (r4300->recomp.dst->f.r.sa & 0x20)
    {
        mov_reg32_reg32(rd1, rd2);
        xor_reg32_reg32(rd2, rd2);
    }
#endif
}

void gen_DSRLV(struct r4300_core* r4300)
{
#ifdef INTERPRET_DSRLV
    gencallinterp(r4300, (unsigned int)cached_interp_DSRLV, 0);
#else
    int rt1, rt2, rd1, rd2;
    allocate_register_manually(r4300, ECX, (unsigned int *)r4300->recomp.dst->f.r.rs);

    rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rd1 != ECX && rd2 != ECX)
    {
        mov_reg32_reg32(rd1, rt1);
        mov_reg32_reg32(rd2, rt2);
        shrd_reg32_reg32_cl(rd1,rd2);
        shr_reg32_cl(rd2);
        test_reg32_imm32(ECX, 0x20);
        je_rj(4);
        mov_reg32_reg32(rd1, rd2); // 2
        xor_reg32_reg32(rd2, rd2); // 2
    }
    else
    {
        int temp1, temp2;
        temp1 = lru_register(r4300);
        temp2 = lru_register_exc1(r4300, temp1);
        free_register(r4300, temp1);
        free_register(r4300, temp2);

        mov_reg32_reg32(temp1, rt1);
        mov_reg32_reg32(temp2, rt2);
        shrd_reg32_reg32_cl(temp1, temp2);
        shr_reg32_cl(temp2);
        test_reg32_imm32(ECX, 0x20);
        je_rj(4);
        mov_reg32_reg32(temp1, temp2); // 2
        xor_reg32_reg32(temp2, temp2); // 2

        mov_reg32_reg32(rd1, temp1);
        mov_reg32_reg32(rd2, temp2);
    }
#endif
}

void gen_DSRL32(struct r4300_core* r4300)
{
#ifdef INTERPRET_DSRL32
    gencallinterp(r4300, (unsigned int)cached_interp_DSRL32, 0);
#else
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    mov_reg32_reg32(rd1, rt2);
    shr_reg32_imm8(rd1, r4300->recomp.dst->f.r.sa);
    xor_reg32_reg32(rd2, rd2);
#endif
}

void gen_SRA(struct r4300_core* r4300)
{
#ifdef INTERPRET_SRA
    gencallinterp(r4300, (unsigned int)cached_interp_SRA, 0);
#else
    int rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    mov_reg32_reg32(rd, rt);
    sar_reg32_imm8(rd, r4300->recomp.dst->f.r.sa);
#endif
}

void gen_SRAV(struct r4300_core* r4300)
{
#ifdef INTERPRET_SRAV
    gencallinterp(r4300, (unsigned int)cached_interp_SRAV, 0);
#else
    int rt, rd;
    allocate_register_manually(r4300, ECX, (unsigned int *)r4300->recomp.dst->f.r.rs);

    rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rd != ECX)
    {
        mov_reg32_reg32(rd, rt);
        sar_reg32_cl(rd);
    }
    else
    {
        int temp = lru_register(r4300);
        free_register(r4300, temp);
        mov_reg32_reg32(temp, rt);
        sar_reg32_cl(temp);
        mov_reg32_reg32(rd, temp);
    }
#endif
}

void gen_DSRA(struct r4300_core* r4300)
{
#ifdef INTERPRET_DSRA
    gencallinterp(r4300, (unsigned int)cached_interp_DSRA, 0);
#else
    int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    mov_reg32_reg32(rd1, rt1);
    mov_reg32_reg32(rd2, rt2);
    shrd_reg32_reg32_imm8(rd1, rd2, r4300->recomp.dst->f.r.sa);
    sar_reg32_imm8(rd2, r4300->recomp.dst->f.r.sa);
    if (r4300->recomp.dst->f.r.sa & 0x20)
    {
        mov_reg32_reg32(rd1, rd2);
        sar_reg32_imm8(rd2, 31);
    }
#endif
}

void gen_DSRAV(struct r4300_core* r4300)
{
#ifdef INTERPRET_DSRAV
    gencallinterp(r4300, (unsigned int)cached_interp_DSRAV, 0);
#else
    int rt1, rt2, rd1, rd2;
    allocate_register_manually(r4300, ECX, (unsigned int *)r4300->recomp.dst->f.r.rs);

    rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    rd1 = allocate_64_register1_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);
    rd2 = allocate_64_register2_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    if (rd1 != ECX && rd2 != ECX)
    {
        mov_reg32_reg32(rd1, rt1);
        mov_reg32_reg32(rd2, rt2);
        shrd_reg32_reg32_cl(rd1,rd2);
        sar_reg32_cl(rd2);
        test_reg32_imm32(ECX, 0x20);
        je_rj(5);
        mov_reg32_reg32(rd1, rd2); // 2
        sar_reg32_imm8(rd2, 31); // 3
    }
    else
    {
        int temp1, temp2;
        temp1 = lru_register(r4300);
        temp2 = lru_register_exc1(r4300, temp1);
        free_register(r4300, temp1);
        free_register(r4300, temp2);

        mov_reg32_reg32(temp1, rt1);
        mov_reg32_reg32(temp2, rt2);
        shrd_reg32_reg32_cl(temp1, temp2);
        sar_reg32_cl(temp2);
        test_reg32_imm32(ECX, 0x20);
        je_rj(5);
        mov_reg32_reg32(temp1, temp2); // 2
        sar_reg32_imm8(temp2, 31); // 3

        mov_reg32_reg32(rd1, temp1);
        mov_reg32_reg32(rd2, temp2);
    }
#endif
}

void gen_DSRA32(struct r4300_core* r4300)
{
#ifdef INTERPRET_DSRA32
    gencallinterp(r4300, (unsigned int)cached_interp_DSRA32, 0);
#else
    int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.r.rt);
    int rd = allocate_register_w(r4300, (unsigned int *)r4300->recomp.dst->f.r.rd);

    mov_reg32_reg32(rd, rt2);
    sar_reg32_imm8(rd, r4300->recomp.dst->f.r.sa);
#endif
}

/* Multiply / Divide instructions */

void gen_MULT(struct r4300_core* r4300)
{
#ifdef INTERPRET_MULT
    gencallinterp(r4300, (unsigned int)cached_interp_MULT, 0);
#else
    int rs, rt;
    allocate_register_manually_w(r4300, EAX, (unsigned int *)r4300_mult_lo(r4300), 0);
    allocate_register_manually_w(r4300, EDX, (unsigned int *)r4300_mult_hi(r4300), 0);
    rs = allocate_register(r4300, (unsigned int*)r4300->recomp.dst->f.r.rs);
    rt = allocate_register(r4300, (unsigned int*)r4300->recomp.dst->f.r.rt);
    mov_reg32_reg32(EAX, rs);
    imul_reg32(rt);
#endif
}

void gen_MULTU(struct r4300_core* r4300)
{
#ifdef INTERPRET_MULTU
    gencallinterp(r4300, (unsigned int)cached_interp_MULTU, 0);
#else
    int rs, rt;
    allocate_register_manually_w(r4300, EAX, (unsigned int *)r4300_mult_lo(r4300), 0);
    allocate_register_manually_w(r4300, EDX, (unsigned int *)r4300_mult_hi(r4300), 0);
    rs = allocate_register(r4300, (unsigned int*)r4300->recomp.dst->f.r.rs);
    rt = allocate_register(r4300, (unsigned int*)r4300->recomp.dst->f.r.rt);
    mov_reg32_reg32(EAX, rs);
    mul_reg32(rt);
#endif
}

void gen_DMULT(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_DMULT, 0);
}

void gen_DMULTU(struct r4300_core* r4300)
{
#ifdef INTERPRET_DMULTU
    gencallinterp(r4300, (unsigned int)cached_interp_DMULTU, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);

    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.r.rs);
    mul_m32((unsigned int *)r4300->recomp.dst->f.r.rt); // EDX:EAX = temp1
    mov_memoffs32_eax((unsigned int *)(r4300_mult_lo(r4300)));

    mov_reg32_reg32(EBX, EDX); // EBX = temp1>>32
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.r.rs);
    mul_m32((unsigned int *)(r4300->recomp.dst->f.r.rt)+1);
    add_reg32_reg32(EBX, EAX);
    adc_reg32_imm32(EDX, 0);
    mov_reg32_reg32(ECX, EDX); // ECX:EBX = temp2

    mov_eax_memoffs32((unsigned int *)(r4300->recomp.dst->f.r.rs)+1);
    mul_m32((unsigned int *)r4300->recomp.dst->f.r.rt); // EDX:EAX = temp3

    add_reg32_reg32(EBX, EAX);
    adc_reg32_imm32(ECX, 0); // ECX:EBX = result2
    mov_m32_reg32((unsigned int*)(r4300_mult_lo(r4300))+1, EBX);

    mov_reg32_reg32(ESI, EDX); // ESI = temp3>>32
    mov_eax_memoffs32((unsigned int *)(r4300->recomp.dst->f.r.rs)+1);
    mul_m32((unsigned int *)(r4300->recomp.dst->f.r.rt)+1);
    add_reg32_reg32(EAX, ESI);
    adc_reg32_imm32(EDX, 0); // EDX:EAX = temp4

    add_reg32_reg32(EAX, ECX);
    adc_reg32_imm32(EDX, 0); // EDX:EAX = result3
    mov_memoffs32_eax((unsigned int *)(r4300_mult_hi(r4300)));
    mov_m32_reg32((unsigned int *)(r4300_mult_hi(r4300))+1, EDX);
#endif
}

void gen_DIV(struct r4300_core* r4300)
{
#ifdef INTERPRET_DIV
    gencallinterp(r4300, (unsigned int)cached_interp_DIV, 0);
#else
    int rs, rt;
    allocate_register_manually_w(r4300, EAX, (unsigned int *)r4300_mult_lo(r4300), 0);
    allocate_register_manually_w(r4300, EDX, (unsigned int *)r4300_mult_hi(r4300), 0);
    rs = allocate_register(r4300, (unsigned int*)r4300->recomp.dst->f.r.rs);
    rt = allocate_register(r4300, (unsigned int*)r4300->recomp.dst->f.r.rt);
    cmp_reg32_imm32(rt, 0);
    je_rj((rs == EAX ? 0 : 2) + 1 + 2);
    mov_reg32_reg32(EAX, rs); // 0 or 2
    cdq(); // 1
    idiv_reg32(rt); // 2
#endif
}

void gen_DIVU(struct r4300_core* r4300)
{
#ifdef INTERPRET_DIVU
    gencallinterp(r4300, (unsigned int)cached_interp_DIVU, 0);
#else
    int rs, rt;
    allocate_register_manually_w(r4300, EAX, (unsigned int *)r4300_mult_lo(r4300), 0);
    allocate_register_manually_w(r4300, EDX, (unsigned int *)r4300_mult_hi(r4300), 0);
    rs = allocate_register(r4300, (unsigned int*)r4300->recomp.dst->f.r.rs);
    rt = allocate_register(r4300, (unsigned int*)r4300->recomp.dst->f.r.rt);
    cmp_reg32_imm32(rt, 0);
    je_rj((rs == EAX ? 0 : 2) + 2 + 2);
    mov_reg32_reg32(EAX, rs); // 0 or 2
    xor_reg32_reg32(EDX, EDX); // 2
    div_reg32(rt); // 2
#endif
}

void gen_DDIV(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_DDIV, 0);
}

void gen_DDIVU(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_DDIVU, 0);
}

void gen_MFHI(struct r4300_core* r4300)
{
#ifdef INTERPRET_MFHI
    gencallinterp(r4300, (unsigned int)cached_interp_MFHI, 0);
#else
    int rd1 = allocate_64_register1_w(r4300, (unsigned int*)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int*)r4300->recomp.dst->f.r.rd);
    int hi1 = allocate_64_register1(r4300, (unsigned int*)r4300_mult_hi(r4300));
    int hi2 = allocate_64_register2(r4300, (unsigned int*)r4300_mult_hi(r4300));

    mov_reg32_reg32(rd1, hi1);
    mov_reg32_reg32(rd2, hi2);
#endif
}

void gen_MTHI(struct r4300_core* r4300)
{
#ifdef INTERPRET_MTHI
    gencallinterp(r4300, (unsigned int)cached_interp_MTHI, 0);
#else
    int hi1 = allocate_64_register1_w(r4300, (unsigned int*)r4300_mult_hi(r4300));
    int hi2 = allocate_64_register2_w(r4300, (unsigned int*)r4300_mult_hi(r4300));
    int rs1 = allocate_64_register1(r4300, (unsigned int*)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int*)r4300->recomp.dst->f.r.rs);

    mov_reg32_reg32(hi1, rs1);
    mov_reg32_reg32(hi2, rs2);
#endif
}

void gen_MFLO(struct r4300_core* r4300)
{
#ifdef INTERPRET_MFLO
    gencallinterp(r4300, (unsigned int)cached_interp_MFLO, 0);
#else
    int rd1 = allocate_64_register1_w(r4300, (unsigned int*)r4300->recomp.dst->f.r.rd);
    int rd2 = allocate_64_register2_w(r4300, (unsigned int*)r4300->recomp.dst->f.r.rd);
    int lo1 = allocate_64_register1(r4300, (unsigned int*)r4300_mult_lo(r4300));
    int lo2 = allocate_64_register2(r4300, (unsigned int*)r4300_mult_lo(r4300));

    mov_reg32_reg32(rd1, lo1);
    mov_reg32_reg32(rd2, lo2);
#endif
}

void gen_MTLO(struct r4300_core* r4300)
{
#ifdef INTERPRET_MTLO
    gencallinterp(r4300, (unsigned int)cached_interp_MTLO, 0);
#else
    int lo1 = allocate_64_register1_w(r4300, (unsigned int*)r4300_mult_lo(r4300));
    int lo2 = allocate_64_register2_w(r4300, (unsigned int*)r4300_mult_lo(r4300));
    int rs1 = allocate_64_register1(r4300, (unsigned int*)r4300->recomp.dst->f.r.rs);
    int rs2 = allocate_64_register2(r4300, (unsigned int*)r4300->recomp.dst->f.r.rs);

    mov_reg32_reg32(lo1, rs1);
    mov_reg32_reg32(lo2, rs2);
#endif
}

/* Jump & Branch instructions */

static void gentest(struct r4300_core* r4300)
{
    cmp_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0);
    je_near_rj(0);

    jump_start_rel32(r4300);

    mov_m32_imm32(&r4300->cp0.last_addr, r4300->recomp.dst->addr + (r4300->recomp.dst-1)->f.i.immediate*4);
    gencheck_interrupt(r4300, (unsigned int)(r4300->recomp.dst + (r4300->recomp.dst-1)->f.i.immediate));
    jmp(r4300->recomp.dst->addr + (r4300->recomp.dst-1)->f.i.immediate*4);

    jump_end_rel32(r4300);

    mov_m32_imm32(&r4300->cp0.last_addr, r4300->recomp.dst->addr + 4);
    gencheck_interrupt(r4300, (unsigned int)(r4300->recomp.dst + 1));
    jmp(r4300->recomp.dst->addr + 4);
}

static void gentest_out(struct r4300_core* r4300)
{
    cmp_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0);
    je_near_rj(0);

    jump_start_rel32(r4300);

    mov_m32_imm32(&r4300->cp0.last_addr, r4300->recomp.dst->addr + (r4300->recomp.dst-1)->f.i.immediate*4);
    gencheck_interrupt_out(r4300, r4300->recomp.dst->addr + (r4300->recomp.dst-1)->f.i.immediate*4);
    mov_m32_imm32(&r4300->recomp.jump_to_address, r4300->recomp.dst->addr + (r4300->recomp.dst-1)->f.i.immediate*4);
    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1));
    mov_reg32_imm32(EAX, (unsigned int)dynarec_jump_to_recomp_address);
    call_reg32(EAX);

    jump_end_rel32(r4300);

    mov_m32_imm32(&r4300->cp0.last_addr, r4300->recomp.dst->addr + 4);
    gencheck_interrupt(r4300, (unsigned int)(r4300->recomp.dst + 1));
    jmp(r4300->recomp.dst->addr + 4);
}

static void gentest_idle(struct r4300_core* r4300)
{
    int reg;

    reg = lru_register(r4300);
    free_register(r4300, reg);

    cmp_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0);
    je_near_rj(0);

    jump_start_rel32(r4300);

    mov_reg32_m32(reg, (unsigned int *)(r4300_cp0_next_interrupt(&r4300->cp0)));
    sub_reg32_m32(reg, (unsigned int *)(&r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]));
    cmp_reg32_imm8(reg, 5);
    jbe_rj(18);

    sub_reg32_imm32(reg, 2); // 6
    and_reg32_imm32(reg, 0xFFFFFFFC); // 6
    add_m32_reg32((unsigned int *)(&r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]), reg); // 6

    jump_end_rel32(r4300);
}

static void gentestl(struct r4300_core* r4300)
{
    cmp_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0);
    je_near_rj(0);

    jump_start_rel32(r4300);

    gendelayslot(r4300);
    mov_m32_imm32(&r4300->cp0.last_addr, r4300->recomp.dst->addr + (r4300->recomp.dst-1)->f.i.immediate*4);
    gencheck_interrupt(r4300, (unsigned int)(r4300->recomp.dst + (r4300->recomp.dst-1)->f.i.immediate));
    jmp(r4300->recomp.dst->addr + (r4300->recomp.dst-1)->f.i.immediate*4);

    jump_end_rel32(r4300);

    gencp0_update_count(r4300, r4300->recomp.dst->addr+4);
    mov_m32_imm32(&r4300->cp0.last_addr, r4300->recomp.dst->addr + 4);
    gencheck_interrupt(r4300, (unsigned int)(r4300->recomp.dst + 1));
    jmp(r4300->recomp.dst->addr + 4);
}

static void gentestl_out(struct r4300_core* r4300)
{
    cmp_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0);
    je_near_rj(0);

    jump_start_rel32(r4300);

    gendelayslot(r4300);
    mov_m32_imm32(&r4300->cp0.last_addr, r4300->recomp.dst->addr + (r4300->recomp.dst-1)->f.i.immediate*4);
    gencheck_interrupt_out(r4300, r4300->recomp.dst->addr + (r4300->recomp.dst-1)->f.i.immediate*4);
    mov_m32_imm32(&r4300->recomp.jump_to_address, r4300->recomp.dst->addr + (r4300->recomp.dst-1)->f.i.immediate*4);
    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1));
    mov_reg32_imm32(EAX, (unsigned int)dynarec_jump_to_recomp_address);
    call_reg32(EAX);

    jump_end_rel32(r4300);

    gencp0_update_count(r4300, r4300->recomp.dst->addr+4);
    mov_m32_imm32(&r4300->cp0.last_addr, r4300->recomp.dst->addr + 4);
    gencheck_interrupt(r4300, (unsigned int)(r4300->recomp.dst + 1));
    jmp(r4300->recomp.dst->addr + 4);
}

static void genbranchlink(struct r4300_core* r4300)
{
    int r31_64bit = is64(r4300, (unsigned int*)&r4300_regs(r4300)[31]);

    if (!r31_64bit)
    {
        int r31 = allocate_register_w(r4300, (unsigned int *)&r4300_regs(r4300)[31]);

        mov_reg32_imm32(r31, r4300->recomp.dst->addr+8);
    }
    else if (r31_64bit == -1)
    {
        mov_m32_imm32((unsigned int *)&r4300_regs(r4300)[31], r4300->recomp.dst->addr + 8);
        if (r4300->recomp.dst->addr & 0x80000000) {
            mov_m32_imm32(((unsigned int *)&r4300_regs(r4300)[31])+1, 0xFFFFFFFF);
        }
        else {
            mov_m32_imm32(((unsigned int *)&r4300_regs(r4300)[31])+1, 0);
        }
    }
    else
    {
        int r311 = allocate_64_register1_w(r4300, (unsigned int *)&r4300_regs(r4300)[31]);
        int r312 = allocate_64_register2_w(r4300, (unsigned int *)&r4300_regs(r4300)[31]);

        mov_reg32_imm32(r311, r4300->recomp.dst->addr+8);
        if (r4300->recomp.dst->addr & 0x80000000) {
            mov_reg32_imm32(r312, 0xFFFFFFFF);
        }
        else {
            mov_reg32_imm32(r312, 0);
        }
    }
}

void gen_J(struct r4300_core* r4300)
{
#ifdef INTERPRET_J
    gencallinterp(r4300, (unsigned int)cached_interp_J, 1);
#else
    unsigned int naddr;

    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_J, 1);
        return;
    }

    gendelayslot(r4300);
    naddr = ((r4300->recomp.dst-1)->f.j.inst_index<<2) | (r4300->recomp.dst->addr & 0xF0000000);

    mov_m32_imm32(&r4300->cp0.last_addr, naddr);
    gencheck_interrupt(r4300, (unsigned int)&r4300->cached_interp.actual->block[(naddr-r4300->cached_interp.actual->start)/4]);
    jmp(naddr);
#endif
}

void gen_J_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_J_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_J_OUT, 1);
#else
    unsigned int naddr;

    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_J_OUT, 1);
        return;
    }

    gendelayslot(r4300);
    naddr = ((r4300->recomp.dst-1)->f.j.inst_index<<2) | (r4300->recomp.dst->addr & 0xF0000000);

    mov_m32_imm32(&r4300->cp0.last_addr, naddr);
    gencheck_interrupt_out(r4300, naddr);
    mov_m32_imm32(&r4300->recomp.jump_to_address, naddr);
    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1));
    mov_reg32_imm32(EAX, (unsigned int)dynarec_jump_to_recomp_address);
    call_reg32(EAX);
#endif
}

void gen_J_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_J_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_J_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_J_IDLE, 1);
        return;
    }

    mov_eax_memoffs32((unsigned int *)(r4300_cp0_next_interrupt(&r4300->cp0)));
    sub_reg32_m32(EAX, (unsigned int *)(&r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]));
    cmp_reg32_imm8(EAX, 3);
    jbe_rj(11);

    and_eax_imm32(0xFFFFFFFC);  // 5
    add_m32_reg32((unsigned int *)(&r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]), EAX); // 6

    gen_J(r4300);
#endif
}

void gen_JAL(struct r4300_core* r4300)
{
#ifdef INTERPRET_JAL
    gencallinterp(r4300, (unsigned int)cached_interp_JAL, 1);
#else
    unsigned int naddr;

    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_JAL, 1);
        return;
    }

    gendelayslot(r4300);

    mov_m32_imm32((unsigned int *)(r4300_regs(r4300) + 31), r4300->recomp.dst->addr + 4);
    if (((r4300->recomp.dst->addr + 4) & 0x80000000)) {
        mov_m32_imm32((unsigned int *)(&r4300_regs(r4300)[31])+1, 0xFFFFFFFF);
    }
    else {
        mov_m32_imm32((unsigned int *)(&r4300_regs(r4300)[31])+1, 0);
    }

    naddr = ((r4300->recomp.dst-1)->f.j.inst_index<<2) | (r4300->recomp.dst->addr & 0xF0000000);

    mov_m32_imm32(&r4300->cp0.last_addr, naddr);
    gencheck_interrupt(r4300, (unsigned int)&r4300->cached_interp.actual->block[(naddr-r4300->cached_interp.actual->start)/4]);
    jmp(naddr);
#endif
}

void gen_JAL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_JAL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_JAL_OUT, 1);
#else
    unsigned int naddr;

    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_JAL_OUT, 1);
        return;
    }

    gendelayslot(r4300);

    mov_m32_imm32((unsigned int *)(r4300_regs(r4300) + 31), r4300->recomp.dst->addr + 4);
    if (((r4300->recomp.dst->addr + 4) & 0x80000000)) {
        mov_m32_imm32((unsigned int *)(&r4300_regs(r4300)[31])+1, 0xFFFFFFFF);
    }
    else {
        mov_m32_imm32((unsigned int *)(&r4300_regs(r4300)[31])+1, 0);
    }

    naddr = ((r4300->recomp.dst-1)->f.j.inst_index<<2) | (r4300->recomp.dst->addr & 0xF0000000);

    mov_m32_imm32(&r4300->cp0.last_addr, naddr);
    gencheck_interrupt_out(r4300, naddr);
    mov_m32_imm32(&r4300->recomp.jump_to_address, naddr);
    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1));
    mov_reg32_imm32(EAX, (unsigned int)dynarec_jump_to_recomp_address);
    call_reg32(EAX);
#endif
}

void gen_JAL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_JAL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_JAL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_JAL_IDLE, 1);
        return;
    }

    mov_eax_memoffs32((unsigned int *)(r4300_cp0_next_interrupt(&r4300->cp0)));
    sub_reg32_m32(EAX, (unsigned int *)(&r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]));
    cmp_reg32_imm8(EAX, 3);
    jbe_rj(11);

    and_eax_imm32(0xFFFFFFFC);
    add_m32_reg32((unsigned int *)(&r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]), EAX);

    gen_JAL(r4300);
#endif
}

void gen_JR(struct r4300_core* r4300)
{
#ifdef INTERPRET_JR
    gencallinterp(r4300, (unsigned int)cached_interp_JR_OUT, 1);
#else
    unsigned int diff =
        (unsigned int)(&r4300->recomp.dst->local_addr) - (unsigned int)(r4300->recomp.dst);
    unsigned int diff_need =
        (unsigned int)(&r4300->recomp.dst->reg_cache_infos.need_map) - (unsigned int)(r4300->recomp.dst);
    unsigned int diff_wrap =
        (unsigned int)(&r4300->recomp.dst->reg_cache_infos.jump_wrapper) - (unsigned int)(r4300->recomp.dst);

    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_JR_OUT, 1);
        return;
    }

    free_all_registers(r4300);
    simplify_access(r4300);
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.i.rs);
    mov_memoffs32_eax((unsigned int *)&r4300->recomp.local_rs);

    gendelayslot(r4300);

    mov_eax_memoffs32((unsigned int *)&r4300->recomp.local_rs);
    mov_memoffs32_eax((unsigned int *)&r4300->cp0.last_addr);

    gencheck_interrupt_reg(r4300);

    mov_eax_memoffs32((unsigned int *)&r4300->recomp.local_rs);
    mov_reg32_reg32(EBX, EAX);
    and_eax_imm32(0xFFFFF000);
    cmp_eax_imm32(r4300->recomp.dst_block->start & 0xFFFFF000);
    je_near_rj(0);

    jump_start_rel32(r4300);

    mov_m32_reg32(&r4300->recomp.jump_to_address, EBX);
    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1));
    mov_reg32_imm32(EAX, (unsigned int)dynarec_jump_to_recomp_address);
    call_reg32(EAX);

    jump_end_rel32(r4300);

    mov_reg32_reg32(EAX, EBX);
    sub_eax_imm32(r4300->recomp.dst_block->start);
    shr_reg32_imm8(EAX, 2);
    mul_m32((unsigned int *)(&precomp_instr_size));

    mov_reg32_preg32pimm32(EBX, EAX, (unsigned int)(r4300->recomp.dst_block->block)+diff_need);
    cmp_reg32_imm32(EBX, 1);
    jne_rj(7);

    add_eax_imm32((unsigned int)(r4300->recomp.dst_block->block)+diff_wrap); // 5
    jmp_reg32(EAX); // 2

    mov_reg32_preg32pimm32(EAX, EAX, (unsigned int)(r4300->recomp.dst_block->block)+diff);
    add_reg32_m32(EAX, (unsigned int *)(&r4300->recomp.dst_block->code));

    jmp_reg32(EAX);
#endif
}

void gen_JALR(struct r4300_core* r4300)
{
#ifdef INTERPRET_JALR
    gencallinterp(r4300, (unsigned int)cached_interp_JALR_OUT, 0);
#else
    unsigned int diff =
        (unsigned int)(&r4300->recomp.dst->local_addr) - (unsigned int)(r4300->recomp.dst);
    unsigned int diff_need =
        (unsigned int)(&r4300->recomp.dst->reg_cache_infos.need_map) - (unsigned int)(r4300->recomp.dst);
    unsigned int diff_wrap =
        (unsigned int)(&r4300->recomp.dst->reg_cache_infos.jump_wrapper) - (unsigned int)(r4300->recomp.dst);

    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_JALR_OUT, 1);
        return;
    }

    free_all_registers(r4300);
    simplify_access(r4300);
    mov_eax_memoffs32((unsigned int *)r4300->recomp.dst->f.r.rs);
    mov_memoffs32_eax((unsigned int *)&r4300->recomp.local_rs);

    gendelayslot(r4300);

    mov_m32_imm32((unsigned int *)(r4300->recomp.dst-1)->f.r.rd, r4300->recomp.dst->addr+4);
    if ((r4300->recomp.dst->addr+4) & 0x80000000) {
        mov_m32_imm32(((unsigned int *)(r4300->recomp.dst-1)->f.r.rd)+1, 0xFFFFFFFF);
    }
    else {
        mov_m32_imm32(((unsigned int *)(r4300->recomp.dst-1)->f.r.rd)+1, 0);
    }

    mov_eax_memoffs32((unsigned int *)&r4300->recomp.local_rs);
    mov_memoffs32_eax((unsigned int *)&r4300->cp0.last_addr);

    gencheck_interrupt_reg(r4300);

    mov_eax_memoffs32((unsigned int *)&r4300->recomp.local_rs);
    mov_reg32_reg32(EBX, EAX);
    and_eax_imm32(0xFFFFF000);
    cmp_eax_imm32(r4300->recomp.dst_block->start & 0xFFFFF000);
    je_near_rj(0);

    jump_start_rel32(r4300);

    mov_m32_reg32(&r4300->recomp.jump_to_address, EBX);
    mov_m32_imm32((unsigned int*)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1));
    mov_reg32_imm32(EAX, (unsigned int)dynarec_jump_to_recomp_address);
    call_reg32(EAX);

    jump_end_rel32(r4300);

    mov_reg32_reg32(EAX, EBX);
    sub_eax_imm32(r4300->recomp.dst_block->start);
    shr_reg32_imm8(EAX, 2);
    mul_m32((unsigned int *)(&precomp_instr_size));

    mov_reg32_preg32pimm32(EBX, EAX, (unsigned int)(r4300->recomp.dst_block->block)+diff_need);
    cmp_reg32_imm32(EBX, 1);
    jne_rj(7);

    add_eax_imm32((unsigned int)(r4300->recomp.dst_block->block)+diff_wrap); // 5
    jmp_reg32(EAX); // 2

    mov_reg32_preg32pimm32(EAX, EAX, (unsigned int)(r4300->recomp.dst_block->block)+diff);
    add_reg32_m32(EAX, (unsigned int *)(&r4300->recomp.dst_block->code));

    jmp_reg32(EAX);
#endif
}

static void genbeq_test(struct r4300_core* r4300)
{
    int rs_64bit = is64(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rt_64bit = is64(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

    if (!rs_64bit && !rt_64bit)
    {
        int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
        int rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

        cmp_reg32_reg32(rs, rt);
        jne_rj(12);
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
    else if (rs_64bit == -1)
    {
        int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
        int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

        cmp_reg32_m32(rt1, (unsigned int *)r4300->recomp.dst->f.i.rs);
        jne_rj(20);
        cmp_reg32_m32(rt2, ((unsigned int *)r4300->recomp.dst->f.i.rs)+1); // 6
        jne_rj(12); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
    else if (rt_64bit == -1)
    {
        int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
        int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

        cmp_reg32_m32(rs1, (unsigned int *)r4300->recomp.dst->f.i.rt);
        jne_rj(20);
        cmp_reg32_m32(rs2, ((unsigned int *)r4300->recomp.dst->f.i.rt)+1); // 6
        jne_rj(12); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
    else
    {
        int rs1, rs2, rt1, rt2;
        if (!rs_64bit)
        {
            rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
            rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
            rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
            rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
        }
        else
        {
            rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
            rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
            rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
            rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
        }
        cmp_reg32_reg32(rs1, rt1);
        jne_rj(16);
        cmp_reg32_reg32(rs2, rt2); // 2
        jne_rj(12); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
}

void gen_BEQ(struct r4300_core* r4300)
{
#ifdef INTERPRET_BEQ
    gencallinterp(r4300, (unsigned int)cached_interp_BEQ, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BEQ, 1);
        return;
    }

    genbeq_test(r4300);
    gendelayslot(r4300);
    gentest(r4300);
#endif
}

void gen_BEQ_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BEQ_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BEQ_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BEQ_OUT, 1);
        return;
    }

    genbeq_test(r4300);
    gendelayslot(r4300);
    gentest_out(r4300);
#endif
}

void gen_BEQ_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BEQ_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BEQ_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BEQ_IDLE, 1);
        return;
    }

    genbeq_test(r4300);
    gentest_idle(r4300);
    gen_BEQ(r4300);
#endif
}

void gen_BEQL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BEQL
    gencallinterp(r4300, (unsigned int)cached_interp_BEQL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BEQL, 1);
        return;
    }

    genbeq_test(r4300);
    free_all_registers(r4300);
    gentestl(r4300);
#endif
}

void gen_BEQL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BEQL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BEQL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BEQL_OUT, 1);
        return;
    }

    genbeq_test(r4300);
    free_all_registers(r4300);
    gentestl_out(r4300);
#endif
}

void gen_BEQL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BEQL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BEQL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BEQL_IDLE, 1);
        return;
    }

    genbeq_test(r4300);
    gentest_idle(r4300);
    gen_BEQL(r4300);
#endif
}

static void genbne_test(struct r4300_core* r4300)
{
    int rs_64bit = is64(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
    int rt_64bit = is64(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

    if (!rs_64bit && !rt_64bit)
    {
        int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
        int rt = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

        cmp_reg32_reg32(rs, rt);
        je_rj(12);
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
    else if (rs_64bit == -1)
    {
        int rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
        int rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);

        cmp_reg32_m32(rt1, (unsigned int *)r4300->recomp.dst->f.i.rs);
        jne_rj(20);
        cmp_reg32_m32(rt2, ((unsigned int *)r4300->recomp.dst->f.i.rs)+1); // 6
        jne_rj(12); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
    }
    else if (rt_64bit == -1)
    {
        int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
        int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

        cmp_reg32_m32(rs1, (unsigned int *)r4300->recomp.dst->f.i.rt);
        jne_rj(20);
        cmp_reg32_m32(rs2, ((unsigned int *)r4300->recomp.dst->f.i.rt)+1); // 6
        jne_rj(12); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
    }
    else
    {
        int rs1, rs2, rt1, rt2;
        if (!rs_64bit)
        {
            rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
            rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
            rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
            rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
        }
        else
        {
            rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
            rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
            rt1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
            rt2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rt);
        }
        cmp_reg32_reg32(rs1, rt1);
        jne_rj(16);
        cmp_reg32_reg32(rs2, rt2); // 2
        jne_rj(12); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
    }
}

void gen_BNE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BNE
    gencallinterp(r4300, (unsigned int)cached_interp_BNE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BNE, 1);
        return;
    }

    genbne_test(r4300);
    gendelayslot(r4300);
    gentest(r4300);
#endif
}

void gen_BNE_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BNE_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BNE_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BNE_OUT, 1);
        return;
    }

    genbne_test(r4300);
    gendelayslot(r4300);
    gentest_out(r4300);
#endif
}

void gen_BNE_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BNE_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BNE_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BNE_IDLE, 1);
        return;
    }

    genbne_test(r4300);
    gentest_idle(r4300);
    gen_BNE(r4300);
#endif
}

void gen_BNEL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BNEL
    gencallinterp(r4300, (unsigned int)cached_interp_BNEL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BNEL, 1);
        return;
    }

    genbne_test(r4300);
    free_all_registers(r4300);
    gentestl(r4300);
#endif
}

void gen_BNEL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BNEL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BNEL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BNEL_OUT, 1);
        return;
    }

    genbne_test(r4300);
    free_all_registers(r4300);
    gentestl_out(r4300);
#endif
}

void gen_BNEL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BNEL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BNEL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BNEL_IDLE, 1);
        return;
    }

    genbne_test(r4300);
    gentest_idle(r4300);
    gen_BNEL(r4300);
#endif
}

static void genblez_test(struct r4300_core* r4300)
{
    int rs_64bit = is64(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

    if (!rs_64bit)
    {
        int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

        cmp_reg32_imm32(rs, 0);
        jg_rj(12);
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
    else if (rs_64bit == -1)
    {
        cmp_m32_imm32(((unsigned int *)r4300->recomp.dst->f.i.rs)+1, 0);
        jg_rj(14);
        jne_rj(24); // 2
        cmp_m32_imm32((unsigned int *)r4300->recomp.dst->f.i.rs, 0); // 10
        je_rj(12); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
    }
    else
    {
        int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
        int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

        cmp_reg32_imm32(rs2, 0);
        jg_rj(10);
        jne_rj(20); // 2
        cmp_reg32_imm32(rs1, 0); // 6
        je_rj(12); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
    }
}

void gen_BLEZ(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLEZ
    gencallinterp(r4300, (unsigned int)cached_interp_BLEZ, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLEZ, 1);
        return;
    }

    genblez_test(r4300);
    gendelayslot(r4300);
    gentest(r4300);
#endif
}

void gen_BLEZ_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLEZ_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BLEZ_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLEZ_OUT, 1);
        return;
    }

    genblez_test(r4300);
    gendelayslot(r4300);
    gentest_out(r4300);
#endif
}

void gen_BLEZ_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLEZ_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BLEZ_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLEZ_IDLE, 1);
        return;
    }

    genblez_test(r4300);
    gentest_idle(r4300);
    gen_BLEZ(r4300);
#endif
}

void gen_BLEZL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLEZL
    gencallinterp(r4300, (unsigned int)cached_interp_BLEZL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLEZL, 1);
        return;
    }

    genblez_test(r4300);
    free_all_registers(r4300);
    gentestl(r4300);
#endif
}

void gen_BLEZL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLEZL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BLEZL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLEZL_OUT, 1);
        return;
    }

    genblez_test(r4300);
    free_all_registers(r4300);
    gentestl_out(r4300);
#endif
}

void gen_BLEZL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLEZL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BLEZL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLEZL_IDLE, 1);
        return;
    }

    genblez_test(r4300);
    gentest_idle(r4300);
    gen_BLEZL(r4300);
#endif
}

static void genbgtz_test(struct r4300_core* r4300)
{
    int rs_64bit = is64(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

    if (!rs_64bit)
    {
        int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

        cmp_reg32_imm32(rs, 0);
        jle_rj(12);
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
    else if (rs_64bit == -1)
    {
        cmp_m32_imm32(((unsigned int *)r4300->recomp.dst->f.i.rs)+1, 0);
        jl_rj(14);
        jne_rj(24); // 2
        cmp_m32_imm32((unsigned int *)r4300->recomp.dst->f.i.rs, 0); // 10
        jne_rj(12); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
    }
    else
    {
        int rs1 = allocate_64_register1(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);
        int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

        cmp_reg32_imm32(rs2, 0);
        jl_rj(10);
        jne_rj(20); // 2
        cmp_reg32_imm32(rs1, 0); // 6
        jne_rj(12); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
    }
}

void gen_BGTZ(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGTZ
    gencallinterp(r4300, (unsigned int)cached_interp_BGTZ, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGTZ, 1);
        return;
    }

    genbgtz_test(r4300);
    gendelayslot(r4300);
    gentest(r4300);
#endif
}

void gen_BGTZ_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGTZ_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BGTZ_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGTZ_OUT, 1);
        return;
    }

    genbgtz_test(r4300);
    gendelayslot(r4300);
    gentest_out(r4300);
#endif
}

void gen_BGTZ_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGTZ_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BGTZ_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGTZ_IDLE, 1);
        return;
    }

    genbgtz_test(r4300);
    gentest_idle(r4300);
    gen_BGTZ(r4300);
#endif
}

void gen_BGTZL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGTZL
    gencallinterp(r4300, (unsigned int)cached_interp_BGTZL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGTZL, 1);
        return;
    }

    genbgtz_test(r4300);
    free_all_registers(r4300);
    gentestl(r4300);
#endif
}

void gen_BGTZL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGTZL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BGTZL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGTZL_OUT, 1);
        return;
    }

    genbgtz_test(r4300);
    free_all_registers(r4300);
    gentestl_out(r4300);
#endif
}

void gen_BGTZL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGTZL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BGTZL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGTZL_IDLE, 1);
        return;
    }

    genbgtz_test(r4300);
    gentest_idle(r4300);
    gen_BGTZL(r4300);
#endif
}

static void genbltz_test(struct r4300_core* r4300)
{
    int rs_64bit = is64(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

    if (!rs_64bit)
    {
        int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

        cmp_reg32_imm32(rs, 0);
        jge_rj(12);
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
    else if (rs_64bit == -1)
    {
        cmp_m32_imm32(((unsigned int *)r4300->recomp.dst->f.i.rs)+1, 0);
        jge_rj(12);
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
    else
    {
        int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

        cmp_reg32_imm32(rs2, 0);
        jge_rj(12);
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
}

void gen_BLTZ(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZ
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZ, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZ, 1);
        return;
    }

    genbltz_test(r4300);
    gendelayslot(r4300);
    gentest(r4300);
#endif
}

void gen_BLTZ_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZ_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZ_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZ_OUT, 1);
        return;
    }

    genbltz_test(r4300);
    gendelayslot(r4300);
    gentest_out(r4300);
#endif
}

void gen_BLTZ_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZ_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZ_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZ_IDLE, 1);
        return;
    }

    genbltz_test(r4300);
    gentest_idle(r4300);
    gen_BLTZ(r4300);
#endif
}

void gen_BLTZAL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZAL
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZAL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZAL, 1);
        return;
    }

    genbltz_test(r4300);
    genbranchlink(r4300);
    gendelayslot(r4300);
    gentest(r4300);
#endif
}

void gen_BLTZAL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZAL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZAL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZAL_OUT, 1);
        return;
    }

    genbltz_test(r4300);
    genbranchlink(r4300);
    gendelayslot(r4300);
    gentest_out(r4300);
#endif
}

void gen_BLTZAL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZAL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZAL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZAL_IDLE, 1);
        return;
    }

    genbltz_test(r4300);
    genbranchlink(r4300);
    gentest_idle(r4300);
    gen_BLTZAL(r4300);
#endif
}

void gen_BLTZL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZL
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZL, 1);
        return;
    }

    genbltz_test(r4300);
    free_all_registers(r4300);
    gentestl(r4300);
#endif
}

void gen_BLTZL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZL_OUT, 1);
        return;
    }

    genbltz_test(r4300);
    free_all_registers(r4300);
    gentestl_out(r4300);
#endif
}

void gen_BLTZL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZL_IDLE, 1);
        return;
    }

    genbltz_test(r4300);
    gentest_idle(r4300);
    gen_BLTZL(r4300);
#endif
}

void gen_BLTZALL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZALL
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZALL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZALL, 1);
        return;
    }

    genbltz_test(r4300);
    genbranchlink(r4300);
    free_all_registers(r4300);
    gentestl(r4300);
#endif
}

void gen_BLTZALL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZALL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZALL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZALL_OUT, 1);
        return;
    }

    genbltz_test(r4300);
    genbranchlink(r4300);
    free_all_registers(r4300);
    gentestl_out(r4300);
#endif
}

void gen_BLTZALL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BLTZALL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BLTZALL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BLTZALL_IDLE, 1);
        return;
    }

    genbltz_test(r4300);
    genbranchlink(r4300);
    gentest_idle(r4300);
    gen_BLTZALL(r4300);
#endif
}

static void genbgez_test(struct r4300_core* r4300)
{
    int rs_64bit = is64(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

    if (!rs_64bit)
    {
        int rs = allocate_register(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

        cmp_reg32_imm32(rs, 0);
        jl_rj(12);
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
    else if (rs_64bit == -1)
    {
        cmp_m32_imm32(((unsigned int *)r4300->recomp.dst->f.i.rs)+1, 0);
        jl_rj(12);
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
    else
    {
        int rs2 = allocate_64_register2(r4300, (unsigned int *)r4300->recomp.dst->f.i.rs);

        cmp_reg32_imm32(rs2, 0);
        jl_rj(12);
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 1); // 10
        jmp_imm_short(10); // 2
        mov_m32_imm32((unsigned int *)(&r4300->recomp.branch_taken), 0); // 10
    }
}

void gen_BGEZ(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZ
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZ, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZ, 1);
        return;
    }

    genbgez_test(r4300);
    gendelayslot(r4300);
    gentest(r4300);
#endif
}

void gen_BGEZ_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZ_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZ_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZ_OUT, 1);
        return;
    }

    genbgez_test(r4300);
    gendelayslot(r4300);
    gentest_out(r4300);
#endif
}

void gen_BGEZ_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZ_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZ_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZ_IDLE, 1);
        return;
    }

    genbgez_test(r4300);
    gentest_idle(r4300);
    gen_BGEZ(r4300);
#endif
}

void gen_BGEZAL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZAL
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZAL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZAL, 1);
        return;
    }

    genbgez_test(r4300);
    genbranchlink(r4300);
    gendelayslot(r4300);
    gentest(r4300);
#endif
}

void gen_BGEZAL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZAL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZAL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZAL_OUT, 1);
        return;
    }

    genbgez_test(r4300);
    genbranchlink(r4300);
    gendelayslot(r4300);
    gentest_out(r4300);
#endif
}

void gen_BGEZAL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZAL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZAL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZAL_IDLE, 1);
        return;
    }

    genbgez_test(r4300);
    genbranchlink(r4300);
    gentest_idle(r4300);
    gen_BGEZAL(r4300);
#endif
}

void gen_BGEZL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZL
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZL, 1);
        return;
    }

    genbgez_test(r4300);
    free_all_registers(r4300);
    gentestl(r4300);
#endif
}

void gen_BGEZL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZL_OUT, 1);
        return;
    }

    genbgez_test(r4300);
    free_all_registers(r4300);
    gentestl_out(r4300);
#endif
}

void gen_BGEZL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZL_IDLE, 1);
        return;
    }

    genbgez_test(r4300);
    gentest_idle(r4300);
    gen_BGEZL(r4300);
#endif
}

void gen_BGEZALL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZALL
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZALL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZALL, 1);
        return;
    }

    genbgez_test(r4300);
    genbranchlink(r4300);
    free_all_registers(r4300);
    gentestl(r4300);
#endif
}

void gen_BGEZALL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZALL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZALL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZALL_OUT, 1);
        return;
    }

    genbgez_test(r4300);
    genbranchlink(r4300);
    free_all_registers(r4300);
    gentestl_out(r4300);
#endif
}

void gen_BGEZALL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BGEZALL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BGEZALL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BGEZALL_IDLE, 1);
        return;
    }

    genbgez_test(r4300);
    genbranchlink(r4300);
    gentest_idle(r4300);
    gen_BGEZALL(r4300);
#endif
}

static void genbc1f_test(struct r4300_core* r4300)
{
    test_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000);
    jne_rj(12);
    mov_m32_imm32((unsigned int*)(&r4300->recomp.branch_taken), 1); // 10
    jmp_imm_short(10); // 2
    mov_m32_imm32((unsigned int*)(&r4300->recomp.branch_taken), 0); // 10
}

void gen_BC1F(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1F
    gencallinterp(r4300, (unsigned int)cached_interp_BC1F, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1F, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1f_test(r4300);
    gendelayslot(r4300);
    gentest(r4300);
#endif
}

void gen_BC1F_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1F_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BC1F_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1F_OUT, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1f_test(r4300);
    gendelayslot(r4300);
    gentest_out(r4300);
#endif
}

void gen_BC1F_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1F_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BC1F_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1F_IDLE, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1f_test(r4300);
    gentest_idle(r4300);
    gen_BC1F(r4300);
#endif
}

void gen_BC1FL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1FL
    gencallinterp(r4300, (unsigned int)cached_interp_BC1FL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1FL, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1f_test(r4300);
    free_all_registers(r4300);
    gentestl(r4300);
#endif
}

void gen_BC1FL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1FL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BC1FL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1FL_OUT, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1f_test(r4300);
    free_all_registers(r4300);
    gentestl_out(r4300);
#endif
}

void gen_BC1FL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1FL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BC1FL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1FL_IDLE, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1f_test(r4300);
    gentest_idle(r4300);
    gen_BC1FL(r4300);
#endif
}

static void genbc1t_test(struct r4300_core* r4300)
{
    test_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000);
    je_rj(12);
    mov_m32_imm32((unsigned int*)(&r4300->recomp.branch_taken), 1); // 10
    jmp_imm_short(10); // 2
    mov_m32_imm32((unsigned int*)(&r4300->recomp.branch_taken), 0); // 10
}

void gen_BC1T(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1T
    gencallinterp(r4300, (unsigned int)cached_interp_BC1T, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1T, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1t_test(r4300);
    gendelayslot(r4300);
    gentest(r4300);
#endif
}

void gen_BC1T_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1T_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BC1T_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1T_OUT, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1t_test(r4300);
    gendelayslot(r4300);
    gentest_out(r4300);
#endif
}

void gen_BC1T_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1T_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BC1T_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1T_IDLE, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1t_test(r4300);
    gentest_idle(r4300);
    gen_BC1T(r4300);
#endif
}

void gen_BC1TL(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1TL
    gencallinterp(r4300, (unsigned int)cached_interp_BC1TL, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1TL, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1t_test(r4300);
    free_all_registers(r4300);
    gentestl(r4300);
#endif
}

void gen_BC1TL_OUT(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1TL_OUT
    gencallinterp(r4300, (unsigned int)cached_interp_BC1TL_OUT, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1TL_OUT, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1t_test(r4300);
    free_all_registers(r4300);
    gentestl_out(r4300);
#endif
}

void gen_BC1TL_IDLE(struct r4300_core* r4300)
{
#ifdef INTERPRET_BC1TL_IDLE
    gencallinterp(r4300, (unsigned int)cached_interp_BC1TL_IDLE, 1);
#else
    if (((r4300->recomp.dst->addr & 0xFFF) == 0xFFC && (r4300->recomp.dst->addr < 0x80000000 || r4300->recomp.dst->addr >= 0xC0000000))
       || r4300->recomp.no_compiled_jump)
    {
        gencallinterp(r4300, (unsigned int)cached_interp_BC1TL_IDLE, 1);
        return;
    }

    gencheck_cop1_unusable(r4300);
    genbc1t_test(r4300);
    gentest_idle(r4300);
    gen_BC1TL(r4300);
#endif
}

/* Special instructions */

void gen_CACHE(struct r4300_core* r4300)
{
}

void gen_ERET(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_ERET, 1);
#if 0
    dst->local_addr = code_length;
    mov_m32_imm32((void *)(&(*r4300_pc_struct(r4300))), (unsigned int)(dst));
    genupdate_system(r4300, 0);
    mov_reg32_imm32(EAX, (unsigned int)(ERET));
    call_reg32(EAX);
    mov_reg32_imm32(EAX, (unsigned int)(jump_code));
    jmp_reg32(EAX);
#endif
}

void gen_SYNC(struct r4300_core* r4300)
{
}

void gen_SYSCALL(struct r4300_core* r4300)
{
#ifdef INTERPRET_SYSCALL
    gencallinterp(r4300, (unsigned int)cached_interp_SYSCALL, 0);
#else
    free_all_registers(r4300);
    simplify_access(r4300);
    mov_m32_imm32(&r4300_cp0_regs(&r4300->cp0)[CP0_CAUSE_REG], 8 << 2);
    gencallinterp(r4300, (unsigned int)dynarec_exception_general, 0);
#endif
}

/* Exception instructions */

void gen_TEQ(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_TEQ, 0);
}

/* TLB instructions */

void gen_TLBP(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_TLBP, 0);
#if 0
    dst->local_addr = code_length;
    mov_m32_imm32((void *)(&(*r4300_pc_struct(r4300))), (unsigned int)(dst));
    mov_reg32_imm32(EAX, (unsigned int)(TLBP));
    call_reg32(EAX);
    genupdate_system(r4300, 0);
#endif
}

void gen_TLBR(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_TLBR, 0);
#if 0
    dst->local_addr = code_length;
    mov_m32_imm32((void *)(&(*r4300_pc_struct(r4300))), (unsigned int)(dst));
    mov_reg32_imm32(EAX, (unsigned int)(TLBR));
    call_reg32(EAX);
    genupdate_system(r4300, 0);
#endif
}

void gen_TLBWR(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_TLBWR, 0);
}

void gen_TLBWI(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_TLBWI, 0);
#if 0
    dst->local_addr = code_length;
    mov_m32_imm32((void *)(&(*r4300_pc_struct(r4300))), (unsigned int)(dst));
    mov_reg32_imm32(EAX, (unsigned int)(TLBWI));
    call_reg32(EAX);
    genupdate_system(r4300, 0);
#endif
}

/* CP0 load/store instructions */

void gen_MFC0(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_MFC0, 0);
}

void gen_MTC0(struct r4300_core* r4300)
{
    gencallinterp(r4300, (unsigned int)cached_interp_MTC0, 0);
}

/* CP1 load/store instructions */

void gen_LWC1(struct r4300_core* r4300)
{
#ifdef INTERPRET_LWC1
    gencallinterp(r4300, (unsigned int)cached_interp_LWC1, 0);
#else
    gencheck_cop1_unusable(r4300);

    mov_eax_memoffs32((unsigned int *)(&r4300_regs(r4300)[r4300->recomp.dst->f.lf.base]));
    add_eax_imm32((int)r4300->recomp.dst->f.lf.offset);
    mov_reg32_reg32(EBX, EAX);
    if (r4300->recomp.fast_memory)
    {
        and_eax_imm32(0xDF800000);
        cmp_eax_imm32(0x80000000);
    }
    else
    {
        shr_reg32_imm8(EAX, 16);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].read32);
        cmp_reg32_imm32(EAX, (unsigned int)read_rdram_dram);
    }
    je_rj(37);

    mov_m32_imm32((unsigned int *)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1)); // 10
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_reg32_m32(EDX, (unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.lf.ft])); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.rdword), EDX); // 6
    mov_reg32_imm32(EBX, (unsigned int)dynarec_read_aligned_word); // 5
    call_reg32(EBX); // 2
    jmp_imm_short(20); // 2

    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    mov_reg32_preg32pimm32(EAX, EBX, (unsigned int)r4300->rdram->dram); // 6
    mov_reg32_m32(EBX, (unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.lf.ft])); // 6
    mov_preg32_reg32(EBX, EAX); // 2
#endif
}

void gen_LDC1(struct r4300_core* r4300)
{
#ifdef INTERPRET_LDC1
    gencallinterp(r4300, (unsigned int)cached_interp_LDC1, 0);
#else
    gencheck_cop1_unusable(r4300);

    mov_eax_memoffs32((unsigned int *)(&r4300_regs(r4300)[r4300->recomp.dst->f.lf.base]));
    add_eax_imm32((int)r4300->recomp.dst->f.lf.offset);
    mov_reg32_reg32(EBX, EAX);
    if (r4300->recomp.fast_memory)
    {
        and_eax_imm32(0xDF800000);
        cmp_eax_imm32(0x80000000);
    }
    else
    {
        shr_reg32_imm8(EAX, 16);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].read32);
        cmp_reg32_imm32(EAX, (unsigned int)read_rdram_dram);
    }
    je_rj(37);

    mov_m32_imm32((unsigned int *)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1)); // 10
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_reg32_m32(EDX, (unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.lf.ft])); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.rdword), EDX); // 6
    mov_reg32_imm32(EBX, (unsigned int)dynarec_read_aligned_dword); // 5
    call_reg32(EBX); // 2
    jmp_imm_short(32); // 2

    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    mov_reg32_preg32pimm32(EAX, EBX, ((unsigned int)r4300->rdram->dram)+4); // 6
    mov_reg32_preg32pimm32(ECX, EBX, ((unsigned int)r4300->rdram->dram)); // 6
    mov_reg32_m32(EBX, (unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.lf.ft])); // 6
    mov_preg32_reg32(EBX, EAX); // 2
    mov_preg32pimm32_reg32(EBX, 4, ECX); // 6
#endif
}

void gen_SWC1(struct r4300_core* r4300)
{
#ifdef INTERPRET_SWC1
    gencallinterp(r4300, (unsigned int)cached_interp_SWC1, 0);
#else
    gencheck_cop1_unusable(r4300);

    mov_reg32_m32(EDX, (unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.lf.ft]));
    mov_reg32_preg32(ECX, EDX);
    mov_eax_memoffs32((unsigned int *)(&r4300_regs(r4300)[r4300->recomp.dst->f.lf.base]));
    add_eax_imm32((int)r4300->recomp.dst->f.lf.offset);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].write32);
        cmp_reg32_imm32(EAX, (unsigned int)write_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(46);

    mov_m32_imm32((unsigned int *)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1)); // 10
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.wword), ECX); // 6
    mov_m32_imm32((unsigned int *)(&r4300->recomp.wmask), ~UINT32_C(0)); // 10
    mov_reg32_imm32(EBX, (unsigned int)dynarec_write_aligned_word); // 5
    call_reg32(EBX); // 2
    mov_eax_memoffs32((unsigned int *)(&r4300->recomp.address)); // 5
    jmp_imm_short(14); // 2

    mov_reg32_reg32(EAX, EBX); // 2
    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    mov_preg32pimm32_reg32(EBX, (unsigned int)r4300->rdram->dram, ECX); // 6

    mov_reg32_reg32(EBX, EAX);
    shr_reg32_imm8(EBX, 12);
    cmp_preg32pimm32_imm8(EBX, (unsigned int)r4300->cached_interp.invalid_code, 0);
    jne_rj(54);
    mov_reg32_reg32(ECX, EBX); // 2
    shl_reg32_imm8(EBX, 2); // 3
    mov_reg32_preg32pimm32(EBX, EBX, (unsigned int)r4300->cached_interp.blocks); // 6
    mov_reg32_preg32pimm32(EBX, EBX, (int)&r4300->cached_interp.actual->block - (int)r4300->cached_interp.actual); // 6
    and_eax_imm32(0xFFF); // 5
    shr_reg32_imm8(EAX, 2); // 3
    mov_reg32_imm32(EDX, sizeof(struct precomp_instr)); // 5
    mul_reg32(EDX); // 2
    mov_reg32_preg32preg32pimm32(EAX, EAX, EBX, (int)&r4300->recomp.dst->ops - (int)r4300->recomp.dst); // 7
    cmp_reg32_imm32(EAX, (unsigned int)dynarec_notcompiled); // 6
    je_rj(7); // 2
    mov_preg32pimm32_imm8(ECX, (unsigned int)r4300->cached_interp.invalid_code, 1); // 7
#endif
}

void gen_SDC1(struct r4300_core* r4300)
{
#ifdef INTERPRET_SDC1
    gencallinterp(r4300, (unsigned int)cached_interp_SDC1, 0);
#else
    gencheck_cop1_unusable(r4300);

    mov_reg32_m32(ESI, (unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.lf.ft]));
    mov_reg32_preg32(ECX, ESI);
    mov_reg32_preg32pimm32(EDX, ESI, 4);
    mov_eax_memoffs32((unsigned int *)(&r4300_regs(r4300)[r4300->recomp.dst->f.lf.base]));
    add_eax_imm32((int)r4300->recomp.dst->f.lf.offset);
    mov_reg32_reg32(EBX, EAX);

    /* is address in RDRAM ? */
    and_reg32_imm32(EAX, 0xDF800000);
    cmp_reg32_imm32(EAX, 0x80000000);

    /* when fast_memory is true, we know that there is
     * no custom read handler so skip this test entirely */
    if (!r4300->recomp.fast_memory) {
        /* not in RDRAM anyway so skip the read32 check */
        jne_rj(0);
        jump_start_rel8(r4300);

        shr_reg32_imm8(EAX, 16);
        and_reg32_imm32(EAX, 0x1fff);
        lea_reg32_preg32x2preg32(EAX, EAX, EAX);
        mov_reg32_preg32x4pimm32(EAX, EAX, (unsigned int)r4300->mem->handlers[0].write32);
        cmp_reg32_imm32(EAX, (unsigned int)write_rdram_dram);

        jump_end_rel8(r4300);
    }
    je_rj(42);

    mov_m32_imm32((unsigned int *)(&(*r4300_pc_struct(r4300))), (unsigned int)(r4300->recomp.dst+1)); // 10
    mov_m32_reg32((unsigned int *)(&r4300->recomp.address), EBX); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.wdword), ECX); // 6
    mov_m32_reg32((unsigned int *)(&r4300->recomp.wdword)+1, EDX); // 6
    mov_reg32_imm32(EBX, (unsigned int)dynarec_write_aligned_dword); // 5
    call_reg32(EBX); // 2
    mov_eax_memoffs32((unsigned int *)(&r4300->recomp.address)); // 5
    jmp_imm_short(20); // 2

    mov_reg32_reg32(EAX, EBX); // 2
    and_reg32_imm32(EBX, 0x7FFFFF); // 6
    mov_preg32pimm32_reg32(EBX, ((unsigned int)r4300->rdram->dram)+4, ECX); // 6
    mov_preg32pimm32_reg32(EBX, ((unsigned int)r4300->rdram->dram)+0, EDX); // 6

    mov_reg32_reg32(EBX, EAX);
    shr_reg32_imm8(EBX, 12);
    cmp_preg32pimm32_imm8(EBX, (unsigned int)r4300->cached_interp.invalid_code, 0);
    jne_rj(54);
    mov_reg32_reg32(ECX, EBX); // 2
    shl_reg32_imm8(EBX, 2); // 3
    mov_reg32_preg32pimm32(EBX, EBX, (unsigned int)r4300->cached_interp.blocks); // 6
    mov_reg32_preg32pimm32(EBX, EBX, (int)&r4300->cached_interp.actual->block - (int)r4300->cached_interp.actual); // 6
    and_eax_imm32(0xFFF); // 5
    shr_reg32_imm8(EAX, 2); // 3
    mov_reg32_imm32(EDX, sizeof(struct precomp_instr)); // 5
    mul_reg32(EDX); // 2
    mov_reg32_preg32preg32pimm32(EAX, EAX, EBX, (int)&r4300->recomp.dst->ops - (int)r4300->recomp.dst); // 7
    cmp_reg32_imm32(EAX, (unsigned int)dynarec_notcompiled); // 6
    je_rj(7); // 2
    mov_preg32pimm32_imm8(ECX, (unsigned int)r4300->cached_interp.invalid_code, 1); // 7
#endif
}

void gen_MFC1(struct r4300_core* r4300)
{
#ifdef INTERPRET_MFC1
    gencallinterp(r4300, (unsigned int)cached_interp_MFC1, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.r.nrd]));
    mov_reg32_preg32(EBX, EAX);
    mov_m32_reg32((unsigned int*)r4300->recomp.dst->f.r.rt, EBX);
    sar_reg32_imm8(EBX, 31);
    mov_m32_reg32(((unsigned int*)r4300->recomp.dst->f.r.rt)+1, EBX);
#endif
}

void gen_DMFC1(struct r4300_core* r4300)
{
#ifdef INTERPRET_DMFC1
    gencallinterp(r4300, (unsigned int)cached_interp_DMFC1, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.r.nrd]));
    mov_reg32_preg32(EBX, EAX);
    mov_reg32_preg32pimm32(ECX, EAX, 4);
    mov_m32_reg32((unsigned int*)r4300->recomp.dst->f.r.rt, EBX);
    mov_m32_reg32(((unsigned int*)r4300->recomp.dst->f.r.rt)+1, ECX);
#endif
}

void gen_CFC1(struct r4300_core* r4300)
{
#ifdef INTERPRET_CFC1
    gencallinterp(r4300, (unsigned int)cached_interp_CFC1, 0);
#else
    gencheck_cop1_unusable(r4300);
    if (r4300->recomp.dst->f.r.nrd == 31) {
        mov_eax_memoffs32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)));
    }
    else {
        mov_eax_memoffs32((unsigned int*)&(*r4300_cp1_fcr0(&r4300->cp1)));
    }
    mov_memoffs32_eax((unsigned int*)r4300->recomp.dst->f.r.rt);
    sar_reg32_imm8(EAX, 31);
    mov_memoffs32_eax(((unsigned int*)r4300->recomp.dst->f.r.rt)+1);
#endif
}

void gen_MTC1(struct r4300_core* r4300)
{
#ifdef INTERPRET_MTC1
    gencallinterp(r4300, (unsigned int)cached_interp_MTC1, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)r4300->recomp.dst->f.r.rt);
    mov_reg32_m32(EBX, (unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.r.nrd]));
    mov_preg32_reg32(EBX, EAX);
#endif
}

void gen_DMTC1(struct r4300_core* r4300)
{
#ifdef INTERPRET_DMTC1
    gencallinterp(r4300, (unsigned int)cached_interp_DMTC1, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)r4300->recomp.dst->f.r.rt);
    mov_reg32_m32(EBX, ((unsigned int*)r4300->recomp.dst->f.r.rt)+1);
    mov_reg32_m32(EDX, (unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.r.nrd]));
    mov_preg32_reg32(EDX, EAX);
    mov_preg32pimm32_reg32(EDX, 4, EBX);
#endif
}

void gen_CTC1(struct r4300_core* r4300)
{
#ifdef INTERPRET_CTC1
    gencallinterp(r4300, (unsigned int)cached_interp_CTC1, 0);
#else
    gencheck_cop1_unusable(r4300);

    if (r4300->recomp.dst->f.r.nrd != 31) {
        return;
    }
    mov_eax_memoffs32((unsigned int*)r4300->recomp.dst->f.r.rt);
    mov_memoffs32_eax((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)));
    and_eax_imm32(3);

    cmp_eax_imm32(0);
    jne_rj(12);
    mov_m32_imm32((unsigned int*)&r4300->cp1.rounding_mode, 0x33F); // 10
    jmp_imm_short(48); // 2

    cmp_eax_imm32(1); // 5
    jne_rj(12); // 2
    mov_m32_imm32((unsigned int*)&r4300->cp1.rounding_mode, 0xF3F); // 10
    jmp_imm_short(29); // 2

    cmp_eax_imm32(2); // 5
    jne_rj(12); // 2
    mov_m32_imm32((unsigned int*)&r4300->cp1.rounding_mode, 0xB3F); // 10
    jmp_imm_short(10); // 2

    mov_m32_imm32((unsigned int*)&r4300->cp1.rounding_mode, 0x73F); // 10

    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

/* CP1 computational instructions */

void gen_CP1_ABS_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_ABS_S
    gencallinterp(r4300, (unsigned int)cached_interp_ABS_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fabs_();
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_dword(EAX);
#endif
}

void gen_CP1_ABS_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_ABS_D
    gencallinterp(r4300, (unsigned int)cached_interp_ABS_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fabs_();
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_qword(EAX);
#endif
}

void gen_CP1_ADD_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_ADD_S
    gencallinterp(r4300, (unsigned int)cached_interp_ADD_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fadd_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_dword(EAX);
#endif
}

void gen_CP1_ADD_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_ADD_D
    gencallinterp(r4300, (unsigned int)cached_interp_ADD_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fadd_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_qword(EAX);
#endif
}

void gen_CP1_DIV_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_DIV_S
    gencallinterp(r4300, (unsigned int)cached_interp_DIV_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fdiv_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_dword(EAX);
#endif
}

void gen_CP1_DIV_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_DIV_D
    gencallinterp(r4300, (unsigned int)cached_interp_DIV_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fdiv_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_qword(EAX);
#endif
}

void gen_CP1_MOV_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_MOV_S
    gencallinterp(r4300, (unsigned int)cached_interp_MOV_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    mov_reg32_preg32(EBX, EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    mov_preg32_reg32(EAX, EBX);
#endif
}

void gen_CP1_MOV_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_MOV_D
    gencallinterp(r4300, (unsigned int)cached_interp_MOV_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    mov_reg32_preg32(EBX, EAX);
    mov_reg32_preg32pimm32(ECX, EAX, 4);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    mov_preg32_reg32(EAX, EBX);
    mov_preg32pimm32_reg32(EAX, 4, ECX);
#endif
}

void gen_CP1_MUL_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_MUL_S
    gencallinterp(r4300, (unsigned int)cached_interp_MUL_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fmul_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_dword(EAX);
#endif
}

void gen_CP1_MUL_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_MUL_D
    gencallinterp(r4300, (unsigned int)cached_interp_MUL_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fmul_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_qword(EAX);
#endif
}

void gen_CP1_NEG_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_NEG_S
    gencallinterp(r4300, (unsigned int)cached_interp_NEG_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fchs();
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_dword(EAX);
#endif
}

void gen_CP1_NEG_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_NEG_D
    gencallinterp(r4300, (unsigned int)cached_interp_NEG_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fchs();
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_qword(EAX);
#endif
}

void gen_CP1_SQRT_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_SQRT_S
    gencallinterp(r4300, (unsigned int)cached_interp_SQRT_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fsqrt();
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_dword(EAX);
#endif
}

void gen_CP1_SQRT_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_SQRT_D
    gencallinterp(r4300, (unsigned int)cached_interp_SQRT_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fsqrt();
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_qword(EAX);
#endif
}

void gen_CP1_SUB_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_SUB_S
    gencallinterp(r4300, (unsigned int)cached_interp_SUB_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fsub_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_dword(EAX);
#endif
}

void gen_CP1_SUB_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_SUB_D
    gencallinterp(r4300, (unsigned int)cached_interp_SUB_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fsub_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_qword(EAX);
#endif
}

void gen_CP1_TRUNC_W_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_TRUNC_W_S
    gencallinterp(r4300, (unsigned int)cached_interp_TRUNC_W_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&trunc_mode);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_dword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_TRUNC_W_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_TRUNC_W_D
    gencallinterp(r4300, (unsigned int)cached_interp_TRUNC_W_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&trunc_mode);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_dword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_TRUNC_L_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_TRUNC_L_S
    gencallinterp(r4300, (unsigned int)cached_interp_TRUNC_L_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&trunc_mode);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_qword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_TRUNC_L_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_TRUNC_L_D
    gencallinterp(r4300, (unsigned int)cached_interp_TRUNC_L_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&trunc_mode);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_qword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_ROUND_W_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_ROUND_W_S
    gencallinterp(r4300, (unsigned int)cached_interp_ROUND_W_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&round_mode);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_dword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_ROUND_W_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_ROUND_W_D
    gencallinterp(r4300, (unsigned int)cached_interp_ROUND_W_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&round_mode);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_dword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_ROUND_L_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_ROUND_L_S
    gencallinterp(r4300, (unsigned int)cached_interp_ROUND_L_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&round_mode);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_qword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_ROUND_L_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_ROUND_L_D
    gencallinterp(r4300, (unsigned int)cached_interp_ROUND_L_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&round_mode);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_qword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_CEIL_W_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CEIL_W_S
    gencallinterp(r4300, (unsigned int)cached_interp_CEIL_W_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&ceil_mode);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_dword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_CEIL_W_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CEIL_W_D
    gencallinterp(r4300, (unsigned int)cached_interp_CEIL_W_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&ceil_mode);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_dword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_CEIL_L_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CEIL_L_S
    gencallinterp(r4300, (unsigned int)cached_interp_CEIL_L_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&ceil_mode);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_qword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_CEIL_L_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CEIL_L_D
    gencallinterp(r4300, (unsigned int)cached_interp_CEIL_L_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&ceil_mode);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_qword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_FLOOR_W_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_FLOOR_W_S
    gencallinterp(r4300, (unsigned int)cached_interp_FLOOR_W_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&floor_mode);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_dword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_FLOOR_W_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_FLOOR_W_D
    gencallinterp(r4300, (unsigned int)cached_interp_FLOOR_W_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&floor_mode);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_dword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_FLOOR_L_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_FLOOR_L_S
    gencallinterp(r4300, (unsigned int)cached_interp_FLOOR_L_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&floor_mode);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_qword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_FLOOR_L_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_FLOOR_L_D
    gencallinterp(r4300, (unsigned int)cached_interp_FLOOR_L_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    fldcw_m16((unsigned short*)&floor_mode);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_qword(EAX);
    fldcw_m16((unsigned short*)&r4300->cp1.rounding_mode);
#endif
}

void gen_CP1_CVT_S_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CVT_S_D
    gencallinterp(r4300, (unsigned int)cached_interp_CVT_S_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_dword(EAX);
#endif
}

void gen_CP1_CVT_S_W(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CVT_S_W
    gencallinterp(r4300, (unsigned int)cached_interp_CVT_S_W, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fild_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_dword(EAX);
#endif
}

void gen_CP1_CVT_S_L(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CVT_S_L
    gencallinterp(r4300, (unsigned int)cached_interp_CVT_S_L, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fild_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_dword(EAX);
#endif
}

void gen_CP1_CVT_D_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CVT_D_S
    gencallinterp(r4300, (unsigned int)cached_interp_CVT_D_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_qword(EAX);
#endif
}

void gen_CP1_CVT_D_W(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CVT_D_W
    gencallinterp(r4300, (unsigned int)cached_interp_CVT_D_W, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fild_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_qword(EAX);
#endif
}

void gen_CP1_CVT_D_L(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CVT_D_L
    gencallinterp(r4300, (unsigned int)cached_interp_CVT_D_L, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fild_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fstp_preg32_qword(EAX);
#endif
}

void gen_CP1_CVT_W_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CVT_W_S
    gencallinterp(r4300, (unsigned int)cached_interp_CVT_W_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_dword(EAX);
#endif
}

void gen_CP1_CVT_W_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CVT_W_D
    gencallinterp(r4300, (unsigned int)cached_interp_CVT_W_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_dword(EAX);
#endif
}

void gen_CP1_CVT_L_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CVT_L_S
    gencallinterp(r4300, (unsigned int)cached_interp_CVT_L_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_qword(EAX);
#endif
}

void gen_CP1_CVT_L_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_CVT_L_D
    gencallinterp(r4300, (unsigned int)cached_interp_CVT_L_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fd]));
    fistp_preg32_qword(EAX);
#endif
}

/* CP1 relational instructions */

void gen_CP1_C_F_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_F_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_F_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000);
#endif
}

void gen_CP1_C_F_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_F_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_F_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000);
#endif
}

void gen_CP1_C_UN_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_UN_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_UN_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(12);
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
    jmp_imm_short(10); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
#endif
}

void gen_CP1_C_UN_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_UN_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_UN_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(12);
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
    jmp_imm_short(10); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
#endif
}

void gen_CP1_C_EQ_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_EQ_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_EQ_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jne_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_EQ_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_EQ_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_EQ_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jne_rj(12); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_UEQ_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_UEQ_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_UEQ_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    jne_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_UEQ_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_UEQ_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_UEQ_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    jne_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_OLT_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_OLT_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_OLT_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jae_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_OLT_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_OLT_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_OLT_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jae_rj(12); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_ULT_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_ULT_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_ULT_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    jae_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_ULT_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_ULT_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_ULT_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    jae_rj(12); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_OLE_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_OLE_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_OLE_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    ja_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_OLE_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_OLE_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_OLE_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    ja_rj(12); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_ULE_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_ULE_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_ULE_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    ja_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_ULE_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_ULE_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_ULE_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fucomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    ja_rj(12); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_SF_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_SF_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_SF_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000);
#endif
}

void gen_CP1_C_SF_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_SF_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_SF_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000);
#endif
}

void gen_CP1_C_NGLE_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_NGLE_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_NGLE_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(12);
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
    jmp_imm_short(10); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
#endif
}

void gen_CP1_C_NGLE_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_NGLE_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_NGLE_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(12);
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
    jmp_imm_short(10); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
#endif
}

void gen_CP1_C_SEQ_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_SEQ_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_SEQ_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jne_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_SEQ_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_SEQ_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_SEQ_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jne_rj(12); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_NGL_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_NGL_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_NGL_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    jne_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_NGL_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_NGL_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_NGL_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    jne_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_LT_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_LT_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_LT_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jae_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_LT_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_LT_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_LT_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jae_rj(12); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_NGE_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_NGE_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_NGE_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    jae_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_NGE_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_NGE_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_NGE_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    jae_rj(12); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_LE_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_LE_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_LE_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    ja_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_LE_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_LE_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_LE_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    ja_rj(12); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_NGT_S(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_NGT_S
    gencallinterp(r4300, (unsigned int)cached_interp_C_NGT_S, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_dword(EAX);
    mov_eax_memoffs32((unsigned int *)(&(r4300_cp1_regs_simple(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_dword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    ja_rj(12);
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}

void gen_CP1_C_NGT_D(struct r4300_core* r4300)
{
#ifdef INTERPRET_CP1_C_NGT_D
    gencallinterp(r4300, (unsigned int)cached_interp_C_NGT_D, 0);
#else
    gencheck_cop1_unusable(r4300);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.ft]));
    fld_preg32_qword(EAX);
    mov_eax_memoffs32((unsigned int*)(&(r4300_cp1_regs_double(&r4300->cp1))[r4300->recomp.dst->f.cf.fs]));
    fld_preg32_qword(EAX);
    fcomip_fpreg(1);
    ffree_fpreg(0);
    jp_rj(14);
    ja_rj(12); // 2
    or_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), 0x800000); // 10
    jmp_imm_short(10); // 2
    and_m32_imm32((unsigned int*)&(*r4300_cp1_fcr31(&r4300->cp1)), ~0x800000); // 10
#endif
}
