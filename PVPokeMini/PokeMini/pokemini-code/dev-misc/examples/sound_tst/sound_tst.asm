	.include "pm_libs/pm_init.s"

	pm_header "PMMusic_TsTC", IRQ_KEY_POWER | IRQ_MUSIC | IRQ_PRC_COPY, 0

	.include "pm_libs/pmrom_music.s"

	.ram	prc_tick	1
	.ram	menu_cursor	1
	.ram	bgm_select	1
	.ram	sfx_select	1

	; Power button, shutdown PM
irq_key_power:
	cint CINT_SHUTDOWN

	; Act as VSync counter
irq_prc_copy:
	push hl
	mov hl, prc_tick
	inc [hl]
	pop hl
	rirq IRQ_PRC_COPY

main_screen:
	.db "Sound TsT -f"
	.db "  BGM 00    "
	.db "  SFX 00    "
	.db "  Vol BGM ? "
	.db "  Vol SFX ? "
	.db "A= B=ÿ C=FX"
	.db "ÄÄÄÄÄÄÄÄÄÄÄÄ"
	.db "            "

	; Main routine
main:
	; Initialize RAM
	xor a, a
	mov [prc_tick], a
	mov [menu_cursor], a
	mov [bgm_select], a
	mov [sfx_select], a

	; Interrupts
	enable_irqs IRQ_KEY_POWER | IRQ_PRC_COPY

	; PRC
	mov [n+PRC_MODE], PRC_ENABLE | PRC_MAP | PRC_MAP12x16
	mov [n+PRC_RATE], PRC_RATE_2
	mov hl, font8x8
	mov [PRC_MAP_BASE], hl

	mov x, main_screen
	mov y, MAP_BASE
	mov b, 96
mainscreencopy:
	mov a, [x]
	mov [y], a
	inc x
	inc y
	jdbnz mainscreencopy
	call render_menu_updatebgmname

	; Init sound engine and play music (BA = Master time, HL = RAM Ptr)
	mov ba, MAP_BASE
	mov hl, $00FF
	call pmmusic_init

	; Enable interrupt
	enable_mirq

displayloop:
	call wait_prc
	call read_keys
	cmp a, 0
	jnz displayloop
displayloop2:
	call render_menu
	call proc_menu
	call wait_prc
	jmp displayloop2

	; Read Keypad
	; Return A, 0 = Released, 1 = Pressed
read_keys:
	mov a, [n+KEY_PAD]
	push b
	mov b, [n+KEY_PAD]
	xor a, b
	mov a, b
	pop b
	jnz read_keys
	not a
	ret

	; Wait PRC
wait_prc:
	push ba
	mov a, [prc_tick]
wait_prc_loop:
	halt
	mov b, [prc_tick]
	cmp a, b
	jz wait_prc_loop
	pop ba
	ret

	; Wait PRC (Num)
	; A = Number of copies
wait_prc_num:
	push ba
	mov b, a
wait_prc_num_loop:
	call wait_prc
	jdbnz wait_prc_num_loop
	pop ba
	ret

render_menu:
	; Get BGM selection and write to map
	mov a, [bgm_select]
	unpack
	mov b, 0
	mov hl, hexnum
	add hl, ba
	mov a, [hl]
	mov [MAP_BASE + (1 * 12) + 7], a
	mov a, [bgm_select]
	unpack
	mov a, b
	mov b, 0
	mov hl, hexnum
	add hl, ba
	mov a, [hl]
	mov [MAP_BASE + (1 * 12) + 6], a
	; Get SFX selection and write to map
	mov a, [sfx_select]
	unpack
	mov b, 0
	mov hl, hexnum
	add hl, ba
	mov a, [hl]
	mov [MAP_BASE + (2 * 12) + 7], a
	mov a, [sfx_select]
	unpack
	mov a, b
	mov b, 0
	mov hl, hexnum
	add hl, ba
	mov a, [hl]
	mov [MAP_BASE + (2 * 12) + 6], a
	; Get BGM volume and write to map
	call pmmusic_getvolbgm
	mov b, 0
	mov hl, hexnum
	add hl, ba
	mov a, [hl]	
	mov [MAP_BASE + (3 * 12) + 10], a
	; Get SFX volume and write to map
	call pmmusic_getvolsfx
	mov b, 0
	mov hl, hexnum
	add hl, ba
	mov a, [hl]	
	mov [MAP_BASE + (4 * 12) + 10], a
	; Check for playing sounds
	mov l, ' '
	call pmmusic_isplayingbgm
	cmp a, 0
	jz :f
	mov l, ''
