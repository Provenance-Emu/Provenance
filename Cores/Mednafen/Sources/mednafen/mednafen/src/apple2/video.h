/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* video.h:
**  Copyright (C) 2018-2023 Mednafen Team
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

#ifndef __MDFN_APPLE2_VIDEO_H
#define __MDFN_APPLE2_VIDEO_H

namespace MDFN_IEN_APPLE2
{
namespace Video
{

struct Settings
{
 float hue = 0.0;
 float saturation = 0.0;
 float contrast = 0.0;
 float brightness = 0.0;
 unsigned color_smooth = 0;
 uint32 force_mono = 0x000000;
 bool mixed_text_mono = false;

 float postsharp = 0.0;
 int mono_lumafilter = 5;
 int color_lumafilter = -3;

 enum
 {
  MODE_COMPOSITE = 0,
  MODE_RGB,
  MODE_RGB_TFR,

  MODE_RGB_QD,
  MODE_RGB_QD_TFR,

  MODE_RGB_ALT,
  MODE_RGB_ALT_TFR,

  MODE_RGB_VIDEO7,

  // TODO: MODE_RGB_IIGS
 };

 unsigned mode = MODE_COMPOSITE;

 enum
 {
  MATRIX_MEDNAFEN = 0,

  MATRIX_LA7620,

  MATRIX_CXA2025_JAPAN,
  MATRIX_CXA2025_USA,

  MATRIX_CXA2060_JAPAN,
  MATRIX_CXA2060_USA,

  MATRIX_CXA2095_JAPAN,
  MATRIX_CXA2095_USA,
  //
  MATRIX_CUSTOM
 };

 unsigned matrix = MATRIX_CUSTOM;

 float custom_matrix[3][2];
};

MDFN_HIDE extern void (*Tick)(void);

MDFN_Rect StartFrame(MDFN_Surface* s, int32* lw);

void Power(void);
void StateAction(StateMem* sm, const unsigned load, const bool data_only);
void Init(const bool emulate_iie);
void Kill(void);
void SetFormat(const MDFN_PixelFormat& f, const Settings& s, uint8* CustomPalette, uint32 CustomPaletteNumEntries);
void SetVideoROM(uint8* p);

enum
{
 GSREG_HCOUNTER = 0,
 GSREG_VCOUNTER
};

uint32 GetRegister(const unsigned id, char* const special = nullptr, const uint32 special_len = 0);
void SetRegister(const unsigned id, const uint32 value);
//
//
}
}
#endif
