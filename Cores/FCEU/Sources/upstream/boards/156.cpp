/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2009 CaH4e3
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

static uint8 chrlo[8], chrhi[8], prg, mirr, mirrisused = 0;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ &prg, 1, "PREG" },
	{ chrlo, 8, "CRGL" },
	{ chrhi, 8, "CRGH" },
	{ &mirr, 1, "MIRR" },
	{ 0 }
};

static void Sync(void) {
	uint32 i;
	for (i = 0; i < 8; i++)
		setchr1(i << 10, chrlo[i] | (chrhi[i] << 8));
	setprg8r(0x10, 0x6000, 0);
	setprg16(0x8000, prg);
	setprg16(0xC000, ~0);
	if (mirrisused)
		setmirror(mirr ^ 1);
	else
		setmirror(MI_0);
}

static DECLFW(M156Write) {
	switch (A) {
	case 0xC000:
	case 0xC001:
	case 0xC002:
	case 0xC003: chrlo[A & 3] = V; Sync(); break;
	case 0xC004:
	case 0xC005:
	case 0xC006:
	case 0xC007: chrhi[A & 3] = V; Sync(); break;
	case 0xC008:
	case 0xC009:
	case 0xC00A:
	case 0xC00B: chrlo[4 + (A & 3)] = V; Sync(); break;
	case 0xC00C:
	case 0xC00D:
	case 0xC00E:
	case 0xC00F: chrhi[4 + (A & 3)] = V; Sync(); break;
	case 0xC010: prg = V; Sync(); break;
	case 0xC014: mirr = V; mirrisused = 1; Sync(); break;
	}
}

static void M156Reset(void) {
	uint32 i;
	for (i = 0; i < 8; i++) {
		chrlo[i] = 0;
		chrhi[i] = 0;
	}
	prg = 0;
	mirr = 0;
	mirrisused = 0;
}

static void M156Power(void) {
	M156Reset();
	Sync();
	SetReadHandler(0x6000, 0xFFFF, CartBR);
	SetWriteHandler(0x6000, 0x7FFF, CartBW);
	SetWriteHandler(0xC000, 0xCFFF, M156Write);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void M156Close(void) {
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void Mapper156_Init(CartInfo *info) {
	info->Reset = M156Reset;
	info->Power = M156Power;
	info->Close = M156Close;

	WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");

	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
