/******************************************************************************/
/* Mednafen WonderSwan Emulation Module(based on Cygne)                       */
/******************************************************************************/
/* gfx.cpp:
**  Copyright (C) 2002 Dox dox@space.pl
**  Copyright (C) 2007-2017 Mednafen Team
**  Copyright (C) 2016 Alex 'trap15' Marshall - http://daifukkat.su/
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License version 2.
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

#include "wswan.h"
#include "gfx.h"
#include "memory.h"
#include "v30mz.h"
#include "rtc.h"
#include "comm.h"
#include <mednafen/video.h>
#include <trio/trio.h>

namespace MDFN_IEN_WSWAN
{

static uint32 wsMonoPal[16][4];
static uint32 wsColors[8];
static uint32 wsCols[16][16];

static uint32 ColorMapG[16];
static uint32 ColorMap[16*16*16];
static uint32 LayerEnabled;

static uint8 wsLine;                 /*current scanline*/
static uint8 weppy;

static uint8 SpriteTable[2][0x80][4];
static uint32 SpriteCountCache[2];
static bool FrameWhichActive;
static uint8 DispControl;
static uint8 BGColor;
static uint8 LineCompare;
static uint8 SPRBase;
static uint8 SpriteStart, SpriteCount;
static uint8 FGBGLoc;
static uint8 FGx0, FGy0, FGx1, FGy1;
static uint8 SPRx0, SPRy0, SPRx1, SPRy1;

static uint8 BGXScroll, BGYScroll;
static uint8 FGXScroll, FGYScroll;
static uint8 LCDControl, LCDIcons;
static uint8 LCDVtotal;

static uint8 BTimerControl;
static uint16 HBTimerPeriod;
static uint16 VBTimerPeriod;

static uint16 HBCounter, VBCounter;
static uint8 VideoMode;

#ifdef WANT_DEBUGGER

enum
{
 GFX_GSREG_DISPCONTROL = 0,
 GFX_GSREG_VIDEOMODE,
 GFX_GSREG_LCDCONTROL,
 GFX_GSREG_LCDICONS,
 GFX_GSREG_LCDVTOTAL,
 GFX_GSREG_BTIMERCONTROL,
 GFX_GSREG_HBTIMERPERIOD,
 GFX_GSREG_VBTIMERPERIOD,
 GFX_GSREG_HBCOUNTER,
 GFX_GSREG_VBCOUNTER,
 GFX_GSREG_BGCOLOR,
 GFX_GSREG_LINECOMPARE,
 GFX_GSREG_SPRBASE,
 GFX_GSREG_SPRITESTART,
 GFX_GSREG_SPRITECOUNT,

 GFX_GSREG_FGBGLOC,
 GFX_GSREG_FGX0,
 GFX_GSREG_FGY0,
 GFX_GSREG_FGX1,
 GFX_GSREG_FGY1,
 GFX_GSREG_SPRX0,
 GFX_GSREG_SPRY0,
 GFX_GSREG_SPRX1,
 GFX_GSREG_SPRY1,

 GFX_GSREG_BGXSCROLL,
 GFX_GSREG_BGYSCROLL,
 GFX_GSREG_FGXSCROLL,
 GFX_GSREG_FGYSCROLL
};

static const RegType WSwanGfxRegs[] =
{
 { GFX_GSREG_DISPCONTROL, "DispControl", "Display Control", 1 },
 { GFX_GSREG_VIDEOMODE, "VideoMode", "Video Mode", 1 },
 { GFX_GSREG_LCDCONTROL, "LCDControl", "LCD Control", 1 },
 { GFX_GSREG_LCDICONS, "LCDIcons", "LCD Icons", 1 },
 { GFX_GSREG_LCDVTOTAL, "LCDVtotal", "LCD Vtotal", 1 },
 { GFX_GSREG_BTIMERCONTROL, "BTimerControl", "VB/HB Timer Control", 1 },
 { GFX_GSREG_HBTIMERPERIOD, "HBTimerPeriod", "Horizontal blank timer counter period", 2 },
 { GFX_GSREG_VBTIMERPERIOD, "VBTimerPeriod", "Vertical blank timer counter period", 2 },
 { GFX_GSREG_HBCOUNTER, "HBCounter", "Horizontal blank counter", 1 },
 { GFX_GSREG_VBCOUNTER, "VBCounter", "Vertical blank counter", 1 },
 { GFX_GSREG_BGCOLOR, "BGColor", "Background Color", 1 },
 { GFX_GSREG_LINECOMPARE, "LineCompare", "Line Compare", 1 },
 { GFX_GSREG_SPRBASE, "SPRBase", "Sprite Table Base", 1 },
 { GFX_GSREG_SPRITESTART, "SpriteStart", "SpriteStart", 1 },
 { GFX_GSREG_SPRITECOUNT, "SpriteCount", "SpriteCount", 1 },

 { GFX_GSREG_FGBGLOC, "FGBGLoc", "FG/BG Map Location", 1 },

 { GFX_GSREG_FGX0, "FGx0", "Foreground Window X0", 1 }, 
 { GFX_GSREG_FGY0, "FGy0", "Foreground Window Y0", 1 },
 { GFX_GSREG_FGX1, "FGx1", "Foreground Window X1", 1 },
 { GFX_GSREG_FGY1, "FGy1", "Foreground Window Y1", 1 },
 { GFX_GSREG_SPRX0, "SPRx0", "Sprite Window X0", 1 },
 { GFX_GSREG_SPRY0, "SPRy0", "Sprite Window Y0", 1 },
 { GFX_GSREG_SPRX1, "SPRx1", "Sprite Window X1", 1 },
 { GFX_GSREG_SPRY1, "SPRy1", "Sprite Window Y1", 1 },

 { GFX_GSREG_BGXSCROLL, "BGXScroll", "Background X Scroll", 1 },
 { GFX_GSREG_BGYSCROLL, "BGYScroll", "Background Y Scroll", 1 },
 { GFX_GSREG_FGXSCROLL, "FGXScroll", "Foreground X Scroll", 1 },
 { GFX_GSREG_FGYSCROLL, "FGYScroll", "Foreground Y Scroll", 1 },

 { 0, "", "", 0 },
};

