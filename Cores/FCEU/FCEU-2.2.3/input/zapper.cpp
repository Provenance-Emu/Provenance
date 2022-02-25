/* FCE Ultra - NES/Famicom Emulator
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
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include <string.h>
#include <stdlib.h>

#include "share.h"
#include "zapper.h"
#include "../movie.h"

ZAPPER ZD[2];

static void ZapperFrapper(int w, uint8 *bg, uint8 *spr, uint32 linets, int final)
{
	int xs,xe;
	int zx,zy;

	if(!bg) // New line, so reset stuff.
	{
		ZD[w].zappo=0;
		return;
	}
	xs=ZD[w].zappo;
	xe=final;

	zx=ZD[w].mzx;
	zy=ZD[w].mzy;

	if(xe>256) xe=256;

	if(scanline>=(zy-4) && scanline<=(zy+4))
	{
		while(xs<xe)
		{
			uint8 a1,a2;
			uint32 sum;
			if(xs<=(zx+4) && xs>=(zx-4))
			{
				a1=bg[xs];
				if(spr)
				{
					a2=spr[xs];

					if(!(a2&0x80))
						if(!(a2&0x40) || (a1&64))
							a1=a2;
				}
				a1&=63;

				sum=palo[a1].r+palo[a1].g+palo[a1].b;
				if(sum>=100*3)
				{
					ZD[w].zaphit=((uint64)linets+(xs+16)*(PAL?15:16))/48+timestampbase; 
					goto endo;
				}
			}   
			xs++;
		}
	}
endo:
	ZD[w].zappo=final;

    //if this was a miss, clear out the hit
    if(ZD[w].mzb&2)
        ZD[w].zaphit=0;
        
}      

static INLINE int CheckColor(int w)
{
	FCEUPPU_LineUpdate();

    if(newppu)
    {
        int x = (int)ZD[w].mzx;
        int y = (int)ZD[w].mzy;
        int b = (int)ZD[w].mzb;
        bool  block = (b&2)!=0;

        int mousetime = y*256+x;
        int nowtime = scanline*256 + g_rasterpos;

        if(!block && mousetime < nowtime && mousetime >= nowtime - 384)
        {
            extern uint8 *XBuf;
            uint8 *pix = XBuf+(ZD[w].mzy<<8);
            uint8 a1 = pix[ZD[w].mzx];
            a1&=63;
            uint32 sum=palo[a1].r+palo[a1].g+palo[a1].b;
            //return ZD[w].zaphit = sum != 0;
            ZD[w].zaphit = (sum>=100*3)?1:0;
        }
        else
        {
            ZD[w].zaphit = 0;
        }

        return ZD[w].zaphit?0:1;
    }


    if((ZD[w].zaphit+100)>=(timestampbase+timestamp))
    {
        return 0;
    }

	return 1;
}

static uint8 ReadZapperVS(int w)
{
	uint8 ret=0;

	if(ZD[w].zap_readbit==4) ret=1;

	if(ZD[w].zap_readbit==7)
	{
		if(ZD[w].bogo)
			ret|=0x1;
	}
	if(ZD[w].zap_readbit==6)
	{
		if(!CheckColor(w))
			ret|=0x1;
	}
	if(!fceuindbg)
		ZD[w].zap_readbit++; 
	return ret;
}

static void StrobeZapperVS(int w)
{                        
	ZD[w].zap_readbit=0;
}

static uint8 ReadZapper(int w)
{
	uint8 ret=0;
	if(ZD[w].bogo)
		ret|=0x10;
	if(CheckColor(w))
		ret|=0x8;
	return ret;
}

static void DrawZapper(int w, uint8 *buf, int arg)
{
	FCEU_DrawGunSight(buf, ZD[w].mzx,ZD[w].mzy);
}

static void UpdateZapper(int w, void *data, int arg)
{
	uint32 *ptr=(uint32 *)data;

    bool newclicked = (ptr[2]&3)!=0;
    bool oldclicked = (ZD[w].lastInput)!=0;

	if(ZD[w].bogo)
    {
		ZD[w].bogo--;	
    }

    ZD[w].lastInput = ptr[2]&3;

    //woah.. this looks like broken bit logic.
	if(newclicked && !oldclicked)
    {
		ZD[w].bogo=5;
	    ZD[w].mzb=ptr[2];
	    ZD[w].mzx=ptr[0];
	    ZD[w].mzy=ptr[1];
    }

}

static void LogZapper(int w, MovieRecord* mr)
{
	mr->zappers[w].x = ZD[w].mzx;
	mr->zappers[w].y = ZD[w].mzy;
	mr->zappers[w].b = ZD[w].mzb;
	mr->zappers[w].bogo = ZD[w].bogo;
	mr->zappers[w].zaphit = ZD[w].zaphit;
}

static void LoadZapper(int w, MovieRecord* mr)
{
	ZD[w].mzx = mr->zappers[w].x;
	ZD[w].mzy = mr->zappers[w].y;
	ZD[w].mzb = mr->zappers[w].b;
	ZD[w].bogo = mr->zappers[w].bogo;
	ZD[w].zaphit = mr->zappers[w].zaphit;
}


static INPUTC ZAPC={ReadZapper,0,0,UpdateZapper,ZapperFrapper,DrawZapper,LogZapper,LoadZapper};
static INPUTC ZAPVSC={ReadZapperVS,0,StrobeZapperVS,UpdateZapper,ZapperFrapper,DrawZapper,LogZapper,LoadZapper};

INPUTC *FCEU_InitZapper(int w)
{
	memset(&ZD[w],0,sizeof(ZAPPER));
	if(GameInfo->type == GIT_VSUNI)
		return(&ZAPVSC);
	else
		return(&ZAPC);
}


