/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Yabause - linkage_x64.s                                               *
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
	.file	"linkage_x86_64.s"
	.bss
	.align 4
	.section	.rodata
	.text
.globl YabauseDynarecOneFrameExec
	.type	YabauseDynarecOneFrameExec, @function
YabauseDynarecOneFrameExec:
/* (arg1/edi - m68kcycles) */
/* (arg2/esi - m68kcenticycles) */
	push	%rbp
	mov	%rsp, %rbp
	mov	master_ip, %rax
	xor	%ecx, %ecx
	push	%rbx
	push	%r12
	push	%r13
	push	%r14
	push	%r15
	push	%rcx /* zero */
	push	%rcx
	push	%rcx
	push	%rcx
	call	.+5
	mov	%esi,-60(%rbp) /* m68kcenticycles */
	mov	%edi,-64(%rbp) /* m68kcycles */
	mov	%rax,-80(%rbp) /* overwrite return address */
/* Stack frame:
   return address (0)
   rbp (8/0)
   save rbx (16/8)
   save r12 (24/16)
   save r13 (32/24)
   save r14 (40/32)
   save r15 (48/40)
   decilinecount (52/44)
   decilinecycles (56/48)
   sh2cycles (60/52)
   scucycles (64/56)
   m68kcenticycles (68/60)
   m68kcycles (72/64)
   space for alignment (80/72)
   ret address/master_ip (88/80) (alternate rsp at call)
   save %rax (96/88)
   save %rcx (104/96)
   save %rdx (112/104)
   save %rsi (120/112)
   save %rdi (128/120)
   space for alignment (136/128) (rsp at call)
   next return address (144/136)
   total = 144 */
/*   usecinc?
   cyclesinc?*/

newline:
/* const u32 decilinecycles = yabsys.DecilineStop >> YABSYS_TIMING_BITS; */
/* const u32 cyclesinc = yabsys.DecilineStop * 10; */
	mov	decilinestop_p, %rax
	mov	yabsys_timing_bits, %ecx
	mov	(%rax), %eax
	lea	(%eax,%eax,4), %ebx /* decilinestop*5 */
	shr	%cl, %eax /* decilinecycles */
	shl	%ebx	/* cyclesinc=decilinestop*10 */
	lea	(%eax,%eax,8), %edx  /* decilinecycles*9 */
        /* yabsys.SH2CycleFrac += cyclesinc;*/
        /* sh2cycles = (yabsys.SH2CycleFrac >> (YABSYS_TIMING_BITS + 1)) << 1;*/
        /* yabsys.SH2CycleFrac &= ((YABSYS_TIMING_MASK << 1) | 1);*/
	mov	SH2CycleFrac_p, %rsi
	mov	yabsys_timing_mask, %edi
	inc	%ecx /* yabsys_timing_bits+1 */
	add	(%rsi), %ebx /* SH2CycleFrac */
	stc
	adc	%edi, %edi /* ((YABSYS_TIMING_MASK << 1) | 1) */
	mov	%eax, -48(%rbp) /* decilinecycles */
	and	%ebx, %edi
	mov	%edi, (%rsi) /* SH2CycleFrac */
	shr	%cl, %ebx
	mov	%ebx, -56(%rbp) /* scucycles */
	add	%ebx, %ebx /* sh2cycles */
	mov	MSH2, %rax
	mov	NumberOfInterruptsOffset, %ecx
	sub	%edx, %ebx  /* sh2cycles(full line) - decilinecycles*9 */
	mov	%rax, CurrentSH2
	mov	%ebx, -52(%rbp) /* sh2cycles */
	cmp	$0, (%rax, %rcx)
	jne	master_handle_interrupts
	mov	master_cc, %esi
	sub	%ebx, %esi
	ret	/* jmp master_ip */
	.size	YabauseDynarecOneFrameExec, .-YabauseDynarecOneFrameExec

.globl master_handle_interrupts
	.type	master_handle_interrupts, @function