:	mov [MAP_BASE + (1 * 12) + 9], l
	mov l, ' '
	call pmmusic_isplayingsfx
	cmp a, 0
	jz :f
	mov l, ''
:	mov [MAP_BASE + (2 * 12) + 9], l
	ret

proc_menu:
	call read_keys
	tst a, KEY_UP
	jnz proc_menu_up
	tst a, KEY_DOWN
	jnz proc_menu_down
	tst a, KEY_A
	jnz proc_menu_play
	tst a, KEY_B
	jnz proc_menu_stop
	tst a, KEY_C
	jnz proc_menu_sfx
proc_menu2:
	mov a, [menu_cursor]
	cmp a, 0
	jz proc_menu_0
	cmp a, 1
	jz proc_menu_1
	cmp a, 2
	jz proc_menu_2
	cmp a, 3
	jz proc_menu_3
	ret

proc_menu_up:
	mov hl, menu_cursor
	cmp [hl], 0
	jz proc_menu2
	dec [hl]
	mov a, 8
	call wait_prc_num
	jmp proc_menu2

proc_menu_down:
	mov hl, menu_cursor
	cmp [hl], 3
	jz proc_menu2
	inc [hl]
	mov a, 8
	call wait_prc_num
	jmp proc_menu2

proc_menu_play:
	mov b, 0
	mov a, [bgm_select]
	shl a
	shl a
	shl a
	shl a
	mov hl, bgm_list+2
	add hl, ba
	mov b, [hl]
	dec hl
	dec hl
	mov hl, [hl]
	call pmmusic_playbgm
	call render_menu
	mov a, 8
	call wait_prc_num
	jmp proc_menu2

proc_menu_stop:
	call pmmusic_stopbgm
	call render_menu
	mov a, 8
	call wait_prc_num
	jmp proc_menu2

proc_menu_sfx:
	mov b, 0
	mov a, [sfx_select]
	shl a
	shl a
	mov hl, sfx_list+2
	add hl, ba
	mov b, [hl]
	dec hl
	dec hl
	mov hl, [hl]
	call pmmusic_playsfx
	call render_menu
	mov a, 8
	call wait_prc_num
	jmp proc_menu2

do_ret:
	ret

proc_menu_0:
	; Set cursor
	xor a, a
	mov b, $1A
	mov [MAP_BASE + (1 * 12) + 1], b
	mov [MAP_BASE + (2 * 12) + 1], a
	mov [MAP_BASE + (3 * 12) + 1], a
	mov [MAP_BASE + (4 * 12) + 1], a
	; Process keys
	call read_keys
	tst a, KEY_LEFT
	jnz proc_menu_0_prevbgm
	tst a, KEY_RIGHT
	jnz proc_menu_0_nextbgm
	ret

render_menu_updatebgmname:
	; Transfer BGM name to screen
	mov a, [bgm_select]
	unpack
	swap a
	mov hl, bgm_list
	add hl, ba
	add hl, 4
	mov x, MAP_BASE + (7 * 12)
	mov b, 12
render_menu_cloop:
	mov a, [hl]
	mov [x], a
	inc hl
	inc x
	jdbnz render_menu_cloop
	ret

