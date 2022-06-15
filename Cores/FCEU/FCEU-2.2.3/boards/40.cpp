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
	setprg8(0x6000, ~1);
	setprg8(0x8000, ~3);
	setprg8(0xa000, ~2);
	setprg8(0xc000, reg);
	setprg8(0xe000, ~0);
	setchr8(0);
}

static DECLFW(M40Write) {
	switch (A & 0xe000) {
	case 0x8000: IRQa = 0; IRQCount = 0; X6502_IRQEnd(FCEU_IQEXT); break;
	case 0xa000: IRQa = 1; break;
	case 0xe000: reg = V & 7; Sync(); break;
	}
}

static void M40Power(void) {
	reg = 0;
	Sync();
	SetReadHandler(0x6000, 0xffff, CartBR);
	SetWriteHandler(0x8000, 0xffff, M40Write);
}

static void M40Reset(void) {
}

static void M40IRQHook(int a) {
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

void Mapper40_Init(CartInfo *info) {
	info->Reset = M40Reset;
	info->Power = M40Power;
	MapIRQHook = M40IRQHook;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
