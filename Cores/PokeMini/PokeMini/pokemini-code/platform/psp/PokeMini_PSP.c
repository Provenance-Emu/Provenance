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

#include "PSPStuffz.h"

#include "PokeMini.h"
#include "Hardware.h"
#include "Joystick.h"

#include "Video_x1.h"
#include "Video_x2.h"
#include "Video_x3.h"
#include "Video_x4.h"
#include "PokeMini_BG2.h"
#include "PokeMini_BG3.h"
#include "PokeMini_BG4.h"

const char *AppName = "PokeMini " PokeMini_Version " PSP";

#define SOUNDBUFFER	2048
#define PMSNDBUFFER	(SOUNDBUFFER*4)

// For the emulator loop and video
int emurunning = 1;
int ui_offset;
int pm_offset;

void setup_screen();

// --------

int exitCallback(int arg1, int arg2, void *common)
{
	emurunning = 0;
	return 0;
}

// --------

const char *clc_zoom_txt[] = {
	"0x (Illegal)",
	"1x ( 96x 64)",
	"2x (192x128)",
	"3x (288x192)",
	"4x (384x256)",
};

// Joystick names and mapping (NEW IN 0.5.0)
char *PSP_KeysNames[] = {
	"Off",		// -1
	"Select",	// 0
	"Unused 1",	// 1
	"Unused 2",	// 2
	"Start",	// 3
	"Up",		// 4
	"Right",	// 5
	"Down",		// 6
	"Left",		// 7
	"L Trigger",	// 8
	"R Trigger",	// 9
	"Unused 4",	// 10
	"Unused 5",	// 11
	"Triangle",	// 12
	"Circle",	// 13
	"Cross",	// 14
	"Square",	// 15
	"Menu"		// 16 but not used
};
int PSP_KeysMapping[] = {
	0,		// Menu
	13,		// A
	14,		// B
	9,		// C
	4,		// Up
	6,		// Down
	7,		// Left
	5,		// Right
	3,		// Power
	8		// Shake
};

// Custom command line (NEW IN 0.5.0)
int clc_zoom = 4;
int clc_displayfps = 0;
const TCommandLineCustom CustomConf[] = {
	{ "zoom", &clc_zoom, COMMANDLINE_INT, 1, 4 },
	{ "displayfps", &clc_displayfps, COMMANDLINE_BOOL },
	{ "", NULL, COMMANDLINE_EOL }
};

// Platform menu (REQUIRED >= 0.4.4)
int UIItems_PlatformC(int index, int reason);
TUIMenu_Item UIItems_Platform[] = {
	PLATFORMDEF_GOBACK,
	{ 0,  1, "Zoom: %s", UIItems_PlatformC },
	{ 0,  2, "Display FPS: %s", UIItems_PlatformC },
	{ 0,  9, "Define Joystick...", UIItems_PlatformC },
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
				if (clc_zoom < 1) clc_zoom = 4;
				zoomchanged = 1;
				break;
			case 2: // Display FPS
				clc_displayfps = !clc_displayfps;
				break;
		}
	}
	if (reason == UIMENU_RIGHT) {
		switch (index) {
			case 1: // Zoom
				clc_zoom++;
				if (clc_zoom > 4) clc_zoom = 1;
				zoomchanged = 1;
				break;
			case 2: // Display FPS
				clc_displayfps = !clc_displayfps;
				break;
			case 9: // Define joystick
				JoystickEnterMenu();
				break;
		}
	}
	UIMenu_ChangeItem(UIItems_Platform, 1, "Zoom: %s", clc_zoom_txt[clc_zoom]);
	UIMenu_ChangeItem(UIItems_Platform, 2, "Display FPS: %s", clc_displayfps ? "Yes" : "No");
	if (zoomchanged) setup_screen();
	return 1;
}

