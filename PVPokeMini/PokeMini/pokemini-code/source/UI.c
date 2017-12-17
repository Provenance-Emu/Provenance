/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2014  JustBurn

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

#include <sys/types.h>
#include <ctype.h>

#ifndef NO_SCANDIRS
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>
#endif

#include "PokeMini.h"
#include "Video.h"
#include "UI.h"
#include "CommandLine.h"
#include "PokeMini_Font12.h"
#include "PokeMini_Icons12.h"

int UI_FirstLoad = 1;
int UI_Enabled = 0;
int UI_Status = UI_STATUS_GAME;
int UI_PreviewDist = 12;
uint32_t *UI_Font1_Pal32 = NULL;
uint16_t *UI_Font1_Pal16 = NULL;
uint32_t *UI_Font2_Pal32 = NULL;
uint16_t *UI_Font2_Pal16 = NULL;
uint32_t *UI_Icons_Pal32 = NULL;
uint16_t *UI_Icons_Pal16 = NULL;

#define UIMenu_FilesLines	(UIMenu_Lines-1)

void UIDraw_BG_32(uint32_t *screen, int pitchW, const uint8_t *image, const uint32_t *palette, int width, int height)
{
	int x, y;
	for (y=0; y<height; y++) {
		for (x=0; x<width; x+=2) {
			screen[x] = palette[*image >> 4];
			screen[x+1] = palette[*image++ & 15];
		}
		screen += pitchW;
	}
}

void UIDraw_BG_16(uint16_t *screen, int pitchW, const uint8_t *image, const uint16_t *palette, int width, int height)
{
	int x, y;
	for (y=0; y<height; y++) {
		for (x=0; x<width; x+=2) {
			screen[x] = palette[*image >> 4];
			screen[x+1] = palette[*image++ & 15];
		}
		screen += pitchW;
	}
}

void UIDraw_Char_32(uint32_t *screen, int pitchW, int x, int y, uint8_t ch, const uint32_t *palette)
{
	int xc, yc;
	uint8_t *chr;
	ch -= 0x20;
	if (ch >= 0x80) return;
	chr = (uint8_t *)&PokeMini_Font12[(ch >> 4) * 96*12 + (ch & 15) * 6];
	screen += (y * pitchW) + x;
	for (yc=0; yc<12; yc++) {
		for (xc=0; xc<12; xc+=2) {
			if (*chr >> 4) screen[xc] = palette[*chr >> 4];
			if (*chr & 15) screen[xc+1] = palette[*chr & 15];
			chr++;
		}
		chr += 96-6;
		screen += pitchW;
	}
}

void UIDraw_Char_16(uint16_t *screen, int pitchW, int x, int y, uint8_t ch, const uint16_t *palette)
{
	int xc, yc;
	uint8_t *chr;
	ch -= 0x20;
	if (ch >= 0x80) return;
	chr = (uint8_t *)&PokeMini_Font12[(ch >> 4) * 96*12 + (ch & 15) * 6];
	screen += (y * pitchW) + x;
	for (yc=0; yc<12; yc++) {
		for (xc=0; xc<12; xc+=2) {
			if (*chr >> 4) screen[xc] = palette[*chr >> 4];
			if (*chr & 15) screen[xc+1] = palette[*chr & 15];
			chr++;
		}
		chr += 96-6;
		screen += pitchW;
	}
}

void UIDraw_String_32(uint32_t *screen, int pitchW, int x, int y, int padd, char *str, const uint32_t *palette)
{
	int len = strlen(str);
	for (;len;len--) {
		UIDraw_Char_32(screen, pitchW, x, y, *str++, palette);
		x += padd;
	}
}

void UIDraw_String_16(uint16_t *screen, int pitchW, int x, int y, int padd, char *str, const uint16_t *palette)
{
	int len = strlen(str);
	for (;len;len--) {
		UIDraw_Char_16(screen, pitchW, x, y, *str++, palette);
		x += padd;
	}
}

void UIDraw_Icon_32(uint32_t *screen, int pitchW, int x, int y, uint8_t ch)
{
	int xc, yc;
	uint8_t *chr;
	if (ch >= 0x10) return;
	chr = (uint8_t *)&PokeMini_Icons12[(ch >> 4) * 96*12 + (ch & 15) * 6];
	screen += (y * pitchW) + x;
	for (yc=0; yc<12; yc++) {
		for (xc=0; xc<12; xc+=2) {
			if (*chr >> 4) screen[xc] = UI_Icons_Pal32[*chr >> 4];
			if (*chr & 15) screen[xc+1] = UI_Icons_Pal32[*chr & 15];
			chr++;
		}
		chr += 96-6;
		screen += pitchW;
	}
}

void UIDraw_Icon_16(uint16_t *screen, int pitchW, int x, int y, uint8_t ch)
{
	int xc, yc;
	uint8_t *chr;
	if (ch >= 0x10) return;
	chr = (uint8_t *)&PokeMini_Icons12[(ch >> 4) * 96*12 + (ch & 15) * 6];
	screen += (y * pitchW) + x;
	for (yc=0; yc<12; yc++) {
		for (xc=0; xc<12; xc+=2) {
			if (*chr >> 4) screen[xc] = UI_Icons_Pal16[*chr >> 4];
			if (*chr & 15) screen[xc+1] = UI_Icons_Pal16[*chr & 15];
			chr++;
		}
		chr += 96-6;
		screen += pitchW;
	}
}

void UIText_Scroll(char *txtout, char *txtin, int maxchars, int anim)
{
	int outsidechars = strlen(txtin) - maxchars;
	if (outsidechars <= 0) {
		// Fit
		strcpy(txtout, txtin);
	} else {
		// Doesn't fit, scroll it
		anim %= outsidechars + 16;
		if (anim < 8) anim = 8;
		if (anim > (outsidechars+8)) anim = outsidechars+8;
		strncpy(txtout, txtin + anim - 8, maxchars);
		txtout[maxchars] = 0;
	}
}

int UIMenu_Width = 0;	// Menu width
int UIMenu_Height = 0;	// Menu height
int UIMenu_PixelLayout = 0;	// Menu pixel layout
int UIMenu_Lines = 0;	// Menu visible lines

uint8_t *UIMenu_BGImage = NULL;
uint32_t *UIMenu_BGPal32 = NULL;
uint16_t *UIMenu_BGPal16 = NULL;

int UIMenu_Page = 0;	// Mode
int UIMenu_MMax = 0;	// Menu max lines
int UIMenu_MOff = 0;	// Menu offset
int UIMenu_Cur = 0;	// Cursor offset
int UIMenu_Ani = 0;	// For animation effect
int UIMenu_InKey = 0;	// Key input
int UIMenu_CKeyMod  = 0;	// C Key modifier
int UIMenu_HardReset = 0;	// Hard reset
int UIMenu_Savestate = 0;	// Savestate offset

int UIMenu_CurrentItemsNum = 0;			// Number of current items
TUIMenu_Item *UIMenu_CurrentItems = NULL;	// Current items list
TUIMenu_FileListCache *UIMenu_FileListCache = NULL;	// Files list cache
int UIMenu_ListOffs = 0;	// Offset on list cache
int UIMenu_ListFiles = 0;	// Number of files in files list cache

#define UIMenu_MsgCountReset1	200
#define UIMenu_MsgCountReset2	80
int UIMenu_MsgOffset = 0;	// Message line offset (if lines exceed the screen)
int UIMenu_MsgCountDw = 0;	// Message count down (to move the offset)
int UIMenu_MsgTimer = 0;	// Message timer (to close the message)
int UIMenu_MsgLines = 0;	// Message lines (total number of lines)

static TUIRealtimeCB UIRealtimeCB = NULL;

enum {
	UIPAGE_MENUITEMS,
	UIPAGE_LOADROM,
	UIPAGE_MESSAGE,
	UIPAGE_REALTIMETEXT
};

