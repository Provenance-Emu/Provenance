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

static uint8 creg[8], preg[2];
static int32 IRQa, IRQCount, IRQClock, IRQLatch;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;
static uint8 *CHRRAM = NULL;
static uint32 CHRRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ creg, 8, "CREG" },
	{ preg, 2, "PREG" },
	{ &IRQa, 4, "IRQA" },
	{ &IRQCount, 4, "IRQC" },
	{ &IRQLatch, 4, "IRQL" },
	{ &IRQClock, 4, "IRQK" },
	{ 0 }
};

static void Sync(void) {
	uint8 i;
	setprg8r(0x10, 0x6000, 0);
	setprg8(0x8000, preg[0]);
	setprg8(0xa000, preg[1]);
	setprg8(0xc000, ~1);
	setprg8(0xe000, ~0);
	for (i = 0; i < 8; i++)
		if ((creg[i] == 6) || (creg[i] == 7))
			setchr1r(0x10, i << 10, creg[i] & 1);
		else
			setchr1(i << 10, creg[i]);
}

static DECLFW(M252Write) {
	if ((A >= 0xB000) && (A <= 0xEFFF)) {
		uint8 ind = ((((A & 8) | (A >> 8)) >> 3) + 2) & 7;
		uint8 sar = A & 4;
		creg[ind] = (creg[ind] & (0xF0 >> sar)) | ((V & 0x0F) << sar);
		Sync();
	} else
		switch (A & 0xF00C) {
		case 0x8000:
		case 0x8004:
		case 0x8008:
		case 0x800C: preg[0] = V; Sync(); break;
		case 0xA000:
		case 0xA004:
		case 0xA008:
		case 0xA00C: preg[1] = V; Sync(); break;
		case 0xF000: X6502_IRQEnd(FCEU_IQEXT); IRQLatch &= 0xF0; IRQLatch |= V & 0xF; break;
		case 0xF004: X6502_IRQEnd(FCEU_IQEXT); IRQLatch &= 0x0F; IRQLatch |= V << 4; break;
		case 0xF008: X6502_IRQEnd(FCEU_IQEXT); IRQClock = 0; IRQCount = IRQLatch; IRQa = V & 2; break;
		}
}

static void M252Power(void) {
	Sync();
	SetReadHandler(0x6000, 0x7FFF, CartBR);
	SetWriteHandler(0x6000, 0x7FFF, CartBW);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M252Write);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void M252IRQ(int a) {
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

static void M252Close(void) {
	if (WRAM)
		FCEU_gfree(WRAM);
	if (CHRRAM)
		FCEU_gfree(CHRRAM);
	WRAM = CHRRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void Mapper252_Init(CartInfo *info) {
	info->Power = M252Power;
	info->Close = M252Close;
	MapIRQHook = M252IRQ;

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
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