// Setup screen
void setup_screen()
{
	TPokeMini_VideoSpec *videospec;

	if (clc_zoom == 1) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video1x1;
		ui_offset = (72 * 512) + 144;
		pm_offset = (104 * 512) + 192;
		UIMenu_SetDisplay(192, 128, PokeMini_RGB16, (uint8_t *)PokeMini_BG2, (uint16_t *)PokeMini_BG2_PalBGR16, (uint32_t *)PokeMini_BG2_PalBGR32);
	} else if (clc_zoom == 2) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video2x2;
		ui_offset = pm_offset = (72 * 512) + 144;
		UIMenu_SetDisplay(192, 128, PokeMini_RGB16, (uint8_t *)PokeMini_BG2, (uint16_t *)PokeMini_BG2_PalBGR16, (uint32_t *)PokeMini_BG2_PalBGR32);
	} else if (clc_zoom == 3) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video3x3;
		ui_offset = pm_offset = (40 * 512) + 96;
		UIMenu_SetDisplay(288, 192, PokeMini_RGB16, (uint8_t *)PokeMini_BG3, (uint16_t *)PokeMini_BG3_PalBGR16, (uint32_t *)PokeMini_BG3_PalBGR32);
	} else {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video4x4;
		ui_offset = pm_offset = (8 * 512) + 48;
		UIMenu_SetDisplay(384, 256, PokeMini_RGB16, (uint8_t *)PokeMini_BG4, (uint16_t *)PokeMini_BG4_PalBGR16, (uint32_t *)PokeMini_BG4_PalBGR32);
	}

	// Set video spec and check if is supported
	if (!PokeMini_SetVideo(videospec, 16, CommandLine.lcdfilter, CommandLine.lcdmode)) {
		PokeDPrint(POKEMSG_ERR, "Couldn't set video spec\n");
		exit(1);
	}
}

// Handle keys
void HandleKeys()
{
	SceCtrlData pad;
	sceCtrlReadBufferPositive(&pad, 1);
	JoystickAxisEvent(0, ((int)pad.Lx - 128) * 256);
	JoystickAxisEvent(1, ((int)pad.Ly - 128) * 256);
	JoystickBitsEvent(pad.Buttons);
}

// Sound stream
void audiostreamcallback(void *buf, unsigned int length, void *userdata)
{
	MinxAudio_GenerateEmulatedS16((int16_t *)buf, length, 2);
}

// Enable / Disable sound
void enablesound(int sound)
{
	static int soundenabled = 0;
	if ((!soundenabled) && sound) {
		// Enable sound
		pspAudioSetChannelCallback(0, audiostreamcallback, NULL);
	} else if ((soundenabled) && !sound) {
		// Disable sound
		pspAudioSetChannelCallback(0, NULL, NULL);
	}
	soundenabled = sound;
}

// Menu loop
void menuloop()
{
	// Stop sound
	enablesound(0);

	// Update EEPROM
	sceDisplayWaitVblank();
	UIMenu_SaveEEPDisplay_16((uint16_t *)PSP_DrawVideo + ui_offset, 512);
	PSP_Flip();
	PSP_ClearDraw();
	PokeMini_SaveFromCommandLines(0);

	while (emurunning && (UI_Status == UI_STATUS_MENU)) {
		// Slowdown to approx. 60fps
		sceDisplayWaitVblank();

		// Handle keys
		HandleKeys();

		// Process UI
		UIMenu_Process();

		// Screen rendering
		UIMenu_Display_16((uint16_t *)PSP_DrawVideo + ui_offset, 512);

		// Wait VSync & Render (72 Hz)
		PSP_Flip();
		PSP_ClearDraw();
	}

	// Flip and clear again
	PSP_Flip();
	PSP_ClearDraw();

	// Apply configs
	PokeMini_ApplyChanges();
	if (UI_Status == UI_STATUS_EXIT) emurunning = 0;
	else enablesound(CommandLine.sound);
}