master_handle_interrupts:
	mov	-80(%rbp), %rax /* get return address */
	mov	%rax, master_ip
	call	DynarecMasterHandleInterrupts
	mov	master_ip, %rax
	mov	master_cc, %esi
	mov	%rax,-80(%rbp) /* overwrite return address */
	sub	%ebx, %esi
	ret	/* jmp master_ip */
	.size	master_handle_interrupts, .-master_handle_interrupts

.globl slave_entry
	.type	slave_entry, @function
slave_entry:
	mov	28(%rsp), %ebx /* sh2cycles */
	mov	%esi, master_cc
	mov	%ebx, %edi
	call	FRTExec
	mov	%ebx, %edi
	call	WDTExec
	mov	slave_ip, %rdx
	test	%edx, %edx
	je	cc_interrupt_master /* slave not running */
	mov	SSH2, %rax
	mov	NumberOfInterruptsOffset, %ecx
	mov	%rax, CurrentSH2
	cmp	$0, (%rax, %rcx)
	jne	slave_handle_interrupts
	mov	slave_cc, %esi
	sub	%ebx, %esi
	jmp	*%rdx /* jmp *slave_ip */
	.size	slave_entry, .-slave_entry

.globl slave_handle_interrupts
	.type	slave_handle_interrupts, @function
slave_handle_interrupts:
	call	DynarecSlaveHandleInterrupts
	mov	slave_ip, %rdx
	mov	slave_cc, %esi
	sub	%ebx, %esi
	jmp	*%rdx /* jmp *slave_ip */
	.size	slave_handle_interrupts, .-slave_handle_interrupts

.globl cc_interrupt
	.type	cc_interrupt, @function
cc_interrupt: /* slave */
	mov	28(%rsp), %ebx /* sh2cycles */
	mov	%rbp, slave_ip
	mov	%esi, slave_cc
	mov	%ebx, %edi
	call	FRTExec
	mov	%ebx, %edi
	call	WDTExec
	.size	cc_interrupt, .-cc_interrupt
.globl cc_interrupt_master
	.type	cc_interrupt_master, @function
cc_interrupt_master:
	lea	80(%rsp), %rbp
	mov	-44(%rbp), %eax /* decilinecount */
	mov	-48(%rbp), %ebx /* decilinecycles */
	inc	%eax
	cmp	$9, %eax
	ja	.A3
	mov	%eax, -44(%rbp) /* decilinecount++ */
	je	.A2
	mov	%ebx, -52(%rbp) /* sh2cycles */
.A1:
	mov	master_cc, %esi
	mov	MSH2, %rax
	mov	NumberOfInterruptsOffset, %ecx
	mov	%rax, CurrentSH2
	cmpl	$0, (%rax, %rcx)
	jne	master_handle_interrupts
	sub	%ebx, %esi
	ret	/* jmp master_ip */	
.A2:
	call	Vdp2HBlankIN
	jmp	.A1
.A3:
	mov	-56(%rbp), %edi /* scucycles */
	call	ScuExec
	call	M68KSync
	call	Vdp2HBlankOUT
	call	ScspExec
	mov	linecount_p, %rbx
	mov	maxlinecount_p, %rax
	mov	vblanklinecount_p, %rcx
	mov	(%rbx), %edx
	mov	(%rax), %eax
	mov	(%rcx), %ecx
	inc	%edx
	andl	$0, -44(%rbp) /* decilinecount=0 */
	cmp	%eax, %edx /* max ? */
	je	nextframe
	mov	%edx, (%rbx) /* linecount++ */
	cmp	%ecx, %edx /* vblank ? */
	je	vblankin
nextline:
	call	finishline
	jmp	newline
