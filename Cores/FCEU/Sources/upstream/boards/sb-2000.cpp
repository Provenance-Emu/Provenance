/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2014 CaH4e3
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

static uint8 preg[8];
static uint8 IRQa;
static int16 IRQCount, IRQLatch;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;
/*
static uint8 *CHRRAM = NULL;
static uint32 CHRRAMSIZE;
*/

static SFORMAT StateRegs[] =
{
	{ preg, 8, "PREG" },
	{ &IRQa, 1, "IRQA" },
	{ &IRQCount, 2, "IRQC" },
	{ &IRQLatch, 2, "IRQL" },
	{ 0 }
};

static void Sync(void) {
	setchr8(0);
	setprg8r(0x10, 0x6000, 0);
	if(preg[0] & 0x80)
		setprg4r(0x10,0x8000,preg[0] & 0x7f);
	else
		setprg4(0x8000,preg[0] & 0x7f);
	if(preg[1] & 0x80)
		setprg4r(0x10,0x9000,preg[1] & 0x7f);
	else
		setprg4(0x9000,preg[1] & 0x7f);
	if(preg[2] & 0x80)
		setprg4r(0x10,0xa000,preg[2] & 0x7f);
	else
		setprg4(0xa000,preg[2] & 0x7f);
	if(preg[3] & 0x80)
		setprg4r(0x10,0xb000,preg[3] & 0x7f);
	else
		setprg4(0xb000,preg[3] & 0x7f);
/*
	if(preg[4] & 0x80)
		setprg4r(0x10,0xc000,preg[4] & 0x7f);
	else
		setprg4(0xc000,preg[4] & 0x7f);
	if(preg[5] & 0x80)
		setprg4r(0x10,0xd000,preg[5] & 0x7f);
	else
		setprg4(0xd000,preg[5] & 0x7f);
	if(preg[6] & 0x80)
		setprg4r(0x10,0xe000,preg[6] & 0x7f);
	else
		setprg4(0xe000,preg[6] & 0x7f);
	if(preg[7] & 0x80)
		setprg4r(0x10,0xf000,preg[7] & 0x7f);
	else
		setprg4(0xf000,preg[7] & 0x7f);
*/
	setprg16(0xC000,1);
}

static DECLFR(UNLSB2000Read) {
	switch(A) {
	case 0x4033:	// IRQ flags
	    X6502_IRQEnd(FCEU_IQFCOUNT);
		return 0xff;
//	case 0x4204:	// unk
//		return 0xff;
//	case 0x4205:	// unk
//		return 0xff;
	default:
		FCEU_printf("unk read: %04x\n",A);
//		break;
		return 0xff; // needed to prevent C4715 warning?
	}
}

static DECLFW(UNLSB2000Write) {
	switch(A) {
	case 0x4027:	// PCM output
		BWrite[0x4015](0x4015, 0x10);
		BWrite[0x4011](0x4011, V >> 1);
		break;
	case 0x4032:	// IRQ mask
		IRQa &= ~V;
//		X6502_IRQEnd(FCEU_IQEXT);
		break;
	case 0x4040:
	case 0x4041:
	case 0x4042:
	case 0x4043:
	case 0x4044:
	case 0x4045:
	case 0x4046:
	case 0x4047:
//		FCEU_printf("bank write: %04x:%02x\n",A,V);
		preg[A&7] = V;
		Sync();
		break;
	default:
//		FCEU_printf("unk write: %04x:%02x\n",A,V);
		break;
	}
}

static void UNLSB2000Reset(void) {
	preg[0] = 0;
	preg[1] = 1;
	preg[2] = 2;
	preg[3] = 3;
	preg[4] = 4;
	preg[5] = 5;
	preg[6] = 6;
	preg[7] = 7;
	IRQa = 0;
//	BWrite[0x4017](0x4017,0xC0);
//	BWrite[0x4015](0x4015,0x1F);
}

static void UNLSB2000Power(void) {
	UNLSB2000Reset();
	Sync();
	SetReadHandler(0x6000, 0x7fff, CartBR);
	SetWriteHandler(0x6000, 0x7fff, CartBW);
	SetReadHandler(0x8000, 0xffff, CartBR);
	SetWriteHandler(0x8000, 0xbfff, CartBW);
	SetWriteHandler(0x4020, 0x5fff, UNLSB2000Write);
	SetReadHandler(0x4020, 0x5fff, UNLSB2000Read);
}

static void UNLSB2000Close(void)
{
	if (WRAM)
		FCEU_gfree(WRAM);
/*
	if (CHRRAM)
		FCEU_gfree(CHRRAM);
*/
	WRAM = /*CHRRAM = */NULL;
}
/*
static void UNLSB2000IRQHook() {
	X6502_IRQBegin(FCEU_IQEXT);
}
*/
static void StateRestore(int version) {
	Sync();
}

void UNLSB2000_Init(CartInfo *info) {
	info->Reset = UNLSB2000Reset;
	info->Power = UNLSB2000Power;
	info->Close = UNLSB2000Close;
//	GameHBIRQHook = UNLSB2000IRQHook;
	GameStateRestore = StateRestore;
/*
	CHRRAMSIZE = 8192;
	CHRRAM = (uint8*)FCEU_gmalloc(CHRRAMSIZE);
	SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSIZE, 1);
	AddExState(CHRRAM, CHRRAMSIZE, 0, "CRAM");
*/

//	SetupCartCHRMapping(0, PRGptr[0], PRGsize[0], 0);

	WRAMSIZE = 512 * 1024;
	WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
	SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
	AddExState(WRAM, WRAMSIZE, 0, "WRAM");
	if (info->battery) {
		info->SaveGame[0] = WRAM;
		info->SaveGameLen[0] = WRAMSIZE;
	}

	AddExState(&StateRegs, ~0, 0, 0);
}
