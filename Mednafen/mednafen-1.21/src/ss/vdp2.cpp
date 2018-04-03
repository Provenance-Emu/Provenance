/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp2.cpp - VDP2 Emulation
**  Copyright (C) 2015-2018 Mednafen Team
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

// TODO: Emulate brokenness(missing vblank) that occurs when switching from 240-height mode to 224-height mode around lines 224-239.

// TODO: Update output signals on Reset()?  Might have to call VDP2::Reset() before other _Reset() then...and take special care in the
// SMPC clock change code.

#include "ss.h"
#include <mednafen/mednafen.h>
#include <mednafen/general.h>
#include <mednafen/FileStream.h>
#include "vdp1.h"
#include "vdp2.h"
#include "scu.h"
#include "smpc.h"

#include "vdp2_common.h"
#include "vdp2_render.h"

namespace MDFN_IEN_SS
{

namespace VDP2
{

static bool PAL;
static sscpu_timestamp_t lastts;
//
//
//
static uint16 RawRegs[0x100];	// For debugging

static bool DisplayOn;
static bool BorderMode;
bool ExLatchEnable;
static bool ExSyncEnable;
static bool ExBGEnable;
static bool DispAreaSelect;

static bool VRAMSize;

static uint8 HRes, VRes;
static uint8 InterlaceMode;
enum { IM_NONE, IM_ILLEGAL, IM_SINGLE, IM_DOUBLE };

static uint16 RAMCTL_Raw;
static uint8 CRAM_Mode;
enum
{
 CRAM_MODE_RGB555_1024	= 0,
 CRAM_MODE_RGB555_2048	= 1,
 CRAM_MODE_RGB888_1024	= 2,
 CRAM_MODE_ILLEGAL	= 3
};

static uint16 BGON;
static uint8 VCPRegs[4][8];
static uint32 VRAMPenalty[4];

static uint32 RPTA;
static uint8 RPRCTL[2];
static uint8 KTAOF[2];

static struct
{
 uint16 YStart, YEnd;
 bool YEndMet;
 bool YIn;
} Window[2];

static uint16 VRAM[262144];

static uint16 CRAM[2048];

static struct
{
 // Signed values are stored sign-extended to the full 32 bits.
 int32 Xst, Yst, Zst;	// 1.12.10
 int32 DXst, DYst;	// 1. 2.10
 int32 DX, DY;		// 1. 2.10
 int32 RotMatrix[6];	// 1. 3.10
 int32 Px, Py, Pz;	// 1.13. 0
 int32 Cx, Cy, Cz;	// 1.13. 0
 int32 Mx, My;		// 1.13.10
 int32 kx, ky;		// 1. 7.16

