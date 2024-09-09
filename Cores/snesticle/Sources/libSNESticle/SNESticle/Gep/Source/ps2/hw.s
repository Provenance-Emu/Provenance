# By Vzzrzzn, modifications by Sjeep

.file   1 "hw.s"

.set nomips16
.set noat




.data 1
.p2align 4

VRendf:     .word 0
VRendid:    .word 0
VRcount:    .word 0
VRstartid:  .word 0


# ----------------------------
# ----------------------------
# ----------------------------


.text
.p2align 4
.set noreorder


# ----------------------------

# void install_VRstart_handler();
    .globl install_VRstart_handler
    .ent install_VRstart_handler
install_VRstart_handler:
    di

    # install handler
    li $4, 3
    la $5, VRstart_handler
    addiu $6, $0, 0
    li $3, 16
    syscall
    nop

    la $4, VRstartid
    sw $2, 0($4)

    # enable the handler
    li $4, 3
    li $3, 20
    syscall
    nop

    la $4, VRcount
    sw $0, 0($4)

    ei

    jr $31
    nop

    .end install_VRstart_handler

# untested
# void remove_VRstart_handler();
    .globl remove_VRstart_handler
    .ent remove_VRstart_handler
remove_VRstart_handler:
    di

    lui $2, %hi(VRstartid)
    addiu $4, $0, 2
    ori $2, %lo(VRstartid)
    addiu $3, $0, 17
    lw $5, 0($2)
    syscall
    nop

    ei

    jr $31
    nop

    .end remove_VRstart_handler
# untested

    .ent VRstart_handler
VRstart_handler:
    la $2, VRcount
    lw $3, 0($2)
    nop
    addiu $3, 1
    sw $3, 0($2)

    daddu $2, $0, $0

    jr $31
    nop

    .end VRstart_handler

    .set at
# clears flag and waits until it gets reset (blocking call)
# void WaitForNextVRstart(int numvrs);
# numvrs = number of vertical retraces to wait for
    .globl WaitForNextVRstart
    .ent WaitForNextVRstart
WaitForNextVRstart:
    la $2, VRcount
    sw $0, 0($2)

WaitForNextVRstart.lp:
    lw $3, 0($2)
    nop
    blt $3, $4, WaitForNextVRstart.lp
    nop

    jr $31
    nop

    .end WaitForNextVRstart
    .set noat

# has start-of-Vertical-Retrace occurred since the flag was last cleared ?
# (non-blocking call)
# int TestVRstart();
    .globl TestVRstart
    .ent TestVRstart
TestVRstart:
    la $3, VRcount
    lw $2, 0($3)

    jr $31
    nop

    .end TestVRstart


# clear the start-of-Vertical-Retrace flag
# void ClearVRcount();
    .globl ClearVRcount
    .ent ClearVRcount
ClearVRcount:
    la $2, VRcount
    sw $0, 0($2)

    jr $31
    nop

    .end ClearVRcount

# ----------------------------
# ----------------------------

# DMA stuff


    .set at
# Dukes DmaReset
# void DmaReset();
    .globl DmaReset
    .ent DmaReset
DmaReset:																   
    sw  $0, 0x1000a080
    sw  $0, 0x1000a000
    sw  $0, 0x1000a030
    sw  $0, 0x1000a010
    sw  $0, 0x1000a050
    sw  $0, 0x1000a040
    li  $2, 0xff1f
    sw  $2, 0x1000e010
    sw  $0, 0x1000e000
    sw  $0, 0x1000e020
    sw  $0, 0x1000e030
    sw  $0, 0x1000e050
    sw  $0, 0x1000e040
    lw  $2, 0x1000e000
    ori $3,$2,1
    nop
    sw  $3, 0x1000e000
    nop
    jr  $31
    nop

    .end DmaReset
    .set noat


# the same as Dukes "SendPrim"
# void SendDma02(void *DmaTag);
    .globl SendDma02
    .ent SendDma02
SendDma02:
    li $3, 0x1000a000

    sw $4, 0x0030($3)
    sw $0, 0x0020($3)
    lw $2, 0x0000($3)
    ori $2, 0x0105
    sw $2, 0x0000($3)

    jr $31
    nop
    .end SendDma02


# Dukes Dma02Wait !
# void Dma02Wait();
    .globl Dma02Wait
    .ent Dma02Wait
Dma02Wait:
    addiu $29, -4
    sw $8, 0($29)

Dma02Wait.poll:
    lw $8, 0x1000a000
    nop
    andi $8, $8, 0x0100
    bnez $8, Dma02Wait.poll
    nop

    lw $8, 0($29)
    addiu $29, 4

    jr  $31
    nop

    .end Dma02Wait

# ----------------------------
# ----------------------------


    .globl qmemcpy
    .ent qmemcpy
# void qmemcpy(void *dest, void *src, int numqwords);
qmemcpy:
    lq $2, 0($5)
    addiu $6, -1
    sq $2, 0($4)
    addiu $4, 0x0010
    bnez $6, qmemcpy
    addiu $5, 0x0010

    jr $31
    nop
    .end qmemcpy


    .globl dmemcpy
    .ent dmemcpy
# void dmemcpy(void *dest, void *src, int numdwords);
dmemcpy:
    ld $2, 0($5)
    addiu $6, -1
    sd $2, 0($4)
    addiu $4, 0x0010
    bnez $6, dmemcpy
    addiu $5, 0x0010

    jr $31
    nop
    .end dmemcpy


    .globl wmemcpy
    .ent wmemcpy
# void wmemcpy(void *dest, void *src, int numwords);
wmemcpy:
    lw $2, 0($5)
    addiu $6, -1
    sw $2, 0($4)
    addiu $4, 0x0010
    bnez $6, wmemcpy
    addiu $5, 0x0010

    jr $31
    nop
    .end wmemcpy

# Dukes pal/ntsc auto-detection. Returns 3 for PAL, 2 for NTSC.
.globl	pal_ntsc
.ent	pal_ntsc
pal_ntsc:
	lui     $8,0x1fc8
	lb      $8,-0xae($8)
	li      $9,'E'
	beql    $8,$9,pal_mode
	li      $2,3                  # 2=NTSC, 3=PAL

	li		$2,2
pal_mode:
	jr		$31
	nop
.end	pal_ntsc
