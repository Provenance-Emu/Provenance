DMATHOP	.macro
	adc \1
	.endm

	.include "XXc.inc"

	.org $8000
Gwarg:	.incbin "adcresults.bin"
	.bank $7F
