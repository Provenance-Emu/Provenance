/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2009 CaH4e3
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

static uint8 reg[8];
static uint32 lastnt = 0;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ reg, 2, "REG" },
	{ &lastnt, 4, "LNT" },
	{ 0 }
};

static uint8 bs_tbl[128] = {
	0x03, 0x13, 0x23, 0x33, 0x03, 0x13, 0x23, 0x33, 0x03, 0x13, 0x23, 0x33, 0x03, 0x13, 0x23, 0x33, // 00
	0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, // 10
	0x03, 0x13, 0x23, 0x33, 0x03, 0x13, 0x23, 0x33, 0x03, 0x13, 0x23, 0x33, 0x03, 0x13, 0x23, 0x33, // 20
	0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, // 30
	0x02, 0x12, 0x22, 0x32, 0x02, 0x12, 0x22, 0x32, 0x02, 0x12, 0x22, 0x32, 0x02, 0x12, 0x22, 0x32, // 40
	0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, // 50
	0x02, 0x12, 0x22, 0x32, 0x02, 0x12, 0x22, 0x32, 0x02, 0x12, 0x22, 0x32, 0x00, 0x10, 0x20, 0x30, // 60
	0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, // 70
};

static uint8 br_tbl[16] = {
	0x00, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02,
};

static void Sync(void) {
	setchr8(0);
	setprg8r(0x10, 0x6000, 0);
	if(PRGsize[0] == 512 * 1024) {
		if(reg[0] & 0x010) {
			setprg32(0x8000, reg[0] & 7);
		} else {
			if(reg[0] & 0x40)
				setprg8(0x8000, (reg[0] & 0x0F) | 0x20 | ((reg[0] & 0x20) >> 1));
		}
		if((reg[0] & 0x18) == 0x18)
			setmirror(MI_H);
		else
			setmirror(MI_V);
	} else {
		setprg16(0x8000, bs_tbl[reg[0] & 0x7f] >> 4);
		setprg16(0xc000, bs_tbl[reg[0] & 0x7f] & 0xf);
		setmirror(MI_V);
	}
}

static DECLFW(UNLPEC586Write) {
	reg[(A & 0x700) >> 8] = V;
	PEC586Hack = (reg[0] & 0x80) >> 7;
//	FCEU_printf("bs %04x %02x\n", A, V);
	Sync();
}

static DECLFR(UNLPEC586Read) {
//	FCEU_printf("read %04x\n", A);
	return (X.DB & 0xD8) | br_tbl[reg[4] >> 4];
}

static DECLFR(UNLPEC586ReadHi) {
	if((reg[0] & 0x10) || ((reg[0] & 0x40) && (A < 0xA000)))
		return CartBR(A);
	else
		return PRGptr[0][((0x0107 | ((A >> 7) & 0x0F8)) << 10) | (A & 0x3FF)];
}

static void UNLPEC586Power(void) {
	if(PRGsize[0] == 512 * 1024)
		reg[0] = 0x00;
	else
		reg[0] = 0x0E;
	Sync();
	SetReadHandler(0x6000, 0x7FFF, CartBR);
	SetWriteHandler(0x6000, 0x7FFF, CartBW);
	if(PRGsize[0] == 512 * 1024)
		SetReadHandler(0x8000, 0xFFFF, UNLPEC586ReadHi);
	else
		SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetWriteHandler(0x5000, 0x5fff, UNLPEC586Write);
	SetReadHandler(0x5000, 0x5fff, UNLPEC586Read);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);
}

static void UNLPEC586Close(void) {
	if (WRAM)
		FCEU_gfree(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void UNLPEC586Init(CartInfo *info) {
	info->Power = UNLPEC586Power;
	info->Close = UNLPEC586Close;
	GameStateRestore = StateRestore;

	WRAMSIZE = 8192;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");

	AddExState(&StateRegs, ~0, 0, 0);
}
