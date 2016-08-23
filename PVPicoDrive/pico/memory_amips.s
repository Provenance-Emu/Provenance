#*
#* memory handlers with banking support
#* (C) notaz, 2007-2008
#*
#* This work is licensed under the terms of MAME license.
#* See COPYING file in the top-level directory.
#*

# OUT OF DATE

.set noreorder
.set noat

.text
.align 4

# default jump tables

m_read8_def_table:
    .long   m_read8_rom0    # 0x000000 - 0x07FFFF
    .long   m_read8_rom1    # 0x080000 - 0x0FFFFF
    .long   m_read8_rom2    # 0x100000 - 0x17FFFF
    .long   m_read8_rom3    # 0x180000 - 0x1FFFFF
    .long   m_read8_rom4    # 0x200000 - 0x27FFFF
    .long   m_read8_rom5    # 0x280000 - 0x2FFFFF
    .long   m_read8_rom6    # 0x300000 - 0x37FFFF
    .long   m_read8_rom7    # 0x380000 - 0x3FFFFF
    .long   m_read8_rom8    # 0x400000 - 0x47FFFF - for all those large ROM hacks
    .long   m_read8_rom9    # 0x480000 - 0x4FFFFF
    .long   m_read8_romA    # 0x500000 - 0x57FFFF
    .long   m_read8_romB    # 0x580000 - 0x5FFFFF
    .long   m_read8_romC    # 0x600000 - 0x67FFFF
    .long   m_read8_romD    # 0x680000 - 0x6FFFFF
    .long   m_read8_romE    # 0x700000 - 0x77FFFF
    .long   m_read8_romF    # 0x780000 - 0x7FFFFF
    .long   m_read8_rom10   # 0x800000 - 0x87FFFF
    .long   m_read8_rom11   # 0x880000 - 0x8FFFFF
    .long   m_read8_rom12   # 0x900000 - 0x97FFFF
    .long   m_read8_rom13   # 0x980000 - 0x9FFFFF
    .long   m_read8_misc    # 0xA00000 - 0xA7FFFF
    .long   m_read_null     # 0xA80000 - 0xAFFFFF
    .long   m_read_null     # 0xB00000 - 0xB7FFFF
    .long   m_read_null     # 0xB80000 - 0xBFFFFF
    .long   m_read8_vdp     # 0xC00000 - 0xC7FFFF
    .long   m_read8_vdp     # 0xC80000 - 0xCFFFFF
    .long   m_read8_vdp     # 0xD00000 - 0xD7FFFF
    .long   m_read8_vdp     # 0xD80000 - 0xDFFFFF
    .long   m_read8_ram     # 0xE00000 - 0xE7FFFF
    .long   m_read8_ram     # 0xE80000 - 0xEFFFFF
    .long   m_read8_ram     # 0xF00000 - 0xF7FFFF
    .long   m_read8_ram     # 0xF80000 - 0xFFFFFF

