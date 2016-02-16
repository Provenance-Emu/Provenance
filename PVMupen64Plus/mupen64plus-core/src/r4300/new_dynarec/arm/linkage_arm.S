/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - linkage_arm.S                                           *
 *   Copyright (C) 2009-2011 Ari64                                         *
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

#define GLOBAL_FUNCTION(name)  \
    .align 2;                  \
    .globl name;               \
    .hidden name;              \
    .type name, %function;     \
    name

#define LOCAL_FUNCTION(name)  \
    .align 2;                 \
    .hidden name;             \
    .type name, %function;    \
    name

#define GLOBAL_VARIABLE(name, size_) \
    .global name;                    \
    .hidden name;                    \
    .type   name, %object;           \
    .size   name, size_

#define BSS_SECTION  .bss
#define TEXT_SECTION .text
#define END_SECTION

    .cpu arm9tdmi
#ifndef __ARM_NEON__
#if (defined(__VFP_FP__) && !defined(__SOFTFP__) && defined(__ARM_PCS_VFP))
    .fpu vfp
#else
    .fpu softvfp
#endif
#else
    .fpu neon
#endif
    .eabi_attribute 20, 1
    .eabi_attribute 21, 1
#ifndef __ARM_NEON__
    .eabi_attribute 23, 3
#endif
    .eabi_attribute 24, 1
    .eabi_attribute 25, 1
    .eabi_attribute 26, 2
#ifndef __ARM_NEON__
#if (defined(__VFP_FP__) && !defined(__SOFTFP__) && defined(__ARM_PCS_VFP))
    .eabi_attribute 28, 1
#endif
#endif
    .eabi_attribute 30, 6
    .eabi_attribute 18, 4
    .file    "linkage_arm.S"

BSS_SECTION

    .align   12
    GLOBAL_VARIABLE(extra_memory, 33554432)
    GLOBAL_VARIABLE(dynarec_local, 64)
    GLOBAL_VARIABLE(next_interupt, 4)
    GLOBAL_VARIABLE(cycle_count, 4)
    GLOBAL_VARIABLE(last_count, 4)
    GLOBAL_VARIABLE(pending_exception, 4)
    GLOBAL_VARIABLE(pcaddr, 4)
    GLOBAL_VARIABLE(stop, 4)
    GLOBAL_VARIABLE(invc_ptr, 4)
    GLOBAL_VARIABLE(address, 4)
    GLOBAL_VARIABLE(readmem_dword, 8)
    GLOBAL_VARIABLE(cpu_dword, 8)
    GLOBAL_VARIABLE(cpu_word, 4)
    GLOBAL_VARIABLE(cpu_hword, 2)
    GLOBAL_VARIABLE(cpu_byte, 1)
    GLOBAL_VARIABLE(FCR0, 4)
    GLOBAL_VARIABLE(FCR31, 4)
    GLOBAL_VARIABLE(reg, 256)
    GLOBAL_VARIABLE(hi, 8)
    GLOBAL_VARIABLE(lo, 8)
    GLOBAL_VARIABLE(g_cp0_regs, 128)
    GLOBAL_VARIABLE(reg_cop1_simple, 128)
    GLOBAL_VARIABLE(reg_cop1_double, 128)
    GLOBAL_VARIABLE(rounding_modes, 16)
    GLOBAL_VARIABLE(branch_target, 4)
    GLOBAL_VARIABLE(PC, 4)
    GLOBAL_VARIABLE(fake_pc, 132)
    GLOBAL_VARIABLE(ram_offset, 4)
    GLOBAL_VARIABLE(mini_ht, 256)
    GLOBAL_VARIABLE(restore_candidate, 512)
    GLOBAL_VARIABLE(memory_map, 4194304)

extra_memory:
    .space    33554432+64+4+4+4+4+4+4+4+4+8+8+4+2+2+4+4+256+8+8+128+128+128+16+4+4+132+4+256+512+4194304

    dynarec_local     = extra_memory      + 33554432
    next_interupt     = dynarec_local     + 64
    cycle_count       = next_interupt     + 4
    last_count        = cycle_count       + 4
    pending_exception = last_count        + 4
    pcaddr            = pending_exception + 4
    stop              = pcaddr            + 4
    invc_ptr          = stop              + 4
    address           = invc_ptr          + 4
    readmem_dword     = address           + 4
    cpu_dword         = readmem_dword     + 8
    cpu_word          = cpu_dword         + 8
    cpu_hword         = cpu_word          + 4
    cpu_byte          = cpu_hword         + 2 /* 1 byte free */
    FCR0              = cpu_hword         + 4
    FCR31             = FCR0              + 4
    reg               = FCR31             + 4
    hi                = reg               + 256
    lo                = hi                + 8
    g_cp0_regs        = lo                + 8
    reg_cop1_simple   = g_cp0_regs        + 128
    reg_cop1_double   = reg_cop1_simple   + 128
    rounding_modes    = reg_cop1_double   + 128
    branch_target     = rounding_modes    + 16
    PC                = branch_target     + 4
    fake_pc           = PC                + 4
    ram_offset        = fake_pc           + 132
    mini_ht           = ram_offset        + 4
    restore_candidate = mini_ht           + 256
    memory_map        = restore_candidate + 512

