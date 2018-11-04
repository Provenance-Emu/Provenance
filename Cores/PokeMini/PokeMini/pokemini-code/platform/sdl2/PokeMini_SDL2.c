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
#include "ExportBMP.h"
#include "ExportWAV.h"
#include "Joystick.h"
#include "Keyboard.h"
#include "KeybMapSDL2.h"

#include "Video_x1.h"
#include "Video_x2.h"
#include "Video_x3.h"
#include "Video_x4.h"
#include "Video_x5.h"
#include "Video_x6.h"
#include "PokeMini_BG2.h"
#include "PokeMini_BG3.h"
#include "PokeMini_BG4.h"
#include "PokeMini_BG5.h"
#include "PokeMini_BG6.h"

const char *AppName = "PokeMini " PokeMini_Version " SDL2";

int emurunning = 1, emulimiter = 1;
SDL_Surface *screen;
SDL_Window *window;
SDL_Texture *texture;
SDL_Renderer *renderer;
SDL_Joystick *joystick = NULL;
SDL_Haptic *haptic = NULL;
int PMWidth, PMHeight;
int PMOffX, PMOffY, UIOffX, UIOffY;

FILE *sdump;
void setup_screen();

// Sound buffer size
#define SOUNDBUFFER	2048
#define PMSNDBUFFER	(SOUNDBUFFER*4)

const char *clc_zoom_txt[] = {
	"0x (Illegal)",
	"1x ( 96x 64)",
	"2x (192x128)",
	"3x (288x192)",
	"4x (384x256)",
	"5x (480x320)",
	"6x (576x384)",
};

// Custom command line
int clc_zoom = 4, clc_bpp = 16, clc_fullscreen = 0;
char clc_dump_sound[PMTMPV] = {0};
int clc_displayfps = 0;
const TCommandLineCustom CustomArgs[] = {
	{ "-dumpsound", (int *)&clc_dump_sound, COMMANDLINE_STR, PMTMPV-1 },
	{ "-zoom", &clc_zoom, COMMANDLINE_INT, 1, 6 },
	{ "-bpp", &clc_bpp, COMMANDLINE_INT, 16, 32 },
	{ "-windowed", &clc_fullscreen, COMMANDLINE_INTSET, 0 },
	{ "-fullscreen", &clc_fullscreen, COMMANDLINE_INTSET, 1 },
	{ "-displayfps", &clc_displayfps, COMMANDLINE_INTSET, 1 },
	{ "", NULL, COMMANDLINE_EOL }
};
const TCommandLineCustom CustomConf[] = {
	{ "zoom", &clc_zoom, COMMANDLINE_INT, 1, 6 },
	{ "bpp", &clc_bpp, COMMANDLINE_INT, 16, 32 },
	{ "fullscreen", &clc_fullscreen, COMMANDLINE_BOOL },
	{ "displayfps", &clc_displayfps, COMMANDLINE_BOOL },
	{ "", NULL, COMMANDLINE_EOL }
};

