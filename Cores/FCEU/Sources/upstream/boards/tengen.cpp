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

#include "mapinc.h"

static uint8 cmd, mirr, regs[11];
static uint8 rmode, IRQmode, IRQCount, IRQa, IRQLatch;

static SFORMAT StateRegs[] = {
	{ regs, 11, "REGS" },
	{ &cmd, 1, "CMDR" },
	{ &mirr, 1, "MIRR" },
	{ &rmode, 1, "RMOD" },
	{ &IRQmode, 1, "IRQM" },
	{ &IRQCount, 1, "IRQC" },
	{ &IRQa, 1, "IRQA" },
	{ &IRQLatch, 1, "IRQL" },
	{ 0 }
};

static void M64IRQHook(int a) {
	static int32 smallcount;
	if (IRQmode) {
		smallcount += a;
		while (smallcount >= 4) {
			smallcount -= 4;
			IRQCount--;
			if (IRQCount == 0xFF)
				if (IRQa) X6502_IRQBegin(FCEU_IQEXT);
		}
	}
}

static void M64HBHook(void) {
	if ((!IRQmode) && (scanline != 240)) {
		rmode = 0;
		IRQCount--;
		if (IRQCount == 0xFF) {
			if (IRQa) {
				rmode = 1;
				X6502_IRQBegin(FCEU_IQEXT);
			}
		}
	}
}

static void Sync(void) {
	if (cmd & 0x20) {
		setchr1(0x0000, regs[0]);
		setchr1(0x0400, regs[8]);
		setchr1(0x0800, regs[1]);
		setchr1(0x0C00, regs[9]);
	} else {
		setchr2(0x0000, regs[0] >> 1);
		setchr2(0x0800, regs[1] >> 1);
	}
	setchr1(0x1000, regs[2]);
	setchr1(0x1400, regs[3]);
	setchr1(0x1800, regs[4]);
	setchr1(0x1C00, regs[5]);
	setprg8(0x8000, regs[6]);
	setprg8(0xA000, regs[7]);
	setprg8(0xC000, regs[10]);
	setprg8(0xE000, ~0);
	setmirror(mirr);
}

static DECLFW(M64Write) {
	switch (A & 0xF001) {
	case 0xA000: mirr = (V & 1) ^ 1; Sync(); break;\
	case 0x8000: cmd = V; break;
	case 0x8001:
		if ((cmd & 0xF) < 10)
			regs[cmd & 0xF] = V;
		else if ((cmd & 0xF) == 0xF)
			regs[10] = V;
		Sync();
		break;
	case 0xC000:
		IRQLatch = V;
		if (rmode == 1)
			IRQCount = IRQLatch;
		break;
	case 0xC001:
		rmode = 1;
		IRQCount = IRQLatch;
		IRQmode = V & 1;
		break;
	case 0xE000:
		IRQa = 0;
		X6502_IRQEnd(FCEU_IQEXT);
		if (rmode == 1)
			IRQCount = IRQLatch;
		break;
	case 0xE001:
		IRQa = 1;
		if (rmode == 1)
			IRQCount = IRQLatch;
		break;
	}
}

static void M64Power(void) {
	cmd = mirr = 0;
	regs[0] = regs[1] = regs[2] = regs[3] = regs[4] = regs[5] = ~0;
	regs[6] = regs[7] = regs[8] = regs[9] = regs[10] = ~0;
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M64Write);
}

static void StateRestore(int version) {
	Sync();
}

void Mapper64_Init(CartInfo *info) {
	info->Power = M64Power;
	GameHBIRQHook = M64HBHook;
	MapIRQHook = M64IRQHook;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
