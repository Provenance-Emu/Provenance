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

#include <nds.h>
#include <fat.h>
#include <maxmod9.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

#include "PokeMini.h"
#include "Hardware.h"
#include "Joystick.h"
#include "PokeMini_ColorPal.h"

#include "UI.h"
#include "Video_x2.h"
#include "PokeMini_BG2.h"

#include "fps_counter_gfx.h"
#include "RumbleSupport.h"

const char *AppName = "PokeMini " PokeMini_Version " NDS";

const char *RumbleLevel[] = {
	"Off", "Weak", "Med.", "Max."
};

const char *RumbleInserted[] = {
	"No", "In"
};

// --------

// Joystick names and mapping (NEW IN 0.5.0)
char *NDS_KeysNames[] = {
	"Off",		// -1
	"A",		// 0
	"B",		// 1
	"Select",	// 2
	"Start",	// 3
	"Right",	// 4
	"Left",		// 5
	"Up",		// 6
	"Down",		// 7
	"R",		// 8
	"L",		// 9
	"X",		// 10
	"Y"		// 11
};
int NDS_KeysMapping[] = {
	2,		// Menu
	0,		// A
	1,		// B
	8,		// C
	6,		// Up
	7,		// Down
	5,		// Left
	4,		// Right
	3,		// Power
	9		// Shake
};

// Custom command line (NEW IN 0.5.0)
int clc_displayfps = 1, clc_rumblepak = 0;
const TCommandLineCustom CustomConf[] = {
	{ "displayfps", &clc_displayfps, COMMANDLINE_BOOL },
	{ "rumblepak", &clc_rumblepak, COMMANDLINE_INT, 0, 3 },
	{ "", NULL, COMMANDLINE_EOL }
};

// Platform menu (REQUIRED >= 0.4.4)
int UIItems_PlatformC(int index, int reason);
TUIMenu_Item UIItems_Platform[] = {
	PLATFORMDEF_GOBACK,
	{ 0,  1, "FPS Counter: %s", UIItems_PlatformC },
	{ 0,  2, "Rumble Pak: %s", UIItems_PlatformC },
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
				clc_displayfps = !clc_displayfps;
				break;
			case 2: // Rumble pak
				clc_rumblepak--;
				if (clc_rumblepak < 0) clc_rumblepak = 3;
				break;
		}
	}
	if (reason == UIMENU_RIGHT) {
		switch (index) {
			case 1: // FPS Counter
				clc_displayfps = !clc_displayfps;
				break;
			case 2: // Rumble pak
				clc_rumblepak++;
				if (clc_rumblepak > 3) clc_rumblepak = 0;
				break;
			case 9: // Define keys...
				JoystickEnterMenu();
				break;
		}
	}
	UIMenu_ChangeItem(UIItems_Platform, 1, "Display FPS: %s", clc_displayfps ? "Yes" : "No");
	UIMenu_ChangeItem(UIItems_Platform, 2, "Rumble Pak: %s (%s)", RumbleLevel[clc_rumblepak & 3], RumbleInserted[RumbleCheck() ? 1 : 0]);
	return 1;
}

// For the emulator loop and video
int emurunning = 1;
uint16_t *VIDEO8, *VIDEO16;
u16 *FPSCountGFX[12];		// 10 characters + "FPS"
int FPSCountIdx[16];
uint16_t VIDEOOFF[256*128];	// For menu graphics

// Handle keys
void HandleKeys()
{
	uint16_t keys;
	scanKeys();
	keys = keysHeld();
	if (UI_Status) keys = keysDownRepeat();	// Allow key repeat inside menu
	JoystickBitsEvent(keys);
}

