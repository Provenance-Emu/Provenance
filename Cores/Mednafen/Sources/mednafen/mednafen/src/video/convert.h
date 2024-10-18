/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* convert.h - Pixel format conversion
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

#ifndef __MDFN_VIDEO_CONVERT_H
#define __MDFN_VIDEO_CONVERT_H

namespace Mednafen
{
 class MDFN_PixelFormatConverter
 {
  public:  
  MDFN_PixelFormatConverter(const MDFN_PixelFormat& src_pf, const MDFN_PixelFormat& dest_pf, const MDFN_PaletteEntry* palette = nullptr);

  INLINE void Convert(void* dest, uint32 count)
  {
   convert1(dest, dest, count, &ctx);
  }

  INLINE void Convert(const void* src, void* dest, uint32 count)
  {
   convert2(src, dest, count, &ctx);
  }

  struct convert_context
  {
   MDFN_PixelFormat spf;
   MDFN_PixelFormat dpf;
   std::unique_ptr<uint32[]> palconv;
  };

  typedef void (*convert_func)(const void*, void*, uint32, const convert_context*);
  private:

  convert_func convert1;
  convert_func convert2;
  convert_context ctx;
 };
}

#endif
