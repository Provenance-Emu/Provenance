/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* convert.cpp - Pixel format conversion
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

#include <mednafen/mednafen.h>
#include <mednafen/video/surface.h>
#include <mednafen/video/convert.h>

namespace Mednafen
{
//
//

template<bool src_equals_dest, typename OT, typename NT, uint8 old_colorspace, uint8 new_colorspace>
static NO_INLINE void Convert_Slow(const void* src, void* dest, uint32 count, const MDFN_PixelFormatConverter::convert_context* ctx)
{
 MDFN_PixelFormat old_pf = ctx->spf;
 MDFN_PixelFormat new_pf = ctx->dpf;

 old_pf.opp = sizeof(OT);
 new_pf.opp = sizeof(NT);

 old_pf.colorspace = old_colorspace;
 new_pf.colorspace = new_colorspace;
 //
 //
 OT* src_row = (OT*)src;
 NT* dest_row = src_equals_dest ? (NT*)src_row : (NT*)dest;

 for(unsigned x = 0; MDFN_LIKELY(x < count); x++)
 {
  if(sizeof(OT) == 1)
   dest_row[x] = ctx->palconv[src_row[x]];
  else
  {
   int r, g, b, a;

   old_pf.DecodeColor(src_row[x], r, g, b, a);
   dest_row[x] = new_pf.MakeColor(r, g, b, a);
  }
 }
}

template<bool src_equals_dest, typename OT, typename NT, uint64 old_pftag, uint64 new_pftag>
static NO_INLINE void Convert_Fast(const void* src, void* dest, uint32 count, const MDFN_PixelFormatConverter::convert_context* ctx)
{
 const MDFN_PixelFormat old_pf = MDFN_PixelFormat(old_pftag);
 const MDFN_PixelFormat new_pf = MDFN_PixelFormat(new_pftag);
 OT* src_row = (OT*)src;
 NT* dest_row = src_equals_dest ? (NT*)src_row : (NT*)dest;

 for(unsigned x = 0; MDFN_LIKELY(x < count); x++)
 {
  uint32 c = src_row[x];

  if(sizeof(OT) == 1)
   dest_row[x] = ctx->palconv[c];
  else if(old_pftag == MDFN_PixelFormat::IRGB16_1555 && new_pftag == MDFN_PixelFormat::RGB16_565)
   dest_row[x] = (c & 0x1F) | ((c << 1) & 0xF800) | (MDFN_PixelFormat::LUT8to6[MDFN_PixelFormat::LUT5to8[(c >> 5) & 0x1F]] << 5);
  else if(old_pftag == MDFN_PixelFormat::RGB16_565 && new_pftag == MDFN_PixelFormat::IRGB16_1555)
   dest_row[x] = (c & 0x1F) | ((c >> 1) & 0x7C00) | (MDFN_PixelFormat::LUT8to5[MDFN_PixelFormat::LUT6to8[(c >> 5) & 0x3F]] << 5);
  else
  {
   int r, g, b, a;

   if(old_pftag == MDFN_PixelFormat::IRGB16_1555)
   {
    r = MDFN_PixelFormat::LUT5to8[(c >> 10) & 0x1F];
    g = MDFN_PixelFormat::LUT5to8[(c >>  5) & 0x1F];
    b = MDFN_PixelFormat::LUT5to8[(c >>  0) & 0x1F];
    a = 0;
   }
   else if(old_pftag == MDFN_PixelFormat::RGB16_565)
   {
    r = MDFN_PixelFormat::LUT5to8[(c >> 11) & 0x1F];
    g = MDFN_PixelFormat::LUT6to8[(c >>  5) & 0x3F];
    b = MDFN_PixelFormat::LUT5to8[(c >>  0) & 0x1F];
    a = 0;
   }
   else if(old_pftag == MDFN_PixelFormat::ARGB16_4444)
   {
    a = ((c & 0xF000) >> 8) | ((c & 0xF000) >> 12);
    r = ((c & 0xF00) >> 4) | ((c & 0xF00) >> 8);
    g = ((c & 0xF0) >> 0) | ((c & 0xF0) >> 4);
    b = ((c & 0xF) << 4) | ((c & 0xF) >> 0);
   }
   else
    old_pf.DecodeColor(c, r, g, b, a);

/*
   if(new_pftag == MDFN_PixelFormat::RGB8X3_888 || new_pftag == MDFN_PixelFormat::BGR8X3_888)
   {
    if(new_pftag == MDFN_PixelFormat::RGB8X3_888)
    {
     dest_row[x * 3 + 0] = r;
     dest_row[x * 3 + 1] = g;
     dest_row[x * 3 + 2] = b;
    }
    else
    {
     dest_row[x * 3 + 0] = b;
     dest_row[x * 3 + 1] = g;
     dest_row[x * 3 + 2] = r;
    }
   }
   else
*/
   {
    if(new_pftag == MDFN_PixelFormat::IRGB16_1555)
     c = (MDFN_PixelFormat::LUT8to5[r] << 10) | (MDFN_PixelFormat::LUT8to5[g] << 5) | (MDFN_PixelFormat::LUT8to5[b] << 0);
    else if(new_pftag == MDFN_PixelFormat::RGB16_565)
     c = (MDFN_PixelFormat::LUT8to5[r] << 11) | (MDFN_PixelFormat::LUT8to6[g] << 5) | (MDFN_PixelFormat::LUT8to5[b] << 0);
    else
     c = new_pf.MakeColor(r, g, b, a);

    dest_row[x] = c;
   }
  }
 }
}

template<bool src_equals_dest>
static void Convert_xxxx8888(const void* src, void* dest, uint32 count, const MDFN_PixelFormatConverter::convert_context* ctx)
{
 const MDFN_PixelFormat spf = ctx->spf;
 const MDFN_PixelFormat dpf = ctx->dpf;
 const unsigned tmp = (0 << spf.Rshift) | (1 << spf.Gshift) | (2 << spf.Bshift) | (3 << spf.Ashift);
 const unsigned drs[4] = { dpf.Rshift, dpf.Gshift, dpf.Bshift, dpf.Ashift };
 const unsigned sh[4] = { (uint8)drs[(tmp >> 0) & 3], (uint8)drs[(tmp >> 8) & 3], (uint8)drs[(tmp >> 16) & 3], (uint8)drs[(tmp >> 24) & 3] };
 uint32* src_row = (uint32*)src;
 uint32* dest_row = src_equals_dest ? src_row : (uint32*)dest;

 for(unsigned x = 0; MDFN_LIKELY(x < count); x++)
 {
  uint32 c = src_row[x];

  dest_row[x] = ((uint8)(c >> 0) << sh[0]) | ((uint8)(c >> 8) << sh[1]) | ((uint8)(c >> 16) << sh[2]) | ((uint8)(c >> 24) << sh[3]);
 }
}

template<bool src_equals_dest>
static MDFN_PixelFormatConverter::convert_func CalcConversionFunction(const MDFN_PixelFormat& spf, const MDFN_PixelFormat& dpf)
{
#if 1
 switch(spf.tag)
 {
  #define CROWE(st, sft, dt, dft) case MDFN_PixelFormat::dft: return Convert_Fast<src_equals_dest, st, dt, MDFN_PixelFormat::sft, MDFN_PixelFormat::dft>;
  #define CROW(st, sft) case MDFN_PixelFormat::sft:	\
				switch(dpf.tag)		\
				{			\
				 default: break;	\
				 CROWE(st, sft, uint32, ABGR32_8888)	\
				 CROWE(st, sft, uint32, ARGB32_8888)	\
				 CROWE(st, sft, uint32, RGBA32_8888)	\
				 CROWE(st, sft, uint32, BGRA32_8888)	\
				 CROWE(st, sft, uint16, IRGB16_1555)	\
				 CROWE(st, sft, uint16, RGB16_565)	\
				 CROWE(st, sft, uint16, ARGB16_4444)	\
				 /*CROWE(st, sft, uint8, RGB8X3_888)*/	\
				 /*CROWE(st, sft, uint8, RGB8X3_888)*/	\
				}			\
				break;
  default: break;
  CROW(uint32, ABGR32_8888)
  CROW(uint32, ARGB32_8888)
  CROW(uint32, RGBA32_8888)
  CROW(uint32, BGRA32_8888)
  CROW(uint16, IRGB16_1555)
  CROW(uint16, RGB16_565)
  CROW(uint16, ARGB16_4444)
  //
  //CROW(uint8,  RGB8P_888)
  //CROW(uint8,  RGB8P_666)
  #undef CROWE
  #undef CROW
 }
#endif

#if 1
 if(spf.opp == dpf.opp && spf.colorspace == dpf.colorspace)
 {
  if(spf.opp == 4 && !((spf.Rshift | spf.Gshift | spf.Bshift | spf.Ashift | dpf.Rshift | dpf.Gshift | dpf.Bshift | dpf.Ashift) & 7))
  {
   return Convert_xxxx8888<src_equals_dest>;
  }
 }
#endif

 //
 // Slow fallback:
 //
 #define CROWE(scs, stype, dcs, dtype) case (dcs << 4) | sizeof(dtype): return Convert_Slow<src_equals_dest, stype, dtype, scs, dcs>; break;
 #define CROW(scs, stype)		\
	case (scs << 4) | sizeof(stype):	\
	switch((dpf.colorspace << 4) | dpf.opp)		\
	{			\
	 CROWE(scs, stype, MDFN_COLORSPACE_RGB, uint8)	\
	 CROWE(scs, stype, MDFN_COLORSPACE_RGB, uint16)	\
	 CROWE(scs, stype, MDFN_COLORSPACE_RGB, uint32)	\
	}			\
	break;
 switch((spf.colorspace << 4) | spf.opp)
 {
  CROW(MDFN_COLORSPACE_RGB, uint8)
  CROW(MDFN_COLORSPACE_RGB, uint16)
  CROW(MDFN_COLORSPACE_RGB, uint32)
 }
 #undef CROWE
 #undef CROW

 return nullptr;
}


MDFN_PixelFormatConverter::MDFN_PixelFormatConverter(const MDFN_PixelFormat& src_pf, const MDFN_PixelFormat& dest_pf, const MDFN_PaletteEntry* palette)
{
 ctx.spf = src_pf;
 ctx.dpf = dest_pf;

 if(palette)
 {
  ctx.palconv.reset(new uint32[256]);

  for(unsigned i = 0; i < 256; i++)
  {
   uint8 r, g, b;

   ctx.spf.DecodePColor(palette[i], r, g, b);
   ctx.palconv[i] = ctx.dpf.MakeColor(r, g, b, 0);
  }
 }

 convert1 = CalcConversionFunction<true>(ctx.spf, ctx.dpf);
 convert2 = CalcConversionFunction<false>(ctx.spf, ctx.dpf);
}

//
//
}
