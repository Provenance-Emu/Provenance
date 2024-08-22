	.zp
Icounter:	.ds 1	; Arg
Fcounter:	.ds 1	; Flags(table)

        .code
	.bank 0
	
	.org $FFF6
	.dw irq2
	.dw irq1
	.dw timer
	.dw nmi
	.dw reset
	.org $F000

irq2:
irq1:
timer:
nmi:	rti

reset:
        sei
        csh
        cld
        ldx #$FF
        txs

	; Map I/O to first page.
        lda #$FF
        tam #0

	; ...and RAM to the second page.
        lda #$F8
        tam #1

	; Clear RAM to 0.
        stz $2000
        tii $2000,$2001,$1FFF

	; Transfer code to RAM for self-modifying goodness.
	tii $F000, $3000, $1000
	lda #$F8
	tam #7

	; Zero sound master balance.
        stz $0801
;;
;;
;;

	ldx #$0F
VCL:
	stx $0000
	stz $0002
	stz $0003
	dex
	bpl VCL

	; CR
	st0 #$05
	st1 #$C8

	; MWR
	st0 #$09
	st1 #$60
	st2 #$00

	; HSR
	st0 #$0A
	st1 #$02
	st2 #$0B

	; HDR
	st0 #$0B
	st1 #$3F
	st2 #$04

	; VSR
	st0 #$0C
	st1 #$02
	st2 #$0F

	; VDR
	st0 #$0D
	st1 #$EF


	; VCR
	st0 #$0E
	st1 #$04


	; Init VCE
	lda #$06
	sta $400
	stz $402
	stz $403

	ldx #$00
PaletteLoop:
	stx $402
	stz $403
	stx $404
	stx $405
	inx
	bne PaletteLoop

	st0 #$00
	st1 #$00
	st2 #$00

	st0 #$02
	ldy #$00
VRAMLoop:
	ldx #$00
VRAMSubLoop:
	txa
	rol a
	stz $0002
	stz $0003
	inx
	bne VRAMSubLoop
	iny
	bne VRAMLoop

	jsr LoadFont

	
	sed		; Enable decimal mode
	lda #$02
	tam #4
	stz <Fcounter
LoopSuperOuter:

	lda <Fcounter
	ldx #$02
	ldy #$02
	jsr PrintHexU8

	stz <Icounter
LoopOuter:
	lda <Icounter
	ldx #$05
	ldy #$02
	jsr PrintHexU8

	clx
LoopInner:
	php
	pla
	and #$3C
	ldy <Fcounter
	ora FlagsTab, Y
	pha
	txa		; Load up Acounter into accumulator
	plp		; Pull up test flags.  Note: remember to make sure there's nothing to alter flags between here and the SBC...

	DMATHOP <Icounter
	php
CmpA:	cmp $8000, X
	bne Fail
	pla
CmpP:	cmp $9000, X
	bne Fail

	inx
	bne LoopInner

	;
	; Incremement high bytes here...
	;
	inc CmpA+2
	ldx CmpP+2
	inx
	cpx #$A0
	stx CmpP+2
	bne SkipCmpReset

	ldx #$80
	stx CmpA+2
	ldx #$90
	stx CmpP+2
	tma #4
	inc A
	tam #4

SkipCmpReset:
	inc <Icounter
	bne LoopOuter

	ldx <Fcounter
	inx
	stx <Fcounter
	cpx #$04
	bne LoopSuperOuter
	cld		; Disable decimal mode.

Pass:
	jmp Infinite

Fail:	
	txa
	ldx #$08
	ldy #$02
	jsr PrintHexU8

	jmp Infinite

Infinite:
	jmp Infinite

LoadFont:
	pha
	tma #02
	pha
	lda #$01
	tam #02

	st0 #$00
	st1 #$00
	st2 #$20

	st0 #$02
	tia $4000, $0002, $2000

	pla
	tam #02
	pla
	rts

PrintHexU8:	; A=character, X=x coord/8, Y=y coord/8
	pha
	pha
	lsr A
	lsr A
	lsr A
	lsr A
	jsr PrintHexU4
	pla
	and #$0F
	inx
	jsr PrintHexU4
	dex
	pla
	rts

PrintHexU4:	; A=character, X=x coord/8, Y=y coord/8
	pha
	phx
	phy

	st0 #$00

	sax
	asl A
	say
	lsr A
	say
	ror A
	sax

	stx $0002
	sty $0003

	st0 #$02
	tax
	lda HexTab, X
	sta $0002
	st2 #$02

	ply
	plx
	pla
	rts

HexTab:		.db '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'

FlagsTab:	.db $00, $01, $C2, $C3

	.org $4000
	.bank 1
Font:	.incbin "../font.bin"


