/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2006 CaH4e3
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
 * YOKO mapper, almost the same as 83, TODO: figure out difference
 * Mapper 83 - 30-in-1 mapper, two modes for single game carts, one mode for
 * multigame Dragon Ball Z Party
 *
 * Mortal Kombat 2 YOKO
 * N-CXX(M), XX -  PRG+CHR, 12 - 128+256, 22 - 256+256, 14 - 128+512
 *
 */

#include "mapinc.h"

static uint8 mode, bank, reg[11], low[4], dip, IRQa;
static int32 IRQCount;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static uint8 is2kbank, isnot2kbank;

static SFORMAT StateRegs[] =
{
	{ &mode, 1, "MODE" },
	{ &bank, 1, "BANK" },
	{ &IRQCount, 4, "IRQC" },
	{ &IRQa, 1, "IRQA" },
	{ reg, 11, "REGS" },
	{ low, 4, "LOWR" },
	{ &is2kbank, 1, "IS2K" },
	{ &isnot2kbank, 1, "NT2K" },
	{ 0 }
};

static void UNLYOKOSync(void) {
	setmirror((mode & 1) ^ 1);
	setchr2(0x0000, reg[3]);
	setchr2(0x0800, reg[4]);
	setchr2(0x1000, reg[5]);
	setchr2(0x1800, reg[6]);
	if (mode & 0x10) {
		uint32 base = (bank & 8) << 1;
		setprg8(0x8000, (reg[0] & 0x0f) | base);
		setprg8(0xA000, (reg[1] & 0x0f) | base);
		setprg8(0xC000, (reg[2] & 0x0f) | base);
		setprg8(0xE000, 0x0f | base);
	} else {
		if (mode & 8)
			setprg32(0x8000, bank >> 1);
		else{
			setprg16(0x8000, bank);
			setprg16(0xC000, ~0);
		}
	}
}

static void M83Sync(void) {
	switch (mode & 3) { // check if it is truth
	case 0: setmirror(MI_V); break;
	case 1: setmirror(MI_H); break;
	case 2: setmirror(MI_0); break;
	case 3: setmirror(MI_1); break;
	}
	if (is2kbank && !isnot2kbank) {
		setchr2(0x0000, reg[0]);
		setchr2(0x0800, reg[1]);
		setchr2(0x1000, reg[6]);
		setchr2(0x1800, reg[7]);
	} else {
		int x;
		for (x = 0; x < 8; x++)
			setchr1(x << 10, reg[x] | ((bank & 0x30) << 4));
	}
	setprg8r(0x10, 0x6000, 0);
	if (mode & 0x40) {
		setprg16(0x8000, (bank & 0x3F));      // DBZ Party [p1]
		setprg16(0xC000, (bank & 0x30) | 0xF);
	} else {
		setprg8(0x8000, reg[8]);
		setprg8(0xA000, reg[9]);
		setprg8(0xC000, reg[10]);
		setprg8(0xE000, ~0);
	}
}

static DECLFW(UNLYOKOWrite) {
	switch (A & 0x8C17) {
	case 0x8000: bank = V; UNLYOKOSync(); break;
	case 0x8400: mode = V; UNLYOKOSync(); break;
	case 0x8800: IRQCount &= 0xFF00; IRQCount |= V; X6502_IRQEnd(FCEU_IQEXT); break;
	case 0x8801: IRQa = mode & 0x80; IRQCount &= 0xFF; IRQCount |= V << 8; break;
	case 0x8c00: reg[0] = V; UNLYOKOSync(); break;
	case 0x8c01: reg[1] = V; UNLYOKOSync(); break;
	case 0x8c02: reg[2] = V; UNLYOKOSync(); break;
	case 0x8c10: reg[3] = V; UNLYOKOSync(); break;
	case 0x8c11: reg[4] = V; UNLYOKOSync(); break;
	case 0x8c16: reg[5] = V; UNLYOKOSync(); break;
	case 0x8c17: reg[6] = V; UNLYOKOSync(); break;
	}
}

