/*
 * Generic routines for mixing audio samples
 * (C) notaz, 2007,2008
 * (C) irixxxx, 2019,2020		added filtering
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

.text
.align 4

@ this assumes src is word aligned
.global mix_16h_to_32 @ int *dest, short *src, int count

mix_16h_to_32:
    stmfd   sp!, {r4-r6,lr}
/*
    tst     r1, #2
    beq     m16_32_mo_unalw
    ldrsh   r4, [r1], #2
    ldr     r3, [r0]
    sub     r2, r2, #1
    add     r3, r3, r4, asr #1
    str     r3, [r0], #4
*/
m16_32_mo_unalw:
    subs    r2, r2, #4
    bmi     m16_32_end

m16_32_loop:
    ldmia   r0, {r3-r6}
    ldmia   r1!,{r12,lr}
    subs    r2, r2, #4
    add     r4, r4, r12,asr #17 @ we use 5/8 volume
    add     r4, r4, r12,asr #19
    mov     r12,r12,lsl #16
    add     r3, r3, r12,asr #17
    add     r3, r3, r12,asr #19
    add     r6, r6, lr, asr #17
    add     r6, r6, lr, asr #19
    mov     lr, lr, lsl #16
    add     r5, r5, lr, asr #17
    add     r5, r5, lr, asr #19
    stmia   r0!,{r3-r6}
    bpl     m16_32_loop

m16_32_end:
    tst     r2, #2
    beq     m16_32_no_unal2
    ldr     r5, [r1], #4
    ldmia   r0, {r3,r4}
    mov     r12,r5, lsl #16
    add     r3, r3, r12,asr #17
    add     r3, r3, r12,asr #19
    add     r4, r4, r5, asr #17
    add     r4, r4, r5, asr #19
    stmia   r0!,{r3,r4}

m16_32_no_unal2:
    tst     r2, #1
    ldmeqfd sp!, {r4-r6,pc}
    ldrsh   r4, [r1], #2
    ldr     r3, [r0]
    add     r3, r3, r4, asr #1
    add     r3, r3, r4, asr #3
    str     r3, [r0], #4

    ldmfd   sp!, {r4-r6,lr}
    bx      lr



.global mix_16h_to_32_s1 @ int *dest, short *src, int count

mix_16h_to_32_s1:
    stmfd   sp!, {r4-r6,lr}

    subs    r2, r2, #4
    bmi     m16_32_s1_end

m16_32_s1_loop:
    ldmia   r0, {r3-r6}
    ldr     r12,[r1], #8
    ldr     lr, [r1], #8
    subs    r2, r2, #4
    add     r4, r4, r12,asr #17 @ we use 5/8 volume
    add     r4, r4, r12,asr #19
    mov     r12,r12,lsl #16
    add     r3, r3, r12,asr #17
    add     r3, r3, r12,asr #19
    add     r6, r6, lr, asr #17
    add     r6, r6, lr, asr #19
    mov     lr, lr, lsl #16
    add     r5, r5, lr, asr #17
    add     r5, r5, lr, asr #19
    stmia   r0!,{r3-r6}
    bpl     m16_32_s1_loop

m16_32_s1_end:
    tst     r2, #2
    beq     m16_32_s1_no_unal2
    ldr     r5, [r1], #8
    ldmia   r0, {r3,r4}
    mov     r12,r5, lsl #16
    add     r3, r3, r12,asr #17
    add     r3, r3, r12,asr #19
    add     r4, r4, r5, asr #17
    add     r4, r4, r5, asr #19
    stmia   r0!,{r3,r4}

m16_32_s1_no_unal2:
    tst     r2, #1
    ldmeqfd sp!, {r4-r6,pc}
    ldrsh   r4, [r1], #2
    ldr     r3, [r0]
    add     r3, r3, r4, asr #1
    add     r3, r3, r4, asr #3
    str     r3, [r0], #4

    ldmfd   sp!, {r4-r6,lr}
    bx      lr



.global mix_16h_to_32_s2 @ int *dest, short *src, int count

