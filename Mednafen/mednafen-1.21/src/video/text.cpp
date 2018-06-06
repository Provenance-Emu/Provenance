/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* text.cpp:
**  Copyright (C) 2005-2017 Mednafen Team
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

/*
** European-centric fixed-width bitmap font text rendering, with some CJK support.
*/

#include "video-common.h"
#include <mednafen/string/string.h>
#include "font-data.h"

static const struct
{
        uint8 glyph_width;
        uint8 glyph_height;
	int8 extension;
        uint8 entry_bsize;
	const uint8* base_ptr;
} FontDescriptors[_MDFN_FONT_COUNT] =
{
 { 5, 7, 	-1,			sizeof(FontData5x7[0]),		&FontData5x7[0].data[0] },
 { 6, 9,	-1,			sizeof(FontData6x9[0]),		&FontData6x9[0].data[0] },
/*
 { 6, 10,	-1,			sizeof(FontData6x10[0]),	&FontData6x10[0].data[0] },
*/
 { 6, 12,	-1,			sizeof(FontData6x12[0]),	&FontData6x12[0].data[0] },
 #ifdef WANT_INTERNAL_CJK
 { 6, 13,	MDFN_FONT_12x13,	sizeof(FontData6x13[0]),	&FontData6x13[0].data[0] },
 { 9, 18,	MDFN_FONT_18x18,	sizeof(FontData9x18[0]),	&FontData9x18[0].data[0] },
 { 12, 13, 	-1,			sizeof(FontData12x13[0]),	&FontData12x13[0].data[0] },
 { 18, 18, 	-1,			sizeof(FontData18x18[0]),	&FontData18x18[0].data[0] },
 #else
 { 6, 13,	-1,			sizeof(FontData6x13[0]),	&FontData6x13[0].data[0] },
 { 9, 18,	-1,			sizeof(FontData9x18[0]),	&FontData9x18[0].data[0] },
 #endif
};

static uint16 FontDataIndexCache[_MDFN_FONT_COUNT][65536];

uint32 GetFontHeight(const unsigned fontid)
{
 return FontDescriptors[fontid].glyph_height;
}

template<typename T>
static void BuildIndexCache(const unsigned wf, const T* const fsd, const size_t fsd_count)
{
 for(size_t i = 0; i < fsd_count; i++)
  FontDataIndexCache[wf][fsd[i].glyph_num] = i;
}

void MDFN_InitFontData(void)
{
 memset(FontDataIndexCache, 0xFF, sizeof(FontDataIndexCache));

 BuildIndexCache(MDFN_FONT_5x7,        FontData5x7,  FontData5x7_Size / sizeof(font5x7));
 BuildIndexCache(MDFN_FONT_6x9,        FontData6x9,  FontData6x9_Size / sizeof(font6x9));
// BuildIndexCache(MDFN_FONT_6x10,       FontData6x10, FontData6x10_Size / sizeof(font6x10));
 BuildIndexCache(MDFN_FONT_6x12,       FontData6x12, FontData6x12_Size / sizeof(font6x12));
 BuildIndexCache(MDFN_FONT_6x13_12x13, FontData6x13, FontData6x13_Size / sizeof(font6x13));
 BuildIndexCache(MDFN_FONT_9x18_18x18, FontData9x18, FontData9x18_Size / sizeof(font9x18));

 #ifdef WANT_INTERNAL_CJK
 BuildIndexCache(MDFN_FONT_12x13,      FontData12x13, FontData12x13_Size / sizeof(font12x13));
 BuildIndexCache(MDFN_FONT_18x18,      FontData18x18, FontData18x18_Size / sizeof(font18x18));
 #endif
}

static size_t utf32_strlen(const char32_t *s)
{
 size_t ret = 0;

 while(*s++) ret++;

 return(ret);
}

static void DecodeGlyph(char32_t thisglyph, const uint8 **glyph_ptr, uint8 *glyph_width, uint8 *glyph_ov_width, uint32 fontid)
{
 bool GlyphFound = false;
 uint32 recurse_fontid = fontid;

 //if(thisglyph < 0x20)
 // thisglyph = 0x2400 + thisglyph;

 while(!GlyphFound)
 {
  if(thisglyph < 0x10000 && FontDataIndexCache[recurse_fontid][thisglyph] != 0xFFFF)
  {
   *glyph_ptr = FontDescriptors[recurse_fontid].base_ptr + (FontDescriptors[recurse_fontid].entry_bsize * FontDataIndexCache[recurse_fontid][thisglyph]);
   *glyph_width = FontDescriptors[recurse_fontid].glyph_width;
   GlyphFound = true;
  }
  else if(FontDescriptors[recurse_fontid].extension != -1)
   recurse_fontid = FontDescriptors[recurse_fontid].extension;
  else
   break;
 }

 if(!GlyphFound)
 {
  *glyph_ptr = FontDescriptors[fontid].base_ptr + (FontDescriptors[fontid].entry_bsize * FontDataIndexCache[fontid][0xFFFD]);
  *glyph_width = FontDescriptors[fontid].glyph_width;
 }

 if((thisglyph >= 0x0300 && thisglyph <= 0x036F) || (thisglyph >= 0xFE20 && thisglyph <= 0xFE2F))
  *glyph_ov_width = 0;
 //else if(MDFN_UNLIKELY(thisglyph < 0x20))
 //{
 // if(thisglyph == '\b')	(If enabling this, need to change all glyph_ov_width types to int8)
 // {
 //  glyph_width[x] = 0;
 //  glyph_ov_width[x] = std::max<int64>(-(int64)ret, -FontDescriptors[fontid].glyph_width);
 //}
 //}
 else
  *glyph_ov_width = *glyph_width;
}

