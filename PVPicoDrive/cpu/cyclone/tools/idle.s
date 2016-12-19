@ vim:filetype=armasm

@ ranges/opcodes (idle, normal):
@ 71xx, 73xx  - bne.s (8bit offset)
@ 75xx, 77xx  - beq.s (8bit offset)
@ 7dxx, 7fxx  - bra.s (8bit offset)

.data
.align 2

have_patches:
  .word 0

.equ patch_desc_table_size, 10

patch_desc_table:
  .word (0x71fa<<16) | 0x66fa, idle_detector_bcc8, idle_bne, Op6602  @ bne.s
  .word (0x71f8<<16) | 0x66f8, idle_detector_bcc8, idle_bne, Op6602  @ bne.s
  .word (0x71f6<<16) | 0x66f6, idle_detector_bcc8, idle_bne, Op6602  @ bne.s
  .word (0x71f2<<16) | 0x66f2, idle_detector_bcc8, idle_bne, Op6602  @ bne.s
  .word (0x75fa<<16) | 0x67fa, idle_detector_bcc8, idle_beq, Op6702  @ beq.s
  .word (0x75f8<<16) | 0x67f8, idle_detector_bcc8, idle_beq, Op6702  @ beq.s
  .word (0x75f6<<16) | 0x67f6, idle_detector_bcc8, idle_beq, Op6702  @ beq.s
  .word (0x75f2<<16) | 0x67f2, idle_detector_bcc8, idle_beq, Op6702  @ beq.s
  .word (0x7dfe<<16) | 0x60fe, idle_detector_bcc8, idle_bra, Op6002  @ bra.s
  .word (0x7dfc<<16) | 0x60fc, idle_detector_bcc8, idle_bra, Op6002  @ bra.s


.text
.align 2


.global CycloneInitIdle

CycloneInitIdle:
    ldr     r3, =CycloneJumpTab
    ldr     r2, =patch_desc_table
    mov     r12,#patch_desc_table_size

cii_loop:
    ldrh    r0, [r2]
    ldr     r1, [r2, #4]           @ detector
    str     r1, [r3, r0, lsl #2]
    ldrh    r0, [r2, #2]
    ldr     r1, [r2, #8]           @ idle
    add     r0, r3, r0, lsl #2
    str     r1, [r0]
    ldr     r1, [r2, #12]          @ normal
    str     r1, [r0, #0x800]
    add     r2, r2, #16
    subs    r12,r12,#1
    bgt     cii_loop

    ldr     r0, =have_patches
    mov     r1, #1
    str     r1, [r0]
    bx      lr


.global CycloneFinishIdle

CycloneFinishIdle:
    ldr     r0, =have_patches
    ldr     r0, [r0]
    tst     r0, r0
    bxeq    lr

    ldr     r3, =CycloneJumpTab
    ldr     r2, =patch_desc_table
    mov     r12,#patch_desc_table_size

cfi_loop:
    ldrh    r0, [r2]
    ldr     r1, [r2, #12]         @ normal
    str     r1, [r3, r0, lsl #2]
    ldrh    r0, [r2, #2]
    ldr     r1, =Op____
    add     r0, r3, r0, lsl #2
    str     r1, [r0]
    str     r1, [r0, #0x800]
    add     r2, r2, #16
    subs    r12,r12,#1
    bgt     cfi_loop

    ldr     r0, =have_patches
    mov     r1, #0
    str     r1, [r0]
    bx      lr



.macro inc_counter cond
@    ldr\cond r0, [r7, #0x60]
@    mov     r11,lr
@    sub     r0, r4, r0
@    sub     r0, r0, #2
@    bl\cond SekRegisterIdleHit
@    mov     lr, r11
.endm

idle_bra:
    mov     r5, #2
    inc_counter
    b       Op6002

idle_bne:
    tst     r10, #0x40000000      @ Z set?
    moveq   r5, #2                @ 2 is intentional due to strange timing issues
    inc_counter eq
    b       Op6602

idle_beq:
    tst     r10, #0x40000000      @ Z set?
    movne   r5, #2
    inc_counter ne
    b       Op6702


@ @@@ @

idle_detector_bcc8:
    bl      SekIsIdleReady
    tst     r0, r0
    beq     exit_detector         @ not yet

    mov     r0, r8, asl #24       @ Shift 8-bit signed offset up...
    add     r0, r4, r0, asr #24   @ jump dest
    bic     r0, r0, #1

    mov     r1, #0
    sub     r1, r1, r8, lsl #24
    mov     r1, r1, lsr #24
    sub     r1, r1, #2
    bic     r1, r1, #1

    bl      SekIsIdleCode
    tst     r0, r0
    and     r2, r8, #0x00ff
    orr     r2, r2, #0x7100
    orreq   r2, r2, #0x0200
    mov     r0, r8, lsr #8
    cmp     r0, #0x66
    orrgt   r2, r2, #0x0400       @ 67xx (beq)
    orrlt   r2, r2, #0x0c00       @ 60xx (bra)

    @ r2 = patch_opcode
    sub     r0, r4, #2
    ldrh    r1, [r0]
    mov     r11,r2
    mov     r3, r7
    bl      SekRegisterIdlePatch
    cmp     r0, #1                @ 0 - ok to patch, 1 - no patch, 2 - remove detector
    strlth  r11,[r4, #-2]
    ble     exit_detector

    @ remove detector from Cyclone
    mov     r0, r8, lsr #8
    cmp     r0, #0x66
    ldrlt   r1, =Op6002
    ldreq   r1, =Op6602
    ldrgt   r1, =Op6702

    ldr     r3, =CycloneJumpTab
    str     r1, [r3, r8, lsl #2]
    bx      r1

exit_detector:
    mov     r0, r8, lsr #8
    cmp     r0, #0x66
    blt     Op6002
    beq     Op6602
    b       Op6702

