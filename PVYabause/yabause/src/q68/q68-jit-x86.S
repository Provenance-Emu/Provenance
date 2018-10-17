/*  src/q68/q68-jit-x86.S: x86 (32/64-bit) dynamic translation implementation
                           for Q68
    Copyright 2009-2010 Andrew Church

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "q68-const.h"

/*************************************************************************/

/*
 * Register usage on x86 and x64 is as follows (for x86, read %rXX as %eXX):
 *
 * %rax -- result, temporary
 * %rbx -- Q68State structure pointer
 * %rcx -- temporary
 * %rdx -- operand 2
 * %rsi -- cumulative cycle count
 * %rdi -- operand 1, (on termination) pointer to next address to execute
 *
 * Additionally, the cycle limit is pushed onto the stack at the start of
 * execution.
 */

/*************************************************************************/

/* Define handy macros so we can use the same source on both x86 and x64 */

#ifdef CPU_X64

/* External routine calling macros (indirect calls only) */
.macro CALL1 address, arg1
	push %rsi
	push %rdi
	mov \arg1, %rdi
	call \address
	pop %rdi
	pop %rsi
.endm
.macro CALL2 address, arg1, arg2
	push %rsi
	push %rdi
	mov \arg1, %rdi
	mov \arg2, %rsi
	call \address
	pop %rdi
	pop %rsi
.endm

/* Label/size/parameter definition macros */
#define DEFLABEL(name) .globl JIT_X64_##name; JIT_X64_##name:
#define DEFSIZE(name)  .globl JIT_X64SIZE_##name; \
    JIT_X64SIZE_##name: .int . - JIT_X64_##name
#define DEFPARAM(name,param,label,offset) \
    .globl JIT_X64PARAM_##name##_##param; \
    JIT_X64PARAM_##name##_##param: \
    .int label - JIT_X64_##name + (offset)

/* Q68State structure offsets */
Q68State_D              =   0
Q68State_A              =  32
Q68State_PC             =  64
Q68State_SR             =  68
Q68State_USP            =  72
Q68State_SSP            =  76
Q68State_current_PC     =  80
Q68State_ea_addr        =  84
Q68State_exception      =  88
Q68State_fault_addr     =  92
Q68State_fault_opcode   =  96
Q68State_fault_status   =  98
Q68State_halted         = 100
Q68State_irq            = 104
Q68State_cycles         = 108
Q68State_malloc_func    = 112
Q68State_realloc_func   = 120
Q68State_free_func      = 128
Q68State_readb_func     = 136
Q68State_readw_func     = 144
Q68State_writeb_func    = 152
Q68State_writew_func    = 160
Q68State_jit_flush      = 168
Q68State_jit_running    = 176
Q68State_jit_abort      = 184
Q68State_jit_table      = 192
Q68State_jit_hashchain  = 200
Q68State_jit_total_data = 208
Q68State_jit_timestamp  = 212
Q68State_jit_blacklist  = 216
Q68State_jit_in_blist   = Q68State_jit_blacklist + (12 * Q68_JIT_BLACKLIST_SIZE)
Q68State_jit_blist_num  = Q68State_jit_in_blist + 4
Q68State_jit_callstack_top = Q68State_jit_blist_num + 4
Q68State_jit_callstack  = (Q68State_jit_callstack_top + 7) & ~7
Q68State_jit_pages      = Q68State_jit_callstack + (24 * Q68_JIT_CALLSTACK_SIZE)

#else  // CPU_X86

/* Register name translation macros (we don't handle any 64-bit data except
 * when protected by #ifdef CPU_X64, so this is safe) */
#define rax eax
#define rbx ebx
#define rcx ecx
#define rdx edx
#define rsp esp
#define rbp ebp
#define rsi esi
#define rdi edi

/* External routine calling macros (indirect calls only) */
.macro CALL1 address, arg1
	push \arg1
	call \address
	pop %rcx
.endm
.macro CALL2 address, arg1, arg2
	push \arg2
	push \arg1
	call \address
	pop %rcx
	pop %rcx
.endm

/* Label/size/parameter definition macros */
#define DEFLABEL(name) .globl JIT_X86_##name; JIT_X86_##name:
#define DEFSIZE(name)  .globl JIT_X86SIZE_##name; \
    JIT_X86SIZE_##name: .int . - JIT_X86_##name
#define DEFPARAM(name,param,label,offset) \
    .globl JIT_X86PARAM_##name##_##param; \
    JIT_X86PARAM_##name##_##param: \
    .int label - JIT_X86_##name + (offset)

/* Q68State structure offsets */
Q68State_D              =   0
Q68State_A              =  32
Q68State_PC             =  64
Q68State_SR             =  68
Q68State_USP            =  72
Q68State_SSP            =  76
Q68State_current_PC     =  80
Q68State_ea_addr        =  84
Q68State_exception      =  88
Q68State_fault_addr     =  92
Q68State_fault_opcode   =  96
Q68State_fault_status   =  98
Q68State_halted         = 100
Q68State_irq            = 104
Q68State_cycles         = 108
Q68State_malloc_func    = 112
Q68State_realloc_func   = 116
Q68State_free_func      = 120
Q68State_readb_func     = 124
Q68State_readw_func     = 128
Q68State_writeb_func    = 132
Q68State_writew_func    = 136
Q68State_jit_flush      = 140
Q68State_jit_running    = 144
Q68State_jit_abort      = 148
Q68State_jit_table      = 152
Q68State_jit_hashchain  = 156
Q68State_jit_total_data = 160
Q68State_jit_timestamp  = 164
Q68State_jit_blacklist  = 168
Q68State_jit_in_blist   = Q68State_jit_blacklist + (12 * Q68_JIT_BLACKLIST_SIZE)
Q68State_jit_blist_num  = Q68State_jit_in_blist + 4
Q68State_jit_callstack_top = Q68State_jit_blist_num + 4
Q68State_jit_callstack  = Q68State_jit_callstack_top + 4
Q68State_jit_pages      = Q68State_jit_callstack + (12 * Q68_JIT_CALLSTACK_SIZE)

#endif  // X64/X86

/*************************************************************************/

/* Shorthand for referencing Q68State fields */

#define D0   Q68State_D+0*4(%rbx)
#define D1   Q68State_D+1*4(%rbx)
#define D2   Q68State_D+2*4(%rbx)
#define D3   Q68State_D+3*4(%rbx)
#define D4   Q68State_D+4*4(%rbx)
#define D5   Q68State_D+5*4(%rbx)
#define D6   Q68State_D+6*4(%rbx)
#define D7   Q68State_D+7*4(%rbx)

#define A0   Q68State_A+0*4(%rbx)
#define A1   Q68State_A+1*4(%rbx)
#define A2   Q68State_A+2*4(%rbx)
#define A3   Q68State_A+3*4(%rbx)
#define A4   Q68State_A+4*4(%rbx)
#define A5   Q68State_A+5*4(%rbx)
#define A6   Q68State_A+6*4(%rbx)
#define A7   Q68State_A+7*4(%rbx)

#define PC   Q68State_PC(%rbx)
#define SR   Q68State_SR(%rbx)
#define USP  Q68State_USP(%rbx)
#define SSP  Q68State_SSP(%rbx)

/*************************************************************************/
/************************** Convenience macros ***************************/
/*************************************************************************/

/**
 * READ{8,16,32}:  Read a value from memory.  The value read is returned
 * zero-extended in %eax; the address parameter is destroyed.  %rdx may not
 * be used as a parameter.
 */
.macro READ8 address
	and $0x00FFFFFF, \address
	mov Q68State_readb_func(%rbx), %rdx
	CALL1 *%rdx, \address
	movzx %al, %eax
.endm

.macro READ16 address
	and $0x00FFFFFF, \address
	mov Q68State_readw_func(%rbx), %rdx
	CALL1 *%rdx, \address
	movzx %ax, %eax
.endm

.macro READ32 address
	and $0x00FFFFFF, \address
	mov Q68State_readw_func(%rbx), %rdx
#ifdef CPU_X64
	push %rdi
	mov \address, %rdi
	call *%rdx
	push %rax
	add $2, %rdi
	and $0x00FFFFFF, %rdi
	mov Q68State_readw_func(%rbx), %rdx
	call *%rdx
	pop %rcx
	pop %rdi
#else
	push \address
	call *%rdx
	xchg %rax, (%rsp)
	addl $2, %rax
	push %rax
	mov Q68State_readw_func(%rbx), %rdx
	call *%rdx
	pop %rcx
	pop %rcx
#endif
	shl $16, %ecx
	or %ecx, %eax
.endm

/*-----------------------------------------------------------------------*/

/**
 * WRITE_CHECK_JIT:  Check whether a write of size \nbytes (*bytes*, not
 * bits) to \address would clobber a page containing already-translated
 * blocks, and clear those translations if so.  The value of \address is
 * preserved, but all other caller-saved registers are destroyed.
 *
 * Note that this macro uses local label 4.
 */
.macro WRITE_CHECK_JIT address, nbytes
	push \address
	mov \address, %rdx
	shr $Q68_JIT_PAGE_BITS+3, %rdx
	mov \address, %rcx
	shr $Q68_JIT_PAGE_BITS, %rcx
	and $7, %cl
	mov $1, %al
	shl %cl, %al
	test %al, Q68State_jit_pages(%rbx,%rdx,1)
	jz 4f
	/* Have to use an indirect call because the offset for the call
	 * instruction will change based on where this code is copied */
	mov (%rsp), \address
#ifdef CPU_X64
	mov $q68_jit_clear_write, %r8
	mov $\nbytes, %edx
	CALL2 *%r8, %rbx, \address
#else
	mov $q68_jit_clear_write, %edx
	pushl $\nbytes
	CALL2 *%edx, %ebx, \address
	pop %ecx
#endif
4:	pop \address
.endm

/*-----------------------------------------------------------------------*/

/**
 * WRITE{8,16,32}:  Write a value to memory.  %rdx may not be used as a
 * parameter; the address parameter is destroyed.
 */
.macro WRITE8 address, value
	and $0x00FFFFFF, \address
	push \value
	WRITE_CHECK_JIT \address, 1
	pop \value
	mov Q68State_writeb_func(%rbx), %rdx
	CALL2 *%rdx, \address, \value
.endm

.macro WRITE16 address, value
	and $0x00FFFFFF, \address
	push \value
	WRITE_CHECK_JIT \address, 2
	pop \value
	mov Q68State_writew_func(%rbx), %rdx
	CALL2 *%rdx, \address, \value
