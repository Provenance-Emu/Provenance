.text
.set noreorder

	.globl	wmemcpy
	.ent	wmemcpy
wmemcpy:
	sra     $6,$6,0x2
	addiu   $6,$6,-1
	li      $2,-1
	beq     $6,$2,wmemcopy_end
	move    $3,$2
wmemcopy_loop:
	lw      $2,0($5)
	addiu   $5,$5,4
	addiu   $6,$6,-1
	sw      $2,0($4)
	bne     $6,$3,wmemcopy_loop
	addiu   $4,$4,4
wmemcopy_end:
	jr      $31
	nop
	.end	wmemcpy

