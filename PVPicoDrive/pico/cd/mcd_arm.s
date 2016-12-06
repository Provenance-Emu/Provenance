@*
@* CPU scheduling code
@* (C) notaz, 2007-2008
@*
@* This work is licensed under the terms of MAME license.
@* See COPYING file in the top-level directory.
@*

@ SekRunPS runs PicoCpuCM68k and PicoCpuCS68k interleaved in steps of PS_STEP_M68K
@ cycles. This is done without calling CycloneRun and jumping directly to
@ Cyclone code to avoid pushing/popping all the registers every time.


.equiv PS_STEP_M68K, ((488<<16)/20) @ ~24

@ .extern is ignored by gas, we add these here just to see what we depend on.
.extern CycloneJumpTab
.extern CycloneDoInterrupt
.extern PicoCpuCM68k
.extern PicoCpuCS68k
.extern SekCycleAim
.extern SekCycleCnt
.extern SekCycleAimS68k
.extern SekCycleCntS68k


.text
.align 4


.global SekRunPS @ cyc_m68k, cyc_s68k

SekRunPS:
    stmfd   sp!, {r4-r8,r10,r11,lr}
    sub     sp, sp, #2*4          @ sp[0] = main_cycle_cnt, sp[4] = run_cycle_cnt

    @ override CycloneEnd for both contexts
    ldr     r7, =PicoCpuCM68k
    ldr     lr, =PicoCpuCS68k
    ldr     r2, =CycloneEnd_M68k
    ldr     r3, =CycloneEnd_S68k
    str     r2, [r7,#0x98]
    str     r3, [lr,#0x98]

    @ update aims
    ldr     r8, =SekCycleAim
    ldr     r10,=SekCycleAimS68k
    ldr     r2, [r8]
    ldr     r3, [r10]
    add     r2, r2, r0
    add     r3, r3, r1
    str     r2, [r8]
    str     r3, [r10]

    ldr     r6, =CycloneJumpTab
    ldr     r1, =SekCycleCnt
    ldr     r0, =((488<<16)-PS_STEP_M68K)
    str     r6, [r7,#0x54]
    str     r6, [lr,#0x54]            @ make copies to avoid literal pools

    @ schedule m68k for the first time..
    ldr     r1, [r1]
    str     r0, [sp]                  @ main target 'left cycle' counter
    sub     r1, r2, r1
    subs    r5, r1, r0, asr #16
    ble     schedule_s68k             @ m68k has not enough cycles

    str     r5, [sp,#4]               @ run_cycle_cnt
    b       CycloneRunLocal



CycloneEnd_M68k:
    ldr     r3, =SekCycleCnt
    ldr     r0, [sp,#4]               @ run_cycle_cnt
    ldr     r1, [r3]
    str     r4, [r7,#0x40]  ;@ Save Current PC + Memory Base
    strb    r10,[r7,#0x46]  ;@ Save Flags (NZCV)
    sub     r0, r0, r5                @ subtract leftover cycles (which should be negative)
    add     r0, r0, r1
    str     r0, [r3]

schedule_s68k:
    ldr     r8, =SekCycleCntS68k
    ldr     r10,=SekCycleAimS68k
    ldr     r3, [sp]
    ldr     r8, [r8]
    ldr     r10,[r10]

    sub     r0, r10, r8
    mov     r2, r3
    add     r3, r3, r2, asr #1
    add     r3, r3, r2, asr #3        @ cycn_s68k = (cycn + cycn/2 + cycn/8)

    subs    r5, r0, r3, asr #16
    ble     schedule_m68k             @ s68k has not enough cycles

    ldr     r7, =PicoCpuCS68k
    str     r5, [sp,#4]               @ run_cycle_cnt
    b       CycloneRunLocal



CycloneEnd_S68k:
    ldr     r3, =SekCycleCntS68k
    ldr     r0, [sp,#4]               @ run_cycle_cnt
    ldr     r1, [r3]
    str     r4, [r7,#0x40]  ;@ Save Current PC + Memory Base
    strb    r10,[r7,#0x46]  ;@ Save Flags (NZCV)
    sub     r0, r0, r5                @ subtract leftover cycles (should be negative)
    add     r0, r0, r1
    str     r0, [r3]

schedule_m68k:
    ldr     r1, =PS_STEP_M68K
    ldr     r3, [sp]                  @ main_cycle_cnt
    ldr     r8, =SekCycleCnt
    ldr     r10,=SekCycleAim
    subs    r3, r3, r1
    bmi     SekRunPS_end

    ldr     r8, [r8]
    ldr     r10,[r10]
    str     r3, [sp]                  @ update main_cycle_cnt
    sub     r0, r10, r8

    subs    r5, r0, r3, asr #16
    ble     schedule_s68k             @ m68k has not enough cycles

    ldr     r7, =PicoCpuCM68k
    str     r5, [sp,#4]               @ run_cycle_cnt
    b       CycloneRunLocal



SekRunPS_end:
    ldr     r7, =PicoCpuCM68k
    ldr     lr, =PicoCpuCS68k
    mov     r0, #0
    str     r0, [r7,#0x98]            @ remove CycloneEnd handler
    str     r0, [lr,#0x98]
    @ return
    add     sp, sp, #2*4
    ldmfd   sp!, {r4-r8,r10,r11,pc}



CycloneRunLocal:
                     ;@ r0-3 = Temporary registers
  ldr r4,[r7,#0x40]  ;@ r4 = Current PC + Memory Base
                     ;@ r5 = Cycles
                     ;@ r6 = Opcode Jump table
                     ;@ r7 = Pointer to Cpu Context
                     ;@ r8 = Current Opcode
  ldrb r10,[r7,#0x46];@ r10 = Flags (NZCV)
  ldr r1,[r7,#0x44]  ;@ get SR high and IRQ level
  orr r10,r10,r10,lsl #28 ;@ r10 = Flags 0xf0000000, cpsr format

;@ CheckInterrupt:
  movs r0,r1,lsr #24 ;@ Get IRQ level
  beq NoIntsLocal
  cmp r0,#6 ;@ irq>6 ?
  andle r1,r1,#7 ;@ Get interrupt mask
  cmple r0,r1 ;@ irq<=6: Is irq<=mask ?
  bgt CycloneDoInterrupt
NoIntsLocal:

;@ Check if our processor is in special state
;@ and jump to opcode handler if not
  ldr r0,[r7,#0x58] ;@ state_flags
  ldrh r8,[r4],#2 ;@ Fetch first opcode
  tst r0,#0x03 ;@ special state?
  andeq r10,r10,#0xf0000000
  ldreq pc,[r6,r8,asl #2] ;@ Jump to opcode handler

CycloneSpecial2:
  tst r0,#2 ;@ tracing?
  bne CycloneDoTrace
;@ stopped or halted
  sub r4,r4,#2
  ldr r1,[r7,#0x98]
  mov r5,#0
  bx r1

@ vim:filetype=armasm