.endm

.macro WRITE32 address, value
	push \value
	push \address
	shr $16, \value
	WRITE16 \address, \value
	pop \address
	pop \value
	add $2, \address
	WRITE16 \address, \value
.endm

/*-----------------------------------------------------------------------*/

/**
 * {PUSH,POP}{16,32}:  Push or pop values onto or off of the stack.  For
 * POP, the value popped is zero-extended and returned in %rax; for PUSH,
 * register %rax is destroyed before storing.  %rdx may not be used as a
 * parameter.
 */
.macro PUSH16 value
	mov A7, %eax
	sub $2, %eax
	mov %eax, A7
	WRITE16 %rax, \value
.endm

.macro PUSH32 value
	mov A7, %eax
	sub $4, %eax
	mov %eax, A7
	WRITE32 %rax, \value
.endm

.macro POP16
	mov A7, %eax
	add $2, A7
	READ16 %rax
.endm

.macro POP32
	mov A7, %eax
	add $4, A7
	READ32 %rax
.endm

/*************************************************************************/

/**
 * LDC_FROM_X:  Set the x86 carry flag (CF) based on the value of the
 * 68000 extend flag (X).  The byte register passed in \temp is destroyed.
 */
.macro LDC_FROM_X temp
	mov SR, \temp
	shr $5, \temp
.endm

/*************************************************************************/

/**
 * SETCC_NZ:  Set the N and Z condition codes according to the x86 flag bits.
 */
.macro SETCC_NZ
	sets %cl
	setz %dl
	andb $~(SR_N|SR_Z), SR
	shl $SR_N_SHIFT, %cl
	shl $SR_Z_SHIFT, %dl
	or %cl, %dl
	or %dl, SR
.endm

/*-----------------------------------------------------------------------*/

/**
 * SETCC_NZ00:  Set the N and Z condition codes according to the x86 flag
 * bits, and clear the V and C condition codes.
 */
.macro SETCC_NZ00
	sets %cl
	setz %dl
	andb $~(SR_N|SR_Z|SR_V|SR_C), SR
	shl $SR_N_SHIFT, %cl
	shl $SR_Z_SHIFT, %dl
	or %cl, %dl
	or %dl, SR
.endm

/*-----------------------------------------------------------------------*/

/**
 * SETCC_NZVC:  Set the N, Z, V, and C condition codes according to the x86
 * flag bits.
 */
.macro SETCC_NZVC
	sets %cl
	setz %dl
	seto %ch
	setc %dh
	andb $~(SR_N|SR_Z|SR_V|SR_C), SR
	shl $SR_N_SHIFT, %cl
	shl $SR_Z_SHIFT, %dl
	shl $SR_V_SHIFT, %ch
	//shl $SR_C_SHIFT, %dh  // SR_C_SHIFT is zero, so skip the shift
	or %ch, %cl
	or %dh, %dl
	or %cl, %dl
	or %dl, SR
.endm

/*-----------------------------------------------------------------------*/

/**
 * SETCC_XNZVC:  Set the N, Z, V, and C condition codes according to the
 * x86 flag bits, and sets the X condition code equal to C.
 */
.macro SETCC_XNZVC
	sets %cl
	setz %dl
	seto %ch
	setc %dh
	andb $~(SR_X|SR_N|SR_Z|SR_V|SR_C), SR
	shl $SR_N_SHIFT, %cl
	shl $SR_Z_SHIFT, %dl
	shl $SR_V_SHIFT, %ch
	//shl $SR_C_SHIFT, %dh  // SR_C_SHIFT is zero, so skip the shift
	or %ch, %cl
	or %dh, %dl
	shl $(SR_X_SHIFT - SR_C_SHIFT), %dh
	or %dh, %dl
	or %cl, %dl
	or %dl, SR
.endm

/*-----------------------------------------------------------------------*/

/**
 * SETCC_XNVC_Z:  Set the N, V, and C condition codes according to the x86
 * flag bits; clears the Z condition code if the x86 Z flag is clear, and
 * sets the X condition code equal to C.
 */
.macro SETCC_XNVC_Z
	sets %cl
	setnz %dl
	seto %ch
	setc %dh
	andb $~(SR_X|SR_N|SR_V|SR_C), SR
	shl $SR_N_SHIFT, %cl
	shl $SR_Z_SHIFT, %dl
	shl $SR_V_SHIFT, %ch
	//shl $SR_C_SHIFT, %dh  // SR_C_SHIFT is zero, so skip the shift
	or %ch, %cl
	or %dh, %cl
	shl $(SR_X_SHIFT - SR_C_SHIFT), %dh
	or %dh, %cl
	or %cl, SR
	not %dl
	and %dl, SR
.endm

/*-----------------------------------------------------------------------*/

/**
 * UPDATE_SR:  Set the status register and condition codes according to
 * the value in %ax.
 *
 * Note that this macro uses local labels 0, 1, 2, and 3.
 */
.macro UPDATE_SR value
	movzwl %ax, %ecx
	xor SR, %eax
	mov %ecx, SR
	test $SR_S, %eax	// Change in S bit?
	jz 1f
	test $SR_S, %ecx	// Which way did it change?
	jz 0f
	mov A7, %eax		// Into supervisor mode
	mov %eax, USP
	mov SSP, %eax
	mov %eax, A7
	jmp 1f
0:	mov A7, %eax		// Out of supervisor mode
	mov %eax, SSP
	mov USP, %eax
	mov %eax, A7
1:	mov Q68State_irq(%rbx), %al
	and $7, %al
	cmp $7, %al
	je 2f
	and $7, %ch
	cmp %al, %ch
	jae 3f
2:	movzx %al, %eax
	add $EX_LEVEL_1_INTERRUPT-1, %eax
	mov %eax, Q68State_exception(%rbx)
	movl $0, Q68State_irq(%rbx)
	TERMINATE
3:
.endm

/*************************************************************************/

/**
 * SETUP:  Perform setup required before executing translated code.
 */
.macro SETUP
	push %rsi
	xor %esi, %esi
.endm

/*-----------------------------------------------------------------------*/

/**
 * TERMINATE:  Terminate execution of the current block.  The emulator will
 * resume execution at the address in state->PC.
 */
.macro TERMINATE
	pop %rax
	xor %rdi, %rdi
	ret
.endm

/*************************************************************************/
/**************************** Meta-operations ****************************/
/*************************************************************************/

/**
 * PROLOGUE:  Any prologue necessary at the beginning of the code stream.
 */
DEFLABEL(PROLOGUE)
	SETUP
DEFSIZE(PROLOGUE)

/*-----------------------------------------------------------------------*/

/**
 * EPILOGUE:  Any epilogue necessary at the end of the code stream.
 */
DEFLABEL(EPILOGUE)
	TERMINATE
DEFSIZE(EPILOGUE)

/*************************************************************************/

/**
 * TRACE:  Trace the current instruction.
 */
DEFLABEL(TRACE)
	mov Q68State_cycles(%rbx), %eax
	push %rax
	add %esi, %eax
	mov %eax, Q68State_cycles(%rbx)
#ifdef CPU_X64
	push %rsi
	push %rdi
#endif
	mov $q68_trace, %rdx
	call *%rdx
#ifdef CPU_X64
	pop %rdi
	pop %rsi
#endif
	pop %rax
	mov %eax, Q68State_cycles(%rbx)
DEFSIZE(TRACE)

/*************************************************************************/

/**
 * ADD_CYCLES:  Add the specified number of clock cycles to the cycle count.
 *
 * [Parameters]
 *     cycles: Number of clock cycles to add
 */
DEFLABEL(ADD_CYCLES)
	add $0x12345678, %esi
