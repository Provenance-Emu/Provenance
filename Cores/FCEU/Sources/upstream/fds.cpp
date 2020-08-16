/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
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

#include "types.h"
#include "x6502.h"
#include "fceu.h"
#include "fds.h"
#include "sound.h"
#include "file.h"
#include "utils/md5.h"
#include "utils/memory.h"
#include "state.h"
#include "file.h"
#include "cart.h"
#include "netplay.h"
#include "driver.h"
#include "movie.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

//	TODO:  Add code to put a delay in between the time a disk is inserted
//	and the when it can be successfully read/written to.  This should
//	prevent writes to wrong places OR add code to prevent disk ejects
//	when the virtual motor is on (mmm...virtual motor).
extern int disableBatteryLoading;

bool isFDS = false; //flag for determining if a FDS game is loaded, movie.cpp needs this

static DECLFR(FDSRead4030);
static DECLFR(FDSRead4031);
static DECLFR(FDSRead4032);
static DECLFR(FDSRead4033);

static DECLFW(FDSWrite);

static DECLFW(FDSWaveWrite);
static DECLFR(FDSWaveRead);

static DECLFR(FDSSRead);
static DECLFW(FDSSWrite);

static void FDSInit(void);
static void FDSClose(void);

static void FDSFix(int a);

static uint8 FDSRegs[6];
static int32 IRQLatch, IRQCount;
static uint8 IRQa;

static uint8 *FDSRAM = NULL;
static uint32 FDSRAMSize;
static uint8 *FDSBIOS = NULL;
static uint32 FDSBIOSsize;
static uint8 *CHRRAM = NULL;
static uint32 CHRRAMSize;

/* Original disk data backup, to help in creating save states. */
static uint8 *diskdatao[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };

static uint8 *diskdata[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };

static int TotalSides; //mbg merge 7/17/06 - unsignedectomy
static uint8 DiskWritten = 0;    /* Set to 1 if disk was written to. */
static uint8 writeskip;
static int32 DiskPtr;
static int32 DiskSeekIRQ;
static uint8 SelectDisk, InDisk;

#define DC_INC    1

void FDSGI(GI h) {
	switch (h) {
	case GI_CLOSE: FDSClose(); break;
	case GI_POWER: FDSInit(); break;
	}
}

static void FDSStateRestore(int version) {
	int x;

	setmirror(((FDSRegs[5] & 8) >> 3) ^ 1);

	if (version >= 9810)
		for (x = 0; x < TotalSides; x++) {
			int b;
			for (b = 0; b < 65500; b++)
				diskdata[x][b] ^= diskdatao[x][b];
		}
}

void FDSSound();
void FDSSoundReset(void);
void FDSSoundStateAdd(void);
static void RenderSound(void);
static void RenderSoundHQ(void);

static void FDSInit(void) {
	memset(FDSRegs, 0, sizeof(FDSRegs));
	writeskip = DiskPtr = DiskSeekIRQ = 0;

	setmirror(1);
	setprg8(0xE000, 0);			// BIOS
	setprg32r(1, 0x6000, 0);	// 32KB RAM
	setchr8(0);					// 8KB CHR RAM

	MapIRQHook = FDSFix;
	GameStateRestore = FDSStateRestore;

	SetReadHandler(0x4030, 0x4030, FDSRead4030);
	SetReadHandler(0x4031, 0x4031, FDSRead4031);
	SetReadHandler(0x4032, 0x4032, FDSRead4032);
	SetReadHandler(0x4033, 0x4033, FDSRead4033);

	SetWriteHandler(0x4020, 0x4025, FDSWrite);

	SetWriteHandler(0x6000, 0xDFFF, CartBW);
	SetReadHandler(0x6000, 0xFFFF, CartBR);

	IRQCount = IRQLatch = IRQa = 0;

	FDSSoundReset();
	InDisk = 0;
	SelectDisk = 0;
}

