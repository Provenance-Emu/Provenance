;;A bankswtiching Demo using M-Network's E7 Scheme.  8 2K Banks + 2K RAM
;;By: Rick Skrbina 4/9/09
;;
;;ROM Banks accesed via $1FE0-$1FE6 and mapped from $F000-$F7FF
;;First 1K RAM block accessed via $1FE7 and loaded from $F000-$F7FF
;;Second 1K block is split up into 256b parts, selected by $FFF8-$FFFB
;;The 256b chuncks are loaded from $F800-$F9FF

	processor 6502
	include "vcs.h"
	include "macro.h"
	
Bank0_Color_Read	equ Bank0_Color_Write+1024

	
	seg.u RIOT_RAM
	org $80
	
	
	seg.u E7_RAM_0		;1K Block
	org $F000
	
Bank0_Color_Write	ds 1
	
	seg.u E7_RAM_1		;256b Blocks
	org $F800
	
	
	seg.u E7_RAM_2
	org $F800
	
	
	seg.u E7_RAM_3
	org $F800
	
	seg.u E7_RAM_4
	org $F800
	
	seg bank0
	org $0000
	rorg $F000
Start0
	
	lda #$10
	sta COLUBK
	
	rts
	


	
	seg bank1
	org $0800
	rorg $F000
Start1
	lda #$20
	sta COLUBK
	
	rts



	
	seg bank2
	org $1000
	rorg $F000
Start2
	lda #$30
	sta COLUBK
	
	rts



	
	seg bank3
	org $1800
	rorg $F000
Start3
	lda #$40
	sta COLUBK
	
	rts



	
	seg bank4
	org $2000
	rorg $F000
Start4
	lda #$50
	sta COLUBK
	
	rts



	
	seg bank5
	org $2800
	rorg $F000
Start5
	lda #$60
	sta COLUBK
	
	rts



	
	seg bank6
	org $3000
	rorg $F000
Start6
	lda #$70
	sta COLUBK
	
	rts



	
	seg bank7
	org $3800
	rorg $F800

	repeat 512
	.byte $00
	repend
Start7

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
	
	lda $1FE7
	
	clc
	lda Bank0_Color_Read
	adc #1
	sta Bank0_Color_Write
	lda Bank0_Color_Read
	sta COLUBK
	
	ldy #24
Picture0
	sta WSYNC
	dey
	bne Picture0
	
	lda $1FE0
	jsr Start0

	
	ldy #24
Picture1
	sta WSYNC
	dey
	bne Picture1
	
	lda $1FE1
	jsr Start1
	
	ldy #24
Picture2
	sta WSYNC
	dey
	bne Picture2
	
	lda $1FE2
	jsr Start2
	
	ldy #24
Picture3
	sta WSYNC
	dey
	bne Picture3
	
	lda $1FE3
	jsr Start3
	
	ldy #24
Picture4
	sta WSYNC
	dey
	bne Picture4
	
	lda $1FE4
	jsr Start4
	
	ldy #24
Picture5
	sta WSYNC
	dey
	bne Picture5
	
	lda $1FE5
	jsr Start5
	
	ldy #24
Picture6
	sta WSYNC
	dey
	bne Picture6
	
	lda $1FE6
	jsr Start6
	
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

	org $3FFC
	rorg $FFFC
	.word Start7
	.byte "07"
	
