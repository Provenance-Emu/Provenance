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
 * FFE Copier Mappers
 *
 */

#include "mapinc.h"

static uint8 preg[4], creg[8], latch, ffemode;
static uint8 IRQa, mirr;
static int32 IRQCount, IRQLatch;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ preg, 4, "PREG" },
	{ creg, 8, "CREG" },
	{ &mirr, 1, "MIRR" },
	{ &IRQa, 1, "IRQA" },
	{ &IRQCount, 4, "IRQC" },
	{ &IRQLatch, 4, "IRQL" },
	{ 0 }
};

static void Sync(void) {
	setprg8r(0x10, 0x6000, 0);
	if (ffemode) {
		int i;
		for (i = 0; i < 8; i++) setchr1(i << 10, creg[i]);
		setprg8(0x8000, preg[0]);
		setprg8(0xA000, preg[1]);
		setprg8(0xC000, preg[2]);
		setprg8(0xE000, preg[3]);
	} else {
		setchr8(latch & 3);
		setprg16(0x8000, (latch >> 2) & 0x3F);
		setprg16(0xc000, 0x7);
	}
	switch (mirr) {
	case 0: setmirror(MI_0); break;
	case 1: setmirror(MI_1); break;
	case 2: setmirror(MI_V); break;
	case 3: setmirror(MI_H); break;
	}
}

static DECLFW(FFEWriteMirr) {
	mirr = ((A << 1) & 2) | ((V >> 4) & 1);
	Sync();
}

static DECLFW(FFEWriteIRQ) {
	switch (A) {
	case 0x4501: IRQa = 0; X6502_IRQEnd(FCEU_IQEXT); break;
	case 0x4502: IRQCount &= 0xFF00; IRQCount |= V; X6502_IRQEnd(FCEU_IQEXT); break;
	case 0x4503: IRQCount &= 0x00FF; IRQCount |= V << 8; IRQa = 1; X6502_IRQEnd(FCEU_IQEXT); break;
	}
}

static DECLFW(FFEWritePrg) {
	preg[A & 3] = V;
	Sync();
}

static DECLFW(FFEWriteChr) {
	creg[A & 7] = V;
	Sync();
}

static DECLFW(FFEWriteLatch) {
	latch = V;
	Sync();
}

static void FFEPower(void) {
	preg[3] = ~0;
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x42FE, 0x42FF, FFEWriteMirr);
	SetWriteHandler(0x4500, 0x4503, FFEWriteIRQ);
	SetWriteHandler(0x4504, 0x4507, FFEWritePrg);
	SetWriteHandler(0x4510, 0x4517, FFEWriteChr);
	SetWriteHandler(0x4510, 0x4517, FFEWriteChr);
	SetWriteHandler(0x6000, 0x7FFF, CartBW);
	SetReadHandler(0x6000, 0x7FFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, FFEWriteLatch);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void FFEIRQHook(int a) {
	if (IRQa) {
		IRQCount += a;
		if (IRQCount >= 0x10000) {
			X6502_IRQBegin(FCEU_IQEXT);
			IRQa = 0;
			IRQCount = 0;
		}
	}
}

static void FFEClose(void)
{
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void Mapper6_Init(CartInfo *info) {
	ffemode = 0;
	mirr = ((info->mirror & 1) ^ 1) | 2;

	info->Power = FFEPower;
	info->Close = FFEClose;
	MapIRQHook = FFEIRQHook;
	GameStateRestore = StateRestore;

	WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");
	if (info->battery) {
		info->SaveGame[0] = WRAM;
		info->SaveGameLen[0] = WRAMSIZE;
	}

	AddExState(&StateRegs, ~0, 0, 0);
}

void Mapper17_Init(CartInfo *info) {
	ffemode = 1;
	Mapper6_Init(info);
}
