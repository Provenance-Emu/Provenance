@*
@* Memory I/O handlers for Sega/Mega CD emulation
@* (C) notaz, 2007-2009
@*
@* This work is licensed under the terms of MAME license.
@* See COPYING file in the top-level directory.
@*
#ifdef __arm__
.equiv PCM_STEP_SHIFT, 11

.text
.align 2

.global PicoRead8_mcd_io
.global PicoRead16_mcd_io
.global PicoWrite8_mcd_io
.global PicoWrite16_mcd_io

.global PicoReadS68k8_pr
.global PicoReadS68k16_pr
.global PicoWriteS68k8_pr
.global PicoWriteS68k16_pr

.global PicoReadM68k8_cell0
.global PicoReadM68k8_cell1
.global PicoReadM68k16_cell0
.global PicoReadM68k16_cell1
.global PicoWriteM68k8_cell0
.global PicoWriteM68k8_cell1
.global PicoWriteM68k16_cell0
.global PicoWriteM68k16_cell1

.global PicoReadS68k8_dec0
.global PicoReadS68k8_dec1
.global PicoReadS68k16_dec0
.global PicoReadS68k16_dec1
.global PicoWriteS68k8_dec_m0b0
.global PicoWriteS68k8_dec_m1b0
.global PicoWriteS68k8_dec_m2b0
.global PicoWriteS68k8_dec_m0b1
.global PicoWriteS68k8_dec_m1b1
.global PicoWriteS68k8_dec_m2b1
.global PicoWriteS68k16_dec_m0b0
.global PicoWriteS68k16_dec_m1b0
.global PicoWriteS68k16_dec_m2b0
.global PicoWriteS68k16_dec_m0b1
.global PicoWriteS68k16_dec_m1b1
.global PicoWriteS68k16_dec_m2b1

@ externs, just for reference
.extern Pico
.extern cdc_host_r
.extern m68k_reg_write8
.extern s68k_reg_read16
.extern s68k_reg_write8
.extern s68k_reg_write16
.extern s68k_poll_detect
.extern pcd_pcm_write
.extern pcd_pcm_read
.extern PicoCpuCS68k
.extern PicoRead8_io
.extern PicoRead16_io
.extern PicoWrite8_io
.extern PicoWrite16_io
.extern m68k_comm_check


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

@ utilities