 uint32 KAst;		// 0.16.10
 uint32 DKAst;		// 1. 9.10
 uint32 DKAx;		// 1. 9.10
 //
 //
 //
 uint32 XstAccum, YstAccum;	// 1.12.10 (sorta)
 uint32 KAstAccum;		//     .10
} RotParams[2];

static void FetchRotParams(const bool field)
{
 uint32 a = RPTA & 0x7FFBE;

 for(unsigned i = 0; i < 2; i++)
 {
  auto& rp = RotParams[i];

  rp.Xst = sign_x_to_s32(23, ne16_rbo_be<uint32>(VRAM, ((a + 0x00) & 0x3FFFF) << 1) >> 6);
  rp.Yst = sign_x_to_s32(23, ne16_rbo_be<uint32>(VRAM, ((a + 0x02) & 0x3FFFF) << 1) >> 6);
  rp.Zst = sign_x_to_s32(23, ne16_rbo_be<uint32>(VRAM, ((a + 0x04) & 0x3FFFF) << 1) >> 6);

  rp.DXst = sign_x_to_s32(13, ne16_rbo_be<uint32>(VRAM, ((a + 0x06) & 0x3FFFF) << 1) >> 6);
  rp.DYst = sign_x_to_s32(13, ne16_rbo_be<uint32>(VRAM, ((a + 0x08) & 0x3FFFF) << 1) >> 6);

  rp.DX = sign_x_to_s32(13, ne16_rbo_be<uint32>(VRAM, ((a + 0x0A) & 0x3FFFF) << 1) >> 6);
  rp.DY = sign_x_to_s32(13, ne16_rbo_be<uint32>(VRAM, ((a + 0x0C) & 0x3FFFF) << 1) >> 6);

  for(unsigned m = 0; m < 6; m++)
  {
   rp.RotMatrix[m] = sign_x_to_s32(14, ne16_rbo_be<uint32>(VRAM, ((a + 0x0E + (m << 1)) & 0x3FFFF) << 1) >> 6);
  }

  rp.Px = sign_x_to_s32(14, VRAM[(a + 0x1A) & 0x3FFFF]);
  rp.Py = sign_x_to_s32(14, VRAM[(a + 0x1B) & 0x3FFFF]);
  rp.Pz = sign_x_to_s32(14, VRAM[(a + 0x1C) & 0x3FFFF]);

  rp.Cx = sign_x_to_s32(14, VRAM[(a + 0x1E) & 0x3FFFF]);
  rp.Cy = sign_x_to_s32(14, VRAM[(a + 0x1F) & 0x3FFFF]);
  rp.Cz = sign_x_to_s32(14, VRAM[(a + 0x20) & 0x3FFFF]);

  rp.Mx = sign_x_to_s32(24, ne16_rbo_be<uint32>(VRAM, ((a + 0x22) & 0x3FFFF) << 1) >> 6);
  rp.My = sign_x_to_s32(24, ne16_rbo_be<uint32>(VRAM, ((a + 0x24) & 0x3FFFF) << 1) >> 6);

  rp.kx = sign_x_to_s32(24, ne16_rbo_be<uint32>(VRAM, ((a + 0x26) & 0x3FFFF) << 1));
  rp.ky = sign_x_to_s32(24, ne16_rbo_be<uint32>(VRAM, ((a + 0x28) & 0x3FFFF) << 1));

  rp.KAst = ne16_rbo_be<uint32>(VRAM, ((a + 0x2A) & 0x3FFFF) << 1) >> 6;
  rp.DKAst = sign_x_to_s32(20, ne16_rbo_be<uint32>(VRAM, ((a + 0x2C) & 0x3FFFF) << 1) >> 6);
  rp.DKAx = sign_x_to_s32(20, ne16_rbo_be<uint32>(VRAM, ((a + 0x2E) & 0x3FFFF) << 1) >> 6);

  a += 0x40;
  //
  // Interlace mode doesn't seem to affect operation?
  //
  // const bool imft = (InterlaceMode == IM_DOUBLE && field);

  if(RPRCTL[i] & 0x01)
   rp.XstAccum = rp.Xst; // + rp.DXst * imft;
  else
   rp.XstAccum += rp.DXst; // << (InterlaceMode == IM_DOUBLE);

  if(RPRCTL[i] & 0x02)
   rp.YstAccum = rp.Yst; // + rp.DYst * imft;
  else
   rp.YstAccum += rp.DYst; // << (InterlaceMode == IM_DOUBLE);

  if(RPRCTL[i] & 0x04)
   rp.KAstAccum = (KTAOF[i] << 26) + rp.KAst; // + rp.DKAst * imft;
  else
   rp.KAstAccum += rp.DKAst; // << (InterlaceMode == IM_DOUBLE);
 }
}

enum
{
 VPHASE_ACTIVE = 0,

 VPHASE_BOTTOM_BORDER,
 VPHASE_BOTTOM_BLANKING,

 VPHASE_VSYNC,

 VPHASE_TOP_BLANKING,
 VPHASE_TOP_BORDER,

