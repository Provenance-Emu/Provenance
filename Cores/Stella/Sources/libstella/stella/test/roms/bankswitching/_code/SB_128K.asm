;;A bankswitching demo for the 128K SuperBanking scheme.  32 4K banks
;;By: Rick Skrbina 4/4/09

	processor 6502
	include "vcs.h"
	include "macro.h"
	
	seg.u vars
	org $80
	
	
	seg bank0
	org $0000
	rorg $F000
Start0
	nop
	nop
	nop
	CLEAN_START
	
;	lda #$1F
;	sta COLUBK
	
Start_Frame
	lda #2
	sta VSYNC
	sta VBLANK
	sta WSYNC
	sta WSYNC
	sta WSYNC
	lsr
	sta VSYNC
	
	ldy #37
Vertical_Blank
	sta WSYNC
	dey
	bne Vertical_Blank
	
	lda #0
	sta VBLANK
	
	lda #$10
	sta COLUBK
	
	ldy #6
Picture0
	sta WSYNC
	dey
	bne Picture0
	
	ldx #1
	jsr Swch1
	
	ldy #6
Picture1
	sta WSYNC
	dey
	bne Picture1
	
	inx
	jsr Swch1
	
	ldy #6
Picture2
	sta WSYNC
	dey
	bne Picture2
	
	inx
	jsr Swch1
	
	ldy #6
Picture3
	sta WSYNC
	dey
	bne Picture3
	
	inx
	jsr Swch1
	
	ldy #6
Picture4
	sta WSYNC
	dey
	bne Picture4
	
	inx
	jsr Swch1
	
	ldy #6
Picture5
	sta WSYNC
	dey
	bne Picture5
	
	inx
	jsr Swch1
	
	ldy #6
Picture6
	sta WSYNC
	dey
	bne Picture6
	
	inx
	jsr Swch1
	
	ldy #6
Picture7
	sta WSYNC
	dey
	bne Picture7
	
	inx
	jsr Swch1
	
	ldy #6
Picture8
	sta WSYNC
	dey
	bne Picture8
	
	inx
	jsr Swch1
	
	ldy #6
Picture9
	sta WSYNC
	dey
	bne Picture9
	
	inx
	jsr Swch1
	
	ldy #6
PictureA
	sta WSYNC
	dey
	bne PictureA
	
	inx
	jsr Swch1
	
	ldy #6
PictureB
	sta WSYNC
	dey
	bne PictureB
	
	inx
	jsr Swch1
	
	ldy #6
PictureC
	sta WSYNC
	dey
	bne PictureC
	
	inx
	jsr Swch1
	
	ldy #6
PictureD
	sta WSYNC
	dey
	bne PictureD
	
	inx
	jsr Swch1
	
	ldy #6
PictureE
	sta WSYNC
	dey
	bne PictureE
	
	inx
	jsr Swch1
	
	ldy #6
PictureF
	sta WSYNC
	dey
	bne PictureF
	
	inx
	jsr Swch1
	
	ldy #6
Picture10
	sta WSYNC
	dey
	bne Picture10
	
	inx
	jsr Swch1
	
	ldy #6
Picture11
	sta WSYNC
	dey
	bne Picture11
	
	inx
	jsr Swch1

	ldy #6
Picture12
	sta WSYNC
	dey
	bne Picture12
	
	inx
	jsr Swch1
	
	ldy #6
Picture13
	sta WSYNC
	dey
	bne Picture13
	
	inx
	jsr Swch1
	
	ldy #6
Picture14
	sta WSYNC
	dey
	bne Picture14
	
	inx
	jsr Swch1
	
	ldy #6
Picture15
	sta WSYNC
	dey
	bne Picture15
	
	inx
	jsr Swch1
	
	ldy #6
Picture16
	sta WSYNC
	dey
	bne Picture16
	
	inx
	jsr Swch1
	
	ldy #6
Picture17
	sta WSYNC
	dey
	bne Picture17
	
	inx
	jsr Swch1
	
	ldy #6
