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
 *
 * VRC-3
 *
 */

#include "mapinc.h"

static uint8 preg;
static uint8 IRQx;	//autoenable
static uint8 IRQm;	//mode
static uint8 IRQa;
static uint16 IRQReload, IRQCount;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ &preg, 1, "PREG" },
	{ &IRQa, 1, "IRQA" },
	{ &IRQx, 1, "IRQX" },
	{ &IRQm, 1, "IRQM" },
	{ &IRQReload, 2, "IRQR" },
	{ &IRQCount, 2, "IRQC" },
	{ 0 }
};

static void Sync(void) {
	setprg8r(0x10, 0x6000, 0);
	setprg16(0x8000, preg);
	setprg16(0xC000, ~0);
	setchr8(0);
}

static DECLFW(M73Write) {
	switch (A & 0xF000) {
	case 0x8000: IRQReload &= 0xFFF0; IRQReload |= (V & 0xF) << 0;  break;
	case 0x9000: IRQReload &= 0xFF0F; IRQReload |= (V & 0xF) << 4;  break;
	case 0xA000: IRQReload &= 0xF0FF; IRQReload |= (V & 0xF) << 8;  break;
	case 0xB000: IRQReload &= 0x0FFF; IRQReload |= (V & 0xF) << 12; break;
	case 0xC000:
		IRQm = V & 4;
		IRQx = V & 1;
		IRQa = V & 2;
		if (IRQa) {
			if (IRQm) {
				IRQCount &= 0xFFFF;
				IRQCount |= (IRQReload & 0xFF);
			} else
				IRQCount = IRQReload;
		}
		X6502_IRQEnd(FCEU_IQEXT);
		break;
	case 0xD000: X6502_IRQEnd(FCEU_IQEXT); IRQa = IRQx; break;
	case 0xF000: preg = V; Sync(); break;
	}
}

static void M73IRQHook(int a) {
	int32 i;
	if (!IRQa) return;
	for (i = 0; i < a; i++) {
		if (IRQm) {
			uint16 temp = IRQCount;
			temp &= 0xFF;
			IRQCount &= 0xFF00;
			if (temp == 0xFF) {
				IRQCount = IRQReload;
				IRQCount |= (uint16)(IRQReload & 0xFF);
				X6502_IRQBegin(FCEU_IQEXT);
			} else {
				temp++;
				IRQCount |= temp;
			}
		} else {
			//16 bit mode
			if (IRQCount == 0xFFFF) {
				IRQCount = IRQReload;
				X6502_IRQBegin(FCEU_IQEXT);
			} else
				IRQCount++;
		}
	}
}

static void M73Power(void) {
	IRQReload = IRQm = IRQx = 0;
	Sync();
	SetReadHandler(0x6000, 0xFFFF, CartBR);
	SetWriteHandler(0x6000, 0x7FFF, CartBW);
	SetWriteHandler(0x8000, 0xFFFF, M73Write);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void M73Close(void)
{
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void Mapper73_Init(CartInfo *info) {
	info->Power = M73Power;
	info->Close = M73Close;
	MapIRQHook = M73IRQHook;

	WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");

	AddExState(&StateRegs, ~0, 0, 0);
	GameStateRestore = StateRestore;
}
