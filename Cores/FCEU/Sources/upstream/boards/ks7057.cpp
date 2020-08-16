/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2011 CaH4e3
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
 * FDS Conversion
 *
 */

#include "mapinc.h"

static uint8 reg[8], mirror;
static SFORMAT StateRegs[] =
{
	{ reg, 8, "PRG" },
	{ &mirror, 1, "MIRR" },
	{ 0 }
};

static void Sync(void) {
	setprg2(0x6000, reg[4]);
	setprg2(0x6800, reg[5]);
	setprg2(0x7000, reg[6]);
	setprg2(0x7800, reg[7]);
	setprg2(0x8000, reg[0]);
	setprg2(0x8800, reg[1]);
	setprg2(0x9000, reg[2]);
	setprg2(0x9800, reg[3]);
	setprg8(0xA000, 0xd);
	setprg16(0xC000, 7);
	setchr8(0);
	setmirror(mirror);
}

static DECLFW(UNLKS7057Write) {
	switch (A & 0xF003) {
	case 0x8000:
	case 0x8001:
	case 0x8002:
	case 0x8003:
	case 0x9000:
	case 0x9001:
	case 0x9002:
	case 0x9003: mirror = V & 1; Sync(); break;
	case 0xB000: reg[0] = (reg[0] & 0xF0) | (V & 0x0F); Sync(); break;
	case 0xB001: reg[0] = (reg[0] & 0x0F) | (V << 4); Sync(); break;
	case 0xB002: reg[1] = (reg[1] & 0xF0) | (V & 0x0F); Sync(); break;
	case 0xB003: reg[1] = (reg[1] & 0x0F) | (V << 4); Sync(); break;
	case 0xC000: reg[2] = (reg[2] & 0xF0) | (V & 0x0F); Sync(); break;
	case 0xC001: reg[2] = (reg[2] & 0x0F) | (V << 4); Sync(); break;
	case 0xC002: reg[3] = (reg[3] & 0xF0) | (V & 0x0F); Sync(); break;
	case 0xC003: reg[3] = (reg[3] & 0x0F) | (V << 4); Sync(); break;
	case 0xD000: reg[4] = (reg[4] & 0xF0) | (V & 0x0F); Sync(); break;
	case 0xD001: reg[4] = (reg[4] & 0x0F) | (V << 4); Sync(); break;
	case 0xD002: reg[5] = (reg[5] & 0xF0) | (V & 0x0F); Sync(); break;
	case 0xD003: reg[5] = (reg[5] & 0x0F) | (V << 4); Sync(); break;
	case 0xE000: reg[6] = (reg[6] & 0xF0) | (V & 0x0F); Sync(); break;
	case 0xE001: reg[6] = (reg[6] & 0x0F) | (V << 4); Sync(); break;
	case 0xE002: reg[7] = (reg[7] & 0xF0) | (V & 0x0F); Sync(); break;
	case 0xE003: reg[7] = (reg[7] & 0x0F) | (V << 4); Sync(); break;
	}
}

static void UNLKS7057Power(void) {
	Sync();
	SetReadHandler(0x6000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, UNLKS7057Write);
}

static void UNLKS7057Reset(void) {
	Sync();
}

void UNLKS7057_Init(CartInfo *info) {
	info->Power = UNLKS7057Power;
	info->Reset = UNLKS7057Reset;
	AddExState(&StateRegs, ~0, 0, 0);
}
