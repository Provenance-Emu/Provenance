;;A Bankswitching demo for the x07 scheme.  16 4K banks (64K total)
;;By: Rick Skrbina 6/11/09


	processor 6502
	include "vcs.h"
	include "macro.h"
	
	seg.u vars
	org $80
	
	
	seg bank0
	org $0000
	rorg $F000
	
Bank0
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
	
	sty VBLANK
	
	lda #$0F
	sta COLUBK
	
	ldy #12
Picture0
	sta WSYNC
	dey
	bne Picture0
	
	jsr Swch1
	
	ldy #12
Picture1
	sta WSYNC
	dey
	bne Picture1
	
	jsr Swch2
	
	ldy #12
Picture2
	sta WSYNC
	dey
	bne Picture2
	
	jsr Swch3
	
	ldy #12
Picture3
	sta WSYNC
	dey
	bne Picture3
	
	jsr Swch4
	
	ldy #12
Picture4
	sta WSYNC
	dey
	bne Picture4
	
	jsr Swch5
	
	ldy #12
Picture5
	sta WSYNC
	dey
	bne Picture5
	
	jsr Swch6
	
	ldy #12
Picture6
	sta WSYNC
	dey
	bne Picture6
	
	jsr Swch7
	
	ldy #12
Picture7
	sta WSYNC
	dey
	bne Picture7
	
	jsr Swch8
	
	ldy #12
Picture8
	sta WSYNC
	dey
	bne Picture8
	
	jsr Swch9
	
	ldy #12
Picture9
	sta WSYNC
	dey
	bne Picture9
	
	jsr SwchA
	
	ldy #12
PictureA
	sta WSYNC
	dey
	bne PictureA
	
	jsr SwchB
	
	ldy #12
PictureB
	sta WSYNC
	dey
	bne PictureB
	
	jsr SwchC
	
	ldy #12
PictureC
	sta WSYNC
	dey
	bne PictureC
	
	jsr SwchD
	
	ldy #12
PictureD
	sta WSYNC
	dey
	bne PictureD
	
	jsr SwchE
	
;	ldy #12
;PictureE
;	sta WSYNC
;	dey
;	bne PictureE
	
;	ldy #12
;PictureF
;	sta WSYNC
;	dey
;	bne PictureF
	
	lda #2
	sta VBLANK
	
	ldy #30
OverScan
	sta WSYNC
	dey
	bne OverScan
	
	jmp Start_Frame

	org $0500
	rorg $F500
	
Swch1
	lda $081D
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F50A
	
Swch2
	lda $082D
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F514
	
Swch3
	lda $083D
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F51E
	
Swch4
	lda $084D
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F528
	
Swch5
	lda $085D
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F532
	
Swch6
	lda $086D
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F53C
	
Swch7
	lda $087D
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F543
	
Swch8
	lda $088D
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F550
	
Swch9
	lda $089D
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F55A
	
SwchA
	lda $08AD
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F564
	
SwchB
	lda $08BD
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F56E
	
SwchC
	lda $08CD
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F578
	
SwchD
	lda $08DD
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	;$F582
	
SwchE
	lda $08ED
	nop
	nop
	nop
	nop
	nop
	nop
	rts


	org $0FFC
	rorg $FFFC
	.word Bank0
	.byte "00"
	
	seg bank1
	org $1000
	rorg $F000
	
Bank1
	nop $080D
Sub1
	lda #$1F
	sta COLUBK
;	jmp Sub1
	rts
	
	org $1500
	rorg $F500
	nop
	nop
	nop
	jsr Sub1
	nop $080D

	org $1FFC
	rorg $FFFC
	.word Bank1
	.byte "01"
	
	seg bank2
	org $2000
	rorg $F000
	
Bank2
	nop $080D
Sub2
	lda #$2F
	sta COLUBK
	rts

	org $250A
	rorg $F50A
	nop
	nop
	nop
	jsr Sub2
	lda $080D

	org $2FFC
	rorg $FFFC
	.word Bank2
	.byte "02"
	
	seg bank3
	org $3000
	rorg $F000
	
Bank3
	nop $080D
	
Sub3
	lda #$3F
	sta COLUBK
	rts

	org $3514
	rorg $F514
	nop
	nop
	nop
	jsr Sub3
	lda $080D

	org $3FFC
	rorg $FFFC
	.word Bank3
	.byte "03"
	
	seg bank4
	org $4000
	rorg $F000
	
