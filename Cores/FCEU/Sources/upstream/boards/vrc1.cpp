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
 * VRC-1
 *
 */

#include "mapinc.h"

static uint8 preg[3], creg[2], mode;
static SFORMAT StateRegs[] =
{
	{ &mode, 1, "MODE" },
	{ creg, 2, "CREG" },
	{ preg, 3, "PREG" },
	{ 0 }
};

static void Sync(void) {
	setprg8(0x8000, preg[0]);
	setprg8(0xA000, preg[1]);
	setprg8(0xC000, preg[2]);
	setprg8(0xE000, ~0);
	setchr4(0x0000, creg[0] | ((mode & 2) << 3));
	setchr4(0x1000, creg[1] | ((mode & 4) << 2));
	setmirror((mode & 1) ^ 1);
}

static DECLFW(M75Write) {
	switch (A & 0xF000) {
	case 0x8000: preg[0] = V; Sync(); break;
	case 0x9000: mode = V; Sync(); break;
	case 0xA000: preg[1] = V; Sync(); break;
	case 0xC000: preg[2] = V; Sync(); break;
	case 0xE000: creg[0] = V & 0xF; Sync(); break;
	case 0xF000: creg[1] = V & 0xF; Sync(); break;
	}
}

static void M75Power(void) {
	Sync();
	SetWriteHandler(0x8000, 0xFFFF, M75Write);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
}

static void StateRestore(int version) {
	Sync();
}

void Mapper75_Init(CartInfo *info) {
	info->Power = M75Power;
	AddExState(&StateRegs, ~0, 0, 0);
	GameStateRestore = StateRestore;
}
