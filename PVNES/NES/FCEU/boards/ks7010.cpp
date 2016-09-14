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

static uint8 preg[4], creg, mirr;

static SFORMAT StateRegs[] =
{
	{ preg, 4, "PREG" },
	{ &creg, 1, "CREG" },
	{ &mirr, 1, "MIRR" },
	{ 0 }
};

static void Sync(void) {
	setprg8(0x6000, preg[0]);
	setprg8(0x8000, 0xa);
	setprg8(0xa000, 0xb);
	setprg8(0xc000, 0x6);
	setprg8(0xe000, 0x7);
	setchr8(0x0c);
	setmirror(mirr);
}

static DECLFW(UNLKS7010Write) {
	switch (A) {
	case 0x4025: mirr = (((V >> 3) & 1) ^ 1); Sync(); break;
	default:
		FCEU_printf("bs %04x %02x\n",A,V);
		break;
	}
}

static void UNLKS7010Reset(void) {
	preg[0]++;
	if(preg[0] == 0x10) {
		preg[0] = 0;
		preg[1]++;
		if(preg[1] == 0x10) {
			preg[1] = 0;
			preg[2]++;
		}
	}
	FCEU_printf("preg %02x %02x %02x\n",preg[0], preg[1], preg[2]);
	Sync();
}

static void UNLKS7010Power(void) {
	preg[0] = preg[1] = preg[2] = 0;
	Sync();
	SetReadHandler(0x6000, 0x7fff, CartBR);
	SetWriteHandler(0x6000, 0x7fff, CartBW);
	SetReadHandler(0x8000, 0xffff, CartBR);
	SetWriteHandler(0x4020, 0xffff, UNLKS7010Write);
}

static void StateRestore(int version) {
	Sync();
}

void UNLKS7010_Init(CartInfo *info) {
	info->Power = UNLKS7010Power;
	info->Reset = UNLKS7010Reset;

	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
