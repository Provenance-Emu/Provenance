;;A demo using CBS Electronic's FA (12K) + RAM (256 bytes) bankswitching scheme
;;3/20/09 By: Rick Skrbina

	processor 6502
	include "vcs.h"
	include "macro.h"
	
;BG_Color_Read		equ BG_Color_Write+256
;PF_Color_Read		equ PF_Color_Write+256
;BG_Write	equ $1000
BG_Read		equ BG_Write+256
PF_Read		equ PF_Write+256
	
	seg.u RIOT_vars
	org $80
	
	
	seg.u FA_RAM_vars
	org $1000
BG_Write		ds 1
PF_Write		ds 1
	
	seg bank_0
	org $D000
	rorg $F000
	
	repeat 512
	.byte $D0
	repend
Bank0

	nop
	nop
	nop

	CLEAN_START
	
	lda #$FF
	sta PF_Write
	sta PF1
	
	lda #$0F
	sta COLUBK
	
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
	
	ldy #192
Picture
	sta WSYNC
	dey
	bne Picture
	
	lda #2
	sta VBLANK
	
	ldy #30
Overscan
	sta WSYNC
	dey
	bne Overscan

	jsr Switch_To_1
	jsr Switch_To_2
	
	lda BG_Read
	sta COLUBK
	
	lda PF_Read
	sta COLUPF
	
	jmp Start_Frame
	
	org $D300
	rorg $F300
	
Switch_To_1		;$F300

	lda $FFF9
	
	nop
	nop
	nop
	
	nop
	nop
	nop
	
	rts

Switch_To_2		;$

	lda $FFFA
	
	nop
	nop
	nop
	
	nop
	nop
	nop
	
	rts
	
	
	org $DFFC
	rorg $FFFC
	.word Bank0
	.byte "B0"
	
	seg bank_1
	org $E000
	rorg $F000
	
	repeat 512
	.byte $00
	repend
	
Bank1
	lda $FFF8
	
Change_BG_Color

	clc
	lda BG_Read
	adc #1
	sta BG_Write
	
	rts

	org $E303
	rorg $F303
	
	
	jsr Change_BG_Color
	lda $FFF8

	org $EFFC
	rorg $FFFC
	.word Bank1
	.byte "B1"
	
	seg bank_2
	org $F000
	rorg $F000
	
	repeat 512
	.byte $00
	repend
	
Bank2
	
	lda $FFF8
	
Change_PF_Color

	sei
	lda PF_Read
	sbc #1
	sta PF_Write

	rts

	org $F30D
	rorg $F30D

	jsr Change_PF_Color
	lda $FFF8

	org $FFFC
	rorg $FFFC
	.word Bank2
	.byte "B2"
