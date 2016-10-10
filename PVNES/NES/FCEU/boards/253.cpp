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

static uint8 chrlo[8], chrhi[8], prg[2], mirr, vlock;
static int32 IRQa, IRQCount, IRQLatch, IRQClock;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;
static uint8 *CHRRAM = NULL;
static uint32 CHRRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ chrlo, 8, "CHRL" },
	{ chrhi, 8, "CHRH" },
	{ prg, 2, "PRGR" },
	{ &mirr, 1, "MIRR" },
	{ &vlock, 1, "VLCK" },
	{ &IRQa, 4, "IRQA" },
	{ &IRQCount, 4, "IRQC" },
	{ &IRQLatch, 4, "IRQL" },
	{ &IRQClock, 4, "IRQK" },
	{ 0 }
};

static void Sync(void) {
	uint8 i;
	setprg8r(0x10, 0x6000, 0);
	setprg8(0x8000, prg[0]);
	setprg8(0xa000, prg[1]);
	setprg8(0xc000, ~1);
	setprg8(0xe000, ~0);
	for (i = 0; i < 8; i++) {
		uint32 chr = chrlo[i] | (chrhi[i] << 8);
		if (((chrlo[i] == 4) || (chrlo[i] == 5)) && !vlock)
			setchr1r(0x10, i << 10, chr & 1);
		else
			setchr1(i << 10, chr);
	}
	switch (mirr) {
	case 0: setmirror(MI_V); break;
	case 1: setmirror(MI_H); break;
	case 2: setmirror(MI_0); break;
	case 3: setmirror(MI_1); break;
	}
}

static DECLFW(M253Write) {
	if ((A >= 0xB000) && (A <= 0xE00C)) {
		uint8 ind = ((((A & 8) | (A >> 8)) >> 3) + 2) & 7;
		uint8 sar = A & 4;
		uint8 clo = (chrlo[ind] & (0xF0 >> sar)) | ((V & 0x0F) << sar);
		chrlo[ind] = clo;
		if (ind == 0) {
			if (clo == 0xc8)
				vlock = 0;
			else if (clo == 0x88)
				vlock = 1;
		}
		if (sar)
			chrhi[ind] = V >> 4;
		Sync();
	} else
		switch (A) {
		case 0x8010: prg[0] = V; Sync(); break;
		case 0xA010: prg[1] = V; Sync(); break;
		case 0x9400: mirr = V & 3; Sync(); break;
		case 0xF000: X6502_IRQEnd(FCEU_IQEXT); IRQLatch &= 0xF0; IRQLatch |= V & 0xF; break;
		case 0xF004: X6502_IRQEnd(FCEU_IQEXT); IRQLatch &= 0x0F; IRQLatch |= V << 4; break;
		case 0xF008: X6502_IRQEnd(FCEU_IQEXT); IRQClock = 0; IRQCount = IRQLatch; IRQa = V & 2; break;
		}
}

static void M253Power(void) {
	vlock = 0;
	Sync();
	SetReadHandler(0x6000, 0x7FFF, CartBR);
	SetWriteHandler(0x6000, 0x7FFF, CartBW);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M253Write);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void M253Close(void) {
	if (WRAM)
		FCEU_gfree(WRAM);
	if (CHRRAM)
		FCEU_gfree(CHRRAM);
	WRAM = CHRRAM = NULL;
}

static void M253IRQ(int a) {
	#define LCYCS 341
	if (IRQa) {
		IRQClock += a * 3;
		if (IRQClock >= LCYCS) {
			while (IRQClock >= LCYCS) {
				IRQClock -= LCYCS;
				IRQCount++;
				if (IRQCount & 0x100) {
					X6502_IRQBegin(FCEU_IQEXT);
					IRQCount = IRQLatch;
				}
			}
		}
	}
}

static void StateRestore(int version) {
	Sync();
}

void Mapper253_Init(CartInfo *info) {
	info->Power = M253Power;
	info->Close = M253Close;
	MapIRQHook = M253IRQ;
	GameStateRestore = StateRestore;

	CHRRAMSIZE = 2048;
	CHRRAM = (uint8*)FCEU_gmalloc(CHRRAMSIZE);
	SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSIZE, 1);
	AddExState(CHRRAM, CHRRAMSIZE, 0, "CRAM");

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
