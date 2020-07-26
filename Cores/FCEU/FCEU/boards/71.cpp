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
 */

#include "mapinc.h"

static uint8 preg, mirr;

static SFORMAT StateRegs[] =
{
	{ &preg, 1, "PREG" },
	{ &mirr, 1, "MIRR" },
	{ 0 }
};

static void Sync(void) {
	setprg16(0x8000, preg);
	setprg16(0xC000, ~0);
	setchr8(0);
	if(mirr)
		setmirror(mirr);
}

static DECLFW(M71Write) {
	if ((A & 0xF000) == 0x9000)
		mirr = MI_0 + ((V >> 4) & 1);   // 2-in-1, some carts are normal hardwire V/H mirror, some uses mapper selectable 0/1 mirror
	else
		preg = V;
	Sync();
}

static void M71Power(void) {
	mirr = 0;
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x8000, 0xFFFF, M71Write);
}

static void StateRestore(int version) {
	Sync();
}

void Mapper71_Init(CartInfo *info) {
	info->Power = M71Power;
	GameStateRestore = StateRestore;

	AddExState(&StateRegs, ~0, 0, 0);
}
