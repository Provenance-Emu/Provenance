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

static uint8 bank;
static uint16 mode;
static SFORMAT StateRegs[] =
{
	{ &bank, 1, "BANK" },
	{ &mode, 2, "MODE" },
	{ 0 }
};

static void Sync(void) {
	setchr8(((mode & 0x1F) << 2) | (bank & 0x03));
	if (mode & 0x20) {
		setprg16(0x8000, (mode & 0x40) | ((mode >> 8) & 0x3F));
		setprg16(0xc000, (mode & 0x40) | ((mode >> 8) & 0x3F));
	} else
		setprg32(0x8000, ((mode & 0x40) | ((mode >> 8) & 0x3F)) >> 1);
	setmirror(((mode >> 7) & 1) ^ 1);
}

static DECLFW(M62Write) {
	mode = A & 0x3FFF;
	bank = V & 3;
	Sync();
}

static void M62Power(void) {
	bank = mode = 0;
	Sync();
	SetWriteHandler(0x8000, 0xFFFF, M62Write);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
}

static void M62Reset(void) {
	bank = mode = 0;
	Sync();
}

static void StateRestore(int version) {
	Sync();
}

void Mapper62_Init(CartInfo *info) {
	info->Power = M62Power;
	info->Reset = M62Reset;
	AddExState(&StateRegs, ~0, 0, 0);
	GameStateRestore = StateRestore;
}