// Platform menu
int UIItems_PlatformC(int index, int reason);
TUIMenu_Item UIItems_Platform[] = {
	PLATFORMDEF_GOBACK,
	{ 0,  1, "Zoom: %s", UIItems_PlatformC },
	{ 0,  2, "Depth: %dbpp", UIItems_PlatformC },
	{ 0,  3, "Fullscreen: %s", UIItems_PlatformC },
	{ 0,  4, "Display FPS: %s", UIItems_PlatformC },
	{ 0,  8, "Define Joystick...", UIItems_PlatformC },
	{ 0,  9, "Define Keyboard...", UIItems_PlatformC },
	PLATFORMDEF_SAVEOPTIONS,
	PLATFORMDEF_END(UIItems_PlatformC)
};
int UIItems_PlatformC(int index, int reason)
{
	int zoomchanged = 0;
	if (reason == UIMENU_OK) {
		reason = UIMENU_RIGHT;
	}
	if (reason == UIMENU_CANCEL) {
		UIMenu_PrevMenu();
	}
	if (reason == UIMENU_LEFT) {
		switch (index) {
			case 1: // Zoom
				clc_zoom--;
				if (clc_zoom < 1) clc_zoom = 6;
				zoomchanged = 1;
				break;
			case 2: // Bits-Per-Pixel
				if (clc_bpp == 32)
					clc_bpp = 16;
				else
					clc_bpp = 32;
				zoomchanged = 1;
				break;
			case 3: // Fullscreen
				clc_fullscreen = !clc_fullscreen;
				zoomchanged = 1;
				break;
			case 4: // Display FPS
				clc_displayfps = !clc_displayfps;
				break;
		}
	}
	if (reason == UIMENU_RIGHT) {
		switch (index) {
			case 1: // Zoom
				clc_zoom++;
				if (clc_zoom > 6) clc_zoom = 1;
				zoomchanged = 1;
				break;
			case 2: // Bits-Per-Pixel
				if (clc_bpp == 32)
					clc_bpp = 16;
				else
					clc_bpp = 32;
				zoomchanged = 1;
				break;
			case 3: // Fullscreen
				clc_fullscreen = !clc_fullscreen;
				zoomchanged = 1;
				break;
			case 4: // Display FPS
				clc_displayfps = !clc_displayfps;
				break;
			case 8: // Define Joystick...
				JoystickEnterMenu();
				break;
			case 9: // Define Keyboard...
				KeyboardEnterMenu();
				break;
		}
	}
	UIMenu_ChangeItem(UIItems_Platform, 1, "Zoom: %s", clc_zoom_txt[clc_zoom]);
	UIMenu_ChangeItem(UIItems_Platform, 2, "Depth: %dbpp", clc_bpp);
	UIMenu_ChangeItem(UIItems_Platform, 3, "Fullscreen: %s", clc_fullscreen ? "Yes" : "No");
	UIMenu_ChangeItem(UIItems_Platform, 4, "Display FPS: %s", clc_displayfps ? "Yes" : "No");
	if (zoomchanged) {
		setup_screen();
		return 0;
	}
	return 1;
}

// Setup screen
int decorationWidth, decorationHeight;
void setup_screen()
{
	TPokeMini_VideoSpec *videospec;
	int depth;

	// Calculate size based of zoom
	if (clc_zoom == 1) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video1x1;
		PMWidth = 192; PMHeight = 128; PMOffX = 48; PMOffY = 32; UIOffX = 0; UIOffY = 0;
		UIMenu_SetDisplay(192, 128, PokeMini_BGR16, (uint8_t *)PokeMini_BG2, (uint16_t *)PokeMini_BG2_PalBGR16, (uint32_t *)PokeMini_BG2_PalBGR32);
	} else if (clc_zoom == 2) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video2x2;
		PMWidth = 208; PMHeight = 144; PMOffX = 8; PMOffY = 8; UIOffX = 8; UIOffY = 8;
		UIMenu_SetDisplay(192, 128, PokeMini_BGR16, (uint8_t *)PokeMini_BG2, (uint16_t *)PokeMini_BG2_PalBGR16, (uint32_t *)PokeMini_BG2_PalBGR32);
	} else if (clc_zoom == 3) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video3x3;
		PMWidth = 304; PMHeight = 208; PMOffX = 8; PMOffY = 8; UIOffX = 8; UIOffY = 8;
		UIMenu_SetDisplay(288, 192, PokeMini_BGR16, (uint8_t *)PokeMini_BG3, (uint16_t *)PokeMini_BG3_PalBGR16, (uint32_t *)PokeMini_BG3_PalBGR32);
	} else if (clc_zoom == 4) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video4x4;
		PMWidth = 400; PMHeight = 272; PMOffX = 8; PMOffY = 8; UIOffX = 8; UIOffY = 8;
		UIMenu_SetDisplay(384, 256, PokeMini_BGR16, (uint8_t *)PokeMini_BG4, (uint16_t *)PokeMini_BG4_PalBGR16, (uint32_t *)PokeMini_BG4_PalBGR32);
	} else if (clc_zoom == 5) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video5x5;
		PMWidth = 496; PMHeight = 336; PMOffX = 8; PMOffY = 8; UIOffX = 8; UIOffY = 8;
		UIMenu_SetDisplay(480, 320, PokeMini_BGR16, (uint8_t *)PokeMini_BG5, (uint16_t *)PokeMini_BG5_PalBGR16, (uint32_t *)PokeMini_BG5_PalBGR32);
	} else {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video6x6;
		PMWidth = 592; PMHeight = 400; PMOffX = 8; PMOffY = 8; UIOffX = 8; UIOffY = 8;
		UIMenu_SetDisplay(576, 384, PokeMini_BGR16, (uint8_t *)PokeMini_BG6, (uint16_t *)PokeMini_BG6_PalBGR16, (uint32_t *)PokeMini_BG6_PalBGR32);
	}

	// Set video spec and check if is supported
	depth = PokeMini_SetVideo(videospec, clc_bpp, CommandLine.lcdfilter, CommandLine.lcdmode);
	if (!depth) {
		fprintf(stderr, "Couldn't set video spec from %i bpp\n", clc_bpp);
		exit(1);
	}
	clc_bpp = depth;

	// (Re)create window
	if (renderer) {
		SDL_DestroyRenderer(renderer);
		renderer = NULL;
	}
	if (window) {
		SDL_DestroyWindow(window);
		window = NULL;
	}
	
	SDL_Delay(200);
	window = SDL_CreateWindow(AppName, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, PMWidth, PMHeight, SDL_WINDOW_RESIZABLE | (clc_fullscreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0));
	if (window == NULL) {
		fprintf(stderr, "Couldn't create SDL window: %s\n", SDL_GetError());
		exit(1);
	}
	renderer = SDL_CreateRenderer(window, -1, 0);
	if (renderer == NULL) {
		fprintf(stderr, "Couldn't create SDL renderer: %s\n", SDL_GetError());
		exit(1);
	}

	// (Re)Create texture
	if (texture != NULL) {
		SDL_DestroyTexture(texture);
	}
	texture = SDL_CreateTexture(renderer, (depth == 32) ? SDL_PIXELFORMAT_ARGB8888 : SDL_PIXELFORMAT_RGB565, SDL_TEXTUREACCESS_STREAMING, PMWidth, PMHeight);
	if (texture == NULL) {
		fprintf(stderr, "Couldn't create texture: %s\n", SDL_GetError());
		exit(1);
	}
	SDL_SetWindowSize(window, PMWidth + decorationWidth, PMHeight + decorationHeight);
}

