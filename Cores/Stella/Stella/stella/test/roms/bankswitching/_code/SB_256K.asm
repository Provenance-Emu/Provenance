;;A bankswitching demo for the 256K SuperBanking scheme.  64 4K banks
;;By: Rick Skrbina 5/4/09

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
	
	ldx #1
	ldy #3
	
Picture_Loop
	sta WSYNC
	dey
	bne Picture_Loop
	ldy #3
	jsr Swch1
	inx
	cpx #$40
	bne Picture_Loop
	
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
	
	seg bank20
	org $20000
	rorg $F000
Start20
	lda $0800
	
Sub20
	lda #$4E
	sta COLUBK
	rts

	org $20200
	rorg $F200

	nop
	nop
	nop
	jsr Sub20
	lda $0800

	org $20FFC
	rorg $FFFC
	.word Start20
	.byte "20"
	
	seg bank21
	org $21000
	rorg $F000
Start21
	lda $0800
	
Sub21
	lda #$50
	sta COLUBK
	rts

	org $21200
	rorg $F200

	nop
	nop
	nop
	jsr Sub21
	lda $0800

	org $21FFC
	rorg $FFFC
	.word Start21
	.byte "21"
	
	seg bank22
	org $22000
	rorg $F000
Start22
	lda $0800
	
Sub22
	lda #$52
	sta COLUBK
	rts

	org $22200
	rorg $F200

	nop
	nop
	nop
	jsr Sub22
	lda $0800

	org $22FFC
	rorg $FFFC
	.word Start22
	.byte "22"
	
	seg bank23
	org $23000
	rorg $F000
Start23
	lda $0800
	
Sub23
	lda #$54
	sta COLUBK
	rts

	org $23200
	rorg $F200

	nop
	nop
	nop
	jsr Sub23
	lda $0800

	org $23FFC
	rorg $FFFC
	.word Start23
	.byte "23"
	
	seg bank24
	org $24000
	rorg $F000
Start24
	lda $0800
	
Sub24
	lda #$56
	sta COLUBK
	rts

	org $24200
	rorg $F200

	nop
	nop
	nop
	jsr Sub24
	lda $0800

	org $24FFC
	rorg $FFFC
	.word Start24
	.byte "24"
	
	seg bank25
	org $25000
	rorg $F000
Start25
	lda $0800
	
Sub25
	lda #$58
	sta COLUBK
	rts

	org $25200
	rorg $F200

	nop
	nop
	nop
	jsr Sub25
	lda $0800

	org $25FFC
	rorg $FFFC
	.word Start25
	.byte "25"
	
	seg bank26
	org $26000
	rorg $F000
Start26
	lda $0800
	
Sub26
	lda #$5A
	sta COLUBK
	rts

	org $26200
	rorg $F200

	nop
	nop
	nop
	jsr Sub26
	lda $0800

	org $26FFC
	rorg $FFFC
	.word Start26
	.byte "26"
	
	seg bank27
	org $27000
	rorg $F000
Start27
	lda $0800
	
Sub27
	lda #$5C
	sta COLUBK
	rts

	org $27200
	rorg $F200

	nop
	nop
	nop
	jsr Sub27
	lda $0800

	org $27FFC
	rorg $FFFC
	.word Start27
	.byte "27"
	
	seg bank28
	org $28000
	rorg $F000
Start28
	lda $0800
	
Sub28
	lda #$5E
	sta COLUBK
	rts

	org $28200
	rorg $F200

	nop
	nop
	nop
	jsr Sub28
	lda $0800

	org $28FFC
	rorg $FFFC
	.word Start28
	.byte "28"
	
	seg bank29
	org $29000
	rorg $F000
Start29
	lda $0800
	
Sub29
	lda #$60
	sta COLUBK
	rts

	org $29200
	rorg $F200

	nop
	nop
	nop
	jsr Sub29
	lda $0800

	org $29FFC
	rorg $FFFC
	.word Start29
	.byte "29"
	
	seg bank2A
	org $2A000
	rorg $F000