 VPHASE__COUNT
};

static const int32 VTimings[2][4][VPHASE__COUNT] = // End lines
{
 { // NTSC:
  { 0x0E0, 0xE8, 0xED, 0xF0, 0x0FF, 0x107 },
  { 0x0F0, 0xF0, 0xF5, 0xF8, 0x107, 0x107 },
  { 0x0E0, 0xE8, 0xED, 0xF0, 0x0FF, 0x107 },
  { 0x0F0, 0xF0, 0xF5, 0xF8, 0x107, 0x107 },
 },
 { // PAL:
  // btm brdr begin, btm blnk begin, vsync begin, /***/ top blnk begin, top brdr begin, total
  { 0x0E0, 0x100, 0x103, /***/ 0x103 + 3/*?*/, 0x119, 0x139 },
  { 0x0F0, 0x108, 0x10B, /***/ 0x10B + 3/*?*/, 0x121, 0x139 },
  { 0x100, 0x110, 0x113, /***/ 0x113 + 3/*?*/, 0x129, 0x139 },
  { 0x100, 0x110, 0x113, /***/ 0x113 + 3/*?*/, 0x129, 0x139 },
 },
};

static bool Out_VB;	// VB output signal

static uint32 VPhase;
/*static*/ int32 VCounter;
static bool InternalVB;
static bool Odd;

static uint32 CRTLineCounter;
static bool Clock28M;
//
static int SurfInterlaceField;
//
//
//


//  (No 0)  8 accesses, No split: 0 added cycles
//  (No 4)  4 accesses, No split: 1 added cycles
//  (No 6)  2 accesses, No split: 2 added cycles
//  (No 7)  1 accesses, No split: 3, Split: 3.51? added cycles
//  (No 8)  0 accesses, No split: 4, Split: 5.34? added cycles
static INLINE void RecalcVRAMPenalty(void)
{
 if(InternalVB)
  VRAMPenalty[0] = VRAMPenalty[1] = VRAMPenalty[2] = VRAMPenalty[3] = 0;
 else
 {
  const unsigned VRAM_Mode = (RAMCTL_Raw >> 8) & 0x3;
  const unsigned RDBS_Mode = (RAMCTL_Raw & 0xFF);
  const size_t sh = ((HRes & 0x6) ? 0 : 4);
  uint8 vcp_type_penalty[0x10];

  for(unsigned vcp_type = 0; vcp_type < 0x10; vcp_type++)
  {
   bool penalty;

   if((vcp_type < 0x8) || vcp_type == 0xC || vcp_type == 0xD)
    penalty = (bool)(BGON & (1U << (vcp_type & 0x3)));
   else
    penalty = false;

   vcp_type_penalty[vcp_type] = penalty;
  }

  for(unsigned bank = 0; bank < 4; bank++)
  {
   const unsigned esb = bank & (2 | ((VRAM_Mode >> (bank >> 1)) & 1));
   const uint8 rdbs = (RDBS_Mode >> (esb << 1)) & 0x3;
   uint32 tmp = 0;

   if(BGON & 0x20)
   {
    if(bank >= 2 || ((BGON & 0x10) && rdbs != RDBS_UNUSED))
     tmp = 8;
   }
   else
   {
    if((BGON & 0x10) && rdbs != RDBS_UNUSED)
     tmp = 8;
    else if(BGON & 0x0F)
    {
     tmp += vcp_type_penalty[VCPRegs[esb][0]];
     tmp += vcp_type_penalty[VCPRegs[esb][1]];
     tmp += vcp_type_penalty[VCPRegs[esb][2]];
     tmp += vcp_type_penalty[VCPRegs[esb][3]];

     tmp += vcp_type_penalty[VCPRegs[esb][sh + 0]];
     tmp += vcp_type_penalty[VCPRegs[esb][sh + 1]];
     tmp += vcp_type_penalty[VCPRegs[esb][sh + 2]];
     tmp += vcp_type_penalty[VCPRegs[esb][sh + 3]];
    }
   }

   static const uint8 tab[9] = { 0, 0, 0, 0, 1, 1, 2, 3, 4 };
   VRAMPenalty[bank] = tab[tmp];
   //printf("%d, %d\n", bank, tmp);
  }
 }
}

enum
{
 HPHASE_ACTIVE = 0,

 HPHASE_RIGHT_BORDER,
 HPHASE_HSYNC,

 // ... ? ? ?

