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
 *
 * VRC-6
 *
 */

#include "mapinc.h"

static uint8 is26;
static uint8 prg[2], chr[8], mirr;
static uint8 IRQLatch, IRQa, IRQd;
static int32 IRQCount, CycleCount;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ prg, 2, "PRG" },
	{ chr, 8, "CHR" },
	{ &mirr, 1, "MIRR" },
	{ &IRQa, 1, "IRQA" },
	{ &IRQd, 1, "IRQD" },
	{ &IRQLatch, 1, "IRQL" },
	{ &IRQCount, 4, "IRQC" },
	{ &CycleCount, 4, "CYCC" },
	{ 0 }
};

static void(*sfun[3]) (void);
static uint8 vpsg1[8];
static uint8 vpsg2[4];
static int32 cvbc[3];
static int32 vcount[3];
static int32 dcount[2];

static SFORMAT SStateRegs[] =
{
	{ vpsg1, 8, "PSG1" },
	{ vpsg2, 4, "PSG2" },
	{ 0 }
};

static void Sync(void) {
	uint8 i;
	if (is26)
		setprg8r(0x10, 0x6000, 0);
	setprg16(0x8000, prg[0]);
	setprg8(0xc000, prg[1]);
	setprg8(0xe000, ~0);
	for (i = 0; i < 8; i++)
		setchr1(i << 10, chr[i]);
	switch (mirr & 3) {
	case 0: setmirror(MI_V); break;
	case 1: setmirror(MI_H); break;
	case 2: setmirror(MI_0); break;
	case 3: setmirror(MI_1); break;
	}
}

static DECLFW(VRC6SW) {
	A &= 0xF003;
	if (A >= 0x9000 && A <= 0x9002) {
		vpsg1[A & 3] = V;
		if (sfun[0]) sfun[0]();
	} else if (A >= 0xA000 && A <= 0xA002) {
		vpsg1[4 | (A & 3)] = V;
		if (sfun[1]) sfun[1]();
	} else if (A >= 0xB000 && A <= 0xB002) {
		vpsg2[A & 3] = V;
		if (sfun[2]) sfun[2]();
	}
}

static DECLFW(VRC6Write) {
	if (is26)
		A = (A & 0xFFFC) | ((A >> 1) & 1) | ((A << 1) & 2);
	if (A >= 0x9000 && A <= 0xB002) {
		VRC6SW(A, V);
		return;
	}
	switch (A & 0xF003) {
	case 0x8000: prg[0] = V; Sync(); break;
	case 0xB003: mirr = (V >> 2) & 3; Sync(); break;
	case 0xC000: prg[1] = V; Sync(); break;
	case 0xD000: chr[0] = V; Sync(); break;
	case 0xD001: chr[1] = V; Sync(); break;
	case 0xD002: chr[2] = V; Sync(); break;
	case 0xD003: chr[3] = V; Sync(); break;
	case 0xE000: chr[4] = V; Sync(); break;
	case 0xE001: chr[5] = V; Sync(); break;
	case 0xE002: chr[6] = V; Sync(); break;
	case 0xE003: chr[7] = V; Sync(); break;
	case 0xF000: IRQLatch = V; X6502_IRQEnd(FCEU_IQEXT); break;
	case 0xF001:
		IRQa = V & 2;
		IRQd = V & 1;
		if (V & 2)
			IRQCount = IRQLatch;
		CycleCount = 0;
		X6502_IRQEnd(FCEU_IQEXT);
		break;
	case 0xF002:
		IRQa = IRQd;
		X6502_IRQEnd(FCEU_IQEXT);
	}
}

