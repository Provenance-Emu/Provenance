/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2015 CaH4e3
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
 * "Blood Of Jurassic" protected MMC3 based board (GD-98 Cart ID, 158B PCB ID)
 *
 */

#include "mapinc.h"
#include "mmc3.h"

static uint8 lut[8] = { 0x00, 0x00, 0x00, 0x01, 0x02, 0x04, 0x0F, 0x00 };

static void UNL158BPW(uint32 A, uint8 V) {
	if (EXPREGS[0] & 0x80) {
		uint32 bank = EXPREGS[0] & 7; 
		if(EXPREGS[0] & 0x20) { // 32Kb mode
			setprg32(0x8000, bank >> 1);
		} else {				// 16Kb mode
			setprg16(0x8000, bank);
			setprg16(0xC000, bank);
		}
	} else {
		setprg8(A, V & 0xF);
	}
}

static DECLFW(UNL158BProtWrite) {
	EXPREGS[A & 7] = V;
	switch(A & 7) {
	case 0:
		FixMMC3PRG(MMC3_cmd);
		break;
	case 7:
		FCEU_printf("UNK PROT WRITE\n");
		break;
	}

}

static DECLFR(UNL158BProtRead) {
	return X.DB | lut[A & 7];
}

static void UNL158BPower(void) {
	GenMMC3Power();
	SetWriteHandler(0x5000, 0x5FFF, UNL158BProtWrite);
	SetReadHandler(0x5000, 0x5FFF, UNL158BProtRead);
}

void UNL158B_Init(CartInfo *info) {
	GenMMC3_Init(info, 128, 128, 0, 0);
	pwrap = UNL158BPW;
	info->Power = UNL158BPower;
	AddExState(EXPREGS, 8, 0, "EXPR");
}
