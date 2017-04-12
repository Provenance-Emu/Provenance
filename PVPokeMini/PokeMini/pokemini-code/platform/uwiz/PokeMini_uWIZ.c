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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <libuwiz.h>

#include "PokeMini.h"
#include "Hardware.h"
#include "Joystick.h"

#include "Video_x3.h"
#include "PokeMini_BG3.h"

const char *AppName = "PokeMini " PokeMini_Version " WIZ (uWIZ Lib)";

// Fragments
#define FSOUNDBUFFER	4
// Block size in bits
#define BSOUNDBUFFER	12
// PM sound buffer size
#define PMSNDBUFFER	8192

// --------

// Joystick names and mapping (NEW IN 0.5.0)
char *WIZ_KeysNames[] = {
	"Off",		// -1
	"Up",		// 0
	"Unused 1",	// 1
	"Left",		// 2
	"Unused 2",	// 3
	"Down",		// 4
	"Unused 3",	// 5
	"Right",	// 6
	"Unused 4",	// 7
	"Menu",		// 8
	"Select",	// 9
	"L",		// 10
	"R",		// 11
	"A",		// 12
	"B",		// 13
	"X",		// 14
	"Y"		// 15
};
int WIZ_KeysMapping[] = {
	8,		// Menu
	13,		// A
	14,		// B
	11,		// C
	0,		// Up
	4,		// Down
	2,		// Left
	6,		// Right
	9,		// Power
	10		// Shake
};

// Custom command line (NEW IN 0.5.0)
int clc_fpscounter = 1;
const TCommandLineCustom CustomConf[] = {
	{ "fpscounter", &clc_fpscounter, COMMANDLINE_BOOL },
	{ "", NULL, COMMANDLINE_EOL }
};

// Platform menu (REQUIRED >= 0.4.4)
int UIItems_PlatformC(int index, int reason);
TUIMenu_Item UIItems_Platform[] = {
	PLATFORMDEF_GOBACK,
	{ 0,  1, "FPS Counter: %s", UIItems_PlatformC },
	{ 0,  9, "Define Joystick...", UIItems_PlatformC },
	PLATFORMDEF_SAVEOPTIONS,
	PLATFORMDEF_END(UIItems_PlatformC)
};
int UIItems_PlatformC(int index, int reason)
{
	if (reason == UIMENU_OK) {
		reason = UIMENU_RIGHT;
	}
	if (reason == UIMENU_CANCEL) {
		UIMenu_PrevMenu();
	}
	if (reason == UIMENU_LEFT) {
		switch (index) {
			case 1: // FPS Counter
				clc_fpscounter = !clc_fpscounter;
				break;
		}
	}
	if (reason == UIMENU_RIGHT) {
		switch (index) {
			case 1: // FPS Counter
				clc_fpscounter = !clc_fpscounter;
				break;
			case 9: // Define joystick
				JoystickEnterMenu();
				break;
		}
	}
	UIMenu_ChangeItem(UIItems_Platform, 1, "FPS Counter: %s", clc_fpscounter ? "Yes" : "No");
	return 1;
}

// For the emulator loop and video
int emurunning = 1;
uint16_t *VIDEO;

// Handle keys
void HandleKeys()
{
	uint32_t keys;
	uWIZ_scankeys();
	keys = uWIZ_keysheld();
	if (UI_Status) keys = uWIZ_keysdownrepeat();	// Allow key repeat inside menu
	JoystickBitsEvent(keys);
}

// Used to fill the sound buffer
void sound_callback(signed short *sound, int samples)
{
	MinxAudio_GetSamplesS16((int16_t *)sound, samples);
	uWIZ_yieldthread();
}

// Enable / Disable sound
void enablesound(int sound)
{
	MinxAudio_ChangeEngine(sound);
	// Enable asyncronous sound filling (using a thread)
	if (!uWIZ_soundenable(sound, (uWIZ_soundcallback)sound_callback)) {
		fprintf(stderr, "Sound async failed.\n");
	}
}

// Menu loop
void menuloop()
{
	// Stop sound
	enablesound(0);

	// Update EEPROM
	PokeMini_SaveFromCommandLines(0);

	// Menu's loop
	uWIZ_fillscreen(0x0000);
	while (emurunning && (UI_Status == UI_STATUS_MENU)) {
		// Slowdown to approx. 60fps
		uWIZ_simulatevsync(uWIZ_60fps);

		// Handle keys
		HandleKeys();

		// Process UI
		UIMenu_Process();

		// Screen rendering
		UIMenu_Display_16((uint16_t *)VIDEO, 320);

		// Render to screen
		uWIZ_render();
	}

	// Apply configs
	PokeMini_ApplyChanges();
	if (UI_Status == UI_STATUS_EXIT) emurunning = 0;
	else enablesound(CommandLine.sound);
}

