;;A bankswitching demo for the EF scheme. 16 4K banks accessed by $FFE0-$FFEF
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
VerticalBlank
	sta WSYNC
	dey
	bne VerticalBlank
	
	lda #0
	sta VBLANK
	
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
	
	ldy #12
PictureE
	sta WSYNC
	dey
	bne PictureE

	jsr SwchF
	
	ldy #12
PictureF
	sta WSYNC
	dey
	bne PictureF
	
	lda #2
	sta VBLANK
	
	ldy #30
OverScan
	sta WSYNC
	dey
	bne OverScan
	
	jmp Start_Frame
	
	org $0400
	rorg $F400
Swch1
	lda $FFE1
Swch2
	lda $FFE2
Swch3
	lda $FFE3
	rts
	rts
	rts
	rts
	rts
	rts
	rts
	rts
	
	org $0415
	rorg $F415
Swch4
	lda $FFE4
Swch5
	lda $FFE5
Swch6
	lda $FFE6
	rts
	rts
	rts
	rts
	rts
	rts
	rts
	rts
	
	org $0430
	rorg $F430
Swch7
	lda $FFE7
Swch8
	lda $FFE8
Swch9
	lda $FFE9
	rts
	rts
	rts
	rts
	rts
	rts
	rts
	rts
	
	org $0445
	rorg $F445
SwchA
	lda $FFEA
SwchB
	lda $FFEB
SwchC
	lda $FFEC
	rts
	rts
	rts
	rts
	rts
	rts
	rts
	rts
	
	org $0460
	rorg $F460
SwchD
	lda $FFED
SwchE
	lda $FFEE
SwchF
	lda $FFEF
	rts
	rts
	rts
	rts
	rts
	rts
	rts
	rts
	
	org $0FFC
	.word Start0
	.byte "00"
	
	seg bank1
	org $1000
	rorg $F000
Start1
	lda $FFE0
	
Sub1
	lda #$1F
	sta COLUBK
	rts

	org $1400
	rorg $F400
	nop
	nop
	nop
	jsr Sub1
	lda $FFE0

	org $1FFC
	rorg $FFFC
	.word Start1
	.byte "01"
	
	seg bank2
	org $2000
	rorg $F000
Start2
	lda $FFE0
	
Sub2
	lda #$2F
	sta COLUBK
	rts

	org $2400
	rorg $F400
	nop
	nop
	nop
	nop
	nop
	nop
	jsr Sub2
	lda $FFE0

	org $2FFC
	rorg $FFFC
	.word Start2
	.byte "02"
	
	seg bank3
	org $3000
	rorg $F000
Start3
	lda $FFE0
	
Sub3
	lda #$3F
	sta COLUBK
	rts

	org $3400
	rorg $F400
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	jsr Sub3
	lda $FFE0

	org $3FFC
	rorg $FFFC
	.word Start3
	.byte "03"
	
	seg bank4
	org $4000
	rorg $F000
Start4
	lda $FFE0
	
Sub4
	lda #$4F
	sta COLUBK
	rts
	
	org $4415
	rorg $F415
	nop
	nop
	nop
	jsr Sub4
	lda $FFE0

	org $4FFC
	rorg $FFFC
	.word Start4
	.byte "04"
	
	seg bank5
	org $5000
	rorg $F000
Start5
	lda $FFE0
	
Sub5
	lda #$5F
	sta COLUBK
	rts
	
	org $5415
	rorg $F415
	nop
	nop
	nop
	nop
	nop
	nop
	jsr Sub5
	lda $FFE0

	org $5FFC
	rorg $FFFC
	.word Start5
	.byte "05"
	
	seg bank6
	org $6000
	rorg $F000
Start6
	lda $FFE0
	
Sub6
	lda #$66
	sta COLUBK
	rts
	
	org $6415
	rorg $F415
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	jsr Sub6
	lda $FFE0

	org $6FFC
	rorg $FFFC
	.word Start6
	.byte "06"
	
	seg bank7
	org $7000
	rorg $F000
Start7

	lda $FFE0
	
Sub7
	lda #$7F
	sta COLUBK
	rts
	
	org $7430
	rorg $F430
	nop
	nop
	nop
	jsr Sub7
	lda $FFE0

	org $7FFC
	rorg $FFFC
	.word Start7
	.byte "07"
	
	seg bank8
	org $8000
	rorg $F000
Start8
	lda $FFE0
	
Sub8
	lda #$8F
	sta COLUBK
	rts
	
	org $8430
	rorg $F430
	nop
	nop
	nop
	nop
	nop
	nop
	jsr Sub8
	lda $FFE0

	org $8FFC
	rorg $FFFC
	.word Start8
	.byte "08"
	
	seg bank9
	org $9000
	rorg $F000
Start9
	lda $FFE0
	
Sub9
	lda #$9F
	sta COLUBK
	rts
	
	org $9430
	rorg $F430
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	jsr Sub9
	lda $FFE0

	org $9FFC
	rorg $FFFC
	.word Start9
	.byte "09"
	
	seg bankA
	org $A000
	rorg $F000
StartA
	lda $FFE0
	
SubA
	lda #$AF
	sta COLUBK
	rts
	
	org $A445
	rorg $F445
	nop
	nop
	nop
	jsr SubA
	lda $FFE0

	org $AFFC
	rorg $FFFC
	.word StartA
	.byte "0A"
	
	seg bankB
	org $B000
	rorg $F000
StartB
	lda $FFE0
	
SubB
	lda #$BF
	sta COLUBK
	rts
	
	org $B445
	rorg $F445
	nop
	nop
	nop
	nop
	nop
	nop
	jsr SubB
	lda $FFE0

	org $BFFC
	rorg $FFFC
	.word StartB
	.byte "0B"
	
	seg bankC
	org $C000
	rorg $F000
StartC
	lda $FFE0
	
SubC
	lda #$CF
	sta COLUBK
	rts
	
	org $C445
	rorg $F445
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	jsr SubC
	lda $FFE0


	org $CFFC
	rorg $FFFC
	.word StartC
	.byte "0C"
	
	seg bankD
	org $D000
	rorg $F000
StartD
	lda $FFE0
	
SubD
	lda #$DF
	sta COLUBK
	rts
	
	org $D460
	rorg $F460
	nop
	nop
	nop
	jsr SubD
	lda $FFE0

	org $DFFC
	rorg $FFFC
	.word StartD
	.byte "0D"
	
	seg bankE
	org $E000
	rorg $F000
StartE
	lda $FFE0
	
SubE
	lda #$EF
	sta COLUBK
	rts
	
	org $E460
	rorg $F460
	nop
	nop
	nop
	nop
	nop
	nop
	jsr SubE
	lda $FFE0

	org $EFFC
	rorg $FFFC
	.word StartE
	.byte "0E"
	
	seg bankF
	org $F000
	rorg $F000
StartF
	lda $FFE0
	
SubF
	lda #$FF
	sta COLUBK
	rts
	
	org $F460
	rorg $F460
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	jsr SubF
	lda $FFE0

	org $FFFC
	rorg $FFFC
	.word StartF
	.byte "0F"
