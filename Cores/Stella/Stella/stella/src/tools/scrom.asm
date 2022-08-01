;;============================================================================
;;
;;   SSSS    tt          lll  lll
;;  SS  SS   tt           ll   ll
;;  SS     tttttt  eeee   ll   ll   aaaa
;;   SSSS    tt   ee  ee  ll   ll      aa
;;      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
;;  SS  SS   tt   ee      ll   ll  aa  aa
;;   SSSS     ttt  eeeee llll llll  aaaaa
;;
;; Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
;; and the Stella Team
;;
;; See the file "License.txt" for information on usage and redistribution of
;; this file, and for a DISCLAIMER OF ALL WARRANTIES.
;;============================================================================
;;
;; This file contains a "dummy" Supercharger BIOS for Stella.  It is based
;; on routines developed by Eckhard Stolberg.
;;
;;============================================================================

        processor 6502

VSYNC   equ  $00
VBLANK  equ  $01
WSYNC   equ  $02
COLUPF  equ  $08
COLUBK  equ  $09
CTRLPF  equ  $0a
PF0     equ  $0d
PF1     equ  $0e
PF2     equ  $0f
RESP0   equ  $10
RESP1   equ  $11
AUDC0   equ  $15
AUDF0   equ  $17
AUDV0   equ  $19
AUDV1   equ  $1a
GRP0    equ  $1b
GRP1    equ  $1c
ENAM0   equ  $1d
ENAM1   equ  $1e
ENABL   equ  $1f
HMP0    equ  $20
HMP1    equ  $21
HMOVE   equ  $2a

;;
;; Entry point for multi-load reading
;;
        org $F800

        LDA $FA        ; Grab the load number and store it in $80 where the
        STA $80        ; emulator will grab it when it does the loading
        JMP clrp7      ; Go clear page 7 of RAM bank 1 like the real SC

;;
;; Entry point for initial load (invoked when the system is reset)
;;
        org $F80A

start   SEI
        CLD

;;
;; Clear page zero routine for initial load (e.g., RAM and TIA registers)
;;
        LDY #$00
        LDX #$00
ilclr   STY $00,X
        INX
        BNE ilclr

        JMP load

;;
;; Clear page 7 of RAM bank 1 (used for stars in the real SC)
;;
clrp7   LDX #$00
        LDA $F006,X
        LDA $FFF8
        LDX #$00
mlclr3  LDA $F000
        NOP
        LDA $F700,X
        DEX
        BNE mlclr3
        JMP load

;;
;; NOTE: The emulator does the actual reading of the new load when the
;; next instruction is accessed.  The emulator expects the load number to
;; to be stored in location $80.  As a side-effect the emulator sets $80
;; to contain the bank selection byte from the load's header and sets
;; $FE and $FF to contain the starting address from the load's header.
;;
load    org $F850

;;
;; Copy code into page zero to do the bank switching
;;
        LDX #$03
copy    LDY code,X
        STY $FA,X
        DEX
        BPL copy

;;
;; Clear some of the 2600's RAM and TIA registers like the real SC BIOS does
;;
        LDY #$00
        LDX #$28
mlclr1  STY $04,X
        DEX
        BPL mlclr1

        LDX #$1C
mlclr2  STY $81,X
        DEX
        BPL mlclr2

;;
;; Display the "emulated" Supercharger loading progress bar
;;
;; Check if we should skip the loading progress bar
;;  Note that the following code seems to never do a jump
;;  However, the comparison value can be patched outside this code
;;
        LDA #$FF
        CMP #$00         ; patch this value to $FF outside ROM to do a jump
        BNE startbars
        JMP skipbars

;; Otherwise we display them
startbars:
        LDA #$00
        STA GRP0
        STA GRP1
        STA ENAM0
        STA ENAM1
        STA ENABL
        STA AUDV0
        STA AUDV1
        STA COLUPF
        STA VBLANK

        LDA #$10
        STA HMP1
        STA WSYNC
        LDX #$07
        DEX
pos     DEX
        BNE pos
        LDA #$00
        STA HMP0
        STA RESP0
        STA RESP1
        STA WSYNC
        STA HMOVE

        LDA #%00000101
        STA CTRLPF
        LDA #$FF
        STA PF0
        STA PF1
        STA PF2
        STA $84
        STA $85
        LDA #$F0
        STA $83
        LDA #$74
        STA COLUBK
        LDA #$0C
        STA AUDC0
        LDA #$1F
        STA AUDF0
        STA $82
        LDA #$07
        STA AUDV0
a1
        LDX #$08
        LDY #$00
a2
        STA WSYNC
        DEY
        BNE a2
        STA WSYNC
        STA WSYNC
        LDA #$02
        STA WSYNC
        STA VSYNC
        STA WSYNC
        STA WSYNC
        STA WSYNC
        LDA #$00
        STA VSYNC
        DEX
        BPL a2
        ASL $83
        ROR $84
        ROL $85
        LDA $83
        STA PF0
        LDA $84
        STA PF1
        LDA $85
        STA PF2
        LDX $82
        DEX
        STX $82
        STX AUDF0
        CPX #$0A
        BNE a1

        LDA #%00000010
        STA VBLANK

        LDX #$1C
        LDY #$00
        STY AUDV0
        STY COLUBK
clear:
        STY $81,x
        DEX
        BPL clear
skipbars:

;;
;; Setup value to be stored in the bank switching control register
;;
        LDX $80
        CMP $F000,X

;;
;; Initialize A, X, Y, and SP registers
;;
        LDA #$9a  ;; This is patched outside the ROM to a random value
        LDX #$FF
        LDY #$00
        TXS

;;
;; Execute the code to do bank switch and start running cartridge code
;;
        JMP $FA

code    dc.b $cd, $f8, $ff    ;; CMP $fff8
        dc.b $4c              ;; JMP $????

