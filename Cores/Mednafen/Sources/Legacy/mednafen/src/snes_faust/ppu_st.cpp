/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* ppu_st.cpp:
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

#include <mednafen/mempatcher.h>
#include <mednafen/hash/sha256.h>

#ifdef HAVE_MMX_INTRINSICS
 #include <mmintrin.h>
#endif

#ifdef HAVE_SSE2_INTRINSICS
 #include <xmmintrin.h>
 #include <emmintrin.h>
#endif

#ifdef HAVE_NEON_INTRINSICS
 #include <arm_neon.h>
#endif

namespace MDFN_IEN_SNES_FAUST
{

namespace PPU_ST
{

struct PPU_S
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
 bool PAL;
 bool FrameBeginVBlank;
 bool VBlank;
 bool InterlaceOnSample;
 uint32 LinePhase;
 uint32 LineCounter;
 uint32 LinesPerFrame;
 uint32 LineTarget;
 uint32 scanline;
 //
 //
 //
 //
 uint8 BusLatch[2];
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
 unsigned WindowPieces[5];	// Derived data, calculated at start of rendering for a scanline.

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

 uint16 VRAM[32768];
 //
 //
 //
 union
 {
  struct
  {
   int16 x;
   uint8 y_offset;
   uint8 tilebase;
   uint8 paloffs;
   uint8 prio;
   uint8 w;
   uint8 h;
   uint8 hfxor;
   bool n;
  } SpriteList[32];

  uint32 objbuf[8 + 256 + 8];
 };

 unsigned SpriteTileCount;
 uint16 SpriteTileTab[16];
 struct
 {
  //uint64 td;	// 4bpp->8bpp, |'d with palette offset + 128; 8-bits * 8
  uint32 tda;
  uint32 tdb;
  int32 x;
  uint32 prio_or;
 } SpriteTileList[34];
 //
 //
 //
 uint8 Sprite_WHTab[8][2][2];
 uint8 inctab[4];
 uint32 ttab[4][3];
 //
 uint32 (*DoHFilter)(void* const t_in, const uint32 w, const bool hires);
 uint32 HFilter_PrevW;
 bool HFilter_Auto512;
 bool HFilter_Out512;
 //
 bool SkipFrame;
 EmulateSpecStruct* es;
 unsigned HFilter;
 unsigned SLDRY, SLDRH;
};

static PPU_S PPU;

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
 GLBVAR(LinesPerFrame)
 GLBVAR(LineTarget)
 GLBVAR(scanline)
 //
 //
 //
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
 GLBVAR(WindowPieces)
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

 GLBVAR(DoHFilter)
 GLBVAR(HFilter_PrevW)
 GLBVAR(HFilter_Auto512)
 GLBVAR(HFilter_Out512)

 GLBVAR(SkipFrame)
 GLBVAR(es)
 GLBVAR(HFilter)
 GLBVAR(SLDRY)
 GLBVAR(SLDRH)
#undef GLBVAR


#include "ppu_render_common.inc"

namespace PPU_MTRENDER
{
 static INLINE void MTIF_Read(unsigned A) { }
 static INLINE void MTIF_Write(unsigned A, unsigned V) { }
 static INLINE void MTIF_StartFrame(EmulateSpecStruct* espec, const unsigned hfilter) { RenderCommon_StartFrame(espec, HFilter); }

 static INLINE void MTIF_EnterVBlank(bool PAL, bool skip) { if(!skip) { RenderZero(PAL ? 239 : 232); } }
 static INLINE void MTIF_ResetLineTarget(bool PAL, bool ilaceon, bool field) { RenderCommon_ResetLineTarget(PAL, ilaceon, field); }

 static INLINE void MTIF_RenderLine(uint32 l) { RenderCommon_RenderLine(); }

 static INLINE void MTIF_FetchSpriteData(signed line_y) { }

 static INLINE void MTIF_Init(const uint64 affinity)
 {
  RenderCommon_Init();
 }

 static INLINE void MTIF_Kill(void)
 {

 }
}

#undef MDFN_SNES_FAUST_SKETCHYPPUOPT	// undef so FetchSpriteData() will be called
#include "ppu_common.inc"

void PPU_Reset(bool powering_up)
{
 RenderCommon_Reset(powering_up);
 //
 //
 Common_Reset(powering_up);
}

void PPU_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 Common_StateAction(sm, load, data_only);
}

void PPU_PokeVRAM(uint32 addr, uint16 val)
{
 VRAM[addr & 0x7FFF] = val;
}

void PPU_PokeCGRAM(uint32 addr, uint16 val)
{
 CGRAM[addr & 0xFF] = val;
}

void PPU_PokeOAM(uint32 addr, uint8 val)
{
 OAM[addr & 0x1FF] = val;
}

void PPU_PokeOAMHI(uint32 addr, uint8 val)
{
 OAMHI[addr & 0x1F] = val;
}

void PPU_SetRegister(const unsigned id, const uint32 value)
{
 switch(id)
 {
  // TODO

  case PPU_GSREG_HTIME:
	HTime = value & 0x1FF;
	break;

  case PPU_GSREG_VTIME:
	VTime = value & 0x1FF;
	break;
  //
  //
  //
  case PPU_GSREG_CGADSUB:
	CGADSUB = value & 0xFF;
	break;

  case PPU_GSREG_BG1HOFS:
	BGHOFS[0] = value & 0x3FF;
	break;

  case PPU_GSREG_BG1VOFS:
	BGVOFS[0] = value & 0x3FF;
	break;

  case PPU_GSREG_BG2HOFS:
	BGHOFS[1] = value & 0x3FF;
	break;

  case PPU_GSREG_BG2VOFS:
	BGVOFS[1] = value & 0x3FF;
	break;

  case PPU_GSREG_BG3HOFS:
	BGHOFS[2] = value & 0x3FF;
	break;

  case PPU_GSREG_BG3VOFS:
	BGVOFS[2] = value & 0x3FF;
	break;

  case PPU_GSREG_BG4HOFS:
	BGHOFS[3] = value & 0x3FF;
	break;

  case PPU_GSREG_BG4VOFS:
	BGVOFS[3] = value & 0x3FF;
	break;

 }
}

}

}