static uint32 GetTextPixLength(const char32_t* text, const size_t text_len, const uint32 fontid)
{
 uint32 ret = 0;

 for(size_t i = 0; i < text_len; i++)
 {
  const uint8 *glyph_ptr;
  uint8 glyph_width;
  uint8 glyph_ov_width;

  DecodeGlyph(text[i], &glyph_ptr, &glyph_width, &glyph_ov_width, fontid);
  ret += (i == (text_len - 1)) ? glyph_width : glyph_ov_width;
 }
 return ret;
}

uint32 GetTextPixLength(const char* text, uint32 fontid)
{
 uint32 max_glyph_len = strlen((char *)text);

 if(MDFN_LIKELY(max_glyph_len > 0))
 {
  size_t dlen = max_glyph_len;
  std::unique_ptr<char32_t[]> utf32_text_d;
  char32_t utf32_text_l[256];
  char32_t* utf32_text = (256 < dlen) ? (utf32_text_d.reset(new char32_t[dlen]), utf32_text_d.get()) : utf32_text_l;

  UTF8_to_UTF32(text, max_glyph_len, utf32_text, &dlen);

  return GetTextPixLength(utf32_text, std::min<size_t>(max_glyph_len, dlen), fontid);
 }

 return 0;
}

uint32 GetTextPixLength(const char32_t* text, uint32 fontid)
{
 const uint32 text_len = utf32_strlen(text);

 if(MDFN_LIKELY(text_len > 0))
  return GetTextPixLength(text, text_len, fontid);

 return 0;
}

template<typename T>
static uint32 DoRealDraw(T* const surfp, uint32 pitch, const int32 x, const int32 y, const int32 bx0, const int32 bx1, const int32 by0, const int32 by1, uint32 fgcolor, const char32_t* const text, const size_t text_len, const uint32 fontid)
{
 const uint32 glyph_height = FontDescriptors[fontid].glyph_height;
 uint32 gy_start = std::min<int64>(glyph_height, std::max<int64>(0, (int64)by0 - y));
 uint32 gy_bound = std::min<int64>(glyph_height, std::max<int64>(0, (int64)by1 - y));
 T* dest = surfp + y * pitch + x;
 uint32 ret = 0;

 for(size_t i = 0; i < text_len; i++)
 {
  const uint8* glyph_ptr;
  uint8 glyph_width;
  uint8 glyph_ov_width;

  DecodeGlyph(text[i], &glyph_ptr, &glyph_width, &glyph_ov_width, fontid);
  //
  //
  //
  uint32 gx_start = std::min<int64>(glyph_width, std::max<int64>(0, (int64)bx0 - x - ret));
  uint32 gx_bound = std::min<int64>(glyph_width, std::max<int64>(0, (int64)bx1 - x - ret));
  size_t sd_inc = (glyph_width >> 3) + 1;
  const uint8* sd = glyph_ptr + (sd_inc * gy_start);
  T* dd = dest + (gy_start * pitch);

  //printf("x=%d, y=%d --- %d %d\n", x, y, gx_start, gx_bound);

  for(uint32 gy = gy_start; MDFN_LIKELY(gy < gy_bound); gy++)
  {
   for(uint32 gx = gx_start; MDFN_LIKELY(gx < gx_bound); gx++)
   {
    if((sd[gx >> 3] << (gx & 0x7)) & 0x80)
     dd[gx] = fgcolor;
   }
   dd += pitch;
   sd += sd_inc;
  }

  dest += glyph_ov_width;
  ret += (i == (text_len - 1)) ? glyph_width : glyph_ov_width;
 }

 return ret;
}

