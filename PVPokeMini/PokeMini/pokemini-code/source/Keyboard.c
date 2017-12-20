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
#include "CommandLine.h"

#include "Keyboard.h"

// Keyboard re-mapping
TKeyboardRemap *KeyboardHostRemap = NULL;

// Keyboard mapping with host keysym
int KeyboardMapHostKeysym_A[10];
int KeyboardMapHostKeysym_B[10];

// Temp keyboard map
static int TMP_keyb_a[10];
static int TMP_keyb_b[10];
static int KeyLastKey = -1;

// Keyboard character names
const char *KeyboardMapStr[PMKEYB_EOL] = {
	"NONE", "ESCAPE", "RETURN",
	"BACKSPACE", "TAB", "BACKQUOTE",

	"RSHIFT", "LSHIFT",
	"RCTRL", "LCTRL",
	"RALT", "LALT",

	"INSERT", "DELETE",
	"HOME", "END",
	"PAGEUP", "PAGEDOWN",

	"NUMLOCK", "CAPSLOCK", "SCROLLLOCK",
	"KP_PERIOD", "KP_DIVIDE",
	"KP_MULTIPLY", "KP_MINUS",
	"KP_PLUS", "KP_ENTER",
	"KP_EQUALS",

	"UP", "DOWN", "RIGHT", "LEFT",

	"SPACE", "EXCLAIM", "QUOTEDBL", "HASH",
	"DOLLAR", "PERCENT", "AMPERSAND", "QUOTE",
	"LEFTPAREN", "RIGHTPAREN", "ASTERISK", "PLUS",
	"COMMA", "MINUS", "PERIOD", "SLASH",

	"0", "1", "2", "3", "4",
	"5", "6", "7", "8", "9",

	"COLON", "SEMICOLON", "LESS",
	"EQUALS", "GREATER", "QUESTION", "AT",

	"A", "B", "C", "D", "E", "F",
	"G", "H", "I", "J", "K", "L",
	"M", "N", "O", "P", "Q", "R",
	"S", "T", "U", "V", "W", "X",
	"Y", "Z",

	"LEFTBRACK", "BACKSLASH",
	"RIGHTBRACK", "CARET",
	"UNDERSCORE",

	"KP_0", "KP_1", "KP_2", "KP_3", "KP_4",
	"KP_5", "KP_6", "KP_7", "KP_8", "KP_9"
};

static const char *GetKeyboardMapStr(int index)
{
	if ((index < 0) || (index >= PMKEYB_EOL)) index = 0;
	return KeyboardMapStr[index];
}

void KeyboardRemap(TKeyboardRemap *keymap)
{
	int i, k;
	if (keymap) KeyboardHostRemap = keymap;
	if (!KeyboardHostRemap) return;
	for (i=0; i<10; i++) {
		k = CommandLine.keyb_a[i];
		if ((k < 0) || (k >= PMKEYB_EOL)) k = 0;
		KeyboardMapHostKeysym_A[i] = (*KeyboardHostRemap)[k];
		k = CommandLine.keyb_b[i];
		if ((k < 0) || (k >= PMKEYB_EOL)) k = 0;
		KeyboardMapHostKeysym_B[i] = (*KeyboardHostRemap)[k];
	}
}

// Joystick menu
int UIItems_KeyboardC(int index, int reason);
TUIMenu_Item UIItems_Keyboard[] = {
	{ 0,  0, "Go back...", UIItems_KeyboardC },
	{ 0,  1, "Apply changes...", UIItems_KeyboardC },
	{ 0, 40, "Check inputs...", UIItems_KeyboardC },
	{ 0,  4, "Menu Key: %s", UIItems_KeyboardC },
	{ 0,  5, "A Key: %s", UIItems_KeyboardC },
	{ 0,  6, "B Key: %s", UIItems_KeyboardC },
	{ 0,  7, "C Key: %s", UIItems_KeyboardC },
	{ 0,  8, "Up Key: %s", UIItems_KeyboardC },
	{ 0,  9, "Down Key: %s", UIItems_KeyboardC },
	{ 0, 10, "Left Key: %s", UIItems_KeyboardC },
	{ 0, 11, "Right Key: %s", UIItems_KeyboardC },
	{ 0, 12, "Power Key: %s", UIItems_KeyboardC },
	{ 0, 13, "Shake Key: %s", UIItems_KeyboardC },
	{ 0, 24, "Menu Alt: %s", UIItems_KeyboardC },
	{ 0, 25, "A Alt: %s", UIItems_KeyboardC },
	{ 0, 26, "B Alt: %s", UIItems_KeyboardC },
	{ 0, 27, "C Alt: %s", UIItems_KeyboardC },
	{ 0, 28, "Up Alt: %s", UIItems_KeyboardC },
	{ 0, 29, "Down Alt: %s", UIItems_KeyboardC },
	{ 0, 30, "Left Alt: %s", UIItems_KeyboardC },
	{ 0, 31, "Right Alt: %s", UIItems_KeyboardC },
	{ 0, 32, "Power Alt: %s", UIItems_KeyboardC },
	{ 0, 33, "Shake Alt: %s", UIItems_KeyboardC },
	{ 9,  0, "Keyboard", UIItems_KeyboardC }
};

