/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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

static uint8 cmd0, cmd1;
static SFORMAT StateRegs[] =
{
	{ &cmd0, 1, "L1" },
	{ &cmd1, 1, "L2" },
	{ 0 }
};

static void Sync(void) {
	setchr8(0);
	if (PRGptr[1])
		setprg8r((cmd0 & 0xC) >> 2, 0x6000, ((cmd0 & 0x3) << 4) | 0xF);
	else
		setprg8(0x6000, (((cmd0 & 0xF) << 4) | 0xF) + 4);
	if (cmd0 & 0x10) {
		if (PRGptr[1]) {
			setprg16r((cmd0 & 0xC) >> 2, 0x8000, ((cmd0 & 0x3) << 3) | (cmd1 & 7));
			setprg16r((cmd0 & 0xC) >> 2, 0xc000, ((cmd0 & 0x3) << 3) | 7);
		} else {
			setprg16(0x8000, (((cmd0 & 0xF) << 3) | (cmd1 & 7)) + 2);
			setprg16(0xc000, (((cmd0 & 0xF) << 3) | 7) + 2);
		}
	} else
		if (PRGptr[4])
			setprg32r(4, 0x8000, 0);
		else
			setprg32(0x8000, 0);
	setmirror(((cmd0 & 0x20) >> 5) ^ 1);
}

static DECLFW(SuperWriteLo) {
	if (!(cmd0 & 0x10)) {
		cmd0 = V;
		Sync();
	}
}

static DECLFW(SuperWriteHi) {
	cmd1 = V;
	Sync();
}

static void SuperPower(void) {
	SetWriteHandler(0x6000, 0x7FFF, SuperWriteLo);
	SetWriteHandler(0x8000, 0xFFFF, SuperWriteHi);
	SetReadHandler(0x6000, 0xFFFF, CartBR);
	cmd0 = cmd1 = 0;
	Sync();
}

static void SuperReset(void) {
	cmd0 = cmd1 = 0;
	Sync();
}

static void SuperRestore(int version) {
	Sync();
}

void Supervision16_Init(CartInfo *info) {
	info->Power = SuperPower;
	info->Reset = SuperReset;
	GameStateRestore = SuperRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