uint32 WSwan_GfxGetRegister(const unsigned id, char* special, const uint32 special_len)
{
 switch(id)
 {
  case GFX_GSREG_DISPCONTROL:
	return DispControl;

  case GFX_GSREG_VIDEOMODE:
	return(VideoMode);

  case GFX_GSREG_LCDCONTROL:
	return(LCDControl);

  case GFX_GSREG_LCDICONS:
	return(LCDIcons);

  case GFX_GSREG_LCDVTOTAL:
	return(LCDVtotal);

  case GFX_GSREG_BTIMERCONTROL:
	return(BTimerControl);

  case GFX_GSREG_HBTIMERPERIOD:
	return(HBTimerPeriod);

  case GFX_GSREG_VBTIMERPERIOD:
	return(VBTimerPeriod);

  case GFX_GSREG_HBCOUNTER:
	return(HBCounter);

  case GFX_GSREG_VBCOUNTER:
	return(VBCounter);

  case GFX_GSREG_BGCOLOR:
	return(BGColor);

  case GFX_GSREG_LINECOMPARE:
	return(LineCompare);

  case GFX_GSREG_SPRBASE:
	if(special)
	{
	 trio_snprintf(special, special_len, "0x%02x * 0x200 = 0x%04x", SPRBase, SPRBase * 0x200);
	}
	return(SPRBase);

  case GFX_GSREG_SPRITESTART:
	return(SpriteStart);

  case GFX_GSREG_SPRITECOUNT:
	return(SpriteCount);

  case GFX_GSREG_FGBGLOC:
	return(FGBGLoc);

  case GFX_GSREG_FGX0:
	return(FGx0);

  case GFX_GSREG_FGY0:
	return(FGy0);

  case GFX_GSREG_FGX1:
	return(FGx1);

  case GFX_GSREG_FGY1:
	return(FGy1);

  case GFX_GSREG_SPRX0:
	return(SPRx0);

  case GFX_GSREG_SPRY0:
	return(SPRy0);

  case GFX_GSREG_SPRX1:
	return(SPRx1);

  case GFX_GSREG_SPRY1:
	return(SPRy1);

  case GFX_GSREG_BGXSCROLL:
	return(BGXScroll);

  case GFX_GSREG_BGYSCROLL:
	return(BGYScroll);

  case GFX_GSREG_FGXSCROLL:
	return(FGXScroll);

  case GFX_GSREG_FGYSCROLL:
	return(FGYScroll);
 }

 return 0xDEADBEEF;
}

