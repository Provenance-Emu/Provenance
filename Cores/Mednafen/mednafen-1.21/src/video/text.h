/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* text.h:
**  Copyright (C) 2007-2016 Mednafen Team
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

#ifndef __MDFN_VIDEO_TEXT_H
#define __MDFN_VIDEO_TEXT_H

enum
{
 // If the order of these constants is changed, you must also update the array of FontDescriptor
 // in text.cpp.
 MDFN_FONT_5x7,
 MDFN_FONT_6x9,

// MDFN_FONT_6x10,

 MDFN_FONT_6x12,
 MDFN_FONT_6x13_12x13,
 MDFN_FONT_9x18_18x18,

 #ifdef WANT_INTERNAL_CJK
 MDFN_FONT_12x13,
 MDFN_FONT_18x18,
 #endif

 _MDFN_FONT_COUNT
};

uint32 GetFontHeight(const unsigned fontid);

uint32 GetTextPixLength(const char* text, uint32 fontid = MDFN_FONT_9x18_18x18);
uint32 GetTextPixLength(const char32_t* text, uint32 fontid = MDFN_FONT_9x18_18x18);

INLINE uint32 GetTextPixLength(const std::string& text, uint32 fontid = MDFN_FONT_9x18_18x18) { return GetTextPixLength(text.c_str(), fontid); }
INLINE uint32 GetTextPixLength(const std::u32string& text, uint32 fontid = MDFN_FONT_9x18_18x18) { return GetTextPixLength(text.c_str(), fontid); } 

uint32 DrawText(MDFN_Surface* surf, int32 x, int32 y, const char* text, uint32 color, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0);
uint32 DrawText(MDFN_Surface* surf, const MDFN_Rect& crect, int32 x, int32 y, const char* text, uint32 color, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0);
uint32 DrawTextShadow(MDFN_Surface* surf, int32 x, int32 y, const char* text, uint32 color, uint32 shadcolor, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0);
uint32 DrawTextShadow(MDFN_Surface* surf, const MDFN_Rect& crect, int32 x, int32 y, const char* text, uint32 color, uint32 shadcolor, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0);

uint32 DrawText(MDFN_Surface* surf, int32 x, int32 y, const char32_t* text, uint32 color, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0);
uint32 DrawText(MDFN_Surface* surf, const MDFN_Rect& crect, int32 x, int32 y, const char32_t* text, uint32 color, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0);
uint32 DrawTextShadow(MDFN_Surface* surf, int32 x, int32 y, const char32_t* text, uint32 color, uint32 shadcolor, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0);
uint32 DrawTextShadow(MDFN_Surface* surf, const MDFN_Rect& crect, int32 x, int32 y, const char32_t* text, uint32 color, uint32 shadcolor, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0);

INLINE uint32 DrawText(MDFN_Surface* surf, int32 x, int32 y, const std::string& text, uint32 color, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0) { return DrawText(surf, x, y, text.c_str(), color, fontid, hcenterw); }
INLINE uint32 DrawText(MDFN_Surface* surf, const MDFN_Rect& crect, int32 x, int32 y, const std::string& text, uint32 color, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0) { return DrawText(surf, crect, x, y, text.c_str(), color, fontid, hcenterw); }
INLINE uint32 DrawTextShadow(MDFN_Surface* surf, int32 x, int32 y, const std::string& text, uint32 color, uint32 shadcolor, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0) { return DrawTextShadow(surf, x, y, text.c_str(), color, shadcolor, fontid, hcenterw); }
INLINE uint32 DrawTextShadow(MDFN_Surface* surf, const MDFN_Rect& crect, int32 x, int32 y, const std::string& text, uint32 color, uint32 shadcolor, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0) { return DrawTextShadow(surf, crect, x, y, text.c_str(), color, shadcolor, fontid, hcenterw); }

INLINE uint32 DrawText(MDFN_Surface* surf, int32 x, int32 y, const std::u32string& text, uint32 color, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0) { return DrawText(surf, x, y, text.c_str(), color, fontid, hcenterw); }
INLINE uint32 DrawText(MDFN_Surface* surf, const MDFN_Rect& crect, int32 x, int32 y, const std::u32string& text, uint32 color, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0) { return DrawText(surf, crect, x, y, text.c_str(), color, fontid, hcenterw); }
INLINE uint32 DrawTextShadow(MDFN_Surface* surf, int32 x, int32 y, const std::u32string& text, uint32 color, uint32 shadcolor, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0) { return DrawTextShadow(surf, x, y, text.c_str(), color, shadcolor, fontid, hcenterw); }
INLINE uint32 DrawTextShadow(MDFN_Surface* surf, const MDFN_Rect& crect, int32 x, int32 y, const std::u32string& text, uint32 color, uint32 shadcolor, uint32 fontid = MDFN_FONT_9x18_18x18, uint32 hcenterw = 0) { return DrawTextShadow(surf, crect, x, y, text.c_str(), color, shadcolor, fontid, hcenterw); }


#endif
