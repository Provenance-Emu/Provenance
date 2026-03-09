@*
@* PicoDrive
@* (C) notaz, 2010
@* (C) irixxxx, 2019-2023
@*
@* This work is licensed under the terms of MAME license.
@* See COPYING file in the top-level directory.
@*

#include <pico/arm_features.h>
#include <pico/pico_int_offs.h>

.extern Pico32x
.extern Pico

.equiv P32XV_PRI,  (1<< 7)

.text
.align 2

    PIC_LDR_INIT()

.macro call_scan_prep cond pico   @ &Pico
.if \cond
    PIC_LDR(r4, r6, PicoScan32xBegin)
    PIC_LDR(r5, r6, PicoScan32xEnd)
    add     r6, \pico, #OFS_Pico_est
    ldr     r4, [r4]
    ldr     r5, [r5]
    stmfd   sp!, {r4,r5,r6}
.endif
.endm

.macro call_scan_fin_ge cond
.if \cond
    addge   sp, sp, #4*3
.endif
.endm

.macro call_scan_begin cond
.if \cond
    stmfd   sp!, {r1-r3}
    and     r0, r2, #0xff
    add     r0, r0, r4
    mov     lr, pc
    ldr     pc, [sp, #(3+0)*4]
    ldr     r0, [sp, #(3+2)*4] @ &Pico.est
    ldmfd   sp!, {r1-r3}
    ldr     r0, [r0, #OFS_EST_DrawLineDest]
.endif
.endm

.macro call_scan_end cond
.if \cond
    stmfd   sp!, {r0-r3}
    and     r0, r2, #0xff
    add     r0, r0, r4
    mov     lr, pc
    ldr     pc, [sp, #(4+1)*4]
    ldr     r1, [sp, #(4+2)*4] @ &Pico.est
    ldr     r0, [r1, #OFS_EST_DrawLineDest]
    ldr     r2, [r1, #OFS_EST_DrawLineDestIncr]
    add     r0, r0, r2
    str     r0, [r1, #OFS_EST_DrawLineDest]
    ldmfd   sp!, {r0-r3}
.endif
.endm

@ direct color
@ unsigned short *dst, unsigned short *dram, int lines_sft_offs, int mdbg
.macro make_do_loop_dc name call_scan do_md
.global \name
\name:
    stmfd   sp!, {r4-r11,lr}

    PIC_LDR(lr, r9, Pico)
    PIC_LDR(r10,r9, Pico32x)
    ldr     r11, [lr, #OFS_Pico_est+OFS_EST_Draw2FB]
    ldrh    r10,[r10, #0x40] @ Pico32x.vdp_regs[0]
    add     r9, lr, #OFS_Pico_est+OFS_EST_HighPal   @ palmd

    and     r4, r2, #0xff
    mov     r5, #328
    mov     r3, r3, lsl #26  @ mdbg << 26
    mla     r11,r4,r5,r11    @ r11 = pmd = PicoDraw2FB + offs*328: md data
    tst     r10,#P32XV_PRI
    movne   r10,#0
    moveq   r10,#0x8000      @ r10 = !inv_bit
    call_scan_prep \call_scan lr

    mov     r4, #0           @ line
    b       1f @ loop_outer_entry

0: @ loop_outer:
    call_scan_end \call_scan
    ldr     r12, [r9, #OFS_EST_DrawLineDestIncr-OFS_EST_HighPal]
    sub     r0, r0, #320*2
    add     r0, r0, r12
    add     r4, r4, #1
    and     r12, r2, #0xff0000
    cmp     r4, r12, lsr #16
    call_scan_fin_ge \call_scan
    ldmgefd sp!, {r4-r11,pc}

1: @ loop_outer_entry:
    call_scan_begin \call_scan
    add     r12,r4, r2, lsr #24
    mov     r12,r12,lsl #1
    ldrh    r12,[r1, r12]
    add     r11,r11,#8
    mov     r6, #320/2
    add     r5, r1, r12, lsl #1 @ p32x = dram + dram[l]

2: @ loop_inner:
@ r4,r6 - counters; r5 - 32x data; r9 - md pal; r10 - inv_prio; r11 - md data
@ r7,r8,r12,lr - temp
    ldrh    r7, [r5], #2
    ldrh    r8, [r5], #2
    subs    r6, r6, #1
    blt     0b @ loop_outer
    cmp     r7, r8
    beq     5f @ check_fill

3: @ no_fill:
    ldrb    r12,[r11], #1    @ MD pixel 0

    eor     r7, r7, r10
    and     lr, r7, #0x03e0  @ convert BGR555 -> RGB565
    mov     r7, r7, ror #5
    orr     r7, r7, r7, ror #10+11
    orr     r7, r7, lr, lsl #1+16
    eor     r8, r8, r10
    and     lr, r8, #0x03e0
    mov     r8, r8, ror #5
    orr     r8, r8, r8, ror #10+11
    orr     r8, r8, lr, lsl #1+16

    ldrb    lr, [r11], #1    @ MD pixel 1

.if \do_md
    cmp     r3, r12, lsl #26
    tstne   r7, #0x20<<16
    movne   r12,r12, lsl #1  @ load MD color if no 32X prio and not bg
    ldrneh  r12,[r9, r12]
    moveq   r12,r7, lsr #16  @ else replace with 32X color

    cmp     r3, lr,  lsl #26
    tstne   r8, #0x20<<16
    movne   lr, lr,  lsl #1  @ load MD color if no 32X prio and not bg
    ldrneh  lr, [r9, lr]
    moveq   lr, r8, lsr #16  @ else replace with 32X color

    orr     r12,r12, lr, lsl #16 @ combine 2 pixels to optimize memory bandwidth
    str     r12,[r0], #4     @ (no write combining on ARM9)
.else
    cmp     r3, r12, lsl #26 @ replace MD bg info into prio bit
    tstne   r7, #0x20<<16
    moveq   r7, r7, lsr #16
    streqh  r7, [r0, #0]

    cmp     r3, lr,  lsl #26
    tstne   r8, #0x20<<16
    moveq   r8, r8, lsr #16
    streqh  r8, [r0, #2]

    add     r0, r0, #4       @ store 32x pixels if 32X prio or MD bg
.endif
    b       2b @ loop_inner

5: @ check_fill:
    @ count pixels, align if needed
    ldrh    r12,[r5, #0]     @ only do this for at least 4 pixels
    ldrh    lr ,[r5, #2]
    cmp     r12,r7
    cmpeq   lr ,r7
    bne     3b @ no_fill
    add     r5, r5, #4       @ adjust for the check above

    sub     lr, r5, #4+4     @ starting r5 (32x render data start)
    add     r6, r6, #1       @ restore from dec
6: @ count_loop:
    sub     r12,r5, lr       @ loop checks 2 pixels
    ldrh    r8, [r5], #2
    cmp     r12,r6, lsl #2
    ldrh    r12,[r5], #2
    bge     7f @ count_done
    cmp     r8, r7
    cmpeq   r12,r7
    beq     6b

7: @ count_done:
    sub     r5, r5, #4       @ undo readahead

    sub     r8, r5, lr       @ pixel count
    mov     r8, r8, lsr #1

    cmp     r8, r6, lsl #1   @ limit count to line length
    movgt   r8, r6, lsl #1
    sub     r6, r6, r8, lsr #1 @ consume pixels

    eor     r7, r7, r10
    and     r12,r7, #0x03e0  @ convert BGR555 -> RGB565
    mov     r7, r7, ror #5
    orr     r7, r7, r7, ror #10+11
    orr     r7, r7, r12,lsl #1+16
    mov     r7, r7, lsr #16

    tst     r7, #0x20        @ check for prio transfer
    bne     9f @ bg_loop

    add     r11,r11,r8       @ consume md pixels (not used)
    orr     r12,r7, r7, lsl #16
    mov     r7 ,r12
8: @ 32x_loop:
    subs    r8, r8, #4       @ store 4 pixels
    stmgeia r0!, {r7, r12}
    bgt     8b @ 32x_loop
    beq     2b @ loop_inner
    adds    r8, r8, #2
    strge   r7, [r0], #4     @ store 2 leftover pixels
    b       2b @ loop_inner

9: @ bg_loop:
    ldrb    r12,[r11],#1     @ MD pixel 0,1
    ldrb    lr, [r11],#1
.if \do_md
    cmp     r3, r12,lsl #26  @ MD pixel 0 has bg?
    mov     r12,r12,lsl #1
    ldrneh  r12,[r9, r12]    @ t = palmd[*pmd]
    moveq   r12,r7
    cmp     r3, lr, lsl #26  @ MD pixel 1 has bg?
    mov     lr, lr, lsl #1
    ldrneh  lr, [r9, lr]
    moveq   lr, r7
    orr     r12,r12,lr, lsl #16 @ combine 2 pixels to optimize memory bandwidth
    str     r12,[r0], #4     @ (no write combining on ARM9)
.else
    add     r0, r0, #4
    cmp     r3, r12,lsl #26  @ MD pixel 0 has bg?
    streqh  r7, [r0, #-4]
    cmp     r3, lr, lsl #26  @ MD pixel 1 has bg?
    streqh  r7, [r0, #-2]
.endif
    subs    r8, r8, #2
    bgt     9b @ bg_loop
    b       2b @ loop_inner
.endm


@ packed pixel
@ note: this may read a few bytes over the end of PicoDraw2FB and dram,
@       so those should have a bit more alloc'ed than really needed.
@ unsigned short *dst, unsigned short *dram, int lines_sft_offs, int mdbg
.macro make_do_loop_pp name call_scan do_md
.global \name
\name:
    stmfd   sp!, {r4-r11,lr}

    PIC_LDR(lr, r9, Pico)
    PIC_LDR(r10,r9, Pico32xMem)
    ldr     r9, =OFS_PMEM32x_pal_native
    ldr     r10, [r10]
    ldr     r11, [lr, #OFS_Pico_est+OFS_EST_Draw2FB]
    add     r10,r10,r9
    add     r9, lr, #OFS_Pico_est+OFS_EST_HighPal   @ palmd

    and     r4, r2, #0xff
    mov     r5, #328
    mov     r3, r3, lsl #26  @ mdbg << 26
    mla     r11,r4,r5,r11    @ r11 = pmd = PicoDraw2FB + offs*328: md data
    call_scan_prep \call_scan lr

    mov     r4, #0           @ line
    b       1f @ loop_outer_entry

0: @ loop_outer:
    call_scan_end \call_scan
    ldr     r12, [r9, #OFS_EST_DrawLineDestIncr-OFS_EST_HighPal]
    sub     r0, r0, #320*2
    add     r0, r0, r12
    add     r4, r4, #1
    and     r12, r2, #0xff0000
    cmp     r4, r12, lsr #16
    call_scan_fin_ge \call_scan
    ldmgefd sp!, {r4-r11,pc}

1: @ loop_outer_entry:
    call_scan_begin \call_scan
    add     r12,r4, r2, lsr #24
    mov     r12,r12,lsl #1
    ldrh    r12,[r1, r12]
    add     r11,r11,#8
    mov     r6, #320/2
    add     r5, r1, r12, lsl #1 @ p32x = dram + dram[l]
    and     r12,r2, #0x100      @ shift
    add     r5, r5, r12,lsr #8

2: @ loop_inner:
@ r4,r6 - counters; r5 - 32x data; r9,r10 - md,32x pal; r11 - md data
@ r7,r8,r12,lr - temp
    tst     r5, #1
    ldreqb  r8, [r5], #2
    ldrb    r7, [r5, #-1]
    ldrneb  r8, [r5, #2]!    @ r7,r8 - 32X pixel 0,1
    subs    r6, r6, #1
    blt     0b @ loop_outer
    cmp     r7, r8
    beq     5f @ check_fill

3: @ no_fill:
    ldrb    r12,[r11], #1    @ MD pixel 0
    ldrb    lr, [r11], #1    @ MD pixel 1

    mov     r7, r7, lsl #1
    mov     r8, r8, lsl #1
    ldrh    r7, [r10,r7]     @ 32X color 0
    ldrh    r8, [r10,r8]     @ 32X color 1

.if \do_md
    cmp     r3, r12, lsl #26
    movne   r12,r12, lsl #1  @ load MD color if not bg
    ldrneh  r12,[r9, r12]
    orreq   r7, r7, #0x20    @ accumulate MD bg info into prio bit
    cmp     r3, lr,  lsl #26
    movne   lr, lr,  lsl #1
    ldrneh  lr, [r9, lr]
    orreq   r8, r8, #0x20

    tst     r7, #0x20        @ replace 32X with MD color if no prio and not bg
    moveq   r7, r12
    tst     r8, #0x20
    moveq   r8, lr
    orr     r7, r7, r8, lsl #16 @ combine 2 pixels to optimize memory bandwidth
    str     r7, [r0], #4     @ (no write combining on ARM9)
.else
    cmp     r3, r12, lsl #26 @ replace MD bg info into prio bit
    orreq   r7, r7, #0x20
    cmp     r3, lr,  lsl #26
    orreq   r8, r8, #0x20

    add     r0, r0, #4       @ store 32x pixels if 32X prio or MD bg
    tst     r7, #0x20
    strneh  r7, [r0, #-4]
    tst     r8, #0x20
    strneh  r8, [r0, #-2]
.endif
    b       2b @ loop_inner

5: @ check_fill:
    @ count pixels, align if needed
    bic     r12,r5, #1
    ldrh    r12,[r12, #0]    @ only do this for at least 4 pixels
    orr     lr, r7, r7, lsl #8
    cmp     r12,lr
    bne     3b @ no_fill
    add     r5, r5, #2       @ adjust for the check above

    sub     lr, r5, #4       @ starting r5 (32x render data start)
    bic     r5, r5, #1
    add     r6, r6, #1       @ restore from dec
    orr     r7, r7, r7, lsl #8
6: @ count_loop:
    sub     r12,r5, lr       @ loop checks 4 pixels
    ldrh    r8, [r5], #2
    cmp     r12,r6, lsl #1
    ldrh    r12,[r5], #2
    bge     7f @ count_done
    cmp     r8, r7
    cmpeq   r12,r7
    beq     6b
    cmp     r8, r7
    addeq   r5, r5, #2       @ adjust if 2 pixels where ok

7: @ count_done:
    sub     r5, r5, #4       @ undo readahead

    tst     lr, #1           @ fix alignment and calculate count
    subne   r5, r5, #1
    sub     r8, r5, lr

    and     r7, r7, #0xff    @ 32x pixel color
    mov     r7, r7, lsl #1
    ldrh    r7, [r10,r7]

    cmp     r8, r6, lsl #1   @ limit count to line length
    movgt   r8, r6, lsl #1
    sub     r6, r6, r8, lsr #1 @ consume pixels

    tst     r7, #0x20        @ check for prio transfer
    beq     9f @ bg_loop

    add     r11,r11,r8       @ consume md pixels (not used)
    orr     r12,r7, r7, lsl #16
    mov     r7 ,r12
8: @ 32x_loop:
    subs    r8, r8, #4       @ store 4 pixels
    stmgeia r0!, {r7, r12}
    bgt     8b @ 32x_loop
    beq     2b @ loop_inner
    adds    r8, r8, #2
    strge   r7, [r0], #4     @ store 2 leftover pixels
    b       2b @ loop_inner

9: @ bg_loop:
    ldrb    r12,[r11],#1     @ MD pixel 0,1
    ldrb    lr, [r11],#1
.if \do_md
    cmp     r3, r12,lsl #26  @ MD pixel 0 has bg?
    mov     r12,r12,lsl #1
    ldrneh  r12,[r9, r12]    @ t = palmd[*pmd]
    moveq   r12,r7
    cmp     r3, lr, lsl #26  @ MD pixel 1 has bg?
    mov     lr, lr, lsl #1
    ldrneh  lr, [r9, lr]
    moveq   lr, r7
    orr     r12,r12,lr, lsl #16 @ combine 2 pixels to optimize memory bandwidth
    str     r12,[r0], #4     @ (no write combining on ARM9)
.else
    add     r0, r0, #4
    cmp     r3, r12,lsl #26  @ MD pixel 0 has bg?
    streqh  r7, [r0, #-4]
    cmp     r3, lr, lsl #26  @ MD pixel 1 has bg?
    streqh  r7, [r0, #-2]
.endif
    subs    r8, r8, #2
    bgt     9b @ bg_loop
    b       2b @ loop_inner
.endm


@ run length
@ unsigned short *dst, unsigned short *dram, int lines_sft_offs, int mdbg
.macro make_do_loop_rl name call_scan do_md
.global \name
\name:
    stmfd   sp!, {r4-r11,lr}

    PIC_LDR(lr, r9, Pico)
    PIC_LDR(r10,r9, Pico32xMem)
    ldr     r9, =OFS_PMEM32x_pal_native
    ldr     r10, [r10]
    ldr     r11, [lr, #OFS_Pico_est+OFS_EST_Draw2FB]
    add     r10,r10,r9
    add     r9, lr, #OFS_Pico_est+OFS_EST_HighPal   @ palmd

    and     r4, r2, #0xff
    mov     r5, #328
    mov     r3, r3, lsl #26  @ mdbg << 26
    mla     r11,r4,r5,r11    @ r11 = pmd = PicoDraw2FB + offs*328: md data
    call_scan_prep \call_scan lr

    mov     r4, #0           @ line
    b       1f @ loop_outer_entry

0: @ loop_outer:
    call_scan_end \call_scan
    ldr     r12, [r9, #OFS_EST_DrawLineDestIncr-OFS_EST_HighPal]
    sub     r0, r0, #320*2
    add     r0, r0, r12
    add     r4, r4, #1
    and     r12, r2, #0xff0000
    cmp     r4, r12, lsr #16
    call_scan_fin_ge \call_scan
    ldmgefd sp!, {r4-r11,pc}

1: @ loop_outer_entry:
    call_scan_begin \call_scan
    add     r12,r4, r2, lsr #24
    mov     r12,r12,lsl #1
    ldrh    r12,[r1, r12]
    add     r11,r11,#8
    mov     r6, #320
    add     r5, r1, r12, lsl #1 @ p32x = dram + dram[l]

2: @ loop_inner:
    ldrh    r8, [r5], #2     @ control word
    and     r12,r8, #0xff
    mov     r12,r12,lsl #1
    ldrh    lr, [r10,r12]    @ t = 32x pixel
    eor     lr, lr, #0x20

3: @ loop_innermost:
    subs    r6, r6, #1
    ldrgeb  r7, [r11], #1    @ MD pixel
    blt     0b @ loop_outer
    tst     lr, #0x20
    cmpne   r3, r7, lsl #26  @ MD has bg pixel?
.if \do_md
    mov     r7, r7, lsl #1
    ldrneh  r12,[r9, r7]     @ t = palmd[*pmd]
    streqh  lr, [r0], #2
    strneh  r12,[r0], #2     @ *dst++ = t
.else
    streqh  lr, [r0]
    add     r0, r0, #2
.endif
    subs    r8, r8, #0x100
    bge     3b @ loop_innermost
    b       2b @ loop_inner
.endm


make_do_loop_dc do_loop_dc,         0, 0
make_do_loop_dc do_loop_dc_md,      0, 1
make_do_loop_dc do_loop_dc_scan,    1, 0
make_do_loop_dc do_loop_dc_scan_md, 1, 1
.pool

make_do_loop_pp do_loop_pp,         0, 0
make_do_loop_pp do_loop_pp_md,      0, 1
make_do_loop_pp do_loop_pp_scan,    1, 0
make_do_loop_pp do_loop_pp_scan_md, 1, 1
.pool

make_do_loop_rl do_loop_rl,         0, 0
make_do_loop_rl do_loop_rl_md,      0, 1
make_do_loop_rl do_loop_rl_scan,    1, 0
make_do_loop_rl do_loop_rl_scan_md, 1, 1
.pool

@ vim:filetype=armasm