proc_menu_0_prevbgm:
	mov hl, bgm_select
	cmp [hl], 0
	jz do_ret
	dec [hl]
	mov a, 8
	call wait_prc_num
	call render_menu_updatebgmname
	ret

proc_menu_0_nextbgm:
	mov hl, bgm_select
	mov a, [bgm_list_last]
	cmp [hl], a
	jz do_ret
	inc [hl]
	mov a, 8
	call wait_prc_num
	call render_menu_updatebgmname
	ret

proc_menu_1:
	; Set cursor
	xor a, a
	mov b, $1A
	mov [MAP_BASE + (1 * 12) + 1], a
	mov [MAP_BASE + (2 * 12) + 1], b
	mov [MAP_BASE + (3 * 12) + 1], a
	mov [MAP_BASE + (4 * 12) + 1], a
	; Process keys
	call read_keys
	tst a, KEY_LEFT
	jnz proc_menu_1_prevsfx
	tst a, KEY_RIGHT
	jnz proc_menu_1_nextsfx
	ret

proc_menu_1_prevsfx:
	mov hl, sfx_select
	cmp [hl], 0
	jz do_ret
	dec [hl]
	mov a, 8
	call wait_prc_num
	ret

proc_menu_1_nextsfx:
	mov hl, sfx_select
	mov a, [sfx_list_last]
	cmp [hl], a
	jz do_ret
	inc [hl]
	mov a, 8
	call wait_prc_num
	ret

proc_menu_2:
	; Set cursor
	xor a, a
	mov b, $1A
	mov [MAP_BASE + (1 * 12) + 1], a
	mov [MAP_BASE + (2 * 12) + 1], a
	mov [MAP_BASE + (3 * 12) + 1], b
	mov [MAP_BASE + (4 * 12) + 1], a
	; Process keys
	call read_keys
	tst a, KEY_LEFT
	jnz proc_menu_2_decvol
	tst a, KEY_RIGHT
	jnz proc_menu_2_incvol
	ret

proc_menu_2_decvol:
	call pmmusic_getvolbgm
	dec a
	call pmmusic_setvolbgm
	mov a, 8
	call wait_prc_num
	ret

proc_menu_2_incvol:
	call pmmusic_getvolbgm
	inc a
	call pmmusic_setvolbgm
	mov a, 8
	call wait_prc_num
	ret

proc_menu_3:
	; Set cursor
	xor a, a
	mov b, $1A
	mov [MAP_BASE + (1 * 12) + 1], a
	mov [MAP_BASE + (2 * 12) + 1], a
	mov [MAP_BASE + (3 * 12) + 1], a
	mov [MAP_BASE + (4 * 12) + 1], b
	; Process keys
	call read_keys
	tst a, KEY_LEFT
	jnz proc_menu_3_decvol
	tst a, KEY_RIGHT
	jnz proc_menu_3_incvol
	ret

proc_menu_3_decvol:
	call pmmusic_getvolsfx
	dec a
	call pmmusic_setvolsfx
	mov a, 8
	call wait_prc_num
	ret

proc_menu_3_incvol:
	call pmmusic_getvolsfx
	inc a
	call pmmusic_setvolsfx
	mov a, 8
	call wait_prc_num
	ret

; --------------------------------------------------------------------------------

hexnum:
	.db "0123456789ABCDEF"

	.align 16
bgm_list:
	.dd music_test
	.db "SndEng Tst  "
	.dd music_pmintro
	.db "PM Intro    "
	.dd music_choco
	.db "OdekaChocobo"
	.dd bgm_unk_tune1
	.db "Unk. Tune 1 "
	.dd bgm_unk_tune2
	.db "Unk. Tune 2 "
	.dd music_galactix
	.db "Galactix  1P"
	.dd music_galactix2
	.db "GalactixRm1P"
	.dd music_metroid
	.db "MetroidTitle"