m_read16_def_table:
    .long   m_read16_rom0    # 0x000000 - 0x07FFFF
    .long   m_read16_rom1    # 0x080000 - 0x0FFFFF
    .long   m_read16_rom2    # 0x100000 - 0x17FFFF
    .long   m_read16_rom3    # 0x180000 - 0x1FFFFF
    .long   m_read16_rom4    # 0x200000 - 0x27FFFF
    .long   m_read16_rom5    # 0x280000 - 0x2FFFFF
    .long   m_read16_rom6    # 0x300000 - 0x37FFFF
    .long   m_read16_rom7    # 0x380000 - 0x3FFFFF
    .long   m_read16_rom8    # 0x400000 - 0x47FFFF
    .long   m_read16_rom9    # 0x480000 - 0x4FFFFF
    .long   m_read16_romA    # 0x500000 - 0x57FFFF
    .long   m_read16_romB    # 0x580000 - 0x5FFFFF
    .long   m_read16_romC    # 0x600000 - 0x67FFFF
    .long   m_read16_romD    # 0x680000 - 0x6FFFFF
    .long   m_read16_romE    # 0x700000 - 0x77FFFF
    .long   m_read16_romF    # 0x780000 - 0x7FFFFF
    .long   m_read16_rom10   # 0x800000 - 0x87FFFF
    .long   m_read16_rom11   # 0x880000 - 0x8FFFFF
    .long   m_read16_rom12   # 0x900000 - 0x97FFFF
    .long   m_read16_rom13   # 0x980000 - 0x9FFFFF
    .long   m_read16_misc    # 0xA00000 - 0xA7FFFF
    .long   m_read_null      # 0xA80000 - 0xAFFFFF
    .long   m_read_null      # 0xB00000 - 0xB7FFFF
    .long   m_read_null      # 0xB80000 - 0xBFFFFF
    .long   m_read16_vdp     # 0xC00000 - 0xC7FFFF
    .long   m_read16_vdp     # 0xC80000 - 0xCFFFFF
    .long   m_read16_vdp     # 0xD00000 - 0xD7FFFF
    .long   m_read16_vdp     # 0xD80000 - 0xDFFFFF
    .long   m_read16_ram     # 0xE00000 - 0xE7FFFF
    .long   m_read16_ram     # 0xE80000 - 0xEFFFFF
    .long   m_read16_ram     # 0xF00000 - 0xF7FFFF
    .long   m_read16_ram     # 0xF80000 - 0xFFFFFF

m_read32_def_table:
    .long   m_read32_rom0    # 0x000000 - 0x07FFFF
    .long   m_read32_rom1    # 0x080000 - 0x0FFFFF
    .long   m_read32_rom2    # 0x100000 - 0x17FFFF
    .long   m_read32_rom3    # 0x180000 - 0x1FFFFF
    .long   m_read32_rom4    # 0x200000 - 0x27FFFF
    .long   m_read32_rom5    # 0x280000 - 0x2FFFFF
    .long   m_read32_rom6    # 0x300000 - 0x37FFFF
    .long   m_read32_rom7    # 0x380000 - 0x3FFFFF
    .long   m_read32_rom8    # 0x400000 - 0x47FFFF
    .long   m_read32_rom9    # 0x480000 - 0x4FFFFF
    .long   m_read32_romA    # 0x500000 - 0x57FFFF
    .long   m_read32_romB    # 0x580000 - 0x5FFFFF
    .long   m_read32_romC    # 0x600000 - 0x67FFFF
    .long   m_read32_romD    # 0x680000 - 0x6FFFFF
    .long   m_read32_romE    # 0x700000 - 0x77FFFF
    .long   m_read32_romF    # 0x780000 - 0x7FFFFF
    .long   m_read32_rom10   # 0x800000 - 0x87FFFF
    .long   m_read32_rom11   # 0x880000 - 0x8FFFFF
    .long   m_read32_rom12   # 0x900000 - 0x97FFFF
    .long   m_read32_rom13   # 0x980000 - 0x9FFFFF
    .long   m_read32_misc    # 0xA00000 - 0xA7FFFF
    .long   m_read_null      # 0xA80000 - 0xAFFFFF
    .long   m_read_null      # 0xB00000 - 0xB7FFFF
    .long   m_read_null      # 0xB80000 - 0xBFFFFF
    .long   m_read32_vdp     # 0xC00000 - 0xC7FFFF
    .long   m_read32_vdp     # 0xC80000 - 0xCFFFFF
    .long   m_read32_vdp     # 0xD00000 - 0xD7FFFF
    .long   m_read32_vdp     # 0xD80000 - 0xDFFFFF
    .long   m_read32_ram     # 0xE00000 - 0xE7FFFF
    .long   m_read32_ram     # 0xE80000 - 0xEFFFFF
    .long   m_read32_ram     # 0xF00000 - 0xF7FFFF
    .long   m_read32_ram     # 0xF80000 - 0xFFFFFF


# #############################################################################

.bss
.align 4

# used tables
m_read8_table:
    .skip 32*4

m_read16_table:
    .skip 32*4

m_read32_table:
    .skip 32*4


