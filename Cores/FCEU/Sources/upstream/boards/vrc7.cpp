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

static uint8 vrc7idx, preg[3], creg[8], mirr;
static uint8 IRQLatch, IRQa, IRQd;
static int32 IRQCount, CycleCount;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

#include "emu2413.h"

static int32 dwave = 0;
static OPLL *VRC7Sound = NULL;
static OPLL **VRC7Sound_saveptr = &VRC7Sound;

static SFORMAT StateRegs[] =
{
	{ &vrc7idx, 1, "VRCI" },
	{ preg, 3, "PREG" },
	{ creg, 8, "CREG" },
	{ &mirr, 1, "MIRR" },
	{ &IRQa, 1, "IRQA" },
	{ &IRQd, 1, "IRQD" },
	{ &IRQLatch, 1, "IRQL" },
	{ &IRQCount, 4, "IRQC" },
	{ &CycleCount, 4, "CYCC" },
	{ (void**)VRC7Sound_saveptr, sizeof(*VRC7Sound) | FCEUSTATE_INDIRECT, "VRC7"  },
	{0}
};

// VRC7 Sound

void DoVRC7Sound(void) {
	int32 z, a;
	if (FSettings.soundq >= 1)
		return;
	z = ((SOUNDTS << 16) / soundtsinc) >> 4;
	a = z - dwave;
	OPLL_fillbuf(VRC7Sound, &Wave[dwave], a, 1);
	dwave += a;
}

void UpdateOPLNEO(int32 *Wave, int Count) {
	OPLL_fillbuf(VRC7Sound, Wave, Count, 4);
}

void UpdateOPL(int Count) {
	int32 z, a;
	z = ((SOUNDTS << 16) / soundtsinc) >> 4;
	a = z - dwave;
	if (VRC7Sound && a)
		OPLL_fillbuf(VRC7Sound, &Wave[dwave], a, 1);
	dwave = 0;
}

static void VRC7SC(void) {
	if (VRC7Sound)
		OPLL_set_rate(VRC7Sound, FSettings.SndRate);
}

static void VRC7SKill(void) {
	if (VRC7Sound)
		OPLL_delete(VRC7Sound);
	VRC7Sound = NULL;
}

static void VRC7_ESI(void) {
	GameExpSound.RChange = VRC7SC;
	GameExpSound.Kill = VRC7SKill;
	VRC7Sound = OPLL_new(3579545, FSettings.SndRate ? FSettings.SndRate : 44100);
	OPLL_reset(VRC7Sound);
	OPLL_reset(VRC7Sound);
}

// VRC7 Sound

static void Sync(void) {
	uint8 i;
	setprg8r(0x10, 0x6000, 0);
	setprg8(0x8000, preg[0]);
	setprg8(0xA000, preg[1]);
	setprg8(0xC000, preg[2]);
	setprg8(0xE000, ~0);
	for (i = 0; i < 8; i++)
		setchr1(i << 10, creg[i]);
	switch (mirr & 3) {
	case 0: setmirror(MI_V); break;
	case 1: setmirror(MI_H); break;
	case 2: setmirror(MI_0); break;
	case 3: setmirror(MI_1); break;
	}
}

static DECLFW(VRC7SW) {
	if (FSettings.SndRate) {
		OPLL_writeReg(VRC7Sound, vrc7idx, V);
		GameExpSound.Fill = UpdateOPL;
		GameExpSound.NeoFill = UpdateOPLNEO;
	}
}

static DECLFW(VRC7Write) {
	A |= (A & 8) << 1;  // another two-in-oooone
	if (A >= 0xA000 && A <= 0xDFFF) {
		A &= 0xF010;
		creg[((A >> 4) & 1) | ((A - 0xA000) >> 11)] = V;
		Sync();
	} else if (A == 0x9030) {
		VRC7SW(A, V);
	} else switch (A & 0xF010) {
		case 0x8000: preg[0] = V; Sync(); break;
		case 0x8010: preg[1] = V; Sync(); break;
		case 0x9000: preg[2] = V; Sync(); break;
		case 0x9010: vrc7idx = V; break;
		case 0xE000: mirr = V & 3; Sync(); break;
		case 0xE010: IRQLatch = V; X6502_IRQEnd(FCEU_IQEXT); break;
		case 0xF000:
			IRQa = V & 2;
			IRQd = V & 1;
			if (V & 2)
				IRQCount = IRQLatch;
			CycleCount = 0;
			X6502_IRQEnd(FCEU_IQEXT);
			break;
		case 0xF010:
			IRQa = IRQd;
			X6502_IRQEnd(FCEU_IQEXT);
			break;
		}
}

static void VRC7Power(void) {
	Sync();
	SetWriteHandler(0x6000, 0x7FFF, CartBW);
	SetReadHandler(0x6000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, VRC7Write);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void VRC7Close(void)
{
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void VRC7IRQHook(int a) {
	if (IRQa) {
		CycleCount += a * 3;
		while(CycleCount >= 341) {
			CycleCount -= 341;
			IRQCount++;
			if (IRQCount == 0x100) {
				IRQCount = IRQLatch;
				X6502_IRQBegin(FCEU_IQEXT);
			}
		}
	}
}

static void StateRestore(int version) {
	Sync();
}

void Mapper85_Init(CartInfo *info) {
	info->Power = VRC7Power;
	info->Close = VRC7Close;
	MapIRQHook = VRC7IRQHook;
	WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");
	if (info->battery) {
		info->SaveGame[0] = WRAM;
		info->SaveGameLen[0] = WRAMSIZE;
	}
	GameStateRestore = StateRestore;
	VRC7_ESI();
	AddExState(&StateRegs, ~0, 0, 0);
}

void NSFVRC7_Init(void) {
	SetWriteHandler(0x9010, 0x901F, VRC7Write);
	SetWriteHandler(0x9030, 0x903F, VRC7Write);
	VRC7_ESI();
}
