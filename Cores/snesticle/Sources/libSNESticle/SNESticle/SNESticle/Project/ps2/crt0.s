#
#  _____     ___ ____
#   ____|   |    ____|      PS2 OpenSource Project
#  |     ___|   |____
#  ------------------------------------------------------------------------
#  crt0.s                   Standard startup file.
#

.set noat
.set noreorder

.global _start
.global	_exit

	.extern	_heap_size
	.extern	_stack
	.extern _stack_size

	.text

	nop
	nop

	.ent _start
_start:

# Clear bss elf segment (static uninitalised data)
zerobss:
	la	$2, _fbss
	la	$3, _end
loop:
	nop
	nop
	nop
	sq	$0,($2)
	sltu	$1,$2,$3
	bne	$1,$0,loop
	addiu	$2,$2,16

# Some program loaders (such as Pukklink) execute programs as a thread, but
# support passing argc and argv values via a0.  This also indicates that when
# the program terminates, control should be returned to the program loader
# instead of the PS2 browser.
	la	$2, _args_ptr
    	sw	$4,($2)

# Setup a thread to use
	la	$4, _gp
	la	$5, _stack
	la	$6, _stack_size
	la	$7, _args
	la	$8, _root
	move	$28,$4
	addiu	$3,$0,60
	syscall			# RFU060(gp, stack, stack_size, args, root_func)
	move	$29, $2

# Heap
	addiu	$3,$0,61
	la	$4, _end
	la	$5, _heap_size
	syscall			# RFU061(heap_start, heap_size)
	nop

# Flush the data cache (no need to preserve regs for this call)
	li	$3, 0x64
	move	$4,$0
	syscall			# FlushCache(0) - Writeback data cache

# Jump main, now that environment and args are setup
	ei

# Check for arguments pased via ExecPS2 or LoadExecPS2
	la	$2, _args
	lw	$3, ($2)
	bnez	$3, 1f
	nop

# Otherwise check for arguments passed by a loader via a0 (_arg_ptr)
	la	$2, _args_ptr
	lw	$3, ($2)
	beqzl	$3, 2f
	addu	$4, $0, 0

	addiu	$2, $3, 4
1:
	lw	$4, ($2)
	addiu	$5, $2, 4
2:
	jal	main
	nop
	.end	_start

	.ent	_exit
_exit:
# If we received our program arguments in a0, then we were executed by a
# loader, and we don't want to return to the browser.
	la	$4, _args_ptr
	lw	$5, ($4)
	beqz	$5, 1f
	move	$4, $2		# main()'s return code

	lw	$6, ($5)
	sw	$0, ($6)
	addiu	$3, $0, 36
	syscall			# ExitDeleteThread(void)

# Return to the browser via Exit()
1:
	addiu	$3, $0, 4
	syscall			# Exit(void)
	.end	_exit

# Call ExitThread()
	.ent	_root
_root:
	addiu	$3, $0, 35
	syscall
	.end	_root

	.bss
	.align	6
_args:
	.space	256+16*4+4
_args_ptr:
	.space	4
