/*
 * PicoDrive 32X memory access functions, assembler version
 * (C) irixxxx, 2018-2021
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <pico/pico_int_offs.h>

@ 32X bank sizes... TODO this should somehow come from an include file
.equ SH2_ROM_SHIFT, 10      @ 0x003fffff
.equ SH2_RAM_SHIFT, 14      @ 0x0003ffff
.equ SH2_DRAM_SHIFT,15      @ 0x0001ffff
.equ SH2_DA_SHIFT,  20      @ 0x00000fff

.equ SH2_DRAM_OW, 1<<(32-SH2_DRAM_SHIFT) @ DRAM overwrite mode bit

.text
.align 5

#if 0
@ u32 a, SH2 *sh2
.global sh2_read8_rom
.global sh2_read8_sdram
.global sh2_read8_da
.global sh2_read8_dram
.global sh2_read16_rom
.global sh2_read16_sdram
.global sh2_read16_da
.global sh2_read16_dram
.global sh2_read32_rom
.global sh2_read32_sdram
.global sh2_read32_da
.global sh2_read32_dram
#endif

@ u32 a, u32 d, SH2 *sh2
.global sh2_write8_sdram
.global sh2_write8_da
.global sh2_write8_dram
.global sh2_write16_sdram
.global sh2_write16_da
.global sh2_write16_dram
.global sh2_write32_sdram
.global sh2_write32_da
.global sh2_write32_dram

#if 0
sh2_read8_rom:
    ldr     ip, [r1, #OFS_SH2_p_rom]
    eor     r0, r0, #1
    mov     r0, r0, lsl #SH2_ROM_SHIFT
    ldrb    r0, [ip, r0, lsr #SH2_ROM_SHIFT]
    bx      lr

sh2_read8_sdram:
    ldr     ip, [r1, #OFS_SH2_p_sdram]
    eor     r0, r0, #1
    mov     r0, r0, lsl #SH2_RAM_SHIFT
    ldrb    r0, [ip, r0, lsr #SH2_RAM_SHIFT]
    bx      lr

sh2_read8_da:
    ldr     ip, [r1, #OFS_SH2_p_da]
    eor     r0, r0, #1
    mov     r0, r0, lsl #SH2_DA_SHIFT
    ldrb    r0, [ip, r0, lsr #SH2_DA_SHIFT]
    bx      lr

sh2_read8_dram:
    ldr     ip, [r1, #OFS_SH2_p_dram]
    eor     r0, r0, #1
    mov     r0, r0, lsl #SH2_DRAM_SHIFT
    ldrb    r0, [ip, r0, lsr #SH2_DRAM_SHIFT]
    bx      lr

sh2_read16_rom:
    ldr     ip, [r1, #OFS_SH2_p_rom]
    mov     r0, r0, lsl #SH2_ROM_SHIFT
    mov     r0, r0, lsr #SH2_ROM_SHIFT
    ldrh    r0, [ip, r0]
    bx      lr

sh2_read16_sdram:
    ldr     ip, [r1, #OFS_SH2_p_sdram]
    mov     r0, r0, lsl #SH2_RAM_SHIFT
    mov     r0, r0, lsr #SH2_RAM_SHIFT
    ldrh    r0, [ip, r0]
    bx      lr

sh2_read16_da:
    ldr     ip, [r1, #OFS_SH2_p_da]
    mov     r0, r0, lsl #SH2_DA_SHIFT
    mov     r0, r0, lsr #SH2_DA_SHIFT
    ldrh    r0, [ip, r0]
    bx      lr

sh2_read16_dram:
    ldr     ip, [r1, #OFS_SH2_p_dram]
    mov     r0, r0, lsl #SH2_DRAM_SHIFT
    mov     r0, r0, lsr #SH2_DRAM_SHIFT
    ldrh    r0, [ip, r0]
    bx      lr

sh2_read32_rom:
    ldr     ip, [r1, #OFS_SH2_p_rom]
    mov     r0, r0, lsl #SH2_ROM_SHIFT
    ldr     r0, [ip, r0, lsr #SH2_ROM_SHIFT]
    mov     r0, r0, ror #16
    bx      lr

sh2_read32_sdram:
    ldr     ip, [r1, #OFS_SH2_p_sdram]
    mov     r0, r0, lsl #SH2_RAM_SHIFT
    ldr     r0, [ip, r0, lsr #SH2_RAM_SHIFT]
    mov     r0, r0, ror #16
    bx      lr

sh2_read32_da:
    ldr     ip, [r1, #OFS_SH2_p_da]
    mov     r0, r0, lsl #SH2_DA_SHIFT
    ldr     r0, [ip, r0, lsr #SH2_DA_SHIFT]
    mov     r0, r0, ror #16
    bx      lr

sh2_read32_dram:
    ldr     ip, [r1, #OFS_SH2_p_dram]
    mov     r0, r0, lsl #SH2_DRAM_SHIFT
    ldr     r0, [ip, r0, lsr #SH2_DRAM_SHIFT]
    mov     r0, r0, ror #16
    bx      lr
#endif

sh2_write8_sdram:
    @ preserve r0-r2 for tail call
    ldr     ip, [r2, #OFS_SH2_p_sdram]
    eor     r3, r0, #1
    mov     r3, r3, lsl #SH2_RAM_SHIFT
    strb    r1, [ip, r3, lsr #SH2_RAM_SHIFT]
#ifdef DRC_SH2
    ldr     r1, [r2, #OFS_SH2_p_drcblk_ram]
    ldrb    r3, [r1, r3, lsr #SH2_RAM_SHIFT+1]
    cmp     r3, #0
    bxeq    lr
    @ need to load aligned 16 bit data for check
    bic     r0, r0, #1
    mov     r1, r0, lsl #SH2_RAM_SHIFT
    mov     r1, r1, lsr #SH2_RAM_SHIFT
    ldrh    r1, [ip, r1]
    b       sh2_sdram_checks
#else
    bx      lr
#endif

sh2_write8_da:
    @ preserve r0 and r2 for tail call
    ldr     ip, [r2, #OFS_SH2_p_da]
    eor     r3, r0, #1
    mov     r3, r3, lsl #SH2_DA_SHIFT
    strb    r1, [ip, r3, lsr #SH2_DA_SHIFT]
#ifdef DRC_SH2
    ldr     ip, [r2, #OFS_SH2_p_drcblk_da]
    ldrb    r1, [ip, r3, lsr #SH2_DA_SHIFT+1]
    bic     r0, r0, #1
    cmp     r1, #0
    bxeq    lr
    mov     r1, #2
    b       sh2_drc_wcheck_da
#else
    bx      lr
#endif

sh2_write8_dram:
    tst     r1, #0xff
    ldrne   ip, [r2, #OFS_SH2_p_dram]
    eorne   r3, r0, #1
    movne   r3, r3, lsl #SH2_DRAM_SHIFT
    strneb  r1, [ip, r3, lsr #SH2_DRAM_SHIFT]
    bx      lr

sh2_write16_sdram:
    @ preserve r0-r2 for tail call
    ldr     ip, [r2, #OFS_SH2_p_sdram]
    mov     r3, r0, lsl #SH2_RAM_SHIFT
    mov     r3, r3, lsr #SH2_RAM_SHIFT
    strh    r1, [ip, r3]
#ifdef DRC_SH2
    ldr     ip, [r2, #OFS_SH2_p_drcblk_ram]
    ldrb    r3, [ip, r3, lsr #1]
    cmp     r3, #0
    bxeq    lr
    b       sh2_sdram_checks
#else
    bx      lr
#endif

sh2_write16_da:
    @ preserve r0 and r2 for tail call
    ldr     ip, [r2, #OFS_SH2_p_da]
    mov     r3, r0, lsl #SH2_DA_SHIFT
    mov     r3, r3, lsr #SH2_DA_SHIFT
    strh    r1, [ip, r3]
#ifdef DRC_SH2
    ldr     ip, [r2, #OFS_SH2_p_drcblk_da]
    ldrb    r1, [ip, r3, lsr #1]
    cmp     r1, #0
    bxeq    lr
    mov     r1, #2
    b       sh2_drc_wcheck_da
#else
    bx      lr
#endif

sh2_write16_dram:
    ldr     ip, [r2, #OFS_SH2_p_dram]
    tst     r0, #SH2_DRAM_OW
    mov     r3, r0, lsl #SH2_DRAM_SHIFT
    mov     r3, r3, lsr #SH2_DRAM_SHIFT
    streqh  r1, [ip, r3]
    bxeq    lr
    add     ip, ip, r3
    tst     r1, #0xff
    strneb  r1, [ip, #0]
    tst     r1, #0xff00
    movne   r1, r1, lsr #8
    strneb  r1, [ip, #1]
    bx      lr

sh2_write32_sdram:
    @ preserve r0-r2 for tail call
    ldr     ip, [r2, #OFS_SH2_p_sdram]
    mov     r1, r1, ror #16
    mov     r3, r0, lsl #SH2_RAM_SHIFT
    str     r1, [ip, r3, lsr #SH2_RAM_SHIFT]
#ifdef DRC_SH2
    ldr     ip, [r2, #OFS_SH2_p_drcblk_ram]
    ldrb    r3, [ip, r3, lsr #SH2_RAM_SHIFT+1]!
    ldrb    ip, [ip, #1]
    orrs    r3, r3, ip, lsl #16
    bxeq    lr
    mov     r1, r1, ror #16
    b       sh2_sdram_checks_l
#else
    bx      lr
#endif

sh2_write32_da:
    @ preserve r0 and r2 for tail call
    ldr     ip, [r2, #OFS_SH2_p_da]
    mov     r1, r1, ror #16
    mov     r3, r0, lsl #SH2_DA_SHIFT
    str     r1, [ip, r3, lsr #SH2_DA_SHIFT]
#ifdef DRC_SH2
    ldr     ip, [r2, #OFS_SH2_p_drcblk_da]
    ldrb    r1, [ip, r3, lsr #SH2_DA_SHIFT+1]!
    ldrb    ip, [ip, #1]
    orrs    r1, r1, ip, lsl #16
    bxeq    lr
    mov     r1, #4
    b       sh2_drc_wcheck_da
#else
    bx      lr
#endif

sh2_write32_dram:
    ldr     ip, [r2, #OFS_SH2_p_dram]
    tst     r0, #SH2_DRAM_OW
    mov     r3, r0, lsl #SH2_DRAM_SHIFT
    mov     r1, r1, ror #16
    streq   r1, [ip, r3, lsr #SH2_DRAM_SHIFT]
    bxeq    lr
    ldr     r0, [ip, r3, lsr #SH2_DRAM_SHIFT]
    tst     r1, #0x00ff0000
    bicne   r0, r0, #0x00ff0000
    tst     r1, #0xff000000
    bicne   r0, r0, #0xff000000
    tst     r1, #0x000000ff
    bicne   r0, r0, #0x000000ff
    tst     r1, #0x0000ff00
    bicne   r0, r0, #0x0000ff00
    orr     r0, r0, r1
    str     r0, [ip, r3, lsr #SH2_DRAM_SHIFT]
    bx      lr

.pool

@ vim:filetype=armasm
