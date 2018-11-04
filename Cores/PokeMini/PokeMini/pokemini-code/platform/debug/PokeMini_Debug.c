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
#include <unistd.h>
#include "SDL.h"

#include "PokeMini.h"
#include "Hardware_Debug.h"
#include "ExportBMP.h"
#include "ExportWAV.h"
#include "Joystick.h"
#include "Keyboard.h"
#include "KeybMapSDL.h"

#include "Video_x1.h"
#include "Video_x2.h"
#include "Video_x3.h"
#include "Video_x4.h"
#include "Video_x5.h"
#include "Video_x6.h"

#include <gtk/gtk.h>

#include "PokeMini_Debug.h"
#include "PokeMiniIcon_96x128.h"
#include "GtkXDialogs.h"

#include "CPUWindow.h"
#include "InputWindow.h"
#include "PalEditWindow.h"
#include "MemWindow.h"
#include "PRCTilesWindow.h"
#include "PRCMapWindow.h"
#include "PRCSprWindow.h"
#include "TimersWindow.h"
#include "HardIOWindow.h"
#include "IRQWindow.h"
#include "MiscWindow.h"
#include "SymbWindow.h"
#include "TraceWindow.h"
#include "ExternalWindow.h"

const char *LCDName = "Pokemon-Mini LCD";
const char *AppName = "PokeMini " PokeMini_Version " Debugger";

int emurunning = 1, emulimiter = 1;
SDL_Joystick *joystick;
SDL_Surface *screen;
int PMWidth, PMHeight;
int PixPitch, PMOff, PMZoom;
void setup_screen(void);

char argv0[PMTMPV];

FILE *sdump = NULL;
double sdumptime = 0.0;

volatile int emumode = EMUMODE_STOP;

// Sound buffer size
#define SOUNDBUFFER	2048
#define PMSNDBUFFER	(SOUNDBUFFER*4)