# #############################################################################

.text
.align 4

.global PicoMemReset
.global PicoRead8
.global PicoRead16
.global PicoRead32
.global PicoWriteRomHW_SSF2

.global m_read8_def_table
.global m_read8_table

.macro PicoMemResetCopyDef dst_table src_table
    lui     $t0, %hi(\dst_table)
    addiu   $t0, %lo(\dst_table)
    lui     $t1, %hi(\src_table)
    addiu   $t1, %lo(\src_table)
    li      $t2, 32
1:
    lw      $t3, 0($t1)
    sw      $t3, 0($t0)
    addiu   $t2, -1
    addiu   $t1, 4
    bnez    $t2, 1b
    addiu   $t0, 4
.endm

# $t4 = 4
.macro PicoMemResetRomArea dst_table ar_label
    lui     $t0, %hi(\dst_table)
    addiu   $t0, %lo(\dst_table)
    lui     $t1, %hi(\ar_label)
    addiu   $t1, %lo(\ar_label)
    li      $t2, 20
1:
    beq     $t2, $v1, 2f
    addiu   $t2, -1
    sll     $t3, $t2, 2
    beq     $t2, $t4, 1b           # do not touch the SRAM area
    addu    $t3, $t0
    j       1b
    sw      $t1, 0($t3)
2:
.endm


PicoMemReset:
    lui     $v1, %hi(Pico+0x22204)
    lw      $v1, %lo(Pico+0x22204)($v1)  # romsize
    lui     $t0, 8
    addu    $v1, $t0
    addiu   $v1, -1
    srl     $v1, 19

    PicoMemResetCopyDef m_read8_table  m_read8_def_table
    PicoMemResetCopyDef m_read16_table m_read16_def_table
    PicoMemResetCopyDef m_read32_table m_read32_def_table

    # update memhandlers according to ROM size
    li      $t4, 4
    PicoMemResetRomArea m_read8_table  m_read8_above_rom
    PicoMemResetRomArea m_read16_table m_read16_above_rom
    PicoMemResetRomArea m_read32_table m_read32_above_rom

    jr      $ra
    nop

# #############################################################################

.macro PicoReadJump table
    lui     $t0, %hi(\table)
    srl     $t1, $a0, 19
    ins     $t0, $t1, 2, 5
    lw      $t0, %lo(\table)($t0)
    ins     $a0, $0,  24, 8
    jr      $t0
    nop
.endm

PicoRead8: # u32 a
    PicoReadJump m_read8_table

PicoRead16: # u32 a
    PicoReadJump m_read16_table

PicoRead32: # u32 a
    PicoReadJump m_read32_table

# #############################################################################

m_read_null:
    jr      $ra
    li      $v0, 0

m_read_neg1:
    jr      $ra
    addiu   $v0, $0, 0xffff

# loads &Pico.rom to $t3
.macro m_read_rom_try_sram is200000 size
    lui     $t2, %hi(SRam)
    addiu   $t2, %lo(SRam)
    lui     $t3, %hi(Pico+0x22200)
    lw      $t1, 8($t2)     # SRam.end
.if \is200000
    ins     $a0, $0,  19, 13
    lui     $t4, 0x20
    or      $a0, $t4
.endif
    subu    $t4, $a0, $t1
    bgtz    $t4, 1f
    addiu   $t3, %lo(Pico+0x22200)
    lw      $t1, 4($t2)     # SRam.start
    subu    $t4, $t1, $a0
    bgtz    $t4, 1f
    nop
    lb      $t1, 0x11($t3)  # Pico.m.sram_reg
    andi    $t4, $t1, 5
    beqz    $t4, 1f
    nop
.if \size == 8
    j       SRAMRead
    nop
.elseif \size == 16
    sw      $ra, -4($sp)
    jal     SRAMRead16
    addiu   $sp, -4
    lw      $ra, 0($sp)
    jr      $ra
    addiu   $sp, 4
