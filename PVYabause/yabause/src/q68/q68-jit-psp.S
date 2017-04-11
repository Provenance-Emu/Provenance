/*  src/q68/q68-jit-psp.S: PSP dynamic translation implementation for Q68
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

.set noreorder
.set nomips16

#define s8 fp  // since binutils doesn't seem to recognize $s8 on its own

/*************************************************************************/

/*
 * Register and stack usage is as follows:
 *
 * $v0 -- result; temporary used by macros; (on return) address to resume
 *           execution at, or NULL to terminate execution
 * $v1 -- temporary
 * $a0 -- temporary
 * $a1 -- temporary
 * $a2 -- temporary
 * $a3 -- temporary
 * $t0 -- temporary (not used by macros)
 * $t1 -- temporary (not used by macros)
 * $t2 -- temporary (not used by macros)
 * $t3 -- temporary (not used by macros)
 * $t4 -- temporary (not used by macros)
 * $t5 -- not used
 * $t6 -- not used
 * $t7 -- operand 2
 * $t8 -- not used
 * $t9 -- indirect function call pointer
 * $s0 -- Q68State structure pointer
 * $s1 -- cycles to execute
 * $s2 -- cumulative cycle count
 * $s3 -- operand 1; persistent temporary
 * $s4 -- PC mirror register
 * $s5 -- SR mirror register
 * $s6 -- effective address (used instead of state->ea_addr); persistent
 *           temporary
 * $s7 -- value of Q68State.jit_abort
 * $s8 -- not used (not saved by JIT_CALL())
 *
 * 0($sp) -- temporary (used by READ/WRITE macros to hold addresses)
 * 4($sp) -- temporary (used by READ/WRITE macros to hold values)
 * 8($sp) -- unused
 * 12($sp) -- saved $ra
 */

/*************************************************************************/

/* Label/size/parameter definition macros */
#define DEFLABEL(name) .globl JIT_PSP_##name; \
    .type JIT_PSP_##name, @function; \
    JIT_PSP_##name:
#define DEFSIZE(name)  .globl JIT_PSPSIZE_##name; \
    .type JIT_PSPSIZE_##name, @object; \
    JIT_PSPSIZE_##name: .int . - JIT_PSP_##name
#define DEFPARAM(name,param,label,offset) \
    .globl JIT_PSPPARAM_##name##_##param; \
    .type JIT_PSPPARAM_##name##_##param, @object; \
    JIT_PSPPARAM_##name##_##param: .int label - JIT_PSP_##name + (offset)

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

/*************************************************************************/

/* Shorthand for referencing Q68State fields */

#define D0   Q68State_D+0*4($s0)
#define D1   Q68State_D+1*4($s0)
#define D2   Q68State_D+2*4($s0)
#define D3   Q68State_D+3*4($s0)
#define D4   Q68State_D+4*4($s0)
#define D5   Q68State_D+5*4($s0)
#define D6   Q68State_D+6*4($s0)
#define D7   Q68State_D+7*4($s0)

#define A0   Q68State_A+0*4($s0)
#define A1   Q68State_A+1*4($s0)
#define A2   Q68State_A+2*4($s0)
#define A3   Q68State_A+3*4($s0)
#define A4   Q68State_A+4*4($s0)
#define A5   Q68State_A+5*4($s0)
#define A6   Q68State_A+6*4($s0)
#define A7   Q68State_A+7*4($s0)

#define PC   Q68State_PC($s0)
#define SR   Q68State_SR($s0)
#define USP  Q68State_USP($s0)
#define SSP  Q68State_SSP($s0)

/*************************************************************************/

/* LOAD_DELAY_NOP is used to indicate where a pipeline stall will occur
 * due to a dependency on data loaded by a previous instruction.  It
 * doesn't actually expand to anything, but can be used as a hint for
 * optimization. */

#define LOAD_DELAY_NOP  /*nothing*/

/*************************************************************************/
/************************** Convenience macros ***************************/
/*************************************************************************/

/**
 * seqz:  seqz rd,rs is a clearer substitute for sltiu rd,rs,1 and sets rd
 * to 1 if rs is zero, 0 otherwise.
 */
.macro seqz rd, rs
	sltiu \rd, \rs, 1
.endm

/*-----------------------------------------------------------------------*/

/**
 * snez:  sgtz rd,rs is a clearer substitute for sltu rd,zero,rs and sets
 * rd to 1 if rs is positive, 0 otherwise.
 */
.macro snez rd, rs
	sltu \rd, $zero, \rs
.endm

/*-----------------------------------------------------------------------*/

/**
 * sgtz:  sgtz rd,rs is a clearer substitute for slt rd,zero,rs and sets
 * rd to 1 if rs is positive, 0 otherwise.
 */
.macro sgtz rd, rs
	slt \rd, $zero, \rs
.endm

/*-----------------------------------------------------------------------*/

/**
 * sltz:  sltz rd,rs is a clearer substitute for slti rd,rs,0 and sets rd
 * to 1 if rs is negative, 0 otherwise.
 */
.macro sltz rd, rs
	slti \rd, \rs, 0
.endm

/*************************************************************************/

/**
 * SETUP:  Perform setup required before executing translated code.
 */
.macro SETUP
	addiu $sp, $sp, -16
	lw $s5, Q68State_SR($s0)
	lw $s4, Q68State_PC($s0)
	sw $ra, 12($sp)
	move $s7, $zero
.endm

/*-----------------------------------------------------------------------*/

/**
 * TERMINATE:  Terminate execution of the current block.  The emulator will
 * resume execution at the address in state->PC.
 */
.macro TERMINATE
	lw $ra, 12($sp)
	sw $s4, Q68State_PC($s0)
	sw $s5, Q68State_SR($s0)
	move $v0, $zero
	jr $ra
	addiu $sp, $sp, 16
.endm

/*-----------------------------------------------------------------------*/

/**
 * TERMINATE_CONTINUE:  Terminate execution of the current block, returning
 * the address of the following native instruction.
 */
.macro TERMINATE_CONTINUE
	sw $s4, Q68State_PC($s0)
	jal TERMINATE_CONTINUE_get_pc
	sw $s5, Q68State_SR($s0)
	jr $ra
	addiu $sp, $sp, 16
	SETUP
.endm

/* Helper subroutine to get the PC */
TERMINATE_CONTINUE_get_pc:
	addiu $v0, $ra, 8  // Size of "jr ra; addiu $sp, $sp, 16"
	jr $ra
	lw $ra, 12($sp)  // Preload the saved $ra to avoid a load stall

/*************************************************************************/

/**
 * READ{8,16,32}:  Read a value from memory.  The address to read from is
 * taken from $s6; the value read is returned zero-extended in \return.
 */
.macro READ8 return
	lw $t9, Q68State_readb_func($s0)
	ext $a0, $s6, 0, 24  // Mask off top 8 bits
	LOAD_DELAY_NOP
	jalr $t9
	nop
	andi \return, $v0, 0xFF
.endm

.macro READ16 return
	lw $t9, Q68State_readw_func($s0)
	ext $a0, $s6, 0, 24
	LOAD_DELAY_NOP
	jalr $t9
	nop
	andi \return, $v0, 0xFFFF
.endm

.macro READ32 return
	lw $t9, Q68State_readw_func($s0)
	ext $a0, $s6, 0, 24
	LOAD_DELAY_NOP
	jalr $t9  // Read high word
	sw $a0, 0($sp)
	lw $a0, 0($sp)
	sll $v0, $v0, 16
	lw $t9, Q68State_readw_func($s0)
	sw $v0, 4($sp)
	addiu $a0, $a0, 2
	jalr $t9  // Read low word
	ext $a0, $a0, 0, 24  // Just in case we're reading from $FFFFFE
	lw $v1, 4($sp)
	andi $v0, $v0, 0xFFFF
	LOAD_DELAY_NOP
	or \return, $v0, $v1
.endm

/*-----------------------------------------------------------------------*/

/**
 * WRITE_CHECK_JIT:  Check whether a write of size \nbytes (*bytes*, not
 * bits) to the address in $s6 would clobber a page containing already-
 * translated blocks, and clear those translations if so.  All caller-saved
 * registers are destroyed.
 *
 * Note that this macro uses local label 4.
 */
.macro WRITE_CHECK_JIT nbytes
	srl $a0, $s6, Q68_JIT_PAGE_BITS+3
	addu $a0, $a0, $s0
	lbu $v0, Q68State_jit_pages($a0)
	ext $a1, $s6, Q68_JIT_PAGE_BITS, 3
	li $v1, 1
	beqz $v0, 4f
	sllv $v1, $v1, $a1
	and $v0, $v0, $v1
	beqz $v0, 4f
	move $a1, $s6
	li $a2, \nbytes
	jal q68_jit_clear_write
	move $a0, $s0
	lw $s7, Q68State_jit_abort($s0)
4:
.endm

/*-----------------------------------------------------------------------*/

/**
 * WRITE{8,16,32}:  Write a value to memory.  The address must be stored in
 * $s6, and the value to write in $v0.  Note that a 32-bit write spanning
 * two JIT pages that clobbers the first word of a translated routine
 * beginning on the second page will not be detected.
 */
.macro WRITE8
	sw $v0, 4($sp)
	WRITE_CHECK_JIT 1
	lw $t9, Q68State_writeb_func($s0)
	lw $a1, 4($sp)
	LOAD_DELAY_NOP
	jalr $t9
	ext $a0, $s6, 0, 24
.endm

.macro WRITE16
	sw $v0, 4($sp)
	WRITE_CHECK_JIT 2
	lw $t9, Q68State_writew_func($s0)
	lw $a1, 4($sp)
	LOAD_DELAY_NOP
	jalr $t9
	ext $a0, $s6, 0, 24
.endm

.macro WRITE32
	sw $v0, 4($sp)
	WRITE_CHECK_JIT 4
	lw $t9, Q68State_writew_func($s0)
	lw $a1, 4($sp)
	ext $a0, $s6, 0, 24
	jalr $t9  // Write high word
	srl $a1, $a1, 16
	lw $t9, Q68State_writew_func($s0)
	lhu $a1, 4($sp)  // Keep only the low 16 bits of the value
	addiu $a0, $s6, 2
	jalr $t9  // Write low word
	ext $a0, $a0, 0, 24
.endm

/*-----------------------------------------------------------------------*/

/**
 * {PUSH,POP}{16,32}:  Push or pop values onto or off of the stack.  For
 * POP, the value popped is zero-extended and returned in \return.
 *
 * For pushes, it is assumed that the push does not clobber any
 * JIT-translated code.
 */
.macro PUSH16 value
	lw $a0, A7
	lw $t9, Q68State_writew_func($s0)
	move $a1, \value
	addiu $a0, $a0, -2
	sw $a0, A7
	jalr $t9
	ext $a0, $a0, 0, 24
.endm

.macro PUSH32 value
	lw $a0, A7
	lw $t9, Q68State_writew_func($s0)
	sw \value, 4($sp)
	addiu $a0, $a0, -4
	sw $a0, A7
	ext $a0, $a0, 0, 24
	jalr $t9  // Write high word
	srl $a1, \value, 16
	lw $a0, A7
	lw $t9, Q68State_writew_func($s0)
	lhu $a1, 4($sp)  // Keep only the low 16 bits of \value
	addiu $a0, $a0, 2
	jalr $t9  // Write low word
	ext $a0, $a0, 0, 24
