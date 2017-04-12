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
#include <SDL/SDL.h>

#include "PokeMini.h"
#include "Hardware.h"
#include "Joystick.h"

#include "UI.h"
#include "Video_x3.h"
#include "PokeMini_BG3.h"

const char *AppName = "PokeMini " PokeMini_Version " Dingux";

// Sound buffer size
#define SOUNDBUFFER	2048
#define PMSOUNDBUFF	(SOUNDBUFFER*2)

// --------

// Joystick names and mapping (NEW IN 0.5.0)
char *Joy_KeysNames[] = {
	"Off",		// -1
	"Select",	// 0
	"Start",	// 1
	"Up",		// 2
	"Down",		// 3
	"Left",		// 4
	"Right",	// 5
	"A",		// 6
	"B",		// 7
	"X",		// 8
	"Y",		// 9
	"L",		// 10
	"R"		// 11
};
int Joy_KeysMapping[] = {
	0,		// Menu
	6,		// A
	7,		// B
	11,		// C
	2,		// Up
	3,		// Down
	4,		// Left
	5,		// Right
	1,		// Power
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

// Handle keyboard and quit events
void handleevents(SDL_Event *event)
{
	switch (event->type) {
	case SDL_KEYDOWN:
		if (event->key.keysym.sym == SDLK_ESCAPE) {		// Dingoo Select
			JoystickButtonsEvent(0, 1);
		} else if (event->key.keysym.sym == SDLK_RETURN) {	// Dingoo Start
			JoystickButtonsEvent(1, 1);
		} else if (event->key.keysym.sym == SDLK_UP) {		// Dingoo Up
			JoystickButtonsEvent(2, 1);
		} else if (event->key.keysym.sym == SDLK_DOWN) {	// Dingoo Down
			JoystickButtonsEvent(3, 1);
		} else if (event->key.keysym.sym == SDLK_LEFT) {	// Dingoo Left
			JoystickButtonsEvent(4, 1);
		} else if (event->key.keysym.sym == SDLK_RIGHT) {	// Dingoo Right
			JoystickButtonsEvent(5, 1);
		} else if (event->key.keysym.sym == SDLK_LCTRL) {	// Dingoo A
			JoystickButtonsEvent(6, 1);
		} else if (event->key.keysym.sym == SDLK_LALT) {	// Dingoo B
			JoystickButtonsEvent(7, 1);
		} else if (event->key.keysym.sym == SDLK_SPACE) {	// Dingoo X
			JoystickButtonsEvent(8, 1);
		} else if (event->key.keysym.sym == SDLK_LSHIFT) {	// Dingoo Y
			JoystickButtonsEvent(9, 1);
		} else if (event->key.keysym.sym == SDLK_TAB) {		// Dingoo L
			JoystickButtonsEvent(10, 1);
		} else if (event->key.keysym.sym == SDLK_BACKSPACE) {	// Dingoo R
			JoystickButtonsEvent(11, 1);
		}
		break;
	case SDL_KEYUP:
		if (event->key.keysym.sym == SDLK_ESCAPE) {		// Dingoo Select
			JoystickButtonsEvent(0, 0);
		} else if (event->key.keysym.sym == SDLK_RETURN) {	// Dingoo Start
			JoystickButtonsEvent(1, 0);
		} else if (event->key.keysym.sym == SDLK_UP) {		// Dingoo Up
			JoystickButtonsEvent(2, 0);
		} else if (event->key.keysym.sym == SDLK_DOWN) {	// Dingoo Down
			JoystickButtonsEvent(3, 0);
		} else if (event->key.keysym.sym == SDLK_LEFT) {	// Dingoo Left
			JoystickButtonsEvent(4, 0);
		} else if (event->key.keysym.sym == SDLK_RIGHT) {	// Dingoo Right
			JoystickButtonsEvent(5, 0);
		} else if (event->key.keysym.sym == SDLK_LCTRL) {	// Dingoo A
			JoystickButtonsEvent(6, 0);
		} else if (event->key.keysym.sym == SDLK_LALT) {	// Dingoo B
			JoystickButtonsEvent(7, 0);
		} else if (event->key.keysym.sym == SDLK_SPACE) {	// Dingoo X
			JoystickButtonsEvent(8, 0);
		} else if (event->key.keysym.sym == SDLK_LSHIFT) {	// Dingoo Y
			JoystickButtonsEvent(9, 0);
		} else if (event->key.keysym.sym == SDLK_TAB) {		// Dingoo L
			JoystickButtonsEvent(10, 0);
		} else if (event->key.keysym.sym == SDLK_BACKSPACE) {	// Dingoo R
			JoystickButtonsEvent(11, 0);
		}
		break;
	case SDL_QUIT:
		emurunning = 0;
		break;
	};
}

// Used to fill the sound buffer
void emulatorsound(void *unused, Uint8 *stream, int len)
{
	MinxAudio_GetSamplesS16((int16_t *)stream, len>>1);
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
	JoystickSetup("Dingoo", 0, 30000, Joy_KeysNames, 12, Joy_KeysMapping);

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
	audfmt.format = AUDIO_S16;
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