// Custom command line (NEW IN 0.4.6)
int clc_zoom = 4, clc_bpp = 16, clc_fullscreen = 0, clc_autorun = 0;
const TCommandLineCustom CustomArgs[] = {
	{ "-zoom", &clc_zoom, COMMANDLINE_INT, 1, 6 },
	{ "-bpp", &clc_bpp, COMMANDLINE_INT, 16, 32 },
	{ "-windowed", &clc_fullscreen, COMMANDLINE_INTSET, 0 },
	{ "-fullscreen", &clc_fullscreen, COMMANDLINE_INTSET, 1 },
	{ "-autorun", &clc_autorun, COMMANDLINE_INT, 0, 3 },
	{ "", NULL, COMMANDLINE_EOL }
};
int dclc_fullrange = 1;
int dclc_followPC = 1;
int dclc_followSP = 1;
int dclc_PRC_bg = 1;
int dclc_PRC_spr = 1;
int dclc_PRC_stallcpu = 1;
int dclc_PRC_stallcycles = 1;
int dclc_cpuwin_refresh = 7;
int dclc_cpuwin_winx = -16, dclc_cpuwin_winy = -16;
int dclc_cpuwin_winw = -1, dclc_cpuwin_winh = -1;
int dclc_memwin_refresh = 7;
int dclc_memwin_winx = -16, dclc_memwin_winy = -16;
int dclc_memwin_winw = -1, dclc_memwin_winh = -1;
int dclc_prctileswin_refresh = 7;
int dclc_prctileswin_winx = -16, dclc_prctileswin_winy = -16;
int dclc_prctileswin_winw = -1, dclc_prctileswin_winh = -1;
int dclc_prcmapwin_refresh = 7;
int dclc_prcmapwin_winx = -16, dclc_prcmapwin_winy = -16;
int dclc_prcmapwin_winw = -1, dclc_prcmapwin_winh = -1;
int dclc_prcsprwin_refresh = 7;
int dclc_prcsprwin_winx = -16, dclc_prcsprwin_winy = -16;
int dclc_prcsprwin_winw = -1, dclc_prcsprwin_winh = -1;
int dclc_timerswin_refresh = 7;
int dclc_timerswin_winx = -16, dclc_timerswin_winy = -16;
int dclc_timerswin_winw = -1, dclc_timerswin_winh = -1;
int dclc_hardiowin_refresh = 7;
int dclc_hardiowin_winx = -16, dclc_hardiowin_winy = -16;
int dclc_hardiowin_winw = -1, dclc_hardiowin_winh = -1;
int dclc_irqwin_refresh = 7;
int dclc_irqwin_winx = -16, dclc_irqwin_winy = -16;
int dclc_irqwin_winw = -1, dclc_irqwin_winh = -1;
int dclc_miscwin_refresh = 7;
int dclc_miscwin_winx = -16, dclc_miscwin_winy = -16;
int dclc_miscwin_winw = -1, dclc_miscwin_winh = -1;
int dclc_symbwin_refresh = 7;
int dclc_symbwin_winx = -16, dclc_symbwin_winy = -16;
int dclc_symbwin_winw = -1, dclc_symbwin_winh = -1;
int dclc_tracewin_refresh = 7;
int dclc_tracewin_winx = -16, dclc_tracewin_winy = -16;
int dclc_tracewin_winw = -1, dclc_tracewin_winh = -1;
int dclc_zoom_prctiles = 4;
int dclc_zoom_prcmap = 4;
int dclc_zoom_prcspr = 2;
int dclc_trans_prctiles = 0xFF00FF;
int dclc_trans_prcspr = 0xFF00FF;
int dclc_show_hspr = 1;
int dclc_minimalist_sprview = 0;
int dclc_irqframes_on_1row = 0;
int dclc_autoread_minsym = 1;
int dclc_autorw_emusym = 1;
char dclc_extapp_title[10][PMTMPV];
char dclc_extapp_exec[10][PMTMPV];
int dclc_extapp_atcurrdir[10];
char dclc_recent[10][PMTMPV];
int dclc_debugout = 1;
int dclc_autodebugout = 1;
const TCommandLineCustom CustomConf[] = {
	{ "zoom", &clc_zoom, COMMANDLINE_INT, 1, 6 },
	{ "bpp", &clc_bpp, COMMANDLINE_INT, 16, 32 },
	{ "fullscreen", &clc_fullscreen, COMMANDLINE_BOOL },
	{ "autorun", &clc_autorun, COMMANDLINE_INT, 0, 3 },
	// Debugger configs
	{ "fullrange", &dclc_fullrange, COMMANDLINE_BOOL },
	{ "follow_pc", &dclc_followPC, COMMANDLINE_BOOL },
	{ "follow_sp", &dclc_followSP, COMMANDLINE_BOOL },
	{ "prc_background", &dclc_PRC_bg, COMMANDLINE_BOOL },
	{ "prc_sprites", &dclc_PRC_spr, COMMANDLINE_BOOL },
	{ "prc_stallcpu", &dclc_PRC_stallcpu, COMMANDLINE_BOOL },
	{ "prc_stallidlecycles", &dclc_PRC_stallcycles, COMMANDLINE_INT, 8, 64 },
	{ "debug_out", &dclc_debugout, COMMANDLINE_BOOL },
	{ "auto_debug_out", &dclc_autodebugout, COMMANDLINE_BOOL },
	{ "cpuwin_refresh", &dclc_cpuwin_refresh, COMMANDLINE_INT, 0, 1000 },
	{ "cpuwin_winx", &dclc_cpuwin_winx, COMMANDLINE_INT, -16, 4095 },
	{ "cpuwin_winy", &dclc_cpuwin_winy, COMMANDLINE_INT, -16, 4095 },
	{ "cpuwin_winw", &dclc_cpuwin_winw, COMMANDLINE_INT, -1, 4095 },
	{ "cpuwin_winh", &dclc_cpuwin_winh, COMMANDLINE_INT, -1, 4095 },
	{ "memwin_refresh", &dclc_memwin_refresh, COMMANDLINE_INT, 0, 1000 },
	{ "memwin_winx", &dclc_memwin_winx, COMMANDLINE_INT, -16, 4095 },
	{ "memwin_winy", &dclc_memwin_winy, COMMANDLINE_INT, -16, 4095 },
	{ "memwin_winw", &dclc_memwin_winw, COMMANDLINE_INT, -1, 4095 },
	{ "memwin_winh", &dclc_memwin_winh, COMMANDLINE_INT, -1, 4095 },
	{ "prctileswin_refresh", &dclc_prctileswin_refresh, COMMANDLINE_INT, 0, 1000 },
	{ "prctileswin_winx", &dclc_prctileswin_winx, COMMANDLINE_INT, -16, 4095 },
	{ "prctileswin_winy", &dclc_prctileswin_winy, COMMANDLINE_INT, -16, 4095 },
	{ "prctileswin_winw", &dclc_prctileswin_winw, COMMANDLINE_INT, -1, 4095 },
	{ "prctileswin_winh", &dclc_prctileswin_winh, COMMANDLINE_INT, -1, 4095 },
	{ "prcmapwin_refresh", &dclc_prcmapwin_refresh, COMMANDLINE_INT, 0, 1000 },
	{ "prcmapwin_winx", &dclc_prcmapwin_winx, COMMANDLINE_INT, -16, 4095 },
	{ "prcmapwin_winy", &dclc_prcmapwin_winy, COMMANDLINE_INT, -16, 4095 },
	{ "prcmapwin_winw", &dclc_prcmapwin_winw, COMMANDLINE_INT, -1, 4095 },
	{ "prcmapwin_winh", &dclc_prcmapwin_winh, COMMANDLINE_INT, -1, 4095 },
	{ "prcsprwin_refresh", &dclc_prcsprwin_refresh, COMMANDLINE_INT, 0, 1000 },
	{ "prcsprwin_winx", &dclc_prcsprwin_winx, COMMANDLINE_INT, -16, 4095 },
	{ "prcsprwin_winy", &dclc_prcsprwin_winy, COMMANDLINE_INT, -16, 4095 },
	{ "prcsprwin_winw", &dclc_prcsprwin_winw, COMMANDLINE_INT, -1, 4095 },
	{ "prcsprwin_winh", &dclc_prcsprwin_winh, COMMANDLINE_INT, -1, 4095 },
	{ "timerswin_refresh", &dclc_timerswin_refresh, COMMANDLINE_INT, 0, 1000 },
	{ "timerswin_winx", &dclc_timerswin_winx, COMMANDLINE_INT, -16, 4095 },
	{ "timerswin_winy", &dclc_timerswin_winy, COMMANDLINE_INT, -16, 4095 },
	{ "timerswin_winw", &dclc_timerswin_winw, COMMANDLINE_INT, -1, 4095 },
	{ "timerswin_winh", &dclc_timerswin_winh, COMMANDLINE_INT, -1, 4095 },
	{ "hardiowin_refresh", &dclc_hardiowin_refresh, COMMANDLINE_INT, 0, 1000 },
	{ "hardiowin_winx", &dclc_hardiowin_winx, COMMANDLINE_INT, -16, 4095 },
	{ "hardiowin_winy", &dclc_hardiowin_winy, COMMANDLINE_INT, -16, 4095 },
	{ "hardiowin_winw", &dclc_hardiowin_winw, COMMANDLINE_INT, -1, 4095 },
	{ "hardiowin_winh", &dclc_hardiowin_winh, COMMANDLINE_INT, -1, 4095 },
	{ "irqwin_refresh", &dclc_irqwin_refresh, COMMANDLINE_INT, 0, 1000 },
	{ "irqwin_winx", &dclc_irqwin_winx, COMMANDLINE_INT, -16, 4095 },
	{ "irqwin_winy", &dclc_irqwin_winy, COMMANDLINE_INT, -16, 4095 },
	{ "irqwin_winw", &dclc_irqwin_winw, COMMANDLINE_INT, -1, 4095 },
	{ "irqwin_winh", &dclc_irqwin_winh, COMMANDLINE_INT, -1, 4095 },
	{ "miscwin_refresh", &dclc_miscwin_refresh, COMMANDLINE_INT, 0, 1000 },
	{ "miscwin_winx", &dclc_miscwin_winx, COMMANDLINE_INT, -16, 4095 },
	{ "miscwin_winy", &dclc_miscwin_winy, COMMANDLINE_INT, -16, 4095 },
	{ "miscwin_winw", &dclc_miscwin_winw, COMMANDLINE_INT, -1, 4095 },
	{ "miscwin_winh", &dclc_miscwin_winh, COMMANDLINE_INT, -1, 4095 },
	{ "symbwin_refresh", &dclc_symbwin_refresh, COMMANDLINE_INT, 0, 1000 },
	{ "symbwin_winx", &dclc_symbwin_winx, COMMANDLINE_INT, -16, 4095 },
	{ "symbwin_winy", &dclc_symbwin_winy, COMMANDLINE_INT, -16, 4095 },
	{ "symbwin_winw", &dclc_symbwin_winw, COMMANDLINE_INT, -1, 4095 },
	{ "symbwin_winh", &dclc_symbwin_winh, COMMANDLINE_INT, -1, 4095 },
	{ "tracewin_refresh", &dclc_tracewin_refresh, COMMANDLINE_INT, 0, 1000 },
	{ "tracewin_winx", &dclc_tracewin_winx, COMMANDLINE_INT, -16, 4095 },
	{ "tracewin_winy", &dclc_tracewin_winy, COMMANDLINE_INT, -16, 4095 },
	{ "tracewin_winw", &dclc_tracewin_winw, COMMANDLINE_INT, -1, 4095 },
	{ "tracewin_winh", &dclc_tracewin_winh, COMMANDLINE_INT, -1, 4095 },
	{ "zoom_prctiles", &dclc_zoom_prctiles, COMMANDLINE_INT, 1, 8 },
	{ "zoom_prcmap", &dclc_zoom_prcmap, COMMANDLINE_INT, 1, 8 },
	{ "zoom_prcspr", &dclc_zoom_prcspr, COMMANDLINE_INT, 1, 8 },
	{ "transparency_prctiles", &dclc_trans_prctiles, COMMANDLINE_INT, 0x000000, 0xFFFFFF },
	{ "transparency_prcspr", &dclc_trans_prcspr, COMMANDLINE_INT, 0x000000, 0xFFFFFF },
	{ "show_hidden_sprites", &dclc_show_hspr, COMMANDLINE_BOOL },
	{ "minimalist_sprview", &dclc_minimalist_sprview, COMMANDLINE_BOOL },
	{ "irqframes_on_1row", &dclc_irqframes_on_1row, COMMANDLINE_BOOL },
	{ "autoread_min_symbols", &dclc_autoread_minsym, COMMANDLINE_BOOL },
	{ "autorw_emu_symbols", &dclc_autorw_emusym, COMMANDLINE_BOOL },
	{ "extapp1_title", (int *)&dclc_extapp_title[0], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp1_exec", (int *)&dclc_extapp_exec[0], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp1_atcurrdir", (int *)&dclc_extapp_atcurrdir[0], COMMANDLINE_BOOL },
	{ "extapp2_title", (int *)&dclc_extapp_title[1], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp2_exec", (int *)&dclc_extapp_exec[1], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp2_atcurrdir", (int *)&dclc_extapp_atcurrdir[1], COMMANDLINE_BOOL },
	{ "extapp3_title", (int *)&dclc_extapp_title[2], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp3_exec", (int *)&dclc_extapp_exec[2], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp3_atcurrdir", (int *)&dclc_extapp_atcurrdir[2], COMMANDLINE_BOOL },
	{ "extapp4_title", (int *)&dclc_extapp_title[3], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp4_exec", (int *)&dclc_extapp_exec[3], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp4_atcurrdir", (int *)&dclc_extapp_atcurrdir[3], COMMANDLINE_BOOL },
	{ "extapp5_title", (int *)&dclc_extapp_title[4], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp5_exec", (int *)&dclc_extapp_exec[4], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp5_atcurrdir", (int *)&dclc_extapp_atcurrdir[4], COMMANDLINE_BOOL },
	{ "extapp6_title", (int *)&dclc_extapp_title[5], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp6_exec", (int *)&dclc_extapp_exec[5], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp6_atcurrdir", (int *)&dclc_extapp_atcurrdir[5], COMMANDLINE_BOOL },
	{ "extapp7_title", (int *)&dclc_extapp_title[6], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp7_exec", (int *)&dclc_extapp_exec[6], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp7_atcurrdir", (int *)&dclc_extapp_atcurrdir[6], COMMANDLINE_BOOL },
	{ "extapp8_title", (int *)&dclc_extapp_title[7], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp8_exec", (int *)&dclc_extapp_exec[7], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp8_atcurrdir", (int *)&dclc_extapp_atcurrdir[7], COMMANDLINE_BOOL },
	{ "extapp9_title", (int *)&dclc_extapp_title[8], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp9_exec", (int *)&dclc_extapp_exec[8], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp9_atcurrdir", (int *)&dclc_extapp_atcurrdir[8], COMMANDLINE_BOOL },
	{ "extapp10_title", (int *)&dclc_extapp_title[9], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp10_exec", (int *)&dclc_extapp_exec[9], COMMANDLINE_STR, PMTMPV-1 },
	{ "extapp10_atcurrdir", (int *)&dclc_extapp_atcurrdir[9], COMMANDLINE_BOOL },
	{ "recent_rom0", (int *)&dclc_recent[0], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom1", (int *)&dclc_recent[1], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom2", (int *)&dclc_recent[2], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom3", (int *)&dclc_recent[3], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom4", (int *)&dclc_recent[4], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom5", (int *)&dclc_recent[5], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom6", (int *)&dclc_recent[6], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom7", (int *)&dclc_recent[7], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom8", (int *)&dclc_recent[8], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom9", (int *)&dclc_recent[9], COMMANDLINE_STR, PMTMPV-1 },
	{ "", NULL, COMMANDLINE_EOL }
};

// Platform menu (REQUIRED >= 0.4.4)
int UIItems_PlatformC(int index, int reason);
TUIMenu_Item UIItems_Platform[] = {
	{ 0,  0, "Go back...", UIItems_PlatformDefC },
	{ 9,  0, "Platform", UIItems_PlatformDefC }
};

// Setup screen
void setup_screen(void)
{
	TPokeMini_VideoSpec *videospec;
	int depth, PMOffX, PMOffY;

	// Calculate size based of zoom
	if (clc_zoom == 1) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video1x1;
		PMWidth = 192; PMHeight = 128; PMOffX = 48; PMOffY = 32; PMZoom = 1;
	} else if (clc_zoom == 2) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video2x2;
		PMWidth = 208; PMHeight = 144; PMOffX = 8; PMOffY = 8; PMZoom = 2;
	} else if (clc_zoom == 3) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video3x3;
		PMWidth = 304; PMHeight = 208; PMOffX = 8; PMOffY = 8; PMZoom = 3;
	} else if (clc_zoom == 4) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video4x4;
		PMWidth = 400; PMHeight = 272; PMOffX = 8; PMOffY = 8; PMZoom = 4;
	} else if (clc_zoom == 5) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video5x5;
		PMWidth = 496; PMHeight = 336; PMOffX = 8; PMOffY = 8; PMZoom = 5;
	} else {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video6x6;
		PMWidth = 592; PMHeight = 400; PMOffX = 8; PMOffY = 8; PMZoom = 6;
	}

	// Set video spec and check if is supported
	depth = PokeMini_SetVideo(videospec, clc_bpp, CommandLine.lcdfilter, CommandLine.lcdmode);
	if (!depth) {
		fprintf(stderr, "Couldn't set video spec from %i bpp\n", clc_bpp);
		exit(1);
	}

	// Set video mode
	screen = SDL_SetVideoMode(PMWidth, PMHeight, depth, SDL_HWSURFACE | SDL_DOUBLEBUF | (clc_fullscreen ? SDL_FULLSCREEN : 0));
	if (!screen) {
		fprintf(stderr, "Couldn't set video mode: %s\n", SDL_GetError());
		exit(1);
	}

	// Calculate pitch and offset
	if (depth == 32) {
		PixPitch = screen->pitch / 4;
		PMOff = (PMOffY * screen->pitch) + (PMOffX * 4);
	} else {
		PixPitch = screen->pitch / 2;
		PMOff = (PMOffY * screen->pitch) + (PMOffX * 2);
	}
	clc_bpp = depth;
}

