; Copyright (C) 2015 by JustBurn
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
; THE SOFTWARE.

.if . < 0x2200
.error "this file must be included after pm_header"
.endif

	; PokeMini Music Player
	;
	; Timers used:
	; TIMER 2 to tick music
	; TIMER 3 for the sound
	;
	; Ctrl [Data...]
	; Bit 15  - Loop*
	; Bit 14  - Jump Pattern or End Sound*
	; Bit 13  - Set Pivot*
	; Bit 12  - Set Frequency*
	; Bit 11  - Write RAM*
	; Bit 10  - Set Volume
	; Bit 8~9 - Volume, 0 to 3
	; Bit 0~7 - Wait time, 0 to 255 (0 = Immediate)

.equ	IRQ_MUSIC $000004	; Same as IRQ_TMR2_HI

	; Main Data
.ram pmmusram_aud_ena   1   ; &1 = BGM, &2 = SFX
.ram pmmusram_aud_cfg   1
	; &128 = Unused
	; &64  = Unused
	; &32  = Jump pattern / End Sound
	; &16  = Write to RAM
	; &8   = Set Pivot
	; &4   = Set Frequency
.ram pmmusram_ram_ptr   2   ; RAM pointer
.ram pmmusram_bgm_ptb   3   ; BGM Absolute pattern address

	; BGM Data
.ram pmmusram_bgm_wait  1   ; BGM wait num ticks
.ram pmmusram_bgm_mvol  1   ; BGM Master volume
.ram pmmusram_bgm_pvol  1   ; BGM Play volume
.ram pmmusram_bgm_ppr   3   ; BGM Absolute music pointer address
.ram pmmusram_bgm_frq   2   ; BGM Playing Frequency
.ram pmmusram_bgm_pvt   2   ; BGM Playing Pivot
.ram pmmusram_bgm_tvol  4   ; BGM volume table, &3 = Volume, &4 = SHR Pivot
.ram pmmusram_bgm_loop0 4   ; BGM Loop 0 (Ptr3, Num loops)
.ram pmmusram_bgm_loop1 4   ; BGM Loop 1 (Ptr3, Num loops)
.ram pmmusram_bgm_loop2 4   ; BGM Loop 2 (Ptr3, Num loops)
.ram pmmusram_bgm_loop3 4   ; BGM Loop 3 (Ptr3, Num loops)

	; SFX Data
.ram pmmusram_sfx_wait  1   ; SFX Wait num ticks
.ram pmmusram_sfx_mvol  1   ; SFX Master volume
.ram pmmusram_sfx_pvol  1   ; SFX Play volume
.ram pmmusram_sfx_ppr   3   ; SFX Absolute music pointer address
.ram pmmusram_sfx_frq   2   ; SFX Playing Frequency
.ram pmmusram_sfx_pvt   2   ; SFX Playing Pivot
.ram pmmusram_sfx_tvol  4   ; SFX volume table, &3 = Volume, &4 = SHR Pivot
.ram pmmusram_sfx_loop0 4   ; SFX Loop 0 (Ptr3, Num loops)
.ram pmmusram_sfx_loop1 4   ; SFX Loop 1 (Ptr3, Num loops)
.ram pmmusram_sfx_loop2 4   ; SFX Loop 2 (Ptr3, Num loops)
.ram pmmusram_sfx_loop3 4   ; SFX Loop 3 (Ptr3, Num loops)

	; (( Initialize tracker ))
	; BA = RAM Pointer
	; HL = Master time
	; No return
