#*
#* several drawing related functions for Allegrex MIPS
#* (C) notaz, 2007-2008
#*
#* This work is licensed under the terms of MAME license.
#* See COPYING file in the top-level directory.
#*
#* this is highly specialized, be careful if changing related C code!
#*

.set noreorder # don't reorder any instructions
.set noat      # don't use $at

.text
.align 4

# void amips_clut(unsigned short *dst, unsigned char *src, unsigned short *pal, int count)

.global amips_clut

amips_clut:
    srl     $a3, 2
amips_clut_loop:
    lbu     $t0, 0($a1)           # tried lw here, no improvement noticed
    lbu     $t1, 1($a1)
    lbu     $t2, 2($a1)
    lbu     $t3, 3($a1)
    sll     $t0, 1
    sll     $t1, 1
    sll     $t2, 1
    sll     $t3, 1
    addu    $t0, $a2
    addu    $t1, $a2
    addu    $t2, $a2
    addu    $t3, $a2
    lhu     $t0, 0($t0)
    lhu     $t1, 0($t1)
    lhu     $t2, 0($t2)
    lhu     $t3, 0($t3)
    ins     $t0, $t1, 16, 16      # ins rt, rs, pos, size - Insert size bits starting
    ins     $t2, $t3, 16, 16      #  from the LSB of rs into rt starting at position pos
    sw      $t0, 0($a0)
    sw      $t2, 4($a0)
    addiu   $a0, 8
    addiu   $a3, -1
    bnez    $a3, amips_clut_loop
    addiu   $a1, 4
    jr      $ra
    nop


.global amips_clut_6bit

amips_clut_6bit:
    srl     $a3, 2
    li      $t4, 0
    li      $t5, 0
    li      $t6, 0
    li      $t7, 0
amips_clut_loop6:
    lbu     $t0, 0($a1)           # tried lw here, no improvement noticed
    lbu     $t1, 1($a1)
    lbu     $t2, 2($a1)
    lbu     $t3, 3($a1)
    ins     $t4, $t0, 1, 6
    ins     $t5, $t1, 1, 6
    ins     $t6, $t2, 1, 6
    ins     $t7, $t3, 1, 6
    addu    $t0, $t4, $a2
    addu    $t1, $t5, $a2
    addu    $t2, $t6, $a2
    addu    $t3, $t7, $a2
    lhu     $t0, 0($t0)
    lhu     $t1, 0($t1)
    lhu     $t2, 0($t2)
    lhu     $t3, 0($t3)
    ins     $t0, $t1, 16, 16      # ins rt, rs, pos, size - Insert size bits starting
    ins     $t2, $t3, 16, 16      #  from the LSB of rs into rt starting at position pos
    sw      $t0, 0($a0)
    sw      $t2, 4($a0)
    addiu   $a0, 8
    addiu   $a3, -1
    bnez    $a3, amips_clut_loop6
    addiu   $a1, 4
    jr      $ra
    nop


# $a0 - pd, $a1 - tile word, $a2 - pal
# ext rt, rs, pos, size  // Extract size bits from position pos in rs and store in rt 

.macro TilePixelPrep shift dreg offs
.if \shift
    ext     \dreg, $a1, \shift, 4
.else
    andi    \dreg, $a1, 0xf
.endif
.if \offs
    sltu    $t8, $0, \dreg
    ins     $t9, $t8, \offs, 1
.else
    sltu    $t9, $0, \dreg
.endif
.endm

.macro TileStartCode
    sll     $a1, $a1, 1
    lui     $t1, %hi(Pico+0x10000)
    addu    $a1, $a1, $t1
    lw      $a1, %lo(Pico+0x10000)($a1)  # Pico.vram + addr
    beqz    $a1, TileEmpty
    rotr    $t1, $a1, 4
    beq     $t1, $a1, SingleColor
    and     $v0, $0                      # not empty tile
.endm

.macro TileEndCode
    xori    $t8, $t9, 0xff
    beqz    $t8, tile11111111            # common case
    lui     $v1, %hi(HighCol)
    lui     $t8, %hi(TileTable)
    ins     $t8, $t9, 2, 8
    lw      $t8, %lo(TileTable)($t8)
    lw      $v1, %lo(HighCol)($v1)
    jr      $t8
    addu    $a0, $v1
.endm


.global TileNorm

TileNorm:
    TileStartCode
    TilePixelPrep 12, $t0, 0
    TilePixelPrep  8, $t1, 1
    TilePixelPrep  4, $t2, 2
    TilePixelPrep  0, $t3, 3
    TilePixelPrep 28, $t4, 4
    TilePixelPrep 24, $t5, 5
    TilePixelPrep 20, $t6, 6
    TilePixelPrep 16, $t7, 7
    TileEndCode


.global TileFlip

TileFlip:
    TileStartCode
    TilePixelPrep 16, $t0, 0
    TilePixelPrep 20, $t1, 1
    TilePixelPrep 24, $t2, 2
    TilePixelPrep 28, $t3, 3
    TilePixelPrep  0, $t4, 4
    TilePixelPrep  4, $t5, 5
    TilePixelPrep  8, $t6, 6
    TilePixelPrep 12, $t7, 7
    TileEndCode


