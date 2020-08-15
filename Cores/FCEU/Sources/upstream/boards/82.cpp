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
 * Taito X1-017 board, battery backed
 *
 */

#include "mapinc.h"

static uint8 regs[9], ctrl;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ regs, 9, "REGS" },
	{ &ctrl, 1, "CTRL" },
	{ 0 }
};

static void Sync(void) {
	uint32 swap = ((ctrl & 2) << 11);
	setchr2(0x0000 ^ swap, regs[0] >> 1);
	setchr2(0x0800 ^ swap, regs[1] >> 1);
	setchr1(0x1000 ^ swap, regs[2]);
	setchr1(0x1400 ^ swap, regs[3]);
	setchr1(0x1800 ^ swap, regs[4]);
	setchr1(0x1c00 ^ swap, regs[5]);
	setprg8r(0x10, 0x6000, 0);
	setprg8(0x8000, regs[6]);
	setprg8(0xA000, regs[7]);
	setprg8(0xC000, regs[8]);
	setprg8(0xE000, ~0);
	setmirror(ctrl & 1);
}

static DECLFW(M82Write) {
	if (A <= 0x7ef5)
		regs[A & 7] = V;
	else
		switch (A) {
		case 0x7ef6: ctrl = V & 3; break;
		case 0x7efa: regs[6] = V >> 2; break;
		case 0x7efb: regs[7] = V >> 2; break;
		case 0x7efc: regs[8] = V >> 2; break;
		}
	Sync();
}

static void M82Power(void) {
	Sync();
	SetReadHandler(0x6000, 0xffff, CartBR);
	SetWriteHandler(0x6000, 0x7fff, CartBW);
	SetWriteHandler(0x7ef0, 0x7efc, M82Write);  // external WRAM might end at $73FF
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void M82Close(void) {
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void Mapper82_Init(CartInfo *info) {
	info->Power = M82Power;
	info->Close = M82Close;

	WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");
	if (info->battery) {
		info->SaveGame[0] = WRAM;
		info->SaveGameLen[0] = WRAMSIZE;
	}
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
