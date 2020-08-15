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
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ regs, 8, "REGS" },
	{ 0 }
};

static void Sync(void) {
	setprg2r(0x10, 0x6800, 0);
	setprg8(0x8000, regs[0]);
	setprg8(0xA000, regs[1]);
	setprg8(0xC000, regs[2]);
	setprg8(0xE000, regs[3]);
	setchr2(0x0000, regs[4]);
	setchr2(0x0800, regs[5]);
	setchr2(0x1000, regs[6]);
	setchr2(0x1800, regs[7]);
}

static DECLFW(M246Write) {
	regs[A & 7] = V;
	Sync();
}

static void M246Power(void) {
	regs[0] = regs[1] = regs[2] = regs[3] = ~0;
	Sync();
	SetWriteHandler(0x6000, 0x67FF, M246Write);
	SetReadHandler(0x6800, 0x6FFF, CartBR);
	SetWriteHandler(0x6800, 0x6FFF, CartBW);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void M246Close(void)
{
	if(WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void Mapper246_Init(CartInfo *info) {
	info->Power = M246Power;
	info->Close = M246Close;
	GameStateRestore = StateRestore;

	WRAMSIZE = 2048;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");

	if (info->battery) {
		info->SaveGame[0] = WRAM;
		info->SaveGameLen[0] = WRAMSIZE;
	}

	AddExState(&StateRegs, ~0, 0, 0);
}
