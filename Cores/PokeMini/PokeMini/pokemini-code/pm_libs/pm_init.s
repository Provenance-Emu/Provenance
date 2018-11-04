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

	; Pokemon-Mini definitions
	; Version 5
.equ	PMINIT_VER	5

	; Flags
.equ	FLAG_Z		$01
.equ	FLAG_C		$02
.equ	FLAG_O		$04
.equ	FLAG_S		$08
.equ	FLAG_BCD	$10
.equ	FLAG_NIBBLE	$20
.equ	FLAG_ID		$40
.equ	FLAG_IB		$80

	; Registers base
.equ	SSTACK_BASE	$1FFC
.equ	STACK_BASE	$2000
.equ	REG_BASE	$2000
.equ	N_BASE		$20

	; Memory defines
.equ	VRAM_BASE	$1000
.equ	VRAM		$1000
.equ	SPR_BASE	$1300
.equ	OAM_BASE	$1300
.equ	MAP_BASE	$1360
.equ	MAP		$1360
.equ	TILEMAP		$1360

	; RAM defines
.ifndef PM_STARTRAM
.equ	PM_STARTRAM	$14E0	; Map up to 24x16
.endif
.if PM_STARTRAM < $1000
.error "Invalid PM_STARTRAM value, too small"
.endif
.if PM_STARTRAM >= $2000
.error "Invalid PM_STARTRAM value, too big"
.endif

.equ	PMINIT_RAND	(PM_STARTRAM + 0)
.equ	PMINIT_KEYPAD	(PM_STARTRAM + 2)
.equ	PMINIT_FRAMECNT	(PM_STARTRAM + 3)
.equ	RAM		(PM_STARTRAM + 4)
.equ	RAM_BASE	(PM_STARTRAM + 4)
.equ	RAM_SIZE	($2000 - RAM_BASE)
.option	ram_base	RAM_BASE
.option symoutput	1

	; ---------
	; Registers

	; BIOS
.equ	SYS_CTRL1	$00
.equ	SYS_CTRL2	$01
.equ	SYS_CTRL3	$02

	; Secound timer
.equ	SEC_CTRL	$08
.equ	SEC_CNT_LO	$09
.equ	SEC_CNT_MID	$0A
.equ	SEC_CNT_HI	$0B

	; Battery status
.equ	SYS_BATT	$10

	; Timers control
.equ	TMR1_SCALE	$18
.equ	TMR1_ENA_OSC	$19
.equ	TMR1_OSC	$19
.equ	TMR2_SCALE	$1A
.equ	TMR2_OSC	$1B
.equ	TMR3_SCALE	$1C
.equ	TMR3_OSC	$1D

	; Interrupts
.equ	IRQ_PRI1	$20
.equ	IRQ_PRI2	$21
.equ	IRQ_PRI3	$22
.equ	IRQ_ENA1	$23
.equ	IRQ_ENA2	$24
.equ	IRQ_ENA3	$25
.equ	IRQ_ENA4	$26
.equ	IRQ_ACT1	$27
.equ	IRQ_ACT2	$28
.equ	IRQ_ACT3	$29
.equ	IRQ_ACT4	$2A

	; Timer 1
.equ	TMR1_CTRL_L	$30
.equ	TMR1_CTRL_H	$31
.equ	TMR1_CTRL	$30
.equ	TMR1_PRE_L	$32
.equ	TMR1_PRE_H	$33
.equ	TMR1_PRE	$32
.equ	TMR1_PVT_L	$34
.equ	TMR1_PVT_H	$35
.equ	TMR1_PVT	$34
.equ	TMR1_CNT_L	$36
.equ	TMR1_CNT_H	$37
.equ	TMR1_CNT	$36

	; Timer 2
.equ	TMR2_CTRL_L	$38
.equ	TMR2_CTRL_H	$39
.equ	TMR2_CTRL	$38
.equ	TMR2_PRE_L	$3A
.equ	TMR2_PRE_H	$3B
.equ	TMR2_PRE	$3A
.equ	TMR2_PVT_L	$3C
.equ	TMR2_PVT_H	$3D
.equ	TMR2_PVT	$3C
.equ	TMR2_CNT_L	$3E
.equ	TMR2_CNT_H	$3F
.equ	TMR2_CNT	$3E

	; 256 Hz Timer
.equ	TMR256_CTRL	$40
.equ	TMR256_CNT	$41

	; Timer 3
.equ	TMR3_CTRL_L	$48
.equ	TMR3_CTRL_H	$49
.equ	TMR3_CTRL	$48
.equ	TMR3_PRE_L	$4A
.equ	TMR3_PRE_H	$4B
.equ	TMR3_PRE	$4A
.equ	TMR3_PVT_L	$4C
.equ	TMR3_PVT_H	$4D
.equ	TMR3_PVT	$4C
.equ	TMR3_CNT_L	$4E
.equ	TMR3_CNT_H	$4F
.equ	TMR3_CNT	$4E

	; Inputs
.equ	KEY_PAD		$52
.equ	KEYPAD		$52
.equ	CART_BUS	$53

	; IO
.equ	IO_DIR		$60
.equ	IO_DATA		$61

	; Audio
.equ	AUD_CTRL	$70
.equ	AUD_VOL		$71

	; PRC
.equ	PRC_MODE	$80
.equ	PRC_RATE	$81
.equ	PRC_MAP_LO	$82
.equ	PRC_MAP_MID	$83
.equ	PRC_MAP_HI	$84
.equ	PRC_SCROLL_Y	$85
.equ	PRC_SCROLL_X	$86
.equ	PRC_SPR_LO	$87
.equ	PRC_OAM_LO	$87
.equ	PRC_SPR_MID	$88
.equ	PRC_OAM_MID	$88
.equ	PRC_SPR_HI	$89
.equ	PRC_OAM_HI	$89
.equ	PRC_CNT		$8A

.equ	PRC_MAP_BASE	$2082
.equ	PRC_SPR_BASE	$2087
.equ	PRC_OAM_BASE	$2087

	; PokeMini Debugger
.equ	POKEMINI_CHR	$D0
.equ	POKEMINI_HEX	$D1
.equ	POKEMINI_NUM	$D2
.equ	POKEMINI_UINTB	$D2
.equ	POKEMINI_SINTB	$D3
.equ	POKEMINI_UINTW	$D4
.equ	POKEMINI_UINTWL	$D4
.equ	POKEMINI_UINTWH	$D5
.equ	POKEMINI_SINTW	$D6
.equ	POKEMINI_SINTWL	$D6
.equ	POKEMINI_SINTWH	$D7
.equ	POKEMINI_FX8_8	$DE
.equ	POKEMINI_FX8_8L	$DE
.equ	POKEMINI_FX8_8H	$DF

	; Color interface
.equ	COLORPM_CMD	$F0
.equ	COLORPM_CTRL	$F0
.equ	COLORPM_ADDR	$F1
.equ	COLORPM_ADDRL	$F1
.equ	COLORPM_ADDRH	$F2
.equ	COLORPM_DATA	$F3
.equ	COLORPM_LP0	$F4
.equ	COLORPM_HP0	$F5
.equ	COLORPM_LP1	$F6
.equ	COLORPM_HP1	$F7

	; LCD
.equ	LCD_CTRL	$FE
.equ	LCD_DATA	$FF

	; ---------------
	; Helpful defines

.equ	DISABLE_IRQ		$C0	; F register
.equ	ENABLE_IRQ		$80

.equ	TMRS_ENABLE		$30	; n+TMR1_ENA_OSC
.equ	TMRS_ON			$30
.equ	TMRS_OSC1		$20
.equ	TMRS_OSC2		$10

.equ	SEC_ENABLE		$01	; n+SEC_CTRL
.equ	SEC_RESET		$02

.equ	LOW_BATTERY		$20	; n+SYS_BATT

.equ	TMR256_ENABLE		$01	; n+TMR256_CNT
.equ	TMR256_RESET		$02

.equ	TMR_8BITS		$00	; n+TMRn_CTRL_L
.equ	TMR_16BITS		$80

.equ	TMR_PRESET		$02	; n+TMRn_CTRL_L / n+TMRn_CTRL_H
.equ	TMR_RESET		$02
.equ	TMR_ENABLE		$04

