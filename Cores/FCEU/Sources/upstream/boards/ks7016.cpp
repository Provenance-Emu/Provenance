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
 * FDS Conversion (Exciting Basket), weird banking addressing, seems because
 * of used addressing scheme, made to disable the lower system banks from 6000
 * but the kaiser mapper chip and PCB are the same as usual
 * probably need a hard eprom dump to verify actual banks layout
 *
 */

#include "mapinc.h"

static uint8 preg;

static SFORMAT StateRegs[] =
{
	{ &preg, 1, "PREG" },
	{ 0 }
};

static void Sync(void) {
	setprg8(0x6000, preg);
	setprg8(0x8000, 0xC);
	setprg8(0xA000, 0xD);
	setprg8(0xC000, 0xE);
	setprg8(0xE000, 0xF);
	setchr8(0);
}

static DECLFW(UNLKS7016Write) {
	u16 mask = (A & 0x30);
	switch(A & 0xD943) {
	case 0xD943: {	
		if(mask == 0x30) {
			preg = 8 | 3;				// or A, or no bus (all FF)
		} else {
			preg = (A >> 2) & 0xF;		// can be anything but C-F
		}
		Sync();
		break;
	}
	case 0xD903: {						// this case isn't usedby the game, but addressing does this as a side effect
		if(mask == 0x30) {
			preg = 8 | ((A >> 2) & 3);	// also masked C-F from output
		} else {
			preg = 8 | 3;
		}
		Sync();
		break;
	}
	}
}

static void UNLKS7016Power(void) {
	preg = 8;
	Sync();
	SetReadHandler(0x6000, 0xffff, CartBR);
	SetWriteHandler(0x8000, 0xffff, UNLKS7016Write);
}

static void StateRestore(int version) {
	Sync();
}

void UNLKS7016_Init(CartInfo *info) {
	info->Power = UNLKS7016Power;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