@ r0=addr[in,out], r1,r2=tmp
.macro cell_map
    ands    r1, r0, #0x01c000
    ldrne   pc, [pc, r1, lsr #12]
    beq     0f                          @ most common?
    .long   0f
    .long   0f
    .long   0f
    .long   0f
    .long   1f
    .long   1f
    .long   2f
    .long   3f
1: @ x16 cells
    and     r1, r0, #0x7e00             @ col
    and     r2, r0, #0x01fc             @ row
    orr     r2, r2, #0x0400
    orr     r1, r2, r1, ror #13
    b       9f
2: @ x8 cells
    and     r1, r0, #0x3f00             @ col
    and     r2, r0, #0x00fc             @ row
    orr     r2, r2, #0x0600
    orr     r1, r2, r1, ror #12
    b       9f
3: @ x4 cells
    and     r1, r0, #0x1f80             @ col
    and     r2, r0, #0x007c             @ row
    orr     r1, r2, r1, ror #11
    and     r2, r0,#0x1e000
    orr     r1, r1, r2, lsr #6
    b       9f
0: @ x32 cells
    and     r1, r0, #0xfc00             @ col
    and     r2, r0, #0x03fc             @ row
    orr     r1, r2, r1, ror #14
9:
    and     r0, r0, #3
    orr     r0, r0, r1, ror #26         @ rol 4+2
.endm


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


m_read_null:
    mov     r0, #0
    bx      lr


PicoReadM68k8_cell0:                    @ 0x220000 - 0x23ffff, cell arranged
    mov     r3, #0x0c0000
    b       0f

PicoReadM68k8_cell1:                    @ 0x220000 - 0x23ffff, cell arranged
    mov     r3, #0x0e0000
0:
    cell_map
    ldr     r1, =(Pico+0x22200)
    add     r0, r0, r3
    ldr     r1, [r1]
    eor     r0, r0, #1
    ldrb    r0, [r1, r0]
    bx      lr


PicoRead8_mcd_io:
    and     r1, r0, #0xff00
    cmp     r1, #0x2000	              @ a120xx?
    bne     PicoRead8_io

    ldr     r1, =(Pico+0x22200)
    and     r0, r0, #0x3f
    ldr     r1, [r1]                  @ Pico.mcd (used everywhere)
    cmp     r0, #0x0e
    ldrlt   pc, [pc, r0, lsl #2]
    b       m_m68k_read8_hi
    .long   m_m68k_read8_r00
    .long   m_m68k_read8_r01
    .long   m_m68k_read8_r02
    .long   m_m68k_read8_r03
    .long   m_m68k_read8_r04
    .long   m_read_null               @ unused bits
    .long   m_m68k_read8_r06
    .long   m_m68k_read8_r07
    .long   m_m68k_read8_r08
    .long   m_m68k_read8_r09
    .long   m_read_null               @ reserved
    .long   m_read_null
    .long   m_m68k_read8_r0c
    .long   m_m68k_read8_r0d
m_m68k_read8_r00:
    add     r1, r1, #0x110000
    ldr     r0, [r1, #0x30]
    and     r0, r0, #0x04000000       @ we need irq2 mask state
    mov     r0, r0, lsr #19
    bx      lr
m_m68k_read8_r01:
    add     r1, r1, #0x110000
    add     r1, r1, #0x002200
    ldrb    r0, [r1, #2]              @ Pico_mcd->m.busreq
    bx      lr
m_m68k_read8_r02:
    add     r1, r1, #0x110000
    ldrb    r0, [r1, #2]
    bx      lr
m_m68k_read8_r03:
    add     r1, r1, #0x110000
    push    {r1, lr}
    bl      m68k_comm_check
    pop     {r1, lr}
    ldrb    r0, [r1, #3]
    and     r0, r0, #0xc7
    bx      lr
m_m68k_read8_r04:
    add     r1, r1, #0x110000
    ldrb    r0, [r1, #4]
    bx      lr
m_m68k_read8_r06:
    ldrb    r0, [r1, #0x73]           @ IRQ vector
    bx      lr
m_m68k_read8_r07:
    ldrb    r0, [r1, #0x72]
    bx      lr
m_m68k_read8_r08:
    mov     r0, #0
    bl      cdc_host_r
    mov     r0, r0, lsr #8
    bx      lr
m_m68k_read8_r09:
    mov     r0, #0
    b       cdc_host_r
m_m68k_read8_r0c:
    add     r1, r1, #0x110000
    add     r1, r1, #0x002200
    ldr     r0, [r1, #0x14]           @ Pico_mcd->m.timer_stopwatch
    mov     r0, r0, lsr #24
    bx      lr
m_m68k_read8_r0d:
    add     r1, r1, #0x110000
    add     r1, r1, #0x002200
    ldr     r0, [r1, #0x14]
    mov     r0, r0, lsr #16
    bx      lr
m_m68k_read8_hi:
    cmp     r0, #0x30
    add     r1, r1, #0x110000
    movge   r0, #0
    bxge    lr
    add     r1, r0
    push    {r1, lr}
    bl      m68k_comm_check
    pop     {r1, lr}
    ldrb    r0, [r1]
    bx      lr


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


PicoReadM68k16_cell0:                   @ 0x220000 - 0x23ffff, cell arranged
    mov     r3, #0x0c0000
    b       0f

PicoReadM68k16_cell1:                   @ 0x220000 - 0x23ffff, cell arranged
    mov     r3, #0x0e0000
0:
    cell_map
    ldr     r1, =(Pico+0x22200)
    add     r0, r0, r3
    ldr     r1, [r1]
    bic     r0, r0, #1
    ldrh    r0, [r1, r0]
    bx      lr


PicoRead16_mcd_io:
    and     r1, r0, #0xff00
    cmp     r1, #0x2000	              @ a120xx
    bne     PicoRead16_io

m_m68k_read16_m68k_regs:
    ldr     r1, =(Pico+0x22200)
    and     r0, r0, #0x3e
    ldr     r1, [r1]                  @ Pico.mcd (used everywhere)
    cmp     r0, #0x0e
    ldrlt   pc, [pc, r0, lsl #1]
    b       m_m68k_read16_hi
    .long   m_m68k_read16_r00
    .long   m_m68k_read16_r02
    .long   m_m68k_read16_r04
    .long   m_m68k_read16_r06
    .long   m_m68k_read16_r08
    .long   m_read_null               @ reserved
    .long   m_m68k_read16_r0c
m_m68k_read16_r00:
    add     r1, r1, #0x110000
    ldr     r0, [r1, #0x30]
    add     r1, r1, #0x002200
    ldrb    r1, [r1, #2]              @ Pico_mcd->m.busreq
    and     r0, r0, #0x04000000       @ we need irq2 mask state
    orr     r0, r1, r0, lsr #11
    bx      lr
m_m68k_read16_r02:
    add     r1, r1, #0x110000
    push    {r1, lr}
    bl      m68k_comm_check
    pop     {r1, lr}
    ldrb    r2, [r1, #3]
    ldrb    r0, [r1, #2]
    and     r2, r2, #0xc7
    orr     r0, r2, r0, lsl #8
    bx      lr
m_m68k_read16_r04:
    add     r1, r1, #0x110000
    ldrb    r0, [r1, #4]
    mov     r0, r0, lsl #8
    bx      lr
m_m68k_read16_r06:
    ldrh    r0, [r1, #0x72]           @ IRQ vector
    bx      lr
m_m68k_read16_r08:
    mov     r0, #0
    b       cdc_host_r
m_m68k_read16_r0c:
    add     r1, r1, #0x110000
    add     r1, r1, #0x002200
    ldr     r0, [r1, #0x14]
    mov     r0, r0, lsr #16
    bx      lr
m_m68k_read16_hi:
    cmp     r0, #0x30
    add     r1, r1, #0x110000
    movge   r0, #0
    bxge    lr

    add     r1, r0, r1
    push    {r1, lr}
    bl      m68k_comm_check
    pop     {r0, lr}
    ldrh    r0, [r0]
    mov     r1, r0, lsr #8
    and     r0, r0, #0xff
    orr     r0, r1, r0, lsl #8
    bx      lr


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


PicoWriteM68k8_cell0:                   @ 0x220000 - 0x23ffff, cell arranged
    mov     r12,#0x0c0000
    b       0f

PicoWriteM68k8_cell1:                   @ 0x220000 - 0x23ffff, cell arranged
    mov     r12,#0x0e0000
0:
    mov     r3, r1
    cell_map
    ldr     r2, =(Pico+0x22200)
    add     r0, r0, r12
    ldr     r2, [r2]
    eor     r0, r0, #1
    strb    r3, [r2, r0]
    bx      lr


PicoWrite8_mcd_io:
    and     r2, r0, #0xff00
    cmp     r2, #0x2000                 @ a120xx?
    beq     m68k_reg_write8
    b       PicoWrite8_io


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


PicoWriteM68k16_cell0:                   @ 0x220000 - 0x23ffff, cell arranged
    mov     r12, #0x0c0000
    b       0f

PicoWriteM68k16_cell1:                   @ 0x220000 - 0x23ffff, cell arranged
    mov     r12, #0x0e0000
0:
    mov     r3, r1
    cell_map
    ldr     r1, =(Pico+0x22200)
    add     r0, r0, r12
    ldr     r1, [r1]
    bic     r0, r0, #1
    strh    r3, [r1, r0]
    bx      lr


PicoWrite16_mcd_io:
    and     r2, r0, #0xff00
    cmp     r2, #0x2000                 @ a120xx?
    bne     PicoWrite16_io

m_m68k_write16_regs:
    and     r0, r0, #0x3e
    cmp     r0, #0x0e
    beq     m_m68k_write16_regs_spec
    and     r3, r1, #0xff
    add     r2, r0, #1
    stmfd   sp!,{r2,r3,lr}
    mov     r1, r1, lsr #8
    bl      m68k_reg_write8
    ldmfd   sp!,{r0,r1,lr}
    b       m68k_reg_write8

m_m68k_write16_regs_spec:               @ special case
    mov     r1, r1, lsr #8
    b       m68k_reg_write8


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@                                   Sub 68k
@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


PicoReadS68k8_dec0:                     @ 0x080000 - 0x0bffff
    mov     r3, #0x080000               @ + ^ / 2
    b       0f

PicoReadS68k8_dec1:
    mov     r3, #0x0a0000               @ + ^ / 2
0:
    ldr     r2, =(Pico+0x22200)
    eor     r0, r0, #2
    ldr     r2, [r2]
    movs    r0, r0, lsr #1              @ +4-6 <<16
    add     r2, r2, r3                  @ map to our address
    ldrb    r0, [r2, r0]
    movcc   r0, r0, lsr #4
    andcs   r0, r0, #0xf
    bx      lr


PicoReadS68k8_pr:
    and     r2, r0, #0xfe00
    cmp     r2, #0x8000
    bne     m_s68k_read8_pcm

m_s68k_read8_regs:
    bic     r0, r0, #0xff0000
    bic     r0, r0, #0x008000
    sub     r2, r0, #0x0e
    cmp     r2, #(0x30-0x0e)
    blo     m_s68k_read8_comm
    stmfd   sp!,{r0,lr}
    bic     r0, r0, #1
    bl      s68k_reg_read16
    ldmfd   sp!,{r1,lr}
    tst     r1, #1
    moveq   r0, r0, lsr #8
    and     r0, r0, #0xff
    bx      lr

m_s68k_read8_comm:
    ldr     r1, =(Pico+0x22200)
    ldr     r1, [r1]
    add     r1, r1, #0x110000
    ldrb    r1, [r1, r0]
    bic     r0, r0, #1
    b       s68k_poll_detect


m_s68k_read8_pcm:
    tst     r0, #0x8000
    bne     m_read_null

    @ must not trash r3 and r12
    ldr     r1, =(Pico+0x22200)
    bic     r0, r0, #0xff0000
    ldr     r1, [r1]
    mov     r2, #0x110000
    orr     r2, r2, #0x002200
    cmp     r0, #0x2000
    bge     m_s68k_read8_pcm_ram
    cmp     r0, #0x20
    movge   r0, r0, lsr #1
    bge     pcd_pcm_read
    mov     r0, #0
    bx      lr

m_s68k_read8_pcm_ram:
    orr     r2, r2, #0x40
    ldr     r2, [r1, r2]
    add     r1, r1, #0x100000           @ pcm_ram
    and     r2, r2, #0x0f000000         @ bank
    add     r1, r1, r2, lsr #12
    bic     r0, r0, #0x00e000
    mov     r0, r0, lsr #1
    ldrb    r0, [r1, r0]
    bx      lr


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


PicoReadS68k16_dec0:                    @ 0x080000 - 0x0bffff
    mov     r3, #0x080000               @ + ^ / 2
    b       0f

PicoReadS68k16_dec1:
    mov     r3, #0x0a0000               @ + ^ / 2
0:
    ldr     r2, =(Pico+0x22200)
    eor     r0, r0, #2
    ldr     r2, [r2]
    mov     r0, r0, lsr #1              @ +4-6 <<16
    add     r2, r2, r3                  @ map to our address
    ldrb    r0, [r2, r0]
    orr     r0, r0, r0, lsl #4
    bic     r0, r0, #0xf0
    bx      lr


PicoReadS68k16_pr:
    and     r2, r0, #0xfe00
    cmp     r2, #0x8000
    @ pcm is on 8-bit bus, would this be same as byte access?
    bne     m_s68k_read8_pcm

m_s68k_read16_regs:
    bic     r0, r0, #0xff0000
    bic     r0, r0, #0x008000
    bic     r0, r0, #0x000001
    cmp     r0, #8
    bne     s68k_reg_read16
    mov     r0, #1
    b       cdc_host_r


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


.macro m_s68k_write8_2M_decode
    ldr     r2, =(Pico+0x22200)
    eor     r0, r0, #2
    ldr     r2, [r2]			@ Pico.rom
    movs    r0, r0, lsr #1              @ +4-6 <<16
    add     r2, r2, r3                  @ map to our address
.endm

PicoWriteS68k8_dec_m2b0:                @ overwrite
    ands    r1, r1, #0x0f
    bxeq    lr

PicoWriteS68k8_dec_m0b0:
    mov     r3, #0x080000
    b       0f

PicoWriteS68k8_dec_m2b1:                @ overwrite
    ands    r1, r1, #0x0f
    bxeq    lr

PicoWriteS68k8_dec_m0b1:
    mov     r3, #0x0a0000
0:
    m_s68k_write8_2M_decode
    ldrb    r0, [r2, r0]!
    and     r1, r1, #0x0f
    movcc   r1, r1, lsl #4
    andcc   r3, r0, #0x0f
    andcs   r3, r0, #0xf0
    orr     r3, r3, r1
    strneb  r3, [r2]
    bx      lr

PicoWriteS68k8_dec_m1b0:                @ underwrite
    mov     r3, #0x080000
    b       0f

PicoWriteS68k8_dec_m1b1:
    mov     r3, #0x0a0000
0:
    ands    r1, r1, #0x0f
    bxeq    lr
    m_s68k_write8_2M_decode
    ldrb    r0, [r2, r0]!
    movcc   r1, r1, lsl #4
    andcc   r3, r0, #0x0f
    andcs   r3, r0, #0xf0
    teq     r3, r0
    bxne    lr
    orr     r3, r3, r1
    strneb  r3, [r2]
    bx      lr


PicoWriteS68k8_pr:
    and     r2, r0, #0xfe00
    cmp     r2, #0x8000
    bne     m_s68k_write8_pcm

m_s68k_write8_regs:
    bic     r0, r0, #0xff0000
    bic     r0, r0, #0x008000
    tst     r0, #0x7e00
    movne   r0, #0
    bxne    lr
    sub     r2, r0, #0x59
    cmp     r2, #0x0f
    bhs     s68k_reg_write8
    bic     r0, r0, #1
    orr     r1, r1, r1, lsl #8
    b       s68k_reg_write16


m_s68k_write8_pcm:
    tst     r0, #0x8000
    bxne    lr
    bic     r0, r0, #0xff0000
    cmp     r0, #0x12
    movlt   r0, r0, lsr #1
    blt     pcd_pcm_write

    cmp     r0, #0x2000
    bxlt    lr

m_s68k_write8_pcm_ram:
    ldr     r3, =(Pico+0x22200)
    bic     r0, r0, #0x00e000
    ldr     r3, [r3]
    mov     r0, r0, lsr #1
    add     r2, r3, #0x110000
    add     r2, r2, #0x002200
    add     r2, r2, #0x000040
    ldr     r2, [r2]
    add     r3, r3, #0x100000           @ pcm_ram
    and     r2, r2, #0x0f000000         @ bank
    add     r3, r3, r2, lsr #12
    strb    r1, [r3, r0]
    bx      lr


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


.macro m_s68k_write16_2M_decode
    ldr     r2, =(Pico+0x22200)
    eor     r0, r0, #2
    ldr     r2, [r2]
    mov     r0, r0, lsr #1              @ +4-6 <<16
    add     r2, r2, r3                  @ map to our address
.endm

PicoWriteS68k16_dec_m0b0:
    mov     r3, #0x080000
    b       0f

PicoWriteS68k16_dec_m0b1:
    mov     r3, #0x0a0000
0:
    m_s68k_write16_2M_decode
    bic     r1, r1, #0xf0
    orr     r1, r1, r1, lsr #4
    strb    r1, [r2, r0]
    bx      lr

PicoWriteS68k16_dec_m1b0:               @ underwrite
    mov     r3, #0x080000
    b       0f

PicoWriteS68k16_dec_m1b1:
    mov     r3, #0x0a0000
0:
    bics    r1, r1, #0xf000
    bicnes  r1, r1, #0x00f0
    bxeq    lr
    orr     r1, r1, r1, lsr #4
    m_s68k_write16_2M_decode
    ldrb    r0, [r2, r0]!
    and     r3, r1, #0x0f
    and     r1, r1, #0xf0
    tst     r0, #0x0f
    orreq   r0, r0, r3
    tst     r0, #0xf0
    orreq   r0, r0, r1
    strb    r0, [r2]
    bx      lr

PicoWriteS68k16_dec_m2b0:               @ overwrite
    mov     r3, #0x080000
    b       0f

PicoWriteS68k16_dec_m2b1:
    mov     r3, #0x0a0000
0:
    bics    r1, r1, #0xf000
    bicnes  r1, r1, #0x00f0
    bxeq    lr
    orr     r1, r1, r1, lsr #4
    m_s68k_write16_2M_decode
    ldrb    r0, [r2, r0]!
    ands    r3, r1, #0x0f
    andne   r0, r0, #0xf0
    orrne   r0, r0, r3
    ands    r1, r1, #0xf0
    andne   r0, r0, #0x0f
    orrne   r0, r0, r1
    strb    r0, [r2]
    bx      lr


PicoWriteS68k16_pr:
    and     r2, r0, #0xfe00
    cmp     r2, #0x8000
    bne     m_s68k_write8_pcm

m_s68k_write16_regs:
    bic     r0, r0, #0xff0000
    bic     r0, r0, #0x008000
    bic     r0, r0, #1
    tst     r0, #0x7e00
    movne   r0, #0
    bxne    lr
    cmp     r0, #0x0e
    bne     s68k_reg_write16

m_s68k_write16_regs_spec:               @ special case
    ldr     r2, =(Pico+0x22200)
    mov     r0, #0x110000
    ldr     r2, [r2]
    add     r0, r0, #0x00000f
    strb    r1, [r2, r0]                @ if (a == 0xe) s68k_regs[0xf] = d;
    bx      lr

.pool

@ vim:filetype=armasm
#endif
