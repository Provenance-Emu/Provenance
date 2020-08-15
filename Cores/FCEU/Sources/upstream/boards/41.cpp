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
 */

#include "mapinc.h"

static uint8 mainreg, chrreg, mirror;

static SFORMAT StateRegs[] =
{
	{ &mainreg, 1, "MREG" },
	{ &chrreg, 1, "CREG" },
	{ &mirror, 1, "MIRR" },
	{ 0 }
};

static void Sync(void) {
	setprg32(0x8000, mainreg & 7);
	setchr8(chrreg);
	setmirror(mirror);
}

static DECLFW(M41Write0) {
	mainreg = A & 0xFF;
	mirror = ((A >> 5) & 1) ^ 1;
	chrreg = (chrreg & 3) | ((A >> 1) & 0xC);
	Sync();
}

static DECLFW(M41Write1) {
	if (mainreg & 0x4) {
		chrreg = (chrreg & 0xC) | (A & 3);
		Sync();
	}
}

static void M41Power(void) {
	mainreg = chrreg = 0;
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x6000, 0x67FF, M41Write0);
	SetWriteHandler(0x8000, 0xFFFF, M41Write1);
}

static void StateRestore(int version) {
	Sync();
}

void Mapper41_Init(CartInfo *info) {
	info->Power = M41Power;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
