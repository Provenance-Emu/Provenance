/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Yabause - linkage_x86.s                                               *
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
	.file	"linkage_x86.s"
	.bss
	.align 4
	.section	.rodata
	.text
.globl YabauseDynarecOneFrameExec
	.type	YabauseDynarecOneFrameExec, @function
YabauseDynarecOneFrameExec:
	push	%ebp
	mov	%esp,%ebp
	mov	master_ip, %eax
	xor	%ecx, %ecx
	push	%edi
	push	%esi
	push	%ebx
	push	%ecx /* zero */
	push	%ecx
	push	%ecx
	push	%ecx
	push	%ecx /* put m68k here (?) */
	push	%ecx
	call	.+5 /* 40+4=44 */
	mov	%eax,-40(%ebp) /* overwrite return address */
/* Stack frame:
   arg2 - m68kcenticycles (+8/+12)
   arg1 - m68kcycles (+4/+8)
   return address (0)
   ebp (4/0)
   save edi (8/4)
   save esi (12/8)
   save ebx (16/12)
   decilinecount (20/16)
   decilinecycles (24/20)
   sh2cycles (28/24)
   scucycles (32/28)
   ... (36/32)
   ... (40/36)
   ret address/master_ip (44/40) (alternate esp at call)
   save %eax (48/44)
   save %ecx (52/48)
   save %edx (56/52)
   ... (esp at call)
   next return address (64/60)
   total = 64 */
/*   usecinc?
   cyclesinc?*/

newline:
/* const u32 decilinecycles = yabsys.DecilineStop >> YABSYS_TIMING_BITS; */
/* const u32 cyclesinc = yabsys.DecilineStop * 10; */
	mov	decilinestop_p, %eax
	mov	yabsys_timing_bits, %ecx
	mov	(%eax), %eax
	lea	(%eax,%eax,4), %ebx /* decilinestop*5 */
	shr	%cl, %eax /* decilinecycles */
	shl	%ebx	/* cyclesinc=decilinestop*10 */
	lea	(%eax,%eax,8), %edx  /* decilinecycles*9 */
        /* yabsys.SH2CycleFrac += cyclesinc;*/
        /* sh2cycles = (yabsys.SH2CycleFrac >> (YABSYS_TIMING_BITS + 1)) << 1;*/
        /* yabsys.SH2CycleFrac &= ((YABSYS_TIMING_MASK << 1) | 1);*/
	mov	SH2CycleFrac_p, %esi
	mov	yabsys_timing_mask, %edi
	inc	%ecx /* yabsys_timing_bits+1 */
	add	(%esi), %ebx /* SH2CycleFrac */
	stc
	adc	%edi, %edi /* ((YABSYS_TIMING_MASK << 1) | 1) */
	mov	%eax, -20(%ebp) /* decilinecycles */
	and	%ebx, %edi
	mov	%edi, (%esi) /* SH2CycleFrac */
	shr	%cl, %ebx
	mov	%ebx, -28(%ebp) /* scucycles */
	add	%ebx, %ebx /* sh2cycles */
	mov	MSH2, %eax
	mov	NumberOfInterruptsOffset, %ecx
	sub	%edx, %ebx  /* sh2cycles(full line) - decilinecycles*9 */
	mov	%eax, CurrentSH2
	mov	%ebx, -24(%ebp) /* sh2cycles */
	cmp	$0, (%eax, %ecx)
	jne	master_handle_interrupts
	mov	master_cc, %esi
	sub	%ebx, %esi
	ret	/* jmp master_ip */
	.size	YabauseDynarecOneFrameExec, .-YabauseDynarecOneFrameExec

.globl master_handle_interrupts
	.type	master_handle_interrupts, @function
master_handle_interrupts:
	mov	-40(%ebp), %eax /* get return address */
	mov	%eax, master_ip
	call	DynarecMasterHandleInterrupts
	mov	master_ip, %eax
	mov	master_cc, %esi
	mov	%eax,-40(%ebp) /* overwrite return address */
	sub	%ebx, %esi
	ret	/* jmp master_ip */
	.size	master_handle_interrupts, .-master_handle_interrupts

.globl slave_entry
	.type	slave_entry, @function