.else
    addiu   $sp, -8
    sw      $ra, 0($sp)
    sw      $a0, 4($sp)
    jal     SRAMRead16
    nop
    lw      $a0, 4($sp)
    sw      $v0, 4($sp)
    jal     SRAMRead16
    addiu   $a0, 2
    lw      $v1, 4($sp)
    lw      $ra, 0($sp)
    addiu   $sp, 8
    jr      $ra
    ins     $v0, $v1, 16, 16
.endif
# m_read_nosram:
1:
.endm

.macro m_read8_rom sect
    lui     $t0, %hi(Pico+0x22200)
    lw      $t0, %lo(Pico+0x22200)($t0)  # rom
    xori    $a0, 1
    ins     $a0, $0,  19, 13
.if \sect
    lui     $t1, 8*\sect
    addu    $a0, $t1
.endif
    addu    $t0, $a0
    jr      $ra
    lb      $v0, 0($t0)
.endm


m_read8_rom0: # 0x000000 - 0x07ffff
    m_read8_rom 0

m_read8_rom1: # 0x080000 - 0x0fffff
    m_read8_rom 1

m_read8_rom2: # 0x100000 - 0x17ffff
    m_read8_rom 2

m_read8_rom3: # 0x180000 - 0x1fffff
    m_read8_rom 3

m_read8_rom4: # 0x200000 - 0x27ffff, SRAM area
    m_read_rom_try_sram 1 8
    lw      $t1, 4($t3)     # romsize
    subu    $t4, $t1, $a0
    blez    $t4, m_read_null
    lw      $t1, 0($t3)     # rom
    xori    $a0, 1
    addu    $t1, $a0
    jr      $ra
    lb      $v0, 0($t1)

m_read8_rom5: # 0x280000 - 0x2fffff
    m_read8_rom 5

m_read8_rom6: # 0x300000 - 0x37ffff
    m_read8_rom 6

m_read8_rom7: # 0x380000 - 0x3fffff
    m_read8_rom 7

m_read8_rom8: # 0x400000 - 0x47ffff
    m_read8_rom 8

m_read8_rom9: # 0x480000 - 0x4fffff
    m_read8_rom 9

m_read8_romA: # 0x500000 - 0x57ffff
    m_read8_rom 0xA

m_read8_romB: # 0x580000 - 0x5fffff
    m_read8_rom 0xB

m_read8_romC: # 0x600000 - 0x67ffff
    m_read8_rom 0xC

m_read8_romD: # 0x680000 - 0x6fffff
    m_read8_rom 0xD

m_read8_romE: # 0x700000 - 0x77ffff
    m_read8_rom 0xE

m_read8_romF: # 0x780000 - 0x7fffff
    m_read8_rom 0xF

m_read8_rom10: # 0x800000 - 0x87ffff
    m_read8_rom 0x10

m_read8_rom11: # 0x880000 - 0x8fffff
    m_read8_rom 0x11

m_read8_rom12: # 0x900000 - 0x97ffff
    m_read8_rom 0x12

m_read8_rom13: # 0x980000 - 0x9fffff
    m_read8_rom 0x13


m_read8_misc:
    srl     $t0, $a0, 5
    sll     $t0, $t0, 5
    lui     $t1, 0xa1
    bne     $t0, $t1, m_read8_misc2
    andi    $t0, $a0, 0x1e
m_read8_misc_io:
    beqz    $t0, m_read8_misc_hwreg
    sub     $t1, $t0, 4
    bgtz    $t1, m_read8_misc_ioports
    nop
    slti    $a0, $t0, 4
    xori    $a0, 1
    j       PadRead
    nop

m_read8_misc_hwreg:
    lui     $v0, %hi(Pico+0x2220f)
    jr      $ra
    lb      $v0, %lo(Pico+0x2220f)($v0)

m_read8_misc_ioports:
    lui     $v0, %hi(Pico+0x22000)
    ins     $v0, $t0, 0, 5
    jr      $ra
    lb      $v0, %lo(Pico+0x22000)($v0)

m_read8_misc2:
    lui     $t0, 0xa1
    ori     $t0, 0x1100
    bne     $a0, $t0, m_read8_misc3
    srl     $t0, $a0, 16
    j       z80ReadBusReq

