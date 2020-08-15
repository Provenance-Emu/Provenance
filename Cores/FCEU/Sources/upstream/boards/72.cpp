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
 * Moero!! Pro Tennis have ADPCM codec on-board, PROM isn't dumped, emulation isn't
 * possible just now.
 */

#include "mapinc.h"

static uint8 preg, creg;

static SFORMAT StateRegs[] =
{
	{ &preg, 1, "PREG" },
	{ &creg, 1, "CREG" },
	{ 0 }
};

static void Sync(void) {
	setprg16(0x8000, preg);
	setprg16(0xC000, ~0);
	setchr8(creg);
}

static DECLFW(M72Write) {
	if (V & 0x80)
		preg = V & 0xF;
	if (V & 0x40)
		creg = V & 0xF;
	Sync();
}

static void M72Power(void) {
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x6000, 0xFFFF, M72Write);
}

static void StateRestore(int version) {
	Sync();
}

void Mapper72_Init(CartInfo *info) {
	info->Power = M72Power;
	GameStateRestore = StateRestore;

	AddExState(&StateRegs, ~0, 0, 0);
}
