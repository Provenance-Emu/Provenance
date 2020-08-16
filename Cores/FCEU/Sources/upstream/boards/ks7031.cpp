/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2012 CaH4e3
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
 * FDS Conversion
 *
 */

#include "mapinc.h"

static uint8 reg[4];

static SFORMAT StateRegs[] =
{
	{ reg, 4, "REGS" },
	{ 0 }
};

static void Sync(void) {
	setprg2(0x6000, reg[0]);
	setprg2(0x6800, reg[1]);
	setprg2(0x7000, reg[2]);
	setprg2(0x7800, reg[3]);

	setprg2(0x8000, 15);
	setprg2(0x8800, 14);
	setprg2(0x9000, 13);
	setprg2(0x9800, 12);
	setprg2(0xa000, 11);
	setprg2(0xa800, 10);
	setprg2(0xb000, 9);
	setprg2(0xb800, 8);

	setprg2(0xc000, 7);
	setprg2(0xc800, 6);
	setprg2(0xd000, 5);
	setprg2(0xd800, 4);
	setprg2(0xe000, 3);
	setprg2(0xe800, 2);
	setprg2(0xf000, 1);
	setprg2(0xf800, 0);

	setchr8(0);
}

static DECLFW(UNLKS7031Write) {
	reg[(A >> 11) & 3] = V;
	Sync();
}

static void UNLKS7031Power(void) {
	Sync();
	SetReadHandler(0x6000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xffff, UNLKS7031Write);
}

static void StateRestore(int version) {
	Sync();
}

void UNLKS7031_Init(CartInfo *info) {
	info->Power = UNLKS7031Power;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