void FCEU_FDSInsert(void)
{
	if (TotalSides == 0)
	{
		FCEU_DispMessage("Not FDS; can't eject disk.", 0);
		return;
	}

	if (FCEUI_EmulationPaused())
		EmulationPaused |= EMULATIONPAUSED_FA;

	if (FCEUMOV_Mode(MOVIEMODE_RECORD))
		FCEUMOV_AddCommand(FCEUNPCMD_FDSINSERT);

	if (InDisk == 255)
	{
		FCEU_DispMessage("Disk %d Side %s Inserted", 0, SelectDisk >> 1, (SelectDisk & 1) ? "B" : "A");
		InDisk = SelectDisk;
	} else
	{
		FCEU_DispMessage("Disk %d Side %s Ejected", 0, SelectDisk >> 1, (SelectDisk & 1) ? "B" : "A");
		InDisk = 255;
	}
}
/*
void FCEU_FDSEject(void)
{
InDisk=255;
}
*/
void FCEU_FDSSelect(void)
{
	if (TotalSides == 0)
	{
		FCEU_DispMessage("Not FDS; can't select disk.", 0);
		return;
	}
	if (InDisk != 255)
	{
		FCEU_DispMessage("Eject disk before selecting.", 0);
		return;
	}

	if (FCEUI_EmulationPaused())
		EmulationPaused |= EMULATIONPAUSED_FA;

	if (FCEUMOV_Mode(MOVIEMODE_RECORD))
		FCEUMOV_AddCommand(FCEUNPCMD_FDSSELECT);

	SelectDisk = ((SelectDisk + 1) % TotalSides) & 3;
	FCEU_DispMessage("Disk %d Side %c Selected", 0, SelectDisk >> 1, (SelectDisk & 1) ? 'B' : 'A');
}

static void FDSFix(int a) {
	if ((IRQa & 2) && IRQCount) {
		IRQCount -= a;
		if (IRQCount <= 0) {
			if (!(IRQa & 1)) {
				IRQa &= ~2;
				IRQCount = IRQLatch = 0;
			} else
				IRQCount = IRQLatch;
			X6502_IRQBegin(FCEU_IQEXT);
		}
	}
	if (DiskSeekIRQ > 0) {
		DiskSeekIRQ -= a;
		if (DiskSeekIRQ <= 0) {
			if (FDSRegs[5] & 0x80) {
				X6502_IRQBegin(FCEU_IQEXT2);
			}
		}
	}
}

static DECLFR(FDSRead4030) {
	uint8 ret = 0;

	/* Cheap hack. */
	if (X.IRQlow & FCEU_IQEXT) ret |= 1;
	if (X.IRQlow & FCEU_IQEXT2) ret |= 2;

	if (!fceuindbg) {
		X6502_IRQEnd(FCEU_IQEXT);
		X6502_IRQEnd(FCEU_IQEXT2);
	}
	return ret;
}

static DECLFR(FDSRead4031) {
	static uint8 z = 0;
	if (InDisk != 255) {
		z = diskdata[InDisk][DiskPtr];
		if (!fceuindbg) {
			if (DiskPtr < 64999) DiskPtr++;
			DiskSeekIRQ = 150;
			X6502_IRQEnd(FCEU_IQEXT2);
		}
	}
	return z;
}
static DECLFR(FDSRead4032) {
	uint8 ret;

	ret = X.DB & ~7;
	if (InDisk == 255)
		ret |= 5;

	if (InDisk == 255 || !(FDSRegs[5] & 1) || (FDSRegs[5] & 2))
		ret |= 2;
	return ret;
}

static DECLFR(FDSRead4033) {
	return 0x80; // battery
}

/* Begin FDS sound */

#define FDSClock (1789772.7272727272727272 / 2)

typedef struct {
	int64 cycles;     // Cycles per PCM sample
	int64 count;    // Cycle counter
	int64 envcount;    // Envelope cycle counter
	uint32 b19shiftreg60;
	uint32 b24adder66;
	uint32 b24latch68;
	uint32 b17latch76;
	int32 clockcount;  // Counter to divide frequency by 8.
	uint8 b8shiftreg88;  // Modulation register.
	uint8 amplitude[2];  // Current amplitudes.
	uint8 speedo[2];
	uint8 mwcount;
	uint8 mwstart;
	uint8 mwave[0x20];      // Modulation waveform
	uint8 cwave[0x40];      // Game-defined waveform(carrier)
	uint8 SPSG[0xB];
} FDSSOUND;

static FDSSOUND fdso;

