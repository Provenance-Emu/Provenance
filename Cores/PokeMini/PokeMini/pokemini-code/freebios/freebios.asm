;-------------------------------------;
; Freeware Pokemon-Mini BIOS Ver 1.3  ;
;  (Fruit of reverse enginnering!!)   ;
;                                     ;
; V1.3:                               ;
;   Fixed Suspend System              ;
;                                     ;
; V1.2:                               ;
;   Added graphics for no cart        ;
;                                     ;
; V1.1:                               ;
;   New functions added               ;
;   Sound on commercial games works   ;
;    once you change vol. in Options  ;
;   Fake PM Suspend / Shutdown.       ;
;    (We need more info of the PM)    ;
;                                     ;
; V1.0:                               ;
;   First release of the PD-BIOS.     ;
;   No sound for commercial games but ;
;    since this is for freeware games ;
;    that doesn't seems to be much of ;
;    a problem.                       ;
;                                     ;
; Team Pokeme              19-06-2009 ;
;-------------------------------------;

	.dw	hreset          ; 00 - NMI - System Start-up (Hard reset)
	.dw	sreset          ; 01 - NMI - System Reset (Soft reset)
	.dw	sreset          ; 02 - NMI - System Reset (Soft reset)
	.dw	int03_2108      ; 03 - IRQ - PRC Copy Complete
	.dw	int04_210E      ; 04 - IRQ - PRC Frame Divider Overflow
	.dw	int05_2114      ; 05 - IRQ - Timer2 Upper-8 Underflow
	.dw	int06_211A      ; 06 - IRQ - Timer2 Lower-8 Underflow (8-bit only)
	.dw	int07_2120      ; 07 - IRQ - Timer1 Upper-8 Underflow
	.dw	int08_2126      ; 08 - IRQ - Timer1 Lower-8 Underflow (8-bit only)
	.dw	int09_212C      ; 09 - IRQ - Timer3 Upper-8 Underflow
	.dw	int0A_2132      ; 0A - IRQ - Timer3 Pivot
	.dw	int0B_2138      ; 0B - IRQ - 32Hz (From 256Hz Timer) 
	.dw	int0C_213E      ; 0C - IRQ - 8Hz (From 256Hz Timer) 
	.dw	int0D_2144      ; 0D - IRQ - 2Hz (From 256Hz Timer) 
	.dw	int0E_214A      ; 0E - IRQ - 1Hz (From 256Hz Timer) 
	.dw	int0F_2150      ; 0F - IRQ - IR Receiver
	.dw	int10_2156      ; 10 - IRQ - Shock Sensor
	.dw	sreset          ; 11
	.dw	sreset          ; 12
	.dw	reticode        ; 13
	.dw	int14_219E      ; 14 - IRQ - Cartridge IRQ 
	.dw	int15_215C      ; 15 - IRQ - Power Key
	.dw	int16_2162      ; 16 - IRQ - Right Key
	.dw	int17_2168      ; 17 - IRQ - Left Key
	.dw	int18_216E      ; 18 - IRQ - Down Key
	.dw	int19_2174      ; 19 - IRQ - Up Key
	.dw	int1A_217A      ; 1A - IRQ - C Key
	.dw	int1B_2180      ; 1B - IRQ - B Key
	.dw	int1C_2186      ; 1C - IRQ - A Key
	.dw	int1D_218C      ; 1D - IRQ - Unknown
	.dw	int1E_2192      ; 1E - IRQ - Unknown
	.dw	int1F_2198      ; 1F - IRQ - Unknown
	.dw	0xFFF1          ; 20 - IRQ - User IRQ Routine at PC 0xFFF1
	.dw	Intr21h         ; 21 - ROU - Suspend System
	.dw	reticode        ; 22
	.dw	reticode        ; 23
	.dw	Intr24h         ; 24 - ROU - Shutdown System
	.dw	reticode        ; 25
	.dw	Intr26h         ; 26 - ROU - Set default LCD Constrast
	.dw	Intr27h         ; 27 - ROU - Increase or decrease Contrast based of Zero flag...
	.dw	Intr28h         ; 28 - ROU - Apply default LCD Constrast
	.dw	Intr29h         ; 29 - ROU - Get default LCD Contrast
	.dw	Intr2Ah         ; 2A - ROU - Set temporary LCD Constrast
	.dw	Intr2Bh         ; 2B - ROU - Turn LCD On
	.dw	Intr2Ch         ; 2C - ROU - Initialize LCD
	.dw	Intr2Dh         ; 2D - ROU - Turn LCD Off
	.dw	Intr2Eh         ; 2E - ROU - Check if Register 0x01 Bit 7 is set, if not, it set bit 6 and 7 
	.dw	reticode        ; 2F
	.dw	reticode        ; 30
	.dw	reticode        ; 31
	.dw	reticode        ; 32
	.dw	reticode        ; 33
	.dw	reticode        ; 34
	.dw	reticode        ; 35
	.dw	reticode        ; 36
	.dw	reticode        ; 37
	.dw	reticode        ; 38
	.dw	Intr39h         ; 39 - ROU - Disable Cartridge and LCD
	.dw	Intr3Ah         ; 3A - ROU - Enable Cartridge and LCD
	.dw	reticode        ; 3B
	.dw	reticode        ; 3C
	.dw	Intr3Dh         ; 3D - ROU - Test Register 0x53 Bit 1 and invert Zero flag
	.dw	Intr3Eh         ; 3E - ROU - Read structure, write 0xFF, compare values and optionally jump to subroutine...
	.dw	Intr3Fh         ; 3F - ROU - Set PRC Rate
	.dw	Intr40h         ; 40 - ROU - Get PRC Rate
	.dw	Intr41h         ; 41 - ROU - Test Register 0x01 Bit 3
	.dw	reticode        ; 42
	.dw	reticode        ; 43
	.dw	reticode        ; 44
	.dw	reticode        ; 45
	.dw	reticode        ; 46
	.dw	reticode        ; 47
	.dw	reticode        ; 48
	.dw	reticode        ; 49
	.dw	reticode        ; 4A
	.dw	0x0000          ; 4B
	.dw	Intr4Ch         ; 4C - ROU - MOV [Y], $02 ; wait B*16 Cycles ; MOV [Y], $00

	.equ	ram_vector	$1FFD	; RAM Vector

	.org	0x009A