mix_16h_to_32_s2:
    stmfd   sp!, {r4-r6,lr}

    subs    r2, r2, #4
    bmi     m16_32_s2_end

m16_32_s2_loop:
    ldmia   r0, {r3-r6}
    ldr     r12,[r1], #16
    ldr     lr, [r1], #16
    subs    r2, r2, #4
    add     r4, r4, r12,asr #17 @ we use 5/8 volume
    add     r4, r4, r12,asr #19
    mov     r12,r12,lsl #16
    add     r3, r3, r12,asr #17
    add     r3, r3, r12,asr #19
    add     r6, r6, lr, asr #17
    add     r6, r6, lr, asr #19
    mov     lr, lr, lsl #16
    add     r5, r5, lr, asr #17
    add     r5, r5, lr, asr #19
    stmia   r0!,{r3-r6}
    bpl     m16_32_s2_loop

m16_32_s2_end:
    tst     r2, #2
    beq     m16_32_s2_no_unal2
    ldr     r5, [r1], #16
    ldmia   r0, {r3,r4}
    mov     r12,r5, lsl #16
    add     r3, r3, r12,asr #17
    add     r3, r3, r12,asr #19
    add     r4, r4, r5, asr #17
    add     r4, r4, r5, asr #19
    stmia   r0!,{r3,r4}

m16_32_s2_no_unal2:
    tst     r2, #1
    ldmeqfd sp!, {r4-r6,pc}
    ldrsh   r4, [r1], #2
    ldr     r3, [r0]
    add     r3, r3, r4, asr #1
    add     r3, r3, r4, asr #3
    str     r3, [r0], #4

    ldmfd   sp!, {r4-r6,lr}
    bx      lr



.global mix_16h_to_32_resample_stereo @ int *dest, short *src, int count, int fac16

mix_16h_to_32_resample_stereo:
    stmfd   sp!, {r4-r9,lr}

    subs    r2, r2, #2
    mov     r4, #0
    bmi     m16_32_rss_end

