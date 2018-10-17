/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Yabause - linkage_arm.s                                               *
 *   Copyright (C) 2009-2011 Ari64                                         *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
	/*.cpu arm9tdmi*/
       /* .fpu softvfp
	.eabi_attribute 20, 1
	.eabi_attribute 21, 1
	.eabi_attribute 23, 3
	.eabi_attribute 24, 1
	.eabi_attribute 25, 1
	.eabi_attribute 26, 2
	.eabi_attribute 30, 6
       .eabi_attribute 18, 4*/
	.file	"linkage_arm.s"
	.global	sh2_dynarec_target
	.global	dynarec_local
	.global	master_reg
	.global	master_cc
	.global	master_pc
	.global	master_ip
	.global	slave_reg
	.global	slave_cc
	.global	slave_pc
	.global	slave_ip
	.global	mini_ht_master
	.global	mini_ht_slave
	.global	restore_candidate
	.global	memory_map
	.global	rccount
	.bss
	.align	12
	.type	sh2_dynarec_target, %object
	.size	sh2_dynarec_target, 16777216
sh2_dynarec_target:
	.space	16777216
	.align	4
	.type	dynarec_local, %object
	.size	dynarec_local, 64
dynarec_local:
	.space	64+88+12+88+12+28+256+256+512+4194304
master_reg = dynarec_local + 64
	.type	master_reg, %object
	.size	master_reg, 88
master_cc = master_reg + 88
	.type	master_cc, %object
	.size	master_cc, 4
master_pc = master_cc + 4
	.type	master_pc, %object
	.size	master_pc, 4
master_ip = master_pc + 4
	.type	master_ip, %object
	.size	master_ip, 4
slave_reg = master_ip + 4
	.type	slave_reg, %object
	.size	slave_reg, 88
slave_cc = slave_reg + 88
	.type	slave_cc, %object
	.size	slave_cc, 4
slave_pc = slave_cc + 4
	.type	slave_pc, %object
	.size	slave_pc, 4
slave_ip = slave_pc + 4
	.type	slave_ip, %object
	.size	slave_ip, 4

m68kcenticycles = slave_ip + 4
	.type	m68kcenticycles, %object
	.size	m68kcenticycles, 4
m68kcycles = m68kcenticycles + 4
	.type	m68kcycles, %object
	.size	m68kcycles, 4
decilinecount = m68kcycles + 4
	.type	decilinecount, %object
	.size	decilinecount, 4
decilinecycles = decilinecount + 4
	.type	decilinecycles, %object
	.size	decilinecycles, 4
sh2cycles = decilinecycles + 4
	.type	sh2cycles, %object
	.size	sh2cycles, 4
scucycles = sh2cycles + 4
	.type	scucycles, %object
	.size	scucycles, 4
rccount = scucycles + 4
	.type	rccount, %object
	.size	rccount, 4

mini_ht_master = rccount + 4
	.type	mini_ht_master, %object
	.size	mini_ht_master, 256
mini_ht_slave = mini_ht_master + 256
	.type	mini_ht_slave, %object
	.size	mini_ht_slave, 256
restore_candidate = mini_ht_slave + 256
	.type	restore_candidate, %object
	.size	restore_candidate, 512
memory_map = restore_candidate + 512
	.type	memory_map, %object
	.size	memory_map, 4194304

	.text
	.align	2
	.global	YabauseDynarecOneFrameExec
	.type	YabauseDynarecOneFrameExec, %function