; Hard reset
hreset:
	mov n, $20              ; n to $20xx
	xor a, a
	mov i, a
	mov [n+$08], $02        ; Reset seconds counter
	or [n+$08], $01         ; Enable seconds counter
	mov [n+$00], $7C        ; Preset contrast to 1F, disable Cartridge/LCD
	mov [n+$02], $00        ; Signal cold reset, bit 2=0: Invalid time
; Soft reset
sreset:
	mov f, $C0              ; Disable interrupts
	mov n, $20              ; n to $20xx
	xor a, a
	mov i, a
	mov xi, a
	mov yi, a
	mov sp, $2000           ; Init stack
	mov [n+$80], $00        ; Disable PRC
	mov u, $01
	jmp dobanking
dobanking:                      ; Set U(01) to V
	or [n+$00], $03         ; Enable Cartridge and LCD
	or [n+$01], $30         ; ???
	or [n+$02], $C0         ; ???
	call init_io
	mov x, Graphics
	mov [$2082], x
	mov [n+$84], b          ; PRC Map Tile Base = FreeBIOS Graphics
	mov [n+$85], b          ; PRC Map Vertical Scroll = $00
	mov [n+$86], b          ; PRC Map Horizontal Scroll = $00
	mov [n+$87], b
	mov [n+$88], b
	mov [n+$89], b          ; PRC Sprite Tile Base = $000000
	; Clear RAM
	xor a, a
	mov x, $1000
clearram_1:
	mov [x], a
	inc x
	cmp x, $2000
	jnz clearram_1
	; Init LCD
	call init_lcd           ; Init LCD
	mov [n+$FE], $AF        ; Display On
	callw clear_lcd         ; Clear directly the LCD
	or [n+$80], $0A         ; Enable PRC Map (FreeBIOS)
	or [n+$81], $01         ; Set bit 0
	; Detect low power
	tst [n+$10], $20
	jnz freebioslogo