.equ	TMR_LO_DIV_OFF		$00	; n+TMRn_SCALE
.equ	TMR_LO_DIV_DISABLE	$00
.equ	TMR_LO_DIV_2		$08
.equ	TMR_LO_DIV_8		$09
.equ	TMR_LO_DIV_32		$0A
.equ	TMR_LO_DIV_64		$0B
.equ	TMR_LO_DIV_128		$0C
.equ	TMR_LO_DIV_256		$0D
.equ	TMR_LO_DIV_1024		$0E
.equ	TMR_LO_DIV_4096		$0F

.equ	TMR_LO_DIV2_OFF		$00	; n+TMRn_SCALE
.equ	TMR_LO_DIV2_DISABLE	$00
.equ	TMR_LO_DIV2_1		$08
.equ	TMR_LO_DIV2_2		$09
.equ	TMR_LO_DIV2_4		$0A
.equ	TMR_LO_DIV2_8		$0B
.equ	TMR_LO_DIV2_16		$0C
.equ	TMR_LO_DIV2_32		$0D
.equ	TMR_LO_DIV2_64		$0E
.equ	TMR_LO_DIV2_128		$0F

.equ	TMR_HI_DIV_OFF		$00	; n+TMRn_SCALE
.equ	TMR_HI_DIV_DISABLE	$00
.equ	TMR_HI_DIV_2		$80
.equ	TMR_HI_DIV_8		$90
.equ	TMR_HI_DIV_32		$A0
.equ	TMR_HI_DIV_64		$B0
.equ	TMR_HI_DIV_128		$C0
.equ	TMR_HI_DIV_256		$D0
.equ	TMR_HI_DIV_1024		$E0
.equ	TMR_HI_DIV_4096		$F0

.equ	TMR_HI_DIV2_OFF		$00	; n+TMRn_SCALE
.equ	TMR_HI_DIV2_DISABLE	$00
.equ	TMR_HI_DIV2_1		$80
.equ	TMR_HI_DIV2_2		$90
.equ	TMR_HI_DIV2_4		$A0
.equ	TMR_HI_DIV2_8		$B0
.equ	TMR_HI_DIV2_16		$C0
.equ	TMR_HI_DIV2_32		$D0
.equ	TMR_HI_DIV2_64		$E0
.equ	TMR_HI_DIV2_128		$F0

.equ	TMR_DIV_OFF		$00	; n+TMRn_SCALE
.equ	TMR_DIV_2		$08
.equ	TMR_DIV_8		$09
.equ	TMR_DIV_32		$0A
.equ	TMR_DIV_64		$0B
.equ	TMR_DIV_128		$0C
.equ	TMR_DIV_256		$0D
.equ	TMR_DIV_1024		$0E
.equ	TMR_DIV_4096		$0F

.equ	TMR_DIV2_OFF		$00	; n+TMRn_SCALE
.equ	TMR_DIV2_1		$08
.equ	TMR_DIV2_2		$09
.equ	TMR_DIV2_4		$0A
.equ	TMR_DIV2_8		$0B
.equ	TMR_DIV2_16		$0C
.equ	TMR_DIV2_32		$0D
.equ	TMR_DIV2_64		$0E
.equ	TMR_DIV2_128		$0F

.equ	TMR_OSC1_LO		$00	; n+TMRn_OSC
.equ	TMR_OSC1_HI		$00
.equ	TMR_OSC2_LO		$01
.equ	TMR_OSC2_HI		$02

.equ	IRQ_PRI1_TMR3		$03	; n+IRQ_PRI1
.equ	IRQ_PRI1_TMR1		$0C
.equ	IRQ_PRI1_TMR2		$30
.equ	IRQ_PRI1_PRC		$C0

.equ	IRQ_PRI2_UNKNOWN	$03	; n+IRQ_PRI2
.equ	IRQ_PRI2_KEY_PAD	$0C
.equ	IRQ_PRI2_KEYPAD		$0C
.equ	IRQ_PRI2_CARTRIDGE	$30
.equ	IRQ_PRI2_TMR256		$C0
.equ	IRQ_PRI2_HZ		$C0

.equ	IRQ_PRI3_IO		$03	; n+IRQ_PRI3
.equ	IRQ_PRI3_PIO		$03

.equ	IRQ_ENA1_TMR3_PVT	$01	; n+IRQ_ENA1
.equ	IRQ_ENA1_TMR3_HI	$02
.equ	IRQ_ENA1_TMR1_LO	$04
.equ	IRQ_ENA1_TMR1_HI	$08
.equ	IRQ_ENA1_TMR2_LO	$10
.equ	IRQ_ENA1_TMR2_HI	$20
.equ	IRQ_ENA1_PRC_DIV	$40
.equ	IRQ_ENA1_PRC_COPY	$80

.equ	IRQ_ENA2_CARTRIDGE	$01	; n+IRQ_ENA2
.equ	IRQ_ENA2_CART_EJECT	$02
.equ	IRQ_ENA2_1HZ		$04
.equ	IRQ_ENA2_2HZ		$08
.equ	IRQ_ENA2_8HZ		$10
.equ	IRQ_ENA2_32HZ		$20

.equ	IRQ_ENA3_KEY_A		$01	; n+IRQ_ENA3
.equ	IRQ_ENA3_KEY_B		$02
.equ	IRQ_ENA3_KEY_C		$04
.equ	IRQ_ENA3_KEY_UP		$08
.equ	IRQ_ENA3_KEY_DOWN	$10
.equ	IRQ_ENA3_KEY_LEFT	$20
.equ	IRQ_ENA3_KEY_RIGHT	$40
.equ	IRQ_ENA3_KEY_POWER	$80
.equ	IRQ_ENA3_KEYS		$FF

.equ	IRQ_ENA4_UNKNOWN1	$01	; n+IRQ_ENA4
.equ	IRQ_ENA4_UNKNOWN2	$02
.equ	IRQ_ENA4_UNKNOWN3	$04
.equ	IRQ_ENA4_UNMAPPED1	$10
.equ	IRQ_ENA4_UNMAPPED2	$20
.equ	IRQ_ENA4_SHOCK		$40
.equ	IRQ_ENA4_IR_RX		$80

.equ	IRQ_ACT1_TMR3_PVT	$01	; n+IRQ_ACT1
.equ	IRQ_ACT1_TMR3_HI	$02
.equ	IRQ_ACT1_TMR1_LO	$04
.equ	IRQ_ACT1_TMR1_HI	$08
.equ	IRQ_ACT1_TMR2_LO	$10
.equ	IRQ_ACT1_TMR2_HI	$20
.equ	IRQ_ACT1_PRC_DIV	$40
.equ	IRQ_ACT1_PRC_COPY	$80

.equ	IRQ_ACT2_CARTRIDGE	$01	; n+IRQ_ACT2
.equ	IRQ_ACT2_CART_EJECT	$02
.equ	IRQ_ACT2_1HZ		$04
.equ	IRQ_ACT2_2HZ		$08
.equ	IRQ_ACT2_8HZ		$10
.equ	IRQ_ACT2_32HZ		$20

.equ	IRQ_ACT3_KEY_A		$01	; n+IRQ_ACT3
.equ	IRQ_ACT3_KEY_B		$02
.equ	IRQ_ACT3_KEY_C		$04
.equ	IRQ_ACT3_KEY_UP		$08
.equ	IRQ_ACT3_KEY_DOWN	$10
.equ	IRQ_ACT3_KEY_LEFT	$20
.equ	IRQ_ACT3_KEY_RIGHT	$40
.equ	IRQ_ACT3_KEY_POWER	$80
.equ	IRQ_ACT3_KEYS		$FF

.equ	IRQ_ACT4_UNKNOWN1	$01	; n+IRQ_ACT4
.equ	IRQ_ACT4_UNKNOWN2	$02
.equ	IRQ_ACT4_UNKNOWN3	$04
.equ	IRQ_ACT4_UNMAPPED1	$10
.equ	IRQ_ACT4_UNMAPPED2	$20
.equ	IRQ_ACT4_SHOCK		$40
.equ	IRQ_ACT4_IR_RX		$80

.equ	KEY_A			$01	; n+KEY_PAD
.equ	KEY_B			$02
.equ	KEY_C			$04
.equ	KEY_UP			$08
.equ	KEY_DOWN		$10
.equ	KEY_LEFT		$20
.equ	KEY_RIGHT		$40
.equ	KEY_POWER		$80

