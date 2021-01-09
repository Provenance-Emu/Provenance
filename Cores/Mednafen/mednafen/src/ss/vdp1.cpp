/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp1.cpp - VDP1 Emulation
**  Copyright (C) 2015-2020 Mednafen Team
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

// TODO: Draw timing for small lines(somewhere between 2 and 15 pixels wide) on the VDP1 seems weird; investigate further
// before making timing changes to the drawing code.

// TODO: Draw timing for (large) primitives should be about 20% higher.

// TODO: Draw timing for shrunken(even just slightly) sprite lines with HSS disabled should be 100% higher.

// TODO: 32-bit writes from the SH-2 CPUs to VDP1 registers seem to be broken on a Saturn; test, and implement here.

// TODO: Check to see what registers are reset on reset.

// TODO: SS_SetPhysMemMap(0x05C80000, 0x05CFFFFF, FB[FBDrawWhich], sizeof(FB[0]));
//  (...but goes weird in 8bpp rotated mode...)

// TODO: Test 1x1 line, polyline, sprite, and polygon.

// TODO: Framebuffer swap/auto drawing start happens a bit too early, should happen near
//       end of hblank instead of the beginning.

#include "ss.h"
#include <mednafen/mednafen.h>
#include <mednafen/FileStream.h>
#include "scu.h"
#include "vdp1.h"
#include "vdp2.h"
#include "vdp1_common.h"

enum : int { VDP1_UpdateTimingGran = 263 };
enum : int { VDP1_IdleTimingGran = 1019 };

namespace MDFN_IEN_SS
{
namespace VDP1
{

uint8 spr_w_shift_tab[8];
uint8 gouraud_lut[0x40];
line_data LineData;
line_inner_data LineInnerData;
prim_data PrimData;

int32 SysClipX, SysClipY;
int32 UserClipX0, UserClipY0, UserClipX1, UserClipY1;

int32 LocalX, LocalY;

uint8 TVMR;
uint8 FBCR;
static uint8 PTMR;
static uint8 EDSR;

uint16* FBDrawWhichPtr;
static bool FBDrawWhich;

static bool DrawingActive;
static uint32 CurCommandAddr;
static int32 RetCommandAddr;
static uint16 LOPR;

static sscpu_timestamp_t lastts;
static int32 CycleCounter;
static int32 CommandPhase;
static uint16 CommandData[0x10];
uint32 DTACounter;

static bool vb_status, hb_status;
static bool vbcdpending;
static bool FBManualPending;
static bool FBVBErasePending;
static bool FBVBEraseActive;
static sscpu_timestamp_t FBVBEraseLastTS;
static sscpu_timestamp_t LastRWTS;

static uint16 EWDR;	// Erase/Write Data
static uint16 EWLR;	// Erase/Write Upper Left Coordinate
static uint16 EWRR;	// Erase/Write Lower Right Coordinate

static struct
{
 bool rot8;
 uint32 fb_x_mask;

 uint32 y_start;
 uint32 x_start;

 uint32 y_end;
 uint32 x_bound;