Picture18
	sta WSYNC
	dey
	bne Picture18
	
	inx
	jsr Swch1
	
	ldy #6
Picture19
	sta WSYNC
	dey
	bne Picture19
	
	inx
	jsr Swch1
	
	ldy #6
Picture1A
	sta WSYNC
	dey
	bne Picture1A
	
	inx
	jsr Swch1
	
	ldy #6
Picture1B
	sta WSYNC
	dey
	bne Picture1B
	
	inx
	jsr Swch1
	
	ldy #6
Picture1C
	sta WSYNC
	dey
	bne Picture1C
	
	inx
	jsr Swch1
	
	ldy #6
Picture1D
	sta WSYNC
	dey
	bne Picture1D
	
	inx
	jsr Swch1
	
	ldy #6
Picture1E
	sta WSYNC
	dey
	bne Picture1E
	
	inx
	jsr Swch1
	
	ldy #6
Picture1F
	sta WSYNC
	dey
	bne Picture1F
	
	inx
	jsr Swch1
	
	lda #2
	sta VBLANK
	
	ldy #30
OverScan
	sta WSYNC
	dey
	bne OverScan
	
	jmp Start_Frame
	
	
	org $0200
	rorg $F200
	
Swch1
	lda $0800,x
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	
	
	org $0FFC
	rorg $FFFC
	.word Start0
	.byte "00"
	
	seg bank1
	org $1000
	rorg $F000
Start1
	lda $0800
Sub1
	lda #$12
	sta COLUBK
	rts

	org $1200
	rorg $F200

	nop
	nop
	nop
	jsr Sub1
	lda $0800

	org $1FFC
	rorg $FFFC
	.word Start1
	.byte "01"
	
	seg bank2
	org $2000
	rorg $F000
Start2
	lda $0800
	
Sub2
	lda #$14
	sta COLUBK
	rts

	org $2200
	rorg $F1200

	nop
	nop
	nop
	jsr Sub2
	lda $0800

	org $2FFC
	rorg $FFFC
	.word Start2
	.byte "02"
	
	seg bank3
	org $3000
	rorg $F000
Start3
	lda $0800
	
Sub3
	lda #$16
	sta COLUBK
	rts

	org $3200
	rorg $F200

	nop
	nop
	nop
	jsr Sub3
	lda $0800

	org $3FFC
	rorg $FFFC
	.word Start3
	.byte "03"
	
	seg bank4
	org $4000
	rorg $F000
Start4
	lda $0800
	
Sub4
	lda #$18
	sta COLUBK
	rts

	org $4200
	rorg $F200

	nop
	nop
	nop
	jsr Sub4
	lda $0800

	org $4FFC
	rorg $FFFC
	.word Start4
	.byte "04"
	
	seg bank5
	org $5000
	rorg $F000
Start5
	lda $0800
	
Sub5
	lda #$1A
	sta COLUBK
	rts

	org $5200
	rorg $F200

	nop
	nop
	nop
	jsr Sub5
	lda $0800

	org $5FFC
	rorg $FFFC
	.word Start5
	.byte "05"
	
	seg bank6
	org $6000
	rorg $F000
Start6
	lda $0800
	
Sub6
	lda #$1C
	sta COLUBK
	rts

	org $6200
	rorg $F200

	nop
	nop
	nop
	jsr Sub6
	lda $0800

	org $6FFC
	rorg $FFFC
	.word Start6
	.byte "06"
	
	seg bank7
	org $7000
	rorg $F000
Start7
	lda $0800
	
Sub7
	lda #$1D
	sta COLUBK
	rts

	org $7200
	rorg $F200

	nop
	nop
	nop
	jsr Sub7
	lda $0800

	org $7FFC
	rorg $FFFC
	.word Start7
	.byte "07"
	
	seg bank8
	org $8000
	rorg $F000
Start8
	lda $0800
Sub8
	lda #$1F
	sta COLUBK
	rts

	org $8200
	rorg $F200

	nop
	nop
	nop
	jsr Sub8
	lda $0800

	org $8FFC
	rorg $FFFC
	.word Start8
	.byte "08"
	
	seg bank9
	org $9000
	rorg $F000
