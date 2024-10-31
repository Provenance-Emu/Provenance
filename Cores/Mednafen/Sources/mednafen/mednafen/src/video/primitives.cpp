/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* primitives.cpp:
**  Copyright (C) 2013-2020 Mednafen Team
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

#include "video-common.h"

namespace Mednafen
{

template<typename T, bool fill>
static void SuperDrawRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 border_color, uint32 fill_color, RectStyle style)
{
 T* pixels = surface->pix<T>() + (y * surface->pitchinpix) + x;
 const uint32 pitchinpix = surface->pitchinpix;

 if(w < 1 || h < 1)
  return;

 // Replace these width and height checks with assert()s in the future.
 if(((uint64)x + w) > (uint32)surface->w)
 {
  fprintf(stderr, "Rect xw bug!\n");
  return;
 }

 if(((uint64)y + h) > (uint32)surface->h)
 {
  fprintf(stderr, "Rect yh bug!\n");
  return;
 }

 if(style == RectStyle::Rounded && w >= 2 && h >= 2)
 {
  for(uint32 iy = 0; iy < h; iy++)
  {
   uint32 xo = 0;
   bool f = fill;
   uint32 fc = fill_color;

   if(iy == 0 || iy == (h - 1))
   {
    xo = 2;
    f = true;
    fc = border_color;
   }
   else if(iy == 1 || iy == (h - 2))
    xo = 1;

   pixels[xo] = border_color;
   pixels[w - 1 - xo] = border_color;
   if(f)
   {
    for(uint32 ix = 1 + xo; (ix + 1 + xo) < w; ix++)
     pixels[ix] = fc;
   }
   pixels += pitchinpix;
  }
 }
 else
 {
  for(uint32 ix = 0; ix < w; ix++)
  {
   pixels[ix] = border_color;
   pixels[ix + (h - 1) * pitchinpix] = border_color;
  }
  pixels += pitchinpix;

  for(uint32 iy = 1; iy < (h - 1); iy++)
  {
   pixels[0] = border_color;
   pixels[w - 1] = border_color;

   if(fill)
    for(uint32 ix = 1; ix < (w - 1); ix++)
     pixels[ix] = fill_color;

   pixels += pitchinpix;
  }
 }
}


void MDFN_DrawRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 border_color, RectStyle style)
{
 switch(surface->format.opp)
 {
  case 1:
	SuperDrawRect<uint8,  false>(surface, x, y, w, h, border_color, 0, style);
	break;

  case 2:
	SuperDrawRect<uint16, false>(surface, x, y, w, h, border_color, 0, style);
	break;

  case 4:
	SuperDrawRect<uint32, false>(surface, x, y, w, h, border_color, 0, style);
	break;
 }
}

void MDFN_DrawFillRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 border_color, uint32 fill_color, RectStyle style)
{
 switch(surface->format.opp)
 {
  case 1:
	SuperDrawRect<uint8,  true>(surface, x, y, w, h, border_color, fill_color, style);
	break;

  case 2:
	SuperDrawRect<uint16, true>(surface, x, y, w, h, border_color, fill_color, style);
	break;

  case 4:
	SuperDrawRect<uint32, true>(surface, x, y, w, h, border_color, fill_color, style);
	break;
 }
}

void MDFN_DrawFillRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 fill_color, RectStyle style)
{
 switch(surface->format.opp)
 {
  case 1:
	SuperDrawRect<uint8,  true>(surface, x, y, w, h, fill_color, fill_color, style);
	break;

  case 2:
	SuperDrawRect<uint16, true>(surface, x, y, w, h, fill_color, fill_color, style);
	break;

  case 4:
	SuperDrawRect<uint32, true>(surface, x, y, w, h, fill_color, fill_color, style);
	break;
 }
}
#if 0
void MDFN_DrawLine_P(MDFN_Surface *surface, int x0, int y0, int x1, int y1, uint32 color)
{
 const bool contig = false;
 const int dx = x1 - x0;
 const int dy = y1 - y0;
 const unsigned int abs_dx = abs(dx);
 const unsigned int abs_dy = abs(dy);
 const uint32 pitchinpix = surface->pitchinpix;
 uint32 *pixels = surface->pixels;
 const unsigned int s_w = surface->w;
 const unsigned int s_h = surface->h;

 if(abs_dy > abs_dx)
 {
  unsigned int accum = abs_dy;
  unsigned int accum_step = abs_dx << 1;
  unsigned int accum_comp = abs_dy << 1;
  const int xinc = (dx >> 31) | 1;
  int x = x0;

  if(dy > 0)
  {
   for(int y = y0; y <= y1; y++)
   {
    if((unsigned)x < s_w && (unsigned)y < s_h)
     pixels[x + (y * pitchinpix)] = color;

    accum += accum_step;
    if(accum >= accum_comp)
    {
     x += xinc;
     accum -= accum_comp;

     if(contig)
     {
      if((unsigned)x < s_w && (unsigned)y < s_h)
       pixels[x + (y * pitchinpix)] = color;
     }
    }
   }
  }
  else
  {
   for(int y = y0; y >= y1; y--)
   {
    if(accum > accum_comp)
    {
     if(contig)
     {
      if((unsigned)x < s_w && (unsigned)y < s_h)
       pixels[x + (y * pitchinpix)] = color;
     }

     x += xinc;
     accum -= accum_comp;
    }

    if((unsigned)x < s_w && (unsigned)y < s_h)
     pixels[x + (y * pitchinpix)] = color;

    accum += accum_step;
   }
  }
 }
 else
 {
  unsigned int accum = abs_dx;
  unsigned int accum_step = abs_dy << 1;
  unsigned int accum_comp = abs_dx << 1;
  const int yinc = (dy >> 31) | 1;
  int y = y0;

  if(dx > 0)
  {
   for(int x = x0; x <= x1; x++)
   {
    if((unsigned)x < s_w && (unsigned)y < s_h)
     pixels[x + (y * pitchinpix)] = color;

    accum += accum_step;
    if(accum >= accum_comp)
    {
     y += yinc;
     accum -= accum_comp;

     if(contig)
     {
      if((unsigned)x < s_w && (unsigned)y < s_h)
       pixels[x + (y * pitchinpix)] = color;
     }
    }
   }
  }
  else
  {
   for(int x = x0; x >= x1; x--)
   {
    if(accum > accum_comp)
    {
     if(contig)
     {
      if((unsigned)x < s_w && (unsigned)y < s_h)
       pixels[x + (y * pitchinpix)] = color;
     }

     y += yinc;
     accum -= accum_comp;
    }

    if((unsigned)x < s_w && (unsigned)y < s_h)
     pixels[x + (y * pitchinpix)] = color;

    accum += accum_step;
   }
  }
 }
}
#endif