finishline:
      /*const u32 usecinc = yabsys.DecilineUsec * 10;*/
	mov	decilineusec_p, %rax
	mov	UsecFrac_p, %rbx
	mov	yabsys_timing_bits, %ecx
	mov	(%rax), %eax
	mov	(%rbx), %edx
	lea	(%eax,%eax,4), %edi
	add	%edi, %edi
      /*yabsys.UsecFrac += usecinc;*/
	add	%edx, %edi
	add	$-8, %rsp /* Align stack */
      /*SmpcExec(yabsys.UsecFrac >> YABSYS_TIMING_BITS);
      /*Cs2Exec(yabsys.UsecFrac >> YABSYS_TIMING_BITS);
      /*yabsys.UsecFrac &= YABSYS_TIMING_MASK;*/
	mov	%edi, (%rbx) /* UsecFrac */
	shr	%cl, %edi
	call	SmpcExec
	/* SmpcExec may modify UsecFrac; must reload it */
	mov	yabsys_timing_mask, %r12d
	mov	(%rbx), %edi /* UsecFrac */
	mov	yabsys_timing_bits, %ecx
	and	%edi, %r12d
	shr	%cl, %edi
	call	Cs2Exec
	mov	%r12d, (%rbx) /* UsecFrac */
	mov	saved_centicycles, %ecx
	mov	-60(%rbp), %ebx /* m68kcenticycles */
	mov	-64(%rbp), %edi /* m68kcycles */
	add	%ebx, %ecx
	mov	%ecx, %ebx
	add	$-100, %ecx
	cmovnc	%ebx, %ecx
	adc	$0, %edi
	mov	%ecx, saved_centicycles
	call	M68KExec
	add	$8, %rsp /* Align stack */
	ret
vblankin:
	call	SmpcINTBACKEnd
	call	Vdp2VBlankIN
	call	CheatDoPatches
	jmp	nextline
nextframe:
	call	Vdp2VBlankOUT
	andl	$0, (%rbx) /* linecount = 0 */
	call	finishline
	call	M68KSync
	mov	rccount, %esi
	inc	%esi
	andl	$0, invalidate_count
	and	$0x3f, %esi
	cmpl	$0, restore_candidate(,%esi,4)
	mov	%esi, rccount
	jne	.A5
.A4:
	mov	(%rsp), %rax
	add	$40, %rsp
	mov	%rax, master_ip
	pop	%r15 /* restore callee-save registers */
	pop	%r14
	pop	%r13
	pop	%r12
	pop	%rbx
	pop	%rbp
	ret
.A5:
	/* Move 'dirty' blocks to the 'clean' list */
	mov	restore_candidate(,%esi,4), %ebx
	mov	%esi, %ebp
	andl	$0, restore_candidate(,%esi,4)
	shl	$5, %ebp
.A6:
	shr	$1, %ebx
	jnc	.A7
	mov	%ebp, %edi
	call	clean_blocks
.A7:
	inc	%ebp
	test	$31, %ebp
	jne	.A6
	jmp	.A4
	.size	cc_interrupt_master, .-cc_interrupt_master

.globl dyna_linker
	.type	dyna_linker, @function
dyna_linker:
	/* eax = virtual target address */
	/* ebx = instruction to patch */
	mov	%eax, %ecx
	mov	$1023, %edx
	shr	$12, %ecx
	and	%ecx, %edx
	and	$0xDFFFF, %ecx
	or	$1024, %edx
	cmp	%edx, %ecx
	cmova	%edx, %ecx
	/* jump_in lookup */
	movq	jump_in(,%ecx,8), %r12
.B1:
	test	%r12, %r12
	je	.B3
	mov	(%r12), %edi
	xor	%eax, %edi
	je	.B2
	movq	16(%r12), %r12
	jmp	.B1
.B2:
	mov	(%ebx), %edi
	mov	%esi, %ebp
	lea	4(%ebx,%edi,1), %esi
	mov	%eax, %edi
	call	add_link
	mov	8(%r12), %edi
	mov	%ebp, %esi
	lea	-4(%edi), %edx
	subl	%ebx, %edx
	movl	%edx, (%ebx)
	jmp	*%rdi
