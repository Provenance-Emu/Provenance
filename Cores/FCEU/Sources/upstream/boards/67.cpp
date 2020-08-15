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

static uint8 preg, creg[4], mirr, suntoggle = 0;
static uint8 IRQa;
static int16 IRQCount, IRQLatch;

static SFORMAT StateRegs[] =
{
	{ &preg, 1, "PREG" },
	{ &suntoggle, 1, "STOG" },
	{ creg, 4, "CREG" },
	{ &mirr, 1, "MIRR" },
	{ &IRQa, 1, "IRQA" },
	{ &IRQCount, 2, "IRQC" },
	{ &IRQLatch, 2, "IRQL" },
	{ 0 }
};

static void Sync(void) {
	setmirror(mirr);
	setprg16(0x8000, preg);
	setprg16(0xC000, ~0);
	setchr2(0x0000, creg[0]);
	setchr2(0x0800, creg[1]);
	setchr2(0x1000, creg[2]);
	setchr2(0x1800, creg[3]);
	switch (mirr) {
	case 0: setmirror(MI_V); break;
	case 1: setmirror(MI_H); break;
	case 2: setmirror(MI_0); break;
	case 3: setmirror(MI_1); break;
	}
}

static DECLFW(M67Write) {
	switch (A & 0xF800) {
	case 0x8800: creg[0] = V; Sync(); break;
	case 0x9800: creg[1] = V; Sync(); break;
	case 0xA800: creg[2] = V; Sync(); break;
	case 0xB800: creg[3] = V; Sync(); break;
	case 0xC000:
	case 0xC800:
		IRQCount &= 0xFF << (suntoggle << 3);
		IRQCount |= V << ((suntoggle ^ 1) << 3);
		suntoggle ^= 1;
		break;
	case 0xD800:
		suntoggle = 0;
		IRQa = V & 0x10;
		X6502_IRQEnd(FCEU_IQEXT);
		break;
	case 0xE800: mirr = V & 3; Sync(); break;
	case 0xF800: preg = V; Sync(); break;
	}
}

static void M67Power(void) {
	suntoggle = 0;
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M67Write);
}

void M67IRQ(int a) {
	if (IRQa) {
		IRQCount -= a;
		if (IRQCount <= 0) {
			X6502_IRQBegin(FCEU_IQEXT);
			IRQa = 0;
			IRQCount = -1;
		}
	}
}

static void StateRestore(int version) {
	Sync();
}

void Mapper67_Init(CartInfo *info) {
	info->Power = M67Power;
	MapIRQHook = M67IRQ;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}