 uint16 fill_data;
} EraseParams;

static uint32 EraseYCounter;

#if 1
static uint32 InstantDrawSanityLimit; // ss_horrible_hacks
#endif

uint16 VRAM[0x40000];
uint16 FB[2][0x20000];
//
//
//
#ifdef MDFN_ENABLE_DEV_BUILD
struct VRAMUsageInfo
{
 uint64 earliest;
 uint64 latest;
};

static VRAMUsageInfo VRAMDrawReads[0x40000];
static VRAMUsageInfo VRAMWrites[0x40000];
static uint64 VRAMUsageTSBase;
static uint64 VRAMUsageStartTS;

static void VRAMUsageInit(void)
{
 VRAMUsageTSBase = 0;
}

static void VRAMUsageAddBaseTime(int32 amount)
{
 VRAMUsageTSBase += amount;
}

static void VRAMUsageStart(void)
{
 if(MDFN_UNLIKELY(ss_dbg_mask & SS_DBG_VDP1_RACE))
 {
  for(size_t i = 0; i < 0x40000; i++)
  {
   VRAMDrawReads[i].earliest = ~(uint64)0;
   VRAMDrawReads[i].latest = ~(uint64)0;

   VRAMWrites[i].earliest = ~(uint64)0;
   VRAMWrites[i].latest = ~(uint64)0;
  }
 }
 VRAMUsageStartTS = VRAMUsageTSBase;
}

static void VRAMUsageWrite(uint32 A)
{
 if(MDFN_UNLIKELY(ss_dbg_mask & SS_DBG_VDP1_RACE))
 {
  const uint64 fullts = VRAMUsageTSBase + SH7095_mem_timestamp;
  const size_t index = A & 0x3FFFF;

  if(VRAMWrites[index].earliest == ~(uint64)0)
   VRAMWrites[index].earliest = fullts;

  VRAMWrites[index].latest = fullts;
 }
}

static void VRAMUsageDrawRead(uint32 A)
{
 if(MDFN_UNLIKELY(ss_dbg_mask & SS_DBG_VDP1_RACE))
 {
  const uint64 fullts = VRAMUsageTSBase + SH7095_mem_timestamp;
  const size_t index = A & 0x3FFFF;

  if(VRAMDrawReads[index].earliest == ~(uint64)0)
   VRAMDrawReads[index].earliest = fullts;

  VRAMDrawReads[index].latest = fullts;
 }
}

static void VRAMUsageEnd(void)
{
 if(MDFN_UNLIKELY(ss_dbg_mask & SS_DBG_VDP1_RACE))
 {
  for(unsigned i = 0; i < 0x40000; i++)
  {
   if(VRAMWrites[i].latest != ~(uint64)0 && VRAMDrawReads[i].latest != ~(uint64)0)
   {
    SS_DBG(SS_DBG_VDP1_RACE, "[VDP1] VRAM[0x%06x] Race --- Write, earliest=%llu, latest=%llu --- Draw Read, earliest=%llu, latest=%llu\n", i * 2, (unsigned long long)(VRAMWrites[i].earliest - VRAMUsageStartTS), (unsigned long long)(VRAMWrites[i].latest - VRAMUsageStartTS), (unsigned long long)(VRAMDrawReads[i].earliest - VRAMUsageStartTS), (unsigned long long)(VRAMDrawReads[i].latest - VRAMUsageStartTS));
   }
  }
 }
}
#else
static INLINE void VRAMUsageInit(void) { }
static INLINE void VRAMUsageAddBaseTime(int32 amount) { }
static INLINE void VRAMUsageStart(void) { }
static INLINE void VRAMUsageWrite(uint32 A) { }
static INLINE void VRAMUsageDrawRead(uint32 A) { }
static INLINE void VRAMUsageEnd(void) { }
#endif
//
//
//
void Init(void)
{
 vbcdpending = false;

 for(int i = 0; i < 0x40; i++)
 {
  gouraud_lut[i] = std::min<int>(31, std::max<int>(0, i - 16));
 }

 for(int i = 0; i < 8; i++)
 {
  spr_w_shift_tab[i] = (7 - i) / 3;
 }


 //
 //
 SS_SetPhysMemMap(0x05C00000, 0x05C7FFFF, VRAM, sizeof(VRAM), true);
 //SS_SetPhysMemMap(0x05C80000, 0x05CFFFFF, FB[FBDrawWhich], sizeof(FB[0]), true);

 vb_status = false;
 hb_status = false;
 lastts = 0;
 FBVBEraseLastTS = 0;
 LastRWTS = 0;

 VRAMUsageInit();
}

void Kill(void)
{

}

void Reset(bool powering_up)
{
 if(powering_up)
 {
  for(unsigned i = 0; i < 0x40000; i++)
  {
   uint16 val;

   if((i & 0xF) == 0)
    val = 0x8000;
   else if(i & 0x1)
    val = 0x5555;
   else
    val = 0xAAAA;

   VRAM[i] = val;
  }

  for(unsigned fb = 0; fb < 2; fb++)
   for(unsigned i = 0; i < 0x20000; i++)
    FB[fb][i] = 0xFFFF;

  memset(&LineData, 0, sizeof(LineData));
  memset(&LineInnerData, 0, sizeof(LineInnerData));
  memset(&PrimData, 0, sizeof(PrimData));

  //
  // Registers with somewhat undefined state on power-on:
  //
  EWDR = 0;
  EWLR = 0;
  EWRR = 0;

  UserClipX0 = 0;
  UserClipY0 = 0;
  UserClipX1 = 0;
  UserClipY1 = 0;

  SysClipX = 0;
  SysClipY = 0;
 
  LocalX = 0;
  LocalY = 0;
 }

 FBDrawWhich = 0;
 FBDrawWhichPtr = FB[FBDrawWhich];
 //SS_SetPhysMemMap(0x05C80000, 0x05CFFFFF, FB[FBDrawWhich], sizeof(FB[0]), true);

 FBManualPending = false;
 FBVBErasePending = false;
 FBVBEraseActive = false;

 LOPR = 0;
 CurCommandAddr = 0;
 RetCommandAddr = -1;
 DrawingActive = false;
 CycleCounter = 0;
 CommandPhase = 0;
 memset(CommandData, 0, sizeof(CommandData));
 InstantDrawSanityLimit = 0;
 DTACounter = 0;

 //
 // Begin registers/variables confirmed to be initialized on reset.
 TVMR = 0;
 FBCR = 0;
 PTMR = 0;
 EDSR = 0;
 // End confirmed.
 //

 memset(&EraseParams, 0, sizeof(EraseParams));
 EraseYCounter = ~0U;
}

static int32 CMD_SetUserClip(const uint16* cmd_data)
{
 UserClipX0 = cmd_data[0x6] & 0x1FFF;
 UserClipY0 = cmd_data[0x7] & 0x1FFF;

 UserClipX1 = cmd_data[0xA] & 0x1FFF;
 UserClipY1 = cmd_data[0xB] & 0x1FFF;

 return 0;
}

int32 CMD_SetSystemClip(const uint16* cmd_data)
{
 SysClipX = cmd_data[0xA] & 0x1FFF;
 SysClipY = cmd_data[0xB] & 0x1FFF;

 return 0;
}

int32 CMD_SetLocalCoord(const uint16* cmd_data)
{
 LocalX = sign_x_to_s32(11, cmd_data[0x6] & 0x7FF);
 LocalY = sign_x_to_s32(11, cmd_data[0x7] & 0x7FF);

 return 0;
}

template<unsigned ECDSPDMode>
static uint32 MDFN_FASTCALL TexFetch(uint32 x)
{
 const uint32 base = LineData.tex_base;
 const bool ECD = ECDSPDMode & 0x10;
 const bool SPD = ECDSPDMode & 0x08;
 const unsigned ColorMode = ECDSPDMode & 0x07;

 uint32 rtd;
 uint32 ret_or = 0;

 switch(ColorMode)
 {
  case 0:	// 16 colors, color bank
	rtd = (VRAM[(base + (x >> 2)) & 0x3FFFF] >> (((x & 0x3) ^ 0x3) << 2)) & 0xF;
	VRAMUsageDrawRead((base + (x >> 2)) & 0x3FFFF);

	if(!ECD && rtd == 0xF)
	{
	 LineData.ec_count--;	
	 return -1;
	}
	ret_or = LineData.cb_or;
	
	if(!SPD) ret_or |= (int32)(rtd - 1) >> 31;

	return rtd | ret_or;

  case 1:	// 16 colors, LUT
	rtd = (VRAM[(base + (x >> 2)) & 0x3FFFF] >> (((x & 0x3) ^ 0x3) << 2)) & 0xF;
	VRAMUsageDrawRead((base + (x >> 2)) & 0x3FFFF);

	if(!ECD && rtd == 0xF)
	{
	 LineData.ec_count--;
	 return -1;
	}

	if(!SPD) ret_or |= (int32)(rtd - 1) >> 31;

	return LineData.CLUT[rtd] | ret_or;

  case 2:	// 64 colors, color bank
	rtd = (VRAM[(base + (x >> 1)) & 0x3FFFF] >> (((x & 0x1) ^ 0x1) << 3)) & 0xFF;
	VRAMUsageDrawRead((base + (x >> 1)) & 0x3FFFF);

	if(!ECD && rtd == 0xFF)
	{
	 LineData.ec_count--;
	 return -1;
	}

	ret_or = LineData.cb_or;

	if(!SPD) ret_or |= (int32)(rtd - 1) >> 31;

	return (rtd & 0x3F) | ret_or;

  case 3:	// 128 colors, color bank
	rtd = (VRAM[(base + (x >> 1)) & 0x3FFFF] >> (((x & 0x1) ^ 0x1) << 3)) & 0xFF;
	VRAMUsageDrawRead((base + (x >> 1)) & 0x3FFFF);

	if(!ECD && rtd == 0xFF)
	{
	 LineData.ec_count--;
	 return -1;
	}

	ret_or = LineData.cb_or;

	if(!SPD) ret_or |= (int32)(rtd - 1) >> 31;

	return (rtd & 0x7F) | ret_or;

  case 4:	// 256 colors, color bank
	rtd = (VRAM[(base + (x >> 1)) & 0x3FFFF] >> (((x & 0x1) ^ 0x1) << 3)) & 0xFF;
	VRAMUsageDrawRead((base + (x >> 1)) & 0x3FFFF);

	if(!ECD && rtd == 0xFF)
	{
	 LineData.ec_count--;
	 return -1;
	}

	ret_or = LineData.cb_or;

	if(!SPD) ret_or |= (int32)(rtd - 1) >> 31;

	return rtd | ret_or;

  case 5:	// 32K colors, RGB
  case 6:
  case 7:
	if(ColorMode >= 6)
	 rtd = VRAM[0];
	else
	 rtd = VRAM[(base + x) & 0x3FFFF];
	VRAMUsageDrawRead((ColorMode >= 6) ? 0 : ((base + x) & 0x3FFFF));

	if(!ECD && (rtd & 0xC000) == 0x4000)
	{
	 LineData.ec_count--;
	 return -1;
	}

	if(!SPD) ret_or |= (int32)(rtd - 0x4000) >> 31;

	return rtd | ret_or;
 }
}


MDFN_HIDE extern uint32 (MDFN_FASTCALL *const TexFetchTab[0x20])(uint32 x) =
{
 #define TF(a) (TexFetch<a>)

 TF(0x00), TF(0x01), TF(0x02), TF(0x03),
 TF(0x04), TF(0x05), TF(0x06), TF(0x07),

 TF(0x08), TF(0x09), TF(0x0A), TF(0x0B),
 TF(0x0C), TF(0x0D), TF(0x0E), TF(0x0F),

 TF(0x10), TF(0x11), TF(0x12), TF(0x13),
 TF(0x14), TF(0x15), TF(0x16), TF(0x17),

 TF(0x18), TF(0x19), TF(0x1A), TF(0x1B),
 TF(0x1C), TF(0x1D), TF(0x1E), TF(0x1F),

 #undef TF
};

bool SetupDrawLine(int32* const cycle_counter, const bool AA, const bool Textured, const uint16 mode)
{
 const bool HSS = (mode & 0x1000);
 const bool PCD = (mode & 0x800);
 const bool UserClipEn = (mode & 0x400);
 const bool UserClipMode = (mode & 0x200);
 //const bool ECD = (mode & 0x80);
 //const bool SPD = (mode & 0x40);
 const bool GouraudEn = (mode & 0x8004) == 0x4;
 line_vertex p0 = LineData.p[0];
 line_vertex p1 = LineData.p[1];
 line_inner_data& lid = LineInnerData;
 bool clipped = false;

 p0.x &= 0x1FFF;
 p0.y &= 0x1FFF;
 p1.x &= 0x1FFF;
 p1.y &= 0x1FFF;

 //printf("(0x%04x,0x%04x) -> (0x%04x,0x%04x)\n", p0.x, p0.y, p1.x, p1.y);

 if(!PCD)
 {
  bool swapped = false;

  *cycle_counter += 4;

  if(UserClipEn && !UserClipMode)
  {
   // Ignore system clipping WRT pre-clip for UserClipEn == 1 && UserClipMode == 0
   clipped |= (((UserClipX1 - p0.x) & (UserClipX1 - p1.x)) | ((p0.x - UserClipX0) & (p1.x - UserClipX0))) & 0x1000;
   clipped |= (((UserClipY1 - p0.y) & (UserClipY1 - p1.y)) | ((p0.y - UserClipY0) & (p1.y - UserClipY0))) & 0x1000;

   swapped = (p0.y == p1.y) & ((p0.x < UserClipX0) | (p0.x > UserClipX1));
  }
  else
  {
   clipped |= (((SysClipX - p0.x) & (SysClipX - p1.x)) | (p0.x & p1.x)) & 0x1000;
   clipped |= (((SysClipY - p0.y) & (SysClipY - p1.y)) | (p0.y & p1.y)) & 0x1000;

   swapped = (p0.y == p1.y) & (p0.x > SysClipX);
  }
  //
  // VDP1 reduces the line into a point to clip it, and it can be seen in the framebuffer under
  // certain conditions relating to coordinate precision.
  //
  if(clipped)
   p1 = p0;
  else if(swapped)
   std::swap(p0, p1);
 }

 *cycle_counter += 8;

 //
 //
 const int32 dx = sign_x_to_s32(13, p1.x - p0.x);
 const int32 dy = sign_x_to_s32(13, p1.y - p0.y);
 const int32 abs_dx = abs(dx); // & 0xFFF;
 const int32 abs_dy = abs(dy); // & 0xFFF;
 const int32 max_adx_ady = std::max<int32>(abs_dx, abs_dy);
 const int32 x_inc = (dx >= 0) ? 1 : -1;
 const int32 y_inc = (dy >= 0) ? 1 : -1;

 lid.x_inc = (x_inc & 0x7FF) <<  0;
 lid.y_inc = (y_inc & 0x7FF) << 16;
 lid.xy = (p0.x & 0x7FF) + ((p0.y & 0x7FF) << 16);
 lid.term_xy = (p1.x & 0x7FF) + ((p1.y & 0x7FF) << 16);
 lid.drawn_ac = true;	// Drawn all-clipped
 lid.color = LineData.color;

 //if(max_adx_ady >= 2048)
 // printf("%d,%d ->  %d, %d\n", p0.x, p0.y, p1.x, p1.y);

 if(GouraudEn)
  lid.g.Setup(max_adx_ady + 1, p0.g, p1.g);

 if(Textured)
 {
  LineData.ec_count = 2;	// Call before tffn()

  if(MDFN_UNLIKELY(max_adx_ady < abs(p1.t - p0.t) && HSS))
  {
   LineData.ec_count = 0x7FFFFFFF;
   lid.t.Setup(max_adx_ady + 1, p0.t >> 1, p1.t >> 1, 2, (bool)(FBCR & FBCR_EOS));
  }
  else
   lid.t.Setup(max_adx_ady + 1, p0.t, p1.t);

  lid.texel = LineData.tffn(lid.t.Current());
 }

 {
  int32 aa_x_inc;
  int32 aa_y_inc;

  if(abs_dy > abs_dx)
  {
   if(y_inc < 0)
   {
    aa_x_inc =  (x_inc >> 31);
    aa_y_inc = -(x_inc >> 31);
   }
   else
   {
    aa_x_inc = -(~x_inc >> 31);
    aa_y_inc =  (~x_inc >> 31);
   }
  }
  else
  {
   if(x_inc < 0)
   {
    aa_x_inc = -(~y_inc >> 31);
    aa_y_inc = -(~y_inc >> 31);
   }
   else
   {
    aa_x_inc =  (y_inc >> 31);
    aa_y_inc =  (y_inc >> 31);
   }
  }
  lid.aa_xy_inc = (aa_x_inc & 0x7FF) + ((aa_y_inc & 0x7FF) << 16);
 }

 // x, y, x_inc, y_inc, aa_x_inc, aa_y_inc, term_x, term_y, error, error_inc, error_adj, t, g, color
 lid.abs_dy_gt_abs_dx = abs_dy > abs_dx;

 if(abs_dy > abs_dx)
 {
  lid.error_inc =  (2 * abs_dx);
  lid.error_adj = -(2 * abs_dy);
  lid.error = (abs_dy - (2 * abs_dy)) - 1;
  lid.error_cmp = 0;

  if(dy < 0 && !AA)
   lid.error_cmp--;

  lid.error -= lid.error_inc;
  lid.xy = (lid.xy + (0x8000000 - lid.y_inc)) & 0x07FF07FF;
 }
 else
 {
  lid.error_inc =  (2 * abs_dy);
  lid.error_adj = -(2 * abs_dx);
  lid.error = (abs_dx - (2 * abs_dx)) - 1;
  lid.error_cmp = 0;

  if(dx < 0 && !AA)
   lid.error_cmp--;

  lid.error -= lid.error_inc;
  lid.xy = (lid.xy + (0x800 - lid.x_inc)) & 0x07FF07FF;
 }
 if(AA)
 {
  lid.error++;
  lid.error_cmp++;
 }

 //
 lid.error_inc <<= 32 - 13;
 lid.error_adj <<= 32 - 13;
 lid.error <<= 32 - 13;
 lid.error_cmp <<= 32 - 13;

 return clipped;
}

void EdgeStepper::Setup(const bool gourauden, const line_vertex& p0, const line_vertex& p1, const int32 dmax)
{
  int32 dx = sign_x_to_s32(13, p1.x - p0.x);
  int32 dy = sign_x_to_s32(13, p1.y - p0.y);
  int32 abs_dx = abs(dx);
  int32 abs_dy = abs(dy);
  int32 max_adxdy = std::max<int32>(abs_dx, abs_dy);

  //if(abs_dy == abs_dx)
  // printf("edge abs_dy == abs_dx; dy=%d dx=%d\n", dy, dx);

  //printf("%d %d, %d\n", dx, dy, dmax);

  x = p0.x;
  x_inc = (dx >= 0) ? 1 : -1;
  x_error_inc =  (2 * abs_dx);
  x_error_adj = -(2 * max_adxdy);
  x_error = (max_adxdy - (2 * max_adxdy)) - 1;
  x_error_cmp = (dy < 0) ? -1 : 0;

  y = p0.y;
  y_inc = (dy >= 0) ? 1 : -1;
  y_error_inc =  (2 * abs_dy);
  y_error_adj = -(2 * max_adxdy);
  y_error = (max_adxdy - (2 * max_adxdy)) - 1;
  y_error_cmp = (dx < 0) ? -1 : 0;

  d_error = dmax - (2 * dmax) - 1;
  d_error_inc =  (2 * max_adxdy);
  d_error_adj = -(2 * dmax);
  d_error_cmp = (((abs_dy > abs_dx) ? dy : dx) < 0) ? -1 : 0;
  //
  x_error <<= (32 - 13);
  x_error_inc <<= (32 - 13);
  x_error_adj <<= (32 - 13);
  x_error_cmp <<= (32 - 13);

  y_error <<= (32 - 13);
  y_error_inc <<= (32 - 13);
  y_error_adj <<= (32 - 13);
  y_error_cmp <<= (32 - 13);

  d_error <<= (32 - 13);
  d_error_inc <<= (32 - 13);
  d_error_adj <<= (32 - 13);
  d_error_cmp <<= (32 - 13);
  //
  if(gourauden)
   g.Setup(max_adxdy + 1, p0.g, p1.g);
}

enum : int { CommandPhaseBias = __COUNTER__ + 1 };
#define VDP1_EAT_CLOCKS(n)									\
		{										\
		 CycleCounter -= (n);								\
		 case __COUNTER__:								\
		 if(CycleCounter <= 0)								\
		 {										\
		  CommandPhase = __COUNTER__ - CommandPhaseBias - 1;				\
		  goto Breakout;								\
		 }										\
		}										\


static INLINE void DoDrawing(void)
{
#if 1
 if(MDFN_UNLIKELY(ss_horrible_hacks & HORRIBLEHACK_VDP1INSTANT))
  CycleCounter = InstantDrawSanityLimit; 
#endif

 switch(CommandPhase + CommandPhaseBias)
 {
  for(;;)
  {
   default:
   VDP1_EAT_CLOCKS(0);

   // Fetch command data
   memcpy(CommandData, &VRAM[CurCommandAddr], sizeof(CommandData));

   VDP1_EAT_CLOCKS(16);

   for(unsigned i = 0; i < 16; i++)
    VRAMUsageDrawRead((CurCommandAddr + i) * 2);

   //SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] Command @ 0x%06x: 0x%04x\n", CurCommandAddr, cmd_data[0]);

   if(MDFN_LIKELY(!(CommandData[0] & 0xC000)))
   {
    if(MDFN_UNLIKELY((CommandData[0] & 0xF) >= 0xC))
    {
     DrawingActive = false;
     VRAMUsageEnd();
     goto Breakout;
    }
    else
    {
     static int32 (*const command_table[0xC])(const uint16* cmd_data) =
     {
      /* 0x0 */         /* 0x1 */           /* 0x2 */            /* 0x3 */
      CMD_NormalSprite, CMD_ScaledSprite,   CMD_DistortedSprite, CMD_DistortedSprite,

      /* 0x4 */         /* 0x5 (polyline) *//* 0x6 */            /* 0x7 (polyline) */
      CMD_Polygon,      CMD_Line,	    CMD_Line,            CMD_Line,

      /* 0x8*/          /* 0x9 */           /* 0xA */            /* 0xB */
      CMD_SetUserClip,  CMD_SetSystemClip,  CMD_SetLocalCoord,   CMD_SetUserClip
     };

     static int32 (*const resume_table[0x8])(const uint16* cmd_data) =
     {
      /* 0x0 */         /* 0x1 */         /* 0x2 */            /* 0x3 */
      RESUME_Sprite, RESUME_Sprite, RESUME_Sprite, RESUME_Sprite,

      /* 0x4 */    /* 0x5 */     /* 0x6 */ /* 0x7 */
      RESUME_Polygon, RESUME_Line, RESUME_Line, RESUME_Line,
     };

     VDP1_EAT_CLOCKS(command_table[CommandData[0] & 0xF](CommandData));
     if(!(CommandData[0] & 0x8))
     {
      for(;;)
      {
       int32 cycles;

       cycles = resume_table[CommandData[0] & 0x7](CommandData);

       if(!cycles)
        break;

       VDP1_EAT_CLOCKS(cycles);
      }
     }
    }
   }
   else if(MDFN_UNLIKELY(CommandData[0] & 0x8000))
   {
    SS_DBGTI(SS_DBG_VDP1, "[VDP1] Drawing finished at 0x%05x", CurCommandAddr);
    DrawingActive = false;
    VRAMUsageEnd();

    EDSR |= 0x2;	// TODO: Does EDSR reflect IRQ out status?

    SCU_SetInt(SCU_INT_VDP1, true);
    SCU_SetInt(SCU_INT_VDP1, false);
    goto Breakout;
   }

   CurCommandAddr = (CurCommandAddr + 0x10) & 0x3FFFF;
   switch((CommandData[0] >> 12) & 0x3)
   {
    case 0:
	break;

    case 1:
	CurCommandAddr = (CommandData[1] << 2) &~ 0xF;
	break;

    case 2:
	if(RetCommandAddr < 0)
	 RetCommandAddr = CurCommandAddr;

	CurCommandAddr = (CommandData[1] << 2) &~ 0xF;
	break;

    case 3:
	if(RetCommandAddr >= 0)
	{
	 CurCommandAddr = RetCommandAddr;
	 RetCommandAddr = -1;
	}
	break;
   }
  //
  //
  //
  }
 }
 Breakout:;

#if 1
 if(MDFN_UNLIKELY(ss_horrible_hacks & HORRIBLEHACK_VDP1INSTANT))
  InstantDrawSanityLimit = CycleCounter;
#endif
}

sscpu_timestamp_t Update(sscpu_timestamp_t timestamp)
{
 if(MDFN_UNLIKELY(timestamp < lastts))
 {
  // Don't else { } normal execution, since this bug condition miiight occur in the call from SetHBVB(),
  // and we need drawing to start ASAP before silly games overwrite the beginning of the command table.
  //
  SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] [BUG] timestamp(%d) < lastts(%d)", timestamp, lastts);
  timestamp = lastts;
 }
 //
 // 
 //
 int32 cycles = timestamp - lastts;
 lastts = timestamp;

