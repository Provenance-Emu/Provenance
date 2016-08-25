/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2009 CaH4e3
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

static uint8 reg;
static uint8 *CHRRAM = NULL;
static uint32 CHRRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ &reg, 1, "REGS" },
	{ 0 }
};

static void Sync(void) {
	setchr4r(0x10, 0x0000, 0);
	setchr4r(0x10, 0x1000, reg & 0x0f);
	setprg16(0x8000, reg >> 6);
	setprg16(0xc000, ~0);
}

static DECLFW(M168Write) {
	reg = V;
	Sync();
}

static DECLFW(M168Dummy) {
}

static void M168Power(void) {
	reg = 0;
	Sync();
	SetWriteHandler(0x4020, 0x7fff, M168Dummy);
	SetWriteHandler(0xB000, 0xB000, M168Write);
	SetWriteHandler(0xF000, 0xF000, M168Dummy);
	SetWriteHandler(0xF080, 0xF080, M168Dummy);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
}

static void M168Close(void) {
	if (CHRRAM)
		FCEU_gfree(CHRRAM);
	CHRRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void Mapper168_Init(CartInfo *info) {
	info->Power = M168Power;
	info->Close = M168Close;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);

	CHRRAMSIZE = 8192 * 8;
	CHRRAM = (uint8*)FCEU_gmalloc(CHRRAMSIZE);
	SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSIZE, 1);
	AddExState(CHRRAM, CHRRAMSIZE, 0, "CRAM");
}