#define  SPSG  fdso.SPSG
#define b19shiftreg60  fdso.b19shiftreg60
#define b24adder66  fdso.b24adder66
#define b24latch68  fdso.b24latch68
#define b17latch76  fdso.b17latch76
#define b8shiftreg88  fdso.b8shiftreg88
#define clockcount  fdso.clockcount
#define amplitude  fdso.amplitude
#define speedo    fdso.speedo

void FDSSoundStateAdd(void) {
	AddExState(fdso.cwave, 64, 0, "WAVE");
	AddExState(fdso.mwave, 32, 0, "MWAV");
	AddExState(amplitude, 2, 0, "AMPL");
	AddExState(SPSG, 0xB, 0, "SPSG");

	AddExState(&b8shiftreg88, 1, 0, "B88");

	AddExState(&clockcount, 4, 1, "CLOC");
	AddExState(&b19shiftreg60, 4, 1, "B60");
	AddExState(&b24adder66, 4, 1, "B66");
	AddExState(&b24latch68, 4, 1, "B68");
	AddExState(&b17latch76, 4, 1, "B76");
}

static DECLFR(FDSSRead) {
	switch (A & 0xF) {
	case 0x0: return(amplitude[0] | (X.DB & 0xC0));
	case 0x2: return(amplitude[1] | (X.DB & 0xC0));
	}
	return(X.DB);
}

static DECLFW(FDSSWrite) {
	if (FSettings.SndRate) {
		if (FSettings.soundq >= 1)
			RenderSoundHQ();
		else
			RenderSound();
	}
	A -= 0x4080;
	switch (A) {
	case 0x0:
	case 0x4:
		if (V & 0x80)
			amplitude[(A & 0xF) >> 2] = V & 0x3F;
		break;
	case 0x7:
		b17latch76 = 0;
		SPSG[0x5] = 0;
		break;
	case 0x8:
		b17latch76 = 0;
		fdso.mwave[SPSG[0x5] & 0x1F] = V & 0x7;
		SPSG[0x5] = (SPSG[0x5] + 1) & 0x1F;
		break;
	}
	SPSG[A] = V;
}

// $4080 - Fundamental wave amplitude data register 92
// $4082 - Fundamental wave frequency data register 58
// $4083 - Same as $4082($4083 is the upper 4 bits).

// $4084 - Modulation amplitude data register 78
// $4086 - Modulation frequency data register 72
// $4087 - Same as $4086($4087 is the upper 4 bits)


static void DoEnv() {
	int x;

	for (x = 0; x < 2; x++)
		if (!(SPSG[x << 2] & 0x80) && !(SPSG[0x3] & 0x40)) {
			static int counto[2] = { 0, 0 };

			if (counto[x] <= 0) {
				if (!(SPSG[x << 2] & 0x80)) {
					if (SPSG[x << 2] & 0x40) {
						if (amplitude[x] < 0x3F)
							amplitude[x]++;
					} else {
						if (amplitude[x] > 0)
							amplitude[x]--;
					}
				}
				counto[x] = (SPSG[x << 2] & 0x3F);
			} else
				counto[x]--;
		}
}

static DECLFR(FDSWaveRead) {
	return(fdso.cwave[A & 0x3f] | (X.DB & 0xC0));
}

static DECLFW(FDSWaveWrite) {
	if (SPSG[0x9] & 0x80)
		fdso.cwave[A & 0x3f] = V & 0x3F;
}

static int ta;
static INLINE void ClockRise(void) {
	if (!clockcount) {
		ta++;

		b19shiftreg60 = (SPSG[0x2] | ((SPSG[0x3] & 0xF) << 8));
		b17latch76 = (SPSG[0x6] | ((SPSG[0x07] & 0xF) << 8)) + b17latch76;

		if (!(SPSG[0x7] & 0x80)) {
			int t = fdso.mwave[(b17latch76 >> 13) & 0x1F] & 7;
			int t2 = amplitude[1];
			int adj = 0;

			if ((t & 3)) {
				if ((t & 4))
					adj -= (t2 * ((4 - (t & 3))));
				else
					adj += (t2 * ((t & 3)));
			}
			adj *= 2;
			if (adj > 0x7F) adj = 0x7F;
			if (adj < -0x80) adj = -0x80;
			b8shiftreg88 = 0x80 + adj;
		} else {
			b8shiftreg88 = 0x80;
		}
	} else {
		b19shiftreg60 <<= 1;
		b8shiftreg88 >>= 1;
	}
	b24adder66 = (b24latch68 + b19shiftreg60) & 0x1FFFFFF;
}