 CycleCounter += cycles;
 if(CycleCounter > VDP1_UpdateTimingGran)
  CycleCounter = VDP1_UpdateTimingGran;

 if(CycleCounter > 0 && SCU_CheckVDP1HaltKludge())
 {
  //puts("Kludge");
  CycleCounter = 0;
 }
 else if(DrawingActive)
  DoDrawing();

 return timestamp + (DrawingActive ? std::max<int32>(VDP1_UpdateTimingGran, 0 - CycleCounter) : VDP1_IdleTimingGran);
}

// Draw-clear minimum x amount is 2(16-bit units) for normal and 8bpp, and 8 for rotate...actually, seems like
// rotate being enabled forces vblank erase mode somehow.

static void StartDrawing(void)
{
 if(DrawingActive)
 {
  SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] Drawing interrupted by new drawing start request.");
 }

 SS_DBGTI(SS_DBG_VDP1, "[VDP1] Started drawing to framebuffer %d.", FBDrawWhich);

 // On draw start, clear CEF.
 EDSR &= ~0x2;

 CurCommandAddr = 0;
 RetCommandAddr = -1;
 DrawingActive = true;
 CommandPhase = 0;
 VRAMUsageStart();

 CycleCounter = VDP1_UpdateTimingGran;
}

void SetHBVB(const sscpu_timestamp_t event_timestamp, const bool new_hb_status, const bool new_vb_status)
{
 const bool old_hb_status = hb_status;
 const bool old_vb_status = vb_status;

 hb_status = new_hb_status;
 vb_status = new_vb_status;

 if(MDFN_UNLIKELY(vbcdpending & hb_status & (old_hb_status ^ hb_status)))
 {
  vbcdpending = false;

  if(vb_status) // Going into v-blank
  {
   //
   // v-blank erase
   //
   if((TVMR & TVMR_VBE) || FBVBErasePending)
   {
    SS_DBGTI(SS_DBG_VDP1, "[VDP1] VB erase start of framebuffer %d.", !FBDrawWhich);

    FBVBErasePending = false;
    FBVBEraseActive = true;
    FBVBEraseLastTS = event_timestamp;
   }
  }
  else // Leaving v-blank
  {
   InstantDrawSanityLimit = 1000000;

   // Run vblank erase at end of vblank all at once(not strictly accurate, but should only have visible side effects wrt the debugger and reset).
   if(FBVBEraseActive)
   {
    int32 count = event_timestamp - FBVBEraseLastTS;
    //printf("%d %d, %d\n", event_timestamp, FBVBEraseLastTS, count);
    //
    //
    //
    uint32 y = EraseParams.y_start;

    do
    {
     uint16* fbyptr;
     uint32 x = EraseParams.x_start;

     fbyptr = &FB[!FBDrawWhich][(y & 0xFF) << 9];
     if(EraseParams.rot8)
      fbyptr += (y & 0x100);

     count -= 8;
     do
     {
      for(unsigned sub = 0; sub < 8; sub++)
      {
       //printf("%d %d:%d %04x\n", FBDrawWhich, x, y, fill_data);
       //printf("%lld\n", &fbyptr[x & fb_x_mask] - FB[!FBDrawWhich]);
       fbyptr[x & EraseParams.fb_x_mask] = EraseParams.fill_data;
       x++;
      }
      count -= 8;
      if(MDFN_UNLIKELY(count <= 0))
      {
       SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] VB erase of framebuffer %d ran out of time.", !FBDrawWhich);
       goto AbortVBErase;
      }
     } while(x < EraseParams.x_bound);
    } while(++y <= EraseParams.y_end);

    AbortVBErase:;
    //
    FBVBEraseActive = false;
   }
   //
   //
   //
   //
   if(!(FBCR & FBCR_FCM) || (FBManualPending && (FBCR & FBCR_FCT)))	// Swap framebuffers
   {
#if 1
    if((ss_horrible_hacks & HORRIBLEHACK_VDP1VRAM5000FIX) && DrawingActive && VRAM[0] == 0x5000 && VRAM[1] == 0x0000)
     VRAM[0] = 0x8000;
#endif

    if(DrawingActive)
    {
     SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] Drawing aborted by framebuffer swap.");
     DrawingActive = false;
     VRAMUsageEnd();
    }

    FBDrawWhich = !FBDrawWhich;
    FBDrawWhichPtr = FB[FBDrawWhich];

    SS_DBGTI(SS_DBG_VDP1, "[VDP1] Displayed framebuffer changed to %d.", !FBDrawWhich);

    // On fb swap, copy CEF to BEF, clear CEF, and copy COPR to LOPR.
    EDSR = EDSR >> 1;
    LOPR = CurCommandAddr >> 2;

    //
    EraseParams.rot8 = (TVMR & (TVMR_8BPP | TVMR_ROTATE)) == (TVMR_8BPP | TVMR_ROTATE);
    EraseParams.fb_x_mask = EraseParams.rot8 ? 0xFF : 0x1FF;

    EraseParams.y_start = EWLR & 0x1FF;
    EraseParams.x_start = ((EWLR >> 9) & 0x3F) << 3;

    EraseParams.y_end = EWRR & 0x1FF;
    EraseParams.x_bound = ((EWRR >> 9) & 0x7F) << 3;

    EraseParams.fill_data = EWDR;
    //

    if(PTMR & 0x2)	// Start drawing(but only if we swapped the frame)
    {
     StartDrawing();
     SS_SetEventNT(&events[SS_EVENT_VDP1], Update(event_timestamp));
    }
   }

   EraseYCounter = ~0U;
   if(!(FBCR & FBCR_FCM) || (FBManualPending && !(FBCR & FBCR_FCT)))
   {
    if(TVMR & TVMR_ROTATE)
     FBVBErasePending = true;
    else
     EraseYCounter = EraseParams.y_start;
   }

   FBManualPending = false;
  }
 }
 vbcdpending |= old_vb_status ^ vb_status;
}