int UIItems_MainMenuC(int index, int reason);
TUIMenu_Item UIItems_MainMenu[] = {
	{ 0,  0, "Resume...", UIItems_MainMenuC },
#ifndef NO_SCANDIRS
	{ 0,  1, "Load ROM...", UIItems_MainMenuC },
#endif
	{ 0,  2, "Load State <0>", UIItems_MainMenuC },
	{ 0,  3, "Save State <0>", UIItems_MainMenuC },
	{ 0,  4, "Reset <Hard>", UIItems_MainMenuC },
	{ 0,  5, "Options...", UIItems_MainMenuC },
	{ 0,  6, "Platform...", UIItems_MainMenuC },
	{ 0,  7, "About...", UIItems_MainMenuC },
	{ 0,  8, "Exit", UIItems_MainMenuC },
	{ 9,  0, "Main Menu", UIItems_MainMenuC }
};

int UIItems_OptionsC(int index, int reason);
TUIMenu_Item UIItems_Options[] = {
	{ 0,  0, "Go Back...", UIItems_OptionsC },
	{ 0,  1, "Palette: %s", UIItems_OptionsC },
	{ 0,  2, "LCD Mode: %s", UIItems_OptionsC },
	{ 0,  3, "LCD Filter: %s", UIItems_OptionsC },
	{ 0, 10, "Contrast: %i%%", UIItems_OptionsC },
	{ 0, 11, "Bright: %i%%", UIItems_OptionsC },
	{ 0,  4, "Sound: %s", UIItems_OptionsC },
	{ 0,  5, "Piezo Filter: %s", UIItems_OptionsC },
	{ 0,  6, "PM Battery: %s", UIItems_OptionsC },
	{ 0,  7, "RTC: %s", UIItems_OptionsC },
	{ 0,  8, "Shared EEP.: %s", UIItems_OptionsC },
	{ 0,  9, "Force FreeBIOS: %s", UIItems_OptionsC },
#ifndef PERFORMANCE
	{ 0, 20, "Multicart: %s", UIItems_OptionsC },
#endif
	{ 0, 50, "Sync Cycles: %d", UIItems_OptionsC },
	{ 0, 60, "Reload Color Info...", UIItems_OptionsC },
	{ 0, 99, "Save Configs...", UIItems_OptionsC },
	{ 9,  0, "Options", UIItems_OptionsC }
};

int UIItems_PalEditC(int index, int reason);
TUIMenu_Item UIItems_PalEdit[] = {
	{ 0,  0, "Go Back...", UIItems_PalEditC },
	{ 0,  1, "1-Light   Red: %d", UIItems_PalEditC },
	{ 0,  2, "1-Light Green: %d", UIItems_PalEditC },
	{ 0,  3, "1-Light  Blue: %d", UIItems_PalEditC },
	{ 0,  4, "1-Dark    Red: %d", UIItems_PalEditC },
	{ 0,  5, "1-Dark  Green: %d", UIItems_PalEditC },
	{ 0,  6, "1-Dark   Blue: %d", UIItems_PalEditC },
	{ 0,  7, "1-Light   Red: %d", UIItems_PalEditC },
	{ 0,  8, "1-Light Green: %d", UIItems_PalEditC },
	{ 0,  9, "1-Light  Blue: %d", UIItems_PalEditC },
	{ 0, 10, "1-Dark    Red: %d", UIItems_PalEditC },
	{ 0, 11, "1-Dark  Green: %d", UIItems_PalEditC },
	{ 0, 12, "1-Dark   Blue: %d", UIItems_PalEditC },
	{ 9,  0, "Palette Edit", UIItems_PalEditC }
};

int UIMenu_SetDisplay(int width, int height, int pixellayout, uint8_t *bg_image, uint16_t *bg_pal16, uint32_t *bg_pal32)
{
	// Calculate maximum number of lines
	UIMenu_Width = width;
	UIMenu_Height = height;
	UIMenu_PixelLayout = pixellayout;
	UIMenu_Lines = (height - 20) / 12;
	if (UIMenu_Lines < 8) return 0;
	UIMenu_MMax = UIMenu_Lines - 2;	

	// Setup pixel layout
	pixellayout &= 15;
	UI_Font1_Pal32 = (uint32_t *)PokeMini_Font12_PalBGR32;
	UI_Font2_Pal32 = (uint32_t *)PokeMini_TFont12_PalBGR32;
	UI_Icons_Pal32 = (uint32_t *)PokeMini_Icons12_PalBGR32;
	if (pixellayout == PokeMini_RGB15) {
		UI_Font1_Pal16 = (uint16_t *)PokeMini_Font12_PalRGB15;
		UI_Font2_Pal16 = (uint16_t *)PokeMini_TFont12_PalRGB15;
		UI_Icons_Pal16 = (uint16_t *)PokeMini_Icons12_PalRGB15;
	} else if (pixellayout == PokeMini_RGB16) {
		UI_Font1_Pal16 = (uint16_t *)PokeMini_Font12_PalRGB16;
		UI_Font2_Pal16 = (uint16_t *)PokeMini_TFont12_PalRGB16;
		UI_Icons_Pal16 = (uint16_t *)PokeMini_Icons12_PalRGB16;
	} else {
		UI_Font1_Pal16 = (uint16_t *)PokeMini_Font12_PalBGR16;
		UI_Font2_Pal16 = (uint16_t *)PokeMini_TFont12_PalBGR16;
		UI_Icons_Pal16 = (uint16_t *)PokeMini_Icons12_PalBGR16;
	}

	// Set/Update BG
	if (bg_image) UIMenu_BGImage = bg_image;
	if (bg_pal16) UIMenu_BGPal16 = bg_pal16;
	if (bg_pal32) UIMenu_BGPal32 = bg_pal32;

	return 1;
}

int UIMenu_Init(void)
{
	// Clear menu
	UIMenu_LoadItems(UIItems_MainMenu, 0);
	UIMenu_Page = UIPAGE_MENUITEMS;
	UIMenu_Ani = 0;
	UIMenu_InKey = 0;
	UIMenu_Savestate = 0;
	UI_Enabled = 1;
	UI_FirstLoad = 1;

	// Allocate files list cache
	UIMenu_FileListCache = (TUIMenu_FileListCache *)malloc(UI_MAXCACHE * sizeof(TUIMenu_FileListCache));
	if (!UIMenu_FileListCache) return 0;

	return 1;
}

void UIMenu_Destroy(void)
{
	UI_Enabled = 0;

	// Free files list cache
	if (UIMenu_FileListCache) {
		free(UIMenu_FileListCache);
		UIMenu_FileListCache = NULL;
	}
}

void UIMenu_SwapEntries(int a, int b)
{
	TUIMenu_FileListCache tmp;
	memcpy(&tmp, &UIMenu_FileListCache[a], sizeof(TUIMenu_FileListCache));
	memcpy(&UIMenu_FileListCache[a], &UIMenu_FileListCache[b], sizeof(TUIMenu_FileListCache));
	memcpy(&UIMenu_FileListCache[b], &tmp, sizeof(TUIMenu_FileListCache));
}

#ifndef NO_SCANDIRS