Bank4
	nop $080D
	
Sub4
	lda #$4F
	sta COLUBK
	rts

	org $451E
	rorg $F51E
	nop
	nop
	nop
	jsr Sub4
	lda $080D

	org $4FFC
	rorg $FFFC
	.word Bank4
	.byte "04"
	
	seg bank5
	org $5000
	rorg $F000
	
Bank5
	nop $080D
	
Sub5
	lda #$5F
	sta COLUBK
	rts

	org $5528
	rorg $F528
	nop
	nop
	nop
	jsr Sub5
	lda $080D

	org $5FFC
	rorg $FFFC
	.word Bank5
	.byte "05"
	
	seg bank6
	org $6000
	rorg $F000
	
Bank6
	nop $080D
	
Sub6
	lda #$6F
	sta COLUBK
	rts

	org $6532
	rorg $F532
	nop
	nop
	nop
	jsr Sub6
	lda $080D

	org $6FFC
	rorg $FFFC
	.word Bank6
	.byte "06"
	
	seg bank7
	org $7000
	rorg $F000
	
Bank7
	nop $080D
	
Sub7
	lda #$7F
	sta COLUBK
	rts

	org $753C
	rorg $F53C
	nop
	nop
	nop
	jsr Sub7
	lda $080D

	org $7FFC
	rorg $FFFC
	.word Bank7
	.byte "07"
	
	seg bank8
	org $8000
	rorg $F000
	
Bank8
	nop $080D
	
Sub8
	lda #$8F
	sta COLUBK
	rts

	org $8546
	rorg $F546
	nop
	nop
	nop
	jsr Sub8
	lda $080D

	org $8FFC
	rorg $FFFC
	.word Bank8
	.byte "08"
	
	seg bank9
	org $9000
	rorg $F000
	
Bank9
	nop $080D
	
Sub9
	lda #$9F
	sta COLUBK
	rts

	org $9550
	rorg $F550
	nop
	nop
	nop
	jsr Sub9
	lda $080D

	org $9FFC
	rorg $FFFC
	.word Bank9
	.byte "09"
	
	seg bankA
	org $A000
	rorg $F000
	
BankA
	nop $080D
	
SubA
	lda #$AF
	sta COLUBK
	rts

	org $A55A
	rorg $F55A
	nop
	nop
	nop
	jsr SubA
	lda $080D

	org $AFFC
	rorg $FFFC
	.word BankA
	.byte "0A"
	
	seg bankB
	org $B000
	rorg $F000
	
BankB
	nop $080D
	
SubB
	lda #$BF
	sta COLUBK
	rts

	org $B564
	rorg $F564
	nop
	nop
	nop
	jsr SubB
	lda $080D

	org $BFFC
	rorg $FFFC
	.word BankB
	.byte "0B"
	
	seg bankC
	org $C000
	rorg $F000
	
BankC
	nop $080D
	
SubC
	lda #$CF
	sta COLUBK
	rts

	org $C56E
	rorg $F56E
	nop
	nop
	nop
	jsr SubC
	lda $080D

	org $CFFC
	rorg $FFFC
	.word BankC
	.byte "0C"
	
	seg bankD
	org $D000
	rorg $F000
	
BankD
	nop $080D
	
SubD
	lda #$DF
	sta COLUBK
	rts

	org $D578
	rorg $F578
	nop
	nop
	nop
	jsr SubD
	lda $080D

	org $DFFC
	rorg $FFFC
	.word BankD
	.byte "0D"
	
	seg bankE
	org $E000
	rorg $F000
	
BankE
	nop $080D
	
SubE

	lda #$EF
	sta COLUBK+$40	;Switch to bank F
	
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	
	ldy #12
PictureF
	sta WSYNC
	dey
	bne PictureF
	
	rts		;go back to bank 0
	

	org $E582
	rorg $F582
	nop
	nop
	nop
	jsr SubE
	lda $080D
	

	org $EFFC
	rorg $FFFC
	.word BankE
	.byte "0E"
	
	seg bankF
	org $F000
	rorg $F000
	
BankF
	nop $080D
	
SubF
	nop
	nop
	nop
	nop
	
	ldy #12
PictureE
	sta WSYNC+$40	;+$40 so no undesired BS
	dey
	bne PictureE
	
	lda #$FF
	sta COLUBK	;switch to bank E
	

	org $FFFC
	rorg $FFFC
	.word BankF
	.byte "0F"
