;
;
;
init_crc:
 lda #$FF
 sta crc7+1
 sta crc6+1
 sta crc5+1
 sta crc4+1
 sta crc3+1
 sta crc2+1
 sta crc1+1
 sta crc0+1
 rts

;
;
;
print_crc:
 lda crc7+1
 eor #$FF
 jsr PRBYTE

 lda crc6+1
 eor #$FF
 jsr PRBYTE

 lda crc5+1
 eor #$FF
 jsr PRBYTE

 lda crc4+1
 eor #$FF
 jsr PRBYTE

 lda crc3+1
 eor #$FF
 jsr PRBYTE

 lda crc2+1
 eor #$FF
 jsr PRBYTE

 lda crc1+1
 eor #$FF
 jsr PRBYTE

 lda crc0+1
 eor #$FF
 jsr PRBYTE

 jsr CROUT

 rts

;
; A: byte to process
;
update_crc:
 crc7: eor #$00
 tax

 crc6: lda #$00
 eor crctab7, X
 sta crc7+1

 crc5: lda #$00
 eor crctab6, X
 sta crc6+1

 crc4: lda #$00
 eor crctab5, X
 sta crc5+1

 crc3: lda #$00
 eor crctab4, X
 sta crc4+1

 crc2: lda #$00
 eor crctab3, X
 sta crc3+1

 crc1: lda #$00
 eor crctab2, X
 sta crc2+1

 crc0: lda #$00
 eor crctab1, X
 sta crc1+1

 lda crctab0, X
 sta crc0+1

 rts

crctab0:
 .bin 0, $100, "../crctab-0.bin"

crctab1:
 .bin 0, $100, "../crctab-1.bin"

crctab2:
 .bin 0, $100, "../crctab-2.bin"

crctab3:
 .bin 0, $100, "../crctab-3.bin"

crctab4:
 .bin 0, $100, "../crctab-4.bin"

crctab5:
 .bin 0, $100, "../crctab-5.bin"

crctab6:
 .bin 0, $100, "../crctab-6.bin"

crctab7:
 .bin 0, $100, "../crctab-7.bin"