slave_entry:
	mov	16(%esp), %ebx /* sh2cycles */
	mov	%esi, master_cc
	sub	$12, %esp
	push	%ebx
	call	FRTExec
	mov	%ebx, (%esp)
	call	WDTExec
	mov	slave_ip, %edx
	add	$16, %esp
	test	%edx, %edx
	je	cc_interrupt_master /* slave not running */
	mov	SSH2, %eax
	mov	NumberOfInterruptsOffset, %ecx
	mov	%eax, CurrentSH2
	cmp	$0, (%eax, %ecx)
	jne	slave_handle_interrupts
	mov	slave_cc, %esi
	sub	%ebx, %esi
	jmp	*%edx /* jmp *slave_ip */
	.size	slave_entry, .-slave_entry

.globl slave_handle_interrupts
	.type	slave_handle_interrupts, @function
slave_handle_interrupts:
	call	DynarecSlaveHandleInterrupts
	mov	slave_ip, %edx
	mov	slave_cc, %esi
	sub	%ebx, %esi
	jmp	*%edx /* jmp *slave_ip */
	.size	slave_handle_interrupts, .-slave_handle_interrupts

.globl cc_interrupt
	.type	cc_interrupt, @function
cc_interrupt: /* slave */
	mov	16(%esp), %ebx /* sh2cycles */
	mov	%ebp, slave_ip
	mov	%esi, slave_cc
	add	$-12, %esp
	push	%ebx
	call	FRTExec
	mov	%ebx, (%esp)
	call	WDTExec
	add	$16, %esp
	.size	cc_interrupt, .-cc_interrupt
.globl cc_interrupt_master
	.type	cc_interrupt_master, @function
cc_interrupt_master:
	lea	40(%esp), %ebp
	mov	-16(%ebp), %eax /* decilinecount */
	mov	-20(%ebp), %ebx /* decilinecycles */
	inc	%eax
	cmp	$9, %eax
	ja	.A3
	mov	%eax, -16(%ebp) /* decilinecount++ */
	je	.A2
	mov	%ebx, -24(%ebp) /* sh2cycles */
.A1:
	mov	master_cc, %esi
	mov	MSH2, %eax
	mov	NumberOfInterruptsOffset, %ecx
	mov	%eax, CurrentSH2
	cmp	$0, (%eax, %ecx)
	jne	master_handle_interrupts
	sub	%ebx, %esi
	ret	/* jmp master_ip */	
.A2:
	call	Vdp2HBlankIN
	jmp	.A1
.A3:
	mov	-28(%ebp), %ebx /* scucycles */
	add	$-12, %esp
	push	%ebx
	call	ScuExec
	call	M68KSync
	call	Vdp2HBlankOUT
	call	ScspExec
	mov	linecount_p, %ebx
	mov	maxlinecount_p, %eax
	mov	vblanklinecount_p, %ecx
	mov	(%ebx), %edx
	mov	(%eax), %eax
	mov	(%ecx), %ecx
	inc	%edx
	andl	$0, -16(%ebp) /* decilinecount=0 */
	cmp	%eax, %edx /* max ? */
	je	nextframe
	mov	%edx, (%ebx) /* linecount++ */
	cmp	%ecx, %edx /* vblank ? */
	je	vblankin
nextline:
	add	$16, %esp
	call	finishline
	jmp	newline
finishline: /* CHECK - Stack align? */
      /*const u32 usecinc = yabsys.DecilineUsec * 10;*/
	mov	decilineusec_p, %eax
	mov	UsecFrac_p, %ebx
	mov	yabsys_timing_bits, %ecx
	mov	(%eax), %eax
	mov	(%ebx), %edx
	lea	(%eax,%eax,4), %esi
	mov	yabsys_timing_mask, %edi
	add	%esi, %esi
      /*yabsys.UsecFrac += usecinc;*/
	add	%edx, %esi
	add	$-8, %esp /* Align stack */
      /*SmpcExec(yabsys.UsecFrac >> YABSYS_TIMING_BITS);
      /*Cs2Exec(yabsys.UsecFrac >> YABSYS_TIMING_BITS);
      /*yabsys.UsecFrac &= YABSYS_TIMING_MASK;*/
	mov	%esi, (%ebx) /* UsecFrac */
	shr	%cl, %esi
	push	%esi
	call	SmpcExec
	/* SmpcExec may modify UsecFrac; must reload it */
	mov	(%ebx), %esi /* UsecFrac */
	mov	yabsys_timing_bits, %ecx
	and	%esi, %edi
	shr	%cl, %esi
	mov	%esi, (%esp)
	call	Cs2Exec
	mov	%edi, (%ebx) /* UsecFrac */
	mov	saved_centicycles, %ecx
	mov	12(%ebp), %ebx /* m68kcenticycles */
	mov	8(%ebp), %eax /* m68kcycles */
	add	%ebx, %ecx
	mov	%ecx, %ebx
	add	$-100, %ecx
	cmovnc	%ebx, %ecx
	adc	$0, %eax
	mov	%ecx, saved_centicycles
	mov	%eax, (%esp) /* cycles */
	call	M68KExec
	add	$12, %esp
	ret
