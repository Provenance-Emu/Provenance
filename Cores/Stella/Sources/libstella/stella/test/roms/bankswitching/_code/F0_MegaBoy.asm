;;A bankswitching demo for the F0 (Dynacom MegaBoy) BS technique.  16 4K banks (64K total)
;;3/26/09 By: Rick Skrbina

	processor 6502
	include "vcs.h"
	include "macro.h"
	
	seg.u vars
	org $80
	
	seg bank0
	org $0000
	rorg $F000
Start0
	CLEAN_START

	
	lda #$0F
	sta COLUBK
	
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
	
	lda #$0F
	sta COLUBK	
	
	ldy #9
Picture0
	sta WSYNC
	dey
	bne Picture0
	
	lda #1
	jsr Switch_Banks
	
	ldy #9
Picture1
	sta WSYNC
	dey
	bne Picture1
	
	lda #2
	jsr Switch_Banks
	
	ldy #9
Picture2
	sta WSYNC
	dey
	bne Picture2
	
	lda #3
	jsr Switch_Banks
	
	ldy #9
Picture3
	sta WSYNC
	dey
	bne Picture3
	
	lda #4
	jsr Switch_Banks
	
	ldy #9
Picture4
	sta WSYNC
	dey
	bne Picture4
	
	lda #5
	jsr Switch_Banks
	
	ldy #9
Picture5
	sta WSYNC
	dey
	bne Picture5
	
	lda #6
	jsr Switch_Banks
	
	ldy #9
Picture6
	sta WSYNC
	dey
	bne Picture6
	
	lda #7
	jsr Switch_Banks
	
	ldy #9
Picture7
	sta WSYNC
	dey
	bne Picture7
	
	lda #8
	jsr Switch_Banks
	
	ldy #9
Picture8
	sta WSYNC
	dey
	bne Picture8
	
	lda #9
	jsr Switch_Banks
	
	ldy #9
Picture9
	sta WSYNC
	dey
	bne Picture9
	
	lda #10
	jsr Switch_Banks
	
	ldy #9
Picture10
	sta WSYNC
	dey
	bne Picture10
	
	lda #11
	jsr Switch_Banks
	
	ldy #9
Picture11
	sta WSYNC
	dey
	bne Picture11
	
	lda #9
	jsr Switch_Banks
	
	ldy #9
Picture12
	sta WSYNC
	dey
	bne Picture12
	
	lda #13
	jsr Switch_Banks
	
	ldy #9
Picture13
	sta WSYNC
	dey
	bne Picture13
	
	lda #14
	jsr Switch_Banks
	
	ldy #9
Picture14
	sta WSYNC
	dey
	bne Picture14
	
	lda #15
	jsr Switch_Banks
	
	ldy #9
Picture15
	sta WSYNC
	dey
	bne Picture15
	
	lda #2
	sta VBLANK
	
	ldy #30
OverScan
	sta WSYNC
	dey
	bne OverScan
	
	jmp Start_Frame
	
	org $0E00
	rorg $FE00
	
Switch_Banks	
	cmp Identity0
	beq Stayin0
	sta $1FF0
	jmp Switch_Banks
Stayin0
	rts


Identity0
	.byte $00

	org $0FFC
	rorg $FFFC
	.word Start0
	.byte "B0"
	
	seg Bank1
	org $1000
	rorg $F000
Start1
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp B1_swch
	
B1_Color
	lda #$1F
	sta COLUBK
	
	lda #0
	jmp B1_swch

	org $1E00
	rorg $FE00
B1_swch
	cmp Identity1
	beq Stayin1
	sta $1FF0
	jmp B1_swch
Stayin1
	jmp B1_Color
	

Identity1
	.byte $01
	
	org $1FFC
	.word Start1
	.byte "B1"
	
	seg Bank2
	org $2000
	rorg $F000
Start2
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp B2_swch
	
B2_Color

	lda #$2F
	sta COLUBK

	lda #0
	jmp B2_swch
	
	org $2E00
	rorg $FE00
B2_swch
	cmp Identity2
	beq Stayin2
	sta $1FF0
	jmp B2_swch
Stayin2
	jmp B2_Color

Identity2
	.byte $02

	org $2FFC
	rorg $FFFC
	.word Start2
	.byte "B2"
	
	seg Bank3
	org $3000
Start3
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp B3_swch
	
B3_Color
	lda #$3F
	sta COLUBK
	lda #0
	jmp B3_swch
	
	org $3E00
	rorg $FE00
B3_swch
	cmp Identity3
	beq Stayin2
	sta $1FF0
	jmp B3_swch
Stayin3
	jmp B3_Color

Identity3
	.byte $03

	org $3FFC
	rorg $FFFC
	.word Start3
	.byte "B3"
	
	seg Bank4
	org $4000
	rorg $F000
Start4
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp B4_swch
	
B4_Color

	lda #$4F
	sta COLUBK

	lda #0
	jmp B4_swch
	
	org $4E00
	rorg $FE00
	
B4_swch
	cmp Identity4
	beq Stayin4
	sta $1FF0
	jmp B4_swch
Stayin4
	jmp B4_Color

Identity4
	.byte $04

	org $4FFC
	rorg $FFFC
	.word Start4
	.byte "B4"
	
	seg Bank5
	org $5000
	rorg $F000
Start5
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp B5_swch
	
B5_Color

	lda #$5F
	sta COLUBK

	lda #0
	jmp B5_swch
	
	org $5E00
	rorg $FE00
	
