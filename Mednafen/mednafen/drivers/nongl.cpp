/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "main.h"
#include "video.h"
#include "nongl.h"
#include "nnx.h"

#include <algorithm>
#include <math.h>
#include <stdlib.h>

//
// Source rectangle sanity checking(more strict than dest rectangle sanity checking).	*/					
//
// true if it's ok, false if it's "bad" and we shouldn't blit.
static INLINE bool CheckSourceRect(const MDFN_Surface *src_surface, const MDFN_Rect *src_rect)
{
	if((src_rect->w <= 0) || (src_rect->h <= 0))
	 return(false);

	if((src_rect->x < 0) || (src_rect->y < 0))
	 return(false);

	if(((int64)src_rect->x + src_rect->w) > src_surface->w)
	 return(false);

	if(((int64)src_rect->y + src_rect->h) > src_surface->h)
	 return(false);

	return(true);
}

//
// Dest rectangle sanity checking.
//
static INLINE bool CheckDestRect(const MDFN_Surface *dest_surface, const MDFN_Rect *dest_rect)
{
	if((dest_rect->w <= 0) || (dest_rect->h <= 0))
	 return(false);

	if(dest_rect->x >= dest_surface->w)
	 return(false);

	if(dest_rect->y >= dest_surface->h)
	 return(false);

	if(((int64)dest_rect->x + dest_rect->w) <= 0)
	 return(false);

	if(((int64)dest_rect->y + dest_rect->h) <= 0)
	 return(false);

	return(true);
}

//
// true if blitting needs to be done with some sort of clipping, false if not.
//
static INLINE bool CheckDRNeedsClipping(const MDFN_Surface *dest_surface, const MDFN_Rect *dest_rect)
{
 if(dest_rect->x < 0 || dest_rect->y < 0)
  return(true);

 if(((int64)dest_rect->x + dest_rect->w) > dest_surface->w)
  return(true);

 if(((int64)dest_rect->y + dest_rect->h) > dest_surface->h)
  return(true);

 return(false);
}

#define SFTBLT_SETUP(T)															\
	/* dr_* should only be used in the actual blitting functions for ratio calculations. */						\
	const int32 sr_w = src_rect->w;													\
	const int32 sr_h = src_rect->h;													\
	const int32 dr_w = dest_rect->w;												\
	const int32 dr_h = dest_rect->h;												\
	const int32 iter_w = std::min(std::max(0, dest_surface->w - std::max(0, dest_rect->x)), std::max(0, dr_w + std::min(0, dest_rect->x)));	\
	const int32 iter_h = std::min(std::max(0, dest_surface->h - std::max(0, dest_rect->y)), std::max(0, dr_h + std::min(0, dest_rect->y)));	\
	const uint32 src_pitchinpix = src_surface->pitchinpix;										\
	const uint32 dest_pitchinpix = dest_surface->pitchinpix;									\
	const int32 dest_pixels_fudge_x = -std::min(0, dest_rect->x);									\
	const int32 dest_pixels_fudge_y = -std::min(0, dest_rect->y);									\
	const T* src_pixels = src_surface->pixels + src_rect->x + (src_rect->y * src_pitchinpix);					\
	T* dest_pixels = dest_surface->pixels + std::max(0, dest_rect->x) + (std::max(0, dest_rect->y) * dest_pitchinpix);


//	const int32 src_pixels_fudge_x = (int64)(-std::min(0, dest_rect->x)) * sr_w / dr_w;						
//	const int32 src_pixels_fudge_y = (int64)(-std::min(0, dest_rect->y)) * sr_h / dr_h;						
// 	const T* src_pixels = src_surface->pixels + src_rect->x + src_pixels_fudge_x + ((src_rect->y + src_pixels_fudge_y) * src_pitchinpix);	

// Write pixel source-alpha-eval
template<typename T, unsigned int alpha_shift>
static INLINE void WPSAE(T &back_pix_ref, const T fore_pix)
{
 if(sizeof(T) == 4 && alpha_shift < 31)
 {
  const T back_pix = back_pix_ref;
  const uint32 alpha = (((fore_pix >> alpha_shift) & 0xFF) * 129) >> 7; //65921) >> 16;
  const uint32 alpha_negoo = 256 - alpha;
  T new_pix;

  new_pix = 0;
  new_pix |= ((((back_pix & 0xFF00FF) * alpha_negoo) + ((fore_pix & 0xFF00FF) * alpha)) >> 8) & 0x00FF00FF;
  new_pix |= (((((back_pix >> 8) & 0xFF00FF) * alpha_negoo) + (((fore_pix >> 8) & 0xFF00FF) * alpha))) & 0xFF00FF00;
  back_pix_ref = new_pix;
 }
 else
  back_pix_ref = fore_pix;
}

