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
#include "Keyboard.h"
#include "KeybMapSDL.h"

#include "Video_x4.h"
#include "PokeMini_BG4.h"

const char *AppName = "PokeMini " PokeMini_Version " uSDL";

int emurunning = 1;
SDL_Surface *screen;
int PixPitch;

// Sound buffer size
#define SOUNDBUFFER	2048
#define PMSOUNDBUFF	(SOUNDBUFFER*2)

// Platform menu (REQUIRED >= 0.4.4)
TUIMenu_Item UIItems_Platform[] = {
	PLATFORMDEF_GOBACK,
	PLATFORMDEF_SAVEOPTIONS,
	PLATFORMDEF_END(UIItems_PlatformDefC)
};

// Handle keyboard and quit events
void handleevents(SDL_Event *event)
{
	switch (event->type) {
	case SDL_KEYDOWN:
		KeyboardPressEvent(event->key.keysym.sym);
		break;
	case SDL_KEYUP:
		KeyboardReleaseEvent(event->key.keysym.sym);
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

	// Update window's title and stop sound
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
		if (SDL_LockSurface(screen) == 0) {
			// Render the menu or the game screen
			UIMenu_Display_16((uint16_t *)screen->pixels, PixPitch);

			// Unlock surface
			SDL_UnlockSurface(screen);
			SDL_Flip(screen);
		}

		// Handle events
		while(SDL_PollEvent(&event)) handleevents(&event);
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
	SDL_Event event;
	static int rumbleani = 0;

	// Process arguments
	printf("%s\n\n", AppName);
	PokeMini_InitDirs(argv[0], NULL);
	CommandLineInit();
	CommandLineConfFile("pokemini.cfg", NULL, NULL);
	if (!CommandLineArgs(argc, argv, NULL)) {
		PrintHelpUsage(stdout);
		return 1;
	}

	// Initialize SDL
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0) {
		fprintf(stderr, "Couldn't initialize SDL: %s\n", SDL_GetError());
		exit(1);
	}
	atexit(SDL_Quit); // Clean up on exit

	// Set video spec and check if is supported
	if (!PokeMini_SetVideo((TPokeMini_VideoSpec *)&PokeMini_Video4x4, 16, CommandLine.lcdfilter, CommandLine.lcdmode)) {
		fprintf(stderr, "Couldn't set video spec\n");
		exit(1);
	}
	UIMenu_SetDisplay(384, 256, PokeMini_BGR16, (uint8_t *)PokeMini_BG4, (uint16_t *)PokeMini_BG4_PalBGR16, (uint32_t *)PokeMini_BG4_PalBGR32);

	// Initialize the display
	screen = SDL_SetVideoMode(96*4, 64*4, 16, SDL_HWSURFACE | SDL_DOUBLEBUF);
	if (screen == NULL) {
		fprintf(stderr, "Couldn't set video mode: %s\n", SDL_GetError());
		exit(1);
	}
	PixPitch = screen->pitch / 2;

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

	// Set the window manager title bar
	SDL_WM_SetCaption(AppName, "PMEWindow");
	SDL_EnableKeyRepeat(0, 0);

	// Initialize the emulator
	printf("Starting emulator...\n");
	if (!PokeMini_Create(0, PMSOUNDBUFF)) {
		fprintf(stderr, "Error while initializing emulator.\n");
		return 1;
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

	// Enable sound and init UI
	printf("Running emulator...\n");
	UIMenu_Init();
	KeyboardRemap(&KeybMapSDL);
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
		if (SDL_LockSurface(screen) == 0) {
			// Render the menu or the game screen
			PokeMini_VideoBlit(screen->pixels, PixPitch);

			// When rumbling, show rumble text
			if (PokeMini_RumblingLatch) {
				rumbleani++;
				UIDraw_String_16((uint16_t *)screen->pixels, PixPitch, 96*4-96, 64*4-24 + ((rumbleani>>2) & 1), 12, "Rubling", ((rumbleani>>2) & 1) ? UI_Font1_Pal16 : UI_Font2_Pal16);
				PokeMini_RumblingLatch = 0;
			}

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

	// Terminate...
	printf("Shutdown emulator...\n");
	PokeMini_VideoPalette_Free();
	PokeMini_Destroy();

	return 0;
}