bool GetLine(const int line, uint16* buf, unsigned w, uint32 rot_x, uint32 rot_y, uint32 rot_xinc, uint32 rot_yinc)
{
 bool ret = false;
 //
 //
 //
 if(TVMR & TVMR_ROTATE)
 {
  const uint16* fbptr = FB[!FBDrawWhich];

  if(TVMR & TVMR_8BPP)
  {
   for(unsigned i = 0; MDFN_LIKELY(i < w); i++)
   {
    const uint32 fb_x = rot_x >> 9;
    const uint32 fb_y = rot_y >> 9;

    if((fb_x | fb_y) &~ 0x1FF)
     buf[i] = 0;	// Not 0xFF00
    else
    {
     const uint16* fbyptr = fbptr + ((fb_y & 0xFF) << 9);
     uint8 tmp = ne16_rbo_be<uint8>(fbyptr, (fb_x & 0x1FF) | ((fb_y & 0x100) << 1));

     buf[i] = 0xFF00 | tmp;
    }

    rot_x += rot_xinc;
    rot_y += rot_yinc;
   }
  }
  else
  {
   for(unsigned i = 0; MDFN_LIKELY(i < w); i++)
   {
    const uint32 fb_x = rot_x >> 9;
    const uint32 fb_y = rot_y >> 9;

    if((fb_x &~ 0x1FF) | (fb_y &~ 0xFF))
     buf[i] = 0;
    else
     buf[i] = fbptr[(fb_y << 9) + fb_x];

    rot_x += rot_xinc;
    rot_y += rot_yinc;
   }
  }
 }
 else
 {
  const uint16* fbyptr = &FB[!FBDrawWhich][(line & 0xFF) << 9];

  if(TVMR & TVMR_8BPP)
   ret = true;

  for(unsigned i = 0; MDFN_LIKELY(i < w); i++)
   buf[i] = fbyptr[i];
 }

 //
 //
 //
 if(EraseYCounter <= EraseParams.y_end)
 {
  uint16* fbyptr;
  uint32 x = EraseParams.x_start;

  fbyptr = &FB[!FBDrawWhich][(EraseYCounter & 0xFF) << 9];
  if(EraseParams.rot8)
   fbyptr += (EraseYCounter & 0x100);

  do
  {
   for(unsigned sub = 0; sub < 2; sub++)
   {
    //printf("%d %d:%d %04x\n", FBDrawWhich, x, y, fill_data);
    //printf("%lld\n", &fbyptr[x & fb_x_mask] - FB[!FBDrawWhich]);
    fbyptr[x & EraseParams.fb_x_mask] = EraseParams.fill_data;
    x++;
   }
  } while(x < EraseParams.x_bound);

  EraseYCounter++;
 }

 return ret;
}

