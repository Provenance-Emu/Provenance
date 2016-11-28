| Processor:        68K
| Target Assembler: 680x0 Assembler by GNU project

| ___________________________________________________________________________

| Segment type: Pure code
| segment "ROM"
dword_0:        .long 0                 | DATA XREF: ROM:00007244r
                                        | sub_764E+3Eo ...
                                        | initial interrupt stack pointer
dword_4:        .long _start            | DATA XREF: ROM:00007248r
                                        | ROM:000142C2w
                                        | reset initial PC
dword_8:        .long 0x4DE             | DATA XREF: sub_20050+B54w
                .long 0x490
                .long 0x4AA             | illegal instruction
                .long 0x4C4
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long _trace            | trace
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x548             | Level 1 Interrupt Autovector
                .long 0x548             | 2 = ext interrupt
                .long 0x548
                .long 0x592             | 4 = horizontal interrupt?
                .long 0x548
                .long 0x594             | 6 = verticai interrupt?
                .long 0x552
dword_80:       .long 0x45C             | DATA XREF: ROM:00152F29o
                                        | trap vector table? trap 0?
                .long 0x1738
                .long 0x171C
                .long 0x1754
                .long 0x1700
                .long 0x556
                .long 0x57A
                .long 0x548
                .long 0x548
                .long 0x7CE             | 9
                .long 0x548
                .long 0x548
                .long 0x548
                .long 0x548
                .long 0x548
                .long 0x548
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
                .long 0x4DE
aSegaGenesis:   .ascii "SEGA GENESIS    " | DATA XREF: ROM:00045C6Ao
aCSega1994_jul: .ascii "(C)SEGA 1994.JUL"
aDumpedByTsd:   .ascii "Dumped By TSD                                   "
aShiningForce2: .ascii "SHINING FORCE 2                                 "
aGmMk131500:    .ascii "GM MK-1315 -00"
                .word 0x8921            | checksum
aJ:             .ascii "J               " | IO_Support
                .long 0                 | Rom_Start_Adress
dword_1A4:      .long 0x1FFFFF          | DATA XREF: sub_28008+F66o
                                        | Rom_End_Adress
                .long 0xFF0000          | Ram_Start_Adress
                .long 0xFFFFFF          | Ram_End_Adress
aRaa:           .ascii "RA° "<0>" "<0><1><0>" ?"<0xFF> | Modem_Infos
                .ascii "                                        "
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
aU:             .ascii "U  "            | Countries
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
                .byte 0x20 |  
_trace:
  nop
  nop
  rte

.globl _start
_start:
  move.l   #0xFFFFFFFF, %d0
  move.l   #0xFFFFFFFF, %d1
  move.w   #0xa711, %sr
  move.l   #0x1, %d2
  move.l   #0x8000, %d3
  negx.l   %d0
  negx.l   %d1
  move.w   #0x270f, %sr
  negx.b   %d2
  negx.w   %d3
_loop:
  bra      _loop

  nop
  nop
  nop
  nop
