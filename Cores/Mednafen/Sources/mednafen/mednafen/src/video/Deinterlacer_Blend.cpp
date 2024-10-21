/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Deinterlacer_Blend.cpp:
**  Copyright (C) 2018-2019 Mednafen Team
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
#include "Deinterlacer.h"
#include "Deinterlacer_Blend.h"

namespace Mednafen
{

Deinterlacer_Blend::Deinterlacer_Blend(bool rg) : prev_height(0), prev_valid(false), WantRG(rg)
{
 if(WantRG)
 {
  for(unsigned i = 0; i < 256; i++)
  {
   double ccp = i / 255.0;
   double cc;

   if(ccp <= 0.04045)
    cc = ccp / 12.92;
   else
    cc = pow((ccp + 0.055) / 1.055, 2.4);

   GCRLUT[i] = std::min<int>(65535, floor(0.5 + 4095 * (65536 / 4096) * cc));
  }

  for(unsigned i = 0; i < 4096; i++)
  {
   double cc = (i + 0.5) / 4095.0;
   double ccp;

   if(cc <= 0.0031308)
    ccp = 12.92 * cc;
   else
    ccp = 1.055 * pow(cc, 1.0 / 2.4) - 0.055;

   GCALUT[i] = std::min<int>(255, floor(0.5 + 255 * ccp));
  }
#if 0
  for(unsigned i = 0; i < 256; i++)
  {
   const unsigned ri = GCALUT[(GCRLUT[i] + GCRLUT[i]) >> (16 - 12 + 1)];

   if(i != ri)
   // printf("* ");
   //else
   // printf("  ");
    printf("%3d: %3d --- %d(%d)\n", i, ri, GCRLUT[i], GCRLUT[i] >> (16 - 12));
  }
  abort();
#endif
 }
}


Deinterlacer_Blend::~Deinterlacer_Blend()
{


}

template<typename T, bool rg, unsigned cc0s, unsigned cc1s, unsigned cc2s>
INLINE T Deinterlacer_Blend::Blend(T a, T b)
{
 if(sizeof(T) == 4)
 {
  if(rg)
  {
   uint32 ret;

   ret  = GCALUT[(GCRLUT[(uint8)(a >> cc0s)] + GCRLUT[(uint8)(b >> cc0s)]) >> (16 - 12 + 1)] << cc0s;
   ret |= GCALUT[(GCRLUT[(uint8)(a >> cc1s)] + GCRLUT[(uint8)(b >> cc1s)]) >> (16 - 12 + 1)] << cc1s;
   ret |= GCALUT[(GCRLUT[(uint8)(a >> cc2s)] + GCRLUT[(uint8)(b >> cc2s)]) >> (16 - 12 + 1)] << cc2s;

   return ret;
  }
  else
   return ((((uint64)a + b) - ((a ^ b) & 0x01010101))) >> 1;
 }
 else if(sizeof(T) == 2)
 {
  return ((a + b) - ((a ^ b) & ((1 << cc0s) | (1 << cc1s) | (1 << cc2s)))) >> 1;
 }
 else
 {
  return 0;
 }
}

template<typename T, bool rg, unsigned cc0s, unsigned cc1s, unsigned cc2s>
NO_INLINE void Deinterlacer_Blend::InternalProcess(MDFN_Surface* surface, MDFN_Rect& dr, int32* LineWidths, const bool field)
{
 const bool lw_in_valid = (LineWidths[0] != ~0);
 const T black = surface->MakeColor(0, 0, 0);
 int32* lw = LineWidths + dr.y;
 T* pix = surface->pix<T>() + dr.y * surface->pitchinpix + dr.x;
 const int32 fh = dr.h / 2;

 for(int32 i = 0; i < fh; i++)
 {
  T* curlp = pix + (i * 2 + field) * surface->pitchinpix;
  T* prevlp = prev_field->pix<T>() + i * prev_field->pitchinpix;
  int32 w = lw_in_valid ? lw[i * 2 + field] : dr.w;
  bool blend_ok = (sizeof(T) >= 2 && prev_valid && w == prev_field_w[i]);
  //
  memcpy(&lb[0], curlp, w * sizeof(T));
  //
  if(!field && i && w != prev_w_delay)
   blend_ok = false;

  if(field && (i + 1) != fh && w != prev_field_w[i + 1])
   blend_ok = false;

  if(blend_ok)
  {
   //
   if(field && i == 0)
   {
    for(int32 x = 0; MDFN_LIKELY(x < w); x++)
     pix[x] = Blend<T, rg, cc0s, cc1s, cc2s>(prevlp[x], black);
   }
   //
   if(field || i > 0)
   {
    T* s = field ? prevlp : (T*)&prev_field_delay[0];

    for(int32 x = 0; MDFN_LIKELY(x < w); x++)
     curlp[x] = Blend<T, rg, cc0s, cc1s, cc2s>(curlp[x], s[x]);
   }
   else
   {
    for(int32 x = 0; MDFN_LIKELY(x < w); x++)
     curlp[x] = Blend<T, rg, cc0s, cc1s, cc2s>(curlp[x], black);
   }

   if(!field || (i + 1) < fh)
   {
    T* t = curlp + surface->pitchinpix;
    T* d = (T*)&lb[0];
    T* s = prev_field->pix<T>() + (i + field) * prev_field->pitchinpix;

    assert(w == prev_field_w[i + field]);

    for(int32 x = 0; MDFN_LIKELY(x < w); x++)
     t[x] = Blend<T, rg, cc0s, cc1s, cc2s>(d[x], s[x]);
   }
  }
  else
  {
   if(!field || (i + 1) < fh)
   {
    memcpy(curlp + 1 * surface->pitchinpix, (T*)&lb[0], w * sizeof(T));
   }

   if(field && i == 0)
    MDFN_FastArraySet(pix, black, w);
  }

  if(!field)
  {
   memcpy(&prev_field_delay[0], prevlp, w * sizeof(T));
   prev_w_delay = w;
  }

  memcpy(prevlp, (T*)&lb[0], w * sizeof(T));
  //
  prev_field_w[i] = w;
  //
  if(field && i == 0)
   lw[0] = w;

  lw[i * 2 + field] = w;

  if(!field || (i + 1) < fh)
   lw[i * 2 + field + 1] = w;
 }
}

void Deinterlacer_Blend::Process(MDFN_Surface* surface, MDFN_Rect& dr, int32* LineWidths, const bool field)
{
 if(dr.h != prev_height)
 {
  prev_valid = false;
  prev_height = dr.h;
 }
 //
 //
 assert(!(surface->h & 1));
 if(!prev_field || prev_field->w < surface->w || prev_field->h < (surface->h / 2))
 {
  prev_field.reset(nullptr);
  prev_field_w.reset(nullptr);
  lb.reset(nullptr);
  prev_field_delay.reset(nullptr);
  //
  prev_field.reset(new MDFN_Surface(nullptr, surface->w, surface->h / 2, surface->w, surface->format));
  prev_field_w.reset(new int32[prev_field->h]);
  lb.reset(new uint32[surface->w]);
  prev_field_delay.reset(new uint32[surface->w]);
  //
  prev_valid = false;
 }
 else if(prev_field->format != surface->format)
 {
  prev_field->SetFormat(surface->format, prev_valid);
 }
 //
 switch(surface->format.opp)
 {
  case 1:
	InternalProcess<uint8, false, 0, 0, 0>(surface, dr, LineWidths, field);
	break;

  case 2:
        if(surface->format.Rprec == 5 && surface->format.Gprec == 6 && surface->format.Bprec == 5)
         InternalProcess<uint16, false, 0, 5, 11>(surface, dr, LineWidths, field); 
        else if(surface->format.Rprec == 5 && surface->format.Gprec == 5 && surface->format.Bprec == 5 && (surface->format.Rshift + surface->format.Gshift + surface->format.Bshift) == 15)
         InternalProcess<uint16, false, 0, 5, 10>(surface, dr, LineWidths, field); 
	else
	{
	 puts("Blend deinterlacer error");
         prev_valid = false;
	 InternalProcess<uint16, false, 0, 5, 11>(surface, dr, LineWidths, field); 
	}
	break;

  case 4:
	if(WantRG)
	{
	 switch(surface->format.Ashift)
	 {
	  case  0: InternalProcess<uint32, true, 8, 16, 24>(surface, dr, LineWidths, field); break;
	  case  8: InternalProcess<uint32, true, 0, 16, 24>(surface, dr, LineWidths, field); break;
	  case 16: InternalProcess<uint32, true, 0,  8, 24>(surface, dr, LineWidths, field); break;
          case 24: InternalProcess<uint32, true, 0,  8, 16>(surface, dr, LineWidths, field); break;

	  default:
		puts("BlendRG deinterlacer error");
		InternalProcess<uint32, false, 0, 0, 0>(surface, dr, LineWidths, field);
		break;
	 }
	}
	else
	 InternalProcess<uint32, false, 0, 0, 0>(surface, dr, LineWidths, field);
	break;
 }
 //
 prev_valid = true;
}

void Deinterlacer_Blend::ClearState(void)
{
 prev_valid = false;
}

}