pmmusic_init:
	push i
	push ba
	mov i, 0
	; Set master time
	mov [REG_BASE+TMR2_PRE], hl
	; Set RAM pointer
	mov [pmmusram_ram_ptr], ba
	; Registers to zero
	mov ba, 0
	mov [pmmusram_aud_ena], a
	mov [pmmusram_bgm_frq], ba
	mov [pmmusram_bgm_pvt], ba
	mov [pmmusram_sfx_frq], ba
	mov [pmmusram_sfx_pvt], ba
	or [n+IRQ_PRI1], IRQ_PRI1_TMR2
	mov [n+AUD_VOL], a
	mov [n+TMR2_OSC], a
	mov [n+TMR2_SCALE], TMR_DIV_256
	mov [n+TMR3_OSC], a
	mov [n+TMR3_SCALE], TMR_DIV_2
	mov [REG_BASE+TMR2_CTRL], ba
	mov [REG_BASE+TMR3_PRE], ba
	mov [REG_BASE+TMR3_PVT], ba
	; Registers to non-zero
	mov a, 3
	mov b, [$14E2]
	tst b, KEY_C
	jnz :f
	mov a, 0
:	call pmmusic_setvolbgm
	call pmmusic_setvolsfx
	mov ba, TMR_ENABLE | TMR_16BITS | TMR_PRESET
	mov [REG_BASE+TMR3_CTRL], ba
	or [n+TMR1_ENA_OSC], TMRS_OSC1
	pop ba
	pop i
	ret

	; (( Set master time ))
	; HL = Master time
	; No return
pmmusic_setmastertime:
	mov [REG_BASE+TMR2_PRE_L], l
	mov [REG_BASE+TMR2_PRE_H], h
	ret

	; (( Get master time ))
	; No parameters
	; Return HL = Master time
pmmusic_getmastertime:
	mov l, [REG_BASE+TMR2_PRE_L]
	mov h, [REG_BASE+TMR2_PRE_H]
	ret

	; (( Set RAM pointer ))
	; HL = RAM Pointer
	; No return
pmmusic_setrampointer:
	mov [pmmusram_ram_ptr], l
	mov [pmmusram_ram_ptr+1], h
	ret

	; (( Get RAM pointer ))
	; No parameters
	; Return HL = RAM Pointer
pmmusic_getrampointer:
	mov l, [pmmusram_ram_ptr]
	mov h, [pmmusram_ram_ptr+1]
	ret

	; (( Set BGM master volume ))
	; A = Volume
	; No return
pmmusic_setvolbgm:
	cmp a, 4
	jncb :f
	pushx
	push ba
	push x
	push y
	mov yi, 0
	mov xi, 0
	mov [pmmusram_bgm_mvol], a
	shl a
	shl a
	mov y, pmmusram_bgm_tvol
	mov x, pmmusic_voltable
	mov b, 0
	add x, ba
	mov a, [x]
	mov [y], a
	mov a, [x+1]
	mov [y+1], a
	mov a, [x+2]
	mov [y+2], a
	mov a, [x+3]
	mov [y+3], a
	pop y
	pop x
	pop ba
	popx
:	ret

	; (( Get BGM master volume ))
	; No parameters
	; Return A = Volume
pmmusic_getvolbgm:
	mov a, [pmmusram_bgm_mvol]
	ret

	; (( Set SFX master volume ))
	; A = Volume
	; No return
pmmusic_setvolsfx:
	cmp a, 4
	jncb :f
	pushx
	push ba
	push x
	push y
	mov yi, 0
	mov xi, 0
	mov [pmmusram_sfx_mvol], a
	shl a
	shl a
	mov y, pmmusram_sfx_tvol
	mov x, pmmusic_voltable
	mov b, 0
	add x, ba
	mov a, [x]
	mov [y], a
	mov a, [x+1]
	mov [y+1], a
	mov a, [x+2]
	mov [y+2], a
	mov a, [x+3]
	mov [y+3], a
	pop y
	pop x
	pop ba
	popx
:	ret

	; (( Get SFX master volume ))
	; No parameters
	; Return A = Volume
pmmusic_getvolsfx:
	mov a, [pmmusram_sfx_mvol]
	ret

	; (( Play BGM ))
	; I+HL = BGM Address
	; No return
