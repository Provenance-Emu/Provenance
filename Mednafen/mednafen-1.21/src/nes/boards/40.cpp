/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* 40.cpp - iNES Mapper 40 Emulation
**  Copyright (C) 2017 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include "mapinc.h"

namespace MDFN_IEN_NES
{

static uint32 IRQCounter;
static bool IRQEnable;
static uint8 PRGBank;

/*
 IRQ counter semantics here may be wrong.
*/
static MDFN_FASTCALL void IRQHook(int c)
{
 if(IRQEnable)
 {
  IRQCounter -= c;
  if((int32)IRQCounter < 0)
  {
#if 1
   IRQCounter = 4095;
   IRQEnable = false;
#else
   IRQCounter &= 4095;
#endif
   X6502_IRQBegin(MDFN_IQEXT);
  }
 }
}

template<unsigned region>
static DECLFW(Write)
{
 switch(region)
 {
  case 0:
	IRQEnable = false;
	IRQCounter = 4095;
	X6502_IRQEnd(MDFN_IQEXT);
	break;

  case 1:
	IRQEnable = true;
	break;

  case 2:
	break;

  case 3:
	PRGBank = V & 0x7;
	setprg8(0xC000, PRGBank);
	break;
 }
}


static void Power(CartInfo* info)
{
 setchr8(0);

 PRGBank = 0;
 setprg8(0x6000, 6);
 setprg8(0x8000, 4);
 setprg8(0xA000, 5);
 setprg8(0xC000, PRGBank);
 setprg8(0xE000, 7);

 IRQCounter = 4095;
 IRQEnable = false;
 X6502_IRQEnd(MDFN_IQEXT);
}

static int StateAction(StateMem* sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(PRGBank),
  SFVAR(IRQCounter),
  SFVAR(IRQEnable),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAPPER40");

 if(load)
 {
  IRQCounter &= 4095;
  PRGBank &= 0x7;
  setprg8(0xC000, PRGBank);
 }

 return true;
}

int Mapper40_Init(CartInfo* info)
{
 SetWriteHandler(0x8000, 0x9FFF, Write<0>);
 SetWriteHandler(0xA000, 0xBFFF, Write<1>);
 SetWriteHandler(0xC000, 0xDFFF, Write<2>);
 SetWriteHandler(0xE000, 0xFFFF, Write<3>);

 SetReadHandler(0x6000, 0xFFFF, CartBR);

 MapIRQHook = IRQHook;
 info->Power = Power;
 info->StateAction = StateAction;

 return true;
}

}