.equ	IO_IR_TX		$01	; n+IO_DIR / n+IO_DATA
.equ	IO_IR_TRANSMIT		$01
.equ	IO_IR_RX		$02
.equ	IO_IR_RECEIVE		$02
.equ	IO_EEPROM_DAT		$04
.equ	IO_EEPROM_DATA		$04
.equ	IO_EEPROM_CLK		$08
.equ	IO_EEPROM_CLOCK		$08
.equ	IO_RUMBLE		$10
.equ	IO_IR_DISABLE		$20
.equ	IO_IR_OFF		$20

.equ	PRC_INVERTMAP		$01	; n+PRC_MODE
.equ	PRC_INVERTBG		$01
.equ	PRC_ENABLEMAP		$02
.equ	PRC_ENABLEBG		$02
.equ	PRC_MAP			$02
.equ	PRC_BG			$02
.equ	PRC_ENABLESPR		$04
.equ	PRC_ENABLEOAM		$04
.equ	PRC_SPR			$04
.equ	PRC_OAM			$04
.equ	PRC_ENABLE		$08
.equ	PRC_ENABLECOPY		$08
.equ	PRC_ENABLECPY		$08

.equ	PRC_MAP12X16		$00	; n+PRC_MODE
.equ	PRC_BG12X16		$00
.equ	PRC_MAP12x16		$00
.equ	PRC_BG12x16		$00
.equ	PRC_MAP16X12		$10
.equ	PRC_BG16X12		$10
.equ	PRC_MAP16x12		$10
.equ	PRC_BG16x12		$10
.equ	PRC_MAP24X8		$20
.equ	PRC_BG24X8		$20
.equ	PRC_MAP24x8		$20
.equ	PRC_BG24x8		$20
.equ	PRC_MAP24X16		$30
.equ	PRC_BG24X16		$30
.equ	PRC_MAP24x16		$30
.equ	PRC_BG24x16		$30
.equ	PRC_MAPMASK		$30
.equ	PRC_BGMASK		$30

.equ	PRC_RATE_3		$00	;n+PRC_RATE
.equ	PRC_RATE_6		$02
.equ	PRC_RATE_9		$04
.equ	PRC_RATE_12		$06
.equ	PRC_RATE_2		$08
.equ	PRC_RATE_4		$0A
.equ	PRC_RATE_6ALT		$0C
.equ	PRC_RATE_8		$0E
.equ	PRC_RATEMASK		$0E
.equ	PRC_24FPS		$00
.equ	PRC_12FPS		$02
.equ	PRC_8FPS		$04
.equ	PRC_6FPS		$06
.equ	PRC_36FPS		$08
.equ	PRC_18FPS		$0A
.equ	PRC_12FPSALT		$0C
.equ	PRC_9FPS		$0E
.equ	PRC_FPSMASK		$0E

.equ	LCD_COLUMN_LO		$00	; n+LCD_CTRL
.equ	LCD_COLUMN_HI		$10
.equ	LCD_STARTLINE		$40
.equ	LCD_PAGE		$B0
.equ	LCD_CONTRAST		$81
.equ	LCD_SEGDIR		$A0
.equ	LCD_INVSEGDIR		$A1
.equ	LCD_DISPSEL_ON		$A4
.equ	LCD_DISPSEL_OFF		$A5
.equ	LCD_DISPINV_ON		$A6
.equ	LCD_DISPINV_OFF		$A7
.equ	LCD_DISPENABLE		$AE
.equ	LCD_DISPDISABLE		$AF
.equ	LCD_ROWNORMAL		$C0
.equ	LCD_ROWINVERT		$C4
.equ	LCD_START_RMW		$E0
.equ	LCD_BEGIN_RMW		$E0
.equ	LCD_END_RMW		$EE
.equ	LCD_RESET		$E2
.equ	LCD_NOP			$E3

.equ	COLORPM_UNLOCKED	$CE

.equ	COLORPM_UNLOCK1		$5A
.equ	COLORPM_UNLOCK2		$CE
.equ	COLORPM_LOCK		$CF

.equ	COLORPM_FIXED		$A0
.equ	COLORPM_POSTINC		$A1
.equ	COLORPM_POSTDEC		$A2
.equ	COLORPM_PREINC		$A3

.equ	COLORPM_VRAM_ON		$D0
.equ	COLORPM_LCD_ON		$D1
.equ	COLORPM_PRC_ON		$D2

.equ	COLORPM_VRAM_OFF	$D8
.equ	COLORPM_LCD_OFF		$D9
.equ	COLORPM_PRC_OFF		$DA

.equ	COLORPM_FLIP		$F0

.equ	SPR_X			$00	; spr * 4 + ...
.equ	SPR_Y			$01
.equ	SPR_TILE		$02
.equ	SPR_CTRL		$03

.equ	OAM_X			$00	; spr * 4 + ...
.equ	OAM_Y			$01
.equ	OAM_TILE		$02
.equ	OAM_CTRL		$03

.equ	SPR_HFLIP		$01	; spr * 4 + SPR_CTRL
.equ	SPR_VFLIP		$02
.equ	SPR_INVERT		$04
.equ	SPR_ENABLE		$08
.equ	SPR_DISABLE		$00

.equ	OAM_FLIPH		$01	; spr * 4 + SPR_CTRL
.equ	OAM_FLIPV		$02
.equ	OAM_INVERT		$04
.equ	OAM_ENABLE		$08
.equ	OAM_DISABLE		$00

	; ---------
	; CINT IRQs

.equ	CINT_HARDRESET		$00
.equ	CINT_SOFTRESET		$01
.equ	CINT_SOFTRESET2		$02
.equ	CINT_PRC_COPY		$03
.equ	CINT_PRC_DIV		$04
.equ	CINT_TMR2_HI		$05
.equ	CINT_TMR2_LO		$06
.equ	CINT_TMR1_HI		$07
.equ	CINT_TMR1_LO		$08
.equ	CINT_TMR3_HI		$09
.equ	CINT_TMR3_PVT		$0A
.equ	CINT_32HZ		$0B
.equ	CINT_8HZ		$0C
.equ	CINT_2HZ		$0D
.equ	CINT_1HZ		$0E
.equ	CINT_IR_RX		$0F
.equ	CINT_SHOCK		$10
.equ	CINT_CART_EJECT		$13
.equ	CINT_CARTRIDGE		$14
.equ	CINT_KEY_POWER		$15
.equ	CINT_KEY_RIGHT		$16
.equ	CINT_KEY_LEFT		$17
.equ	CINT_KEY_DOWN		$18
.equ	CINT_KEY_UP		$19
.equ	CINT_KEY_C		$1A
.equ	CINT_KEY_B		$1B
.equ	CINT_KEY_A		$1C
.equ	CINT_UNKNOWN1D		$1D
.equ	CINT_UNKNOWN1E		$1E
.equ	CINT_UNKNOWN1F		$1F
.equ	CINT_IRQ_FFF1		$20
.equ	CINT_SUSPEND		$21
.equ	CINT_SLEEP_LCDOFF	$22
.equ	CINT_SLEEP_LCDON	$23
.equ	CINT_SHUTDOWN		$24
.equ	CINT_EXIT		$24
.equ	CINT_UNKNOWN25		$25
.equ	CINT_SET_CONTRAST	$26
.equ	CINT_ADD_CONTRAST	$27
.equ	CINT_APPLY_CONTRAST	$28
.equ	CINT_GET_CONTRAST	$29
.equ	CINT_TMP_CONTRAST	$2A
.equ	CINT_LCD_ON		$2B
.equ	CINT_LCD_INIT		$2C
.equ	CINT_LCD_OFF		$2D
.equ	CINT_ENABLE_RAMVECTOR	$2E
.equ	CINT_DISABLE_RAMVECTOR	$2F
.equ	CINT_ENABLE_CART_EJECT	$30
.equ	CINT_DISABLE_CART_EJECT	$31
.equ	CINT_UNKNOWN32		$32
.equ	CINT_UNKNOWN33		$33
.equ	CINT_UNKNOWN34		$34
.equ	CINT_UNKNOWN35		$35
.equ	CINT_UNKNOWN36		$36
.equ	CINT_UNKNOWN37		$37
.equ	CINT_UNKNOWN38		$38
.equ	CINT_UNKNOWN39		$39
.equ	CINT_UNKNOWN3A		$3A
.equ	CINT_CART_DISABLE	$3B
.equ	CINT_CART_ENABLE	$3C
.equ	CINT_CART_DETECT	$3D
.equ	CINT_ROUTINE		$3E
.equ	CINT_SET_PRC_RATE	$3F
.equ	CINT_GET_PRC_RATE	$40
.equ	CINT_MULTICART		$41
.equ	CINT_DEVCART_READID	$42
.equ	CINT_DEVCART_RESET	$43
.equ	CINT_DEVCART_PROGRAM	$44
.equ	CINT_DEVCART_ERASE	$45
.equ	CINT_DEVCART_UNLOCK	$46
.equ	CINT_DEVCART_BANK	$47
.equ	CINT_DEVCART_CMD_C9	$48
.equ	CINT_DEVCART_PREPID	$49
.equ	CINT_DEVCART_SELGAME	$4A
.equ	CINT_DEVCART_NSDK	$4B
.equ	CINT_IR_PULSE		$4C

	; --------------
	; Helpful Macros