YabauseDynarecOneFrameExec:
	ldr	r12, .dlptr
	str	r0, [r12, #m68kcycles-dynarec_local-28]
	str	r1, [r12, #m68kcenticycles-dynarec_local-28]
	mov	r2, #0
	stmia	r12, {r4, r5, r6, r7, r8, r9, sl, fp, lr}
	sub	fp, r12, #28
	str	r2, [r12, #decilinecount-dynarec_local-28]
	ldr	r14, [r12, #master_ip-dynarec_local-28]
newline:
	/*movw	r0, #:lower16:decilinestop_p*/
	/*movt	r0, #:upper16:decilinestop_p*/
	ldr	r0, .dspptr
	/*movw	r1, #:lower16:yabsys_timing_bits*/
	/*movt	r1, #:upper16:yabsys_timing_bits*/
	ldr	r1, .ytbptr
	/*movw	r2, #:lower16:SH2CycleFrac_p*/
	ldr	r2, .scfptr
	ldr	r0, [r0] /* pointer to decilinestop */
	/*movt	r2, #:upper16:SH2CycleFrac_p*/
	/*movw	r3, #:lower16:yabsys_timing_mask*/
	ldr	r3, .ytmptr
	ldr	r1, [r1] /* yabsys_timing_bits */
	/*movt	r3, #:upper16:yabsys_timing_mask*/
	ldr	r2, [r2] /* pointer to SH2CycleFrac */
	ldr	r0, [r0] /* decilinestop */
	ldr	r3, [r3] /* yabsys_timing_mask */
	ldr	r4, [r2] /* SH2CycleFrac */
	add	r5, r0, r0 /* decilinestop*2 */
	lsr	r6, r0, r1 /* decilinecycles = decilinestop>>yabsys_timing_bits*/
	add	r5, r5, r0, lsl #3 /* cyclesinc=decilinestop*10 */
	str	r6, [fp, #decilinecycles-dynarec_local]
	add	r1, r1, #1 /* yabsys_timing_bits+1 */
	add	r6, r6, r6, lsl #3 /* decilinecycles*9 */
	add	r3, r3, r3
	add	r5, r5, r4 /* cyclesinc+=SH2CycleFrac */
	/*movw	r7, #:lower16:MSH2*/
	/*movt	r7, #:upper16:MSH2*/
	ldr	r7, .msh2ptr
	orr	r3, r3, #1 /* ((YABSYS_TIMING_MASK << 1) | 1) */
	/*movw	r8, #:lower16:NumberOfInterruptsOffset*/
	/*movt	r8, #:upper16:NumberOfInterruptsOffset*/
	ldr	r8, .nioptr
	and	r3, r5, r3 /* SH2CycleFrac &= ... */
	lsr	r5, r5, r1 /* scucycles */
	/*movw	r9, #:lower16:CurrentSH2*/
	/*movt	r9, #:upper16:CurrentSH2*/
	ldr	r9, .csh2ptr
	ldr	r7, [r7] /* MSH2 */
	ldr	r8, [r8] /* NumberOfInterruptsOffset */
	str	r5, [fp, #scucycles-dynarec_local]
	add	r5, r5, r5 /* sh2cycles=scucycles*2 */
	str	r3, [r2] /* SH2CycleFrac */
	sub	r6, r5, r6 /* sh2cycles(full line) -= decilinecycles*9 */
	ldr	r12, [r7, r8]
	str	r6, [fp, #sh2cycles-dynarec_local]
	str	r7, [r9] /* CurrentSH2 */
	tst	r12, r12
	bne	master_handle_interrupts
	ldr	r10, [fp, #master_cc-dynarec_local]
	sub	r10, r10, r6
	mov	pc, r14
master_handle_interrupts:
	str	r14, [fp, #master_ip-dynarec_local]
	bl	DynarecMasterHandleInterrupts
	ldr	r10, [fp, #master_cc-dynarec_local]
	ldr	r14, [fp, #master_ip-dynarec_local]
	sub	r10, r10, r6
	mov	pc, r14
.dlptr:
	.word	dynarec_local+28
.dspptr:
	.word	decilinestop_p
.ytbptr:
	.word	yabsys_timing_bits
.scfptr:
	.word	SH2CycleFrac_p
.ytmptr:
	.word	yabsys_timing_mask
.msh2ptr:
	.word	MSH2
.ssh2ptr:
	.word	SSH2
.nioptr:
	.word	NumberOfInterruptsOffset
.csh2ptr:
	.word	CurrentSH2
.lcpptr:
	.word	linecount_p
.vlcpptr:
	.word	vblanklinecount_p
.mlcpptr:
	.word	maxlinecount_p
.dupptr:
	.word	decilineusec_p
.ufpptr:
	.word	UsecFrac_p
.scptr:
	.word	saved_centicycles
.icptr:
	.word	invalidate_count
.ccptr:
	.word	cached_code
	.size	YabauseDynarecOneFrameExec, .-YabauseDynarecOneFrameExec

	.global	slave_entry
	.type	slave_entry, %function
slave_entry:
	ldr	r0, [fp, #sh2cycles-dynarec_local]
	str	r10, [fp, #master_cc-dynarec_local]
	str	r14, [fp, #master_ip-dynarec_local]
	bl	FRTExec
	ldr	r0, [fp, #sh2cycles-dynarec_local]
	bl	WDTExec
	ldr	r4, [fp, #slave_ip-dynarec_local]
	/*movw	r7, #:lower16:SSH2*/
	/*movt	r7, #:upper16:SSH2*/
	ldr	r7, .ssh2ptr
	tst	r4, r4
	beq	cc_interrupt_master
	/*movw	r8, #:lower16:NumberOfInterruptsOffset*/
	ldr	r6, [fp, #sh2cycles-dynarec_local]
	/*movt	r8, #:upper16:NumberOfInterruptsOffset*/
	ldr	r8, .nioptr
	/*movw	r9, #:lower16:CurrentSH2*/
	ldr	r9, .csh2ptr
	ldr	r7, [r7]
	/*movt	r9, #:upper16:CurrentSH2*/
	ldr	r8, [r8]
	str	r7, [r9] /* CurrentSH2 */
	ldr	r12, [r7, r8]
	tst	r12, r12
	bne	slave_handle_interrupts
	ldr	r10, [fp, #slave_cc-dynarec_local]
	sub	r10, r10, r6
	mov	pc, r4
slave_handle_interrupts:
	bl	DynarecSlaveHandleInterrupts
	ldr	r10, [fp, #slave_cc-dynarec_local]
	sub	r10, r10, r6
	ldr	pc, [fp, #slave_ip-dynarec_local]
	.size	slave_entry, .-slave_entry

	.global	cc_interrupt
	.type	cc_interrupt, %function
cc_interrupt:
	ldr	r0, [fp, #sh2cycles-dynarec_local]
	str	r10, [fp, #slave_cc-dynarec_local]
	str	r8, [fp, #slave_ip-dynarec_local]
	bl	FRTExec
	ldr	r0, [fp, #sh2cycles-dynarec_local]
	bl	WDTExec
	.size	cc_interrupt, .-cc_interrupt
	.global	cc_interrupt_master
	.type	cc_interrupt_master, %function
cc_interrupt_master:
	ldr	r0, [fp, #decilinecount-dynarec_local]
	ldr	r6, [fp, #decilinecycles-dynarec_local]
	cmp	r0, #8
	add	r0, r0, #1
	bhi	.A3
	str	r0, [fp, #decilinecount-dynarec_local]
	beq	.A2
	str	r6, [fp, #sh2cycles-dynarec_local]
	ldr	r14, [fp, #master_ip-dynarec_local]
.A1:
	/*movw	r7, #:lower16:MSH2*/
	/*movt	r7, #:upper16:MSH2*/
	/*movw	r8, #:lower16:NumberOfInterruptsOffset*/
	/*movt	r8, #:upper16:NumberOfInterruptsOffset*/
	/*movw	r9, #:lower16:CurrentSH2*/
	/*movt	r9, #:upper16:CurrentSH2*/
	ldr	r7, .msh2ptr
	ldr	r8, .nioptr
	ldr	r9, .csh2ptr
	ldr	r7, [r7] /* MSH2 */
	ldr	r8, [r8] /* NumberOfInterruptsOffset */
	ldr	r12, [r7, r8]
	str	r7, [r9] /* CurrentSH2 */
	tst	r12, r12
	bne	master_handle_interrupts
	ldr	r10, [fp, #master_cc-dynarec_local]
	sub	r10, r10, r6
	mov	pc, r14
.A2:
	bl	Vdp2HBlankIN
	ldr	r14, [fp, #master_ip-dynarec_local]
	b	.A1
.A3:
	ldr	r0, [fp, #scucycles-dynarec_local]
	bl	ScuExec
	/*movw	r4, #:lower16:linecount_p*/
	/*movt	r4, #:upper16:linecount_p*/
	ldr	r4, .lcpptr
	bl	M68KSync
	/*movw	r5, #:lower16:vblanklinecount_p*/
	/*movt	r5, #:upper16:vblanklinecount_p*/
	ldr	r5, .vlcpptr
	bl	Vdp2HBlankOUT
	/*movw	r6, #:lower16:maxlinecount_p*/
	/*movt	r6, #:upper16:maxlinecount_p*/
	ldr	r6, .mlcpptr
	bl	ScspExec
	ldr	r4, [r4] /* pointer to linecount */
	ldr	r5, [r5] /* pointer to vblanklinecount */
	ldr	r6, [r6] /* pointer to maxlinecount */
	mov	r0, #0
	ldr	r7, [r4] /* linecount */
	ldr	r5, [r5] /* vblanklinecount */
	ldr	r6, [r6] /* maxlinecount */
	add	r7, r7, #1
	str	r0, [fp, #decilinecount-dynarec_local]
	cmp	r5, r7 /* linecount==vblanklinecount ? */
	beq	vblankin
	cmp	r6, r7 /* linecount==maxlinecount ? */
	strne	r7, [r4] /* linecount++ */
	bleq	Vdp2VBlankOUT
nextline:
	/* finishline */
      /*const u32 usecinc = yabsys.DecilineUsec * 10;*/
	/*movw	r3, #:lower16:decilineusec_p*/
	/*movt	r3, #:upper16:decilineusec_p*/
	ldr	r3, .dupptr
	/*movw	r5, #:lower16:UsecFrac_p*/
	/*movt	r5, #:upper16:UsecFrac_p*/
	ldr	r5, .ufpptr
	/*movw	r8, #:lower16:yabsys_timing_bits*/
	/*movt	r8, #:upper16:yabsys_timing_bits*/
	ldr	r8, .ytbptr
	/*movw	r9, #:lower16:yabsys_timing_mask*/
	/*movt	r9, #:upper16:yabsys_timing_mask*/
	ldr	r9, .ytmptr
	ldr	r3, [r3] /* pointer to decilineusec */
	ldr	r5, [r5] /* pointer to usecfrac */
	ldr	r8, [r8] /* yabsys_timing_bits */
	ldr	r3, [r3] /* decilineusec */
	ldr	r0, [r5] /* usecfrac */
	ldr	r9, [r9] /* yabsys_timing_mask */
	add	r0, r0, r3, lsl #3 /* UsecFrac += yabsys.DecilineUsec * 8 */
	add	r0, r0, r3, lsl #1 /* UsecFrac += yabsys.DecilineUsec * 2 */
	str	r0, [r5]
	lsr	r0, r0, r8
	bl	SmpcExec
	/* SmpcExec may modify UsecFrac; must reload it */
	ldr	r10, [r5] /* usecfrac */
	lsr	r0, r10, r8
	and	r10, r10, r9
	bl	Cs2Exec
	/*movw	r8, #:lower16:saved_centicycles*/
	str	r10, [r5] /* usecfrac */
	/*movt	r8, #:upper16:saved_centicycles*/
	ldr	r8, .scptr
	ldr	r1, [fp, #m68kcenticycles-dynarec_local]
	ldr	r2, [r8]
	ldr	r0, [fp, #m68kcycles-dynarec_local]
	add	r2, r2, r1
	cmp	r2, #100
	subcs	r2, r2, #100
	addcs	r0, r0, #1
	str	r2, [r8] /* saved_centicycles */
	bl	M68KExec
	ldr	r14, [fp, #master_ip-dynarec_local]
	eors	r1, r6, r7 /* linecount==maxlinecount ? */
	bne	newline
nextframe:
	str	r1, [r4] /* linecount=0 */
	bl	M68KSync
	ldr	r2, [fp, #rccount-dynarec_local]
	/*movw	r0, #:lower16:invalidate_count /* FIX: Put into dynarec_local? */
	add	r3, fp, #restore_candidate-dynarec_local
	/*movt	r0, #:upper16:invalidate_count*/
	ldr	r0, .icptr
	add	r2, r2, #1
	and	r2, r2, #0x3f
	str	r2, [fp, #rccount-dynarec_local]
	ldr	r4, [r3, r2, lsl #2]
	str	r1, [r0] /* invalidate_count=0 */
	tst	r4, r4
	bne	.A5
.A4:
	add     r12, fp, #28
	ldmia   r12, {r4, r5, r6, r7, r8, r9, sl, fp, pc}
.A5:
	/* Move 'dirty' blocks to the 'clean' list */
	lsl	r5, r2, #5
	str	r1, [r3, r2, lsl #2]
.A6:
	lsrs	r4, r4, #1
	mov	r0, r5
	add	r5, r5, #1
	blcs	clean_blocks
	tst	r5, #31
	bne	.A6
	b	.A4
vblankin:
	str	r7, [r4] /* linecount++ */
	bl	SmpcINTBACKEnd
	add	r0, r0, #0 /* NOP for Cortex-A8 branch predictor */
	bl	Vdp2VBlankIN
	add	r0, r0, #0 /* NOP for Cortex-A8 branch predictor */
	bl	CheatDoPatches
	add	r0, r0, #0 /* NOP for Cortex-A8 branch predictor */
	b	nextline
	.size	cc_interrupt_master, .-cc_interrupt_master

	.align	2
	.global	dyna_linker
	.type	dyna_linker, %function
dyna_linker:
	/* r0 = virtual target address */
	/* r1 = instruction to patch */
	mov	r6, #2048
	ldr	r3, .jiptr
	mvn	r2, #0x20000
	ldr	r7, [r1]
	sub	r6, r6, #1
	and	r2, r2, r0, lsr #12
	and	r6, r6, r0, lsr #12
	cmp	r2, #1024
	add	r12, r7, #2
	orrcs	r2, r6, #1024
	ldr	r5, [r3, r2, lsl #2]
	lsl	r12, r12, #8
	/* jump_in lookup */
.B1:
	movs	r4, r5
	beq	.B3
	ldr	r3, [r5]
	ldr	r5, [r4, #12]
	teq	r3, r0
	bne	.B1
	ldr	r4, [r4, #8]
.B2:
	mov	r5, r1
	add	r1, r1, r12, asr #6
	teq	r1, r4
	moveq	pc, r4 /* Stale i-cache */
	bl	add_link
	sub	r2, r4, r5
	and	r1, r7, #0xff000000
	lsl	r2, r2, #6
	sub	r1, r1, #2
	add	r1, r1, r2, lsr #8
	str	r1, [r5]
	mov	pc, r4
.B3:
	/* hash_table lookup */
	ldr	r3, .jdptr
	eor	r4, r0, r0, lsl #16
	ldr	r6, .htptr
	lsr	r4, r4, #12
	bic	r4, r4, #15
	ldr	r5, [r3, r2, lsl #2]
	ldr	r7, [r6, r4]!
	teq	r7, r0
	ldreq	pc, [r6, #4]
	ldr	r7, [r6, #8]
	teq	r7, r0
	ldreq	pc, [r6, #12]
	/* jump_dirty lookup */
.B6:
	movs	r4, r5
	beq	.B8
	ldr	r3, [r5]
	ldr	r5, [r4, #12]
	teq	r3, r0
	bne	.B6
.B7:
	ldr	r1, [r4, #8]
	/* hash_table insert */
	ldr	r2, [r6]
	ldr	r3, [r6, #4]
	str	r0, [r6]
	str	r1, [r6, #4]
	str	r2, [r6, #8]
	str	r3, [r6, #12]
	mov	pc, r1
.B8:
	mov	r4, r0
	mov	r5, r1
	bl	sh2_recompile_block
	tst	r0, r0
	mov	r0, r4
	mov	r1, r5
	beq	dyna_linker
	/* shouldn't happen */
	b	.-8
.jiptr:
	.word	jump_in
.jdptr:
	.word	jump_dirty
.htptr:
	.word	hash_table
	.align	2
	.global	jump_vaddr_r0_master
	.type	jump_vaddr_r0_master, %function
jump_vaddr_r0_master:
	eor	r2, r0, r0, lsl #16
	b	jump_vaddr
	.size	jump_vaddr_r0_master, .-jump_vaddr_r0_master
	.global	jump_vaddr_r1_master
	.type	jump_vaddr_r1_master, %function
jump_vaddr_r1_master:
	eor	r2, r1, r1, lsl #16
	mov	r0, r1
	b	jump_vaddr
	.size	jump_vaddr_r1_master, .-jump_vaddr_r1_master
	.global	jump_vaddr_r2_master
	.type	jump_vaddr_r2_master, %function
jump_vaddr_r2_master:
	mov	r0, r2
	eor	r2, r2, r2, lsl #16
	b	jump_vaddr
	.size	jump_vaddr_r2_master, .-jump_vaddr_r2_master
	.global	jump_vaddr_r3_master
	.type	jump_vaddr_r3_master, %function
jump_vaddr_r3_master:
	eor	r2, r3, r3, lsl #16
	mov	r0, r3
	b	jump_vaddr
	.size	jump_vaddr_r3_master, .-jump_vaddr_r3_master
	.global	jump_vaddr_r4_master
	.type	jump_vaddr_r4_master, %function
jump_vaddr_r4_master:
	eor	r2, r4, r4, lsl #16
	mov	r0, r4
	b	jump_vaddr
	.size	jump_vaddr_r4_master, .-jump_vaddr_r4_master
	.global	jump_vaddr_r5_master
	.type	jump_vaddr_r5_master, %function
jump_vaddr_r5_master:
	eor	r2, r5, r5, lsl #16
	mov	r0, r5
	b	jump_vaddr
	.size	jump_vaddr_r5_master, .-jump_vaddr_r5_master
	.global	jump_vaddr_r6_master
	.type	jump_vaddr_r6_master, %function
jump_vaddr_r6_master:
	eor	r2, r6, r6, lsl #16
	mov	r0, r6
	b	jump_vaddr
	.size	jump_vaddr_r6_master, .-jump_vaddr_r6_master
	.global	jump_vaddr_r7_master
	.type	jump_vaddr_r7_master, %function
jump_vaddr_r7_master:
	eor	r2, r7, r7, lsl #16
	mov	r0, r7
	b	jump_vaddr
	.size	jump_vaddr_r7_master, .-jump_vaddr_r7_master
	.global	jump_vaddr_r8_master
	.type	jump_vaddr_r8_master, %function
jump_vaddr_r8_master:
	eor	r2, r8, r8, lsl #16
	mov	r0, r8
	b	jump_vaddr
	.size	jump_vaddr_r8_master, .-jump_vaddr_r8_master
	.global	jump_vaddr_r9_master
	.type	jump_vaddr_r9_master, %function
jump_vaddr_r9_master:
	eor	r2, r9, r9, lsl #16
	mov	r0, r9
	b	jump_vaddr
	.size	jump_vaddr_r9_master, .-jump_vaddr_r9_master
	.global	jump_vaddr_r12_master
	.type	jump_vaddr_r12_master, %function
jump_vaddr_r12_master:
	eor	r2, r12, r12, lsl #16
	mov	r0, r12
	b	jump_vaddr
	.size	jump_vaddr_r12_master, .-jump_vaddr_r12_master
	.global	jump_vaddr_r0_slave
	.type	jump_vaddr_r0_slave, %function
jump_vaddr_r0_slave:
	eor	r2, r0, r0, lsl #16
	b	jump_vaddr_slave
	.size	jump_vaddr_r0_slave, .-jump_vaddr_r0_slave
	.global	jump_vaddr_r1_slave
	.type	jump_vaddr_r1_slave, %function
jump_vaddr_r1_slave:
	eor	r2, r1, r1, lsl #16
	mov	r0, r1
	b	jump_vaddr_slave
	.size	jump_vaddr_r1_slave, .-jump_vaddr_r1_slave
	.global	jump_vaddr_r2_slave
	.type	jump_vaddr_r2_slave, %function
jump_vaddr_r2_slave:
	mov	r0, r2
	eor	r2, r2, r2, lsl #16
	b	jump_vaddr_slave
	.size	jump_vaddr_r2_slave, .-jump_vaddr_r2_slave
	.global	jump_vaddr_r3_slave
	.type	jump_vaddr_r3_slave, %function
jump_vaddr_r3_slave:
	eor	r2, r3, r3, lsl #16
	mov	r0, r3
	b	jump_vaddr_slave
	.size	jump_vaddr_r3_slave, .-jump_vaddr_r3_slave
	.global	jump_vaddr_r4_slave
	.type	jump_vaddr_r4_slave, %function
jump_vaddr_r4_slave:
	eor	r2, r4, r4, lsl #16
	mov	r0, r4
	b	jump_vaddr_slave
	.size	jump_vaddr_r4_slave, .-jump_vaddr_r4_slave
	.global	jump_vaddr_r5_slave
	.type	jump_vaddr_r5_slave, %function
jump_vaddr_r5_slave:
	eor	r2, r5, r5, lsl #16
	mov	r0, r5
	b	jump_vaddr_slave
	.size	jump_vaddr_r5_slave, .-jump_vaddr_r5_slave
	.global	jump_vaddr_r6_slave
	.type	jump_vaddr_r6_slave, %function
jump_vaddr_r6_slave:
	eor	r2, r6, r6, lsl #16
	mov	r0, r6
	b	jump_vaddr_slave
	.size	jump_vaddr_r6_slave, .-jump_vaddr_r6_slave
	.global	jump_vaddr_r7_slave
	.type	jump_vaddr_r7_slave, %function
jump_vaddr_r7_slave:
	eor	r2, r7, r7, lsl #16
	mov	r0, r7
	b	jump_vaddr_slave
	.size	jump_vaddr_r7_slave, .-jump_vaddr_r7_slave
	.global	jump_vaddr_r8_slave
	.type	jump_vaddr_r8_slave, %function
jump_vaddr_r8_slave:
	eor	r2, r8, r8, lsl #16
	mov	r0, r8
	b	jump_vaddr_slave
	.size	jump_vaddr_r8_slave, .-jump_vaddr_r8_slave
	.global	jump_vaddr_r9_slave
	.type	jump_vaddr_r9_slave, %function
jump_vaddr_r9_slave:
	eor	r2, r9, r9, lsl #16
	mov	r0, r9
	b	jump_vaddr_slave
	.size	jump_vaddr_r9_slave, .-jump_vaddr_r9_slave
	.global	jump_vaddr_r12_slave
	.type	jump_vaddr_r12_slave, %function
jump_vaddr_r12_slave:
	eor	r2, r12, r12, lsl #16
	mov	r0, r12
	b	jump_vaddr_slave
	.size	jump_vaddr_r12_slave, .-jump_vaddr_r12_slave
	.global	jump_vaddr_slave
	.type	jump_vaddr_slave, %function
jump_vaddr_slave:
	add	r2, r2, #65536
	add	r0, r0, #1
	.size	jump_vaddr_slave, .-jump_vaddr_slave
	.global	jump_vaddr
	.type	jump_vaddr, %function
jump_vaddr:
	ldr	r1, .htptr
	mvn	r3, #15
	and	r2, r3, r2, lsr #12
	ldr	r2, [r1, r2]!
	teq	r2, r0
	ldreq	pc, [r1, #4]
	ldr	r2, [r1, #8]
	teq	r2, r0
	ldreq	pc, [r1, #12]
	bl	get_addr
	mov	pc, r0
	.size	jump_vaddr, .-jump_vaddr
	.align	2
	.global	verify_code
	.type	verify_code, %function
verify_code:
	/* r1 = source */
	/* r2 = target */
	/* r3 = length */
	tst	r3, #4
	mov	r4, #0
	add	r3, r1, r3
	mov	r5, #0
	ldrne	r4, [r1], #4
	mov	r12, #0
	ldrne	r5, [r2], #4
	teq	r1, r3
	beq	.D3
.D2:
	ldr	r7, [r1], #4
	eor	r9, r4, r5
	ldr	r8, [r2], #4
	orrs	r9, r9, r12
	bne	.D4
	ldr	r4, [r1], #4
	eor	r12, r7, r8
	ldr	r5, [r2], #4
	cmp	r1, r3
	bcc	.D2
	teq	r7, r8
.D3:
	teqeq	r4, r5
.D4:
	moveq	pc, lr
.D5:
	bl	get_addr
	mov	pc, r0
	.size	verify_code, .-verify_code

	.align	2
	.global	WriteInvalidateLong
	.type	WriteInvalidateLong, %function
WriteInvalidateLong:
	/*movw	r12, #:lower16:cached_code*/
	lsr	r2, r0, #17
	/*movt	r12, #:upper16:cached_code*/
	ldr	r12, .ccptr
	lsr	r3, r0, #12
	ldr	r2, [r12, r2, lsl #2]
	mov	r12, #1
	tst	r12, r2, ror r3
	beq	MappedMemoryWriteLong
	push	{r0, r1, r2, lr}
	bl	invalidate_addr
	pop	{r0, r1, r2, lr}
	b	MappedMemoryWriteLong
	.size	WriteInvalidateLong, .-WriteInvalidateLong
	.align	2
	.global	WriteInvalidateWord
	.type	WriteInvalidateWord, %function
WriteInvalidateWord:
	/*movw	r12, #:lower16:cached_code*/
	lsr	r2, r0, #17
	/*movt	r12, #:upper16:cached_code*/
	ldr	r12, .ccptr
	lsr	r3, r0, #12
	bic	r1, r1, #0xFF000000
	ldr	r2, [r12, r2, lsl #2]
	mov	r12, #1
	/*movt	r1, #0*/
	/*uxth	r1, r1*/
	bic	r1, r1, #0xFF0000
	tst	r12, r2, ror r3
	beq	MappedMemoryWriteWord
	push	{r0, r1, r2, lr}
	bl	invalidate_addr
	pop	{r0, r1, r2, lr}
	b	MappedMemoryWriteWord
	.size	WriteInvalidateWord, .-WriteInvalidateWord
	.align	2
	.global	WriteInvalidateByteSwapped
	.type	WriteInvalidateByteSwapped, %function
WriteInvalidateByteSwapped:
	eor	r0, r0, #1
	.size	WriteInvalidateByteSwapped, .-WriteInvalidateByteSwapped
	.global	WriteInvalidateByte
	.type	WriteInvalidateByte, %function
WriteInvalidateByte:
	/*movw	r12, #:lower16:cached_code*/
	lsr	r2, r0, #17
	/*movt	r12, #:upper16:cached_code*/
	ldr	r12, .ccptr
	lsr	r3, r0, #12
	ldr	r2, [r12, r2, lsl #2]
	mov	r12, #1
	and	r1, r1, #0xff
	tst	r12, r2, ror r3
	beq	MappedMemoryWriteByte
	push	{r0, r1, r2, lr}
	bl	invalidate_addr
	pop	{r0, r1, r2, lr}
	b	MappedMemoryWriteByte
	.size	WriteInvalidateByte, .-WriteInvalidateByte

	.align	2
	.global	div1
	.type	div1, %function
div1:
	/* r0 = dividend */
	/* r1 = divisor */
	/* r2 = sr */
	tst	r2, #0x200
	bne	div1_negative_divisor
	lsrs	r2, r2, #1 /* Get T bit and shift out */
	adcs	r0, r0, r0 /* rn=(rn<<1)+T */
	adc	r3, r3, r3 /* New Q in r3 */
	mov	r4, r1     /* divisor (rm) */
	tst	r2, #0x80  /* Get (shifted) Q bit */
	mov	r5, #1
	rsbeq	r4, r1, #0 /* inverted if old_Q clear */
	moveq	r5, #0     /* 0 if old_Q clear, 1 otherwise */
	adds	r0, r4, r0 /* rn+rm if old_Q, rn-rm if !old_Q */
		           /* carry set if rn < old_rn */
	adc	r3, r5, r3 /* low bit = (rn<old_rn)^new_Q^old_Q */
	                   /* inverted for old_Q==1, ie (rn>=old_rn)^new_Q */
	orr	r2, r2, #0x80 /* set (shifted) Q bit */
	and	r3, r3, #1
	orrs	r5, r4, r5 /* zero if old_Q==0 && rn==old_rn */
	eoreq	r3, r3, #1 /* invert result for old_Q==0 && rn==old_rn */
	orr	r2, r3, r2, lsl #1 /* New T = (Q==M) */
	eor	r2, r2, r3, lsl #8 /* save new Q (=!T) */
/*
	mov	r4, r0
	mov	r5, r1
	mov	r6, r2
	mov	r7, r14
	bl	debug_division
	mov	r0, r4
	mov	r1, r5
	mov	r2, r6
	mov	r14, r7
*/
	mov	pc, lr
div1_negative_divisor:
	lsrs	r2, r2, #1 /* Get T bit and shift out */
	adcs	r0, r0, r0 /* rn=(rn<<1)+T */
	adc	r3, r3, r3 /* New Q in r3 */
	mov	r4, r1     /* divisor (rm) */
	tst	r2, #0x80  /* Get (shifted) Q bit */
	mov	r5, #1
	rsbne	r4, r1, #0 /* inverted if old_Q clear */
	movne	r5, #0     /* 0 if old_Q set, 1 otherwise */
	adds	r0, r4, r0 /* rn+rm if !old_Q, rn-rm if old_Q */
		           /* carry set if rn < old_rn */
	adc	r3, r5, r3 /* low bit = (rn<old_rn)^new_Q^old_Q */
	                   /* inverted for old_Q==1, ie (rn>=old_rn)^new_Q */
	bic	r2, r2, #0x80 /* clear (shifted) Q bit */
	and	r3, r3, #1
	orrs	r5, r4, r5 /* zero if old_Q==1 && rn==old_rn */
	/*eoreq	r3, r3, #1 /* invert result for old_Q==1 && rn==old_rn */
	eorne	r3, r3, #1 /* don't invert result for old_Q==1 && rn==old_rn */
	orr	r2, r3, r2, lsl #1 /* New T = (Q==M) */
	orr	r2, r2, r3, lsl #8 /* save new Q (=T) */
	mov	pc, lr
	.size	div1, .-div1

	.align	2
	.global	macl
	.type	macl, %function
macl:
	/* r4 = sr */
	/* r5 = multiplicand address */
	/* r6 = multiplicand address */
	/* r0 = return MACL */
	/* r1 = return MACH */
	mov	r7, r14
	mov	r8, r0 /* MACL */
	mov	r9, r1 /* MACH */
	mov	r0, r6
	bl	MappedMemoryReadLong
	mov	r10, r0
	mov	r0, r5
	bl	MappedMemoryReadLong
	add	r5, r5, #4
	add	r6, r6, #4
	mov	r12, r0
	mov	r0, r8
	mov	r1, r9
	mov	r14, r7
	smlal	r0, r1, r10, r12
	tst	r4, #2
	moveq	pc, lr
macl_saturation:
	cmn	r1, #0x8000
	mov	r7, #0x8000
	movlt	r0, #0
	rsblt	r1, r7, #0
	cmp	r1, #0x8000
	mvnge	r0, #0
	subge	r1, r7, #1
	mov	pc, lr
	.size	macl, .-macl

	.align	2
	.global	macw
	.type	macw, %function
macw:
	/* r4 = sr */
	/* r5 = multiplicand address */
	/* r6 = multiplicand address */
	/* r0 = return MACL */
	/* r1 = return MACH */
	mov	r7, r14
	mov	r8, r0 /* MACL */
	mov	r9, r1 /* MACH */
	mov	r0, r6
	bl	MappedMemoryReadWord
	/*sxth	r10, r0*/
	lsl	r10, r0, #16
	mov	r0, r5
	bl	MappedMemoryReadWord
	add	r5, r5, #2
	add	r6, r6, #2
	lsl	r12, r0, #16
	/*sxth	r12, r0*/
	mov	r0, r8
	mov	r1, r9
	asr	r10, r10, #16
	asr	r12, r12, #16
	mov	r14, r7
	smlal	r0, r1, r10, r12
	tst	r4, #2
	moveq	pc, lr
macw_saturation:
	cmn	r0, #0x80000000
	adcs	r7, r1, #0
	mvnne	r0, #0x80000000 /* 0x7FFFFFFF */
	movlt	r0, #0x80000000 /* 0x80000000 */
	mov	r1, r9
	mov	pc, lr
	.size	macw, .-macw

	.align	2
	.global	master_handle_bios
	.type	master_handle_bios, %function
master_handle_bios:
	/*movw	r1, #:lower16:MSH2*/
	str	r0, [fp, #master_pc-dynarec_local]
	/*movt	r1, #:upper16:MSH2*/
	ldr	r1, .msh2ptr
	str	r10, [fp, #master_cc-dynarec_local]
	str	r14, [fp, #master_ip-dynarec_local]
	ldr	r0, [r1] /* MSH2 */
	bl	BiosHandleFunc
	ldr	r14, [fp, #master_ip-dynarec_local]
	ldr	r10, [fp, #master_cc-dynarec_local]
	mov	pc, lr
	.size	master_handle_bios, .-master_handle_bios

	.align	2
	.global	slave_handle_bios
	.type	slave_handle_bios, %function
slave_handle_bios:
	/*movw	r1, #:lower16:SSH2*/
	str	r0, [fp, #slave_pc-dynarec_local]
	/*movt	r1, #:upper16:SSH2*/
	ldr	r1, .ssh2ptr
	str	r10, [fp, #slave_cc-dynarec_local]
	str	r14, [fp, #slave_ip-dynarec_local]
	ldr	r0, [r1] /* SSH2 */
	bl	BiosHandleFunc
	ldr	r14, [fp, #slave_ip-dynarec_local]
	ldr	r10, [fp, #slave_cc-dynarec_local]
	mov	pc, lr
	.size	slave_handle_bios, .-slave_handle_bios

/* __clear_cache syscall for Linux OS with broken libraries */
	.align	2
	.global	clear_cache
	.type	clear_cache, %function
clear_cache:
	push	{r7, lr}
	mov	r7, #2
	mov	r2, #0
	orr	r7, #0xf0000
	svc	0x00000000
	pop	{r7, pc}
	.size	clear_cache, .-clear_cache

	.align	2
	.global	breakpoint
	.type	breakpoint, %function
breakpoint:
	/* Set breakpoint here for debugging */
	mov	pc, lr
	.size	breakpoint, .-breakpoint
	.section	.note.GNU-stack,"",%progbits
