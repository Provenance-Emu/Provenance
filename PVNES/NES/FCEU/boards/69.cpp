/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2012 CaH4e3
 *  Copyright (C) 2002 Xodnizel
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

static uint8 cmdreg, preg[4], creg[8], mirr;
static uint8 IRQa;
static int32 IRQCount;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ &cmdreg, 1, "CMDR" },
	{ preg, 4, "PREG" },
	{ creg, 8, "CREG" },
	{ &mirr, 1, "MIRR" },
	{ &IRQa, 1, "IRQA" },
	{ &IRQCount, 4, "IRQC" },
	{ 0 }
};

static void Sync(void) {
	uint8 i;
	if ((preg[3] & 0xC0) == 0xC0)
		setprg8r(0x10, 0x6000, preg[3] & 0x3F);
	else
		setprg8(0x6000, preg[3] & 0x3F);
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

static DECLFW(M69WRAMWrite) {
	if ((preg[3] & 0xC0) == 0xC0)
		CartBW(A, V);
}

static DECLFR(M69WRAMRead) {
	if ((preg[3] & 0xC0) == 0x40)
		return X.DB;
	else
		return CartBR(A);
}

static DECLFW(M69Write0) {
	cmdreg = V & 0xF;
}

static DECLFW(M69Write1) {
	switch (cmdreg) {
	case 0x0: creg[0] = V; Sync(); break;
	case 0x1: creg[1] = V; Sync(); break;
	case 0x2: creg[2] = V; Sync(); break;
	case 0x3: creg[3] = V; Sync(); break;
	case 0x4: creg[4] = V; Sync(); break;
	case 0x5: creg[5] = V; Sync(); break;
	case 0x6: creg[6] = V; Sync(); break;
	case 0x7: creg[7] = V; Sync(); break;
	case 0x8: preg[3] = V; Sync(); break;
	case 0x9: preg[0] = V; Sync(); break;
	case 0xA: preg[1] = V; Sync(); break;
	case 0xB: preg[2] = V; Sync(); break;
	case 0xC: mirr = V & 3; Sync();break;
	case 0xD: IRQa = V; X6502_IRQEnd(FCEU_IQEXT); break;
	case 0xE: IRQCount &= 0xFF00; IRQCount |= V; break;
	case 0xF: IRQCount &= 0x00FF; IRQCount |= V << 8; break;
	}
}

// SUNSOFT-5/FME-7 Sound

static void AYSound(int Count);
static void AYSoundHQ(void);
static void DoAYSQ(int x);
static void DoAYSQHQ(int x);

static uint8 sndcmd, sreg[14];
static int32 vcount[3];
static int32 dcount[3];
static int CAYBC[3];

static SFORMAT SStateRegs[] =
{
	{ &sndcmd, 1, "SCMD" },
	{ sreg, 14, "SREG" },
	{ 0 }
};

static DECLFW(M69SWrite0) {
	sndcmd = V % 14;
}

static DECLFW(M69SWrite1) {
	int x;
	GameExpSound.Fill = AYSound;
	GameExpSound.HiFill = AYSoundHQ;
	if (FSettings.SndRate)
		switch (sndcmd) {
		case 0:
		case 1:
		case 8: if (FSettings.soundq >= 1) DoAYSQHQ(0); else DoAYSQ(0); break;
		case 2:
		case 3:
		case 9: if (FSettings.soundq >= 1) DoAYSQHQ(1); else DoAYSQ(1); break;
		case 4:
		case 5:
		case 10: if (FSettings.soundq >= 1) DoAYSQHQ(2); else DoAYSQ(2); break;
		case 7:
			for (x = 0; x < 2; x++)
				if (FSettings.soundq >= 1) DoAYSQHQ(x); else DoAYSQ(x);
			break;
		}
	sreg[sndcmd] = V;
}

static void DoAYSQ(int x) {
	int32 freq = ((sreg[x << 1] | ((sreg[(x << 1) + 1] & 15) << 8)) + 1) << (4 + 17);
	int32 amp = (sreg[0x8 + x] & 15) << 2;
	int32 start, end;
	int V;

	amp += amp >> 1;

	start = CAYBC[x];
	end = (SOUNDTS << 16) / soundtsinc;
	if (end <= start) return;
	CAYBC[x] = end;

	if (amp && !(sreg[0x7] & (1 << x)))
		for (V = start; V < end; V++) {
			if (dcount[x])
				Wave[V >> 4] += amp;
			vcount[x] -= nesincsize;
			while (vcount[x] <= 0) {
				dcount[x] ^= 1;
				vcount[x] += freq;
			}
		}
}

static void DoAYSQHQ(int x) {
	uint32 V;
	int32 freq = ((sreg[x << 1] | ((sreg[(x << 1) + 1] & 15) << 8)) + 1) << 4;
	int32 amp = (sreg[0x8 + x] & 15) << 6;

	amp += amp >> 1;

	if (!(sreg[0x7] & (1 << x))) {
		for (V = CAYBC[x]; V < SOUNDTS; V++) {
			if (dcount[x])
				WaveHi[V] += amp;
			vcount[x]--;
			if (vcount[x] <= 0) {
				dcount[x] ^= 1;
				vcount[x] = freq;
			}
		}
	}
	CAYBC[x] = SOUNDTS;
}

static void AYSound(int Count) {
	int x;
	DoAYSQ(0);
	DoAYSQ(1);
	DoAYSQ(2);
	for (x = 0; x < 3; x++)
		CAYBC[x] = Count;
}

static void AYSoundHQ(void) {
	DoAYSQHQ(0);
	DoAYSQHQ(1);
	DoAYSQHQ(2);
}

static void AYHiSync(int32 ts) {
	int x;

	for (x = 0; x < 3; x++)
		CAYBC[x] = ts;
}

void Mapper69_ESI(void) {
	GameExpSound.RChange = Mapper69_ESI;
	GameExpSound.HiSync = AYHiSync;
	memset(dcount, 0, sizeof(dcount));
	memset(vcount, 0, sizeof(vcount));
	memset(CAYBC, 0, sizeof(CAYBC));
	AddExState(&SStateRegs, ~0, 0, 0);
}

// SUNSOFT-5/FME-7 Sound

static void M69Power(void) {
	cmdreg = sndcmd = 0;
	IRQCount = 0xFFFF;
	IRQa = 0;
	Sync();
	SetReadHandler(0x6000, 0x7FFF, M69WRAMRead);
	SetWriteHandler(0x6000, 0x7FFF, M69WRAMWrite);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0x9FFF, M69Write0);
	SetWriteHandler(0xA000, 0xBFFF, M69Write1);
	SetWriteHandler(0xC000, 0xDFFF, M69SWrite0);
	SetWriteHandler(0xE000, 0xFFFF, M69SWrite1);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void M69Close(void) {
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void M69IRQHook(int a) {
	if (IRQa) {
		IRQCount -= a;
		if (IRQCount <= 0) {
			X6502_IRQBegin(FCEU_IQEXT); IRQa = 0; IRQCount = 0xFFFF;
		}
	}
}

static void StateRestore(int version) {
	Sync();
}

void Mapper69_Init(CartInfo *info) {
	info->Power = M69Power;
	info->Close = M69Close;
	MapIRQHook = M69IRQHook;
	if(info->ines2)
		WRAMSIZE = info->wram_size + info->battery_wram_size;
	else
		WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");
	if (info->battery) {
		info->SaveGame[0] = WRAM;
		info->SaveGameLen[0] = WRAMSIZE;
	}
	GameStateRestore = StateRestore;
	Mapper69_ESI();
	AddExState(&StateRegs, ~0, 0, 0);
}

void NSFAY_Init(void) {
	sndcmd = 0;
	SetWriteHandler(0xC000, 0xDFFF, M69SWrite0);
	SetWriteHandler(0xE000, 0xFFFF, M69SWrite1);
	Mapper69_ESI();
}