// Capture screen
void capture_screen()
{
	FILE *capf;
	int y, capnum;
	unsigned long Video[96*64];
	PokeMini_VideoPreview_32((uint32_t *)Video, 96, PokeMini_LCDMode);
	capf = OpenUnique_ExportBMP(&capnum, 96, 64);
	if (!capf) {
		fprintf(stderr, "Error while saving capture\n");
		return;
	}
	for (y=0; y<64; y++) {
		WriteArray_ExportBMP(capf, (uint32_t *)&Video[(63-y) * 96], 96);
	}
	printf("Capture saved at 'snap_%03d.bmp'\n", capnum);
	Close_ExportBMP(capf);
}

// Handle keyboard and quit events
void handleevents(SDL_Event *event)
{
	switch (event->type) {
	case SDL_KEYDOWN:
		if (event->key.keysym.sym == SDLK_F9) {			// Capture screen
			capture_screen();
		} else if ((event->key.keysym.mod & KMOD_ALT) && (event->key.keysym.sym == SDLK_RETURN)) {
			clc_fullscreen = !clc_fullscreen;
			setup_screen();
			UIItems_PlatformC(0, UIMENU_LOAD);
		} else if (event->key.keysym.sym == SDLK_F10) {		// Fullscreen/Window
			clc_fullscreen = !clc_fullscreen;
			setup_screen();
			UIItems_PlatformC(0, UIMENU_LOAD);
		} else if (event->key.keysym.sym == SDLK_F11) {		// Disable speed throttling
			emulimiter = !emulimiter;
		} else if (event->key.keysym.sym == SDLK_TAB) {		// Temp disable speed throttling
			emulimiter = 0;
		} else {
			KeyboardPressEvent(event->key.keysym.sym);
		}
		break;
	case SDL_KEYUP:
		if (event->key.keysym.sym == SDLK_TAB) {		// Speed threhold
			emulimiter = 1;
		} else {
			KeyboardReleaseEvent(event->key.keysym.sym);
		}
		break;
	case SDL_JOYBUTTONDOWN:
		JoystickButtonsEvent(event->jbutton.button, 1);
		break;
	case SDL_JOYBUTTONUP:
		JoystickButtonsEvent(event->jbutton.button, 0);
		break;
	case SDL_JOYAXISMOTION:
		JoystickAxisEvent(event->jaxis.axis & 1, event->jaxis.value);
		break;
	case SDL_JOYHATMOTION:
		JoystickHatsEvent(event->jhat.value);
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
	if (clc_dump_sound[0]) WriteS16A_ExportWAV(sdump, (int16_t *)stream, len>>1);
}

// Enable / Disable sound
void enablesound(int sound)
{
	MinxAudio_ChangeEngine(sound);
	if (AudioEnabled) SDL_PauseAudio(!sound);
}

// Callback when joystick is re-opened
void reopen_joystick(int enable, int index)
{
	if (haptic) {
		SDL_HapticClose(haptic);
		haptic = NULL;
	}
	if (joystick) {
		SDL_JoystickClose(joystick);
		joystick = NULL;
	}
	if (enable && (SDL_NumJoysticks() > 0)) {
		SDL_JoystickEventState(SDL_ENABLE);
		joystick = SDL_JoystickOpen(index);	// Open joystick
		if (joystick) {
			printf("Opened joystick: %s\n", SDL_JoystickName(joystick));
			haptic = SDL_HapticOpenFromJoystick(joystick);
			if (haptic) {
				printf("  Rumble support: %s\n", SDL_HapticRumbleSupported(haptic) ? "Yes" : "No");
				SDL_HapticRumbleInit(haptic);
			} else {
				printf("  Rumble support: Haptic not supported\n");
			}
			printf("\n");
		}
	}
}

// Menu loop
void menuloop()
{
	SDL_Event event;
	void *pixscreen;
	int pixpitch, uioff;

	// Update window's title and stop sound
	SDL_SetWindowTitle(window, AppName);
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
		if (SDL_LockTexture(texture, NULL, &pixscreen, &pixpitch) >= 0) {
			// Clear texture
			memset(pixscreen, 0, PMHeight * pixpitch);

			// Setup pitch in pixel size and screen offset
			if (clc_bpp == 32) {
				pixpitch >>= 2;
			} else {
				pixpitch >>= 1;
			}
			uioff = (UIOffY * pixpitch) + UIOffX;

			// Render the menu or the game screen
			if (PokeMini_VideoDepth == 32) 
				UIMenu_Display_32((uint32_t *)pixscreen + uioff, pixpitch);
			else 
				UIMenu_Display_16((uint16_t *)pixscreen + uioff, pixpitch);

			// Unlock texture
			SDL_UnlockTexture(texture);
		}

		// Render texture to screen
		SDL_RenderClear(renderer);
		SDL_RenderCopy(renderer, texture, NULL, NULL);
		SDL_RenderPresent(renderer);

		// Handle events
		while (SDL_PollEvent(&event)) handleevents(&event);
	}

	// Apply configs
	PokeMini_ApplyChanges();
	if (UI_Status == UI_STATUS_EXIT) emurunning = 0;
	else enablesound(CommandLine.sound);
}