9:
DEFSIZE(ADD_CYCLES)
DEFPARAM(ADD_CYCLES, cycles, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * CHECK_CYCLES:  Check whether the clock cycle limit has been reached, and
 * interrupt execution if so.
 */
DEFLABEL(CHECK_CYCLES)
	cmp %esi, (%rsp)
	ja 4f
	pop %rax
	call 1f
0:	jmp 2f
1:	mov (%rsp), %rdi
	ret
2:	add $3f-0b, %rdi
	ret
3:	SETUP
4:
DEFSIZE(CHECK_CYCLES)

/*************************************************************************/

/**
 * ADVANCE_PC:  Add the specified value to the current program counter.
 *
 * [Parameters]
 *     value: Amount to add
 */
DEFLABEL(ADVANCE_PC)
	addl $0x12345678, PC
9:
DEFSIZE(ADVANCE_PC)
DEFPARAM(ADVANCE_PC, value, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * ADVANCE_PC_CHECK_ABORT:  Add the specified value to the current program
 * counter, then check the jit_abort flag and abort if necessary.
 *
 * [Parameters]
 *     value: Amount to add
 */
DEFLABEL(ADVANCE_PC_CHECK_ABORT)
	addl $0x12345678, PC
9:	testb $1, Q68State_jit_abort(%rbx)
	jz 0f
	TERMINATE
0:
DEFSIZE(ADVANCE_PC_CHECK_ABORT)
DEFPARAM(ADVANCE_PC_CHECK_ABORT, value, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * CHECK_ABORT:  Check the jit_abort flag and abort if necessary.
 */
DEFLABEL(CHECK_ABORT)
	testb $1, Q68State_jit_abort(%rbx)
	jz 0f
	TERMINATE
0:
DEFSIZE(CHECK_ABORT)

/*************************************************************************/

/**
 * EXCEPTION:  Raise the specified exception.
 *
 * [Parameters]
 *     num: Exception number
 */
DEFLABEL(EXCEPTION)
	movl $0x12345678, Q68State_exception(%rbx)
9:	TERMINATE
DEFSIZE(EXCEPTION)
DEFPARAM(EXCEPTION, num, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * CHECK_ALIGNED_EA:  Check whether the previously resolved effective
 * address is word-aligned (bit 0 is clear), and raise an address error
 * exception if not.
 *
 * [Parameters]
 *     opcode: Instruction opcode
 *     status: Status word for address error exception
 */
DEFLABEL(CHECK_ALIGNED_EA)
	testl $1, Q68State_ea_addr(%rbx)
	jz 0f
	movl $EX_ADDRESS_ERROR, Q68State_exception(%rbx)
	mov Q68State_ea_addr(%rbx), %eax
	mov %eax, Q68State_fault_addr(%rbx)
	movw $0x1234, Q68State_fault_opcode(%rbx)
8:	movw $0x1234, Q68State_fault_status(%rbx)
9:	TERMINATE
0:
DEFSIZE(CHECK_ALIGNED_EA)
DEFPARAM(CHECK_ALIGNED_EA, opcode, 8b, -2)
DEFPARAM(CHECK_ALIGNED_EA, status, 9b, -2)

/*-----------------------------------------------------------------------*/

/**
 * CHECK_ALIGNED_SP:  Check whether the current stack pointer (register A7)
 * is word-aligned (bit 0 is clear), and raise an address error exception
 * if not.
 *
 * [Parameters]
 *     opcode: Instruction opcode
 *     status: Status word for address error exception
 */
DEFLABEL(CHECK_ALIGNED_SP)
	testl $1, A7
	jz 0f
	movl $EX_ADDRESS_ERROR, Q68State_exception(%rbx)
	mov A7, %eax
	mov %eax, Q68State_fault_addr(%rbx)
	movw $0x1234, Q68State_fault_opcode(%rbx)
8:	movw $0x1234, Q68State_fault_status(%rbx)
9:	TERMINATE
0:
DEFSIZE(CHECK_ALIGNED_SP)
DEFPARAM(CHECK_ALIGNED_SP, opcode, 8b, -2)
DEFPARAM(CHECK_ALIGNED_SP, status, 9b, -2)

/*-----------------------------------------------------------------------*/

/**
 * CHECK_SUPER:  Check whether the processor is in supervisor mode, and
 * raise a privilege violation exception if not.
 */
DEFLABEL(CHECK_SUPER)
	testl $SR_S, SR
	jnz 0f
	movl $EX_PRIVILEGE_VIOLATION, Q68State_exception(%rbx)
	TERMINATE
0:
DEFSIZE(CHECK_SUPER)

/*************************************************************************/
/********************* Effective address resolution **********************/
/*************************************************************************/

/**
 * RESOLVE_INDIRECT:  Resolve an address register indirect reference.
 *
 * [Parameters]
 *     reg4: (8+n)*4 for register An
 */
DEFLABEL(RESOLVE_INDIRECT)
	mov 1(%rbx), %eax
9:	mov %eax, Q68State_ea_addr(%rbx)
DEFSIZE(RESOLVE_INDIRECT)
DEFPARAM(RESOLVE_INDIRECT, reg4, 9b, -1)

/*-----------------------------------------------------------------------*/

/**
 * RESOLVE_POSTINC:  Resolve an address register postincrement reference.
 *
 * [Parameters]
 *     reg4: (8+n)*4 for register An
 *     size: Size in bytes of the reference
 */
DEFLABEL(RESOLVE_POSTINC)
	lea 1(%rbx), %rcx
8:	mov (%rcx), %eax
	add $1, (%rcx)
9:	mov %eax, Q68State_ea_addr(%rbx)
DEFSIZE(RESOLVE_POSTINC)
DEFPARAM(RESOLVE_POSTINC, reg4, 8b, -1)
DEFPARAM(RESOLVE_POSTINC, size, 9b, -1)

/* For byte-sized (A7)+, make sure A7 stays even */
DEFLABEL(RESOLVE_POSTINC_A7_B)
	mov A7, %ecx
	lea 1(%ecx), %eax
	add $2, A7
	mov %eax, Q68State_ea_addr(%rbx)
DEFSIZE(RESOLVE_POSTINC_A7_B)

/*-----------------------------------------------------------------------*/

/**
 * RESOLVE_PREDEC:  Resolve an address register predecrement reference.
 *
 * [Parameters]
 *     reg4: (8+n)*4 for register An
 *     size: Size in bytes of the reference
 */
DEFLABEL(RESOLVE_PREDEC)
	lea 1(%rbx), %rcx
8:	sub $1, (%rcx)
9:	mov (%rcx), %eax
	mov %eax, Q68State_ea_addr(%rbx)
DEFSIZE(RESOLVE_PREDEC)
DEFPARAM(RESOLVE_PREDEC, reg4, 8b, -1)
DEFPARAM(RESOLVE_PREDEC, size, 9b, -1)

/* For byte-sized -(A7), make sure A7 stays even */
DEFLABEL(RESOLVE_PREDEC_A7_B)
	mov A7, %ecx
	lea -1(%ecx), %eax
	sub $2, A7
	mov %eax, Q68State_ea_addr(%rbx)
DEFSIZE(RESOLVE_PREDEC_A7_B)

/*-----------------------------------------------------------------------*/

/**
 * RESOLVE_DISP:  Resolve an address register indirect with displacement
 * reference.
 *
 * [Parameters]
 *     reg4: (8+n)*4 for register An
 *     disp: Displacement
 */
DEFLABEL(RESOLVE_DISP)
	mov 1(%rbx), %eax
8:	add $0x12345678, %eax
9:	mov %eax, Q68State_ea_addr(%rbx)
DEFSIZE(RESOLVE_DISP)
DEFPARAM(RESOLVE_DISP, reg4, 8b, -1)
DEFPARAM(RESOLVE_DISP, disp, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * RESOLVE_INDEX_[WL]:  Resolve an address register indirect with index
 * reference.
 *
 * [Parameters]
 *      reg4: (8+n)*4 for register An
 *     ireg4: Index register number * 4
 *      disp: Displacement
 */
DEFLABEL(RESOLVE_INDEX_W)
	mov 1(%rbx), %eax
7:	mov 1(%rbx), %ecx
8:	movsx %cx, %ecx
	lea 1(%eax, %ecx), %eax
9:	mov %eax, Q68State_ea_addr(%rbx)
DEFSIZE(RESOLVE_INDEX_W)
DEFPARAM(RESOLVE_INDEX_W, reg4, 7b, -1)
DEFPARAM(RESOLVE_INDEX_W, ireg4, 8b, -1)
DEFPARAM(RESOLVE_INDEX_W, disp, 9b, -1)

DEFLABEL(RESOLVE_INDEX_L)
	mov 1(%rbx), %eax
7:	mov 1(%rbx), %ecx
8:	lea 1(%eax, %ecx), %eax
9:	mov %eax, Q68State_ea_addr(%rbx)
DEFSIZE(RESOLVE_INDEX_L)
DEFPARAM(RESOLVE_INDEX_L, reg4, 7b, -1)
DEFPARAM(RESOLVE_INDEX_L, ireg4, 8b, -1)
DEFPARAM(RESOLVE_INDEX_L, disp, 9b, -1)

/*-----------------------------------------------------------------------*/

/**
 * RESOLVE_ABSOLUTE:  Resolve an absolute short, absolute long, or
 * PC-relative reference.
 *
 * [Parameters]
 *     addr: Absolute address
 */
DEFLABEL(RESOLVE_ABSOLUTE)
	mov $0x12345678, %eax
9:	mov %eax, Q68State_ea_addr(%rbx)
DEFSIZE(RESOLVE_ABSOLUTE)
DEFPARAM(RESOLVE_ABSOLUTE, addr, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * RESOLVE_ABS_INDEX_[WL]:  Resolve a PC-relative with index reference.
 *
 * [Parameters]
 *      addr: Absolute address
 *     ireg4: Index register number * 4
 */
DEFLABEL(RESOLVE_ABS_INDEX_W)
	mov $0x12345678, %eax
8:	movswl 1(%rbx), %ecx
9:	add %ecx, %eax
	mov %eax, Q68State_ea_addr(%rbx)
DEFSIZE(RESOLVE_ABS_INDEX_W)
DEFPARAM(RESOLVE_ABS_INDEX_W, addr, 8b, -4)
DEFPARAM(RESOLVE_ABS_INDEX_W, ireg4, 9b, -1)

DEFLABEL(RESOLVE_ABS_INDEX_L)
	mov $0x12345678, %eax
8:	add 1(%rbx), %ecx
9:	mov %eax, Q68State_ea_addr(%rbx)
DEFSIZE(RESOLVE_ABS_INDEX_L)
DEFPARAM(RESOLVE_ABS_INDEX_L, addr, 8b, -4)
DEFPARAM(RESOLVE_ABS_INDEX_L, ireg4, 9b, -1)

/*************************************************************************/
/*************************** Operand retrieval ***************************/
/*************************************************************************/

/**
 * GET_OP1_REGISTER:  Get the current value of the given register as
 * operand 1.
 *
 * [Parameters]
 *     reg4: Register number * 4 (0-28: D0-D7, 32-60: A0-A7)
 */
DEFLABEL(GET_OP1_REGISTER)
	mov 1(%rbx), %edi
9:
DEFSIZE(GET_OP1_REGISTER)
DEFPARAM(GET_OP1_REGISTER, reg4, 9b, -1)

/*-----------------------------------------------------------------------*/

/**
 * GET_OP1_EA_[BWL]:  Get the value pointed to by the previously resolved
 * effective address as operand 1.
 */
DEFLABEL(GET_OP1_EA_B)
	mov Q68State_ea_addr(%rbx), %eax
	READ8 %rax
	movzx %al, %edi
DEFSIZE(GET_OP1_EA_B)

DEFLABEL(GET_OP1_EA_W)
	mov Q68State_ea_addr(%rbx), %eax
	READ16 %rax
	movzx %ax, %edi
DEFSIZE(GET_OP1_EA_W)

DEFLABEL(GET_OP1_EA_L)
	mov Q68State_ea_addr(%rbx), %eax
	READ32 %rax
	mov %eax, %edi
DEFSIZE(GET_OP1_EA_L)

/*-----------------------------------------------------------------------*/

/**
 * GET_OP1_IMMEDIATE:  Get an immediate value as operand 1.
 *
 * [Parameters]
 *     value: Immediate value
 */
DEFLABEL(GET_OP1_IMMEDIATE)
	mov $0x12345678, %edi
9:
DEFSIZE(GET_OP1_IMMEDIATE)
DEFPARAM(GET_OP1_IMMEDIATE, value, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * GET_OP1_CCR:  Get the current value of CCR as operand 1.
 */
DEFLABEL(GET_OP1_CCR)
	movzbl SR, %edi
DEFSIZE(GET_OP1_CCR)

/*-----------------------------------------------------------------------*/

/**
 * GET_OP1_SR:  Get the current value of SR as operand 1.
 */
DEFLABEL(GET_OP1_SR)
	mov SR, %edi
DEFSIZE(GET_OP1_SR)

/*************************************************************************/

/**
 * GET_OP2_*:  Get the same things as above as operand 2.
 */
DEFLABEL(GET_OP2_REGISTER)
	mov 1(%rbx), %edx
9:
DEFSIZE(GET_OP2_REGISTER)
DEFPARAM(GET_OP2_REGISTER, reg4, 9b, -1)

/*-----------------------------------------------------------------------*/

DEFLABEL(GET_OP2_EA_B)
	mov Q68State_ea_addr(%rbx), %eax
	READ8 %rax
	movzx %al, %edx
DEFSIZE(GET_OP2_EA_B)

DEFLABEL(GET_OP2_EA_W)
	mov Q68State_ea_addr(%rbx), %eax
	READ16 %rax
	movzx %ax, %edx
DEFSIZE(GET_OP2_EA_W)

DEFLABEL(GET_OP2_EA_L)
	mov Q68State_ea_addr(%rbx), %eax
	READ32 %rax
	mov %eax, %edx
DEFSIZE(GET_OP2_EA_L)

/*-----------------------------------------------------------------------*/

DEFLABEL(GET_OP2_IMMEDIATE)
	mov $0x12345678, %edx
9:
DEFSIZE(GET_OP2_IMMEDIATE)
DEFPARAM(GET_OP2_IMMEDIATE, value, 9b, -4)

/*-----------------------------------------------------------------------*/

DEFLABEL(GET_OP2_CCR)
	movzbl SR, %edx
DEFSIZE(GET_OP2_CCR)

/*-----------------------------------------------------------------------*/

DEFLABEL(GET_OP2_SR)
	mov SR, %edx
DEFSIZE(GET_OP2_SR)

/*************************************************************************/
/**************************** Result storing *****************************/
/*************************************************************************/

/**
 * SET_REGISTER_[BWL]:  Set the value of the given register to the result
 * value.
 *
 * [Parameters]
 *     reg4: Register number * 4 (0-28: D0-D7, 32-60: A0-A7)
 */
DEFLABEL(SET_REGISTER_B)
	mov %al, 1(%rbx)
9:
DEFSIZE(SET_REGISTER_B)
DEFPARAM(SET_REGISTER_B, reg4, 9b, -1)

DEFLABEL(SET_REGISTER_W)
	mov %ax, 1(%rbx)
9:
DEFSIZE(SET_REGISTER_W)
DEFPARAM(SET_REGISTER_W, reg4, 9b, -1)

DEFLABEL(SET_REGISTER_L)
	mov %eax, 1(%rbx)
9:
DEFSIZE(SET_REGISTER_L)
DEFPARAM(SET_REGISTER_L, reg4, 9b, -1)

/*-----------------------------------------------------------------------*/

/**
 * SET_AREG_W:  Set the value of the given address register to the
 * sign-extended result value.
 *
 * [Parameters]
 *     reg4: Register number * 4 (32-60: A0-A7)
 */
DEFLABEL(SET_AREG_W)
	cwde
	mov %eax, 1(%rbx)
9:
DEFSIZE(SET_AREG_W)
DEFPARAM(SET_AREG_W, reg4, 9b, -1)

/*-----------------------------------------------------------------------*/

/**
 * SET_EA_[BWL]:  Set the value pointed to by the previously resolved
 * effective address to the result value.
 */
DEFLABEL(SET_EA_B)
	mov Q68State_ea_addr(%rbx), %ecx
	WRITE8 %rcx, %rax
DEFSIZE(SET_EA_B)

DEFLABEL(SET_EA_W)
	mov Q68State_ea_addr(%rbx), %ecx
	WRITE16 %rcx, %rax
DEFSIZE(SET_EA_W)

DEFLABEL(SET_EA_L)
	mov Q68State_ea_addr(%rbx), %ecx
	WRITE32 %rcx, %rax
DEFSIZE(SET_EA_L)

/*-----------------------------------------------------------------------*/

/**
 * SET_CCR:  Set the condition codes from the result value.
 */
DEFLABEL(SET_CCR)
	mov %al, SR  // Update low byte only
DEFSIZE(SET_CCR)

/*-----------------------------------------------------------------------*/

/**
 * SET_SR:  Set the status register from the result value.
 */
DEFLABEL(SET_SR)
	UPDATE_SR
DEFSIZE(SET_SR)

/*************************************************************************/
/*************************** Stack operations ****************************/
/*************************************************************************/

/**
 * PUSH_L:  Push the 32-bit value of operand 1 onto the stack.
 */
DEFLABEL(PUSH_L)
	PUSH32 %rdi
DEFSIZE(PUSH_L)

/*-----------------------------------------------------------------------*/

/**
 * POP_L:  Pop a 32-bit value off the stack into the result register.
 */
DEFLABEL(POP_L)
	POP32
DEFSIZE(POP_L)

/*************************************************************************/
/************************ Condition code setting *************************/
/*************************************************************************/

/**
 * SETCC_ADD_[BWL]:  Set the condition codes for the result of an ADD
 * instruction stored in the result register.
 */
DEFLABEL(SETCC_ADD_B)
	SETCC_XNZVC
DEFSIZE(SETCC_ADD_B)

DEFLABEL(SETCC_ADD_W)
	SETCC_XNZVC
DEFSIZE(SETCC_ADD_W)

DEFLABEL(SETCC_ADD_L)
	SETCC_XNZVC
DEFSIZE(SETCC_ADD_L)

/*************************************************************************/

/**
 * SETCC_ADDX_[BWL]:  Set the condition codes for the result of an ADDX
 * instruction stored in the result register.
 */
DEFLABEL(SETCC_ADDX_B)
	SETCC_XNVC_Z
DEFSIZE(SETCC_ADDX_B)

DEFLABEL(SETCC_ADDX_W)
	SETCC_XNVC_Z
DEFSIZE(SETCC_ADDX_W)

DEFLABEL(SETCC_ADDX_L)
	SETCC_XNVC_Z
DEFSIZE(SETCC_ADDX_L)

/*************************************************************************/

/**
 * SETCC_SUB_[BWL]:  Set the condition codes for the result of a SUB
 * instruction stored in the result register.
 */
DEFLABEL(SETCC_SUB_B)
	SETCC_XNZVC
DEFSIZE(SETCC_SUB_B)

DEFLABEL(SETCC_SUB_W)
	SETCC_XNZVC
DEFSIZE(SETCC_SUB_W)

DEFLABEL(SETCC_SUB_L)
	SETCC_XNZVC
DEFSIZE(SETCC_SUB_L)

/*************************************************************************/

/**
 * SETCC_SUBX_[BWL]:  Set the condition codes for the result of a SUBX
 * instruction stored in the result register.
 */
DEFLABEL(SETCC_SUBX_B)
	SETCC_XNVC_Z
DEFSIZE(SETCC_SUBX_B)

DEFLABEL(SETCC_SUBX_W)
	SETCC_XNVC_Z
DEFSIZE(SETCC_SUBX_W)

DEFLABEL(SETCC_SUBX_L)
	SETCC_XNVC_Z
DEFSIZE(SETCC_SUBX_L)

/*************************************************************************/

/**
 * SETCC_CMP_[BWL]:  Set the condition codes for the result of a CMP
 * instruction stored in the result register.  The X flag is unmodified.
 */
DEFLABEL(SETCC_CMP_B)
	SETCC_NZVC
DEFSIZE(SETCC_CMP_B)

DEFLABEL(SETCC_CMP_W)
	SETCC_NZVC
DEFSIZE(SETCC_CMP_W)

DEFLABEL(SETCC_CMP_L)
	SETCC_NZVC
DEFSIZE(SETCC_CMP_L)

/*************************************************************************/

/**
 * SETCC_LOGIC_[BWL]:  Set the condition codes for the result of a logical
 * instruction (MOVE, AND, OR, EOR) stored in the result register.  The X
 * flag is unmodified.
 */
DEFLABEL(SETCC_LOGIC_B)
	SETCC_NZ00
DEFSIZE(SETCC_LOGIC_B)

DEFLABEL(SETCC_LOGIC_W)
	SETCC_NZ00
DEFSIZE(SETCC_LOGIC_W)

DEFLABEL(SETCC_LOGIC_L)
	SETCC_NZ00
DEFSIZE(SETCC_LOGIC_L)

/*************************************************************************/
/*************************** Condition testing ***************************/
/*************************************************************************/

/**
 * TEST_*:  Check whether a condition is true (based on the current
 * condition codes) and set %al based on the result (nonzero = true).
 */

DEFLABEL(TEST_T)
	mov $1, %al
DEFSIZE(TEST_T)

DEFLABEL(TEST_F)
	mov $0, %al
DEFSIZE(TEST_F)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_HI)
	mov SR, %al
	mov %al, %cl
	shr $SR_Z_SHIFT, %cl
	or %cl, %al
	and $1, %al
	xor $1, %al
DEFSIZE(TEST_HI)

DEFLABEL(TEST_LS)
	mov SR, %al
	mov %al, %cl
	shr $SR_Z_SHIFT, %cl
	or %cl, %al
	and $1, %al
DEFSIZE(TEST_LS)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_CC)
	mov SR, %al
	and $1, %al
	xor $1, %al
DEFSIZE(TEST_CC)

DEFLABEL(TEST_CS)
	mov SR, %al
	and $1, %al
DEFSIZE(TEST_CS)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_NE)
	mov SR, %al
	shr $SR_Z_SHIFT, %al
	and $1, %al
	xor $1, %al
DEFSIZE(TEST_NE)

DEFLABEL(TEST_EQ)
	mov SR, %al
	shr $SR_Z_SHIFT, %al
	and $1, %al
DEFSIZE(TEST_EQ)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_VC)
	mov SR, %al
	shr $SR_V_SHIFT, %al
	and $1, %al
	xor $1, %al
DEFSIZE(TEST_VC)

DEFLABEL(TEST_VS)
	mov SR, %al
	shr $SR_V_SHIFT, %al
	and $1, %al
DEFSIZE(TEST_VS)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_PL)
	mov SR, %al
	shr $SR_N_SHIFT, %al
	and $1, %al
	xor $1, %al
DEFSIZE(TEST_PL)

DEFLABEL(TEST_MI)
	mov SR, %al
	shr $SR_N_SHIFT, %al
	and $1, %al
DEFSIZE(TEST_MI)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_GE)
	mov SR, %al
	mov %al, %cl
	shr $SR_N_SHIFT, %al
	shr $SR_V_SHIFT, %cl
	xor %cl, %al
	and $1, %al
	xor $1, %al
DEFSIZE(TEST_GE)

DEFLABEL(TEST_LT)
	mov SR, %al
	mov %al, %cl
	shr $SR_N_SHIFT, %al
	shr $SR_V_SHIFT, %cl
	xor %cl, %al
	and $1, %al
DEFSIZE(TEST_LT)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_GT)
	mov SR, %al
	push %rax
	mov %al, %cl
	shr $SR_N_SHIFT, %al
	shr $SR_V_SHIFT, %cl
	xor %al, %cl
	pop %rax
	shr $SR_Z_SHIFT, %al
	or %cl, %al
	and $1, %al
	xor $1, %al