.B3:
	/* hash_table lookup */
	mov	%eax, %edi
	shr	$16, %edi
	xor	%eax, %edi
	movzwl	%di, %edi
	shl	$4, %edi
	cmp	hash_table(%edi), %eax
	jne	.B5
.B4:
	mov	hash_table+4(%edi), %edx
	jmp	*%rdx
.B5:
	cmp	hash_table+8(%edi), %eax
	lea	8(%edi), %edi
	je	.B4
	/* jump_dirty lookup */
	movq	jump_dirty(,%ecx,8), %r12
.B6:
	test	%r12, %r12
	je	.B8
	mov	(%r12), %ecx
	xor	%eax, %ecx
	je	.B7
	movq	16(%r12), %r12
	jmp	.B6
.B7:
	movl	8(%r12), %edx
	/* hash_table insert */
	mov	hash_table-8(%edi), %ebx
	mov	hash_table-4(%edi), %ecx
	mov	%eax, hash_table-8(%edi)
	mov	%edx, hash_table-4(%edi)
	mov	%ebx, hash_table(%edi)
	mov	%ecx, hash_table+4(%edi)
	jmp	*%rdx
.B8:
	mov	%eax, %edi
	mov	%eax, %ebp /* Note: assumes %rbx and %rbp are callee-saved */
	mov	%esi, %r12d
	call	sh2_recompile_block
	test	%eax, %eax
	mov	%ebp, %eax
	mov	%r12d, %esi
	je	dyna_linker
	/* shouldn't happen */
	int3
	.size	dyna_linker, .-dyna_linker

.globl jump_vaddr_eax_master
	.type	jump_vaddr_eax_master, @function
jump_vaddr_eax_master:
	mov	%eax, %edi
	jmp	jump_vaddr_edi_master
	.size	jump_vaddr_eax_master, .-jump_vaddr_eax_master
.globl jump_vaddr_ecx_master
	.type	jump_vaddr_ecx_master, @function
jump_vaddr_ecx_master:
	mov	%ecx, %edi
	jmp	jump_vaddr_edi_master
	.size	jump_vaddr_ecx_master, .-jump_vaddr_ecx_master
.globl jump_vaddr_edx_master
	.type	jump_vaddr_edx_master, @function
jump_vaddr_edx_master:
	mov	%edx, %edi
	jmp	jump_vaddr_edi_master
	.size	jump_vaddr_edx_master, .-jump_vaddr_edx_master
.globl jump_vaddr_ebx_master
	.type	jump_vaddr_ebx_master, @function
jump_vaddr_ebx_master:
	mov	%ebx, %edi
	jmp	jump_vaddr_edi_master
	.size	jump_vaddr_ebx_master, .-jump_vaddr_ebx_master
.globl jump_vaddr_ebp_master
	.type	jump_vaddr_ebp_master, @function
jump_vaddr_ebp_master:
	mov	%ebp, %edi
	jmp	jump_vaddr_edi_master
	.size	jump_vaddr_ebp_master, .-jump_vaddr_ebp_master
.globl jump_vaddr_eax_slave
	.type	jump_vaddr_eax_slave, @function
jump_vaddr_eax_slave:
	mov	%eax, %edi
	jmp	jump_vaddr_edi_slave
	.size	jump_vaddr_eax_slave, .-jump_vaddr_eax_slave
.globl jump_vaddr_ecx_slave
	.type	jump_vaddr_ecx_slave, @function
jump_vaddr_ecx_slave:
	mov	%ecx, %edi
	jmp	jump_vaddr_edi_slave
	.size	jump_vaddr_ecx_slave, .-jump_vaddr_ecx_slave
.globl jump_vaddr_edx_slave
	.type	jump_vaddr_edx_slave, @function
jump_vaddr_edx_slave:
	mov	%edx, %edi
	jmp	jump_vaddr_edi_slave
	.size	jump_vaddr_edx_slave, .-jump_vaddr_edx_slave