int UIMenu_ReadDir(char *dirname)
{
	int i, j, cmp, hasslash, isdir, items = 0;
	char file[PMTMPV];

	// Clear all cache
	for (i=0; i<UI_MAXCACHE; i++) {
		UIMenu_FileListCache[i].name[0] = 0;
		UIMenu_FileListCache[i].stats = 0;
		UIMenu_FileListCache[i].color = 0;
	}

	// Read directories and files
	hasslash = HasLastSlash(dirname);
#ifdef FS_DC
	file_t d = fs_open(dirname, O_RDONLY | O_DIR);
	dirent_t *de;
	if (strlen(dirname) > 1) {
		strcpy(UIMenu_FileListCache[0].name, "..");
		UIMenu_FileListCache[0].stats = 1;
		items = 1;
	}
	while ( (de = fs_readdir(d)) ) {
		if (de->name[0] == 0) break;
		if (de->name[0] == '.') continue;
		UIMenu_FileListCache[items].stats = 1;
		strcpy(UIMenu_FileListCache[items].name, de->name);
		if (hasslash) sprintf(file, "%s%s", dirname, de->name);
		else sprintf(file, "%s/%s", dirname, de->name);
		isdir = (de->size < 0);
		if (isdir) {
			// Directory
			UIMenu_FileListCache[items++].stats = 1;
			if (items >= UI_MAXCACHE) break;
		} else {
			// File
			if (ExtensionCheck(de->name, ".min")) {
				UIMenu_FileListCache[items].stats = 2;
				sprintf(file, "%sc", de->name);
				if (FileExist(file)) UIMenu_FileListCache[items].color = 1;
				items++;
#ifndef NO_ZIP
			} else if (ExtensionCheck(de->name, ".zip")) {
				UIMenu_FileListCache[items].stats = 2;
				UIMenu_FileListCache[items].color = 2;
				items++;
#endif
			}
			if (items >= UI_MAXCACHE) break;
		}
	}
	fs_close(d);
#else
	struct dirent *dirEntry;
	struct stat Stat;
	DIR *dir = opendir(dirname);
	if (dir == NULL) {
		PokeDPrint(POKEMSG_ERR, "opendir('%s') error\n", dirname);
		return 0;
	}
	while((dirEntry = readdir(dir)) != NULL) {
		if (dirEntry->d_name[0] == 0) break;
		UIMenu_FileListCache[items].stats = 0;
		strcpy(UIMenu_FileListCache[items].name, dirEntry->d_name);
		if (strcmp(dirEntry->d_name, ".") == 0) {
			// Current directory
			continue;
		} else {
			// Current directory, file or directory
			if (hasslash) sprintf(file, "%s%s", dirname, dirEntry->d_name);
			else sprintf(file, "%s/%s", dirname, dirEntry->d_name);
			if (stat(file, &Stat) == -1) {
				PokeDPrint(POKEMSG_ERR, "stat('%s') error\n", file);
				continue;
			} else {
				isdir = S_ISDIR(Stat.st_mode);
			}
			
		}
		if (isdir) {
			// Directory
			UIMenu_FileListCache[items++].stats = 1;
			if (items >= UI_MAXCACHE) break;
		} else {
			// File
			if (ExtensionCheck(dirEntry->d_name, ".min")) {
				UIMenu_FileListCache[items].stats = 2;
				sprintf(file, "%sc", dirEntry->d_name);
				if (FileExist(file)) UIMenu_FileListCache[items].color = 1;
				items++;
#ifndef NO_ZIP
			} else if (ExtensionCheck(dirEntry->d_name, ".zip")) {
				UIMenu_FileListCache[items].stats = 2;
				UIMenu_FileListCache[items].color = 2;
				items++;
#endif
			}
		}
	}
	closedir(dir);
#endif

	// Sort the list
	for (i=0; i<items; i++) {
		for (j=i; j<items; j++) {
			cmp = strcasecmp(UIMenu_FileListCache[j].name, UIMenu_FileListCache[i].name);
			if (UIMenu_FileListCache[j].stats < UIMenu_FileListCache[i].stats) {
				UIMenu_SwapEntries(i, j);
			} else if (cmp < 0) {
				UIMenu_SwapEntries(i, j);
			}
		}
	}

	return items;
}

void UIMenu_GotoRelativeDir(char *newdir)
{
	char file[PMTMPV];
	int hasslash;

	hasslash = HasLastSlash(PokeMini_CurrDir);

	if (newdir) {
		if (hasslash)
			sprintf(file, "%s%s", PokeMini_CurrDir, newdir);
		else
			sprintf(file, "%s/%s", PokeMini_CurrDir, newdir);
#ifdef FS_DC
		chdir(file);
#else
		struct stat Stat;
		if (stat(file, &Stat) == -1) {
			PokeDPrint(POKEMSG_ERR, "stat('%s') error\n", file);
		} else {
			if (S_ISDIR(Stat.st_mode)) {
				if (chdir(file)) PokeDPrint(POKEMSG_ERR, "rel chdir('%s') error\n", file);
			}
		}
#endif
	} else {
		PokeMini_GotoCurrentDir();
	}
	PokeMini_GetCurrentDir();
}

#else

int UIMenu_ReadDir(char *dirname) { return 0; }
void UIMenu_GotoRelativeDir(char *newdir) {}

#endif

void UIMenu_KeyEvent(int key, int press)
{
	if (key == MINX_KEY_C) UIMenu_CKeyMod = press;
	if (press) {
		if (UI_Enabled && UI_Status) {
			UIMenu_InKey = key;
		} else {
			PokeMini_KeypadEvent(key, 1);
		}
	} else {
		PokeMini_KeypadEvent(key, 0);
	}
}

void UIMenu_LoadItems(TUIMenu_Item *items, int cursorindex)
{
	int i = 0;
	while (items[i].code < 2) i++;
	items[i].index = UIMenu_Cur;
	items[i].prev = UIMenu_CurrentItems;
	UIMenu_CurrentItems = items;
	UIMenu_CurrentItemsNum = i;
	UIMenu_Cur = cursorindex;
	if (UIMenu_Cur >= UIMenu_MMax) UIMenu_MOff = UIMenu_Cur - UIMenu_MMax + 1;
	else UIMenu_MOff = 0;
	items[i].callback(i, UIMENU_LOAD);
}

void UIMenu_PrevMenu(void)
{
	int i = 0;
	if (!UIMenu_CurrentItems) return;
	UIMenu_Cur = UIMenu_CurrentItems[UIMenu_CurrentItemsNum].index;
	UIMenu_CurrentItems = UIMenu_CurrentItems[UIMenu_CurrentItemsNum].prev;
	while (UIMenu_CurrentItems[i].code < 2) i++;
	UIMenu_CurrentItemsNum = i;
	if (UIMenu_Cur >= UIMenu_MMax) UIMenu_MOff = UIMenu_Cur - UIMenu_MMax + 1;
	else UIMenu_MOff = 0;
	UIMenu_CurrentItems[i].callback(i, UIMENU_LOAD);
}

int UIMenu_ChangeItem(TUIMenu_Item *items, int index, const char *format, ...)
{
	va_list args;
	char buffer[PMTMPV];
	int i = 0;
	if (!items) return 0;
	while (items[i].code < 2) {
		if (items[i].index == index) {
			va_start(args, format);
			vsprintf(buffer, format, args);
			va_end(args);
			buffer[31] = 0;		// Menu only have 32 characters
			strcpy(items[i].caption, buffer);
			return 1;
		}
		i++;
	}
	return 0;
}

void UIMenu_BeginMessage(void)
{
	UIMenu_MsgLines = 0;
}

void UIMenu_SetMessage(char *message, int color)
{
	strcpy(UIMenu_FileListCache[UIMenu_MsgLines].name, message);
	UIMenu_FileListCache[UIMenu_MsgLines].color = color;
	UIMenu_MsgLines++;
}

void UIMenu_EndMessage(int timeout)
{
	UIMenu_Page = UIPAGE_MESSAGE;
	UIMenu_MsgOffset = 0;
	UIMenu_MsgCountDw = UIMenu_MsgCountReset1;
	UIMenu_MsgTimer = timeout;
}

void UIMenu_RealTimeMessage(TUIRealtimeCB cb)
{
	if (cb == NULL) return;
	UIMenu_Page = UIPAGE_REALTIMETEXT;
	UIRealtimeCB = cb;
	UIRealtimeCB(1, NULL);
}

