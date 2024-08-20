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

#include        "share.h"

namespace MDFN_IEN_NES
{

struct SPACE_SHADOW
{
        uint32 mzx,mzy,mzb;
        int bogo;
        uint64 zaphit;
};

static SPACE_SHADOW ZD;

static void ShadowLinehook(uint8 *bg, uint32 linets, int final)
{
 int xs,xe;   
 int zx,zy;
 
 xs=linets; 
 xe=final;

 zx=ZD.mzx;
 zy=ZD.mzy;
 
 if(xe>256) xe=256;
 
 if(scanline>=(zy-6) && scanline<=(zy+6))
 {
  int32 sum = 0;

  while(xs<xe)
  {
   uint8 a1;
   if(xs<=(zx+7) && xs>=(zx-7))
   {
    a1=bg[xs] & 0x3F;
    sum += (((ActiveNESPalette[a1].r+ActiveNESPalette[a1].g+ActiveNESPalette[a1].b) << 8) - sum) >> 2;

    if(sum >= 256 * 220*3)
    {
     //puts("K");
     ZD.zaphit=timestampbase + timestamp;
     goto endo;
    }
   }
   xs++;
  }
 }
 endo: ;
}

static INLINE int CheckColor(void)
{ 
 MDFNPPU_LineUpdate();
 
 if((ZD.zaphit+10)>=(timestampbase+timestamp) && !(ZD.mzb & 0x2))
  return(0);
 
 return(1);   
}


static uint8 ReadShadow(int w, uint8 ret)
{
		if(w)
		{
		 ret&=~0x18;
                 if(ZD.bogo)
                  ret|=0x10;
                 if(CheckColor())
                  ret|=0x8;
		}
		else
		{
		 ret&=~2;
		 ret|=(ret&1)<<1;
		}
                return ret;
}

static void DrawShadow(uint8 *pix, int pix_y)
{
 NESCURSOR_DrawGunSight(1, pix, pix_y, ZD.mzx, ZD.mzy);
}

static void UpdateShadow(void *data)
{
  uint8 *ptr=(uint8*)data;

  if(ZD.bogo)
   ZD.bogo--;

  if((ptr[4] & 0x3) && !(ZD.mzb & 0x3))
   ZD.bogo=5;

  ZD.mzx = (int16)MDFN_de16lsb(ptr + 0);
  ZD.mzy = (int16)MDFN_de16lsb(ptr + 2);
  ZD.mzb=ptr[4];
}

static void StrobeShadow(void)
{

}

static void StateActionFC(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(ZD.mzx),
  SFVAR(ZD.mzy),
  SFVAR(ZD.mzb),
  SFVAR(ZD.bogo),
  SFVAR(ZD.zaphit),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "INPF", true);

 if(load)
 {

 }
}

static INPUTCFC SHADOWC = { ReadShadow, 0, StrobeShadow, UpdateShadow, ShadowLinehook, DrawShadow, StateActionFC };

INPUTCFC *MDFN_InitSpaceShadow(void)
{
  memset(&ZD, 0, sizeof(SPACE_SHADOW));
  return(&SHADOWC);
}

}