.macroicase FJMP pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jmp ((pmpar_offset & $7FFF) | $8000)
 .else
	jmp pmpar_offset
 .endif
.endm

.macroicase FJC pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jc ((pmpar_offset & $7FFF) | $8000)
 .else
	jc pmpar_offset
 .endif
.endm

.macroicase FJNC pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jnc ((pmpar_offset & $7FFF) | $8000)
 .else
	jnc pmpar_offset
 .endif
.endm

.macroicase FJZ pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jz ((pmpar_offset & $7FFF) | $8000)
 .else
	jz pmpar_offset
 .endif
.endm

.macroicase FJNZ pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jnz ((pmpar_offset & $7FFF) | $8000)
 .else
	jnz pmpar_offset
 .endif
.endm

.macroicase FJDBNZ pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jdbnz ((pmpar_offset & $7FFF) | $8000)
 .else
	jdbnz pmpar_offset
 .endif
.endm

.macroicase FJL pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jl ((pmpar_offset & $7FFF) | $8000)
 .else
	jl pmpar_offset
 .endif
.endm

.macroicase FJLE pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jle ((pmpar_offset & $7FFF) | $8000)
 .else
	jle pmpar_offset
 .endif
.endm

.macroicase FJG pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jg ((pmpar_offset & $7FFF) | $8000)
 .else
	jg pmpar_offset
 .endif
.endm

.macroicase FJGE pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jge ((pmpar_offset & $7FFF) | $8000)
 .else
	jge pmpar_offset
 .endif
.endm

.macroicase FJO pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jo ((pmpar_offset & $7FFF) | $8000)
 .else
	jo pmpar_offset
 .endif
.endm

.macroicase FJNO pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jno ((pmpar_offset & $7FFF) | $8000)
 .else
	jno pmpar_offset
 .endif
.endm

.macroicase FJNS pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	jns ((pmpar_offset & $7FFF) | $8000)
 .else
	jns pmpar_offset
 .endif
.endm

.macroicase FJS pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	js ((pmpar_offset & $7FFF) | $8000)
 .else
	js pmpar_offset
 .endif
.endm

.macroicase FCALL pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	call ((pmpar_offset & $7FFF) | $8000)
 .else
	call pmpar_offset
 .endif
.endm

.macroicase FCALLC pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	callc ((pmpar_offset & $7FFF) | $8000)
 .else
	callc pmpar_offset
 .endif
.endm

.macroicase FCALLNC pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	callnc ((pmpar_offset & $7FFF) | $8000)
 .else
	callnc pmpar_offset
 .endif
.endm

.macroicase FCALLZ pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	callz ((pmpar_offset & $7FFF) | $8000)
 .else
	callz pmpar_offset
 .endif
.endm

.macroicase FCALLNZ pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	callnz ((pmpar_offset & $7FFF) | $8000)
 .else
	callnz pmpar_offset
 .endif
.endm

.macroicase FCALLL pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	calll ((pmpar_offset & $7FFF) | $8000)
 .else
	calll pmpar_offset
 .endif
.endm

.macroicase FCALLLE pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	callle ((pmpar_offset & $7FFF) | $8000)
 .else
	callle pmpar_offset
 .endif
.endm

.macroicase FCALLG pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	callg ((pmpar_offset & $7FFF) | $8000)
 .else
	callg pmpar_offset
 .endif
.endm

.macroicase FCALLGE pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	callge ((pmpar_offset & $7FFF) | $8000)
 .else
	callge pmpar_offset
 .endif
.endm

.macroicase FCALLO pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	callo ((pmpar_offset & $7FFF) | $8000)
 .else
	callo pmpar_offset
 .endif
.endm

.macroicase FCALLNO pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	callno ((pmpar_offset & $7FFF) | $8000)
 .else
	callno pmpar_offset
 .endif
.endm

.macroicase FCALLNS pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	callns ((pmpar_offset & $7FFF) | $8000)
 .else
	callns pmpar_offset
 .endif
.endm

.macroicase FCALLS pmpar_offset
 .if pmpar_offset >= $8000
	mov u, (pmpar_offset >> 15)
	calls ((pmpar_offset & $7FFF) | $8000)
 .else
	calls pmpar_offset
 .endif
.endm

.macroicase CPU_CLEAR
	and f, $CF
.endm

.macroicase SET_F pmpar_flags
	or f, pmpar_flags
.endm

.macroicase CLEAR_F pmpar_flags
	and f, ~pmpar_flags
.endm

.macroicase PM_ALIGN_MAP
 .org (. + 7) & ~7
.endm

.macroicase PM_ALIGN_TILES
 .org (. + 7) & ~7
.endm

.macroicase PM_ALIGN_BG
 .org (. + 7) & ~7
.endm

.macroicase PM_ALIGN_BACKGROUND
 .org (. + 7) & ~7
.endm

.macroicase PM_ALIGN_SPR
 .org (. + 63) & ~63
.endm

.macroicase PM_ALIGN_OAM
 .org (. + 63) & ~63
.endm

.macroicase PM_ALIGN_SPRITES
 .org (. + 63) & ~63
.endm

.macroicase PM_CODEINFO
 .printf "Code size: %i Bytes\n", (. - ROM_BASE)
.endm

.macroicase PM_DATAINFO
 .printf "ROM size: %i Bytes\n", (.)
 .printf "ROM banks: %i Bank(s)\n", (. + 32767) / 32768
 .printf "RAM size: %i Bytes\n", (__RAMBASE__ - RAM_BASE)
 .printf "RAM usage: %i%%\n", (__RAMBASE__ - RAM_BASE) * 100 / RAM_SIZE
.endm

.macroicase PM_ROMINFO
 .printf "ROM size: %i Bytes\n", (.)
 .printf "ROM banks: %i Bank(s)\n", (. + 32767) / 32768
.endm

.macroicase COLORPM_INIT
	mov [n+COLORPM_CMD], COLORPM_UNLOCK1
	mov [n+COLORPM_CMD], COLORPM_UNLOCK2
.endm

	; ----------------
	; Interrupt Macros

; 3rd macro parameter
.define	IRQ_PRC_COPY	$000001
.define	IRQ_PRC_DIV	$000002
.define	IRQ_TMR2_HI	$000004
.define	IRQ_TMR2_LO	$000008
.define	IRQ_TMR1_HI	$000010
.define	IRQ_TMR1_LO	$000020
.define	IRQ_TMR3_HI	$000040
.define	IRQ_TMR3_PVT	$000080
.define	IRQ_32HZ	$000100
.define	IRQ_8HZ		$000200
.define	IRQ_2HZ		$000400
.define	IRQ_1HZ		$000800
.define	IRQ_IR_RX	$001000
.define	IRQ_SHOCK	$002000
.define	IRQ_UNKNOWN	$004000
.define	IRQ_CARTRIDGE	$008000
.define	IRQ_KEY_POWER	$010000
.define	IRQ_KEY_RIGHT	$020000
.define	IRQ_KEY_LEFT	$040000
.define	IRQ_KEY_DOWN	$080000
.define	IRQ_KEY_UP	$100000
.define	IRQ_KEY_C	$200000
.define	IRQ_KEY_B	$400000
.define	IRQ_KEY_A	$800000

