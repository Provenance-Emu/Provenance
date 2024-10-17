/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* ppu_mt.cpp:
**  Copyright (C) 2015-2019 Mednafen Team
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

//
// FIXME: Hires/pseudo-hires color math and color window are all wonky.
//
// FIXME: Add mode 6 emulation
//
// FIXME: Correct handling of lower 3 bits of BGHOFS registers.
//
// FIXME: Short/long line.
//

#include "snes.h"
#include "ppu.h"
#include "input.h"
#include "cart.h"
#include "ppu_mtrender.h"

#include <mednafen/mempatcher.h>

namespace MDFN_IEN_SNES_FAUST
{

namespace PPU_MT
{

static struct
{
 uint32 lastts;

 uint32 LineStartTS;
 uint32 HLatch;
 uint32 VLatch;
 uint32 HLatchReadShift;
 uint32 VLatchReadShift;

 //
 // Cheaty registers and state:
 uint32 InHDMA;
 uint16 HTime;
 uint16 VTime;
 bool IRQThing;

 uint8 NMITIMEEN;

 uint8 HVBJOY;
 uint8 NMIFlag;	// 0x00 or 0x80
 uint8 IRQFlag;	// 0x00 or 0x80
 uint8 JPReadCounter;
 //
 //
 uint8 BusLatch[2];
 //
 bool PAL;
 bool FrameBeginVBlank;
 bool VBlank;
 bool InterlaceOnSample;
 uint32 LinePhase;
 uint32 LineCounter;
 uint32 scanline;
 uint32 LinesPerFrame;
 uint32 LineTarget;

 uint8 Status[2];	// $3E and $3F.

 uint8 ScreenMode;	// $33
 uint8 INIDisp;
 uint8 BGMode;
 uint8 Mosaic;
 uint8 MosaicYOffset;

 uint8 BGSC[4];

 uint8 BGNBA[2];

 uint8 BGOFSPrev;
 uint16 BGHOFS[4];
 uint16 BGVOFS[4];

 uint16 VRAM_Addr;
 uint16 VRAM_ReadBuffer;
 bool VMAIN_IncMode;
 unsigned VMAIN_AddrInc;
 unsigned VMAIN_AddrTransMaskA;
 unsigned VMAIN_AddrTransShiftB;
 unsigned VMAIN_AddrTransMaskC;

 uint8 M7Prev;
 uint8 M7SEL;
 int16 M7Matrix[4];
 int16 M7Center[2];
 int16 M7HOFS;
 int16 M7VOFS;

 bool CGRAM_Toggle;
 uint8 CGRAM_Buffer;
 uint8 CGRAM_Addr;
 uint16 CGRAM[256];

 uint8 MSEnable;
 uint8 SSEnable;

 uint8 WMSettings[3];
 uint8 WMMainEnable;
 uint8 WMSubEnable;
 uint16 WMLogic;
 uint8 WindowPos[2][2];

 uint8 CGWSEL;
 uint8 CGADSUB;
 uint16 FixedColor;