template<typename T, int alpha_shift>
static void BlitStraight(const MDFN_Surface *src_surface, const MDFN_Rect *src_rect, MDFN_Surface *dest_surface, const MDFN_Rect *dest_rect)
{
 SFTBLT_SETUP(T);

 (void)sr_w;
 (void)sr_h;

 //puts("Straight");

 src_pixels += dest_pixels_fudge_x + (dest_pixels_fudge_y * src_pitchinpix);

 for(int32 y = 0; y < iter_h; y++)
 {
  if(alpha_shift >= 0)
  {
   for(int32 x = 0; x < iter_w; x++)
   {
    WPSAE<T, alpha_shift>(dest_pixels[x], src_pixels[x]);
   }
  }
  else
   memcpy(dest_pixels, src_pixels, iter_w * sizeof(T));

  src_pixels += src_pitchinpix;
  dest_pixels += dest_pitchinpix;
 }
}

template<typename T, int alpha_shift>
static void BlitIScale(const MDFN_Surface *src_surface, const MDFN_Rect &sr, MDFN_Surface *dest_surface, const MDFN_Rect &dr, int xscale, int yscale)
{
 //puts("IScale");
 const uint32 src_pitchinpix = src_surface->pitchinpix;
 int32 dpitch_diff;

 T *src_row, *dest_row;

 src_row = src_surface->pixels + src_surface->pitchinpix * sr.y + sr.x;
 dest_row = dest_surface->pixels + dest_surface->pitchinpix * dr.y + dr.x;

 dpitch_diff = dest_surface->pitchinpix - (sr.w * xscale);

 //printf("%f %f, %d %d\n", dw_to_sw_ratio, dh_to_sh_ratio, xscale, yscale);

 for(int y = sr.h; y; y--)
 {
  for(int ys = yscale; ys; ys--)
  {
   uint32 *src_pixels = src_row;

   for(int x = sr.w; x; x--)
   {
    uint32 tmp_pixel = *src_pixels;

    for(int xs = xscale; xs; xs--)
     WPSAE<T, alpha_shift>(*dest_row++, tmp_pixel);

    src_pixels++;
   }
   dest_row += dpitch_diff;
  }
  src_row += src_pitchinpix;
 }
}