static uint32 DrawTextUTF32(MDFN_Surface* surf, const MDFN_Rect* cr, int32 x, int32 y, const char32_t* text, const size_t text_len, uint32 color, uint32 shadcolor, uint32 fontid, uint32 hcenterw, const bool shadow)
{
 int32 bx0, bx1;
 int32 by0, by1;

 if(cr)
 {
  bx0 = std::max<int32>(0, cr->x);
  bx1 = std::min<int64>(surf->w, std::max<int64>(0, (int64)cr->x + cr->w));

  by0 = std::max<int32>(0, cr->y);
  by1 = std::min<int64>(surf->h, std::max<int64>(0, (int64)cr->y + cr->h));
 }
 else
 {
  bx0 = 0;
  bx1 = surf->w;

  by0 = 0;
  by1 = surf->h;
 }

 //
 //
 //
 if(!text_len)
  return 0;

 if(hcenterw)
 {
  uint32 pixwidth = GetTextPixLength(text, text_len, fontid);

  if(hcenterw > pixwidth)
   x += (int32)(hcenterw - pixwidth) / 2;
 }

 switch(surf->format.bpp)
 {
  default:
	return 0;

  case 8:
	if(shadow)
	 DoRealDraw(surf->pix<uint8>(), surf->pitchinpix, x + 1, y + 1, bx0, bx1, by0, by1, shadcolor, text, text_len, fontid);

	return DoRealDraw(surf->pix<uint8>(), surf->pitchinpix, x, y, bx0, bx1, by0, by1, color, text, text_len, fontid);

  case 16:
	if(shadow)
	 DoRealDraw(surf->pix<uint16>(), surf->pitchinpix, x + 1, y + 1, bx0, bx1, by0, by1, shadcolor, text, text_len, fontid);

	return DoRealDraw(surf->pix<uint16>(), surf->pitchinpix, x, y, bx0, bx1, by0, by1, color, text, text_len, fontid);

  case 32:
	if(shadow)
	 DoRealDraw(surf->pix<uint32>(), surf->pitchinpix, x + 1, y + 1, bx0, bx1, by0, by1, shadcolor, text, text_len, fontid);

	return DoRealDraw(surf->pix<uint32>(), surf->pitchinpix, x, y, bx0, bx1, by0, by1, color, text, text_len, fontid);
 }
}

static uint32 DrawTextUTF8(MDFN_Surface* surf, const MDFN_Rect* cr, int32 x, int32 y, const char* text, const size_t text_len, uint32 color, uint32 shadcolor, uint32 fontid, uint32 hcenterw, const bool shadow)
{
 size_t dlen = text_len;
 std::unique_ptr<char32_t[]> utf32_text_d;
 char32_t utf32_text_l[256];
 char32_t* utf32_text = (256 < dlen) ? (utf32_text_d.reset(new char32_t[dlen]), utf32_text_d.get()) : utf32_text_l;

 UTF8_to_UTF32(text, text_len, utf32_text, &dlen);

 return DrawTextUTF32(surf, cr, x, y, utf32_text, std::min<size_t>(text_len, dlen), color, shadcolor, fontid, hcenterw, shadow);
}

uint32 DrawText(MDFN_Surface* surf, int32 x, int32 y, const char* text, uint32 color, uint32 fontid, uint32 hcenterw)
{
 return DrawTextUTF8(surf, nullptr, x, y, text, strlen(text), color, 0, fontid, hcenterw, false);
}

uint32 DrawText(MDFN_Surface* surf, const MDFN_Rect& cr, int32 x, int32 y, const char* text, uint32 color, uint32 fontid, uint32 hcenterw)
{
 return DrawTextUTF8(surf, &cr, x, y, text, strlen(text), color, 0, fontid, hcenterw, false);
}

uint32 DrawTextShadow(MDFN_Surface* surf, int32 x, int32 y, const char* text, uint32 color, uint32 shadcolor, uint32 fontid, uint32 hcenterw)
{
 return DrawTextUTF8(surf, nullptr, x, y, text, strlen(text), color, shadcolor, fontid, hcenterw, true);
}

uint32 DrawTextShadow(MDFN_Surface* surf, const MDFN_Rect& cr, int32 x, int32 y, const char* text, uint32 color, uint32 shadcolor, uint32 fontid, uint32 hcenterw)
{
 return DrawTextUTF8(surf, &cr, x, y, text, strlen(text), color, shadcolor, fontid, hcenterw, true);
}

//
//
//
uint32 DrawText(MDFN_Surface* surf, int32 x, int32 y, const char32_t* text, uint32 color, uint32 fontid, uint32 hcenterw)
{
 return DrawTextUTF32(surf, nullptr, x, y, text, utf32_strlen(text), color, 0, fontid, hcenterw, false);
}

uint32 DrawText(MDFN_Surface* surf, const MDFN_Rect& cr, int32 x, int32 y, const char32_t* text, uint32 color, uint32 fontid, uint32 hcenterw)
{
 return DrawTextUTF32(surf, &cr, x, y, text, utf32_strlen(text), color, 0, fontid, hcenterw, false);
}

uint32 DrawTextShadow(MDFN_Surface* surf, int32 x, int32 y, const char32_t* text, uint32 color, uint32 shadcolor, uint32 fontid, uint32 hcenterw)
{
 return DrawTextUTF32(surf, nullptr, x, y, text, utf32_strlen(text), color, shadcolor, fontid, hcenterw, true);
}

uint32 DrawTextShadow(MDFN_Surface* surf, const MDFN_Rect& cr, int32 x, int32 y, const char32_t* text, uint32 color, uint32 shadcolor, uint32 fontid, uint32 hcenterw)
{
 return DrawTextUTF32(surf, &cr, x, y, text, utf32_strlen(text), color, shadcolor, fontid, hcenterw, true);
}
