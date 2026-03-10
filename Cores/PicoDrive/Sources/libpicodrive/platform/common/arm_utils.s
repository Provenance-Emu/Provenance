/*
 * some color conversion and blitting routines
 * (C) notaz, 2006-2009
 * (C) irixxxx, 2020-2023
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

.text
.align 4

@ Convert 0000bbbb ggggrrrr 0000bbbb ggggrrrr
@ to      00000000 rrrr0000 gggg0000 bbbb0000 ...

@ lr =  0x00f000f0, out: r3=lower_pix, r2=higher_pix; trashes rin
.macro convRGB32_2 rin sh=0
    and     r2,  lr, \rin, lsr #4 @ blue
    and     r3,  \rin, lr
    orr     r2,  r2,   r3, lsl #8         @ g0b0g0b0

    mov     r3,  r2,  lsl #16             @ g0b00000
    and     \rin,lr,  \rin, ror #12       @ 00r000r0 (reversed)
    orr     r3,  r3,  \rin, lsr #16       @ g0b000r0
.if \sh == 1
    mov     r3,  r3,  ror #17             @ shadow mode
.elseif \sh == 2
    adds    r3,  r3,  #0x40000000         @ green
    orrcs   r3,  r3,  lr, lsl #24
    mov     r3,  r3,  ror #8
    adds    r3,  r3,  #0x40000000
    orrcs   r3,  r3,  lr, lsl #24
    mov     r3,  r3,  ror #16
    adds    r3,  r3,  #0x40000000
    orrcs   r3,  r3,  lr, lsl #24
    mov     r3,  r3,  ror #24
.else
    mov     r3,  r3,  ror #16             @ r3=low
.endif

    orr     r3,  r3,   r3, lsr #3
    str     r3, [r0], #4

    mov     r2,  r2,  lsr #16
    orr     r2,  r2,  \rin, lsl #16
.if \sh == 1
    mov     r2,  r2,  lsr #1
.elseif \sh == 2
    mov     r2,  r2,  ror #8
    adds    r2,  r2,  #0x40000000         @ blue
    orrcs   r2,  r2,  lr, lsl #24
    mov     r2,  r2,  ror #8
    adds    r2,  r2,  #0x40000000
    orrcs   r2,  r2,  lr, lsl #24
    mov     r2,  r2,  ror #8
    adds    r2,  r2,  #0x40000000
    orrcs   r2,  r2,  lr, lsl #24
    mov     r2,  r2,  ror #8
.endif

    orr     r2,  r2,   r2,  lsr #3
    str     r2, [r0], #4
.endm


.global bgr444_to_rgb32 @ void *to, void *from, unsigned entries

bgr444_to_rgb32:
    stmfd   sp!, {r4-r7,lr}

    mov     r12, r2, lsr #3 @ repeats
    mov     lr, #0x00f00000
    orr     lr, lr, #0x00f0

.loopRGB32:
    ldmia    r1!, {r4-r7}
    convRGB32_2 r4
    convRGB32_2 r5
    convRGB32_2 r6
    convRGB32_2 r7

    subs    r12, r12, #1
    bgt     .loopRGB32

    ldmfd   sp!, {r4-r7,pc}


.global bgr444_to_rgb32_sh @ void *to, void *from

bgr444_to_rgb32_sh:
    stmfd   sp!, {r4-r7,lr}

    mov     r12, #0x40>>3 @ repeats
    add     r0, r0, #0x40*4
    mov     lr, #0x00f00000
    orr     lr, lr, #0x00f0

.loopRGB32sh:
    ldmia    r1!, {r4-r7}
    convRGB32_2 r4, 2
    convRGB32_2 r5, 2
    convRGB32_2 r6, 2
    convRGB32_2 r7, 2

    subs    r12, r12, #1
    bgt     .loopRGB32sh

    mov     r12, #0x40>>3 @ repeats
    sub     r1, r1, #0x40*2
    and     lr, lr, lr, lsl #1  @ kill LSB for correct shadow colors

.loopRGB32hi:
    ldmia    r1!, {r4-r7}
    convRGB32_2 r4, 1
    convRGB32_2 r5, 1
    convRGB32_2 r6, 1
    convRGB32_2 r7, 1

    subs    r12, r12, #1
    bgt     .loopRGB32hi

    ldmfd   sp!, {r4-r7,lr}
    bx      lr


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

.global vidcpy_8bit @ void *dest, void *src, int x_y, int w_h
vidcpy_8bit:
    stmfd   sp!, {r4-r6,lr}

    mov     r12, r2, lsl #16    @ y

    mov     r4, r12, lsr #16-8  @ 320*y = 256*y+64*y
    add     r4, r4, r12, lsr #16-6
    add     r0, r0, r4          @ pd += 320*y + x
    add     r0, r0, r2, lsr #16

    add     r4, r4, r12, lsr #16-3 @ 328*y = 320*y + 8*y
    add     r1, r1, r4          @ ps += 328*y + x + 8
    add     r1, r1, r2, lsr #16
    add     r1, r1, #8

    mov     lr, r3, lsr #16     @ w
    mov     r12, r3, lsl #16    @ h

vidCpy8bit_loop_out:
    movs    r6, lr, lsr #5
@   beq     vidCpy8bit_loop_end
vidCpy8bit_loop:
    subs    r6, r6, #1
    ldmia   r1!, {r2-r5}
    stmia   r0!, {r2-r5}
    ldmia   r1!, {r2-r5}
    stmia   r0!, {r2-r5}
    bne     vidCpy8bit_loop

    ands    r6, lr, #0x0018
    beq     vidCpy8bit_loop_end
vidCpy8bit_loop2:
    ldmia   r1!, {r2-r3}
    subs    r6, r6, #8
    stmia   r0!, {r2-r3}
    bne     vidCpy8bit_loop2

vidCpy8bit_loop_end:
    subs    r12,r12,#1<<16
    add     r0, r0, #320
    sub     r0, r0, lr
    add     r1, r1, #328
    sub     r1, r1, lr
    bne     vidCpy8bit_loop_out

    ldmfd   sp!, {r4-r6,pc}


.global vidcpy_8bit_rot @ void *dest, void *src, int x_y, int w_h
vidcpy_8bit_rot:
    stmfd   sp!, {r4-r10,lr}

    mov     r12, r2, lsl #16    @ y

    add     r0, r0, r12, lsr #16 @ pd += y + (319-x)*240
    mov     r4, #320
    sub     r4, r4, #1
    sub     r4, r4, r2, lsr #16 @    (319-x)
    add     r0, r0, r4, lsl #8
    sub     r0, r0, r4, lsl #4

    mov     r4, r12, lsr #16-8  @ 328*y = 256*y + 64*y + 8*y
    add     r4, r4, r12, lsr #16-6
    add     r4, r4, r12, lsr #16-3
    add     r1, r1, r4          @ ps += 328*y + x + 8
    add     r1, r1, r2, lsr #16
    add     r1, r1, #8

    mov     lr, r3, lsr #16     @ w
    mov     r12, r3, lsl #16    @ h

    mov     r8, #328
vidCpy8bitrot_loop_out:
    mov     r10, r0
    movs    r9, lr, lsr #2
@   beq     vidCpy8bitrot_loop_end
vidCpy8bitrot_loop:
    mov     r6, r1
    ldr     r2, [r6], r8
    ldr     r3, [r6], r8
    ldr     r4, [r6], r8
    ldr     r5, [r6], r8

    mov     r6, r2, lsl #24
    mov     r6, r6, lsr #8
    orr     r6, r6, r3, lsl #24
    mov     r6, r6, lsr #8
    orr     r6, r6, r4, lsl #24
    mov     r6, r6, lsr #8
    orr     r6, r6, r5, lsl #24
    str     r6, [r0], #-240

    and     r6, r3, #0xff00
    and     r7, r2, #0xff00
    orr     r6, r6, r7, lsr #8
    and     r7, r4, #0xff00
    orr     r6, r6, r7, lsl #8
    and     r7, r5, #0xff00
    orr     r6, r6, r7, lsl #16
    str     r6, [r0], #-240

    and     r6, r4, #0xff0000
    and     r7, r2, #0xff0000
    orr     r6, r6, r7, lsr #16
    and     r7, r3, #0xff0000
    orr     r6, r6, r7, lsr #8
    and     r7, r5, #0xff0000
    orr     r6, r6, r7, lsl #8
    str     r6, [r0], #-240

    mov     r6, r5, lsr #24
    mov     r6, r6, lsl #8
    orr     r6, r6, r4, lsr #24
    mov     r6, r6, lsl #8
    orr     r6, r6, r3, lsr #24
    mov     r6, r6, lsl #8
    orr     r6, r6, r2, lsr #24
    str     r6, [r0], #-240

    subs    r9, r9, #1
    add     r1, r1, #4
    bne     vidCpy8bitrot_loop

vidCpy8bitrot_loop_end:
    subs    r12,r12,#4<<16
    add     r0, r10, #4
    sub     r1, r1, lr
    add     r1, r1, #4*328
    bne     vidCpy8bitrot_loop_out

    ldmfd   sp!, {r4-r10,pc}


.global rotated_blit8 @ void *dst, void *linesx4, u32 y, int is_32col
rotated_blit8:
    stmfd   sp!,{r4-r8,lr}
    mov     r8, #320

rotated_blit8_2:
    add     r0, r0, #(240*320)
    sub     r0, r0, #(240+4)	@ y starts from 4
    add     r0, r0, r2

    tst     r3, r3
    subne   r0, r0, #(240*32)
    addne   r1, r1, #32
    movne   lr, #256/4
    moveq   lr, #320/4

rotated_blit_loop8:
    mov     r6, r1
    ldr     r2, [r6], r8
    ldr     r3, [r6], r8
    ldr     r4, [r6], r8
    ldr     r5, [r6], r8

    mov     r6, r2, lsl #24
    mov     r6, r6, lsr #8
    orr     r6, r6, r3, lsl #24
    mov     r6, r6, lsr #8
    orr     r6, r6, r4, lsl #24
    mov     r6, r6, lsr #8
    orr     r6, r6, r5, lsl #24
    str     r6, [r0], #-240

    and     r6, r3, #0xff00
    and     r7, r2, #0xff00
    orr     r6, r6, r7, lsr #8
    and     r7, r4, #0xff00
    orr     r6, r6, r7, lsl #8
    and     r7, r5, #0xff00
    orr     r6, r6, r7, lsl #16
    str     r6, [r0], #-240

    and     r6, r4, #0xff0000
    and     r7, r2, #0xff0000
    orr     r6, r6, r7, lsr #16
    and     r7, r3, #0xff0000
    orr     r6, r6, r7, lsr #8
    and     r7, r5, #0xff0000
    orr     r6, r6, r7, lsl #8
    str     r6, [r0], #-240

    mov     r6, r5, lsr #24
    mov     r6, r6, lsl #8
    orr     r6, r6, r4, lsr #24
    mov     r6, r6, lsl #8
    orr     r6, r6, r3, lsr #24
    mov     r6, r6, lsl #8
    orr     r6, r6, r2, lsr #24
    str     r6, [r0], #-240

    subs    lr, lr, #1
    add     r1, r1, #4
    bne     rotated_blit_loop8

    ldmfd   sp!,{r4-r8,pc}


@ input: r2-r5
@ output: r7,r8
@ trash: r6
.macro rb_line_low
    mov     r6, r2, lsl #16
    mov     r7, r3, lsl #16
    orr     r7, r7, r6, lsr #16
    mov     r6, r4, lsl #16
    mov     r8, r5, lsl #16
    orr     r8, r8, r6, lsr #16
.endm

.macro rb_line_hi
    mov     r6, r2, lsr #16
    mov     r7, r3, lsr #16
    orr     r7, r6, r7, lsl #16
    mov     r6, r4, lsr #16
    mov     r8, r5, lsr #16
    orr     r8, r6, r8, lsl #16
.endm

.global rotated_blit16 @ void *dst, void *linesx4, u32 y, int is_32col
rotated_blit16:
    stmfd   sp!,{r4-r8,lr}

    add     r0, r0, #(240*320)*2
    sub     r0, r0, #(240+4)*2	@ y starts from 4
    add     r0, r0, r2, lsl #1

    tst     r3, r3
    subne   r0, r0, #(240*32)*2
    addne   r1, r1, #32*2
    movne   lr, #256/4
    moveq   lr, #320/4

rotated_blit_loop16:
    ldr     r2, [r1, #320*0*2]
    ldr     r3, [r1, #320*1*2]
    ldr     r4, [r1, #320*2*2]
    ldr     r5, [r1, #320*3*2]
    rb_line_low
    stmia   r0, {r7,r8}
    sub     r0, r0, #240*2
    rb_line_hi
    stmia   r0, {r7,r8}
    sub     r0, r0, #240*2

    ldr     r2, [r1, #320*0*2+4]
    ldr     r3, [r1, #320*1*2+4]
    ldr     r4, [r1, #320*2*2+4]
    ldr     r5, [r1, #320*3*2+4]
    rb_line_low
    stmia   r0, {r7,r8}
    sub     r0, r0, #240*2
    rb_line_hi
    stmia   r0, {r7,r8}
    sub     r0, r0, #240*2

    subs    lr, lr, #1
    add     r1, r1, #8
    bne     rotated_blit_loop16

    ldmfd   sp!,{r4-r8,pc}


.global spend_cycles @ c

spend_cycles:
    mov     r0, r0, lsr #2  @ 4 cycles/iteration
    sub     r0, r0, #2      @ entry/exit/init
.sc_loop:
    subs    r0, r0, #1
    bpl     .sc_loop

    bx      lr

@ vim:filetype=armasm
