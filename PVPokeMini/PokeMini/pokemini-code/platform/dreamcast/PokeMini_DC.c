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
// KOS Documentation: http://gamedev.allusion.net/docs/kos-current/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

#include <kos.h>
#include <dc/spu.h>
#include <dc/sound/sound.h>
#include <arm/aica_cmd_iface.h>

#define SPU_RAM_BASE    0xa0800000

#include "PokeMini.h"
#include "Hardware.h"
#include "Video_x3.h"
#include "PokeMini_BG3.h"
#include "Joystick.h"

#include "VMUIcon.h"

const char *AppName = "PokeMini " PokeMini_Version " Dreamcast";

KOS_INIT_FLAGS(INIT_DEFAULT);

// --------

int emurunning = 1;
unsigned short *VIDEO;
int PixPitch, ScOffP;

#define DC_CONT_TRG_DEAD	80
#define DC_CONT_JOY_DEAD	40
#define CONT_LTRIG	0x10000
#define CONT_RTRIG	0x20000

// Sound buffer size
#define SOUNDBUFFER	2048
#define PMSNDBUFFER	(SOUNDBUFFER*2)

int VideoMode(int pal);

// Joystick names and mapping (NEW IN 0.5.0)
char *DCJoy_KeysNames[] = {
	"Off",		// -1
	"C",		// 0
	"B",		// 1
	"A",		// 2
	"Start",	// 3
	"DPad Up",	// 4
	"DPad Down",	// 5
	"DPad Left",	// 6
	"DPad Right",	// 7
	"Z",		// 8
	"Y",		// 9
	"X",		// 10
	"D",		// 11
	"DPad2 Up",	// 12
	"DPad2 Down",	// 13
	"DPad2 Left",	// 14
	"DPad2 Right",	// 15
	"L Trigger",	// 16
	"R Trigger"	// 17
};
int DCJoy_KeysMapping[] = {
	10,		// Menu
	1,		// A
	2,		// B
	17,		// C
	4,		// Up
	5,		// Down
	6,		// Left
	7,		// Right
	3,		// Power
	16		// Shake
};

// Custom command line (NEW IN 0.5.0)
int clc_tvout_pal = 0;
int clc_vmu_eeprom = 0;
int clc_displayfps = 0;
const TCommandLineCustom CustomConf[] = {
	{ "tvout_pal", &clc_tvout_pal, COMMANDLINE_BOOL },
	{ "vmu_eeprom", &clc_vmu_eeprom, COMMANDLINE_BOOL },
	{ "displayfps", &clc_displayfps, COMMANDLINE_BOOL },
	{ "", NULL, COMMANDLINE_EOL }
};

// Platform menu (REQUIRED >= 0.4.4)
int UIItems_PlatformC(int index, int reason);
TUIMenu_Item UIItems_Platform[] = {
	PLATFORMDEF_GOBACK,
	{ 0,  1, "TV Out: %s", UIItems_PlatformC },
	{ 0,  2, "EEPROM: %s", UIItems_PlatformC },
	{ 0,  3, "Display FPS: %s", UIItems_PlatformC },
	{ 0,  9, "Define Joystick...", UIItems_PlatformC },
	PLATFORMDEF_SAVEOPTIONS,
	PLATFORMDEF_END(UIItems_PlatformC)
};
int UIItems_PlatformC(int index, int reason)
{
	int videochanged = 0;
	if (reason == UIMENU_OK) reason = UIMENU_RIGHT;
	if (reason == UIMENU_CANCEL) UIMenu_PrevMenu();
	if (reason == UIMENU_LEFT) {
		switch (index) {
			case 1: // TV Out
				clc_tvout_pal = !clc_tvout_pal;
				videochanged = 1;
				break;
			case 2: // VMU EEPROM
				clc_vmu_eeprom = !clc_vmu_eeprom;
				break;
			case 3: // Display FPS
				clc_displayfps = !clc_displayfps;
				break;
		}
	}
	if (reason == UIMENU_RIGHT) {
		switch (index) {
			case 1: // TV Out
				clc_tvout_pal = !clc_tvout_pal;
				videochanged = 1;
				break;
			case 2: // VMU EEPROM
				clc_vmu_eeprom = !clc_vmu_eeprom;
				break;
			case 3: // Display FPS
				clc_displayfps = !clc_displayfps;
				break;
			case 9: // Define keys
				JoystickEnterMenu();
				break;
		}
	}
	if (videochanged) VideoMode(clc_tvout_pal);
	UIMenu_ChangeItem(UIItems_Platform, 1, "TV Out: %s", clc_tvout_pal ? "PAL" : "NTSC");
	UIMenu_ChangeItem(UIItems_Platform, 2, "EEPROM: %s", clc_vmu_eeprom ? "Auto write to VMU" : "Write discarded");
	UIMenu_ChangeItem(UIItems_Platform, 3, "Display FPS: %s", clc_displayfps ? "Yes" : "No");
	return 1;
}

