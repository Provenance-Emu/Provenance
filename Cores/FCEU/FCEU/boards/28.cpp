/*
	Copyright (C) 2012 FCEUX team

	This file is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 2 of the License, or
	(at your option) any later version.

	This file is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with the this software.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "mapinc.h"

// http://wiki.nesdev.com/w/index.php/INES_Mapper_028

//config
static int prg_mask_16k;

// state
uint8 nes_reg;
uint8 chr;
uint8 prg;
uint8 mode;
uint8 outer;

void SyncMirror()
{
	switch (mode & 3)
	{
		case 0: setmirror(MI_0); break;
		case 1: setmirror(MI_1); break;
		case 2: setmirror(MI_V); break;
		case 3: setmirror(MI_H); break;
	}
}

void Mirror(uint8 value)
{
	if ((mode & 2) == 0)
	{
		mode &= 0xfe;
		mode |= value >> 4 & 1;
	}
	SyncMirror();
}


static void Sync()
{		
	int prglo;
	int prghi;

	int outb = outer << 1;
	//this can probably be rolled up, but i have no motivation to do so
	//until it's been tested
	switch (mode & 0x3c)
	{
		//32K modes
	case 0x00:
	case 0x04:
		prglo = outb;
		prghi = outb | 1;
		break;
	case 0x10:
	case 0x14:
		prglo = outb & ~2 | prg << 1 & 2;
		prghi = outb & ~2 | prg << 1 & 2 | 1;
		break;
	case 0x20:
	case 0x24:
		prglo = outb & ~6 | prg << 1 & 6;
		prghi = outb & ~6 | prg << 1 & 6 | 1;
		break;
	case 0x30:
	case 0x34:
		prglo = outb & ~14 | prg << 1 & 14;
		prghi = outb & ~14 | prg << 1 & 14 | 1;
		break;
		//bottom fixed modes
	case 0x08:
		prglo = outb;
		prghi = outb | prg & 1;
		break;
	case 0x18:
		prglo = outb;
		prghi = outb & ~2 | prg & 3;
		break;
	case 0x28:
		prglo = outb;
		prghi = outb & ~6 | prg & 7;
		break;
	case 0x38:
		prglo = outb;
		prghi = outb & ~14 | prg & 15;
		break;
		//top fixed modes
	case 0x0c:
		prglo = outb | prg & 1;
		prghi = outb | 1;
		break;
	case 0x1c:
		prglo = outb & ~2 | prg & 3;
		prghi = outb | 1;
		break;
	case 0x2c:
		prglo = outb & ~6 | prg & 7;
		prghi = outb | 1;
		break;
	case 0x3c:
		prglo = outb & ~14 | prg & 15;
		prghi = outb | 1;
		break;
	}
	prglo &= prg_mask_16k;
	prghi &= prg_mask_16k;

	setprg16(0x8000, prglo);
	setprg16(0xC000, prghi);
	setchr8(chr);
}

static DECLFW(WriteEXP)
{
	uint32 addr = A;
	uint8 value = V;
	nes_reg = value & 0x81;
}

static DECLFW(WritePRG)
{
	uint32 addr = A;
	uint8 value = V;
	switch (nes_reg)
	{
	case 0x00:
		chr = value & 3;
		Mirror(value);
		break;
	case 0x01:
		prg = value & 15;
		Mirror(value);
		Sync();
		break;
	case 0x80:
		mode = value & 63;
		SyncMirror();
		Sync();
		break;
	case 0x81:
		outer = value & 63;
		Sync();
		break;
	}
}



static void M28Reset(void)
{
	outer = 63;
	prg = 15;
	Sync();
}


static void M28Power(void)
{
	prg_mask_16k = PRGsize[0] - 1;

	//EXP
	SetWriteHandler(0x5000,0x5FFF,WriteEXP);
  
	//PRG
	SetWriteHandler(0x8000,0xFFFF,WritePRG);
	SetReadHandler(0x8000,0xFFFF,CartBR);
	
	//WRAM
  SetReadHandler(0x6000,0x7FFF,CartBR);
  SetWriteHandler(0x6000,0x7FFF,CartBW);

	M28Reset();
}

static void M28Close(void)
{
}

static SFORMAT StateRegs[]=
{
	{&nes_reg, 1, "REG"},
	{&chr, 1, "CHR"},
	{&prg, 1, "PRG"},
	{&mode, 1, "MODE"},
	{&outer, 1, "OUTR"},
	{0}
};

static void StateRestore(int version)
{
	Sync();
}

void Mapper28_Init(CartInfo* info)
{
	info->Power=M28Power;
	info->Reset=M28Reset;
	info->Close=M28Close;
	GameStateRestore=StateRestore;
	AddExState(&StateRegs, ~0, 0, 0);
}
