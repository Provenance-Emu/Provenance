# vim:filetype=mips

# some asm utils for the Sony Emotion Engine (MIPS R5900)

.set push
.set noreorder

.text
.align 4

# A1B5G5R5 abbb bbgg gggr rrrr
.global do_pal_convert # dest, src
.ent do_pal_convert
do_pal_convert:
	li $t0, 0x8000800080008000	#A
	li $t1, 0x000E000E000E000E	#R
	li $t2, 0x00E000E000E000E0	#G
	li $t3, 0x0E000E000E000E00	#B
	li $t4, 64	# 64 16-bit colours

	#Duplicate the lower dword into the upper dword of each mask (0-63 to 64-127).
	pcpyld $t0, $t0
	pcpyld $t1, $t1
	pcpyld $t2, $t2
	pcpyld $t3, $t3

	#	I couldn't do this with qword loads and stores in C (There's no 128-bit literal data type definition), but here's the 16-bit (1 colour per literation) equivalent in C for a reference.
	#	PalRow=in_palette[i];
	#	palette[i]=((PalRow&0x000E)<< 1)|((PalRow&0x00E0)<<2)|((PalRow&0x0E00)<<3) | 0x8000;
pal_convert_loop:
	ld $t5, 8($a1)
	ld $t6, 0($a1)
	pcpyld $t5, $t5, $t6
#	lq $t5, 0($a1)	#This won't work because the CRAM palette may not be aligned to a 128-bit address (And unless the source code of Picodrive is modified for that purpose, use two dword loads instead). :(

	#Blue
	pand $t6, $t5, $t3
	psllh $t6, $t6, 3

	#Green
	pand $t7, $t5, $t2
	psllh $t7, $t7, 2

	#Red
	pand $t5, $t5, $t1
	psllh $t5, $t5, 1

	por $t5, $t5, $t0	#Logical OR in the alpha channel
	por $t5, $t5, $t6	#Logical OR in the blue channel
	por $t5, $t5, $t7	#Logical OR in the green channel

	sq $t5, ($a0)

	addiu $a1, $a1, 16
	addiu $t4, $t4, -8	#8 16-bit colours were processed.
	bgez $t4, pal_convert_loop
	addiu $a0, $a0, 16

    jr      $ra
    nop
.end do_pal_convert

.global do_pal_convert_with_shadows # dest, src
.ent do_pal_convert_with_shadows
do_pal_convert_with_shadows:
	li $t0, 0x8000800080008000	#A mask
	li $t1, 0x000E000E000E000E	#R mask
	li $t2, 0x00E000E000E000E0	#G mask
	li $t3, 0x0E000E000E000E00	#B mask
	li $a2, 0x39CE39CE39CE39CE	#Shadow mask
	li $a3, 0x4210421042104210	#Highlight mask
	li $t4, 64	# 64 16-bit colours
	#	$t5 will contain the raw converted colour, without alpha. This will be also used for conversion into the shadow alternate colours.

	# Duplicate the lower dword into the upper dword of each mask (0-63 to 64-127).
	pcpyld $t0, $t0
	pcpyld $t1, $t1
	pcpyld $t2, $t2
	pcpyld $t3, $t3
	pcpyld $a2, $a2
	pcpyld $a3, $a3

	#	I couldn't do this with qword loads and stores in C (There's no 128-bit literal data type definition), but here's the 16-bit (1 colour per literation) equivalent in C for a reference.
	#	PalRow=in_palette[i];
	#	palette[i]=((PalRow&0x000E)<< 1)|((PalRow&0x00E0)<<2)|((PalRow&0x0E00)<<3) | 0x8000;
pal_convert_loop_sh:
	ld $t5, 8($a1)
	ld $t6, 0($a1)
	pcpyld $t5, $t5, $t6
#	lq $t5, 0($a1)	#This won't work because the CRAM palette may not be aligned to a 128-bit address (And unless the source code of Picodrive is modified for that purpose, use two dword loads instead). :(

	#Blue
	pand $t6, $t5, $t3
	psllh $t6, $t6, 3

	#Green
	pand $t7, $t5, $t2
	psllh $t7, $t7, 2

	#Red
	pand $t5, $t5, $t1
	psllh $t5, $t5, 1

	por $t5, $t5, $t6	#Logical OR in the blue channel
	por $t5, $t5, $t7	#Logical OR in the green channel
	por $t6, $t5, $t0	#Logical OR in the alpha channel
	sq $t6, ($a0)		#Normal

	#Highlights
	por $t6, $t6, $a3
	sq $t6, 0x80($a0)

	#Shadows
	psrlh $t5, $t5, 1
	pand $t5, $t5, $a2
	por $t5, $t5, $t0	#Logical OR in the alpha channel
	sq $t5, 0x40($a0)
	sq $t5, 0xC0($a0)

	addiu $a1, $a1, 16
	addiu $t4, $t4, -8	#8 16-bit colours were processed.
	bgez $t4, pal_convert_loop_sh
	addiu $a0, $a0, 16

    jr      $ra
    nop
.end do_pal_convert_with_shadows

.set pop