// Set video
int VideoMode(int pal)
{
	if (vid_check_cable() == CT_VGA) {
		// VGA
		vid_set_mode(DM_320x240_VGA, PM_RGB565);
	} else {
		// Composite or RGB
		if (pal) {
			vid_set_mode(DM_320x240_PAL, PM_RGB565);
		} else {
			vid_set_mode(DM_320x240_NTSC, PM_RGB565);
		}
	}
	PixPitch = 320;
	vid_border_color(0, 0, 0);
	memset(vram_s, 0, 1024*1024*2);
	VIDEO = vram_s + (24 * PixPitch) + 16;

	return 1;
}

// Handle keys
void HandleKeys()
{
	maple_device_t *cont;
	cont_state_t *state;
	uint32_t keys;

	cont = maple_enum_type(0, MAPLE_FUNC_CONTROLLER);
	if (!cont) return;
	state = (cont_state_t *)maple_dev_status(cont);
	if (!state) return;

	JoystickAxisEvent(0, state->joyx);
	JoystickAxisEvent(1, state->joyy);

	keys = (state->buttons & 0xFFFF)
	 | (state->ltrig > DC_CONT_TRG_DEAD ? CONT_LTRIG : 0)
	 | (state->rtrig > DC_CONT_TRG_DEAD ? CONT_RTRIG : 0);
	JoystickBitsEvent(keys);
}

