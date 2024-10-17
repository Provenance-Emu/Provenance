;;A bankswtiching demo for Parker Bros. E0 scheme.  8 1K slices.
;;By Rick Skrbina 5/3/09

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
	org $0400
	rorg $F000
Slice1
	lda #$2F
	sta COLUBK
	rts
	
	seg slice2
	org $0800
	rorg $F000
Slice2
	lda #$3F
	sta COLUBK
	rts

	seg slice3
	org $0C00
	rorg $F000
Slice3
	lda #$4F
	sta COLUBK
	rts

	seg slice4
	org $1000
	rorg $F000
Slice4
	lda #$5F
	sta COLUBK
	rts

	seg slice5
	org $1400
	rorg $F000
Slice5
	lda #$6F
	sta COLUBK
	rts
	
	seg slice6
	org $1800
	rorg $F000
Slice6
	lda #$7F
	sta COLUBK
	rts

	seg slice7
	org $1C00
	rorg $FC00
Slice7
	CLEAN_START
	
Start_Frame
	lda #2
	sta VBLANK
	sta VSYNC
	sta WSYNC
	sta WSYNC
	sta WSYNC
	lda #0
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
	
	ldy #24
Picture0
	sta WSYNC
	dey
	bne Picture0
	
	lda $1FE0
	jsr Slice0
	
	ldy #24
Picture1
	sta WSYNC
	dey
	bne Picture1
	
	lda $1FE1
	jsr Slice1
	
	ldy #24
Picture2
	sta WSYNC
	dey
	bne Picture2
	
	lda $1FE2
	jsr Slice2
	
	ldy #24
Picture3
	sta WSYNC
	dey
	bne Picture3
	
	lda $1FE3
	jsr Slice3
	
	ldy #24
Picture4
	sta WSYNC
	dey
	bne Picture4
	
	lda $1FE4
	jsr Slice4
	
	ldy #24
Picture5
	sta WSYNC
	dey
	bne Picture5
	
	lda $1FE5
	jsr Slice5
	
	ldy #24
Picture6
	sta WSYNC
	dey
	bne Picture6
	
	lda $1FE6
	jsr Slice6
	
	ldy #24
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

	org $1FFC
	rorg $FFFC
	.word Slice7
	.byte "RS"