 HPHASE__COUNT
};

static const int32 HTimings[2][HPHASE__COUNT] =
{
 { 0x140, 0x15B, 0x1AB },
 { 0x160, 0x177, 0x1C7 },
};

static uint32 HPhase;
/*static*/ int32 HCounter;

static uint16 Latched_VCNT, Latched_HCNT;
static bool HVIsExLatched;
bool ExLatchIn;
bool ExLatchPending;


static INLINE unsigned GetNLVCounter(void)
{
 unsigned ret;

 if(VPhase >= VPHASE_VSYNC)
  ret = VCounter + (0x200 - VTimings[PAL][VRes][VPHASE__COUNT - 1]);
 else
  ret = VCounter;

 if(InterlaceMode == IM_DOUBLE)
  ret = (ret << 1) | !Odd;

 return ret;
}

static void LatchHV(void)
{
 Latched_VCNT = GetNLVCounter();

 if(HPhase >= HPHASE_HSYNC)
  Latched_HCNT = (HCounter + (0x200 - HTimings[HRes & 1][HPHASE__COUNT - 1])) << 1;
 else
  Latched_HCNT = HCounter << 1;
}

//
//
void GetGunXTranslation(const bool clock28m, float* scale, float* offs)
{
 VDP2REND_GetGunXTranslation(clock28m, scale, offs);
}

void StartFrame(EmulateSpecStruct* espec, const bool clock28m)
{
 Clock28M = clock28m;
 //printf("StartFrame: %d\n", SurfInterlaceField);
 VDP2REND_StartFrame(espec, clock28m, SurfInterlaceField);
 CRTLineCounter = 0;
}

//
//
static INLINE void IncVCounter(const sscpu_timestamp_t event_timestamp)
{
 const unsigned prev_nlvc = GetNLVCounter();
 //
 VCounter = (VCounter + 1) & 0x1FF;

 if(VCounter == (VTimings[PAL][VRes][VPHASE__COUNT - 1] - 1))
 {
  Out_VB = false;
  Window[0].YEndMet = Window[1].YEndMet = false;
 }

 // - 1, so the CPU loop will  have plenty of time to exit before we reach non-hblank top border area
 // (exit granularity could be large if program is executing from SCSP RAM space, for example).
 if(VCounter == (VTimings[PAL][VRes][VPHASE_TOP_BLANKING] - 1))
 {
#if 0
  for(unsigned bank = 0; bank < 4; bank++)
  {
   printf("Bank %d: ", bank);
   for(unsigned vc = 0; vc < 8; vc++)
    printf("%01x ", VCPRegs[bank][vc]);
   printf("\n");
  }
#endif

  SS_RequestMLExit();
  VDP2REND_EndFrame();
  //printf("Meow: %d\n", VCounter);
 }

 while(VCounter >= VTimings[PAL][VRes][VPhase] - ((VPhase == VPHASE_VSYNC - 1) && InterlaceMode))
 {
  VPhase++;

  if(VPhase == VPHASE__COUNT)
  {
   VPhase = 0;
   VCounter -= VTimings[PAL][VRes][VPHASE__COUNT - 1];
  }

  if(VPhase == VPHASE_ACTIVE)
   InternalVB = !DisplayOn;
  else if(VPhase == VPHASE_BOTTOM_BORDER)
  {
   SS_SetEventNT(&events[SS_EVENT_MIDSYNC], event_timestamp + 1);
   InternalVB = true;
   Out_VB = true;
  }
  else if(VPhase == VPHASE_BOTTOM_BLANKING)
  {
   CRTLineCounter = 0x80000000U;
  }
  else if(VPhase == VPHASE_VSYNC)
  {
   if(InterlaceMode)
   {
    Odd = !Odd;
    VCounter += Odd;
    SurfInterlaceField = !Odd;
   }
   else
   {
    SurfInterlaceField = -1;
    Odd = true;
   }
  }
 }

 //
 //
 {
  const unsigned nlvc = GetNLVCounter();
  const unsigned mask = (InterlaceMode == IM_DOUBLE) ? 0x1FE : 0x1FF;

  for(unsigned d = 0; d < 2; d++)
  {
   if((nlvc & mask) == (Window[d].YStart & mask))
   {
    //printf("Window%d YStartMet at VC=0x%03x ---- %03x %03x\n", d, nlvc, Window[d].YStart, Window[d].YEnd);
    Window[d].YIn = true;
   }

   if((prev_nlvc & mask) == (Window[d].YEnd & mask))
   {
    //printf("Window%d YEndMet at VC=0x%03x ---- %03x %03x\n", d, nlvc, Window[d].YStart, Window[d].YEnd);
    Window[d].YEndMet = true;
   }

   Window[d].YIn &= !Window[d].YEndMet;
  }
 }
 //
 //

 RecalcVRAMPenalty();

 SMPC_SetVBVS(event_timestamp, Out_VB, VPhase == VPHASE_VSYNC);
}

static INLINE int32 AddHCounter(const sscpu_timestamp_t event_timestamp, int32 count)
{
 HCounter += count;

 //if(HCounter > HTimings[HRes & 1][HPhase])
 // printf("VDP2 oops: %d %d\n", HCounter, HTimings[HRes & 1][HPhase]);

 while(HCounter >= HTimings[HRes & 1][HPhase])
 {
  HPhase++;

  if(HPhase == HPHASE__COUNT)
  {
   HPhase = 0;
   HCounter -= HTimings[HRes & 1][HPHASE__COUNT - 1];
  }
  //
  //
  //
  if(HPhase == HPHASE_ACTIVE)
  {
   {
    const int32 div = Clock28M ? 61 : 65;
    const int32 coord_adj = 6832 - 80 * div;

    SMPC_LineHook(event_timestamp, CRTLineCounter, div, coord_adj);
   }

   if(VPhase == VPHASE_ACTIVE)
   {
    VDP2Rend_LIB* lib = VDP2REND_GetLIB(VCounter);

    lib->win_ymet[0] = Window[0].YIn;
    lib->win_ymet[1] = Window[1].YIn;

    if(!InternalVB)
    {
     if(BGON & 0x30)
     {
      if(VCounter == 0)
       RPRCTL[0] = RPRCTL[1] = 0x07;
      FetchRotParams(false/*field*/);
      RPRCTL[0] = RPRCTL[1] = 0;
     }

     for(unsigned i = 0; i < 2; i++)
     {
      auto const& rp = RotParams[i];
      auto& r = lib->rv[i];

      r.Xsp = ((int64)rp.RotMatrix[0] * ((int32)rp.XstAccum - (rp.Px * 1024)) +
	      (int64)rp.RotMatrix[1] * ((int32)rp.YstAccum - (rp.Py * 1024)) +
	      (int64)rp.RotMatrix[2] * (rp.Zst      - (rp.Pz * 1024))) >> 10;
      r.Ysp = ((int64)rp.RotMatrix[3] * ((int32)rp.XstAccum - (rp.Px * 1024)) +
	      (int64)rp.RotMatrix[4] * ((int32)rp.YstAccum - (rp.Py * 1024)) +
	      (int64)rp.RotMatrix[5] * (rp.Zst      - (rp.Pz * 1024))) >> 10;
 
      r.Xp = rp.RotMatrix[0] * (rp.Px - rp.Cx) +
	    rp.RotMatrix[1] * (rp.Py - rp.Cy) +
	    rp.RotMatrix[2] * (rp.Pz - rp.Cz) +
	    (rp.Cx * 1024) + rp.Mx;

      r.Yp = rp.RotMatrix[3] * (rp.Px - rp.Cx) +
	    rp.RotMatrix[4] * (rp.Py - rp.Cy) +
	    rp.RotMatrix[5] * (rp.Pz - rp.Cz) +
	    (rp.Cy * 1024) + rp.My;

      r.dX = (rp.RotMatrix[0] * rp.DX + rp.RotMatrix[1] * rp.DY) >> 10;
      r.dY = (rp.RotMatrix[3] * rp.DX + rp.RotMatrix[4] * rp.DY) >> 10;

      r.kx = rp.kx;
      r.ky = rp.ky;

      r.KAstAccum = rp.KAstAccum;
      r.DKAx = rp.DKAx;
     }
    }
    //printf("%d, 0x%08x(%f) 0x%08x(%f)\n", VCounter, RotParams[0].KAstAccum >> 10, (int32)RotParams[0].DKAst / 1024.0, RotParams[1].KAstAccum >> 10, (int32)RotParams[1].DKAst / 1024.0);
    //printf("DL: %d\n", VCounter);
    lib->vdp1_hires8 = VDP1::GetLine(VCounter, lib->vdp1_line, (HRes & 1) ? 352 : 320, (int32)RotParams[0].XstAccum >> 1, (int32)RotParams[0].YstAccum >> 1, (int32)RotParams[0].DX >> 1, (int32)RotParams[0].DY >> 1); // Always call, has side effects.
    VDP2REND_DrawLine(InternalVB ? -1 : VCounter, CRTLineCounter, !Odd);
    CRTLineCounter++;
   }
   else if(VPhase == VPHASE_TOP_BORDER || VPhase == VPHASE_BOTTOM_BORDER)
   {
    VDP2REND_DrawLine(-1, CRTLineCounter, !Odd);
    CRTLineCounter++;
   }
  }
  else if(HPhase == HPHASE_HSYNC)
  {
   IncVCounter(event_timestamp);
  }
 }

 return (HTimings[HRes & 1][HPhase] - HCounter);
}

sscpu_timestamp_t Update(sscpu_timestamp_t timestamp)
{
 int32 clocks = (timestamp - lastts) >> 2;

 if(MDFN_UNLIKELY(timestamp < lastts))
 {
  SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP2, "[VDP2] [BUG] timestamp(%d) < lastts(%d)", timestamp, lastts);
  clocks = 0;
 }