void AdjustTS(const int32 delta)
{
 lastts += delta;
 if(FBVBEraseActive)
  FBVBEraseLastTS += delta;

 LastRWTS = std::max<sscpu_timestamp_t>(-1000000, LastRWTS + delta);

 VRAMUsageAddBaseTime(-delta);
}

static INLINE void WriteReg(const unsigned which, const uint16 value)
{
 SS_SetEventNT(&events[SS_EVENT_VDP2], VDP2::Update(SH7095_mem_timestamp));
 sscpu_timestamp_t nt = Update(SH7095_mem_timestamp);

 SS_DBGTI(SS_DBG_VDP1_REGW, "[VDP1] Register write: 0x%02x: 0x%04x", which << 1, value);

 switch(which)
 {
  default:
	SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] Unknown write of value 0x%04x to register 0x%02x", value, which << 1);
	break;

  case 0x0:	// TVMR
	TVMR = value & 0xF;
	break;

  case 0x1:	// FBCR
	FBCR = value & 0x1F;
	FBManualPending |= value & 0x2;
	break;

  case 0x2:	// PTMR
	PTMR = (value & 0x3);
	if(value & 0x1)
	{
	 StartDrawing();
	 nt = SH7095_mem_timestamp + 1;
	}
	break;

  case 0x3:	// EWDR
	EWDR = value;
	break;

  case 0x4:	// EWLR
	EWLR = value & 0x7FFF;
	break;

  case 0x5:	// EWRR
	EWRR = value;
	break;

  case 0x6:	// ENDR
	if(DrawingActive)
	{
	 DrawingActive = false;
         VRAMUsageEnd();
	 if(CycleCounter < 0)
	  CycleCounter = 0;
	 nt = SH7095_mem_timestamp + VDP1_IdleTimingGran;
	 SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] Program forced termination of VDP1 drawing.");
	}
	break;

 }

 SS_SetEventNT(&events[SS_EVENT_VDP1], nt);
}

