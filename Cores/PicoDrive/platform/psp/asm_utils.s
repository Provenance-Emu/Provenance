# vim:filetype=mips

# some asm utils
# (c) Copyright 2007, Grazvydas "notaz" Ignotas
# All Rights Reserved

.set noreorder
.set noat

.data
.align 4

.byte  0,  1,  6, 11, 16, 21, 26, 31 # -4
.byte  0,  2,  7, 12, 16, 21, 26, 31 # -3
.byte  0,  3,  7, 12, 17, 22, 26, 31 # -2
.byte  0,  4,  8, 13, 17, 22, 26, 31 # -1
pal_gmtab:
.byte  0,  5, 10, 15, 16, 21, 26, 31 #  0
.byte  0,  6, 10, 15, 19, 23, 27, 31
.byte  0,  7, 11, 15, 19, 23, 27, 31
.byte  0,  8, 12, 16, 19, 23, 27, 31
.byte  0,  9, 12, 16, 20, 24, 27, 31
.byte  0, 10, 13, 17, 20, 24, 27, 31
.byte  0, 10, 14, 17, 21, 24, 28, 31
.byte  0, 11, 15, 18, 21, 24, 28, 31
.byte  0, 12, 15, 18, 22, 25, 28, 31
.byte  0, 13, 16, 19, 22, 25, 28, 31
.byte  0, 14, 17, 20, 22, 25, 28, 31 # 10
.byte  0, 15, 17, 20, 23, 26, 28, 31
.byte  0, 16, 18, 21, 23, 26, 28, 31
.byte  0, 16, 19, 21, 24, 26, 29, 31
.byte  0, 17, 20, 22, 24, 26, 29, 31
.byte  0, 18, 20, 22, 25, 27, 29, 31
.byte  0, 19, 21, 23, 25, 27, 29, 31 # 16

.text
.align 4

# bbbb bggg gggr rrrr

#.global pal_gmtab
.global do_pal_convert # dest, src, gammaa_val, black_lvl

do_pal_convert:
    bnez    $a2, dpc_gma
    li      $t0, 64/2
    bnez    $a3, dpc_gma
    lui     $t2, 0x00e
    ori     $t2, 0x00e
    lui     $t3, 0x006
    ori     $t3, 0x006
    lui     $t4, 0x0e0
    ori     $t4, 0x0e0
    lui     $t6, 0xe00
    ori     $t6, 0xe00
    lui     $t7, 0x600
    ori     $t7, 0x600

dpc_loop:
    lw      $v0, 0($a1)
    addiu   $a1, 4
    and     $v1, $v0, $t2   # r
    sll     $v1, 1
    and     $t9, $v0, $t3
    srl     $t9, 1
    or      $v1, $t9        # r
    and     $t9, $v0, $t4   # g
    sll     $t8, $t9, 3
    or      $v1, $t8
    or      $v1, $t9        # g
    and     $t9, $v0, $t6   # b
    sll     $t9, 4
    or      $v1, $t9
    and     $t9, $v0, $t7
    sll     $t9, 2
    or      $v1, $t9        # b
    sw      $v1, 0($a0)
    addiu   $t0, -1
    bnez    $t0, dpc_loop
    addiu   $a0, 4

    jr      $ra
    nop

# non-zero gamma
dpc_gma:
    slt     $t2, $a2, $0
    sll     $a2, 3
    lui     $t1, %hi(pal_gmtab)
    addiu   $t1, %lo(pal_gmtab)
    addu    $a2, $t1
    beqz    $a3, dpc_gma_loop
    sb      $0,  0($a2)        # black level 0
    bnez    $t2, dpc_gma_loop  # gamma < 0, keep black at 0
    addiu   $a3, -2
    slt     $t2, $a3, $0       # t2 = a3_orig == 1 ? 1 : 0
    lb      $t1, 1($a2)
    addiu   $t1, -2
    srlv    $t1, $t1, $t2
    sb      $t1, 0($a2)

dpc_gma_loop:
    lw      $v0, 0($a1)
    addiu   $a1, 4
    ext     $v1, $v0, 1, 3
    addu    $v1, $a2
    lb      $v1, 0($v1)
    ext     $t1, $v0, 5, 3
    addu    $t1, $a2
    lb      $t1, 0($t1)
    ext     $t2, $v0, 9, 3
    addu    $t2, $a2
    lb      $t2, 0($t2)
    ext     $t3, $v0, 17, 3
    addu    $t3, $a2
    lb      $t3, 0($t3)
    ext     $t4, $v0, 21, 3
    addu    $t4, $a2
    lb      $t4, 0($t4)
    ext     $t5, $v0, 25, 3
    addu    $t5, $a2
    lb      $t5, 0($t5)
    ins     $v1, $t1,  6, 5
    ins     $v1, $t2, 11, 5
    ins     $v1, $t3, 16, 5
    ins     $v1, $t4, 22, 5
    ins     $v1, $t5, 27, 5
    sw      $v1, 0($a0)
    addiu   $t0, -1
    bnez    $t0, dpc_gma_loop
    addiu   $a0, 4

    jr      $ra
    nop