vblankin:
	call	SmpcINTBACKEnd
	call	Vdp2VBlankIN
	call	CheatDoPatches
	jmp	nextline
nextframe:
	call	Vdp2VBlankOUT
	andl	$0, (%ebx) /* linecount = 0 */
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
	mov	16(%esp), %eax
	add	$44, %esp
	mov	%eax, master_ip
	pop	%ebx
	pop	%esi
	pop	%edi
	pop	%ebp
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
	mov	%ebp, (%esp)
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
	mov	jump_in(,%ecx,4), %edx
.B1:
	test	%edx, %edx
	je	.B3
	mov	(%edx), %edi
	xor	%eax, %edi
	je	.B2
	movl	12(%edx), %edx
	jmp	.B1
.B2:
	mov	(%ebx), %edi
	mov	%esi, %ebp
	lea	4(%ebx,%edi,1), %esi
	mov	%eax, %edi
	pusha
	call	add_link
	popa
	mov	8(%edx), %edi
	mov	%ebp, %esi
	lea	-4(%edi), %edx
	subl	%ebx, %edx
	movl	%edx, (%ebx)
	jmp	*%edi
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
	jmp	*%edx
.B5:
	cmp	hash_table+8(%edi), %eax
	lea	8(%edi), %edi
	je	.B4
	/* jump_dirty lookup */
	mov	jump_dirty(,%ecx,4), %edx
.B6:
	testl	%edx, %edx
	je	.B8
	mov	(%edx), %ecx
	xor	%eax, %ecx
	je	.B7
	movl	12(%edx), %edx
	jmp	.B6
.B7:
	mov	8(%edx), %edx
	/* hash_table insert */
	mov	hash_table-8(%edi), %ebx
	mov	hash_table-4(%edi), %ecx
	mov	%eax, hash_table-8(%edi)
	mov	%edx, hash_table-4(%edi)
	mov	%ebx, hash_table(%edi)
	mov	%ecx, hash_table+4(%edi)
	jmp	*%edx
.B8:
	mov	%eax, %edi
	pusha
	call	sh2_recompile_block
	test	%eax, %eax
	popa
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
	jmp	*%edi
.C2:
	cmp	hash_table+8(%eax), %edi
	lea	8(%eax), %eax
	je	.C1
  /* No hit on hash table, call compiler */
	push	%edi
	call	get_addr
	add	$4, %esp
	jmp	*%eax
	.size	jump_vaddr, .-jump_vaddr

.globl verify_code
	.type	verify_code, @function
verify_code:
	/* eax = source */
	/* ebx = target */
	/* ecx = length */
	mov	-4(%eax,%ecx,1), %edi
	xor	-4(%ebx,%ecx,1), %edi
	jne	.D5
	mov	%ecx, %edx
	add	$-4, %ecx
	je	.D3
	test	$4, %edx
	cmove	%edx, %ecx
	push	%esi
.D2:
	mov	-4(%eax,%ecx,1), %edx
	mov	-4(%ebx,%ecx,1), %ebp
	mov	-8(%eax,%ecx,1), %esi
	xor	%edx, %ebp
	mov	-8(%ebx,%ecx,1), %edi
	jne	.D4
	xor	%esi, %edi
	jne	.D4
	add	$-8, %ecx
	jne	.D2
	pop	%esi
.D3:
	ret
.D4:
	pop	%esi
.D5:
	add	$4, %esp /* pop return address, we're not returning */
	call	get_addr
	add	$4, %esp /* pop virtual address */
	jmp	*%eax
	.size	verify_code, .-verify_code

