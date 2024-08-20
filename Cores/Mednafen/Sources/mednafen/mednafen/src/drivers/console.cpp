/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* console.cpp:
**  Copyright (C) 2006-2020 Mednafen Team
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
#include "console.h"
#include "nongl.h"
#include <mednafen/string/string.h>

MDFNConsole::MDFNConsole(bool setshellstyle)
{
 shellstyle = setshellstyle;
 prompt_visible = true;
 Scrolled = 0;
 opacity = 0xC0;

 ScrolledVecTarg = -1;
 LastPageSize = 0;
}

MDFNConsole::~MDFNConsole()
{

}

bool MDFNConsole::TextHook(const std::string &text)
{
 WriteLine(text);

 return true;
}

void MDFNConsole::ProcessKBBuffer(void)
{
 const std::string kb_utf8 = UTF32_to_UTF8(te.GetKBB()); 
 //
 te.ClearKBB();
 //
 for(size_t i = 0, begin_i = 0; i <= kb_utf8.size(); i++)
 {
  if(i == kb_utf8.size() || kb_utf8[i] == '\r' || kb_utf8[i] == '\n')
  {
   TextHook(kb_utf8.substr(begin_i, i - begin_i));

   if((i + 1) < kb_utf8.size() && kb_utf8[i] == '\r' && kb_utf8[i + 1] == '\n')
    i++;

   begin_i = i + 1;
  }
 }
}

#define KMOD_TEST_SHIFT(mod) (!((mod) & (KMOD_CTRL | KMOD_LALT)) && ((mod) & (KMOD_SHIFT)))
#define KMOD_TEST_CTRL(mod) (!((mod) & (KMOD_SHIFT | KMOD_LALT)) && ((mod) & (KMOD_CTRL)))

bool MDFNConsole::Event(const SDL_Event *event)
{
 if(event->type == SDL_TEXTINPUT)
 {
  if(!(SDL_GetModState() & KMOD_LALT))
  {
   te.InsertKBB(event->text.text);
  }
 }
 else if(event->type == SDL_KEYDOWN)
 {
  const auto mod = event->key.keysym.mod;
  const bool ctrl = mod & KMOD_CTRL;
  //const bool shift = mod & KMOD_SHIFT;
  const bool alt = mod & KMOD_LALT;

  if(alt)
   return false;

  switch(event->key.keysym.sym)
  {
   case SDLK_HOME:
	if(ctrl)
	 Scrolled = -1;
	break;

   case SDLK_END:
	if(ctrl)
	 Scrolled = 0;
	break;

   case SDLK_UP: 
	Scrolled = Scrolled + 1;
	break;

   case SDLK_DOWN: 
	Scrolled = std::max<int32>(0, Scrolled - 1);
	break;

   case SDLK_PAGEUP:
	Scrolled = (Scrolled + LastPageSize);
	break;

   case SDLK_PAGEDOWN:
	Scrolled = std::max<int64>(0, (int64)Scrolled - LastPageSize);
	break;
  }
 }

 if(te.Event(event))
  ProcessKBBuffer();

 return false;
}