 lastts += clocks << 2;
 //
 //
 int32 ne;
 int32 tmp;

 ne = AddHCounter(timestamp, clocks);
 VDP1::SetHBVB(timestamp, HPhase > HPHASE_ACTIVE, Out_VB);
 tmp = SCU_SetHBVB(clocks, HPhase > HPHASE_ACTIVE, Out_VB);
 if(tmp < ne)
  ne = tmp;

 //
 //
 //
 if(MDFN_UNLIKELY(ExLatchPending))
 {
  LatchHV();
  HVIsExLatched = true;
  ExLatchPending = false;
  //printf("ExLatch: %04x %04x\n", Latched_VCNT, Latched_HCNT);
 }

 return lastts + (ne << 2);
}

//
// Register writes seem to always be 16-bit
//
static INLINE void RegsWrite(uint32 A, uint16 V)
{
 A &= 0x1FE;

 RawRegs[A >> 1] = V;

 SS_DBGTI(SS_DBG_VDP2_REGW, "[VDP2] Register write 0x%03x: 0x%04x", A, V);

 switch(A)
 {
  default:
//	SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP2, "[VDP2] Unknown write to register at 0x%08x of value 0x%04x", A, V);
	break;

  case 0x00:
	Update(SH7095_mem_timestamp);
	//
	DisplayOn = (V >> 15) & 0x1;
	BorderMode = (V >> 8) & 0x1;
	InterlaceMode = (V >> 6) & 0x3;
	VRes = (V >> 4) & 0x3;
	HRes = (V >> 0) & 0x7;
	//
	InternalVB |= !DisplayOn;
	//
	SS_SetEventNT(&events[SS_EVENT_VDP2], Update(SH7095_mem_timestamp));
	break;

  case 0x02:
	ExLatchEnable = (V >> 9) & 0x1;
	ExSyncEnable = (V >> 8) & 0x1;

	DispAreaSelect = (V >> 1) & 0x1;
	ExBGEnable = (V >> 0) & 0x1;
	break;

  case 0x06:
	VRAMSize = (V >> 15) & 0x1;

	if(VRAMSize)
	 SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP2, "[VDP2] VRAMSize=%d (unemulated)", VRAMSize);
	break;

  case 0x0E:
	RAMCTL_Raw = V & 0xB3FF;
	CRAM_Mode = (V >> 12) & 0x3;
	break;

  case 0x10:
  case 0x12:
  case 0x14:
  case 0x16:
  case 0x18:
  case 0x1A:
  case 0x1C:
  case 0x1E:
	{
	 uint8* const b = &VCPRegs[(A >> 2) & 3][(A & 0x2) << 1];
	 b[0] = (V >> 12) & 0xF;
	 b[1] = (V >>  8) & 0xF;
	 b[2] = (V >>  4) & 0xF;
	 b[3] = (V >>  0) & 0xF;
	}
	break;

  case 0x20:
	BGON = V & 0x1F3F;
	break;

  case 0xB2:
	RPRCTL[0] = (V >> 0) & 0x7;
	RPRCTL[1] = (V >> 8) & 0x7;
	break;

  case 0xB6:
	KTAOF[0] = (V >> 0) & 0x7;
	KTAOF[1] = (V >> 8) & 0x7;
	break;

  case 0xBC:
	RPTA = (RPTA & 0xFFFF) | ((V & 0x7) << 16);
	break;

  case 0xBE:
	RPTA = (RPTA & ~0xFFFF) | (V & 0xFFFE);
	break;

  case 0xC2: Window[0].YStart = V & 0x1FF; break;
  case 0xC6: Window[0].YEnd = V & 0x1FF; break;

  case 0xCA: Window[1].YStart = V & 0x1FF; break;
  case 0xCE: Window[1].YEnd = V & 0x1FF; break;
 }
}

