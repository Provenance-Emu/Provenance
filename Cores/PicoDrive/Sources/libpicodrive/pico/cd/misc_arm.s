@*
@* Memory converters for different modes
@* (C) notaz, 2007-2008
@*
@* This work is licensed under the terms of MAME license.
@* See COPYING file in the top-level directory.
@*


@ r10 is tmp, io1 is lsb halfword, io2 is msb
@ | 0 1 | 2 3 |  ->  | 0 2 | 1 3 |  (little endian)
.macro _conv_reg io1 io2
    mov     r10,  \io2, lsl #16
    and     \io2, \io2, r11,  lsl #16
    orr     \io2, \io2, \io1, lsr #16
    and     \io1, \io1, r11
    orr     \io1, \io1, r10
/*
    mov     \io2, \io2, ror #16
    mov     r10,  \io1, lsl #16
    orr     r10,  r10,  \io2, lsr #16
    mov     \io1, \io1, lsr #16
    orr     \io1, \io1, \io2, lsl #16
    mov     \io2, r10,  ror #16
*/
.endm


.global wram_2M_to_1M
wram_2M_to_1M:
    stmfd   sp!,{r4-r11,lr}
    add     r1, r0, #0x60000    @ m1M_b1
    add     r0, r0, #0x40000    @ m1M_b0
    mov     r2, r0              @ m2M

    mov     r11, #0xff
    orr     r11, r11, r11, lsl #8
    mov     r12, #(0x40000/8/4)

_2Mto1M_loop:
    ldmdb   r2!,{r3-r9,lr}
    _conv_reg r3,r4
    _conv_reg r5,r6
    _conv_reg r7,r8
    _conv_reg r9,lr
    subs    r12, r12, #1
    stmdb   r0!,{r3,r5,r7,r9}
    stmdb   r1!,{r4,r6,r8,lr}
    bne     _2Mto1M_loop

    ldmfd   sp!,{r4-r11,pc}



.global wram_1M_to_2M
wram_1M_to_2M:
    stmfd   sp!,{r4-r11,lr}
    mov     r2, r0              @ m2M
    add     r1, r0, #0x40000    @ m1M_b1
    add     r0, r0, #0x20000    @ m1M_b0

    mov     r11, #0xff
    orr     r11, r11, r11, lsl #8
    mov     r12, #(0x40000/8/4)

_1Mto2M_loop:
    ldmia   r0!,{r3,r5,r7,r9}
    ldmia   r1!,{r4,r6,r8,lr}
    _conv_reg r3,r4
    _conv_reg r5,r6
    _conv_reg r7,r8
    _conv_reg r9,lr
    subs    r12, r12, #1
    stmia   r2!,{r3-r9,lr}
    bne     _1Mto2M_loop

    ldmfd   sp!,{r4-r11,pc}

@ vim:filetype=armasm