m_read8_misc3:
    addiu   $t0, 0xff60       # expecting 0xa0 to get 0
    bnez    $t0, m_read8_misc4

    # z80 area
    andi    $t0, $a0, 0x4000
    bnez    $t0, m_read8_z80_misc
    andi    $t0, $a0, 0x6000
    j       z80Read8          # z80 RAM

m_read8_z80_misc:
    addiu   $t0, 0xc000       # expecting 0x4000 to get 0
    bnez    $t0, m_read_neg1  # invalid
    nop
    j       ym2612_read_local_68k
    nop

m_read8_fake_ym2612:
    lb      $v0, %lo(Pico+0x22208)($t0) # Pico.m.rotate
    addiu   $t1, $v0, 1
    jr      $ra
    sb      $t1, %lo(Pico+0x22208)($t0)

# delay slot friendly
.macro m_read8_call16 funcname is_func_ptr=0
.if \is_func_ptr
    lui     $t1, %hi(\funcname)
    lw      $t1, %lo(\funcname)($t1)
.endif
    andi    $t0, $a0, 1
    beqz    $t0, 1f
    li      $a1, 8      # not always needed, but shouln't cause problems
.if \is_func_ptr
    jr      $t1
.else
    j       \funcname   # odd address
.endif
    nop
1:
    addiu   $sp, -4
    sw      $ra, 0($sp)
.if \is_func_ptr
    jalr    $t1
.else
    jal     \funcname
.endif
    xori    $a0, 1
    lw      $ra, 0($sp)
    addiu   $sp, 4
    jr      $ra
    srl     $v0, 8
.endm

m_read8_misc4:
    # if everything else fails, use generic handler
    m_read8_call16 OtherRead16

m_read8_vdp:
    ext     $t0, $a0, 16, 3
    andi    $t1, $a0, 0xe0
    or      $t0, $t1
    bnez    $t0, m_read_null # invalid address
    nop
    j       PicoVideoRead8
    nop

m_read8_ram:
    lui     $t0, %hi(Pico)
    ins     $t0, $a0, 0, 16
    xori    $t0, 1
    jr      $ra
    lb      $v0, %lo(Pico)($t0)

m_read8_above_rom:
    # might still be SRam (Micro Machines, HardBall '95)
    m_read_rom_try_sram 0 8
    m_read8_call16 PicoRead16Hook 1

# #############################################################################

.macro m_read16_rom sect
    lui     $t0, %hi(Pico+0x22200)
    lw      $t0, %lo(Pico+0x22200)($t0)  # rom
    ins     $a0, $0,   0,  1
    ins     $a0, $0,  19, 13
.if \sect
    lui     $t1, 8*\sect
    addu    $a0, $t1
.endif
    addu    $t0, $a0
    jr      $ra
    lh      $v0, 0($t0)
.endm


m_read16_rom0: # 0x000000 - 0x07ffff
    m_read16_rom 0

m_read16_rom1: # 0x080000 - 0x0fffff
    m_read16_rom 1

m_read16_rom2: # 0x100000 - 0x17ffff
    m_read16_rom 2

m_read16_rom3: # 0x180000 - 0x1fffff
    m_read16_rom 3

m_read16_rom4: # 0x200000 - 0x27ffff, SRAM area
    m_read_rom_try_sram 1 16
    lw      $t1, 4($t3)     # romsize
    subu    $t4, $t1, $a0
    blez    $t4, m_read_null
    lw      $t1, 0($t3)     # rom
    ins     $a0, $0, 0, 1
    addu    $t1, $a0
    jr      $ra
    lh      $v0, 0($t1)

m_read16_rom5: # 0x280000 - 0x2fffff
    m_read16_rom 5

m_read16_rom6: # 0x300000 - 0x37ffff
    m_read16_rom 6

m_read16_rom7: # 0x380000 - 0x3fffff
    m_read16_rom 7

m_read16_rom8: # 0x400000 - 0x47ffff
    m_read16_rom 8