checkgame:
	call checkcartridge
	jnz freebioslogo
startgame:
	; Restore default PRC map
	xor a, a
	mov [n+$80], $00        ; Disable PRC
	mov [n+$81], $07
	mov [n+$82], a
	mov [n+$83], a          ; PRC Map Tile Base = $000000
	and [n+$01], $EF        ; Clear Reg[$01] bit 4
	; Clear RAM again
	mov x, $1000
clearram_2:
	mov [x], a
	inc x
	cmp x, $2000
	jnz clearram_2
	; Initialize registers
	mov ba, 0
	mov hl, ba
	mov x, ba
	mov y, ba
	mov b, [n+$52]          ; B = Power on keys
	mov a, $ff              ; A = Cart type
	and f, $C0              ; Clear all flags except interrupt flag
	; Start the game...
	jmp @00002102

; Detect cartridge (FreeBIOS)
checkcartridge:
	mov a, [$2100]
	cmp a, $4D
	ret nz
	mov a, [$2101]
	cmp a, $4E
	ret

; Draw FreeBIOS Logo (FreeBIOS)
freebioslogo:
	mov b, 3
freebioslogo_loop:
	push ba
	; Draw logo
	mov a, $01
	mov x, $137D
	mov b, $03
	call drawsequence
	mov x, $1388
	mov b, $04
	call drawsequence
	; Draw low power
	tst [n+$10], $20
	jz freebioslogo_haspower
	mov x, $1394
	mov a, $08
	mov b, $04
	call drawsequence
freebioslogo_haspower:
	; Draw no-cartridge
	call checkcartridge
	jz freebioslogo_hascart
	mov x, $13A0
	mov a, $0C
	mov b, $04
	call drawsequence
freebioslogo_hascart:
	; Delay
	call delay_some
	; Clear low power
	mov x, $1394
	mov a, $00
	mov b, $04
	call drawfixed
	; Delay
	call delay_some
	pop ba
	jdbnz freebioslogo_loop
	; Clear no-cartridge
	mov x, $13A0
	mov a, $00
	mov b, $04
	call drawfixed
	; Delay
	call delay_some
	jmp checkgame

; Draw fixed (FreeBIOS)
drawfixed:
	mov [x], a
	inc x
	jdbnz drawfixed
	ret 

; Draw sequence (FreeBIOS)
drawsequence: 
	mov [x], a
	inc x
	inc a
	jdbnz drawsequence
	ret 

; Delay some time (FreeBIOS)
delay_some:
	mov a, 255
delay_some_loop1:
	mov b, 255
delay_some_loop2:
	jdbnz delay_some_loop2
	dec a
	jnz delay_some_loop1
	ret

; Initialize I/O
init_io:
	mov b, $00
	mov [n+$10], $08        ; Battery Sensor
	and [n+$19], $CF        ; Clear Timer 1 but leave Osci. enablers
	mov [n+$20], b
	mov [n+$21], $30        ; Cartridge Interrupts Priority 3
	mov [n+$22], $02        ; IR/Shock Priority 2
	mov [n+$23], b
	mov [n+$24], $02        ; Enable 1Hz Timer Interrupt
	mov [n+$25], b
	mov [n+$26], b
	mov [n+$40], b          ; Disable 256 Hz Timer
	mov [n+$44], b          ; ???
	mov [n+$50], $FF        ; ???
	mov [n+$51], b          ; ???
	mov [n+$54], b          ; ???
	mov [n+$55], b          ; ???
	or [n+$60], $0C         ; Set EEPROM pins high
	and [n+$61], $FB        ; EEPROM Data as input
	or [n+$61], $08         ; EEPROM Clock as output
	or [n+$61], $04         ; EEPROM Data as output
	mov [n+$61], $20        ; IR Disable as output, all others as input
	mov [n+$60], $32        ; Disable IR
	mov [n+$62], b          ; ???
	mov [n+$70], b          ; ???
	mov [n+$71], b          ; Disable sound
	mov [n+$FE], $81        ; Set contrast ...
	mov [n+$FE], $1F	; ... to $1F
	ret