static INLINE uint16 ReadReg(const unsigned which)
{
 switch(which)
 {
  default:
	SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] Unknown read from register 0x%02x", which);
	return 0;

  case 0x8:	// EDSR
	return EDSR;

  case 0x9:	// LOPR
	return LOPR;

  case 0xA:	// COPR
	return CurCommandAddr >> 2;

  case 0xB:	// MODR
	return (0x1 << 12) | ((PTMR & 0x2) << 7) | ((FBCR & 0x1E) << 3) | (TVMR << 0);
 }
}

//
// Due to the emulated CPUs running faster than they should(due to lack of instruction cache emulation, lack of emulation of some pipeline details,
// lack of memory refresh cycle emulation), there is the potential that a game may write too much data too fast, causing drawing to timeout and abort,
// and the game could subsequently hang waiting for drawing to complete.  With this in mind, only selectively enable it for games that are known
// to benefit, via the horrible hacks mechanism.
//
MDFN_FASTCALL void Write_CheckDrawSlowdown(uint32 A, sscpu_timestamp_t time_thing)
{
 if(DrawingActive && time_thing > LastRWTS && (ss_horrible_hacks & HORRIBLEHACK_VDP1RWDRAWSLOWDOWN))
 {
  const int32 count = (A & 0x100000) ? 22 : 25;
  const uint32 a = std::min<uint32>(count, time_thing - LastRWTS);

  CycleCounter -= a;
  LastRWTS = time_thing;
 }
}