.define	IRQ_PRC		$000003
.define	IRQ_TMR2	$00000C
.define	IRQ_TMR1	$000030
.define	IRQ_TMR3	$0000C0
.define	IRQ_TMR256	$000F00
.define	IRQ_HZ		$000F00
.define	IRQ_IO		$003000
.define	IRQ_PIO		$003000
.define	IRQ_KEY		$FF0000
.define	IRQ_ALL		$FF3FFF
.define	IRQ_TOTALLYALL	$FFFFFF

; 4th macro parameter
.define IRQF_FAR	$01
.define IRQF_NORIRQ	$02
.define IRQF_NOSTARTUP	$04

.macroicase RIRQ pmpar_irq_select
	push hl
 .if (pmpar_irq_select == IRQ_PRC_COPY)
	mov l, $00
 .elif (pmpar_irq_select == IRQ_PRC_DIV)
	mov l, $02
 .elif (pmpar_irq_select == IRQ_TMR2_HI)
	mov l, $04
 .elif (pmpar_irq_select == IRQ_TMR2_LO)
	mov l, $06
 .elif (pmpar_irq_select == IRQ_TMR1_HI)
	mov l, $08
 .elif (pmpar_irq_select == IRQ_TMR1_LO)
	mov l, $0A
 .elif (pmpar_irq_select == IRQ_TMR3_HI)
	mov l, $0C
 .elif (pmpar_irq_select == IRQ_TMR3_PVT)
	mov l, $0E
 .elif (pmpar_irq_select == IRQ_32HZ)
	mov l, $10
 .elif (pmpar_irq_select == IRQ_8HZ)
	mov l, $12
 .elif (pmpar_irq_select == IRQ_2HZ)
	mov l, $14
 .elif (pmpar_irq_select == IRQ_1HZ)
	mov l, $16
 .elif (pmpar_irq_select == IRQ_IR_RX)
	mov l, $18
 .elif (pmpar_irq_select == IRQ_SHOCK)
	mov l, $1A
 .elif (pmpar_irq_select == IRQ_UNKNOWN)
	mov l, $1C
 .elif (pmpar_irq_select == IRQ_CARTRIDGE)
	mov l, $1E
 .elif (pmpar_irq_select == IRQ_KEY_POWER)
	mov l, $20
 .elif (pmpar_irq_select == IRQ_KEY_RIGHT)
	mov l, $22
 .elif (pmpar_irq_select == IRQ_KEY_LEFT)
	mov l, $24
 .elif (pmpar_irq_select == IRQ_KEY_DOWN)
	mov l, $26
 .elif (pmpar_irq_select == IRQ_KEY_UP)
	mov l, $28
 .elif (pmpar_irq_select == IRQ_KEY_C)
	mov l, $2A
 .elif (pmpar_irq_select == IRQ_KEY_B)
	mov l, $2C
 .elif (pmpar_irq_select == IRQ_KEY_A)
	mov l, $2E
 .else
  .error "Unsupported IRQ value in rirq macro"
 .endif
 .if (pmpar_irq_select == IRQ_PRC_DIV)
	jmp rirq_handle_prcdiv
 .else
	jmp rirq_handle
 .endif
.endm

.macroicase DISABLE_MIRQ
	or f, $40
.endm 

.macroicase ENABLE_MIRQ
	and f, $BF
.endm

.macroicase PRIORITY_IRQS pmpar_priority, pmpar_irqs_select
 .if ((pmpar_priority < 0) && (pmpar_priority > 3))
  .error "Priority must be between 0 and 3"
 .endif
 .set priority_irqs___enable1 0
 .set priority_irqs___enable2 0
 .set priority_irqs___enable3 0
 .set priority_irqs___enable4 0
 .if (pmpar_irqs_select & (IRQ_PRC_COPY | IRQ_PRC_DIV))
  .set priority_irqs___enable1 priority_irqs___enable1+IRQ_PRI1_PRC
 .endif
 .if (pmpar_irqs_select & (IRQ_TMR2_HI | IRQ_TMR2_LO))
  .set priority_irqs___enable1 priority_irqs___enable1+IRQ_PRI1_TMR2
 .endif
 .if (pmpar_irqs_select & (IRQ_TMR1_HI | IRQ_TMR1_LO))
  .set priority_irqs___enable1 priority_irqs___enable1+IRQ_PRI1_TMR1
 .endif
 .if (pmpar_irqs_select & (IRQ_TMR3_HI | IRQ_TMR3_PVT))
  .set priority_irqs___enable1 priority_irqs___enable1+IRQ_PRI1_TMR3
 .endif
 .if (pmpar_irqs_select & (IRQ_32HZ | IRQ_8HZ | IRQ_2HZ | IRQ_1HZ))
  .set priority_irqs___enable2 priority_irqs___enable2+IRQ_PRI2_TMR256
 .endif
 .if (pmpar_irqs_select & (IRQ_IR_RX | IRQ_SHOCK))
  .set priority_irqs___enable3 priority_irqs___enable3+IRQ_PRI3_IO
 .endif
 .if (pmpar_irqs_select & IRQ_UNKNOWN)
  .set priority_irqs___enable2 priority_irqs___enable2+IRQ_PRI2_UNKNOWN
 .endif
 .if (pmpar_irqs_select & IRQ_CARTRIDGE)
  .set priority_irqs___enable2 priority_irqs___enable2+IRQ_PRI2_CARTRIDGE
 .endif
 .if (pmpar_irqs_select & (IRQ_KEY_POWER | IRQ_KEY_RIGHT | IRQ_KEY_LEFT | IRQ_KEY_DOWN | IRQ_KEY_UP | IRQ_KEY_C | IRQ_KEY_B | IRQ_KEY_A))
  .set priority_irqs___enable2 priority_irqs___enable2+IRQ_PRI2_KEY_PAD
 .endif
 .if (priority_irqs___enable1 != 0)
  .if (pmpar_priority == 0)
	and [n+IRQ_PRI1], ~priority_irqs___enable1
  .elif (pmpar_priority == 3)
	or [n+IRQ_PRI1], priority_irqs___enable1
  .else
	and [n+IRQ_PRI1], ~priority_irqs___enable1
	or [n+IRQ_PRI1], (priority_irqs___enable1 & 0x55) * pmpar_priority
  .endif
 .endif
 .if (priority_irqs___enable2 != 0)
  .if (pmpar_priority == 0)
	and [n+IRQ_PRI2], ~priority_irqs___enable2
  .elif (pmpar_priority == 3)
	or [n+IRQ_PRI2], priority_irqs___enable2
  .else
	and [n+IRQ_PRI2], ~priority_irqs___enable2
	or [n+IRQ_PRI2], (priority_irqs___enable2 & 0x55) * pmpar_priority
  .endif
 .endif
 .if (priority_irqs___enable3 != 0)
  .if (pmpar_priority == 0)
	and [n+IRQ_PRI3], ~priority_irqs___enable3
  .elif (pmpar_priority == 3)
	or [n+IRQ_PRI3], priority_irqs___enable3
  .else
	and [n+IRQ_PRI3], ~priority_irqs___enable3
	or [n+IRQ_PRI3], (priority_irqs___enable3 & 0x55) * pmpar_priority
  .endif
 .endif
 .if (priority_irqs___enable4 != 0)
  .if (pmpar_priority == 0)
	and [n+IRQ_PRI4], ~priority_irqs___enable4
  .elif (pmpar_priority == 3)
	or [n+IRQ_PRI4], priority_irqs___enable4
  .else
	and [n+IRQ_PRI4], ~priority_irqs___enable4
	or [n+IRQ_PRI4], (priority_irqs___enable4 & 0x55) * pmpar_priority
  .endif
 .endif
 .unset priority_irqs___enable1
 .unset priority_irqs___enable2
 .unset priority_irqs___enable3
 .unset priority_irqs___enable4
.endm