void WSwan_GfxSetRegister(const unsigned id, uint32 value)
{
 switch(id)
 {
  case GFX_GSREG_DISPCONTROL:
	DispControl = value;
	break;

  case GFX_GSREG_VIDEOMODE:
	VideoMode = value;
	wsSetVideo(VideoMode >> 5, false);
	break;

  case GFX_GSREG_LCDCONTROL:
	LCDControl = value;
	break;

  case GFX_GSREG_LCDICONS:
	LCDIcons = value;
	break;

  case GFX_GSREG_LCDVTOTAL:
	LCDVtotal = value;
	break;

  case GFX_GSREG_BTIMERCONTROL:
	BTimerControl = value;
	break;

  case GFX_GSREG_HBTIMERPERIOD:
	HBTimerPeriod = value;
	break;

  case GFX_GSREG_VBTIMERPERIOD:
	VBTimerPeriod = value;
	break;

  case GFX_GSREG_HBCOUNTER:
	HBCounter = value;
	break;

  case GFX_GSREG_VBCOUNTER:
	VBCounter = value;
	break;

  case GFX_GSREG_BGCOLOR:
	BGColor = value;
	break;

  case GFX_GSREG_LINECOMPARE:
	LineCompare = value;
	break;

  case GFX_GSREG_SPRBASE:
	SPRBase = value;
	break;

  case GFX_GSREG_SPRITESTART:
	SpriteStart = value;
	break;

  case GFX_GSREG_SPRITECOUNT:
	SpriteCount = value;
	break;

  case GFX_GSREG_FGBGLOC:
	FGBGLoc = value;
	break;

  case GFX_GSREG_FGX0:
	FGx0 = value;
	break;

  case GFX_GSREG_FGY0:
	FGy0 = value;
	break;

  case GFX_GSREG_FGX1:
	FGx1 = value;
	break;

  case GFX_GSREG_FGY1:
	FGy1 = value;
	break;

  case GFX_GSREG_SPRX0:
	SPRx0 = value;
	break;

  case GFX_GSREG_SPRY0:
	SPRy0 = value;
	break;

  case GFX_GSREG_SPRX1:
	SPRx1 = value;
	break;

  case GFX_GSREG_SPRY1:
	SPRy1 = value;
	break;

  case GFX_GSREG_BGXSCROLL:
	BGXScroll = value;
	break;

  case GFX_GSREG_BGYSCROLL:
	BGYScroll = value;
	break;

  case GFX_GSREG_FGXSCROLL:
	FGXScroll = value;
	break;

  case GFX_GSREG_FGYSCROLL:
	FGYScroll = value;
	break;
 }
}

static const RegGroupType WSwanGfxRegsGroup =
{
 "Gfx",
 WSwanGfxRegs,
 WSwan_GfxGetRegister,
 WSwan_GfxSetRegister,
};


static void DoGfxDecode(void);
static MDFN_Surface *GfxDecode_Buf = NULL;
static int GfxDecode_Line = -1;
static int GfxDecode_Layer = 0;
static int GfxDecode_Scroll = 0;
static int GfxDecode_Pbn = 0;
#endif

void WSwan_GfxInit(void)
{
 LayerEnabled = 7; // BG, FG, sprites
 #ifdef WANT_DEBUGGER
 MDFNDBG_AddRegGroup(&WSwanGfxRegsGroup);
 #endif
}

void WSwan_GfxWSCPaletteRAMWrite(uint32 ws_offset, uint8 data)
{
 ws_offset=(ws_offset&0xfffe)-0xfe00;
 wsCols[(ws_offset>>1)>>4][(ws_offset>>1)&15] = wsRAM[ws_offset+0xfe00] | ((wsRAM[ws_offset+0xfe01]&0x0f) << 8);
}

void WSwan_GfxWrite(uint32 A, uint8 V)
{
 if(A >= 0x1C && A <= 0x1F)
 {
  wsColors[(A - 0x1C) * 2 + 0] = 0xF - (V & 0xf);
  wsColors[(A - 0x1C) * 2 + 1] = 0xF - (V >> 4);
 }
 else if(A >= 0x20 && A <= 0x3F)
 {
  wsMonoPal[(A - 0x20) >> 1][((A & 0x1) << 1) + 0] = V&7;
  wsMonoPal[(A - 0x20) >> 1][((A & 0x1) << 1) | 1] = (V>>4)&7;
 }
 else switch(A)
 {
  case 0x00: DispControl = V; break;
  case 0x01: BGColor = V; break;
  case 0x03: LineCompare = V; break;
  case 0x04: SPRBase = V & 0x3F; break;
  case 0x05: SpriteStart = V; break;
  case 0x06: SpriteCount = V; break;
  case 0x07: FGBGLoc = V; break;
  case 0x08: FGx0 = V; break;
  case 0x09: FGy0 = V; break;
  case 0x0A: FGx1 = V; break;
  case 0x0B: FGy1 = V; break;
  case 0x0C: SPRx0 = V; break;
  case 0x0D: SPRy0 = V; break;
  case 0x0E: SPRx1 = V; break;
  case 0x0F: SPRy1 = V; break;
  case 0x10: BGXScroll = V; break;
  case 0x11: BGYScroll = V; break;
  case 0x12: FGXScroll = V; break;
  case 0x13: FGYScroll = V; break;

  case 0x14: LCDControl = V; break; //    if((!(wsIO[0x14]&1))&&(data&1)) { wsLine=0; }break; /* LCD off ??*/
  case 0x15: LCDIcons = V; break;
  case 0x16: LCDVtotal = V; break;

  case 0x60: VideoMode = V; 
	     wsSetVideo(V>>5, false); 
	     //printf("VideoMode: %02x, %02x\n", V, V >> 5);
	     break;

  case 0xa2: BTimerControl = V; 
	     //printf("%04x:%02x\n", A, V);
	     break;
  case 0xa4: HBTimerPeriod &= 0xFF00; HBTimerPeriod |= (V << 0); /*printf("%04x:%02x, %d\n", A, V, wsLine);*/ break;
  case 0xa5: HBTimerPeriod &= 0x00FF; HBTimerPeriod |= (V << 8); HBCounter = HBTimerPeriod; /*printf("%04x:%02x, %d\n", A, V, wsLine);*/ break;
  case 0xa6: VBTimerPeriod &= 0xFF00; VBTimerPeriod |= (V << 0); /*printf("%04x:%02x, %d\n", A, V, wsLine);*/ break;
  case 0xa7: VBTimerPeriod &= 0x00FF; VBTimerPeriod |= (V << 8); VBCounter = VBTimerPeriod; /*printf("%04x:%02x, %d\n", A, V, wsLine);*/ break;
  //default: printf("%04x:%02x\n", A, V); break;
 }
}