pmmusic_playbgm:
	push f
	push i
	push ba
	mov f, $C0
	; Set pattern table
	mov a, i
	mov [pmmusram_bgm_ptb+2], a
	mov [pmmusram_bgm_ptb+1], h
	mov [pmmusram_bgm_ptb], l
	; Set BGM pointer
	mov a, b
	mov i, a
	mov ba, [hl]
	inc hl
	inc hl
	mov l, [hl]
	mov i, 0
	mov [pmmusram_bgm_ppr], ba
	mov [pmmusram_bgm_ppr+2], l
	mov a, 1
	mov [pmmusram_bgm_wait], a
	; Enable BGM play
	mov a, [pmmusram_aud_ena]
	or a, $01
	mov [pmmusram_aud_ena], a
	or [n+IRQ_ENA1], IRQ_ENA1_TMR2_HI
	tst a, $02
	jnzb :f
	mov ba, TMR_ENABLE | TMR_16BITS | TMR_PRESET
	mov [REG_BASE+TMR2_CTRL], ba
	mov ba, 0
	mov [REG_BASE+TMR3_PRE], ba
	or [n+TMR3_CTRL], TMR_ENABLE | TMR_PRESET
:	pop ba
	pop i
	pop f
	ret

	; (( Stop BGM ))
	; No parameters
	; No return
pmmusic_stopbgm:
	push f
	push ba
	mov f, $C0
	; Disable BGM play
	mov a, $02
	and a, [pmmusram_aud_ena]
	mov [pmmusram_aud_ena], a
	jnzb :f
	push i
	mov i, 0
	and [n+IRQ_ENA1], ~IRQ_ENA1_TMR2_HI
	and [n+TMR2_CTRL], ~TMR_ENABLE
	and [n+TMR3_CTRL], ~TMR_ENABLE
	pop i
:	pop ba
	pop f
	ret

	; (( Is playing BGM? ))
	; No parameters
	; Return F = Playing if Non-Zero
	; Return A = Playing is Non-Zero
pmmusic_isplayingbgm:
	push i
	mov i, 0
	mov a, $01
	and a, [pmmusram_aud_ena]
	pop i
	ret

	; (( Play SFX ))
	; I+HL = SFX Address
	; No return
pmmusic_playsfx:
	push f
	push i
	push ba
	mov f, $C0
	; Set SFX pointer
	mov a, i
	mov [pmmusram_sfx_ppr+2], a
	mov [pmmusram_sfx_ppr+1], h
	mov [pmmusram_sfx_ppr], l
	mov a, 1
	mov [pmmusram_sfx_wait], a
	mov i, 0
	; Enable SFX play
	mov i, 0
	mov a, $02
	or a, [pmmusram_aud_ena]
	mov [pmmusram_aud_ena], a
	or [n+IRQ_ENA1], IRQ_ENA1_TMR2_HI
	mov ba, TMR_ENABLE | TMR_16BITS | TMR_PRESET
	mov [REG_BASE+TMR2_CTRL], ba
	; Clear timer 3 preset
	mov a, [pmmusram_sfx_mvol]
	cmp a, 0
	jzb :f
	mov ba, 0
	mov [REG_BASE+TMR3_PRE], ba
	or [n+TMR3_CTRL], TMR_ENABLE | TMR_PRESET
:	pop ba
	pop i
	pop f
	ret

	; (( Stop SFX ))
	; No parameters
	; No return
pmmusic_stopsfx:
	push f
	push ba
	mov f, $C0
	; Disable SFX play
	mov a, $01
	and a, [pmmusram_aud_ena]
	mov [pmmusram_aud_ena], a
	jnzb :f
	push i
	mov i, 0
	and [n+IRQ_ENA1], ~IRQ_ENA1_TMR2_HI
	and [n+TMR2_CTRL], ~TMR_ENABLE
	and [n+TMR3_CTRL], ~TMR_ENABLE
	pop i
:	pop ba
	pop f
	ret

	; (( Is playing SFX? ))
	; No parameters
	; Return F = Playing if Non-Zero
	; Return A = Playing is Non-Zero
pmmusic_isplayingsfx:
	push i
	mov i, 0
	mov a, $02
	and a, [pmmusram_aud_ena]
	pop i
	ret

	; (( Process sound from interrupt ))
	; No parameters
	; No return