m_read16_rom9: # 0x480000 - 0x4fffff
    m_read16_rom 9

m_read16_romA: # 0x500000 - 0x57ffff
    m_read16_rom 0xA

m_read16_romB: # 0x580000 - 0x5fffff
    m_read16_rom 0xB

m_read16_romC: # 0x600000 - 0x67ffff
    m_read16_rom 0xC

m_read16_romD: # 0x680000 - 0x6fffff
    m_read16_rom 0xD

m_read16_romE: # 0x700000 - 0x77ffff
    m_read16_rom 0xE

m_read16_romF: # 0x780000 - 0x7fffff
    m_read16_rom 0xF

m_read16_rom10: # 0x800000 - 0x87ffff
    m_read16_rom 0x10

m_read16_rom11: # 0x880000 - 0x8fffff
    m_read16_rom 0x11

m_read16_rom12: # 0x900000 - 0x97ffff
    m_read16_rom 0x12

m_read16_rom13: # 0x980000 - 0x9fffff
    m_read16_rom 0x13

m_read16_misc:
    ins     $a0, $0, 0, 1
    j       OtherRead16
    li      $a1, 16

m_read16_vdp:
    ext     $t0, $a0, 16, 3
    andi    $t1, $a0, 0xe0
    or      $t0, $t1
    bnez    $t0, m_read_null # invalid address
    ins     $a0, $0, 0, 1
    j       PicoVideoRead
    nop

m_read16_ram:
    lui     $t0, %hi(Pico)
    ins     $a0, $0, 0, 1
    ins     $t0, $a0, 0, 16
    jr      $ra
    lh      $v0, %lo(Pico)($t0)

m_read16_above_rom:
    # might still be SRam
    m_read_rom_try_sram 0 16
    lui     $t1, %hi(PicoRead16Hook)
    lw      $t1, %lo(PicoRead16Hook)($t1)
    jr      $t1
    ins     $a0, $0, 0, 1

# #############################################################################

.macro m_read32_rom sect
    lui     $t0, %hi(Pico+0x22200)
    lw      $t0, %lo(Pico+0x22200)($t0)  # rom
    ins     $a0, $0,   0,  1
    ins     $a0, $0,  19, 13
.if \sect
    lui     $t1, 8*\sect
    addu    $a0, $t1
.endif
    addu    $t0, $a0
    lh      $v1, 0($t0)
    lh      $v0, 2($t0)
    jr      $ra
    ins     $v0, $v1, 16, 16
.endm


m_read32_rom0: # 0x000000 - 0x07ffff
    m_read32_rom 0

m_read32_rom1: # 0x080000 - 0x0fffff
    m_read32_rom 1

m_read32_rom2: # 0x100000 - 0x17ffff
    m_read32_rom 2

m_read32_rom3: # 0x180000 - 0x1fffff
    m_read32_rom 3

m_read32_rom4: # 0x200000 - 0x27ffff, SRAM area
    m_read_rom_try_sram 1 32
    lw      $t1, 4($t3)     # romsize
    subu    $t4, $t1, $a0
    blez    $t4, m_read_null
    lw      $t1, 0($t3)     # rom
    ins     $a0, $0, 0, 1
    addu    $t1, $a0
    lh      $v1, 0($t1)
    lh      $v0, 2($t1)
    jr      $ra
    ins     $v0, $v1, 16, 16

m_read32_rom5: # 0x280000 - 0x2fffff
    m_read32_rom 5

m_read32_rom6: # 0x300000 - 0x37ffff
    m_read32_rom 6

m_read32_rom7: # 0x380000 - 0x3fffff
    m_read32_rom 7

m_read32_rom8: # 0x400000 - 0x47ffff
    m_read32_rom 8

m_read32_rom9: # 0x480000 - 0x4fffff
    m_read32_rom 9

m_read32_romA: # 0x500000 - 0x57ffff
    m_read32_rom 0xA

m_read32_romB: # 0x580000 - 0x5fffff
    m_read32_rom 0xB