static INLINE void ClockFall(void) {
	if ((b8shiftreg88 & 1))
		b24latch68 = b24adder66;
	clockcount = (clockcount + 1) & 7;
}

static INLINE int32 FDSDoSound(void) {
	fdso.count += fdso.cycles;
	if (fdso.count >= ((int64)1 << 40)) {
 dogk:
		fdso.count -= (int64)1 << 40;
		ClockRise();
		ClockFall();
		fdso.envcount--;
		if (fdso.envcount <= 0) {
			fdso.envcount += SPSG[0xA] * 3;
			DoEnv();
		}
	}
	if (fdso.count >= 32768) goto dogk;

	// Might need to emulate applying the amplitude to the waveform a bit better...
	{
		int k = amplitude[0];
		if (k > 0x20) k = 0x20;
		return (fdso.cwave[b24latch68 >> 19] * k) * 4 / ((SPSG[0x9] & 0x3) + 2);
	}
}

static int32 FBC = 0;

static void RenderSound(void) {
	int32 end, start;
	int32 x;

	start = FBC;
	end = (SOUNDTS << 16) / soundtsinc;
	if (end <= start)
		return;
	FBC = end;

	if (!(SPSG[0x9] & 0x80))
		for (x = start; x < end; x++) {
			uint32 t = FDSDoSound();
			t += t >> 1;
			t >>= 4;
			Wave[x >> 4] += t; //(t>>2)-(t>>3); //>>3;
		}
}

static void RenderSoundHQ(void) {
	uint32 x; //mbg merge 7/17/06 - made this unsigned

	if (!(SPSG[0x9] & 0x80))
		for (x = FBC; x < SOUNDTS; x++) {
			uint32 t = FDSDoSound();
			t += t >> 1;
			WaveHi[x] += t; //(t<<2)-(t<<1);
		}
	FBC = SOUNDTS;
}

static void HQSync(int32 ts) {
	FBC = ts;
}

void FDSSound(int c) {
	RenderSound();
	FBC = c;
}

static void FDS_ESI(void) {
	if (FSettings.SndRate) {
		if (FSettings.soundq >= 1) {
			fdso.cycles = (int64)1 << 39;
		} else {
			fdso.cycles = ((int64)1 << 40) * FDSClock;
			fdso.cycles /= FSettings.SndRate * 16;
		}
	}
	SetReadHandler(0x4040, 0x407f, FDSWaveRead);
	SetWriteHandler(0x4040, 0x407f, FDSWaveWrite);
	SetWriteHandler(0x4080, 0x408A, FDSSWrite);
	SetReadHandler(0x4090, 0x4092, FDSSRead);
}

void FDSSoundReset(void) {
	memset(&fdso, 0, sizeof(fdso));
	FDS_ESI();
	GameExpSound.HiSync = HQSync;
	GameExpSound.HiFill = RenderSoundHQ;
	GameExpSound.Fill = FDSSound;
	GameExpSound.RChange = FDS_ESI;
}

static DECLFW(FDSWrite) {
	switch (A) {
	case 0x4020:
		X6502_IRQEnd(FCEU_IQEXT);
		IRQLatch &= 0xFF00;
		IRQLatch |= V;
		break;
	case 0x4021:
		X6502_IRQEnd(FCEU_IQEXT);
		IRQLatch &= 0xFF;
		IRQLatch |= V << 8;
		break;
	case 0x4022:
		X6502_IRQEnd(FCEU_IQEXT);
		IRQCount = IRQLatch;
		IRQa = V & 3;
		break;
	case 0x4023: break;
	case 0x4024:
		if ((InDisk != 255) && !(FDSRegs[5] & 0x4) && (FDSRegs[3] & 0x1)) {
			if (DiskPtr >= 0 && DiskPtr < 65500) {
				if (writeskip)
					writeskip--;
				else if (DiskPtr >= 2) {
					DiskWritten = 1;
					diskdata[InDisk][DiskPtr - 2] = V;
				}
			}
		}
		break;
	case 0x4025:
		X6502_IRQEnd(FCEU_IQEXT2);
		if (InDisk != 255) {
			if (!(V & 0x40)) {
				if ((FDSRegs[5] & 0x40) && !(V & 0x10)) {
					DiskSeekIRQ = 200;
					DiskPtr -= 2;
				}
				if (DiskPtr < 0) DiskPtr = 0;
			}
			if (!(V & 0x4)) writeskip = 2;
			if (V & 2) {
				DiskPtr = 0; DiskSeekIRQ = 200;
			}
			if (V & 0x40) DiskSeekIRQ = 200;
		}
		setmirror(((V >> 3) & 1) ^ 1);
		break;
	}
	FDSRegs[A & 7] = V;
}