// Emulator sound
enum {
	soundstate_idle,
	soundstate_start,
	soundstate_playing,
	soundstate_stop,
	soundstate_end,
	soundstate_endok,
};
volatile int emulatorsoundstate = soundstate_idle;
static semaphore_t *emulatorsound_sem = NULL;
int16_t soundsamp[SOUNDBUFFER / 2];
void *emulatorsoundthr(void *ptr)
{
	AICA_CMDSTR_CHANNEL(tmp, cmd, chan);
	int sndpos, buff_sndpos;
	uint32 soundptr;

	snd_init();
	emulatorsound_sem = sem_create(0);
	buff_sndpos = SOUNDBUFFER;

	// Allocate sound buffer
	soundptr = snd_mem_malloc(PMSNDBUFFER);
	spu_memset(soundptr, 0x00, PMSNDBUFFER);
	snd_sh4_to_aica_stop();

	// Setup channel
	cmd->cmd = AICA_CMD_CHAN;
	cmd->timestamp = 0;
	cmd->size = AICA_CMDSTR_CHANNEL_SIZE;
	cmd->cmd_id = 0;	// (1 << 0)
	chan->cmd = AICA_CH_CMD_START | AICA_CH_START_DELAY;
	chan->base = soundptr;
	chan->type = AICA_SM_16BIT;
	chan->length = PMSNDBUFFER / 2;
	chan->loop = 1;
	chan->loopstart = 0;
	chan->loopend = PMSNDBUFFER / 2;
	chan->freq = MINX_AUDIOFREQ;
	chan->vol = 255;
	chan->pan = 128;
	snd_sh4_to_aica(tmp, cmd->size);
	snd_sh4_to_aica_start();

	while (emulatorsoundstate != soundstate_end) {
		switch(emulatorsoundstate) {
			case soundstate_idle:
				sem_wait(emulatorsound_sem);
				break;
			case soundstate_start:
				cmd->cmd_id = 1 << 0;
				chan->cmd = AICA_CH_CMD_START | AICA_CH_START_SYNC;
				snd_sh4_to_aica(tmp, cmd->size);
				emulatorsoundstate = soundstate_playing;
				break;
			case soundstate_playing:
				sndpos = g2_read_32(SPU_RAM_BASE + AICA_CHANNEL(0) + offsetof(aica_channel_t, pos)) << 1;
				while(buff_sndpos < sndpos && (buff_sndpos + SOUNDBUFFER) > sndpos) {
					thd_pass();
					sndpos = g2_read_32(SPU_RAM_BASE + AICA_CHANNEL(0) + offsetof(aica_channel_t, pos)) << 1;
				};
				MinxAudio_GenerateEmulatedS16(soundsamp, SOUNDBUFFER / 2, 1);
				spu_memload(soundptr + buff_sndpos, soundsamp, SOUNDBUFFER);
				buff_sndpos += SOUNDBUFFER;
				if (buff_sndpos >= PMSNDBUFFER) buff_sndpos = 0;
				break;
			case soundstate_stop:
				if (emulatorsoundstate != soundstate_idle) {
					snd_sh4_to_aica_stop();
					cmd->cmd_id = 1 << 0;
					chan->cmd = AICA_CH_CMD_STOP;
					snd_sh4_to_aica(tmp, cmd->size);
					spu_memset(soundptr, 0x00, PMSNDBUFFER);
					snd_sh4_to_aica_start();
				}
				emulatorsoundstate = soundstate_idle;
				break;
		}
		thd_pass();
	}
	snd_sh4_to_aica_stop();
	cmd->cmd_id = 1 << 0;
	chan->cmd = AICA_CH_CMD_STOP;
	snd_sh4_to_aica(tmp, cmd->size);
	snd_sh4_to_aica_start();
	snd_mem_free(soundptr);
	emulatorsoundstate = soundstate_endok;

	return NULL;
}

// Enable / Disable sound
void enablesound(int sound)
{
	static int lastsound = 0;
	MinxAudio_ChangeEngine(sound);
	if (sound && !lastsound) {
		// Enabling
		emulatorsoundstate = soundstate_start;
		sem_signal(emulatorsound_sem);
		while(emulatorsoundstate != soundstate_playing) thd_pass();
	}
	if (!sound && lastsound) {
		// Disabling
		emulatorsoundstate = soundstate_stop;
		sem_signal(emulatorsound_sem);
		while(emulatorsoundstate != soundstate_idle) thd_pass();
	}
	lastsound = sound;
}

const char *VMUDevName[8] = {
	"a1", "a2",
	"b1", "b2",
	"c1", "c2",
	"d1", "d2"
};