int KeyboardTestButtons(int line, char *outtext)
{
	int i, key = 0;
	if (line == 0) {
		if (KeyLastKey == -1) sprintf(outtext, "Last key: None");
		else {
			for (i=0; i<PMKEYB_EOL; i++) {
				if (KeyLastKey == (*KeyboardHostRemap)[i]) {
					key = i;
					break;
				}
			}
			sprintf(outtext, "Last key: %s", GetKeyboardMapStr(key));
		}
	}
	return line < 1;
}

int UIItems_KeyboardC(int index, int reason)
{
	int i;
	if (reason == UIMENU_OK) {
		reason = UIMENU_RIGHT;
	}
	if (reason == UIMENU_CANCEL) {
		UIMenu_PrevMenu();
		return 1;
	}
	if (reason == UIMENU_LEFT) {
		switch (index) {
			case 4: case 5: case 6: case 7:
			case 8: case 9: case 10: case 11:
			case 12: case 13:
				TMP_keyb_a[index-4]--;
				if (TMP_keyb_a[index-4] < 0) TMP_keyb_a[index-4] = PMKEYB_EOL-1;
				break;
			case 24: case 25: case 26: case 27:
			case 28: case 29: case 30: case 31:
			case 32: case 33:
				TMP_keyb_b[index-24]--;
				if (TMP_keyb_b[index-24] < 0) TMP_keyb_b[index-24] = PMKEYB_EOL-1;
				break;
		}
	}
	if (reason == UIMENU_RIGHT) {
		switch (index) {
			case 0: UIMenu_PrevMenu();
				break;
			case 1: for (i=0; i<10; i++) {
					CommandLine.keyb_a[i] = TMP_keyb_a[i];
					CommandLine.keyb_b[i] = TMP_keyb_b[i];
				}
				KeyboardRemap(NULL);
				UIMenu_BeginMessage();
				UIMenu_SetMessage("Keyboard definition..", 1);
				UIMenu_SetMessage("", 1);
				UIMenu_SetMessage("Changes applied!", 0);
				UIMenu_EndMessage(60);
				break;
			case 4: case 5: case 6: case 7:
			case 8: case 9: case 10: case 11:
			case 12: case 13:
				TMP_keyb_a[index-4]++;
				if (TMP_keyb_a[index-4] >= PMKEYB_EOL) TMP_keyb_a[index-4] = 0;
				break;
			case 24: case 25: case 26: case 27:
			case 28: case 29: case 30: case 31:
			case 32: case 33:
				TMP_keyb_b[index-24]++;
				if (TMP_keyb_b[index-24] >= PMKEYB_EOL) TMP_keyb_b[index-24] = 0;
				break;
			case 40:
				KeyLastKey = -1;
				UIMenu_RealTimeMessage(KeyboardTestButtons);
				break;
		}
	}
	UIMenu_ChangeItem(UIItems_Keyboard, 4, "Menu Key: %s", GetKeyboardMapStr(TMP_keyb_a[0]));
	UIMenu_ChangeItem(UIItems_Keyboard, 5, "A Key: %s", GetKeyboardMapStr(TMP_keyb_a[1]));
	UIMenu_ChangeItem(UIItems_Keyboard, 6, "B Key: %s", GetKeyboardMapStr(TMP_keyb_a[2]));
	UIMenu_ChangeItem(UIItems_Keyboard, 7, "C Key: %s", GetKeyboardMapStr(TMP_keyb_a[3]));
	UIMenu_ChangeItem(UIItems_Keyboard, 8, "Up Key: %s", GetKeyboardMapStr(TMP_keyb_a[4]));
	UIMenu_ChangeItem(UIItems_Keyboard, 9, "Down Key: %s", GetKeyboardMapStr(TMP_keyb_a[5]));
	UIMenu_ChangeItem(UIItems_Keyboard, 10, "Left Key: %s", GetKeyboardMapStr(TMP_keyb_a[6]));
	UIMenu_ChangeItem(UIItems_Keyboard, 11, "Right Key: %s", GetKeyboardMapStr(TMP_keyb_a[7]));
	UIMenu_ChangeItem(UIItems_Keyboard, 12, "Power Key: %s", GetKeyboardMapStr(TMP_keyb_a[8]));
	UIMenu_ChangeItem(UIItems_Keyboard, 13, "Shake Key: %s", GetKeyboardMapStr(TMP_keyb_a[9]));
	UIMenu_ChangeItem(UIItems_Keyboard, 24, "Menu Alt: %s", GetKeyboardMapStr(TMP_keyb_b[0]));
	UIMenu_ChangeItem(UIItems_Keyboard, 25, "A Alt: %s", GetKeyboardMapStr(TMP_keyb_b[1]));
	UIMenu_ChangeItem(UIItems_Keyboard, 26, "B Alt: %s", GetKeyboardMapStr(TMP_keyb_b[2]));
	UIMenu_ChangeItem(UIItems_Keyboard, 27, "C Alt: %s", GetKeyboardMapStr(TMP_keyb_b[3]));
	UIMenu_ChangeItem(UIItems_Keyboard, 28, "Up Alt: %s", GetKeyboardMapStr(TMP_keyb_b[4]));
	UIMenu_ChangeItem(UIItems_Keyboard, 29, "Down Alt: %s", GetKeyboardMapStr(TMP_keyb_b[5]));
	UIMenu_ChangeItem(UIItems_Keyboard, 30, "Left Alt: %s", GetKeyboardMapStr(TMP_keyb_b[6]));
	UIMenu_ChangeItem(UIItems_Keyboard, 31, "Right Alt: %s", GetKeyboardMapStr(TMP_keyb_b[7]));
	UIMenu_ChangeItem(UIItems_Keyboard, 32, "Power Alt: %s", GetKeyboardMapStr(TMP_keyb_b[8]));
	UIMenu_ChangeItem(UIItems_Keyboard, 33, "Shake Alt: %s", GetKeyboardMapStr(TMP_keyb_b[9]));
	return 1;
}