irq_tmr2_hi:
	push ba
	push hl
	push x
	push i
	pushx
	mov i, 0
	; Process BGM
_checkBGM:
	mov a, $01
	and a, [pmmusram_aud_ena]
	jzw _checkSFX
_decwaitBGM:
	; Decrease BGM wait
	mov hl, pmmusram_bgm_wait
	dec [hl]
	jnzw _checkSFX
_goBGM:
	; Read data from BGM pointer
	mov x, [pmmusram_bgm_ppr]
	mov a, [pmmusram_bgm_ppr+2]
	mov xi, a
	; Set wait and volume
	mov ba, [x]
	mov [pmmusram_bgm_wait], a
	mov [pmmusram_aud_cfg], b
	tst b, $04
	jzb _BGMnovol
	mov a, b
	mov b, 0
	and a, $03
	mov hl, pmmusram_bgm_tvol
	add hl, ba
	mov a, [hl]
	mov [pmmusram_bgm_pvol], a
_BGMnovol:
	; Increment BGM pointer to next command
	mov b, 0
	mov a, [pmmusram_aud_cfg]
	shr a
	shr a
	shr a
	mov hl, pmmusic_cmdextableadd
	add hl, ba
	mov a, [hl]
	mov hl, x
	add hl, ba
	mov [pmmusram_bgm_ppr], hl
	jncb _bgm_noinc1
	mov hl, pmmusram_bgm_ppr+2
	inc [hl]
_bgm_noinc1:
	; ---------
	; Write RAM
_BGM_Cwriteram:
	mov a, $08
	and a, [pmmusram_aud_cfg]
	jzb _BGM_Csetfreq
	inc x
	inc x
	jnzb _BGM_Rwriteram
	mov a, xi
	inc a
	mov xi, a
_BGM_Rwriteram:
	mov hl, [pmmusram_ram_ptr]
	mov b, 0
	mov a, [x+1]
	add hl, ba
	mov [hl], [x]
	; -------------
	; Set Frequency
_BGM_Csetfreq:
	mov a, $10
	and a, [pmmusram_aud_cfg]
	jzb _BGM_Csetpivot
	inc x
	inc x
	jnzb _BGM_Rsetfreq
	mov a, xi
	inc a
	mov xi, a
_BGM_Rsetfreq:
	mov ba, [x]
	mov [pmmusram_bgm_frq], ba
	; ---------
	; Set Pivot
_BGM_Csetpivot:
	mov a, $20
	and a, [pmmusram_aud_cfg]
	jzb _BGM_Cnextend
	inc x
	inc x
	jnzb _BGM_Rsetpivot
	mov a, xi
	inc a
	mov xi, a
_BGM_Rsetpivot:
	mov ba, [x]
	mov [pmmusram_bgm_pvt], ba
	; ------------------------
	; Jump pattern / End Sound
_BGM_Cnextend:
	mov a, $40
	and a, [pmmusram_aud_cfg]
	jzb _BGM_Cloop
	inc x
	inc x
	jnzb _BGM_Rnextend
	mov a, xi
	inc a
	mov xi, a
_BGM_Rnextend:
	mov ba, [x]
	cmp ba, 0
	jnzb _BGM_Rpatt
	call pmmusic_stopbgm
	jmpb _BGM_Cloop
_BGM_Rpatt:
	tst b, $80
	jnzb _BGM_Rpattsub
	mov hl, [pmmusram_bgm_ptb]
	add hl, ba
	mov [pmmusram_bgm_ptb], hl
	mov a, [pmmusram_bgm_ptb+2]
	jncb _BGM_Rpatt_noinc1
	inc a
	mov [pmmusram_bgm_ptb+2], a
_BGM_Rpatt_noinc1:
	jmpb _BGM_Rpatt_set
_BGM_Rpattsub:
	mov hl, [pmmusram_bgm_ptb]
	add hl, ba
	mov [pmmusram_bgm_ptb], hl
	mov a, [pmmusram_bgm_ptb+2]
	jcb _BGM_Rpatt_noinc2
	inc a
	mov [pmmusram_bgm_ptb+2], a