// Transfer VMU file to RAM
int loadFileDCRAM(const char *vmufile, const char *ramfile)
{
	maple_device_t *vmu;
	vmu_pkg_t pkg;
	uint8 *pkg_out;
	FILE *fp;
	file_t f;
	int dev, pkg_size;
	char savfile[64];

	// Search a VMU with the file
	for (dev = 0; dev < 8; dev++) {
		vmu = maple_enum_dev(dev >> 1, (dev & 1) + 1);
		if (!vmu || !vmu->valid || !(vmu->info.functions & MAPLE_FUNC_MEMCARD)) continue;
		sprintf(savfile, "/vmu/%s/%s", VMUDevName[dev], vmufile);
		f = fs_open(savfile, O_RDONLY);
		if (f != FILEHND_INVALID) {
			fs_close(f);
			break;
		}
	}
	if (dev == 8) {
		// No VMU found, return error
		return 0;
	}
	printf("VMU load at %s\n", savfile);

	// Read package
	fp = fopen(savfile, "rb");
	fseek(fp, 0, SEEK_END);
	pkg_size = ftell(fp);
	fseek(fp, 0, SEEK_SET);
	pkg_out = (uint8 *)malloc(pkg_size);
	fread(pkg_out, pkg_size, 1, fp);
	fclose(fp);
	vmu_pkg_parse(pkg_out, &pkg);

	// Copy data
	fp = fopen(ramfile, "wb");
	fwrite(pkg.data, pkg.data_len, 1, fp);
	fclose(fp);

	free(pkg_out);
	return 1;

}

// Transfer RAM file to VMU
int saveFileDCRAM(const char *vmufile, const char *ramfile, const char *desc_short, const char *desc_long)
{
	maple_device_t *vmu;
	vmu_pkg_t pkg;
	uint8 *pkg_out, *data_out;
	FILE *fp;
	file_t f;
	int dev, pkg_size, blocks_freed = 0;
	int data_len;
	char savfile[64];

	// Read RAM file
	fp = fopen(ramfile, "rb");
	if (!fp) {
		printf("RAM file %s not found!\n", ramfile);
		return 0;
	}
	fseek(fp, 0, SEEK_END);
	data_len = ftell(fp);
	fseek(fp, 0, SEEK_SET);
	data_out = (uint8 *)malloc(data_len);
	fread(data_out, data_len, 1, fp);
	fclose(fp);

	// Setup package
	strcpy(pkg.desc_long, desc_long);
	strcpy(pkg.desc_short, desc_short);
	strcpy(pkg.app_id, "PokeMini");
	pkg.icon_cnt = 1;
	pkg.icon_anim_speed = 0;
	memcpy(pkg.icon_pal, vmuicon_pal, 32);
	pkg.icon_data = vmuicon_img;
	pkg.eyecatch_type = VMUPKG_EC_NONE;
	pkg.data_len = data_len;
	pkg.data = data_out;
	vmu_pkg_build(&pkg, &pkg_out, &pkg_size);

	// Detect a suitable VMU
	// Search a VMU with the file
	for (dev = 0; dev < 8; dev++) {
		vmu = maple_enum_dev(dev >> 1, (dev & 1) + 1);
		if (!vmu || !vmu->valid || !(vmu->info.functions & MAPLE_FUNC_MEMCARD)) continue;
		sprintf(savfile, "/vmu/%s/%s", VMUDevName[dev], vmufile);
		f = fs_open(savfile, O_RDONLY);
		if (f != FILEHND_INVALID) {
			fs_close(f);
			break;
		}
	}
	if (dev == 8) {
		// No file found, try to find a VMU with enough free space
		for (dev = 0; dev < 8; dev++) {
			vmu = maple_enum_dev(dev >> 1, (dev & 1) + 1);
			if (!vmu || !vmu->valid || !(vmu->info.functions & MAPLE_FUNC_MEMCARD)) continue;
			sprintf(savfile, "/vmu/%s/%s", VMUDevName[dev], vmufile);
			if (vmufs_free_blocks(vmu) >= (pkg_size >> 9)) break;
		}
	}
	if (dev == 8) {
		// No VMU free, return error
		free(data_out);
		free(pkg_out);
		return -2;
	}
	printf("VMU save at %s\n", savfile);

	// Check file if there's one
	f = fs_open(savfile, O_RDONLY);
	if (f != FILEHND_INVALID) {
		blocks_freed = fs_total(f) >> 9;
		fs_close(f);
	}

	// Make sure there's enough free space on the VMU
	if (vmufs_free_blocks(vmu) + blocks_freed < (pkg_size >> 9)) {
		free(data_out);
		free(pkg_out);
		return -2;
	}

	// Open file and write
	if(!(fp = fopen(savfile, "wb"))) {
		free(data_out);
		free(pkg_out);
		return 0;
	}
	if (fwrite(pkg_out, 1, pkg_size, fp) != (size_t)pkg_size) {
		fclose(fp);
		free(data_out);
		free(pkg_out);
		return 0;
	}

	fclose(fp);
	free(data_out);
	free(pkg_out);
	return 1;
}