m_read32_romC: # 0x600000 - 0x67ffff
    m_read32_rom 0xC

m_read32_romD: # 0x680000 - 0x6fffff
    m_read32_rom 0xD

m_read32_romE: # 0x700000 - 0x77ffff
    m_read32_rom 0xE

m_read32_romF: # 0x780000 - 0x7fffff
    m_read32_rom 0xF

m_read32_rom10: # 0x800000 - 0x87ffff
    m_read32_rom 0x10

m_read32_rom11: # 0x880000 - 0x8fffff
    m_read32_rom 0x11

m_read32_rom12: # 0x900000 - 0x97ffff
    m_read32_rom 0x12

m_read32_rom13: # 0x980000 - 0x9fffff
    m_read32_rom 0x13

.macro m_read32_call16 func need_a1=0
    addiu   $sp, -8
    sw      $ra, 0($sp)
    sw      $s0, 4($sp)
.if \need_a1
    li      $a1, 16
.endif
    jal     \func
    move    $s0, $a0

    addu    $a0, $s0, 2
.if \need_a1
    li      $a1, 16
.endif
    jal     \func
    move    $s0, $v0

    ins     $v0, $s0, 16, 16
    lw      $ra, 0($sp)
    lw      $s0, 4($sp)
    jr      $ra
    addiu   $sp, 8
.endm

m_read32_misc:
    ins     $a0, $0, 0, 1
    m_read32_call16 OtherRead16, 1

m_read32_vdp:
    ext     $t0, $a0, 16, 3
    andi    $t1, $a0, 0xe0
    or      $t0, $t1
    bnez    $t0, m_read_null # invalid address
    ins     $a0, $0, 0, 1
    m_read32_call16 PicoVideoRead

m_read32_ram:
    lui     $t0, %hi(Pico)
    ins     $a0, $0, 0, 1
    ins     $t0, $a0, 0, 16
    lh      $v1, %lo(Pico)($t0)
    lh      $v0, %lo(Pico+2)($t0)
    jr      $ra
    ins     $v0, $v1, 16, 16

m_read32_above_rom:
    # might still be SRam
    m_read_rom_try_sram 0 32
    ins     $a0, $0, 0, 1
    lui     $t1, %hi(PicoRead16Hook)
    lw      $t1, %lo(PicoRead16Hook)($t1)
    addiu   $sp, -4*3
    sw      $ra, 0($sp)
    sw      $s0, 4($sp)
    sw      $t1, 8($sp)
    jalr    $t1
    move    $s0, $a0

    lw      $t1, 8($sp)
    addu    $a0, $s0, 2
    jalr    $t1
    move    $s0, $v0

    ins     $v0, $s0, 16, 16
    lw      $ra, 0($sp)
    lw      $s0, 4($sp)
    jr      $ra
    addiu   $sp, 4*3

# #############################################################################

.macro PicoWriteRomHW_SSF2_ls def_table table
    lui     $t3, %hi(\def_table)
    ins     $t3, $a1, 2, 5
    lw      $t0, %lo(\def_table)($t3)
    lui     $t2, %hi(\table)
    ins     $t2, $a0, 2, 3
    sw      $t0, %lo(\table)($t2)
.endm

PicoWriteRomHW_SSF2: # u32 a, u32 d
    ext     $a0, $a0, 1, 3
    bnez    $a0, pwr_banking

    # sram register
    lui     $t0, %hi(Pico+0x22211)
    lb      $t1, %lo(Pico+0x22211)($t0) # Pico.m.sram_reg
    ins     $t1, $a1, 0, 2
    jr      $ra
    sb      $t1, %lo(Pico+0x22211)($t0)

pwr_banking:
    andi    $a1, 0x1f

    PicoWriteRomHW_SSF2_ls m_read8_def_table  m_read8_table
    PicoWriteRomHW_SSF2_ls m_read16_def_table m_read16_table
    PicoWriteRomHW_SSF2_ls m_read32_def_table m_read32_table
 
    jr      $ra
    nop

# vim:filetype=mips