m16_32_rss_loop:
    ldmia   r0, {r5-r8}
    mov     r9, r4, lsr #16
    ldr     r12,[r1, r9, lsl #2]
    add     r4, r4, r3
    mov     r9, r4, lsr #16
    ldr     lr ,[r1, r9, lsl #2]
    add     r4, r4, r3
    subs    r2, r2, #2
    add     r6, r6, r12,asr #17 @ we use 5/8 volume
    add     r6, r6, r12,asr #19
    mov     r12,r12,lsl #16
    add     r5, r5, r12,asr #17
    add     r5, r5, r12,asr #19
    add     r8, r8, lr, asr #17
    add     r8, r8, lr, asr #19
    mov     lr, lr, lsl #16
    add     r7, r7, lr, asr #17
    add     r7, r7, lr, asr #19
    stmia   r0!,{r5-r8}
    bpl     m16_32_rss_loop

m16_32_rss_end:
    tst     r2, #1
    ldmeqfd sp!, {r4-r9,pc}
    mov     r9, r4, lsr #16
    ldr     lr ,[r1, r9, lsl #2]
    ldmia   r0, {r5,r6}
    mov     r12,lr, lsl #16
    add     r5, r5, r12,asr #17
    add     r5, r5, r12,asr #19
    add     r6, r6, lr, asr #17
    add     r6, r6, lr, asr #19
    stmia   r0!,{r5,r6}

    ldmfd   sp!, {r4-r9,lr}
    bx      lr



.global mix_16h_to_32_resample_mono @ int *dest, short *src, int count, int fac16

mix_16h_to_32_resample_mono:
    stmfd   sp!, {r4-r6,r9,lr}

    subs    r2, r2, #2
    mov     r4, #0
    bmi     m16_32_rsm_end

m16_32_rsm_loop:
    ldmia   r0, {r5-r6}
    mov     r9, r4, lsr #16
    ldr     r12,[r1, r9, lsl #2]
    add     r4, r4, r3
    mov     r9, r4, lsr #16
    ldr     lr ,[r1, r9, lsl #2]
    add     r4, r4, r3
    subs    r2, r2, #2
    add     r5, r5, r12,asr #18 @ we use 5/8 volume (= 5/16 vol per channel)
    add     r5, r5, r12,asr #20
    mov     r12,r12,lsl #16
    add     r5, r5, r12,asr #18
    add     r5, r5, r12,asr #20
    add     r6, r6, lr, asr #18
    add     r6, r6, lr, asr #20
    mov     lr, lr, lsl #16
    add     r6, r6, lr, asr #18
    add     r6, r6, lr, asr #20
    stmia   r0!,{r5-r6}
    bpl     m16_32_rsm_loop

m16_32_rsm_end:
    tst     r2, #1
    ldmeqfd sp!, {r4-r6,r9,pc}
    mov     r9, r4, lsr #16
    ldr     lr ,[r1, r9, lsl #2]
    ldr     r5, [r0]
    mov     r12,lr, lsl #16
    add     r5, r5, r12,asr #18
    add     r5, r5, r12,asr #20
    add     r5, r5, lr, asr #18
    add     r5, r5, lr, asr #20
    str     r5, [r0]

    ldmfd   sp!, {r4-r6,r9,lr}
    bx      lr



@ limit
@ reg=int_sample, r12=1, r8=tmp, kills flags
.macro Limit reg
    sub     \reg, \reg, \reg, asr #3	@ reduce audio lvl some to avoid clipping
    add     r8, r12, \reg, asr #15
    bics    r8, r8, #1			@ in non-overflow conditions r8 is 0 or 1
    movne   \reg, #0x8000
    subpl   \reg, \reg, #1
.endm

@ limit and shift up by 16
@ reg=int_sample, r12=1, r8=tmp, kills flags
.macro Limitsh reg
    sub     \reg, \reg, \reg, asr #3	@ reduce audio lvl some to avoid clipping
    add     r8, r12,\reg, asr #15
    bics    r8, r8, #1			@ in non-overflow conditions r8 is 0 or 1
    moveq   \reg, \reg, lsl #16
    movne   \reg, #0x80000000
    subpl   \reg, \reg, #0x00010000
.endm


@ filter out DC offset
@ in=int_sample (max 20 bit), y=filter memory, r8=tmp
.macro DCfilt in y
    rsb     r8, \y, \in, lsl #12	@ fixpoint 20.12
    add     \y, \y, r8, asr #12		@ alpha = 1-1/4094
    sub     \in, \in, \y, asr #12
.endm

@ lowpass filter
@ in=int_sample (max 20 bit), y=filter memory, r12=alpha(Q8), r8=tmp
.macro LPfilt in y
@    mov     r8, \y, asr #8
@    rsb     r8, r8, \in, lsl #4		@ fixpoint 20.12
    sub     r8, \in, \y, asr #12		@ fixpoint 20.12
    mla     \y, r8, r12, \y
    mov     \in, \y, asr #12
.endm


@ mix 32bit audio (with 16bits really used, upper bits indicate overflow) with normal 16 bit audio with left channel only
@ warning: this function assumes dest is word aligned
.global mix_32_to_16_stereo @ short *dest, int *src, int count

mix_32_to_16_stereo:
    stmfd   sp!, {r4-r8,r10-r11,lr}

    mov     r2, r2, lsl #1
    subs    r2, r2, #4
    bmi     m32_16_st_end

    ldr     r12, =filter
    ldr     r8, [r12], #4
    ldmia   r12, {r3,r10-r11,lr}
    str     r8, [sp, #-4]!

m32_16_st_loop:
    ldmia   r0,  {r8,r12}
    ldmia   r1!, {r4-r7}
    add     r5, r5, r8, asr #16
    add     r7, r7, r12,asr #16
    mov     r8, r8, lsl #16
    mov     r12,r12,lsl #16
    add     r4, r4, r8, asr #16
    add     r6, r6, r12,asr #16
    ldr     r12,[sp]
    LPfilt  r4, r3
    LPfilt  r5, lr
    LPfilt  r6, r3
    LPfilt  r7, lr
    DCfilt  r4, r10
    DCfilt  r5, r11
    DCfilt  r6, r10
    DCfilt  r7, r11
    mov     r12,#1
    Limitsh r4
    Limitsh r5
    Limitsh r6
    Limitsh r7
    subs    r2, r2, #4
    orr     r4, r5, r4, lsr #16
    orr     r5, r7, r6, lsr #16
    stmia   r0!, {r4,r5}
    bpl     m32_16_st_loop

m32_16_st_end:
    @ check for remaining bytes to convert
    tst     r2, #2
    beq     m32_16_st_no_unal2
    ldr     r6, [r0]
    ldmia   r1!,{r4,r5}
    add     r5, r5, r6, asr #16
    mov     r6, r6, lsl #16
    add     r4, r4, r6, asr #16
    ldr     r12,[sp]
    LPfilt  r4, r3
    LPfilt  r5, lr
    DCfilt  r4, r10
    DCfilt  r5, r11
    mov     r12,#1
    Limitsh r4
    Limitsh r5
    orr     r4, r5, r4, lsr #16
    str     r4, [r0], #4

m32_16_st_no_unal2:
    ldr     r12, =filter
    add     r12,r12, #4
    stmia   r12, {r3,r10-r11,lr}
    add     sp, sp, #4
    ldmfd   sp!, {r4-r8,r10-r11,lr}
    bx      lr


@ mix 32bit audio (with 16bits really used, upper bits indicate overflow) with normal 16 bit audio (for mono sound)
.global mix_32_to_16_mono @ short *dest, int *src, int count

mix_32_to_16_mono:
    stmfd   sp!, {r4-r8,r10-r11,lr}

    ldr     r12, =filter
    ldr     r8, [r12], #4
    ldmia   r12, {r10-r11}
    str     r8, [sp, #-4]!

    @ check if dest is word aligned
    tst     r0, #2
    beq     m32_16_mo_no_unalw
    ldrsh   r5, [r0]
    ldr     r4, [r1], #4
    sub     r2, r2, #1
    add     r4, r4, r5
    ldr     r12,[sp]
    LPfilt  r4, r11
    DCfilt  r4, r10
    mov     r12,#1
    Limit   r4
    strh    r4, [r0], #2

m32_16_mo_no_unalw:
    subs    r2, r2, #4
    bmi     m32_16_mo_end

m32_16_mo_loop:
    ldmia   r0,  {r8,r12}
    ldmia   r1!, {r4-r7}
    add     r5, r5, r8, asr #16
    add     r7, r7, r12,asr #16
    mov     r8, r8, lsl #16
    mov     r12,r12,lsl #16
    add     r4, r4, r8, asr #16
    add     r6, r6, r12,asr #16
    ldr     r12,[sp]
    LPfilt  r4, r11
    LPfilt  r5, r11
    LPfilt  r6, r11
    LPfilt  r7, r11
    DCfilt  r4, r10
    DCfilt  r5, r10
    DCfilt  r6, r10
    DCfilt  r7, r10
    mov     r12,#1
    Limitsh r4
    Limitsh r5
    Limitsh r6
    Limitsh r7
    subs    r2, r2, #4
    orr     r4, r5, r4, lsr #16
    orr     r5, r7, r6, lsr #16
    stmia   r0!, {r4,r5}
    bpl     m32_16_mo_loop

m32_16_mo_end:
    @ check for remaining bytes to convert
    tst     r2, #2
    beq     m32_16_mo_no_unal2
    ldr     r6, [r0]
    ldmia   r1!,{r4,r5}
    add     r5, r5, r6, asr #16
    mov     r6, r6, lsl #16
    add     r4, r4, r6, asr #16
    ldr     r12,[sp]
    LPfilt  r4, r11
    LPfilt  r5, r11
    DCfilt  r4, r10
    DCfilt  r5, r10
    mov     r12,#1
    Limitsh r4
    Limitsh r5
    orr     r4, r5, r4, lsr #16
    str     r4, [r0], #4

m32_16_mo_no_unal2:
    tst     r2, #1
    beq     m32_16_mo_no_unal
    ldrsh   r5, [r0]
    ldr     r4, [r1], #4
    add     r4, r4, r5
    ldr     r12,[sp]
    LPfilt  r4, r11
    DCfilt  r4, r10
    mov     r12,#1
    Limit   r4
    strh    r4, [r0], #2

m32_16_mo_no_unal:
    ldr     r12, =filter
    add     r12,r12, #4
    stmia   r12, {r10-r11}
    add     sp, sp, #4
    ldmfd   sp!, {r4-r8,r10-r11,lr}
    bx      lr


#ifdef __GP2X__

.data
.align 4

.global mix_32_to_16_level
mix_32_to_16_level:
    .word   0

.text
.align 4

@ same as mix_32_to_16_stereo, but with additional shift
.global mix_32_to_16_stereo_lvl @ short *dest, int *src, int count

mix_32_to_16_stereo_lvl:
    stmfd   sp!, {r4-r11,lr}

    ldr     r9, =mix_32_to_16_level
    mov     lr, #1
    ldr     r9, [r9]
    ldr     r12, =filter
    ldr     r8, [r12], #4
    ldmia   r12, {r3,r10-r11,lr}
    str     r8, [sp, #-4]!

    mov     r2, r2, lsl #1
    subs    r2, r2, #4
    bmi     m32_16_st_l_end

m32_16_st_l_loop:
    ldmia   r0,  {r8,r12}
    ldmia   r1!, {r4-r7}
    add     r5, r5, r8, asr #16
    add     r7, r7, r12,asr #16
    mov     r8, r8, lsl #16
    mov     r12,r12,lsl #16
    add     r4, r4, r8, asr #16
    add     r6, r6, r12,asr #16
    mov     r4, r4, asr r9
    mov     r5, r5, asr r9
    mov     r6, r6, asr r9
    mov     r7, r7, asr r9
    ldr     r12,[sp]
    LPfilt  r4, r3
    LPfilt  r5, lr
    LPfilt  r6, r3
    LPfilt  r7, lr
    DCfilt  r4, r10
    DCfilt  r5, r11
    DCfilt  r6, r10
    DCfilt  r7, r11
    mov     r12,#1
    Limitsh r4
    Limitsh r5
    Limitsh r6
    Limitsh r7
    subs    r2, r2, #4
    orr     r4, r5, r4, lsr #16
    orr     r5, r7, r6, lsr #16
    stmia   r0!, {r4,r5}
    bpl     m32_16_st_l_loop

m32_16_st_l_end:
    @ check for remaining bytes to convert
    tst     r2, #2
    beq     m32_16_st_l_no_unal2
    ldr     r6, [r0]
    ldmia   r1!,{r4,r5}
    add     r5, r5, r6, asr #16
    mov     r6, r6, lsl #16
    add     r4, r4, r6, asr #16
    mov     r4, r4, asr r9
    mov     r5, r5, asr r9
    ldr     r12,[sp]
    LPfilt  r4, r3
    LPfilt  r5, lr
    DCfilt  r4, r10
    DCfilt  r5, r11
    mov     r12,#1
    Limitsh r4
    Limitsh r5
    orr     r4, r5, r4, lsr #16
    str     r4, [r0], #4

m32_16_st_l_no_unal2:
    ldr     r12, =filter
    add     r12,r12, #4
    stmia   r12, {r3,r10-r11,lr}
    add     sp, sp, #4
    ldmfd   sp!, {r4-r11,lr}
    bx      lr

#endif /* __GP2X__ */

.global mix_reset @ int alpha_q16
mix_reset:
    ldr     r2, =filter
    rsb     r0, r0, #0x10000
@    mov     r0, r0, asr #8
    mov     r0, r0, asr #4
    str     r0, [r2], #4
    mov     r1, #0
    str     r1, [r2], #4
    str     r1, [r2], #4
    str     r1, [r2], #4
    str     r1, [r2], #4
    bx      lr

.data
filter:
    .ds     4				@ alpha_q8
    .ds     8				@ filter history for left channel
    .ds     8				@ filter history for right channel

@ vim:filetype=armasm