static void FreeFDSMemory(void) {
	int x;

	for (x = 0; x < TotalSides; x++)
		if (diskdata[x]) {
			free(diskdata[x]);
			diskdata[x] = 0;
		}
}

static int SubLoad(FCEUFILE *fp) {
	struct md5_context md5;
	uint8 header[16];
	int x;

	FCEU_fread(header, 16, 1, fp);

	if (memcmp(header, "FDS\x1a", 4)) {
		if (!(memcmp(header + 1, "*NINTENDO-HVC*", 14))) {
			long t;
			t = FCEU_fgetsize(fp);
			if (t < 65500)
				t = 65500;
			TotalSides = t / 65500;
			FCEU_fseek(fp, 0, SEEK_SET);
		} else
			return(0);
	} else
		TotalSides = header[4];

	md5_starts(&md5);

	if (TotalSides > 8) TotalSides = 8;
	if (TotalSides < 1) TotalSides = 1;

	for (x = 0; x < TotalSides; x++) {
		diskdata[x] = (uint8*)FCEU_malloc(65500);
		if (!diskdata[x]) {
			int zol;
			for (zol = 0; zol < x; zol++)
				free(diskdata[zol]);
			return 0;
		}
		FCEU_fread(diskdata[x], 1, 65500, fp);
		md5_update(&md5, diskdata[x], 65500);
	}
	md5_finish(&md5, GameInfo->MD5.data);
	return(1);
}

static void PreSave(void) {
	int x;
	for (x = 0; x < TotalSides; x++) {
		int b;
		for (b = 0; b < 65500; b++)
			diskdata[x][b] ^= diskdatao[x][b];
	}
}

static void PostSave(void) {
	int x;
	for (x = 0; x < TotalSides; x++) {
		int b;
		for (b = 0; b < 65500; b++)
			diskdata[x][b] ^= diskdatao[x][b];
	}
}

