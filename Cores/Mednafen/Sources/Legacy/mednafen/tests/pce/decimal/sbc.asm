DMATHOP	.macro
	sbc \1
	.endm

	.include "XXc.inc"

	.org $8000
Gwarg:	.incbin "sbcresults.bin"
	.bank $7F
