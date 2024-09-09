# 1 "../../../Gep/Source/ps2/exceptions.S"
# 1 "<built-in>"
# 1 "<command line>"
# 1 "../../../Gep/Source/ps2/exceptions.S"







# ASM exception handlers

# 1 "../../../Gep/Source/ps2/r5900_regs.h" 1
# 11 "../../../Gep/Source/ps2/exceptions.S" 2

.set noat
.set noreorder


.text
.p2align 4

        .global _savedRegs

        .global pkoStepBP
        .ent pkoStepBP
pkoStepBP:
        # Should check for cause in cop0 $13 reg
        # If Bp, increase $14 (DO NOT PUT 'break' in a branch delay slot!!!)
        mfc0 $26, $14 # cop0 $14
        addiu $26, $26, 4 # Step over breakpoint
        mtc0 $26, $14
        sync.p
        eret
        .end pkoStepBP


        # Save all user regs
        # Save HI/LO, SR, $8, $13, $14, ErrorEPC,
        # ShiftAmount, cop0: $24, $25
        # Save float regs??
        # Set $14 to debugger
        # Set stack to 'exception stack'
        # eret
        .global pkoExceptionHandler
        .ent pkoExceptionHandler
pkoExceptionHandler:
        la $26, _savedRegs
        sq $0, 0x00($26)
        sq $1, 0x10($26)
        sq $2, 0x20($26)
        sq $3, 0x30($26)
        sq $4, 0x40($26)
        sq $5, 0x50($26)
        sq $6, 0x60($26)
        sq $7, 0x70($26)
        sq $8, 0x80($26)
        sq $9, 0x90($26)
        sq $10, 0xa0($26)
        sq $11, 0xb0($26)
        sq $12, 0xc0($26)
        sq $13, 0xd0($26)
        sq $14, 0xe0($26)
        sq $15, 0xf0($26)
        sq $24, 0x100($26)
        sq $25, 0x110($26)
        sq $16, 0x120($26)
        sq $17, 0x130($26)
        sq $18, 0x140($26)
        sq $19, 0x150($26)
        sq $20, 0x160($26)
        sq $21, 0x170($26)
        sq $22, 0x180($26)
        sq $23, 0x190($26)
# sq $26, 0x1a0($26) # $$26
        sq $0, 0x1a0($26) # $0 instead
        sq $27, 0x1b0($26) # $$27
        sq $28, 0x1c0($26)
        sq $29, 0x1d0($26) # $29
        sq $30, 0x1e0($26)
        sq $31, 0x1f0($26) # $$31

        pmfhi $8 # HI
        pmflo $9 # LO
        sq $8, 0x200($26)
        sq $9, 0x210($26)

        mfc0 $8, $8 # Cop0 state regs
        mfc0 $9, $12
        sw $8, 0x220($26)
        sw $9, 0x224($26)

        mfc0 $8, $13
        mfc0 $9, $14
        sw $8, 0x228($26)
        sw $9, 0x22c($26)

        # Kernel saves these two also..
        mfc0 $8, $24
        mfc0 $9, $25
        sw $8, 0x230($26)
        sw $9, 0x234($26)

        mfsa $8
        sw $8, 0x238($26)

        # Use our own stack..
        la $29, _exceptionStack+0x2000-16
        la $28, _gp # Use exception handlers _gp

        # Return from exception and start 'debugger'
        mfc0 $4, $13 # arg0
        mfc0 $5, $8
        mfc0 $6, $12
        mfc0 $7, $14
        addu $8, $0, $26 # arg4 = registers
        move $9, $29
        la $26, pkoDebug
        mtc0 $26, $14 # eret return address
        sync.p
        mfc0 $26, $12 # check this out..
        li $2, 0xfffffffe
        and $26, $2
        mtc0 $26, $12
        sync.p
        nop
        nop
        nop
        nop
        eret
        nop
        .end pkoExceptionHandler



        # Put EE in kernel mode
        # Restore all user regs etc
        # Restore PC? & Stack ptr
        # Restore interrupt sources
        # Jump to $14
        .ent pkoReturnFromDebug
        .global pkoReturnFromDebug
pkoReturnFromDebug:

        lui $9, 0x1
_disable:
        di
        sync
        mfc0 $8, $12
        and $8, $9
        beqz $8, _disable
        nop

        la $26, _savedRegs

        lq $8, 0x200($26)
        lq $9, 0x210($26)
        pmthi $8 # HI
        pmtlo $9 # LO

        lw $8, 0x220($26)
        lw $9, 0x224($26)
        mtc0 $8, $8
        mtc0 $9, $12

        lw $8, 0x228($26)
        lw $9, 0x22c($26)
        mtc0 $8, $13
        mtc0 $9, $14

        # Kernel saves these two also..
        lw $8, 0x230($26)
        lw $9, 0x234($26)
        mtc0 $8, $24
        mtc0 $9, $25

        # Shift Amount reg
        lw $8, 0x238($26)
        mtsa $8


 # ori $10, 0xff
# sw $10, 0($27)

        # lq $0, 0x00($26)
        lq $1, 0x10($26)
        lq $2, 0x20($26)
        lq $3, 0x30($26)
        lq $4, 0x40($26)
        lq $5, 0x50($26)
        lq $6, 0x60($26)
        lq $7, 0x70($26)
        lq $8, 0x80($26)
        lq $9, 0x90($26)
        lq $10, 0xa0($26)
        lq $11, 0xb0($26)
        lq $12, 0xc0($26)
        lq $13, 0xd0($26)
        lq $14, 0xe0($26)
        lq $15, 0xf0($26)
        lq $16, 0x100($26)
        lq $17, 0x110($26)
        lq $18, 0x120($26)
        lq $19, 0x130($26)
        lq $10, 0x140($26)
        lq $21, 0x150($26)
        lq $22, 0x160($26)
        lq $23, 0x170($26)
        lq $24, 0x180($26)
        lq $25, 0x190($26)
# lq $26, 0x1a0($26) # $$26
        lq $27, 0x1b0($26) # $$27
        lq $28, 0x1c0($26)
        lq $29, 0x1d0($26) # $$29
        lq $30, 0x1e0($26)
# lq $31, 0x1f0($26) # $$31

        lw $31, 0x22c($26)
        # Guess one should have some check here, and only advance PC if
        # we are going to step over a Breakpoint or something
        # (i.e. do stuff depending on $13)
        addiu $31, 4
        sync.p
        ei
        sync.p

        jr $31
        nop
        .end pkoReturnFromDebug
