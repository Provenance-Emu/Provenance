;;A bankswitching demo for the F8 BS technique. 2 4K banks (8K total)
;;By: Rick Skrbina
	processor 6502
	include "vcs.h"
	include "macro.h"
	
	seg.u vars
	org $80
	
PF_Color		ds 1
	
	seg Bank_0
	
	org $E000
	rorg $F000
	
	nop
	nop
	nop
Start_0
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
	
	lda PF_Color
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
	
Init_1
	sta $FFF8
Bank1_Sub
;	lda #$0F
;	sta COLUPF
	inc PF_Color
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
	