; Initialize LCD
init_lcd:
	push hl
	mov hl, $20FE
	mov [hl], $E3           ; ??
	mov [hl], $A4           ; Set All Pixels: Disable
	mov [hl], $AD           ; ??
	mov [hl], $00           ; Set column $00
	mov [hl], $10
	mov [hl], $EE           ; ??
	mov [hl], $40           ; initial display line to 0
	mov [hl], $A2           ; Max Contrast: Disable
	mov [hl], $A0           ; Invert Half Horizontal: Disable
	mov [hl], $C0           ; From top to bottom
	mov [hl], $A6           ; Invert All Pixels: Disable
	mov [hl], $2F           ; Turn on internal voltage booster & regulator
	pop hl
	ret

; Clear LCD directly
clear_lcd:
	mov hl, $20FE           ; Mem[20FE]
	mov [hl], $E3           ; ??
	mov h, $B0              ; Set Page 0
clear_lcd_B0_to_B8:
	mov [hl], h	        ; Write Page
	mov [hl], $00           ; Set Column x0
	mov [hl], $10           ; Set Column 0x
	mov b, $60              ; Number of columns per page
	inc hl                  ; Mem[20FF]
clear_lcd_clearcolumns:
	mov [n+$FF], $00
	jdbnz clear_lcd_clearcolumns
	dec hl                  ; Mem[20FE]
	inc h                   ; Increase the Page
	cmp h, $B8              ; Check if reached the last page
	jnz clear_lcd_B0_to_B8
	ret

int03_2108:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002108

int04_210E:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @0000210E

int05_2114:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002114

int06_211A:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @0000211A

int07_2120:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002120

int08_2126:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002126

int09_212C:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @0000212C

int0A_2132:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002132

int0B_2138:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002138

int0C_213E:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @0000213E

int0D_2144:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002144

int0E_214A:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @0000214A

int0F_2150:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002150

int10_2156:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002156

int14_219E:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @0000219E

int16_2162:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002162

int17_2168:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002168

int18_216E:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @0000216E

int19_2174:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002174

int1A_217A:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @0000217A

int1B_2180:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002180

int1C_2186:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002186

int1D_218C:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @0000218C

int1E_2192:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002192

int1F_2198:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20
	callz IntrAlt
	pop n
	pop i
	jmp @00002198

int15_215C:
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $20        ; Handle IRQs in cartrige
	jnz int15_215C_2
	tst [n+$01], $10        ; Test Reg[$01] Bit 4
	jnz sreset              ; Reset if set (Shutdown)
	tst [n+$71], $04        ; Cart power
	jz int15_215C_3
	tst [n+$02], $40        ; ???
	jz int15_215C_3
	; Cart power is off and something else...
	and [n+$71], $FB
	or [n+$02], $80
int15_215C_3:
	tst [n+$01], $80        ; RAM Vector defined?
	jz int15_215C_4
	tst [n+$02], $20        ; ???
	jnz int15_215C_5
	pop n
	pop i
	jmp ram_vector
int15_215C_2:                   ; Handle power button interrupt in cartridge
	pop n
	pop i
	jmp @0000215C
int15_215C_4:                   ; No RAM vector
	or [n+$01], $20         ; Set Handle IRQs in cartridge
	tst [n+$02], $20        ; ???
	jnz int15_215C_2
int15_215C_5:                   ; Exit power button IRQ
	mov [n+$29], $80        ; Mask as complete
	pop n
	pop i
	reti

; Interrupt alternative (when IRQ not handled by the cartridge)
IntrAlt:
	tst [n+$71], $04        ; Cart power
	jz IntrAlt_haspower
	tst [n+$02], $40        ; ???
	jz IntrAlt_haspower
	; Cart power is off and something else...
	and [n+$71], $FB
	or [n+$02], $80
IntrAlt_haspower:
	tst [n+$01], $80        ; RAM Vector defined?
	jz IntrAlt_noramvector
	add sp, 3               ; Unstack interrupt return address
	pop n
	pop i
	jmp ram_vector
