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

static uint8 preg[3], creg[8], mirr;
static uint8 IRQa;
static int16 IRQCount, IRQLatch;

static SFORMAT StateRegs[] =
{
	{ preg, 3, "PREG" },
	{ creg, 8, "CREG" },
	{ &mirr, 1, "MIRR" },
	{ &IRQa, 1, "IRQA" },
	{ &IRQCount, 2, "IRQC" },
	{ &IRQLatch, 2, "IRQL" },
	{ 0 }
};

static void Sync(void) {
	setmirror(mirr);
	setprg8(0x8000, preg[0]);
	setprg8(0xA000, preg[1]);
	setprg8(0xC000, preg[2]);
	setprg8(0xE000, ~0);
	setchr1(0x0000, creg[0]);
	setchr1(0x0400, creg[1]);
	setchr1(0x0800, creg[2]);
	setchr1(0x0C00, creg[3]);
	setchr1(0x1000, creg[4]);
	setchr1(0x1400, creg[5]);
	setchr1(0x1800, creg[6]);
	setchr1(0x1C00, creg[7]);
	setmirror(mirr);
}

static DECLFW(M65Write) {
	switch (A) {
	case 0x8000: preg[0] = V; Sync(); break;
	case 0xA000: preg[1] = V; Sync(); break;
	case 0xC000: preg[2] = V; Sync(); break;
	case 0x9001: mirr = ((V >> 7) & 1) ^ 1; Sync(); break;
	case 0x9003: IRQa = V & 0x80; X6502_IRQEnd(FCEU_IQEXT); break;
	case 0x9004: IRQCount = IRQLatch; break;
	case 0x9005: IRQLatch &= 0x00FF; IRQLatch |= V << 8; break;
	case 0x9006: IRQLatch &= 0xFF00; IRQLatch |= V; break;
	case 0xB000: creg[0] = V; Sync(); break;
	case 0xB001: creg[1] = V; Sync(); break;
	case 0xB002: creg[2] = V; Sync(); break;
	case 0xB003: creg[3] = V; Sync(); break;
	case 0xB004: creg[4] = V; Sync(); break;
	case 0xB005: creg[5] = V; Sync(); break;
	case 0xB006: creg[6] = V; Sync(); break;
	case 0xB007: creg[7] = V; Sync(); break;
	}
}

static void M65Power(void) {
	preg[2] = ~1;
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M65Write);
}

void  M65IRQ(int a) {
	if (IRQa) {
		IRQCount -= a;
		if (IRQCount < -4) {
			X6502_IRQBegin(FCEU_IQEXT);
			IRQa = 0;
			IRQCount = -1;
		}
	}
}

static void StateRestore(int version) {
	Sync();
}

void Mapper65_Init(CartInfo *info) {
	info->Power = M65Power;
	MapIRQHook = M65IRQ;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}

