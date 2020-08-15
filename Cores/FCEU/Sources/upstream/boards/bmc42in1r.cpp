/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005 CaH4e3
 *  Copyright (C) 2009 qeed
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
 * BMC 42-in-1 "reset switch" + "select switch"
 *
 */

#include "mapinc.h"

static uint8 isresetbased = 0;
static uint8 latche[2], reset;
static SFORMAT StateRegs[] =
{
	{ &reset, 1, "RST" },
	{ latche, 2, "LATC" },
	{ 0 }
};

static void Sync(void) {
	uint8 bank;
	if (isresetbased)
		bank = (latche[0] & 0x1f) | (reset << 5) | ((latche[1] & 1) << 6);
	else
		bank = (latche[0] & 0x1f) | ((latche[0] & 0x80) >> 2) | ((latche[1] & 1) << 6);
	if (!(latche[0] & 0x20))
		setprg32(0x8000, bank >> 1);
	else{
		setprg16(0x8000, bank);
		setprg16(0xC000, bank);
	}
	setmirror((latche[0] >> 6) & 1);
	setchr8(0);
}

static DECLFW(M226Write) {
	latche[A & 1] = V;
	Sync();
}

static void M226Power(void) {
	latche[0] = latche[1] = reset = 0;
	Sync();
	SetWriteHandler(0x8000, 0xFFFF, M226Write);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
}

static void StateRestore(int version) {
	Sync();
}

void Mapper226_Init(CartInfo *info) {
	isresetbased = 0;
	info->Power = M226Power;
	AddExState(&StateRegs, ~0, 0, 0);
	GameStateRestore = StateRestore;
}

static void M233Reset(void) {
	reset ^= 1;
	Sync();
}

void Mapper233_Init(CartInfo *info) {
	isresetbased = 1;
	info->Power = M226Power;
	info->Reset = M233Reset;
	AddExState(&StateRegs, ~0, 0, 0);
	GameStateRestore = StateRestore;
}
