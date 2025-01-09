@ vim:filetype=armasm


.global vidCpy8to16 @ void *dest, void *src, short *pal, int lines|(flags<<16),
                    @ flags=is32col[0], no_even_lines[1], no_odd_lines[2]

vidCpy8to16:
    stmfd   sp!, {r4-r8,lr}

    and     r4, r3, #0xff0000
    and     r3, r3, #0xff
    tst     r4, #0x10000
    mov     r3, r3, lsr #1
    orr     r3, r3, r3, lsl #8
    orreq   r3, r3, #(320/8-1)<<24 @ 40 col mode
    orrne   r3, r3, #(256/8-1)<<24 @ 32 col mode
    addne   r0, r0, #32*2
    orr     r3, r3, r4
    add     r1, r1, #8
    mov     lr, #0xff
    mov     lr, lr, lsl #1

    @ no even lines?
    tst     r3, #0x20000
    addne   r0, r0, #320*2
    addne   r1, r1, #328
    bne     vcloop_odd

    @ even lines first
vcloop_aligned:
    ldr     r12, [r1], #4
    ldr     r7,  [r1], #4

    and     r4, lr, r12,lsl #1
    ldrh    r4, [r2, r4]
    and     r5, lr, r12,lsr #7
    ldrh    r5, [r2, r5]
    and     r6, lr, r12,lsr #15
    ldrh    r6, [r2, r6]
    orr     r4, r4, r5, lsl #16

    and     r5, lr, r12,lsr #23
    ldrh    r5, [r2, r5]
    and     r8, lr, r7, lsl #1
    ldrh    r8, [r2, r8]
    orr     r5, r6, r5, lsl #16

    and     r6, lr, r7, lsr #7
    ldrh    r6, [r2, r6]
    and     r12,lr, r7, lsr #15
    ldrh    r12,[r2, r12]
    and     r7, lr, r7, lsr #23
    ldrh    r7, [r2, r7]
    orr     r8, r8, r6, lsl #16

    subs    r3, r3, #1<<24
    orr     r12,r12, r7, lsl #16

    stmia   r0!, {r4,r5,r8,r12}
    bpl     vcloop_aligned

    tst     r3, #0x10000
    add     r1, r1, #336             @ skip a line and 1 col
    addne   r1, r1, #64              @ skip more for 32col mode
    add     r0, r0, #(320+2)*2
    addne   r0, r0, #64*2
    addeq   r3, r3, #(320/8)<<24
    addne   r3, r3, #(256/8)<<24
    sub     r3, r3, #1
    tst     r3, #0xff
    bne     vcloop_aligned

    @ no odd lines?
    tst     r3, #0x40000
    ldmnefd sp!, {r4-r8,pc}

    and     r4, r3, #0xff00
    orr     r3, r3, r4, lsr #8
    mov     r4, r4, lsr #7
    sub     r6, r4, #1
    mov     r5, #320*2
    add     r5, r5, #2
    mul     r4, r5, r6
    sub     r0, r0, r4
    mov     r5, #328
    mul     r4, r5, r6
    sub     r1, r1, r4

    sub     r0, r0, #2
vcloop_odd:
    mov     r8, #0

vcloop_unaligned:
    ldr     r12, [r1], #4
    ldr     r7,  [r1], #4

    and     r6, lr, r12, lsl #1
    ldrh    r6, [r2, r6]
    and     r5, lr, r12, lsr #7
    ldrh    r5, [r2, r5]
    orr     r4, r8, r6, lsl #16

    and     r6, lr, r12, lsr #15
    ldrh    r6, [r2, r6]
    and     r8, lr, r12, lsr #23
    ldrh    r8, [r2, r8]
    orr     r5, r5, r6, lsl #16

    and     r6, lr, r7, lsl #1
    ldrh    r6, [r2, r6]
    and     r12,lr, r7, lsr #7
    ldrh    r12,[r2, r12]
    orr     r6, r8, r6, lsl #16

    and     r8, lr, r7, lsr #15
    ldrh    r8, [r2, r8]

    subs    r3, r3, #1<<24
    and     r7, lr, r7, lsr #23
    orr     r12,r12,r8, lsl #16

    ldrh    r8, [r2, r7]

    stmia   r0!, {r4,r5,r6,r12}
    bpl     vcloop_unaligned

    strh    r8, [r0]
    mov     r8, #0

    tst     r3, #0x10000
    add     r1, r1, #336             @ skip a line and 1 col
    addne   r1, r1, #64              @ skip more for 32col mode
    add     r0, r0, #(320+2)*2
    addne   r0, r0, #64*2
    addeq   r3, r3, #(320/8)<<24
    addne   r3, r3, #(256/8)<<24
    sub     r3, r3, #1
    tst     r3, #0xff
    bne     vcloop_unaligned

    ldmfd   sp!, {r4-r8,lr}
    bx      lr


