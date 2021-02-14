/*
 * PicoDrive
 * (C) notaz, 2006
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

@ this is a rewrite of MAME's ym2612 code, in particular this is only the main sample-generatin loop.
@ it does not seem to give much performance increase (if any at all), so don't use it if it causes trouble.
@ - notaz, 2006

@ vim:filetype=armasm

.equiv SLOT1, 0
.equiv SLOT2, 2
.equiv SLOT3, 1
.equiv SLOT4, 3
.equiv SLOT_STRUCT_SIZE, 0x30

.equiv TL_TAB_LEN, 0x1A00

.equiv EG_ATT, 4
.equiv EG_DEC, 3
.equiv EG_SUS, 2
.equiv EG_REL, 1
.equiv EG_OFF, 0

.equiv EG_SH,			  16             @ 16.16 fixed point (envelope generator timing)
.equiv EG_TIMER_OVERFLOW, (3*(1<<EG_SH)) @ envelope generator timer overflows every 3 samples (on real chip)
.equiv LFO_SH,            25  /*  7.25 fixed point (LFO calculations)       */

.equiv ENV_QUIET,		  (2*13*256/8)/2


@ r5=slot, r1=eg_cnt, trashes: r0,r2,r3
@ writes output to routp, but only if vol_out changes
.macro update_eg_phase_slot slot
    ldrb    r2, [r5,#0x17]	     @ state
    mov     r3, #1               @ 1ci
    cmp     r2, #1
    blt     5f                   @ EG_OFF
    beq     3f                   @ EG_REL
    cmp     r2, #3
    blt     2f                   @ EG_SUS
    beq     1f                   @ EG_DEC

0:  @ EG_ATT
    ldr     r2, [r5,#0x20]       @ eg_pack_ar (1ci)
    mov     r0, r2, lsr #24
    mov     r3, r3, lsl r0
    sub     r3, r3, #1
    tst     r1, r3
    bne     5f                   @ do smth for tl problem (set on init?)
    mov     r3, r1, lsr r0
    ldrh    r0, [r5,#0x1a]	     @ volume, unsigned (0-1023)
    and     r3, r3, #7
    add     r3, r3, r3, lsl #1
    mov     r3, r2, lsr r3
    and     r3, r3, #7           @ shift for eg_inc calculation
    mvn     r2, r0
    mov     r2, r2, lsl r3
    add     r0, r0, r2, asr #5
    cmp     r0, #0               @ if (volume <= MIN_ATT_INDEX)
    movle   r3, #EG_DEC
    strleb  r3, [r5,#0x17]       @ state
    movle   r0, #0
    b       4f

1:  @ EG_DEC
    ldr     r2, [r5,#0x24]       @ eg_pack_d1r (1ci)
    mov     r0, r2, lsr #24
    mov     r3, r3, lsl r0
    sub     r3, r3, #1
    tst     r1, r3
    bne     5f                   @ do smth for tl problem (set on init?)
    mov     r3, r1, lsr r0
    ldrh    r0, [r5,#0x1a]       @ volume
    and     r3, r3, #7
    add     r3, r3, r3, lsl #1
    mov     r3, r2, lsr r3
    and     r3, r3, #7           @ shift for eg_inc calculation
    mov     r2, #1
    mov     r3, r2, lsl r3
    ldr     r2, [r5,#0x1c]       @ sl (can be 16bit?)
    add     r0, r0, r3, asr #1
    cmp     r0, r2               @ if ( volume >= (INT32) SLOT->sl )
    movge   r3, #EG_SUS
    strgeb  r3, [r5,#0x17]       @ state
    b       4f

2:  @ EG_SUS
    ldr     r2, [r5,#0x28]       @ eg_pack_d2r (1ci)
    mov     r0, r2, lsr #24
    mov     r3, r3, lsl r0
    sub     r3, r3, #1
    tst     r1, r3
    bne     5f                   @ do smth for tl problem (set on init?)
    mov     r3, r1, lsr r0
    ldrh    r0, [r5,#0x1a]       @ volume
    and     r3, r3, #7
    add     r3, r3, r3, lsl #1
    mov     r3, r2, lsr r3
    and     r3, r3, #7           @ shift for eg_inc calculation
    mov     r2, #1
    mov     r3, r2, lsl r3
    add     r0, r0, r3, asr #1
    mov     r2, #1024
    sub     r2, r2, #1           @ r2 = MAX_ATT_INDEX
    cmp     r0, r2               @ if ( volume >= MAX_ATT_INDEX )
    movge   r0, r2
    b       4f

3:  @ EG_REL
    ldr     r2, [r5,#0x2c]       @ eg_pack_rr (1ci)
    mov     r0, r2, lsr #24
    mov     r3, r3, lsl r0
    sub     r3, r3, #1
    tst     r1, r3
    bne     5f                   @ do smth for tl problem (set on init?)
    mov     r3, r1, lsr r0
    ldrh    r0, [r5,#0x1a]       @ volume
    and     r3, r3, #7
    add     r3, r3, r3, lsl #1
    mov     r3, r2, lsr r3
    and     r3, r3, #7           @ shift for eg_inc calculation
    mov     r2, #1
    mov     r3, r2, lsl r3
    add     r0, r0, r3, asr #1
    mov     r2, #1024
    sub     r2, r2, #1           @ r2 = MAX_ATT_INDEX
    cmp     r0, r2               @ if ( volume >= MAX_ATT_INDEX )
    movge   r0, r2
    movge   r3, #EG_OFF
    strgeb  r3, [r5,#0x17]       @ state

4:
    ldrh    r3, [r5,#0x18]       @ tl
    strh    r0, [r5,#0x1a]       @ volume
.if     \slot == SLOT1
    mov     r6, r6, lsr #16
    add     r0, r0, r3
    orr     r6, r0, r6, lsl #16
.elseif \slot == SLOT2
    mov     r6, r6, lsl #16
    add     r0, r0, r3
    mov     r0, r0, lsl #16
    orr     r6, r0, r6, lsr #16
.elseif \slot == SLOT3
    mov     r7, r7, lsr #16
    add     r0, r0, r3
    orr     r7, r0, r7, lsl #16
.elseif \slot == SLOT4
    mov     r7, r7, lsl #16
    add     r0, r0, r3
    mov     r0, r0, lsl #16
    orr     r7, r0, r7, lsr #16
.endif

5:
.endm


@ r12=lfo_ampm[31:16], r1=lfo_cnt_old, r2=lfo_cnt, r3=scratch
.macro advance_lfo_m
    mov     r2, r2, lsr #LFO_SH
    cmp     r2, r1, lsr #LFO_SH
    beq     0f
    and     r3, r2, #0x3f
    cmp     r2, #0x40
    rsbge   r3, r3, #0x3f
    bic     r12,r12, #0xff000000          @ lfo_ampm &= 0xff
    orr     r12,r12, r3, lsl #1+24

    mov     r2, r2, lsr #2
    cmp     r2, r1, lsr #LFO_SH+2
    bicne   r12,r12, #0xff0000
    orrne   r12,r12, r2, lsl #16

0:
.endm


@ result goes to r1, trashes r2
.macro make_eg_out slot
    tst     r12, #8
    tstne   r12, #(1<<(\slot+8))
.if     \slot == SLOT1
    mov     r1, r6, lsl #16
    mov     r1, r1, lsr #17
.elseif \slot == SLOT2
    mov     r1, r6, lsr #17
.elseif \slot == SLOT3
    mov     r1, r7, lsl #16
    mov     r1, r1, lsr #17
.elseif \slot == SLOT4
    mov     r1, r7, lsr #17
.endif
    andne   r2, r12, #0xc0
    movne   r2, r2,  lsr #6
    addne   r2, r2,  #24
    addne   r1, r1,  r12, lsr r2
.endm


.macro lookup_tl r
    tst     \r, #0x100
    eorne   \r, \r, #0xff   @ if (sin & 0x100) sin = 0xff - (sin&0xff);
    tst     \r, #0x200
    and     \r, \r, #0xff
    orr     \r, \r, r1, lsl #8
    mov     \r, \r, lsl #1
    ldrh    \r, [r3, \r]    @ 2ci if ne
    rsbne   \r, \r, #0
.endm


@ lr=context, r12=pack (stereo, lastchan, disabled, lfo_enabled | pan_r, pan_l, ams[2] | AMmasks[4] | FB[4] | lfo_ampm[16])
@ r0-r2=scratch, r3=sin_tab, r5=scratch, r6-r7=vol_out[4], r10=op1_out
.macro upd_algo0_m

    @ SLOT3
    make_eg_out SLOT3
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     0f
    ldr     r2, [lr, #0x18]
    ldr     r0, [lr, #0x38] @ mem (signed)
    mov     r2, r2, lsr #16
    add     r0, r2, r0, lsr #1
    lookup_tl r0                  @ r0=c2

0:

    @ SLOT4
    make_eg_out SLOT4
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     1f
    ldr     r2, [lr, #0x1c]
    mov     r0, r0, lsr #1
    add     r0, r0, r2, lsr #16
    lookup_tl r0                  @ r0=output smp

1:
    @ SLOT2
    make_eg_out SLOT2
    cmp     r1, #ENV_QUIET
    movcs   r2, #0
    bcs     2f
    ldr     r2, [lr, #0x14]       @ 1ci
    mov     r5, r10, lsr #17
    add     r2, r5, r2, lsr #16
    lookup_tl r2                  @ r2=mem

2:
    str     r2, [lr, #0x38] @ mem
.endm


.macro upd_algo1_m

    @ SLOT3
    make_eg_out SLOT3
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     0f
    ldr     r2, [lr, #0x18]
    ldr     r0, [lr, #0x38] @ mem (signed)
    mov     r2, r2, lsr #16
    add     r0, r2, r0, lsr #1
    lookup_tl r0                 @ r0=c2

0:
    @ SLOT4
    make_eg_out SLOT4
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     1f
    ldr     r2, [lr, #0x1c]
    mov     r0, r0, lsr #1
    add     r0, r0, r2, lsr #16
    lookup_tl r0                 @ r0=output smp

1:
    @ SLOT2
    make_eg_out SLOT2
    cmp     r1, #ENV_QUIET
    movcs   r2, #0
    bcs     2f
    ldr     r2, [lr, #0x14]      @ 1ci
    mov     r2, r2, lsr #16
    lookup_tl r2                 @ r2=mem

2:
    add     r2, r2, r10, asr #16
    str     r2, [lr, #0x38]
.endm


.macro upd_algo2_m

    @ SLOT3
    make_eg_out SLOT3
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     0f
    ldr     r2, [lr, #0x18]
    ldr     r0, [lr, #0x38] @ mem (signed)
    mov     r2, r2, lsr #16
    add     r0, r2, r0, lsr #1
    lookup_tl r0                 @ r0=c2

0:
    add     r0, r0, r10, asr #16

    @ SLOT4
    make_eg_out SLOT4
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     1f
    ldr     r2, [lr, #0x1c]
    mov     r0, r0, lsr #1
    add     r0, r0, r2, lsr #16
    lookup_tl r0                 @ r0=output smp

1:
    @ SLOT2
    make_eg_out SLOT2
    cmp     r1, #ENV_QUIET
    movcs   r2, #0
    bcs     2f
    ldr     r2, [lr, #0x14]
    mov     r2, r2, lsr #16      @ 1ci
    lookup_tl r2                 @ r2=mem

2:
    str     r2, [lr, #0x38] @ mem
.endm


.macro upd_algo3_m

    @ SLOT3
    make_eg_out SLOT3
    cmp     r1, #ENV_QUIET
    ldr     r2, [lr, #0x38] @ mem (for future)
    movcs   r0, r2
    bcs     0f
    ldr     r0, [lr, #0x18]      @ 1ci
    mov     r0, r0, lsr #16
    lookup_tl r0                 @ r0=c2

0:
    add     r0, r0, r2

    @ SLOT4
    make_eg_out SLOT4
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     1f
    ldr     r2, [lr, #0x1c]
    mov     r0, r0, lsr #1
    add     r0, r0, r2, lsr #16
    lookup_tl r0                 @ r0=output smp

1:
    @ SLOT2
    make_eg_out SLOT2
    cmp     r1, #ENV_QUIET
    movcs   r2, #0
    bcs     2f
    ldr     r2, [lr, #0x14]
    mov     r5, r10, lsr #17
    add     r2, r5, r2, lsr #16
    lookup_tl r2                 @ r2=mem

2:
    str     r2, [lr, #0x38] @ mem
.endm


.macro upd_algo4_m

    @ SLOT3
    make_eg_out SLOT3
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     0f
    ldr     r0, [lr, #0x18]
    mov     r0, r0, lsr #16      @ 1ci
    lookup_tl r0                 @ r0=c2

0:
    @ SLOT4
    make_eg_out SLOT4
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     1f
    ldr     r2, [lr, #0x1c]
    mov     r0, r0, lsr #1
    add     r0, r0, r2, lsr #16
    lookup_tl r0                 @ r0=output smp

1:
    @ SLOT2
    make_eg_out SLOT2
    cmp     r1, #ENV_QUIET
    bcs     2f
    ldr     r2, [lr, #0x14]
    mov     r5, r10, lsr #17
    add     r2, r5, r2, lsr #16
    lookup_tl r2
    add     r0, r0, r2            @ add to smp

2:
.endm


.macro upd_algo5_m

    @ SLOT3
    make_eg_out SLOT3
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     0f
    ldr     r2, [lr, #0x18]
    ldr     r0, [lr, #0x38] @ mem (signed)
    mov     r2, r2, lsr #16
    add     r0, r2, r0, lsr #1
    lookup_tl r0                 @ r0=output smp

0:
    @ SLOT4
    make_eg_out SLOT4
    cmp     r1, #ENV_QUIET
    bcs     1f
    ldr     r2, [lr, #0x1c]
    mov     r5, r10, lsr #17
    add     r2, r5, r2, lsr #16
    lookup_tl r2
    add     r0, r0, r2           @ add to smp

1:  @ SLOT2
    make_eg_out SLOT2
    cmp     r1, #ENV_QUIET
    bcs     2f
    ldr     r2, [lr, #0x14]
    mov     r5, r10, lsr #17
    add     r2, r5, r2, lsr #16
    lookup_tl r2
    add     r0, r0, r2           @ add to smp

2:
    mov     r1, r10, asr #16
    str     r1, [lr, #0x38] @ mem
.endm


.macro upd_algo6_m

    @ SLOT3
    make_eg_out SLOT3
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     0f
    ldr     r0, [lr, #0x18]
    mov     r0, r0, lsr #16      @ 1ci
    lookup_tl r0                 @ r0=output smp

0:
    @ SLOT4
    make_eg_out SLOT4
    cmp     r1, #ENV_QUIET
    bcs     1f
    ldr     r2, [lr, #0x1c]
    mov     r2, r2, lsr #16      @ 1ci
    lookup_tl r2
    add     r0, r0, r2           @ add to smp

1:  @ SLOT2
    make_eg_out SLOT2
    cmp     r1, #ENV_QUIET
    bcs     2f
    ldr     r2, [lr, #0x14]
    mov     r5, r10, lsr #17
    add     r2, r5, r2, lsr #16
    lookup_tl r2
    add     r0, r0, r2           @ add to smp

2:
.endm


.macro upd_algo7_m

    @ SLOT3
    make_eg_out SLOT3
    cmp     r1, #ENV_QUIET
    movcs   r0, #0
    bcs     0f
    ldr     r0, [lr, #0x18]
    mov     r0, r0, lsr #16      @ 1ci
    lookup_tl r0                 @ r0=output smp

0:
    add     r0, r0, r10, asr #16

    @ SLOT4
    make_eg_out SLOT4
    cmp     r1, #ENV_QUIET
    bcs     1f
    ldr     r2, [lr, #0x1c]
    mov     r2, r2, lsr #16      @ 1ci
    lookup_tl r2
    add     r0, r0, r2           @ add to smp

1:  @ SLOT2
    make_eg_out SLOT2
    cmp     r1, #ENV_QUIET
    bcs     2f
    ldr     r2, [lr, #0x14]
    mov     r2, r2, lsr #16      @ 1ci
    lookup_tl r2
    add     r0, r0, r2           @ add to smp

2:
.endm


.macro upd_slot1_m

    make_eg_out SLOT1
    cmp     r1, #ENV_QUIET
    movcs   r10, r10, lsl #16     @ ct->op1_out <<= 16; // op1_out0 = op1_out1; op1_out1 = 0;
    bcs     0f
    ands    r2, r12, #0xf000
    moveq   r0, #0
    movne   r2, r2, lsr #12
    addne   r0, r10, r10, lsl #16
    movne   r0, r0, asr #16
    movne   r0, r0, lsl r2

    ldr     r2, [lr, #0x10]
    mov     r0, r0, lsr #16
    add     r0, r0, r2, lsr #16
    lookup_tl r0
    mov     r10,r10,lsl #16     @ ct->op1_out <<= 16;
    mov     r0, r0, lsl #16
    orr     r10,r10, r0, lsr #16

0:
.endm


/*
.global update_eg_phase @ FM_SLOT *SLOT, UINT32 eg_cnt

update_eg_phase:
    stmfd   sp!, {r5,r6}
    mov     r5, r0             @ slot
    ldrh    r3, [r5,#0x18]       @ tl
    ldrh    r6, [r5,#0x1a]       @ volume
    add     r6, r6, r3
    update_eg_phase_slot SLOT1
    mov     r0, r6
    ldmfd   sp!, {r5,r6}
    bx      lr
.pool


.global advance_lfo @ int lfo_ampm, UINT32 lfo_cnt_old, UINT32 lfo_cnt

advance_lfo:
    mov     r12, r0, lsl #16
    advance_lfo_m
    mov     r0, r12, lsr #16
    bx      lr
.pool


.global upd_algo0 @ chan_rend_context *c
upd_algo0:
    stmfd   sp!, {r4-r10,lr}
    mov     lr, r0

    ldr     r3, =ym_sin_tab
    ldr     r5, =ym_tl_tab
    ldmia   lr, {r6-r7}
    ldr     r10, [lr, #0x54]
    ldr     r12, [lr, #0x4c]

    upd_algo0_m

    ldmfd   sp!, {r4-r10,pc}
.pool


.global upd_algo1 @ chan_rend_context *c
upd_algo1:
    stmfd   sp!, {r4-r10,lr}
    mov     lr, r0

    ldr     r3, =ym_sin_tab
    ldr     r5, =ym_tl_tab
    ldmia   lr, {r6-r7}
    ldr     r10, [lr, #0x54]
    ldr     r12, [lr, #0x4c]

    upd_algo1_m

    ldmfd   sp!, {r4-r10,pc}
.pool


.global upd_algo2 @ chan_rend_context *c
upd_algo2:
    stmfd   sp!, {r4-r10,lr}
    mov     lr, r0

    ldr     r3, =ym_sin_tab
    ldr     r5, =ym_tl_tab
    ldmia   lr, {r6-r7}
    ldr     r10, [lr, #0x54]
    ldr     r12, [lr, #0x4c]

    upd_algo2_m

    ldmfd   sp!, {r4-r10,pc}
.pool


.global upd_algo3 @ chan_rend_context *c
upd_algo3:
    stmfd   sp!, {r4-r10,lr}
    mov     lr, r0

    ldr     r3, =ym_sin_tab
    ldr     r5, =ym_tl_tab
    ldmia   lr, {r6-r7}
    ldr     r10, [lr, #0x54]
    ldr     r12, [lr, #0x4c]

    upd_algo3_m

    ldmfd   sp!, {r4-r10,pc}
.pool


.global upd_algo4 @ chan_rend_context *c
upd_algo4:
    stmfd   sp!, {r4-r10,lr}
    mov     lr, r0

    ldr     r3, =ym_sin_tab
    ldr     r5, =ym_tl_tab
    ldmia   lr, {r6-r7}
    ldr     r10, [lr, #0x54]
    ldr     r12, [lr, #0x4c]

    upd_algo4_m

    ldmfd   sp!, {r4-r10,pc}
.pool


.global upd_algo5 @ chan_rend_context *c
upd_algo5:
    stmfd   sp!, {r4-r10,lr}
    mov     lr, r0

    ldr     r3, =ym_sin_tab
    ldr     r5, =ym_tl_tab
    ldmia   lr, {r6-r7}
    ldr     r10, [lr, #0x54]
    ldr     r12, [lr, #0x4c]

    upd_algo5_m

    ldmfd   sp!, {r4-r10,pc}
.pool


.global upd_algo6 @ chan_rend_context *c
upd_algo6:
    stmfd   sp!, {r4-r10,lr}
    mov     lr, r0

    ldr     r3, =ym_sin_tab
    ldr     r5, =ym_tl_tab
    ldmia   lr, {r6-r7}
    ldr     r10, [lr, #0x54]
    ldr     r12, [lr, #0x4c]

    upd_algo6_m

    ldmfd   sp!, {r4-r10,pc}
.pool


.global upd_algo7 @ chan_rend_context *c
upd_algo7:
    stmfd   sp!, {r4-r10,lr}
    mov     lr, r0

    ldr     r3, =ym_sin_tab
    ldr     r5, =ym_tl_tab
    ldmia   lr, {r6-r7}
    ldr     r10, [lr, #0x54]
    ldr     r12, [lr, #0x4c]

    upd_algo7_m

    ldmfd   sp!, {r4-r10,pc}
.pool


.global upd_slot1 @ chan_rend_context *c
upd_slot1:
    stmfd   sp!, {r4-r10,lr}
    mov     lr, r0

    ldr     r3, =ym_sin_tab
    ldr     r5, =ym_tl_tab
    ldmia   lr, {r6-r7}
    ldr     r10, [lr, #0x54]
    ldr     r12, [lr, #0x4c]

    upd_slot1_m
    str     r10, [lr, #0x38]

    ldmfd   sp!, {r4-r10,pc}
.pool
*/


@ lr=context, r12=pack (stereo, lastchan, disabled, lfo_enabled | pan_r, pan_l, ams[2] | AMmasks[4] | FB[4] | lfo_ampm[16])
@ r0-r2=scratch, r3=sin_tab/scratch, r4=(length<<8)|unused[4],was_update,algo[3], r5=tl_tab/slot,
@ r6-r7=vol_out[4], r8=eg_timer, r9=eg_timer_add[31:16], r10=op1_out, r11=buffer
.global chan_render_loop @ chan_rend_context *ct, int *buffer, int length

chan_render_loop:
    stmfd   sp!, {r4-r11,lr}
    mov     lr,  r0
    mov     r4,  r2, lsl #8      @ no more 24 bits here
    ldr     r12, [lr, #0x4c]
    ldr     r0,  [lr, #0x50]
    mov     r11, r1
    and     r0,  r0, #7
    orr     r4,  r4, r0          @ (length<<8)|algo
    add     r0,  lr, #0x44
    ldmia   r0,  {r8,r9}         @ eg_timer, eg_timer_add
    ldr     r10, [lr, #0x54]     @ op1_out
    ldmia   lr,  {r6,r7}         @ load volumes

    tst     r12, #8              @ lfo?
    beq     crl_loop

crl_loop_lfo:
    add     r0, lr, #0x30
    ldmia   r0, {r1,r2}
    add     r2, r2, r1
    str     r2, [lr, #0x30]
    @ r12=lfo_ampm[31:16], r1=lfo_cnt_old, r2=lfo_cnt
    advance_lfo_m

crl_loop:
    subs    r4, r4, #0x100
    bmi     crl_loop_end

    @ -- EG --
    add     r8, r8, r9
    cmp     r8, #EG_TIMER_OVERFLOW
    bcc     eg_done
    add     r0, lr, #0x3c
    ldmia   r0, {r1,r5}         @ eg_cnt, CH
eg_loop:
    sub     r8, r8, #EG_TIMER_OVERFLOW
    add     r1, r1, #1
                                        @ SLOT1 (0)
    @ r5=slot, r1=eg_cnt, trashes: r0,r2,r3
    update_eg_phase_slot SLOT1
    add     r5, r5, #SLOT_STRUCT_SIZE*2 @ SLOT2 (2)
    update_eg_phase_slot SLOT2
    sub     r5, r5, #SLOT_STRUCT_SIZE   @ SLOT3 (1)
    update_eg_phase_slot SLOT3
    add     r5, r5, #SLOT_STRUCT_SIZE*2 @ SLOT4 (3)
    update_eg_phase_slot SLOT4

    cmp     r8, #EG_TIMER_OVERFLOW
    subcs   r5, r5, #SLOT_STRUCT_SIZE*3
    bcs     eg_loop
    str     r1, [lr, #0x3c]

eg_done:

    @ -- disabled? --
    and     r0, r12, #0xC
    cmp     r0, #0xC
    beq     crl_loop_lfo
    cmp     r0, #0x4
    beq     crl_loop

    @ -- SLOT1 --
    ldr     r3, =ym_tl_tab

    @ lr=context, r12=pack (stereo, lastchan, disabled, lfo_enabled | pan_r, pan_l, ams[2] | AMmasks[4] | FB[4] | lfo_ampm[16])
    @ r0-r2=scratch, r3=tl_tab, r5=scratch, r6-r7=vol_out[4], r10=op1_out
    upd_slot1_m

    @ -- SLOT2+ --
    and     r0, r4, #7
    ldr     pc, [pc, r0, lsl #2]
    nop
    .word   crl_algo0
    .word   crl_algo1
    .word   crl_algo2
    .word   crl_algo3
    .word   crl_algo4
    .word   crl_algo5
    .word   crl_algo6
    .word   crl_algo7
    .pool

crl_algo0:
    upd_algo0_m
    b       crl_algo_done
    .pool

crl_algo1:
    upd_algo1_m
    b       crl_algo_done
    .pool

crl_algo2:
    upd_algo2_m
    b       crl_algo_done
    .pool

crl_algo3:
    upd_algo3_m
    b       crl_algo_done
    .pool

crl_algo4:
    upd_algo4_m
    b       crl_algo_done
    .pool

crl_algo5:
    upd_algo5_m
    b       crl_algo_done
    .pool

crl_algo6:
    upd_algo6_m
    b       crl_algo_done
    .pool

crl_algo7:
    upd_algo7_m
    .pool


crl_algo_done:
    @ -- WRITE SAMPLE --
    tst     r0, r0
    beq     ctl_sample_skip
    orr     r4, r4, #8              @ have_output
    tst     r12, #1
    beq     ctl_sample_mono

    tst     r12, #0x20              @ L
    ldrne   r1, [r11]
    addeq   r11, r11, #4
    addne   r1, r0, r1
    strne   r1, [r11], #4
    tst     r12, #0x10              @ R
    ldrne   r1, [r11]
    addeq   r11, r11, #4
    addne   r1, r0, r1
    strne   r1, [r11], #4
    b       crl_do_phase

ctl_sample_skip:
    and     r1, r12, #1
    add     r1, r1,  #1
    add     r11,r11, r1, lsl #2
    b       crl_do_phase

ctl_sample_mono:
    ldr     r1, [r11]
    add     r1, r0, r1
    str     r1, [r11], #4

crl_do_phase:
    @ -- PHASE UPDATE --
    add     r5, lr, #0x10
    ldmia   r5, {r0-r1}
    add     r5, lr, #0x20
    ldmia   r5, {r2-r3}
    add     r5, lr, #0x10
    add     r0, r0, r2
    add     r1, r1, r3
    stmia   r5!,{r0-r1}
    ldmia   r5, {r0-r1}
    add     r5, lr, #0x28
    ldmia   r5, {r2-r3}
    add     r5, lr, #0x18
    add     r0, r0, r2
    add     r1, r1, r3
    stmia   r5, {r0-r1}

    tst     r12, #8
    bne     crl_loop_lfo
    b       crl_loop


crl_loop_end:
    str     r8,  [lr, #0x44]     @ eg_timer
    str     r12, [lr, #0x4c]     @ pack (for lfo_ampm)
    str     r4,  [lr, #0x50]     @ was_update
    str     r10, [lr, #0x54]     @ op1_out
    ldmfd   sp!, {r4-r11,pc}

.pool

