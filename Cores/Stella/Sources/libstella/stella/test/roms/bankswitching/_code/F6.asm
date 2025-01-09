;;A bankswitching demo fhr the F6 BS technique.  4 4K banks (16K total)
;;By: Rick Skrbina 3/28/09

	processor 6502
	include "vcs.h"
	include "macro.h"
	
	seg.u vars
	org $80
	
	
	seg bank0
	org $C000
	rorg $F000
	
	nop
	nop
	nop
Start
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
	
	lda #0
	sta VBLANK
	
	lda #$0F
	sta COLUBK
	
	ldy #48
Picture1
	sta WSYNC
	dey
	bne Picture1

	jsr Swch1
	
	ldy #48
Picture2
	sta WSYNC
	dey
	bne Picture2
	
	jsr Swch2
	
	ldy #48
Picture3
	sta WSYNC
	dey
	bne Picture3
	
	jsr Swch3
	
	ldy #48
Picture4
	sta WSYNC
	dey
	bne Picture4
	
	lda #2
	sta VBLANK
	
	ldy #30
OverScan
	sta WSYNC
	dey
	bne OverScan
	
	jmp Start_Frame
	
	org $CFE0
	rorg $FFE0
Swch1
	lda $FFF7
Swch2
	lda $FFF8
Swch3
	lda $FFF9
	
	rts
	rts
	rts
	rts
	rts
	rts
	rts

	org $CFFC
	rorg $FFFC
	.word Start
	.byte "B0"
	
	seg bank1
	org $D000
	rorg $F000
Start1
	lda $1FF6
	
Bank1Sub
	lda #$1F
	sta COLUBK
	rts

	org $DFE0
	rorg $FFE0
	
	nop
	nop
	nop
	jsr Bank1Sub
	lda $FFF6

	org $DFFC
	rorg $FFFC
	.word Start
	.byte "B1"
	
	seg bank2
	org $E000
	rorg $F000
Start2
	lda $1FF6
	
Bank2Sub
	lda #$4F
	sta COLUBK
	rts
	
	org $EFE0
	rorg $FFE0
	
	nop
	nop
	nop
	nop
	nop
	nop
	jsr Bank2Sub
	lda $FFF6

	org $EFFC
	rorg $FFFC
	.word Start2
	.byte "B2"
	
	seg bank3
	org $F000
	rorg $F000
Start3
	lda $1FF6

Bank3Sub
	lda #$8F
	sta COLUBK
	rts
	
	org $FFE0
	rorg $FFE0
	
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	jsr Bank3Sub
	lda $FFF6

	org $FFFC
	rorg $FFFC
	.word Start3
	.byte "B3"