SingleColor:
    lui     $t9, %hi(HighCol)
    lw      $t9, %lo(HighCol)($t9)
    andi    $t0, $a1, 0xf
    or      $t0, $t0, $a2
    addu    $a0, $t9
    sb      $t0, 0($a0)
    sb      $t0, 1($a0)
    sb      $t0, 2($a0)
    sb      $t0, 3($a0)
    sb      $t0, 4($a0)
    sb      $t0, 5($a0)
    sb      $t0, 6($a0)
    jr      $ra
    sb      $t0, 7($a0)

TileEmpty:
    jr      $ra
    or      $v0, $0, 1                   # empty tile

tile11111111:
    lw      $v1, %lo(HighCol)($v1)
    or      $t0, $t0, $a2
    addu    $a0, $v1
    sb      $t0, 0($a0)
tile11111110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile11111100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile11111000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
tile11110000:
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
tile11100000:
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
tile11000000:
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
tile10000000:
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11111101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11111011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11111010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11111001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11110111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11110110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile11110100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11110101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11110011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11110010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11110001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11101111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11101110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile11101100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile11101000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11101101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11101011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11101010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11101001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11100111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11100110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile11100100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11100101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11100011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11100010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11100001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11011111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11011110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile11011100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile11011000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
tile11010000:
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11011101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11011011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11011010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11011001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11010111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11010110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile11010100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11010101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11010011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11010010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11010001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11001111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11001110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile11001100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile11001000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11001101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11001011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11001010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11001001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11000111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11000110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile11000100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11000101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11000011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile11000010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile11000001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t6, $t6, $a2
    sb      $t6, 6($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10111111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10111110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile10111100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile10111000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
tile10110000:
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
tile10100000:
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10111101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10111011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10111010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10111001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10110111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10110110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile10110100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10110101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10110011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10110010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10110001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10101111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10101110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile10101100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile10101000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10101101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10101011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10101010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10101001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10100111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10100110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile10100100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10100101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10100011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10100010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10100001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10011111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10011110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile10011100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile10011000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
tile10010000:
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10011101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10011011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10011010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10011001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10010111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10010110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile10010100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10010101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10010011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10010010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10010001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10001111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10001110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile10001100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile10001000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10001101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10001011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10001010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10001001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10000111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10000110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile10000100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10000101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10000011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile10000010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile10000001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t7, $t7, $a2
    jr      $ra
    sb      $t7, 7($a0)
tile01111111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01111110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile01111100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile01111000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
tile01110000:
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
tile01100000:
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
tile01000000:
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile00000000:
tile01111101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01111011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01111010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01111001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01110111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01110110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile01110100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01110101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01110011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01110010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01110001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01101111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01101110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile01101100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile01101000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01101101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01101011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01101010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01101001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01100111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01100110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile01100100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01100101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01100011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01100010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01100001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t5, $t5, $a2
    sb      $t5, 5($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01011111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01011110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile01011100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile01011000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
tile01010000:
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01011101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01011011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01011010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01011001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01010111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01010110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile01010100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01010101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01010011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01010010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01010001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01001111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01001110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile01001100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile01001000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01001101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01001011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01001010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01001001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01000111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01000110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile01000100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01000101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01000011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile01000010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile01000001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t6, $t6, $a2
    jr      $ra
    sb      $t6, 6($a0)
tile00111111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00111110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile00111100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile00111000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
tile00110000:
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
tile00100000:
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00111101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00111011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00111010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00111001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00110111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00110110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile00110100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00110101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00110011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00110010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00110001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t4, $t4, $a2
    sb      $t4, 4($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00101111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00101110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile00101100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile00101000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00101101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00101011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00101010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00101001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00100111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00100110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile00100100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00100101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00100011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00100010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00100001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t5, $t5, $a2
    jr      $ra
    sb      $t5, 5($a0)
tile00011111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00011110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile00011100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile00011000:
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
tile00010000:
    or      $t4, $t4, $a2
    jr      $ra
    sb      $t4, 4($a0)
tile00011101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    jr      $ra
    sb      $t4, 4($a0)
tile00011011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00011010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    jr      $ra
    sb      $t4, 4($a0)
tile00011001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    sb      $t3, 3($a0)
    or      $t4, $t4, $a2
    jr      $ra
    sb      $t4, 4($a0)
tile00010111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00010110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile00010100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    jr      $ra
    sb      $t4, 4($a0)
tile00010101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t4, $t4, $a2
    jr      $ra
    sb      $t4, 4($a0)
tile00010011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00010010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t4, $t4, $a2
    jr      $ra
    sb      $t4, 4($a0)
tile00010001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t4, $t4, $a2
    jr      $ra
    sb      $t4, 4($a0)
tile00001111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00001110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile00001100:
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
tile00001000:
    or      $t3, $t3, $a2
    jr      $ra
    sb      $t3, 3($a0)
tile00001101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    sb      $t2, 2($a0)
    or      $t3, $t3, $a2
    jr      $ra
    sb      $t3, 3($a0)
tile00001011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00001010:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
    or      $t3, $t3, $a2
    jr      $ra
    sb      $t3, 3($a0)
tile00001001:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t3, $t3, $a2
    jr      $ra
    sb      $t3, 3($a0)
tile00000111:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00000110:
    or      $t1, $t1, $a2
    sb      $t1, 1($a0)
tile00000100:
    or      $t2, $t2, $a2
    jr      $ra
    sb      $t2, 2($a0)
tile00000101:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
    or      $t2, $t2, $a2
    jr      $ra
    sb      $t2, 2($a0)
tile00000011:
    or      $t0, $t0, $a2
    sb      $t0, 0($a0)
tile00000010:
    or      $t1, $t1, $a2
    jr      $ra
    sb      $t1, 1($a0)
tile00000001:
    or      $t0, $t0, $a2
    jr      $ra
    sb      $t0, 0($a0)

.data
.align 4

TileTable:
  .long 000000000000, tile00000001, tile00000010, tile00000011, tile00000100, tile00000101, tile00000110, tile00000111
  .long tile00001000, tile00001001, tile00001010, tile00001011, tile00001100, tile00001101, tile00001110, tile00001111
  .long tile00010000, tile00010001, tile00010010, tile00010011, tile00010100, tile00010101, tile00010110, tile00010111
  .long tile00011000, tile00011001, tile00011010, tile00011011, tile00011100, tile00011101, tile00011110, tile00011111
  .long tile00100000, tile00100001, tile00100010, tile00100011, tile00100100, tile00100101, tile00100110, tile00100111
  .long tile00101000, tile00101001, tile00101010, tile00101011, tile00101100, tile00101101, tile00101110, tile00101111
  .long tile00110000, tile00110001, tile00110010, tile00110011, tile00110100, tile00110101, tile00110110, tile00110111
  .long tile00111000, tile00111001, tile00111010, tile00111011, tile00111100, tile00111101, tile00111110, tile00111111
  .long tile01000000, tile01000001, tile01000010, tile01000011, tile01000100, tile01000101, tile01000110, tile01000111
  .long tile01001000, tile01001001, tile01001010, tile01001011, tile01001100, tile01001101, tile01001110, tile01001111
  .long tile01010000, tile01010001, tile01010010, tile01010011, tile01010100, tile01010101, tile01010110, tile01010111
  .long tile01011000, tile01011001, tile01011010, tile01011011, tile01011100, tile01011101, tile01011110, tile01011111
  .long tile01100000, tile01100001, tile01100010, tile01100011, tile01100100, tile01100101, tile01100110, tile01100111
  .long tile01101000, tile01101001, tile01101010, tile01101011, tile01101100, tile01101101, tile01101110, tile01101111
  .long tile01110000, tile01110001, tile01110010, tile01110011, tile01110100, tile01110101, tile01110110, tile01110111
  .long tile01111000, tile01111001, tile01111010, tile01111011, tile01111100, tile01111101, tile01111110, tile01111111
  .long tile10000000, tile10000001, tile10000010, tile10000011, tile10000100, tile10000101, tile10000110, tile10000111
  .long tile10001000, tile10001001, tile10001010, tile10001011, tile10001100, tile10001101, tile10001110, tile10001111
  .long tile10010000, tile10010001, tile10010010, tile10010011, tile10010100, tile10010101, tile10010110, tile10010111
  .long tile10011000, tile10011001, tile10011010, tile10011011, tile10011100, tile10011101, tile10011110, tile10011111
  .long tile10100000, tile10100001, tile10100010, tile10100011, tile10100100, tile10100101, tile10100110, tile10100111
  .long tile10101000, tile10101001, tile10101010, tile10101011, tile10101100, tile10101101, tile10101110, tile10101111
  .long tile10110000, tile10110001, tile10110010, tile10110011, tile10110100, tile10110101, tile10110110, tile10110111
  .long tile10111000, tile10111001, tile10111010, tile10111011, tile10111100, tile10111101, tile10111110, tile10111111
  .long tile11000000, tile11000001, tile11000010, tile11000011, tile11000100, tile11000101, tile11000110, tile11000111
  .long tile11001000, tile11001001, tile11001010, tile11001011, tile11001100, tile11001101, tile11001110, tile11001111
  .long tile11010000, tile11010001, tile11010010, tile11010011, tile11010100, tile11010101, tile11010110, tile11010111
  .long tile11011000, tile11011001, tile11011010, tile11011011, tile11011100, tile11011101, tile11011110, tile11011111
  .long tile11100000, tile11100001, tile11100010, tile11100011, tile11100100, tile11100101, tile11100110, tile11100111
  .long tile11101000, tile11101001, tile11101010, tile11101011, tile11101100, tile11101101, tile11101110, tile11101111
  .long tile11110000, tile11110001, tile11110010, tile11110011, tile11110100, tile11110101, tile11110110, tile11110111
  .long tile11111000, tile11111001, tile11111010, tile11111011, tile11111100, tile11111101, tile11111110, tile11111111

# vim:filetype=mips
