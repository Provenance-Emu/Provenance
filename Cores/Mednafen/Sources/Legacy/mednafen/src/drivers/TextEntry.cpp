/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* TextEntry.cpp:
**  Copyright (C) 2007-2020 Mednafen Team
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

#include "main.h"
#include "TextEntry.h"

TextEntry::TextEntry()
{
 kb_buffer.clear();
 kb_cursor_pos = 0;
 selection_start = ~0U;
}

TextEntry::~TextEntry()
{


}

void TextEntry::InsertKBB(const std::u32string& zestring_u32)
{
 kb_buffer.insert(kb_cursor_pos, zestring_u32);
 kb_cursor_pos += zestring_u32.size();
 while(kb_cursor_pos < kb_buffer.size() && UCPIsCombining(kb_buffer[kb_cursor_pos]))
  kb_cursor_pos++;
}

void TextEntry::InsertKBB(const std::string &zestring)
{
 std::u32string zestring_u32 = UTF8_to_UTF32(zestring);

 InsertKBB(zestring_u32);
}

void TextEntry::ClearKBB(void)
{
 kb_buffer.clear();
 kb_cursor_pos = 0;
 selection_start = ~0U;
}

void TextEntry::Draw(MDFN_Surface* surface, const MDFN_Rect& rect, const char* prefix_str, const uint32 color, const uint32 shadcolor, const uint32 font)
{
 const uint32 font_height = GetFontHeight(font);
 const int32 prefix_w = prefix_str ? GetTextPixLength(prefix_str, font) : 0;
 const int32 kbcursorw = GetGlyphWidth((kb_cursor_pos < kb_buffer.size()) ? kb_buffer[kb_cursor_pos] : ' ', font);
 const int32 pixtocursor = GetTextPixLength(kb_buffer.data(), kb_cursor_pos, font);
 int32 kb_x = rect.x + std::min<int32>(0, rect.w - (prefix_w + pixtocursor + kbcursorw));
 const int32 kb_y = rect.y;

 if(prefix_str)
  kb_x += DrawTextShadow(surface, rect, kb_x, kb_y, prefix_str, color, shadcolor, font);

 DrawTextShadow(surface, rect, kb_x, kb_y, kb_buffer, color, shadcolor, font);

 if(Time::MonoMS() & 0x100)
 {
  uint32 x = kb_x + pixtocursor;
  uint32 w = kbcursorw;

  MDFN_DrawFillRect(surface, rect, x, kb_y, w, font_height, color);
 }
}

bool TextEntry::Event(const SDL_Event *event)
{
 bool ret = false;

 if(event->type == SDL_KEYDOWN)
 {
  const auto sym = event->key.keysym.sym;
  const auto mod = event->key.keysym.mod;
  const bool ctrl = mod & KMOD_CTRL;
  const bool shift = mod & KMOD_SHIFT;
  const bool alt = mod & KMOD_LALT;

  if(alt)
   return ret;

  if((sym == SDLK_v      && ctrl && !shift) ||
     (sym == SDLK_INSERT && !ctrl && shift))
  {
   if(SDL_HasClipboardText() == SDL_TRUE)
   {
    char* ctext = SDL_GetClipboardText();	// FIXME: SDL_Free() on exception
    if(ctext)
    {
     const std::u32string u32ctext = UTF8_to_UTF32(ctext);
     SDL_free(ctext);
     InsertKBB(u32ctext);
    }
   }
  }
  else switch(sym)
  {
/*
   case SDLK_LSHIFT:
   case SDLK_RSHIFT:
	if(selection_start == ~0U)
	 selection_start = kb_cursor_pos;
	break;
*/
   case SDLK_HOME:
	if(!ctrl)
	 kb_cursor_pos = 0;
        break;

   case SDLK_END:
	if(!ctrl)
	 kb_cursor_pos = kb_buffer.size();
        break;

   case SDLK_LEFT:
	if(kb_cursor_pos)
	{
	 do
         {
          kb_cursor_pos--;
         } while(kb_cursor_pos && UCPIsCombining(kb_buffer[kb_cursor_pos]));
	}
        break;

   case SDLK_RIGHT:
	if(kb_cursor_pos < kb_buffer.size())
	{
	 do
	 {
          kb_cursor_pos++;
         } while(kb_cursor_pos < kb_buffer.size() && UCPIsCombining(kb_buffer[kb_cursor_pos]));
	}
        break;

   case SDLK_RETURN:
	ret = true;
	break;

   case SDLK_BACKSPACE:
        if(kb_buffer.size() && kb_cursor_pos)
        {
	 if(ctrl && !shift)
	 {
	  kb_buffer.erase(0, std::min<size_t>(kb_buffer.size(), kb_cursor_pos));
	  kb_cursor_pos = 0;
	 }
	 else
	 {
          bool uic;

	  do
	  {
	   uic = UCPIsCombining(kb_buffer[kb_cursor_pos - 1]);
           kb_buffer.erase(kb_cursor_pos - 1, 1);
           kb_cursor_pos--;
	  } while(kb_buffer.size() && kb_cursor_pos && uic);
	 }
        }
        break;

   case SDLK_DELETE:
        if(kb_buffer.size() && kb_cursor_pos < kb_buffer.size())
        {
	 if(ctrl && !shift)
	  kb_buffer.erase(kb_cursor_pos);
	 else
	 {
          do
          {
           kb_buffer.erase(kb_cursor_pos, 1);
          } while(kb_buffer.size() && kb_cursor_pos < kb_buffer.size() && UCPIsCombining(kb_buffer[kb_cursor_pos]));
	 }
        }
        break;
  }
 }
 return ret;
}