.globl jump_vaddr_ebx_slave
	.type	jump_vaddr_ebx_slave, @function
jump_vaddr_ebx_slave:
	mov	%ebx, %edi
	jmp	jump_vaddr_edi_slave
	.size	jump_vaddr_ebx_slave, .-jump_vaddr_ebx_slave
.globl jump_vaddr_ebp_slave
	.type	jump_vaddr_ebp_slave, @function
jump_vaddr_ebp_slave:
	mov	%ebp, %edi
	.size	jump_vaddr_ebp_slave, .-jump_vaddr_ebp_slave
.globl jump_vaddr_edi_slave
	.type	jump_vaddr_edi_slave, @function
jump_vaddr_edi_slave:
	or	$1, %edi
	.size	jump_vaddr_edi_slave, .-jump_vaddr_edi_slave
.globl jump_vaddr_edi_master
	.type	jump_vaddr_edi_master, @function
jump_vaddr_edi_master:
	mov	%edi, %eax
	.size	jump_vaddr_edi_master, .-jump_vaddr_edi_master

.globl jump_vaddr
	.type	jump_vaddr, @function
jump_vaddr:
  /* Check hash table */
	shr	$16, %eax
	xor	%edi, %eax
	movzwl	%ax, %eax
	shl	$4, %eax
	cmp	hash_table(%eax), %edi
	jne	.C2
.C1:
	mov	hash_table+4(%eax), %edi
	jmp	*%rdi
.C2:
	cmp	hash_table+8(%eax), %edi
	lea	8(%eax), %eax
	je	.C1
  /* No hit on hash table, call compiler */
	mov	%esi, %ebx /* CCREG */
	call	get_addr
	mov	%ebx, %esi
	jmp	*%rax
	.size	jump_vaddr, .-jump_vaddr

.globl verify_code
	.type	verify_code, @function
verify_code:
	/* rax = source */
	/* ebx = target */
	/* ecx = length */
	/* r12d = instruction pointer */
	mov	-4(%rax,%rcx,1), %edi
	xor	-4(%ebx,%ecx,1), %edi
	jne	.D4
	mov	%ecx, %edx
	add	$-4, %ecx
	je	.D3
	test	$4, %edx
	cmove	%edx, %ecx
.D2:
	mov	-8(%rax,%rcx,1), %rdi
	cmp	-8(%ebx,%ecx,1), %rdi
	jne	.D4
	add	$-8, %ecx
	jne	.D2
.D3:
	ret
.D4:
	add	$8, %rsp /* pop return address, we're not returning */
	mov	%r12d, %edi
	mov	%esi, %ebx
	call	get_addr
	mov	%ebx, %esi
	jmp	*%rax
	.size	verify_code, .-verify_code

.globl WriteInvalidateLong
	.type	WriteInvalidateLong, @function
WriteInvalidateLong:
	mov	%edi, %ecx
	shr	$12, %ecx
	bt	%ecx, cached_code
	jnc	MappedMemoryWriteLong
	/*push	%rax*/
	/*push	%rcx*/
	push	%rdx /* unused, for stack alignment */
	push	%rsi
	push	%rdi
	call	invalidate_addr
	pop	%rdi
	pop	%rsi
	pop	%rdx /* unused, for stack alignment */
	/*pop	%rcx*/
	/*pop	%rax*/
	jmp	MappedMemoryWriteLong
	.size	WriteInvalidateLong, .-WriteInvalidateLong
.globl WriteInvalidateWord
	.type	WriteInvalidateWord, @function
WriteInvalidateWord:
	mov	%edi, %ecx
	shr	$12, %ecx
	bt	%ecx, cached_code
	jnc	MappedMemoryWriteWord
	/*push	%rax*/
	/*push	%rcx*/
	push	%rdx /* unused, for stack alignment */
	push	%rsi
	push	%rdi
	call	invalidate_addr
	pop	%rdi
	pop	%rsi
	pop	%rdx /* unused, for stack alignment */
	/*pop	%rcx*/
	/*pop	%rax*/
	jmp	MappedMemoryWriteWord
	.size	WriteInvalidateWord, .-WriteInvalidateWord
