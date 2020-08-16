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
 *
 * Many-in-one hacked mapper crap.
 *
 * Original BNROM is actually AxROM variations without mirroring control,
 * and haven't SRAM on-board, so it must be removed from here
 *
 * Difficult banking is what NINA board doing, most hacks for 34 mapper are
 * NINA hacks, so this is actually 34 mapper
 *
 */

#include "mapinc.h"

static uint8 regs[3];
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ regs, 3, "REGS" },
	{ 0 }
};

static void Sync(void) {
	setprg8r(0x10, 0x6000, 0);
	setprg32(0x8000, regs[0]);
	setchr4(0x0000, regs[1]);
	setchr4(0x1000, regs[2]);
}

static DECLFW(M34Write) {
	if (A >= 0x8000)
		regs[0] = V;
	else
		switch (A) {
		case 0x7ffd: regs[0] = V; break;
		case 0x7ffe: regs[1] = V; break;
		case 0x7fff: regs[2] = V; break;
		}
	Sync();
}

static void M34Power(void) {
	regs[0] = regs[1] = 0;
	regs[2] = 1;
	Sync();
	SetReadHandler(0x6000, 0x7ffc, CartBR);
	SetWriteHandler(0x6000, 0x7ffc, CartBW);
	SetReadHandler(0x8000, 0xffff, CartBR);
	SetWriteHandler(0x7ffd, 0xffff, M34Write);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void M34Close(void) {
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void Mapper34_Init(CartInfo *info) {
	info->Power = M34Power;
	info->Close = M34Close;
	GameStateRestore = StateRestore;

	WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");

	AddExState(&StateRegs, ~0, 0, 0);
}