 uint8 OBSEL;
 uint8 OAMADDL;
 uint8 OAMADDH;
 uint8 OAM_Buffer;
 uint32 OAM_Addr;
 uint8 OAM[512];
 uint8 OAMHI[32];
 alignas(8) uint16 VRAM[32768];
 //
 //
 //
 bool SkipFrame;
 EmulateSpecStruct* es;
 unsigned HFilter;
 unsigned SLDRY, SLDRH;
} PPU;

#define GLBVAR(x) static auto& x = PPU.x;
 GLBVAR(lastts)
 GLBVAR(LineStartTS)
 GLBVAR(HLatch)
 GLBVAR(VLatch)
 GLBVAR(HLatchReadShift)
 GLBVAR(VLatchReadShift)
 GLBVAR(InHDMA)
 GLBVAR(IRQThing)
 GLBVAR(HTime)
 GLBVAR(VTime)
 GLBVAR(NMITIMEEN)
 GLBVAR(HVBJOY)
 GLBVAR(NMIFlag)
 GLBVAR(IRQFlag)
 GLBVAR(JPReadCounter)
 GLBVAR(PAL)
 GLBVAR(FrameBeginVBlank)
 GLBVAR(VBlank)
 GLBVAR(InterlaceOnSample)
 GLBVAR(LinePhase)
 GLBVAR(LineCounter)
 GLBVAR(scanline)
 GLBVAR(LinesPerFrame)
 GLBVAR(LineTarget)
 GLBVAR(BusLatch)
 GLBVAR(Status)
 GLBVAR(ScreenMode)
 GLBVAR(INIDisp)
 GLBVAR(BGMode)
 GLBVAR(Mosaic)
 GLBVAR(MosaicYOffset)
 GLBVAR(BGSC)
 GLBVAR(BGNBA)
 GLBVAR(BGOFSPrev)
 GLBVAR(BGHOFS)
 GLBVAR(BGVOFS)
 GLBVAR(VRAM_Addr)
 GLBVAR(VRAM_ReadBuffer)
 GLBVAR(VMAIN_IncMode)
 GLBVAR(VMAIN_AddrInc)
 GLBVAR(VMAIN_AddrTransMaskA)
 GLBVAR(VMAIN_AddrTransShiftB)
 GLBVAR(VMAIN_AddrTransMaskC)
 GLBVAR(M7Prev)
 GLBVAR(M7SEL)
 GLBVAR(M7Matrix)
 GLBVAR(M7Center)
 GLBVAR(M7HOFS)
 GLBVAR(M7VOFS)
 GLBVAR(CGRAM_Toggle)
 GLBVAR(CGRAM_Buffer)
 GLBVAR(CGRAM_Addr)
 GLBVAR(CGRAM)
 GLBVAR(MSEnable)
 GLBVAR(SSEnable)
 GLBVAR(WMSettings)
 GLBVAR(WMMainEnable)
 GLBVAR(WMSubEnable)
 GLBVAR(WMLogic)
 GLBVAR(WindowPos)
 GLBVAR(CGWSEL)
 GLBVAR(CGADSUB)
 GLBVAR(FixedColor)
 GLBVAR(OBSEL)
 GLBVAR(OAMADDL)
 GLBVAR(OAMADDH)
 GLBVAR(OAM_Buffer)
 GLBVAR(OAM_Addr)
 GLBVAR(OAM)
 GLBVAR(OAMHI)
 GLBVAR(VRAM)

