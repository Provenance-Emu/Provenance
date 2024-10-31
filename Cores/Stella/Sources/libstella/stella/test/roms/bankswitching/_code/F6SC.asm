;;A bankswitching demo fhr the F6SC BS technique.  4 4K banks + 128b RAM (16K total)
;;By: Rick Skrbina 3/31/09

	processor 6502
	include "vcs.h"
	include "macro.h"
	
Color0_Read	equ Color0_Write+128
Color1_Read	equ Color1_Write+128
Color2_Read	equ Color2_Write+128
Color3_Read	equ Color3_Write+128
	
	seg.u vars
	org $80
	
	
	seg.u SuperChip_RAM
	org $1000
Color0_Write		ds 1
Color1_Write		ds 1
Color2_Write		ds 1
Color3_Write		ds 1
	
	seg bank0
	org $C000
	rorg $F000

	repeat 256
	.byte $00
	repend

Start	
	nop
	nop
	nop

	CLEAN_START
	
	lda #$0F
	sta Color0_Write
	lda #$1F
	sta Color1_Write
	lda #$4F
	sta Color2_Write
	lda #$8F
	sta Color3_Write
	
Start_Frame
	lda #2
	sta VBLANK
	sta VSYNC
	sta WSYNC
	sta WSYNC
	sta WSYNC
	lsr
	sta VSYNC
	
	clc
	lda Color0_Read
	adc #1
	sta Color0_Write
	sta COLUBK
	
	ldy #37
VerticalBlank
	sta WSYNC
	dey
	bne VerticalBlank
	

	
	lda #0
	sta VBLANK
	
	ldy #48
Picture1
	sta WSYNC
	dey
	bne Picture1

	jsr Swch1
	
	ldy #47
Picture2
	sta WSYNC
	dey
	bne Picture2
	
	jsr Swch2
	
	ldy #47
Picture3
	sta WSYNC
	dey
	bne Picture3
	
	jsr Swch3
	
	ldy #47
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
	
	repeat 256
	.byte $00
	repend
Start1
	lda $1FF6
	
Bank1Sub
	clc
	lda Color1_Read
	adc #1
	sta Color1_Write
	sta WSYNC
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
	
	repeat 256
	.byte $00
	repend
	
Start2
	lda $1FF6
	
Bank2Sub
	clc
	lda Color2_Read
	adc #1
	sta Color2_Write
	sta WSYNC
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
	
	repeat 256
	.byte $00
	repend
	
Start3
	lda $1FF6

Bank3Sub
	clc
	lda Color3_Read
	adc #1
	sta Color3_Write
	lda Color3_Read
	sta WSYNC
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