static INLINE uint16 RegsRead(uint32 A)
{
 switch(A & 0x1FE)
 {
  default:
	SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP2, "[VDP2] Unknown read from 0x%08x", A);
	return 0;

  case 0x00:
	return (DisplayOn << 15) | (BorderMode << 8) | (InterlaceMode << 6) | (VRes << 4) | (HRes << 0);

  case 0x02:
	if(!ExLatchEnable)
	{
	 SS_SetEventNT(&events[SS_EVENT_VDP2], Update(SH7095_mem_timestamp));
 	 LatchHV();
	}
	return (ExLatchEnable << 9) | (ExSyncEnable << 8) | (DispAreaSelect << 1) | (ExBGEnable << 0);

  case 0x04:
	SS_SetEventNT(&events[SS_EVENT_VDP2], Update(SH7095_mem_timestamp));
	{
	 // TODO: EXSYFG
	 uint16 ret = (HVIsExLatched << 9) | (InternalVB << 3) | ((HPhase > HPHASE_ACTIVE) << 2) | (Odd << 1) | (PAL << 0);

	 HVIsExLatched = false;

	 return ret;
	}

  case 0x06:
	return VRAMSize << 15;

  case 0x08:
	return Latched_HCNT;

  case 0x0A:
	return Latched_VCNT;

  case 0x0E:
	return RAMCTL_Raw;
 }
}

template<typename T, bool IsWrite>
static INLINE uint32 RW(uint32 A, uint16* DB)
{
 static_assert(IsWrite || sizeof(T) == 2, "Wrong type for read.");

 A &= 0x1FFFFF;

 //
 // VRAM
 //
 if(A < 0x100000)
 {
  const size_t vri = (A & 0x7FFFF) >> 1;

  if(IsWrite)
  {
   const unsigned mask = (sizeof(T) == 2) ? 0xFFFF : (0xFF00 >> ((A & 1) << 3));

   VRAM[vri] = (VRAM[vri] &~ mask) | (*DB & mask);
  }
  else
   *DB = VRAM[vri];

  return VRAMPenalty[vri >> 16];
 }

 //
 // CRAM
 //
 if(A < 0x180000)
 {
  const unsigned cri = (A & 0xFFF) >> 1;

  if(IsWrite)
  {
   switch(CRAM_Mode)
   {
    case CRAM_MODE_RGB555_1024:
	(CRAM + 0x000)[cri & 0x3FF] = *DB;
	(CRAM + 0x400)[cri & 0x3FF] = *DB;
	break;

    case CRAM_MODE_RGB555_2048:
	CRAM[cri] = *DB;
	break;

    case CRAM_MODE_RGB888_1024:
    case CRAM_MODE_ILLEGAL:
    default:
	CRAM[((cri >> 1) & 0x3FF) | ((cri & 1) << 10)] = *DB;
	break;
   }
  }
  else
  {
   switch(CRAM_Mode)
   {
    case CRAM_MODE_RGB555_1024:
    case CRAM_MODE_RGB555_2048:
	*DB = CRAM[cri];
	break;

    case CRAM_MODE_RGB888_1024:
    case CRAM_MODE_ILLEGAL:
    default:
	*DB = CRAM[((cri >> 1) & 0x3FF) | ((cri & 1) << 10)];
	break;
   }
  }

  return 0;
 }

 //
 // Registers
 //
 if(A < 0x1C0000)
 {
  if(IsWrite)
  {
   if(sizeof(T) == 1)
    SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP2, "[VDP2] Byte-write to register at 0x%08x(DB=0x%04x)", A, *DB);

   RegsWrite(A, *DB);
  }
  else
   *DB = RegsRead(A);

  return 0;
 }

 if(IsWrite)
 {
  //SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP2, "[VDP2] Unknown %zu-byte write to 0x%08x(DB=0x%04x)", sizeof(T), A, *DB);
 }
 else
 {
  //SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP2, "[VDP2] Unknown %zu-byte read from 0x%08x", sizeof(T), A);
  *DB = 0;
 }

 return 0;
}

