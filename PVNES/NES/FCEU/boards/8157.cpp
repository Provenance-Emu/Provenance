/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005 CaH4e3
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
 * GG1 boards, similar to T-262, with no Data latch
 *
 */

#include "mapinc.h"

static uint16 cmdreg;
static uint8 reset;
static SFORMAT StateRegs[] =
{
	{ &reset, 1, "REST" },
	{ &cmdreg, 2, "CREG" },
	{ 0 }
};

static void Sync(void) {
	uint32 base = ((cmdreg & 0x060) | ((cmdreg & 0x100) >> 1)) >> 2;
	uint32 bank = (cmdreg & 0x01C) >> 2;
	uint32 lbank = (cmdreg & 0x200) ? 7 : ((cmdreg & 0x80) ? bank : 0);
	if (PRGptr[1]) {
		setprg16r(base >> 3, 0x8000, bank);        // for versions with split ROMs
		setprg16r(base >> 3, 0xC000, lbank);
	} else {
		setprg16(0x8000, base | bank);
		setprg16(0xC000, base | lbank);
	}
	setmirror(((cmdreg & 2) >> 1) ^ 1);
}

static DECLFR(UNL8157Read) {
	if ((cmdreg & 0x100) && (PRGsize[0] < (1024 * 1024))) {
		A = (A & 0xFFF0) + reset;
	}
	return CartBR(A);
}

static DECLFW(UNL8157Write) {
	cmdreg = A;
	Sync();
}

static void UNL8157Power(void) {
	setchr8(0);
	SetWriteHandler(0x8000, 0xFFFF, UNL8157Write);
	SetReadHandler(0x8000, 0xFFFF, UNL8157Read);
	cmdreg = reset = 0;
	Sync();
}

static void UNL8157Reset(void) {
	cmdreg = reset = 0;
	reset++;
	reset &= 0x1F;
	Sync();
}

static void UNL8157Restore(int version) {
	Sync();
}

void UNL8157_Init(CartInfo *info) {
	info->Power = UNL8157Power;
	info->Reset = UNL8157Reset;
	GameStateRestore = UNL8157Restore;
	AddExState(&StateRegs, ~0, 0, 0);
}