IntrAlt_noramvector:
	or [n+$01], $20         ; Set Handle IRQs in cartridge
	ret

reticode:
	reti

; Suspend/Shutdown pokemon-mini
SuspendShutdown:
	; This is not how the real BIOS does... but oh well.
	and [n+$80], $F7        ; Disable PRC
	mov [n+$FE], $AE        ; Display Off
	mov [n+$FE], $AC        ; ???
	mov [n+$FE], $28        ; Turn off voltage booster / op-amp buffer
	mov [n+$FE], $A5        ; Set All Pixels: Enable
	and [n+$02], $E3        ; Unknown
	and [n+$81], $FE        ; ???
	or [n+$02], $01         ; ???
	or [n+$24], $02         ; Cartridge Eject IRQ
	or [n+$21], $30         ; Enable Cartridge IRQ
	and [n+$01], $DF        ; Disable cart interrupts
	and [n+$02], $E3        ; ???
	push f
	mov f, $80              ; Enable interrupt (!?)
	halt                    ; Halt the CPU
	pop f
	or [n+$02], $10         ; ???
	or [n+$81], $01         ; ???
	callw init_lcd          ; Init LCD
	mov [n+$FE], $AF        ; Display On
	and [n+$02], $DF        ; Enable cart interrupts
	or [n+$00], $03         ; Enable Cartridge and LCD
	ret

; cint $21 - ROU - Suspend System
Intr21h:
	; Suspend System
	push i
	push n
	mov f, $C0
	mov i, $00
	mov n, $20
	; Back up registers
	mov b, [n+$80]
	mov a, [n+$21]
	and a, $0C
	push ba
	mov b, [n+$23]
	mov a, [n+$24]
	push ba
	mov b, [n+$25]
	mov a, [n+$26]
	push ba
	; Setup registers
	mov [n+$23], $00
	mov [n+$24], $00
	mov [n+$25], $80        ; Only enable power key interrupt
	mov [n+$26], $00
	or [n+$21], $0C
	mov [n+$29], $80
	mov [n+$80], $00
	; Something cause the PM to suspend
	call SuspendShutdown
	; Restore registers
	pop ba
	mov [n+$25], b
	mov [n+$26], a
	pop ba
	mov [n+$23], b
	mov [n+$24], a
	pop ba
	mov [n+$80], b
	and a, $F3
	mov [n+$21], a
	pop n
	pop i
	reti

; cint $24 - ROU - Shutdown System
Intr24h:
	; Shutdown System
	mov f, $C0
	mov sp, $2000
	mov i, $00
	mov n, $20
	callw init_io
	mov [n+$23], $00
	mov [n+$24], $00
	mov [n+$25], $80        ; Only enable power key interrupt
	mov [n+$26], $00
	mov [n+$29], $80
	mov [n+$80], $00
	mov [n+$21], $0C
	callw SuspendShutdown
	jmp sreset

; cint $26 - ROU - Set default LCD Constrast
Intr26h:
	; Set default LCD Constrast (A = Contrast level 0x00 to 0x3F) 
	pop f
Intr26h_0:
	push i
	push hl
	mov i, $00
	mov hl, $2000
	shl a
	shl a
	and [hl], $03
	or [hl], a
	pop hl
	pop i
	jmp Intr28h_0

; cint $27 - ROU - Increase or decrease Contrast based of Zero flag...
Intr27h:
	; Increase or decrease Contrast based of Zero flag (0 = Increase, 1 = Decrease)
	; Return A = 0x00 if succeed, 0xFF if not.
	call Intr29h_0
	pop f
	push f                  ; We need to get the flags that were stored in stack but still remain stack intact
	jz Intr27h_Inc
Intr27h_Dec:
	cmp a, $3F              ; Check if is $3F ...
	jz Intr27h_Err          ; ... return error if so
	inc a
	jmp Intr27h_SetOk
Intr27h_Inc:
	or a, a                 ; Check if is $00 ...
	jz Intr27h_Err          ; ... return error if so
	dec a
	jmp Intr27h_SetOk
