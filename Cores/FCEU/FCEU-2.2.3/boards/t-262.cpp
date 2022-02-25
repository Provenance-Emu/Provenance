/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2006 CaH4e3
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

static uint8 bank, base, lock, mirr, mode;
static SFORMAT StateRegs[] =
{
	{ &bank, 1, "BANK" },
	{ &base, 1, "BASE" },
	{ &lock, 1, "LOCK" },
	{ &mirr, 1, "MIRR" },
	{ &mode, 1, "MODE" },
	{ 0 }
};

static void Sync(void) {
	setchr8(0);
	setprg16(0x8000, base | bank);
	setprg16(0xC000, base | (mode ? bank : 7));
	setmirror(mirr);
}

static DECLFW(BMCT262Write) {
	if (!lock) {
		base = ((A & 0x60) >> 2) | ((A & 0x100) >> 3);
		mode = A & 0x80;
		mirr = ((A & 2) >> 1) ^ 1;
		lock = (A & 0x2000) >> 13;
	}
	bank = V & 7;
	Sync();
}

static void BMCT262Power(void) {
	lock = bank = base = mode = 0;
	Sync();
	SetWriteHandler(0x8000, 0xFFFF, BMCT262Write);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
}

static void BMCT262Reset(void) {
	lock = bank = base = mode = 0;
	Sync();
}

static void BMCT262Restore(int version) {
	Sync();
}

void BMCT262_Init(CartInfo *info) {
	info->Power = BMCT262Power;
	info->Reset = BMCT262Reset;
	GameStateRestore = BMCT262Restore;
	AddExState(&StateRegs, ~0, 0, 0);
}
