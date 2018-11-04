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

#include <windows.h>
#include <commctrl.h>
#include <mmsystem.h>
#include "PokeMini_Win32.h"
#include "Win32Stuffz.h"
#include "VideoRend.h"
#include "AudioRend.h"
#include "CustomPalEdit.h"
#include "CustomContrast.h"
#include "CustomBright.h"
#include "DefineInput.h"
#include "Joystick_DInput.h"

#include "PokeMini.h"
#include "Hardware.h"
#include "ExportBMP.h"
#include "ExportWAV.h"
#include "Video_x1.h"
#include "Video_x2.h"
#include "Video_x3.h"
#include "Video_x4.h"
#include "Video_x5.h"
#include "Video_x6.h"
#include "KeybWinMap.h"

const char *AppName = "PokeMini " PokeMini_Version;
HINSTANCE hInst = NULL;		// Current instance
HWND hMainWnd = NULL;		// Current window header
HMENU hMainMenu = NULL;		// Current menu header
RECT rWindowed;				// Windowed rectangle

const char *AboutTxt = "PokeMini " PokeMini_Version " Win32"
	"\n\n"
	"Coded by JustBurn\n"
	"Thanks to p0p, Dave|X,\n"
	"Onori, goldmono, Agilo,\n"
	"DarkFader, asterick,\n"
	"MrBlinky, Wa, Lupin and\n"
	"everyone in #pmdev on\n"
	"IRC EFNET!\n\n"
	"Please check readme.txt\n\n"
	"For latest version visit:\n"
	"http://pokemini.sourceforge.net/\n\n"
	"Special thanks to:\n"
	"Museum of Electronic Games & Art\n"
	"http://m-e-g-a.org\n"
	"MEGA supports preservation\n"
	"projects of digital art & culture\n";

const char *WebsiteTxt = "http://pokemini.sourceforge.net/";

// Variables
volatile int emumodeE = EMUMODE_STOP;	// Emulation thread
volatile int emumodeA = EMUMODE_STOP;	// Application thread
int FirstROMLoad = 1;
int emulimiter = 1;
int PMWidth, PMHeight, FPS;
int BytPitch, PixPitch, PMOff;

// Sound buffer size
#define SOUNDBUFFER	4096
#define PMSNDBUFFER	(SOUNDBUFFER*2)

// --------------------------------------------------------------------------------

// Custom command line (NEW IN 0.5.0)
int clc_zoom = 4, clc_fullscreen = 0;
const TCommandLineCustom CustomArgs[] = {
	{ "-zoom", &clc_zoom, COMMANDLINE_INT, 1, 6 },
	{ "-windowed", &clc_fullscreen, COMMANDLINE_INTSET, 0 },
	{ "-fullscreen", &clc_fullscreen, COMMANDLINE_INTSET, 1 },
	{ "", NULL, COMMANDLINE_EOL }
};
// Win32 custom conf
int wclc_winx = 0;
int wclc_winy = 0;
int wclc_winw = 400;
int wclc_winh = 272;
int wclc_autorun = 1;
int wclc_pauseinactive = 1;
int wclc_inactivestate = 2;	// 0 = Inactive, 1 = Active, 2 = Stoped
int wclc_videorend = 2;
int wclc_audiorend = 1;
int wclc_forcefeedback = 1;
char wclc_recent[10][PMTMPV];
const int wclc_recent_ids[10] = {ID_RECENT0, ID_RECENT1, ID_RECENT2, ID_RECENT3, ID_RECENT4, ID_RECENT5, ID_RECENT6, ID_RECENT7, ID_RECENT8, ID_RECENT9};
const TCommandLineCustom CustomConf[] = {
	{ "zoom", &clc_zoom, COMMANDLINE_INT, 1, 6 },
	{ "fullscreen", &clc_fullscreen, COMMANDLINE_BOOL },
	// Win32 Platform
	{ "window_x", &wclc_winx, COMMANDLINE_INT, 0, 65535 },
	{ "window_y", &wclc_winy, COMMANDLINE_INT, 0, 65535 },
	{ "window_width", &wclc_winw, COMMANDLINE_INT, 0, 65535 },
	{ "window_height", &wclc_winh, COMMANDLINE_INT, 0, 65535 },
	{ "autorun", &wclc_autorun, COMMANDLINE_BOOL },
	{ "pauseinactive", &wclc_pauseinactive, COMMANDLINE_BOOL },
	{ "videorend", &wclc_videorend, COMMANDLINE_INT, 0, 2 },
	{ "audiorend", &wclc_audiorend, COMMANDLINE_INT, 1, 1 },
	{ "forcefeedback", &wclc_forcefeedback, COMMANDLINE_BOOL },
	{ "recent_rom0", (int *)&wclc_recent[0], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom1", (int *)&wclc_recent[1], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom2", (int *)&wclc_recent[2], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom3", (int *)&wclc_recent[3], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom4", (int *)&wclc_recent[4], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom5", (int *)&wclc_recent[5], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom6", (int *)&wclc_recent[6], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom7", (int *)&wclc_recent[7], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom8", (int *)&wclc_recent[8], COMMANDLINE_STR, PMTMPV-1 },
	{ "recent_rom9", (int *)&wclc_recent[9], COMMANDLINE_STR, PMTMPV-1 },
	{ "", NULL, COMMANDLINE_EOL }
};

// Platform menu (REQUIRED >= 0.4.4)
TUIMenu_Item UIItems_Platform[] = {
	{ 0,  0, "Go back...", UIItems_PlatformDefC },
	{ 9,  0, "Platform", UIItems_PlatformDefC }
};

// --------------------------------------------------------------------------------

DWORD WINAPI EmulatorThread(LPVOID lpParameter)
{
	DWORD time, NewTickFPS = 0, NewTickSync = 0;
	int fpscnt = 0;
	uint8_t *vidbuf;

	timeBeginPeriod(1);
	while (emumodeE != EMUMODE_TERMINATE) {
		time = timeGetTime();
		emumodeE = emumodeA;
		if (emumodeE == EMUMODE_RUNFULL) {
			if (RequireSoundSync) {
				PokeMini_EmulateFrame();
				// Sleep a little in the hope to free a few samples
				if (emulimiter) while (MinxAudio_SyncWithAudio()) Sleep(1);
				Sleep(1);		// This lower CPU usage
			} else {
				PokeMini_EmulateFrame();
				if (emulimiter) {
					do {
						Sleep(1);		// This lower CPU usage
						time = timeGetTime();
					} while (time < NewTickSync);
					NewTickSync = time + 13;	// Aprox 72 times per sec
				}
			}

			VideoRend->ClearVideo();
			if (VideoRend->Lock((void *)&vidbuf)) {
				// Render the menu or the game screen
				if (PokeMini_Rumbling) {
					PokeMini_VideoBlit((void *)&vidbuf[PMOff + PokeMini_GenRumbleOffset(BytPitch)], PixPitch);
				} else {
					PokeMini_VideoBlit((void *)&vidbuf[PMOff], PixPitch);
				}
				LCDDirty = 0;

				// Unlock surface
				VideoRend->Unlock();
				VideoRend->Flip(hMainWnd);
			}

			// Poll joystick if enabled
			if (CommandLine.joyenabled) {
				Joystick_DInput_Process(wclc_forcefeedback ? PokeMini_RumblingLatch : 0);
				PokeMini_RumblingLatch = 0;
			}

			// calculate FPS
			fpscnt++;
			if (time >= NewTickFPS) {
				FPS = fpscnt * 100 / 72;
				NewTickFPS = time + 1000;
				fpscnt = 0;
			}
		} else if (emumodeE == EMUMODE_STOP) {
				Joystick_DInput_StopRumble();
				Sleep(250);
		}
	}
	timeEndPeriod(1);
	return 0;
}

// --------------------------------------------------------------------------------

// Update window title caption
DWORD title_timer_id = 0;
void CALLBACK title_timer(UINT uTimerID, UINT uMsg, DWORD_PTR dwUser, DWORD_PTR dw1, DWORD_PTR dw2)
{
	char tmp[PMTMPV];
	if (emumodeE == EMUMODE_RUNFULL) {
		sprintf_s(tmp, PMTMPV, "%s - %d%%", AppName, FPS);
		SetWindowText(hMainWnd, tmp);
	} else {
		SetWindowText(hMainWnd, AppName);
	}
}

// Used to fill the sound buffer
void emulatorsound(void *stream, int len)
{
	MinxAudio_GetSamplesS16((int16_t *)stream, len>>1);
}

// Enable/Disable sound
void enablesound(int sound)
{
	MinxAudio_ChangeEngine(sound);
	if (AudioEnabled) AudioRend->Enable(sound);
}