MDFN_FASTCALL void Read_CheckDrawSlowdown(uint32 A, sscpu_timestamp_t time_thing)
{
 //printf("%08x\n", A);
 if(!(A & 0x100000) && time_thing > LastRWTS && DrawingActive && (ss_horrible_hacks & HORRIBLEHACK_VDP1RWDRAWSLOWDOWN))
 {
  const int32 count = (A & 0x80000) ? 44 : 41;
  const uint32 a = std::min<uint32>(count, time_thing - LastRWTS);

  CycleCounter -= a;
  LastRWTS = time_thing;
 }
}

MDFN_FASTCALL void Write8_DB(uint32 A, uint16 DB)
{
 A &= 0x1FFFFF;

 if(A < 0x80000)
 {
  VRAMUsageWrite(A >> 1);
  SS_DBGTI(SS_DBG_VDP1_VRAMW, "[VDP1] Write to VRAM: 0x%02x->VRAM[0x%05x]", (DB >> (((A & 1) ^ 1) << 3)) & 0xFF, A);
  ne16_wbo_be<uint8>(VRAM, A, DB >> (((A & 1) ^ 1) << 3) );
  return;
 }

 if(A < 0x100000)
 {
  uint32 FBA = A;

  SS_DBGTI(SS_DBG_VDP1_FBW, "[VDP1] Write to FB: 0x%02x->FB[%d][0x%05x] CycleCounter=%d", (DB >> (((A & 1) ^ 1) << 3)) & 0xFF, FBDrawWhich, A & 0x3FFFF, CycleCounter);

  if((TVMR & (TVMR_8BPP | TVMR_ROTATE)) == (TVMR_8BPP | TVMR_ROTATE))
   FBA = (FBA & 0x1FF) | ((FBA << 1) & 0x3FC00) | ((FBA >> 8) & 0x200);

  ne16_wbo_be<uint8>(FB[FBDrawWhich], FBA & 0x3FFFF, DB >> (((A & 1) ^ 1) << 3) );
  return;
 }

 SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] 8-bit write to 0x%08x(DB=0x%04x)", A, DB);
 WriteReg((A - 0x100000) >> 1, DB);
}

MDFN_FASTCALL void Write16_DB(uint32 A, uint16 DB)
{
 A &= 0x1FFFFE;

 if(A < 0x80000)
 {
  VRAMUsageWrite(A >> 1);
  SS_DBGTI(SS_DBG_VDP1_VRAMW, "[VDP1] Write to VRAM: 0x%04x->VRAM[0x%05x]", DB, A);
  VRAM[A >> 1] = DB;
  return;
 }

 if(A < 0x100000)
 {
  uint32 FBA = A;

  SS_DBGTI(SS_DBG_VDP1_FBW, "[VDP1] Write to FB: 0x%04x->FB[%d][0x%05x] CycleCounter=%d", DB, FBDrawWhich, A & 0x3FFFF, CycleCounter);

  if((TVMR & (TVMR_8BPP | TVMR_ROTATE)) == (TVMR_8BPP | TVMR_ROTATE))
   FBA = (FBA & 0x1FF) | ((FBA << 1) & 0x3FC00) | ((FBA >> 8) & 0x200);

  FB[FBDrawWhich][(FBA >> 1) & 0x1FFFF] = DB;
  return;
 }

 WriteReg((A - 0x100000) >> 1, DB);
}

MDFN_FASTCALL uint16 Read16_DB(uint32 A)
{
 A &= 0x1FFFFE;

 if(A < 0x080000)
  return VRAM[A >> 1];

 if(A < 0x100000)
 {
  uint32 FBA = A;

  if((TVMR & (TVMR_8BPP | TVMR_ROTATE)) == (TVMR_8BPP | TVMR_ROTATE))
   FBA = (FBA & 0x1FF) | ((FBA << 1) & 0x3FC00) | ((FBA >> 8) & 0x200);

  return FB[FBDrawWhich][(FBA >> 1) & 0x1FFFF];
 }

 return ReadReg((A - 0x100000) >> 1);
}