Intr27h_Err:
	mov a, $FF
	reti
Intr27h_SetOk:
	call Intr26h_0
	xor a, a
	reti

; cint $28 - ROU - Apply default LCD Constrast
Intr28h:
	; Apply default LCD Constrast
	pop f
Intr28h_0:
	call Intr29h_0
	jmp Intr2Ah_0

; cint $29 - ROU - Get default LCD Contrast
Intr29h:
	; Get default LCD Contrast (return A)
	pop f
Intr29h_0:
	push i
	push n
	mov i, $00
	mov n, $20
	mov a, [n+$00]
	shr a
	shr a
	pop n
	pop i
	ret

; cint $2A - ROU - Set temporary LCD Constrast
Intr2Ah:
	; Set temporary LCD Constrast (A = Contrast level 0x00 to 0x3F)
	pop f                   ; We need to return the flags (beats me why...)
Intr2Ah_0:
	push i
	push n
	mov i, $00
	mov n, $20
	mov b, a
	tst [n+$80], $08        ; Test if PRC Copy is enabled
	push f
	and [n+$80], $F7        ; Disable PRC Copy (...for safety)
	mov [n+$FE], $81
	mov [n+$FE], b
	pop f
	jz Intr2Ah_1
	or [n+$80], $08         ; Restore PRC Copy if was set before
Intr2Ah_1:
	pop n
	pop i
	ret

; cint $2B - ROU - Turn LCD On
Intr2Bh:
	; Turn LCD On
	push i
	push n
	mov i, $00
	mov n, $20
	callw init_lcd          ; Init LCD
	mov [n+$FE], $AF        ; Display On
	or [n+$80], $04         ; Enable PRC Copy
	or [n+$81], $01         ; Set bit 0
	pop n
	pop i
	reti	

; cint $2C - ROU - Initialize LCD
Intr2Ch:
	; Initialize LCD
	push i
	push n
	mov i, $00
	mov n, $20
	callw init_lcd          ; Init LCD
	pop n
	pop i
	reti

; cint $2D - ROU - Turn LCD Off
Intr2Dh:
	; Turn LCD Off
	push i
	push n
	mov i, $00
	mov n, $20
	and [n+$80], $F7        ; Disable PRC Copy
	mov [n+$FE], $AE        ; Display Off
	mov [n+$FE], $AC        ; ???
	mov [n+$FE], $28        ; Turn off voltage booster / op-amp buffer
	mov [n+$FE], $A5        ; Set All Pixels: Enable
	and [n+$81], $FE        ; Clear bit 0
	pop n
	pop i
	reti

; cint $2E - ROU - Check if Register 0x01 Bit 7 is set, if not then set bit 6 and 7 
Intr2Eh:
	; Check if Register 0x01 Bit 7 is set, if not, it set bit 6 and 7
	push i
	push n
	mov i, $00
	mov n, $20
	mov f, $C0
	tst [n+$01], $80
	jnz Intr2Eh_0
	or [n+$01], $80
	or [n+$01], $40
	and [n+$01], $DF
Intr2Eh_0:
	pop n
	pop i
	reti

; cint $39 - ROU - Disable Cartridge and LCD
Intr39h:
	; Disable Cartridge and LCD
	push i
	push n
	mov i, $00
	mov n, $20
	and [n+$00], $FC
	pop n
	pop i
	reti

; cint $3A - ROU - Enable Cartridge and LCD
Intr3Ah:
	; Recover from IRQ $39 (Enable Cartridge and LCD)
	push i
	push n
	mov i, $00
	mov n, $20
	or [n+$00], $03
	pop n
	pop i
	reti

; cint $3D - ROU - Test Register 0x53 Bit 1 and invert Zero flag
Intr3Dh:
	; Test Register 0x53 Bit 1 and invert Zero flag
	pop f
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$53], $02
	xor f, $01
	pop n
	pop i
	ret