template<typename T, int alpha_shift, bool scanlines_on, bool rotation_on>
static void BlitSScale(const MDFN_Surface *src_surface, const MDFN_Rect *src_rect, MDFN_Surface *dest_surface, const MDFN_Rect *dest_rect, const MDFN_Rect *original_src_rect, int scanlines = 0, unsigned rotation = 0, int InterlaceField = -1)
{
 SFTBLT_SETUP(T);

 //puts("SScale");
// printf("%d %d\n", iter_w, iter_h);

 static const unsigned fract_bits = 18;	// 2**(32 - 18) == 16384

 uint32 src_x, src_y;
 uint32 src_x_inc, src_y_inc;

 // Extra vars for scanlines
 const int32 o_sr_h = original_src_rect->h;
 uint32 sl_mult;
 uint32 sl;
 uint32 sl_inc;
 uint32 sl_init;	// For scanlines+rotation!!

 // Extra vars for rotation.
 uint32 src_x_init;
 uint32 src_y_init;

 if(rotation_on)
 {
  if(rotation == MDFN_ROTATE90)
  {
   src_x_inc = ((sr_h << fract_bits) + dr_w - 1) / dr_w;
   src_y_inc = -((sr_w << fract_bits) + dr_h - 1) / dr_h;
  }
  else //if(rotated == MDFN_ROTATE270)
  {
   src_x_inc = -((sr_h << fract_bits) + dr_w - 1) / dr_w;
   src_y_inc = ((sr_w << fract_bits) + dr_h - 1) / dr_h;
  }

  //
  //
  //
  if((((int64)abs((int32)src_x_inc) * (iter_w + dest_pixels_fudge_x - 1)) >> fract_bits) >= sr_h)
  {
   printf("Rot %u Prec-round BUG X\n", rotation);
   if((int32)src_x_inc < 0)
    src_x_inc++;
   else
    src_x_inc--;
  }

  if((((int64)abs((int32)src_y_inc) * (iter_h + dest_pixels_fudge_y - 1)) >> fract_bits) >= sr_w)
  {
   printf("Rot %u Prec-round BUG Y\n", rotation);
   if((int32)src_y_inc < 0)
    src_y_inc++;
   else
    src_y_inc--;
  }
  //
  //
  //

  if(rotation == MDFN_ROTATE90)
  {
   src_x_init = dest_pixels_fudge_x * src_x_inc;
   src_y_init = (iter_h + dest_pixels_fudge_y - 1) * -src_y_inc;
  }
  else //if(rotated == MDFN_ROTATE270)
  {
   src_x_init = (iter_w + dest_pixels_fudge_x - 1) * -src_x_inc;
   src_y_init = dest_pixels_fudge_y * src_y_inc;
   //printf("%d %08x\n", dest_pixels_fudge_x, dest_pixels_fudge_y * src_y_inc);
  }
 }
 else
 {
  src_x_inc = ((sr_w << fract_bits) + dr_w - 1) / dr_w;
  src_y_inc = ((sr_h << fract_bits) + dr_h - 1) / dr_h;

  if((((int64)src_x_inc * (iter_w + dest_pixels_fudge_x - 1)) >> fract_bits) >= sr_w)
  {
   puts("Prec-round BUG X");
   src_x_inc--;
  }

  if((((int64)src_y_inc * (iter_h + dest_pixels_fudge_y - 1)) >> fract_bits) >= sr_h)
  {
   puts("Prec-round BUG Y");
   src_y_inc--;
  }

  src_pixels += ((int64)dest_pixels_fudge_x * src_x_inc) >> fract_bits;
  src_pixels += (((int64)dest_pixels_fudge_y * src_y_inc) >> fract_bits) * src_pitchinpix;
 }

#if 0
 printf("%lld, %lld\n", ((long long)src_y + src_y_inc * (dr.h - 1)) >> fract_bits, ((long long)src_y + src_y_inc * (dr.h - (dr.h / sr.h) - 1)) >> fract_bits);
#endif

 if(scanlines_on)
 {
  unsigned o_sr_h_ps = 0;
  int sl_init_offs = 0;

  sl_mult = 256 - 256 * abs(scanlines) / 100;

  if(scanlines < 0 && InterlaceField >= 0)
  {
   o_sr_h_ps = 1;
   sl_init_offs = InterlaceField;
  }

  if(rotation_on)
  {
   if(rotation == MDFN_ROTATE90)
   {
    sl_inc = (((o_sr_h >> o_sr_h_ps) << fract_bits) + dr_w - 1) / dr_w * 2;
    sl_init = (sl_init_offs * (dr_w / o_sr_h) + dest_pixels_fudge_x) * sl_inc;
   }
   else
   {
    sl_inc = -(((o_sr_h >> o_sr_h_ps) << fract_bits) + dr_w - 1) / dr_w * 2;
    sl_init = (sl_init_offs * (dr_w / o_sr_h) + iter_w + dest_pixels_fudge_x - 1) * -sl_inc;
   }
  }
  else
  {
   sl_inc = (((o_sr_h >> o_sr_h_ps) << fract_bits) + dr_h - 1) / dr_h * 2;
   sl_init = (sl_init_offs * (dr_h / o_sr_h)) * sl_inc;
  }

  if(!rotation_on)
   sl = sl_init;
  //printf("%08x, %d\n", sl_init, sl_init >> fract_bits);
 }

 if(rotation_on)
  src_y = src_y_init;
 else
  src_y = 0;

 for(int y = 0; y < iter_h; y++)
 {
  T *dest_row_ptr = dest_pixels + (y * dest_pitchinpix);
  const T *src_row_ptr;
  const T *src_col_ptr;

  if(rotation_on)
  {
   src_x = src_x_init;
   src_col_ptr = src_pixels + (src_y >> fract_bits);
   if(scanlines_on)
    sl = sl_init;
  }
  else
  {
   src_x = 0;
   src_row_ptr = src_pixels + (src_y >> fract_bits) * src_pitchinpix;
  }

  if(scanlines_on && (rotation_on || (sl & (1U << fract_bits))))
  {
   for(int x = 0; x < iter_w; x++)
   {
    T pixel = rotation_on ? src_col_ptr[(src_x >> fract_bits) * src_pitchinpix] : src_row_ptr[(src_x >> fract_bits)];

    if(!rotation_on || (sl & (1U << fract_bits)))
     pixel = ((((pixel & 0xFF00FF) * sl_mult) >> 8) & 0x00FF00FF) | ((((pixel >> 8) & 0xFF00FF) * sl_mult) & 0xFF00FF00);

    WPSAE<T, alpha_shift>(dest_row_ptr[x], pixel);
    src_x += src_x_inc;
    if(rotation_on)
     sl += sl_inc;
   }
  }
  else
  {
   for(int x = 0; x < iter_w; x++)
   {
    T pixel = rotation_on ? src_col_ptr[(src_x >> fract_bits) * src_pitchinpix] : src_row_ptr[(src_x >> fract_bits)];

    WPSAE<T, alpha_shift>(dest_row_ptr[x], pixel);
    src_x += src_x_inc;
   }
  }

  src_y += src_y_inc;
  if(scanlines_on && !rotation_on)
   sl += sl_inc;
 }
}