uint16 Read16_DB(uint32 A)
{
 uint16 DB;

 RW<uint16, false>(A, &DB);

 return DB;
}


uint32 Write8_DB(uint32 A, uint16 DB)
{
 VDP2REND_Write8_DB(A, DB);

 return RW<uint8, true>(A, &DB);
}

uint32 Write16_DB(uint32 A, uint16 DB)
{
 VDP2REND_Write16_DB(A, DB);

 return RW<uint16, true>(A, &DB);
}


//
//
//

void AdjustTS(const int32 delta)
{
 lastts += delta;
}


void Init(const bool IsPAL)
{
 SurfInterlaceField = -1;
 PAL = IsPAL;
 lastts = 0;

 SS_SetPhysMemMap(0x05E00000, 0x05EFFFFF, VRAM, 0x80000, true);

 ExLatchIn = false;

 VDP2REND_Init(IsPAL);
}

void SetGetVideoParams(MDFNGI* gi, const bool caspect, const int sls, const int sle, const bool show_h_overscan, const bool dohblend)
{
 if(PAL)
  gi->fps = 65536 * 256 * (1734687500.0 / 61 / 4 / 455 / ((313 + 312.5) / 2.0));
 else
  gi->fps = 65536 * 256 * (1746818181.8 / 61 / 4 / 455 / ((263 + 262.5) / 2.0));

 VDP2REND_SetGetVideoParams(gi, caspect, sls, sle, show_h_overscan, dohblend);
}

void Kill(void)
{
 VDP2REND_Kill();
}

//
// TODO: Check reset versus power on values.
//
void Reset(bool powering_up)
{
 DisplayOn = false;
 BorderMode = false;
 ExLatchEnable = false;
 ExSyncEnable = false;
 ExBGEnable = false;
 DispAreaSelect = false;
 HRes = 0;
 VRes = 0;
 InterlaceMode = 0;

 VRAMSize = 0;

 InternalVB = true;
 Out_VB = false;
 VPhase = VPHASE_ACTIVE;
 VCounter = 0;
 Odd = true;

 RAMCTL_Raw = 0;
 CRAM_Mode = 0;

 BGON = 0;

 memset(VCPRegs, 0, sizeof(VCPRegs));

 for(unsigned i = 0; i < 2; i++)
 {
  KTAOF[i] = 0;
  RPRCTL[i] = 0;
 }
 RPTA = 0;
 memset(RotParams, 0, sizeof(RotParams));

 for(unsigned w = 0; w < 2; w++)
 {
  Window[w].YStart = 0;
  Window[w].YEnd = 0;
  Window[w].YEndMet = false;
  Window[w].YIn = false;
 }
 //
 //
 //
 if(powering_up)
 {
  HPhase = 0;
  HCounter = 0;

  Latched_VCNT = 0;
  Latched_HCNT = 0;
  HVIsExLatched = false;
  ExLatchPending = false;
 }
 //
 // FIXME(init values), also in VDP2REND.
 if(powering_up)
 {
  memset(VRAM, 0, sizeof(VRAM));
  memset(CRAM, 0, sizeof(CRAM));
 }
 //
 RecalcVRAMPenalty();
 //
 //
 VDP2REND_Reset(powering_up);
}

