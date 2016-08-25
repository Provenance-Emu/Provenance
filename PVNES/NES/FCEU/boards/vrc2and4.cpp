/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
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

static uint8 isPirate, is22;
static uint16 IRQCount;
static uint8 IRQLatch, IRQa;
static uint8 prgreg[2], chrreg[8];
static uint16 chrhi[8];
static uint8 regcmd, irqcmd, mirr, big_bank;
static uint16 acount = 0;
static uint16 weirdo = 0;

static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ prgreg, 2, "PREG" },
	{ chrreg, 8, "CREG" },
	{ chrhi, 16, "CRGH" },
	{ &regcmd, 1, "CMDR" },
	{ &irqcmd, 1, "CMDI" },
	{ &mirr, 1, "MIRR" },
	{ &big_bank, 1, "BIGB" },
	{ &IRQCount, 2, "IRQC" },
	{ &IRQLatch, 1, "IRQL" },
	{ &IRQa, 1, "IRQA" },
	{ 0 }
};

static void Sync(void) {
	if (regcmd & 2) {
		setprg8(0xC000, prgreg[0] | big_bank);
		setprg8(0x8000, ((~1) & 0x1F) | big_bank);
	} else {
		setprg8(0x8000, prgreg[0] | big_bank);
		setprg8(0xC000, ((~1) & 0x1F) | big_bank);
	}
	setprg8(0xA000, prgreg[1] | big_bank);
	setprg8(0xE000, ((~0) & 0x1F) | big_bank);
	if (UNIFchrrama)
		setchr8(0);
	else{
		uint8 i;
		if(!weirdo)
			for (i = 0; i < 8; i++)
				setchr1(i << 10, (chrhi[i] | chrreg[i]) >> is22);
		else {
			setchr1(0x0000, 0xFC);
			setchr1(0x0400, 0xFD);
			setchr1(0x0800, 0xFF);
			weirdo--;
		}
	}
	switch (mirr & 0x3) {
	case 0: setmirror(MI_V); break;
	case 1: setmirror(MI_H); break;
	case 2: setmirror(MI_0); break;
	case 3: setmirror(MI_1); break;
	}
}

static DECLFW(VRC24Write) {
	A &= 0xF003;
	if ((A >= 0xB000) && (A <= 0xE003)) {
		if (UNIFchrrama)
			big_bank = (V & 8) << 2;							// my personally many-in-one feature ;) just for support pirate cart 2-in-1
		else{
			uint16 i = ((A >> 1) & 1) | ((A - 0xB000) >> 11);
			uint16 nibble = ((A & 1) << 2);
			chrreg[i] = (chrreg[i] & (0xF0 >> nibble)) | ((V & 0xF) << nibble);
			if(nibble)
				chrhi[i] = (V & 0x10) << 4;						// another one many in one feature from pirate carts
		}
		Sync();
	} else
		switch (A & 0xF003) {
		case 0x8000:
		case 0x8001:
		case 0x8002:
		case 0x8003:
			if (!isPirate) {
				prgreg[0] = V & 0x1F;
				Sync();
			}
			break;
		case 0xA000:
		case 0xA001:
		case 0xA002:
		case 0xA003:
			if (!isPirate)
				prgreg[1] = V & 0x1F;
			else{
				prgreg[0] = (V & 0x1F) << 1;
				prgreg[1] = ((V & 0x1F) << 1) | 1;
			}
			Sync();
			break;
		case 0x9000:
		case 0x9001: if (V != 0xFF) mirr = V; Sync(); break;
		case 0x9002:
		case 0x9003: regcmd = V; Sync(); break;
		case 0xF000: X6502_IRQEnd(FCEU_IQEXT); IRQLatch &= 0xF0; IRQLatch |= V & 0xF; break;
		case 0xF001: X6502_IRQEnd(FCEU_IQEXT); IRQLatch &= 0x0F; IRQLatch |= V << 4; break;
		case 0xF002: X6502_IRQEnd(FCEU_IQEXT); acount = 0; IRQCount = IRQLatch; IRQa = V & 2; irqcmd = V & 1; break;
		case 0xF003: X6502_IRQEnd(FCEU_IQEXT); IRQa = irqcmd; break;
		}
}