int UIItems_MainMenuC(int index, int reason)
{
	char tmp[PMTMPV];

	// Main Menu
	if (reason == UIMENU_OK) {
		switch (index) {
			case 0: // Resume...
				reason = UIMENU_CANCEL;
				break;
			case 1: // Load ROM...
				if (UI_FirstLoad) {
					if (strlen(CommandLine.rom_dir)) PokeMini_SetCurrentDir(CommandLine.rom_dir);
					UI_FirstLoad = 0;
				} else UIMenu_GotoRelativeDir(NULL);
				UIMenu_Page = UIPAGE_LOADROM;
				UIMenu_Cur = 0;
				UIMenu_ListFiles = UIMenu_ReadDir(PokeMini_CurrDir);
				UIMenu_ListOffs = 0;
				break;
			case 2: // Load state
				UIMenu_BeginMessage();
				UIMenu_SetMessage("Load state...", 1);
				UIMenu_SetMessage("", 1);
				sprintf(tmp, "%s.st%d", CommandLine.min_file, UIMenu_Savestate);
				if (PokeMini_LoadSSFile(tmp)) {
					UIMenu_SetMessage("State loaded!", 0);
					UIMenu_EndMessage(60);
				} else {
					UIMenu_SetMessage("Loading failed", 0);
					UIMenu_EndMessage(240);
				}
				break;
			case 3: // Save state
				UIMenu_BeginMessage();
				UIMenu_SetMessage("Save state...", 1);
				UIMenu_SetMessage("", 1);
				sprintf(tmp, "%s.st%d", CommandLine.min_file, UIMenu_Savestate);
				if (PokeMini_SaveSSFile(tmp, CommandLine.min_file)) {
					UIMenu_SetMessage("State saved!", 0);
					UIMenu_EndMessage(60);
				} else {
					UIMenu_SetMessage("Saving failed", 0);
					UIMenu_EndMessage(240);
				}
				break;
			case 4: // Reset
				PokeMini_Reset(UIMenu_HardReset);
				UI_Status = UI_STATUS_GAME;
				break;
			case 5: // Options...
				UIMenu_LoadItems(UIItems_Options, 0);
				break;
			case 6: // Platform...
				UIMenu_LoadItems(UIItems_Platform, 0);
				break;
			case 7: // About...
				UIMenu_BeginMessage();
				UIMenu_SetMessage("PokeMini " PokeMini_Version, 1);
				UIMenu_SetMessage("", 0);
				// Zoom >= 2, up to 23 chars
				UIMenu_SetMessage("Thanks to p0p, Dave|X,", 0);
				UIMenu_SetMessage("Onori, goldmomo, Agilo,", 0);
				UIMenu_SetMessage("DarkFader, asterick,", 0);
				UIMenu_SetMessage("MrBlinky, Wa, Lupin and", 0);
				UIMenu_SetMessage("everyone in #pmdev on", 0);
				UIMenu_SetMessage("IRC EFNET!", 0);
				UIMenu_SetMessage("", 0);
				UIMenu_SetMessage("Please check readme.txt", 1);
				if (UIMenu_Width >= 350) {
					// Zoom >= 4, up to 34 chars
					UIMenu_SetMessage("", 0);
					UIMenu_SetMessage("For latest version visit:", 1);
					UIMenu_SetMessage("http://code.google.com/p/pokemini/", 0);
					UIMenu_SetMessage("", 0);
					//                 0000000001111111111222222222233333
					//                 1234567890123456789012345678901234
					UIMenu_SetMessage("Google Play fee donated by MEGA", 1);
					UIMenu_SetMessage("Museum of Electronic Games & Art", 0);
					UIMenu_SetMessage("       http://m-e-g-a.org", 0);
					UIMenu_SetMessage("MEGA supports preservation", 0);
					UIMenu_SetMessage("projects of digital art & culture", 0);
				}
				UIMenu_EndMessage(72*3600);
				break;
			case 8: // Exit
				UI_Status = UI_STATUS_EXIT;
				break;
		}
	}
	if (reason == UIMENU_CANCEL) {
		UI_Status = UI_STATUS_GAME;
		return 0;
	}
	if (reason == UIMENU_LEFT) {
		switch (index) {
			case 2: case 3:	// Load/Save State
				UIMenu_Savestate--;
				if (UIMenu_Savestate < 0) UIMenu_Savestate = 9;
				break;
			case 4:		// Reset
				UIMenu_HardReset = !UIMenu_HardReset;
				break;
		}
	}
	if (reason == UIMENU_RIGHT) {
		switch (index) {
			case 2: case 3:	// Load/Save State
				UIMenu_Savestate++;
				if (UIMenu_Savestate > 9) UIMenu_Savestate = 0;
				break;
			case 4:		// Reset
				UIMenu_HardReset = !UIMenu_HardReset;
				break;
		}
	}

	// Update items
	UIMenu_ChangeItem(UIItems_MainMenu, 2, "Load State <%d>", UIMenu_Savestate);
	UIMenu_ChangeItem(UIItems_MainMenu, 3, "Save State <%d>", UIMenu_Savestate);
	UIMenu_ChangeItem(UIItems_MainMenu, 4, "Reset <%s>", UIMenu_HardReset ? "Hard" : "Soft");

	return 1;
}

char *UIMenuTxt_Palette[16] = {
	"Default", "Old", "Black & White", "Green Palette",
	"Green Vector",	"Red Palette", "Red Vector", "Blue LCD",
	"LEDBacklight", "Girl Power", "Blue Palette", "Blue Vector",
	"Sepia", "Inv. B&W", "Custom 1...", "Custom 2..."
};

char *UIMenuTxt_LCDMode[4] = {
	"Analog", "3-Shades", "2-Shades", "Colors"
};

char *UIMenuTxt_LCDFilter[3] = {
	"None", "Matrix/Hi", "Scanline"
};

char *UIMenuTxt_Sound[6] = {
	"Disabled", "Generated", "Direct", "Emulated", "Direct PWM"
};

char *UIMenuTxt_Battery[3] = {
	"Full", "Low", "Auto"
};

char *UIMenuTxt_RTC[3] = {
	"Off", "State time diff.", "From Host"
};

char *UIMenuTxt_Multicart[3] = {
	"Disabled", "Flash 512K", "Lupin 512K"
};

char *UIMenuTxt_Enabled[2] = {
	"Disabled", "Enabled"
};