Start9
	lda $0800
	
Sub9
	lda #$20
	sta COLUBK
	rts

	org $9200
	rorg $F200

	nop
	nop
	nop
	jsr Sub9
	lda $0800

	org $9FFC
	rorg $FFFC
	.word Start9
	.byte "09"
	
	seg bankA
	org $A000
	rorg $F000
StartA
	lda $0800
	
SubA
	lda #$22
	sta COLUBK
	rts

	org $A200
	rorg $F200

	nop
	nop
	nop
	jsr SubA
	lda $0800

	org $AFFC
	rorg $FFFC
	.word StartA
	.byte "0A"
	
	seg bankB
	org $B000
	rorg $F000
StartB
	lda $0800
	
SubB
	lda #$24
	sta COLUBK
	rts

	org $B200
	rorg $F200

	nop
	nop
	nop
	jsr SubB
	lda $0800

	org $BFFC
	rorg $FFFC
	.word StartB
	.byte "0B"
	
	seg bankC
	org $C000
	rorg $F000
StartC
	lda $0800
	
SubC
	lda #$26
	sta COLUBK
	rts

	org $C200
	rorg $F200

	nop
	nop
	nop
	jsr SubC
	lda $0800

	org $CFFC
	rorg $FFFC
	.word StartC
	.byte "0C"
	
	seg bankD
	org $D000
	rorg $F000
StartD
	lda $0800
	
SubD
	lda #$28
	sta COLUBK
	rts

	org $D200
	rorg $F200

	nop
	nop
	nop
	jsr SubD
	lda $0800

	org $DFFC
	rorg $FFFC
	.word StartD
	.byte "0D"
	
	seg bankE
	org $E000
	rorg $F000
StartE
	lda $0800
	
SubE
	lda #$2A
	sta COLUBK
	rts

	org $E200
	rorg $F200

	nop
	nop
	nop
	jsr SubE
	lda $0800

	org $EFFC
	rorg $FFFC
	.word StartE
	.byte "0E"
	
	seg bankF
	org $F000
	rorg $F000
StartF
	lda $0800
	
SubF
	lda #$2C
	sta COLUBK
	rts

	org $F200
	rorg $F200

	nop
	nop
	nop
	jsr SubF
	lda $0800

	org $FFFC
	rorg $FFFC
	.word StartF
	.byte "0F"
	
	seg bank10
	org $10000
	rorg $F000
Start10
	lda $0800
	
Sub10
	lda #$2E
	sta COLUBK
	rts

	org $10200
	rorg $F200

	nop
	nop
	nop
	jsr Sub10
	lda $0800

	org $10FFC
	rorg $FFFC
	.word Start10
	.byte "10"
	
	seg bank11
	org $11000
	rorg $F000
Start11
	lda $0800
	
Sub11
	lda #$30
	sta COLUBK
	rts

	org $11200
	rorg $F200

	nop
	nop
	nop
	jsr Sub11
	lda $0800

	org $11FFC
	rorg $FFFC
	.word Start11
	.byte "11"
	
	seg bank12
	org $12000
	rorg $F000
Start12
	lda $0800
	
Sub12
	lda #$32
	sta COLUBK
	rts

	org $12200
	rorg $F200

	nop
	nop
	nop
	jsr Sub12
	lda $0800

	org $12FFC
	rorg $FFFC
	.word Start12
	.byte "12"
	
	seg bank13
	org $13000
	rorg $F000
Start13
	lda $0800
	
Sub13
	lda #$34
	sta COLUBK
	rts

	org $13200
	rorg $F200

	nop
	nop
	nop
	jsr Sub13
	lda $0800

	org $13FFC
	rorg $FFFC
	.word Start13
	.byte "13"
	
	seg bank14
	org $14000
	rorg $F000
Start14
	lda $0800
	
