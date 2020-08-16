/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "PokeMini.h"
#include "UI.h"

int UI_Enabled = 0;
int UI_Status = UI_STATUS_GAME;

void UIMenu_PrevMenu(void) {}
void UIMenu_LoadItems(TUIMenu_Item *items, int cursorindex) {}
int UIMenu_ChangeItem(TUIMenu_Item *items, int index, const char *format, ...)
{
	return 0;
}
void UIMenu_BeginMessage(void) {}
void UIMenu_SetMessage(char *message, int color) {}
void UIMenu_EndMessage(int timeout) {}
void UIMenu_RealTimeMessage(TUIRealtimeCB cb) {}

void UIMenu_KeyEvent(int key, int press) {
	if (press) {
		PokeMini_KeypadEvent(key, 1);
	} else {
		PokeMini_KeypadEvent(key, 0);
	}
}

int UIItems_PlatformDefC(int index, int reason)
{
	return 1;
}
