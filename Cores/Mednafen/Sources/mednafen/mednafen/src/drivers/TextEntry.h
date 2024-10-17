/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* TextEntry.h:
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

#ifndef __MDFN_DRIVERS_TEXTENTRY_H
#define __MDFN_DRIVERS_TEXTENTRY_H

class TextEntry
{
 public:

 TextEntry();
 ~TextEntry();

 void Draw(MDFN_Surface* surface, const MDFN_Rect& rect, const char* prefix_str, const uint32 color, const uint32 shadcolor, const uint32 font);
 bool Event(const SDL_Event* event);
 void InsertKBB(const std::string& zestring);
 void InsertKBB(const std::u32string& zestring_u32);

 INLINE const std::u32string& GetKBB(void)
 {
  return kb_buffer;
 }

 void ClearKBB(void);
 private:

 std::u32string kb_buffer;
 uint32 kb_cursor_pos;
 uint32 selection_start;
};

#endif
