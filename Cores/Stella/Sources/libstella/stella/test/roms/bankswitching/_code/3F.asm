;;A Bankswitcing demo for TigerVision's 3F scheme.  4 2K slices
;;By Rick Skrbina 5/4/09

TIA_BASE_ADDRESS = $40		;Use $40-$7F for TIA access so there is no undesired Bankswitch

	processor 6502
	include "vcs.h"
	include "macro.h"
	
	
	seg.u vars
	org $80
	
	
	seg slice0
	org $0000
	rorg $F000
Slice0
	lda #$1F
	sta COLUBK
	rts

	seg slice1
	org $0800
	rorg $F000
Slice1
	lda #$2F
	sta COLUBK
	rts
	
	seg slice2
	org $1000
	rorg $F000
Slice2
	lda #$3F
	sta COLUBK
	rts

	seg slice3
	org $1800
	rorg $F800
Slice3
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
Picture0
	sta WSYNC
	dey
	bne Picture0
	
	lda #0
	sta $3F
	jsr Slice0
	
	ldy #48
Picture1
	sta WSYNC
	dey
	bne Picture1
	
	lda #1
	sta $3F
	jsr Slice1
	
	ldy #48
Picture2
	sta WSYNC
	dey
	bne Picture2
	
	lda #2
	sta $3F
	jsr Slice2
	
	ldy #48
Picture3
	sta WSYNC
	dey
	bne Picture3
	
	lda #2
	sta VBLANK
	
	ldy #30
OverScan
	sta WSYNC
	dey
	bne OverScan
	
	jmp Start_Frame
	

	org $1FFC
	rorg $FFFC
	.word Slice3
	.byte "RS"