uint8 WSwan_GfxRead(uint32 A)
{
 if(A >= 0x1C && A <= 0x1F)
 {
  uint8 ret = 0;

  ret |= 0xF - wsColors[(A - 0x1C) * 2 + 0];
  ret |= (0xF - wsColors[(A - 0x1C) * 2 + 1]) << 4;

  return(ret);
 }
 else if(A >= 0x20 && A <= 0x3F)
 {
  uint8 ret = wsMonoPal[(A - 0x20) >> 1][((A & 0x1) << 1) + 0] | (wsMonoPal[(A - 0x20) >> 1][((A & 0x1) << 1) | 1] << 4);

  return(ret);
 }
 else switch(A)
 {
  case 0x00: return(DispControl);
  case 0x01: return(BGColor);
  case 0x02: return(wsLine);
  case 0x03: return(LineCompare);
  case 0x04: return(SPRBase);
  case 0x05: return(SpriteStart);
  case 0x06: return(SpriteCount);
  case 0x07: return(FGBGLoc);
  case 0x08: return(FGx0); break;
  case 0x09: return(FGy0); break;
  case 0x0A: return(FGx1); break;
  case 0x0B: return(FGy1); break;
  case 0x0C: return(SPRx0); break;
  case 0x0D: return(SPRy0); break;
  case 0x0E: return(SPRx1); break;
  case 0x0F: return(SPRy1); break;
  case 0x10: return(BGXScroll);
  case 0x11: return(BGYScroll);
  case 0x12: return(FGXScroll);
  case 0x13: return(FGYScroll);
  case 0x14: return(LCDControl);
  case 0x15: return(LCDIcons);
  case 0x16: return(LCDVtotal);
  case 0x60: return(VideoMode);
  case 0xa0: return(wsc ? 0x87 : 0x86);
  case 0xa2: return(BTimerControl);
  case 0xa4: return((HBTimerPeriod >> 0) & 0xFF);
  case 0xa5: return((HBTimerPeriod >> 8) & 0xFF);
  case 0xa6: return((VBTimerPeriod >> 0) & 0xFF);
  case 0xa7: return((VBTimerPeriod >> 8) & 0xFF);
  case 0xa8: /*printf("%04x\n", A);*/ return((HBCounter >> 0) & 0xFF);
  case 0xa9: /*printf("%04x\n", A);*/ return((HBCounter >> 8) & 0xFF);
  case 0xaa: /*printf("%04x\n", A);*/ return((VBCounter >> 0) & 0xFF);
  case 0xab: /*printf("%04x\n", A);*/ return((VBCounter >> 8) & 0xFF);
  default: return(0);
  //default: printf("GfxRead:  %04x\n", A); return(0);
 }
}