Start2A
	lda $0800
	
Sub2A
	lda #$62
	sta COLUBK
	rts

	org $2A200
	rorg $F200

	nop
	nop
	nop
	jsr Sub2A
	lda $0800

	org $2AFFC
	rorg $FFFC
	.word Start2A
	.byte "2A"
	
	seg bank2B
	org $2B000
	rorg $F000
Start2B
	lda $0800
	
Sub2B
	lda #$64
	sta COLUBK
	rts

	org $2B200
	rorg $F200

	nop
	nop
	nop
	jsr Sub2B
	lda $0800

	org $2BFFC
	rorg $FFFC
	.word Start2B
	.byte "2B"
	
	seg bank2C
	org $2C000
	rorg $F000
Start2C
	lda $0800
	
Sub2C
	lda #$66
	sta COLUBK
	rts

	org $2C200
	rorg $F200

	nop
	nop
	nop
	jsr Sub2C
	lda $0800

	org $2CFFC
	rorg $FFFC
	.word Start2C
	.byte "2C"
	
	seg bank2D
	org $2D000
	rorg $F000
Start2D
	lda $0800
	
Sub2D
	lda #$68
	sta COLUBK
	rts

	org $2D200
	rorg $F200

	nop
	nop
	nop
	jsr Sub2D
	lda $0800

	org $2DFFC
	rorg $FFFC
	.word Start2D
	.byte "2D"
	
	seg bank2E
	org $2E000
	rorg $F000
Start2E
	lda $0800
	
Sub2E
	lda #$6A
	sta COLUBK
	rts

	org $2E200
	rorg $F200

	nop
	nop
	nop
	jsr Sub2E
	lda $0800

	org $2EFFC
	rorg $FFFC
	.word Start2E
	.byte "2E"
	
	seg bank2F
	org $2F000
	rorg $F000
Start2F
	lda $0800
	
Sub2F
	lda #$6C
	sta COLUBK
	rts

	org $2F200
	rorg $F200

	nop
	nop
	nop
	jsr Sub2F
	lda $0800

	org $2FFFC
	rorg $FFFC
	.word Start2F
	.byte "2F"
	
	seg bank30
	org $30000
	rorg $F000
Start30
	lda $0800
	
Sub30
	lda #$6E
	sta COLUBK
	rts

	org $30200
	rorg $F200

	nop
	nop
	nop
	jsr Sub30
	lda $0800

	org $30FFC
	rorg $FFFC
	.word Start30
	.byte "30"
	
	seg bank31
	org $31000
	rorg $F000
Start31
	lda $0800
	
Sub31
	lda #$70
	sta COLUBK
	rts

	org $31200
	rorg $F200

	nop
	nop
	nop
	jsr Sub31
	lda $0800

	org $31FFC
	rorg $FFFC
	.word Start31
	.byte "31"
	
	seg bank32
	org $32000
	rorg $F000
Start32
	lda $0800
	
Sub32
	lda #$72
	sta COLUBK
	rts

	org $32200
	rorg $F200

	nop
	nop
	nop
	jsr Sub32
	lda $0800

	org $32FFC
	rorg $FFFC
	.word Start32
	.byte "32"
	
	seg bank33
	org $33000
	rorg $F000
Start33
	lda $0800
	
Sub33
	lda #$74
	sta COLUBK
	rts

	org $33200
	rorg $F200

	nop
	nop
	nop
	jsr Sub33
	lda $0800

	org $33FFC
	rorg $FFFC
	.word Start33
	.byte "33"
	
	seg bank34
	org $34000
	rorg $F000
Start34
	lda $0800
	
Sub34
	lda #$76
	sta COLUBK
	rts

	org $34200
	rorg $F200

	nop
	nop
	nop
	jsr Sub34
	lda $0800

	org $34FFC
	rorg $FFFC
	.word Start34
	.byte "34"
	
	seg bank35
	org $35000
	rorg $F000
