/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2013 CaH4e3
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
 * DSOUNDV1/FL-TR8MA boards (32K WRAM, 8/16M), 178 mapper boards (8K WRAM, 4/8M)
 * Various Education Cartridges
 *
 */

#include "mapinc.h"

static uint8 reg[4];

static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

// Tennis with VR sensor, very simple behaviour
extern void GetMouseData(uint32 (&md)[3]);
static uint32 MouseData[3], click, lastclick;
static int32 SensorDelay;

// highly experimental, not actually working, just curious if it hapen to work with some other decoder
// SND Registers
static uint8 pcm_enable = 0;
static int16 pcm_latch = 0x3F6, pcm_clock = 0x3F6;
static writefunc pcmwrite;

static SFORMAT StateRegs[] =
{
	{ reg, 4, "REGS" },
	{ 0 }
};

//static int16 step_size[49] = {
//	16, 17, 19, 21, 23, 25, 28, 31, 34, 37,
//	41, 45, 50, 55, 60, 66, 73, 80, 88, 97,
//	107, 118, 130, 143, 157, 173, 190, 209, 230, 253,
//	279, 307, 337, 371, 408, 449, 494, 544, 598, 658,
//	724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552
//};	//49 items
//static int32 step_adj[16] = { -1, -1, -1, -1, 2, 5, 7, 9, -1, -1, -1, -1, 2, 5, 7, 9 };

//decode stuff
//static int32 jedi_table[16 * 49];
//static int32 acc = 0;	//ADPCM accumulator, initial condition must be 0
//static int32 decstep = 0;	//ADPCM decoding step, initial condition must be 0

//static void jedi_table_init() {
//	int step, nib;
//
//	for (step = 0; step < 49; step++) {
//		for (nib = 0; nib < 16; nib++) {
//			int value = (2 * (nib & 0x07) + 1) * step_size[step] / 8;
//			jedi_table[step * 16 + nib] = ((nib & 0x08) != 0) ? -value : value;
//		}
//	}
//}

//static uint8 decode(uint8 code) {
//	acc += jedi_table[decstep + code];
//	if ((acc & ~0x7ff) != 0)	// acc is > 2047
//		acc |= ~0xfff;
//	else acc &= 0xfff;
//	decstep += step_adj[code & 7] * 16;
//	if (decstep < 0) decstep = 0;
//	if (decstep > 48 * 16) decstep = 48 * 16;
//	return (acc >> 8) & 0xff;
//}

static void Sync(void) {
	uint32 sbank = reg[1] & 0x7;
	uint32 bbank = reg[2];
	setchr8(0);
	setprg8r(0x10, 0x6000, reg[3] & 3);
	if (reg[0] & 2) {	// UNROM mode
		setprg16(0x8000, (bbank << 3) | sbank);
		if (reg[0] & 4)
			setprg16(0xC000, (bbank << 3) | 6 | (reg[1] & 1));
		else
			setprg16(0xC000, (bbank << 3) | 7);
	} else {			// NROM mode
		uint32 bank = (bbank << 3) | sbank;
		if (reg[0] & 4) {
			setprg16(0x8000, bank);
			setprg16(0xC000, bank);
		} else
			setprg32(0x8000, bank >> 1);
	}
	setmirror((reg[0] & 1) ^ 1);
}

static DECLFW(M178Write) {
	reg[A & 3] = V;
//	FCEU_printf("cmd %04x:%02x\n", A, V);
	Sync();
}

static DECLFW(M178WriteSnd) {
	if (A == 0x5800) {
		if (V & 0xF0) {
			pcm_enable = 1;
//			pcmwrite(0x4011, (V & 0xF) << 3);
//			pcmwrite(0x4011, decode(V & 0xf));
		} else
			pcm_enable = 0;
	}// else
//		FCEU_printf("misc %04x:%02x\n", A, V);
}

static DECLFR(M178ReadSnd) {
	if (A == 0x5800)
		return (X.DB & 0xBF) | ((pcm_enable ^ 1) << 6);
	else
		return X.DB;
}

static DECLFR(M178ReadSensor) {
	X6502_IRQEnd(FCEU_IQEXT);		// hacky-hacky, actual reg is 6000 and it clear IRQ while reading, but then I need another mapper lol
	return 0x00;
}

static void M178Power(void) {
	reg[0] = reg[1] = reg[2] = reg[3] = SensorDelay = 0;
	Sync();
//	pcmwrite = GetWriteHandler(0x4011);
	SetWriteHandler(0x4800, 0x4fff, M178Write);
	SetWriteHandler(0x5800, 0x5fff, M178WriteSnd);
	SetReadHandler(0x5800, 0x5fff, M178ReadSnd);
	SetReadHandler(0x5000, 0x5000, M178ReadSensor);
	SetReadHandler(0x6000, 0x7fff, CartBR);
	SetWriteHandler(0x6000, 0x7fff, CartBW);
	SetReadHandler(0x8000, 0xffff, CartBR);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void M178SndClk(int a) {
	SensorDelay += a;
	if(SensorDelay > 0x32768) {
		SensorDelay -= 32768;
		//GetMouseData (MouseData);
		lastclick = click;
		click = MouseData[2] & 1;	// to prevent from continuos IRQ trigger if button is held.
									// actual circuit is just a D-C-R edge detector for IR-sensor
									// triggered by the active IR bat.
		if(lastclick && !click)
			X6502_IRQBegin(FCEU_IQEXT);
	}
			
//	if (pcm_enable) {
//		pcm_latch -= a;
//		if (pcm_latch <= 0) {
//			pcm_latch += pcm_clock;
//			pcm_enable = 0;
//		}
//	}
}

static void M178Close(void) {
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void Mapper178_Init(CartInfo *info) {
	info->Power = M178Power;
	info->Close = M178Close;
	GameStateRestore = StateRestore;
	MapIRQHook = M178SndClk;

//	jedi_table_init();

	WRAMSIZE = 32768;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	if (info->battery) {
		info->SaveGame[0] = WRAM;
		info->SaveGameLen[0] = WRAMSIZE;
	}
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");

	AddExState(&StateRegs, ~0, 0, 0);
}
