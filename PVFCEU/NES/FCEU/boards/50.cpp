/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2012 CaH4e3
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
 *
 * FDS Conversion
 *
 */

#include "mapinc.h"

static uint8 reg;
static uint32 IRQCount, IRQa;

static SFORMAT StateRegs[] =
{
	{ &IRQCount, 4, "IRQC" },
	{ &IRQa, 4, "IRQA" },
	{ &reg, 1, "REG" },
	{ 0 }
};

static void Sync(void) {
	setprg8(0x6000, 0xF);
	setprg8(0x8000, 0x8);
	setprg8(0xa000, 0x9);
	setprg8(0xc000, reg);
	setprg8(0xe000, 0xB);
	setchr8(0);
}

static DECLFW(M50Write) {
	switch (A & 0xD160) {
	case 0x4120: IRQa = V & 1; if (!IRQa) IRQCount = 0; X6502_IRQEnd(FCEU_IQEXT); break;
	case 0x4020: reg = ((V & 1) << 2) | ((V & 2) >> 1) | ((V & 4) >> 1) | (V & 8); Sync(); break;
	}
}

static void M50Power(void) {
	reg = 0;
	Sync();
	SetReadHandler(0x6000, 0xffff, CartBR);
	SetWriteHandler(0x4020, 0x5fff, M50Write);
}

static void M50Reset(void) {
}

static void M50IRQHook(int a) {
	if (IRQa) {
		if (IRQCount < 4096)
			IRQCount += a;
		else{
			IRQa = 0;
			X6502_IRQBegin(FCEU_IQEXT);
		}
	}
}

static void StateRestore(int version) {
	Sync();
}

void Mapper50_Init(CartInfo *info) {
	info->Reset = M50Reset;
	info->Power = M50Power;
	MapIRQHook = M50IRQHook;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