bool wsExecuteLine(MDFN_Surface *surface, bool skip)
{
	static const void* const WEP_Tab[4] = { &&WEP0, &&WEP1, &&WEP2, &&WEP3 };	// The things we do for debugger step mode save states!  If we ever add more entries, remember to change the mask stuff in StateAction
        bool ret;

	weppy = 0;
        WEP0: ;

	ret = false;

         #ifdef WANT_DEBUGGER
         if(GfxDecode_Buf && GfxDecode_Line >=0 && wsLine == GfxDecode_Line)
          DoGfxDecode();
         #endif

	if(wsLine < 144)
	{
	 if(!skip)
          wsScanline(surface->pixels + wsLine * surface->pitch32);
	}

	Comm_Process();
	WSwan_CheckSoundDMA();

        // Update sprite data table
        // Note: it's at 142 actually but it doesn't "update" until next frame
        if(wsLine == 142)
        {
	 SpriteCountCache[!FrameWhichActive] = std::min<uint8>(0x80, SpriteCount);
         memcpy(SpriteTable[!FrameWhichActive], &wsRAM[(SPRBase << 9) + (SpriteStart << 2)], SpriteCountCache[!FrameWhichActive] << 2);
	}

        if(wsLine == 144)
        {
		FrameWhichActive = !FrameWhichActive;
                ret = true;
                WSwan_Interrupt(WSINT_VBLANK);
                //printf("VBlank: %d\n", wsLine);
                if(VBCounter && (BTimerControl & 0x04))
                {
                 VBCounter--;
                 if(!VBCounter)
                 {
                  if(BTimerControl & 0x08) // loop
                   VBCounter = VBTimerPeriod;
                  WSwan_Interrupt(WSINT_VBLANK_TIMER);
                 }
                }
        }


        if(HBCounter && (BTimerControl & 0x01))
        {
         HBCounter--;
         if(!HBCounter)
         {
          if(BTimerControl & 0x02) // loop
           HBCounter = HBTimerPeriod;
          WSwan_Interrupt(WSINT_HBLANK_TIMER);
         }
        }

	weppy = 1;
        v30mz_execute(128);
        goto *WEP_Tab[weppy];
	WEP1: ;
	//

	WSwan_CheckSoundDMA();

	//
	weppy = 2;
        v30mz_execute(96);
        goto *WEP_Tab[weppy];
	WEP2: ;

	wsLine = (wsLine + 1) % (std::max<uint8>(144, LCDVtotal) + 1);
        if(wsLine == LineCompare)
        {
         WSwan_Interrupt(WSINT_LINE_HIT);
         //printf("Line hit: %d\n", wsLine);
        }

	weppy = 3;
	v30mz_execute(32);
	goto *WEP_Tab[weppy];
	WEP3: ;

	RTC_Clock(256);

	weppy = 0;
        return(ret);
}

void WSwan_SetLayerEnableMask(uint64 mask)
{
 LayerEnabled = mask;
}

void WSwan_SetPixelFormat(const MDFN_PixelFormat &format)
{
 for(int r = 0; r < 16; r++)
  for(int g = 0; g < 16; g++)
   for(int b = 0; b < 16; b++)
   {
    uint32 neo_r, neo_g, neo_b;

    neo_r = r * 17;
    neo_g = g * 17;
    neo_b = b * 17;

    ColorMap[(r << 8) | (g << 4) | (b << 0)] = format.MakeColor(neo_r, neo_g, neo_b); //(neo_r << rs) | (neo_g << gs) | (neo_b << bs);
   }

 for(int i = 0; i < 16; i++)
 {
  uint32 neo_r, neo_g, neo_b;

  neo_r = (i) * 17;
  neo_g = (i) * 17;
  neo_b = (i) * 17;

  ColorMapG[i] = format.MakeColor(neo_r, neo_g, neo_b); //(neo_r << rs) | (neo_g << gs) | (neo_b << bs);
 }
}

