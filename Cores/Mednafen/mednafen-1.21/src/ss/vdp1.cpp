/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp1.cpp - VDP1 Emulation
**  Copyright (C) 2015-2017 Mednafen Team
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

// TODO: Check to see what registers are reset on reset.

// TODO: Fix preclipping when raw system clipping values have bit12==1(sign bit?).

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
line_data LineSetup;
uint8 gouraud_lut[0x40];

uint16 VRAM[0x40000];
uint16 FB[2][0x20000];
bool FBDrawWhich;

static bool FBManualPending;

static bool FBVBErasePending;
static bool FBVBEraseActive;
static sscpu_timestamp_t FBVBEraseLastTS;

int32 SysClipX, SysClipY;
int32 UserClipX0, UserClipY0, UserClipX1, UserClipY1;
int32 LocalX, LocalY;

static uint32 CurCommandAddr;
static int32 RetCommandAddr;
static bool DrawingActive;

static uint16 LOPR;

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

uint8 TVMR;
uint8 FBCR;
uint8 PTMR;
static uint8 EDSR;

static bool vb_status, hb_status;
static sscpu_timestamp_t lastts;
static int32 CycleCounter;

static bool vbcdpending;

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

  memset(&LineSetup, 0, sizeof(LineSetup));

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
 //SS_SetPhysMemMap(0x05C80000, 0x05CFFFFF, FB[FBDrawWhich], sizeof(FB[0]), true);

 FBManualPending = false;
 FBVBErasePending = false;
 FBVBEraseActive = false;

 LOPR = 0;
 CurCommandAddr = 0;
 RetCommandAddr = -1;
 DrawingActive = false;

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

 CycleCounter = 0;
}

static int32 CMD_SetUserClip(const uint16* cmd_data)
{
 UserClipX0 = cmd_data[0x6] & 0x3FF;
 UserClipY0 = cmd_data[0x7] & 0x1FF;

 UserClipX1 = cmd_data[0xA] & 0x3FF;
 UserClipY1 = cmd_data[0xB] & 0x1FF;

 return 0;
}

int32 CMD_SetSystemClip(const uint16* cmd_data)
{
 SysClipX = cmd_data[0xA] & 0x3FF;
 SysClipY = cmd_data[0xB] & 0x1FF;

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
 const uint32 base = LineSetup.tex_base;
 const bool ECD = ECDSPDMode & 0x10;
 const bool SPD = ECDSPDMode & 0x08;
 const unsigned ColorMode = ECDSPDMode & 0x07;

 uint32 rtd;
 uint32 ret_or = 0;

 switch(ColorMode)
 {
  case 0:	// 16 colors, color bank
	rtd = (VRAM[(base + (x >> 2)) & 0x3FFFF] >> (((x & 0x3) ^ 0x3) << 2)) & 0xF;

	if(!ECD && rtd == 0xF)
	{
	 LineSetup.ec_count--;	
	 return -1;
	}
	ret_or = LineSetup.cb_or;
	
	if(!SPD) ret_or |= (int32)(rtd - 1) >> 31;

	return rtd | ret_or;

  case 1:	// 16 colors, LUT
	rtd = (VRAM[(base + (x >> 2)) & 0x3FFFF] >> (((x & 0x3) ^ 0x3) << 2)) & 0xF;

	if(!ECD && rtd == 0xF)
	{
	 LineSetup.ec_count--;
	 return -1;
	}

	if(!SPD) ret_or |= (int32)(rtd - 1) >> 31;

	return LineSetup.CLUT[rtd] | ret_or;

  case 2:	// 64 colors, color bank
	rtd = (VRAM[(base + (x >> 1)) & 0x3FFFF] >> (((x & 0x1) ^ 0x1) << 3)) & 0xFF;

	if(!ECD && rtd == 0xFF)
	{
	 LineSetup.ec_count--;
	 return -1;
	}

	ret_or = LineSetup.cb_or;

	if(!SPD) ret_or |= (int32)(rtd - 1) >> 31;

	return (rtd & 0x3F) | ret_or;

  case 3:	// 128 colors, color bank
	rtd = (VRAM[(base + (x >> 1)) & 0x3FFFF] >> (((x & 0x1) ^ 0x1) << 3)) & 0xFF;

	if(!ECD && rtd == 0xFF)
	{
	 LineSetup.ec_count--;
	 return -1;
	}

	ret_or = LineSetup.cb_or;

	if(!SPD) ret_or |= (int32)(rtd - 1) >> 31;

	return (rtd & 0x7F) | ret_or;

  case 4:	// 256 colors, color bank
	rtd = (VRAM[(base + (x >> 1)) & 0x3FFFF] >> (((x & 0x1) ^ 0x1) << 3)) & 0xFF;

	if(!ECD && rtd == 0xFF)
	{
	 LineSetup.ec_count--;
	 return -1;
	}

	ret_or = LineSetup.cb_or;

	if(!SPD) ret_or |= (int32)(rtd - 1) >> 31;

	return rtd | ret_or;

  case 5:	// 32K colors, RGB
  case 6:
  case 7:
	if(ColorMode >= 6)
	 rtd = VRAM[0];
	else
	 rtd = VRAM[(base + x) & 0x3FFFF];

	if(!ECD && (rtd & 0xC000) == 0x4000)
	{
	 LineSetup.ec_count--;
	 return -1;
	}

	if(!SPD) ret_or |= (int32)(rtd - 0x4000) >> 31;

	return rtd | ret_or;
 }
}