.macroicase ENABLE_IRQS pmpar_irqs_select
 .set enable_irqs___enable1 0
 .set enable_irqs___enable2 0
 .set enable_irqs___enable3 0
 .set enable_irqs___enable4 0
 .if (pmpar_irqs_select & IRQ_PRC_COPY)
  .set enable_irqs___enable1 enable_irqs___enable1+IRQ_ENA1_PRC_COPY
 .endif
 .if (pmpar_irqs_select & IRQ_PRC_DIV)
  .set enable_irqs___enable1 enable_irqs___enable1+IRQ_ENA1_PRC_DIV
 .endif
 .if (pmpar_irqs_select & IRQ_TMR2_HI)
  .set enable_irqs___enable1 enable_irqs___enable1+IRQ_ENA1_TMR2_HI
 .endif
 .if (pmpar_irqs_select & IRQ_TMR2_LO)
  .set enable_irqs___enable1 enable_irqs___enable1+IRQ_ENA1_TMR2_LO
 .endif
 .if (pmpar_irqs_select & IRQ_TMR1_HI)
  .set enable_irqs___enable1 enable_irqs___enable1+IRQ_ENA1_TMR1_HI
 .endif
 .if (pmpar_irqs_select & IRQ_TMR1_LO)
  .set enable_irqs___enable1 enable_irqs___enable1+IRQ_ENA1_TMR1_LO
 .endif
 .if (pmpar_irqs_select & IRQ_TMR3_HI)
  .set enable_irqs___enable1 enable_irqs___enable1+IRQ_ENA1_TMR3_HI
 .endif
 .if (pmpar_irqs_select & IRQ_TMR3_PVT)
  .set enable_irqs___enable1 enable_irqs___enable1+IRQ_ENA1_TMR3_PVT
 .endif
 .if (pmpar_irqs_select & IRQ_32HZ)
  .set enable_irqs___enable2 enable_irqs___enable2+IRQ_ENA2_32HZ
 .endif
 .if (pmpar_irqs_select & IRQ_8HZ)
  .set enable_irqs___enable2 enable_irqs___enable2+IRQ_ENA2_8HZ
 .endif
 .if (pmpar_irqs_select & IRQ_2HZ)
  .set enable_irqs___enable2 enable_irqs___enable2+IRQ_ENA2_2HZ
 .endif
 .if (pmpar_irqs_select & IRQ_1HZ)
  .set enable_irqs___enable2 enable_irqs___enable2+IRQ_ENA2_1HZ
 .endif
 .if (pmpar_irqs_select & IRQ_IR_RX)
  .set enable_irqs___enable4 enable_irqs___enable4+IRQ_ENA4_IR_RX
 .endif
 .if (pmpar_irqs_select & IRQ_SHOCK)
  .set enable_irqs___enable4 enable_irqs___enable4+IRQ_ENA4_SHOCK
 .endif
 .if (pmpar_irqs_select & IRQ_UNKNOWN)
  .set enable_irqs___enable4 enable_irqs___enable4+IRQ_ENA4_UNKNOWN1+IRQ_ENA4_UNKNOWN2+IRQ_ENA4_UNKNOWN3
 .endif
 .if (pmpar_irqs_select & IRQ_CARTRIDGE)
  .set enable_irqs___enable2 enable_irqs___enable2+IRQ_ENA2_CARTRIDGE
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_POWER)
  .set enable_irqs___enable3 enable_irqs___enable3+IRQ_ENA3_KEY_POWER
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_RIGHT)
  .set enable_irqs___enable3 enable_irqs___enable3+IRQ_ENA3_KEY_RIGHT
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_LEFT)
  .set enable_irqs___enable3 enable_irqs___enable3+IRQ_ENA3_KEY_LEFT
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_DOWN)
  .set enable_irqs___enable3 enable_irqs___enable3+IRQ_ENA3_KEY_DOWN
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_UP)
  .set enable_irqs___enable3 enable_irqs___enable3+IRQ_ENA3_KEY_UP
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_C)
  .set enable_irqs___enable3 enable_irqs___enable3+IRQ_ENA3_KEY_C
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_B)
  .set enable_irqs___enable3 enable_irqs___enable3+IRQ_ENA3_KEY_B
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_A)
  .set enable_irqs___enable3 enable_irqs___enable3+IRQ_ENA3_KEY_A
 .endif
 .if (enable_irqs___enable1 != 0)
	or [n+IRQ_ENA1], enable_irqs___enable1
 .endif
 .if (enable_irqs___enable2 != 0)
	or [n+IRQ_ENA2], enable_irqs___enable2
 .endif
 .if (enable_irqs___enable3 != 0)
	or [n+IRQ_ENA3], enable_irqs___enable3
 .endif
 .if (enable_irqs___enable4 != 0)
	or [n+IRQ_ENA4], enable_irqs___enable4
 .endif
 .unset enable_irqs___enable1
 .unset enable_irqs___enable2
 .unset enable_irqs___enable3
 .unset enable_irqs___enable4
.endm

.macroicase DISABLE_IRQS pmpar_irqs_select
 .set disable_irqs___enable1 0
 .set disable_irqs___enable2 0
 .set disable_irqs___enable3 0
 .set disable_irqs___enable4 0
 .if (pmpar_irqs_select & IRQ_PRC_COPY)
  .set disable_irqs___enable1 disable_irqs___enable1+IRQ_ENA1_PRC_COPY
 .endif
 .if (pmpar_irqs_select & IRQ_PRC_DIV)
  .set disable_irqs___enable1 disable_irqs___enable1+IRQ_ENA1_PRC_DIV
 .endif
 .if (pmpar_irqs_select & IRQ_TMR2_HI)
  .set disable_irqs___enable1 disable_irqs___enable1+IRQ_ENA1_TMR2_HI
 .endif
 .if (pmpar_irqs_select & IRQ_TMR2_LO)
  .set disable_irqs___enable1 disable_irqs___enable1+IRQ_ENA1_TMR2_LO
 .endif
 .if (pmpar_irqs_select & IRQ_TMR1_HI)
  .set disable_irqs___enable1 disable_irqs___enable1+IRQ_ENA1_TMR1_HI
 .endif
 .if (pmpar_irqs_select & IRQ_TMR1_LO)
  .set disable_irqs___enable1 disable_irqs___enable1+IRQ_ENA1_TMR1_LO
 .endif
 .if (pmpar_irqs_select & IRQ_TMR3_HI)
  .set disable_irqs___enable1 disable_irqs___enable1+IRQ_ENA1_TMR3_HI
 .endif
 .if (pmpar_irqs_select & IRQ_TMR3_PVT)
  .set disable_irqs___enable1 disable_irqs___enable1+IRQ_ENA1_TMR3_PVT
 .endif
 .if (pmpar_irqs_select & IRQ_32HZ)
  .set disable_irqs___enable2 disable_irqs___enable2+IRQ_ENA2_32HZ
 .endif
 .if (pmpar_irqs_select & IRQ_8HZ)
  .set disable_irqs___enable2 disable_irqs___enable2+IRQ_ENA2_8HZ
 .endif
 .if (pmpar_irqs_select & IRQ_2HZ)
  .set disable_irqs___enable2 disable_irqs___enable2+IRQ_ENA2_2HZ
 .endif
 .if (pmpar_irqs_select & IRQ_1HZ)
  .set disable_irqs___enable2 disable_irqs___enable2+IRQ_ENA2_1HZ
 .endif
 .if (pmpar_irqs_select & IRQ_IR_RX)
  .set disable_irqs___enable4 disable_irqs___enable4+IRQ_ENA4_IR_RX
 .endif
 .if (pmpar_irqs_select & IRQ_SHOCK)
  .set disable_irqs___enable4 disable_irqs___enable4+IRQ_ENA4_SHOCK
 .endif
 .if (pmpar_irqs_select & IRQ_UNKNOWN)
  .set disable_irqs___enable4 disable_irqs___enable4+IRQ_ENA4_UNKNOWN1+IRQ_ENA4_UNKNOWN2+IRQ_ENA4_UNKNOWN3
 .endif
 .if (pmpar_irqs_select & IRQ_CARTRIDGE)
  .set disable_irqs___enable2 disable_irqs___enable2+IRQ_ENA2_CARTRIDGE
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_POWER)
  .set disable_irqs___enable3 disable_irqs___enable3+IRQ_ENA3_KEY_POWER
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_RIGHT)
  .set disable_irqs___enable3 disable_irqs___enable3+IRQ_ENA3_KEY_RIGHT
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_LEFT)
  .set disable_irqs___enable3 disable_irqs___enable3+IRQ_ENA3_KEY_LEFT
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_DOWN)
  .set disable_irqs___enable3 disable_irqs___enable3+IRQ_ENA3_KEY_DOWN
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_UP)
  .set disable_irqs___enable3 disable_irqs___enable3+IRQ_ENA3_KEY_UP
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_C)
  .set disable_irqs___enable3 disable_irqs___enable3+IRQ_ENA3_KEY_C
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_B)
  .set disable_irqs___enable3 disable_irqs___enable3+IRQ_ENA3_KEY_B
 .endif
 .if (pmpar_irqs_select & IRQ_KEY_A)
  .set disable_irqs___enable3 disable_irqs___enable3+IRQ_ENA3_KEY_A
 .endif
 .if (disable_irqs___enable1 != 0)
	and [n+IRQ_ENA1], ~disable_irqs___enable1
 .endif
 .if (disable_irqs___enable2 != 0)
	and [n+IRQ_ENA2], ~disable_irqs___enable2
 .endif
 .if (disable_irqs___enable3 != 0)
	and [n+IRQ_ENA3], ~disable_irqs___enable3
 .endif
 .if (disable_irqs___enable4 != 0)
	and [n+IRQ_ENA4], ~disable_irqs___enable4
 .endif
 .unset disable_irqs___enable1
 .unset disable_irqs___enable2
 .unset disable_irqs___enable3
 .unset disable_irqs___enable4