int UIItems_OptionsC(int index, int reason)
{
	char tmp[PMTMPV];

	// Options
	if (reason == UIMENU_OK) {
		switch (index) {
			case 0: // Go back...
				reason = UIMENU_CANCEL;
				break;
			case 1: // Palette
				UIMenu_LoadItems(UIItems_PalEdit, 0);
				break;
			case 2: case 3: case 4: case 5:
			case 6: case 7: case 8: case 9:
				reason = UIMENU_RIGHT;
				break;
			case 20: // Multicart
				reason = UIMENU_RIGHT;
				break;
			case 60: // Reload Color Info...
				UIMenu_BeginMessage();
				UIMenu_SetMessage("Reload Color Info...", 1);
				UIMenu_SetMessage("", 1);
				sprintf(tmp, "%sc", CommandLine.min_file);
				if (!FileExist(tmp) || !PokeMini_LoadColorFile(tmp)) {
					if (CommandLine.lcdmode == 3) CommandLine.lcdmode = 0;
					UIMenu_SetMessage("Reload failed!", 0);
					UIMenu_EndMessage(240);
				} else {
					CommandLine.lcdmode = 3;
					UIMenu_SetMessage("Reload complete!", 0);
					UIMenu_EndMessage(60);
				}
				break;
			case 99: // Save configs...
				UIMenu_BeginMessage();
				UIMenu_SetMessage("Save Configs...", 1);
				UIMenu_SetMessage("", 1);
				PokeMini_GotoExecDir();
				if (CommandLineConfSave()) {
					UIMenu_SetMessage("Configurations saved", 0);
				} else {
					UIMenu_SetMessage("Saving failed!", 0);
				}
				UIMenu_EndMessage(240);
				break;
		}
	}
	if (reason == UIMENU_CANCEL) {
		UIMenu_PrevMenu();
		return 1;
	}
	if (reason == UIMENU_LEFT) {
		switch (index) {
			case 1: CommandLine.palette = (CommandLine.palette - 1) & 15;
				PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
				break;
			case 2: CommandLine.lcdmode--;
				if (CommandLine.lcdmode < 0) CommandLine.lcdmode = PRCColorMap ? 3 : 2;
				break;
			case 3: CommandLine.lcdfilter--;
				if (CommandLine.lcdfilter < 0) CommandLine.lcdfilter = 2;
				break;
			case 10: CommandLine.lcdcontrast -= 2;
				if (CommandLine.lcdcontrast < 0) CommandLine.lcdcontrast = 100;
				PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
				break;
			case 11: CommandLine.lcdbright -= 2;
				if (CommandLine.lcdbright < -100) CommandLine.lcdbright = 100;
				PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
				break;
			case 4: if (PokeMini_Flags & POKEMINI_GENSOUND) {
					CommandLine.sound = !CommandLine.sound;
				} else {
					CommandLine.sound--;
					if (CommandLine.sound < 0) CommandLine.sound = 4;
				}
				break;
			case 5: CommandLine.piezofilter = !CommandLine.piezofilter;
				break;
			case 6: if (PokeMini_Flags & POKEMINI_AUTOBATT)
					CommandLine.low_battery--;
				else
					CommandLine.low_battery = !CommandLine.low_battery;
				if (CommandLine.low_battery < 0) CommandLine.low_battery = 2;
				break;
			case 7: CommandLine.updatertc--;
				if (CommandLine.updatertc < 0) CommandLine.updatertc = 2;
				break;
			case 8: CommandLine.eeprom_share = !CommandLine.eeprom_share;
				break;
			case 9: CommandLine.forcefreebios = !CommandLine.forcefreebios;
				break;
			case 20: CommandLine.multicart--;
				if (CommandLine.multicart < 0) CommandLine.multicart = 2;
				break;
			case 50: CommandLine.synccycles >>= 1;
				if (CommandLine.synccycles < 8) CommandLine.synccycles = 8;
				break;
		}
	}
	if (reason == UIMENU_RIGHT) {
		switch (index) {
			case 1: CommandLine.palette = (CommandLine.palette + 1) & 15;
				PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
				break;
			case 2: CommandLine.lcdmode++;
				if (CommandLine.lcdmode > (PRCColorMap ? 3 : 2)) CommandLine.lcdmode = 0;
				break;
			case 3: CommandLine.lcdfilter++;
				if (CommandLine.lcdfilter > 2) CommandLine.lcdfilter = 0;
				break;
			case 10: CommandLine.lcdcontrast += 2;
				if (CommandLine.lcdcontrast > 100) CommandLine.lcdcontrast = 0;
				PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
				break;
			case 11: CommandLine.lcdbright += 2;
				if (CommandLine.lcdbright > 100) CommandLine.lcdbright = -100;
				PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
				break;
			case 4: if (PokeMini_Flags & POKEMINI_GENSOUND) {
					CommandLine.sound = !CommandLine.sound;
				} else {
					CommandLine.sound++;
					if (CommandLine.sound > 4) CommandLine.sound = 0;
				}
				break;
			case 5: CommandLine.piezofilter = !CommandLine.piezofilter;
				break;
			case 6: if (PokeMini_Flags & POKEMINI_AUTOBATT)
					CommandLine.low_battery++;
				else
					CommandLine.low_battery = !CommandLine.low_battery;
				if (CommandLine.low_battery > 2) CommandLine.low_battery = 0;
				break;
			case 7: CommandLine.updatertc++;
				if (CommandLine.updatertc > 2) CommandLine.updatertc = 0;
				break;
			case 8: CommandLine.eeprom_share = !CommandLine.eeprom_share;
				break;
			case 9: CommandLine.forcefreebios = !CommandLine.forcefreebios;
				break;
			case 20: CommandLine.multicart++;
				if (CommandLine.multicart > 2) CommandLine.multicart = 0;
				break;
			case 50: CommandLine.synccycles <<= 1;
#ifdef PERFORMANCE
				if (CommandLine.synccycles > 512) CommandLine.synccycles = 512;
#else
				if (CommandLine.synccycles > 64) CommandLine.synccycles = 64;
#endif
				break;
		}
	}

	// Update items
	UIMenu_ChangeItem(UIItems_Options,  1, "Palette: %s", UIMenuTxt_Palette[CommandLine.palette]);
	UIMenu_ChangeItem(UIItems_Options,  2, "LCD Mode: %s", UIMenuTxt_LCDMode[CommandLine.lcdmode]);
	UIMenu_ChangeItem(UIItems_Options,  3, "LCD Filter: %s", UIMenuTxt_LCDFilter[CommandLine.lcdfilter]);
	UIMenu_ChangeItem(UIItems_Options, 10, "Contrast: %i%%", CommandLine.lcdcontrast);
	UIMenu_ChangeItem(UIItems_Options, 11, "Bright: %i%%", CommandLine.lcdbright);
	if (PokeMini_Flags & POKEMINI_NOSOUND) {
		CommandLine.sound = 0;
		UIMenu_ChangeItem(UIItems_Options,  4, "Sound: Disabled");
	} else if (PokeMini_Flags & POKEMINI_GENSOUND) {
		CommandLine.sound = CommandLine.sound ? 1 : 0;
		UIMenu_ChangeItem(UIItems_Options,  4, "Sound: %s", UIMenuTxt_Enabled[CommandLine.sound]);
	} else {
		UIMenu_ChangeItem(UIItems_Options,  4, "Sound: %s", UIMenuTxt_Sound[CommandLine.sound]);
	}
	UIMenu_ChangeItem(UIItems_Options,  5, "Piezo Filter: %s", CommandLine.piezofilter ? "Yes" : "No");
	if (PokeMini_Flags & POKEMINI_AUTOBATT) {
		UIMenu_ChangeItem(UIItems_Options,  6, "PM Batt.: %s (%s)", UIMenuTxt_Battery[CommandLine.low_battery], UIMenuTxt_Battery[PokeMini_HostBattStatus]);
	} else {
		UIMenu_ChangeItem(UIItems_Options,  6, "PM Battery: %s", UIMenuTxt_Battery[CommandLine.low_battery]);
	}
	UIMenu_ChangeItem(UIItems_Options,  7, "RTC: %s", UIMenuTxt_RTC[CommandLine.updatertc]);
	UIMenu_ChangeItem(UIItems_Options,  8, "Shared EEP.: %s", CommandLine.eeprom_share ? "Yes" : "No");
	UIMenu_ChangeItem(UIItems_Options,  9, "Force FreeBIOS: %s", CommandLine.forcefreebios ? "Yes" : "No");
	UIMenu_ChangeItem(UIItems_Options, 20, "Multicart: %s", UIMenuTxt_Multicart[CommandLine.multicart]);
	UIMenu_ChangeItem(UIItems_Options, 50, "Sync Cycles: %d", CommandLine.synccycles);

	return 1;
}

int UIItems_PalEditC(int index, int reason)
{
	uint8_t r, g, b, ic, ix;
	const int deco[] = {0, 0, 1, 2, 4, 5, 6, 8, 9, 10, 12, 13, 14};

	// Palette Editor
	if (reason == UIMENU_OK) {
		switch (index) {
			case 0: // Go back...
				reason = UIMENU_CANCEL;
				break;
		}
	}
	if (reason == UIMENU_CANCEL) {
		UIMenu_PrevMenu();
		return 1;
	}
	if (reason == UIMENU_LEFT) {
		if (index > 0) {
			ic = deco[index] & 3;
			ix = (deco[index] & 12) >> 2;
			r = GetValH24(CommandLine.custompal[ix]);
			g = GetValM24(CommandLine.custompal[ix]);
			b = GetValL24(CommandLine.custompal[ix]);
			if (UIMenu_CKeyMod) {
				if (ic == 0) r-=16;
				if (ic == 1) g-=16;
				if (ic == 2) b-=16;
			} else {
				if (ic == 0) r--;
				if (ic == 1) g--;
				if (ic == 2) b--;
			}
			CommandLine.custompal[ix] = RGB24(b, g, r);
			PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
		}
	}
	if (reason == UIMENU_RIGHT) {
		if (index > 0) {
			ic = deco[index] & 3;
			ix = (deco[index] & 12) >> 2;
			r = GetValH24(CommandLine.custompal[ix]);
			g = GetValM24(CommandLine.custompal[ix]);
			b = GetValL24(CommandLine.custompal[ix]);
			if (UIMenu_CKeyMod) {
				if (ic == 0) r+=16;
				if (ic == 1) g+=16;
				if (ic == 2) b+=16;
			} else {
				if (ic == 0) r++;
				if (ic == 1) g++;
				if (ic == 2) b++;
			}
			CommandLine.custompal[ix] = RGB24(b, g, r);
			PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
		}
	}

	// Update items
	UIMenu_ChangeItem(UIItems_PalEdit,  1, "1-Light   Red: %d", GetValH24(CommandLine.custompal[0]));
	UIMenu_ChangeItem(UIItems_PalEdit,  2, "1-Light Green: %d", GetValM24(CommandLine.custompal[0]));
	UIMenu_ChangeItem(UIItems_PalEdit,  3, "1-Light  Blue: %d", GetValL24(CommandLine.custompal[0]));
	UIMenu_ChangeItem(UIItems_PalEdit,  4, "1-Dark    Red: %d", GetValH24(CommandLine.custompal[1]));
	UIMenu_ChangeItem(UIItems_PalEdit,  5, "1-Dark  Green: %d", GetValM24(CommandLine.custompal[1]));
	UIMenu_ChangeItem(UIItems_PalEdit,  6, "1-Dark   Blue: %d", GetValL24(CommandLine.custompal[1]));
	UIMenu_ChangeItem(UIItems_PalEdit,  7, "2-Light   Red: %d", GetValH24(CommandLine.custompal[2]));
	UIMenu_ChangeItem(UIItems_PalEdit,  8, "2-Light Green: %d", GetValM24(CommandLine.custompal[2]));
	UIMenu_ChangeItem(UIItems_PalEdit,  9, "2-Light  Blue: %d", GetValL24(CommandLine.custompal[2]));
	UIMenu_ChangeItem(UIItems_PalEdit, 10, "2-Dark    Red: %d", GetValH24(CommandLine.custompal[3]));
	UIMenu_ChangeItem(UIItems_PalEdit, 11, "2-Dark  Green: %d", GetValM24(CommandLine.custompal[3]));
	UIMenu_ChangeItem(UIItems_PalEdit, 12, "2-Dark   Blue: %d", GetValL24(CommandLine.custompal[3]));

	return 1;
}