.globl WriteInvalidateLong
	.type	WriteInvalidateLong, @function
WriteInvalidateLong:
	mov	%eax, %ecx
	shr	$12, %ecx
	bt	%ecx, cached_code
	jnc	MappedMemoryWriteLong
	push	%eax
	push	%edx
	push	%eax
	call	invalidate_addr
	pop	%eax
	pop	%edx
	pop	%eax
	jmp	MappedMemoryWriteLong
	.size	WriteInvalidateLong, .-WriteInvalidateLong
.globl WriteInvalidateWord
	.type	WriteInvalidateWord, @function
WriteInvalidateWord:
	mov	%eax, %ecx
	shr	$12, %ecx
	bt	%ecx, cached_code
	jnc	MappedMemoryWriteWord
	push	%eax
	push	%edx
	push	%eax
	call	invalidate_addr
	pop	%eax
	pop	%edx
	pop	%eax
	jmp	MappedMemoryWriteWord
	.size	WriteInvalidateWord, .-WriteInvalidateWord
.globl WriteInvalidateByteSwapped
	.type	WriteInvalidateByteSwapped, @function
WriteInvalidateByteSwapped:
	xor	$1, %eax
	.size	WriteInvalidateByteSwapped, .-WriteInvalidateByteSwapped
.globl WriteInvalidateByte
	.type	WriteInvalidateByte, @function
WriteInvalidateByte:
	mov	%eax, %ecx
	shr	$12, %ecx
	bt	%ecx, cached_code
	jnc	MappedMemoryWriteByte
	push	%eax
	push	%edx
	push	%eax
	call	invalidate_addr
	pop	%eax
	pop	%edx
	pop	%eax
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
	push	%edx /* MACH */
	push	%eax /* MACL */
	mov	%edi, %eax
	call	MappedMemoryReadLong
	mov	%eax, %esi
	mov	%ebp, %eax
	call	MappedMemoryReadLong
	add	$4, %ebp
	add	$4, %edi
	imul	%esi
	add	(%esp), %eax /* MACL */
	adc	4(%esp), %edx /* MACH */
	add	$8, %esp
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
	push	%edx /* MACH */
	push	%eax /* MACL */
	mov	%edi, %eax
	call	MappedMemoryReadWord
	movswl	%ax, %esi
	mov	%ebp, %eax
	call	MappedMemoryReadWord
	movswl	%ax, %eax
	add	$2, %ebp
	add	$2, %edi
	imul	%esi
	test	$0x2, %bl
	jne	macw_saturation
	add	(%esp), %eax /* MACL */
	adc	4(%esp), %edx /* MACH */
	add	$8, %esp
	ret
macw_saturation:
	mov	(%esp), %esi
	sar	$31, %esi
	add	(%esp), %eax /* MACL */
	adc	%esi, %edx
	mov	$0x80000000, %esi
	mov	$0x7FFFFFFF, %ecx
	add	%eax, %esi
	adc	$0, %edx
	cmovne	%ecx, %eax
	not	%ecx
	cmovl	%ecx, %eax
	pop	%edx
	pop	%edx
	ret
	.size	macw, .-macw

.globl master_handle_bios
	.type	master_handle_bios, @function
master_handle_bios:
	mov	(%esp), %edx /* get return address */
	mov	%eax, master_pc
	mov	%esi, master_cc
	mov	%edx, master_ip
	mov	MSH2, %eax
	call	BiosHandleFunc
	mov	master_ip, %edx
	mov	master_cc, %esi
	mov	%edx, (%esp)
	ret	/* jmp *master_ip */
	.size	master_handle_bios, .-master_handle_bios

.globl slave_handle_bios
	.type	slave_handle_bios, @function
slave_handle_bios:
	pop	%edx /* get return address */
	mov	%eax, slave_pc
	mov	%esi, slave_cc
	mov	%edx, slave_ip
	mov	SSH2, %eax
	call	BiosHandleFunc
	mov	slave_ip, %edx
	mov	slave_cc, %esi
	jmp	*%edx /* jmp *slave_ip */
	.size	slave_handle_bios, .-slave_handle_bios

.globl breakpoint
	.type	breakpoint, @function
breakpoint:
	ret
	/* Set breakpoint here for debugging */
	.size	breakpoint, .-breakpoint