static DECLFW(M83Write) {
	switch (A) {
	case 0x8000: is2kbank = 1;
	case 0xB000:                                              // Dragon Ball Z Party [p1] BMC
	case 0xB0FF:                                              // Dragon Ball Z Party [p1] BMC
	case 0xB1FF: bank = V; mode |= 0x40; M83Sync(); break;    // Dragon Ball Z Party [p1] BMC
	case 0x8100: mode = V | (mode & 0x40); M83Sync(); break;
	case 0x8200: IRQCount &= 0xFF00; IRQCount |= V; X6502_IRQEnd(FCEU_IQEXT); break;
	case 0x8201: IRQa = mode & 0x80; IRQCount &= 0xFF; IRQCount |= V << 8; break;
	case 0x8300: reg[8] = V; mode &= 0xBF; M83Sync(); break;
	case 0x8301: reg[9] = V; mode &= 0xBF; M83Sync(); break;
	case 0x8302: reg[10] = V; mode &= 0xBF; M83Sync(); break;
	case 0x8310: reg[0] = V; M83Sync(); break;
	case 0x8311: reg[1] = V; M83Sync(); break;
	case 0x8312: reg[2] = V; isnot2kbank = 1; M83Sync(); break;
	case 0x8313: reg[3] = V; isnot2kbank = 1; M83Sync(); break;
	case 0x8314: reg[4] = V; isnot2kbank = 1; M83Sync(); break;
	case 0x8315: reg[5] = V; isnot2kbank = 1; M83Sync(); break;
	case 0x8316: reg[6] = V; M83Sync(); break;
	case 0x8317: reg[7] = V; M83Sync(); break;
	}
}

static DECLFR(UNLYOKOReadDip) {
	return (X.DB & 0xFC) | dip;
}

static DECLFR(UNLYOKOReadLow) {
	return low[A & 3];
}

static DECLFW(UNLYOKOWriteLow) {
	low[A & 3] = V;
}

static void UNLYOKOPower(void) {
	mode = bank = 0;
	dip = 3;
	UNLYOKOSync();
	SetReadHandler(0x5000, 0x53FF, UNLYOKOReadDip);
	SetReadHandler(0x5400, 0x5FFF, UNLYOKOReadLow);
	SetWriteHandler(0x5400, 0x5FFF, UNLYOKOWriteLow);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, UNLYOKOWrite);
}

static void M83Power(void) {
	is2kbank = 0;
	isnot2kbank = 0;
	mode = bank = 0;
	dip = 0;
	M83Sync();
	SetReadHandler(0x5000, 0x5000, UNLYOKOReadDip);
	SetReadHandler(0x5100, 0x5103, UNLYOKOReadLow);
	SetWriteHandler(0x5100, 0x5103, UNLYOKOWriteLow);
	SetReadHandler(0x6000, 0x7fff, CartBR);
	SetWriteHandler(0x6000, 0x7fff, CartBW); // Pirate Dragon Ball Z Party [p1] used if for saves instead of seraial EEPROM
	SetReadHandler(0x8000, 0xffff, CartBR);
	SetWriteHandler(0x8000, 0xffff, M83Write);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void UNLYOKOReset(void) {
	dip = (dip + 1) & 3;
	mode = bank = 0;
	UNLYOKOSync();
}

static void M83Reset(void) {
	dip ^= 1;
	M83Sync();
}

static void M83Close(void) {
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void UNLYOKOIRQHook(int a) {
	if (IRQa) {
		IRQCount -= a;
		if (IRQCount < 0) {
			X6502_IRQBegin(FCEU_IQEXT);
			IRQa = 0;
			IRQCount = 0xFFFF;
		}
	}
}

static void UNLYOKOStateRestore(int version) {
	UNLYOKOSync();
}

static void M83StateRestore(int version) {
	M83Sync();
}

void UNLYOKO_Init(CartInfo *info) {
	info->Power = UNLYOKOPower;
	info->Reset = UNLYOKOReset;
	MapIRQHook = UNLYOKOIRQHook;
	GameStateRestore = UNLYOKOStateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}

void Mapper83_Init(CartInfo *info) {
	info->Power = M83Power;
	info->Reset = M83Reset;
	info->Close = M83Close;
	MapIRQHook = UNLYOKOIRQHook;
	GameStateRestore = M83StateRestore;

	WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");

	AddExState(&StateRegs, ~0, 0, 0);
}