static DECLFW(M21Write) {
	A = (A & 0xF000) | ((A >> 1) & 0x3);						// Ganbare Goemon Gaiden 2 - Tenka no Zaihou (J) [!] isn't mapper 21 actually,
																// it's mapper 23 by wirings
	VRC24Write(A, V);
}

static DECLFW(M22Write) {
	if (A == 0xC007) {											// Ganbare Goemon Gaiden does strange things!!! at the end credits
		weirdo = 8;												// quick dirty hack, seems there is no other games with such PCB, so
																// we never know if it will not work for something else lol
	}
	A |= ((A >> 2) & 0x3);										// It's just swapped lines from 21 mapper
																//
	VRC24Write((A & 0xF000) | ((A >> 1) & 1) | ((A << 1) & 2), V);
}

static DECLFW(M23Write) {
	A |= ((A >> 2) & 0x3) | ((A >> 4) & 0x3) | ((A >> 6) & 0x3);// actually there is many-in-one mapper source, some pirate or
																// licensed games use various address bits for registers
	VRC24Write(A, V);
}

static void M21Power(void) {
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M21Write);
}

static void M22Power(void) {
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M22Write);
}

static void M23Power(void) {
	big_bank = 0x20;
	Sync();
	setprg8r(0x10, 0x6000, 0);	// Only two Goemon games are have battery backed RAM, three more shooters
								// (Parodius Da!, Gradius 2 and Crisis Force uses 2k or SRAM at 6000-67FF only
	SetReadHandler(0x6000, 0x7FFF, CartBR);
	SetWriteHandler(0x6000, 0x7FFF, CartBW);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M23Write);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void M25Power(void) {
	big_bank = 0x20;
	Sync();
	setprg8r(0x10, 0x6000, 0);
	SetReadHandler(0x6000, 0x7FFF, CartBR);
	SetWriteHandler(0x6000, 0x7FFF, CartBW);
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M22Write);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

void VRC24IRQHook(int a) {
	#define LCYCS 341
	if (IRQa) {
		acount += a * 3;
		if (acount >= LCYCS) {
			while (acount >= LCYCS) {
				acount -= LCYCS;
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

static void VRC24Close(void) {
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

void Mapper21_Init(CartInfo *info) {
	isPirate = 0;
	is22 = 0;
	info->Power = M21Power;
	MapIRQHook = VRC24IRQHook;
	GameStateRestore = StateRestore;

	AddExState(&StateRegs, ~0, 0, 0);
}

void Mapper22_Init(CartInfo *info) {
	isPirate = 0;
	is22 = 1;
	info->Power = M22Power;
	GameStateRestore = StateRestore;

	AddExState(&StateRegs, ~0, 0, 0);
}

void VRC24_Init(CartInfo *info) {
	info->Close = VRC24Close;
	MapIRQHook = VRC24IRQHook;
	GameStateRestore = StateRestore;

	WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");

	if(info->battery) {
		info->SaveGame[0]=WRAM;
		info->SaveGameLen[0]=WRAMSIZE;
	}

	AddExState(&StateRegs, ~0, 0, 0);
}

void Mapper23_Init(CartInfo *info) {
	isPirate = 0;
	is22 = 0;
	info->Power = M23Power;
	VRC24_Init(info);
}

void Mapper25_Init(CartInfo *info) {
	isPirate = 0;
	is22 = 0;
	info->Power = M25Power;
	VRC24_Init(info);
}

void UNLT230_Init(CartInfo *info) {
	isPirate = 1;
	is22 = 0;
	info->Power = M23Power;
	VRC24_Init(info);
}