Sub14
	lda #$36
	sta COLUBK
	rts

	org $14200
	rorg $F200

	nop
	nop
	nop
	jsr Sub14
	lda $0800

	org $14FFC
	rorg $FFFC
	.word Start14
	.byte "14"
	
	seg bank15
	org $15000
	rorg $F000
Start15
	lda $0800
	
Sub15	lda #$38
	sta COLUBK
	rts

	org $15200
	rorg $F200

	nop
	nop
	nop
	jsr Sub15
	lda $0800

	org $15FFC
	rorg $FFFC
	.word Start15
	.byte "15"
	
	seg bank16
	org $16000
	rorg $F000
Start16
	lda $0800
	
Sub16
	lda #$3A
	sta COLUBK
	rts

	org $16200
	rorg $F200

	nop
	nop
	nop
	jsr Sub16
	lda $0800

	org $16FFC
	rorg $FFFC
	.word Start16
	.byte "16"
	
	seg bank17
	org $17000
	rorg $F000
Start17
	lda $0800
	
Sub17
	lda #$3C
	sta COLUBK
	rts

	org $17200
	rorg $F200

	nop
	nop
	nop
	jsr Sub17
	lda $0800

	org $17FFC
	rorg $FFFC
	.word Start17
	.byte "17"
	
	seg bank18
	org $18000
	rorg $F000
Start18
	lda $0800
	
Sub18
	lda #$3E
	sta COLUBK
	rts

	org $18200
	rorg $F200

	nop
	nop
	nop
	jsr Sub18
	lda $0800

	org $18FFC
	rorg $FFFC
	.word Start18
	.byte "18"
	
	seg bank19
	org $19000
	rorg $F000
Start19
	lda $0800
	
Sub19
	lda #$40
	sta COLUBK
	rts

	org $19200
	rorg $F200

	nop
	nop
	nop
	jsr Sub19
	lda $0800

	org $19FFC
	rorg $FFFC
	.word Start19
	.byte "19"
	
	seg bank1A
	org $1A000
	rorg $F000
Start1A
	lda $0800
	
Sub1A
	lda #$42
	sta COLUBK
	rts

	org $1A200
	rorg $F200

	nop
	nop
	nop
	jsr Sub1A
	lda $0800

	org $1AFFC
	rorg $FFFC
	.word Start1A
	.byte "1A"
	
	seg bank1B
	org $1B000
	rorg $F000
Start1B
	lda $0800
	
Sub1B
	lda #$44
	sta COLUBK
	rts

	org $1B200
	rorg $F200

	nop
	nop
	nop
	jsr Sub1B
	lda $0800

	org $1BFFC
	rorg $FFFC
	.word Start1B
	.byte "1B"
	
	seg bank1C
	org $1C000
	rorg $F000
Start1C
	lda $0800
	
Sub1C
	lda #$46
	sta COLUBK
	rts

	org $1C200
	rorg $F200

	nop
	nop
	nop
	jsr Sub1C
	lda $0800

	org $1CFFC
	rorg $FFFC
	.word Start1C
	.byte "1C"
	
	seg bank1D
	org $1D000
	rorg $F000
Start1D
	lda $0800
	
Sub1D
	lda #$48
	sta COLUBK
	rts

	org $1D200
	rorg $F200

	nop
	nop
	nop
	jsr Sub1D
	lda $0800

	org $1DFFC
	rorg $FFFC
	.word Start1D
	.byte "1D"
	
	seg bank1E
	org $1E000
	rorg $F000
Start1E
	lda $0800
	
Sub1E
	lda #$4A
	sta COLUBK
	rts

	org $1E200
	rorg $F200

	nop
	nop
	nop
	jsr Sub1E
	lda $0800

	org $1EFFC
	rorg $FFFC
	.word Start1E
	.byte "1E"
	
	seg bank1F
	org $1F000
	rorg $F000
Start1F
	lda $0800
	
Sub1F
	lda #$4C
	sta COLUBK
	rts

	org $1F200
	rorg $F200

	nop
	nop
	nop
	jsr Sub1F
	lda $0800

	org $1FFFC
	rorg $FFFC
	.word Start1F
	.byte "1F"