void wsScanline(uint32 *target)
{
	uint32		start_tile_n,map_a,startindex,adrbuf,b1,b2,j,t,l;
	uint8		b_bg[256];
	uint8		b_bg_pal[256];

	if(!wsVMode)
		memset(b_bg, wsColors[BGColor&0xF]&0xF, 256);
	else
	{
		memset(&b_bg[0], BGColor & 0xF, 256);
		memset(&b_bg_pal[0], (BGColor>>4)  & 0xF, 256);
	}
	start_tile_n=(wsLine+BGYScroll)&0xff;/*First line*/
	map_a=(((uint32)(FGBGLoc&0xF))<<11)+((start_tile_n&0xfff8)<<3);
	startindex = BGXScroll >> 3; /*First tile in row*/
	adrbuf = 7-(BGXScroll&7); /*Pixel in tile*/
	
	if((DispControl & 0x01) && (LayerEnabled & 0x01)) /*BG layer*/
        {
	 for(t=0;t<29;t++)
	 {
	  b1=wsRAM[map_a+(startindex<<1)];
	  b2=wsRAM[map_a+(startindex<<1)+1];
	  uint32 palette=(b2>>1)&15;
	  b2=(b2<<8)|b1;
	  wsGetTile(b2&0x1ff,start_tile_n&7,b2&0x8000,b2&0x4000,b2&0x2000);

          if(wsVMode)
          {
           if(wsVMode & 0x2)
	   {
            for(int x = 0; x < 8; x++)
             if(wsTileRow[x])
             {
              b_bg[adrbuf + x] = wsTileRow[x];
              b_bg_pal[adrbuf + x] = palette;
             }
	   }
	   else
	   {
            for(int x = 0; x < 8; x++)
             if(wsTileRow[x] || !(palette & 0x4))
             {
              b_bg[adrbuf + x] = wsTileRow[x];
              b_bg_pal[adrbuf + x] = palette;
             }
	   }
          }
          else
          {
           for(int x = 0; x < 8; x++)
            if(wsTileRow[x] || !(palette & 4))
            {
             b_bg[adrbuf + x] = wsColors[wsMonoPal[palette][wsTileRow[x]]];
            }
          }
	  adrbuf += 8;
	  startindex=(startindex + 1)&31;
	 } // end for(t = 0 ...
	} // End BG layer drawing

	if((DispControl & 0x02) && (LayerEnabled & 0x02))/*FG layer*/
	{
	 uint8 windowtype = DispControl&0x30;
         bool in_window[256 + 8*2];

	 if(windowtype)
         {
          memset(in_window, 0, sizeof(in_window));

	  if(windowtype == 0x20) // Display FG only inside window
	  {
           if((wsLine >= FGy0) && (wsLine <= FGy1))
            for(j = FGx0; j <= FGx1 && j < 224; j++)
              in_window[7 + j] = 1;
	  }
	  else if(windowtype == 0x30) // Display FG only outside window
	  {
	   for(j = 0; j < 224; j++)
	   {
	    if(!(j >= FGx0 && j <= FGx1) || !((wsLine >= FGy0) && (wsLine <= FGy1)))
	     in_window[7 + j] = 1;
	   }
 	  }
	  else
	  {
	   //puts("Who knows!");
	  }
         }
         else
          memset(in_window, 1, sizeof(in_window));

	 start_tile_n=(wsLine+FGYScroll)&0xff;
	 map_a=(((uint32)((FGBGLoc>>4)&0xF))<<11)+((start_tile_n>>3)<<6);
	 startindex = FGXScroll >> 3;
	 adrbuf = 7-(FGXScroll&7);

         for(t=0; t<29; t++)
         {
          b1=wsRAM[map_a+(startindex<<1)];
          b2=wsRAM[map_a+(startindex<<1)+1];
          uint32 palette=(b2>>1)&15;
          b2=(b2<<8)|b1;
          wsGetTile(b2&0x1ff,start_tile_n&7,b2&0x8000,b2&0x4000,b2&0x2000);

          if(wsVMode)
          {
	   if(wsVMode & 0x2)
            for(int x = 0; x < 8; x++)
	    {
             if(wsTileRow[x] && in_window[adrbuf + x])
             {
              b_bg[adrbuf + x] = wsTileRow[x] | 0x10;
              b_bg_pal[adrbuf + x] = palette;
             }
	    }
	   else
            for(int x = 0; x < 8; x++)
	    {
             if((wsTileRow[x] || !(palette & 0x4)) && in_window[adrbuf + x])
             {
              b_bg[adrbuf + x] = wsTileRow[x] | 0x10;
              b_bg_pal[adrbuf + x] = palette;
             }
	    }
          }
          else
          {
           for(int x = 0; x < 8; x++)
            if((wsTileRow[x] || !(palette & 4)) && in_window[adrbuf + x])
            {
             b_bg[adrbuf + x] = wsColors[wsMonoPal[palette][wsTileRow[x]]] | 0x10;
            }
          }
          adrbuf += 8;
          startindex=(startindex + 1)&31;
         } // end for(t = 0 ...

	} // end FG drawing

	if((DispControl & 0x04) && SpriteCountCache[FrameWhichActive] && (LayerEnabled & 0x04))/*Sprites*/
	{
	  bool in_window[256 + 8*2];

          if(DispControl & 0x08)
	  {
	   memset(in_window, 0, sizeof(in_window));
	   if((wsLine >= SPRy0) && (wsLine <= SPRy1))
            for(j = SPRx0; j <= SPRx1 && j < 256; j++)
	      in_window[7 + j] = 1;
	  }
	  else
	   memset(in_window, 1, sizeof(in_window));

		for(int h = SpriteCountCache[FrameWhichActive] - 1; h >= 0; h--)
		{
			const uint8* stab = SpriteTable[FrameWhichActive][h];
			int ts = stab[0];
			int as = stab[1];
			int ysx = stab[2];
			int xs = stab[3];
			int ys;

			if(xs >= 249) xs -= 256;

			if(ysx > 150) 
			 ys = (int8)ysx;
			else 
			 ys = ysx;

			ys = wsLine - ys;

			if(ys >= 0 && ys < 8 && xs < 224)
			{
			 uint32 palette = ((as >> 1) & 0x7);
			 
			 ts |= (as&1) << 8;
			 wsGetTile(ts, ys, as & 0x80, as & 0x40, 0);

			 if(wsVMode)
			 {
			  if(wsVMode & 0x2)
			  {
			   for(int x = 0; x < 8; x++)
			    if(wsTileRow[x])
			    {
		             if((as & 0x20) || !(b_bg[xs + x + 7] & 0x10))
		             {
			      bool drawthis = 0;

			      if(!(DispControl & 0x08)) 
			       drawthis = true;
			      else if((as & 0x10) && !in_window[7 + xs + x])
			       drawthis = true;
			      else if(!(as & 0x10) && in_window[7 + xs + x])
			       drawthis = true;

			      if(drawthis)
		              {
		               b_bg[xs + x + 7] = wsTileRow[x] | (b_bg[xs + x + 7] & 0x10);
		               b_bg_pal[xs + x + 7] = 8 + palette;
		              }
		             }
		            }
			  }
			  else
			  {
                           for(int x = 0; x < 8; x++)
                            if(wsTileRow[x] || !(palette & 0x4))
                            {
                             if((as & 0x20) || !(b_bg[xs + x + 7] & 0x10))
                             {
                              bool drawthis = 0;

                              if(!(DispControl & 0x08))
                               drawthis = true;
                              else if((as & 0x10) && !in_window[7 + xs + x])
                               drawthis = true;
                              else if(!(as & 0x10) && in_window[7 + xs + x])
                               drawthis = true;

                              if(drawthis)
                              {
                               b_bg[xs + x + 7] = wsTileRow[x] | (b_bg[xs + x + 7] & 0x10);
                               b_bg_pal[xs + x + 7] = 8 + palette;
                              }
                             }
                            }

			  }

			 }
			 else
			 {
                          for(int x = 0; x < 8; x++)
                           if(wsTileRow[x] || !(palette & 4))
                           {
                            if((as & 0x20) || !(b_bg[xs + x + 7] & 0x10))
                            {
                             bool drawthis = 0;

                             if(!(DispControl & 0x08))
                              drawthis = true;
                             else if((as & 0x10) && !in_window[7 + xs + x])
                              drawthis = true;
                             else if(!(as & 0x10) && in_window[7 + xs + x])
                              drawthis = true;

                             if(drawthis)
                             //if((as & 0x10) || in_window[7 + xs + x])
                             {
		              b_bg[xs + x + 7] = wsColors[wsMonoPal[8 + palette][wsTileRow[x]]] | (b_bg[xs + x + 7] & 0x10);
                             }
                            }
                           }

			 }
			}
		}

	}	// End sprite drawing

	if(wsVMode)
	{
	 for(l=0;l<224;l++)
	  target[l] = ColorMap[wsCols[b_bg_pal[l+7]][b_bg[(l+7)]&0xf]];
	}
	else
	{
	 for(l=0;l<224;l++)
 	  target[l] = ColorMapG[(b_bg[l+7])&15];
	}
}


