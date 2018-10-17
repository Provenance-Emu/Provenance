!   Copyright 2008 Lawrence Sebald
!
!   This file is part of Yabause.
!
!   Yabause is free software; you can redistribute it and/or modify
!   it under the terms of the GNU General Public License as published by
!   the Free Software Foundation; either version 2 of the License, or
!   (at your option) any later version.
!
!   Yabause is distributed in the hope that it will be useful,
!   but WITHOUT ANY WARRANTY; without even the implied warranty of
!   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!   GNU General Public License for more details.
!
!   You should have received a copy of the GNU General Public License
!   along with Yabause; if not, write to the Free Software
!   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

!   Ok, so this is the start of me assemblerizing different parts of the core
!   of the Dreamcast port of Yabause. I picked the CD core since its one of the
!   parts of the emulator that is least likely to change in the future
!   (hopefully anyway), and its somewhat simple to start with.

    .file       "cd.s"
    .little
    .text
    .align      2

!   static int DCCDInit(const char *cdrom_name)
!       Initialize the GD drive to read 2352 byte sectors.
DCCDInit:
    sts.l       pr, @-r15
.do_reinit:
    mov.l       .cdrom_exec_cmd, r0
    mov         #0, r5
    jsr         @r0
    mov         #24, r4                 ! CMD_INIT
    cmp/eq      #1, r0                  ! ERR_NO_DISC
    bt          .init_return_success
    cmp/eq      #3, r0                  ! ERR_SYS
    bt          .init_return_error
    mov.l       .gdc_syscall_vector, r1
    mova        .DCCDInitParams, r0
    mov         #10, r7
    mov.l       @r1, r1
    mov         r0, r4
    mov         #0, r6
    jsr         @r1
    mov         #0, r5
    lds.l       @r15+, pr
    rts
    nop
.init_return_success:
    lds.l       @r15+, pr
    rts
    mov         #0, r0
.init_return_error:
    lds.l       @r15+, pr
    rts
    mov         #-1, r0
    .align 4
.cdrom_exec_cmd:
    .long       _cdrom_exec_cmd
.DCCDInitParams:
    .long       0       ! 0 = set
    .long       4096    ! Magic value for RAW sector reads
    .long       0x0400  ! Ditto
    .long       2352    ! Sector Size? (Maybe not for RAW though?)

!   static int DCCDGetStatus(void)
!       Execute the BIOS syscall of the Dreamcast to get the GD drive status,
!       translating that into the format expected by the core of Yabause.
DCCDGetStatus:
    sts.l       pr, @-r15
.status_startgame:
    mov.l       .gdc_syscall_vector, r1
    mova        .get_status_scratchpad, r0
    mov         #4, r7
    mov.l       @r1, r1
    mov         #0, r5
    mov         r0, r4
    jsr         @r1
    mov         #0, r6
    cmp/eq      #2, r0                      ! 2 = Disc change error
    bt          .status_reinit
    cmp/eq      #0, r0
    bf          .status_error
.status_endgame:                            ! status in 1st entry in scratchpad
    mova        .get_status_scratchpad, r0
    mov         #0x07, r2
    mov.l       @r0, r1
    mova        .get_status_return_value, r0
    and         r2, r1
    add         r1, r0
    lds.l       @r15+, pr
    rts
    mov.b       @r0, r0
.status_reinit:
    mov.l       .get_status_init_func, r0
    jsr         @r0
    mov         #0, r4
    cmp/eq      #0, r0
    bt          .status_startgame
.status_error:
    lds.l       @r15+, pr
    rts
    mov         #2, r0

    .align      4
.gdc_syscall_vector:
    .long       0x8c0000bc
.get_status_scratchpad:
    .long       0
    .long       0
.get_status_return_value:
    .byte       0, 1, 1, 0, 0, 0, 3, 2
.get_status_init_func:
    .long       DCCDInit

!   static int DCCDDeInit(void)
!       Deinitialize the CD Drive of the Dreamcast (i.e., undo the odd
!       initialization stuff that the code does for Yabause).
DCCDDeInit:
    mov.l       .cdrom_reinit, r0
    sts.l       pr, @-r15
    jsr         @r0
    nop
    lds.l       @r15+, pr
    rts
    nop         ! Leave the return value from cdrom_reinit as the return here.

!   static int DCCDReadSectorFAD(u32 FAD, void *buffer)
!       Read a single 2352 byte sector from the given position on the disc.
DCCDReadSectorFAD:
    sts.l       pr, @-r15
    mov         r4, r2
    mov.l       r4, @-r15
    mov         r5, r4
    mov.l       .cdrom_read_sectors, r0
    mov.l       r5, @-r15
    mov         r2, r5
.read_sector_start:
    jsr         @r0
    mov         #1, r6
    cmp/eq      #2, r0
    bt          .read_reinit
    cmp/eq      #0, r0
    add         #8, r15
    bf/s        .read_error
    lds.l       @r15+, pr
    rts
    mov         #1, r0
.read_reinit:
    mov.l       .DCCDInit, r0
    jsr         @r0
    mov         #0, r4
    cmp/eq      #0, r0
    mov.l       @r15, r4
    mov.l       .cdrom_read_sectors, r0
    bt/s        .read_sector_start
    mov.l       @(4, r15), r5
    add         #8, r15
.read_error:
    rts
    mov         #0, r0

!   static int DCCDReadAheadFAD(u32 FAD)
!       No-op (for the moment).
DCCDReadAheadFAD:
    rts
    nop

!   static s32 DCCDReadTOC(u32 *TOC);
!       Read the TOC of the CD inserted in the drive.
!       Amusingly enough, I just realized that the format that Yabause expects
!       and what the Dreamcast spews out are exactly the same. Go figure!
DCCDReadTOC:
    sts.l       pr, @-r15
    mov.l       .cdrom_read_toc, r0
    mov.l       r4, @-r15
.readtoc_start:
    jsr         @r0
    mov         #0, r5
    cmp/eq      #2, r0
    bt          .readtoc_reinit
    cmp/eq      #0, r0
    add         #4, r15
    bf/s        .readtoc_error
    mov         #0xCC, r0
    lds.l       @r15+, pr
    extu.b      r0, r0
    rts
    shll        r0
.readtoc_reinit:
    mov.l       .DCCDInit, r0
    jsr         @r0
    mov         #0, r4
    cmp/eq      #0, r0
    mov.l       @r15, r4
    bt/s        .readtoc_start
    mov.l       .cdrom_read_toc, r0
    add         #4, r15
.readtoc_error:
    rts
    mov         #0, r0

    .align      4
.cdrom_reinit:
    .long       _cdrom_reinit
.cdrom_read_sectors:
    .long       _cdrom_read_sectors
.DCCDInit:
    .long       DCCDInit
.cdrom_read_toc:
    .long       _cdrom_read_toc

    .section    .rodata
    .align      2
.CDInterfaceName:
    .string     "Dreamcast CD Drive"

    .data
    .align      4
    .globl      _ArchCD
    .size       _ArchCD, 32
_ArchCD:
    .long       2
    .long       .CDInterfaceName
    .long       DCCDInit
    .long       DCCDDeInit
    .long       DCCDGetStatus
    .long       DCCDReadTOC
    .long       DCCDReadSectorFAD
    .long       DCCDReadAheadFAD