sfx_list:
	.dd sound_fx0
	.dd sound_fx1
	.dd sound_fx2
	.dd sound_fx3
	.dd sound_fx4
	.dd sound_fx5

bgm_list_last:	.db 7
sfx_list_last:	.db 5

	PMMUSIC_ALIGN

music_data_start:

.include "music_test.asm"
.include "music_pmintro.asm"
.include "music_choco.asm"
.include "music_unknown.asm"
.include "music_galactix.asm"
.include "music_metroid.asm"

sound_fx0:
	PMMUSIC_ROW N_C_4, $80, 3, 1
	PMMUSIC_ROW N_C_3, $80, 3, 1
	PMMUSIC_ROW N_C_5, $80, 3, 1
	PMMUSIC_ROW N_C_7, $80, 3, 1
	PMMUSIC_END

sound_fx1:
	PMMUSIC_ROW N_C_4, $80, 3, 1
	PMMUSIC_ROW N_C_5, $70, 3, 1
	PMMUSIC_ROW N_C_4, $60, 3, 1
	PMMUSIC_ROW N_C_5, $50, 3, 1
	PMMUSIC_ROW N_C_4, $40, 3, 1
	PMMUSIC_ROW N_C_5, $30, 3, 1
	PMMUSIC_ROW N_C_4, $20, 3, 1
	PMMUSIC_ROW N_C_5, $10, 3, 1
	PMMUSIC_ROW N_C_4, $00, 3, 1
	PMMUSIC_END

sound_fx2:
	PMMUSIC_ROW N_C_1, $80, 3, 1
	PMMUSIC_ROW N_E_1, $80, 3, 1
	PMMUSIC_ROW N_G_1, $80, 3, 1
	PMMUSIC_ROW N_C_2, $80, 3, 1
	PMMUSIC_ROW N_E_2, $80, 3, 1
	PMMUSIC_ROW N_G_2, $80, 3, 1
	PMMUSIC_ROW N_C_3, $80, 3, 1
	PMMUSIC_ROW N_E_3, $80, 3, 1
	PMMUSIC_ROW N_G_3, $80, 3, 1
	PMMUSIC_ROW N_C_4, $80, 3, 1
	PMMUSIC_ROW N_E_4, $80, 3, 1
	PMMUSIC_ROW N_G_4, $80, 3, 1
	PMMUSIC_END

sound_fx3:
	PMMUSIC_ROW N_C_4, $40, 0, 1
	PMMUSIC_ROW N_C_4, $40, 3, 1
	PMMUSIC_ROW N_C_3, $40, 2, 1
	PMMUSIC_ROW N_C_2, $40, 2, 1
	PMMUSIC_ROW N_C_1, $40, 2, 1
	PMMUSIC_ROW N_C_1, $40, 2, 1
	PMMUSIC_END

sound_fx4:
	PMMUSIC_ROW N_A_5, $40, 2, 6
	PMMUSIC_WRITERAM (0 * 12 + 10), $2B
	PMMUSIC_ROW N_A_5, $20, 2, 6
	PMMUSIC_WRITERAM (0 * 12 + 10), $2D
	PMMUSIC_END

sound_fx5:
	PMMUSIC_ROW N_E_6, $80, 3, 1
	PMMUSIC_ROW N_E_4, $70, 2, 1
	PMMUSIC_ROW N_E_5, $60, 3, 1
	PMMUSIC_ROW N_E_3, $50, 2, 1
	PMMUSIC_ROW N_E_4, $40, 3, 1
	PMMUSIC_ROW N_E_2, $30, 2, 1
	PMMUSIC_ROW N_E_1, $20, 2, 1
	PMMUSIC_END

music_data_end:
	.printf "Music Data size: %i bytes\n", music_data_end - music_data_start

; --------------------------------------------------------------------------------

	pm_align_tiles
font8x8:
	.incbin "pm_libs/font8x8.bin"

	pm_rominfo
