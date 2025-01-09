;
; cl65 -t none hdd_driver.asm -o hdd_driver.bin && cat hdd_driver.bin | hexdump -v -e "15/1 \"0x%02x, \"1/1 \" 0x%02x,\n\"" > hdd_driver.bin.h
;

;
; Reference Beneath Apple ProDOS, 6-6, 7-13
;

.setcpu "6502"
.org $0

COMMAND_CODE	  = $0042
UNIT_NUMBER	  = $0043
IO_BUFFER         = $0044
BLOCK_NUMBER      = $0046

CMD_STATUS	= $00
CMD_READ	= $01
CMD_WRITE	= $02
CMD_FORMAT	= $03

ERROR_NONE	= $00
ERROR_IO	= $27
ERROR_NO_DEVICE = $28
ERROR_WRITE_PROTECT= $2B

STATUS_WP    = $01
STATUS_BUSY  = $40
STATUS_ERROR = $80

;
;
;

HDC_STATUS	  = $C080
HDC_DATA_READ	  = $C081
HDC_BLOCK_COUNT_L = $C082
HDC_BLOCK_COUNT_H = $C083

HDC_MAGIC_WRITE	  = $C084
HDC_DATA_WRITE	  = $C085
HDC_LBA_L	  = $C086
HDC_LBA_H	  = $C087

boot_entry:
	lda #$20	;
	ldy #$00	;
	lda #$03	;
	lda #$3C	;

	sty BLOCK_NUMBER+0
	sty BLOCK_NUMBER+1
	sty IO_BUFFER+0
	lda #$08
	sta IO_BUFFER+1

	iny
	sty COMMAND_CODE

	jsr $FF58
	tsx
	dex
	txs
	lda #<(boot1 - 1)
	pha
	bne driver_entry

	boot1:
	bcs boot_entry

	jmp $0801

prodos_unit_check:
	lda UNIT_NUMBER
	bpl driver_entry
error_no_dev:
	sec
	lda #ERROR_NO_DEVICE
	rts

prodos_entry:
	sec
	bcs prodos_unit_check
halfass_smartport_entry:
	;
	; Supports only READ BLOCK and WRITE BLOCK,
	; writes to ProDOS zero page argument addresses,
	; and returns error codes that aren't really right.
	;
	cld
	clc
	pla
	sta IO_BUFFER+0
	adc #$03
	tax
	pla
	sta IO_BUFFER+1 
	adc #$00
	pha
	txa
	pha

	ldy #$01
	lda (IO_BUFFER), Y
	sta COMMAND_CODE
	iny
	lda (IO_BUFFER), Y
	tax
	iny
	lda (IO_BUFFER), Y
	stx IO_BUFFER+0
	sta IO_BUFFER+1

	iny
	lda (IO_BUFFER), Y
	sta BLOCK_NUMBER+0
	iny
	lda (IO_BUFFER), Y
	sta BLOCK_NUMBER+1
	iny
	lda (IO_BUFFER), Y
	bne error_io

	ldy #$01
	lda (IO_BUFFER), Y
	cmp #$01
	bne error_no_dev
	iny
	lda (IO_BUFFER), Y
	tax
	iny
	lda (IO_BUFFER), Y
	stx IO_BUFFER+0
	sta IO_BUFFER+1

	ldy COMMAND_CODE
	beq error_io

	lda UNIT_NUMBER

driver_entry:
	sei
	ldx #$60
	stx UNIT_NUMBER
	jsr UNIT_NUMBER
	sta UNIT_NUMBER
	tsx
	dex
	txs
	pla
	and #$07
	asl A
	asl A
	asl A
	asl A
	tax

	lda BLOCK_NUMBER+0
	sta HDC_LBA_L, X
	lda BLOCK_NUMBER+1
	sta HDC_LBA_H, X

	wait_read_ready:
	asl HDC_STATUS, X
	bmi wait_read_ready
	bcs error_io

	lda COMMAND_CODE
	beq status
	cmp #$03
	bcs error_io
	cmp #CMD_WRITE
	bne read_block
write_block:
	lsr HDC_STATUS, X
	bcc write_block_no_wp
error_write_protect:
	lda #ERROR_WRITE_PROTECT
	rts
write_block_no_wp:
	ldy #$00
	write_loop:
	tya
	eor #$AA
	sta HDC_MAGIC_WRITE, X
	lda (IO_BUFFER), Y
	sta HDC_DATA_WRITE, X
	inc IO_BUFFER+1
	lda (IO_BUFFER), Y
	sta HDC_DATA_WRITE, X
	dec IO_BUFFER+1
	iny
	bne write_loop

	wait_write_done:
	asl HDC_STATUS, X
	bmi wait_write_done
	bcc error_none
error_io:
	sec
	lda #ERROR_IO
	rts

;
;
;
status:
	lsr HDC_STATUS, X
	lda HDC_BLOCK_COUNT_H, X
	tay
	lda HDC_BLOCK_COUNT_L, X
	tax
	bcs error_write_protect
error_none:
	lda #ERROR_NONE
	rts

;
;
;
read_block:
	ldy #$00
	read_loop:
	lda HDC_DATA_READ, X
	sta (IO_BUFFER), Y
	inc IO_BUFFER+1
	lda HDC_DATA_READ, X
	sta (IO_BUFFER), Y
	dec IO_BUFFER+1
	iny
	bne read_loop

	bcc error_none

.res $FC - *, $00
.word $0000
.byte $47
.byte <prodos_entry
