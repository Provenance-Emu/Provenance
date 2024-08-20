/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "main.h"

static bool IsActive;

void Help_Draw(MDFN_Surface* surface, const MDFN_Rect& rect)
{
 if(!IsActive) return;

 const uint32 bgcolor = surface->MakeColor(0, 0, 0, 0xFF);

 MDFN_DrawFillRect(surface, rect.x, rect.y, rect.w, rect.h, bgcolor);

 static const char *HelpStrings[][2] = {
	{ "F1", gettext_noop("Toggle Help") },
	{ "-", NULL },
	{ "F2", gettext_noop("Configure Command Key") },
	{ "SHIFT + F2", gettext_noop("Configure Command Key, for logical AND mode") },
	{ "ALT + SHIFT + [n]", gettext_noop("Configure buttons on port n(1-8)") },
	{ "CTRL + SHIFT + [n]", gettext_noop("Select device on port n") },
	{ "CTRL + SHIFT + MENU", gettext_noop("Toggle input grabbing") },
	{ "-", NULL },
	{ "ALT + O", gettext_noop("Rotate Screen") },
	{ "ALT + ENTER", gettext_noop("Toggle Fullscreen Mode") },
	{ "F9", gettext_noop("Take Screen Snapshot") },
        { "SHIFT + F9", gettext_noop("Take Scaled(and filtered) Screen Snapshot") },
	{ "-", NULL },
	{ "ALT + S", gettext_noop("Enable state rewinding") },
	{ "BACKSPACE", gettext_noop("Rewind") },
	{ "F5", gettext_noop("Save State") },
	{ "F7", gettext_noop("Load State") },
        { "F6", gettext_noop("Select Disk") },
	{ "F8", gettext_noop("Insert coin; Insert/Eject disk") },
	{ "-", NULL },
	{ "F10", gettext_noop("(Soft) Reset, if available on emulated system.") },
	{ "F11", gettext_noop("Power Toggle/Hard Reset") },
	{ "F12", gettext_noop("Exit") },
 };

 unsigned y = rect.y;

 DrawText(surface, rect, 0, y,  _("Default key assignments:"), surface->MakeColor(0x00,0xFF,0x00,0xFF), MDFN_FONT_9x18_18x18);
 DrawText(surface, rect, rect.w - (strlen(MEDNAFEN_VERSION) * 6), y, MEDNAFEN_VERSION, surface->MakeColor(0xD0, 0x28, 0x00, 0xFF), MDFN_FONT_6x9);
 y += 18;

 for(unsigned int i = 0; i < sizeof(HelpStrings) / sizeof(HelpStrings[0]); i++)
 {
  unsigned x = rect.x;
  if(HelpStrings[i][0][0] == '-')
  {
   y -= 4;
   DrawText(surface, rect, 0, y,  " -------------------------------------------------------", surface->MakeColor(0x60,0x60,0x60,0xFF), MDFN_FONT_9x18_18x18);
   y += 14;
  }
  else
  {
   x += 9;

   x += DrawText(surface, rect, x, y, HelpStrings[i][0], surface->MakeColor(0x40,0xDF,0x40,0xFF), MDFN_FONT_9x18_18x18);
   x += DrawText(surface, rect, x, y, " - ", surface->MakeColor(0x40,0x40,0x40,0xFF), MDFN_FONT_9x18_18x18);
   x += DrawText(surface, rect, x, y, _(HelpStrings[i][1]), surface->MakeColor(0xC0,0xC0,0xC0,0xFF), MDFN_FONT_9x18_18x18);

   y += 18;
  }
 }
}

bool Help_IsActive(void)
{
 return IsActive;
}

bool Help_Toggle(void)
{
 IsActive = !IsActive;
 return IsActive;
}

void Help_Init(void)
{
 IsActive = false;
}

void Help_Close(void)
{

}
