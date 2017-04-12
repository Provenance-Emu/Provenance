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
#include "SDL.h"

#include "PokeMini.h"
#include "Hardware.h"
#include "Joystick.h"

#include "Video_x3.h"
#include "PokeMini_BG3.h"

const char *AppName = "PokeMini " PokeMini_Version " WIZ (SDL Lib)";

// Sound buffer size
#define SOUNDBUFFER	2048
#define PMSOUNDBUFF	(SOUNDBUFFER*2)

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

// Platform menu (REQUIRED >= 0.4.4)
int UIItems_PlatformC(int index, int reason);
TUIMenu_Item UIItems_Platform[] = {
	PLATFORMDEF_GOBACK,
	{ 0,  9, "Define Joystick...", UIItems_PlatformC },
	PLATFORMDEF_SAVEOPTIONS,
	PLATFORMDEF_END(UIItems_PlatformC)
};
int UIItems_PlatformC(int index, int reason)
{
	if (reason == UIMENU_OK) reason = UIMENU_RIGHT;
	if (reason == UIMENU_CANCEL) UIMenu_PrevMenu();
	if (reason == UIMENU_RIGHT) {
		if (index == 9) JoystickEnterMenu();
	}
	return 1;
}

// For the emulator loop and video
int emurunning = 1;
SDL_Surface *screen;
int PixPitch, ScOffP;

// WIZ Joystick Keys
#define WIZ_BUTTON_UP              (0)
#define WIZ_BUTTON_UPLEFT          (1)
#define WIZ_BUTTON_LEFT            (2)
#define WIZ_BUTTON_DOWNLEFT        (3)
#define WIZ_BUTTON_DOWN            (4)
#define WIZ_BUTTON_DOWNRIGHT       (5)
#define WIZ_BUTTON_RIGHT           (6)
#define WIZ_BUTTON_UPRIGHT         (7)
#define WIZ_BUTTON_MENU            (8)
#define WIZ_BUTTON_SELECT          (9)
#define WIZ_BUTTON_L               (10)
#define WIZ_BUTTON_R               (11)
#define WIZ_BUTTON_A               (12)
#define WIZ_BUTTON_B               (13)
#define WIZ_BUTTON_X               (14)
#define WIZ_BUTTON_Y               (15)
#define WIZ_BUTTON_VOLUP           (16)
#define WIZ_BUTTON_VOLDOWN         (17)
#define WIZ_BUTTON_CLICK           (18)

// Handle keyboard and quit events
void handleevents(SDL_Event *event)
{
	switch (event->type) {
	case SDL_JOYBUTTONDOWN:
		if (event->jbutton.button < 16) JoystickButtonsEvent(event->jbutton.button, 1);
		break;
	case SDL_JOYBUTTONUP:
		if (event->jbutton.button < 16) JoystickButtonsEvent(event->jbutton.button, 0);
		break;
	case SDL_QUIT:
		emurunning = 0;
		break;
	};
}

// Used to fill the sound buffer
void emulatorsound(void *unused, Uint8 *stream, int len)
{
	MinxAudio_GetSamplesU8(stream, len);
}

// Enable / Disable sound
void enablesound(int sound)
{
	MinxAudio_ChangeEngine(sound);
	if (AudioEnabled) SDL_PauseAudio(!sound);
}

// Menu loop
void menuloop()
{
	SDL_Event event;

	// Stop sound
	SDL_EnableKeyRepeat(SDL_DEFAULT_REPEAT_DELAY, SDL_DEFAULT_REPEAT_INTERVAL);
	enablesound(0);

	// Update EEPROM
	PokeMini_SaveFromCommandLines(0);

	// Menu's loop
	while (emurunning && (UI_Status == UI_STATUS_MENU)) {
		// Slowdown to approx. 60fps
		SDL_Delay(16);

		// Process UI
		UIMenu_Process();

		// Screen rendering
		SDL_FillRect(screen, NULL, 0);
		if (SDL_LockSurface(screen) == 0) {
			// Render the menu or the game screen
			UIMenu_Display_16((uint16_t *)screen->pixels + ScOffP, PixPitch);

			// Unlock surface
			SDL_UnlockSurface(screen);
			SDL_Flip(screen);
		}

		// Handle events
		while (SDL_PollEvent(&event)) handleevents(&event);
	}

	// Apply configs
	PokeMini_ApplyChanges();
	if (UI_Status == UI_STATUS_EXIT) emurunning = 0;
	else enablesound(CommandLine.sound);
	SDL_EnableKeyRepeat(0, 0);
}

