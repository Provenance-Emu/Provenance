;;A demo for the F4 banking scheme.  8 4K banks (32K total)
;;By: Rick Skrbina 4/30/09

	processor 6502
	include "vcs.h"
	include "macro.h"
	
Bank0_Read	equ Bank0_Write+128
	
	seg.u vars
	org $80
	
	seg.u SC_RAM
	org $1000
Bank0_Write		ds 1
	
	seg bank0
	org $8000
	rorg $F000
	
	repeat 256
	.byte $FF
	repend
	
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
	
;	lda #$0F
;	sta COLUBK
	
	ldy #37
VerticalBlank
	sta WSYNC
	dey
	bne VerticalBlank
	
	lda #0
	sta VBLANK
	
	clc
	lda Bank0_Read
	adc #1
	sta Bank0_Write
	lda Bank0_Read
	sta COLUBK
	
	sta WSYNC
	
	ldy #23
Picture0
	sta WSYNC
	dey
	bne Picture0
	
	jsr Swch1
	
	ldy #23
Picture1
	sta WSYNC
	dey
	bne Picture1
	
	jsr Swch2
	
	ldy #23
Picture2
	sta WSYNC
	dey
	bne Picture2
	
	jsr Swch3
	
	ldy #23
Picture3
	sta WSYNC
	dey
	bne Picture3
	
	jsr Swch4
	
	ldy #23
Picture4
	sta WSYNC
	dey
	bne Picture4
	
	jsr Swch5
	
	ldy #23
Picture5
	sta WSYNC
	dey
	bne Picture5
	
	jsr Swch6
	
	ldy #23
Picture6
	sta WSYNC
	dey
	bne Picture6
	
	jsr Swch7
	
	ldy #23
Picture7
	sta WSYNC
	dey
	bne Picture7
	
	lda #2
	sta VBLANK
	
	ldy #30
OverScan
	sta WSYNC
	dey
	bne OverScan
	
	jmp Start_Frame
	
	org $8FC0
	rorg $FFC0
	
Swch7
	lda $FFFB
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	

	org $8FD0
	rorg $FFD0
Swch1
	lda $FFF5
Swch2
	lda $FFF6
Swch3
	lda $FFF7
	
	rts
	rts
	rts
	rts
	rts
	rts
	rts
	
	org $8FE0
	rorg $FFE0
Swch4
	lda $FFF8
Swch5
	lda $FFF9
Swch6
	lda $FFFA
	
	rts
	rts
	rts
	rts
	rts
	rts
	rts


	org $8FFC
	rorg $FFFC
	.word Start0
	.byte "B0"
	
	seg bank1
	org $9000
	rorg $F000
	
	repeat 256
	.byte $FF
	repend
	
Start1
	lda $FFF4
	
Bank1Sub
	lda #$1F
	sta WSYNC
	sta COLUBK
	rts
	
	org $9FD0
	rorg $FFD0
	
	nop
	nop
	nop
	jsr Bank1Sub
	sta $FFF4

	org $9FFC
	rorg $FFFC
	.word Start1
	.byte "B1"
	
	seg bank2
	org $A000
	rorg $F000
	
	repeat 256
	.byte $FF
	repend
	
Start2
	lda $FFF4
	
Bank2Sub
	lda #$2F
	sta WSYNC
	sta COLUBK
	rts
	
	org $AFD0
	rorg $FFD0
	
	nop
	nop
	nop
	nop
	nop
	nop
	jsr Bank2Sub
	sta $FFF4

	org $AFFC
	rorg $FFFC
	.word Start2
	.byte "B2"
	
	seg bank3
	org $B000
	rorg $F000
	
	repeat 256
	.byte $FF
	repend
	
Start3
	lda $FFF4
	
Bank3Sub
	lda #$3F
	sta WSYNC
	sta COLUBK
	rts
	
	org $BFD0
	rorg $FFD0
	
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
	sta $FFF4

	org $BFFC
	rorg $FFFC
	.word Start3
	.byte "B3"
	
	seg bank4
	org $C000
	rorg $F000
	
	repeat 256
	.byte $FF
	repend

Start4
	lda $FFF4
	
Bank4Sub
	lda #$4F
	sta WSYNC
	sta COLUBK
	rts
	
	org $CFE0
	rorg $FFE0

	nop
	nop
	nop
	jsr Bank4Sub
	sta $FFF4

	org $CFFC
	rorg $FFFC
	.word Start4
	.byte "B4"
	
	seg bank5
	org $D000
	rorg $F000
	
	repeat 256
	.byte $FF
	repend
	
Start5
	lda $FFF4
	
Bank5Sub
	lda #$5F
	sta WSYNC
	sta COLUBK
	rts
	
	org $DFE0
	rorg $FFE0
	
	nop
	nop
	nop
	nop
	nop
	nop
	jsr Bank5Sub
	sta $FFF4

	org $DFFC
	rorg $FFFC
	.word Start5
	.byte "B5"
	
	seg bank6
	org $E000
	rorg $F000
	
	repeat 256
	.byte $FF
	repend
	
Start6
	lda $FFF4
	
Bank6Sub

	lda #$6F
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
	nop
	nop
	nop
	jsr Bank6Sub
	sta $FFF4

	org $EFFC
	rorg $FFFC
	.word Start6
	.byte "B6"
	
	seg bank7
	org $F000
	rorg $F000
	
	repeat 256
	.byte $FF
	repend
	
Start7
	lda $FFF4
	
Bank7Sub

	lda #$8F
	sta WSYNC
	sta COLUBK
	rts
	
	org $FFC0
	rorg $FFC0
	
	nop
	nop
	nop
	jsr Bank7Sub
	sta $FFF4

	org $FFFC
	rorg $FFFC
	.word Start7
	.byte "B7"