// Set emulator mode
void set_emumode(int mode, int tempsave)
{
	static int temp_emumode = EMUMODE_STOP;

	// Backup/restore mode
	if (mode == EMUMODE_RESTORE) mode = temp_emumode;
	else if (tempsave) temp_emumode = emumodeA;

	// Enable/disable sound
	if ((emumodeA == EMUMODE_RUNFULL) && (mode != EMUMODE_RUNFULL)) {
		enablesound(0);
		timeKillEvent(title_timer_id);
		SetWindowText(hMainWnd, AppName);
	}
	if ((emumodeA != EMUMODE_RUNFULL) && (mode == EMUMODE_RUNFULL)) {
		enablesound(CommandLine.sound);
		title_timer_id = (DWORD)timeSetEvent(900, 64, title_timer, 0, TIME_PERIODIC);
	}

	// Set mode and wait for thread
	emumodeA = mode;
	while (emumodeA != emumodeE) Sleep(16);
}

// Setup screen
void setup_screen(int resizewin)
{
	TPokeMini_VideoSpec *videospec;
	int viddepth, depth, PMOffX, PMOffY;
	RECT cRect;
	static int wasFullScreen = 0;

	// Backup RECT when entering fullscreen
	if (clc_fullscreen & !wasFullScreen) {
		GetWindowRect(hMainWnd, &rWindowed);
		rWindowed.right -= rWindowed.left;
		rWindowed.bottom -= rWindowed.top;
	}

	// Calculate size based of zoom
	if (clc_zoom == 1) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video1x1;
		PMWidth = 192; PMHeight = 128; PMOffX = 48; PMOffY = 32;
	} else if (clc_zoom == 2) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video2x2;
		PMWidth = 208; PMHeight = 144; PMOffX = 8; PMOffY = 8;
	} else if (clc_zoom == 3) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video3x3;
		PMWidth = 304; PMHeight = 208; PMOffX = 8; PMOffY = 8;
	} else if (clc_zoom == 4) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video4x4;
		PMWidth = 400; PMHeight = 272; PMOffX = 8; PMOffY = 8;
	} else if (clc_zoom == 5) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video5x5;
		PMWidth = 496; PMHeight = 336; PMOffX = 8; PMOffY = 8;
	} else {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video6x6;
		PMWidth = 592; PMHeight = 400; PMOffX = 8; PMOffY = 8;
	}

	// Set video mode
	if (VideoRend->WasInit()) VideoRend->Terminate();
	VideoRend_Set(wclc_videorend);
	viddepth = VideoRend->Init(hMainWnd, PMWidth, PMHeight, clc_fullscreen);
	if (!viddepth) {
		VideoRend_Set(0); wclc_videorend = 0;
		viddepth = VideoRend->Init(hMainWnd, PMWidth, PMHeight, clc_fullscreen);
		if (!viddepth) {
			MessageBox(hMainWnd, "Couldn't initialize video", "Video init error", MB_ICONERROR);
			ExitProcess(1);
		}
	}
	VideoRend->GetPitch(&BytPitch, &PixPitch);

	// Set video spec and check if is supported
	depth = PokeMini_SetVideo(videospec, viddepth, CommandLine.lcdfilter, CommandLine.lcdmode);
	if (!depth) {
		MessageBox(hMainWnd, "Couldn't set video spec", "Video init error", MB_ICONERROR);
		ExitProcess(1);
	}

	// Calculate pitch and offset
	if (depth == 32) {
		PMOff = (PMOffY * BytPitch) + (PMOffX * 4);
	} else {
		PMOff = (PMOffY * BytPitch) + (PMOffX * 2);
	}

	// Handle window style
	if (clc_fullscreen) {
		SetWindowLong(hMainWnd, GWL_STYLE, GetWindowLong(hMainWnd, GWL_STYLE) & ~WS_OVERLAPPEDWINDOW | WS_POPUP);
		SetWindowLong(hMainWnd, GWL_EXSTYLE, GetWindowLong(hMainWnd, GWL_EXSTYLE) | WS_EX_TOPMOST);
	} else {
		SetWindowLong(hMainWnd, GWL_STYLE, GetWindowLong(hMainWnd, GWL_STYLE) & ~WS_POPUP | WS_OVERLAPPEDWINDOW);
		SetWindowLong(hMainWnd, GWL_EXSTYLE, GetWindowLong(hMainWnd, GWL_EXSTYLE) & ~WS_EX_TOPMOST);
	}

	// Restore RECT when exiting fullscreen
	if (!clc_fullscreen & wasFullScreen) {
		MoveWindow(hMainWnd, rWindowed.left, rWindowed.top, rWindowed.right, rWindowed.bottom, 1);
	}

	// Resize window
	if (!clc_fullscreen) {
		if (resizewin) {
			MainWndClientSize(hMainWnd, PMWidth, PMHeight);
		}
	} else {
		if (resizewin) {
			VMainWndClientSize(hMainWnd, PMWidth, PMHeight);
		}
	}

	// Resize and refresh windows
	RedrawWindow(hMainWnd, NULL, NULL, RDW_INVALIDATE);
	GetClientRect(hMainWnd, &cRect);
	VideoRend->ResizeWin(cRect.right, cRect.bottom);
	wasFullScreen = clc_fullscreen;
	Sleep(250);
}

// Render dummy frame
void render_dummyframe(void)
{
	uint8_t *vidbuf;

	if ((VidPalette32) && (emumodeE != EMUMODE_RUNFULL)) {
		VideoRend->ClearVideo();
		if (VideoRend->Lock((void *)&vidbuf)) {

			// Render the menu or the game screen
			PokeMini_VideoBlit((void *)&vidbuf[PMOff], PixPitch);

			// Unlock surface
			VideoRend->Unlock();
			VideoRend->Flip(hMainWnd);
		}
	}
}

// Capture screen
void capture_screen(void)
{
	FILE *capf;
	int y, capnum;
	unsigned long Video[96*64];
	PokeMini_VideoPreview_32((uint32_t *)Video, 96, PokeMini_LCDMode);
	capf = OpenUnique_ExportBMP(&capnum, 96, 64);
	if (!capf) return;
	for (y=0; y<64; y++) {
		WriteArray_ExportBMP(capf, (uint32_t *)&Video[(63-y) * 96], 96);
	}
	Close_ExportBMP(capf);
}

void PMWin_OnUnzipError(const char *zipfile, const char *reason)
{
	SetStatusBarText("Error decompressing %s: %s\n", zipfile, reason);
}

void PMWin_OnLoadBIOSFile(const char *filename, int success)
{
	if (success == 1) SetStatusBarText("BIOS '%s' loaded\n", filename);
	else if (success == -1) SetStatusBarText("Error loading BIOS '%s': file not found, Using FreeBIOS\n", filename);
	else SetStatusBarText("Error loading BIOS '%s': read error, Using FreeBIOS\n", filename);
}

void PMWin_OnLoadMINFile(const char *filename, int success)
{
	if (success == 1) SetStatusBarText("ROM '%s' loaded\n", filename);
	else if (success == -1) SetStatusBarText("Error loading ROM '%s': file not found\n", filename);
	else if (success == -2) SetStatusBarText("Error loading ROM '%s': invalid size\n", filename);
	else SetStatusBarText("Error loading ROM '%s', read error\n", filename);
}

void PMWin_OnLoadColorFile(const char *filename, int success)
{
	if (success == 1) SetStatusBarText("Color info '%s' loaded\n", filename);
	else if (success == -1) SetStatusBarText("Error loading color info '%s': file not found\n", filename);
	else SetStatusBarText("Error loading color info '%s': read error\n", filename);
}

void PMWin_OnLoadEEPROMFile(const char *filename, int success)
{
	if (success == 1) SetStatusBarText("EEPROM '%s' loaded\n", filename);
	else if (success == -1) SetStatusBarText("Error loading EEPROM '%s': file not found\n", filename);
	else SetStatusBarText("Error loading EEPROM '%s': read error\n", filename);
}

void PMWin_OnSaveEEPROMFile(const char *filename, int success)
{
	if (success == 1) SetStatusBarText("EEPROM '%s' saved\n", filename);
	else if (success == -1) SetStatusBarText("Error saving EEPROM '%s': filename invalid\n", filename);
	else SetStatusBarText("Error saving EEPROM '%s': write error\n", filename);
}