// Capture screen
void capture_screen(void)
{
	FILE *capf;
	int y, capnum;
	unsigned long Video[96*64];
	PokeMini_VideoPreview_32((uint32_t *)Video, 96, PokeMini_LCDMode);
	capf = OpenUnique_ExportBMP(&capnum, 96, 64);
	if (!capf) {
		Add_InfoMessage("[Error] Saving capture\n");
		return;
	}
	for (y=0; y<64; y++) {
		WriteArray_ExportBMP(capf, (uint32_t *)&Video[(63-y) * 96], 96);
	}
	Add_InfoMessage("[Info] Capture saved at 'snap_%03d.bmp'\n", capnum);
	Close_ExportBMP(capf);
}

// Handle keyboard and quit events
void handleevents(SDL_Event *event)
{
	int modx;
	switch (event->type) {
	case SDL_KEYDOWN:
		modx = 0;
		if (event->key.keysym.mod & KMOD_CTRL) modx |= 1;
		if (event->key.keysym.mod & KMOD_SHIFT) modx |= 2;
		if (event->key.keysym.mod & KMOD_ALT) modx |= 4;
		if (ProcessMenuItemAccel(event->key.keysym.sym, modx, Menu_item_accel)) break;

		// Process rest of the keys
		if (event->key.keysym.sym == SDLK_F9) {			// Capture screen
			capture_screen();
		} else if (event->key.keysym.sym == SDLK_F10) {		// Fullscreen/Window
			clc_fullscreen = !clc_fullscreen;
			setup_screen();
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
	if (sdump) {
		WriteS16A_ExportWAV(sdump, (int16_t *)stream, len>>1);
		sdumptime += (double)len / 88200.0;
	}
}

// Enable / Disable sound
void enablesound(int sound)
{
	MinxAudio_ChangeEngine(sound);
	if (AudioEnabled) SDL_PauseAudio(!sound);
}

// Re-open joystick
void reopenjoystick(void)
{
	if (joystick) SDL_JoystickClose(joystick);
	joystick = SDL_JoystickOpen(CommandLine.joyid);
}

void PMDebug_OnAllocMIN(int newsize, int success)
{
	ColorInfoFile[0] = 0;
	CPUWindow_ROMResized();
	MemWindow_ROMResized();
	PRCTilesWindow_ROMResized();
}

void PMDebug_OnUnzipError(const char *zipfile, const char *reason)
{
	Add_InfoMessage("[Error] Decompressing %s: %s\n", zipfile, reason);
}

void PMDebug_OnLoadBIOSFile(const char *filename, int success)
{
	if (success == 1) Add_InfoMessage("[Info] BIOS '%s' loaded\n", filename);
	else if (success == -1) Add_InfoMessage("[Error] Loading BIOS '%s': file not found, Using FreeBIOS\n", filename);
	else Add_InfoMessage("[Error] Loading BIOS '%s': read error, Using FreeBIOS\n", filename);
}

void PMDebug_OnLoadMINFile(const char *filename, int success)
{
	if (success == 1) {
		Add_InfoMessage("[Info] ROM '%s' loaded\n", filename);
		SymbWindow_ROMLoaded(filename);
		CPUWindow_Refresh(1);
	} else if (success == -1) Add_InfoMessage("[Error] Loading ROM '%s': file not found\n", filename);
	else if (success == -2) Add_InfoMessage("[Error] Loading ROM '%s': invalid size\n", filename);
	else Add_InfoMessage("[Error] Loading ROM '%s', read error\n", filename);
}

void PMDebug_OnLoadColorFile(const char *filename, int success)
{
	if (success == 1) {
		Add_InfoMessage("[Info] Color info '%s' loaded\n", filename);
		strcpy(ColorInfoFile, filename);
	} else if (success == -1) Add_InfoMessage("[Error] Loading color info '%s': file not found\n", filename);
	else Add_InfoMessage("[Error] Loading color info '%s': read error\n", filename);
}

void PMDebug_OnLoadEEPROMFile(const char *filename, int success)
{
	if (success == 1) Add_InfoMessage("[Info] EEPROM '%s' loaded\n", filename);
	else if (success == -1) Add_InfoMessage("[Error] Loading EEPROM '%s': file not found\n", filename);
	else Add_InfoMessage("[Error] Loading EEPROM '%s': read error\n", filename);
}

void PMDebug_OnSaveEEPROMFile(const char *filename, int success)
{
	if (success == 1) Add_InfoMessage("[Info] EEPROM '%s' saved\n", filename);
	else if (success == -1) Add_InfoMessage("[Error] Saving EEPROM '%s': filename invalid\n", filename);
	else Add_InfoMessage("[Error] Saving EEPROM '%s': write error\n", filename);
}

void PMDebug_OnLoadStateFile(const char *filename, int success)
{
	if (success == 1) Add_InfoMessage("[Info] State '%s' loaded\n", filename);
	else if (success == -1) Add_InfoMessage("[Error] Loading state '%s': file not found\n", filename);
	else if (success == -2) Add_InfoMessage("[Error] Loading state '%s': invalid file\n", filename);
	else if (success == -3) Add_InfoMessage("[Error] Loading state '%s': wrong version\n", filename);
	else if (success == -4) Add_InfoMessage("[Error] Loading state '%s': invalid header\n", filename);
	else if (success == -5) Add_InfoMessage("[Error] Loading state '%s': invalid internal block\n", filename);
	else Add_InfoMessage("[Error] Loading state '%s': read error\n", filename);
}

void PMDebug_OnSaveStateFile(const char *filename, int success)
{
	if (success == 1) Add_InfoMessage("[Info] State '%s' saved\n", filename);
	else if (success == -1) Add_InfoMessage("[Error] Saving state '%s': filename invalid\n", filename);
	else Add_InfoMessage("[Error] Saving state '%s': write error\n", filename);
}

void PMDebug_OnReset(int hardreset)
{
	PMHD_Reset(hardreset);
	Cmd_DebugOutput(-1);
}

// Set emulator mode
void set_emumode(int mode, int tempsave)
{
	static int temp_emumode = EMUMODE_STOP;
	int dorefresh = 0;

	if (mode == EMUMODE_RESTORE) mode = temp_emumode;
	else if (tempsave) temp_emumode = emumode;

	if ((emumode & EMUMODE_SOUND) && !(mode & EMUMODE_SOUND)) enablesound(0);
	if (!(emumode & EMUMODE_SOUND) && (mode & EMUMODE_SOUND)) enablesound(CommandLine.sound);
	if ((emumode != EMUMODE_RUNFULL) && (mode == EMUMODE_RUNFULL)) sensitive_debug(0);
	if ((emumode == EMUMODE_RUNFULL) && (mode != EMUMODE_RUNFULL)) sensitive_debug(1);
	if (emumode != mode) dorefresh = 1;

	emumode = mode;
	if (dorefresh) {
		CPUWindow_EmumodeChanged();
		refresh_debug(1);
	}
}

// Refresh all debug components
void refresh_debug(int now)
{
	CPUWindow_Refresh(now);
	MemWindow_Refresh(now);
	PRCTilesWindow_Refresh(now);
	PRCMapWindow_Refresh(now);
	PRCSprWindow_Refresh(now);
	TimersWindow_Refresh(now);
	HardIOWindow_Refresh(now);
	IRQWindow_Refresh(now);
	MiscWindow_Refresh(now);
	SymbWindow_Refresh(now);
	TraceWindow_Refresh(now);
}

// "Run full" status changed
void sensitive_debug(int enable)
{
	MemWindow_Sensitive(enable);
	PRCTilesWindow_Sensitive(enable);
	PRCMapWindow_Sensitive(enable);
	PRCSprWindow_Sensitive(enable);
	TimersWindow_Sensitive(enable);
	HardIOWindow_Sensitive(enable);
	IRQWindow_Sensitive(enable);
	MiscWindow_Sensitive(enable);
	SymbWindow_Sensitive(enable);
	TraceWindow_Sensitive(enable);
}

// Display command-line switches
void display_commandline(void)
{
	char *buffer;
	buffer = (char *)malloc(PrintHelpUsageStr(NULL)+256);
	PrintHelpUsageStr(buffer);
	strcat(buffer, "  -autorun               Autorun, 0=Off, 1=Full, 2=Dbg+Snd, 3=Dbg\n");
	strcat(buffer, "  -windowed              Display in window (default)\n");
	strcat(buffer, "  -fullscreen            Display in fullscreen\n");
	strcat(buffer, "  -zoom n                Zoom display: 1 to 6 (def 4)\n");
	strcat(buffer, "  -bpp n                 Bits-Per-Pixel: 16 or 32 (def 16)\n");
	MessageDialog(MainWindow, buffer, "Command line", GTK_MESSAGE_INFO, PokeMiniIcon_96x128);
	free(buffer);
}

// Main function
int main(int argc, char **argv)
{
	SDL_Event event;
	char title[PMTMPV];
	int AutoRun = 0;

	// Get current directory
	PokeMini_InitDirs(argv[0], argv0);

	// Change to executable directory
	PokeMini_GotoExecDir();

	// Init GTK & create main window
	gtk_init(&argc, &argv);
	if (!CPUWindow_Create()) { fprintf(stderr, "Error creating CPU window"); return 1; }
	if (!InputWindow_Create()) { fprintf(stderr, "Error creating input window"); return 1; }
	if (!PalEditWindow_Create()) { fprintf(stderr, "Error creating palette edit window"); return 1; }
	if (!MemWindow_Create()) { fprintf(stderr, "Error creating memory window"); return 1; }
	if (!PRCTilesWindow_Create()) { fprintf(stderr, "Error creating PRC tiles window"); return 1; }
	if (!PRCMapWindow_Create()) { fprintf(stderr, "Error creating PRC map window"); return 1; }
	if (!PRCSprWindow_Create()) { fprintf(stderr, "Error creating PRC sprites window"); return 1; }
	if (!TimersWindow_Create()) { fprintf(stderr, "Error creating misc. window"); return 1; }
	if (!HardIOWindow_Create()) { fprintf(stderr, "Error creating hardware IO window"); return 1; }
	if (!IRQWindow_Create()) { fprintf(stderr, "Error creating IRQ window"); return 1; }
	if (!MiscWindow_Create()) { fprintf(stderr, "Error creating misc. window"); return 1; }
	if (!SymbWindow_Create()) { fprintf(stderr, "Error creating symbol list window"); return 1; }
	if (!TraceWindow_Create()) { fprintf(stderr, "Error creating trace window"); return 1; }
	if (!ExternalWindow_Create()) { fprintf(stderr, "Error creating external window"); return 1; }

	// Process arguments
	Add_InfoMessage("%s\n\n", AppName);
	CommandLineInit();
	CommandLineConfFile("pokemini.cfg", "pokemini_debug.cfg", CustomConf);
	if (!CommandLineArgs(argc, argv, CustomArgs)) {
		display_commandline();
	}

	// Initialize SDL
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK) < 0) {
		fprintf(stderr, "Couldn't initialize SDL: %s\n", SDL_GetError());
		return 1;
	}
	joystick = SDL_JoystickOpen(CommandLine.joyid);	// Open joystick
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
		Add_InfoMessage("[Error] Unable to open audio: %s\n", SDL_GetError());
		Add_InfoMessage("[Error] Audio will be disabled\n");
		AudioEnabled = 0;
	} else {
		AudioEnabled = 1;
	}

	// Set the window manager title bar
	SDL_WM_SetCaption(LCDName, "PokeMini");
	SDL_EnableKeyRepeat(0, 0);

	// Restore current directory
	PokeMini_GotoCurrentDir();

	// Initialize the emulator
	if (!PokeMini_Create(0, PMSNDBUFFER)) {
		fprintf(stderr, "Error while initializing emulator\n");
		return 1;
	}
	PMHD_MINLoaded();

	// Setup palette and LCD mode
	PokeMini_VideoPalette_Init(PokeMini_BGR16, 1);
	PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
	PokeMini_ApplyChanges();

	// Load stuff & allocate dummy ROM
	PokeMini_OnAllocMIN = PMDebug_OnAllocMIN;
	PokeMini_OnUnzipError = PMDebug_OnUnzipError;
	PokeMini_OnLoadBIOSFile = PMDebug_OnLoadBIOSFile;
	PokeMini_OnLoadMINFile = PMDebug_OnLoadMINFile;
	PokeMini_OnLoadColorFile = PMDebug_OnLoadColorFile;
	PokeMini_OnLoadEEPROMFile = PMDebug_OnLoadEEPROMFile;
	PokeMini_OnSaveEEPROMFile = PMDebug_OnSaveEEPROMFile;
	PokeMini_OnLoadStateFile = PMDebug_OnLoadStateFile;
	PokeMini_OnSaveStateFile = PMDebug_OnSaveStateFile;
	PokeMini_OnReset = PMDebug_OnReset;
	CPUWindow_UpdateConfigs();
	InputWindow_UpdateConfigs();
	PalEditWindow_UpdateConfigs();
	MemWindow_UpdateConfigs();
	PRCTilesWindow_UpdateConfigs();
	PRCMapWindow_UpdateConfigs();
	PRCSprWindow_UpdateConfigs();
	TimersWindow_UpdateConfigs();
	HardIOWindow_UpdateConfigs();
	IRQWindow_UpdateConfigs();
	MiscWindow_UpdateConfigs();
	SymbWindow_UpdateConfigs();
	TraceWindow_UpdateConfigs();
	ExternalWindow_UpdateConfigs();
	if (PokeMini_LoadFromCommandLines("Using FreeBIOS", "EEPROM data will be discarded!")) {
		CPUWindow_AddMinOnRecent(CommandLine.min_file);
		AutoRun = 1;
	}
	if (!PM_ROM_Alloc) {
		if (!PokeMini_NewMIN(65536)) {
			fprintf(stderr, "Not enough memory for 64KB ROM!\n");
			return 1;
		}
	}

	// Activate CPU window and map keyboard
	CPUWindow_Activate();
	Add_InfoMessage("[Info] Emulator started.\n");
	KeyboardRemap(&KeybMapSDL);
	refresh_debug(1);
	enablesound(0);

	// Autorun if MIN was loaded in command-lines
	if (AutoRun) {
		switch (clc_autorun) {
			case 1: set_emumode(EMUMODE_RUNFULL, 0); break;
			case 2: set_emumode(EMUMODE_RUNDEBFRAMESND, 0); break;
			case 3: set_emumode(EMUMODE_RUNDEBFRAME, 0); break;
		}
	}

	// Emulator's loop
	unsigned long time, NewTickFPS = 0, NewTickSync = 0;
	int fpscnt = 0;
	while (emurunning) {
		time = SDL_GetTicks();
		switch (emumode) {
			case EMUMODE_STOP:
				SDL_Delay(50);		// This lower CPU usage
				break;
			case EMUMODE_STEP:
				PokeMini_EmulateStep();
				set_emumode(EMUMODE_STOP, 0);
				break;
			case EMUMODE_STEPSKIP:
				PokeMini_EmulateStepSkip();
				set_emumode(EMUMODE_STOP, 0);
				break;
			case EMUMODE_FRAME:
				PokeMini_EmulateFrame();
				set_emumode(EMUMODE_STOP, 0);
				break;
			case EMUMODE_RUNDEBSTEP:
				PokeMini_EmulateStep();
				refresh_debug(0);
				break;
			case EMUMODE_RUNDEBFRAME: case EMUMODE_RUNDEBFRAMESND:
				refresh_debug(0);
				// continue with EMUMODE_RUNFULL
			case EMUMODE_RUNFULL:
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
				break;
		}

		// Screen rendering
		SDL_FillRect(screen, NULL, 0);
		if (SDL_LockSurface(screen) == 0) {
			// Render the menu or the game screen
			if (PokeMini_Rumbling) {
				PokeMini_VideoBlit((void *)((uint8_t *)screen->pixels + PMOff + PokeMini_GenRumbleOffset(screen->pitch)), PixPitch);
			} else {
				PokeMini_VideoBlit((void *)((uint8_t *)screen->pixels + PMOff), PixPitch);
			}
			LCDDirty--;

			// Unlock surface
			SDL_UnlockSurface(screen);
			SDL_Flip(screen);
		}
		CPUWindow_FrameRendered();

		// Handle events
		while (SDL_PollEvent(&event)) handleevents(&event);
		while (gtk_events_pending()) gtk_main_iteration();

		// calculate FPS
		fpscnt++;
		if (time >= NewTickFPS) {
				if (emumode == EMUMODE_STOP) {
					sprintf(title, "%s - Stopped", LCDName);
					SDL_WM_SetCaption(title, "PokeMini");
				} else {
					sprintf(title, "%s - %d%%", LCDName, fpscnt * 100 / 72);
					SDL_WM_SetCaption(title, "PokeMini");
				}
				NewTickFPS = time + 1000;
				fpscnt = 0;
		}
	}

	// Disable sound
	enablesound(0);

	// Destroy windows
	CPUWindow_Destroy();
	InputWindow_Destroy();
	PalEditWindow_Destroy();
	MemWindow_Destroy();
	PRCTilesWindow_Destroy();
	PRCMapWindow_Destroy();
	PRCSprWindow_Destroy();
	TimersWindow_Destroy();
	HardIOWindow_Destroy();
	IRQWindow_Destroy();
	MiscWindow_Destroy();
	SymbWindow_Destroy();
	TraceWindow_Destroy();
	ExternalWindow_Destroy();

	// Restore launch directory and save stuff
	PokeMini_SaveFromCommandLines(1);
	CommandLineConfSave();

	// Close joystick
	if (joystick) SDL_JoystickClose(joystick);

	// Terminate...
	PokeMini_VideoPalette_Free();
	PokeMini_Destroy();

	// Close sound dump if still open
	if (sdump) {
		Close_ExportWAV(sdump);
		sdump = NULL;
	}

	return 0;
}
