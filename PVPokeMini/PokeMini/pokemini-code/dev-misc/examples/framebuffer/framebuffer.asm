	.include "pm_libs/pm_init.s"

	pm_header "TestFramebuf", IRQ_KEY_POWER, 0

	; Shutdown down when power key pressed
irq_key_power:
	cint CINT_SHUTDOWN

main:
	; Enable interrupts
	enable_irqs IRQ_KEY_POWER | IRQ_PRC_COPY	; PRC_COPY declared to wake up HALT
	enable_mirq

	; Blank LCD
	mov a, 0
	cint CINT_TMP_CONTRAST

	; Setup PRC
	mov [n+PRC_MODE], PRC_ENABLE
	mov [n+PRC_RATE], PRC_24FPS

	; Copy image to VRAM
	mov y, teampokeme
	mov x, VRAM_BASE
	mov hl, 768
:	mov a, [y]
	mov [x], a
	inc x
	inc y
	dec hl
	jnzb :b

	; Fade in
	mov a, 0
:	push a
	cint CINT_TMP_CONTRAST
	pop a
	halt
	inc a
	cmp a, $20
	jnzb :b

	; Wait for any key press
	mov a, 0
:	halt
	mov a, [n+KEY_PAD]
	cmp a, $FF
	jzb :b

	; Fade out
	mov a, $20
:	push a
	cint CINT_TMP_CONTRAST
	pop a
	halt
	dec a
	jnzb :b

	; Shutdown
	cint CINT_SHUTDOWN

	pm_align_tiles
teampokeme:
	.incbin "teampokeme.bin"

	pm_rominfo
