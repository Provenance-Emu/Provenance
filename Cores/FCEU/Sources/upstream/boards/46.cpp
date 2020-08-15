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

static uint8 reg0, reg1;

static SFORMAT StateRegs[] =
{
	{ &reg0, 1, "REG0" },
	{ &reg1, 1, "REG1" },
	{ 0 }
};

static void Sync(void) {
	setprg32(0x8000, (reg1 & 1) + ((reg0 & 0xF) << 1));
	setchr8(((reg1 >> 4) & 7) + ((reg0 & 0xF0) >> 1));
}

static DECLFW(M46Write0) {
	reg0 = V;
	Sync();
}

static DECLFW(M46Write1) {
	reg1 = V;
	Sync();
}

static void M46Power(void) {
	reg0 = reg1 = 0;
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x6000, 0x7FFF, M46Write0);
	SetWriteHandler(0x8000, 0xFFFF, M46Write1);
}

static void M46Reset(void) {
	reg0 = reg1 = 0;
	Sync();
}

static void StateRestore(int version) {
	Sync();
}

void Mapper46_Init(CartInfo *info) {
	info->Power = M46Power;
	info->Reset = M46Reset;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