END_SECTION

TEXT_SECTION

    .align   2
    .jiptr_offset1  : .word jump_in-(.jiptr_pic1+8)
    .jiptr_offset2  : .word jump_in-(.jiptr_pic2+8)
    .jdptr_offset1  : .word jump_dirty-(.jdptr_pic1+8)
    .jdptr_offset2  : .word jump_dirty-(.jdptr_pic2+8)
    .tlbptr_offset1 : .word tlb_LUT_r-(.tlbptr_pic1+8)
    .tlbptr_offset2 : .word tlb_LUT_r-(.tlbptr_pic2+8)
    .htptr_offset1  : .word hash_table-(.htptr_pic1+8)
    .htptr_offset2  : .word hash_table-(.htptr_pic2+8)
    .htptr_offset3  : .word hash_table-(.htptr_pic3+8)
    .dlptr_offset   : .word dynarec_local+28-(.dlptr_pic+8)
    .outptr_offset  : .word out-(.outptr_pic+8)

GLOBAL_FUNCTION(dyna_linker):
    /* r0 = virtual target address */
    /* r1 = instruction to patch */
    ldr    r4, .tlbptr_offset1
.tlbptr_pic1:
    add    r4, pc, r4
    lsr    r5, r0, #12
    mov    r12, r0
    cmp    r0, #0xC0000000
    mov    r6, #4096
    ldrge  r12, [r4, r5, lsl #2]
    mov    r2, #0x80000
    ldr    r3, .jiptr_offset1
.jiptr_pic1:
    add    r3, pc, r3
    tst    r12, r12
    sub    r6, r6, #1
    moveq  r12, r0
    ldr    r7, [r1]
    eor    r2, r2, r12, lsr #12
    and    r6, r6, r12, lsr #12
    cmp    r2, #2048
    add    r12, r7, #2
    orrcs  r2, r6, #2048
    ldr    r5, [r3, r2, lsl #2]
    lsl    r12, r12, #8
    /* jump_in lookup */
.A1:
    movs   r4, r5
    beq    .A3
    ldr    r3, [r5]
    ldr    r5, [r4, #12]
    teq    r3, r0
    bne    .A1
    ldr    r3, [r4, #4]
    ldr    r4, [r4, #8]
    tst    r3, r3
    bne    .A1
.A2:
    mov    r5, r1
    add    r1, r1, r12, asr #6
    teq    r1, r4
    moveq  pc, r4 /* Stale i-cache */
    bl     add_link
    sub    r2, r4, r5
    and    r1, r7, #0xff000000
    lsl    r2, r2, #6
    sub    r1, r1, #2
    add    r1, r1, r2, lsr #8
    str    r1, [r5]
    mov    pc, r4
.A3:
    /* hash_table lookup */
    cmp    r2, #2048
    ldr    r3, .jdptr_offset1
.jdptr_pic1:
    add    r3, pc, r3
    eor    r4, r0, r0, lsl #16
    lslcc  r2, r0, #9
    ldr    r6, .htptr_offset1
.htptr_pic1:
    add    r6, pc, r6
    lsr    r4, r4, #12
    lsrcc  r2, r2, #21
    bic    r4, r4, #15
    ldr    r5, [r3, r2, lsl #2]
    ldr    r7, [r6, r4]!
    teq    r7, r0
    ldreq  pc, [r6, #4]
    ldr    r7, [r6, #8]
    teq    r7, r0
    ldreq  pc, [r6, #12]
    /* jump_dirty lookup */
.A6:
    movs   r4, r5
    beq    .A8
    ldr    r3, [r5]
    ldr    r5, [r4, #12]
    teq    r3, r0
    bne    .A6
.A7:
    ldr    r1, [r4, #8]
    /* hash_table insert */
    ldr    r2, [r6]
    ldr    r3, [r6, #4]
    str    r0, [r6]
    str    r1, [r6, #4]
    str    r2, [r6, #8]
    str    r3, [r6, #12]
    mov    pc, r1
.A8:
    mov    r4, r0
    mov    r5, r1
    bl     new_recompile_block
    tst    r0, r0
    mov    r0, r4
    mov    r1, r5
    beq    dyna_linker
    /* pagefault */
    mov    r1, r0
    mov    r2, #8

LOCAL_FUNCTION(exec_pagefault):
    /* r0 = instruction pointer */
    /* r1 = fault address */
    /* r2 = cause */
    ldr    r3, [fp, #g_cp0_regs+48-dynarec_local] /* Status */
    mvn    r6, #0xF000000F
    ldr    r4, [fp, #g_cp0_regs+16-dynarec_local] /* Context */
    bic    r6, r6, #0x0F800000
    str    r0, [fp, #g_cp0_regs+56-dynarec_local] /* EPC */
    orr    r3, r3, #2
    str    r1, [fp, #g_cp0_regs+32-dynarec_local] /* BadVAddr */
    bic    r4, r4, r6
    str    r3, [fp, #g_cp0_regs+48-dynarec_local] /* Status */
    and    r5, r6, r1, lsr #9
    str    r2, [fp, #g_cp0_regs+52-dynarec_local] /* Cause */
    and    r1, r1, r6, lsl #9
    str    r1, [fp, #g_cp0_regs+40-dynarec_local] /* EntryHi */
    orr    r4, r4, r5
    str    r4, [fp, #g_cp0_regs+16-dynarec_local] /* Context */
    mov    r0, #0x80000000
    bl     get_addr_ht
    mov    pc, r0

/* Special dynamic linker for the case where a page fault
   may occur in a branch delay slot */
GLOBAL_FUNCTION(dyna_linker_ds):
    /* r0 = virtual target address */
    /* r1 = instruction to patch */
    ldr    r4, .tlbptr_offset2
.tlbptr_pic2:
    add    r4, pc, r4
    lsr    r5, r0, #12
    mov    r12, r0
    cmp    r0, #0xC0000000
    mov    r6, #4096
    ldrge  r12, [r4, r5, lsl #2]
    mov    r2, #0x80000
    ldr    r3, .jiptr_offset2
.jiptr_pic2:
    add    r3, pc, r3
    tst    r12, r12
    sub    r6, r6, #1
    moveq  r12, r0
    ldr    r7, [r1]
    eor    r2, r2, r12, lsr #12
    and    r6, r6, r12, lsr #12
    cmp    r2, #2048
    add    r12, r7, #2
    orrcs  r2, r6, #2048
    ldr    r5, [r3, r2, lsl #2]
    lsl    r12, r12, #8
    /* jump_in lookup */
.B1:
    movs   r4, r5
    beq    .B3
    ldr    r3, [r5]
    ldr    r5, [r4, #12]
    teq    r3, r0
    bne    .B1
    ldr    r3, [r4, #4]
    ldr    r4, [r4, #8]
    tst    r3, r3
    bne    .B1
.B2:
    mov    r5, r1
    add    r1, r1, r12, asr #6
    teq    r1, r4
    moveq  pc, r4 /* Stale i-cache */
    bl     add_link
    sub    r2, r4, r5
    and    r1, r7, #0xff000000
    lsl    r2, r2, #6
    sub    r1, r1, #2
    add    r1, r1, r2, lsr #8
    str    r1, [r5]
    mov    pc, r4
.B3:
    /* hash_table lookup */
    cmp    r2, #2048
    ldr    r3, .jdptr_offset2
.jdptr_pic2:
    add    r3, pc, r3
    eor    r4, r0, r0, lsl #16
    lslcc  r2, r0, #9
    ldr    r6, .htptr_offset2
.htptr_pic2:
    add    r6, pc, r6
    lsr    r4, r4, #12
    lsrcc  r2, r2, #21
    bic    r4, r4, #15
    ldr    r5, [r3, r2, lsl #2]
    ldr    r7, [r6, r4]!
    teq    r7, r0
    ldreq  pc, [r6, #4]
    ldr    r7, [r6, #8]
    teq    r7, r0
    ldreq  pc, [r6, #12]
    /* jump_dirty lookup */
.B6:
    movs   r4, r5
    beq    .B8
    ldr    r3, [r5]
    ldr    r5, [r4, #12]
    teq    r3, r0
    bne    .B6
.B7:
    ldr    r1, [r4, #8]
    /* hash_table insert */
    ldr    r2, [r6]
    ldr    r3, [r6, #4]
    str    r0, [r6]
    str    r1, [r6, #4]
    str    r2, [r6, #8]
    str    r3, [r6, #12]
    mov    pc, r1
.B8:
    mov    r4, r0
    bic    r0, r0, #7
    mov    r5, r1
    orr    r0, r0, #1
    bl     new_recompile_block
    tst    r0, r0
    mov    r0, r4
    mov    r1, r5
    beq    dyna_linker_ds
    /* pagefault */
    bic    r1, r0, #7
    mov    r2, #0x80000008 /* High bit set indicates pagefault in delay slot */
    sub    r0, r1, #4
    b      exec_pagefault

GLOBAL_FUNCTION(jump_vaddr_r0):
    eor    r2, r0, r0, lsl #16
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_r1):
    eor    r2, r1, r1, lsl #16
    mov    r0, r1
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_r2):
    mov    r0, r2
    eor    r2, r2, r2, lsl #16
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_r3):
    eor    r2, r3, r3, lsl #16
    mov    r0, r3
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_r4):
    eor    r2, r4, r4, lsl #16
    mov    r0, r4
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_r5):
    eor    r2, r5, r5, lsl #16
    mov    r0, r5
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_r6):
    eor    r2, r6, r6, lsl #16
    mov    r0, r6
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_r8):
    eor    r2, r8, r8, lsl #16
    mov    r0, r8
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_r9):
    eor    r2, r9, r9, lsl #16
    mov    r0, r9
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_r10):
    eor    r2, r10, r10, lsl #16
    mov    r0, r10
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_r12):
    eor    r2, r12, r12, lsl #16
    mov    r0, r12
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_r7):
    eor    r2, r7, r7, lsl #16
    add    r0, r7, #0

GLOBAL_FUNCTION(jump_vaddr):
    ldr    r1, .htptr_offset3
.htptr_pic3:
    add    r1, pc, r1
    mvn    r3, #15
    and    r2, r3, r2, lsr #12
    ldr    r2, [r1, r2]!
    teq    r2, r0
    ldreq  pc, [r1, #4]
    ldr    r2, [r1, #8]
    teq    r2, r0
    ldreq  pc, [r1, #12]
    str    r10, [fp, #cycle_count-dynarec_local]
    bl     get_addr
    ldr    r10, [fp, #cycle_count-dynarec_local]
    mov    pc, r0

GLOBAL_FUNCTION(verify_code_ds):
    str    r8, [fp, #branch_target-dynarec_local]

GLOBAL_FUNCTION(verify_code_vm):
    /* r0 = instruction pointer (virtual address) */
    /* r1 = source (virtual address) */
    /* r2 = target */
    /* r3 = length */
    cmp    r1, #0xC0000000
    blt    verify_code
    add    r12, fp, #memory_map-dynarec_local
    lsr    r4, r1, #12
    add    r5, r1, r3
    sub    r5, #1
    ldr    r6, [r12, r4, lsl #2]
    lsr    r5, r5, #12
    movs   r7, r6
    bmi    .D5
    add    r1, r1, r6, lsl #2
    lsl    r6, r6, #2
.D1:
    add    r4, r4, #1
    teq    r6, r7, lsl #2
    bne    .D5
    ldr    r7, [r12, r4, lsl #2]
    cmp    r4, r5
    bls    .D1

GLOBAL_FUNCTION(verify_code):
    /* r1 = source */
    /* r2 = target */
    /* r3 = length */
    tst    r3, #4
    mov    r4, #0
    add    r3, r1, r3
    mov    r5, #0
    ldrne  r4, [r1], #4
    mov    r12, #0
    ldrne  r5, [r2], #4
    teq    r1, r3
    beq    .D3
.D2:
    ldr    r7, [r1], #4
    eor    r9, r4, r5
    ldr    r8, [r2], #4
    orrs   r9, r9, r12
    bne    .D4
    ldr    r4, [r1], #4
    eor    r12, r7, r8
    ldr    r5, [r2], #4
    cmp    r1, r3
    bcc    .D2
    teq    r7, r8
.D3:
    teqeq  r4, r5
.D4:
    ldr    r8, [fp, #branch_target-dynarec_local]
    moveq  pc, lr
.D5:
    bl     get_addr
    mov    pc, r0

GLOBAL_FUNCTION(cc_interrupt):
    ldr    r0, [fp, #last_count-dynarec_local]
    mov    r1, #0
    mov    r2, #0x1fc
    add    r10, r0, r10
    str    r1, [fp, #pending_exception-dynarec_local]
    and    r2, r2, r10, lsr #19
    add    r3, fp, #restore_candidate-dynarec_local
    str    r10, [fp, #g_cp0_regs+36-dynarec_local] /* Count */
    ldr    r4, [r2, r3]
    mov    r10, lr
    tst    r4, r4
    bne    .E4
.E1:
    bl     gen_interupt
    mov    lr, r10
    ldr    r10, [fp, #g_cp0_regs+36-dynarec_local] /* Count */
    ldr    r0, [fp, #next_interupt-dynarec_local]
    ldr    r1, [fp, #pending_exception-dynarec_local]
    ldr    r2, [fp, #stop-dynarec_local]
    str    r0, [fp, #last_count-dynarec_local]
    sub    r10, r10, r0
    tst    r2, r2
    bne    .E3
    tst    r1, r1
    moveq  pc, lr
.E2:
    ldr    r0, [fp, #pcaddr-dynarec_local]
    bl     get_addr_ht
    mov    pc, r0
.E3:
    add    r12, fp, #28
    ldmia  r12, {r4, r5, r6, r7, r8, r9, sl, fp, pc}
.E4:
    /* Move 'dirty' blocks to the 'clean' list */
    lsl    r5, r2, #3
    str    r1, [r2, r3]
    mov    r6,    #0
.E5:
    lsrs   r4, r4, #1
    add    r0, r5, r6
    blcs   clean_blocks
    add    r6, r6, #1
    tst    r6, #31
    bne    .E5
    b      .E1

GLOBAL_FUNCTION(do_interrupt):
    ldr    r0, [fp, #pcaddr-dynarec_local]
    bl     get_addr_ht
    ldr    r1, [fp, #next_interupt-dynarec_local]
    ldr    r10, [fp, #g_cp0_regs+36-dynarec_local] /* Count */
    str    r1, [fp, #last_count-dynarec_local]
    sub    r10, r10, r1
    add    r10, r10, #2
    mov    pc, r0

GLOBAL_FUNCTION(fp_exception):
    mov    r2, #0x10000000
.E7:
    ldr    r1, [fp, #g_cp0_regs+48-dynarec_local] /* Status */
    mov    r3, #0x80000000
    str    r0, [fp, #g_cp0_regs+56-dynarec_local] /* EPC */
    orr    r1, #2
    add    r2, r2, #0x2c
    str    r1, [fp, #g_cp0_regs+48-dynarec_local] /* Status */
    str    r2, [fp, #g_cp0_regs+52-dynarec_local] /* Cause */
    add    r0, r3, #0x180
    bl     get_addr_ht
    mov    pc, r0

GLOBAL_FUNCTION(fp_exception_ds):
    mov    r2, #0x90000000 /* Set high bit if delay slot */
    b      .E7

GLOBAL_FUNCTION(jump_syscall):
    ldr    r1, [fp, #g_cp0_regs+48-dynarec_local] /* Status */
    mov    r3, #0x80000000
    str    r0, [fp, #g_cp0_regs+56-dynarec_local] /* EPC */
    orr    r1, #2
    mov    r2, #0x20
    str    r1, [fp, #g_cp0_regs+48-dynarec_local] /* Status */
    str    r2, [fp, #g_cp0_regs+52-dynarec_local] /* Cause */
    add    r0, r3, #0x180
    bl     get_addr_ht
    mov    pc, r0

GLOBAL_FUNCTION(indirect_jump_indexed):
    ldr    r0, [r0, r1, lsl #2]

GLOBAL_FUNCTION(indirect_jump):
    ldr    r12, [fp, #last_count-dynarec_local]
    add    r2, r2, r12 
    str    r2, [fp, #g_cp0_regs+36-dynarec_local] /* Count */
    mov    pc, r0

GLOBAL_FUNCTION(jump_eret):
    ldr    r1, [fp, #g_cp0_regs+48-dynarec_local] /* Status */
    ldr    r0, [fp, #last_count-dynarec_local]
    bic    r1, r1, #2
    add    r10, r0, r10
    str    r1, [fp, #g_cp0_regs+48-dynarec_local] /* Status */
    str    r10, [fp, #g_cp0_regs+36-dynarec_local] /* Count */
    bl     check_interupt
    ldr    r1, [fp, #next_interupt-dynarec_local]
    ldr    r0, [fp, #g_cp0_regs+56-dynarec_local] /* EPC */
    str    r1, [fp, #last_count-dynarec_local]
    subs   r10, r10, r1
    bpl    .E11
.E8:
    add    r6, fp, #reg+256-dynarec_local
    mov    r5, #248
    mov    r1, #0
.E9:
    ldr    r2, [r6, #-8]!
    ldr    r3, [r6, #4]
    eor    r3, r3, r2, asr #31
    subs   r3, r3, #1
    adc    r1, r1, r1
    subs   r5, r5, #8
    bne    .E9
    ldr    r2, [fp, #hi-dynarec_local]
    ldr    r3, [fp, #hi+4-dynarec_local]
    eors   r3, r3, r2, asr #31
    ldr    r2, [fp, #lo-dynarec_local]
    ldreq  r3, [fp, #lo+4-dynarec_local]
    eoreq  r3, r3, r2, asr #31
    subs   r3, r3, #1
    adc    r1, r1, r1
    bl     get_addr_32
    mov    pc, r0
.E11:
    str    r0, [fp, #pcaddr-dynarec_local]
    bl     cc_interrupt
    ldr    r0, [fp, #pcaddr-dynarec_local]
    b      .E8

GLOBAL_FUNCTION(new_dyna_start):
    ldr    r12, .dlptr_offset
.dlptr_pic:
    add    r12, pc, r12
    ldr    r1, .outptr_offset
.outptr_pic:
    add    r1, pc, r1
    mov    r0, #0xa4000000
    stmia  r12, {r4, r5, r6, r7, r8, r9, sl, fp, lr}
    sub    fp, r12, #28
    ldr    r4, [r1]
    add    r0, r0, #0x40
    bl     new_recompile_block
    ldr    r0, [fp, #next_interupt-dynarec_local]
    ldr    r10, [fp, #g_cp0_regs+36-dynarec_local] /* Count */
    str    r0, [fp, #last_count-dynarec_local]
    sub    r10, r10, r0
    mov    pc, r4

GLOBAL_FUNCTION(invalidate_addr_r0):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r0, #12    
    b      invalidate_addr_call

GLOBAL_FUNCTION(invalidate_addr_r1):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r1, #12    
    b      invalidate_addr_call

GLOBAL_FUNCTION(invalidate_addr_r2):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r2, #12    
    b      invalidate_addr_call

GLOBAL_FUNCTION(invalidate_addr_r3):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r3, #12    
    b      invalidate_addr_call

GLOBAL_FUNCTION(invalidate_addr_r4):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r4, #12    
    b      invalidate_addr_call

GLOBAL_FUNCTION(invalidate_addr_r5):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r5, #12    
    b      invalidate_addr_call

GLOBAL_FUNCTION(invalidate_addr_r6):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r6, #12    
    b      invalidate_addr_call

GLOBAL_FUNCTION(invalidate_addr_r7):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r7, #12    
    b      invalidate_addr_call

GLOBAL_FUNCTION(invalidate_addr_r8):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r8, #12    
    b      invalidate_addr_call

GLOBAL_FUNCTION(invalidate_addr_r9):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r9, #12    
    b      invalidate_addr_call

GLOBAL_FUNCTION(invalidate_addr_r10):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r10, #12    
    b      invalidate_addr_call

GLOBAL_FUNCTION(invalidate_addr_r12):
    stmia  fp, {r0, r1, r2, r3, r12, lr}
    lsr    r0, r12, #12    

LOCAL_FUNCTION(invalidate_addr_call):
    bl     invalidate_block
    ldmia  fp, {r0, r1, r2, r3, r12, pc}

GLOBAL_FUNCTION(write_rdram_new):
    ldr    r3, [fp, #ram_offset-dynarec_local]
    ldr    r2, [fp, #address-dynarec_local]
    ldr    r0, [fp, #cpu_word-dynarec_local]
    str    r0, [r2, r3, lsl #2]
    b      .E12

GLOBAL_FUNCTION(write_rdramb_new):
    ldr    r3, [fp, #ram_offset-dynarec_local]
    ldr    r2, [fp, #address-dynarec_local]
    ldrb   r0, [fp, #cpu_byte-dynarec_local]
    eor    r2, r2, #3
    strb   r0, [r2, r3, lsl #2]
    b      .E12

GLOBAL_FUNCTION(write_rdramh_new):
    ldr    r3, [fp, #ram_offset-dynarec_local]
    ldr    r2, [fp, #address-dynarec_local]
    ldrh   r0, [fp, #cpu_hword-dynarec_local]
    eor    r2, r2, #2
    lsl    r3, r3, #2
    strh   r0, [r2, r3]
    b      .E12

GLOBAL_FUNCTION(write_rdramd_new):
    ldr    r3, [fp, #ram_offset-dynarec_local]
    ldr    r2, [fp, #address-dynarec_local]
/*    ldrd    r0, [fp, #cpu_dword-dynarec_local]*/
    ldr    r0, [fp, #cpu_dword-dynarec_local]
    ldr    r1, [fp, #cpu_dword+4-dynarec_local]
    add    r3, r2, r3, lsl #2
    str    r0, [r3, #4]
    str    r1, [r3]
    b      .E12

LOCAL_FUNCTION(do_invalidate):
    ldr    r2, [fp, #address-dynarec_local]
.E12:
    ldr    r1, [fp, #invc_ptr-dynarec_local]
    lsr    r0, r2, #12
    ldrb   r2, [r1, r0]
    tst    r2, r2
    beq    invalidate_block
    mov    pc, lr

GLOBAL_FUNCTION(read_nomem_new):
    ldr    r2, [fp, #address-dynarec_local]
    add    r12, fp, #memory_map-dynarec_local
    lsr    r0, r2, #12
    ldr    r12, [r12, r0, lsl #2]
    mov    r1, #8
    tst    r12, r12
    bmi    tlb_exception
    ldr    r0, [r2, r12, lsl #2]
    str    r0, [fp, #readmem_dword-dynarec_local]
    mov    pc, lr

GLOBAL_FUNCTION(read_nomemb_new):
    ldr    r2, [fp, #address-dynarec_local]
    add    r12, fp, #memory_map-dynarec_local
    lsr    r0, r2, #12
    ldr    r12, [r12, r0, lsl #2]
    mov    r1, #8
    tst    r12, r12
    bmi    tlb_exception
    eor    r2, r2, #3
    ldrb   r0, [r2, r12, lsl #2]
    str    r0, [fp, #readmem_dword-dynarec_local]
    mov    pc, lr

GLOBAL_FUNCTION(read_nomemh_new):
    ldr    r2, [fp, #address-dynarec_local]
    add    r12, fp, #memory_map-dynarec_local
    lsr    r0, r2, #12
    ldr    r12, [r12, r0, lsl #2]
    mov    r1, #8
    tst    r12, r12
    bmi    tlb_exception
    lsl    r12, r12, #2
    eor    r2, r2, #2
    ldrh   r0, [r2, r12]
    str    r0, [fp, #readmem_dword-dynarec_local]
    mov    pc, lr

GLOBAL_FUNCTION(read_nomemd_new):
    ldr    r2, [fp, #address-dynarec_local]
    add    r12, fp, #memory_map-dynarec_local
    lsr    r0, r2, #12
    ldr    r12, [r12, r0, lsl #2]
    mov    r1, #8
    tst    r12, r12
    bmi    tlb_exception
    lsl    r12, r12, #2
/*    ldrd    r0, [r2, r12]*/
    add    r3, r2, #4
    ldr    r0, [r2, r12]
    ldr    r1, [r3, r12]
    str    r0, [fp, #readmem_dword+4-dynarec_local]
    str    r1, [fp, #readmem_dword-dynarec_local]
    mov    pc, lr

GLOBAL_FUNCTION(write_nomem_new):
    str    r3, [fp, #24]
    str    lr, [fp, #28]
    bl     do_invalidate
    ldr    r2, [fp, #address-dynarec_local]
    add    r12, fp, #memory_map-dynarec_local
    ldr    lr, [fp, #28]
    lsr    r0, r2, #12
    ldr    r3, [fp, #24]
    ldr    r12, [r12, r0, lsl #2]
    mov    r1, #0xc
    tst    r12, #0x40000000
    bne    tlb_exception
    ldr    r0, [fp, #cpu_word-dynarec_local]
    str    r0, [r2, r12, lsl #2]
    mov    pc, lr

GLOBAL_FUNCTION(write_nomemb_new):
    str    r3, [fp, #24]
    str    lr, [fp, #28]
    bl     do_invalidate
    ldr    r2, [fp, #address-dynarec_local]
    add    r12, fp, #memory_map-dynarec_local
    ldr    lr, [fp, #28]
    lsr    r0, r2, #12
    ldr    r3, [fp, #24]
    ldr    r12, [r12, r0, lsl #2]
    mov    r1, #0xc
    tst    r12, #0x40000000
    bne    tlb_exception
    eor    r2, r2, #3
    ldrb   r0, [fp, #cpu_byte-dynarec_local]
    strb   r0, [r2, r12, lsl #2]
    mov    pc, lr

GLOBAL_FUNCTION(write_nomemh_new):
    str    r3, [fp, #24]
    str    lr, [fp, #28]
    bl     do_invalidate
    ldr    r2, [fp, #address-dynarec_local]
    add    r12, fp, #memory_map-dynarec_local
    ldr    lr, [fp, #28]
    lsr    r0, r2, #12
    ldr    r3, [fp, #24]
    ldr    r12, [r12, r0, lsl #2]
    mov    r1, #0xc
    lsls   r12, #2
    bcs    tlb_exception
    eor    r2, r2, #2
    ldrh   r0, [fp, #cpu_hword-dynarec_local]
    strh   r0, [r2, r12]
    mov    pc, lr

GLOBAL_FUNCTION(write_nomemd_new):
    str    r3, [fp, #24]
    str    lr, [fp, #28]
    bl     do_invalidate
    ldr    r2, [fp, #address-dynarec_local]
    add    r12, fp, #memory_map-dynarec_local
    ldr    lr, [fp, #28]
    lsr    r0, r2, #12
    ldr    r3, [fp, #24]
    ldr    r12, [r12, r0, lsl #2]
    mov    r1, #0xc
    lsls   r12, #2
    bcs    tlb_exception
    add    r3, r2, #4
    ldr    r0, [fp, #cpu_dword+4-dynarec_local]
    ldr    r1, [fp, #cpu_dword-dynarec_local]
/*    strd    r0, [r2, r12]*/
    str    r0, [r2, r12]
    str    r1, [r3, r12]
    mov    pc, lr

LOCAL_FUNCTION(tlb_exception):
    /* r1 = cause */
    /* r2 = address */
    /* r3 = instr addr/flags */
    ldr    r4, [fp, #g_cp0_regs+48-dynarec_local] /* Status */
    add    r5, fp, #memory_map-dynarec_local
    lsr    r6, r3, #12
    orr    r1, r1, r3, lsl #31
    orr    r4, r4, #2
    ldr    r7, [r5, r6, lsl #2]
    bic    r8, r3, #3
    str    r4, [fp, #g_cp0_regs+48-dynarec_local] /* Status */
    mov    r6, #0x6000000
    str    r1, [fp, #g_cp0_regs+52-dynarec_local] /* Cause */
    orr    r6, r6, #0x22
    ldr    r0, [r8, r7, lsl #2]
    add    r4, r8, r1, asr #29
    add    r5, fp, #reg-dynarec_local
    str    r4, [fp, #g_cp0_regs+56-dynarec_local] /* EPC */
    mov    r7, #0xf8
    ldr    r8, [fp, #g_cp0_regs+16-dynarec_local] /* Context */
    lsl    r1, r0, #16
    lsr    r4, r0,    #26
    and    r7, r7, r0, lsr #18
    mvn    r9, #0xF000000F
    sub    r2, r2, r1, asr #16
    bic    r9, r9, #0x0F800000
    rors   r6, r6, r4
    mov    r0, #0x80000000
    ldrcs  r2, [r5, r7]
    bic    r8, r8, r9
    tst    r3, #2
    str    r2, [r5, r7]
    add    r4, r2, r1, asr #16
    add    r6, fp, #reg+4-dynarec_local
    asr    r3, r2, #31
    str    r4, [fp, #g_cp0_regs+32-dynarec_local] /* BadVAddr */
    add    r0, r0, #0x180
    and    r4, r9, r4, lsr #9
    strne  r3, [r6, r7]
    orr    r8, r8, r4
    str    r8, [fp, #g_cp0_regs+16-dynarec_local] /* Context */
    bl     get_addr_ht
    ldr    r1, [fp, #next_interupt-dynarec_local]
    ldr    r10, [fp, #g_cp0_regs+36-dynarec_local] /* Count */
    str    r1, [fp, #last_count-dynarec_local]
    sub    r10, r10, r1
    mov    pc, r0    

GLOBAL_FUNCTION(breakpoint):
    /* Set breakpoint here for debugging */
    mov    pc, lr

GLOBAL_FUNCTION(__clear_cache_bugfix):
    /*  The following bug-fix implements __clear_cache (missing in Android)  */
    push   {r7, lr}
    mov    r2, #0
    mov    r7, #0x2
    add    r7, r7, #0xf0000
    svc    0x00000000
    pop    {r7, pc}

END_SECTION