.globl WriteInvalidateByteSwapped
	.type	WriteInvalidateByteSwapped, @function
WriteInvalidateByteSwapped:
	xor	$1, %edi
	.size	WriteInvalidateByteSwapped, .-WriteInvalidateByteSwapped
.globl WriteInvalidateByte
	.type	WriteInvalidateByte, @function
WriteInvalidateByte:
	mov	%edi, %ecx
	shr	$12, %ecx
	bt	%ecx, cached_code
	jnc	MappedMemoryWriteByte
	/*push	%rax*/
	/*push	%rcx*/
	push	%rdx /* unused, for stack alignment */
	push	%rsi
	push	%rdi
	call	invalidate_addr
	pop	%rdi
	pop	%rsi
	pop	%rdx /* unused, for stack alignment */
	/*pop	%rcx*/
	/*pop	%rax*/
	jmp	MappedMemoryWriteByte
	.size	WriteInvalidateByte, .-WriteInvalidateByte

.globl div1
	.type	div1, @function
div1:
	/* eax = dividend */
	/* ecx = divisor */
	/* edx = sr */
	bt	$9, %edx   /* M bit */
	jc	div1_negative_divisor
	bts	$0, %edx   /* Get T bit and set */
	adc 	%eax, %eax /* rn=(rn<<1)+T */
	adc	%ebx, %ebx /* New Q in ebx */
	mov	%ecx, %ebp
	btr	$8, %edx   /* Get Q bit and clear it */
	cmc
	sbb	%edi, %edi /* 0xFFFFFFFF if old_Q clear, 0 otherwise */
	sbb	$0, %ebp
	xor	%edi, %ebp
	add	%ebp, %eax /* rn+rm if old_Q, rn-rm if !old_Q */
		           /* carry set if rn < old_rn */
	adc	%edi, %ebx /* low bit = (rn<old_rn)^new_Q^!old_Q */
	                   /* inverted for old_Q==0, ie (rn>=old_rn)^new_Q */
	not	%edi	   /* if old_Q clear, edi=0 */
	or	%ebp, %edi /* zero if old_Q==0 && rn==old_rn */
	neg	%edi       /* clear carry if edi==0 */
	adc	$-1, %ebx  /* invert result for old_Q==0 && rn==old_rn */
	and	$1, %ebx
	xor	%ebx, %edx /* New T = (Q==M) */
	shl	$8, %ebx
	or	%ebx, %edx /* save new Q */
/*
	push	%edx
	push	%eax
	push	%ecx
	call	debug_division
	pop	%ecx
	pop	%eax
	pop	%edx
*/
	ret
div1_negative_divisor:
	btr	$0, %edx   /* Get T bit and clear */
	adc 	%eax, %eax /* rn=(rn<<1)+T */
	adc	%ebx, %ebx /* New Q in ebx */
	mov	%ecx, %ebp
	btr	$8, %edx   /* Get Q bit and clear it */
	sbb	%edi, %edi /* 0xFFFFFFFF if old_Q set, 0 otherwise */
	sbb	$0, %ebp
	xor	%edi, %ebp
	not	%edi	   /* if old_Q clear, edi=-1 */
	add	%ebp, %eax /* rn+rm if !old_Q, rn-rm if old_Q */
		           /* carry set if rn < old_rn */
	adc	%edi, %ebx /* low bit = (rn<old_rn)^new_Q^!old_Q */
	                   /* inverted for old_Q==0, ie (rn>=old_rn)^new_Q */
	or	%ebp, %edi /* zero if old_Q==1 && rn==old_rn */
	neg	%edi       /* clear carry if edi==0 */
	adc	$-1, %ebx  /* invert result for old_Q==1 && rn==old_rn */
	and	$1, %ebx
	xor	%ebx, %edx /* New T = (Q==M) */
	shl	$8, %ebx
	or	%ebx, %edx /* save new Q */
	ret
	.size	div1, .-div1