int UIItems_PlatformDefC(int index, int reason)
{
	if (reason == UIMENU_OK) {
		if (index == 99) { // Save configs...
			UIMenu_BeginMessage();
			UIMenu_SetMessage("Save Configs...", 1);
			UIMenu_SetMessage("", 1);
			PokeMini_GotoExecDir();
			if (CommandLineConfSave()) {
				UIMenu_SetMessage("Configurations saved", 0);
			} else {
				UIMenu_SetMessage("Saving failed!", 0);
			}
			UIMenu_EndMessage(240);
		} else reason = UIMENU_CANCEL;
	}
	if (reason == UIMENU_CANCEL) {
		UIMenu_PrevMenu();
		return 1;
	}
	return 1;
}

int UIMenu_DoStuff(int key)
{
	int i;

	// Menu items
	if (UIMenu_Page == UIPAGE_MENUITEMS) {
		if (key == MINX_KEY_DOWN) {
			UIMenu_Cur++;
			if (UIMenu_Cur >= UIMenu_CurrentItemsNum) UIMenu_Cur = 0;
			if (UIMenu_Cur >= UIMenu_MMax) UIMenu_MOff = UIMenu_Cur - UIMenu_MMax + 1;
			else UIMenu_MOff = 0;
		}
		if (key == MINX_KEY_UP) {
			UIMenu_Cur--;
			if (UIMenu_Cur < 0) UIMenu_Cur = UIMenu_CurrentItemsNum-1;
			if (UIMenu_Cur >= UIMenu_MMax) UIMenu_MOff = UIMenu_Cur - UIMenu_MMax + 1;
			else UIMenu_MOff = 0;
		}
		if (key == MINX_KEY_A) {
			return UIMenu_CurrentItems[UIMenu_Cur].callback(UIMenu_CurrentItems[UIMenu_Cur].index, UIMENU_OK);
		}
		if (key == MINX_KEY_B) {
			return UIMenu_CurrentItems[UIMenu_Cur].callback(UIMenu_CurrentItems[UIMenu_Cur].index, UIMENU_CANCEL);
		}
		if (key == MINX_KEY_LEFT) {
			return UIMenu_CurrentItems[UIMenu_Cur].callback(UIMenu_CurrentItems[UIMenu_Cur].index, UIMENU_LEFT);
		}
		if (key == MINX_KEY_RIGHT) {
			return UIMenu_CurrentItems[UIMenu_Cur].callback(UIMenu_CurrentItems[UIMenu_Cur].index, UIMENU_RIGHT);
		}
	}

	// Load ROM
	if (UIMenu_Page == UIPAGE_LOADROM) {
		if (UIMenu_CKeyMod) {
			// Key C Modifier (On)
			// C + Down  = Last item
			// C + Up    = First item
			// C + Left  = Left drive (Windows)
			// C + Right = Right drive (Windows)

			if (key == MINX_KEY_DOWN) {
				UIMenu_Cur = (UIMenu_ListFiles-1) % UIMenu_FilesLines;
				UIMenu_ListOffs = (UIMenu_ListFiles-1) / UIMenu_FilesLines * UIMenu_FilesLines;
			}
			if (key == MINX_KEY_UP) {
				UIMenu_Cur = 0;
				UIMenu_ListOffs = 0;
			}
			if (key == MINX_KEY_LEFT) {
				// Hack to support windows drives
				if (strlen(PokeMini_CurrDir) >= 3) {
					if (PokeMini_CurrDir[1] == ':') {
						for (i=toupper((int)PokeMini_CurrDir[0]); i>'A';) {
							PokeMini_CurrDir[0] = --i;
							PokeMini_CurrDir[2] = '\\';
							PokeMini_CurrDir[3] = 0;
							UIMenu_GotoRelativeDir(NULL);
							if (toupper((int)PokeMini_CurrDir[0]) == i) {
								UIMenu_Cur = 0;
								UIMenu_ListFiles = UIMenu_ReadDir(PokeMini_CurrDir);
								UIMenu_ListOffs = 0;
								break;
							}
						}
					}
				}
			}
			if (key == MINX_KEY_RIGHT) {
				// Hack to support windows drives
				if (strlen(PokeMini_CurrDir) >= 3) {
					if (PokeMini_CurrDir[1] == ':') {
						for (i=toupper((int)PokeMini_CurrDir[0]); i<'Z';) {
							PokeMini_CurrDir[0] = ++i;
							PokeMini_CurrDir[2] = '\\';
							PokeMini_CurrDir[3] = 0;
							UIMenu_GotoRelativeDir(NULL);
							if (toupper((int)PokeMini_CurrDir[0]) == i) {
								UIMenu_Cur = 0;
								UIMenu_ListFiles = UIMenu_ReadDir(PokeMini_CurrDir);
								UIMenu_ListOffs = 0;
								break;
							}
						}
					}
				}
			}
		} else {
			// Key C Modifier (Off)
			// Down  = Previous item
			// Up    = Next item
			// Left  = Previous page
			// Right = Next page

			if (key == MINX_KEY_DOWN) {
				UIMenu_Cur++;
				if ((UIMenu_ListOffs + UIMenu_Cur) >= UIMenu_ListFiles) {
					// Over last item
					UIMenu_Cur = 0;
					UIMenu_ListOffs = 0;
				} else if (UIMenu_Cur >= UIMenu_FilesLines) {
					// Over last line
					UIMenu_Cur = 0;
					UIMenu_ListOffs += UIMenu_FilesLines;
					if (UIMenu_ListOffs >= UIMenu_ListFiles) UIMenu_ListOffs -= UIMenu_FilesLines;
				}
			}
			if (key == MINX_KEY_UP) {
				UIMenu_Cur--;
				if (UIMenu_Cur < 0) {
					// Under last line
					UIMenu_Cur = UIMenu_Lines-2;
					UIMenu_ListOffs -= UIMenu_FilesLines;
					if (UIMenu_ListOffs < 0) {
						// Under last item
						UIMenu_Cur = (UIMenu_ListFiles-1) % UIMenu_FilesLines;
						UIMenu_ListOffs = (UIMenu_ListFiles-1) / UIMenu_FilesLines * UIMenu_FilesLines;
					}
				}
			}
			if (key == MINX_KEY_LEFT) {
				UIMenu_Cur -= UIMenu_FilesLines;
				if (UIMenu_Cur < 0) {
					// Under first line
					UIMenu_Cur = UIMenu_Lines-2;
					UIMenu_ListOffs -= UIMenu_FilesLines;
					if (UIMenu_ListOffs < 0) {
						// Under first item
						UIMenu_Cur = (UIMenu_ListFiles-1) % UIMenu_FilesLines;
						UIMenu_ListOffs = (UIMenu_ListFiles-1) / UIMenu_FilesLines * UIMenu_FilesLines;
					}
				}
			}
			if (key == MINX_KEY_RIGHT) {
				UIMenu_Cur += UIMenu_FilesLines;
				if ((UIMenu_ListOffs + UIMenu_Cur) >= UIMenu_ListFiles) {
					// Over last item
					UIMenu_Cur = 0;
					UIMenu_ListOffs += UIMenu_FilesLines;
					if (UIMenu_ListOffs >= UIMenu_ListFiles) {
						UIMenu_ListOffs = 0;
					}
				} else if (UIMenu_Cur >= UIMenu_FilesLines) {
					// Over last line
					UIMenu_Cur = 0;
					UIMenu_ListOffs += UIMenu_FilesLines;
					if (UIMenu_ListOffs >= UIMenu_ListFiles) UIMenu_ListOffs -= UIMenu_FilesLines;
				}
			}
		}
		if (key == MINX_KEY_B) {
			PokeMini_GotoExecDir();
			UIMenu_Page = UIPAGE_MENUITEMS;
			UIMenu_Cur = 1;
			return 1;
		}
		if (key == MINX_KEY_A) {
			if ((UIMenu_ListOffs + UIMenu_Cur) < UIMenu_ListFiles) {
				if (UIMenu_FileListCache[UIMenu_ListOffs + UIMenu_Cur].stats == 2) {
					// Load ROM
					PokeMini_GotoCurrentDir();
					strcpy(CommandLine.rom_dir, PokeMini_CurrDir);
					PokeMini_LoadROM(UIMenu_FileListCache[UIMenu_ListOffs + UIMenu_Cur].name);
					PokeMini_GotoExecDir();
					UIMenu_Page = UIPAGE_MENUITEMS;
					UIMenu_Cur = 1;
					UI_Status = UI_STATUS_GAME;
					return 1;
				} else {
					// Jump to directory
					UIMenu_GotoRelativeDir(UIMenu_FileListCache[UIMenu_ListOffs + UIMenu_Cur].name);
					UIMenu_Cur = 0;
					UIMenu_ListFiles = UIMenu_ReadDir(PokeMini_CurrDir);
					UIMenu_ListOffs = 0;
				}
			}
		}
	}

	// User Message
	if (UIMenu_Page == UIPAGE_MESSAGE) {
		if ((key == MINX_KEY_A) || (key == MINX_KEY_B)) {
			UIMenu_Page = UIPAGE_MENUITEMS;
			return 1;
		}
	}

	// Real-time text
	if (UIMenu_Page == UIPAGE_REALTIMETEXT) {
		if (UIMenu_CKeyMod && (key == MINX_KEY_A)) {
			UIMenu_Page = UIPAGE_MENUITEMS;
			UIRealtimeCB(0, NULL);
			return 1;
		}
	}

	return 1;
}