// Read configurations
int loadConfs(const char *filename, const char *platcfgfile)
{
	if (!loadFileDCRAM("pokemini.sav", filename)) return 0;
	if (!loadFileDCRAM("pokemini.sDC", platcfgfile)) return 0;
	return 1;
}

// Write configurations
int saveConfs(int success, const char *filename, const char *platcfgfile)
{
	printf("Success is %d\n", success);
	if (!success) return 0;
	if (!saveFileDCRAM("pokemini.sav", filename, "Configurations", "PokeMini Common Conf.")) return 0;
	if (!saveFileDCRAM("pokemini.sDC", platcfgfile, "Configurations", "PokeMini Dreamcast Conf.")) return 0;
	return 1;
}

// Read EEPROM
int loadEEPROM(const char *filename)
{
	FILE *fp;

	// Transfer VMU to RAM file
	if (!loadFileDCRAM("pokemini.eep", filename)) return 0;

	// Read EEPROM from RAM file
	fp = fopen(filename, "rb");
	if (!fp) return 0;
	fread(EEPROM, 8192, 1, fp);
	fclose(fp);

	return 1;
}

// Write EEPROM
int saveEEPROM(const char *filename)
{
	FILE *fp;

	// Silently exit on EEPROM discard
	if (!clc_vmu_eeprom) return 1;

	// Write EEPROM to RAM file
	fp = fopen(filename, "wb");
	if (!fp) return 0;
	fwrite(EEPROM, 8192, 1, fp);
	fclose(fp);

	// Transfer RAM file to VMU
	if (!saveFileDCRAM("pokemini.eep", filename, "EEPROM", "PokeMini EEPROM data")) return 0;

	return 1;
}

// Menu loop
void menuloop()
{
	uint16_t *VIDEOOFF;

	// Stop sound
	enablesound(0);

	// Create offscreen buffer
	VIDEOOFF = (uint16_t *)malloc(PixPitch*192*2);
	memset(VIDEOOFF, 0, PixPitch*192*2);

	// Update EEPROM
	UIMenu_SaveEEPDisplay_16((uint16_t *)VIDEOOFF, PixPitch);
	memcpy(VIDEO, VIDEOOFF, PixPitch*192*2);
	PokeMini_SaveFromCommandLines(0);

	// Menu's loop
	while (emurunning && (UI_Status == UI_STATUS_MENU)) {
		// Delay some time
		thd_sleep(16);

		// Handle keys
		HandleKeys();

		// Process UI
		UIMenu_Process();

		// Screen rendering
		UIMenu_Display_16((uint16_t *)VIDEOOFF, PixPitch);

		// Copy offscreen to display
		memcpy(VIDEO, VIDEOOFF, PixPitch*192*2);
	}

	// Free offscreen buffer and apply configs
	free(VIDEOOFF);
	vid_border_color(0, 0, 0);

	// Apply configs
	CommandLine.eeprom_share = 1;
	PokeMini_ApplyChanges();
	if (UI_Status == UI_STATUS_EXIT) emurunning = 0;
	else if (CommandLine.sound) enablesound(CommandLine.sound);
	PokeMini_VideoBlit(VIDEO, PixPitch);
}

