; 
; xa -o decimal.bin decimal.asm && ../bintodsk decimal.bin decimal.dsk
;
PRBYTE = $FDDA
HOME = $FC58
CROUT = $FD8E

* = $800
 .byte $10

entry:
 jsr HOME

instr_loop:
 jsr init_crc
 ;
 ;
 ;
 instridx: ldx #$01
 lda instrtab, X
 sta instr+0

 lda #$07
 sta flags+1
flags_loop:
arg_loop:
accum_loop:

 flags: ldx #$00
 lda flagstab, X
 pha
 accum: lda #$00
 plp
 instr: adc #$00
 php
 jsr update_crc
 pla
 jsr update_crc

 inc accum+1
 bne accum_loop  
 inc instr+1
 bne arg_loop

 dec flags+1
 bpl flags_loop

 cld
 jsr print_crc

 dec instridx+1
 bpl instr_loop

end:
 jmp end

#include "../crc.inc"

instrtab:
 .byte $E9, $69

flagstab:
 .byt $00, $01, $08, $09, $f6, $f7, $fe, $ff