// Main function
int main(int argc, char **argv)
{
	int battimeout = 0;
	char fpstxt[16];

	// Open debug files
	PokeDebugFOut = fopen("dbg_stdout.txt", "w");
	PokeDebugFErr = fopen("dbg_stderr.txt", "w");

	// Init video
	PokeDPrint(POKEMSG_OUT, "%s\n\n", AppName);
	PokeMini_InitDirs(argv[0], NULL);
	CommandLineInit();
	CommandLine.low_battery = 2;	// PSP can report battery status
	CommandLineConfFile("pokemini.cfg", "pokemini_psp.cfg", CustomConf);
	JoystickSetup("PSP", 0, 30000, PSP_KeysNames, 16, PSP_KeysMapping);

	// PSP Init and set screen
	PSP_Init();
	setup_screen();

	// Create emulator and load test roms
	PokeDPrint(POKEMSG_OUT, "Starting emulator...\n");
	PokeMini_Create(POKEMINI_GENSOUND | POKEMINI_AUTOBATT, 0);

	// Setup palette and LCD mode
	PokeMini_VideoPalette_Init(PokeMini_RGB16, 1);
	PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
	PokeMini_ApplyChanges();

	// Load stuff
	PokeMini_UseDefaultCallbacks();
	if (!PokeMini_LoadFromCommandLines("Using FreeBIOS", "EEPROM data will be discarded!")) {
		UI_Status = UI_STATUS_MENU;
	}

	// Enable sound & init UI
	PokeDPrint(POKEMSG_OUT, "Running emulator...\n");
	UIMenu_Init();
	enablesound(CommandLine.sound);
	sceCtrlSetSamplingCycle(0);
	sceCtrlSetSamplingMode(PSP_CTRL_MODE_ANALOG);

	// Emulator's loop
	u64 tickcurr;
	u64 fpsticknext,fpstickres = (u64)sceRtcGetTickResolution();
	u64 frmticknext, frmtickres = (u64)sceRtcGetTickResolution() / 36;
	sceRtcGetCurrentTick(&tickcurr);
	fpsticknext = tickcurr + fpstickres;
	frmticknext = tickcurr + frmtickres;
	int fps = 72, fpscnt = 0;
	strcpy(fpstxt, "");
	while (emurunning) {
		// Emulate 2 frames
		PokeMini_EmulateFrame();
		PokeMini_EmulateFrame();
		if (RequireSoundSync) {
			while (MinxAudio_SyncWithAudio()) sceKernelDelayThread(1000);
		} else {
			do {
				sceRtcGetCurrentTick(&tickcurr);
				sceKernelDelayThread(1000);
			} while (tickcurr < frmticknext);
			frmticknext = tickcurr + frmtickres;	// Aprox 36 times per sec
		}

		// Screen rendering
		PSP_ClearDraw();
		if (PokeMini_Rumbling) {
			PokeMini_VideoBlit((uint16_t *)PSP_DrawVideo + pm_offset + PokeMini_GenRumbleOffset(512), 512);
		} else {
			PokeMini_VideoBlit((uint16_t *)PSP_DrawVideo + pm_offset, 512);
		}
		LCDDirty = 0;

		// Display FPS counter
		if (clc_displayfps) {
			sceRtcGetCurrentTick(&tickcurr);
			if (tickcurr >= fpsticknext) {
				fpsticknext = tickcurr + fpstickres;
				fps = fpscnt;
				fpscnt = 0;
				sprintf(fpstxt, "%i FPS", fps);
			} else fpscnt++;
			UIDraw_String_16((uint16_t *)PSP_DrawVideo, 512, 4, 4, 10, fpstxt, UI_Font1_Pal16);
		}

		// Handle keys
		HandleKeys();

		// Menu
		if (UI_Status == UI_STATUS_MENU) menuloop();

		// Wait VSync & Render (72 Hz)
		PSP_Flip();

		// Check battery
		if (battimeout <= 0) {
			PokeMini_LowPower(scePowerIsLowBattery());
			battimeout = 600;
		} else battimeout--;
	}

	// Stop sound & free UI
	enablesound(0);
	UIMenu_Destroy();

	// Save Stuff
	PokeMini_SaveFromCommandLines(1);

	// Terminate...
	PokeDPrint(POKEMSG_OUT, "Shutdown emulator...\n");
	PokeMini_VideoPalette_Free();
	PokeMini_Destroy();

	// Close debug files
	fclose(PokeDebugFOut);
	fclose(PokeDebugFErr);

	// PSP Quit
	PSP_Quit();

	return 0;
}
