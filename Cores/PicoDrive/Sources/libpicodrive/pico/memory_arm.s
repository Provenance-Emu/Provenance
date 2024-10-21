/*
 * PicoDrive
 * (C) notaz, 2006-2009
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "pico_int_o32.h"

.equ SRR_MAPPED,    (1 <<  0)
.equ SRR_READONLY,  (1 <<  1)
.equ SRF_EEPROM,    (1 <<  1)
.equ POPT_EN_32X,   (1 << 20)

.text
.align 4

.global PicoRead8_sram
.global PicoRead8_io
.global PicoRead16_sram
.global PicoRead16_io
.global PicoWrite8_io
.global PicoWrite16_io

PicoRead8_sram: @ u32 a
    ldr     r3, =Pico
    ldr     r1, [r3, #OFS_Pico_sv_end]
    cmp     r0, r1
    bgt     m_read8_nosram
    ldr     r2, [r3, #OFS_Pico_sv_start]
    cmp     r0, r2
    blt     m_read8_nosram
    ldrb    r1, [r3, #OFS_Pico_m_sram_reg]
    tst     r1, #SRR_MAPPED
    beq     m_read8_nosram
    ldr     r1, [r3, #OFS_Pico_sv_flags]
    tst     r1, #SRF_EEPROM
    bne     m_read8_eeprom
    ldr     r1, [r3, #OFS_Pico_sv_data]
    sub     r0, r0, r2
    ldrb    r0, [r0, r1]
    bx      lr

m_read8_nosram:
    ldr     r1, [r3, #OFS_Pico_romsize]
    cmp     r0, r1
    movgt   r0, #0
    bxgt    lr              @ bad location
    @ XXX: banking unfriendly
    ldr     r1, [r3, #OFS_Pico_rom]
    eor     r0, r0, #1
    ldrb    r0, [r1, r0]
    bx      lr

m_read8_eeprom:
    stmfd   sp!,{r0,lr}
    bl      EEPROM_read
    ldmfd   sp!,{r1,lr}
    tst     r1, #1
    moveq   r0, r0, lsr #8
    bx      lr


PicoRead8_io: @ u32 a
    bic     r2, r0, #0x001f   @ most commonly we get i/o port read,
    cmp     r2, #0xa10000     @ so check for it first
    beq     io_ports_read

m_read8_not_io:
    and     r2, r0, #0xfc00
    cmp     r2, #0x1000
    bne     PicoRead8_32x

    ldr     r3, =Pico
    mov     r1, r0
    ldr     r0, [r3, #OFS_Pico_m_rotate]
    add     r0, r0, #1
    strb    r0, [r3, #OFS_Pico_m_rotate]
    eor     r0, r0, r0, lsl #6

    tst     r1, #1
    bxne    lr                @ odd addr -> open bus
    bic     r0, r0, #1        @ bit0 defined in this area
    and     r2, r1, #0xff00
    cmp     r2, #0x1100
    bxne    lr                @ not busreq

    ldrb    r1, [r3, #OFS_Pico_m_z80Run]
    ldrb    r2, [r3, #OFS_Pico_m_z80_reset]
    orr     r0, r0, r1
    orr     r0, r0, r2
    bx      lr

@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

PicoRead16_sram: @ u32 a, u32 d
    ldr     r3, =Pico
    ldr     r1, [r3, #OFS_Pico_sv_end]
    cmp     r0, r1
    bgt     m_read16_nosram
    ldr     r2, [r3, #OFS_Pico_sv_start]
    cmp     r0, r2
    blt     m_read16_nosram
    ldrb    r1, [r3, #OFS_Pico_m_sram_reg]
    tst     r1, #SRR_MAPPED
    beq     m_read16_nosram
    ldr     r1, [r3, #OFS_Pico_sv_flags]
    tst     r1, #SRF_EEPROM
    bne     EEPROM_read
    ldr     r1, [r3, #OFS_Pico_sv_data]
    sub     r0, r0, r2
    ldrb    r1, [r0, r1]!
    ldrb    r0, [r0, #1]
    orr     r0, r0, r1, lsl #8
    bx      lr

m_read16_nosram:
    ldr     r1, [r3, #OFS_Pico_romsize]
    cmp     r0, r1
    movgt   r0, #0
    bxgt    lr              @ bad location
    @ XXX: banking unfriendly
    ldr     r1, [r3, #OFS_Pico_rom]
    ldrh    r0, [r1, r0]
    bx      lr


PicoRead16_io: @ u32 a, u32 d
    bic     r2, r0, #0x001f   @ most commonly we get i/o port read,
    cmp     r2, #0xa10000     @ so check for it first
    bne     m_read16_not_io
    stmfd   sp!,{lr}
    bl      io_ports_read     @ same as read8
    orr     r0, r0, r0, lsl #8 @ only has bytes mirrored
    ldmfd   sp!,{pc}

m_read16_not_io:
    and     r2, r0, #0xfc00
    cmp     r2, #0x1000
    bne     PicoRead16_32x

    ldr     r3, =Pico
    and     r2, r0, #0xff00
    ldr     r0, [r3, #OFS_Pico_m_rotate]
    add     r0, r0, #1
    strb    r0, [r3, #OFS_Pico_m_rotate]
    eor     r0, r0, r0, lsl #5
    eor     r0, r0, r0, lsl #8
    bic     r0, r0, #0x100    @ bit8 defined in this area
    cmp     r2, #0x1100
    bxne    lr                @ not busreq

    ldrb    r1, [r3, #OFS_Pico_m_z80Run]
    ldrb    r2, [r3, #OFS_Pico_m_z80_reset]
    orr     r0, r0, r1, lsl #8
    orr     r0, r0, r2, lsl #8
    bx      lr

@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

PicoWrite8_io: @ u32 a, u32 d
    bic     r2, r0, #0x1e       @ most commonly we get i/o port write,
    eor     r2, r2, #0xa10000   @ so check for it first
    eors    r2, r2, #1
    beq     io_ports_write

m_write8_not_io:
    tst     r0, #1
    bne     m_write8_not_z80ctl @ even addrs only
    and     r2, r0, #0xff00
    cmp     r2, #0x1100
    moveq   r0, r1
    beq     ctl_write_z80busreq
    cmp     r2, #0x1200
    moveq   r0, r1
    beq     ctl_write_z80reset

m_write8_not_z80ctl:
    @ unlikely
    eor     r2, r0, #0xa10000
    eor     r2, r2, #0x003000
    eors    r2, r2, #0x0000f1
    bne     PicoWrite8_32x
    ldr     r3, =Pico
    ldrb    r2, [r3, #OFS_Pico_m_sram_reg]
    and     r1, r1, #(SRR_MAPPED|SRR_READONLY)
    bic     r2, r2, #(SRR_MAPPED|SRR_READONLY)
    orr     r2, r2, r1
    strb    r2, [r3, #OFS_Pico_m_sram_reg]
    bx      lr

@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

PicoWrite16_io: @ u32 a, u32 d
    bic     r2, r0, #0x1f    @ most commonly we get i/o port write,
    cmp     r2, #0xa10000    @ so check for it first
    beq     io_ports_write

m_write16_not_io:
    and     r2, r0, #0xff00
    cmp     r2, #0x1100
    moveq   r0, r1, lsr #8
    beq     ctl_write_z80busreq
    cmp     r2, #0x1200
    moveq   r0, r1, lsr #8
    beq     ctl_write_z80reset

m_write16_not_z80ctl:
    @ unlikely
    eor     r2, r0, #0xa10000
    eor     r2, r2, #0x003000
    eors    r2, r2, #0x0000f0
    bne     PicoWrite16_32x
    ldr     r3, =Pico
    ldrb    r2, [r3, #OFS_Pico_m_sram_reg]
    and     r1, r1, #(SRR_MAPPED|SRR_READONLY)
    bic     r2, r2, #(SRR_MAPPED|SRR_READONLY)
    orr     r2, r2, r1
    strb    r2, [r3, #OFS_Pico_m_sram_reg]
    bx      lr

.pool

@ vim:filetype=armasm
