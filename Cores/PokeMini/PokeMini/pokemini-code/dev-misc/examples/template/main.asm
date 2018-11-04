	.include "pm_libs/pm_init.s"

	pm_header "MainTemplate", IRQ_KEY_POWER, 0

	; Shutdown down when power key pressed
irq_key_power:
	cint CINT_SHUTDOWN

main:
	; Enable interrupts
	enable_irqs IRQ_KEY_POWER | IRQ_PRC_COPY
	enable_mirq

_loop:
	halt
	jmpb _loop

	pm_rominfo
