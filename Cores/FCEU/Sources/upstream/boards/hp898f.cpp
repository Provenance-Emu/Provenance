/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2015 CaH4e3
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

static uint8 regs[2];

static SFORMAT StateRegs[] =
{
	{ regs, 2, "REGS" },
	{ 0 }
};

static void Sync(void) {
	uint8 chr = (regs[0] >> 4) & 7;
	uint8 prg = (regs[1] >> 3) & 7;
	uint8 dec = (regs[1] >> 4) & 4;
	setchr8(chr & (~(((regs[0] & 1) << 2) | (regs[0] & 2))));
	setprg16(0x8000,prg & (~dec));
	setprg16(0xC000,prg | dec);
	setmirror(regs[1] >> 7);
}

static DECLFW(HP898FWrite) {
	if((A & 0x6000) == 0x6000) {
		regs[(A & 4) >> 2] = V;
		Sync();
	}
}

static void HP898FPower(void) {
	regs[0] = regs[1] = 0;
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x6000, 0xFFFF, HP898FWrite);
}

static void HP898FReset(void) {
	regs[0] = regs[1] = 0;
	Sync();
}

static void StateRestore(int version) {
	Sync();
}

void BMCHP898F_Init(CartInfo *info) {
	info->Reset = HP898FReset;
	info->Power = HP898FPower;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
