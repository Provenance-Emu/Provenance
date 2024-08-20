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

#define TEXT_SECTION .text
#define END_SECTION

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

#include "asm_defines_gas.h"

device_r4300_new_dynarec_hot_state_dynarec_local = (offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_dynarec_local)

/* Defines offsets for fp addressed variables */
fp_saved_context       = offsetof_struct_new_dynarec_hot_state_dynarec_local + 28
fp_next_interrupt      = offsetof_struct_new_dynarec_hot_state_next_interrupt
fp_cycle_count         = offsetof_struct_new_dynarec_hot_state_cycle_count
fp_last_count          = offsetof_struct_new_dynarec_hot_state_last_count
fp_pending_exception   = offsetof_struct_new_dynarec_hot_state_pending_exception
fp_pcaddr              = offsetof_struct_new_dynarec_hot_state_pcaddr
fp_stop                = offsetof_struct_new_dynarec_hot_state_stop
fp_invc_ptr            = offsetof_struct_new_dynarec_hot_state_invc_ptr
fp_fcr0                = offsetof_struct_new_dynarec_hot_state_fcr0
fp_fcr31               = offsetof_struct_new_dynarec_hot_state_fcr31
fp_regs                = offsetof_struct_new_dynarec_hot_state_regs
fp_hi                  = offsetof_struct_new_dynarec_hot_state_hi
fp_lo                  = offsetof_struct_new_dynarec_hot_state_lo
fp_cp0_regs            = offsetof_struct_new_dynarec_hot_state_cp0_regs
fp_cp1_regs_simple     = offsetof_struct_new_dynarec_hot_state_cp1_regs_simple
fp_cp1_regs_double     = offsetof_struct_new_dynarec_hot_state_cp1_regs_double
fp_rounding_modes      = offsetof_struct_new_dynarec_hot_state_rounding_modes
fp_branch_target       = offsetof_struct_new_dynarec_hot_state_branch_target
fp_pc                  = offsetof_struct_new_dynarec_hot_state_pc
fp_fake_pc             = offsetof_struct_new_dynarec_hot_state_fake_pc
fp_mini_ht             = offsetof_struct_new_dynarec_hot_state_mini_ht
fp_restore_candidate   = offsetof_struct_new_dynarec_hot_state_restore_candidate
fp_memory_map          = offsetof_struct_new_dynarec_hot_state_memory_map