.endm

.macro POP16 return
	lw $a0, A7
	lw $t9, Q68State_readw_func($s0)
	LOAD_DELAY_NOP
	addiu $v0, $a0, 2
	sw $v0, A7
	jalr $t9
	ext $a0, $a0, 0, 24
	andi \return, $v0, 0xFFFF
.endm

.macro POP32 return
	lw $a0, A7
	lw $t9, Q68State_readw_func($s0)
	LOAD_DELAY_NOP
	addiu $v0, $a0, 4
	sw $v0, A7
	jalr $t9  // Read high word
	ext $a0, $a0, 0, 24
	lw $a0, A7
	sll $v0, $v0, 16
	lw $t9, Q68State_readw_func($s0)
	sw $v0, 4($sp)
	addiu $a0, $a0, -2  // Since it was already incremented by 4
	jalr $t9  // Read low word
	ext $a0, $a0, 0, 24
	lw $v1, 4($sp)
	andi $v0, $v0, 0xFFFF
	LOAD_DELAY_NOP
	or \return, $v0, $v1
.endm

/*************************************************************************/

/**
 * SETCC_NZ_[BWL]:  Set the N and Z condition codes according to \value.
 */
.macro SETCC_NZ_B value
	ext $v1, \value, 7, 1
	ins $s5, $v1, SR_N_SHIFT, 1
	andi $v1, \value, 0xFF
	seqz $v1, $v1
	ins $s5, $v1, SR_Z_SHIFT, 1
.endm

.macro SETCC_NZ_W value
	ext $v1, \value, 15, 1
	ins $s5, $v1, SR_N_SHIFT, 1
	andi $v1, \value, 0xFFFF
	seqz $v1, $v1
	ins $s5, $v1, SR_Z_SHIFT, 1
.endm

.macro SETCC_NZ_L value
	ext $v1, \value, 31, 1
	ins $s5, $v1, SR_N_SHIFT, 1
	seqz $v1, \value
	ins $s5, $v1, SR_Z_SHIFT, 1
.endm

/*-----------------------------------------------------------------------*/

/**
 * SETCC_NZ00_[BWL]:  Set the N and Z condition codes according to \value,
 * and clear the V and C condition codes.
 */
.macro SETCC_NZ00_B value
	SETCC_NZ_B \value
	ins $s5, $zero, 0, 2
.endm

.macro SETCC_NZ00_W value
	SETCC_NZ_W \value
	ins $s5, $zero, 0, 2
.endm

.macro SETCC_NZ00_L value
	SETCC_NZ_L \value
	ins $s5, $zero, 0, 2
.endm

/*-----------------------------------------------------------------------*/

/**
 * SETCC_XNZVC_ADD:  Set the condition codes for an ADD operation based on
 * the values in the op1, op2, and result registers.
 */
.macro SETCC_XNZVC_ADD nbits
	.if \nbits == 8
		SETCC_NZ_B $v0
	.else
	.if \nbits == 16
		SETCC_NZ_W $v0
	.else
		SETCC_NZ_L $v0
	.endif
	.endif
	xor $a0, $s3, $v0
	xor $a1, $t7, $v0
	and $v1, $a0, $a1
	ext $v1, $v1, \nbits-1, 1
	ins $s5, $v1, SR_V_SHIFT, 1
	ext $a0, $s3, \nbits-1, 1
	ext $a1, $t7, \nbits-1, 1
	ext $v1, $v0, \nbits-1, 1
	addu $a0, $a0, $a1
	subu $v1, $a0, $v1
	sgtz $v1, $v1
	ins $s5, $v1, SR_C_SHIFT, 1
	ins $s5, $v1, SR_X_SHIFT, 1
.endm

/*-----------------------------------------------------------------------*/

/**
 * SETCC_XNZVC_ADDX:  Set the condition codes for an ADDX operation based
 * on the values in the op1, op2, and result registers.
 */
.macro SETCC_XNZVC_ADDX nbits
	// Z is only cleared (never set) by ADDX etc., so we can't use SETNZ
	ext $v1, $v0, \nbits-1, 1
	ins $s5, $v1, SR_N_SHIFT, 1
	.if \nbits < 32
		ext $v1, $v0, 0, \nbits
		snez $v1, $v1
	.else
		snez $v1, $v0
	.endif
	sll $v1, $v1, SR_Z_SHIFT
	not $v1, $v1
	and $s5, $s5, $v1
	xor $a0, $s3, $v0
	xor $a1, $t7, $v0
	and $v1, $a0, $a1
	ext $v1, $v1, \nbits-1, 1
	ins $s5, $v1, SR_V_SHIFT, 1
	ext $a0, $s3, \nbits-1, 1
	ext $a1, $t7, \nbits-1, 1
	ext $v1, $v0, \nbits-1, 1
	addu $a0, $a0, $a1
	subu $v1, $a0, $v1
	sgtz $v1, $v1
	ins $s5, $v1, SR_C_SHIFT, 1
	ins $s5, $v1, SR_X_SHIFT, 1
.endm

/*-----------------------------------------------------------------------*/

/**
 * SETCC_NZVC_SUB, SETCC_XNZVC_SUB:  Set the condition codes for a SUB
 * operation (excluding or including the X flag) based on the values in the
 * op1, op2, and result registers.
 */
.macro SETCC_NZVC_SUB nbits
	.if \nbits == 8
		SETCC_NZ_B $v0
	.else
	.if \nbits == 16
		SETCC_NZ_W $v0
	.else
		SETCC_NZ_L $v0
	.endif
	.endif
	xor $a0, $s3, $t7
	xor $a1, $v0, $t7
	and $v1, $a0, $a1
	ext $v1, $v1, \nbits-1, 1
	ins $s5, $v1, SR_V_SHIFT, 1
	ext $a0, $s3, \nbits-1, 1
	ext $a1, $t7, \nbits-1, 1
	ext $v1, $v0, \nbits-1, 1
	subu $a0, $a0, $a1
	addu $v1, $a0, $v1
	sgtz $v1, $v1
	ins $s5, $v1, SR_C_SHIFT, 1
.endm

.macro SETCC_XNZVC_SUB nbits
	SETCC_NZVC_SUB \nbits
	ins $s5, $v1, SR_X_SHIFT, 1
.endm

/*-----------------------------------------------------------------------*/

/**
 * SETCC_XNZVC_SUBX:  Set the condition codes for a SUBX operation based on
 * the values in the op1, op2, and result registers.
 */
.macro SETCC_XNZVC_SUBX nbits
	ext $v1, $v0, \nbits-1, 1
	ins $s5, $v1, SR_N_SHIFT, 1
	.if \nbits < 32
		ext $v1, $v0, 0, \nbits
		snez $v1, $v1
	.else
		snez $v1, $v0
	.endif
	sll $v1, $v1, SR_Z_SHIFT
	not $v1, $v1
	and $s5, $s5, $v1
	xor $a0, $s3, $t7
	xor $a1, $v0, $t7
	and $v1, $a0, $a1
	ext $v1, $v1, \nbits-1, 1
	ins $s5, $v1, SR_V_SHIFT, 1
	ext $a0, $s3, \nbits-1, 1
	ext $a1, $t7, \nbits-1, 1
	ext $v1, $v0, \nbits-1, 1
	subu $a0, $a0, $a1
	addu $v1, $a0, $v1
	sgtz $v1, $v1
	ins $s5, $v1, SR_C_SHIFT, 1
	ins $s5, $v1, SR_X_SHIFT, 1
.endm

/*************************************************************************/
/*************************** Local subroutines ***************************/
/*************************************************************************/

/**
 * UPDATE_SR:  Set the status register according to the value in $v0.
 */
UPDATE_SR:
	lw $a0, Q68State_irq($s0)  // Load early for IRQ check below
	xor $v1, $s5, $v0
	andi $v1, $v1, SR_S	// Change in S bit?
	beqz $v1, 1f
	andi $s5, $v0, 0xFFFF   // Zero-extend value into SR mirror register
	andi $v1, $v0, SR_S	// Which way did it change?
	beqz $v1, 0f
	lw $a0, A7
	lw $a1, SSP		// Into supervisor mode
	LOAD_DELAY_NOP
	sw $a0, USP
	j 1f
	sw $a1, A7
0:	lw $a1, USP		// Out of supervisor mode
	sw $a0, SSP
	LOAD_DELAY_NOP
	sw $a1, A7
1:	andi $v1, $a0, 7
	slti $a1, $v1, 7	// Check for a pending NMI
	beqz $a1, 2f
	ext $v0, $v0, SR_I0_SHIFT, 3
	slt $v0, $v0, $v1	// Check for a pending unmasked interrupt
	beqz $v0, 3f
2:	addiu $a0, $v1, EX_LEVEL_1_INTERRUPT-1  // In a delay slot, but okay
	sw $a0, Q68State_exception($s0)
	sw $zero, Q68State_irq($s0)
	TERMINATE
3:	jr $ra
	nop

/*************************************************************************/
/**************************** Meta-operations ****************************/
/*************************************************************************/

/**
 * PROLOGUE:  Any prologue necessary at the beginning of the code stream.
 */
DEFLABEL(PROLOGUE)
_PROLOGUE_TOP:
	/* Include various exceptional termination code here, so we can
	 * conditionally branch to it (meaning we can skip the branch in
	 * 1-2 cycles) instead of having to inverse-branch around an
	 * unconditional jump (costing 3-4 cycles). */
	b 0f
	nop
_PROLOGUE_TERMINATE:  // Generic termination (used for CHECK_ABORT)
1:	TERMINATE
_PROLOGUE_EXCEPTION:  // Exception raised (exception number in $a0)
	b 1b
	sw $a0, Q68State_exception($s0)
_PROLOGUE_ADDRESS_ERROR_EA:  // EA address error (opcode in $a2, status in $a3)
	li $v1, EX_ADDRESS_ERROR
	sw $v1, Q68State_exception($s0)
	sw $s6, Q68State_fault_addr($s0)
	sh $a2, Q68State_fault_opcode($s0)
	b 1b
	sh $a3, Q68State_fault_status($s0)
_PROLOGUE_ADDRESS_ERROR_SP:  // Stack address error (address in $a1,
                             // opcode in $a2, status in $a3)
	li $a0, EX_ADDRESS_ERROR
	sw $a0, Q68State_exception($s0)
	sw $v1, Q68State_fault_addr($s0)
	sh $a2, Q68State_fault_opcode($s0)
	b 1b
	sh $a3, Q68State_fault_status($s0)
0:	// Actual setup starts here
	SETUP
DEFSIZE(PROLOGUE)


/* Offset definitions used for branching to termination code; "branchofs"
 * is the offset in _instructions_ (not bytes) from the beginning of the
 * named fragment */
#define DEFOFS(name,branchofs) \
    .globl JIT_PSPOFS_##name; \
    .type JIT_PSPOFS_##name, @object; \
    JIT_PSPOFS_##name: .int _PROLOGUE_##name - _PROLOGUE_TOP - 4*branchofs
DEFOFS(TERMINATE, 0)
DEFOFS(EXCEPTION, 0)
DEFOFS(ADDRESS_ERROR_EA, 2)
DEFOFS(ADDRESS_ERROR_SP, 4)

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
	lw $s3, Q68State_cycles($s0)
	addu $t0, $s3, $s2
	sw $t0, Q68State_cycles($s0)
	sw $s4, Q68State_PC($s0)
	jal q68_trace
	sw $s5, Q68State_SR($s0)
	sw $s3, Q68State_cycles($s0)
