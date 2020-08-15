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

static uint8 bank, mode;
static SFORMAT StateRegs[] =
{
	{ &bank, 1, "BANK" },
	{ &mode, 1, "MODE" },
	{ 0 }
};

static void Sync(void) {
	if (mode & 2) {
		setprg8(0x6000, ((bank & 7) << 2) | 0x23);
		setprg16(0x8000, (bank << 1) | 0);
		setprg16(0xC000, (bank << 1) | 1);
	} else {
		setprg8(0x6000, ((bank & 4) << 2) | 0x2F);
		setprg16(0x8000, (bank << 1) | (mode >> 4));
		setprg16(0xC000, ((bank & 0xC) << 1) | 7);
	}
	if (mode == 0x12)
		setmirror(MI_H);
	else
		setmirror(MI_V);
	setchr8(0);
}

static DECLFW(M51WriteMode) {
	mode = V & 0x12;
	Sync();
}

static DECLFW(M51WriteBank) {
	bank = V & 0x0F;
	if (A & 0x4000)
		mode = (mode & 2) | (V & 0x10);
	Sync();
}

static void M51Power(void) {
	bank = 0;
	mode = 2;
	Sync();
	SetWriteHandler(0x6000, 0x7FFF, M51WriteMode);
	SetWriteHandler(0x8000, 0xFFFF, M51WriteBank);
	SetReadHandler(0x6000, 0xFFFF, CartBR);
}

static void M51Reset(void) {
	bank = 0;
	mode = 2;
	Sync();
}

static void StateRestore(int version) {
	Sync();
}

void Mapper51_Init(CartInfo *info) {
	info->Power = M51Power;
	info->Reset = M51Reset;
	AddExState(&StateRegs, ~0, 0, 0);
	GameStateRestore = StateRestore;
}