void PMWin_OnLoadStateFile(const char *filename, int success)
{
	if (success == 1) SetStatusBarText("State '%s' loaded\n", filename);
	else if (success == -1) SetStatusBarText("Error loading state '%s': file not found\n", filename);
	else if (success == -2) SetStatusBarText("Error loading state '%s': invalid file\n", filename);
	else if (success == -3) SetStatusBarText("Error loading state '%s': wrong version\n", filename);
	else if (success == -4) SetStatusBarText("Error loading state '%s': invalid header\n", filename);
	else if (success == -5) SetStatusBarText("Error loading state '%s': invalid internal block\n", filename);
	else SetStatusBarText("Error loading state '%s': read error\n", filename);
}

void PMWin_OnSaveStateFile(const char *filename, int success)
{
	if (success == 1) SetStatusBarText("State '%s' saved\n", filename);
	else if (success == -1) SetStatusBarText("Error saving state '%s': filename invalid\n", filename);
	else SetStatusBarText("Error saving state '%s': write error\n", filename);
}

// --------------------------------------------------------------------------------

int Menu_FileAssociation_DoRegister(void)
{
	const char *tenam1 = "PokeMini_min";
	const char *tenam2 = "PokeMini_minc";
	const char *tenam3 = "PokeMini Emulator ROM";
	const char *tenam4 = "PokeMini Emulator Color File";
	const char *tenam5 = "open";
	const char *tenam6 = "&Open";
	char tmp[PMTMPV];
	char argv0[PMTMPV];
	HKEY key;
	DWORD dispo;

	// Receive module filename
	GetModuleFileName(NULL, argv0, PMTMPV);

	// HKEY_CLASSES_ROOT\.min
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, ".min", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam1, (DWORD)strlen(tenam1)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\.minc
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, ".minc", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam2, (DWORD)strlen(tenam2)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_min
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam3, (DWORD)strlen(tenam3)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_minc
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam4, (DWORD)strlen(tenam4)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_min\DefaultIcon
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min\\DefaultIcon", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	sprintf_s(tmp, PMTMPV, "\"%s\",2", argv0);
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tmp, (DWORD)strlen(tmp)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_minc\DefaultIcon
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc\\DefaultIcon", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	sprintf_s(tmp, PMTMPV, "\"%s\",3", argv0);
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tmp, (DWORD)strlen(tmp)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_min\shell
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min\\shell", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, &dispo) != ERROR_SUCCESS) return 0;
	if (dispo == REG_CREATED_NEW_KEY) {
		if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam5, (DWORD)strlen(tenam5)+1) != ERROR_SUCCESS) return 0;
	}
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_minc\shell
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, &dispo) != ERROR_SUCCESS) return 0;
	if (dispo == REG_CREATED_NEW_KEY) {
		if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam5, (DWORD)strlen(tenam5)+1) != ERROR_SUCCESS) return 0;
	}
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_min\shell\open
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\open", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam6, (DWORD)strlen(tenam6)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_minc\shell\open
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\open", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	if (RegSetValueExA(key, NULL, 0, REG_SZ, (LPBYTE)tenam6, (DWORD)strlen(tenam6)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_min\shell\open\command
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\open\\command", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	sprintf_s(tmp, PMTMPV, "\"%s\" \"%%1\"", argv0);
	if (RegSetValueExA(key, NULL, 0, REG_SZ, tmp, (DWORD)strlen(tmp)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	// HKEY_CLASSES_ROOT\PokeMini_minc\shell\open\command
	if (RegCreateKeyEx(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\open\\command", 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, NULL) != ERROR_SUCCESS) return 0;
	sprintf_s(tmp, PMTMPV, "\"%s\" \"%%1\"", argv0);
	if (RegSetValueExA(key, NULL, 0, REG_SZ, tmp, (DWORD)strlen(tmp)+1) != ERROR_SUCCESS) return 0;
	RegCloseKey(key);

	return 1;
}

int Menu_FileAssociation_DoUnregister(void)
{
	int success = 2;

	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\open\\command")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\open\\command")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min\\shell\\open")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell\\open")) success = 0;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min\\shell")) success = 1;
	if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc\\shell")) success = 1;
	if (success == 2) {
		if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min\\DefaultIcon")) success = 0;
		if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc\\DefaultIcon")) success = 0;
		if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_min")) success = 0;
		if (RegDeleteKey(HKEY_CLASSES_ROOT, "PokeMini_minc")) success = 0;
		if (RegDeleteKey(HKEY_CLASSES_ROOT, ".min")) success = 0;
		if (RegDeleteKey(HKEY_CLASSES_ROOT, ".minc")) success = 0;
	}

	return success;
}

