#ifdef __arm__
@*
@* Compiler helper functions and some SVP HLE code
@* (C) notaz, 2008,2009
@*
@* This work is licensed under the terms of MAME license.
@* See COPYING file in the top-level directory.
@*

#include "../../arm_features.h"

.syntax unified
.text
.align 2

@       SSP_GR0, SSP_X,     SSP_Y,   SSP_A,
@       SSP_ST,  SSP_STACK, SSP_PC,  SSP_P,
@       SSP_PM0, SSP_PM1,   SSP_PM2, SSP_XST,
@       SSP_PM4, SSP_gr13,  SSP_PMC, SSP_AL

@ register map:
@ r4:  XXYY
@ r5:  A
@ r6:  STACK and emu flags: sss0 * .uu. .lll NZCV (NZCV is PSR bits from ARM)
@ r7:  SSP context
@ r8:  r0-r2 (.210)
@ r9:  r4-r6 (.654)
@ r10: P
@ r11: cycles
@ r12: tmp


#define SSP_OFFS_GR         0x400
#define SSP_PC                  6
#define SSP_P                   7
#define SSP_PM0                 8
#define SSP_PMC                14
#define SSP_OFFS_PM_WRITE   0x46c // pmac_write[]
#define SSP_OFFS_EMUSTAT    0x484 // emu_status
#define SSP_OFFS_IRAM_ROM   0x48c // ptr_iram_rom
#define SSP_OFFS_DRAM       0x490 // ptr_dram
#define SSP_OFFS_IRAM_DIRTY 0x494
#define SSP_OFFS_IRAM_CTX   0x498 // iram_context
#define SSP_OFFS_BLTAB      0x49c // block_table
#define SSP_OFFS_BLTAB_IRAM 0x4a0
#define SSP_OFFS_TMP0       0x4a4 // for entry PC
#define SSP_OFFS_TMP1       0x4a8
#define SSP_OFFS_TMP2       0x4ac
#define SSP_WAIT_PM0       0x2000


