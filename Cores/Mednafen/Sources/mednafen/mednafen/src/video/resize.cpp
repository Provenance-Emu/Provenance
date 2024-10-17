/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* resize.cpp:
**  Copyright (C) 2020 Mednafen Team
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

// TODO: ring buffer, instead of full intermediate framebuffer
// TODO: re-examine the math someday, it's kind of fudgey

#include "video-common.h"

namespace Mednafen
{

void MDFN_ResizeSurface(const MDFN_Surface* src, const MDFN_Rect* src_rect, const int32* LineWidths, MDFN_Surface* dest, const MDFN_Rect* dest_rect)
{
 struct ResizePix16
 {
  uint16 r, g, b;
 };
 const MDFN_Rect srect = *src_rect;
 const MDFN_Rect drect = *dest_rect;
 const MDFN_PixelFormat spf = src->format;
 MDFN_PixelFormat dpf = dest->format;
 std::unique_ptr<ResizePix16[]> linebuf(new ResizePix16[src->w]);
 std::unique_ptr<ResizePix16[]> framebuf(new ResizePix16[srect.h * drect.w]);
 std::unique_ptr<uint16[]> GCRLUT(new uint16[256]);
 std::unique_ptr<uint8[]> GCALUT(new uint8[4096]);
 const int totalcoeffs = 1025;
 std::unique_ptr<float[]> Filter(new float[totalcoeffs]);

 Filter[totalcoeffs / 2] = 1.0f;
 for(int i = 0; i < totalcoeffs / 2; i++)
 {
  float k = 1 + i;
#if 0
  float c_k = sin(M_PI * k / 256) / (M_PI * k / 256);
  float w_k = sin(M_PI * (k / 2) / 256) / (M_PI * (k / 2) / 256);
#else
  float c_k = sin(M_PI * k / 512) / (M_PI * k / 512);
  float w_k = c_k;
#endif
  float r = c_k * w_k;

  Filter[totalcoeffs/2 + 1 + i] = r;
  Filter[totalcoeffs/2 - 1 - i] = r;
 }
#if 0
 for(int i = 0; i < totalcoeffs; i++)
 {
  printf("%4d %4f\n", i, Filter[i]);
 }
 abort();
#endif
 for(unsigned i = 0; i < 256; i++)
 {
  float ccp = i / 255.0f;
  float cc;

  if(ccp <= 0.04045f)
   cc = ccp / 12.92f;
  else
   cc = (float)pow((ccp + 0.055f) / 1.055f, 2.4f);

  GCRLUT[i] = std::min<int>(65535, floor(0.5f + 4095 * (65536 / 4096) * cc));
 }

 for(unsigned i = 0; i < 4096; i++)
 {
  float cc = (i + 0.5f) / 4095.0f;
  float ccp;

  if(cc <= 0.0031308f)
   ccp = 12.92f * cc;
  else
   ccp = 1.055f * (float)pow(cc, 1.0f / 2.4f) - 0.055f;

  GCALUT[i] = std::min<int>(255, floor(0.5f + 255 * ccp));
 }

 for(int y = 0; y < srect.h; y++)
 {
  int32 w = (LineWidths[0] != ~0) ? LineWidths[srect.y + y] : srect.w;

  for(int x = 0; x < w; x++)
  {
   const size_t src_offset = (srect.y + y) * src->pitchinpix + srect.x + x;
   uint32 c = src->pixels16 ? src->pixels16[src_offset] : src->pixels[src_offset];
   int r, g, b;

   spf.DecodeColor(c, r, g, b);

   linebuf[x].r = GCRLUT[r];
   linebuf[x].g = GCRLUT[g];
   linebuf[x].b = GCRLUT[b];
  }
  //
  //
  //
  if(MDFN_UNLIKELY(w == 0))
  {
   for(int dx = 0; dx < drect.w; dx++)
   {
    framebuf[y * drect.w + dx] = { 0, 0, 0 };
   }
  }
  else if(w == drect.w)
  {
   for(int dx = 0; dx < drect.w; dx++)
   {
    framebuf[y * drect.w + dx] = linebuf[dx];
   }
  }
  else
  {
   const uint32 src_x_inc = (int64)w * (1U << 20) / drect.w;
   const int numphases = std::min<int>(512, (512 << 20) / src_x_inc);
   const int numcoeffs = ((totalcoeffs + numphases - 1) / numphases + 1) &~ 1;
   uint32 src_x = (1U << 19) + (src_x_inc >> 1);

   for(int dx = 0; dx < drect.w; dx++, src_x += src_x_inc)
   {
    int sxi = src_x >> 20;
    int phi = (numphases * (src_x & ((1U << 20) - 1))) >> 20;
    float r = 0, g = 0, b = 0;
    float fa = 0;

    for(int i = 0; i < numcoeffs; i++)
    {
     size_t findex = (totalcoeffs / 2) + (i - numcoeffs / 2) * numphases + numphases - 1 - phi;
     float f = (findex >= totalcoeffs) ? 0 : Filter[findex];
     int lbpi = sxi + i - numcoeffs / 2;
     auto* lbp = &linebuf[std::max<int>(0, std::min<int>(w - 1, lbpi))];

     //if(y == 200)
     // printf("w=%d, dx=%d, i=%d, findex=%d, f=%f, lbpi=%d\n", w, dx, i, (int)findex, 10000*f, lbpi);

     fa += f;
     r += lbp->r * f;
     g += lbp->g * f;
     b += lbp->b * f;
    }

    //if(!y)
    // printf("%f\n", fa * (256 / 0.0146));

    float adj = 1.0f / fa;
    r *= adj;
    g *= adj;
    b *= adj;
    //
    auto* fbp = &framebuf[y * drect.w + dx];
    fbp->r = std::max<int>(0, std::min<int>(0xFFFF, floor(r)));
    fbp->g = std::max<int>(0, std::min<int>(0xFFFF, floor(g)));
    fbp->b = std::max<int>(0, std::min<int>(0xFFFF, floor(b)));
   }
  }
 }
 //
 //
 //
 if(MDFN_UNLIKELY(srect.h == 0))
 {
  for(int dy = 0; dy < drect.h; dy++)
  {
   for(int dx = 0; dx < drect.w; dx++)
   {
    dest->pixels[(drect.y + dy) * dest->pitchinpix + drect.x + dx] = dpf.MakeColor(0, 0, 0);
   }
  }
 }
 else if(srect.h == drect.h)
 {
  for(int dy = 0; dy < drect.h; dy++)
  {
   for(int dx = 0; dx < drect.w; dx++)
   {
    ResizePix16 p = framebuf[dy * drect.w + dx];

    dest->pixels[(drect.y + dy) * dest->pitchinpix + drect.x + dx] = dpf.MakeColor(GCALUT[p.r >> 4], GCALUT[p.g >> 4], GCALUT[p.b >> 4]);
   }
  }
 }
 else
 {
  const uint32 src_y_inc = (int64)srect.h * (1U << 20) / drect.h;
  const int numphases = std::min<int>(512, (512 << 20) / src_y_inc);
  const int numcoeffs = ((totalcoeffs + numphases - 1) / numphases + 1) &~ 1;

  for(int dx = 0; dx < drect.w; dx++)
  {
   uint32 src_y = (1U << 19) + (src_y_inc >> 1);

   for(int dy = 0; dy < drect.h; dy++, src_y += src_y_inc)
   {
    int syi = src_y >> 20;
    int phi = (numphases * (src_y & ((1U << 20) - 1))) >> 20;
    float r = 0, g = 0, b = 0;
    float fa = 0;

    for(int i = 0; i < numcoeffs; i++)
    {
     size_t findex = (totalcoeffs / 2) + (i - numcoeffs / 2) * numphases + numphases - 1 - phi;
     float f = (findex >= totalcoeffs) ? 0 : Filter[findex];
     auto* fbp = &framebuf[dx + drect.w * std::max<int>(0, std::min<int>(srect.h - 1, syi + i - numcoeffs / 2))];

     fa += f;
     r += fbp->r * f;
     g += fbp->g * f;
     b += fbp->b * f;
    }

    //if(!y)
    // printf("%f\n", fa * (256 / 0.0146));

    float adj = 1.0f / fa;
    r *= adj;
    g *= adj;
    b *= adj;
    //
    ResizePix16 p;

    p.r = std::max<int>(0, std::min<int>(0xFFFF, floor(r)));
    p.g = std::max<int>(0, std::min<int>(0xFFFF, floor(g)));
    p.b = std::max<int>(0, std::min<int>(0xFFFF, floor(b)));

    dest->pixels[(drect.y + dy) * dest->pitchinpix + drect.x + dx] = dpf.MakeColor(GCALUT[p.r >> 4], GCALUT[p.g >> 4], GCALUT[p.b >> 4]);
   }
  }
 }
}

}