// Main function
int main(int argc, char **argv)
{
	SDL_Event event;
	char title[256];
	char fpstxt[16];
	void *pixscreen;
	int bytpitch, pixpitch, pmoff;

	// Process arguments
	printf("%s\n\n", AppName);
	PokeMini_InitDirs(argv[0], NULL);
	CommandLineInit();
	CommandLineConfFile("pokemini.cfg", "pokemini_sdl2.cfg", CustomConf);
	if (!CommandLineArgs(argc, argv, CustomArgs)) {
		PrintHelpUsage(stdout);
		printf("  -dumpsound sound.wav   Dump sound into a WAV file\n");
		printf("  -windowed              Display in window (default)\n");
		printf("  -fullscreen            Display in fullscreen\n");
		printf("  -displayfps            Display FPS counter on screen\n");
		printf("  -zoom n                Zoom display: 1 to 6 (def 4)\n");
		printf("  -bpp n                 Bits-Per-Pixel: 16 or 32 (def 16)\n");
		return 1;
	}

	// Initialize SDL
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK | SDL_INIT_HAPTIC) < 0) {
		fprintf(stderr, "Couldn't initialize SDL: %s\n", SDL_GetError());
		return 1;
	}
	SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "1");
	atexit(SDL_Quit); // Clean up on exit

	// Initialize the display
	setup_screen();

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

	// Open WAV capture if was requested
	if (clc_dump_sound[0]) {
		sdump = Open_ExportWAV(clc_dump_sound, EXPORTWAV_44KHZ | EXPORTWAV_MONO | EXPORTWAV_16BITS);
		if (!sdump) {
			fprintf(stderr, "Error opening sound export file.\n");
			return 1;
		}
	}

	// Initialize the emulator
	printf("Starting emulator...\n");
	if (!PokeMini_Create(0, PMSNDBUFFER)) {
		fprintf(stderr, "Error while initializing emulator\n");
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

	// Enable sound & init UI
	printf("Running emulator...\n");
	UIMenu_Init();
	KeyboardRemap(&KeybMapSDL2);
	JoystickUpdateCallback(reopen_joystick);
	enablesound(CommandLine.sound);

	// Emulator's loop
	unsigned long time, NewTickFPS = 0, NewTickSync = 0;
	int fps = 72, fpscnt = 0, oldrumbling = 0;
	while (emurunning) {
		// Emulate and syncronize
		time = SDL_GetTicks();
		if (RequireSoundSync) {
			PokeMini_EmulateFrame();
			// Sleep a little in the hope to free a few samples
			if (emulimiter) while (MinxAudio_SyncWithAudio()) SDL_Delay(1);
		} else {
			PokeMini_EmulateFrame();
			if (emulimiter) {
				do {
					SDL_Delay(1);		// This lower CPU usage
					time = SDL_GetTicks();
				} while (time < NewTickSync);
				NewTickSync = time + 13;	// Aprox 72 times per sec
			}
		}

		// Screen rendering
		if (SDL_LockTexture(texture, NULL, &pixscreen, &bytpitch) >= 0) {
			// Clear texture
			memset(pixscreen, 0, PMHeight * bytpitch);

			// Setup pitch in pixel size and screen offset
			if (clc_bpp == 32) {
				pmoff = (PMOffY * bytpitch) + (PMOffX << 2);
				pixpitch = bytpitch >> 2;
			} else {
				pmoff = (PMOffY * bytpitch) + (PMOffX << 1);
				pixpitch = bytpitch >> 1;
			}

			// Render the menu or the game screen
			if (PokeMini_Rumbling) {
				PokeMini_VideoBlit((void *)((uint8_t *)pixscreen + pmoff + PokeMini_GenRumbleOffset(bytpitch)), pixpitch);
			} else {
				PokeMini_VideoBlit((void *)((uint8_t *)pixscreen + pmoff), pixpitch);
			}
			if (haptic) {
				if (!oldrumbling && PokeMini_Rumbling) {
					if (SDL_HapticRumblePlay(haptic, 1.0f, 60000) < 0) {
						printf("SDL failed: %s\n", SDL_GetError());
					}
				} else if (oldrumbling && !PokeMini_Rumbling) {
					SDL_HapticRumbleStop(haptic);
				}
			}
			oldrumbling = PokeMini_Rumbling;
			LCDDirty = 0;

			// Display FPS counter
			if (clc_displayfps) {
				if (PokeMini_VideoDepth == 32)
					UIDraw_String_32((uint32_t *)pixscreen, pixpitch, 4, 4, 10, fpstxt, UI_Font1_Pal32);
				else
					UIDraw_String_16((uint16_t *)pixscreen, pixpitch, 4, 4, 10, fpstxt, UI_Font1_Pal16);
			}

			// Unlock texture
			SDL_UnlockTexture(texture);
		}

		// Render texture to screen
		SDL_RenderClear(renderer);
		SDL_RenderCopy(renderer, texture, NULL, NULL);
		SDL_RenderPresent(renderer);

		// Handle events
		while (SDL_PollEvent(&event)) handleevents(&event);

		// Menu
		if (UI_Status == UI_STATUS_MENU) menuloop();

		// calculate FPS
		fpscnt++;
		if (time >= NewTickFPS) {
			fps = fpscnt;
			sprintf(title, "%s - %d%%", AppName, fps * 100 / 72);
			sprintf(fpstxt, "%i FPS", fps);
			SDL_SetWindowTitle(window, title);
			NewTickFPS = time + 1000;
			fpscnt = 0;
		}
	}

	// Disable sound & free UI
	enablesound(0);
	UIMenu_Destroy();

	// Close WAV capture if there's one
	if (clc_dump_sound[0]) Close_ExportWAV(sdump);

	// Save Stuff
	PokeMini_SaveFromCommandLines(1);

	// Close joystick
	if (haptic) SDL_HapticClose(haptic);
	if (joystick) SDL_JoystickClose(joystick);

	// Terminate...
	printf("Shutdown emulator...\n");
	PokeMini_VideoPalette_Free();
	PokeMini_Destroy();

	return 0;
}