// Enter into the keyboard menu
void KeyboardEnterMenu(void)
{
	int i;
	for (i=0; i<10; i++) {
		TMP_keyb_a[i] = CommandLine.keyb_a[i];
		TMP_keyb_b[i] = CommandLine.keyb_b[i];
	}
	UIMenu_LoadItems(UIItems_Keyboard, 0);
}

// Process keyboard press event
int KeyboardPressEvent(int keysym)
{
	int index, took = 0;

	KeyLastKey = keysym;

	for (index=0; index<10; index++) {
		if (KeyboardMapHostKeysym_A[index] == keysym) {
			took = 1;
			if (index) {
				UIMenu_KeyEvent(index, 1);
			} else {
				UI_Status = !UI_Status;
			}
		} else if (KeyboardMapHostKeysym_B[index] == keysym) {
			took = 1;
			if (index) {
				UIMenu_KeyEvent(index, 1);
			} else {
				UI_Status = !UI_Status;
			}
		}
	}
	return took;
}

// Process keyboard release event
int KeyboardReleaseEvent(int keysym)
{
	int index, took = 0;
	for (index=1; index<10; index++) {
		if (KeyboardMapHostKeysym_A[index] == keysym) {
			took = 1;
			UIMenu_KeyEvent(index, 0);
		} else if (KeyboardMapHostKeysym_B[index] == keysym) {
			took = 1;
			UIMenu_KeyEvent(index, 0);
		}
	}
	return took;
}