DEFSIZE(TEST_GT)

DEFLABEL(TEST_LE)
	mov SR, %al
	push %rax
	mov %al, %cl
	shr $SR_N_SHIFT, %al
	shr $SR_V_SHIFT, %cl
	xor %al, %cl
	pop %rax
	shr $SR_Z_SHIFT, %al
	or %cl, %al
	and $1, %al
DEFSIZE(TEST_LE)

/*************************************************************************/
/**************************** ALU operations *****************************/
/*************************************************************************/

/**
 * MOVE_[BWL]:  Evaluate op1, setting the result value for the MOVE
 * instruction.
 */
DEFLABEL(MOVE_B)
	mov %edi, %eax
	test %al, %al
DEFSIZE(MOVE_B)

DEFLABEL(MOVE_W)
	mov %edi, %eax
	test %ax, %ax
DEFSIZE(MOVE_W)

DEFLABEL(MOVE_L)
	mov %edi, %eax
	test %eax, %eax
DEFSIZE(MOVE_L)

/*************************************************************************/

/**
 * ADD_[BWL]:  Evaluate op2 + op1.
 */
DEFLABEL(ADD_B)
	mov %edi, %eax
	add %dl, %al
DEFSIZE(ADD_B)

DEFLABEL(ADD_W)
	mov %edi, %eax
	add %dx, %ax