Start35
	lda $0800
	
Sub35
	lda #$78
	sta COLUBK
	rts

	org $35200
	rorg $F200

	nop
	nop
	nop
	jsr Sub35
	lda $0800

	org $35FFC
	rorg $FFFC
	.word Start35
	.byte "35"
	
	seg bank36
	org $36000
	rorg $F000
Start36
	lda $0800
	
Sub36
	lda #$7A
	sta COLUBK
	rts

	org $36200
	rorg $F200

	nop
	nop
	nop
	jsr Sub36
	lda $0800

	org $36FFC
	rorg $FFFC
	.word Start36
	.byte "36"
	
	seg bank37
	org $37000
	rorg $F000
Start37
	lda $0800
	
Sub37
	lda #$7C
	sta COLUBK
	rts

	org $37200
	rorg $F200

	nop
	nop
	nop
	jsr Sub37
	lda $0800

	org $37FFC
	rorg $FFFC
	.word Start37
	.byte "37"
	
	seg bank38
	org $38000
	rorg $F000
Start38
	lda $0800
	
Sub38
	lda #$7E
	sta COLUBK
	rts

	org $38200
	rorg $F200

	nop
	nop
	nop
	jsr Sub38
	lda $0800

	org $38FFC
	rorg $FFFC
	.word Start38
	.byte "38"
	
	seg bank39
	org $39000
	rorg $F000
Start39
	lda $0800
	
Sub39
	lda #$80
	sta COLUBK
	rts

	org $39200
	rorg $F200

	nop
	nop
	nop
	jsr Sub39
	lda $0800

	org $39FFC
	rorg $FFFC
	.word Start39
	.byte "39"
	
	seg bank3A
	org $3A000
	rorg $F000
Start3A
	lda $0800
	
Sub3A
	lda #$82
	sta COLUBK
	rts

	org $3A200
	rorg $F200

	nop
	nop
	nop
	jsr Sub3A
	lda $0800

	org $3AFFC
	rorg $FFFC
	.word Start3A
	.byte "3A"
	
	seg bank3B
	org $3B000
	rorg $F000
Start3B
	lda $0800
	
Sub3B
	lda #$84
	sta COLUBK
	rts

	org $3B200
	rorg $F200

	nop
	nop
	nop
	jsr Sub3B
	lda $0800

	org $3BFFC
	rorg $FFFC
	.word Start3B
	.byte "3B"
	
	seg bank3C
	org $3C000
	rorg $F000
Start3C
	lda $0800
	
Sub3C
	lda #$86
	sta COLUBK
	rts

	org $3C200
	rorg $F200

	nop
	nop
	nop
	jsr Sub3C
	lda $0800

	org $3CFFC
	rorg $FFFC
	.word Start3C
	.byte "3C"
	
	seg bank3D
	org $3D000
	rorg $F000
Start3D
	lda $0800
	
Sub3D
	lda #$88
	sta COLUBK
	rts

	org $3D200
	rorg $F200

	nop
	nop
	nop
	jsr Sub3D
	lda $0800

	org $3DFFC
	rorg $FFFC
	.word Start3D
	.byte "3D"
	
	seg bank3E
	org $3E000
	rorg $F000
Start3E
	lda $0800
	
Sub3E
	lda #$8A
	sta COLUBK
	rts

	org $3E200
	rorg $F200

	nop
	nop
	nop
	jsr Sub3E
	lda $0800

	org $3EFFC
	rorg $FFFC
	.word Start3E
	.byte "3E"
	
	seg bank3F
	org $3F000
	rorg $F000
Start3F
	lda $0800
	
Sub3F
	lda #$8C
	sta COLUBK
	rts

	org $3F200
	rorg $F200

	nop
	nop
	nop
	jsr Sub3F
	lda $0800

	org $3FFFC
	rorg $FFFC
	.word Start3F
	.byte "3F"