void Menu_FileAssociation_Register(void)
{
	set_emumode(EMUMODE_STOP, 1);
	if (MessageBox(hMainWnd, "Are you sure you want to add\n.min and .minc associations?", "Question", MB_YESNO | MB_ICONQUESTION)) {
		if (Menu_FileAssociation_DoRegister()) {
			MessageBox(hMainWnd, ".min and .minc have been successfuly registered", "Success", MB_ICONINFORMATION);
		} else {
			MessageBox(hMainWnd, "Error while trying to associate extensions", "Error", MB_ICONERROR);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_FileAssociation_Unregister(void)
{
	int ret;
	set_emumode(EMUMODE_STOP, 1);
	if (MessageBox(hMainWnd, "Are you sure you want to remove\n.min and .minc associations?", "Question", MB_YESNO | MB_ICONQUESTION)) {
		ret = Menu_FileAssociation_DoUnregister();
		if (ret == 2) {
			MessageBox(hMainWnd, ".min and .minc have been successfuly unregistered", "Success", MB_ICONINFORMATION);
		} else if (ret == 1) {
			MessageBox(hMainWnd, ".min and .minc are still associated with other program", "Note", MB_ICONINFORMATION);
		} else {
			MessageBox(hMainWnd, "Error while trying to remove association", "Error", MB_ICONERROR);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

void AddMinOnRecent(const char *filename)
{
	int i, x;
	for (x=0; x<9; x++) {
		if (!strcmp(filename, wclc_recent[x])) break;
	}
	if (x == 10) {
		// Not found, shift down
		for (i=8; i>=0; i--) {
			strcpy_s(wclc_recent[i+1], PMTMPV, wclc_recent[i]);
		}
	} else if (x == 0) {
		// Last loaded, do nothing
		return;
	} else {
		// Found at x, shift middle
		for (i=x-1; i>=0; i--) {
			strcpy_s(wclc_recent[i+1], PMTMPV, wclc_recent[i]);
		}
	}
	strcpy_s(wclc_recent[0], PMTMPV, filename);
}

void Recent_OpenMin(const char *filename)
{
	set_emumode(EMUMODE_STOP, 1);
	if (!PokeMini_LoadROM(filename)) {
		MessageBox(hMainWnd, "Error loading ROM", "MIN load error", MB_ICONERROR);
	} else {
		if ((emumodeA == EMUMODE_STOP) && wclc_autorun) {
			SetStatusBarText("Emulation auto-started\n");
			set_emumode(EMUMODE_RUNFULL, 1);
			wclc_inactivestate = 1;
			return;
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

void DragDrop_OpenMin(const char *filename)
{
	set_emumode(EMUMODE_STOP, 1);
	if (!PokeMini_LoadROM(filename)) {
		MessageBox(hMainWnd, "Error loading ROM", "MIN load error", MB_ICONERROR);
	} else {
		AddMinOnRecent(CommandLine.min_file);
		if ((emumodeA == EMUMODE_STOP) && wclc_autorun) {
			SetStatusBarText("Emulation auto-started\n");
			set_emumode(EMUMODE_RUNFULL, 1);
			wclc_inactivestate = 1;
			return;
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_File_OpenMin(void)
{
	char tmp[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	if (FirstROMLoad) {
		if (strlen(CommandLine.rom_dir)) PokeMini_SetCurrentDir(CommandLine.rom_dir);
		FirstROMLoad = 0;
	}
	if (OpenFileDialogEx(hMainWnd, "Open MIN", tmp, CommandLine.min_file, "ZIP Package or MIN Rom (*.zip;*.min)\0*.zip;*.min\0ZIP Package (*.zip)\0*.zip\0MIN Rom (*.min)\0*.min\0All (*.*)\0*.*\0", 0)) {
		if (!PokeMini_LoadROM(tmp)) {
			MessageBox(hMainWnd, "Error loading ROM", "MIN load error", MB_ICONERROR);
		} else {
			strcpy_s(CommandLine.rom_dir, PMTMPV, PokeMini_CurrDir);
			AddMinOnRecent(CommandLine.min_file);
			if ((emumodeA == EMUMODE_STOP) && wclc_autorun) {
				SetStatusBarText("Emulation auto-started\n");
				set_emumode(EMUMODE_RUNFULL, 1);
				wclc_inactivestate = 1;
				return;
			}
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_File_LoadState(void)
{
	char tmp[PMTMPV], romfile[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	sprintf_s(tmp, PMTMPV, "%s.sta", CommandLine.min_file);
	if (OpenFileDialogEx(hMainWnd, "Load state", tmp, tmp, "State (*.sta)\0*.sta\0All (*.*)\0*.*\0", 0)) {
		if (!PokeMini_CheckSSFile(tmp, romfile)) {
			MessageBox(hMainWnd, "Invalid state file", "Load state error", MB_ICONERROR);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		if (strcmp(romfile, CommandLine.min_file)) {
			if (!MessageBox(hMainWnd, "Assigned ROM does not match, continue?", "Load state", MB_YESNO | MB_ICONERROR)) {
				if (MessageBox(hMainWnd, "Want to load with the assigned ROM?", "Load state", MB_YESNO | MB_ICONERROR)) {
					if (!PokeMini_LoadROM(romfile)) {
						MessageBox(hMainWnd, "Error loading ROM", "MIN load error", MB_ICONERROR);
						set_emumode(EMUMODE_RESTORE, 1);
						return;
					}
					if (!PokeMini_LoadSSFile(tmp)) {
						MessageBox(hMainWnd, "Error loading state", "Load state error", MB_ICONERROR);
						set_emumode(EMUMODE_RESTORE, 1);
						return;
					}
					AddMinOnRecent(CommandLine.min_file);
				}
				SetStatusBarText("State loaded\n");
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}
		}
		if (!PokeMini_LoadSSFile(tmp)) {
			MessageBox(hMainWnd, "Error loading state", "Load state error", MB_ICONERROR);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		SetStatusBarText("State loaded\n");
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_File_SaveState(void)
{
	char tmp[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	sprintf_s(tmp, PMTMPV, "%s.sta", CommandLine.min_file);
	if (SaveFileDialogEx(hMainWnd, "Save state", tmp, tmp, "State (*.sta)\0*.sta\0All (*.*)\0*.*\0", 0)) {
		if (!PokeMini_SaveSSFile(tmp, CommandLine.min_file)) {
			MessageBox(hMainWnd, "Error saving state", "Save state error", MB_ICONERROR);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		SetStatusBarText("State saved\n");
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_Capt_Snapshot1x(void)
{
	char filename[PMTMPV];
	uint32_t *imgptr = NULL;
	FILE *capf;
	int y;

	set_emumode(EMUMODE_STOP, 1);
	if (SaveFileDialogEx(hMainWnd, "Save snapshot (1x preview)", filename, "snapshot.bmp", "BMP (*.bmp)\0*.bmp\0", 0)) {
		imgptr = (uint32_t *)LocalAlloc(LPTR, 96*64*4);
		PokeMini_VideoPreview_32(imgptr, 96, PokeMini_LCDMode);
		capf = Open_ExportBMP(filename, 96, 64);
		if (!capf) {
			MessageBox(hMainWnd, "Open failed", "Save snapshot error", MB_ICONERROR);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		for (y=0; y<64; y++) {
			WriteArray_ExportBMP(capf, (uint32_t *)&imgptr[(63-y) * 96], 96);
		}
		Close_ExportBMP(capf);
		LocalFree(imgptr);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_Capt_SnapshotLCD(void)
{
	char filename[PMTMPV];
	uint32_t *imgptr = NULL;
	FILE *capf;
	int w, h, y;

	w = 96 * clc_zoom;
	h = 64 * clc_zoom;
	set_emumode(EMUMODE_STOP, 1);
	if (SaveFileDialogEx(hMainWnd, "Save snapshot (from LCD)", filename, "snapshot.bmp", "BMP (*.bmp)\0*.bmp\0", 0)) {
		imgptr = (uint32_t *)LocalAlloc(LPTR, w*h*4);
		PokeMini_VideoBlit32(imgptr, w);
		capf = Open_ExportBMP(filename, w, h);
		if (!capf) {
			MessageBox(hMainWnd, "Open failed", "Save snapshot error", MB_ICONERROR);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		for (y=0; y<h; y++) {
			WriteArray_ExportBMP(capf, (uint32_t *)&imgptr[((h-1)-y) * w], w);
		}
		Close_ExportBMP(capf);
		LocalFree(imgptr);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_Options_Zoom(int index)
{
	BOOL WinZoomed = IsZoomed(hMainWnd);
	clc_zoom = index;
	set_emumode(EMUMODE_STOP, 1);
	if (WinZoomed) ShowWindow(hMainWnd, SW_RESTORE);
	setup_screen(1);
	render_dummyframe();
	if (WinZoomed) ShowWindow(hMainWnd, SW_MAXIMIZE);
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_Options_Palette(int index)
{
	if (CommandLine.palette != index) {
		CommandLine.palette = index;
		PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
		render_dummyframe();
	}
}

void Menu_Options_LCDMode(int index)
{
	if (CommandLine.lcdmode != index) {
		CommandLine.lcdmode = index;
		if ((CommandLine.lcdmode == 3) && !PRCColorMap) {
			CommandLine.lcdmode = 0;
		}
		PokeMini_ApplyChanges();
	}
}

void Menu_Options_LCDFilter(int index)
{
	if (CommandLine.lcdfilter != index) {
		CommandLine.lcdfilter = index;
		PokeMini_ApplyChanges();
	}
}

void Menu_Options_LCDContrast(int index)
{
	if (CommandLine.lcdcontrast != index) {
		CommandLine.lcdcontrast = index;
		PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
		render_dummyframe();
	}
}

void Menu_Options_LCDBright(int index)
{
	if (CommandLine.lcdbright != index) {
		CommandLine.lcdbright = index;
		PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
		render_dummyframe();
	}
}

void Menu_Options_RumbleLevel(int index)
{
	if (CommandLine.rumblelvl != index) {
		CommandLine.rumblelvl = index;
		PokeMini_ApplyChanges();
	}
}

void Menu_Options_Fullscreen(void)
{
	clc_fullscreen = !clc_fullscreen;
	set_emumode(EMUMODE_STOP, 1);
	if (IsZoomed(hMainWnd)) ShowWindow(hMainWnd, SW_RESTORE);
	setup_screen(0);
	render_dummyframe();
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_Options_Sound(int index)
{
	CommandLine.sound = index;
	if (emumodeA == EMUMODE_RUNFULL) enablesound(CommandLine.sound);
}

void Menu_Options_PiezoFilter(void)
{
	CommandLine.piezofilter = !CommandLine.piezofilter;
	PokeMini_ApplyChanges();
}

void Menu_Options_SyncCycles(int index)
{
	CommandLine.synccycles = index;
}

void Menu_Options_LowBattery(void)
{
	CommandLine.low_battery = !CommandLine.low_battery;
	PokeMini_ApplyChanges();
}

void Menu_Options_RTC(int index)
{
	CommandLine.updatertc = index;
}

void Menu_Options_ShareEEPROM(void)
{
	CommandLine.eeprom_share = !CommandLine.eeprom_share;
	PokeMini_ApplyChanges();
}

void Menu_Options_Multicart(int index)
{
	if (CommandLine.multicart != index) {
		CommandLine.multicart = index;
		set_emumode(EMUMODE_STOP, 1);
		MessageBox(hMainWnd, "Changing multicart require a reset or reload", "Multicart", MB_ICONWARNING);
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

void Menu_Options_ForceFreeBIOS(void)
{
	CommandLine.forcefreebios = !CommandLine.forcefreebios;
	PokeMini_ApplyChanges();
}

void Menu_Options_UpdateEEPROM(void)
{
	set_emumode(EMUMODE_STOP, 1);
	PokeMini_SaveFromCommandLines(1);
	SetStatusBarText("EEPROM Updated\n");
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_Options_SaveOptions(void)
{
	PokeMini_GetCurrentDir();
	PokeMini_GotoExecDir();
	if (CommandLineConfSave()) {
		SetStatusBarText("Configurations saved\n");
	} else {
		SetStatusBarText("Error configurations saving\n");
	}
	PokeMini_GotoCurrentDir();
}

void Menu_Emulator_Reset(int hard)
{
	set_emumode(EMUMODE_STOP, 1);
	if (hard) {
		SetStatusBarText("Emulator has been hard reset (Full)\n");
	} else {
		SetStatusBarText("Emulator has been soft reset (Partial)\n");
	}
	PokeMini_Reset(hard);
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_Emulator_VideoRend(int index)
{
	if (wclc_videorend != index) {
		set_emumode(EMUMODE_STOP, 1);
		wclc_videorend = index;
		setup_screen(0);
		render_dummyframe();
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

void Menu_Emulator_Autorun(void)
{
	wclc_autorun = !wclc_autorun;
}

void Menu_Emulator_PauseInactive(void)
{
	wclc_pauseinactive = !wclc_pauseinactive;
}

void Menu_Help_VisitWebsite(void)
{
	ShellExecuteA(NULL, "open", WebsiteTxt, "", NULL, SW_SHOWNORMAL);
}

void Menu_Help_CommandLine(void)
{
	MSGBOXPARAMS MsgBox;
	char *buffer;
	set_emumode(EMUMODE_STOP, 1);
	buffer = (char *)LocalAlloc(LPTR, PrintHelpUsageStr(NULL));
	PrintHelpUsageStr(buffer);
	strcat_s(buffer, 4096, "  -windowed              Display in window (default)\n");
	strcat_s(buffer, 4096, "  -fullscreen            Display in fullscreen\n");
	strcat_s(buffer, 4096, "  -zoom n                Zoom display: 1 to 6 (def 4)\n");
	strcat_s(buffer, 4096, "  -bpp n                 Bits-Per-Pixel: 16 or 32 (def 16)\n");
	MsgBox.cbSize = sizeof(MSGBOXPARAMS);
	MsgBox.hwndOwner = hMainWnd;
	MsgBox.hInstance = hInst;
	MsgBox.lpszText = buffer;
	MsgBox.lpszCaption = "Command line";
	MsgBox.dwStyle = MB_USERICON;
	MsgBox.lpszIcon = MAKEINTRESOURCE(IDI_ICON1);
	MsgBox.dwContextHelpId = 0;
	MsgBox.lpfnMsgBoxCallback = NULL;
	MsgBox.dwLanguageId = LANG_ENGLISH;
	MessageBoxIndirect(&MsgBox);
	LocalFree(buffer);
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_Help_About(void)
{
	MSGBOXPARAMS MsgBox;
	set_emumode(EMUMODE_STOP, 1);
	MsgBox.cbSize = sizeof(MSGBOXPARAMS);
	MsgBox.hwndOwner = hMainWnd;
	MsgBox.hInstance = hInst;
	MsgBox.lpszText = AboutTxt;
	MsgBox.lpszCaption = "About";
	MsgBox.dwStyle = MB_USERICON;
	MsgBox.lpszIcon = MAKEINTRESOURCE(IDI_ICON1);
	MsgBox.dwContextHelpId = 0;
	MsgBox.lpfnMsgBoxCallback = NULL;
	MsgBox.dwLanguageId = LANG_ENGLISH;
	MessageBoxIndirect(&MsgBox);
	set_emumode(EMUMODE_RESTORE, 1);
}

// --------------------------------------------------------------------------------

// Update all options
void update_options(void)
{
	char tmp[PMTMPV];
	int i, j;

	CheckMenuItem(hMainMenu, ID_ZOOM_1X, (clc_zoom == 1) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_ZOOM_2X, (clc_zoom == 2) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_ZOOM_3X, (clc_zoom == 3) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_ZOOM_4X, (clc_zoom == 4) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_ZOOM_5X, (clc_zoom == 5) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_ZOOM_6X, (clc_zoom == 6) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_0, (CommandLine.palette == 0) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_1, (CommandLine.palette == 1) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_2, (CommandLine.palette == 2) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_3, (CommandLine.palette == 3) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_4, (CommandLine.palette == 4) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_5, (CommandLine.palette == 5) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_6, (CommandLine.palette == 6) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_7, (CommandLine.palette == 7) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_8, (CommandLine.palette == 8) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_9, (CommandLine.palette == 9) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_10, (CommandLine.palette == 10) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_11, (CommandLine.palette == 11) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_12, (CommandLine.palette == 12) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_13, (CommandLine.palette == 13) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_14, (CommandLine.palette == 14) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_PALETTE_15, (CommandLine.palette == 15) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDMODE_ANALOG, (CommandLine.lcdmode == 0) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDMODE_3SHADES, (CommandLine.lcdmode == 1) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDMODE_2SHADES, (CommandLine.lcdmode == 2) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDMODE_COLORS, (CommandLine.lcdmode == 3) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDFILTER_NONE, (CommandLine.lcdfilter == 0) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDFILTER_MATRIX, (CommandLine.lcdfilter == 1) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDFILTER_SCANLINE, (CommandLine.lcdfilter == 2) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDCONTRAST_DEFAULT, (CommandLine.lcdcontrast == 64) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDCONTRAST_LOWEST, (CommandLine.lcdcontrast == 0) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDCONTRAST_LOW, (CommandLine.lcdcontrast == 25) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDCONTRAST_MEDIUM, (CommandLine.lcdcontrast == 50) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDCONTRAST_HIGH, (CommandLine.lcdcontrast == 75) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDCONTRAST_HIGHEST, (CommandLine.lcdcontrast == 100) ? MF_CHECKED : MF_UNCHECKED);
	if ((CommandLine.lcdcontrast == 64) ||
		(CommandLine.lcdcontrast == 0) ||
		(CommandLine.lcdcontrast == 25) ||
		(CommandLine.lcdcontrast == 50) ||
		(CommandLine.lcdcontrast == 75) ||
		(CommandLine.lcdcontrast == 100)) {
		CheckMenuItem(hMainMenu, ID_LCDCONTRAST_CUSTOM, MF_UNCHECKED);
	} else {
		CheckMenuItem(hMainMenu, ID_LCDCONTRAST_CUSTOM, MF_CHECKED);
	}
	CheckMenuItem(hMainMenu, ID_LCDBRIGHT_DEFAULT, (CommandLine.lcdbright == 0) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDBRIGHT_LIGHTER, (CommandLine.lcdbright == 24) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDBRIGHT_LIGHT, (CommandLine.lcdbright == 12) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDBRIGHT_DARK, (CommandLine.lcdbright == -12) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_LCDBRIGHT_DARKER, (CommandLine.lcdbright == -24) ? MF_CHECKED : MF_UNCHECKED);
	if ((CommandLine.lcdbright == 0) ||
		(CommandLine.lcdbright == 24) ||
		(CommandLine.lcdbright == 12) ||
		(CommandLine.lcdbright == -12) ||
		(CommandLine.lcdbright == -24)) {
		CheckMenuItem(hMainMenu, ID_LCDBRIGHT_CUSTOM, MF_UNCHECKED);
	} else {
		CheckMenuItem(hMainMenu, ID_LCDBRIGHT_CUSTOM, MF_CHECKED);
	}
	CheckMenuItem(hMainMenu, ID_RUMBLELEVEL_0, (CommandLine.rumblelvl == 0) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_RUMBLELEVEL_1, (CommandLine.rumblelvl == 1) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_RUMBLELEVEL_2, (CommandLine.rumblelvl == 2) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_RUMBLELEVEL_3, (CommandLine.rumblelvl == 3) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_OPTIONS_FULLSCREEN, (clc_fullscreen) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SOUND_DISABLED, (CommandLine.sound == 0) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SOUND_GENERATED, (CommandLine.sound == 1) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SOUND_DIRECT, (CommandLine.sound == 2) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SOUND_EMULATED, (CommandLine.sound == 3) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SOUND_DIRECTPWM, (CommandLine.sound == 4) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_OPTIONS_PIEZOFILTER, (CommandLine.piezofilter) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SYNCCYCLES_8, (CommandLine.synccycles == 8) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SYNCCYCLES_16, (CommandLine.synccycles == 16) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SYNCCYCLES_32, (CommandLine.synccycles == 32) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SYNCCYCLES_64, (CommandLine.synccycles == 64) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SYNCCYCLES_128, (CommandLine.synccycles == 128) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SYNCCYCLES_256, (CommandLine.synccycles == 256) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_SYNCCYCLES_512, (CommandLine.synccycles == 512) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_OPTIONS_LOWBATTERY, (CommandLine.low_battery) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_RTC_NORTC, (CommandLine.updatertc == 0) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_RTC_STATE, (CommandLine.updatertc == 1) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_RTC_HOST, (CommandLine.updatertc == 2) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_OPTIONS_SHAREEEPROM, (CommandLine.eeprom_share) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_MULTICART_DISABLED, (CommandLine.multicart == 0) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_MULTICART_FLASH512KB, (CommandLine.multicart == 1) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_MULTICART_LUPIN512KB, (CommandLine.multicart == 2) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_OPTIONS_FORCEFREEBIOS, (CommandLine.forcefreebios) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_VIDEO_GDI, (wclc_videorend == 0) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_VIDEO_DIRECTDRAW, (wclc_videorend == 1) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_VIDEO_DIRECT3D, (wclc_videorend == 2) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_EMULATOR_AUTORUN, (wclc_autorun) ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_EMULATOR_PAUSEWHENINACTIVE, (wclc_pauseinactive) ? MF_CHECKED : MF_UNCHECKED);
#ifdef NO_DIRECTDRAW
	EnableMenuItem(hMainMenu, ID_VIDEO_DIRECTDRAW, MF_GRAYED);
#endif
	for (i=0; i<10; i++) {
		if (strlen(wclc_recent[i]) > 0) {
			for (j=(int)strlen(wclc_recent[i])-1; j>=0; j--) if (wclc_recent[i][j] == '\\') { j++; break; }
			sprintf_s(tmp, PMTMPV, "%s\tCtrl+F%i", &wclc_recent[i][j], i+1);
			ModifyMenu(hMainMenu, wclc_recent_ids[i], MF_BYCOMMAND | MF_STRING | MF_ENABLED, wclc_recent_ids[i], tmp);
		} else {
			sprintf_s(tmp, PMTMPV, "---\tCtrl+F%i", i+1);
			ModifyMenu(hMainMenu, wclc_recent_ids[i], MF_BYCOMMAND | MF_STRING | MF_GRAYED, wclc_recent_ids[i], tmp);
		}
	}
}

// Windows Start Point
int APIENTRY WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
	MSG msg;
	HACCEL hAccelTable;
	HANDLE EmuThread;
    DWORD EmuThreadID;
	int i, argc;
	char **argv;
	size_t sz;

	// Get argc/argv parameters
	LPWSTR *pathnam;
	pathnam = CommandLineToArgvW(GetCommandLineW(), &argc);
	argv = (char **)LocalAlloc(LPTR, argc * sizeof(char **));
	for (i=0; i<argc; i++) {
		argv[i] = (char *)LocalAlloc(LPTR, (wcslen(pathnam[i]) + 1) * sizeof(char *));
		wcstombs_s(&sz, argv[i], wcslen(pathnam[i])+1, pathnam[i], 256);
	}
	LocalFree(pathnam);

	// Process arguments
	PokeMini_InitDirs(argv[0], NULL);
	CommandLineInit();
	CommandLineConfFile("pokemini.cfg", "pokemini_win32.cfg", CustomConf);
	if (!CommandLineArgs(argc, argv, CustomArgs)) {
		Menu_Help_CommandLine();
		return 1;
	}

	// Register and create main window
	VideoRend_Set(0);
	AudioRend_Set(1);
	PokeMiniW_RegisterClasses(hInstance);
	if (!PokeMiniW_CreateWindow(hInstance, nCmdShow)) {
		MessageBox(NULL, "Couldn't create main window!", "Error", MB_ICONERROR);
		return 1;
	}
	hAccelTable = LoadAccelerators(hInstance, (LPCTSTR)IDR_ACCELERATOR);
	hInst = hInstance;

	// Initialize video here
	setup_screen(1);

	// Initialize audio here
	if (!AudioRend->Init(hMainWnd, 44100, 16, 1, SOUNDBUFFER, (AudioRend_Callback)emulatorsound)) {
		MessageBox(NULL, "Couldn't initialize sound!\nUsing no sound.", "Error", MB_ICONERROR);
		AudioEnabled = 0;
	} else {
		AudioEnabled = 1;
	}

	// Initialize joystick
	Joystick_DInput_Init(hInst, hMainWnd);
	if (CommandLine.joyenabled) {
		Joystick_DInput_JoystickOpen(CommandLine.joyid);
	}

	// Initialize the emulator
	if (!PokeMini_Create(0, PMSNDBUFFER)) {
		MessageBox(NULL, "Error while initializing emulator", "Error", MB_ICONERROR);
		return 1;
	}

	// Setup palette and LCD mode
	PokeMini_VideoPalette_Init(PokeMini_BGR16, 1);
	PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
	PokeMini_ApplyChanges();

	// Sound, keyboard mapping and options
	enablesound(0);
	KeyboardRemap(&KeybWinRemap);
	render_dummyframe();

	// Create and run emulator thread
	EmuThread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)EmulatorThread, NULL, 0, &EmuThreadID);

	// Load stuff
	PokeMini_OnUnzipError = PMWin_OnUnzipError;
	PokeMini_OnLoadBIOSFile = PMWin_OnLoadBIOSFile;
	PokeMini_OnLoadMINFile = PMWin_OnLoadMINFile;
	PokeMini_OnLoadColorFile = PMWin_OnLoadColorFile;
	PokeMini_OnLoadEEPROMFile = PMWin_OnLoadEEPROMFile;
	PokeMini_OnSaveEEPROMFile = PMWin_OnSaveEEPROMFile;
	PokeMini_OnLoadStateFile = PMWin_OnLoadStateFile;
	PokeMini_OnSaveStateFile = PMWin_OnSaveStateFile;
	if (PokeMini_LoadFromCommandLines("Using FreeBIOS", "EEPROM data will be discarded!")) {
		AddMinOnRecent(CommandLine.min_file);
		if ((emumodeA == EMUMODE_STOP) && wclc_autorun) {
			SetStatusBarText("Emulation auto-started\n");
			set_emumode(EMUMODE_RUNFULL, 1);
			wclc_inactivestate = 1;
		}
	}
	if (emumodeA == EMUMODE_STOP) SetStatusBarText("Emulator started\n");
	RedrawWindow(hMainWnd, NULL, NULL, RDW_INVALIDATE);
	update_options();

	// Main message loop
	while (GetMessage(&msg, NULL, 0, 0)) {
		if (!TranslateAccelerator(msg.hwnd, hAccelTable, &msg)) {
			TranslateMessage(&msg);
			DispatchMessage(&msg);
		}
	}

	// Wait for emulator thread to finish
	set_emumode(EMUMODE_TERMINATE, 0);
	WaitForSingleObject(EmuThread, INFINITE);

	// Free video
	if (VideoRend->WasInit()) VideoRend->Terminate();
	if (AudioRend->WasInit()) AudioRend->Terminate();
	Joystick_DInput_Terminate();

	// Save Stuff and terminate
	CommandLineConfSave();
	PokeMini_SaveFromCommandLines(1);
	PokeMini_VideoPalette_Free();
	PokeMini_Destroy();

	// Free argc/argv parameters
	for (i=0; i<argc; i++) {
		LocalFree(argv[i]);
	}
	LocalFree(argv);

	return 0;
}

// When Key is pressed on main window
void OnWinKeyDownEvent(uint32_t VKey)
{
		static int LastUI_Status;
		if (VKey == VK_F9) {			// Capture screen
			capture_screen();
		} else if (VKey == VK_F10) {	// Fullscreen/Window
			clc_fullscreen = !clc_fullscreen;
			set_emumode(EMUMODE_STOP, 1);
			setup_screen(0);
			render_dummyframe();
			set_emumode(EMUMODE_RESTORE, 1);
		} else if (VKey == VK_F11) {	// Disable speed throttling
			emulimiter = !emulimiter;
		} else if (VKey == VK_TAB) {	// Temp disable speed throttling
			emulimiter = 0;
		} else {
			KeyboardPressEvent(VKey);
			if (UI_Status != LastUI_Status) {
				if (GetMenu(hMainWnd) == NULL) {
					SetMenu(hMainWnd, hMainMenu);
				} else {
					SetMenu(hMainWnd, NULL);
				}
			}
		}
		LastUI_Status = UI_Status;
}

// When Key is released on main window
void OnWinKeyUpEvent(uint32_t VKey)
{
		if (VKey == VK_TAB) {			// Speed threhold
			emulimiter = 1;
		} else {
			KeyboardReleaseEvent(VKey);
		}
}

// When main window change size
// (Client size)
void OnWinResize(int Width, int Height)
{
	VideoRend->ResizeWin(Width, Height);
	if (emumodeE != EMUMODE_RUNFULL) {
		InvalidateRect(hMainWnd, NULL, FALSE);
		UpdateWindow(hMainWnd);
	}
}

// Limit the minimum/maximum size of the window
void OnWinSizing(WPARAM sizedtype, LPRECT area)
{ 
	if ((area->right - area->left) < 192) area->right = area->left + 192;
	if ((area->bottom - area->top) < 128) area->bottom = area->top + 128;
}

// Register main window class
void PokeMiniW_RegisterClasses(HINSTANCE hInstance)
{
	WNDCLASSEX wcex;

	// Register Main Window Class
	wcex.cbSize = sizeof(WNDCLASSEX); 
	wcex.style          = 0;
	wcex.lpfnWndProc    = (WNDPROC)PokeMiniW_WndProc;
	wcex.cbClsExtra     = 0;
	wcex.cbWndExtra     = 0;
	wcex.hInstance      = hInstance;
	wcex.hIcon          = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_ICON1));
	wcex.hCursor        = LoadCursor(NULL, IDC_ARROW);
	wcex.hbrBackground  = NULL;
	wcex.lpszMenuName   = (LPCSTR)IDR_MENU;
	wcex.lpszClassName  = "POKEMINIWIN";
	wcex.hIconSm        = (HICON)LoadImage(wcex.hInstance, MAKEINTRESOURCE(IDI_ICON1), IMAGE_ICON, 16, 16, LR_SHARED);
	RegisterClassEx(&wcex);
}

// Create main window
int PokeMiniW_CreateWindow(HINSTANCE hInstance, int nCmdShow)
{
	int Width, Height;

	// Create window
	
	hMainWnd = CreateWindowEx(WS_EX_LEFT | WS_EX_ACCEPTFILES, "POKEMINIWIN", AppName, WS_OVERLAPPEDWINDOW, 0, 0, 384, 256, NULL, NULL, hInstance, NULL);
	if (!hMainWnd) return FALSE;

	// Assign menu into the window
	hMainMenu = GetMenu(hMainWnd);
	if (!hMainMenu) return FALSE;

	// Correct the window size
	if ((wclc_winw < 16) || (wclc_winh < 16)) {
		Width = 384; Height = 256;
		MainWndClientSize(hMainWnd, Width, Height);
	} else {
		MoveWindow(hMainWnd, wclc_winx, wclc_winy, wclc_winw, wclc_winh, 0);
	}

	// Turn window visible
	ShowWindow(hMainWnd, nCmdShow);
	UpdateWindow(hMainWnd);

	return TRUE;
}

// Destroy main window
void PokeMiniW_DestroyWindow(void)
{
	RECT wRect;

	// Save position and size
	if (!clc_fullscreen) {
		GetWindowRect(hMainWnd, &wRect);
		wclc_winx = wRect.left;
		wclc_winy = wRect.top;
		wclc_winw = wRect.right - wRect.left;
		wclc_winh = wRect.bottom - wRect.top;
	}
}

// Virtually Resize Client Area
void VMainWndClientSize(HWND hWnd, int Width, int Height)
{
	RECT cRect;
	if (hWnd == NULL) return;

	cRect.left = 0;
	cRect.top = 0;
	cRect.right = Width;
	cRect.bottom = Height;
	AdjustWindowRect(&cRect, WS_BORDER | WS_CAPTION | WS_SYSMENU | WS_SIZEBOX, 1);
	rWindowed.right = cRect.right - cRect.left;
	rWindowed.bottom = cRect.bottom - cRect.top;
}

// Resize Client Area
void MainWndClientSize(HWND hWnd, int Width, int Height)
{
	RECT cRect;
	if (hWnd == NULL) return;

	cRect.left = 0;
	cRect.top = 0;
	cRect.right = Width;
	cRect.bottom = Height;
	AdjustWindowRect(&cRect, WS_BORDER | WS_CAPTION | WS_SYSMENU | WS_SIZEBOX, 1);
	cRect.right -= cRect.left;
	cRect.bottom -= cRect.top;
	SetWindowPos(hWnd, NULL, 0, 0, cRect.right, cRect.bottom, SWP_NOMOVE | SWP_NOOWNERZORDER);
	OnWinResize(Width, Height);
}

// Set StatusBar Text
void SetStatusBarText(char *format, ...)
{
	// Still nothing coded yet...
}

// Main window callbacks
LRESULT CALLBACK PokeMiniW_WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	int wmId, wmEvent, i;
	char tmp[PMTMPV];

	switch (message) {
		case WM_COMMAND:
			wmId    = LOWORD(wParam); 
			wmEvent = HIWORD(wParam); 
			switch (wmId) {
				case ID_FILE_OPENMIN:
					Menu_File_OpenMin();
					update_options();
					break;
				case ID_RECENT0:
					Recent_OpenMin(wclc_recent[0]);
					break;
				case ID_RECENT1:
					Recent_OpenMin(wclc_recent[1]);
					break;
				case ID_RECENT2:
					Recent_OpenMin(wclc_recent[2]);
					break;
				case ID_RECENT3:
					Recent_OpenMin(wclc_recent[3]);
					break;
				case ID_RECENT4:
					Recent_OpenMin(wclc_recent[4]);
					break;
				case ID_RECENT5:
					Recent_OpenMin(wclc_recent[5]);
					break;
				case ID_RECENT6:
					Recent_OpenMin(wclc_recent[6]);
					break;
				case ID_RECENT7:
					Recent_OpenMin(wclc_recent[7]);
					break;
				case ID_RECENT8:
					Recent_OpenMin(wclc_recent[8]);
					break;
				case ID_RECENT9:
					Recent_OpenMin(wclc_recent[9]);
					break;
				case ID_RECENT_CLEARLIST:
					for (i=0; i<10; i++) wclc_recent[i][0] = 0;
					update_options();
					break;
				case ID_FILE_LOADSTATE:
					Menu_File_LoadState();
					update_options();
					break;
				case ID_FILE_SAVESTATE:
					Menu_File_SaveState();
					break;
				case ID_CAPTURE_SNAPSHOT1XPREVIEW:
					Menu_Capt_Snapshot1x();
					break;
				case ID_CAPTURE_SNAPSHOTFROMLCD:
					Menu_Capt_SnapshotLCD();
					break;
				case ID_FILE_QUIT:
					DestroyWindow(hWnd);
					break;
				case ID_ZOOM_1X:
					Menu_Options_Zoom(1);
					update_options();
					break;
				case ID_ZOOM_2X:
					Menu_Options_Zoom(2);
					update_options();
					break;
				case ID_ZOOM_3X:
					Menu_Options_Zoom(3);
					update_options();
					break;
				case ID_ZOOM_4X:
					Menu_Options_Zoom(4);
					update_options();
					break;
				case ID_ZOOM_5X:
					Menu_Options_Zoom(5);
					update_options();
					break;
				case ID_ZOOM_6X:
					Menu_Options_Zoom(6);
					update_options();
					break;
				case ID_PALETTE_0:
					Menu_Options_Palette(0);
					update_options();
					break;
				case ID_PALETTE_1:
					Menu_Options_Palette(1);
					update_options();
					break;
				case ID_PALETTE_2:
					Menu_Options_Palette(2);
					update_options();
					break;
				case ID_PALETTE_3:
					Menu_Options_Palette(3);
					update_options();
					break;
				case ID_PALETTE_4:
					Menu_Options_Palette(4);
					update_options();
					break;
				case ID_PALETTE_5:
					Menu_Options_Palette(5);
					update_options();
					break;
				case ID_PALETTE_6:
					Menu_Options_Palette(6);
					update_options();
					break;
				case ID_PALETTE_7:
					Menu_Options_Palette(7);
					update_options();
					break;
				case ID_PALETTE_8:
					Menu_Options_Palette(8);
					update_options();
					break;
				case ID_PALETTE_9:
					Menu_Options_Palette(9);
					update_options();
					break;
				case ID_PALETTE_10:
					Menu_Options_Palette(10);
					update_options();
					break;
				case ID_PALETTE_11:
					Menu_Options_Palette(11);
					update_options();
					break;
				case ID_PALETTE_12:
					Menu_Options_Palette(12);
					update_options();
					break;
				case ID_PALETTE_13:
					Menu_Options_Palette(13);
					update_options();
					break;
				case ID_PALETTE_14:
					Menu_Options_Palette(14);
					update_options();
					break;
				case ID_PALETTE_15:
					Menu_Options_Palette(15);
					update_options();
					break;
				case ID_LCDMODE_ANALOG:
					Menu_Options_LCDMode(0);
					update_options();
					break;
				case ID_LCDMODE_3SHADES:
					Menu_Options_LCDMode(1);
					update_options();
					break;
				case ID_LCDMODE_2SHADES:
					Menu_Options_LCDMode(2);
					update_options();
					break;
				case ID_LCDMODE_COLORS:
					Menu_Options_LCDMode(3);
					update_options();
					break;
				case ID_LCDFILTER_NONE:
					Menu_Options_LCDFilter(0);
					update_options();
					break;
				case ID_LCDFILTER_MATRIX:
					Menu_Options_LCDFilter(1);
					update_options();
					break;
				case ID_LCDFILTER_SCANLINE:
					Menu_Options_LCDFilter(2);
					update_options();
					break;
				case ID_LCDCONTRAST_DEFAULT:
					Menu_Options_LCDContrast(64);
					update_options();
					break;
				case ID_LCDCONTRAST_LOWEST:
					Menu_Options_LCDContrast(0);
					update_options();
					break;
				case ID_LCDCONTRAST_LOW:
					Menu_Options_LCDContrast(25);
					update_options();
					break;
				case ID_LCDCONTRAST_MEDIUM:
					Menu_Options_LCDContrast(50);
					update_options();
					break;
				case ID_LCDCONTRAST_HIGH:
					Menu_Options_LCDContrast(75);
					update_options();
					break;
				case ID_LCDCONTRAST_HIGHEST:
					Menu_Options_LCDContrast(100);
					update_options();
					break;
				case ID_LCDCONTRAST_CUSTOM:
					CustomContrast_Dialog(hInst, hMainWnd);
					update_options();
					break;
				case ID_LCDBRIGHT_DEFAULT:
					Menu_Options_LCDBright(0);
					update_options();
					break;
				case ID_LCDBRIGHT_LIGHTER:
					Menu_Options_LCDBright(24);
					update_options();
					break;
				case ID_LCDBRIGHT_LIGHT:
					Menu_Options_LCDBright(12);
					update_options();
					break;
				case ID_LCDBRIGHT_DARK:
					Menu_Options_LCDBright(-12);
					update_options();
					break;
				case ID_LCDBRIGHT_DARKER:
					Menu_Options_LCDBright(-24);
					update_options();
					break;
				case ID_LCDBRIGHT_CUSTOM:
					CustomBright_Dialog(hInst, hMainWnd);
					update_options();
					break;
				case ID_RUMBLELEVEL_0:
					Menu_Options_RumbleLevel(0);
					update_options();
					break;
				case ID_RUMBLELEVEL_1:
					Menu_Options_RumbleLevel(1);
					update_options();
					break;
				case ID_RUMBLELEVEL_2:
					Menu_Options_RumbleLevel(2);
					update_options();
					break;
				case ID_RUMBLELEVEL_3:
					Menu_Options_RumbleLevel(3);
					update_options();
					break;
				case ID_OPTIONS_FULLSCREEN:
					Menu_Options_Fullscreen();
					update_options();
					break;
				case ID_SOUND_DISABLED:
					Menu_Options_Sound(0);
					update_options();
					break;
				case ID_SOUND_GENERATED:
					Menu_Options_Sound(1);
					update_options();
					break;
				case ID_SOUND_DIRECT:
					Menu_Options_Sound(2);
					update_options();
					break;
				case ID_SOUND_EMULATED:
					Menu_Options_Sound(3);
					update_options();
					break;
				case ID_SOUND_DIRECTPWM:
					Menu_Options_Sound(4);
					update_options();
					break;
				case ID_OPTIONS_PIEZOFILTER:
					Menu_Options_PiezoFilter();
					update_options();
					break;
				case ID_SYNCCYCLES_8:
					Menu_Options_SyncCycles(8);
					update_options();
					break;
				case ID_SYNCCYCLES_16:
					Menu_Options_SyncCycles(16);
					update_options();
					break;
				case ID_SYNCCYCLES_32:
					Menu_Options_SyncCycles(32);
					update_options();
					break;
				case ID_SYNCCYCLES_64:
					Menu_Options_SyncCycles(64);
					update_options();
					break;
				case ID_SYNCCYCLES_128:
					Menu_Options_SyncCycles(128);
					update_options();
					break;
				case ID_SYNCCYCLES_256:
					Menu_Options_SyncCycles(256);
					update_options();
					break;
				case ID_SYNCCYCLES_512:
					Menu_Options_SyncCycles(512);
					update_options();
					break;
				case ID_OPTIONS_LOWBATTERY:
					Menu_Options_LowBattery();
					update_options();
					break;
				case ID_RTC_NORTC:
					Menu_Options_RTC(0);
					update_options();
					break;
				case ID_RTC_STATE:
					Menu_Options_RTC(1);
					update_options();
					break;
				case ID_RTC_HOST:
					Menu_Options_RTC(2);
					update_options();
					break;
				case ID_OPTIONS_SHAREEEPROM:
					Menu_Options_ShareEEPROM();
					update_options();
					break;
				case ID_MULTICART_DISABLED:
					Menu_Options_Multicart(0);
					update_options();
					break;
				case ID_MULTICART_FLASH512KB:
					Menu_Options_Multicart(1);
					update_options();
					break;
				case ID_MULTICART_LUPIN512KB:
					Menu_Options_Multicart(2);
					update_options();
					break;
				case ID_OPTIONS_FORCEFREEBIOS:
					Menu_Options_ForceFreeBIOS();
					update_options();
					break;
				case ID_OPTIONS_CUSTOMPALETTEEDIT:
					set_emumode(EMUMODE_STOP, 1);
					CustomPalEdit_Dialog(hInst, hMainWnd);
					set_emumode(EMUMODE_RESTORE, 1);
					break;
				case ID_OPTIONS_DEFINEKEYBOARD:
					set_emumode(EMUMODE_STOP, 1);
					DefineKeyboard_Dialog(hInst, hMainWnd);
					set_emumode(EMUMODE_RESTORE, 1);
					break;
				case ID_OPTIONS_DEFINEJOYSTICK:
					set_emumode(EMUMODE_STOP, 1);
					DefineJoystick_Dialog(hInst, hMainWnd);
					set_emumode(EMUMODE_RESTORE, 1);
					break;
				case ID_OPTIONS_UPDATEEEPROM:
					Menu_Options_UpdateEEPROM();
					break;
				case ID_EMULATOR_START:
					set_emumode(EMUMODE_RUNFULL, 0);
					wclc_inactivestate = 1;
					SetStatusBarText("Emulation started\n");
					break;
				case ID_EMULATOR_STOP:
					set_emumode(EMUMODE_STOP, 0);
					wclc_inactivestate = 2;
					SetStatusBarText("Emulation stoped\n");
					break;
				case ID_RESET_HARD:
					Menu_Emulator_Reset(1);
					break;
				case ID_RESET_SOFT:
					Menu_Emulator_Reset(0);
					break;
				case ID_VIDEO_GDI:
					Menu_Emulator_VideoRend(0);
					update_options();
					break;
				case ID_VIDEO_DIRECTDRAW:
					Menu_Emulator_VideoRend(1);
					update_options();
					break;
				case ID_VIDEO_DIRECT3D:
					Menu_Emulator_VideoRend(2);
					update_options();
					break;
				case ID_EMULATOR_AUTORUN:
					Menu_Emulator_Autorun();
					update_options();
					break;
				case ID_EMULATOR_PAUSEWHENINACTIVE:
					Menu_Emulator_PauseInactive();
					update_options();
					break;
				case ID_FILEASSOCIATION_REGISTER:
					Menu_FileAssociation_Register();
					break;
				case ID_FILEASSOCIATION_UNREGISTER:
					Menu_FileAssociation_Unregister();
					break;
				case ID_HELP_VISITWEBSITE:
					Menu_Help_VisitWebsite();
					break;
				case ID_HELP_COMMANDLINE:
					Menu_Help_CommandLine();
					break;
				case ID_HELP_ABOUT:
					Menu_Help_About();
					break;
				default:
					return DefWindowProc(hWnd, message, wParam, lParam);
			}
			break;
		case WM_KEYDOWN:
			OnWinKeyDownEvent((uint32_t)wParam);
			break;
		case WM_KEYUP:
			OnWinKeyUpEvent((uint32_t)wParam);
			break;
		case WM_PAINT:
			VideoRend->Paint(hMainWnd);
			break;
		case WM_SIZE:
			OnWinResize(LOWORD(lParam), HIWORD(lParam));
			break;
		case WM_SIZING:
			OnWinSizing(wParam, (RECT *)lParam);
			break;
		case WM_DESTROY:
			PokeMiniW_DestroyWindow();
			PostQuitMessage(0);
			break;
		case WM_ACTIVATE:
			if (wclc_pauseinactive) {
				if (LOWORD(wParam) > 0) {
					if (wclc_inactivestate == 0) {
						set_emumode(EMUMODE_RUNFULL, 0);
						wclc_inactivestate = 1;
					}
				} else {
					if (wclc_inactivestate == 1) {
						set_emumode(EMUMODE_STOP, 0);
						wclc_inactivestate = 0;
					}
				}
			}
			break;
		case WM_DROPFILES:
			DragQueryFile((HDROP)wParam, 0, tmp, PMTMPV);
			DragDrop_OpenMin(tmp);
			update_options();
			break;
		default:
			return DefWindowProc(hWnd, message, wParam, lParam);
	}
	return 0;
}
