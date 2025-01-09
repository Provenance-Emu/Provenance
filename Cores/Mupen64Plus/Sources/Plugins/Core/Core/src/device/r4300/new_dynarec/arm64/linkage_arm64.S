/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - linkage_arm64.S                                         *
 *   Copyright (C) 2009-2018 Gillou68310                                   *
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
    .globl name;               \
    .hidden name;              \
    .type name, %function;     \
    name

#define LOCAL_FUNCTION(name)  \
    .hidden name;             \
    .type name, %function;    \
    name

#define GLOBAL_VARIABLE(name, size_) \
    .global name;                    \
    .hidden name;                    \
    .type   name, %object;           \
    .size   name, size_

.macro movl Wn, imm
    movz    \Wn, (\imm >> 16) & 0xFFFF, lsl 16
    movk    \Wn,  \imm & 0xFFFF
.endm

#define TEXT_SECTION .text
#define END_SECTION

#include "asm_defines_gas.h"

device_r4300_new_dynarec_hot_state_dynarec_local = (offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_dynarec_local)
saved_context = 160

/* Defines offsets for fp addressed variables */
fp_cycle_count         = offsetof_struct_new_dynarec_hot_state_cycle_count
fp_pending_exception   = offsetof_struct_new_dynarec_hot_state_pending_exception
fp_pcaddr              = offsetof_struct_new_dynarec_hot_state_pcaddr
fp_stop                = offsetof_struct_new_dynarec_hot_state_stop

TEXT_SECTION

GLOBAL_FUNCTION(jump_vaddr_x0):
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x1):
    mov    w0, w1
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x2):
    mov    w0, w2
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x3):
    mov    w0, w3
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x4):
    mov    w0, w4
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x5):
    mov    w0, w5
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x6):
    mov    w0, w6
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x8):
    mov    w0, w8
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x9):
    mov    w0, w9
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x10):
    mov    w0, w10
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x11):
    mov    w0, w11
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x12):
    mov    w0, w12
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x13):
    mov    w0, w13
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x14):
    mov    w0, w14
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x15):
    mov    w0, w15
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x16):
    mov    w0, w16
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x17):
    mov    w0, w17
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x19):
    mov    w0, w19
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x21):
    mov    w0, w21
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x22):
    mov    w0, w22
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x23):
    mov    w0, w23
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x24):
    mov    w0, w24
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x25):
    mov    w0, w25
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x26):
    mov    w0, w26
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x27):
    mov    w0, w27
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x28):
    mov    w0, w28
    b      jump_vaddr

GLOBAL_FUNCTION(jump_vaddr_x7):
    mov    w0, w7

GLOBAL_FUNCTION(jump_vaddr):
    bl     get_addr_ht
    br     x0

GLOBAL_FUNCTION(verify_code):
    /* x0 = head */
    mov    x21, x30 /* Save link register */
    bl     verify_dirty
    tst    x0, x0
    b.ne   .D1
    mov    x30, x21 /* Restore link register */
    ret
.D1:
    bl     get_addr
    br     x0

GLOBAL_FUNCTION(cc_interrupt):
    str    w20, [x29, #fp_cycle_count]
    str    wzr, [x29, #fp_pending_exception]
    mov    x20, x30 /* Save link register */
    bl     dynarec_gen_interrupt
    mov    x30, x20 /* Restore link register */
    ldr    w20, [x29, #fp_cycle_count]
    ldr    w1, [x29, #fp_pending_exception]
    ldr    w2, [x29, #fp_stop]
    tst    w2, w2
    b.ne   new_dyna_stop
    tst    w1, w1
    b.ne   .E1
    ret
.E1:
    ldr    w0, [x29, #fp_pcaddr]
    bl     get_addr_ht
    br     x0

LOCAL_FUNCTION(new_dyna_stop):
    add    x16, x29, #saved_context
    ldp    x19,x20,[x16,#0]
    ldp    x21,x22,[x16,#16]
    ldp    x23,x24,[x16,#32]
    ldp    x25,x26,[x16,#48]
    ldp    x27,x28,[x16,#64]
    ldp    x29,x30,[x16,#80]
    ret

GLOBAL_FUNCTION(do_interrupt):
    ldr    w2, [x29, #fp_stop]
    tst    w2, w2
    b.ne   new_dyna_stop
    ldr    w0, [x29, #fp_pcaddr]
    bl     get_addr_ht
    ldr    w20, [x29, #fp_cycle_count]
    br     x0

GLOBAL_FUNCTION(fp_exception):
    str    w0, [x29, #fp_pcaddr]
    bl     cop1_unusable
    br     x0

GLOBAL_FUNCTION(jump_syscall):
    str    w0, [x29, #fp_pcaddr]
    bl     SYSCALL_new
    br     x0

GLOBAL_FUNCTION(jump_eret):
    str    w20, [x29, #fp_cycle_count]
    bl     ERET_new
    ldr    w20, [x29, #fp_cycle_count]
    tst    w0, w0
    b.eq   new_dyna_stop
    br     x0

GLOBAL_FUNCTION(dyna_linker):
    bl     dynamic_linker
    br     x0

GLOBAL_FUNCTION(dyna_linker_ds):
    bl     dynamic_linker_ds
    br     x0

GLOBAL_FUNCTION(new_dyna_start):
    adrp   x16, g_dev
    add    x16, x16, :lo12:g_dev
    movl   x1, (device_r4300_new_dynarec_hot_state_dynarec_local + saved_context)
    add    x16, x16, x1
    adrp   x1, base_addr_rx
    add    x1, x1, :lo12:base_addr_rx
    mov    w0, #0xa4000000
    stp    x19,x20,[x16,#0]
    stp    x21,x22,[x16,#16]
    stp    x23,x24,[x16,#32]
    stp    x25,x26,[x16,#48]
    stp    x27,x28,[x16,#64]
    stp    x29,x30,[x16,#80]
    sub    x29, x16, #saved_context
    ldr    x19, [x1]
    add    w0, w0, #0x40
    bl     new_recompile_block
    ldr    w20, [x29, #fp_cycle_count]
    br     x19

GLOBAL_FUNCTION(breakpoint):
    brk 0
    ret

END_SECTION