DEFSIZE(ADD_W)

DEFLABEL(ADD_L)
	mov %edi, %eax
	add %edx, %eax
DEFSIZE(ADD_L)

/*-----------------------------------------------------------------------*/

/**
 * ADDA_W:  Sign-extend op1 to 32 bits, then evaluate op2 + op1.
 */
DEFLABEL(ADDA_W)
	movsx %di, %edi
	mov %edi, %eax
	add %edx, %eax
DEFSIZE(ADDA_W)

/*-----------------------------------------------------------------------*/

/**
 * ADDX_[BWL]:  Evaluate op2 + op1 + X.
 */
DEFLABEL(ADDX_B)
	LDC_FROM_X %al
	mov %edi, %eax
	adc %dl, %al
DEFSIZE(ADDX_B)

DEFLABEL(ADDX_W)
	LDC_FROM_X %al
	mov %edi, %eax
	adc %dx, %ax
DEFSIZE(ADDX_W)

DEFLABEL(ADDX_L)
	LDC_FROM_X %al
	mov %edi, %eax
	adc %edx, %eax
DEFSIZE(ADDX_L)

/*************************************************************************/

/**
 * SUB_[BWL]:  Evaluate op2 - op1.
 */
DEFLABEL(SUB_B)
	mov %edi, %eax
	xchg %edx, %eax
	sub %dl, %al
DEFSIZE(SUB_B)

DEFLABEL(SUB_W)
	mov %edi, %eax
	xchg %edx, %eax
	sub %dx, %ax
DEFSIZE(SUB_W)

DEFLABEL(SUB_L)
	mov %edi, %eax
	xchg %edx, %eax
	sub %edx, %eax
DEFSIZE(SUB_L)

/*-----------------------------------------------------------------------*/

/**
 * SUBA_W:  Sign-extend op1 to 32 bits, then evaluate op2 - op1.
 */
DEFLABEL(SUBA_W)
	movsx %di, %edi
	mov %edi, %eax
	xchg %edx, %eax
	sub %edx, %eax
DEFSIZE(SUBA_W)

/*-----------------------------------------------------------------------*/

/**
 * SUBX_[BWL]:  Evaluate op2 - op1 - X.
 */
DEFLABEL(SUBX_B)
	LDC_FROM_X %al
	mov %edi, %eax
	xchg %edx, %eax
	sbb %dl, %al
DEFSIZE(SUBX_B)

DEFLABEL(SUBX_W)
	LDC_FROM_X %al
	mov %edi, %eax
	xchg %edx, %eax
	sbb %dx, %ax
DEFSIZE(SUBX_W)

DEFLABEL(SUBX_L)
	LDC_FROM_X %al
	mov %edi, %eax
	xchg %edx, %eax
	sbb %edx, %eax
DEFSIZE(SUBX_L)

/*************************************************************************/

/**
 * MUL[SU]_W:  Evaluate op2 * op1 in signed or unsigned context.
 */
DEFLABEL(MULS_W)
	movsx %di, %eax
	movsx %dx, %edx
	imul %edx
	test %eax, %eax
DEFSIZE(MULS_W)

DEFLABEL(MULU_W)
	movzx %di, %eax
	movzx %dx, %edx
	mul %edx
	test %eax, %eax
DEFSIZE(MULU_W)

/*************************************************************************/

/**
 * DIV[SU]_W:  Evaluate op2 / op1 in signed or unsigned context, setting
 * the condition codes appropriately.  The quotient is stored in the low
 * 16 bits, the remainder in the high 16 bits of the result value.  On
 * overflow, op2 is copied to the result.
 */
DEFLABEL(DIVS_W)
	andb $~SR_C, SR
	test %di, %di
	jnz 0f
	movl $EX_DIVIDE_BY_ZERO, Q68State_exception(%rbx)
	TERMINATE
0:	push %rdx  // Save op2 (register value) so we can restore it as the
	           // result on overflow
	mov %edx, %eax
	cdq
	movsx %di, %edi
	idiv %edi
	lea 0x8000(%eax), %ecx
	test $0xFFFF0000, %ecx
	jz 1f
	pop %rax
	orb $SR_V, SR
	jmp 2f
1:	pop %rcx
	shl $16, %edx
	or %edx, %eax
	test %ax, %ax
	SETCC_NZ
	andb $~SR_V, SR
2:
DEFSIZE(DIVS_W)

DEFLABEL(DIVU_W)
	andb $~SR_C, SR
	test %di, %di
	jnz 0f
	movl $EX_DIVIDE_BY_ZERO, Q68State_exception(%rbx)
	TERMINATE
0:	push %rdx  // Save op2 (register value) so we can restore it as the
	           // result on overflow
	mov %edx, %eax
	xor %edx, %edx
	movsx %di, %edi
	div %edi
	test $0xFFFF0000, %eax
	jz 1f
	pop %rax
	orb $SR_V, SR
	jmp 2f
1:	pop %rcx
	shl $16, %edx
	or %edx, %eax
	test %ax, %ax
	SETCC_NZ
	andb $~SR_V, SR
2:
DEFSIZE(DIVU_W)

/*************************************************************************/

/**
 * AND_[BWL]:  Evaluate op2 & op1.
 */
DEFLABEL(AND_B)
	mov %edi, %eax
	and %dl, %al
DEFSIZE(AND_B)

DEFLABEL(AND_W)
	mov %edi, %eax
	and %dx, %ax
DEFSIZE(AND_W)

DEFLABEL(AND_L)
	mov %edi, %eax
	and %edx, %eax
DEFSIZE(AND_L)

/*************************************************************************/

/**
 * OR_[BWL]:  Evaluate op2 | op1.
 */
DEFLABEL(OR_B)
	mov %edi, %eax
	or %dl, %al
DEFSIZE(OR_B)

DEFLABEL(OR_W)
	mov %edi, %eax
	or %dx, %ax
DEFSIZE(OR_W)

DEFLABEL(OR_L)
	mov %edi, %eax
	or %edx, %eax
DEFSIZE(OR_L)

/*************************************************************************/

/**
 * EOR_[BWL]:  Evaluate op2 ^ op1.
 */
DEFLABEL(EOR_B)
	mov %edi, %eax
	xor %dl, %al
DEFSIZE(EOR_B)

DEFLABEL(EOR_W)
	mov %edi, %eax
	xor %dx, %ax
DEFSIZE(EOR_W)

DEFLABEL(EOR_L)
	mov %edi, %eax
	xor %edx, %eax
DEFSIZE(EOR_L)

/*************************************************************************/

/**
 * EXT_[WL]:  Sign-extend op1 from 8 to 16 or from 16 to 32 bits.
 */
DEFLABEL(EXT_W)
	mov %edi, %eax
	movsx %al, %ax
	test %ax, %ax
DEFSIZE(EXT_W)

DEFLABEL(EXT_L)
	movsx %di, %eax
	test %eax, %eax
DEFSIZE(EXT_L)

/*************************************************************************/

/**
 * SWAP:  Swap the upper and lower 16-bit halves of op1, placing the result
 * in the result register.
 */
DEFLABEL(SWAP)
	mov %edi, %eax
	rol $16, %eax
	test %eax, %eax
DEFSIZE(SWAP)

/*************************************************************************/
/**************************** BCD operations *****************************/
/*************************************************************************/

/**
 * ABCD:  Evaluate op2 + op1 + X, treating the operands as binary-coded
 * decimal values.
 */
DEFLABEL(ABCD)
	mov %edi, %ecx
	mov %edx, %eax
	and $0x0F, %ecx
	and $0x0F, %eax
	add %ecx, %eax
	mov SR, %ecx
	shr $SR_X_SHIFT, %ecx
	and $1, %ecx
	add %ecx, %eax
	cmp $10, %eax
	jb 0f
	add $6, %eax
0:	and $0xF0, %edi
	and $0xF0, %edx
	add %edi, %edx
	add %edx, %eax
	xor %ecx, %ecx
	cmp $10<<4, %eax
	jb 1f
	sub $10<<4, %eax
	mov $1, %cl
1:	mov %cl, %dl
	//shl $SR_C_SHIFT, %cl  // Shift count is 0, so omitted
	shl $SR_X_SHIFT, %dl
	or %cl, %dl
	andb $~(SR_X|SR_C), SR
	or %dl, SR
	test %al, %al
	setnz %cl
	shl $SR_Z_SHIFT, %cl
	not %cl
	and %cl, SR
DEFSIZE(ABCD)

/*************************************************************************/

/**
 * SBCD:  Evaluate op2 - op1 - X, treating the operands as binary-coded
 * decimal values.
 */
