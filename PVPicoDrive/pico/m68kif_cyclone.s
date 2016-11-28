/*
 * PicoDrive
 * (C) notaz, 2009
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#ifdef __arm__
.equ M68K_MEM_SHIFT, 16

.global cyclone_checkpc
.global cyclone_fetch8
.global cyclone_fetch16
.global cyclone_fetch32
.global cyclone_read8
.global cyclone_read16
.global cyclone_read32
.global cyclone_write8
.global cyclone_write16
.global cyclone_write32

@ Warning: here we abuse the fact that we are only called
@ from Cyclone, and assume that r7 contains context pointer.
cyclone_checkpc:
    ldr     r1, [r7, #0x60]  @ membase
    sub     r0, r0, r1
    and     r3, r0, #0xff000000
    bic     r0, r0, #1
    bics    r2, r0, #0xff000000
    beq     crashed

    ldr     r1, [r7, #0x6c]  @ read16 map
    mov     r2, r2, lsr #M68K_MEM_SHIFT
    ldr     r1, [r1, r2, lsl #2]
    movs    r1, r1, lsl #1
    bcs     crashed

    sub     r1, r1, r3
    str     r1, [r7, #0x60]  @ membase
    add     r0, r0, r1
    bx      lr

crashed:
    stmfd   sp!,{lr}
    mov     r1, r7
    bl      cyclone_crashed
    ldr     r0, [r7, #0x40]  @ reload PC + membase
    ldmfd   sp!,{pc}


cyclone_read8: @ u32 a
cyclone_fetch8:
    bic     r0, r0, #0xff000000
    ldr     r1, [r7, #0x68]  @ read8 map
    mov     r2, r0, lsr #M68K_MEM_SHIFT
    ldr     r1, [r1, r2, lsl #2]
    eor     r2, r0, #1
    movs    r1, r1, lsl #1
    ldrccb  r0, [r1, r2]
    bxcc    lr
    bx      r1


cyclone_read16: @ u32 a
cyclone_fetch16:
    bic     r0, r0, #0xff000000
    ldr     r1, [r7, #0x6c]  @ read16 map
    mov     r2, r0, lsr #M68K_MEM_SHIFT
    ldr     r1, [r1, r2, lsl #2]
    bic     r0, r0, #1
    movs    r1, r1, lsl #1
    ldrcch  r0, [r1, r0]
    bxcc    lr
    bx      r1


cyclone_read32: @ u32 a
cyclone_fetch32:
    bic     r0, r0, #0xff000000
    ldr     r1, [r7, #0x6c]  @ read16 map
    mov     r2, r0, lsr #M68K_MEM_SHIFT
    ldr     r1, [r1, r2, lsl #2]
    bic     r0, r0, #1
    movs    r1, r1, lsl #1
    ldrcch  r0, [r1, r0]!
    ldrcch  r1, [r1, #2]
    orrcc   r0, r1, r0, lsl #16
    bxcc    lr

    stmfd   sp!,{r0,r1,lr}
    mov     lr, pc
    bx      r1
    mov     r2, r0, lsl #16
    ldmia   sp, {r0,r1}
    str     r2, [sp]
    add     r0, r0, #2
    mov     lr, pc
    bx      r1
    ldr     r1, [sp]
    mov     r0, r0, lsl #16
    orr     r0, r1, r0, lsr #16
    ldmfd   sp!,{r1,r2,pc}


cyclone_write8: @ u32 a, u8 d
    bic     r0, r0, #0xff000000
    ldr     r2, [r7, #0x74]  @ write8 map
    mov     r3, r0, lsr #M68K_MEM_SHIFT
    ldr     r2, [r2, r3, lsl #2]
    eor     r3, r0, #1
    movs    r2, r2, lsl #1
    strccb  r1, [r2, r3]
    bxcc    lr
    bx      r2


cyclone_write16: @ u32 a, u16 d
    bic     r0, r0, #0xff000000
    ldr     r2, [r7, #0x78]  @ write16 map
    mov     r3, r0, lsr #M68K_MEM_SHIFT
    ldr     r2, [r2, r3, lsl #2]
    bic     r0, r0, #1
    movs    r2, r2, lsl #1
    strcch  r1, [r2, r0]
    bxcc    lr
    bx      r2


cyclone_write32: @ u32 a, u32 d
    bic     r0, r0, #0xff000000
    ldr     r2, [r7, #0x78]  @ write16 map
    mov     r3, r0, lsr #M68K_MEM_SHIFT
    ldr     r2, [r2, r3, lsl #2]
    bic     r0, r0, #1
    movs    r2, r2, lsl #1
    movcc   r3, r1, lsr #16
    strcch  r3, [r2, r0]!
    strcch  r1, [r2, #2]
    bxcc    lr

    stmfd   sp!,{r0-r2,lr}
    mov     r1, r1, lsr #16
    mov     lr, pc
    bx      r2
    ldmfd   sp!,{r0-r2,lr}
    add     r0, r0, #2
    bx      r2

@ vim:filetype=armasm
#endif
