/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2006 CaH4e3
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
 * TXC mappers, originally much complex banksitching
 *
 * 01-22111-000 (05-00002-010) (132, 22211) - MGC-001 Qi Wang
 * 01-22110-000 (52S         )              - MGC-002 2-in-1 Gun
 * 01-22111-100 (02-00002-010) (173       ) - MGC-008 Mahjong Block
 *                             (079       ) - MGC-012 Poke Block
 * 01-22110-200 (05-00002-010) (036       ) - MGC-014 Strike Wolf
 * 01-22000-400 (05-00002-010) (036       ) - MGC-015 Policeman
 * 01-22017-000 (05-PT017-080) (189       ) - MGC-017 Thunder Warrior
 * 01-11160-000 (04-02310-000) (   , 11160) - MGC-023 6-in-1
 * 01-22270-000 (05-00002-010) (132, 22211) - MGC-xxx Creatom
 * 01-22200-400 (------------) (079       ) - ET.03   F-15 City War
 *                             (172       ) -         1991 Du Ma Racing
 *
 */

#include "mapinc.h"

static uint8 reg[4], cmd, is172, is173;
static SFORMAT StateRegs[] =
{
	{ reg, 4, "REGS" },
	{ &cmd, 1, "CMD" },
	{ 0 }
};

static void Sync(void) {
	setprg32(0x8000, (reg[2] >> 2) & 1);
	if (is172)
		setchr8((((cmd ^ reg[2]) >> 3) & 2) | (((cmd ^ reg[2]) >> 5) & 1));	// 1991 DU MA Racing probably CHR bank sequence is WRONG, so it is possible to
																			// rearrange CHR banks for normal UNIF board and mapper 172 is unneccessary
	else
		setchr8(reg[2] & 3);
}

static DECLFW(UNL22211WriteLo) {
//	FCEU_printf("bs %04x %02x\n",A,V);
	reg[A & 3] = V;
}

static DECLFW(UNL22211WriteHi) {
//	FCEU_printf("bs %04x %02x\n",A,V);
	cmd = V;
	Sync();
}

static DECLFR(UNL22211ReadLo) {
	return (reg[1] ^ reg[2]) | (is173 ? 0x01 : 0x40);
//	if(reg[3])
//		return reg[2];
//	else
//		return X.DB;
}

static void UNL22211Power(void) {
	Sync();
	SetReadHandler(0x8000, 0xFFFF, CartBR);
	SetReadHandler(0x4100, 0x4100, UNL22211ReadLo);
	SetWriteHandler(0x4100, 0x4103, UNL22211WriteLo);
	SetWriteHandler(0x8000, 0xFFFF, UNL22211WriteHi);
}

static void StateRestore(int version) {
	Sync();
}

void UNL22211_Init(CartInfo *info) {
	is172 = 0;
	is173 = 0;
	info->Power = UNL22211Power;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}

void Mapper172_Init(CartInfo *info) {
	is172 = 1;
	is173 = 0;
	info->Power = UNL22211Power;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}

void Mapper173_Init(CartInfo *info) {
	is172 = 0;
	is173 = 1;
	info->Power = UNL22211Power;
	GameStateRestore = StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}