.globl macl
	.type	macl, @function
macl:
	/* ebx = sr */
	/* ebp = multiplicand address */
	/* edi = multiplicand address */
	/* eax = return MACL */
	/* edx = return MACH */
	mov	%edx, %r12d /* MACH */
	mov	%eax, %r13d /* MACL */
	mov	%ebp, %r14d
	mov	%edi, %r15d
	call	MappedMemoryReadLong
	mov	%eax, %esi
	mov	%r14d, %edi
	call	MappedMemoryReadLong
	lea	4(%r14), %ebp
	lea	4(%r15), %edi
	imul	%esi
	add	%r13d, %eax /* MACL */
	adc	%r12d, %edx /* MACH */
	test	$0x2, %bl
	jne	macl_saturation
	ret
macl_saturation:
	mov	$0xFFFF8000, %esi
	xor	%ecx, %ecx
	cmp	%esi, %edx
	cmovl	%esi, %edx
	cmovl	%ecx, %eax
	not	%esi
	not	%ecx
	cmp	%esi, %edx
	cmovg	%esi, %edx
	cmovg	%ecx, %eax
	ret
	.size	macl, .-macl

.globl macw
	.type	macw, @function
macw:
	/* ebx = sr */
	/* ebp = multiplicand address */
	/* edi = multiplicand address */
	/* eax = return MACL */
	/* edx = return MACH */
	mov	%edx, %r12d /* MACH */
	mov	%eax, %r13d /* MACL */
	mov	%ebp, %r14d
	mov	%edi, %r15d
	call	MappedMemoryReadWord
	movswl	%ax, %esi
	mov	%r14d, %edi
	call	MappedMemoryReadWord
	movswl	%ax, %eax
	lea	2(%r14), %ebp
	lea	2(%r15), %edi
	imul	%esi
	test	$0x2, %bl
	jne	macw_saturation
	add	%r13d, %eax /* MACL */
	adc	%r12d, %edx /* MACH */
	ret
macw_saturation:
	mov	%r13d, %esi
	sar	$31, %esi
	add	%r13d, %eax /* MACL */
	adc	%esi, %edx
	mov	$0x80000000, %esi
	mov	$0x7FFFFFFF, %ecx
	add	%eax, %esi
	adc	$0, %edx
	cmovne	%ecx, %eax
	not	%ecx
	cmovl	%ecx, %eax
	mov	%r12d, %edx
	ret
	.size	macw, .-macw

.globl master_handle_bios
	.type	master_handle_bios, @function
master_handle_bios:
	mov	(%rsp), %rdx /* get return address */
	mov	%eax, master_pc
	mov	%esi, master_cc
	mov	%rdx, master_ip
	mov	MSH2, %rdi
	call	BiosHandleFunc
	mov	master_ip, %rdx
	mov	master_cc, %esi
	mov	%rdx, (%rsp)
	ret	/* jmp *master_ip */
	.size	master_handle_bios, .-master_handle_bios

.globl slave_handle_bios
	.type	slave_handle_bios, @function
slave_handle_bios:
	pop	%rdx /* get return address */
	mov	%eax, slave_pc
	mov	%esi, slave_cc
	mov	%rdx, slave_ip
	mov	SSH2, %rdi
	call	BiosHandleFunc
	mov	slave_ip, %rdx
	mov	slave_cc, %esi
	jmp	*%rdx /* jmp *slave_ip */
	.size	slave_handle_bios, .-slave_handle_bios

.globl breakpoint
	.type	breakpoint, @function
breakpoint:
	ret
	/* Set breakpoint here for debugging */
	.size	breakpoint, .-breakpoint
