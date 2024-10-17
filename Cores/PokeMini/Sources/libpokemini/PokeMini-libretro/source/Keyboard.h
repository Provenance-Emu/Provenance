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

#ifndef POKEMINI_KEYBOARD
#define POKEMINI_KEYBOARD

#include "UI.h"

enum {
	PMKEYB_NONE		= 0,
	PMKEYB_ESCAPE		= 1,
	PMKEYB_RETURN		= 2,
	PMKEYB_BACKSPACE	= 3,
	PMKEYB_TAB		= 4,
	PMKEYB_BACKQUOTE	= 5,

	PMKEYB_RSHIFT		= 6,
	PMKEYB_LSHIFT		= 7,
	PMKEYB_RCTRL		= 8,
	PMKEYB_LCTRL		= 9,
	PMKEYB_RALT		= 10,
	PMKEYB_LALT		= 11,

	PMKEYB_INSERT		= 12,
	PMKEYB_DELETE		= 13,
	PMKEYB_HOME		= 14,
	PMKEYB_END		= 15,
	PMKEYB_PAGEUP		= 16,
	PMKEYB_PAGEDOWN		= 17,

	PMKEYB_NUMLOCK		= 18,
	PMKEYB_CAPSLOCK		= 19,
	PMKEYB_SCROLLLOCK	= 20,
	PMKEYB_KP_PERIOD	= 21,
	PMKEYB_KP_DIVIDE	= 22,
	PMKEYB_KP_MULTIPLY	= 23,
	PMKEYB_KP_MINUS		= 24,
	PMKEYB_KP_PLUS		= 25,
	PMKEYB_KP_ENTER		= 26,
	PMKEYB_KP_EQUALS	= 27,

	PMKEYB_UP		= 28,
	PMKEYB_DOWN		= 29,
	PMKEYB_RIGHT		= 30,
	PMKEYB_LEFT		= 31,

	PMKEYB_SPACE		= 32,
	PMKEYB_EXCLAIM		= 33,
	PMKEYB_QUOTEDBL		= 34,
	PMKEYB_HASH		= 35,
	PMKEYB_DOLLAR		= 36,
	PMKEYB_PERCENT		= 37,
	PMKEYB_AMPERSAND	= 38,
	PMKEYB_QUOTE		= 39,
	PMKEYB_LEFTPAREN	= 40,
	PMKEYB_RIGHTPAREN	= 41,
	PMKEYB_ASTERISK		= 42,
	PMKEYB_PLUS		= 43,
	PMKEYB_COMMA		= 44,
	PMKEYB_MINUS		= 45,
	PMKEYB_PERIOD		= 46,
	PMKEYB_SLASH		= 47,

	PMKEYB_0		= 48,
	PMKEYB_1		= 49,
	PMKEYB_2		= 50,
	PMKEYB_3		= 51,
	PMKEYB_4		= 52,
	PMKEYB_5		= 53,
	PMKEYB_6		= 54,
	PMKEYB_7		= 55,
	PMKEYB_8		= 56,
	PMKEYB_9		= 57,

	PMKEYB_COLON		= 58,
	PMKEYB_SEMICOLON	= 59,
	PMKEYB_LESS		= 60,
	PMKEYB_EQUALS		= 61,
	PMKEYB_GREATER		= 62,
	PMKEYB_QUESTION		= 63,
	PMKEYB_AT		= 64,

	PMKEYB_A		= 65,
	PMKEYB_B		= 66,
	PMKEYB_C		= 67,
	PMKEYB_D		= 68,
	PMKEYB_E		= 69,
	PMKEYB_F		= 70,
	PMKEYB_G		= 71,
	PMKEYB_H		= 72,
	PMKEYB_I		= 73,
	PMKEYB_J		= 74,
	PMKEYB_K		= 75,
	PMKEYB_L		= 76,
	PMKEYB_M		= 77,
	PMKEYB_N		= 78,
	PMKEYB_O		= 79,
	PMKEYB_P		= 80,
	PMKEYB_Q		= 81,
	PMKEYB_R		= 82,
	PMKEYB_S		= 83,
	PMKEYB_T		= 84,
	PMKEYB_U		= 85,
	PMKEYB_V		= 86,
	PMKEYB_W		= 87,
	PMKEYB_X		= 88,
	PMKEYB_Y		= 89,
	PMKEYB_Z		= 90,

	PMKEYB_LEFTBRACK	= 91,
	PMKEYB_BACKSLASH	= 92,
	PMKEYB_RIGHTBRACK	= 93,
	PMKEYB_CARET		= 94,
	PMKEYB_UNDERSCORE	= 95,

	PMKEYB_KP_0		= 96,
	PMKEYB_KP_1		= 97,
	PMKEYB_KP_2		= 98,
	PMKEYB_KP_3		= 99,
	PMKEYB_KP_4		= 100,
	PMKEYB_KP_5		= 101,
	PMKEYB_KP_6		= 102,
	PMKEYB_KP_7		= 103,
	PMKEYB_KP_8		= 104,
	PMKEYB_KP_9		= 105,

	PMKEYB_EOL		= 106,
};

// Keyboard map string
extern const char *KeyboardMapStr[PMKEYB_EOL];

// Keyboard remapper
typedef int TKeyboardRemap[PMKEYB_EOL];
void KeyboardRemap(TKeyboardRemap *keymap);

// Keyboard menu items
extern TUIMenu_Item UIItems_Keyboard[];

// Enter into the keyboard menu
void KeyboardEnterMenu(void);

// Process keyboard press
int KeyboardPressEvent(int keysym);

// Process keyboard press
int KeyboardReleaseEvent(int keysym);

#endif
