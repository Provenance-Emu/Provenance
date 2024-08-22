	.zp
pointer:	.ds 2
temp:		.ds 1
scroll:		.ds 2
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


	ldx #$04
DelayLoop0:
DelayLoop1:
	lda $0000
	and #$20
	beq DelayLoop1
	dex
	bne DelayLoop0

	; Copy palette into RAM
	stz $402
	stz $403
	tai $404,$3000,$400

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


	;
	; Hexdump palette
	;
	lda #$00
	sta <pointer+0
	lda #$30
	sta <pointer+1

HDLoop:
	lda <pointer+0
	asl a
	and #$3E
	tax

	lda <pointer+1
	sta <temp

	lda <pointer+0
	lsr <temp
	ror a
	lsr <temp
	ror a
	lsr <temp
	ror a
	lsr <temp
	ror a
	lsr <temp
	ror a
	and #$3F
	tay

	lda [pointer]
	jsr PrintHexU8

	clc
	lda <pointer+0
	adc #$01
	sta <pointer+0
	lda <pointer+1
	adc #$00
	sta <pointer+1
	cmp #$34
	bne HDLoop

	lda #$03
	sta $1000
	; CLR=0, SEL=1
	lda #$01
	sta $1000

	stz <scroll+0
	stz <scroll+1
	ldx #$00
Infinite:
WaitVB:
	lda $0000
	and #$20
	beq WaitVB

	lda $1000
	eor #$0E
	pha
	lsr a
	lda <scroll+0
	sbc #$00
	sta <scroll+0
	lda <scroll+1
	sbc #$00
	sta <scroll+1
	pla
	lsr a
	lsr a
	lsr a
	lda <scroll+0
	adc #$00
	sta <scroll+0
	lda <scroll+1
	adc #$00
	sta <scroll+1

        ; BYR
        st0 #$08
	lda <scroll+0
	sta $0002
	lda <scroll+1
	sta $0003

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

	.org $4000
	.bank 1
Font:	.incbin "../font.bin"


