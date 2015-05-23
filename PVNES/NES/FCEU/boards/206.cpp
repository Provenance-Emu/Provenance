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

static uint8 cmd;
static uint8 DRegs[8];

static SFORMAT StateRegs[] =
{
	{ &cmd, 1, "CMD" },
	{ DRegs, 8, "DREG" },
	{ 0 }
};

static void Sync(void) {
	setchr2(0x0000, DRegs[0]);
	setchr2(0x0800, DRegs[1]);
	int x;
	for (x = 0; x < 4; x++)
		setchr1(0x1000 + (x << 10), DRegs[2 + x]);
	setprg8(0x8000, DRegs[6]);
	setprg8(0xa000, DRegs[7]);
	setprg8(0xc000, ~1);
	setprg8(0xe000, ~0);
}

static void StateRestore(int version) {
	Sync();
}

static DECLFW(M206Write) {
	switch (A & 0x8001) {
	case 0x8000: cmd = V & 0x07; break;
	case 0x8001:
		if (cmd <= 0x05)
			V &= 0x3F;
		else
			V &= 0x0F;
		if (cmd <= 0x01) V >>= 1;
		DRegs[cmd & 0x07] = V;
		Sync();
		break;
	}
}

static void M206Power(void) {
	cmd = 0;
	DRegs[6] = 0;
	DRegs[7] = 1;
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M206Write);
}


void Mapper206_Init(CartInfo *info) {
	info->Power = M206Power;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
