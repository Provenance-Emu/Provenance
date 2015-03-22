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
 *
 * FDS Conversion
 *
 * Logical bank layot 32 K BANK 0, 64K BANK 1, 32K ~0 hardwired, 8K is missing
 * need redump from MASKROM!
 * probably need refix mapper after hard dump
 *
 */

#include "mapinc.h"

static uint8 reg0, reg1;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ &reg0, 1, "REG0" },
	{ &reg1, 1, "REG1" },
	{ 0 }
};

static void Sync(void) {
	setchr8(0);
	setprg32(0x8000, ~0);
	setprg4(0xb800, reg0);
	setprg4(0xc800, 8 + reg1);
}

// 6000 - 6BFF - RAM
// 6C00 - 6FFF - BANK 1K REG1
// 7000 - 7FFF - BANK 4K REG0

static DECLFW(UNLKS7030RamWrite0) {
	if ((A >= 0x6000) && A <= 0x6BFF) {
		WRAM[A - 0x6000] = V;
	} else if ((A >= 0x6C00) && A <= 0x6FFF) {
		CartBW(0xC800 + (A - 0x6C00), V);
	} else if ((A >= 0x7000) && A <= 0x7FFF) {
		CartBW(0xB800 + (A - 0x7000), V);
	}
}

static DECLFR(UNLKS7030RamRead0) {
	if ((A >= 0x6000) && A <= 0x6BFF) {
		return WRAM[A - 0x6000];
	} else if ((A >= 0x6C00) && A <= 0x6FFF) {
		return CartBR(0xC800 + (A - 0x6C00));
	} else if ((A >= 0x7000) && A <= 0x7FFF) {
		return CartBR(0xB800 + (A - 0x7000));
	}
	return 0;
}

// B800 - BFFF - RAM
// C000 - CBFF - BANK 3K
// CC00 - D7FF - RAM

static DECLFW(UNLKS7030RamWrite1) {
	if ((A >= 0xB800) && A <= 0xBFFF) {
		WRAM[0x0C00 + (A - 0xB800)] = V;
	} else if ((A >= 0xC000) && A <= 0xCBFF) {
		CartBW(0xCC00 + (A - 0xC000), V);
	} else if ((A >= 0xCC00) && A <= 0xD7FF) {
		WRAM[0x1400 + (A - 0xCC00)] = V;
	}
}

static DECLFR(UNLKS7030RamRead1) {
	if ((A >= 0xB800) && A <= 0xBFFF) {
		return WRAM[0x0C00 + (A - 0xB800)];
	} else if ((A >= 0xC000) && A <= 0xCBFF) {
		return CartBR(0xCC00 + (A - 0xC000));
	} else if ((A >= 0xCC00) && A <= 0xD7FF) {
		return WRAM[0x1400 + (A - 0xCC00)];
	}
	return 0;
}

static DECLFW(UNLKS7030Write0) {
	reg0 = A & 7;
	Sync();
}

static DECLFW(UNLKS7030Write1) {
	reg1 = A & 15;
	Sync();
}

static void UNLKS7030Power(void) {
	reg0 = reg1 = ~0;
	Sync();
	SetReadHandler(0x6000, 0x7FFF, UNLKS7030RamRead0);
	SetWriteHandler(0x6000, 0x7FFF, UNLKS7030RamWrite0);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0x8FFF, UNLKS7030Write0);
	SetWriteHandler(0x9000, 0x9FFF, UNLKS7030Write1);
	SetReadHandler(0xB800, 0xD7FF, UNLKS7030RamRead1);
	SetWriteHandler(0xB800, 0xD7FF, UNLKS7030RamWrite1);
}

static void UNLKS7030Close(void) {
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void UNLKS7030_Init(CartInfo *info) {
	info->Power = UNLKS7030Power;
	info->Close = UNLKS7030Close;
	GameStateRestore = StateRestore;

	WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");

	AddExState(&StateRegs, ~0, 0, 0);
}
