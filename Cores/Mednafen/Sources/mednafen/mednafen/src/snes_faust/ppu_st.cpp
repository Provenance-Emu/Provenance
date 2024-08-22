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

#include "ppu_base.inc"

static struct PPU_S final : PPU_BASE_S
{
 unsigned WindowPieces[5];	// Derived data, calculated at start of rendering for a scanline.

 uint16 CGRAM[256];
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
 GLBVAR(AllowVRAMAccess)
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
 GLBVAR(OAM_AllowFBReset)
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
 static INLINE void MTIF_EndOAMAddrReset(void) { }
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
  case PPU_GSREG_TM:
	MSEnable = value & 0xFF;
	break;

  case PPU_GSREG_TS:
	SSEnable = value & 0xFF;
	break;

  case PPU_GSREG_TMW:
	WMMainEnable = value & 0xFF;
	break;

  case PPU_GSREG_TSW:
	WMSubEnable = value & 0xFF;
	break;

  case PPU_GSREG_CGWSEL:
	CGWSEL = value & 0xFF;
	break;

  case PPU_GSREG_CGADSUB:
	CGADSUB = value & 0xFF;
	break;

  case PPU_GSREG_BG1SC:
  case PPU_GSREG_BG2SC:
  case PPU_GSREG_BG3SC:
  case PPU_GSREG_BG4SC:
	{
	 const unsigned w = id - PPU_GSREG_BG1SC;

	 assert(w < 4);

	 BGSC[w] = value & 0xFF;
	}
	break;

  case PPU_GSREG_BG12NBA:
	BGNBA[0] = value & 0xFF;
	break;

  case PPU_GSREG_BG34NBA:
	BGNBA[1] = value & 0xFF;
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