void WSwan_GfxReset(void)
{
 weppy = 0;
 wsLine=0;
 wsSetVideo(0,true);

 memset(SpriteTable, 0, sizeof(SpriteTable));
 SpriteCountCache[0] = SpriteCountCache[1] = 0;
 FrameWhichActive = false;
 DispControl = 0;
 BGColor = 0;
 LineCompare = 0xBB;
 SPRBase = 0;

 SpriteStart = 0;
 SpriteCount = 0;
 FGBGLoc = 0;

 FGx0 = 0;
 FGy0 = 0;
 FGx1 = 0;
 FGy1 = 0;
 SPRx0 = 0;
 SPRy0 = 0;
 SPRx1 = 0;
 SPRy1 = 0;

 BGXScroll = BGYScroll = 0;
 FGXScroll = FGYScroll = 0;
 LCDControl = 0;
 LCDIcons = 0;
 LCDVtotal = 158;

 BTimerControl = 0;
 HBTimerPeriod = 0;
 VBTimerPeriod = 0;

 HBCounter = 0;
 VBCounter = 0;


 for(int u0=0;u0<16;u0++)
  for(int u1=0;u1<16;u1++)
   wsCols[u0][u1]=0;

}

void WSwan_GfxStateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVARN(wsMonoPal, "wsMonoPal"),
  SFVAR(wsColors),

  SFVAR(wsLine),

  SFVARN(SpriteTable[0], "SpriteTable"),
  SFVARN(SpriteTable[1], "SpriteTable1"),
  SFVARN(SpriteCountCache[0], "SpriteCountCache"),
  SFVARN(SpriteCountCache[1], "SpriteCountCache1"),
  SFVAR(FrameWhichActive),
  SFVAR(DispControl),
  SFVAR(BGColor),
  SFVAR(LineCompare),
  SFVAR(SPRBase),
  SFVAR(SpriteStart),
  SFVAR(SpriteCount),
  SFVAR(FGBGLoc),
  SFVAR(FGx0),
  SFVAR(FGy0),
  SFVAR(FGx1),
  SFVAR(FGy1),

  SFVAR(SPRx0),
  SFVAR(SPRy0),

  SFVAR(SPRx1),
  SFVAR(SPRy1),

  SFVAR(BGXScroll),
  SFVAR(BGYScroll),
  SFVAR(FGXScroll),
  SFVAR(FGYScroll),
  SFVAR(LCDControl),
  SFVAR(LCDIcons),
  SFVAR(LCDVtotal),

  SFVAR(BTimerControl),
  SFVAR(HBTimerPeriod),
  SFVAR(VBTimerPeriod),

  SFVAR(HBCounter),
  SFVAR(VBCounter),

  SFVAR(VideoMode),

  SFVAR(weppy),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "GFX");

 if(load)
 {
  if(load < 0x94100)
  {
   FrameWhichActive = 0;
   SpriteCountCache[1] = SpriteCountCache[0];
   memcpy(SpriteTable[1], SpriteTable[0], 0x80 * 4);

   if(weppy == 2)
    weppy = 3;
  }
  //
  //
  weppy %= 4;

  for(unsigned i = 0; i < 2; i++)
  {
   if(SpriteCountCache[i] > 0x80)
    SpriteCountCache[i] = 0x80;
  }

  for(unsigned i = 0; i < 16; i++)
   for(unsigned j = 0; j < 4; j++)
    wsMonoPal[i][j] &= 0x7;

  wsSetVideo(VideoMode >> 5, true);
 }
}

