/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* prompt.cpp:
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
#include <trio/trio.h>
#include "prompt.h"
#include <mednafen/string/string.h>

//static const uint32 font = MDFN_FONT_9x18_18x18;
static const uint32 font = MDFN_FONT_6x13_12x13;

HappyPrompt::HappyPrompt(void)
{

}

HappyPrompt::HappyPrompt(const std::string& ptext, const std::string& zestring)
{
 SetText(ptext);
 te.InsertKBB(zestring);
}

HappyPrompt::~HappyPrompt()
{

}

void HappyPrompt::TheEnd(const std::string &pstring)
{


}

void HappyPrompt::SetText(const std::string &ptext)
{
 PromptText = ptext;
}

void HappyPrompt::InsertKBB(const std::string& zestring)
{
 te.InsertKBB(zestring);
}

void HappyPrompt::Draw(MDFN_Surface *surface, const MDFN_Rect *rect)
{
 const uint8 font_nomwidth = GetGlyphWidth(' ', font);
 const uint8 font_height = GetFontHeight(font);
 const uint32 bgcolor = surface->MakeColor(0x00, 0x00, 0x00, 0xFF);
 const uint32 box_border_color = surface->MakeColor(0x00, 0x00, 0x00, 0xFF);
 const uint32 box_color = surface->MakeColor(0xFF, 0xFF, 0xFF, 0xFF);
 const uint32 title_color = surface->MakeColor(0xFF, 0x00, 0xFF, 0xFF);
 const uint32 entry_color = surface->MakeColor(0x00, 0xFF, 0x00, 0xFF);

 const int32 tw = 38;
 const int32 box_w = 4 + tw * font_nomwidth;
 const int32 box_h = 4 + 13 * font_height / 4;
 const int32 box_x = (rect->w - box_w) / 2;
 const int32 box_y = (rect->h - box_h) / 2;

 MDFN_DrawFillRect(surface, box_x, box_y, box_w, box_h, box_border_color, RectStyle::Rounded);
 MDFN_DrawFillRect(surface, box_x + 2, box_y + 2, box_w - 4, box_h - 4, box_color, bgcolor, RectStyle::Rounded);

 const MDFN_Rect kb_crect = { box_x + 2 + 1 * font_nomwidth, box_y + font_height * 7 / 4 + 2, (tw - 2) * font_nomwidth, font_height };

 DrawText(surface, box_x + 2 + 1 * font_nomwidth, box_y + font_height / 2 + 2, PromptText, title_color, font);
 te.Draw(surface, kb_crect, nullptr, entry_color, bgcolor, font);
}

void HappyPrompt::Event(const SDL_Event *event)
{
 if(te.Event(event))
 {
  TheEnd(UTF32_to_UTF8(te.GetKBB()));
  te.ClearKBB();
 }
}