// Rumble effect
void VBlankHandler()
{
	static int rumbleani = 0;

	// Rumble animation
	if ((PokeMini_Rumbling) && (UI_Status == UI_STATUS_GAME)) {
		if (clc_rumblepak) {
			if (clc_rumblepak == 3) RumbleEnable(1);
			else if (clc_rumblepak == 2) RumbleEnable(!(rumbleani & 1));
			else RumbleEnable(!(rumbleani & 3));
			rumbleani++;
		}
		REG_BG3Y = PokeMini_GenRumbleOffset(256);
	} else {
		if (clc_rumblepak) RumbleEnable(0);
		REG_BG3Y = 0;
	}

	// FPS counter
	if ((clc_displayfps) && (UI_Status == UI_STATUS_GAME)) {
		oamSet(&oamMain, 0,	// oam index
			4, 12, 0,	// x & y position, priority
			0, SpriteSize_16x16, SpriteColorFormat_16Color,	// pal index, sprite size and format
			FPSCountGFX[FPSCountIdx[0]],	// pointer to the loaded graphics
			-1, 0, FPSCountIdx[0] >= 10,	// sprite rotation data, double size, hide sprite
			 0, 0, 0	// vflip, hflip, mosaic
			);
		oamSet(&oamMain, 1,	// oam index
			16, 12, 0,	// x & y position, priority
			0, SpriteSize_16x16, SpriteColorFormat_16Color,	// pal index, sprite size and format
			FPSCountGFX[FPSCountIdx[1]],	// pointer to the loaded graphics
			-1, 0, FPSCountIdx[1] >= 10,	// sprite rotation data, double size, hide sprite
			 0, 0, 0	// vflip, hflip, mosaic
			);
		oamSet(&oamMain, 2,	// oam index
			28, 12, 0,	// x & y position, priority
			0, SpriteSize_16x16, SpriteColorFormat_16Color,	// pal index, sprite size and format
			FPSCountGFX[FPSCountIdx[2]],	// pointer to the loaded graphics
			-1, 0, FPSCountIdx[2] >= 10,	// sprite rotation data, double size, hide sprite
			 0, 0, 0	// vflip, hflip, mosaic
			);
		oamUpdate(&oamMain);
	}
}

// FPS Counter
volatile u32 vfpscounter = 0;
void FPSCounterHandler()
{
	vfpscounter++;
}

// Sound stream
mm_word audiostreamcallback( mm_word length, mm_addr dest, mm_stream_formats format )
{
	MinxAudio_GenerateEmulatedS8(dest, length, 1);
	return length;
}
void enablesound(int enable)
{
	static int soundenabled = 0;
	if ((!soundenabled) && (enable)) {
		// Enable sound
		mm_stream mystream;
		mystream.sampling_rate = 22050;
		mystream.buffer_length = 1024;
		mystream.callback = audiostreamcallback;
		mystream.format = MM_STREAM_8BIT_MONO;
		mystream.timer = MM_TIMER0;
		mystream.manual = false;
		mmStreamOpen(&mystream);
	} else if ((soundenabled) && (!enable)) {
		// Disable sound
		mmStreamClose();
	}
	soundenabled = enable;
}

// Menu loop
void menuloop()
{
	// Stop sound
	enablesound(0);

	// Set 15-bits mode & create offscreen buffer
	oamDisable(&oamMain);
	REG_BG3CNT = BG_BMP16_256x256;
	memset(BG_GFX, 0, 256*256*2);
	BG_PALETTE[0] = 0x0000;
	memset(VIDEOOFF, 0, 256*128*2);

	// Update EEPROM
	UIMenu_SaveEEPDisplay_16((uint16_t *)VIDEOOFF, 256);
	memcpy(VIDEO16, VIDEOOFF, 256*128*2);
	PokeMini_SaveFromCommandLines(0);

	// Menu's loop
	while (emurunning && (UI_Status == UI_STATUS_MENU)) {
		// Handle keys
		HandleKeys();

		// Process UI
		UIMenu_Process();

		// Screen rendering
		UIMenu_Display_16((uint16_t *)VIDEOOFF, 256);

		// Wait VSync & Render (72 Hz)
		memcpy(VIDEO16, VIDEOOFF, 256*128*2);
	}

	// Apply configs
	PokeMini_ApplyChanges();
	if (UI_Status == UI_STATUS_EXIT) emurunning = 0;
	else enablesound(CommandLine.sound);

	// Restore 8-bits mode
	REG_BG3CNT = BG_BMP8_256x256;
	memset(BG_GFX, 0, 256*256*2);
	if (clc_displayfps) oamEnable(&oamMain);

	// Copy palette and refresh
	if (CommandLine.lcdmode == 3) memcpy(BG_PALETTE, PokeMini_ColorPalRGB15, 256*2);
	else memcpy(BG_PALETTE, VidPalette16, 256*2);
	PokeMini_VideoBlit(VIDEO8, 128);
}