#ifdef WANT_DEBUGGER
static void DoGfxDecode(void)
{
 // FIXME
 //uint32 *palette_ptr;
 uint32 *target = GfxDecode_Buf->pixels;
 int w = GfxDecode_Buf->w;
 int h = GfxDecode_Buf->h;
 int scroll = GfxDecode_Scroll;
 uint32 neo_palette[16];
 uint32 tile_limit;
 uint32 zero_color = GfxDecode_Buf->MakeColor(0, 0, 0, 0);

 if(wsVMode && GfxDecode_Layer != 2) // Sprites can't use the extra tile bank in WSC mode
  tile_limit = 0x400;
 else
  tile_limit = 0x200;

 if(GfxDecode_Pbn == -1)
 {
  if(wsVMode)
  {
   for(int x = 0; x < 16; x++)
    neo_palette[x] = GfxDecode_Buf->MakeColor(x * 17, x * 17, x * 17, 0xFF);
  }
  else
   for(int x = 0; x < 16; x++)
    neo_palette[x] = GfxDecode_Buf->MakeColor(x * 85, x * 85, x * 85, 0xFF);
 }
 else
 {
  if(wsVMode)
   for(int x = 0; x < 16; x++)
   {
    uint32 raw = wsCols[GfxDecode_Pbn & 0xF][x];
    uint32 r, g, b;

    r = (raw >> 8) & 0x0F;
    g = (raw >> 4) & 0x0F;
    b = (raw >> 0) & 0x0F;

    neo_palette[x] = GfxDecode_Buf->MakeColor(r * 17, g * 17, b * 17, 0xFF);
   }
  else
   for(int x = 0; x < 4; x++)
   {
    uint32 raw = wsMonoPal[GfxDecode_Pbn & 0xF][x];

    neo_palette[x] = GfxDecode_Buf->MakeColor(raw * 17 , raw * 17, raw * 17, 0xFF);
   }
 }
 //palette_ptr = neo_palette;

 for(int y = 0; y < h; y++)
 {
  for(int x = 0; x < w; x += 8)
  {
   unsigned int which_tile = (x / 8) + (scroll + (y / 8)) * (w / 8);

   if(which_tile >= tile_limit)
   {
    for(int sx = 0; sx < 8; sx++)
    {
     target[x + sx] = zero_color;
     target[x + w * 1 + sx] = 0;
     target[x + w * 2 + sx] = 0;
    }
    continue;
   }

   wsGetTile(which_tile & 0x1FF, y&7, 0, 0, which_tile & 0x200);
   if(wsVMode)
   {
    for(int sx = 0; sx < 8; sx++)
     target[x + sx] = neo_palette[wsTileRow[sx]];
   }
   else
   {
    for(int sx = 0; sx < 8; sx++)
     target[x + sx] = neo_palette[wsTileRow[sx]];
   }

   uint32 address_base;
   uint32 tile_bsize;

   if(wsVMode & 0x4)
   {
    tile_bsize = 4 * 8 * 8 / 8;
    if(which_tile & 0x200)
     address_base = 0x8000;
    else
     address_base = 0x4000;
   }
   else
   {
    tile_bsize = 2 * 8 * 8 / 8;
    if(which_tile & 0x200)
     address_base = 0x4000;
    else
     address_base = 0x2000;
   }

   for(int sx = 0; sx < 8; sx++)
   {
    target[x + w * 1 + sx] = which_tile;
    target[x + w * 2 + sx] = address_base + (which_tile & 0x1FF) * tile_bsize;
   }
  }
  target += w * 3;
 }
}

void WSwan_GfxSetGraphicsDecode(MDFN_Surface *surface, int line, int which, int xscroll, int yscroll, int pbn)
{
 GfxDecode_Buf = surface;
 GfxDecode_Line = line;
 GfxDecode_Layer = which;
 GfxDecode_Scroll = yscroll;
 GfxDecode_Pbn = pbn;

 if(GfxDecode_Line == -1)
  DoGfxDecode();
}

#endif

}