_BGM_Rpatt_noinc2:
_BGM_Rpatt_set:
	mov i, a
	mov ba, [hl]
	inc hl
	inc hl
	mov l, [hl]
	mov i, 0
	mov [pmmusram_bgm_ppr], ba
	mov [pmmusram_bgm_ppr+2], l
	; ----
	; Loop
_BGM_Cloop:
	mov a, $80
	and a, [pmmusram_aud_cfg]
	jzb _BGM_Cdone
	inc x
	inc x
	jnzb _BGM_Rloop
	mov a, xi
	inc a
	mov xi, a
_BGM_Rloop:
	mov hl, [x]
	and h, $0C
	cmp l, 0
	jnzb _BGM_Rloop_loop
	; Mark Loop
	mov a, h
	mov b, 0
	mov hl, pmmusram_bgm_loop0
	add hl, ba
	mov ba, [pmmusram_bgm_ppr]
	mov [hl], ba
	inc hl
	inc hl
	mov a, [pmmusram_bgm_ppr+2]
	mov [hl], a
	inc hl
	xor a, a
	mov [hl], a
	jmpb _BGM_Cdone
_BGM_Rloop_loop:
	; Loop back
	mov a, h
	mov b, 0
	mov hl, pmmusram_bgm_loop0+3
	add hl, ba
	mov a, [x]
	cmp a, [hl]
	jzb _BGM_Cdone
	inc [hl]
	dec hl
	mov a, [hl]
	mov [pmmusram_bgm_ppr+2], a
	dec hl
	dec hl
	mov ba, [hl]
	mov [pmmusram_bgm_ppr], ba
	; ---------
	; All done!
_BGM_Cdone:
	mov a, $FF
	and a, [pmmusram_bgm_wait]
	jzw _goBGM
	; Check SFX first as it have higher priority
	mov a, [pmmusram_sfx_mvol]
	cmp a, 0
	jzb _setBGMaudio
	mov a, $02
	and a, [pmmusram_aud_ena]
	jnzb _checkSFX
	; Set BGM audio
_setBGMaudio:
	mov hl, [pmmusram_bgm_frq]
	mov [REG_BASE+TMR3_PRE], hl
	mov hl, [pmmusram_bgm_pvt]
	mov a, [pmmusram_bgm_pvol]
	tst a, $04
	jzb _BGM_noSHRpivot
	mov ba, hl
	shr b
	rorc a
	shr b
	rorc a
	shr b
	rorc a
	shr b
	rorc a
	shr b
	rorc a
	mov hl, ba
	mov a, [pmmusram_bgm_pvol]
_BGM_noSHRpivot:
	mov [REG_BASE+TMR3_PVT], hl
	and a, $03
	mov [n+AUD_VOL], a
	; Process SFX
_checkSFX:
	mov a, $02
	and a, [pmmusram_aud_ena]
	jzw _goEND
_decwaitSFX:
	; Decrease SFX wait
	mov hl, pmmusram_sfx_wait
	dec [hl]
	jnzw _goEND
_goSFX:
	; Read data from SFX pointer
	mov x, [pmmusram_sfx_ppr]
	mov a, [pmmusram_sfx_ppr+2]
	mov xi, a
	; Set wait and volume
	mov ba, [x]
	mov [pmmusram_sfx_wait], a
	mov [pmmusram_aud_cfg], b
	tst b, $04
	jzb _SFXnovol
	mov a, b
	mov b, 0
	and a, $03
	mov hl, pmmusram_sfx_tvol
	add hl, ba
	mov a, [hl]
	mov [pmmusram_sfx_pvol], a
_SFXnovol:
	; Increment SFX pointer to next command
	mov b, 0
	mov a, [pmmusram_aud_cfg]
	shr a
	shr a
	shr a
	mov hl, pmmusic_cmdextableadd
	add hl, ba
	mov a, [hl]
	mov hl, x
	add hl, ba
	mov [pmmusram_sfx_ppr], hl
	jncb _sfx_noinc1
	mov hl, pmmusram_sfx_ppr+2
	inc [hl]
