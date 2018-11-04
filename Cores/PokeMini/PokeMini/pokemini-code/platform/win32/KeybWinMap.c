/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

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

#include <windows.h>
#include "Keyboard.h"

TKeyboardRemap KeybWinRemap = {
	0,
	VK_ESCAPE,
	VK_RETURN,
	VK_BACK,
	VK_TAB,
	VK_OEM_3,

	VK_SHIFT,
	VK_LSHIFT,
	VK_CONTROL,
	VK_LCONTROL,
	VK_MENU,
	VK_LMENU,

	VK_INSERT,
	VK_DELETE,
	VK_HOME,
	VK_END,
	VK_PRIOR,
	VK_NEXT,

	VK_NUMLOCK,
	VK_CAPITAL,
	VK_SCROLL,
	VK_DECIMAL,
	VK_DIVIDE,
	VK_MULTIPLY,
	VK_SUBTRACT,
	VK_ADD,
	VK_SEPARATOR,
	VK_OEM_NEC_EQUAL,

	VK_UP,
	VK_DOWN,
	VK_RIGHT,
	VK_LEFT,

	VK_SPACE,
	0x100,	//	EXCLAIM
	0x101,	//	QUOTEDBL
	0x102,	//	HASH
	0x103,	//	DOLLAR
	0x104,	//	UNKNOWN
	0x105,	//	AMPERSAND
	0x106,	//	QUOTE
	0x107,	//	LEFTPAREN
	0x108,	//	RIGHTPAREN
	0x109,	//	ASTERISK
	0x10A,	//	PLUS
	0x10B,	//	COMMA
	0x10C,	//	MINUS
	0x10D,	//	PERIOD
	0x10E,	//	SLASH

	'0',
	'1',
	'2',
	'3',
	'4',
	'5',
	'6',
	'7',
	'8',
	'9',

	0x110,	//	COLON
	0x111,	//	SEMICOLON
	0x112,	//	LESS
	0x113,	//	EQUALS
	0x114,	//	GREATER
	0x115,	//	QUESTION
	0x116,	//	AT

	'A',
	'B',
	'C',
	'D',
	'E',
	'F',
	'G',
	'H',
	'I',
	'J',
	'K',
	'L',
	'M',
	'N',
	'O',
	'P',
	'Q',
	'R',
	'S',
	'T',
	'U',
	'V',
	'W',
	'X',
	'Y',
	'Z',

	0x120,	//	LEFTBRACKET
	0x121,	//	BACKSLASH
	0x122,	//	RIGHTBRACKET
	0x123,	//	CARET
	0x124,	//	UNDERSCORE

	VK_NUMPAD0,
	VK_NUMPAD1,
	VK_NUMPAD2,
	VK_NUMPAD3,
	VK_NUMPAD4,
	VK_NUMPAD5,
	VK_NUMPAD6,
	VK_NUMPAD7,
	VK_NUMPAD8,
	VK_NUMPAD9
};
