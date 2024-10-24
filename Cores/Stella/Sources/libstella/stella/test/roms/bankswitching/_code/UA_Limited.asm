;;A bankswitching demo for the UA limited technique.  2 4K banks (8K)
;;By: Rick Skrbina 3/29/09

	processor 6502
	include "vcs.h"
	include "macro.h"
	
	
	seg.u vars
	org $80
BG_Color		ds 1
	
	seg Bank0
	org $E000
	rorg $F000
Start0
	nop
	nop
	nop

	CLEAN_START
	
Start_Frame
	lda #2
	sta VBLANK
	sta VSYNC
	sta WSYNC
	sta WSYNC
	sta WSYNC
	lsr
	sta VSYNC
	ldy #37
VerticalBlank
	sta WSYNC
	dey
	bne VerticalBlank
	
	sta VBLANK
	
	ldy #192
Picture
	sta WSYNC
	dey
	bne Picture
	
	lda #2
	sta VBLANK
	
	ldy #30
OverScan
	sta WSYNC
	dey
	bne OverScan
	
	jsr SwchTo1
	
	lda BG_Color
	sta COLUBK
	
	jmp Start_Frame
	
	org $EFE0
	rorg $FFE0
SwchTo1	
	lda $0240
	nop
	nop
	nop
	nop
	nop
	nop
	rts

	org $EFFC
	rorg $FFFC
	.word Start0
	.byte "B0"
	
	seg Bank1
	org $F000
	rorg $F000
Start1
	lda $0220
	
Bank1Sub

	inc BG_Color
	rts
	
	org $FFE0
	rorg $FFE0
	
	nop
	nop
	nop
	jsr Bank1Sub
	lda $0220

	org $FFFC
	rorg $FFFC
	.word Start1
	.byte "B1"