_sfx_noinc1:
	; ---------
	; Write RAM
_SFX_Cwriteram:
	mov a, $08
	and a, [pmmusram_aud_cfg]
	jzb _SFX_Csetfreq
	inc x
	inc x
	jnzb _SFX_Rwriteram
	mov a, xi
	inc a
	mov xi, a
_SFX_Rwriteram:
	mov hl, [pmmusram_ram_ptr]
	mov b, 0
	mov a, [x+1]
	add hl, ba
	mov [hl], [x]
	; -------------
	; Set Frequency
_SFX_Csetfreq:
	mov a, $10
	and a, [pmmusram_aud_cfg]
	jzb _SFX_Csetpivot
	inc x
	inc x
	jnzb _SFX_Rsetfreq
	mov a, xi
	inc a
	mov xi, a
_SFX_Rsetfreq:
	mov ba, [x]
	mov [pmmusram_sfx_frq], ba
	; ---------
	; Set Pivot
_SFX_Csetpivot:
	mov a, $20
	and a, [pmmusram_aud_cfg]
	jzb _SFX_Cnextend
	inc x
	inc x
	jnzb _SFX_Rsetpivot
	mov a, xi
	inc a
	mov xi, a
_SFX_Rsetpivot:
	mov ba, [x]
	mov [pmmusram_sfx_pvt], ba
	; ------------------------
	; Jump pattern / End Sound
_SFX_Cnextend:
	mov a, $40
	and a, [pmmusram_aud_cfg]
	jzb _SFX_Cloop
	inc x
	inc x
	jnzb _SFX_Rnextend
	mov a, xi
	inc a
	mov xi, a
_SFX_Rnextend:
	call pmmusic_stopsfx
	; ----
	; Loop
_SFX_Cloop:
	mov a, $80
	and a, [pmmusram_aud_cfg]
	jzb _SFX_Cdone
	inc x
	inc x
	jnzb _SFX_Rloop
	mov a, xi
	inc a
	mov xi, a
_SFX_Rloop:
	mov hl, [x]
	and h, $0C
	cmp l, 0
	jnzb _SFX_Rloop_loop
	; Mark Loop
	mov a, h
	mov b, 0
	mov hl, pmmusram_sfx_loop0
	add hl, ba
	mov ba, [pmmusram_sfx_ppr]
	mov [hl], ba
	inc hl
	inc hl
	mov a, [pmmusram_sfx_ppr+2]
	mov [hl], a
	inc hl
	xor a, a
	mov [hl], a
	jmpb _SFX_Cdone
_SFX_Rloop_loop:
	; Loop back
	mov a, h
	mov b, 0
	mov hl, pmmusram_sfx_loop0+3
	add hl, ba
	mov a, [x]
	cmp a, [hl]
	jzb _SFX_Cdone
	inc [hl]
	dec hl
	mov a, [hl]
	mov [pmmusram_sfx_ppr+2], a
	dec hl
	dec hl
	mov ba, [hl]
	mov [pmmusram_sfx_ppr], ba
	; ---------
	; All done!
_SFX_Cdone:
	mov a, $FF
	and a, [pmmusram_sfx_wait]
	jzw _goSFX
	; Set SFX audio
	mov a, [pmmusram_sfx_mvol]
	cmp a, 0
	jzb _goEND
_setSFXaudio:
	mov hl, [pmmusram_sfx_frq]
	mov [REG_BASE+TMR3_PRE], hl
	mov hl, [pmmusram_sfx_pvt]
	mov a, [pmmusram_sfx_pvol]
	tst a, $04
	jzb _SFX_noSHRpivot
	mov ba, hl
	shr b
	rorc a
	shr b
	rorc a
	shr b
	rorc a
	shr b
	rorc a
	shr b
	rorc a
	mov hl, ba
	mov a, [pmmusram_sfx_pvol]
_SFX_noSHRpivot:
	mov [REG_BASE+TMR3_PVT], hl
	and a, $03
	mov [n+AUD_VOL], a
