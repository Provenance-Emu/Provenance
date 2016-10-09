/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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
	for (int i=0; i < 8; ++i)
	{
		setprg4(0x8000 + (0x1000 * i), regs[i]);
	}
}

static DECLFW(M31Write) {
	if (A >= 0x5000 && A <= 0x5FFF)
	{
		regs[A&7] = V;
		Sync();
	}
}

static void M31Power(void) {
	setchr8(0);
	regs[7] = 0xFF;
	Sync();
	SetReadHandler(0x8000, 0xffff, CartBR);
	SetWriteHandler(0x5000, 0x5fff, M31Write);
}

static void StateRestore(int version) {
	Sync();
}

void Mapper31_Init(CartInfo *info) {
	info->Power = M31Power;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
