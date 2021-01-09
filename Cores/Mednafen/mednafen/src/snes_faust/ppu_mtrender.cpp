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

#include "snes.h"
#include "ppu.h"
#include "ppu_mtrender.h"

#include <mednafen/Time.h>
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

namespace PPU_MTRENDER
{

PPU_S PPU;

#include "ppu_render_common.inc"

//
//
//
//
//
//

#define PPUMT_DEFWRITE(x) INLINE void x (uint8 A, uint8 V)

static PPUMT_DEFWRITE(Write_ScreenMode)
{
 ScreenMode = V;
}

static PPUMT_DEFWRITE(Write_2100)
{
 if((INIDisp ^ V) & 0x80 & ~V)
  OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;

 INIDisp = V;

 //printf("INIDisp = %02x --- scanline=%u\n", V, scanline);
}

static PPUMT_DEFWRITE(Write_OBSEL)
{
 OBSEL = V;
}

static PPUMT_DEFWRITE(Write_OAMADDL)
{
 OAMADDL = V;
 OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;
}

static PPUMT_DEFWRITE(Write_OAMADDH)
{
 OAMADDH = V;
 OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;
}

static PPUMT_DEFWRITE(Write_OAMDATA)
{
 if(OAM_Addr & 0x200)
  OAMHI[OAM_Addr & 0x1F] = V;
 else if(OAM_Addr & 1)
 {
  OAM[(size_t)OAM_Addr - 1] = OAM_Buffer;
  OAM[(size_t)OAM_Addr + 0] = V;
 }

 if(!(OAM_Addr & 1))
  OAM_Buffer = V;

 OAM_Addr = (OAM_Addr + 1) & 0x3FF;
}

static PPUMT_DEFWRITE(Write_OAMDATA_Uniracers)
{
 OAMHI[0x18] = V;
}

static PPUMT_DEFWRITE(Write_2105)
{
 BGMode = V;
}

static PPUMT_DEFWRITE(Write_2106)
{
 if((Mosaic ^ V) & 0xF0)
  MosaicYOffset = 0;

 Mosaic = V;
}

static PPUMT_DEFWRITE(Write_BGSC)
{
 BGSC[(size_t)(uint8)A - 0x07] = V;
}

static PPUMT_DEFWRITE(Write_BGNBA)
{
 BGNBA[(size_t)(uint8)A - 0x0B] = V;
}

template<bool bg0>
static PPUMT_DEFWRITE(Write_BGHOFS)
{
 uint16* const t = &BGHOFS[((size_t)(uint8)A >> 1) - (0x0D >> 1)];
 *t = BGOFSPrev | ((V & 0x3) << 8);
 BGOFSPrev = V;

 if(bg0)
 {
  //printf("M7HOFS: %u, %02x\n", scanline, V);
  M7HOFS = sign_13_to_s16(M7Prev | ((V & 0x1F) << 8));
  M7Prev = V;
 }
}

template<bool bg0>
static PPUMT_DEFWRITE(Write_BGVOFS)
{
 BGVOFS[((size_t)(uint8)A >> 1) - (0x0E >> 1)] = BGOFSPrev | ((V & 0x3) << 8);
 BGOFSPrev = V;

 if(bg0)
 {
  //printf("M7VOFS: %u, %02x\n", scanline, V);
  M7VOFS = sign_13_to_s16(M7Prev | ((V & 0x1F) << 8));
  M7Prev = V;
 }
}

static MDFN_HOT uint16 GetVAddr(void)
{
 return (VRAM_Addr & VMAIN_AddrTransMaskA) | ((VRAM_Addr >> VMAIN_AddrTransShiftB) & 0x7) | ((VRAM_Addr << 3) & VMAIN_AddrTransMaskC);
}

static PPUMT_DEFWRITE(Write_2115)
{
 VMAIN_IncMode = V & 0x80;
 VMAIN_AddrInc = PPU.inctab[V & 0x3];

 VMAIN_AddrTransMaskA = PPU.ttab[(V >> 2) & 0x3][0];
 VMAIN_AddrTransShiftB = PPU.ttab[(V >> 2) & 0x3][1];
 VMAIN_AddrTransMaskC = PPU.ttab[(V >> 2) & 0x3][2];
}

static PPUMT_DEFWRITE(Write_2116)
{
 VRAM_Addr &= 0xFF00;
 VRAM_Addr |= V << 0;
}

static PPUMT_DEFWRITE(Write_2117)
{
 VRAM_Addr &= 0x00FF;
 VRAM_Addr |= V << 8;
}

static PPUMT_DEFWRITE(Write_2118)
{
 const unsigned va = GetVAddr();

 //if(va >= 0x2000 && va < 0x3000)
 // fprintf(stderr, "Low: %04x %04x, %02x\n", va, VRAM_Addr, V);

 VRAM[va] &= 0xFF00;
 VRAM[va] |= V << 0;

 if(!VMAIN_IncMode)
  VRAM_Addr += VMAIN_AddrInc;
}

static PPUMT_DEFWRITE(Write_2119)
{
 const unsigned va = GetVAddr();

 //if(va >= 0x2000 && va < 0x3000)
 // fprintf(stderr, "High: %04x %04x, %02x\n", va, VRAM_Addr, V);

 VRAM[va] &= 0x00FF;
 VRAM[va] |= V << 8;

 if(VMAIN_IncMode)
  VRAM_Addr += VMAIN_AddrInc;
}

static PPUMT_DEFWRITE(Write_211A)
{
 M7SEL = V & 0xC3;
}

static PPUMT_DEFWRITE(Write_M7Matrix)		// $1b-$1e
{
 M7Matrix[(size_t)(uint8)A - 0x1B] = M7Prev | (V << 8);
 M7Prev = V;
}

static PPUMT_DEFWRITE(Write_M7Center)
{
 M7Center[(size_t)(uint8)A - 0x1F] = sign_13_to_s16(M7Prev | ((V & 0x1F) << 8));
 M7Prev = V;
}

static PPUMT_DEFWRITE(Write_CGADD)
{
 CGRAM_Addr = V;
 CGRAM_Toggle = false;
}

static PPUMT_DEFWRITE(Write_CGDATA)
{
 if(CGRAM_Toggle)
 {
  CGRAM[CGRAM_Addr] = ((V & 0x7F) << 8) | CGRAM_Buffer;
  CGRAM_Addr++;
 }
 else
  CGRAM_Buffer = V;

 CGRAM_Toggle = !CGRAM_Toggle;
}

static PPUMT_DEFWRITE(Write_MSEnable)
{
 MSEnable = V & 0x1F;
}

static PPUMT_DEFWRITE(Write_SSEnable)
{
 SSEnable = V & 0x1F;
}

static PPUMT_DEFWRITE(Write_WMMainEnable)
{
 WMMainEnable = V;
}

static PPUMT_DEFWRITE(Write_WMSubEnable)
{
 WMSubEnable = V;
}

template<bool msb>
static PPUMT_DEFWRITE(Write_WMLogic)
{
 if(msb)
  WMLogic = (WMLogic & 0x00FF) | ((V & 0xF) << 8);
 else
  WMLogic = (WMLogic & 0xFF00) | (V << 0);
}

static PPUMT_DEFWRITE(Write_WMSettings)
{
 WMSettings[(size_t)(uint8)A - 0x23] = V;
}


static PPUMT_DEFWRITE(Write_WindowPos)	// $26-$29
{
 ((uint8*)WindowPos)[(size_t)(uint8)A - 0x26] = V;

 //printf("%04x %02x\n", A, V);
}


static PPUMT_DEFWRITE(Write_CGWSEL)
{
 CGWSEL = V;
}

static PPUMT_DEFWRITE(Write_CGADSUB)
{
 CGADSUB = V;
}

static PPUMT_DEFWRITE(Write_COLDATA)
{
 unsigned cc = V & 0x1F;

 if(V & 0x20)
  FixedColor = (FixedColor &~ (0x1F <<  0)) | (cc <<  0);

 if(V & 0x40)
  FixedColor = (FixedColor &~ (0x1F <<  5)) | (cc <<  5);

 if(V & 0x80)
  FixedColor = (FixedColor &~ (0x1F << 10)) | (cc << 10);
}


//
//
//
//
//

void MTIF_StartFrame(EmulateSpecStruct* espec, const unsigned hfilter)
{
 RenderCommon_StartFrame(espec, hfilter);
}

static INLINE void Write(uint8 A, uint8 V)
{
 switch(A)
 {
  default: printf("Bad Write: %02x %02x\n", A, V); break;

  case 0x00: Write_2100(A, V); break;

  case 0x01: Write_OBSEL(A, V); break;
  case 0x02: Write_OAMADDL(A, V); break;
  case 0x03: Write_OAMADDH(A, V); break;
  case 0x04: Write_OAMDATA(A, V); break;
  case 0x3F: Write_OAMDATA_Uniracers(A, V); break;	// HAX

  case 0x05: Write_2105(A, V); break;
  case 0x06: Write_2106(A, V); break;

  case 0x07: Write_BGSC(A, V); break;
  case 0x08: Write_BGSC(A, V); break;
  case 0x09: Write_BGSC(A, V); break;
  case 0x0A: Write_BGSC(A, V); break;

  case 0x0B: Write_BGNBA(A, V); break;
  case 0x0C: Write_BGNBA(A, V); break;

  case 0x0D: Write_BGHOFS<true>(A, V); break;
  case 0x0F: Write_BGHOFS<false>(A, V); break;
  case 0x11: Write_BGHOFS<false>(A, V); break;
  case 0x13: Write_BGHOFS<false>(A, V); break;

  case 0x0E: Write_BGVOFS<true>(A, V); break;
  case 0x10: Write_BGVOFS<false>(A, V); break;
  case 0x12: Write_BGVOFS<false>(A, V); break;
  case 0x14: Write_BGVOFS<false>(A, V); break;

  case 0x15: Write_2115(A, V); break;
  case 0x16: Write_2116(A, V); break;
  case 0x17: Write_2117(A, V); break;
  case 0x18: Write_2118(A, V); break;
  case 0x19: Write_2119(A, V); break;

  case 0x1A: Write_211A(A, V); break;
  case 0x1B: Write_M7Matrix(A, V); break;
  case 0x1C: Write_M7Matrix(A, V); break;
  case 0x1D: Write_M7Matrix(A, V); break;
  case 0x1E: Write_M7Matrix(A, V); break;

  case 0x1F: Write_M7Center(A, V); break;
  case 0x20: Write_M7Center(A, V); break;

  case 0x21: Write_CGADD(A, V); break;
  case 0x22: Write_CGDATA(A, V); break;

  case 0x23: Write_WMSettings(A, V); break;
  case 0x24: Write_WMSettings(A, V); break;
  case 0x25: Write_WMSettings(A, V); break;

  case 0x26: Write_WindowPos(A, V); break;
  case 0x27: Write_WindowPos(A, V); break;
  case 0x28: Write_WindowPos(A, V); break;
  case 0x29: Write_WindowPos(A, V); break;
  case 0x2A: Write_WMLogic<false>(A, V); break;
  case 0x2B: Write_WMLogic<true>(A, V); break;

  case 0x2C: Write_MSEnable(A, V); break;
  case 0x2D: Write_SSEnable(A, V); break;

  case 0x2E: Write_WMMainEnable(A, V); break;
  case 0x2F: Write_WMSubEnable(A, V); break;

  case 0x30: Write_CGWSEL(A, V); break;
  case 0x31: Write_CGADSUB(A, V); break;

  case 0x32: Write_COLDATA(A, V); break;

  case 0x33: Write_ScreenMode(A, V); break;
  //
  //
  //
  case 0x38:
	//printf("MT OAM Addr Inc\n");
	OAM_Addr = (OAM_Addr + 1) & 0x3FF;
	break;

  case 0x39:
  case 0x3A:
	//printf("MT VRAM Addr Inc\n");
	VRAM_Addr += VMAIN_AddrInc;
	break;
 }
}

void MTIF_Reset(bool powering_up)
{
 RenderCommon_Reset(powering_up);
}

static INLINE bool DoCommand(uint8 Command, uint8 Arg8)
{
 bool ret = true;

 if(Command == COMMAND_EXIT)
  ret = false;
 else if(Command == COMMAND_FETCH_SPRITE_DATA)
 {
  FetchSpriteData(Arg8);
 }
 else if(Command == COMMAND_RENDER_LINE)
 {
  scanline = Arg8;

  RenderCommon_RenderLine();
 }
 else if(Command == COMMAND_ENTER_VBLANK)
 {
  const bool PAL = (bool)(Arg8 & 1);
  const bool skip = (bool)(Arg8 & 0x80);

  if(!skip)
   RenderZero(PAL ? 239 : 232);
  //assert(es->DisplayRect.y != 0);

  if(!(INIDisp & 0x80))
   OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;
 }
 else if(Command == COMMAND_RESET_LINE_TARGET)
 {
  const bool PAL = Arg8 & 0x1;
  const bool ilaceon = Arg8 & 0x2;
  const bool field = Arg8 & 0x4;

  Status[1] = field << 7;
  RenderCommon_ResetLineTarget(PAL, ilaceon, field);
 }

 return ret;
}

alignas(32) ITC_S ITC;

static MDFN_HOT int RThreadEntry(void* data)
{
 bool Running = true;
 size_t WritePos = 0;
 size_t ReadPos = 0;

 while(MDFN_LIKELY(Running))
 {
  ITC.TMP_ReadPos.store(ReadPos, std::memory_order_release);
  WritePos = ITC.TMP_WritePos.load(std::memory_order_acquire);

  while(ReadPos == WritePos)
  {
   MThreading::Sem_Post(ITC.WakeupSem);
   MThreading::Sem_TimedWait(ITC.RT_WakeupSem, 1);
   WritePos = ITC.TMP_WritePos.load(std::memory_order_acquire);
  }
  //printf("RThread Sync; WritePos=%d time=%lld\n", (int)WritePos, (long long)Time::MonoUS());
  //
  //
  //
  uint8 Command;
  uint8 Arg8;

  //printf("RThread: ReadPos=%d, WritePos=%d\n", (int)ReadPos, (int)WritePos);
  while(ReadPos != WritePos)
  {
   {
    WQ_Entry* e = &ITC.WQ[ReadPos];

    Command = e->Command;
    Arg8 = e->Arg8;
    //
    ReadPos = (ReadPos + 1) % ITC.WQ.size();
   }
   //
   if(Command < COMMAND_BASE)
   {
    //printf("RThread: Write 0x%02x 0x%02x\n", Command, Arg8);
    Write(Command, Arg8);
   }
   else
   {
    //printf("RThread: Command 0x%02x 0x%02x\n", Command, Arg8);
    Running &= DoCommand(Command, Arg8);
   }
  }
 }

 return 0;
}

void MTIF_Init(const uint64 affinity)
{
 RenderCommon_Init();
 //
 //
 //
 ITC.WritePos = 0;
 ITC.ReadPos = 0;
 ITC.TMP_WritePos = 0;
 ITC.TMP_ReadPos = 0;
 //
 ITC.RT_WakeupSem = MThreading::Sem_Create();
 ITC.WakeupSem = MThreading::Sem_Create();
 //
 ITC.RThread = MThreading::Thread_Create(RThreadEntry, NULL, "PPU Render");
 if(affinity)
  MThreading::Thread_SetAffinity(ITC.RThread, affinity);
}

void MTIF_Kill(void)
{
 if(ITC.RThread)
 {
  WWQ(COMMAND_EXIT);
  Wakeup(false);
  MThreading::Thread_Wait(ITC.RThread, NULL);
  ITC.RThread = NULL;
 }

 if(ITC.RT_WakeupSem)
 {
  MThreading::Sem_Destroy(ITC.RT_WakeupSem);
  ITC.RT_WakeupSem = NULL;
 }

 if(ITC.WakeupSem)
 {
  MThreading::Sem_Destroy(ITC.WakeupSem);
  ITC.WakeupSem = NULL;
 }
}


//
//
//
}
}