MDFN_Surface* MDFNConsole::Draw(const MDFN_PixelFormat& pformat, const int32 dim_w, const int32 dim_h, const unsigned fontid, const uint32 hex_color) //, const uint32 hex_cursorcolor)
{
 const int32 font_height = GetFontHeight(fontid);
 const uint32 color = pformat.MakeColor((hex_color >> 16) & 0xFF, (hex_color >> 8) & 0xFF, (hex_color >> 0) & 0xFF, 0xFF);
 const uint32 shadcolor = pformat.MakeColor(0x00, 0x00, 0x01, 0xFF);
 //const uint32 cursorcolor = pformat.MakeColor((hex_cursorcolor >> 16) & 0xFF, (hex_cursorcolor >> 8) & 0xFF, (hex_cursorcolor >> 0) & 0xFF, 0xFF);
 bool scroll_resync = false;
 bool draw_scrolled_notice = false;

 if(Scrolled < 0)
 {
  scroll_resync = true;
  ScrolledVecTarg = 0;
 }

 if(!surface || surface->w != dim_w)
 {
  Scrolled = 0;

  if(ScrolledVecTarg >= 0)
   scroll_resync = true;
 }

 if(!surface || surface->w != dim_w || surface->h != dim_h || surface->format != pformat)
 {
  surface.reset(nullptr);
  surface.reset(new MDFN_Surface(nullptr, dim_w, dim_h, dim_w, pformat));
  tmp_surface.reset(nullptr);
 }

 if(!tmp_surface || tmp_surface->h < (font_height + 1))
 {
  tmp_surface.reset(nullptr);
  tmp_surface.reset(new MDFN_Surface(nullptr, 1024, font_height + 1, 1024, pformat));
 }
 //
 //
 //
 const int32 w = surface->w;
 const int32 h = surface->h;

 surface->Fill(0, 0, 0, opacity);

 //
 //
 //
 int32 scroll_counter = 0;
 int32 destline;
 int32 vec_index = TextLog.size() - 1;

 destline = ((h - font_height) / font_height) - 1;

 if(shellstyle)
  vec_index--;
 else if(!prompt_visible)
 {
  destline = (h / font_height) - 1;
  //vec_index--;
 }

 LastPageSize = (destline + 1);

 while(destline >= 0 && vec_index >= 0)
 {
  int32 pw = GetTextPixLength(TextLog[vec_index].c_str(), fontid) + 1;

  if(pw > tmp_surface->w)
  {
   tmp_surface.reset(nullptr);
   tmp_surface.reset(new MDFN_Surface(nullptr, pw, font_height + 1, pw, pformat));
  }

  tmp_surface->Fill(0, 0, 0, opacity);
  DrawTextShadow(tmp_surface.get(), 0, 0, TextLog[vec_index], color, shadcolor, fontid);
  int32 numlines = (uint32)ceil((double)pw / w);

  // Resync console scroll to the last drawn line of the target unwrapped line in the scrollback buffer, not the first,
  // otherwise the console will erroneously scroll up on windowed<->fullscreen transitions when the last line is wider
  // than the console viewport, confusing the user.
  if(scroll_resync && vec_index == ScrolledVecTarg)
  {
   Scrolled = scroll_counter;
   scroll_resync = false;
  }

  while(numlines > 0 && destline >= 0)
  {
   if(!scroll_resync && scroll_counter >= Scrolled)
   {
    if(scroll_counter == Scrolled)
     ScrolledVecTarg = vec_index;
    //
    int32 offs = (numlines - 1) * w;
    MDFN_Rect tmp_rect, dest_rect;
    tmp_rect.x = offs;
    tmp_rect.y = 0;
    tmp_rect.h = font_height;
    tmp_rect.w = (pw - offs) > (int32)w ? w : pw - offs;

    dest_rect.x = 0;
    dest_rect.y = destline * font_height;
    dest_rect.w = tmp_rect.w;
    dest_rect.h = tmp_rect.h;

    MDFN_StretchBlitSurface(tmp_surface.get(), tmp_rect, surface.get(), dest_rect);
    destline--;
   }
   else
    draw_scrolled_notice = true;

   numlines--;
   scroll_counter++;
  }
  vec_index--;
 }

 if(prompt_visible)
 {
  const char* prefix_str;

  if(shellstyle)
  {
   int t = TextLog.size() - 1;
   if(t >= 0)
    prefix_str = TextLog[t].c_str();
   else
    prefix_str = "";
  }
  else
   prefix_str = "#>";

  MDFN_Rect kbrect = { 0, h - (font_height + 1), surface->w, font_height };
  te.Draw(surface.get(), kbrect, prefix_str, color, shadcolor, fontid);
 }

 if(draw_scrolled_notice)
  DrawText(surface.get(), surface->w - 8, surface->h - 14, "↕", pformat.MakeColor(0x00, 0xFF, 0x00, 0xFF), fontid);

 return surface.get();
}

void MDFNConsole::WriteLine(const std::string &text)
{
 TextLog.push_back(text);
}

void MDFNConsole::AppendLastLine(const std::string &text)
{
 if(TextLog.size()) // Should we throw an exception if this isn't true?
  TextLog[TextLog.size() - 1] += text;
}

void MDFNConsole::ShowPrompt(bool shown)
{
 prompt_visible = shown;
}
