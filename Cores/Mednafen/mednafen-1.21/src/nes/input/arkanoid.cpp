/* Mednafen - Multi-system Emulator
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
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include	"share.h"

namespace MDFN_IEN_NES
{

typedef struct {
	uint32 mzx,mzb;
	uint32 readbit;
} ARK;

static ARK NESArk[2];
static ARK FCArk;

static void StrobeARKFC(void)
{
	FCArk.readbit=0;
}


static uint8 ReadARKFC(int w,uint8 ret)
{
 ret&=~2;

 if(w)  
 {
  if(FCArk.readbit>=8) 
   ret|=2;
  else
  {
   ret|=((FCArk.mzx>>(7-FCArk.readbit))&1)<<1;
   if(!fceuindbg)
    FCArk.readbit++;
  }
 }
 else
  ret|=FCArk.mzb<<1;
 return(ret);
}

static uint32 FixX(uint32 in_x)
{
 int32 x;

 x = (int32)in_x + 98 - 32;

 if(x < 98)
  x = 98;

 if(x > 242)
  x = 242;

 x=~x;
 return(x);
}

static void UpdateARKFC(void *data)
{
 uint8 *ptr = (uint8*)data;

 FCArk.mzx = FixX((int16)MDFN_de16lsb(ptr + 0));
 FCArk.mzb = (bool)ptr[2];
}

static void StateAction(int w, StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
   SFVAR(NESArk[w].mzx),
   SFVAR(NESArk[w].mzb),
   SFVAR(NESArk[w].readbit),
   SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, w ? "INP1" : "INP0", true);

 if(load)
 {

 }
}

static void StateActionFC(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
   SFVAR(FCArk.mzx),
   SFVAR(FCArk.mzb),
   SFVAR(FCArk.readbit),
   SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "INPF", true);

 if(load)
 {

 }
}


static INPUTCFC ARKCFC={ReadARKFC,0,StrobeARKFC,UpdateARKFC,0,0, StateActionFC };

INPUTCFC *MDFN_InitArkanoidFC(void)
{
 FCArk.mzx=98;
 FCArk.mzb=0;
 return(&ARKCFC);
}

static uint8 ReadARK(int w)
{
 uint8 ret=0;

 if(NESArk[w].readbit>=8)
  ret|=1<<4;
 else
 {
  ret|=((NESArk[w].mzx>>(7-NESArk[w].readbit))&1)<<4;
  if(!fceuindbg)
   NESArk[w].readbit++;
 }
 ret|=(NESArk[w].mzb&1)<<3;
 return(ret);
}


static void StrobeARK(int w)
{
	NESArk[w].readbit=0;
}

static void UpdateARK(int w, void *data)
{
 uint8 *ptr = (uint8*)data;

 NESArk[w].mzx = FixX((int16)MDFN_de16lsb(ptr + 0));
 NESArk[w].mzb = (bool)ptr[2];
}

static INPUTC ARKC={ReadARK, 0, StrobeARK, UpdateARK, 0, 0, StateAction };

INPUTC *MDFN_InitArkanoid(int w)
{
 NESArk[w].mzx=98;
 NESArk[w].mzb=0;
 return(&ARKC);
}

}
