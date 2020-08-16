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

static uint8 latch;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;
static writefunc old4016;

static SFORMAT StateRegs[] =
{
	{ &latch, 1, "LATC" },
	{ 0 }
};

static void Sync(void) {
	setchr8((latch >> 2) & 1);
	setprg8r(0x10, 0x6000, 0);
	setprg32(0x8000, 0);
	setprg8(0x8000, latch & 4);        /* Special for VS Gumshoe */
}

static DECLFW(M99Write) {
	latch = V;
	Sync();
	old4016(A, V);
}

static void M99Power(void) {
	latch = 0;
	Sync();
	old4016 = GetWriteHandler(0x4016);
	SetWriteHandler(0x4016, 0x4016, M99Write);
	SetReadHandler(0x6000, 0xFFFF, CartBR);
	SetWriteHandler(0x6000, 0x7FFF, CartBW);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void M99Close(void)
{
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void Mapper99_Init(CartInfo *info) {
	info->Power = M99Power;
	info->Close = M99Close;

	WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");

	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