_goEND:
	popx
	pop i
	pop x
	pop hl
	pop ba
	mov [n+IRQ_ACT1], $20
	reti

pmmusic_voltable:
	.db $00, $00, $00, $00
	.db $00, $00, $06, $06
	.db $00, $06, $02, $02
	.db $00, $06, $02, $03

pmmusic_cmdextableadd:
	.db  2,  4,  4,  6,  4,  6,  6,  8,  4,  6,  6,  8,  6,  8,  8, 10
	.db  4,  6,  6,  8,  6,  8,  8, 10,  6,  8,  8, 10,  8, 10, 10, 12


	; Macros

.equ N____ -1

.equ N_C_1 $EEE3  ; 32.70 Hz
.equ N_CS1 $E17A  ; 34.65 Hz
.equ N_D_1 $D4D2  ; 36.71 Hz
.equ N_DS1 $C8E0  ; 38.89 Hz
.equ N_E_1 $BD9A  ; 41.20 Hz
.equ N_F_1 $B2F6  ; 43.65 Hz
.equ N_FS1 $A8EA  ; 46.25 Hz
.equ N_G_1 $9F6F  ; 49.00 Hz
.equ N_GS1 $967C  ; 51.91 Hz
.equ N_A_1 $8E0A  ; 55.00 Hz
.equ N_AS1 $8611  ; 58.27 Hz
.equ N_B_1 $7E8B  ; 61.74 Hz

.equ N_C_2 $7771  ; 65.41 Hz
.equ N_CS2 $70BC  ; 69.30 Hz
.equ N_D_2 $6A68  ; 73.42 Hz
.equ N_DS2 $646F  ; 77.78 Hz
.equ N_E_2 $5ECC  ; 82.41 Hz
.equ N_F_2 $597A  ; 87.31 Hz
.equ N_FS2 $5474  ; 92.50 Hz
.equ N_G_2 $4FB7  ; 98.00 Hz
.equ N_GS2 $4B3D  ; 103.83 Hz
.equ N_A_2 $4704  ; 110.00 Hz
.equ N_AS2 $4308  ; 116.54 Hz
.equ N_B_2 $3F45  ; 123.47 Hz

.equ N_C_3 $3BB8  ; 130.81 Hz
.equ N_CS3 $385D  ; 138.59 Hz
.equ N_D_3 $3533  ; 146.83 Hz
.equ N_DS3 $3237  ; 155.56 Hz
.equ N_E_3 $2F65  ; 164.81 Hz
.equ N_F_3 $2CBC  ; 174.61 Hz
.equ N_FS3 $2A39  ; 185.00 Hz
.equ N_G_3 $27DB  ; 196.00 Hz
.equ N_GS3 $259E  ; 207.65 Hz
.equ N_A_3 $2381  ; 220.00 Hz
.equ N_AS3 $2183  ; 233.08 Hz
.equ N_B_3 $1FA2  ; 246.94 Hz

.equ N_C_4 $1DDB  ; 261.63 Hz
.equ N_CS4 $1C2E  ; 277.18 Hz
.equ N_D_4 $1A99  ; 293.66 Hz
.equ N_DS4 $191B  ; 311.13 Hz
.equ N_E_4 $17B2  ; 329.63 Hz
.equ N_F_4 $165D  ; 349.23 Hz
.equ N_FS4 $151C  ; 369.99 Hz
.equ N_G_4 $13ED  ; 392.00 Hz
.equ N_GS4 $12CE  ; 415.30 Hz
.equ N_A_4 $11C0  ; 440.00 Hz
.equ N_AS4 $10C1  ; 466.16 Hz
.equ N_B_4 $0FD0  ; 493.88 Hz

.equ N_C_5 $0EED  ; 523.25 Hz
.equ N_CS5 $0E16  ; 554.37 Hz
.equ N_D_5 $0D4C  ; 587.33 Hz
.equ N_DS5 $0C8D  ; 622.25 Hz
.equ N_E_5 $0BD8  ; 659.26 Hz
.equ N_F_5 $0B2E  ; 698.46 Hz
.equ N_FS5 $0A8D  ; 739.99 Hz
.equ N_G_5 $09F6  ; 783.99 Hz
.equ N_GS5 $0966  ; 830.61 Hz
.equ N_A_5 $08DF  ; 880.00 Hz
.equ N_AS5 $0860  ; 932.33 Hz
.equ N_B_5 $07E7  ; 987.77 Hz

