/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* tblur.cpp:
**  Copyright (C) 2007-2020 Mednafen Team
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

// TODO: Support resolution and format changes without screen garbage.

#include <mednafen/mednafen.h>
#include "tblur.h"

namespace Mednafen
{

struct HQPixelEntry
{
 uint16 a, b, c, d;
};

static std::unique_ptr<uint32[]> BlurBuf;
static uint32 AccumBlurAmount; // max of 16384, infinite blur!
static std::unique_ptr<HQPixelEntry[]> AccumBlurBuf;
static uint64 FormatWarningGiven;
//static uint64 BlurBufFormat;
static uint32 BlurBufPitchInPix;

void TBlur_Init(bool accum_mode, double accum_amount, uint32 max_width, uint32 max_height)
{
 try
 {
  BlurBufPitchInPix = max_width;
  //BlurBufFormat = 0;

  AccumBlurAmount = (uint32)(16384 * accum_amount / 100);

  if(accum_mode)
  {
   AccumBlurBuf.reset(new HQPixelEntry[BlurBufPitchInPix * max_height]);
   memset(AccumBlurBuf.get(), 0, sizeof(HQPixelEntry) * BlurBufPitchInPix * max_height);
  }
  else
  {
   BlurBuf.reset(new uint32[BlurBufPitchInPix * max_height]);
   memset(BlurBuf.get(), 0, sizeof(uint32) * BlurBufPitchInPix * max_height);
  }

  FormatWarningGiven = 0;
 }
 catch(...)
 {
  BlurBuf.reset(nullptr);
  AccumBlurBuf.reset(nullptr);
  throw;
 }
}

template<bool accum_half, typename T, uint64 rgb16_tag>
static INLINE void ProcessAccumRow(T* const pixrow, HQPixelEntry* accumrow, int w)
{
 const uint32 InvAccumBlurAmount = 16384 - AccumBlurAmount;

 for(int x = 0; x < w; x++)
 {
  uint32 color = pixrow[x];
  HQPixelEntry mixcolor = accumrow[x];

  // 0rrrrrgg gggbbbbb
  // rrrrrggg gggbbbbb
  if(accum_half)
  {
   if(sizeof(T) == 2)
   {
    mixcolor.a = ((uint32)mixcolor.a + ((color & (0x1F <<  0)) << 11) + 0x0400) >> 1;
    if(rgb16_tag == MDFN_PixelFormat::IRGB16_1555)
    {
     mixcolor.b = ((uint32)mixcolor.b + ((color & (0x1F <<  5)) <<  6) + 0x0400) >> 1;
     mixcolor.c = ((uint32)mixcolor.c + ((color & (0x1F << 10)) <<  1) + 0x0400) >> 1;
    }
    else
    {
     mixcolor.b = ((uint32)mixcolor.b + ((color & (0x3F <<  5)) <<  5) + 0x0200) >> 1;
     mixcolor.c = ((uint32)mixcolor.c + ((color & (0x1F << 11)) <<  0) + 0x0400) >> 1;
    }
   }
   else
   {
    mixcolor.a = ((uint32)mixcolor.a + ((color & 0xFF) << 8)) >> 1;
    mixcolor.b = ((uint32)mixcolor.b + ((color & 0xFF00))) >> 1;
    mixcolor.c = ((uint32)mixcolor.c + ((color & 0xFF0000) >> 8)) >> 1;
    mixcolor.d = ((uint32)mixcolor.d + ((color & 0xFF000000) >> 16)) >> 1;
   }
  }
  else
  {
   if(sizeof(T) == 2)
   {
    if(rgb16_tag == MDFN_PixelFormat::IRGB16_1555)
     color = ((color & 0x1F) << 3) | ((color << 6) & 0xF800) | ((color << 9) & 0xF80000) | 0x040404;
    else
     color = ((color & 0x1F) << 3) | ((color << 5) & 0xFC00) | ((color << 8) & 0xF80000) | 0x040204;
   }

   mixcolor.a = ((uint32)mixcolor.a * AccumBlurAmount + InvAccumBlurAmount * ((color & 0xFF) << 8)) >> 14;
   mixcolor.b = ((uint32)mixcolor.b * AccumBlurAmount + InvAccumBlurAmount * ((color & 0xFF00))) >> 14;
   mixcolor.c = ((uint32)mixcolor.c * AccumBlurAmount + InvAccumBlurAmount * ((color & 0xFF0000) >> 8)) >> 14;
   if(sizeof(T) != 2)
    mixcolor.d = ((uint32)mixcolor.d * AccumBlurAmount + InvAccumBlurAmount * ((color & 0xFF000000) >> 16)) >> 14;
  }
  accumrow[x] = mixcolor;

  if(sizeof(T) == 2)
  {
   if(rgb16_tag == MDFN_PixelFormat::IRGB16_1555)
    color = (mixcolor.a >> 11) | ((mixcolor.b >> 11) << 5) | ((mixcolor.c >> 11) << 10);
   else
    color = (mixcolor.a >> 11) | ((mixcolor.b >> 10) << 5) | ((mixcolor.c >> 11) << 11);
  }
  else
   color = ((mixcolor.a >> 8) << 0) | ((mixcolor.b >> 8) << 8) | ((mixcolor.c >> 8) << 16) | ((mixcolor.d >> 8) << 24);

  pixrow[x] = color;
 }
}

template<typename T, uint64 rgb16_tag = 0>
static void TBlurLoop(MDFN_Surface* surface, const MDFN_Rect& DisplayRect, const int32* LineWidths)
{
 const uint32 bbpitchinpix = BlurBufPitchInPix;
 const uint32 pitchinpix = surface->pitchinpix;
 const int w = DisplayRect.w;
 const int h = DisplayRect.h;
 T* pix = surface->pix<T>() + DisplayRect.x + DisplayRect.y * pitchinpix;

 if(LineWidths[0] != ~0)
  LineWidths += DisplayRect.y;
 else
  LineWidths = nullptr;
 //
 //
 //
 if(AccumBlurBuf)
 {
  for(int y = 0; y < h; y++)
  {
   int xw = LineWidths ? LineWidths[y] : w;
   T* pixrow = &pix[y * pitchinpix];
   HQPixelEntry* accumrow = &AccumBlurBuf[y * bbpitchinpix];

   if(AccumBlurAmount == 8192)
    ProcessAccumRow<true, T, rgb16_tag>(pixrow, accumrow, xw);
   else
    ProcessAccumRow<false, T, rgb16_tag>(pixrow, accumrow, xw);
  }
 }
 else if(BlurBuf)
 {
  for(int y = 0; y < h; y++)
  {
   int xw = LineWidths ? LineWidths[y] : w;

   for(int x = 0; x < xw; x++)
   {
    uint32 color = pix[y * pitchinpix + x];
    uint32 mixcolor = BlurBuf[y * bbpitchinpix + x];

    BlurBuf[y * bbpitchinpix + x] = color;

    if(sizeof(T) == 2)
    {
     const uint32 mask = (rgb16_tag == MDFN_PixelFormat::IRGB16_1555) ? 0x8421 : 0x0821;

     color = ((color + mixcolor) - ((color ^ mixcolor) & mask)) >> 1;
    }
    else
    {
     // Needs 64-bit
     #ifdef HAVE_NATIVE64BIT
     color = ((((uint64)color + mixcolor) - ((color ^ mixcolor) & 0x01010101))) >> 1;
     #else
     color = ((((color & 0x00FF00FF) + (mixcolor & 0x00FF00FF)) >> 1) & 0x00FF00FF) | (((((color & 0xFF00FF00) >> 1) + ((mixcolor & 0xFF00FF00) >> 1))) & 0xFF00FF00);
     #endif
     //    color = (((color & 0xFF) + (mixcolor & 0xFF)) >> 1) | ((((color & 0xFF00) + (mixcolor & 0xFF00)) >> 1) & 0xFF00) |
     //       ((((color & 0xFF0000) + (mixcolor & 0xFF0000)) >> 1) & 0xFF0000) | ((((color >> 24) + (mixcolor >> 24)) >> 1) << 24);
    }
    pix[y * pitchinpix + x] = color;
   }
  }
 }
}

void TBlur_Run(EmulateSpecStruct *espec)
{
 MDFN_Surface* surface = espec->surface;

 if(surface->format.opp != 4 && surface->format != MDFN_PixelFormat::IRGB16_1555 && surface->format != MDFN_PixelFormat::RGB16_565)
 {
  if(FormatWarningGiven != surface->format.tag)
  {
   MDFN_Notify(MDFN_NOTICE_WARNING, _("Format 0x%016llx unsupported by temporal blur feature."), (unsigned long long)surface->format.tag);
   FormatWarningGiven = surface->format.tag;
  }
  return;
 }

 if(surface->format.opp == 4)
  TBlurLoop<uint32>(surface, espec->DisplayRect, espec->LineWidths);
 else if(surface->format.Gprec == 5)
  TBlurLoop<uint16, MDFN_PixelFormat::IRGB16_1555>(surface, espec->DisplayRect, espec->LineWidths);
 else
  TBlurLoop<uint16, MDFN_PixelFormat::RGB16_565>(surface, espec->DisplayRect, espec->LineWidths);
}

void TBlur_Kill(void)
{
 BlurBuf.reset(nullptr);
 AccumBlurBuf.reset(nullptr);
}

bool TBlur_IsOn(void)
{
 return(BlurBuf || AccumBlurBuf);
}

}