DEFLABEL(SBCD)
	mov %edi, %ecx
	mov %edx, %eax
	and $0x0F, %ecx
	and $0x0F, %eax
	sub %ecx, %eax
	mov SR, %ecx
	shr $SR_X_SHIFT, %ecx
	and $1, %ecx
	sub %ecx, %eax
	xor %ecx, %ecx
	test %eax, %eax
	jns 0f
	add $10, %eax
	add $16, %ecx
0:	and $0xF0, %edi
	and $0xF0, %edx
	sub %ecx, %edx
	xor %ecx, %ecx
	sub %edi, %edx
	jns 1f
	add $10<<4, %eax
	mov $1, %cl
1:	add %edx, %eax
	jns 2f
	mov $1, %cl
2:	mov %cl, %dl
	//shl $SR_C_SHIFT, %cl  // Shift count is 0, so omitted
	shl $SR_X_SHIFT, %dl
	or %cl, %dl
	andb $~(SR_X|SR_C), SR
	or %dl, SR
	test %al, %al
	setnz %cl
	shl $SR_Z_SHIFT, %cl
	not %cl
	and %cl, SR
DEFSIZE(SBCD)

/*************************************************************************/
/*********************** Bit-twiddling operations ************************/
/*************************************************************************/

/**
 * BTST_[BL]:  Evaluate op2 & (1 << op1).  The value (1 << op1), where the
 * high bits of op1 have been masked to zero, is left in %edi for use by a
 * subsequent BCHG/BCLR/BSET operation.
 */
DEFLABEL(BTST_B)
	mov %edi, %ecx
	and $7, %ecx
	mov $1, %edi
	shl %cl, %edi
	test %edi, %edx
	setz %cl
	shl $SR_Z_SHIFT, %cl
	and $~SR_Z, SR
	or %cl, SR
DEFSIZE(BTST_B)

DEFLABEL(BTST_L)
	mov %edi, %ecx
	and $31, %ecx
	mov $1, %edi
	shl %cl, %edi
	test %edi, %edx
	setz %cl
	shl $SR_Z_SHIFT, %cl
	and $~SR_Z, SR
	or %cl, SR
DEFSIZE(BTST_L)

/*************************************************************************/

/**
 * BCHG:  Evaluate op2 ^ (1 << op1), where (1 << op1) has already been
 * stored in %edi.
 */
DEFLABEL(BCHG)
	mov %edx, %eax
	xor %edi, %eax
DEFSIZE(BCHG)

/*-----------------------------------------------------------------------*/

/**
 * BCLR:  Evaluate op2 & ~(1 << op1), where (1 << op1) has already been
 * stored in %edi.
 */
DEFLABEL(BCLR)
	mov %edx, %eax
	not %edi
	and %edi, %eax
DEFSIZE(BCLR)

/*-----------------------------------------------------------------------*/

/**
 * BSET:  Evaluate op2 | (1 << op1), where (1 << op1) has already been
 * stored in %edi.
 */
DEFLABEL(BSET)
	mov %edx, %eax
	or %edi, %eax
DEFSIZE(BSET)

/*************************************************************************/
/************************ Shift/rotate operations ************************/
/*************************************************************************/

/**
 * SETCC_XC_SHIFT:  Set the X and C flags for a shift or rotate instruction.
 * The value to set (0 or 1) is passed in %dl; %dh is destroyed.  Assumes
 * that the X and C flags have already been cleared.
 */
.macro SETCC_XC_SHIFT
	mov %dl, %dh
	shl $SR_X_SHIFT, %dh
	//shl $SR_C_SHIFT, %dl  // Shift count is 0, so omitted
	or %dh, %dl
	or %dl, SR
.endm

/*************************************************************************/

/**
 * ASL_[BWL]:  Evaluate (signed) op2 << op1.
 */
.macro DEF_ASL nbits, reg
	mov %edi, %ecx
	mov %edx, %eax
	and $0x3F, %ecx
	add %ecx, %esi
	add %ecx, %esi
	andb $~(SR_V|SR_C), SR
	test %ecx, %ecx
	jz 1f
	andb $~SR_X, SR
	// Have to shift bit by bit to detect overflow
0:	sal $1, \reg
	setc %dl
	seto %dh
	shl $SR_V_SHIFT, %dh
	or %dh, SR
	loop 0b
	SETCC_XC_SHIFT
1:	test \reg, \reg
	SETCC_NZ
.endm

DEFLABEL(ASL_B)
	DEF_ASL 8, %al
DEFSIZE(ASL_B)

DEFLABEL(ASL_W)
	DEF_ASL 16, %ax
DEFSIZE(ASL_W)

DEFLABEL(ASL_L)
	DEF_ASL 32, %eax
DEFSIZE(ASL_L)

/*-----------------------------------------------------------------------*/

/**
 * ASR_[BWL]:  Evaluate (signed) op2 >> op1.
 */
.macro DEF_ASR nbits, reg
	mov %edi, %ecx
	mov %edx, %eax
	and $0x3F, %ecx
	add %ecx, %esi
	add %ecx, %esi
	andb $~(SR_V|SR_C), SR
	test %ecx, %ecx
	jz 4f
	andb $~SR_X, SR
	cmp $\nbits, %ecx
	jb 2f
1:	// count >= nbits
	sar $\nbits-1, \reg
	mov %al, %dl
	and $1, %dl
	jmp 3f
2:	// 0 < count < nbits
	sar %cl, \reg
	setc %dl
3:	// count != 0
	SETCC_XC_SHIFT
4:	// All cases
	test \reg, \reg
	SETCC_NZ
.endm

DEFLABEL(ASR_B)
	DEF_ASR 8, %al
DEFSIZE(ASR_B)

DEFLABEL(ASR_W)
	DEF_ASR 16, %ax
DEFSIZE(ASR_W)

DEFLABEL(ASR_L)
	DEF_ASR 32, %eax
DEFSIZE(ASR_L)

/*************************************************************************/

/**
 * LSL_[BWL]:  Evaluate (unsigned) op2 << op1.
 */
.macro DEF_LSL nbits, reg
	mov %edi, %ecx
	mov %edx, %eax
	and $0x3F, %ecx
	add %ecx, %esi
	add %ecx, %esi
	andb $~(SR_V|SR_C), SR
	test %ecx, %ecx
	jz 4f
	andb $~SR_X, SR
	cmp $\nbits, %ecx
	jb 2f
	ja 1f
0:	// count == nbits
	and $1, %al
	mov %al, %dl
	xor \reg, \reg
	jmp 3f
1:	// count > nbits
	xor \reg, \reg
	jmp 4f
2:	// 0 < count < nbits
	sal %cl, \reg
	setc %dl
3:	// 0 < count <= nbits
	SETCC_XC_SHIFT
4:	// All cases
	test \reg, \reg
	SETCC_NZ
.endm

DEFLABEL(LSL_B)
	DEF_LSL 8, %al
DEFSIZE(LSL_B)

DEFLABEL(LSL_W)
	DEF_LSL 16, %ax
DEFSIZE(LSL_W)

DEFLABEL(LSL_L)
	DEF_LSL 32, %eax
DEFSIZE(LSL_L)

/*-----------------------------------------------------------------------*/

/**
 * LSR_[BWL]:  Evaluate (unsigned) op2 >> op1.
 */
.macro DEF_LSR nbits, reg
	mov %edi, %ecx
	mov %edx, %eax
	and $0x3F, %ecx
	add %ecx, %esi
	add %ecx, %esi
	andb $~(SR_V|SR_C), SR
	test %ecx, %ecx
	jz 4f
	andb $~SR_X, SR
	cmp $\nbits, %ecx
	jb 2f
	ja 1f
0:	// count == nbits
	shl $1, \reg
	setc %dl
	xor \reg, \reg
	jmp 3f
1:	// count > nbits
	xor \reg, \reg
	jmp 4f
2:	// 0 < count < nbits
	shr %cl, \reg
	setc %dl
3:	// 0 < count <= nbits
	SETCC_XC_SHIFT
4:	// All cases
	test \reg, \reg
	SETCC_NZ
.endm

DEFLABEL(LSR_B)
	DEF_LSR 8, %al
DEFSIZE(LSR_B)

DEFLABEL(LSR_W)
	DEF_LSR 16, %ax
DEFSIZE(LSR_W)

DEFLABEL(LSR_L)
	DEF_LSR 32, %eax
DEFSIZE(LSR_L)

/*************************************************************************/

/**
 * ROXL_[BWL]:  Evaluate op2 ROXL op1.
 */
.macro DEF_ROXL nbits, reg
	mov %edi, %ecx
	mov %edx, %eax
	and $0x3F, %ecx
	add %ecx, %esi
	add %ecx, %esi
	andb $~(SR_V|SR_C), SR
	test %ecx, %ecx
	jnz 0f
	mov SR, %dl
	shr $SR_X_SHIFT, %dl
	and $1, %dl
	jmp 2f
0:	LDC_FROM_X %dl
1:	rcl \reg
	loop 1b
	setc %dl
	andb $~SR_X, SR
2:	SETCC_XC_SHIFT
	test \reg, \reg
	SETCC_NZ
.endm

DEFLABEL(ROXL_B)
	DEF_ROXL 8, %al
DEFSIZE(ROXL_B)

DEFLABEL(ROXL_W)
	DEF_ROXL 16, %ax
DEFSIZE(ROXL_W)

DEFLABEL(ROXL_L)
	DEF_ROXL 32, %eax
DEFSIZE(ROXL_L)

/*-----------------------------------------------------------------------*/

/**
 * ROXR_[BWL]:  Evaluate op2 ROXR op1.
 */
.macro DEF_ROXR nbits, reg
	mov %edi, %ecx
	mov %edx, %eax
	and $0x3F, %ecx
	add %ecx, %esi
	add %ecx, %esi
	andb $~(SR_V|SR_C), SR
	test %ecx, %ecx
	jnz 0f
	mov SR, %dl
	shr $SR_X_SHIFT, %dl
	and $1, %dl
	jmp 2f
0:	LDC_FROM_X %dl
1:	rcr \reg
	loop 1b
	setc %dl
	andb $~SR_X, SR
2:	SETCC_XC_SHIFT
	test \reg, \reg
	SETCC_NZ
.endm

DEFLABEL(ROXR_B)
	DEF_ROXR 8, %al
DEFSIZE(ROXR_B)

DEFLABEL(ROXR_W)
	DEF_ROXR 16, %ax
DEFSIZE(ROXR_W)

DEFLABEL(ROXR_L)
	DEF_ROXR 32, %eax
DEFSIZE(ROXR_L)

