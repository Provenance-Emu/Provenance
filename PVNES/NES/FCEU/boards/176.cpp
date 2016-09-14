/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
 *  Copyright (C) 2012 FCEUX team
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

extern uint32 ROM_size;

static uint8 prg[4], chr, sbw, we_sram;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[]=
{
  {prg, 4, "PRG"},
  {&chr, 1, "CHR"},
  {&sbw, 1, "SBW"},
  {0}
};

static void Sync(void)
{
  setprg8r(0x10,0x6000,0);
	setprg8(0x8000,prg[0]);
	setprg8(0xA000,prg[1]);
	setprg8(0xC000,prg[2]);
	setprg8(0xE000,prg[3]);

  setchr8(chr);
}

static DECLFW(M176Write_5001)
{
	printf("%04X = $%02X\n",A,V);
	if(sbw)
	{
		prg[0] = V*4;
		prg[1] = V*4+1;
		prg[2] = V*4+2;
		prg[3] = V*4+3;
	}
  Sync();
}

static DECLFW(M176Write_5010)
{
	printf("%04X = $%02X\n",A,V);
	if(V == 0x24) sbw = 1;
  Sync();
}

static DECLFW(M176Write_5011)
{
	printf("%04X = $%02X\n",A,V);
	V >>= 1;
	if(sbw)
	{
		prg[0] = V*4;
		prg[1] = V*4+1;
		prg[2] = V*4+2;
		prg[3] = V*4+3;
	}
  Sync();
}

static DECLFW(M176Write_5FF1)
{
	printf("%04X = $%02X\n",A,V);
  V >>= 1;
	prg[0] = V*4;
	prg[1] = V*4+1;
	prg[2] = V*4+2;
	prg[3] = V*4+3;
  Sync();
}

static DECLFW(M176Write_5FF2)
{
	printf("%04X = $%02X\n",A,V);
  chr = V;
  Sync();
}

static DECLFW(M176Write_A001)
{
	we_sram = V & 0x03;
}

static DECLFW(M176Write_WriteSRAM)
{
//	if(we_sram)
		CartBW(A,V);
}

static void M176Power(void)
{
	SetReadHandler(0x6000,0x7fff,CartBR);
	SetWriteHandler(0x6000,0x7fff,M176Write_WriteSRAM);
	SetReadHandler(0x8000,0xFFFF,CartBR);
	SetWriteHandler(0xA001,0xA001,M176Write_A001);
	SetWriteHandler(0x5001,0x5001,M176Write_5001);
	SetWriteHandler(0x5010,0x5010,M176Write_5010);
	SetWriteHandler(0x5011,0x5011,M176Write_5011);
	SetWriteHandler(0x5ff1,0x5ff1,M176Write_5FF1);
	SetWriteHandler(0x5ff2,0x5ff2,M176Write_5FF2);
	FCEU_CheatAddRAM(WRAMSIZE >> 10, 0x6000, WRAM);

	we_sram = 0;
	sbw = 0;
	prg[0] = 0;
	prg[1] = 1;
	prg[2] = (ROM_size-2)&63;
	prg[3] = (ROM_size-1)&63;
  Sync();
}


static void M176Close(void)
{
  if(WRAM)
    FCEU_gfree(WRAM);
  WRAM = NULL;
}

static void StateRestore(int version)
{
  Sync();
}

void Mapper176_Init(CartInfo *info)
{
  info->Power=M176Power;
  info->Close=M176Close;

  GameStateRestore=StateRestore;

  WRAMSIZE=8192;
  WRAM=(uint8*)FCEU_gmalloc(WRAMSIZE);
  SetupCartPRGMapping(0x10,WRAM,WRAMSIZE,1);
  AddExState(WRAM, WRAMSIZE, 0, "WRAM");
  AddExState(&StateRegs, ~0, 0, 0);
}
