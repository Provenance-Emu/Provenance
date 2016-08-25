/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007-2010 CaH4e3
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
 * VR02/VT03 Console and OneBus System
 *
 * Street Dance (Dance pad) (Unl)
 * 101-in-1 Arcade Action II
 * DreamGEAR 75-in-1, etc.
 *
 */

#include "mapinc.h"

// General Purpose Registers
static uint8 cpu410x[16], ppu201x[16], apu40xx[64];

// IRQ Registers
static uint8 IRQCount, IRQa, IRQReload;
#define IRQLatch cpu410x[0x1]	// accc cccc, a = 0, AD12 switching, a = 1, HSYNC switching

// MMC3 Registers
static uint8 inv_hack = 0;		// some OneBus Systems have swapped PRG reg commans in MMC3 inplementation,
								// trying to autodetect unusual behavior, due not to add a new mapper.
#define mmc3cmd  cpu410x[0x5]	// pcv- ----, p - program swap, c - video swap, v - internal VRAM enable
#define mirror   cpu410x[0x6]	// ---- ---m, m = 0 - H, m = 1 - V

// APU Registers
static uint8 pcm_enable = 0, pcm_irq = 0;
static int16 pcm_addr, pcm_size, pcm_latch, pcm_clock = 0xE1;

static writefunc defapuwrite[64];
static readfunc defapuread[64];

static SFORMAT StateRegs[] =
{
	{ cpu410x, 16, "REGC" },
	{ ppu201x, 16, "REGS" },
	{ apu40xx, 64, "REGA" },
	{ &IRQReload, 1, "IRQR" },
	{ &IRQCount, 1, "IRQC" },
	{ &IRQa, 1, "IRQA" },
	{ &pcm_enable, 1, "PCME" },
	{ &pcm_irq, 1, "PCMI" },
	{ &pcm_addr, 2, "PCMA" },
	{ &pcm_size, 2, "PCMS" },
	{ &pcm_latch, 2, "PCML" },
	{ &pcm_clock, 2, "PCMC" },
	{ 0 }
};

static void PSync(void) {
	uint8 bankmode = cpu410x[0xb] & 7;
	uint8 mask = (bankmode == 0x7) ? (0xff) : (0x3f >> bankmode);
	uint32 block = ((cpu410x[0x0] & 0xf0) << 4) + (cpu410x[0xa] & (~mask));
	uint32 pswap = (mmc3cmd & 0x40) << 8;

//	uint8 bank0  = (cpu410x[0xb] & 0x40)?(~1):(cpu410x[0x7]);
//	uint8 bank1  = cpu410x[0x8];
//	uint8 bank2  = (cpu410x[0xb] & 0x40)?(cpu410x[0x9]):(~1);
//	uint8 bank3  = ~0;
	uint8 bank0 = cpu410x[0x7 ^ inv_hack];
	uint8 bank1 = cpu410x[0x8 ^ inv_hack];
	uint8 bank2 = (cpu410x[0xb] & 0x40) ? (cpu410x[0x9]) : (~1);
	uint8 bank3 = ~0;

//	FCEU_printf(" PRG: %04x [%02x]",0x8000^pswap,block | (bank0 & mask));
	setprg8(0x8000 ^ pswap, block | (bank0 & mask));
//	FCEU_printf(" %04x [%02x]",0xa000^pswap,block | (bank1 & mask));
	setprg8(0xa000, block | (bank1 & mask));
//	FCEU_printf(" %04x [%02x]",0xc000^pswap,block | (bank2 & mask));
	setprg8(0xc000 ^ pswap, block | (bank2 & mask));
//	FCEU_printf(" %04x [%02x]\n",0xe000^pswap,block | (bank3 & mask));
	setprg8(0xe000, block | (bank3 & mask));
}