.endm

	; -------------
	; Header Macros

.ifndef PM_GAMECODE
.define PM_GAMECODE "HmBw"
.endif

.macroicase PM_HEADER pmpar_txt_name, pmpar_irq_active, pmpar_irq_flag
.org $2100
.db "MN"
.if (pmpar_irq_flag & IRQF_NOSTARTUP)
	jmp main
.else
	jmp main_pm_entry
.endif

.org $2108	; IRQ $03 - PRC Copy Complete
.if (pmpar_irq_active & IRQ_PRC_COPY)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_prc_copy >> 15)
 .endif
	jmp irq_prc_copy
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $00
	jmp rirq_handle
 .endif
.endif

.org $210E	; IRQ $04 - PRC Frame Divider Overflow
.if (pmpar_irq_active & IRQ_PRC_DIV)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_prc_div >> 15)
 .endif
	jmp irq_prc_div
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $02
	jmp rirq_handle_prcdiv
 .endif
.endif

.org $2114	; IRQ $05 - Timer2 Upper-8 Underflow
.if (pmpar_irq_active & IRQ_TMR2_HI)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_tmr2_hi >> 15)
 .endif
	jmp irq_tmr2_hi
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $04
	jmp rirq_handle
 .endif
.endif

.org $211A	; IRQ $06 - Timer2 Lower-8 Underflow (8-bit only)
.if (pmpar_irq_active & IRQ_TMR2_LO)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_tmr2_lo >> 15)
 .endif
	jmp irq_tmr2_lo
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $06
	jmp rirq_handle
 .endif
.endif

.org $2120	; IRQ $07 - Timer1 Upper-8 Underflow
.if (pmpar_irq_active & IRQ_TMR1_HI)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_tmr1_hi >> 15)
 .endif
	jmp irq_tmr1_hi
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $08
	jmp rirq_handle
 .endif
.endif

.org $2126	; IRQ $08 - Timer1 Lower-8 Underflow (8-bit only)
.if (pmpar_irq_active & IRQ_TMR1_LO)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_tmr1_lo >> 15)
 .endif
	jmp irq_tmr1_lo
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $0A
	jmp rirq_handle
 .endif
.endif

.org $212C	; IRQ $09 - Timer3 Upper-8 Underflow
.if (pmpar_irq_active & IRQ_TMR3_HI)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_tmr3_hi >> 15)
 .endif
	jmp irq_tmr3_hi
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $0C
	jmp rirq_handle
 .endif
.endif

.org $2132	; IRQ $0A - Timer3 Pivot
.if (pmpar_irq_active & IRQ_TMR3_PVT)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_tmr3_pvt >> 15)
 .endif
	jmp irq_tmr3_pvt
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $0E
	jmp rirq_handle
 .endif
.endif

.org $2138	; IRQ $0B - 32Hz (From 256Hz Timer)
.if (pmpar_irq_active & IRQ_32HZ)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_32hz >> 15)
 .endif
	jmp irq_32hz
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $10
	jmp rirq_handle
 .endif
.endif
	
.org $213E	; IRQ $0C - 8Hz (From 256Hz Timer)
.if (pmpar_irq_active & IRQ_8HZ)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_8hz >> 15)
 .endif
	jmp irq_8hz
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $12
	jmp rirq_handle
 .endif
.endif
	
.org $2144	; IRQ $0D - 2Hz (From 256Hz Timer)
.if (pmpar_irq_active & IRQ_2HZ)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_2hz >> 15)
 .endif
	jmp irq_2hz
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $14
	jmp rirq_handle
 .endif
.endif
	
.org $214A	; IRQ $0E - 1Hz (From 256Hz Timer)
.if (pmpar_irq_active & IRQ_1HZ)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_1hz >> 15)
 .endif
	jmp irq_1hz
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $16
	jmp rirq_handle
 .endif
.endif

.org $2150	; IRQ $0F - IR Receiver
.if (pmpar_irq_active & IRQ_IR_RX)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_ir_rx >> 15)
 .endif
	jmp irq_ir_rx
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $18
	jmp rirq_handle
 .endif
.endif

.org $2156	; IRQ $10 - Shock Sensor
.if (pmpar_irq_active & IRQ_SHOCK)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_shock >> 15)
 .endif
	jmp irq_shock
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $1A
	jmp rirq_handle
 .endif
.endif

.org $215C	; IRQ $15 - Power Key
.if (pmpar_irq_active & IRQ_KEY_POWER)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_key_power >> 15)
 .endif
	jmp irq_key_power
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $20
	jmp rirq_handle
 .endif
.endif

.org $2162	; IRQ $16 - Right Key
.if (pmpar_irq_active & IRQ_KEY_RIGHT)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_key_right >> 15)
 .endif
	jmp irq_key_right
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $22
	jmp rirq_handle
 .endif
.endif

.org $2168	; IRQ $17 - Left Key
.if (pmpar_irq_active & IRQ_KEY_LEFT)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_key_left >> 15)
 .endif
	jmp irq_key_left
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $24
	jmp rirq_handle
 .endif
.endif
	
.org $216E	; IRQ $18 - Down Key
.if (pmpar_irq_active & IRQ_KEY_DOWN)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_key_down >> 15)
 .endif
	jmp irq_key_down
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $26
	jmp rirq_handle
 .endif
.endif

.org $2174	; IRQ $19 - Up Key
.if (pmpar_irq_active & IRQ_KEY_UP)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_key_up >> 15)
 .endif
	jmp irq_key_up
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $28
	jmp rirq_handle
 .endif
.endif

.org $217A	; IRQ $1A - C Key
.if (pmpar_irq_active & IRQ_KEY_C)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_key_c >> 15)
 .endif
	jmp irq_key_c
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $2A
	jmp rirq_handle
 .endif
.endif

.org $2180	; IRQ $1B - B Key
.if (pmpar_irq_active & IRQ_KEY_B)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_key_b >> 15)
 .endif
	jmp irq_key_b
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $2C
	jmp rirq_handle
 .endif
.endif

.org $2186	; IRQ $1C - A Key
.if (pmpar_irq_active & IRQ_KEY_A)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_key_a >> 15)
 .endif
	jmp irq_key_a
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $2E
	jmp rirq_handle
 .endif
.endif

.org $218C	; IRQ $1D - Unknown
.if (pmpar_irq_active & IRQ_UNKNOWN)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_unknown >> 15)
 .endif
	jmp irq_unknown
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $1C
	jmp rirq_handle
 .endif
.endif

.org $2192	; IRQ $1E - Unknown
.if (pmpar_irq_active & IRQ_UNKNOWN)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_unknown >> 15)
 .endif
	jmp irq_unknown
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $1C
	jmp rirq_handle
 .endif
.endif

.org $2198	; IRQ $1F - Unknown
.if (pmpar_irq_active & IRQ_UNKNOWN)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_unknown >> 15)
 .endif
	jmp irq_unknown
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $1C
	jmp rirq_handle
 .endif