// Will fail GLORIOUSLY if trying to draw a line where the distance between x coordinates, or between y coordinates, is >= 2**31
// but you'd have to be 2**32 types of crazy to want to draw a line that long anyway.
template<typename T>
static void SuperDrawLine(MDFN_Surface *surface, int x0, int y0, int x1, int y1, uint32 color)
{
 const int dx = x1 - x0;
 const int dy = y1 - y0;
 const unsigned int abs_dx = abs(dx);
 const unsigned int abs_dy = abs(dy);
 const uint32 pitchinpix = surface->pitchinpix;
 T *pixels = surface->pix<T>();
// const unsigned int s_w = surface->w;
// const unsigned int s_h = surface->h;

 int64 x = ((int64)x0 << 32) + ((int64)1 << 31);
 int64 y = ((int64)y0 << 32) + ((int64)1 << 31);
 int64 x_inc;
 int64 y_inc;
 uint32 k;

 if((abs_dx | abs_dy) == 0)
 {
  k = 0;
  x_inc = 0;
  y_inc = 0;
 }
 else
 {
  if(abs_dx > abs_dy)
  {
   k = abs_dx;
   x_inc = ((int64)dx >> 63) | ((int64)1 << 32);
   //y_inc = (((int64)dy << 32) - ((dy < 0) ? (k - 1) : 0)) / k;
   y_inc = (((int64)dy << 32) + ((dy < 0) ? 0 : (k - 1))) / k;
  }
  else
  {
   k = abs_dy;
   //x_inc = (((int64)dx << 32) - ((dx < 0) ? (k - 1) : 0)) / k;
   x_inc = (((int64)dx << 32) + ((dx < 0) ? 0 : (k - 1))) / k;
   y_inc = (int64)((dy >> 31) | 1) << 32;
  }
 }

 for(uint32 i = 0; i <= k; i++)
 {
  int xc = x >> 32;
  int yc = y >> 32;

  pixels[xc + (yc * pitchinpix)] = color;

  x += x_inc;
  y += y_inc;
 }
}

void MDFN_DrawLine(MDFN_Surface *surface, int x0, int y0, int x1, int y1, uint32 color)
{
 switch(surface->format.opp)
 {
  case 1:
	SuperDrawLine<uint8>(surface, x0, y0, x1, y1, color);
	break;

  case 2:
	SuperDrawLine<uint16>(surface, x0, y0, x1, y1, color);
	break;

  case 4:
	SuperDrawLine<uint32>(surface, x0, y0, x1, y1, color);
	break;
 }
}

template<typename T>
static void MDFN_SuperDrawFillRect(MDFN_Surface* surface, const MDFN_Rect& crect, int32 x, int32 y, uint32 w, uint32 h, uint32 color)
{
 int32 bx0 = std::min<int32>(surface->w, std::max<int32>(0, crect.x));
 int32 bx1 = std::min<int64>(surface->w, std::max<int64>(0, (int64)crect.x + std::max<int32>(0, crect.w)));
 int32 by0 = std::min<int32>(surface->h, std::max<int32>(0, crect.y));
 int32 by1 = std::min<int64>(surface->h, std::max<int64>(0, (int64)crect.y + std::max<int32>(0, crect.h)));
 int32 xstart = std::min<int32>(bx1, std::max<int32>(bx0, x));
 int32 xbound = std::min<int64>(bx1, std::max<int64>(bx0, (int64)x + w));
 int32 ystart = std::min<int32>(by1, std::max<int32>(by0, y));
 int32 ybound = std::min<int64>(by1, std::max<int64>(by0, (int64)y + h));

 if(xstart >= xbound || ystart >= ybound)
  return;
 //
 //
 //
 T* p = surface->pix<T>() + ystart * surface->pitchinpix + xstart;
 const uint32 pitchinpix = surface->pitchinpix;
 const int32 iw = xbound - xstart;

 for(int32 iy = ybound - ystart; iy; iy--)
 {
  for(int32 ix = 0; ix < iw; ix++)
   p[ix] = color;

  p += pitchinpix;
 }
}

void MDFN_DrawFillRect(MDFN_Surface* surface, const MDFN_Rect& crect, int32 x, int32 y, uint32 w, uint32 h, uint32 color)
{
 switch(surface->format.opp)
 {
  case 1:
	MDFN_SuperDrawFillRect<uint8>(surface, crect, x, y, w, h, color);
	break;

  case 2:
	MDFN_SuperDrawFillRect<uint16>(surface, crect, x, y, w, h, color);
	break;

  case 4:
	MDFN_SuperDrawFillRect<uint32>(surface, crect, x, y, w, h, color);
	break;
 }
}

}