int UIMenu_Process(void)
{
	int res;
	if (UIMenu_InKey) {
		res = UIMenu_DoStuff(UIMenu_InKey);
		UIMenu_InKey = 0;
		return res;
	}
	return 1;
}

void UIMenu_Display_32(uint32_t *screen, int pitchW)
{
	int padd, i, j;
	char text[PMTMPV];

	if (UIMenu_Width >= 288) padd = 10;
	else padd = 8; // Padding need to be small for small resolutions

	// Draw background
	UIDraw_BG_32(screen, pitchW, UIMenu_BGImage, UIMenu_BGPal32, UIMenu_Width, UIMenu_Height);

	// Draw version
	UIDraw_String_32(screen, pitchW, UIMenu_Width - 48, 2, 8, PokeMini_VerShort, UI_Font1_Pal32);

	// Animate and do stuff
	UIMenu_Ani++;

	// Menu items
	if (UIMenu_Page == UIPAGE_MENUITEMS) {
		// Preview
		if (UI_PreviewDist) {
			PokeMini_VideoRect_32(screen, pitchW, UIMenu_Width - 100 - UI_PreviewDist, 16 + UI_PreviewDist, 100, 68, 0x00000000);
			PokeMini_VideoPreview_32(screen + ((18 + UI_PreviewDist) * pitchW) + (UIMenu_Width - 98 - UI_PreviewDist), pitchW, PokeMini_LCDMode);
		}

		// More...
		if ((UIMenu_CurrentItemsNum > UIMenu_MMax) && (UIMenu_Cur != (UIMenu_CurrentItemsNum-1))) {
			UIDraw_String_32(screen, pitchW, 16, 18 + UIMenu_MMax*12, 8, "...", UI_Font2_Pal32);
		}

		// List
		UIDraw_String_32(screen, pitchW, 4, 2, padd, UIMenu_CurrentItems[UIMenu_CurrentItemsNum].caption, UI_Font2_Pal32);
		for (i=0; i<UIMenu_MMax; i++) {
			j = i + UIMenu_MOff;
			if (j >= UIMenu_CurrentItemsNum) break;
			UIDraw_String_32(screen, pitchW, 16, 20 + (12 * i), padd, UIMenu_CurrentItems[j].caption, UIMenu_CurrentItems[j].code ? UI_Font2_Pal32 : UI_Font1_Pal32);
		}

		// Cursor
		UIDraw_Icon_32(screen, pitchW, 2, 20 + (UIMenu_Cur-UIMenu_MOff)*12, ((UIMenu_Ani>>2) & 3));

		// Loaded ROM
		sprintf(text, "ROM: %s", CommandLine.min_file);
		text[(UIMenu_Width/padd)-1] = 0; // Avoid string going out of the screen
		UIDraw_String_32(screen, pitchW, 2, 20 + (UIMenu_MMax+1)*12, padd, text, UI_Font1_Pal32);
	}

	// Load ROM
	if (UIMenu_Page == UIPAGE_LOADROM) {
		// Menu
		UIDraw_String_32(screen, pitchW, 4, 2, padd, "Load Rom", UI_Font2_Pal32);

		// Display current dir and parent
		UIText_Scroll(text, PokeMini_CurrDir, (UIMenu_Width/padd)-2, UIMenu_Ani>>4);
		UIDraw_String_32(screen, pitchW, 4, 20, padd, text, UI_Font2_Pal32);

		// Display files list
		for (i=0; i<(UIMenu_Lines-1); i++) {
			j = UIMenu_ListOffs + i;
			if (j < UIMenu_ListFiles) {
				UIDraw_Icon_32(screen, pitchW, 13, 32+(i*12), 4 + UIMenu_FileListCache[j].stats + UIMenu_FileListCache[j].color);
				UIText_Scroll(text, UIMenu_FileListCache[j].name, (UIMenu_Width/padd)-4, UIMenu_Ani>>4);
				UIDraw_String_32(screen, pitchW, 26, 32+(i*12), padd, text, UI_Font1_Pal32);
			}
		}

		// Cursor
		UIDraw_Icon_32(screen, pitchW, 2, 32 + UIMenu_Cur*12, ((UIMenu_Ani>>2) & 3));
	}

	// User Message
	if (UIMenu_Page == UIPAGE_MESSAGE) {
		// Menu
		UIDraw_String_32(screen, pitchW, 4, 2, padd, "Message", UI_Font2_Pal32);

		// Display all messages
		for (i=0; i<UIMenu_Lines; i++) {
			j = UIMenu_MsgOffset + i;
			if (j == UIMenu_MsgLines) break;
			UIDraw_String_32(screen, pitchW, 4, 20+(i*12), padd, UIMenu_FileListCache[j].name, UIMenu_FileListCache[j].color ? UI_Font2_Pal32 : UI_Font1_Pal32);
		}

		// Decrement timer to expire message
		if (UIMenu_MsgCountDw-- <= 0) {
			j = UIMenu_Lines + UIMenu_MsgOffset + 1;
			if (j > UIMenu_MsgLines) {
				UIMenu_MsgOffset = 0;
				UIMenu_MsgCountDw = UIMenu_MsgCountReset1;
			} else if (j == UIMenu_MsgLines) {
				UIMenu_MsgOffset++;
				UIMenu_MsgCountDw = UIMenu_MsgCountReset1;
			} else {
				UIMenu_MsgOffset++;
				UIMenu_MsgCountDw = UIMenu_MsgCountReset2;
			}
		}
		if (UIMenu_MsgTimer-- <= 0) {
			UIMenu_Page = UIPAGE_MENUITEMS;
		}
	}

	// Real-time text
	if (UIMenu_Page == UIPAGE_REALTIMETEXT) {
		// Menu
		UIDraw_String_32(screen, pitchW, 4, 2, padd, "Real-Time", UI_Font2_Pal32);

		// Refresh text
		i = 0;
		if (UIRealtimeCB) {
			for (i=0; i<UIMenu_Lines - 2; i++) {
				j = UIRealtimeCB(i, text);
				if (!j) break;
				UIDraw_String_32(screen, pitchW, 4, 32+(i*12), padd, text, UI_Font1_Pal32);
			}
		}

		UIDraw_String_32(screen, pitchW, 4, 44+(i*12), padd, "Press C+A to go back...", UI_Font2_Pal32);
	}
}