TEXT_SECTION

    .align   2
    .outptr_offset  : .word out-(.outptr_pic+8)
    .savedcontextptr_offset  : .word g_dev + device_r4300_new_dynarec_hot_state_dynarec_local + fp_saved_context -(.savedcontextptr_pic+8)

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
    str    r10, [fp, #fp_cycle_count]
    ldr    r9,  [fp, #fp_last_count]
    add    r10, r9, r10 /* Count */
    str    r10, [fp, #fp_cp0_regs + 36] /* Count */
    bl     get_addr_ht
    ldr    r10, [fp, #fp_cycle_count]
    mov    pc, r0

GLOBAL_FUNCTION(verify_code_ds):
    str    r8, [fp, #fp_branch_target]

GLOBAL_FUNCTION(verify_code_vm):
    /* r0 = instruction pointer (virtual address) */
    /* r1 = source (virtual address) */
    /* r2 = target */
    /* r3 = length */
    cmp    r1, #0xC0000000
    blt    verify_code
#ifdef ARMv5_ONLY
    ldr    r12, =fp_memory_map
#else
    movw   r12, #:lower16:fp_memory_map
    movt   r12, #:upper16:fp_memory_map
#endif
    add    r12, fp, r12
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
    ldr    r8, [fp, #fp_branch_target]
    moveq  pc, lr
.D5:
    bl     get_addr
    mov    pc, r0

GLOBAL_FUNCTION(cc_interrupt):
    ldr    r0, [fp, #fp_last_count]
    mov    r1, #0
    mov    r2, #0x1fc
    add    r10, r0, r10
    str    r1, [fp, #fp_pending_exception]
    and    r2, r2, r10, lsr #19
#ifdef ARMv5_ONLY
    ldr    r3, =fp_restore_candidate
#else
    movw   r3, #:lower16:fp_restore_candidate
    movt   r3, #:upper16:fp_restore_candidate
#endif
    add    r3, fp, r3
    str    r10, [fp, #fp_cp0_regs+36] /* Count */
    ldr    r4, [r2, r3]
    mov    r10, lr
    tst    r4, r4
    bne    .E4
.E1:
    bl     dynarec_gen_interrupt
    mov    lr, r10
    ldr    r10, [fp, #fp_cp0_regs+36] /* Count */
    ldr    r0, [fp, #fp_next_interrupt]
    ldr    r1, [fp, #fp_pending_exception]
    ldr    r2, [fp, #fp_stop]
    str    r0, [fp, #fp_last_count]
    sub    r10, r10, r0
    tst    r2, r2
    bne    .E3
    tst    r1, r1
    moveq  pc, lr
.E2:
    ldr    r0, [fp, #fp_pcaddr]
    bl     get_addr_ht
    mov    pc, r0
.E3:
    add    r12, fp, #fp_saved_context
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
    ldr    r0, [fp, #fp_pcaddr]
    bl     get_addr_ht
    ldr    r1, [fp, #fp_next_interrupt]
    ldr    r10, [fp, #fp_cp0_regs+36] /* Count */
    str    r1, [fp, #fp_last_count]
    sub    r10, r10, r1
    mov    pc, r0

GLOBAL_FUNCTION(fp_exception):
    mov    r2, #0x10000000
.E7:
    ldr    r1, [fp, #fp_cp0_regs+48] /* Status */
    mov    r3, #0x80000000
    str    r0, [fp, #fp_cp0_regs+56] /* EPC */
    orr    r1, #2
    add    r2, r2, #0x2c
    str    r1, [fp, #fp_cp0_regs+48] /* Status */
    str    r2, [fp, #fp_cp0_regs+52] /* Cause */
    add    r0, r3, #0x180
    bl     get_addr_ht
    mov    pc, r0

GLOBAL_FUNCTION(fp_exception_ds):
    mov    r2, #0x90000000 /* Set high bit if delay slot */
    b      .E7

GLOBAL_FUNCTION(jump_syscall):
    ldr    r1, [fp, #fp_cp0_regs+48] /* Status */
    mov    r3, #0x80000000
    str    r0, [fp, #fp_cp0_regs+56] /* EPC */
    orr    r1, #2
    mov    r2, #0x20
    str    r1, [fp, #fp_cp0_regs+48] /* Status */
    str    r2, [fp, #fp_cp0_regs+52] /* Cause */
    add    r0, r3, #0x180
    bl     get_addr_ht
    mov    pc, r0

GLOBAL_FUNCTION(jump_eret):
    ldr    r1, [fp, #fp_cp0_regs+48] /* Status */
    ldr    r0, [fp, #fp_last_count]
    bic    r1, r1, #2
    add    r10, r0, r10
    str    r1, [fp, #fp_cp0_regs+48] /* Status */
    str    r10, [fp, #fp_cp0_regs+36] /* Count */
    bl     new_dynarec_check_interrupt
    ldr    r1, [fp, #fp_next_interrupt]
    ldr    r0, [fp, #fp_cp0_regs+56] /* EPC */
    str    r1, [fp, #fp_last_count]
    subs   r10, r10, r1
    bpl    .E11
.E8:
    add    r6, fp, #fp_regs+256
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
    ldr    r2, [fp, #fp_hi]
    ldr    r3, [fp, #fp_hi+4]
    eors   r3, r3, r2, asr #31
    ldr    r2, [fp, #fp_lo]
    ldreq  r3, [fp, #fp_lo+4]
    eoreq  r3, r3, r2, asr #31
    subs   r3, r3, #1
    adc    r1, r1, r1
    bl     get_addr_32
    mov    pc, r0
.E11:
    str    r0, [fp, #fp_pcaddr]
    bl     cc_interrupt
    ldr    r0, [fp, #fp_pcaddr]
    b      .E8

GLOBAL_FUNCTION(new_dyna_start):
    ldr    r12, .savedcontextptr_offset
.savedcontextptr_pic:
    add    r12, pc, r12
    ldr    r1, .outptr_offset
.outptr_pic:
    add    r1, pc, r1
    mov    r0, #0xa4000000
    stmia  r12, {r4, r5, r6, r7, r8, r9, sl, fp, lr}
    sub    fp, r12, #fp_saved_context
    ldr    r4, [r1]
    add    r0, r0, #0x40
    bl     new_recompile_block
    ldr    r0, [fp, #fp_next_interrupt]
    ldr    r10, [fp, #fp_cp0_regs+36] /* Count */
    str    r0, [fp, #fp_last_count]
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