.endif

.org $219E	; IRQ $14 - Cartridge IRQ
.if (pmpar_irq_active & IRQ_CARTRIDGE)
 .if (pmpar_irq_flag & IRQF_FAR)
	mov u, (irq_cartridge >> 15)
 .endif
	jmp irq_cartridge
.else
 .if (pmpar_irq_flag & IRQF_NORIRQ)
	reti
 .else
	push hl
	mov l, $1E
	jmp rirq_handle
 .endif
.endif

.org $21A4
.db "NINTENDO"
.org $21AC
.db PM_GAMECODE
.org $21B0
.db pmpar_txt_name
.org $21BC
.db "2P"

.org $21D0
.if (!(pmpar_irq_flag & IRQF_NORIRQ))
rirq_table:
.db $80, IRQ_ACT1	; IRQ $03 - PRC Copy Complete
.db $40, IRQ_ACT1	; IRQ $04 - PRC Frame Divider Overflow
.db $20, IRQ_ACT1	; IRQ $05 - Timer2 Upper-8 Underflow
.db $10, IRQ_ACT1	; IRQ $06 - Timer2 Lower-8 Underflow (8-bit only)
.db $08, IRQ_ACT1	; IRQ $07 - Timer1 Upper-8 Underflow
.db $04, IRQ_ACT1	; IRQ $08 - Timer1 Lower-8 Underflow (8-bit only)
.db $02, IRQ_ACT1	; IRQ $09 - Timer3 Upper-8 Underflow
.db $01, IRQ_ACT1	; IRQ $0A - Timer3 Pivot
.db $20, IRQ_ACT2	; IRQ $0B - 32Hz (From 256Hz Timer)
.db $10, IRQ_ACT2	; IRQ $0C - 8Hz (From 256Hz Timer)
.db $08, IRQ_ACT2	; IRQ $0D - 2Hz (From 256Hz Timer)
.db $04, IRQ_ACT2	; IRQ $0E - 1Hz (From 256Hz Timer)
.db $80, IRQ_ACT4	; IRQ $0F - IR Receiver
.db $40, IRQ_ACT4	; IRQ $10 - Shock Sensor
.db $07, IRQ_ACT4	; IRQ $1D~$1F - Unknown
.db $01, IRQ_ACT2	; IRQ $14 - Cartridge IRQ
.db $80, IRQ_ACT3	; IRQ $15 - Power Key
.db $40, IRQ_ACT3	; IRQ $16 - Right Key
.db $20, IRQ_ACT3	; IRQ $17 - Left Key
.db $10, IRQ_ACT3	; IRQ $18 - Down Key
.db $08, IRQ_ACT3	; IRQ $19 - Up Key
.db $04, IRQ_ACT3	; IRQ $1A - C Key
.db $02, IRQ_ACT3	; IRQ $1B - B Key
.db $01, IRQ_ACT3	; IRQ $1C - A Key

rirq_handle_prcdiv:
	push i
	mov i, $00
	mov hl, PMINIT_FRAMECNT
	inc [hl]
	mov [n+IRQ_ACT1], IRQ_ACT1_PRC_DIV
	pop i
	pop hl
	reti

rirq_handle:
	push i
	push ba
	mov i, $00
	mov h, $00
	add hl, rirq_table
	mov a, [hl]
	inc hl
	mov l, [hl]
	mov h, $20
	mov [hl], a
	pop ba
	pop i
	pop hl
	reti
.endif

.if (!(pmpar_irq_flag & IRQF_NOSTARTUP))
main_pm_entry:
	mov f, DISABLE_IRQ
	xor a, a
	mov i, a
	mov xi, a
	mov yi, a
	mov n, N_BASE
	mov sp, SSTACK_BASE
	mov [n+PRC_MAP_HI], a
	mov [n+PRC_SPR_HI], a
	mov [PMINIT_RAND+1], a   ; Hi Rand
	mov [PMINIT_FRAMECNT], a ; Frame Cnt
	mov [PMINIT_KEYPAD], b   ; InitKeys
	mov [n+IRQ_ENA1], a
	mov [n+IRQ_ENA2], a
	mov [n+IRQ_ENA3], a
	mov [n+IRQ_ENA4], a
	mov a, $FF
	mov [n+IRQ_ACT1], a
	mov [n+IRQ_ACT2], a
	mov [n+IRQ_ACT3], a
	mov [n+IRQ_ACT4], a
	mov [n+IRQ_PRI1], a
	mov [n+IRQ_PRI2], a
	mov [n+IRQ_PRI3], a
	mov a, $01
	mov [PMINIT_RAND], a     ; Lo Rand = $0001
	jmp main
.endif

ROM_BASE:
.endm

.macroicase ADD24X pminitp_addsub24
 .if pminitp_addsub24 == 1
	inc x
	jnzb _skip
	push a
	mov a, xi
	inc a
	mov xi, a
	pop a
 .elif pminitp_addsub24 >= 65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 <= -65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 > 0
	add x, pminitp_addsub24
	jncb _skip
	push a
	mov a, xi
	inc a
	mov xi, a
	pop a
 .elif pminitp_addsub24 < 0
	sub x, -pminitp_addsub24
	jncb _skip
	push a
	mov a, xi
	dec a
	mov xi, a
	pop a
 .endif
_skip:
.endm

.macroicase ADD24Y pminitp_addsub24
 .if pminitp_addsub24 == 1
	inc y
	jnzb _skip
	push a
	mov a, yi
	inc a
	mov yi, a
	pop a
 .elif pminitp_addsub24 >= 65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 <= -65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 > 0
	add y, pminitp_addsub24
	jncb _skip
	push a
	mov a, yi
	inc a
	mov yi, a
	pop a
 .elif pminitp_addsub24 < 0
	sub y, -pminitp_addsub24
	jncb _skip
	push a
	mov a, yi
	dec a
	mov yi, a
	pop a
 .endif
_skip:
.endm

.macroicase ADD24HL pminitp_addsub24
 .if pminitp_addsub24 == 1
	inc hl
	jnzb _skip
	push a
	mov a, i
	inc a
	mov i, a
	pop a
 .elif pminitp_addsub24 >= 65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 <= -65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 > 0
	add hl, pminitp_addsub24
	jncb _skip
	push a
	mov a, i
	inc a
	mov i, a
	pop a
 .elif pminitp_addsub24 < 0
	sub y, -pminitp_addsub24
	jncb _skip
	push a
	mov a, i
	dec a
	mov i, a
	pop a
 .endif
_skip:
.endm

.macroicase ADD24X_A pminitp_addsub24
 .if pminitp_addsub24 == 1
	inc x
	jnzb _skip
	mov a, xi
	inc a
	mov xi, a
 .elif pminitp_addsub24 >= 65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 <= -65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 > 0
	add x, pminitp_addsub24
	jncb _skip
	mov a, xi
	inc a
	mov xi, a
 .elif pminitp_addsub24 < 0
	sub x, -pminitp_addsub24
	jncb _skip
	mov a, xi
	dec a
	mov xi, a
 .endif
_skip:
.endm

.macroicase ADD24Y_A pminitp_addsub24
 .if pminitp_addsub24 == 1
	inc y
	jnzb _skip
	mov a, yi
	inc a
	mov yi, a
 .elif pminitp_addsub24 >= 65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 <= -65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 > 0
	add y, pminitp_addsub24
	jncb _skip
	mov a, yi
	inc a
	mov yi, a
 .elif pminitp_addsub24 < 0
	sub y, -pminitp_addsub24
	jncb _skip
	mov a, yi
	dec a
	mov yi, a
 .endif
_skip:
.endm

.macroicase ADD24HL_A pminitp_addsub24
 .if pminitp_addsub24 == 1
	inc hl
	jnzb _skip
	mov a, i
	inc a
	mov i, a
 .elif pminitp_addsub24 >= 65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 <= -65536
  .error "Value is out-of-range, must be 16-bits"
 .elif pminitp_addsub24 > 0
	add hl, pminitp_addsub24
	jncb _skip
	mov a, i
	inc a
	mov i, a
 .elif pminitp_addsub24 < 0
	sub y, -pminitp_addsub24
	jncb _skip
	mov a, i
	dec a
	mov i, a
 .endif
_skip:
.endm