// Main function
int main(int argc, char **argv)
{
	SDL_Joystick *joy;
	SDL_Event event;

	// Process arguments
	printf("%s\n\n", AppName);
	PokeMini_InitDirs(argv[0], NULL);
	CommandLineInit();
	CommandLineConfFile("pokemini.cfg", NULL, NULL);
	if (!CommandLineArgs(argc, argv, NULL)) {
		PrintHelpUsage(stdout);
		return 1;
	}
	JoystickSetup("WIZ", 0, 0, WIZ_KeysNames, 16, WIZ_KeysMapping);

	// Initialize SDL
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK) < 0) {
		fprintf(stderr, "Couldn't initialize SDL: %s\n", SDL_GetError());
		exit(1);
	}
	joy = SDL_JoystickOpen(0);
	atexit(SDL_Quit); // Clean up on exit

	// Set video spec and check if is supported
	if (!PokeMini_SetVideo((TPokeMini_VideoSpec *)&PokeMini_Video3x3, 16, CommandLine.lcdfilter, CommandLine.lcdmode)) {
		fprintf(stderr, "Couldn't set video spec\n");
		exit(1);
	}
	UIMenu_SetDisplay(288, 192, PokeMini_BGR16, (uint8_t *)PokeMini_BG3, (uint16_t *)PokeMini_BG3_PalBGR16, (uint32_t *)PokeMini_BG3_PalBGR32);

	// Initialize the display
	screen = SDL_SetVideoMode(320, 240, 16, SDL_SWSURFACE); // SDL_HWSURFACE | SDL_DOUBLEBUF
	if (screen == NULL) {
		fprintf(stderr, "Couldn't set video mode: %s\n", SDL_GetError());
		exit(1);
	}
	PixPitch = screen->pitch / 2;
	ScOffP = (24 * PixPitch) + 16;

	// Initialize the sound
	SDL_AudioSpec audfmt;
	audfmt.freq = 44100;
	audfmt.format = AUDIO_U8;
	audfmt.channels = 1;
	audfmt.samples = SOUNDBUFFER;
	audfmt.callback = emulatorsound;
	audfmt.userdata = NULL;

	// Open the audio device
	if (SDL_OpenAudio(&audfmt, NULL) < 0) {
		fprintf(stderr, "Unable to open audio: %s\n", SDL_GetError());
		fprintf(stderr, "Audio will be disabled\n");
		AudioEnabled = 0;
	} else {
		AudioEnabled = 1;
	}

	// Disable key repeat and hide cursor
	SDL_EnableKeyRepeat(0, 0);
	SDL_ShowCursor(SDL_DISABLE);

	// Initialize the emulator
	printf("Starting emulator...\n");
	if (!PokeMini_Create(0, PMSOUNDBUFF)) {
		fprintf(stderr, "Error while initializing emulator.\n");
	}

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
	unsigned long time, NewTickSync = 0;
	while (emurunning) {
		// Emulate and syncronize
		if (RequireSoundSync) {
			PokeMini_EmulateFrame();
			// Sleep a little in the hope to free a few samples
			while (MinxAudio_SyncWithAudio()) SDL_Delay(1);
		} else {
			time = SDL_GetTicks();
			PokeMini_EmulateFrame();
			do {
				SDL_Delay(1);		// This lower CPU usage
				time = SDL_GetTicks();
			} while (time < NewTickSync);
			NewTickSync = time + 13;	// Aprox 72 times per sec
		}

		// Screen rendering
		SDL_FillRect(screen, NULL, 0);
		if (SDL_LockSurface(screen) == 0) {
			// Render the menu or the game screen
			if (PokeMini_Rumbling) {
				PokeMini_VideoBlit((uint16_t *)screen->pixels + ScOffP + PokeMini_GenRumbleOffset(PixPitch), PixPitch);
			} else {
				PokeMini_VideoBlit((uint16_t *)screen->pixels + ScOffP, PixPitch);
			}
			LCDDirty = 0;

			// Unlock surface
			SDL_UnlockSurface(screen);
			SDL_Flip(screen);
		}

		// Handle events
		while (SDL_PollEvent(&event)) handleevents(&event);

		// Menu
		if (UI_Status == UI_STATUS_MENU) menuloop();
	}

	// Disable sound & free UI
	enablesound(0);
	UIMenu_Destroy();

	// Save Stuff
	PokeMini_SaveFromCommandLines(1);

	// Close joystick
	if (joy) SDL_JoystickClose(joy);

	// Terminate...
	printf("Shutdown emulator...\n");
	PokeMini_VideoPalette_Free();
	PokeMini_Destroy();

	return 0;
}

