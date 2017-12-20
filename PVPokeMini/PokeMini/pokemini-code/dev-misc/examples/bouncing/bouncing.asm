	.include "pm_libs/pm_init.s"

	pm_header "TestFramebuf", IRQ_KEY_POWER | IRQ_PRC_COPY | IRQ_MUSIC | IRQ_SHOCK, 0

	.include "pm_libs/pmrom_music.s"

	; For grayscaling (3rd color)
	.ram PRC_MAP_BASE_FLIP 2
	.ram PRC_SPR_BASE_FLIP 2

	; All coords are fixed-point 8.8
	.ram pokeball_px 2	; Position
	.ram pokeball_py 2
	.ram pokeball_vx 2	; Velocity
	.ram pokeball_vy 2
	.ram pokeball_ax 2	; Acceleration
	.ram pokeball_ay 2
	.ram pokeball_anim 2	; Rolling animation

	.set pokeball_reducex	8
	.set pokeball_reducey	64

	; Shutdown down when power key pressed
irq_key_power:
	cint CINT_SHUTDOWN

	; Flip map & spr bases
	; This demo isn't over 64KB so we can skip upper address fliping
irq_prc_copy:
	pushax
	mov ba, [PRC_SPR_BASE]
	mov hl, [PRC_SPR_BASE_FLIP]
	mov [PRC_SPR_BASE], hl
	mov [PRC_SPR_BASE_FLIP], ba
	mov ba, [PRC_MAP_BASE]
	mov hl, [PRC_MAP_BASE_FLIP]
	mov [PRC_MAP_BASE], hl
	mov [PRC_MAP_BASE_FLIP], ba
	popax
	rirq IRQ_PRC_COPY

	; Shock detector handler
irq_shock:
	pushax
	mov hl, [pokeball_py]
	cmp hl, 46<<8		; If near ground...
	jl _end
	mov hl, [pokeball_vy]
	cmp hl, $8000		; and if going up...
	jnc _end
	add hl, 2<<8		; Project ball way up
	mov [pokeball_vy], hl
	mov hl, [pokeball_vx]
	mov a, [n+TMR256_CNT]
	tst a, 0x01		; We pick the lowest bit of 256hz timer to set the x direction
	jnzb :f
	add hl, 1<<8		; Throw left
	jmpb :ff
:	sub hl, 1<<8		; ... or right!
:	mov [pokeball_vx], hl
_end:	popax
	rirq IRQ_SHOCK

	; Main routine
main:
	; Setup ball
	mov ba, 40<<8
	mov [pokeball_px], ba
	mov ba, 24<<8
	mov [pokeball_py], ba
	mov ba, 64
	mov [pokeball_vx], ba
	mov ba, -64
	mov [pokeball_vy], ba
	mov ba, 0
	mov [pokeball_ax], ba
	mov ba, 16
	mov [pokeball_ay], ba
	mov a, 0
	mov [pokeball_anim], ba

	; Copy background map
	mov x, background_map
	mov y, MAP_BASE
	mov b, 96
:	mov a, [x]
	mov [y], a
	inc x
	inc y
	jdbnz :b

	; Setup map and sprite bases
	; This demo isn't over 64KB so we don't care about the upper address
	mov ba, background_1
	mov [PRC_MAP_BASE], ba
	mov ba, background_2
	mov [PRC_MAP_BASE_FLIP], ba
	mov ba, pokeball_1
	mov [PRC_SPR_BASE], ba
	mov ba, pokeball_2
	mov [PRC_SPR_BASE_FLIP], ba

	; Enable Tmr256
	mov [n+TMR256_CTRL], TMR256_ENABLE

	; Setup PRC
	mov [n+PRC_MODE], PRC_ENABLE | PRC_SPR | PRC_MAP | PRC_MAP12x16
	mov [n+PRC_RATE], PRC_36FPS

	; Enable interrupts
	enable_irqs IRQ_KEY_POWER | IRQ_PRC_COPY | IRQ_SHOCK
	enable_mirq

	; Initialize pmmusic for our sound effect
	mov ba, 0
	mov hl, $00FF
	call pmmusic_init

	; Begin loop
_loop:	halt					; Battery likes HALT but be careful that it needs IRQs to wake up
	tst [n+IRQ_ACT1], IRQ_ACT1_PRC_DIV	; Wait for PRC divider flag, IRQ cannot be active for this trick to work
	jzb _loop
	or [n+IRQ_ACT1], IRQ_ACT1_PRC_DIV	; Clear it
	call update_position
	call update_velocity
	call update_anim

	; Copy pokeball information into sprite 0
	mov a, [pokeball_py+1]
	add a, 16				; HW Sprites start at X of  -16
	mov [SPR_BASE + SPR_Y], a
	mov a, [pokeball_px+1]
	add a, 16				; HW Sprites start at Y of -16
	mov [SPR_BASE + SPR_X], a
	mov a, [pokeball_anim+1]		; Use the integer part of our animation
	mov [SPR_BASE + SPR_TILE], a
	mov a, SPR_ENABLE
	mov [SPR_BASE + SPR_CTRL], a
	jmpb _loop

	; Update ball position based of velocity