extern uint32 (MDFN_FASTCALL *const TexFetchTab[0x20])(uint32 x) =
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



/*
 Notes:
	When vblank starts: Abort command processing, and if VBE=1, erase framebuffer just displayed according to set values.

	When vblank ends: Abort framebuffer erase, swap framebuffer, and if (PTMR&2) start command processing.

	See if EDSR and LOPR are modified or not when PTMR=0 and an auto framebuffer swap occurs.

	FB erase params are latched at framebuffer swap time probably.

	VBE=1 is persistent.
*/

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
 {
  while(CycleCounter > 0)
  {
   uint16 cmd_data[0x10];

   // Fetch command data
   memcpy(cmd_data, &VRAM[CurCommandAddr], sizeof(cmd_data));
   CycleCounter -= 16;

   //SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] Command @ 0x%06x: 0x%04x\n", CurCommandAddr, cmd_data[0]);

   if(MDFN_LIKELY(!(cmd_data[0] & 0xC000)))
   {
    const unsigned cc = cmd_data[0] & 0xF;

    if(MDFN_UNLIKELY(cc >= 0xC))
    {
     DrawingActive = false;
     break;
    }
    else
    {
     static int32 (*const command_table[0xC])(const uint16* cmd_data) =
     {
      /* 0x0 */         /* 0x1 */         /* 0x2 */            /* 0x3 */
      CMD_NormalSprite, CMD_ScaledSprite, CMD_DistortedSprite, CMD_DistortedSprite,

      /* 0x4 */    /* 0x5 */     /* 0x6 */ /* 0x7 */
      CMD_Polygon, CMD_Polyline, CMD_Line, CMD_Polyline,

      /* 0x8*/         /* 0x9 */           /* 0xA */          /* 0xB */
      CMD_SetUserClip, CMD_SetSystemClip,  CMD_SetLocalCoord, CMD_SetUserClip
     };

     CycleCounter -= command_table[cc](cmd_data);
    }
   }
   else if(MDFN_UNLIKELY(cmd_data[0] & 0x8000))
   {
    SS_DBGTI(SS_DBG_VDP1, "[VDP1] Drawing finished at 0x%05x", CurCommandAddr);
    DrawingActive = false;

    EDSR |= 0x2;	// TODO: Does EDSR reflect IRQ out status?

    SCU_SetInt(SCU_INT_VDP1, true);
    SCU_SetInt(SCU_INT_VDP1, false);
    break;
   }

   CurCommandAddr = (CurCommandAddr + 0x10) & 0x3FFFF;
   switch((cmd_data[0] >> 12) & 0x3)
   {
    case 0:
	break;

    case 1:
	CurCommandAddr = (cmd_data[1] << 2) &~ 0xF;
	break;

    case 2:
	if(RetCommandAddr < 0)
	 RetCommandAddr = CurCommandAddr;

	CurCommandAddr = (cmd_data[1] << 2) &~ 0xF;
	break;

    case 3:
	if(RetCommandAddr >= 0)
	{
	 CurCommandAddr = RetCommandAddr;
	 RetCommandAddr = -1;
	}
	break;
   }
  }
 }

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
    if(DrawingActive)
    {
     SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] Drawing aborted by framebuffer swap.");
     DrawingActive = false;
    }

    FBDrawWhich = !FBDrawWhich;

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

   if(!(FBCR & FBCR_FCM) || (FBManualPending && !(FBCR & FBCR_FCT)))
   {
    if(TVMR & TVMR_ROTATE)
    {
     EraseYCounter = ~0U;
     FBVBErasePending = true;
    }
    else
    {
     EraseYCounter = EraseParams.y_start;
    }
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

void Write8_DB(uint32 A, uint16 DB)
{
 A &= 0x1FFFFF;

 if(A < 0x80000)
 {
  SS_DBGTI(SS_DBG_VDP1_VRAMW, "[VDP1] Write to VRAM: 0x%02x->VRAM[0x%05x]", (DB >> (((A & 1) ^ 1) << 3)) & 0xFF, A);
  ne16_wbo_be<uint8>(VRAM, A, DB >> (((A & 1) ^ 1) << 3) );
  return;
 }

 if(A < 0x100000)
 {
  uint32 FBA = A;

  SS_DBGTI(SS_DBG_VDP1_FBW, "[VDP1] Write to FB: 0x%02x->FB[%d][0x%05x]", (DB >> (((A & 1) ^ 1) << 3)) & 0xFF, FBDrawWhich, A & 0x3FFFF);

  if((TVMR & (TVMR_8BPP | TVMR_ROTATE)) == (TVMR_8BPP | TVMR_ROTATE))
   FBA = (FBA & 0x1FF) | ((FBA << 1) & 0x3FC00) | ((FBA >> 8) & 0x200);

  ne16_wbo_be<uint8>(FB[FBDrawWhich], FBA & 0x3FFFF, DB >> (((A & 1) ^ 1) << 3) );
  return;
 }

 SS_DBGTI(SS_DBG_WARNING | SS_DBG_VDP1, "[VDP1] 8-bit write to 0x%08x(DB=0x%04x)", A, DB);
 WriteReg((A - 0x100000) >> 1, DB);
}

void Write16_DB(uint32 A, uint16 DB)
{
 A &= 0x1FFFFE;

 if(A < 0x80000)
 {
  SS_DBGTI(SS_DBG_VDP1_VRAMW, "[VDP1] Write to VRAM: 0x%04x->VRAM[0x%05x]", DB, A);
  VRAM[A >> 1] = DB;
  return;
 }

 if(A < 0x100000)
 {
  uint32 FBA = A;

  SS_DBGTI(SS_DBG_VDP1_FBW, "[VDP1] Write to FB: 0x%04x->FB[%d][0x%05x]", DB, FBDrawWhich, A & 0x3FFFF);

  if((TVMR & (TVMR_8BPP | TVMR_ROTATE)) == (TVMR_8BPP | TVMR_ROTATE))
   FBA = (FBA & 0x1FF) | ((FBA << 1) & 0x3FC00) | ((FBA >> 8) & 0x200);

  FB[FBDrawWhich][(FBA >> 1) & 0x1FFFF] = DB;
  return;
 }

 WriteReg((A - 0x100000) >> 1, DB);
}

uint16 Read16_DB(uint32 A)
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

  SFVAR(vbcdpending),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "VDP1");

 if(load)
 {
  CurCommandAddr &= 0x3FFFF;
  if(RetCommandAddr >= 0)
   RetCommandAddr &= 0x3FFFF;

  EraseParams.fb_x_mask = EraseParams.rot8 ? 0xFF : 0x1FF;

  EraseParams.y_start &= 0x1FF;
  EraseParams.x_start &= 0x3F << 3;

  EraseParams.y_end &= 0x1FF;
  EraseParams.x_bound &= 0x7F << 3;
 }
}

void MakeDump(const std::string& path)
{
 FileStream fp(path, FileStream::MODE_WRITE);

 for(unsigned i = 0; i < 0x40000; i++)
  fp.print_format("0x%04x, ", VRAM[i]);

 fp.close();
}

}

}