// Main function
int main(int argc, char **argv)
{
	//int battimeout = 0;
	int fpscount = 0;
	u32 time = 0, nexttime = 0, fpstime = 0;
	char fpscountstr[32];
	int i;

	// Setup interrupts
	irqSet(IRQ_VBLANK, VBlankHandler);
	timerStart(3, ClockDivider_1024, timerFreqToTicks_1024(72), FPSCounterHandler);	// 72 Hz Timer
	irqEnable(IRQ_VBLANK | IRQ_TIMER3);
	RumbleCheck();

	// Console init
	consoleDemoInit();

	// Initialize libfat
	if (!fatInitDefault()) {
		printf("Error, libfat failed!\n");
	}

	// Init video
	printf("%s\n\n", AppName);
	if (argv) PokeMini_InitDirs(argv[0], NULL);
	else PokeMini_InitDirs("/", NULL);
	CommandLineInit();
	//CommandLine.low_battery = 2;	// NDS can report battery status
	CommandLine.lcdfilter = 0;	// Disable LCD filtering
	CommandLine.lcdmode = LCDMODE_3SHADES;
	CommandLineConfFile("pokemini.cfg", "pokemini_nds.cfg", CustomConf);
	JoystickSetup("NDS", 0, 30000, NDS_KeysNames, 12, NDS_KeysMapping);
	keysSetRepeat(30, 8);

	// Initialize NDS video
	printf("Initializing video...\n");
	videoSetMode(MODE_5_2D | DISPLAY_BG3_ACTIVE);
	vramSetPrimaryBanks(VRAM_A_MAIN_BG_0x06000000, VRAM_B_MAIN_SPRITE_0x06400000, VRAM_C_SUB_BG_0x06200000, VRAM_D_SUB_SPRITE);

	// NDS Sprites
	oamInit(&oamMain, SpriteMapping_1D_32, false);
	for (i=0; i<12; i++) {
		FPSCountGFX[i] = oamAllocateGfx(&oamMain, SpriteSize_16x16, SpriteColorFormat_16Color);
		dmaCopy(&fps_counter_gfxTiles[i*64], FPSCountGFX[i], 128);
	}
	dmaCopy(fps_counter_gfxPal, SPRITE_PALETTE, 512);
	FPSCountIdx[0] = FPSCountIdx[1] = 10;
	FPSCountIdx[2] = 0;
	oamSet(&oamMain, 4,	// oam index
		40, 12, 0,	// x & y position, priority
		0, SpriteSize_16x16, SpriteColorFormat_16Color,	// pal index, sprite size and format
		FPSCountGFX[10],	// pointer to the loaded graphics
		-1, 0, 0,	// sprite rotation data, double size, hide sprite
		 0, 0, 0	// vflip, hflip, mosaic
		);
	oamSet(&oamMain, 5,	// oam index
		56, 12, 0,	// x & y position, priority
		0, SpriteSize_16x16, SpriteColorFormat_16Color,	// pal index, sprite size and format
		FPSCountGFX[11],	// pointer to the loaded graphics
		-1, 0, 0,	// sprite rotation data, double size, hide sprite
		 0, 0, 0	// vflip, hflip, mosaic
		);

	// NDS Background
	REG_BG3CNT = BG_BMP8_256x256;
	REG_BG3PA = 256;     // 1.0
	REG_BG3PB = 0;       // 0.0
	REG_BG3PC = 0;       // 0.0
	REG_BG3PD = 256;     // 1.0
	REG_BG3X = 0;        // 0.0
	REG_BG3Y = 0;        // 0.0
	memset(BG_GFX, 0, 256*256*2);
	VIDEO8 = (uint16_t *)&BG_GFX[(32 * 128) + 16];
	VIDEO16 = (uint16_t *)&BG_GFX[(64 * 128) + 32];

	// Set video spec and check if is supported
	if (!PokeMini_SetVideo((TPokeMini_VideoSpec *)&PokeMini_Video2x2_NDS, 16, CommandLine.lcdfilter, CommandLine.lcdmode)) {
		fprintf(stderr, "Couldn't set video spec\n");
		exit(1);
	}
	UIMenu_SetDisplay(192, 128, PokeMini_RGB15, (uint8_t *)PokeMini_BG2, (uint16_t *)PokeMini_BG2_PalRGB15, (uint32_t *)PokeMini_BG2_PalRGB15);

	// Initialize maxmod
	printf("Initializing maxmod...\n");
	mm_ds_system sys;
	sys.mod_count = 0;
	sys.samp_count = 0;
	sys.mem_bank = 0;
	sys.fifo_channel = FIFO_MAXMOD;
	mmInit(&sys);

	// Create emulator and load test roms
	printf("Starting emulator...\n");
	if (!PokeMini_Create(POKEMINI_GENSOUND, 0)) {
		fprintf(stderr, "Error while initializing emulator.\n");
	}

	// Setup palette and LCD mode
	PokeMini_VideoPalette_Init(PokeMini_RGB15, 0);
	PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
	PokeMini_ApplyChanges();
	if (CommandLine.lcdmode == 3) memcpy(BG_PALETTE, PokeMini_ColorPalRGB15, 256*2);
	else memcpy(BG_PALETTE, VidPalette16, 256*2);

	// Load stuff
	PokeMini_UseDefaultCallbacks();
	if (!PokeMini_LoadFromCommandLines("Using FreeBIOS", "EEPROM data will be discarded!")) {
		UI_Status = UI_STATUS_MENU;
	}

	// Enable sound & init UI
	printf("Running emulator...\n");
	UIMenu_Init();
	enablesound(CommandLine.sound);

	// Emulator's loop
	while (emurunning) {
		// Emulate 1 frame
		PokeMini_EmulateFrame();
		do {
			time = vfpscounter;
		} while (time < nexttime);
		nexttime = time + 1;

		// FPS counter
		fpscount++;
		if (time >= fpstime) {
			sprintf(fpscountstr, "%3i", fpscount);
			if (fpscountstr[0] != ' ') FPSCountIdx[0] = fpscountstr[0] - '0';
			else FPSCountIdx[0] = 10;
			if (fpscountstr[1] != ' ') FPSCountIdx[1] = fpscountstr[1] - '0';
			else FPSCountIdx[1] = 10;
			if (fpscountstr[2] != ' ') FPSCountIdx[2] = fpscountstr[2] - '0';
			else FPSCountIdx[2] = 10;
			fpscount = 0;
			fpstime = time + 74;
		}

		// Screen rendering if LCD changes
		if (LCDDirty) {
			PokeMini_VideoBlit(VIDEO8, 128);
			LCDDirty--;
		}

		// Handle keys
		HandleKeys();

		// Menu
		if (UI_Status == UI_STATUS_MENU) menuloop();

		// Check battery
		/*if (battimeout <= 0) {
			PokeMini_LowPower(getBatteryLevel() < 4);
			battimeout = 600;
		} else battimeout--;*/
	}

	// Stop sound & free UI
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
