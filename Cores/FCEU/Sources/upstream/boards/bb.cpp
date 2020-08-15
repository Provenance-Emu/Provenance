/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
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
 */

#include "mapinc.h"

static uint8 reg, chr;

static SFORMAT StateRegs[] =
{
	{ &reg, 1, "REG" },
	{ &chr, 1, "CHR" },
	{ 0 }
};

static void Sync(void) {
	setprg8(0x6000, reg & 3);
	setprg32(0x8000, ~0);
	setchr8(chr & 3);
}

static DECLFW(UNLBBWrite) {
	if ((A & 0x9000) == 0x8000)
		reg = chr = V;
	else
		chr = V & 1;  // hacky hacky, ProWres simplified FDS conversion 2-in-1 mapper
	Sync();
}

static void UNLBBPower(void) {
	chr = 0;
	reg = ~0;
	Sync();
	SetReadHandler(0x6000, 0x7FFF, CartBR);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, UNLBBWrite);
}

static void StateRestore(int version) {
	Sync();
}

void UNLBB_Init(CartInfo *info) {
	info->Power = UNLBBPower;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