B5_swch
	cmp Identity5
	beq Stayin5
	sta $1FF0
	jmp B5_swch
Stayin5
	jmp B5_Color

Identity5
	.byte $05

	org $5FFC
	rorg $FFFC
	.word Start5
	.byte "B5"
	
	seg Bank6
	org $6000
	rorg $F000
Start6
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp B6_swch
	
B6_Color

	lda #$6F
	sta COLUBK

	lda #0
	jmp B6_swch
	
	org $6E00
	rorg $FE00
	
B6_swch
	cmp Identity6
	beq Stayin6
	sta $1FF0
	jmp B6_swch
Stayin6
	jmp B6_Color

Identity6
	.byte $06

	org $6FFC
	rorg $FFFC
	.word Start6
	.byte "B6"
	
	seg Bank7
	org $7000
	rorg $F000
Start7
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp B7_swch
	
B7_Color

	lda #$7F
	sta COLUBK

	lda #0
	jmp B7_swch

	org $7E00
	rorg $FE00
	
B7_swch
	cmp Identity7
	beq Stayin7
	sta $1FF0
	jmp B7_swch
Stayin7
	jmp B7_Color
	
Identity7
	.byte $07

	org $7FFC
	rorg $FFFC
	.word Start7
	.byte "B7"
	
	seg Bank8
	org $8000
	rorg $F000
Start8
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp B8_swch
	
B8_Color

	lda #$8F
	sta COLUBK

	lda #0
	jmp B8_swch
	
	org $8E00
	rorg $FE00
	
B8_swch
	cmp Identity8
	beq Stayin8
	sta $1FF0
	jmp B8_swch
Stayin8
	jmp B8_Color

Identity8
	.byte $08

	org $8FFC
	rorg $FFFC
	.word Start8
	.byte "B8"
	
	seg Bank9
	org $9000
	rorg $F000
Start9
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp B9_swch
	
B9_Color

	lda #$9F
	sta COLUBK

	lda #0
	jmp B9_swch
	
	org $9E00
	rorg $FE00
	
B9_swch
	cmp Identity9
	beq Stayin9
	sta $1FF0
	jmp B9_swch
Stayin9
	jmp B9_Color

Identity9
	.byte $09

	org $9FFC
	rorg $FFFC
	.word Start9
	.byte "B9"
	
	seg BankA
	org $A000
	rorg $F000
StartA
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp BA_swch
	
BA_Color

	lda #$AF
	sta COLUBK

	lda #0
	jmp BA_swch
	
	org $AE00
	rorg $FE00
	
BA_swch
	cmp IdentityA
	beq StayinA
	sta $1FF0
	jmp BA_swch
StayinA
	jmp BA_Color

IdentityA
	.byte $0A

	org $AFFC
	rorg $FFFC
	.word StartA
	.byte "BA"
	
	seg BankB
	org $B000
	rorg $F000
StartB
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp BB_swch
	
BB_Color

	lda #$BF
	sta COLUBK
	lda #0
	jmp BB_swch
	
	org $BE00
	rorg $FE00
	
BB_swch
	cmp IdentityB
	beq StayinB
	sta $1FF0
	jmp BB_swch
StayinB
	jmp BB_Color

IdentityB
	.byte $0B

	org $BFFC
	rorg $FFFC
	.word StartB
	.byte "BB"
	
	seg BankC
	org $C000
	rorg $F000
StartC
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp BC_swch
	
BC_Color

	lda #$CF
	sta COLUBK

	lda #0
	jmp BC_swch
	
	org $CE00
	rorg $FE00
	
BC_swch
	cmp IdentityC
	beq StayinC
	sta $1FF0
	jmp BC_swch
StayinC
	jmp BC_Color

IdentityC
	.byte $0C
	
	org $CFFC
	rorg $FFFC
	.word StartC
	.byte "BC"
	
	seg BankD
	org $D000
	rorg $F000
StartD
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp BD_swch
	
BD_Color

	lda #$DF
	sta COLUBK

	lda #0
	jmp BD_swch
	
	org $DE00
	rorg $FE00
	
BD_swch
	cmp IdentityD
	beq StayinD
	sta $1FF0
	jmp BD_swch
StayinD
	jmp BD_Color

IdentityD
	.byte $0D

	org $DFFC
	rorg $FFFC
	.word StartD
	.byte "BD"
	
	seg BankE
	org $E000
	rorg $F000
StartE
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp BE_swch
	
BE_Color

	lda #$EF
	sta COLUBK

	lda #0
	jmp BE_swch
	
	org $EE00
	rorg $FE00
	
BE_swch
	cmp IdentityE
	beq StayinE
	sta $1FF0
	jmp BE_swch
StayinE
	jmp BE_Color

IdentityE

	.byte $0E

	org $EFFC
	rorg $FFFC
	.word StartE
	.byte "BE"
	
	seg BankF
	org $F000
	rorg $F000
StartF
	CLEAN_START
	lda #$F0
	sta $FE
	lda #0
	jmp BF_swch
	
BF_Color

	lda #$FF
	sta COLUBK

	lda #0
	jmp BF_swch

	org $FE00
	rorg $FE00
	
BF_swch
	cmp IdentityF
	beq StayinF
	sta $1FF0
	jmp BF_swch
StayinF
	jmp BF_Color
	
IdentityF
	.byte $0F
	
	org $FFFC
	rorg $FFFC
	.word StartF
	.byte "BF"
	