/*************************************************************************/

/**
 * ROL_[BWL]:  Evaluate op2 ROL op1.
 */
.macro DEF_ROL nbits, reg
	mov %edi, %ecx
	mov %edx, %eax
	and $0x3F, %ecx
	add %ecx, %esi
	add %ecx, %esi
	andb $~(SR_V|SR_C), SR
	test %ecx, %ecx
	jz 3f
	and $\nbits-1, %ecx
	jnz 2f
1:	// count != 0 && count % nbits == 0
	mov %al, %dl
	and $1, %dl
	//shl $SR_C_SHIFT, %dl  // Shift count is 0, so omitted
	or %dl, SR
	jmp 3f
2:	// count % nbits != 0
	rol %cl, \reg
	setc %dl
	//shl $SR_C_SHIFT, %dl  // Shift count is 0, so omitted
	or %dl, SR
3:	// All cases
	test \reg, \reg
	SETCC_NZ
.endm

DEFLABEL(ROL_B)
	DEF_ROL 8, %al
DEFSIZE(ROL_B)

DEFLABEL(ROL_W)
	DEF_ROL 16, %ax
DEFSIZE(ROL_W)

DEFLABEL(ROL_L)
	DEF_ROL 32, %eax
DEFSIZE(ROL_L)

/*-----------------------------------------------------------------------*/

/**
 * ROR_[BWL]:  Evaluate op2 ROR op1.
 */
.macro DEF_ROR nbits, reg
	mov %edi, %ecx
	mov %edx, %eax
	and $0x3F, %ecx
	add %ecx, %esi
	add %ecx, %esi
	andb $~(SR_V|SR_C), SR
	test %ecx, %ecx
	jz 3f
	and $\nbits-1, %ecx
	jnz 2f
1:	// count != 0 && count % nbits == 0
	mov %eax, %edx
	shr $\nbits-1, %edx
	and $1, %dl
	//shl $SR_C_SHIFT, %dl  // Shift count is 0, so omitted
	or %dl, SR
	jmp 3f
2:	// count % nbits != 0
	ror %cl, \reg
	setc %dl
	//shl $SR_C_SHIFT, %dl  // Shift count is 0, so omitted
	or %dl, SR
3:	// All cases
	test \reg, \reg
	SETCC_NZ
.endm

DEFLABEL(ROR_B)
	DEF_ROR 8, %al
DEFSIZE(ROR_B)

DEFLABEL(ROR_W)
	DEF_ROR 16, %ax
DEFSIZE(ROR_W)

DEFLABEL(ROR_L)
	DEF_ROR 32, %eax
DEFSIZE(ROR_L)

/*************************************************************************/
/******************* Conditional and branch operations *******************/
/*************************************************************************/

/**
 * Scc:  Set the lower 8 bits of the result value to 0xFF if the condition
 * is true, 0x00 if false.
 */
DEFLABEL(Scc)
	neg %al
DEFSIZE(Scc)

/*-----------------------------------------------------------------------*/

/**
 * ADD_CYCLES_Scc_Dn:  Add the appropriate number of clock cycles for an
 * Scc Dn instruction to the cycle count.
 */
DEFLABEL(ADD_CYCLES_Scc_Dn)
	movzx %al, %ecx
	and $2, %ecx
	add $4, %ecx
	add %ecx, %esi
DEFSIZE(ADD_CYCLES_Scc_Dn)

/*************************************************************************/

/**
 * DBcc:  Jump to the specified target address unless the condition is true
 * or the lower 16 bits of the given data register, after being decremented,
 * are equal to -1.
 *
 * [Parameters]
 *       reg4: Register number * 4 (0-28: D0-D7)
 *     target: Target address
 */
DEFLABEL(DBcc)
	test %al, %al
	jz 0f
	add $12, %esi
	jmp 2f
0:	lea 1(%rbx), %rcx
8:	subw $1, (%rcx)
	mov (%rcx), %ax
	cmp $-1, %ax
	jne 1f
	add $14, %esi
	jmp 2f
1:	add $10, %esi
	mov $0x12345678, %eax
9:	mov %eax, PC
	TERMINATE