 GLBVAR(SkipFrame)
 GLBVAR(es)
 GLBVAR(HFilter)
 GLBVAR(SLDRY)
 GLBVAR(SLDRH)
#undef GLBVAR

#ifdef MDFN_SNES_FAUST_SKETCHYPPUOPT
 #warning "Compiling with sketchy PPU optimization."
#else
static const struct
{
 uint8 w;
 uint8 h;
} Sprite_WHTab[8][2] =
{
 { {  8,  8 }, { 16, 16 } },
 { {  8,  8 }, { 32, 32 } },
 { {  8,  8 }, { 64, 64 } },

 { { 16, 16 }, { 32, 32 } },
 { { 16, 16 }, { 64, 64 } },

 { { 32, 32 }, { 64, 64 } },

 { { 16, 32 }, { 32, 64 } },
 { { 16, 32 }, { 32, 32 } },
};

static INLINE void FetchSpriteData(signed line_y)
{
 static struct
 {
  int16 x;
  uint8 y_offset;
  uint8 w;
  uint8 h;
 } SpriteList[32];
 unsigned SpriteTileCount = 0;
 unsigned SpriteIndex = 0;
 unsigned SpriteCount = 0;
 uint8 whtab[2][2];

 if(INIDisp & 0x80)
 {
  SpriteTileCount = 0;
  return;
 }

 if(OAMADDH & 0x80)
 {
  if((OAM_Addr & 0x3) == 0x3)
   SpriteIndex = ((OAM_Addr >> 2) + line_y) & 0x7F;
  else
   SpriteIndex = (OAM_Addr >> 2) & 0x7F;
 }

 {
  const auto* tp = Sprite_WHTab[(OBSEL >> 5) & 0x7];

  for(unsigned i = 0; i < 2; i++)
  {
   whtab[i][0] = tp[i].w;
   whtab[i][1] = tp[i].h;
  }
 }

 for(unsigned i = 0; i < 128; i++, SpriteIndex = (SpriteIndex + 1) & 0x7F)
 {
  const uint8* const oa = &OAM[SpriteIndex << 2];
  const uint8 hob = OAMHI[SpriteIndex >> 2] >> ((SpriteIndex & 0x3) << 1);
  const bool sizebit = hob & 0x2;
  const signed x = sign_x_to_s32(9, oa[0] | ((hob & 1) << 8));
  uint8 y_offset = line_y - oa[1];
  uint8 w = whtab[sizebit][0];
  uint8 h = whtab[sizebit][1];

  if(y_offset >= h)
   continue;

  //printf("Line %d, Sprite: %d:%d, %d:%d\n", line_y, x, y_offset, w, h);
  if(w <= sign_x_to_s32(9, -x))
   continue;

  if(SpriteCount == 32)
  {
   //printf("Sprite count over on %u\n", line_y);
   Status[0] |= 0x40;
   break;
  }

  //
  //
  //
  auto* l = &SpriteList[SpriteCount];   

  if(oa[3] & 0x80)
   y_offset ^= (h - 1) & ~w;

  l->x = x;
  l->y_offset = y_offset;
  l->w = w;
  l->h = h;
  SpriteCount++;
 }

 SpriteTileCount = 0;
 for(int i = SpriteCount - 1; i >= 0; i--)
 {
  const auto* const l = &SpriteList[i];

  if(MDFN_UNLIKELY(l->x == -256))
  {
   for(int ht = 0; ht < l->w; ht += 8)
   {
    if(SpriteTileCount == 34)
    {
     //printf("Sprite tile overflow on %u\n", line_y);
     Status[0] |= 0x80;
     goto ExitTileLoop;
    }
   }
  }
  else
  {
   for(int ht = 0; ht < l->w; ht += 8)
   {
    int xo = l->x + ht;

    if(xo <= -8 || xo >= 256) //rof > (255 + 7))
     continue;

    if(SpriteTileCount == 34)
    {
     //printf("Sprite tile overflow on %u\n", line_y);
     Status[0] |= 0x80;
     goto ExitTileLoop;
    }
   }
  }
 }
 ExitTileLoop: ;
}
#endif

#include "ppu_common.inc"

void PPU_SyncMT(void)
{
 PPU_MTRENDER::MTIF_Sync();
}

static INLINE void CopyStateToRenderer(void)
{
 //PPU_MTRENDER::MTIF_Sync();
#define PPUMTVAR(x) memcpy(&PPU_MTRENDER::x, &x, sizeof(x))
  PPUMTVAR(Status);

  PPUMTVAR(VRAM);

  PPUMTVAR(ScreenMode);
  PPUMTVAR(INIDisp);
  PPUMTVAR(BGMode);
  PPUMTVAR(Mosaic);
  PPUMTVAR(MosaicYOffset);

  PPUMTVAR(BGSC);

  PPUMTVAR(BGNBA);

  PPUMTVAR(BGOFSPrev);
  PPUMTVAR(BGHOFS);
  PPUMTVAR(BGVOFS);

  PPUMTVAR(VRAM_Addr);
  PPUMTVAR(VMAIN_IncMode);
  PPUMTVAR(VMAIN_AddrInc);
  PPUMTVAR(VMAIN_AddrTransMaskA);
  PPUMTVAR(VMAIN_AddrTransShiftB);
  PPUMTVAR(VMAIN_AddrTransMaskC);

  PPUMTVAR(M7Prev);
  PPUMTVAR(M7SEL);
  PPUMTVAR(M7Matrix);
  PPUMTVAR(M7Center);
  PPUMTVAR(M7HOFS);
  PPUMTVAR(M7VOFS);

  PPUMTVAR(CGRAM_Toggle);
  PPUMTVAR(CGRAM_Buffer);
  PPUMTVAR(CGRAM_Addr);
  PPUMTVAR(CGRAM);

  PPUMTVAR(MSEnable);
  PPUMTVAR(SSEnable);

  PPUMTVAR(WMSettings);
  PPUMTVAR(WMMainEnable);
  PPUMTVAR(WMSubEnable);
  PPUMTVAR(WMLogic);
  PPUMTVAR(WindowPos);

  PPUMTVAR(CGWSEL);
  PPUMTVAR(CGADSUB);
  PPUMTVAR(FixedColor);

  PPUMTVAR(OBSEL);
  PPUMTVAR(OAMADDL);
  PPUMTVAR(OAMADDH);
  PPUMTVAR(OAM_Buffer);
  PPUMTVAR(OAM_Addr);
  PPUMTVAR(OAM);
  PPUMTVAR(OAMHI);
#undef PPUMTVAR
}

void PPU_Reset(bool powering_up)
{
 PPU_MTRENDER::MTIF_Reset(powering_up);
 //
 //
 Common_Reset(powering_up);
 //
 //
 //
 CopyStateToRenderer();
}

void PPU_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 Common_StateAction(sm, load, data_only);

 if(load)
 {
  CopyStateToRenderer();
 }
}

}
}

