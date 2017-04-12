	.include "pm_libs/pm_init.s"

	pm_header "TestMapView ", IRQ_KEY_POWER | IRQ_PRC_COPY, 0

	; Shutdown down when power key pressed
irq_key_power:
	cint CINT_SHUTDOWN

	; Flip map bases
	; This demo isn't over 64KB so we can skip upper address fliping
irq_prc_copy:
	pushax
	mov ba, [PRC_MAP_BASE]
	mov hl, [PRC_MAP_BASE_FLIP]
	mov [PRC_MAP_BASE], hl
	mov [PRC_MAP_BASE_FLIP], ba
	popax
	rirq IRQ_PRC_COPY

	.ram PRC_MAP_BASE_FLIP 2
	.ram camera_x 2
	.ram camera_y 2
	.ram camera_speed 2

	; Our map definitions
	.include "pokemap.inc"

	; Main routine
main:
	; Initialize RAM
	mov ba, 16
	mov [camera_speed], ba

	; Enable interrupts
	enable_irqs IRQ_KEY_POWER | IRQ_PRC_COPY
	enable_mirq

	; Setup PRC
	mov [n+PRC_MODE], PRC_ENABLE | PRC_MAP | PRC_MAP16x12
	mov [n+PRC_RATE], PRC_36FPS
	mov ba, tileset_1
	mov [PRC_MAP_BASE], ba
	mov ba, tileset_2
	mov [PRC_MAP_BASE_FLIP], ba

loop:
	; Battery likes HALT but be careful that it needs IRQs to wake up
	halt

	; Render map
	call rendermap

	; Move
	call movemap

	jmpb loop


	; Render map
rendermap:
	; Fine scroll
	mov a, [camera_x]
	rol a
	rol a
	rol a
	and a, $7
	mov [n+PRC_SCROLL_X], a	; Set higher fractional 3-bits to scroll
	mov a, [camera_y]
	rol a
	rol a
	rol a
	and a, $7
	mov [n+PRC_SCROLL_Y], a	; Set higher fractional 3-bits to scroll

	; Transfer map
	mov x, pokemap
	mov l, [camera_x+1]
	mov h, 0
	add x, hl
	mov l, [camera_y+1]
	mov a, pokemap_mapw
	mul l, a
	add x, hl		; src <= pokemap + (int)camera_x + (int)camera_y * mapw
	mov y, MAP_BASE		; dst <= map_base
	mov b, 9		; Screen height + 1
_y:	
	push b
	mov b, 13		; Screen width + 1
_x:
	mov a, [x]
	mov [y], a
	inc x
	inc y
	jdbnz _x

	add x, pokemap_mapw - 13
	add y, 16 - 13		; Padding
	pop b
	jdbnz _y
	ret

	; Move around the map
movemap:
	mov a, [n+KEY_PAD]
	tst a, KEY_B
	callzb _keyb
	callnzb _keybx
	tst a, KEY_A
	callzb _keya
	tst a, KEY_C
	callzb _keyc
	tst a, KEY_LEFT
	callzb _left
	tst a, KEY_RIGHT
	callzb _right
	tst a, KEY_UP
	callzb _up
	tst a, KEY_DOWN
	callzb _down
	ret
_keyb:
	push a
	mov ba, 64
	mov [camera_speed], ba
	pop a
	ret
_keybx:
	push a
	mov ba, 16
	mov [camera_speed], ba
	pop a
	ret
_keya:
	push a
	mov ba, 8
	mov [camera_speed], ba
	pop a
	ret
_keyc:
	push a
	mov ba, 128
	mov [camera_speed], ba
	pop a
	ret
_left:
	push a
	mov hl, camera_x
	mov ba, [hl]
	mov x, [camera_speed]
	sub ba, x
	cmp ba, 0
	jge :f
	mov ba, 0
:	mov [hl], ba
	pop a
	ret
_right:
	push a
	mov hl, camera_x
	mov ba, [hl]
	mov x, [camera_speed]
	add ba, x
	cmp ba, (pokemap_mapw - 12) * 256
	jl :f
	mov ba, (pokemap_mapw - 12) * 256
:	mov [hl], ba
	pop a
	ret
_up:
	push a
	mov hl, camera_y
	mov ba, [hl]
	mov x, [camera_speed]
	sub ba, x
	cmp ba, 0
	jge :f
	mov ba, 0
:	mov [hl], ba
	pop a
	ret
_down:
	push a
	mov hl, camera_y
	mov ba, [hl]
	mov x, [camera_speed]
	add ba, x
	cmp ba, (pokemap_maph - 8) * 256
	jl :f
	mov ba, (pokemap_maph - 8) * 256
:	mov [hl], ba
	pop a
	ret

pokemap:
	.incbin "pokemap.map"

	pm_align_map
tileset_1:
	.incbin "tileset.bin"
tileset_2:
	.incbin "tilesetG.bin"

	pm_rominfo
