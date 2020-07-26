#*
#* Some misc routines for Allegrex MIPS
#* (C) notaz, 2007-2008
#*
#* This work is licensed under the terms of MAME license.
#* See COPYING file in the top-level directory.
#*

.set noreorder
.set noat

.text
.align 4

.globl memset32 # int *dest, int c, int count

memset32:
ms32_aloop:
    andi    $t0, $a0, 0x3f
    beqz    $t0, ms32_bloop_prep
    nop
    sw      $a1, 0($a0)
    addiu   $a2, -1
    beqz    $a2, ms32_return
    addiu   $a0, 4
    j       ms32_aloop
    nop

ms32_bloop_prep:
    srl     $t0, $a2, 4    # we will do 64 bytes per iteration (cache line)
    beqz    $t0, ms32_bloop_end

ms32_bloop:
    addiu   $t0, -1
    cache   0x18, ($a0)    # create dirty exclusive
    sw      $a1, 0x00($a0)
    sw      $a1, 0x04($a0)
    sw      $a1, 0x08($a0)
    sw      $a1, 0x0c($a0)
    sw      $a1, 0x10($a0)
    sw      $a1, 0x14($a0)
    sw      $a1, 0x18($a0)
    sw      $a1, 0x1c($a0)
    sw      $a1, 0x20($a0)
    sw      $a1, 0x24($a0)
    sw      $a1, 0x28($a0)
    sw      $a1, 0x2c($a0)
    sw      $a1, 0x30($a0)
    sw      $a1, 0x34($a0)
    sw      $a1, 0x38($a0)
    sw      $a1, 0x3c($a0)
    bnez    $t0, ms32_bloop
    addiu   $a0, 0x40

ms32_bloop_end:
    andi    $a2, $a2, 0x0f
    beqz    $a2, ms32_return

ms32_cloop:
    addiu   $a2, -1
    sw      $a1, 0($a0)
    bnez    $a2, ms32_cloop
    addiu   $a0, 4

ms32_return:
    jr      $ra
    nop


.globl memset32_uncached # int *dest, int c, int count

memset32_uncached:
    srl     $t0, $a2, 3    # we will do 32 bytes per iteration
    beqz    $t0, ms32u_bloop_end

ms32u_bloop:
    addiu   $t0, -1
    sw      $a1, 0x00($a0)
    sw      $a1, 0x04($a0)
    sw      $a1, 0x08($a0)
    sw      $a1, 0x0c($a0)
    sw      $a1, 0x10($a0)
    sw      $a1, 0x14($a0)
    sw      $a1, 0x18($a0)
    sw      $a1, 0x1c($a0)
    bnez    $t0, ms32u_bloop
    addiu   $a0, 0x20

ms32u_bloop_end:
    andi    $a2, $a2, 0x0f
    beqz    $a2, ms32u_return

ms32u_cloop:
    addiu   $a2, -1
    sw      $a1, 0($a0)
    bnez    $a2, ms32u_cloop
    addiu   $a0, 4

ms32u_return:
    jr      $ra
    nop


.globl memcpy32 # int *dest, int *src, int count

memcpy32:
mc32_aloop:
    andi    $t0, $a0, 0x3f
    beqz    $t0, mc32_bloop_prep
    nop
    lw      $t1, 0($a1)
    addiu   $a2, -1
    sw      $t1, 0($a0)
    beqz    $a2, mc32_return
    addiu   $a0, 4
    j       mc32_aloop
    addiu   $a1, 4

mc32_bloop_prep:
    srl     $t0, $a2, 4    # we will do 64 bytes per iteration (cache line)
    beqz    $t0, mc32_bloop_end

mc32_bloop:
    addiu   $t0, -1
    cache   0x18, ($a0)    # create dirty exclusive
    lw      $t2, 0x00($a1)
    lw      $t3, 0x04($a1)
    lw      $t4, 0x08($a1)
    lw      $t5, 0x0c($a1)
    lw      $t6, 0x10($a1)
    lw      $t7, 0x14($a1)
    lw      $t8, 0x18($a1)
    lw      $t9, 0x1c($a1)
    sw      $t2, 0x00($a0)
    sw      $t3, 0x04($a0)
    sw      $t4, 0x08($a0)
    sw      $t5, 0x0c($a0)
    sw      $t6, 0x10($a0)
    sw      $t7, 0x14($a0)
    sw      $t8, 0x18($a0)
    sw      $t9, 0x1c($a0)
    lw      $t2, 0x20($a1)
    lw      $t3, 0x24($a1)
    lw      $t4, 0x28($a1)
    lw      $t5, 0x2c($a1)
    lw      $t6, 0x30($a1)
    lw      $t7, 0x34($a1)
    lw      $t8, 0x38($a1)
    lw      $t9, 0x3c($a1)
    sw      $t2, 0x20($a0)
    sw      $t3, 0x24($a0)
    sw      $t4, 0x28($a0)
    sw      $t5, 0x2c($a0)
    sw      $t6, 0x30($a0)
    sw      $t7, 0x34($a0)
    sw      $t8, 0x38($a0)
    sw      $t9, 0x3c($a0)
    addiu   $a0, 0x40
    bnez    $t0, mc32_bloop
    addiu   $a1, 0x40

mc32_bloop_end:
    andi    $a2, $a2, 0x0f
    beqz    $a2, mc32_return

mc32_cloop:
    lw      $t1, 0($a1)
    addiu   $a2, -1
    addiu   $a1, 4
    sw      $t1, 0($a0)
    bnez    $a2, mc32_cloop
    addiu   $a0, 4

mc32_return:
    jr      $ra
    nop

# vim:filetype=mips
