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
 */

#include "mapinc.h"

static uint8 preg[3], creg[6], isExMirr;
static uint8 mirr, cmd, wram_enable, wram[256];
static uint8 mcache[8];
static uint32 lastppu;

static SFORMAT StateRegs80[] =
{
	{ preg, 3, "PREG" },
	{ creg, 6, "CREG" },
	{ wram, 256, "WRAM" },
	{ &mirr, 1, "MIRR" },
	{ &wram_enable, 1, "WRME" },
	{ 0 }
};

static SFORMAT StateRegs95[] =
{
	{ &cmd, 1, "CMDR" },
	{ preg, 3, "PREG" },
	{ creg, 6, "CREG" },
	{ mcache, 8, "MCCH" },
	{ &lastppu, 4, "LPPU" },
	{ 0 }
};

static SFORMAT StateRegs207[] =
{
	{ preg, 3, "PREG" },
	{ creg, 6, "CREG" },
	{ mcache, 8, "MCCH" },
	{ &lastppu, 4, "LPPU" },
	{ 0 }
};

static void Sync(void) {
	setprg8(0x8000, preg[0]);
	setprg8(0xA000, preg[1]);
	setprg8(0xC000, preg[2]);
	setprg8(0xE000, ~0);
	setchr2(0x0000, (creg[0] >> 1) & 0x3F);
	setchr2(0x0800, (creg[1] >> 1) & 0x3F);
	setchr1(0x1000, creg[2]);
	setchr1(0x1400, creg[3]);
	setchr1(0x1800, creg[4]);
	setchr1(0x1C00, creg[5]);
	if (isExMirr) {
		setmirror(MI_0 + mcache[lastppu]);
	} else
		setmirror(mirr);
}

static DECLFW(M80RamWrite) {
	if(wram_enable == 0xA3)
		wram[A & 0xFF] = V;
}

static DECLFR(M80RamRead) {
	if(wram_enable == 0xA3)
		return wram[A & 0xFF];
	else
		return 0xFF;
}

static DECLFW(M80Write) {
	switch (A) {
	case 0x7EF0: creg[0] = V; mcache[0] = mcache[1] = V >> 7; Sync(); break;
	case 0x7EF1: creg[1] = V; mcache[2] = mcache[3] = V >> 7; Sync(); break;
	case 0x7EF2: creg[2] = V; mcache[4] = V >> 7; Sync(); break;
	case 0x7EF3: creg[3] = V; mcache[5] = V >> 7; Sync(); break;
	case 0x7EF4: creg[4] = V; mcache[6] = V >> 7; Sync(); break;
	case 0x7EF5: creg[5] = V; mcache[7] = V >> 7; Sync(); break;
	case 0x7EF6: mirr = V & 1; Sync(); break;
	case 0x7EF8: wram_enable = V; break;
	case 0x7EFA:
	case 0x7EFB: preg[0] = V; Sync(); break;
	case 0x7EFC:
	case 0x7EFD: preg[1] = V; Sync(); break;
	case 0x7EFE:
	case 0x7EFF: preg[2] = V; Sync(); break;
	}
}

static DECLFW(M95Write) {
	switch (A & 0xF001) {
	case 0x8000: cmd = V; break;
	case 0x8001:
		switch (cmd & 0x07) {
		case 0: creg[0] = V & 0x1F; mcache[0] = mcache[1] = (V >> 5) & 1; Sync(); break;
		case 1: creg[1] = V & 0x1F; mcache[2] = mcache[3] = (V >> 5) & 1; Sync(); break;
		case 2: creg[2] = V & 0x1F; mcache[4] = (V >> 5) & 1; Sync(); break;
		case 3: creg[3] = V & 0x1F; mcache[5] = (V >> 5) & 1; Sync(); break;
		case 4: creg[4] = V & 0x1F; mcache[6] = (V >> 5) & 1; Sync(); break;
		case 5: creg[5] = V & 0x1F; mcache[7] = (V >> 5) & 1; Sync(); break;
		case 6: preg[0] = V; Sync(); break;
		case 7: preg[1] = V; Sync(); break;
		}
		Sync();
	}
}

static void MExMirrPPU(uint32 A) {
	static int8 lastmirr = -1, curmirr;
	if (A < 0x2000) {
		lastppu = A >> 10;
		curmirr = mcache[lastppu];
		if (curmirr != lastmirr) {
			setmirror(MI_0 + curmirr);
			lastmirr = curmirr;
		}
	}
}

static void M80Power(void) {
	wram_enable = 0xFF;
	Sync();
	SetReadHandler(0x7F00, 0x7FFF, M80RamRead);
	SetWriteHandler(0x7F00, 0x7FFF, M80RamWrite);
	SetWriteHandler(0x7EF0, 0x7EFF, M80Write);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
}

static void M207Power(void) {
	mcache[0] = mcache[1] = mcache[2] = mcache[3] = 0;
	mcache[4] = mcache[5] = mcache[6] = mcache[7] = 0;
	Sync();
	SetWriteHandler(0x7EF0, 0x7EFF, M80Write);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
}

static void M95Power(void) {
	preg[2] = ~1;
	mcache[0] = mcache[1] = mcache[2] = mcache[3] = 0;
	mcache[4] = mcache[5] = mcache[6] = mcache[7] = 0;
	Sync();
	SetWriteHandler(0x8000, 0xFFFF, M95Write);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
}

static void StateRestore(int version) {
	Sync();
}

void Mapper80_Init(CartInfo *info) {
	isExMirr = 0;
	info->Power = M80Power;
	GameStateRestore = StateRestore;

	if (info->battery) {
		info->SaveGame[0] = wram;
		info->SaveGameLen[0] = 256;
	}

	AddExState(&StateRegs80, ~0, 0, 0);
}

void Mapper95_Init(CartInfo *info) {
	isExMirr = 1;
	info->Power = M95Power;
	PPU_hook = MExMirrPPU;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs95, ~0, 0, 0);
}

void Mapper207_Init(CartInfo *info) {
	isExMirr = 1;
	info->Power = M207Power;
	PPU_hook = MExMirrPPU;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs207, ~0, 0, 0);
}