static void CSync(void) {
	static const uint8 midx[8] = { 0, 1, 2, 0, 3, 4, 5, 0 };
	uint8 mask = 0xff >> midx[ppu201x[0xa] & 7];
	uint32 block = ((cpu410x[0x0] & 0x0f) << 11) + ((ppu201x[0x8] & 0x70) << 4) + (ppu201x[0xa] & (~mask));
	uint32 cswap = (mmc3cmd & 0x80) << 5;

	uint8 bank0 = ppu201x[0x6] & (~1);
	uint8 bank1 = ppu201x[0x6] | 1;
	uint8 bank2 = ppu201x[0x7] & (~1);
	uint8 bank3 = ppu201x[0x7] | 1;
	uint8 bank4 = ppu201x[0x2];
	uint8 bank5 = ppu201x[0x3];
	uint8 bank6 = ppu201x[0x4];
	uint8 bank7 = ppu201x[0x5];

	setchr1(0x0000 ^ cswap, block | (bank0 & mask));
	setchr1(0x0400 ^ cswap, block | (bank1 & mask));
	setchr1(0x0800 ^ cswap, block | (bank2 & mask));
	setchr1(0x0c00 ^ cswap, block | (bank3 & mask));
	setchr1(0x1000 ^ cswap, block | (bank4 & mask));
	setchr1(0x1400 ^ cswap, block | (bank5 & mask));
	setchr1(0x1800 ^ cswap, block | (bank6 & mask));
	setchr1(0x1c00 ^ cswap, block | (bank7 & mask));

	setmirror((mirror ^ 1) & 1);
}

static void Sync(void) {
	PSync();
	CSync();
}

static DECLFW(UNLOneBusWriteCPU410X) {
//	FCEU_printf("CPU %04x:%04x\n",A,V);
	switch (A & 0xf) {
	case 0x1: IRQLatch = V & 0xfe; break;	// не по даташиту
	case 0x2: IRQReload = 1; break;
	case 0x3: X6502_IRQEnd(FCEU_IQEXT); IRQa = 0; break;
	case 0x4: IRQa = 1; break;
	default:
		cpu410x[A & 0xf] = V;
		Sync();
	}
}

static DECLFW(UNLOneBusWritePPU201X) {
//	FCEU_printf("PPU %04x:%04x\n",A,V);
	ppu201x[A & 0x0f] = V;
	Sync();
}

static DECLFW(UNLOneBusWriteMMC3) {
//	FCEU_printf("MMC %04x:%04x\n",A,V);
	switch (A & 0xe001) {
	case 0x8000: mmc3cmd = (mmc3cmd & 0x38) | (V & 0xc7); Sync(); break;
	case 0x8001:
	{
		switch (mmc3cmd & 7) {
		case 0: ppu201x[0x6] = V; CSync(); break;
		case 1: ppu201x[0x7] = V; CSync(); break;
		case 2: ppu201x[0x2] = V; CSync(); break;
		case 3: ppu201x[0x3] = V; CSync(); break;
		case 4: ppu201x[0x4] = V; CSync(); break;
		case 5: ppu201x[0x5] = V; CSync(); break;
		case 6: cpu410x[0x7] = V; PSync(); break;
		case 7: cpu410x[0x8] = V; PSync(); break;
		}
		break;
	}
	case 0xa000: mirror = V; CSync(); break;
	case 0xc000: IRQLatch = V & 0xfe; break;
	case 0xc001: IRQReload = 1; break;
	case 0xe000: X6502_IRQEnd(FCEU_IQEXT); IRQa = 0; break;
	case 0xe001: IRQa = 1; break;
	}
}

static void UNLOneBusIRQHook(void) {
	uint32 count = IRQCount;
	if (!count || IRQReload) {
		IRQCount = IRQLatch;
		IRQReload = 0;
	} else
		IRQCount--;
	if (count && !IRQCount) {
		if (IRQa)
			X6502_IRQBegin(FCEU_IQEXT);
	}
}

