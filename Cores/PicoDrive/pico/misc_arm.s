/*
 * Generic memory routines.
 * (C) notaz, 2007-2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

.global memcpy16 @ unsigned short *dest, unsigned short *src, int count

memcpy16:
    eor     r3, r0, r1
    tst     r3, #2
    bne     mcp16_cant_align

    tst     r0, #2
    ldrneh  r3, [r1], #2
    subne   r2, r2, #1
    strneh  r3, [r0], #2

    subs    r2, r2, #4
    bmi     mcp16_fin

mcp16_loop:
    ldmia   r1!, {r3,r12}
    subs    r2, r2, #4
    stmia   r0!, {r3,r12}
    bpl     mcp16_loop

mcp16_fin:
    tst     r2, #2
    ldrne   r3, [r1], #4
    strne   r3, [r0], #4
    ands    r2, r2, #1
    bxeq    lr

mcp16_cant_align:
    ldrh    r3, [r1], #2
    subs    r2, r2, #1
    strh    r3, [r0], #2
    bne     mcp16_cant_align

    bx      lr



@ 0x12345678 -> 0x34127856
@ r4=temp, lr=0x00ff00ff
.macro bswap reg
    and     r4,   \reg, lr
    and     \reg, lr,   \reg, lsr #8
    orr     \reg, \reg, r4,   lsl #8
.endm


@ dest must be halfword aligned, src can be unaligned
.global memcpy16bswap @ unsigned short *dest, void *src, int count

memcpy16bswap:
    tst     r1, #1
    bne     mcp16bs_cant_align2

    eor     r3, r0, r1
    tst     r3, #2
    bne     mcp16bs_cant_align

    tst     r0, #2
    beq     mcp16bs_aligned
    ldrh    r3, [r1], #2
    sub     r2, r2, #1
    orr     r3, r3, r3, lsl #16
    mov     r3, r3, lsr #8
    strh    r3, [r0], #2

mcp16bs_aligned:
    stmfd   sp!, {r4,lr}
    mov     lr, #0xff
    orr     lr, lr, lr, lsl #16

    subs    r2, r2, #4
    bmi     mcp16bs_fin4

mcp16bs_loop:
    ldmia   r1!, {r3,r12}
    subs    r2, r2, #4
    bswap   r3
    bswap   r12
    stmia   r0!, {r3,r12}
    bpl     mcp16bs_loop

mcp16bs_fin4:
    tst     r2, #2
    beq     mcp16bs_fin2
    ldr     r3, [r1], #4
    bswap   r3
    str     r3, [r0], #4

mcp16bs_fin2:
    ldmfd   sp!, {r4,lr}
    ands    r2, r2, #1
    bxeq    lr

mcp16bs_cant_align:
    ldrh    r3, [r1], #2
    subs    r2, r2, #1
    orr     r3, r3, r3, lsl #16
    mov     r3, r3, lsr #8
    strh    r3, [r0], #2
    bne     mcp16bs_cant_align
    bx      lr

    @ worst case
mcp16bs_cant_align2:
    ldrb    r3, [r1], #1
    ldrb    r12,[r1], #1
    subs    r2, r2, #1
    mov     r3, r3, lsl #8
    orr     r3, r3, r12
    strh    r3, [r0], #2
    bne     mcp16bs_cant_align2
    bx      lr



.global memcpy32 @ int *dest, int *src, int count

memcpy32:
    stmfd   sp!, {r4,lr}

    subs    r2, r2, #4
    bmi     mcp32_fin

mcp32_loop:
    ldmia   r1!, {r3,r4,r12,lr}
    subs    r2, r2, #4
    stmia   r0!, {r3,r4,r12,lr}
    bpl     mcp32_loop

mcp32_fin:
    tst     r2, #3
    ldmeqfd sp!, {r4,pc}
    tst     r2, #1
    ldrne   r3, [r1], #4
    strne   r3, [r0], #4

mcp32_no_unal1:
    tst     r2, #2
    ldmneia r1!, {r3,r12}
    ldmfd   sp!, {r4,lr}
    stmneia r0!, {r3,r12}
    bx      lr



.global memset32 @ int *dest, int c, int count

memset32:
    stmfd   sp!, {lr}

    mov     r3, r1
    subs    r2, r2, #4
    bmi     mst32_fin

    mov     r12,r1
    mov     lr, r1

mst32_loop:
    subs    r2, r2, #4
    stmia   r0!, {r1,r3,r12,lr}
    bpl     mst32_loop

mst32_fin:
    tst     r2, #1
    strne   r1, [r0], #4

    tst     r2, #2
    stmneia r0!, {r1,r3}

    ldmfd   sp!, {lr}
    bx      lr

@ vim:filetype=armasm