void UIMenu_Display_16(uint16_t *screen, int pitchW)
{
	int padd, i, j;
	char text[128];

	if (UIMenu_Width >= 288) padd = 10;
	else padd = 8; // Padding need to be small for small resolutions

	// Draw background
	UIDraw_BG_16(screen, pitchW, UIMenu_BGImage, UIMenu_BGPal16, UIMenu_Width, UIMenu_Height);

	// Draw version
	UIDraw_String_16(screen, pitchW, UIMenu_Width - 48, 2, 8, PokeMini_VerShort, UI_Font1_Pal16);

	// Animate and do stuff
	UIMenu_Ani++;

	// Menu items
	if (UIMenu_Page == UIPAGE_MENUITEMS) {
		// Preview
		if (UI_PreviewDist) {
			PokeMini_VideoRect_16(screen, pitchW, UIMenu_Width - 100 - UI_PreviewDist, 16 + UI_PreviewDist, 100, 68, 0x00000000);
			PokeMini_VideoPreview_16(screen + ((18 + UI_PreviewDist) * pitchW) + (UIMenu_Width - 98 - UI_PreviewDist), pitchW, PokeMini_LCDMode);
		}

		// More...
		if ((UIMenu_CurrentItemsNum > UIMenu_MMax) && (UIMenu_Cur != (UIMenu_CurrentItemsNum-1))) {
			UIDraw_String_16(screen, pitchW, 16, 18 + UIMenu_MMax*12, 8, "...", UI_Font2_Pal16);
		}

		// List
		UIDraw_String_16(screen, pitchW, 4, 2, padd, UIMenu_CurrentItems[UIMenu_CurrentItemsNum].caption, UI_Font2_Pal16);
		for (i=0; i<UIMenu_MMax; i++) {
			j = i + UIMenu_MOff;
			if (j >= UIMenu_CurrentItemsNum) break;
			UIDraw_String_16(screen, pitchW, 16, 20 + (12 * i), padd, UIMenu_CurrentItems[j].caption, UIMenu_CurrentItems[j].code ? UI_Font2_Pal16 : UI_Font1_Pal16);
		}

		// Cursor
		UIDraw_Icon_16(screen, pitchW, 2, 20 + (UIMenu_Cur-UIMenu_MOff)*12, ((UIMenu_Ani>>2) & 3));

		// Loaded ROM
		sprintf(text, "ROM: %s", CommandLine.min_file);
		text[(UIMenu_Width/padd)-1] = 0; // Avoid string going out of the screen
		UIDraw_String_16(screen, pitchW, 2, 20 + (UIMenu_MMax+1)*12, padd, text, UI_Font1_Pal16);
	}

	// Load ROM
	if (UIMenu_Page == UIPAGE_LOADROM) {
		// Menu
		UIDraw_String_16(screen, pitchW, 4, 2, padd, "Load ROM", UI_Font2_Pal16);

		// Display current dir and parent
		UIText_Scroll(text, PokeMini_CurrDir, (UIMenu_Width/padd)-2, UIMenu_Ani>>4);
		UIDraw_String_16(screen, pitchW, 4, 20, padd, text, UI_Font2_Pal16);

		// Display files list
		for (i=0; i<(UIMenu_Lines-1); i++) {
			j = UIMenu_ListOffs + i;
			if (j < UIMenu_ListFiles) {
				UIDraw_Icon_16(screen, pitchW, 13, 32+(i*12), 4 + UIMenu_FileListCache[j].stats + UIMenu_FileListCache[j].color);
				UIText_Scroll(text, UIMenu_FileListCache[j].name, (UIMenu_Width/padd)-4, UIMenu_Ani>>4);
				UIDraw_String_16(screen, pitchW, 26, 32+(i*12), padd, text, UI_Font1_Pal16);
			}
		}
		// Cursor
		UIDraw_Icon_16(screen, pitchW, 2, 32 + UIMenu_Cur*12, ((UIMenu_Ani>>2) & 3));
	}

	// User Message
	if (UIMenu_Page == UIPAGE_MESSAGE) {
		// Menu
		UIDraw_String_16(screen, pitchW, 4, 2, padd, "Message", UI_Font2_Pal16);

		// Display all messages
		for (i=0; i<UIMenu_Lines; i++) {
			j = UIMenu_MsgOffset + i;
			if (j == UIMenu_MsgLines) break;
			UIDraw_String_16(screen, pitchW, 4, 20+(i*12), padd, UIMenu_FileListCache[j].name, UIMenu_FileListCache[j].color ? UI_Font2_Pal16 : UI_Font1_Pal16);
		}

		// Decrement timer to expire message
		if (UIMenu_MsgCountDw-- <= 0) {
			j = UIMenu_Lines + UIMenu_MsgOffset + 1;
			if (j > UIMenu_MsgLines) {
				UIMenu_MsgOffset = 0;
				UIMenu_MsgCountDw = UIMenu_MsgCountReset1;
			} else if (j == UIMenu_MsgLines) {
				UIMenu_MsgOffset++;
				UIMenu_MsgCountDw = UIMenu_MsgCountReset1;
			} else {
				UIMenu_MsgOffset++;
				UIMenu_MsgCountDw = UIMenu_MsgCountReset2;
			}
		}
		if (UIMenu_MsgTimer-- <= 0) {
			UIMenu_Page = UIPAGE_MENUITEMS;
		}
	}

	// Real-time text
	if (UIMenu_Page == UIPAGE_REALTIMETEXT) {
		// Menu
		UIDraw_String_16(screen, pitchW, 4, 2, padd, "Real-Time", UI_Font2_Pal16);

		// Refresh text
		i = 0;
		if (UIRealtimeCB) {
			for (i=0; i<UIMenu_Lines - 2; i++) {
				j = UIRealtimeCB(i, text);
				if (!j) break;
				UIDraw_String_16(screen, pitchW, 4, 32+(i*12), padd, text, UI_Font1_Pal16);
			}
		}

		UIDraw_String_16(screen, pitchW, 4, 44+(i*12), padd, "Press C+A to go back...", UI_Font2_Pal16);
	}
}

void UIMenu_SaveEEPDisplay_32(uint32_t *screen, int pitchW)
{
	PokeMini_VideoRect_32(screen, pitchW, 0, 0, UIMenu_Width, UIMenu_Height, 0xFFFFFFFF);
	UIDraw_String_32(screen, pitchW, 4, 8, 10, "Saving EEPROM", UI_Font2_Pal32);
	UIDraw_String_32(screen, pitchW, 4, 24, 10, "Please stand by...", UI_Font1_Pal32);
}

void UIMenu_SaveEEPDisplay_16(uint16_t *screen, int pitchW)
{
	PokeMini_VideoRect_16(screen, pitchW, 0, 0, UIMenu_Width, UIMenu_Height, 0xFFFF);
	UIDraw_String_16(screen, pitchW, 4, 8, 10, "Saving EEPROM", UI_Font2_Pal16);
	UIDraw_String_16(screen, pitchW, 4, 24, 10, "Please stand by...", UI_Font1_Pal16);
}