static DECLFW(UNLOneBusWriteAPU40XX) {
//	if(((A & 0x3f)!=0x16) && ((apu40xx[0x30] & 0x10) || ((A & 0x3f)>0x17)))FCEU_printf("APU %04x:%04x\n",A,V);
	apu40xx[A & 0x3f] = V;
	switch (A & 0x3f) {
	case 0x12:
		if (apu40xx[0x30] & 0x10) {
			pcm_addr = V << 6;
		}
		break;
	case 0x13:
		if (apu40xx[0x30] & 0x10) {
			pcm_size = (V << 4) + 1;
		}
		break;
	case 0x15:
		if (apu40xx[0x30] & 0x10) {
			pcm_enable = V & 0x10;
			if (pcm_irq) {
				X6502_IRQEnd(FCEU_IQEXT);
				pcm_irq = 0;
			}
			if (pcm_enable)
				pcm_latch = pcm_clock;
			V &= 0xef;
		}
		break;
	}
	defapuwrite[A & 0x3f](A, V);
}

static DECLFR(UNLOneBusReadAPU40XX) {
	uint8 result = defapuread[A & 0x3f](A);
//	FCEU_printf("read %04x, %02x\n",A,result);
	switch (A & 0x3f) {
	case 0x15:
		if (apu40xx[0x30] & 0x10) {
			result = (result & 0x7f) | pcm_irq;
		}
		break;
	}
	return result;
}

static void UNLOneBusCpuHook(int a) {
	if (pcm_enable) {
		pcm_latch -= a;
		if (pcm_latch <= 0) {
			pcm_latch += pcm_clock;
			pcm_size--;
			if (pcm_size < 0) {
				pcm_irq = 0x80;
				pcm_enable = 0;
				X6502_IRQBegin(FCEU_IQEXT);
			} else {
				uint16 addr = pcm_addr | ((apu40xx[0x30]^3) << 14);
				uint8 raw_pcm = ARead[addr](addr) >> 1;
				defapuwrite[0x11](0x4011, raw_pcm);
				pcm_addr++;
				pcm_addr &= 0x7FFF;
			}
		}
	}
}

static void UNLOneBusPower(void) {
	uint32 i;
	IRQReload = IRQCount = IRQa = 0;

	memset(cpu410x, 0x00, sizeof(cpu410x));
	memset(ppu201x, 0x00, sizeof(ppu201x));
	memset(apu40xx, 0x00, sizeof(apu40xx));

	SetupCartCHRMapping(0, PRGptr[0], PRGsize[0], 0);

	for (i = 0; i < 64; i++) {
		defapuread[i] = GetReadHandler(0x4000 | i);
		defapuwrite[i] = GetWriteHandler(0x4000 | i);
	}
	SetReadHandler(0x4000, 0x403f, UNLOneBusReadAPU40XX);
	SetWriteHandler(0x4000, 0x403f, UNLOneBusWriteAPU40XX);

	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x2010, 0x201f, UNLOneBusWritePPU201X);
	SetWriteHandler(0x4100, 0x410f, UNLOneBusWriteCPU410X);
	SetWriteHandler(0x8000, 0xffff, UNLOneBusWriteMMC3);

	Sync();
}

static void UNLOneBusReset(void) {
	IRQReload = IRQCount = IRQa = 0;

	memset(cpu410x, 0x00, sizeof(cpu410x));
	memset(ppu201x, 0x00, sizeof(ppu201x));
	memset(apu40xx, 0x00, sizeof(apu40xx));

	Sync();
}

static void StateRestore(int version) {
	Sync();
}

void UNLOneBus_Init(CartInfo *info) {
	info->Power = UNLOneBusPower;
	info->Reset = UNLOneBusReset;

	if (((*(uint32*)&(info->MD5)) == 0x305fcdc3) ||	// PowerJoy Supermax Carts
		((*(uint32*)&(info->MD5)) == 0x6abfce8e))
		inv_hack = 0xf;

	GameHBIRQHook = UNLOneBusIRQHook;
	MapIRQHook = UNLOneBusCpuHook;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