; cint $3E - ROU - Read structure, write 0xFF, compare values and optionally jump to subroutine...
Intr3Eh:
	; Read structure, write 0xFF, compare values and optionally jump to subroutine
	; X point to a structure in memory:
	; structure {
	;  byte   type            ; 0x01 = Call subroutine, 0x00 = Don't call subroutine
	;  triple write_0xFF_addr ; Address that 0xFF will be written
	;  triple compare_addr    ; Address to read for compare
	;  byte   compare_value   ; Value that must match the compare
	;  triple subroutine      ; Use byte POP to receive flag of the compare
	; }
	; if type is 0x00, register A return 0x01 if compare is equal
	push i
	push n
	mov i, $00
	mov n, $20
	pushx
	push x
	push y
	push hl
	push b                  ; Push all registers except "A"
	mov f, $C0
	mov a, [x]
	tst a, $01              ; Test Bit 0 of type in the structure
	mov a, f
	jz Intr3Eh_0            ; Jump if type 0x00

	add x, $000A
	mov h, [x]
	dec x
	mov l, [x]
	dec x
	push hl
	mov b, [x]
	dec x
	jmp Intr3Eh_1

Intr3Eh_0:
	add x, $0007
Intr3Eh_1:

	push ba
	mov b, [x]              ; B = compare_value
	dec x
	mov a, [x]
	dec x
	mov h, [x]
	dec x
	mov l, [x]
	dec x
	mov yi, a
	mov y, hl               ; YI & Y = compare_address
	mov a, [x]
	dec x
	mov h, [x]
	dec x
	mov l, [x]
	mov xi, a
	mov x, hl               ; XI & X = write_0xFF_addr

	or [n+$02], $80         ; No clue why... but... maybe there's a reason...
	mov [x], $FF           ; ??
	or [n+$02], $80
	mov a, [y]
	or [n+$02], $80
	cmp a, b
	pop ba                  ; Restore top push, it holds the low addr byte of the subroutine... \
	push f                  ; (Backup compare result)                                           |
	mov f, a                ; ...and bit 0 test of the type in structure... <-------------------'
	jz Intr3Eh_2            ; Skip if type is 0x00
	pop f                   ; Restore the compare result
	mov l, b                ; L = Low Byte Address
	pop ba
	mov h, a                ; H = High Byte Address
	mov a, b                ; A = Bank of Address
	push f                  ; Push the compare result into stack
	call Intr3Eh_3
Intr3Eh_2:
	pop ba
	and a, $01		; Only return the lowest bit as the result
	pop hl
	pop y
	pop x
	popx			; Restore all registers except "A"
	pop n
	pop i
	reti

Intr3Eh_3:
	mov u, a
	jmp hl			; jump to the Subroutine... use POP to receive compare result

; cint $3F - ROU - Set PRC Rate
Intr3Fh:
	; Set PRC Rate (A = 0 to 7)
	push i
	push hl
	mov i, $00
	mov hl, $2081
	and [hl], $F1
	and a, $07
	shl a
	or [hl], a
	pop hl
	pop i
	reti

; cint $40 - ROU - Get PRC Rate
Intr40h:
	; Get PRC Rate (return A)
	push i
	push n
	mov i, $00
	mov n, $20
	mov a, [n+$81]
	shr a
	and a, $07
	pop n
	pop i
	reti

; cint $41 - ROU - Test Register 0x01 Bit 3
Intr41h:
	; Test Register 0x01 Bit 3
	pop f
	push i
	push n
	mov i, $00
	mov n, $20
	tst [n+$01], $08
	pop n
	pop i
	ret

; cint $4C - ROU - MOV [Y], $02 ; wait B*16 Cycles ; MOV [Y], $00
Intr4Ch:
	; MOV [Y], $02 ; wait B*16 Cycles ; MOV [Y], $00
	mov [y], $02
Intr4Ch_0:
	jdbnz Intr4Ch_0
	mov [y], $00
	reti

	.align 8
Graphics:
	.incbin gfx.bin

	.orgfill 0x1000 - 64

	;    0123456789ABCDEF
	.db "    Freeware    "
	.db "PokemonMini BIOS"
	.db "  Version  1.3  "
	.db " by Team Pokeme "
