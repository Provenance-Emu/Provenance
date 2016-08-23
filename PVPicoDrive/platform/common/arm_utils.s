/*
 * some color conversion and blitting routines
 * (C) notaz, 2006-2009
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

.text
.align 4

@ Convert 0000bbb0 ggg0rrr0 0000bbb0 ggg0rrr0
@ to      00000000 rrr00000 ggg00000 bbb00000 ...

@ lr =  0x00e000e0, out: r3=lower_pix, r2=higher_pix; trashes rin
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
    orrcs   r3,  r3,  #0xe0000000
    mov     r3,  r3,  ror #8
    adds    r3,  r3,  #0x40000000
    orrcs   r3,  r3,  #0xe0000000
    mov     r3,  r3,  ror #16
    adds    r3,  r3,  #0x40000000
    orrcs   r3,  r3,  #0xe0000000
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
    orrcs   r2,  r2,  #0xe0000000
    mov     r2,  r2,  ror #8
    adds    r2,  r2,  #0x40000000
    orrcs   r2,  r2,  #0xe0000000
    mov     r2,  r2,  ror #8
    adds    r2,  r2,  #0x40000000
    orrcs   r2,  r2,  #0xe0000000
    mov     r2,  r2,  ror #8
.endif

    orr     r2,  r2,   r2,  lsr #3
.if \sh == 1
    str     r2, [r0, #0x40*2*4]
.endif
    str     r2, [r0], #4
.endm


.global bgr444_to_rgb32 @ void *to, void *from

bgr444_to_rgb32:
    stmfd   sp!, {r4-r7,lr}

    mov     r12, #0x40>>3 @ repeats
    mov     lr, #0x00e00000
    orr     lr, lr, #0x00e0

.loopRGB32:
    subs    r12, r12, #1

    ldmia    r1!, {r4-r7}
    convRGB32_2 r4
    convRGB32_2 r5
    convRGB32_2 r6
    convRGB32_2 r7
    bgt     .loopRGB32

    ldmfd   sp!, {r4-r7,pc}


.global bgr444_to_rgb32_sh @ void *to, void *from

bgr444_to_rgb32_sh:
    stmfd   sp!, {r4-r7,lr}

    mov     r12, #0x40>>3 @ repeats
    add     r0, r0, #0x40*4
    mov     lr, #0x00e00000
    orr     lr, lr, #0x00e0

.loopRGB32sh:
    subs    r12, r12, #1

    ldmia    r1!, {r4-r7}
    convRGB32_2 r4, 1
    convRGB32_2 r5, 1
    convRGB32_2 r6, 1
    convRGB32_2 r7, 1
    bgt     .loopRGB32sh

    mov     r12, #0x40>>3 @ repeats
    sub     r1, r1, #0x40*2

.loopRGB32hi:
     ldmia    r1!, {r4-r7}
    convRGB32_2 r4, 2
    convRGB32_2 r5, 2
    convRGB32_2 r6, 2
    convRGB32_2 r7, 2

    subs    r12, r12, #1
    bgt     .loopRGB32hi

    ldmfd   sp!, {r4-r7,lr}
    bx      lr


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


@ mode2 blitter
.global vidcpy_m2 @ void *dest, void *src, int m32col, int with_32c_border
vidcpy_m2:
    stmfd   sp!, {r4-r6,lr}

    mov     r12, #224       @ lines
    add     r0, r0, #320*8
    add     r1, r1, #8
    mov     lr, #0

    tst     r2, r2
    movne   lr, #64
    tstne   r3, r3
    addne   r0, r0, #32

vidCpyM2_loop_out:
    mov     r6, #10
    sub     r6, r6, lr, lsr #5	@ -= 2 in 32col mode
vidCpyM2_loop:
    subs    r6, r6, #1
    ldmia   r1!, {r2-r5}
    stmia   r0!, {r2-r5}
    ldmia   r1!, {r2-r5}
    stmia   r0!, {r2-r5}
    bne     vidCpyM2_loop

    subs    r12,r12,#1
    add     r0, r0, lr
    add     r1, r1, #8
    add     r1, r1, lr
    bne     vidCpyM2_loop_out

    ldmfd   sp!, {r4-r6,pc}


.global vidcpy_m2_rot @ void *dest, void *src, int m32col, int with_32c_border
vidcpy_m2_rot:
    stmfd   sp!,{r4-r8,lr}
    add     r1, r1, #8
    tst     r2, r2
    subne   r1, r1, #32		@ adjust

    mov     r4, r0
    mov     r5, r1
    mov     r6, r2
    mov     r7, #8+4

vidcpy_m2_rot_loop:
    @ a bit lame but oh well..
    mov     r0, r4
    mov     r1, r5
    mov     r2, r7
    mov     r3, r6
    mov     r8, #328
    adr     lr, after_rot_blit8
    stmfd   sp!,{r4-r8,lr}
    b       rotated_blit8_2

after_rot_blit8:
    add     r5, r5, #328*4
    add     r7, r7, #4
    cmp     r7, #224+8+4
    ldmgefd sp!,{r4-r8,pc}
    b       vidcpy_m2_rot_loop


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