static void VRC6Power(void) {
	Sync();
	SetReadHandler(0x6000, 0xFFFF, CartBR);
	SetWriteHandler(0x6000, 0x7FFF, CartBW);
	SetWriteHandler(0x8000, 0xFFFF, VRC6Write);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void VRC6IRQHook(int a) {
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

static void VRC6Close(void)
{
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

// VRC6 Sound

static void DoSQV1(void);
static void DoSQV2(void);
static void DoSawV(void);

static INLINE void DoSQV(int x) {
	int32 V;
	int32 amp = (((vpsg1[x << 2] & 15) << 8) * 6 / 8) >> 4;
	int32 start, end;

	start = cvbc[x];
	end = (SOUNDTS << 16) / soundtsinc;
	if (end <= start) return;
	cvbc[x] = end;

	if (vpsg1[(x << 2) | 0x2] & 0x80) {
		if (vpsg1[x << 2] & 0x80) {
			for (V = start; V < end; V++)
				Wave[V >> 4] += amp;
		} else {
			int32 thresh = (vpsg1[x << 2] >> 4) & 7;
			int32 freq = ((vpsg1[(x << 2) | 0x1] | ((vpsg1[(x << 2) | 0x2] & 15) << 8)) + 1) << 17;
			for (V = start; V < end; V++) {
				if (dcount[x] > thresh)
					Wave[V >> 4] += amp;
				vcount[x] -= nesincsize;
				while (vcount[x] <= 0) {
					vcount[x] += freq;
					dcount[x] = (dcount[x] + 1) & 15;
				}
			}
		}
	}
}

static void DoSQV1(void) {
	DoSQV(0);
}

static void DoSQV2(void) {
	DoSQV(1);
}

static void DoSawV(void) {
	int V;
	int32 start, end;

	start = cvbc[2];
	end = (SOUNDTS << 16) / soundtsinc;
	if (end <= start) return;
	cvbc[2] = end;

	if (vpsg2[2] & 0x80) {
		static int32 saw1phaseacc = 0;
		uint32 freq3;
		static uint8 b3 = 0;
		static int32 phaseacc = 0;
		static uint32 duff = 0;

		freq3 = (vpsg2[1] + ((vpsg2[2] & 15) << 8) + 1);

		for (V = start; V < end; V++) {
			saw1phaseacc -= nesincsize;
			if (saw1phaseacc <= 0) {
				int32 t;
 rea:
				t = freq3;
				t <<= 18;
				saw1phaseacc += t;
				phaseacc += vpsg2[0] & 0x3f;
				b3++;
				if (b3 == 7) {
					b3 = 0;
					phaseacc = 0;
				}
				if (saw1phaseacc <= 0)
					goto rea;
				duff = (((phaseacc >> 3) & 0x1f) << 4) * 6 / 8;
			}
			Wave[V >> 4] += duff;
		}
	}
}

static INLINE void DoSQVHQ(int x) {
	int32 V;
	int32 amp = ((vpsg1[x << 2] & 15) << 8) * 6 / 8;

	if (vpsg1[(x << 2) | 0x2] & 0x80) {
		if (vpsg1[x << 2] & 0x80) {
			for (V = cvbc[x]; V < (int)SOUNDTS; V++)
				WaveHi[V] += amp;
		} else {
			int32 thresh = (vpsg1[x << 2] >> 4) & 7;
			for (V = cvbc[x]; V < (int)SOUNDTS; V++) {
				if (dcount[x] > thresh)
					WaveHi[V] += amp;
				vcount[x]--;
				if (vcount[x] <= 0) {
					vcount[x] = (vpsg1[(x << 2) | 0x1] | ((vpsg1[(x << 2) | 0x2] & 15) << 8)) + 1;
					dcount[x] = (dcount[x] + 1) & 15;
				}
			}
		}
	}
	cvbc[x] = SOUNDTS;
}

static void DoSQV1HQ(void) {
	DoSQVHQ(0);
}

static void DoSQV2HQ(void) {
	DoSQVHQ(1);
}

static void DoSawVHQ(void) {
	static uint8 b3 = 0;
	static int32 phaseacc = 0;
	int32 V;

	if (vpsg2[2] & 0x80) {
		for (V = cvbc[2]; V < (int)SOUNDTS; V++) {
			WaveHi[V] += (((phaseacc >> 3) & 0x1f) << 8) * 6 / 8;
			vcount[2]--;
			if (vcount[2] <= 0) {
				vcount[2] = (vpsg2[1] + ((vpsg2[2] & 15) << 8) + 1) << 1;
				phaseacc += vpsg2[0] & 0x3f;
				b3++;
				if (b3 == 7) {
					b3 = 0;
					phaseacc = 0;
				}
			}
		}
	}
	cvbc[2] = SOUNDTS;
}


void VRC6Sound(int Count) {
	int x;

	DoSQV1();
	DoSQV2();
	DoSawV();
	for (x = 0; x < 3; x++)
		cvbc[x] = Count;
}

void VRC6SoundHQ(void) {
	DoSQV1HQ();
	DoSQV2HQ();
	DoSawVHQ();
}

void VRC6SyncHQ(int32 ts) {
	int x;
	for (x = 0; x < 3; x++) cvbc[x] = ts;
}

static void VRC6_ESI(void) {
	GameExpSound.RChange = VRC6_ESI;
	GameExpSound.Fill = VRC6Sound;
	GameExpSound.HiFill = VRC6SoundHQ;
	GameExpSound.HiSync = VRC6SyncHQ;

	memset(cvbc, 0, sizeof(cvbc));
	memset(vcount, 0, sizeof(vcount));
	memset(dcount, 0, sizeof(dcount));
	if (FSettings.SndRate) {
		if (FSettings.soundq >= 1) {
			sfun[0] = DoSQV1HQ;
			sfun[1] = DoSQV2HQ;
			sfun[2] = DoSawVHQ;
		} else {
			sfun[0] = DoSQV1;
			sfun[1] = DoSQV2;
			sfun[2] = DoSawV;
		}
	} else
		memset(sfun, 0, sizeof(sfun));
	AddExState(&SStateRegs, ~0, 0, 0);
}

// VRC6 Sound

void Mapper24_Init(CartInfo *info) {
	is26 = 0;
	info->Power = VRC6Power;
	MapIRQHook = VRC6IRQHook;
	VRC6_ESI();
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}

void Mapper26_Init(CartInfo *info) {
	is26 = 1;
	info->Power = VRC6Power;
	info->Close = VRC6Close;
	MapIRQHook = VRC6IRQHook;
	VRC6_ESI();
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

void NSFVRC6_Init(void) {
	VRC6_ESI();
	SetWriteHandler(0x8000, 0xbfff, VRC6SW);
}