int FDSLoad(const char *name, FCEUFILE *fp) {
	FILE *zp;
	int x;

	char *fn = strdup(FCEU_MakeFName(FCEUMKF_FDSROM, 0, 0).c_str());

	if (!(zp = FCEUD_UTF8fopen(fn, "rb"))) {
		FCEU_PrintError("FDS BIOS ROM image missing: %s", FCEU_MakeFName(FCEUMKF_FDSROM, 0, 0).c_str());
		free(fn);
		return 0;
	}

	free(fn);

	fseek(zp, 0L, SEEK_END);
	if (ftell(zp) != 8192) {
		fclose(zp);
		FCEU_PrintError("FDS BIOS ROM image incompatible: %s", FCEU_MakeFName(FCEUMKF_FDSROM, 0, 0).c_str());
		return 0;
	}
	fseek(zp, 0L, SEEK_SET);

	ResetCartMapping();

	if(FDSBIOS)
		free(FDSBIOS);
	FDSBIOS = NULL;
	if(FDSRAM)
		free(FDSRAM);
	FDSRAM = NULL;
	if(CHRRAM)
		free(CHRRAM);
	CHRRAM = NULL;

	FDSBIOSsize = 8192;
	FDSBIOS = (uint8*)FCEU_gmalloc(FDSBIOSsize);
	SetupCartPRGMapping(0, FDSBIOS, FDSBIOSsize, 0);

	if (fread(FDSBIOS, 1, FDSBIOSsize, zp) != FDSBIOSsize) {
		if(FDSBIOS)
			free(FDSBIOS);
		FDSBIOS = NULL;
		fclose(zp);
		FCEU_PrintError("Error reading FDS BIOS ROM image.");
		return 0;
	}

	fclose(zp);

	FCEU_fseek(fp, 0, SEEK_SET);

	FreeFDSMemory();
	if (!SubLoad(fp)) {
		if(FDSBIOS)
			free(FDSBIOS);
		FDSBIOS = NULL;
		return(0);
	}

	if (!disableBatteryLoading) {
		FCEUFILE *tp;
		char *fn = strdup(FCEU_MakeFName(FCEUMKF_FDS, 0, 0).c_str());

		int x;
		for (x = 0; x < TotalSides; x++) {
			diskdatao[x] = (uint8*)FCEU_malloc(65500);
			memcpy(diskdatao[x], diskdata[x], 65500);
		}

		if ((tp = FCEU_fopen(fn, 0, "rb", 0))) {
			FCEU_printf("Disk was written. Auxillary FDS file open \"%s\".\n",fn);
			FreeFDSMemory();
			if (!SubLoad(tp)) {
				FCEU_PrintError("Error reading auxillary FDS file.");
				if(FDSBIOS)
					free(FDSBIOS);
				FDSBIOS = NULL;
				free(fn);
				return(0);
			}
			FCEU_fclose(tp);
			DiskWritten = 1;  /* For save state handling. */
		}
		free(fn);
	}

	extern char LoadedRomFName[2048];
	strcpy(LoadedRomFName, name); //For the debugger list

	GameInfo->type = GIT_FDS;
	GameInterface = FDSGI;
	isFDS = true;

	SelectDisk = 0;
	InDisk = 255;

	ResetExState(PreSave, PostSave);
	FDSSoundStateAdd();

	for (x = 0; x < TotalSides; x++) {
		char temp[5];
		sprintf(temp, "DDT%d", x);
		AddExState(diskdata[x], 65500, 0, temp);
	}

	AddExState(FDSRegs, sizeof(FDSRegs), 0, "FREG");
	AddExState(&IRQCount, 4, 1, "IRQC");
	AddExState(&IRQLatch, 4, 1, "IQL1");
	AddExState(&IRQa, 1, 0, "IRQA");
	AddExState(&writeskip, 1, 0, "WSKI");
	AddExState(&DiskPtr, 4, 1, "DPTR");
	AddExState(&DiskSeekIRQ, 4, 1, "DSIR");
	AddExState(&SelectDisk, 1, 0, "SELD");
	AddExState(&InDisk, 1, 0, "INDI");
	AddExState(&DiskWritten, 1, 0, "DSKW");

	CHRRAMSize = 8192;
	CHRRAM = (uint8*)FCEU_gmalloc(CHRRAMSize);
	memset(CHRRAM, 0, CHRRAMSize);
	SetupCartCHRMapping(0, CHRRAM, CHRRAMSize, 1);
	AddExState(CHRRAM, CHRRAMSize, 0, "CHRR");

	FDSRAMSize = 32768;
	FDSRAM = (uint8*)FCEU_gmalloc(FDSRAMSize);
	memset(FDSRAM, 0, FDSRAMSize);
	SetupCartPRGMapping(1, FDSRAM, FDSRAMSize, 1);
	AddExState(FDSRAM, FDSRAMSize, 0, "FDSR");

	SetupCartMirroring(0, 0, 0);

	FCEU_printf(" Sides: %d\n\n", TotalSides);

	FCEUI_SetVidSystem(0);

	return 1;
}

void FDSClose(void) {
	FILE *fp;
	int x;
	isFDS = false;

	if (!DiskWritten) return;

	const std::string &fn = FCEU_MakeFName(FCEUMKF_FDS, 0, 0);
	if (!(fp = FCEUD_UTF8fopen(fn.c_str(), "wb"))) {
		return;
	}

	for (x = 0; x < TotalSides; x++) {
		if (fwrite(diskdata[x], 1, 65500, fp) != 65500) {
			FCEU_PrintError("Error saving FDS image!");
			fclose(fp);
			return;
		}
	}

	for (x = 0; x < TotalSides; x++)
		if (diskdatao[x]) {
			free(diskdatao[x]);
			diskdatao[x] = 0;
		}

	FreeFDSMemory();
	if(FDSBIOS)
		free(FDSBIOS);
	FDSBIOS = NULL;
	if(FDSRAM)
		free(FDSRAM);
	FDSRAM = NULL;
	if(CHRRAM)
		free(CHRRAM);
	CHRRAM = NULL;
	fclose(fp);
}