DEFSIZE(TRACE)

/*************************************************************************/

/**
 * ADD_CYCLES:  Add the specified number of clock cycles to the cycle count.
 *
 * [Parameters]
 *     cycles: Number of clock cycles to add
 */
DEFLABEL(ADD_CYCLES)
	addiu $s2, $s2, 1
9:
DEFSIZE(ADD_CYCLES)
DEFPARAM(ADD_CYCLES, cycles, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * CHECK_CYCLES:  Check whether the clock cycle limit has been reached, and
 * interrupt execution if so.
 */
DEFLABEL(CHECK_CYCLES)
	slt $v0, $s2, $s1
	bnez $v0, 2f
	sw $s4, Q68State_PC($s0)  // Can't have JAL in a delay slot
	jal CHECK_CYCLES_get_pc   //    (got to keep up their reputation)
	sw $s5, Q68State_SR($s0)
0:	jr $ra
	addiu $sp, $sp, 16
1:	SETUP
2:
DEFSIZE(CHECK_CYCLES)

/* Helper subroutine to get the PC (as with TERMINATE_CONTINUE) */
CHECK_CYCLES_get_pc:
	addiu $v0, $ra, 1b-0b
	jr $ra
	lw $ra, 12($sp)  // Preload the saved $ra to avoid a load stall

/*************************************************************************/

/**
 * ADVANCE_PC:  Add the specified value to the current program counter.
 *
 * [Parameters]
 *     value: Amount to add
 */
DEFLABEL(ADVANCE_PC)
	addiu $s4, $s4, 1
9:
DEFSIZE(ADVANCE_PC)
DEFPARAM(ADVANCE_PC, value, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * ADVANCE_PC_CHECK_ABORT:  Add the specified value to the current program
 * counter, then check the jit_abort flag and abort if necessary.
 *
 * [Parameters]
 *      value: Amount to add
 *     disp_4: (JIT_PSPOFS_TERMINATE - native offset of this fragment) / 4
 */
DEFLABEL(ADVANCE_PC_CHECK_ABORT)
	bnez $s7, .+0x1234
8:	addiu $s4, $s4, 1
9:
DEFSIZE(ADVANCE_PC_CHECK_ABORT)
DEFPARAM(ADVANCE_PC_CHECK_ABORT, value, 9b, -4)
DEFPARAM(ADVANCE_PC_CHECK_ABORT, disp_4, 8b, -4)

/*-----------------------------------------------------------------------*/

/**
 * CHECK_ABORT:  Check the jit_abort flag and abort if necessary.
 *
 * [Parameters]
 *     disp_4: (JIT_PSPOFS_TERMINATE - native offset of this fragment) / 4
 */
DEFLABEL(CHECK_ABORT)
	bnez $s7, .+0x1234
9:	nop
DEFSIZE(CHECK_ABORT)
DEFPARAM(CHECK_ABORT, disp_4, 9b, -4)

/*************************************************************************/

/**
 * EXCEPTION:  Raise the specified exception.
 *
 * [Parameters]
 *        num: Exception number
 *     disp_4: (JIT_PSPOFS_EXCEPTION - native offset of this fragment) / 4
 */
DEFLABEL(EXCEPTION)
	b .+0x1234
8:	addiu $a0, $zero, 1
9:
DEFSIZE(EXCEPTION)
DEFPARAM(EXCEPTION, num, 9b, -4)
DEFPARAM(EXCEPTION, disp_4, 8b, -4)

/*-----------------------------------------------------------------------*/

/**
 * CHECK_ALIGNED_EA:  Check whether the previously resolved effective
 * address is word-aligned (bit 0 is clear), and raise an address error
 * exception if not.
 *
 * [Parameters]
 *     opcode: Instruction opcode
 *     status: Status word for address error exception
 *     disp_4: (JIT_PSPOFS_ADDRESS_ERROR_EA
 *                  - native offset of this fragment) / 4
 */
DEFLABEL(CHECK_ALIGNED_EA)
	andi $v1, $s6, 1
	ori $a2, $zero, 0x1234
7:	bnezl $v1, .+0x1234
8:	ori $a3, $zero, 0x1234
9:
DEFSIZE(CHECK_ALIGNED_EA)
DEFPARAM(CHECK_ALIGNED_EA, opcode, 7b, -4)
DEFPARAM(CHECK_ALIGNED_EA, status, 9b, -4)
DEFPARAM(CHECK_ALIGNED_EA, disp_4, 8b, -4)

/*-----------------------------------------------------------------------*/

/**
 * CHECK_ALIGNED_SP:  Check whether the current stack pointer (register A7)
 * is word-aligned (bit 0 is clear), and raise an address error exception
 * if not.  Destroys $v1 and $a0-$a3.
 *
 * [Parameters]
 *     opcode: Instruction opcode
 *     status: Status word for address error exception
 *     disp_4: (JIT_PSPOFS_ADDRESS_ERROR_SP
 *                  - native offset of this fragment) / 4
 */
DEFLABEL(CHECK_ALIGNED_SP)
	lw $a1, A7
	ori $a2, $zero, 0x1234
7:	LOAD_DELAY_NOP
	andi $v1, $a1, 1
	bnez $v1, .+0x1234
8:	ori $a3, $zero, 0x1234
9:
DEFSIZE(CHECK_ALIGNED_SP)
DEFPARAM(CHECK_ALIGNED_SP, opcode, 7b, -4)
DEFPARAM(CHECK_ALIGNED_SP, status, 9b, -4)
DEFPARAM(CHECK_ALIGNED_SP, disp_4, 8b, -4)

/*-----------------------------------------------------------------------*/

/**
 * CHECK_SUPER:  Check whether the processor is in supervisor mode, and
 * raise a privilege violation exception if not.
 *
 * [Parameters]
 *     disp_4: (JIT_PSPOFS_EXCEPTION - native offset of this fragment) / 4
 */
DEFLABEL(CHECK_SUPER)
	andi $v0, $s5, SR_S
	beqzl $v0, .+0x1234
9:	li $a0, EX_PRIVILEGE_VIOLATION
DEFSIZE(CHECK_SUPER)
DEFPARAM(CHECK_SUPER, disp_4, 9b, -4)

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
	lw $s6, 1($s0)
9:
DEFSIZE(RESOLVE_INDIRECT)
DEFPARAM(RESOLVE_INDIRECT, reg4, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * RESOLVE_POSTINC:  Resolve an address register postincrement reference.
 *
 * [Parameters]
 *     reg4: (8+n)*4 for register An
 *     size: Size in bytes of the reference
 */
DEFLABEL(RESOLVE_POSTINC)
	lw $s6, 1($s0)
7:	LOAD_DELAY_NOP
	LOAD_DELAY_NOP
	addiu $v0, $s6, 1
8:	sw $v0, 1($s0)
9:
DEFSIZE(RESOLVE_POSTINC)
DEFPARAM(RESOLVE_POSTINC, reg4, 7b, -4)
DEFPARAM(RESOLVE_POSTINC, size, 8b, -4)
DEFPARAM(RESOLVE_POSTINC, reg4_b, 9b, -4)  // same as reg4

/* For byte-sized (A7)+, make sure A7 stays even */
DEFLABEL(RESOLVE_POSTINC_A7_B)
	lw $s6, A7
	LOAD_DELAY_NOP
	LOAD_DELAY_NOP
	addiu $s6, $s6, 1
	addiu $v0, $s6, 1
	sw $v0, A7
DEFSIZE(RESOLVE_POSTINC_A7_B)

/*-----------------------------------------------------------------------*/

/**
 * RESOLVE_PREDEC:  Resolve an address register predecrement reference.
 *
 * [Parameters]
 *      reg4: (8+n)*4 for register An
 *     nsize: Size in bytes of the reference, negated
 */
DEFLABEL(RESOLVE_PREDEC)
	lw $s6, 1($s0)
7:	LOAD_DELAY_NOP
	LOAD_DELAY_NOP
	addiu $s6, $s6, -1
8:	sw $s6, 1($s0)
9:
DEFSIZE(RESOLVE_PREDEC)
DEFPARAM(RESOLVE_PREDEC, reg4, 7b, -4)
DEFPARAM(RESOLVE_PREDEC, nsize, 8b, -4)
DEFPARAM(RESOLVE_PREDEC, reg4_b, 9b, -4)  // same as reg4

/* For byte-sized -(A7), make sure A7 stays even */
DEFLABEL(RESOLVE_PREDEC_A7_B)
	lw $s6, 1($s0)
	LOAD_DELAY_NOP
	LOAD_DELAY_NOP
	addiu $s6, $s6, -1
	addiu $v0, $s6, -1
	sw $v0, A7
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
	lw $s6, 1($s0)
8:	LOAD_DELAY_NOP
	LOAD_DELAY_NOP
	addiu $s6, $s6, 1
9:
DEFSIZE(RESOLVE_DISP)
DEFPARAM(RESOLVE_DISP, reg4, 8b, -4)
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
	lw $s6, 1($s0)
7:	lh $v0, 1($s0)
8:	LOAD_DELAY_NOP
	addi $s6, $s6, 1
9:	add $s6, $s6, $v0
DEFSIZE(RESOLVE_INDEX_W)
DEFPARAM(RESOLVE_INDEX_W, reg4, 7b, -4)
DEFPARAM(RESOLVE_INDEX_W, ireg4, 8b, -4)
DEFPARAM(RESOLVE_INDEX_W, disp, 9b, -4)

DEFLABEL(RESOLVE_INDEX_L)
	lw $s6, 1($s0)
7:	lw $v0, 1($s0)
8:	LOAD_DELAY_NOP
	addi $s6, $s6, 1
9:	add $s6, $s6, $v0
DEFSIZE(RESOLVE_INDEX_L)
DEFPARAM(RESOLVE_INDEX_L, reg4, 7b, -4)
DEFPARAM(RESOLVE_INDEX_L, ireg4, 8b, -4)
DEFPARAM(RESOLVE_INDEX_L, disp, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * RESOLVE_ABSOLUTE:  Resolve an absolute short, absolute long, or
 * PC-relative reference.
 *
 * [Parameters]
 *     addr_hi: Absolute address, high 16 bits
 *     addr_lo: Absolute address, low 16 bits
 */
DEFLABEL(RESOLVE_ABSOLUTE)
	lui $s6, 0x1234
8:	ori $s6, $s6, 0x5678
9:
DEFSIZE(RESOLVE_ABSOLUTE)
DEFPARAM(RESOLVE_ABSOLUTE, addr_hi, 8b, -4)
DEFPARAM(RESOLVE_ABSOLUTE, addr_lo, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * RESOLVE_ABS_INDEX_[WL]:  Resolve a PC-relative with index reference.
 *
 * [Parameters]
 *       ireg4: Index register number * 4
 *     addr_hi: Absolute address, high 16 bits
 *     addr_lo: Absolute address, low 16 bits
 */
DEFLABEL(RESOLVE_ABS_INDEX_W)
	lh $v0, 1($s0)
7:	lui $s6, 0x1234
8:	ori $s6, $s6, 0x5678
9:	addu $s6, $s6, $v0
DEFSIZE(RESOLVE_ABS_INDEX_W)
DEFPARAM(RESOLVE_ABS_INDEX_W, ireg4, 7b, -4)
DEFPARAM(RESOLVE_ABS_INDEX_W, addr_hi, 8b, -4)
DEFPARAM(RESOLVE_ABS_INDEX_W, addr_lo, 9b, -4)

DEFLABEL(RESOLVE_ABS_INDEX_L)
	lh $v0, 1($s0)
7:	lui $s6, 0x1234
8:	ori $s6, $s6, 0x5678
9:	addu $s6, $s6, $v0
DEFSIZE(RESOLVE_ABS_INDEX_L)
DEFPARAM(RESOLVE_ABS_INDEX_L, ireg4, 7b, -4)
DEFPARAM(RESOLVE_ABS_INDEX_L, addr_hi, 8b, -4)
DEFPARAM(RESOLVE_ABS_INDEX_L, addr_lo, 9b, -4)

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
	lw $s3, 1($s0)
9:
DEFSIZE(GET_OP1_REGISTER)
DEFPARAM(GET_OP1_REGISTER, reg4, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * GET_OP1_EA_[BWL]:  Get the value pointed to by the previously resolved
 * effective address as operand 1.
 */
DEFLABEL(GET_OP1_EA_B)
	READ8 $s3
DEFSIZE(GET_OP1_EA_B)

DEFLABEL(GET_OP1_EA_W)
	READ16 $s3
DEFSIZE(GET_OP1_EA_W)

DEFLABEL(GET_OP1_EA_L)
	READ32 $s3
DEFSIZE(GET_OP1_EA_L)

/*-----------------------------------------------------------------------*/

/**
 * GET_OP1_IMMED_{16S,16U,16HI,32}:  Get an immediate value as operand 1.
 *
 * [Parameters]
 *     value_hi: High 16 bits of immediate value
 *     value_lo: Low 16 bits of immediate value (signed for 16S, else unsigned)
 */
DEFLABEL(GET_OP1_IMMED_16S)
	addiu $s3, $zero, 1
9:
DEFSIZE(GET_OP1_IMMED_16S)
DEFPARAM(GET_OP1_IMMED_16S, value_lo, 9b, -4)

DEFLABEL(GET_OP1_IMMED_16U)
	ori $s3, $zero, 1
9:
DEFSIZE(GET_OP1_IMMED_16U)
DEFPARAM(GET_OP1_IMMED_16U, value_lo, 9b, -4)

DEFLABEL(GET_OP1_IMMED_16HI)
	lui $s3, 1
9:
DEFSIZE(GET_OP1_IMMED_16HI)
DEFPARAM(GET_OP1_IMMED_16HI, value_hi, 9b, -4)

DEFLABEL(GET_OP1_IMMED_32)
	lui $s3, 1
8:	ori $s3, $s3, 1
9:
DEFSIZE(GET_OP1_IMMED_32)
DEFPARAM(GET_OP1_IMMED_32, value_hi, 8b, -4)
DEFPARAM(GET_OP1_IMMED_32, value_lo, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * GET_OP1_CCR:  Get the current value of CCR as operand 1.
 */
DEFLABEL(GET_OP1_CCR)
	andi $s3, $s5, 0xFF
DEFSIZE(GET_OP1_CCR)

/*-----------------------------------------------------------------------*/

/**
 * GET_OP1_SR:  Get the current value of SR as operand 1.
 */
DEFLABEL(GET_OP1_SR)
	move $s3, $s5
DEFSIZE(GET_OP1_SR)

/*************************************************************************/

/**
 * GET_OP2_*:  Get the same things as above as operand 2.
 */
DEFLABEL(GET_OP2_REGISTER)
	lw $t7, 1($s0)
9:
DEFSIZE(GET_OP2_REGISTER)
DEFPARAM(GET_OP2_REGISTER, reg4, 9b, -4)

/*-----------------------------------------------------------------------*/

DEFLABEL(GET_OP2_EA_B)
	READ8 $t7
DEFSIZE(GET_OP2_EA_B)

DEFLABEL(GET_OP2_EA_W)
	READ16 $t7
DEFSIZE(GET_OP2_EA_W)

DEFLABEL(GET_OP2_EA_L)
	READ32 $t7
DEFSIZE(GET_OP2_EA_L)

/*-----------------------------------------------------------------------*/

DEFLABEL(GET_OP2_IMMED_16S)
	addiu $t7, $zero, 1
9:
DEFSIZE(GET_OP2_IMMED_16S)
DEFPARAM(GET_OP2_IMMED_16S, value_lo, 9b, -4)

DEFLABEL(GET_OP2_IMMED_16U)
	ori $t7, $zero, 1
9:
DEFSIZE(GET_OP2_IMMED_16U)
DEFPARAM(GET_OP2_IMMED_16U, value_lo, 9b, -4)

DEFLABEL(GET_OP2_IMMED_16HI)
	lui $t7, 1
9:
DEFSIZE(GET_OP2_IMMED_16HI)
DEFPARAM(GET_OP2_IMMED_16HI, value_hi, 9b, -4)

DEFLABEL(GET_OP2_IMMED_32)
	lui $t7, 1
8:	ori $t7, $t7, 1
9:
DEFSIZE(GET_OP2_IMMED_32)
DEFPARAM(GET_OP2_IMMED_32, value_hi, 8b, -4)
DEFPARAM(GET_OP2_IMMED_32, value_lo, 9b, -4)

/*-----------------------------------------------------------------------*/

DEFLABEL(GET_OP2_CCR)
	andi $t7, $s5, 0xFF
DEFSIZE(GET_OP2_CCR)

/*-----------------------------------------------------------------------*/

DEFLABEL(GET_OP2_SR)
	move $t7, $s5
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
	sb $v0, 1($s0)
9:
DEFSIZE(SET_REGISTER_B)
DEFPARAM(SET_REGISTER_B, reg4, 9b, -4)

DEFLABEL(SET_REGISTER_W)
	sh $v0, 1($s0)
9:
DEFSIZE(SET_REGISTER_W)
DEFPARAM(SET_REGISTER_W, reg4, 9b, -4)

DEFLABEL(SET_REGISTER_L)
	sw $v0, 1($s0)
9:
DEFSIZE(SET_REGISTER_L)
DEFPARAM(SET_REGISTER_L, reg4, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * SET_AREG_W:  Set the value of the given address register to the
 * sign-extended result value.
 *
 * [Parameters]
 *     reg4: Register number * 4 (32-60: A0-A7)
 */
DEFLABEL(SET_AREG_W)
	seh $v1, $v0
	sw $v1, 1($s0)
9:
DEFSIZE(SET_AREG_W)
DEFPARAM(SET_AREG_W, reg4, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * SET_EA_[BWL]:  Set the value pointed to by the previously resolved
 * effective address to the result value.
 */
DEFLABEL(SET_EA_B)
	WRITE8
DEFSIZE(SET_EA_B)

DEFLABEL(SET_EA_W)
	WRITE16
DEFSIZE(SET_EA_W)

DEFLABEL(SET_EA_L)
	WRITE32
DEFSIZE(SET_EA_L)

/*-----------------------------------------------------------------------*/

/**
 * SET_CCR:  Set the condition codes from the result value.
 */
DEFLABEL(SET_CCR)
	ins $s5, $v0, 0, 8
DEFSIZE(SET_CCR)

/*-----------------------------------------------------------------------*/

/**
 * SET_SR:  Set the status register from the result value.
 */
DEFLABEL(SET_SR)
	jal UPDATE_SR
	nop
DEFSIZE(SET_SR)

/*************************************************************************/
/*************************** Stack operations ****************************/
/*************************************************************************/

/**
 * PUSH_L:  Push the 32-bit value of operand 1 onto the stack.
 */
DEFLABEL(PUSH_L)
	PUSH32 $s3
DEFSIZE(PUSH_L)

/*-----------------------------------------------------------------------*/

/**
 * POP_L:  Pop a 32-bit value off the stack into the result register.
 */
DEFLABEL(POP_L)
	POP32 $v0
DEFSIZE(POP_L)

/*************************************************************************/
/************************ Condition code setting *************************/
/*************************************************************************/

/**
 * SETCC_ADD_[BWL]:  Set the condition codes for the result of an ADD
 * instruction stored in the result register.
 */
DEFLABEL(SETCC_ADD_B)
	SETCC_XNZVC_ADD 8
DEFSIZE(SETCC_ADD_B)

DEFLABEL(SETCC_ADD_W)
	SETCC_XNZVC_ADD 16
DEFSIZE(SETCC_ADD_W)

DEFLABEL(SETCC_ADD_L)
	SETCC_XNZVC_ADD 32
DEFSIZE(SETCC_ADD_L)

/*************************************************************************/

/**
 * SETCC_ADDX_[BWL]:  Set the condition codes for the result of an ADDX
 * instruction stored in the result register.
 */
DEFLABEL(SETCC_ADDX_B)
	SETCC_XNZVC_ADDX 8
DEFSIZE(SETCC_ADDX_B)

DEFLABEL(SETCC_ADDX_W)
	SETCC_XNZVC_ADDX 16
DEFSIZE(SETCC_ADDX_W)

DEFLABEL(SETCC_ADDX_L)
	SETCC_XNZVC_ADDX 32
DEFSIZE(SETCC_ADDX_L)

/*************************************************************************/

/**
 * SETCC_SUB_[BWL]:  Set the condition codes for the result of a SUB
 * instruction stored in the result register.
 */
DEFLABEL(SETCC_SUB_B)
	SETCC_XNZVC_SUB 8
DEFSIZE(SETCC_SUB_B)

DEFLABEL(SETCC_SUB_W)
	SETCC_XNZVC_SUB 16
DEFSIZE(SETCC_SUB_W)

DEFLABEL(SETCC_SUB_L)
	SETCC_XNZVC_SUB 32
DEFSIZE(SETCC_SUB_L)

/*************************************************************************/

/**
 * SETCC_SUBX_[BWL]:  Set the condition codes for the result of a SUBX
 * instruction stored in the result register.
 */
DEFLABEL(SETCC_SUBX_B)
	SETCC_XNZVC_SUBX 8
DEFSIZE(SETCC_SUBX_B)

DEFLABEL(SETCC_SUBX_W)
	SETCC_XNZVC_SUBX 16
DEFSIZE(SETCC_SUBX_W)

DEFLABEL(SETCC_SUBX_L)
	SETCC_XNZVC_SUBX 32
DEFSIZE(SETCC_SUBX_L)

/*************************************************************************/

/**
 * SETCC_CMP_[BWL]:  Set the condition codes for the result of a CMP
 * instruction stored in the result register.  The X flag is unmodified.
 */
DEFLABEL(SETCC_CMP_B)
	SETCC_NZVC_SUB 8
DEFSIZE(SETCC_CMP_B)

DEFLABEL(SETCC_CMP_W)
	SETCC_NZVC_SUB 16
DEFSIZE(SETCC_CMP_W)

DEFLABEL(SETCC_CMP_L)
	SETCC_NZVC_SUB 32
DEFSIZE(SETCC_CMP_L)

/*************************************************************************/

/**
 * SETCC_LOGIC_[BWL]:  Set the condition codes for the result of a logical
 * instruction (MOVE, AND, OR, EOR) stored in the result register.  The X
 * flag is unmodified.
 */
DEFLABEL(SETCC_LOGIC_B)
	SETCC_NZ00_B $v0
DEFSIZE(SETCC_LOGIC_B)

DEFLABEL(SETCC_LOGIC_W)
	SETCC_NZ00_W $v0
DEFSIZE(SETCC_LOGIC_W)

DEFLABEL(SETCC_LOGIC_L)
	SETCC_NZ00_L $v0
DEFSIZE(SETCC_LOGIC_L)

/*************************************************************************/
/*************************** Condition testing ***************************/
/*************************************************************************/

/**
 * TEST_*:  Check whether a condition is true (based on the current
 * condition codes) and set $v1 based on the result (nonzero = true).
 */

DEFLABEL(TEST_T)
	li $v1, 1
DEFSIZE(TEST_T)

DEFLABEL(TEST_F)
	li $v1, 0
DEFSIZE(TEST_F)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_HI)
	ext $v1, $s5, SR_Z_SHIFT, 1
	ext $a0, $s5, SR_C_SHIFT, 1
	or $v1, $v1, $a0
	xori $v1, $v1, 1
DEFSIZE(TEST_HI)

DEFLABEL(TEST_LS)
	ext $v1, $s5, SR_Z_SHIFT, 1
	ext $a0, $s5, SR_C_SHIFT, 1
	or $v1, $v1, $a0
DEFSIZE(TEST_LS)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_CC)
	ext $v1, $s5, SR_C_SHIFT, 1
	xori $v1, $v1, 1
DEFSIZE(TEST_CC)

DEFLABEL(TEST_CS)
	ext $v1, $s5, SR_C_SHIFT, 1
DEFSIZE(TEST_CS)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_NE)
	ext $v1, $s5, SR_Z_SHIFT, 1
	xori $v1, $v1, 1
DEFSIZE(TEST_NE)

DEFLABEL(TEST_EQ)
	ext $v1, $s5, SR_Z_SHIFT, 1
DEFSIZE(TEST_EQ)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_VC)
	ext $v1, $s5, SR_V_SHIFT, 1
	xori $v1, $v1, 1
DEFSIZE(TEST_VC)

DEFLABEL(TEST_VS)
	ext $v1, $s5, SR_V_SHIFT, 1
DEFSIZE(TEST_VS)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_PL)
	ext $v1, $s5, SR_N_SHIFT, 1
	xori $v1, $v1, 1
DEFSIZE(TEST_PL)

DEFLABEL(TEST_MI)
	ext $v1, $s5, SR_N_SHIFT, 1
DEFSIZE(TEST_MI)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_GE)
	ext $v1, $s5, SR_N_SHIFT, 1
	ext $a0, $s5, SR_V_SHIFT, 1
	xor $v1, $v1, $a0
	xori $v1, $v1, 1
DEFSIZE(TEST_GE)

DEFLABEL(TEST_LT)
	ext $v1, $s5, SR_N_SHIFT, 1
	ext $a0, $s5, SR_V_SHIFT, 1
	xor $v1, $v1, $a0
DEFSIZE(TEST_LT)

/*-----------------------------------------------------------------------*/

DEFLABEL(TEST_GT)
	ext $v1, $s5, SR_N_SHIFT, 1
	ext $a0, $s5, SR_V_SHIFT, 1
	ext $a1, $s5, SR_Z_SHIFT, 1
	xor $v1, $v1, $a0
	or $v1, $v1, $a1
	xori $v1, $v1, 1
DEFSIZE(TEST_GT)

DEFLABEL(TEST_LE)
	ext $v1, $s5, SR_N_SHIFT, 1
	ext $a0, $s5, SR_V_SHIFT, 1
	ext $a1, $s5, SR_Z_SHIFT, 1
	xor $v1, $v1, $a0
	or $v1, $v1, $a1
DEFSIZE(TEST_LE)

/*************************************************************************/
/**************************** ALU operations *****************************/
/*************************************************************************/

/**
 * MOVE_[BWL]:  Evaluate op1, setting the result value for the MOVE
 * instruction.
 */
DEFLABEL(MOVE_B)
	move $v0, $s3
DEFSIZE(MOVE_B)

DEFLABEL(MOVE_W)
	move $v0, $s3
DEFSIZE(MOVE_W)

DEFLABEL(MOVE_L)
	move $v0, $s3
DEFSIZE(MOVE_L)

/*************************************************************************/

/**
 * ADD_[BWL]:  Evaluate op2 + op1.
 */
DEFLABEL(ADD_B)
	addu $v0, $t7, $s3
DEFSIZE(ADD_B)

DEFLABEL(ADD_W)
	addu $v0, $t7, $s3
DEFSIZE(ADD_W)

DEFLABEL(ADD_L)
	addu $v0, $t7, $s3
DEFSIZE(ADD_L)

/*-----------------------------------------------------------------------*/

/**
 * ADDA_W:  Sign-extend op1 to 32 bits, then evaluate op2 + op1.
 */
DEFLABEL(ADDA_W)
	seh $v1, $s3
	addu $v0, $t7, $v1
DEFSIZE(ADDA_W)

/*-----------------------------------------------------------------------*/

/**
 * ADDX_[BWL]:  Evaluate op2 + op1 + X.
 */
DEFLABEL(ADDX_B)
	ext $v1, $s5, SR_X_SHIFT, 1
	addu $v0, $t7, $s3
	addu $v0, $v0, $v1
DEFSIZE(ADDX_B)

DEFLABEL(ADDX_W)
	ext $v1, $s5, SR_X_SHIFT, 1
	addu $v0, $t7, $s3
	addu $v0, $v0, $v1
DEFSIZE(ADDX_W)

DEFLABEL(ADDX_L)
	ext $v1, $s5, SR_X_SHIFT, 1
	addu $v0, $t7, $s3
	addu $v0, $v0, $v1
DEFSIZE(ADDX_L)

/*************************************************************************/

/**
 * SUB_[BWL]:  Evaluate op2 - op1.
 */
DEFLABEL(SUB_B)
	subu $v0, $t7, $s3
DEFSIZE(SUB_B)

DEFLABEL(SUB_W)
	subu $v0, $t7, $s3
DEFSIZE(SUB_W)

DEFLABEL(SUB_L)
	subu $v0, $t7, $s3
DEFSIZE(SUB_L)

/*-----------------------------------------------------------------------*/

/**
 * SUBA_W:  Sign-extend op1 to 32 bits, then evaluate op2 - op1.
 */
DEFLABEL(SUBA_W)
	seh $v1, $s3
	subu $v0, $t7, $v1
DEFSIZE(SUBA_W)

/*-----------------------------------------------------------------------*/

/**
 * SUBX_[BWL]:  Evaluate op2 - op1 - X.
 */
DEFLABEL(SUBX_B)
	ext $v1, $s5, SR_X_SHIFT, 1
	subu $v0, $t7, $s3
	subu $v0, $v0, $v1
DEFSIZE(SUBX_B)

DEFLABEL(SUBX_W)
	ext $v1, $s5, SR_X_SHIFT, 1
	subu $v0, $t7, $s3
	subu $v0, $v0, $v1
DEFSIZE(SUBX_W)

DEFLABEL(SUBX_L)
	ext $v1, $s5, SR_X_SHIFT, 1
	subu $v0, $t7, $s3
	subu $v0, $v0, $v1
DEFSIZE(SUBX_L)

/*************************************************************************/

/**
 * MUL[SU]_W:  Evaluate op2 * op1 in signed or unsigned context.
 */
DEFLABEL(MULS_W)
	seh $v0, $t7
	seh $v1, $s3
	mul $v0, $v1
	mflo $v0
DEFSIZE(MULS_W)

DEFLABEL(MULU_W)
	andi $v0, $t7, 0xFFFF
	andi $v1, $s3, 0xFFFF
	multu $v0, $v1
	mflo $v0
DEFSIZE(MULU_W)

/*************************************************************************/

/**
 * DIV[SU]_W:  Evaluate op2 / op1 in signed or unsigned context, setting
 * the condition codes appropriately.  The quotient is stored in the low
 * 16 bits, the remainder in the high 16 bits of the result value.  On
 * overflow, op2 is copied to the result.
 */
DEFLABEL(DIVS_W)
	seh $v1, $s3
	/* MIPS doesn't raise an exception on divide-by-zero, so let the
	 * divider unit do its thing while we check for a zero divisor */
	div $t7, $v1
	bnez $v1, 0f
	// The C flag is always cleared, so do it here in the delay slot
	ins $s5, $zero, SR_C_SHIFT, 1
	li $a0, EX_DIVIDE_BY_ZERO
	sw $a0, Q68State_exception($s0)
	TERMINATE
0:	mflo $v0
	mfhi $a3
	li $a0, 0x8000  // Overflow check
	addu $a0, $v0, $a0
	srl $a0, $a0, 16
	beqz $a0, 1f
	sll $a3, $a3, 16
	li $a0, 1
	ins $s5, $a0, SR_V_SHIFT, 1
	j 2f
	move $v0, $t7
1:	andi $v0, $v0, 0xFFFF // Need to clear upper bits in case it's negative
	SETCC_NZ_W $v0
	ins $s5, $zero, SR_V_SHIFT, 1
	or $v0, $v0, $a3
2:
DEFSIZE(DIVS_W)

DEFLABEL(DIVU_W)
	andi $v1, $s3, 0xFFFF
	divu $t7, $v1
	bnez $v1, 0f
	ins $s5, $zero, SR_C_SHIFT, 1
	li $a0, EX_DIVIDE_BY_ZERO
	sw $a0, Q68State_exception($s0)
	TERMINATE
0:	mflo $v0
	mfhi $a3
	srl $a0, $v0, 16  // Overflow check (easier for unsigned quotients)
	beqz $a0, 1f
	sll $a3, $a3, 16
	li $a0, 1
	ins $s5, $a0, SR_V_SHIFT, 1
	j 2f
	move $v0, $t7
1:	SETCC_NZ_W $v0
	ins $s5, $zero, SR_V_SHIFT, 1
	or $v0, $v0, $a3
2:
DEFSIZE(DIVU_W)

/*************************************************************************/

/**
 * AND_[BWL]:  Evaluate op2 & op1.
 */
DEFLABEL(AND_B)
	and $v0, $t7, $s3
DEFSIZE(AND_B)

DEFLABEL(AND_W)
	and $v0, $t7, $s3
DEFSIZE(AND_W)

DEFLABEL(AND_L)
	and $v0, $t7, $s3
DEFSIZE(AND_L)

/*************************************************************************/

/**
 * OR_[BWL]:  Evaluate op2 | op1.
 */
DEFLABEL(OR_B)
	or $v0, $t7, $s3
DEFSIZE(OR_B)

DEFLABEL(OR_W)
	or $v0, $t7, $s3
DEFSIZE(OR_W)

DEFLABEL(OR_L)
	or $v0, $t7, $s3
DEFSIZE(OR_L)

/*************************************************************************/

/**
 * EOR_[BWL]:  Evaluate op2 ^ op1.
 */
DEFLABEL(EOR_B)
	xor $v0, $t7, $s3
DEFSIZE(EOR_B)

DEFLABEL(EOR_W)
	xor $v0, $t7, $s3
DEFSIZE(EOR_W)

DEFLABEL(EOR_L)
	xor $v0, $t7, $s3
DEFSIZE(EOR_L)

/*************************************************************************/

/**
 * EXT_[WL]:  Sign-extend op1 from 8 to 16 or from 16 to 32 bits.
 */
DEFLABEL(EXT_W)
	seb $v0, $s3
DEFSIZE(EXT_W)

DEFLABEL(EXT_L)
	seh $v0, $s3
DEFSIZE(EXT_L)

/*************************************************************************/

/**
 * SWAP:  Swap the upper and lower 16-bit halves of op1, placing the result
 * in the result register.
 */
DEFLABEL(SWAP)
	srl $v0, $s3, 16
	ins $v0, $s3, 16, 16
DEFSIZE(SWAP)

/*************************************************************************/
/**************************** BCD operations *****************************/
/*************************************************************************/

/**
 * ABCD:  Evaluate op2 + op1 + X, treating the operands as binary-coded
 * decimal values.
 */
DEFLABEL(ABCD)
	ext $t2, $s5, SR_X_SHIFT, 1
	andi $t0, $t7, 0xF
	andi $t1, $s3, 0xF
	addu $t3, $t0, $t1
	addu $t3, $t3, $t2
	sltiu $v1, $t3, 10
	beqzl $v1, 0f
	addiu $t3, $t3, 6  // Skipped if no carry from the units place
0:	andi $t0, $t7, 0xF0
	andi $t1, $s3, 0xF0
	addu $t2, $t0, $t1
	addu $v0, $t2, $t3
	sltiu $v1, $v0, 10<<4
	bnezl $v1, 1f
	move $a3, $zero  // Executed if no carry from the tens place
	addiu $v0, $v0, -(10<<4)
	li $a3, 1
1:	ins $s5, $a3, SR_C_SHIFT, 1
	ins $s5, $a3, SR_X_SHIFT, 1
	andi $v1, $v0, 0xFF
	snez $v1, $v1
	sll $v1, $v1, SR_Z_SHIFT
	not $v1, $v1
	and $s5, $s5, $v1
DEFSIZE(ABCD)

/*************************************************************************/

/**
 * SBCD:  Evaluate op2 - op1 - X, treating the operands as binary-coded
 * decimal values.
 */
DEFLABEL(SBCD)
	ext $t2, $s5, SR_X_SHIFT, 1
	andi $t0, $t7, 0xF
	andi $t1, $s3, 0xF
	subu $t3, $t0, $t1
	subu $t3, $t3, $t2
	sltz $v1, $t3
	bnezl $v1, 0f
	move $t2, $zero  // Executed if no borrow from the units place
	addiu $t3, $t3, 10
	li $t2, 1<<4
0:	andi $t0, $t7, 0xF0
	andi $t1, $s3, 0xF0
	subu $t4, $t0, $t1
	subu $t4, $t4, $t2
	sltz $v1, $t4
	bnezl $v1, 1f
	move $a3, $zero  // Executed if no carry from the tens place
	addiu $v0, $v0, 10<<4
	li $a3, 1
1:	addu $v0, $t3, $t4
	sltz $v1, $v0
	or $a3, $a3, $v1
	ins $s5, $a3, SR_C_SHIFT, 1
	ins $s5, $a3, SR_X_SHIFT, 1
	andi $v1, $v0, 0xFF
	snez $v1, $v1
	sll $v1, $v1, SR_Z_SHIFT
	not $v1, $v1
	and $s5, $s5, $v1
DEFSIZE(SBCD)

/*************************************************************************/
/*********************** Bit-twiddling operations ************************/
/*************************************************************************/

/**
 * BTST_[BL]:  Evaluate op2 & (1 << op1).  The value (1 << op1), where the
 * high bits of op1 have been masked to zero, is left in $t0 for use by a
 * subsequent BCHG/BCLR/BSET operation.
 */
DEFLABEL(BTST_B)
	andi $a0, $s3, 7
	li $t0, 1
	sllv $t0, $t0, $a0
	and $v1, $t7, $t0
	seqz $v1, $v1
	ins $s5, $v1, SR_Z_SHIFT, 1
DEFSIZE(BTST_B)

DEFLABEL(BTST_L)
	andi $a0, $s3, 31
	li $t0, 1
	sllv $t0, $t0, $a0
	and $v1, $t7, $t0
	seqz $v1, $v1
	ins $s5, $v1, SR_Z_SHIFT, 1
DEFSIZE(BTST_L)

/*************************************************************************/

/**
 * BCHG:  Evaluate op2 ^ (1 << op1), where (1 << op1) has already been
 * stored in $t0.
 */
DEFLABEL(BCHG)
	xor $v0, $t7, $t0
DEFSIZE(BCHG)

/*-----------------------------------------------------------------------*/

/**
 * BCLR:  Evaluate op2 & ~(1 << op1), where (1 << op1) has already been
 * stored in $t0.
 */
DEFLABEL(BCLR)
	not $v1, $t0
	and $v0, $t7, $v1
DEFSIZE(BCLR)

/*-----------------------------------------------------------------------*/

/**
 * BSET:  Evaluate op2 | (1 << op1), where (1 << op1) has already been
 * stored in $t0.
 */
DEFLABEL(BSET)
	or $v0, $t7, $t0
DEFSIZE(BSET)

/*************************************************************************/
/************************ Shift/rotate operations ************************/
/*************************************************************************/

/**
 * ASL_[BWL]:  Evaluate (signed) op2 << op1.
 */
.macro DEF_ASL nbits
	andi $s3, $s3, 0x3F
	sll $v1, $s3, 1  // Add 2 clock cycles per shift
	add $s2, $s2, $v1
	ins $s5, $zero, SR_C_SHIFT, 2  // Clear V and C
	beqz $s3, 1f
	move $v0, $t7
	// Have to shift bit by bit to detect overflow
0:	ext $a3, $v0, \nbits-1, 1
	ext $v1, $v0, \nbits-2, 1
	sll $v0, $v0, 1
	addiu $s3, $s3, -1
	xor $v1, $v1, $a3
	sll $v1, $v1, SR_V_SHIFT
	bnez $s3, 0b
	or $s5, $s5, $v1
	ins $s5, $a3, SR_C_SHIFT, 1
	ins $s5, $a3, SR_X_SHIFT, 1
1:
.endm

DEFLABEL(ASL_B)
	DEF_ASL 8
	SETCC_NZ_B $v0
DEFSIZE(ASL_B)

DEFLABEL(ASL_W)
	DEF_ASL 16
	SETCC_NZ_W $v0
DEFSIZE(ASL_W)

DEFLABEL(ASL_L)
	DEF_ASL 32
	SETCC_NZ_L $v0
DEFSIZE(ASL_L)

/*-----------------------------------------------------------------------*/

/**
 * ASR_[BWL]:  Evaluate (signed) op2 >> op1.
 */
.macro DEF_ASR nbits
	andi $s3, $s3, 0x3F
	sll $v1, $s3, 1
	add $s2, $s2, $v1
	ins $s5, $zero, SR_C_SHIFT, 2  // Clear V and C
	beqz $s3, 3f
	move $v0, $t7
	sltiu $v1, $s3, \nbits
	bnez $v1, 2f
	nop
1:	// count >= nbits
	sra $v0, $t7, \nbits-1
	andi $a3, $v0, 1
	ins $s5, $a3, SR_C_SHIFT, 1
	j 3f
	ins $s5, $a3, SR_X_SHIFT, 1
2:	// count != 0 && count < nbits
	addiu $v1, $s3, -1
	srav $v0, $t7, $v1
	andi $a3, $v0, 1
	ins $s5, $a3, SR_C_SHIFT, 1
	ins $s5, $a3, SR_X_SHIFT, 1
	sra $v0, $v0, 1
3:	// All cases
.endm

DEFLABEL(ASR_B)
	seb $t7
	DEF_ASR 8
	SETCC_NZ_B $v0
DEFSIZE(ASR_B)

DEFLABEL(ASR_W)
	seh $t7
	DEF_ASR 16
	SETCC_NZ_W $v0
DEFSIZE(ASR_W)

DEFLABEL(ASR_L)
	DEF_ASR 32
	SETCC_NZ_L $v0
DEFSIZE(ASR_L)

/*************************************************************************/

/**
 * LSL_[BWL]:  Evaluate (unsigned) op2 << op1.
 */
.macro DEF_LSL nbits
	andi $s3, $s3, 0x3F
	sll $v1, $s3, 1
	add $s2, $s2, $v1
	ins $s5, $zero, SR_C_SHIFT, 2  // Clear V and C
	beqz $s3, 3f
	move $v0, $t7
	li $a0, \nbits
	sltu $v1, $s3, $a0
	bnez $v1, 2f
	sltu $v1, $a0, $s3
	bnez $v1, 1f
	nop
0:	// count == nbits
	ins $s5, $t7, SR_C_SHIFT, 1
	ins $s5, $t7, SR_X_SHIFT, 1
	j 3f
	move $v0, $zero
1:	// count > nbits
	ins $s5, $zero, SR_X_SHIFT, 1
	j 3f
	move $v0, $zero
2:	// count != 0 && count < nbits
	addiu $v1, $s3, -1
	sllv $v0, $t7, $v1
	ext $a3, $v0, \nbits-1, 1
	ins $s5, $a3, SR_C_SHIFT, 1
	ins $s5, $a3, SR_X_SHIFT, 1
	sll $v0, $v0, 1
3:	// All cases
.endm

DEFLABEL(LSL_B)
	DEF_LSL 8
	SETCC_NZ_B $v0
DEFSIZE(LSL_B)

DEFLABEL(LSL_W)
	DEF_LSL 16
	SETCC_NZ_W $v0
DEFSIZE(LSL_W)

DEFLABEL(LSL_L)
	DEF_LSL 32
	SETCC_NZ_L $v0
DEFSIZE(LSL_L)

/*-----------------------------------------------------------------------*/

/**
 * LSR_[BWL]:  Evaluate (unsigned) op2 >> op1.
 */
.macro DEF_LSR nbits
	andi $s3, $s3, 0x3F
	sll $v1, $s3, 1
	add $s2, $s2, $v1
	ins $s5, $zero, SR_C_SHIFT, 2  // Clear V and C
	beqz $s3, 3f
	move $v0, $t7
	li $a0, \nbits
	sltu $v1, $s3, $a0
	bnez $v1, 2f
	sltu $v1, $a0, $s3
	bnez $v1, 1f
	nop
0:	// count == nbits
	ext $a3, $t7, \nbits-1, 1
	ins $s5, $a3, SR_C_SHIFT, 1
	ins $s5, $a3, SR_X_SHIFT, 1
	j 3f
	move $v0, $zero
1:	// count > nbits
	ins $s5, $zero, SR_X_SHIFT, 1
	j 3f
	move $v0, $zero
2:	// count != 0 && count < nbits
	addiu $v1, $s3, -1
	srlv $v0, $t7, $v1
	andi $a3, $v0, 1
	ins $s5, $a3, SR_C_SHIFT, 1
	ins $s5, $a3, SR_X_SHIFT, 1
	srl $v0, $v0, 1
3:	// All cases
.endm

DEFLABEL(LSR_B)
	andi $t7, $t7, 0xFF
	DEF_LSR 8
	SETCC_NZ_B $v0
DEFSIZE(LSR_B)

DEFLABEL(LSR_W)
	andi $t7, $t7, 0xFFFF
	DEF_LSR 16
	SETCC_NZ_W $v0
DEFSIZE(LSR_W)

DEFLABEL(LSR_L)
	DEF_LSR 32
	SETCC_NZ_L $v0
DEFSIZE(LSR_L)

/*************************************************************************/

/**
 * ROXL_[BWL]:  Evaluate op2 ROXL op1.
 */
.macro DEF_ROXL nbits
	andi $s3, $s3, 0x3F
	sll $v1, $s3, 1
	add $s2, $s2, $v1
	ext $a3, $s5, SR_X_SHIFT, 1
	ins $s5, $a3, SR_C_SHIFT, 2  // Clear V while setting C
	beqz $s3, 1f
	move $v0, $t7
0:	sll $v1, $v0, 1
	ext $a0, $v0, \nbits-1, 1
	or $v0, $v1, $a3
	addiu $s3, $s3, -1
	bnez $s3, 0b
	move $a3, $a0
	ins $s5, $a3, SR_C_SHIFT, 1
	ins $s5, $a3, SR_X_SHIFT, 1
1:
.endm

DEFLABEL(ROXL_B)
	DEF_ROXL 8
	SETCC_NZ_B $v0
DEFSIZE(ROXL_B)

DEFLABEL(ROXL_W)
	DEF_ROXL 16
	SETCC_NZ_W $v0
DEFSIZE(ROXL_W)

DEFLABEL(ROXL_L)
	DEF_ROXL 32
	SETCC_NZ_L $v0
DEFSIZE(ROXL_L)

/*-----------------------------------------------------------------------*/

/**
 * ROXR_[BWL]:  Evaluate op2 ROXR op1.
 */
.macro DEF_ROXR nbits
	andi $s3, $s3, 0x3F
	sll $v1, $s3, 1
	add $s2, $s2, $v1
	ext $a3, $s5, SR_X_SHIFT, 1
	ins $s5, $a3, SR_C_SHIFT, 2  // Clear V while setting C
	beqz $s3, 1f
	move $v0, $t7
0:	srl $v1, $v0, 1
	ins $v1, $a3, \nbits-1, 1
	andi $a3, $v0, 1
	addiu $s3, $s3, -1
	bnez $s3, 0b
	move $v0, $v1
	ins $s5, $a3, SR_C_SHIFT, 1
	ins $s5, $a3, SR_X_SHIFT, 1
1:
.endm

DEFLABEL(ROXR_B)
	DEF_ROXR 8
	SETCC_NZ_B $v0
DEFSIZE(ROXR_B)

DEFLABEL(ROXR_W)
	DEF_ROXR 16
	SETCC_NZ_W $v0
DEFSIZE(ROXR_W)

DEFLABEL(ROXR_L)
	DEF_ROXR 32
	SETCC_NZ_L $v0
DEFSIZE(ROXR_L)

/*************************************************************************/

/**
 * ROL_[BWL]:  Evaluate op2 ROL op1.
 */
.macro DEF_ROL nbits
	andi $s3, $s3, 0x3F
	sll $v1, $s3, 1
	add $s2, $s2, $v1
	ins $s5, $zero, SR_C_SHIFT, 2  // Clear V and C
	beqz $s3, 3f
	move $v0, $t7
	andi $s3, $s3, \nbits-1
	bnez $s3, 2f
1:	// count != 0 && count % nbits == 0
	andi $a3, $t7, 1  // Branch delay slot from above (this is safe)
	j 3f
	ins $s5, $a3, SR_C_SHIFT, 1
2:	// count % nbits != 0
	li $v1, \nbits
	sub $v1, $v1, $s3
	sllv $a0, $t7, $s3
	srlv $t0, $t7, $v1
	or $v0, $a0, $t0
	andi $a3, $t7, 1
	ins $s5, $a3, SR_C_SHIFT, 1
3:	// All cases
.endm

DEFLABEL(ROL_B)
	andi $t7, $t7, 0xFF
	DEF_ROL 8
	SETCC_NZ_B $v0
DEFSIZE(ROL_B)

DEFLABEL(ROL_W)
	andi $t7, $t7, 0xFFFF
	DEF_ROL 16
	SETCC_NZ_W $v0
DEFSIZE(ROL_W)

DEFLABEL(ROL_L)
	DEF_ROL 32
	SETCC_NZ_L $v0
DEFSIZE(ROL_L)

/*-----------------------------------------------------------------------*/

/**
 * ROR_[BWL]:  Evaluate op2 ROR op1.
 */
.macro DEF_ROR nbits
	andi $s3, $s3, 0x3F
	sll $v1, $s3, 1
	add $s2, $s2, $v1
	ins $s5, $zero, SR_C_SHIFT, 2  // Clear V and C
	beqz $s3, 3f
	move $v0, $t7
	andi $s3, $s3, \nbits-1
	bnez $s3, 2f
1:	// count != 0 && count % nbits == 0
	ext $a3, $t7, \nbits-1, 1  // Branch delay slot from above (safe)
	j 3f
	ins $s5, $a3, SR_C_SHIFT, 1
2:	// count % nbits != 0
	li $v1, \nbits
	sub $v1, $v1, $s3
	srlv $a0, $t7, $s3
	sllv $t0, $t7, $v1
	or $v0, $a0, $t0
	ext $a3, $t7, \nbits-1, 1
	ins $s5, $a3, SR_C_SHIFT, 1
3:	// All cases
.endm

DEFLABEL(ROR_B)
	andi $t7, $t7, 0xFF
	DEF_ROR 8
	SETCC_NZ_B $v0
DEFSIZE(ROR_B)

DEFLABEL(ROR_W)
	andi $t7, $t7, 0xFFFF
	DEF_ROR 16
	SETCC_NZ_W $v0
DEFSIZE(ROR_W)

DEFLABEL(ROR_L)
	DEF_ROR 32
	SETCC_NZ_L $v0
DEFSIZE(ROR_L)

/*************************************************************************/
/******************* Conditional and branch operations *******************/
/*************************************************************************/

/**
 * Scc:  Set the lower 8 bits of the result value to 0xFF if the condition
 * is true, 0x00 if false.
 */
DEFLABEL(Scc)
	negu $v0, $v1
DEFSIZE(Scc)

/*-----------------------------------------------------------------------*/

/**
 * ADD_CYCLES_Scc_Dn:  Add the appropriate number of clock cycles for an
 * Scc Dn instruction to the cycle count.
 */
DEFLABEL(ADD_CYCLES_Scc_Dn)
	andi $v1, $v0, 2
	addiu $v1, $v1, 4
	addu $s2, $s2, $v1
DEFSIZE(ADD_CYCLES_Scc_Dn)

/*************************************************************************/

/**
 * DBcc:  Jump to the specified target address unless the condition is true
 * or the lower 16 bits of the given data register, after being decremented,
 * are equal to -1.
 *
 * [Parameters]
 *          reg4: Register number * 4 (0-28: D0-D7)
 *     target_hi: High 16 bits of target address
 *     target_lo: Low 16 bits of target address
 */
DEFLABEL(DBcc)
	lhu $v0, 1($s0)
6:	bnezl $v1, 0f
	addiu $s2, $s2, 12
	addiu $v1, $v0, -1
	sh $v1, 1($s0)
7:	beqzl $v0, 0f
	addiu $s2, $s2, 14
	addiu $s2, $s2, 10
	lui $v0, 0x1234
8:	ori $s4, $v0, 0x5678
9:	TERMINATE
0:
DEFSIZE(DBcc)
DEFPARAM(DBcc, reg4, 6b, -4)
DEFPARAM(DBcc, reg4_b, 7b, -4)  // same as reg4
DEFPARAM(DBcc, target_hi, 8b, -4)
DEFPARAM(DBcc, target_lo, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * DBcc_native:  Implement DBcc using a jump within the native code.
 *
 * [Parameters]
 *              reg4: Register number * 4 (0-28: D0-D7)
 *         target_hi: High 16 bits of target 68000 address
 *         target_lo: Low 16 bits of target 68000 address
 *     native_disp_4_4: (Native displacement from end of this fragment + 4) / 4
 */
DEFLABEL(DBcc_native)
	lhu $v0, 1($s0)
6:	bnezl $v1, 0f
	addiu $s2, $s2, 12
	addiu $v1, $v0, -1
	sh $v1, 1($s0)
7:	beqzl $v0, 0f
	addiu $s2, $s2, 14
	addiu $s2, $s2, 10
	lui $v0, 0x1234
8:	ori $s4, $v0, 0x5678
9:	b .+0x1234
5:	nop
0:
DEFSIZE(DBcc_native)
DEFPARAM(DBcc_native, reg4, 6b, -4)
DEFPARAM(DBcc_native, reg4_b, 7b, -4)  // same as reg4
DEFPARAM(DBcc_native, target_hi, 8b, -4)
DEFPARAM(DBcc_native, target_lo, 9b, -4)
DEFPARAM(DBcc_native, native_disp_4_4, 5b, -4)

/*************************************************************************/

/**
 * Bcc_common:  Jump to the specified target address if the condition is
 * true.  Used for both interpreted jumps (by branching to TERMINATE) and
 * native jumps.
 *
 * [Parameters]
 *     target_hi: High 16 bits of target 68000 address
 *     target_lo: Low 16 bits of target 68000 address
 *        disp_4: Native displacement / 4 (either JIT_PSPOFS_TERMINATE or
 *                   target address minus address of "nop" following branch)
 */
DEFLABEL(Bcc_common)
	beqz $v1, 0f
	lui $v0, 0x1234  // In the delay slot, but not a problem
8:	ori $s4, $v0, 0x5678
9:	addiu $s2, $s2, 10
	b .+0x1234
5:	nop
0:
DEFSIZE(Bcc_common)
DEFPARAM(Bcc_common, target_hi, 8b, -4)
DEFPARAM(Bcc_common, target_lo, 9b, -4)
DEFPARAM(Bcc_common, disp_4, 5b, -4)

/*-----------------------------------------------------------------------*/

/**
 * BSR:  Push the address of the next instruction onto the stack, then jump
 * to the specified target address.
 *
 * [Parameters]
 *     return_addr_hi: High 16 bits of return address to push onto the stack
 *     return_addr_lo: High 16 bits of return address to push onto the stack
 *          target_hi: High 16 bits of target address
 *          target_lo: Low 16 bits of target address
 */
DEFLABEL(BSR)
	lui $v0, 0x1234
6:	ori $v0, $v0, 0x5678
7:	PUSH32 $v0
	lui $v0, 0x1234
8:	ori $s4, $v0, 0x5678
9:	ori $s2, $s2, 0x8000  // Indicate that this is a BSR/JSR termination
	TERMINATE_CONTINUE
DEFSIZE(BSR)
DEFPARAM(BSR, return_addr_hi, 6b, -4)
DEFPARAM(BSR, return_addr_lo, 7b, -4)
DEFPARAM(BSR, target_hi, 8b, -4)
DEFPARAM(BSR, target_lo, 9b, -4)

/*************************************************************************/

/**
 * JMP:  Jump to the previously resolved effective address.
 */
DEFLABEL(JMP)
	move $s4, $s6
	TERMINATE
DEFSIZE(JMP)

/*-----------------------------------------------------------------------*/

/**
 * JSR:  Push the address of the next instruction onto the stack, then jump
 * to the previously resolved effective address.
 *
 * [Parameters]
 *     return_addr_hi: High 16 bits of return address to push onto the stack
 *     return_addr_lo: High 16 bits of return address to push onto the stack
 */
DEFLABEL(JSR)
	lui $v0, 0x1234
8:	ori $v0, $v0, 0x5678
9:	PUSH32 $v0
	move $s4, $s6
	ori $s2, $s2, 0x8000  // Indicate that this is a BSR/JSR termination
	TERMINATE_CONTINUE
DEFSIZE(JSR)
DEFPARAM(JSR, return_addr_hi, 8b, -4)
DEFPARAM(JSR, return_addr_lo, 9b, -4)

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
	lw $v0, 1($s0)
9:	addiu $s6, $s6, -2
	LOAD_DELAY_NOP
	WRITE16
DEFSIZE(STORE_DEC_W)
DEFPARAM(STORE_DEC_W, reg4, 9b, -4)

DEFLABEL(STORE_DEC_L)
	lw $v0, 1($s0)
9:	addiu $s6, $s6, -4
	LOAD_DELAY_NOP
	WRITE32
DEFSIZE(STORE_DEC_L)
DEFPARAM(STORE_DEC_L, reg4, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * STORE_INC_[WL]:  Store the specified register to the location indicated
 * by state->ea_addr, then increment state->ea_addr.
 *
 * [Parameters]
 *     reg4: Register number * 4 (0-28: D0-D7, 32-60: A0-A7)
 */
DEFLABEL(STORE_INC_W)
	lw $v0, 1($s0)
9:	LOAD_DELAY_NOP
	LOAD_DELAY_NOP
	WRITE16
	addiu $s6, $s6, 2
DEFSIZE(STORE_INC_W)
DEFPARAM(STORE_INC_W, reg4, 9b, -4)

DEFLABEL(STORE_INC_L)
	lw $v0, 1($s0)
9:	LOAD_DELAY_NOP
	LOAD_DELAY_NOP
	WRITE32
	addiu $s6, $s6, 4
DEFSIZE(STORE_INC_L)
DEFPARAM(STORE_INC_L, reg4, 9b, -4)

/*************************************************************************/

/**
 * LOAD_INC_[WL]:  Load the specified register from the location indicated
 * by state->ea_addr, then increment state->ea_addr.
 *
 * [Parameters]
 *     reg4: Register number * 4 (0-28: D0-D7, 32-60: A0-A7)
 */
DEFLABEL(LOAD_INC_W)
	READ16 $v0
	sh $v0, 1($s0)
9:	addiu $s6, $s6, 2
DEFSIZE(LOAD_INC_W)
DEFPARAM(LOAD_INC_W, reg4, 9b, -4)

DEFLABEL(LOAD_INC_L)
	READ32 $v0
	sw $v0, 1($s0)
9:	addiu $s6, $s6, 4
DEFSIZE(LOAD_INC_L)
DEFPARAM(LOAD_INC_L, reg4, 9b, -4)

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
	READ16 $v0
	seh $v0, $v0
	sh $v0, 1($s0)
9:	addiu $s6, $s6, 2
DEFSIZE(LOADA_INC_W)
DEFPARAM(LOADA_INC_W, reg4, 9b, -4)

/*************************************************************************/

/**
 * MOVEM_WRITEBACK:  Store the address in state->ea_addr to the specified
 * address register.
 *
 * [Parameters]
 *     reg4: Register number * 4 (32-60: A0-A7)
 */
DEFLABEL(MOVEM_WRITEBACK)
	sw $s6, 1($s0)
9:
DEFSIZE(MOVEM_WRITEBACK)
DEFPARAM(MOVEM_WRITEBACK, reg4, 9b, -4)

/*************************************************************************/
/*********************** Miscellaneous operations ************************/
/*************************************************************************/

/**
 * CHK_W:  Raise a CHK exception if op1 < 0 or op1 > op2, treating both
 * operands as signed 16-bit values.
 */
DEFLABEL(CHK_W)
	seh $s3, $s3
	seh $t7, $t7
	bltzl $s3, 0f
	ori $s5, $s5, SR_N
	slt $v1, $t7, $s3
	beqz $v1, 1f
	nop
	ins $s5, $zero, SR_N_SHIFT, 1
0:	li $a0, EX_CHK
	sw $a0, Q68State_exception($s0)
	TERMINATE
1:
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
	sw $s6, 1($s0)
9:
DEFSIZE(LEA)
DEFPARAM(LEA, reg4, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * PEA:  Push the previously resolved effective address onto the stack.
 */
DEFLABEL(PEA)
	PUSH32 $s6
DEFSIZE(PEA)

/*************************************************************************/

/**
 * TAS:  Test the 8-bit value of op1, setting the condition codes
 * appropriately, then calculate op1 | 0x80.
 */
DEFLABEL(TAS)
	SETCC_NZ00_B $s3
	ori $v0, $s3, 0x80
DEFSIZE(TAS)

/*************************************************************************/

/**
 * MOVE_FROM_USP:  Copy the user stack pointer to the specified register.
 *
 * [Parameters]
 *     reg4: Register number * 4 (32-60: A0-A7)
 */
DEFLABEL(MOVE_FROM_USP)
	lw $v0, USP
	LOAD_DELAY_NOP
	LOAD_DELAY_NOP
	sw $v0, 1($s0)
9:
DEFSIZE(MOVE_FROM_USP)
DEFPARAM(MOVE_FROM_USP, reg4, 9b, -4)

/*-----------------------------------------------------------------------*/

/**
 * MOVE_TO_USP:  Copy the specified register to the user stack pointer.
 *
 * [Parameters]
 *     reg4: Register number * 4 (32-60: A0-A7)
 */
DEFLABEL(MOVE_TO_USP)
	lw $v0, 1($s0)
9:	LOAD_DELAY_NOP
	LOAD_DELAY_NOP
	sw $v0, USP
DEFSIZE(MOVE_TO_USP)
DEFPARAM(MOVE_TO_USP, reg4, 9b, -4)

/*************************************************************************/

/**
 * STOP:  Halt the processor.
 *
 * [Parameters]
 *     newSR: Value to load into SR
 */
DEFLABEL(STOP)
	li $v0, 1
	sw $v0, Q68State_halted($s0)
	jal UPDATE_SR
	ori $v0, $zero, 0x1234
9:
DEFSIZE(STOP)
DEFPARAM(STOP, newSR, 9b, -4)

/*************************************************************************/

/**
 * TRAPV:  Raise a TRAPV exception if the overflow flag is set.
 */
DEFLABEL(TRAPV)
	ext $v1, $s5, SR_V_SHIFT, 1
	beqz $v1, 0f
	li $a0, EX_TRAPV  // In the delay slot, but that's okay
	sw $a0, Q68State_exception($s0)
	TERMINATE
0:
DEFSIZE(TRAPV)

/*************************************************************************/

/**
 * RTS:  Pop the PC from the stack.
 */
DEFLABEL(RTS)
	POP32 $s4
	ori $s2, $s2, 0xC000  // Indicate that this is an RTS/RTR termination
	TERMINATE
DEFSIZE(RTS)

/*-----------------------------------------------------------------------*/

/**
 * RTR:  Pop the condition codes and PC from the stack.
 */
DEFLABEL(RTR)
	POP16 $v0
	ins $s5, $v0, 0, 8
	POP32 $s4
	ori $s2, $s2, 0xC000  // Indicate that this is an RTS/RTR termination
	TERMINATE
DEFSIZE(RTR)

/*-----------------------------------------------------------------------*/

/**
 * RTE:  Pop the status register and PC from the stack.
 */
DEFLABEL(RTE)
	POP16 $s3  // Borrow op1, since POP32 will destroy temporary registers
	POP32 $s4
	jal UPDATE_SR
	move $v0, $s3
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
	lw $s6, 1($s0)
7:	LOAD_DELAY_NOP
	LOAD_DELAY_NOP
	addiu $s6, $s6, 1
8:	READ8 $v0  // Byte 1
	addiu $s6, $s6, 2
	ins $s3, $v0, 8, 8
	READ8 $v0  // Byte 0
	ins $s3, $v0, 0, 8
	sh $s3, 1($s0)
9:
DEFSIZE(MOVEP_READ_W)
DEFPARAM(MOVEP_READ_W, areg4, 7b, -4)
DEFPARAM(MOVEP_READ_W, disp, 8b, -4)
DEFPARAM(MOVEP_READ_W, dreg4, 9b, -4)

DEFLABEL(MOVEP_READ_L)
	lw $s6, 1($s0)
7:	LOAD_DELAY_NOP
	LOAD_DELAY_NOP
	addiu $s6, $s6, 1
8:	READ8 $v0  // Byte 3
	addiu $s6, $s6, 2
	ins $s3, $v0, 24, 8
	READ8 $v0  // Byte 2
	addiu $s6, $s6, 2
	ins $s3, $v0, 16, 8
	READ8 $v0  // Byte 1
	addiu $s6, $s6, 2
	ins $s3, $v0, 8, 8
	READ8 $v0  // Byte 0
	ins $s3, $v0, 0, 8
	sh $s3, 1($s0)
9:
DEFSIZE(MOVEP_READ_L)
DEFPARAM(MOVEP_READ_L, areg4, 7b, -4)
DEFPARAM(MOVEP_READ_L, disp, 8b, -4)
DEFPARAM(MOVEP_READ_L, dreg4, 9b, -4)

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
	lw $s6, 1($s0)
7:	lw $s3, 1($s0)
9:	LOAD_DELAY_NOP
	addiu $s6, $s6, 1
8:	ext $v0, $s3, 8, 8
	WRITE8  // Byte 1
	addiu $s6, $s6, 2
	ext $v0, $s3, 0, 8
	WRITE8  // Byte 0
DEFSIZE(MOVEP_WRITE_W)
DEFPARAM(MOVEP_WRITE_W, areg4, 7b, -4)
DEFPARAM(MOVEP_WRITE_W, disp, 8b, -4)
DEFPARAM(MOVEP_WRITE_W, dreg4, 9b, -4)

DEFLABEL(MOVEP_WRITE_L)
	lw $s6, 1($s0)
7:	lw $s3, 1($s0)
9:	LOAD_DELAY_NOP
	addiu $s6, $s6, 1
8:	ext $v0, $s3, 24, 8
	WRITE8  // Byte 3
	addiu $s6, $s6, 2
	ext $v0, $s3, 16, 8
	WRITE8  // Byte 2
	addiu $s6, $s6, 2
	ext $v0, $s3, 8, 8
	WRITE8  // Byte 1
	addiu $s6, $s6, 2
	ext $v0, $s3, 0, 8
	WRITE8  // Byte 0
DEFSIZE(MOVEP_WRITE_L)
DEFPARAM(MOVEP_WRITE_L, areg4, 7b, -4)
DEFPARAM(MOVEP_WRITE_L, disp, 8b, -4)
DEFPARAM(MOVEP_WRITE_L, dreg4, 9b, -4)

/*************************************************************************/

/**
 * EXG:  Exchange the values of two registers.
 *
 * [Parameters]
 *     reg1_4: Register number * 4 of first register (0-60 = D0-A7)
 *     reg2_4: Register number * 4 of second register (0-60 = D0-A7)
 */
DEFLABEL(EXG)
	addiu $a0, $s0, 1
8:	lw $v0, 0($a0)
	addiu $a1, $s0, 1
9:	lw $v1, 0($a1)
	sw $v0, 0($a1)
	LOAD_DELAY_NOP
	sw $v1, 0($a0)
DEFSIZE(EXG)
DEFPARAM(EXG, reg1_4, 8b, -1)
DEFPARAM(EXG, reg2_4, 9b, -1)

/*************************************************************************/
/*************************************************************************/