void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT Prim_StateRegs[] =
 {
  SFVAR(PrimData.e->d_error, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->d_error_inc, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->d_error_adj, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->d_error_cmp, 0x2, sizeof(*PrimData.e), PrimData.e),

  SFVAR(PrimData.e->x, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->x_inc, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->x_error, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->x_error_inc, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->x_error_adj, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->x_error_cmp, 0x2, sizeof(*PrimData.e), PrimData.e),

  SFVAR(PrimData.e->y, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->y_inc, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->y_error, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->y_error_inc, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->y_error_adj, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->y_error_cmp, 0x2, sizeof(*PrimData.e), PrimData.e),

  SFVAR(PrimData.e->g.g, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->g.intinc, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->g.ginc, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->g.error, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->g.error_inc, 0x2, sizeof(*PrimData.e), PrimData.e),
  SFVAR(PrimData.e->g.error_adj, 0x2, sizeof(*PrimData.e), PrimData.e),

  SFVAR(PrimData.big_t.t),
  SFVAR(PrimData.big_t.tinc),
  SFVAR(PrimData.big_t.error),
  SFVAR(PrimData.big_t.error_inc),
  SFVAR(PrimData.big_t.error_adj),

  SFVAR(PrimData.iter),
  SFVAR(PrimData.tex_base),
  SFVAR(PrimData.need_line_resume),
  //
  //
  //
  SFVAR(LineInnerData.xy),
  SFVAR(LineInnerData.error),
  SFVAR(LineInnerData.drawn_ac),

  SFVAR(LineInnerData.texel),

  SFVAR(LineInnerData.t.t),
  SFVAR(LineInnerData.t.tinc),
  SFVAR(LineInnerData.t.error),
  SFVAR(LineInnerData.t.error_inc),
  SFVAR(LineInnerData.t.error_adj),

  SFVAR(LineInnerData.g.g),
  SFVAR(LineInnerData.g.intinc),
  SFVAR(LineInnerData.g.ginc),
  SFVAR(LineInnerData.g.error),
  SFVAR(LineInnerData.g.error_inc),
  SFVAR(LineInnerData.g.error_adj),

  SFVAR(LineInnerData.x_inc),
  SFVAR(LineInnerData.y_inc),
  SFVAR(LineInnerData.aa_xy_inc),
  SFVAR(LineInnerData.term_xy),

  SFVAR(LineInnerData.error_cmp),
  SFVAR(LineInnerData.error_inc),
  SFVAR(LineInnerData.error_adj),

  SFVAR(LineInnerData.color),

  SFVAR(LineInnerData.abs_dy_gt_abs_dx),
  //
  //
  //
  SFVAR(LineData.p->t, 0x2, sizeof(*LineData.p), LineData.p),
  SFVAR(LineData.color),
  SFVAR(LineData.ec_count),
  //uint32 (MDFN_FASTCALL *tffn)(uint32);
  SFVAR(LineData.CLUT),
  SFVAR(LineData.cb_or),
  SFVAR(LineData.tex_base),
  //
  //
  //
  SFEND
 };

 SFORMAT StateRegs[] =
 {
  SFVAR(VRAM),
  SFVARN(FB, "&FB[0][0]"),
  SFVAR(FBDrawWhich),

  SFVAR(FBManualPending),

  SFVAR(FBVBErasePending),
  SFVAR(FBVBEraseActive),
  SFVAR(FBVBEraseLastTS),

  SFVAR(SysClipX),
  SFVAR(SysClipY),
  SFVAR(UserClipX0),
  SFVAR(UserClipY0),
  SFVAR(UserClipX1),
  SFVAR(UserClipY1),
  SFVAR(LocalX),
  SFVAR(LocalY),

  SFVAR(CurCommandAddr),
  SFVAR(RetCommandAddr),
  SFVAR(DrawingActive),

  SFVAR(LOPR),

  SFVAR(EWDR),
  SFVAR(EWLR),
  SFVAR(EWRR),	// Erase/Write Lower Right Coordinate

  SFVAR(EraseParams.rot8),
  // Recovered in if(load): SFVAR(EraseParams.fb_x_mask),

  SFVAR(EraseParams.y_start),
  SFVAR(EraseParams.x_start),

  SFVAR(EraseParams.y_end),
  SFVAR(EraseParams.x_bound),

  SFVAR(EraseParams.fill_data),

  SFVAR(EraseYCounter),

  SFVAR(TVMR),
  SFVAR(FBCR),
  SFVAR(PTMR),
  SFVAR(EDSR),

  SFVAR(vb_status),
  SFVAR(hb_status),
  SFVAR(lastts),
  SFVAR(CycleCounter),
  SFVAR(CommandPhase),
  SFVAR(CommandData),
  SFVAR(DTACounter),

  SFVAR(vbcdpending),

  SFVAR(LastRWTS),

  SFVAR(InstantDrawSanityLimit),

  SFLINK(Prim_StateRegs),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "VDP1");

 if(load)
 {
  CurCommandAddr &= 0x3FFFF;
  if(RetCommandAddr >= 0)
   RetCommandAddr &= 0x3FFFF;

  DTACounter &= 0xFF;

  EraseParams.fb_x_mask = EraseParams.rot8 ? 0xFF : 0x1FF;

  EraseParams.y_start &= 0x1FF;
  EraseParams.x_start &= 0x3F << 3;

  EraseParams.y_end &= 0x1FF;
  EraseParams.x_bound &= 0x7F << 3;
  //
  FBDrawWhichPtr = FB[FBDrawWhich];

  if(load < 0x00102500)
  {
   CommandPhase = 0;
  }
 }
}

void MakeDump(const std::string& path)
{
 FileStream fp(path, FileStream::MODE_WRITE);

 for(unsigned i = 0; i < 0x40000; i++)
  fp.print_format("0x%04x, ", VRAM[i]);

 fp.close();
}

uint32 GetRegister(const unsigned id, char* const special, const uint32 special_len)
{
 uint32 ret = 0xDEADBEEF;

 switch(id)
 {
  case GSREG_SYSCLIPX:
	ret = SysClipX;
	break;

  case GSREG_SYSCLIPY:
	ret = SysClipY;
	break;

  case GSREG_USERCLIPX0:
	ret = UserClipX0;
	break;

  case GSREG_USERCLIPY0:
	ret = UserClipY0;
	break;

  case GSREG_USERCLIPX1:
	ret = UserClipX1;
	break;

  case GSREG_USERCLIPY1:
	ret = UserClipY1;
	break;

  case GSREG_LOCALX:
	ret = LocalX;
	break;

  case GSREG_LOCALY:
	ret = LocalY;
 	break;

  case GSREG_TVMR:
	ret = TVMR;
	break;

  case GSREG_FBCR:
	ret = FBCR;
	break;

  case GSREG_EWDR:
	ret = EWDR;
	break;

  case GSREG_EWLR:
	ret = EWLR;
	break;

  case GSREG_EWRR:
	ret = EWRR;
	break;
 }

 return ret;
}

void SetRegister(const unsigned id, const uint32 value)
{
 // TODO
 switch(id)
 {
  case GSREG_SYSCLIPX:
	SysClipX = value & 0x1FFF;
	break;

  case GSREG_SYSCLIPY:
	SysClipY = value & 0x1FFF;
	break;

  case GSREG_USERCLIPX0:
	UserClipX0 = value & 0x1FFF;
	break;

  case GSREG_USERCLIPY0:
	UserClipY0 = value & 0x1FFF;
	break;

  case GSREG_USERCLIPX1:
	UserClipX1 = value & 0x1FFF;
	break;

  case GSREG_USERCLIPY1:
	UserClipY1 = value & 0x1FFF;
	break;

/*
  case GSREG_LOCALX:
	ret = LocalX;
	break;

  case GSREG_LOCALY:
	ret = LocalY;
 	break;

  case GSREG_TVMR:
	ret = TVMR;
	break;

  case GSREG_FBCR:
	ret = FBCR;
	break;

  case GSREG_EWDR:
	ret = EWDR;
	break;

  case GSREG_EWLR:
	ret = EWLR;
	break;

  case GSREG_EWRR:
	ret = EWRR;
	break;
*/
 }
}

}

}
