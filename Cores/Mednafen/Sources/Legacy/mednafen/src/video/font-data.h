/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* font-data.h:
**  Copyright (C) 2005-2016 Mednafen Team
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

#ifndef __MDFN_VIDEO_FONT_DATA_H
#define __MDFN_VIDEO_FONT_DATA_H

// Note: The size of each these structs shouldn't exceed 256 bytes(current worst-case is about 56 bytes with the 18x18 font).

typedef struct
{
        uint16 glyph_num;
        uint8 data[7];
} font5x7;

typedef struct
{
        uint16 glyph_num;
        uint8 data[9];
} font6x9;
/*
typedef struct
{
        uint16 glyph_num;
        uint8 data[10];
} font6x10;
*/
typedef struct
{
        uint16 glyph_num;
        uint8 data[12];
} font6x12;

typedef struct
{
        uint16 glyph_num;
        uint8 data[13];
} font6x13;

typedef struct
{
        uint16 glyph_num;
        uint8 data[18 * 2];
} font9x18;

extern const font5x7 FontData5x7[];
extern const font6x9 FontData6x9[];
//extern const font6x10 FontData6x10[];
extern const font6x12 FontData6x12[];
extern const font6x13 FontData6x13[];
extern const font9x18 FontData9x18[];

#ifdef __cplusplus
extern "C" {
#endif

typedef struct
{
        uint16_t glyph_num;
        uint8_t data[13 * 2];
} font12x13;

typedef struct
{
        uint16 glyph_num;
        uint8 data[18 * 3];
} font18x18;

extern const font12x13 FontData12x13[];
extern const font18x18 FontData18x18[];

extern const int FontData12x13_Size;
extern const int FontData18x18_Size;

#ifdef __cplusplus
} /* extern "C" */
#endif


extern const int FontData5x7_Size;
extern const int FontData6x9_Size;
//extern const int FontData6x10_Size;
extern const int FontData6x12_Size;
extern const int FontData6x13_Size;
extern const int FontData9x18_Size;

#endif
