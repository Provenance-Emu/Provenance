/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2016 CaH4e3
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * 8-in-1  Rockin' Kats, Snake, (PCB marked as "8 in 1"), similar to 12IN1,
 * but with MMC3 on board, all games are hacked the same, Snake is buggy too!
 *
 * no reset-citcuit, so selected game can be reset, but to change it you must use power
 *
 */

#include "mapinc.h"
#include "mmc3.h"

static void BMC8IN1CW(uint32 A, uint8 V) {
	setchr1(A, ((EXPREGS[0] & 0xC) << 5) | (V & 0x7F));
}

static void BMC8IN1PW(uint32 A, uint8 V) {
	if(EXPREGS[0] & 0x10) {		// MMC3 mode
		setprg8(A, ((EXPREGS[0] & 0xC) << 2) | (V & 0xF));
	} else {
		setprg32(0x8000, EXPREGS[0] & 0xF);
	}
}

static DECLFW(BMC8IN1Write) {
	if(A & 0x1000) {
		EXPREGS[0] = V;
		FixMMC3PRG(MMC3_cmd);
		FixMMC3CHR(MMC3_cmd);
	} else {
		if(A < 0xC000)
			MMC3_CMDWrite(A, V);
		else
			MMC3_IRQWrite(A, V);
	}
}

static void BMC8IN1Power(void) {
	EXPREGS[0] = 0;
	GenMMC3Power();
	SetWriteHandler(0x8000, 0xFFFF, BMC8IN1Write);
}

void BMC8IN1_Init(CartInfo *info) {
	GenMMC3_Init(info, 128, 128, 0, 0);
	cwrap = BMC8IN1CW;
	pwrap = BMC8IN1PW;
	info->Power = BMC8IN1Power;
	AddExState(EXPREGS, 1, 0, "EXPR");
}
