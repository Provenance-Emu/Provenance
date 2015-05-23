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

static uint8 regs[8];

static SFORMAT StateRegs[] =
{
	{ regs, 8, "REGS" },
	{ 0 }
};

static void Sync(void) {
	setprg8(0x8000, regs[0]);
	setprg8(0xA000, regs[2]);
	setprg8(0xC000, regs[4]);
	setprg8(0xE000, ~0);
	setchr4(0x0000, regs[6]);
	setchr4(0x1000, regs[7]);
}

static DECLFW(M151Write) {
	regs[(A >> 12) & 7] = V;
	Sync();
}

static void M151Power(void) {
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M151Write);
}

static void StateRestore(int version) {
	Sync();
}

void Mapper151_Init(CartInfo *info) {
	info->Power = M151Power;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
