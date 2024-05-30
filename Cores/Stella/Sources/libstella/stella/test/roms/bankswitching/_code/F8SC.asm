;;A bankswitching demo for the F8SC scheme.  2 4K banks of ROM + 128 bytes of RAM
;;By: Rick Skrbina 3/29/09
	
	processor 6502
	include "vcs.h"
	include "macro.h"
	
PF_Color_Read	equ PF_Color_Write+128	
	seg.u vars
	org $80
	


	seg.u SC_RAM_vars
	org $1000
PF_Color_Write		ds 1
	
	seg Bank_0
	
	org $E000
	rorg $F000
	
	repeat 256
	.byte $00
	repend

Start_0
	nop
	nop
	nop
	
	CLEAN_START
;	jsr Call_1
	lda #$FF
	sta PF1
StartFrame
	lda #2
	sta VBLANK
	sta VSYNC
	
	sta WSYNC
	sta WSYNC
	sta WSYNC
	
	lda #0
	sta VSYNC
	
	ldy #37
Vert
	sta WSYNC
	dey
	bne Vert
	
	lda #0
	sta VBLANK
	
	ldy #192
Pic
	sta WSYNC
	dey
	bne Pic
	
	lda #2
	sta VBLANK
	
	ldy #30
Over
	sta WSYNC
	dey
	bne Over
	
	jsr Call_1
	
	lda PF_Color_Read
	sta COLUPF

	
	jmp StartFrame

	


	org $EFE0
	rorg $FFE0
Call_1
	stx $FFF9
	
	nop
	nop
	nop
	nop
	nop
	nop
	
	rts
	
	org $EFF8
	rorg $FFF8
	.word $FFFF
	.word Start_0
	.word Start_0
	.word Start_0
	
	seg Bank_1
	
	org $F000
	rorg $F000
	
	repeat 256
	.byte $00
	repend
	
Init_1
	sta $FFF8
Bank1_Sub
;	lda #$0F
;	sta COLUPF
;	inc PF_Color
	clc
	lda PF_Color_Read
	adc #1
	sta PF_Color_Write
	rts
	
	org $FFE3
	rorg $FFE3
	jsr Bank1_Sub
	stx $FFF8
	
	org $FFF8
	.word $FFFF
	.word Init_1
	.word Init_1
	.word Init_1
	