//
//
//
//
uint32 GetRegister(const unsigned id, char* const special, const uint32 special_len)
{
 uint32 ret = 0xDEADBEEF;

 switch(id)
 {
  case GSREG_LINE:
	ret = VCounter;
	break;

 case GSREG_DON:
	ret = DisplayOn;
	break;

 case GSREG_BM:
	ret = BorderMode;
	break;

 case GSREG_IM:
	ret = InterlaceMode;
	break;

 case GSREG_VRES:
	ret = VRes;
	break;

 case GSREG_HRES:
	ret = HRes;
	break;
 }

 return ret;
}

void SetRegister(const unsigned id, const uint32 value)
{

}

uint8 PeekVRAM(const uint32 addr)
{
 return ne16_rbo_be<uint8>(VRAM, addr & 0x7FFFF);
}

void PokeVRAM(const uint32 addr, const uint8 val)
{
 ne16_wbo_be<uint8>(VRAM, addr & 0x7FFFF, val);
 //VDP2REND_Write8_DB(addr, val << (((A & 1) ^ 1) << 3));
}

void SetLayerEnableMask(uint64 mask)
{
 VDP2REND_SetLayerEnableMask(mask);
}

void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(lastts),

  SFVAR(RawRegs),
  SFVAR(DisplayOn),
  SFVAR(BorderMode),
  SFVAR(ExLatchEnable),
  SFVAR(ExSyncEnable),
  SFVAR(ExBGEnable),
  SFVAR(DispAreaSelect),

  SFVAR(VRAMSize),

  SFVAR(HRes),
  SFVAR(VRes),
  SFVAR(InterlaceMode),

  SFVAR(RAMCTL_Raw),
  SFVAR(CRAM_Mode),

  SFVAR(BGON),
  SFVARN(VCPRegs, "&VCPRegs[0][0]"),
  SFVAR(VRAMPenalty),

  SFVAR(RPTA),
  SFVAR(RPRCTL),
  SFVAR(KTAOF),

  SFVAR(VRAM),
  SFVAR(CRAM),

  SFVAR(RotParams->Xst, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->Yst, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->Zst, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->DXst, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->DYst, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->DX, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->DY, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->RotMatrix, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->Px, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->Py, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->Pz, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->Cx, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->Cy, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->Cz, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->Mx, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->My, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->kx, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->ky, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->KAst, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->DKAst, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->DKAx, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->XstAccum, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->YstAccum, 2, sizeof(*RotParams), RotParams),
  SFVAR(RotParams->KAstAccum, 2, sizeof(*RotParams), RotParams),

  SFVAR(Out_VB),

  SFVAR(VPhase),
  SFVAR(VCounter),
  SFVAR(InternalVB),
  SFVAR(Odd),

  SFVAR(CRTLineCounter),
  SFVAR(Clock28M),
//
  SFVAR(SurfInterlaceField),

  SFVAR(HPhase),
  SFVAR(HCounter),

  SFVAR(Latched_VCNT),
  SFVAR(Latched_HCNT),
  SFVAR(HVIsExLatched),
  SFVAR(ExLatchIn),
  SFVAR(ExLatchPending),

  SFVAR(Window->YStart, 2, sizeof(*Window), Window),
  SFVAR(Window->YEnd, 2, sizeof(*Window), Window),
  SFVAR(Window->YEndMet, 2, sizeof(*Window), Window),
  SFVAR(Window->YIn, 2, sizeof(*Window), Window),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "VDP2");

 if(load)
 {
  if(load < 0x00102100)
  {
   Window[0].YStart = RawRegs[0xC2 >> 1] & 0x1FF;
   Window[0].YEnd = RawRegs[0xC6 >> 1] & 0x1FF;

   Window[1].YStart = RawRegs[0xCA >> 1] & 0x1FF;
   Window[1].YEnd = RawRegs[0xCE >> 1] & 0x1FF;

   //printf("%08x %03x:%03x, %03x:%03x\n", load, Window[0].YStart, Window[0].YEnd, Window[1].YStart, Window[1].YEnd);

   for(unsigned d = 0; d < 2; d++)
   {
    Window[d].YEndMet = false;
    Window[d].YIn = false;
   }
  }
 }

 VDP2REND_StateAction(sm, load, data_only, RawRegs, CRAM, VRAM);
}

void MakeDump(const std::string& path)
{
 FileStream fp(path, FileStream::MODE_WRITE);

 fp.print_format(" { ");
 for(unsigned i = 0; i < 0x100; i++)
  fp.print_format("0x%04x, ", RawRegs[i]);
 fp.print_format(" }, \n");

 fp.print_format(" { ");
 for(unsigned i = 0; i < 2048; i++)
  fp.print_format("0x%04x, ", CRAM[i]);
 fp.print_format(" }, \n");

 fp.print_format(" { ");
 for(unsigned i = 0; i < 0x40000; i++)
  fp.print_format("0x%04x, ", VRAM[i]);
 fp.print_format(" }, \n");

 fp.close();
}

}

}