.equ N_C_6 $0776  ; 1046.50 Hz
.equ N_CS6 $070A  ; 1108.73 Hz
.equ N_D_6 $06A5  ; 1174.66 Hz
.equ N_DS6 $0646  ; 1244.51 Hz
.equ N_E_6 $05EB  ; 1318.51 Hz
.equ N_F_6 $0596  ; 1396.91 Hz
.equ N_FS6 $0546  ; 1479.98 Hz
.equ N_G_6 $04FA  ; 1567.98 Hz
.equ N_GS6 $04B2  ; 1661.22 Hz
.equ N_A_6 $046F  ; 1760.00 Hz
.equ N_AS6 $042F  ; 1864.66 Hz
.equ N_B_6 $03F3  ; 1975.53 Hz

.equ N_C_7 $03BA  ; 2093.00 Hz
.equ N_CS7 $0384  ; 2217.46 Hz
.equ N_D_7 $0352  ; 2349.32 Hz
.equ N_DS7 $0322  ; 2489.02 Hz
.equ N_E_7 $02F5  ; 2637.02 Hz
.equ N_F_7 $02CA  ; 2793.83 Hz
.equ N_FS7 $02A2  ; 2959.96 Hz
.equ N_G_7 $027C  ; 3135.96 Hz
.equ N_GS7 $0258  ; 3322.44 Hz
.equ N_A_7 $0237  ; 3520.00 Hz
.equ N_AS7 $0217  ; 3729.31 Hz
.equ N_B_7 $01F9  ; 3951.07 Hz

.macroicase PMMUSIC_ALIGN
	.align 2
.endm

.macroicase PMMUSIC_PATTERN pataddr
	.dw pataddr & 0xFFFF, pataddr >> 16
.endm

.macroicase PMMUSIC_ROW note_id, pwm_amt, volume, wait_amt
  .if (note_id >= 0) && (pwm_amt >= 0) && (volume >= 0)
	.dw $3400 | (volume << 8) | (wait_amt & 255)
	.dw note_id
	.dw (note_id * pwm_amt / 256)
  .elif (note_id >= 0) && (pwm_amt >= 0)
	.dw $3000 | (wait_amt & 255)
	.dw note_id
	.dw (note_id * pwm_amt / 256)
  .elif (pwm_amt >= 0) && (volume >= 0)
	.dw $2400 | (volume << 8) | (wait_amt & 255)
	.dw (note_id * pwm_amt / 256)
  .elif (pwm_amt >= 0)
	.dw $2000 | (wait_amt & 255)
	.dw (note_id * pwm_amt / 256)
  .elif (note_id >= 0) && (volume >= 0)
	.dw $1400 | (volume << 8) | (wait_amt & 255)
	.dw note_id
  .elif (note_id >= 0)
	.dw $1000 | (wait_amt & 255)
	.dw note_id
  .elif (volume >= 0)
	.dw $0400 | (volume << 8) | (wait_amt & 255)
  .else
	.dw $0000 | (wait_amt & 255)
  .endif
.endm

.macroicase PMMUSIC_WRITERAM address, value
	.dw $0800
	.db value, address
.endm

.macroicase PMMUSIC_MARK loop_id
	.dw $8000
	.db 0, (loop_id << 2)
.endm

.macroicase PMMUSIC_LOOP loop_id, loop_num
  .if (loop_num >= 0)
	.dw $8000
	.db loop_num, (loop_id << 2)
  .endif
.endm

.macroicase PMMUSIC_NEXT
	.dw $4000, $0004
.endm

.macroicase PMMUSIC_GOBACK patt
	.dw $4000, -(patt * 4)
.endm

.macroicase PMMUSIC_END
	.dw $4401, $0000
.endm