// Main function
int main(int argc, char **argv)
{
	int fpscnt = 0, currtick = 0, nexttick = 0;
	char fpsstr[16];
	int battimeout = 0;
	int err;

	// Process arguments
	printf("%s\n\n", AppName);
	PokeMini_InitDirs(argv[0], NULL);
	CommandLineInit();
	CommandLine.low_battery = 2;	// libuwiz can report battery status
	CommandLineConfFile("pokemini.cfg", "pokemini_uwiz.cfg", CustomConf);
	if (!CommandLineArgs(argc, argv, NULL)) {
		PrintHelpUsage(stdout);
		return 1;
	}
	JoystickSetup("WIZ", 0, 0, WIZ_KeysNames, 16, WIZ_KeysMapping);

	// Initialize lib
	if ((err = uWIZ_init()) < 0) {
		fprintf(stderr, "Error %d.\n", err);
		exit(1);
	}
	VIDEO = uWIZ_fb16 + (24 * 320) + 16;
	uWIZ_setrepeat(30, 8);

	// Set video spec and check if is supported
	if (!PokeMini_SetVideo((TPokeMini_VideoSpec *)&PokeMini_Video3x3, 16, CommandLine.lcdfilter, CommandLine.lcdmode)) {
		fprintf(stderr, "Couldn't set video spec\n");
		exit(1);
	}
	UIMenu_SetDisplay(288, 192, PokeMini_BGR16, (uint8_t *)PokeMini_BG3, (uint16_t *)PokeMini_BG3_PalBGR16, (uint32_t *)PokeMini_BG3_PalBGR32);

	// Setup 44Khz Mono (Output is always Signed 16-Bits)
	if (!uWIZ_soundsetup(44100, 1, FSOUNDBUFFER, BSOUNDBUFFER)) {	// Setup sound
		fprintf(stderr, "Sound setup failed.\n");
	}
	uWIZ_setvolume(64);
	uWIZ_autovolume(1);

	// Create emulator and load test roms
	printf("Starting emulator...\n");
	PokeMini_Create(POKEMINI_AUTOBATT, PMSNDBUFFER);

	// Setup palette and LCD mode
	PokeMini_VideoPalette_Init(PokeMini_BGR16, 1);
	PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
	PokeMini_ApplyChanges();

	// Load stuff
	PokeMini_UseDefaultCallbacks();
	if (!PokeMini_LoadFromCommandLines("Using FreeBIOS", "EEPROM data will be discarded!")) {
		UI_Status = UI_STATUS_MENU;
	}

	// Enable sound & init UI
	printf("Starting emulator...\n");
	UIMenu_Init();
	enablesound(CommandLine.sound);

	// Emulator's loop
	while (emurunning) {
		// Emulate and syncronize
		if (RequireSoundSync) {
			PokeMini_EmulateFrame();
			// Sleep a little in the hope to free a few samples
			while (MinxAudio_SyncWithAudio()) uWIZ_yieldthread();
		} else {
			PokeMini_EmulateFrame();
			uWIZ_simulatevsync(1000000/72);	// Aprox 72 times per sec
		}

		// Screen rendering
		uWIZ_fillscreen(0x0000);
		if (PokeMini_Rumbling) {
			PokeMini_VideoBlit((uint16_t *)VIDEO + PokeMini_GenRumbleOffset(320), 320);
		} else {
			PokeMini_VideoBlit((uint16_t *)VIDEO, 320);
		}

		LCDDirty = 0;

		// FPS counter
		if (clc_fpscounter) {
			currtick = uWIZ_getticks32();
			if (currtick >= nexttick) {
				nexttick = currtick + 1000;
				sprintf(fpsstr, "%3d fps", fpscnt);
				fpscnt = 0;
			} else fpscnt++;
			uWIZ_basprint(12, 8, 0xFFFF, fpsstr);
		}

		// Handle keys
		HandleKeys();

		// Render to screen
		uWIZ_render();

		// Menu
		if (UI_Status == UI_STATUS_MENU) menuloop();

		// Check battery
		if (battimeout <= 0) {
			PokeMini_LowPower(uWIZ_getbatterylevel() >= uWIZ_BATT_LOW);
			battimeout = 600;
		}
	}

	// Stop sound & free UI
	enablesound(0);
	UIMenu_Destroy();

	// Disable async. filling
	uWIZ_soundenable(0, NULL);

	// Save Stuff
	PokeMini_SaveFromCommandLines(1);

	// Terminate...
	printf("Shutdown emulator...\n");
	PokeMini_VideoPalette_Free();
	PokeMini_Destroy();

	// Close lib
	uWIZ_end();

	return 0;
}
