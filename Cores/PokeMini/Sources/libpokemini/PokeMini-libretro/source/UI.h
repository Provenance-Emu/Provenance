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

#ifndef POKEMINI_INUI
#define POKEMINI_INUI

#include <stdint.h>

#define UI_STATUS_MENU	1
#define UI_STATUS_GAME	0
#define UI_STATUS_EXIT	-1

// File list cache
typedef struct {
	char name[PMTMPV]; // Filename					| Message
	char stats;	// 0 = Invalid, 1 = Directory, 2 = File		| Unused
	char color;	// 0 = Normal, 1 = Color available, 2 = Package	| 0 = Yellow, 1 = Aqua
} TUIMenu_FileListCache;

// Maximum files/directories per directory
#ifndef UI_MAXCACHE
#define UI_MAXCACHE	512
#endif

// Menu callback reason
enum {
	UIMENU_LOAD,	// Menu was loaded (called from UIMenu_LoadItems)
	UIMENU_CANCEL,	// User pressed B
	UIMENU_OK,	// User pressed A
	UIMENU_LEFT,	// User pressed Left
	UIMENU_RIGHT	// User pressed Right
};

// Menu callback type
typedef int (*TUIMenu_Callback)(int index, int reason);

// Menu item
typedef struct TUIMenu_Item {
	int code;			// Code: 0 = Yellow, 1 = Aqua, 9 = End-of-list
	int index;			// Index of item
	char caption[32];		// Text to display, last entry will be the title
	TUIMenu_Callback callback;	// Callback, last entry will receive UIMENU_LOAD
	struct TUIMenu_Item *prev;	// Must be NULL
} TUIMenu_Item;

// External font and icons palette
extern uint32_t *UI_Font1_Pal32;
extern uint16_t *UI_Font1_Pal16;
extern uint32_t *UI_Font2_Pal32;
extern uint16_t *UI_Font2_Pal16;
extern uint32_t *UI_Icons_Pal32;
extern uint16_t *UI_Icons_Pal16;

// UI Items
extern TUIMenu_Item UIItems_MainMenu[];			// Main Menu items list
extern TUIMenu_Item UIItems_Options[];			// Options items list
int UIItems_PlatformDefC(int index, int reason);	// Platform default callback
extern TUIMenu_Item UIItems_Platform[];			// Platform items list (USER DEFINED)

#define PLATFORMDEF_GOBACK	{ 0,  0, "Go back...", UIItems_PlatformDefC }
#define PLATFORMDEF_SAVEOPTIONS	{ 0, 99, "Save Configs...", UIItems_PlatformDefC }
#define PLATFORMDEF_END(cb)	{ 9,  0, "Platform", cb }

// UI return status
//  1 = In Menu
//  0 = Game
// -1 = Exit
extern int UI_Status;

// UI PM screen preview distance from top-right, 0 to disable
extern int UI_PreviewDist;

// Load items list
void UIMenu_LoadItems(TUIMenu_Item *items, int cursorindex);

// Return to previous menu
void UIMenu_PrevMenu(void);

// Change item on current menu
int UIMenu_ChangeItem(TUIMenu_Item *items, int index, const char *format, ...);

// Message output
void UIMenu_BeginMessage(void);
void UIMenu_SetMessage(char *message, int color);
void UIMenu_EndMessage(int timeout);

// Real-time text output
typedef int (*TUIRealtimeCB)(int line, char *outtext);
void UIMenu_RealTimeMessage(TUIRealtimeCB cb);

// Resize display
int UIMenu_SetDisplay(int width, int height, int pixellayout, uint8_t *bg_image, uint16_t *bg_pal16, uint32_t *bg_pal32);

// Initialize
int UIMenu_Init(void);

// Destroy
void UIMenu_Destroy(void);

// Handle key events
void UIMenu_KeyEvent(int key, int press);

// Display Character
void UIDraw_Char_32(uint32_t *screen, int pitchW, int x, int y, uint8_t ch, const uint32_t *palette);
void UIDraw_Char_16(uint16_t *screen, int pitchW, int x, int y, uint8_t ch, const uint16_t *palette);

// Display String
void UIDraw_String_32(uint32_t *screen, int pitchW, int x, int y, int padd, char *str, const uint32_t *palette);
void UIDraw_String_16(uint16_t *screen, int pitchW, int x, int y, int padd, char *str, const uint16_t *palette);

// Display Icons
void UIDraw_Icon_32(uint32_t *screen, int pitchW, int x, int y, uint8_t ch);
void UIDraw_Icon_16(uint16_t *screen, int pitchW, int x, int y, uint8_t ch);

// Process UI
int UIMenu_Process(void);

// Display UI
void UIMenu_Display_32(uint32_t *screen, int pitchW);
void UIMenu_Display_16(uint16_t *screen, int pitchW);

// Display Saving EEPROM
void UIMenu_SaveEEPDisplay_32(uint32_t *screen, int pitchW);
void UIMenu_SaveEEPDisplay_16(uint16_t *screen, int pitchW);

#endif