void MDFN_StretchBlitSurface(MDFN_Surface *src_surface, const MDFN_Rect *src_rect, MDFN_Surface *dest_surface, const MDFN_Rect *dest_rect, bool source_alpha, int scanlines, const MDFN_Rect *original_src_rect, int rotated, int InterlaceField)
{
 if(!CheckSourceRect(src_surface, src_rect))
  return;

 if(!CheckDestRect(dest_surface, dest_rect))
  return;

 const bool NeedClipping = CheckDRNeedsClipping(dest_surface, dest_rect);


 if(original_src_rect == NULL)
  original_src_rect = src_rect;

 MDFN_Rect sr, dr, o_sr;

 sr = *src_rect;
 o_sr = *original_src_rect;
 dr = *dest_rect;

 //printf("%d:%d, %d:%d, %d:%d\n", sr.x, sr.w, sr.y, sr.h, src_surface->w, src_surface->h);

 if(rotated != MDFN_ROTATE0)
 {
  if(scanlines)
   BlitSScale<uint32, 31, true, true>(src_surface, src_rect, dest_surface, dest_rect, original_src_rect, scanlines, rotated, InterlaceField);
  else
   BlitSScale<uint32, 31, true, true>(src_surface, src_rect, dest_surface, dest_rect, original_src_rect,	 0, rotated);

  return;
 }

 if(sr.w == dr.w && sr.h == dr.h && (!scanlines || (sr.w == o_sr.w && sr.h == o_sr.h)))
 {
  switch(source_alpha ? (int)src_surface->format.Ashift : -1)
  {
   case -1:  BlitStraight<uint32, 31>(src_surface, &sr, dest_surface, &dr); break;
   case  0:  BlitStraight<uint32,  0>(src_surface, &sr, dest_surface, &dr); break;
   case  8:  BlitStraight<uint32,  8>(src_surface, &sr, dest_surface, &dr); break;
   case  16: BlitStraight<uint32, 16>(src_surface, &sr, dest_surface, &dr); break;
   case  24: BlitStraight<uint32, 24>(src_surface, &sr, dest_surface, &dr); break;
  }
  //BlitStraight<uint32, 31>(src_surface, &sr, dest_surface, &dr);
  //SDL_BlitSurface(src_surface, &sr, dest_surface, &dr);
  return;
 }

 //printf("%d\n", dr.x);

 double dw_to_sw_ratio = (double)dr.w / sr.w;
 double dh_to_sh_ratio = (double)dr.h / sr.h;

 if(!scanlines && !NeedClipping && floor(dw_to_sw_ratio) == dw_to_sw_ratio && floor(dh_to_sh_ratio) == dh_to_sh_ratio)
 {
  switch(source_alpha ? (int)src_surface->format.Ashift : -1)
  {
   case -1:  if((dw_to_sw_ratio == dh_to_sh_ratio) && dw_to_sw_ratio <= 5)
	      nnx(dw_to_sw_ratio, src_surface, &sr, dest_surface, &dr);
	     else	
	      BlitIScale<uint32, 31>(src_surface, sr, dest_surface, dr, dw_to_sw_ratio, dh_to_sh_ratio);
	     break;

   case  0:  BlitIScale<uint32,  0>(src_surface, sr, dest_surface, dr, dw_to_sw_ratio, dh_to_sh_ratio);	break;
   case  8:  BlitIScale<uint32,  8>(src_surface, sr, dest_surface, dr, dw_to_sw_ratio, dh_to_sh_ratio);	break;
   case  16: BlitIScale<uint32, 16>(src_surface, sr, dest_surface, dr, dw_to_sw_ratio, dh_to_sh_ratio); break;
   case  24: BlitIScale<uint32, 24>(src_surface, sr, dest_surface, dr, dw_to_sw_ratio, dh_to_sh_ratio); break;
  }
 }
 else
 {
  if(scanlines)
  {
   BlitSScale<uint32, 31, true, false>(src_surface, src_rect, dest_surface, dest_rect, original_src_rect, scanlines, 0, InterlaceField);
  }
  else switch(source_alpha ? (int)src_surface->format.Ashift : -1)
  {
   case -1:  BlitSScale<uint32, 31, false, false>(src_surface, src_rect, dest_surface, dest_rect, original_src_rect); break;
   case  0:  BlitSScale<uint32,  0, false, false>(src_surface, src_rect, dest_surface, dest_rect, original_src_rect); break;
   case  8:  BlitSScale<uint32,  8, false, false>(src_surface, src_rect, dest_surface, dest_rect, original_src_rect); break;
   case  16: BlitSScale<uint32, 16, false, false>(src_surface, src_rect, dest_surface, dest_rect, original_src_rect); break;
   case  24: BlitSScale<uint32, 24, false, false>(src_surface, src_rect, dest_surface, dest_rect, original_src_rect); break;
  }
 }
}