2:
DEFSIZE(DBcc)
DEFPARAM(DBcc, reg4, 8b, -1)
DEFPARAM(DBcc, target, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * DBcc_native:  Implement DBcc using a jump within the native code.
 *
 * [Parameters]
 *            reg4: Register number * 4 (0-28: D0-D7)
 *          target: Target 68000 address
 *     native_disp: Target native displacement from end of this fragment
 */
DEFLABEL(DBcc_native)
	test %al, %al
	jz 0f
	add $12, %esi
	jmp 2f
0:	lea 1(%rbx), %rcx
8:	subw $1, (%rcx)
	mov (%rcx), %ax
	cmp $-1, %ax
	jne 1f
	add $14, %esi
	jmp 2f
1:	add $10, %esi
	mov $0x12345678, %eax
9:	mov %eax, PC
	jmp .+0x12345678
2:
DEFSIZE(DBcc_native)
DEFPARAM(DBcc_native, reg4, 8b, -1)
DEFPARAM(DBcc_native, target, 9b, -4)
DEFPARAM(DBcc_native, native_disp, 2b, -4)

/*************************************************************************/

/**
 * Bcc:  Jump to the specified target address if the condition is true.
 *
 * [Parameters]
 *     target: Target address
 */
DEFLABEL(Bcc)
	test %al, %al
	jz 0f
	mov $0x12345678, %eax
9:	mov %eax, PC
	add $10, %esi
	TERMINATE
0:
DEFSIZE(Bcc)
DEFPARAM(Bcc, target, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * Bcc_native:  Implement Bcc using a jump within the native code.
 *
 * [Parameters]
 *          target: Target 68000 address
 *     native_disp: Target native displacement from end of this fragment
 */
DEFLABEL(Bcc_native)
	test %al, %al
	jz 0f
	mov $0x12345678, %eax
9:	mov %eax, PC
	add $10, %esi
	jmp .+0x12345678
0:
DEFSIZE(Bcc_native)
DEFPARAM(Bcc_native, target, 9b, -4)
DEFPARAM(Bcc_native, native_disp, 0b, -4)

/*-----------------------------------------------------------------------*/

/**
 * BSR:  Push the address of the next instruction onto the stack, then jump
 * to the specified target address.
 *
 * [Parameters]
 *     return_addr: Return address to push onto the stack
 *          target: Target address
 */
DEFLABEL(BSR)
	mov $0x12345678, %ecx
8:	PUSH32 %rcx
	mov $0x12345678, %eax
9:	mov %eax, PC
	TERMINATE
DEFSIZE(BSR)
DEFPARAM(BSR, return_addr, 8b, -4)
DEFPARAM(BSR, target, 9b, -4)

/*************************************************************************/

/**
 * JMP:  Jump to the previously resolved effective address.
 */
DEFLABEL(JMP)
	mov Q68State_ea_addr(%rbx), %eax
	mov %eax, PC
	TERMINATE
DEFSIZE(JMP)

/*-----------------------------------------------------------------------*/

/**
 * JSR:  Push the address of the next instruction onto the stack, then jump
 * to the previously resolved effective address.
 *
 * [Parameters]
 *     return_addr: Return address to push onto the stack
 */
DEFLABEL(JSR)
	mov $0x12345678, %ecx
9:	PUSH32 %rcx
	mov Q68State_ea_addr(%rbx), %eax
	mov %eax, PC
	TERMINATE
DEFSIZE(JSR)
DEFPARAM(JSR, return_addr, 9b, -4)

/*************************************************************************/
/*********************** MOVEM-related operations ************************/
/*************************************************************************/

/**
 * STORE_DEC_[WL]:  Decrement state->ea_addr, then store the specified
 * register to the resulting location.
 *
 * [Parameters]
 *     reg4: Register number * 4 (0-28: D0-D7, 32-60: A0-A7)
 */
DEFLABEL(STORE_DEC_W)
	mov Q68State_ea_addr(%rbx), %ecx
	sub $2, %ecx
	mov %ecx, Q68State_ea_addr(%rbx)
	mov 1(%rbx), %eax
9:	WRITE16 %rcx, %rax
DEFSIZE(STORE_DEC_W)
DEFPARAM(STORE_DEC_W, reg4, 9b, -1)

DEFLABEL(STORE_DEC_L)
	mov Q68State_ea_addr(%rbx), %ecx
	sub $4, %ecx
	mov %ecx, Q68State_ea_addr(%rbx)
	mov 1(%rbx), %eax
9:	WRITE32 %rcx, %rax
DEFSIZE(STORE_DEC_L)
DEFPARAM(STORE_DEC_L, reg4, 9b, -1)

/*-----------------------------------------------------------------------*/

/**
 * STORE_INC_[WL]:  Store the specified register to the location indicated
 * by state->ea_addr, then increment state->ea_addr.
 *
 * [Parameters]
 *     reg4: Register number * 4 (0-28: D0-D7, 32-60: A0-A7)
 */
DEFLABEL(STORE_INC_W)
	mov Q68State_ea_addr(%rbx), %ecx
	mov 1(%rbx), %eax
9:	WRITE16 %rcx, %rax
	add $2, Q68State_ea_addr(%rbx)
DEFSIZE(STORE_INC_W)
DEFPARAM(STORE_INC_W, reg4, 9b, -1)

DEFLABEL(STORE_INC_L)
	mov Q68State_ea_addr(%rbx), %ecx
	mov 1(%rbx), %eax
9:	WRITE32 %rcx, %rax
	add $4, Q68State_ea_addr(%rbx)
DEFSIZE(STORE_INC_L)
DEFPARAM(STORE_INC_L, reg4, 9b, -1)

/*************************************************************************/

/**
 * LOAD_INC_[WL]:  Load the specified register from the location indicated
 * by state->ea_addr, then increment state->ea_addr.
 *
 * [Parameters]
 *     reg4: Register number * 4 (0-28: D0-D7, 32-60: A0-A7)
 */
DEFLABEL(LOAD_INC_W)
	mov Q68State_ea_addr(%rbx), %ecx
	READ16 %rcx
	mov %ax, 1(%rbx)
9:	add $2, Q68State_ea_addr(%rbx)
DEFSIZE(LOAD_INC_W)
DEFPARAM(LOAD_INC_W, reg4, 9b, -1)

DEFLABEL(LOAD_INC_L)
	mov Q68State_ea_addr(%rbx), %ecx
	READ32 %rcx
	mov %eax, 1(%rbx)
9:	add $4, Q68State_ea_addr(%rbx)
DEFSIZE(LOAD_INC_L)
DEFPARAM(LOAD_INC_L, reg4, 9b, -1)

/*-----------------------------------------------------------------------*/

/**
 * LOADA_INC_W:  Load the specified address register from the location
 * indicated by state->ea_addr, sign-extending the 16-bit value to 32 bits,
 * then increment state->ea_addr.
 *
 * [Parameters]
 *     reg4: Register number * 4 (32-60: A0-A7)
 */
DEFLABEL(LOADA_INC_W)
	mov Q68State_ea_addr(%rbx), %ecx
	READ16 %rcx
	cwde
	mov %eax, 1(%rbx)
9:	add $2, Q68State_ea_addr(%rbx)
DEFSIZE(LOADA_INC_W)
DEFPARAM(LOADA_INC_W, reg4, 9b, -1)

/*************************************************************************/

/**
 * MOVEM_WRITEBACK:  Store the address in state->ea_addr to the specified
 * address register.
 *
 * [Parameters]
 *     reg4: Register number * 4 (32-60: A0-A7)
 */
DEFLABEL(MOVEM_WRITEBACK)
	mov Q68State_ea_addr(%rbx), %ecx
	mov %ecx, 1(%rbx)
9:
DEFSIZE(MOVEM_WRITEBACK)
DEFPARAM(MOVEM_WRITEBACK, reg4, 9b, -1)

/*************************************************************************/
/*********************** Miscellaneous operations ************************/
/*************************************************************************/

/**
 * CHK_W:  Raise a CHK exception if op1 < 0 or op1 > op2, treating both
 * operands as signed 16-bit values.
 */
DEFLABEL(CHK_W)
	test %di, %di
	jns 0f
	orb $SR_N, SR
	jmp 1f
0:	cmp %dx, %di
	jle 2f
	andb $~SR_N, SR
1:	movl $EX_CHK, Q68State_exception(%rbx)
	TERMINATE
2:
DEFSIZE(CHK_W)

/*************************************************************************/

/**
 * LEA:  Store the previously resolved effective address in the specified
 * address register.
 *
 * [Parameters]
 *     reg4: Register number * 4 (32-60: A0-A7)
 */
DEFLABEL(LEA)
	mov Q68State_ea_addr(%rbx), %eax
	mov %eax, 1(%rbx)
9:
DEFSIZE(LEA)
DEFPARAM(LEA, reg4, 9b, -1)

/*-----------------------------------------------------------------------*/

/**
 * PEA:  Push the previously resolved effective address onto the stack.
 */
DEFLABEL(PEA)
	mov Q68State_ea_addr(%rbx), %ecx
	PUSH32 %rcx
DEFSIZE(PEA)

/*************************************************************************/

/**
 * TAS:  Test the 8-bit value of op1, setting the condition codes
 * appropriately, then calculate op1 | 0x80.
 */
DEFLABEL(TAS)
	mov %edi, %eax
	test %al, %al
	SETCC_NZ00
	or $0x80, %al
DEFSIZE(TAS)

/*************************************************************************/

/**
 * MOVE_FROM_USP:  Copy the user stack pointer to the specified register.
 *
 * [Parameters]
 *     reg4: Register number * 4 (32-60: A0-A7)
 */
DEFLABEL(MOVE_FROM_USP)
	mov USP, %eax
	mov %eax, 1(%rbx)
9:
DEFSIZE(MOVE_FROM_USP)
DEFPARAM(MOVE_FROM_USP, reg4, 9b, -1)

/*-----------------------------------------------------------------------*/

/**
 * MOVE_TO_USP:  Copy the specified register to the user stack pointer.
 *
 * [Parameters]
 *     reg4: Register number * 4 (32-60: A0-A7)
 */
DEFLABEL(MOVE_TO_USP)
	mov 1(%rbx), %eax
9:	mov %eax, USP
DEFSIZE(MOVE_TO_USP)
DEFPARAM(MOVE_TO_USP, reg4, 9b, -1)

/*************************************************************************/

/**
 * STOP:  Halt the processor.
 *
 * [Parameters]
 *     newSR: Value to load into SR
 */
DEFLABEL(STOP)
	movl $1, Q68State_halted(%rbx)
	mov $0x1234, %ax
9:	UPDATE_SR
DEFSIZE(STOP)
DEFPARAM(STOP, newSR, 9b, -2)

/*************************************************************************/

/**
 * TRAPV:  Raise a TRAPV exception if the overflow flag is set.
 */
DEFLABEL(TRAPV)
	testb $SR_V, SR
	jz 0f
	movl $EX_TRAPV, Q68State_exception(%rbx)
	TERMINATE
0:
DEFSIZE(TRAPV)

/*************************************************************************/

/**
 * RTS:  Pop the PC from the stack.
 */
DEFLABEL(RTS)
	POP32
	mov %eax, PC
	TERMINATE
DEFSIZE(RTS)

/*-----------------------------------------------------------------------*/

/**
 * RTR:  Pop the condition codes and PC from the stack.
 */
DEFLABEL(RTR)
	POP16
	mov %al, SR  // Update low byte only
	POP32
	mov %eax, PC
	TERMINATE
DEFSIZE(RTR)

/*-----------------------------------------------------------------------*/

/**
 * RTE:  Pop the status register and PC from the stack.
 */
DEFLABEL(RTE)
	POP16
	push %rax
	POP32
	mov %eax, PC
	pop %rax
	UPDATE_SR
	TERMINATE
DEFSIZE(RTE)

/*************************************************************************/

/**
 * MOVEP_READ_[WL]:  Read a value from memory, skipping every other byte.
 *
 * [Parameters]
 *     areg4: Register number * 4 of base address register (32-60 = A0-A7)
 *      disp: Displacement from base address register
 *     dreg4: Register number * 4 of data reg. to receive data (0-28 = D0-D7)
 */
DEFLABEL(MOVEP_READ_W)
	mov 1(%rbx), %ecx
7:	add $0x12345678, %ecx
8:	push %rcx
	READ8 %rcx      // Byte 1
	movzx %al, %edi
	shl $8, %edi
	pop %rcx
	add $2, %ecx
	READ8 %rcx      // Byte 0
	movzx %al, %eax
	or %eax, %edi
	mov %di, 1(%rbx)
9:
DEFSIZE(MOVEP_READ_W)
DEFPARAM(MOVEP_READ_W, areg4, 7b, -1)
DEFPARAM(MOVEP_READ_W, disp, 8b, -4)
DEFPARAM(MOVEP_READ_W, dreg4, 9b, -1)

DEFLABEL(MOVEP_READ_L)
	mov 1(%rbx), %ecx
7:	add $0x12345678, %ecx
8:	push %rcx
	READ8 %rcx      // Byte 3
	movzx %al, %edi
	shl $24, %edi
	mov (%rsp), %ecx
	add $2, %ecx
	READ8 %rcx      // Byte 2
	movzx %al, %eax
	shl $16, %eax
	or %eax, %edi
	mov (%rsp), %ecx
	add $4, %ecx
	READ8 %rcx      // Byte 1
	movzx %al, %eax
	shl $8, %eax
	or %eax, %edi
	pop %rcx
	add $6, %ecx
	READ8 %rcx      // Byte 0
	movzx %al, %eax
	or %eax, %edi
	mov %di, 1(%rbx)
9:
DEFSIZE(MOVEP_READ_L)
DEFPARAM(MOVEP_READ_L, areg4, 7b, -1)
DEFPARAM(MOVEP_READ_L, disp, 8b, -4)
DEFPARAM(MOVEP_READ_L, dreg4, 9b, -1)

/*-----------------------------------------------------------------------*/

/**
 * MOVEP_WRITE_[WL]:  Write a value to memory, skipping every other byte.
 *
 * [Parameters]
 *     areg4: Register number * 4 of base address register (32-60 = A0-A7)
 *      disp: Displacement from base address register
 *     dreg4: Register number * 4 of data reg. containing data (0-28 = D0-D7)
 */
DEFLABEL(MOVEP_WRITE_W)
	mov 1(%rbx), %ecx
7:	add $0x12345678, %ecx
8:	mov 1(%rbx), %eax
9:	push %rcx
	push %rax
	shr $8, %eax
	WRITE8 %rcx, %rax       // Byte 1
	pop %rax
	pop %rcx
	add $2, %ecx
	WRITE8 %rcx, %rax       // Byte 0
DEFSIZE(MOVEP_WRITE_W)
DEFPARAM(MOVEP_WRITE_W, areg4, 7b, -1)
DEFPARAM(MOVEP_WRITE_W, disp, 8b, -4)
DEFPARAM(MOVEP_WRITE_W, dreg4, 9b, -1)

DEFLABEL(MOVEP_WRITE_L)
	mov 1(%rbx), %ecx
7:	add $0x12345678, %ecx
8:	mov 1(%rbx), %eax
9:	push %rcx
	push %rax
	shr $24, %eax
	WRITE8 %rcx, %rax       // Byte 3
	pop %rax
	mov (%rsp), %ecx
	add $2, %ecx
	push %rax
	shr $16, %eax
	WRITE8 %rcx, %rax       // Byte 2
	pop %rax
	mov (%rsp), %ecx
	add $4, %ecx
	push %rax
	shr $8, %eax
	WRITE8 %rcx, %rax       // Byte 1
	pop %rax
	pop %rcx
	add $6, %ecx
	WRITE8 %rcx, %rax       // Byte 0
DEFSIZE(MOVEP_WRITE_L)
DEFPARAM(MOVEP_WRITE_L, areg4, 7b, -1)
DEFPARAM(MOVEP_WRITE_L, disp, 8b, -4)
DEFPARAM(MOVEP_WRITE_L, dreg4, 9b, -1)

/*************************************************************************/

/**
 * EXG:  Exchange the values of two registers.
 *
 * [Parameters]
 *     reg1_4: Register number * 4 of first register (0-60 = D0-A7)
 *     reg2_4: Register number * 4 of second register (0-60 = D0-A7)
 */
DEFLABEL(EXG)
	lea 1(%rbx), %ecx
8:	lea 1(%rbx), %edx
9:	mov (%rcx), %eax
	mov (%rdx), %edi
	mov %eax, (%rdx)
	mov %edi, (%rcx)
DEFSIZE(EXG)
DEFPARAM(EXG, reg1_4, 8b, -1)
DEFPARAM(EXG, reg2_4, 9b, -1)

/*************************************************************************/
/*************************************************************************/