.macro ssp_drc_do_next patch_jump=0
.if \patch_jump
    str     lr, [r7, #SSP_OFFS_TMP2]		@ jump instr. (actually call) address + 4
.endif
    mov     r0, r0, lsl #16
    mov     r0, r0, lsr #16
    str     r0, [r7, #SSP_OFFS_TMP0]
    cmp     r0, #0x400
    blt     0f @ ssp_de_iram

    ldr     r2, [r7, #SSP_OFFS_BLTAB]
    ldr     r2, [r2, r0, lsl #2]
    tst     r2, r2
.if \patch_jump
    bne     ssp_drc_do_patch
.else
    bxne    r2
.endif
    bl      ssp_translate_block
    mov     r2, r0
    ldr     r0, [r7, #SSP_OFFS_TMP0]		@ entry PC
    ldr     r1, [r7, #SSP_OFFS_BLTAB]
    str     r2, [r1, r0, lsl #2]
.if \patch_jump
    b       ssp_drc_do_patch
.else
    bx      r2
.endif

0: @ ssp_de_iram:
    ldr     r1, [r7, #SSP_OFFS_IRAM_DIRTY]
    tst     r1, r1
    ldreq   r1, [r7, #SSP_OFFS_IRAM_CTX]
    beq     1f @ ssp_de_iram_ctx

    bl      ssp_get_iram_context
    mov     r1, #0
    str     r1, [r7, #SSP_OFFS_IRAM_DIRTY]
    mov     r1, r0
    str     r1, [r7, #SSP_OFFS_IRAM_CTX]
    ldr     r0, [r7, #SSP_OFFS_TMP0]		@ entry PC
    
1: @ ssp_de_iram_ctx:
    ldr     r2, [r7, #SSP_OFFS_BLTAB_IRAM]
    add     r2, r2, r1, lsl #12			@ block_tab_iram + iram_context * 0x800/2*4
    add     r1, r2, r0, lsl #2
    ldr     r2, [r1]
    tst     r2, r2
.if \patch_jump
    bne     ssp_drc_do_patch
.else
    bxne    r2
.endif
    str     r1, [r7, #SSP_OFFS_TMP1]
    bl      ssp_translate_block
    mov     r2, r0
    ldr     r0, [r7, #SSP_OFFS_TMP0]		@ entry PC
    ldr     r1, [r7, #SSP_OFFS_TMP1]		@ &block_table_iram[iram_context][rPC]
    str     r2, [r1]
.if \patch_jump
    b       ssp_drc_do_patch
.else
    bx      r2
.endif
.endm @ ssp_drc_do_next


FUNCTION(ssp_drc_entry):
    stmfd   sp!, {r4-r11, lr}
    mov     r7, r0                      @ ssp
    mov     r11, r1
ssp_regfile_load:
    add     r2, r7, #0x400
    add     r2, r2, #4
    ldmia   r2, {r3,r4,r5,r6,r8}
    mov     r3, r3, lsr #16
    mov     r3, r3, lsl #16
    orr     r4, r3, r4, lsr #16         @ XXYY

    and     r8, r8, #0x0f0000
    mov     r8, r8, lsl #13             @ sss0 *
    and     r9, r6, #0x670000
    tst     r6,     #0x80000000
    orrne   r8, r8, #0x8
    tst     r6,     #0x20000000
    orrne   r8, r8, #0x4                @ sss0 *           NZ..
    orr     r6, r8, r9, lsr #12         @ sss0 * .uu. .lll NZ..

    ldr     r8, [r7, #0x440]            @ r0-r2
    ldr     r9, [r7, #0x444]            @ r4-r6
    ldr     r10,[r7, #(0x400+SSP_P*4)]  @ P

    ldr     r0, [r7, #(SSP_OFFS_GR+SSP_PC*4)]
    mov     r0, r0, lsr #16


FUNCTION(ssp_drc_next):
    ssp_drc_do_next 0


FUNCTION(ssp_drc_next_patch):
    ssp_drc_do_next 1

ssp_drc_do_patch:
    ldr     r1, [r7, #SSP_OFFS_TMP2]	@ jump instr. (actually call) address + 4
    subs    r12,r2, r1
    moveq   r3,     #0xe1000000
    orreq   r3, r3, #0x00a00000		@ nop
    streq   r3, [r1, #-4]
    beq     ssp_drc_dp_end

    cmp     r12,#4
    ldreq   r3, [r1]
    addeq   r3, r3, #1
    streq   r3, [r1, #-4]               @ move the other cond up
    moveq   r3,     #0xe1000000
    orreq   r3, r3, #0x00a00000
    streq   r3, [r1]                    @ fill it's place with nop
    beq     ssp_drc_dp_end

    ldr     r3, [r1, #-4]
    sub     r12,r12,#4
    mov     r3, r3, lsr #24
    bic     r3, r3, #1			@ L bit
    orr     r3, r3, r12,lsl #6
    mov     r3, r3, ror #8              @ patched branch instruction
    str     r3, [r1, #-4]               @ patch the bl/b to jump directly to another handler

ssp_drc_dp_end:
    str     r2, [r7, #SSP_OFFS_TMP1]
    sub     r0, r1, #4
    add     r1, r1, #4
    bl      cache_flush_d_inval_i
    ldr     r2, [r7, #SSP_OFFS_TMP1]
    ldr     r0, [r7, #SSP_OFFS_TMP0]
    bx      r2


FUNCTION(ssp_drc_end):
    mov     r0, r0, lsl #16
    str     r0, [r7, #(SSP_OFFS_GR+SSP_PC*4)]

ssp_regfile_store:
    str     r10,[r7, #(0x400+SSP_P*4)]  @ P
    str     r8, [r7, #0x440]            @ r0-r2
    str     r9, [r7, #0x444]            @ r4-r6

    mov     r9, r6, lsr #13
    and     r9, r9, #(7<<16)            @ STACK
    mov     r3, r6, lsl #28
    msr     cpsr_f, r3                  @ to to ARM PSR
    and     r6, r6, #0x670
    mov     r6, r6, lsl #12
    orrmi   r6, r6, #0x80000000         @ N
    orreq   r6, r6, #0x20000000         @ Z

    mov     r3, r4, lsl #16             @ Y
    mov     r2, r4, lsr #16
    mov     r2, r2, lsl #16             @ X
    add     r8, r7, #0x400
    add     r8, r8, #4
    stmia   r8, {r2,r3,r5,r6,r9}

    mov     r0, r11
    ldmfd   sp!, {r4-r11, lr}
    bx      lr



@ ld      A, PM0
@ andi    2
@ bra     z=1, gloc_0800
FUNCTION(ssp_hle_800):
    ldr     r0, [r7, #(SSP_OFFS_GR+SSP_PM0*4)]
    ldr     r1, [r7, #SSP_OFFS_EMUSTAT]
    tst     r0, #0x20000
    orreq   r1, r1,  #SSP_WAIT_PM0
    subeq   r11,r11, #1024
    streq   r1, [r7, #SSP_OFFS_EMUSTAT]
    mov     r0,     #0x400
    beq     ssp_drc_end
    orrne   r0, r0, #0x004
    b       ssp_drc_next


.macro hle_flushflags
    bic     r6, r6, #0xf
    mrs     r1, cpsr
    orr     r6, r6, r1, lsr #28 
.endm

.macro hle_popstack
    sub     r6, r6, #0x20000000
    add     r1, r7, #0x400
    add     r1, r1, #0x048			@ stack
    add     r1, r1, r6, lsr #28
    ldrh    r0, [r1]
.endm

FUNCTION(ssp_hle_902):
    cmp     r11, #0
    ble     ssp_drc_end

    add     r1, r7, #0x200
    ldrh    r0, [r1]
    ldr     r3, [r7, #SSP_OFFS_IRAM_ROM]
    add     r2, r3, r0, lsl #1			@ (r7|00)
    ldrh    r0, [r2], #2
    mov     r5, r5, lsl #16
    mov     r5, r5, lsr #16
    bic     r0, r0, #0xfc00
    add     r3, r3, r0, lsl #1 			@ IRAM dest
    ldrh    r12,[r2], #2			@ length
    bic     r3, r3, #3				@ always seen aligned
@    orr     r5, r5, #0x08000000
@    orr     r5, r5, #0x00880000
@    sub     r5, r5, r12, lsl #16
    bic     r6, r6, #0xf
    add     r12,r12,#1
    mov     r0, #1
    str     r0, [r7, #SSP_OFFS_IRAM_DIRTY]
    sub     r11,r11,r12,lsl #1
    sub     r11,r11,r12				@ -= length*3

ssp_hle_902_loop:
    ldrh    r0, [r2], #2
    ldrh    r1, [r2], #2
    subs    r12,r12,#2
    orr     r0, r0, r1, lsl #16
    str     r0, [r3], #4
    bgt     ssp_hle_902_loop

    tst     r12, #1
    ldrhne  r0, [r2], #2
    strhne  r0, [r3], #2

    ldr     r0, [r7, #SSP_OFFS_IRAM_ROM]
    add     r1, r7, #0x200
    sub     r2, r2, r0
    mov     r2, r2, lsr #1
    strh    r2, [r1]				@ (r7|00)

    sub     r0, r3, r0
    mov     r0, r0, lsr #1
    orr     r0, r0, #0x08000000
    orr     r0, r0, #0x001c8000
    str     r0, [r7, #(SSP_OFFS_GR+SSP_PMC*4)]
    str     r0, [r7, #(SSP_OFFS_PM_WRITE+4*4)]

    hle_popstack
    subs    r11,r11,#16				@ timeslice is likely to end
    ble     ssp_drc_end
    b       ssp_drc_next


@ this one is car rendering related
.macro hle_11_12c_mla offs_in
    ldrsh   r5, [r7, #(\offs_in+0)]
    ldrsh   r0, [r7, #(\offs_in+2)]
    ldrsh   r1, [r7, #(\offs_in+4)]
    mul     r5, r2, r5
    ldrsh   r12,[r7, #(\offs_in+6)]
    mla     r5, r3, r0, r5
    mla     r5, r4, r1, r5
    add     r5, r5, r12,lsl #11

    movs    r5, r5, lsr #13
    add     r1, r7, r8, lsr #23
    strh    r5, [r1]
    add     r8, r8, #(1<<24)
.endm

FUNCTION(ssp_hle_11_12c):
    cmp     r11, #0
    ble     ssp_drc_end

    mov     r0, #0
    bl      ssp_pm_read
    mov     r4, r0

    mov     r0, #0
    bl      ssp_pm_read
    mov     r5, r0

    mov     r0, #0
    bl      ssp_pm_read

    mov     r2, r4, lsl #16
    mov     r2, r2, asr #15			@ (r7|00) << 1
    mov     r3, r5, lsl #16
    mov     r3, r3, asr #15			@ (r7|01) << 1
    mov     r4, r0, lsl #16
    mov     r4, r4, asr #15			@ (r7|10) << 1

    bic     r8, r8, #0xff
    mov     r8, r8, ror #16

    hle_11_12c_mla 0x20
    hle_11_12c_mla 0x28
    hle_11_12c_mla 0x30

    mov     r8, r8, ror #16
    orr     r8, r8, #0x1c
@    hle_flushflags
    hle_popstack
    sub     r11,r11,#33
    b       ssp_drc_next


FUNCTION(ssp_hle_11_384):
    mov     r3, #2
    b       ssp_hle_11_38x

FUNCTION(ssp_hle_11_38a):
    mov     r3, #3		@ r5

ssp_hle_11_38x:
    cmp     r11, #0
    ble     ssp_drc_end

    mov     r2, #0		@ EFh, EEh
    mov     r1, #1		@ r4
    add     r0, r7, #0x1c0	@ r0 (based)

ssp_hle_11_38x_loop:
    ldrh    r5, [r0], #2
    ldr     r12,[r7, #0x224]
    mov     r5, r5, lsl #16
    eor     r5, r5, r5, asr #31
    add     r5, r5, r5, lsr #31	@ abs(r5)
    cmp     r5, r12,lsl #16
    orrpl   r2, r2, r1,lsl #16	@ EFh |= r4

    ldrh    r5, [r0, #2]!
    ldr     r12,[r7, #0x220]
    cmp     r5, r12,lsr #16
    orrpl   r2, r2, r1,lsl #16	@ EFh |= r4

    ldr     r12,[r7, #0x1e8]
    add     r0, r0, #2
    mov     r12,r12,lsl #16
    cmp     r5, r12,lsr #16
    orrmi   r2, r2, r1

    mov     r1, r1, lsl #1
    subs    r3, r3, #1
    bpl     ssp_hle_11_38x_loop

    str     r2, [r7, #0x1dc]
    sub     r0, r0, r7
    bic     r8, r8, #0xff
    orr     r8, r8, r0, lsr #1
    bic     r9, r9, #0xff
    orr     r9, r9, r1

@    hle_flushflags
    hle_popstack
    sub     r11,r11,#(9+30*4)
    b       ssp_drc_next


FUNCTION(ssp_hle_07_6d6):
    cmp     r11, #0
    ble     ssp_drc_end

    ldr     r1, [r7, #0x20c]
    and     r0, r8, #0xff	@ assuming alignment
    add     r0, r7, r0, lsl #1
    mov     r2, r1, lsr #16
    mov     r1, r1, lsl #16	@ 106h << 16
    mov     r2, r2, lsl #16	@ 107h << 16

ssp_hle_07_6d6_loop:
    ldr     r5, [r0], #4
    tst     r5, r5
    bmi     ssp_hle_07_6d6_end
    mov     r5, r5, lsl #16
    cmp     r5, r1
    movmi   r1, r5
    cmp     r5, r2
    sub     r11,r11,#16
    bmi     ssp_hle_07_6d6_loop
    mov     r2, r5
    b       ssp_hle_07_6d6_loop

ssp_hle_07_6d6_end:
    sub     r0, r0, r7
    mov     r0, r0, lsr #1
    bic     r8, r8, #0xff
    orr     r8, r8, r0
    orr     r1, r2, r1, lsr #16
    str     r1, [r7, #0x20c]
    hle_popstack
    sub     r11,r11,#6
    b       ssp_drc_next


FUNCTION(ssp_hle_07_030):
    ldrh    r0, [r7]
    mov     r0, r0, lsl #4
    orr     r0, r0, r0, lsr #16
    strh    r0, [r7]
    sub     r11,r11,#3

FUNCTION(ssp_hle_07_036):
    ldr     r1, [r7, #0x1e0]	@ F1h F0h
    rsb     r5, r1, r1, lsr #16
    mov     r5, r5, lsl #16	@ AL not needed
    cmp     r5, #(4<<16)
    sub     r11,r11,#5
    bmi     hle_07_036_ending2
    ldr     r1, [r7, #0x1dc]	@ EEh
    cmp     r5, r1, lsl #16
    sub     r11,r11,#5
    bpl     hle_07_036_ret

    mov     r0, r5, lsr #16
    add     r1, r7, #0x100
    strh    r0, [r1, #0xea]	@ F5h
    ldr     r0, [r7, #0x1e0]	@ F0h
    and     r0, r0, #3
    strh    r0, [r1, #0xf0]	@ F8h
    add     r2, r0, #0xc0	@ r2
    add     r2, r7, r2, lsl #1
    ldrh    r2, [r2]
    ldr     r0, [r7]
    mov     r1, #4
    and     r0, r0, r2
    bl      ssp_pm_write
    @ will handle PMC later
    ldr     r0, [r7, #0x1e8]	@ F5h << 16
    ldr     r1, [r7, #0x1f0]	@ F8h
    ldr     r2, [r7, #0x1d4]	@ EAh
    sub     r0, r0, #(3<<16)
    add     r0, r0, r1, lsl #16
    sub     r0, r2, r0, asr #18
    and     r0, r0, #0x7f
    rsbs    r0, r0, #0x78	@ length
    ble     hle_07_036_ending1

    sub     r11,r11,r0

    @ copy part
    ldr     r1, [r7, #(SSP_OFFS_GR+SSP_PMC*4)]
    ldr     r2, [r7, #SSP_OFFS_DRAM]
    mov     r1, r1, lsl #16
    add     r1, r2, r1, lsr #15	@ addr (based)
    ldrh    r2, [r7, #0]	@ pattern
    ldrh    r3, [r7, #6]	@ mode

    mov     r12,    #0x4000
    orr     r12,r12,#0x0018
    subs    r12,r3, r12
    subsne  r12,r12,#0x0400
    blne    tr_unhandled

    orr     r2, r2, r2, lsl #16
    tst     r3, #0x400
    bne     hle_07_036_ovrwr

hle_07_036_no_ovrwr:
    tst     r1, #2
    strhne  r2, [r1], #0x3e	@ align
    subne   r0, r0, #1
    subs    r0, r0, #4
    blt     hle_07_036_l2

hle_07_036_l1:
    subs    r0, r0, #4
    str     r2, [r1], #0x40
    str     r2, [r1], #0x40
    bge     hle_07_036_l1

hle_07_036_l2:
    tst     r0, #2
    strne   r2, [r1], #0x40
    tst     r0, #1
    strhne  r2, [r1], #2
    b       hle_07_036_end_copy

hle_07_036_ovrwr:
    tst     r2,     #0x000f
    orreq   r12,r12,#0x000f
    tst     r2,     #0x00f0
    orreq   r12,r12,#0x00f0
    tst     r2,     #0x0f00
    orreq   r12,r12,#0x0f00
    tst     r2,     #0xf000
    orreq   r12,r12,#0xf000
    orrs    r12,r12,r12,lsl #16
    beq     hle_07_036_no_ovrwr

    tst     r1, #2
    beq     hle_07_036_ol0
    ldrh    r3, [r1]
    and     r3, r3, r12
    orr     r3, r3, r2
    strh    r3, [r1], #0x3e	@ align
    sub     r0, r0, #1

hle_07_036_ol0:
    subs    r0, r0, #2
    blt     hle_07_036_ol2

hle_07_036_ol1:
    subs    r0, r0, #2
    ldr     r3, [r1]
    and     r3, r3, r12
    orr     r3, r3, r2
    str     r3, [r1], #0x40
    bge     hle_07_036_ol1

hle_07_036_ol2:
    tst     r0, #1
    ldrhne  r3, [r1]
    andne   r3, r3, r12
    orrne   r3, r3, r2
    strhne  r3, [r1], #2

hle_07_036_end_copy:
    ldr     r2, [r7, #SSP_OFFS_DRAM]
    add     r3, r7, #0x400
    sub     r0, r1, r2          @ new addr
    mov     r0, r0, lsr #1
    strh    r0, [r3, #(0x6c+4*4)] @ SSP_OFFS_PM_WRITE+4*4 (low)

hle_07_036_ending1:
    ldr     r0, [r7, #0x1e0]	@ F1h << 16
    add     r0, r0, #(1<<16)
    and     r0, r0, #(3<<16)
    add     r0, r0, #(0xc4<<16)
    bic     r8, r8, #0xff0000
    orr     r8, r8, r0		@ r2
    add     r0, r7, r0, lsr #15
    ldrh    r0, [r0]
    ldr     r2, [r7]
    and     r0, r0, r2
    movs    r5, r0, lsl #16

    ldr     r1, [r7, #4]	@ new mode
    add     r2, r7, #0x400
    strh    r1, [r2, #(0x6c+4*4+2)] @ SSP_OFFS_PM_WRITE+4*4 (high)
    mov     r1, #4
    bl      ssp_pm_write
    sub     r11,r11,#35

hle_07_036_ret:
    hle_popstack
    b       ssp_drc_next

hle_07_036_ending2:
    sub     r11,r11,#3
    movs    r5, r5, lsl #1
    bmi     hle_07_036_ret
    mov     r0, #0x87
    b       ssp_drc_next	@ let the dispatcher finish this


@ ios stuff - preserving r9 on external calls
#ifdef __MACH__

#define APPLE_WRAP(f) \
  f:; \
  push {r9,lr}; \
  bl _##f; \
  pop {r9,pc}

APPLE_WRAP(cache_flush_d_inval_i)
APPLE_WRAP(ssp_get_iram_context)
APPLE_WRAP(ssp_pm_read)
APPLE_WRAP(ssp_pm_write)
APPLE_WRAP(ssp_translate_block)
APPLE_WRAP(tr_unhandled)

#endif

@ vim:filetype=armasm
#endif