update_position:
	; X coord.
	mov x, [pokeball_vx]
	mov y, [pokeball_vy]
	mov ba, [pokeball_px]
	add ba, x		; px += vx;
	cmp ba, 0<<8		; if (px < 0.0) {
	jge :f
	mov ba, 0<<8		;	px = 0.0;
	cmp x, $8000
	js :f
	mov hl, 0
	sub hl, x
	mov x, hl		;	vx = abs(vx);
	call oncollision	;	oncollision(); }
:	cmp ba, 80<<8		; if (px >= 80.0) {
	jle :f
	mov ba, 80<<8		;	px = 80.0;
	cmp x, $8000
	jns :f
	mov hl, 0
	sub hl, x
	mov x, hl		;	vx = -abs(vx);
	call oncollision	;	oncollision(); }
:	mov [pokeball_px], ba
	; Y coord.
	mov ba, [pokeball_py]
	add ba, y		; py += vy;
	cmp ba, 0<<8		; if (py < 0.0) {
	jge :f
	mov ba, 0<<8		;	py = 0.0;
	cmp y, $8000
	js :f
	mov hl, 0
	sub hl, y
	mov y, hl		;	vy = abs(vy);
	call oncollision	;	oncollision(); }
:	cmp ba, 48<<8		; if (py >= 48.0) {
	jle :f
	mov ba, 48<<8		;	py = 48.0;
	cmp y, $8000
	jns :f
	mov hl, 0
	sub hl, y
	mov y, hl		;	vy = -abs(vy);
	call oncollision	;	oncollision(); }
:	mov [pokeball_py], ba
	mov [pokeball_vx], x
	mov [pokeball_vy], y
	ret

	; Update ball velocity based of acceleration
update_velocity:
	mov hl, [pokeball_ax]
	mov ba, [pokeball_vx]
	add ba, hl		; vx += ax;
	cmp ba, -3<<8		; if (vx < -3.0) vx = -3.0;
	jge :f
	mov ba, -3<<8
:	cmp ba, 3<<8		; if (vx > 3.0) vx = 3.0;
	jle :f
	mov ba, 3<<8
:	mov [pokeball_vx], ba
	mov hl, [pokeball_ay]
	mov ba, [pokeball_vy]
	add ba, hl		; vy += ay;
	cmp ba, -3<<8		; if (vy < -3.0) vx = -3.0;
	jge :f
	mov ba, -3<<8
:	cmp ba, 3<<8		; if (vy > 3.0) vx = 3.0;
	jle :f
	mov ba, 3<<8
:	mov [pokeball_vy], ba
	ret

	; Update animation based of velocity
update_anim:
	mov ba, [pokeball_anim]
	mov hl, [pokeball_vx]
	add ba, hl
	and b, $07		; anim = (anim + vx) & 0x07FF;
	mov [pokeball_anim], ba
	ret

	; Called when the ball collide with any wall
	;  only HL can be destroyed
oncollision:
	; Reduce velocity, remember they are still in X and Y register
_x:
	cmp x, $8000
	jncb _xneg
_xpos:
	sub x, pokeball_reducex
	jnc _y
	mov x, 0
	jmpb _y
_xneg:
	add x, pokeball_reducex
	jnc _y
	mov x, 0
_y:
	cmp y, $8000
	jncb _yneg
_ypos:
	sub y, pokeball_reducey
	jnc _z
	mov y, 0
	jmpb _z
_yneg:
	add y, pokeball_reducey
	jnc _z
	mov y, 0
_z:
	; Only play SFX if ball is moving
	cmp x, 0
	jnz _do_sfx
	cmp y, 0
	jnz _do_sfx
	ret
_do_sfx:
	mov hl, wallsfx
	call pmmusic_playsfx
	ret


	; PMMusic stuff here!
	pmmusic_align
wallsfx:
	;           Note    Pw  V  Wait
	pmmusic_row N_C_2, $20, 2, 1
	pmmusic_row N_C_7, $80, 2, 1
	pmmusic_row N_C_5, $40, 2, 1
	pmmusic_row N_C_3, $20, 2, 1
	pmmusic_end


	pm_rominfo


	; Tiles must be 8 bytes aligned!
	pm_align_tiles
background_1:
	.incbin "background.bin"
background_2:
	.incbin "backgroundG.bin"
background_map:
	.incbin "background.map"


	; Sprites must be 64 bytes aligned!
	pm_align_spr
pokeball_1:
	.incbin "pokeball.bin"
pokeball_2:
	.incbin "pokeballG.bin"