// Main function
int main(int argc, char **argv)
{
	int rumbling_old = 0;
	char fpstxt[16];

	// Setup custom EEPROM access
	PokeMini_PreConfigLoad = loadConfs;
	PokeMini_PostConfigSave = saveConfs;
	PokeMini_CustomLoadEEPROM = loadEEPROM;
	PokeMini_CustomSaveEEPROM = saveEEPROM;

	// Process no arguments
	printf("%s\n\n", AppName);
	PokeMini_InitDirs("/cd/PokeMini", NULL);
	CommandLineInit();
	CommandLineConfFile("/ram/PokeMini.cfg", "/ram/PokeMini.cDC", CustomConf);
	CommandLine.sound = CommandLine.sound ? 1 : 0;
	CommandLine.eeprom_share = 1;
	JoystickSetup("Dreamcast", 0, DC_CONT_JOY_DEAD, DCJoy_KeysNames, 18, DCJoy_KeysMapping);

	// Load EEPROM to RAM
	strcpy(CommandLine.eeprom_file, "/ram/PokeMini.eep");
	loadEEPROM(CommandLine.eeprom_file);

	// Allocate sound stream
	emulatorsoundstate = soundstate_idle;
	if (!thd_create(1, emulatorsoundthr, NULL)) {
		printf("Error creating sound thread\n");
	}

	// Set video spec and check if is supported
	if (!PokeMini_SetVideo((TPokeMini_VideoSpec *)&PokeMini_Video3x3, 16, CommandLine.lcdfilter, CommandLine.lcdmode)) {
		fprintf(stderr, "Couldn't set video spec\n");
		exit(1);
	}
	UIMenu_SetDisplay(288, 192, PokeMini_BGR16, (uint8_t *)PokeMini_BG3, (uint16_t *)PokeMini_BG3_PalBGR16, (uint32_t *)PokeMini_BG3_PalBGR32);

	// Initialize video
	VideoMode(0);

	// Initialize the emulator
	printf("Starting emulator...\n");
	if (!PokeMini_Create(POKEMINI_GENSOUND, 0)) {
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
	printf("Running emulator...\n");
	UIMenu_Init();
	enablesound(CommandLine.sound);

	// Emulator's loop
	uint64 time = 0, nexttime = 0, fpsnexttime = 0;
	int fps = 72, fpscnt = 0;
	strcpy(fpstxt, "");
	while (emurunning) {
		// Emulate 1 frame
		PokeMini_EmulateFrame();
		do {
			time = timer_us_gettime64();
		} while (time < nexttime);
		nexttime = time + 13888;

		// Screen rendering
		if (PokeMini_Rumbling || rumbling_old) {
			PokeMini_VideoRect_16(VIDEO, PixPitch, 0, -2, PixPitch, 2, 0x0000);
			PokeMini_VideoRect_16(VIDEO, PixPitch, 0, 192, PixPitch, 2, 0x0000);
			rumbling_old = PokeMini_Rumbling;
		}
		if (LCDDirty) {
			if (PokeMini_Rumbling) {
				PokeMini_VideoBlit(VIDEO + PokeMini_GenRumbleOffset(PixPitch), PixPitch);
			} else {
				PokeMini_VideoBlit(VIDEO, PixPitch);
			}
			LCDDirty--;
		}

		// Display FPS counter
		if (clc_displayfps) {
			time = timer_us_gettime64();
			if (time >= fpsnexttime) {
				fpsnexttime = time + 1000000;
				fps = fpscnt;
				fpscnt = 0;
				sprintf(fpstxt, "%i FPS", fps);
			} else fpscnt++;
			UIDraw_String_16(VIDEO, PixPitch, 4, 4, 10, fpstxt, UI_Font1_Pal16);
		}

		// Handle keys
		HandleKeys();

		// Menu
		if (UI_Status == UI_STATUS_MENU) menuloop();
		thd_pass();
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

	// Destroy sound stream
	emulatorsoundstate = soundstate_end;
	sem_signal(emulatorsound_sem);
	while(emulatorsoundstate != soundstate_endok) thd_pass();

	// Going back to dctool
	printf("Exit!\n");

	return 0;
}
