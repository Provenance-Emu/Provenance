/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
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
 * FDS Conversions
 *
 * Super Mario Bros 2j (Alt Full) is a BAD incomplete dump, should be mapper 43
 *
 * Both Voleyball and Zanac by Whirlind Manu shares the same PCB, but with
 * some differences: Voleyball has 8K CHR ROM and 8K ROM at 6000K, Zanac
 * have 8K CHR RAM and banked 16K ROM mapper at 6000 as two 8K banks.
*
 * Super Mario Bros 2j (Alt Small) uses additionally IRQ timer to drive framerate
 *
 * PCB for this mapper is "09-034A"
 */

#include "mapinc.h"

static uint8 prg;
static uint32 IRQCount, IRQa;

static SFORMAT StateRegs[] =
{
	{ &IRQCount, 4, "IRQC" },
	{ &IRQa, 4, "IRQA" },
	{ &prg, 1, "PRG" },
	{ 0 }
};

static void Sync(void) {
	setprg8r(1, 0x6000, prg);
	setprg32(0x8000, 0);
	setchr8(0);
}

static DECLFW(UNLSMB2JWrite1) {
	prg = V & 1;
	Sync();
}

static DECLFW(UNLSMB2JWrite2) {
	IRQa = V & 1;
	IRQCount = 0;
	X6502_IRQEnd(FCEU_IQEXT);
}

static DECLFR(UNLSMB2JRead) {
	return 0xFF;
}

static void UNLSMB2JPower(void) {
	prg = 0;
	Sync();
	SetReadHandler(0x6000, 0xFFFF, CartBR);
	SetReadHandler(0x4042, 0x4055, UNLSMB2JRead);
	SetWriteHandler(0x4068, 0x4068, UNLSMB2JWrite2);
	SetWriteHandler(0x4027, 0x4027, UNLSMB2JWrite1);
}

static void UNLSMB2JIRQHook(int a) {
	if (IRQa)
	{
		if (IRQCount < 5750)	// completely by guess
			IRQCount += a;
		else {
			IRQa = 0;
			X6502_IRQBegin(FCEU_IQEXT);
		}
	}
}

static void StateRestore(int version) {
	Sync();
}

void UNLSMB2J_Init(CartInfo *info) {
	info->Power = UNLSMB2JPower;
	MapIRQHook = UNLSMB2JIRQHook;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
