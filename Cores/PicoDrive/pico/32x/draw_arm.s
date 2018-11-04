@*
@* PicoDrive
@* (C) notaz, 2010
@*
@* This work is licensed under the terms of MAME license.
@* See COPYING file in the top-level directory.
@*

.extern Pico32x
.extern PicoDraw2FB
.extern HighPal

.equiv P32XV_PRI,  (1<< 7)

.bss
.align 2
.global Pico32xNativePal
Pico32xNativePal:
    .word 0

.text
.align 2


.macro call_scan_prep cond
.if \cond
    ldr     r4, =PicoScan32xBegin
    ldr     r5, =PicoScan32xEnd
    ldr     r6, =DrawLineDest
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
    ldr     r0, [sp, #(3+2)*4] @ &DrawLineDest
    ldmfd   sp!, {r1-r3}
    ldr     r0, [r0]
.endif
.endm

.macro call_scan_end cond
.if \cond
    stmfd   sp!, {r0-r3}
    and     r0, r2, #0xff
    add     r0, r0, r4
    mov     lr, pc
    ldr     pc, [sp, #(4+1)*4]
    ldmfd   sp!, {r0-r3}
.endif
.endm

@ direct color
@ unsigned short *dst, unsigned short *dram, int lines_sft_offs, int mdbg
.macro make_do_loop_dc name call_scan do_md
.global \name
\name:
    stmfd   sp!, {r4-r11,lr}

    ldr     r10,=Pico32x
    ldr     r11,=PicoDraw2FB
    ldr     r10,[r10, #0x40] @ Pico32x.vdp_regs[0]
    ldr     r11,[r11]
    ldr     r9, =HighPal     @ palmd
    and     r4, r2, #0xff
    mov     r5, #328
    lsl     r3, #26          @ mdbg << 26
    mla     r11,r4,r5,r11    @ r11 = pmd = PicoDraw2FB + offs*328: md data
    tst     r10,#P32XV_PRI
    moveq   r10,#0
    movne   r10,#0x8000      @ r10 = inv_bit
    call_scan_prep \call_scan

    mov     r4, #0           @ line
    b       1f @ loop_outer_entry

0: @ loop_outer:
    call_scan_end \call_scan
    add     r4, r4, #1
    sub     r11,r11,#1       @ adjust for prev read
    cmp     r4, r2, lsr #16
    call_scan_fin_ge \call_scan
    ldmgefd sp!, {r4-r11,pc}

1: @ loop_outer_entry:
    call_scan_begin \call_scan
    mov     r12,r4, lsl #1
    ldrh    r12,[r1, r12]
    add     r11,r11,#8
    mov     r6, #320
    add     r5, r1, r12, lsl #1 @ p32x = dram + dram[l]

2: @ loop_inner:
    ldrb    r7, [r11], #1    @ MD pixel
    subs    r6, r6, #1
    blt     0b @ loop_outer
    ldrh    r8, [r5], #2     @ 32x pixel
    cmp     r3, r7, lsl #26  @ MD has bg pixel?
    beq     3f @ draw32x
    eor     r12,r8, r10
    ands    r12,r12,#0x8000  @ !((t ^ inv) & 0x8000)
.if \do_md
    mov     r7, r7, lsl #1
    ldreqh  r12,[r9, r7]
    streqh  r12,[r0], #2     @ *dst++ = palmd[*pmd]
.endif
    beq     2b @ loop_inner

3: @ draw32x:
    and     r12,r8, #0x03e0
    mov     r8, r8, lsl #11
    orr     r8, r8, r8, lsr #(10+11)
    orr     r8, r8, r12,lsl #1
    bic     r8, r8, #0x0020  @ kill prio bit
    strh    r8, [r0], #2     @ *dst++ = bgr2rgb(*p32x++)
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

    ldr     r11,=PicoDraw2FB
    ldr     r10,=Pico32xNativePal
    ldr     r11,[r11]
    ldr     r10,[r10]
    ldr     r9, =HighPal     @ palmd
    and     r4, r2, #0xff
    mov     r5, #328
    lsl     r3, #26          @ mdbg << 26
    mla     r11,r4,r5,r11    @ r11 = pmd = PicoDraw2FB + offs*328: md data
    call_scan_prep \call_scan

    mov     r4, #0           @ line
    b       1f @ loop_outer_entry

0: @ loop_outer:
    call_scan_end \call_scan
    add     r4, r4, #1
    cmp     r4, r2, lsr #16
    call_scan_fin_ge \call_scan
    ldmgefd sp!, {r4-r11,pc}

1: @ loop_outer_entry:
    call_scan_begin \call_scan
    mov     r12,r4, lsl #1
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
    ldrneb  r8, [r5, #2]!    @ r7,r8 - pixel 0,1 index
    subs    r6, r6, #1
    blt     0b @ loop_outer
    cmp     r7, r8
    beq     5f @ check_fill @ +8

3: @ no_fill:
    mov     r12,r7, lsl #1
    mov     lr, r8, lsl #1
    ldrh    r7, [r10,r12]
    ldrh    r8, [r10,lr]
    add     r11,r11,#2

    eor     r12,r7, #0x20
    tst     r12,#0x20
    ldrneb  r12,[r11,#-2]    @ MD pixel 0
    eor     lr, r8, #0x20
    cmpne   r3, r12, lsl #26 @ MD has bg pixel?
.if \do_md
    mov     r12,r12,lsl #1
    ldrneh  r7, [r9, r12]    @ t = palmd[pmd[0]]
    tst     lr, #0x20
    ldrneb  lr, [r11,#-1]    @ MD pixel 1
    strh    r7, [r0], #2
    cmpne   r3, lr, lsl #26  @ MD has bg pixel?
    mov     lr, lr, lsl #1
    ldrneh  r8, [r9, lr]     @ t = palmd[pmd[1]]
    strh    r8, [r0], #2
.else
    streqh  r7, [r0]
    tst     lr, #0x20
    ldrneb  lr, [r11,#-1]    @ MD pixel 1
    add     r0, r0, #4
    cmpne   r3, lr, lsl #26  @ MD has bg pixel?
    streqh  r8, [r0, #-2]
.endif
    b       2b @ loop_inner

5: @ check_fill
    @ count pixels, align if needed
    bic     r12,r5, #1
    ldrh    r12,[r12]
    orr     lr, r7, r7, lsl #8
    cmp     r12,lr
    bne     3b @ no_fill

    tst     r5, #1
    sub     lr, r5, #2       @ starting r5 (32x render data start)
    addeq   r5, r5, #2
    addne   r5, r5, #1       @ add for the check above
    add     r6, r6, #1       @ restore from dec
    orr     r7, r7, r7, lsl #8
6:
    sub     r12,r5, lr
    ldrh    r8, [r5], #2
    cmp     r12,r6, lsl #1
    ldrh    r12,[r5], #2
    bge     7f @ count_done
    cmp     r8, r7
    cmpeq   r12,r7
    beq     6b

7: @ count_done
    sub     r5, r5, #4      @ undo readahead

    @ fix alignment and check type
    sub     r8, r5, lr
    tst     r8, #1
    subne   r5, r5, #1
    subne   r8, r8, #1

    and     r7, r7, #0xff
    cmp     r8, r6, lsl #1
    mov     r7, r7, lsl #1
    movgt   r8, r6, lsl #1  @ r8=count
    ldrh    r7, [r10,r7]
    sub     r6, r6, r8, lsr #1 @ adjust counter
    tst     r7, #0x20
    beq     9f @ bg_mode

    add     r11,r11,r8
8:
    subs    r8, r8, #2
    strgeh  r7, [r0], #2
    strgeh  r7, [r0], #2
    bgt     8b
    b       2b @ loop_inner

9: @ bg_mode:
    ldrb    r12,[r11],#1     @ MD pixel
    ldrb    lr, [r11],#1
    cmp     r3, lr, lsl #26  @ MD has bg pixel?
.if \do_md
    mov     r12,r12,lsl #1
    ldrneh  r12,[r9, r12]    @ t = palmd[*pmd]
    moveq   r12,r7
    cmp     r3, lr, lsl #26
    mov     lr, lr, lsl #1
    ldrneh  lr, [r9, lr]
    moveq   lr, r7
    strh    r12,[r0], #2
    strh    lr, [r0], #2
.else
    streqh  r7, [r0]
    cmp     r3, lr, lsl #26
    streqh  r7, [r0, #2]
    add     r0, r0, #4
.endif
    subs    r8, r8, #2
    bgt     9b @ bg_mode
    b       2b @ loop_inner
.endm


@ run length
@ unsigned short *dst, unsigned short *dram, int lines_sft_offs, int mdbg
.macro make_do_loop_rl name call_scan do_md
.global \name
\name:
    stmfd   sp!, {r4-r11,lr}

    ldr     r11,=PicoDraw2FB
    ldr     r10,=Pico32xNativePal
    ldr     r11,[r11]
    ldr     r10,[r10]
    ldr     r9, =HighPal     @ palmd
    and     r4, r2, #0xff
    mov     r5, #328
    lsl     r3, #26          @ mdbg << 26
    mla     r11,r4,r5,r11    @ r11 = pmd = PicoDraw2FB + offs*328: md data
    call_scan_prep \call_scan

    mov     r4, #0           @ line
    b       1f @ loop_outer_entry

0: @ loop_outer:
    call_scan_end \call_scan
    add     r4, r4, #1
    sub     r11,r11,#1       @ adjust for prev read
    cmp     r4, r2, lsr #16
    call_scan_fin_ge \call_scan
    ldmgefd sp!, {r4-r11,pc}

1: @ loop_outer_entry:
    call_scan_begin \call_scan
    mov     r12,r4, lsl #1
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
    ldrb    r7, [r11], #1    @ MD pixel
    subs    r6, r6, #1
    blt     0b @ loop_outer
    cmp     r3, r7, lsl #26  @ MD has bg pixel?
    mov     r7, r7, lsl #1
    tstne   lr, #0x20
.if \do_md
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

make_do_loop_pp do_loop_pp,         0, 0
make_do_loop_pp do_loop_pp_md,      0, 1
make_do_loop_pp do_loop_pp_scan,    1, 0
make_do_loop_pp do_loop_pp_scan_md, 1, 1

make_do_loop_rl do_loop_rl,         0, 0
make_do_loop_rl do_loop_rl_md,      0, 1
make_do_loop_rl do_loop_rl_scan,    1, 0
make_do_loop_rl do_loop_rl_scan_md, 1, 1

@ vim:filetype=armasm
