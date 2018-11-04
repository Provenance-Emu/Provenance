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

#include <asndlib.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <malloc.h>
#include <math.h>
#include <gccore.h>
#include <wiiuse/wpad.h>
#include <ogc/lwp_watchdog.h>
#include <fat.h>
#include <unistd.h>
#include <time.h>

#include "PokeMini.h"
#include "Hardware.h"
#include "Joystick.h"

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

const char *AppName = "PokeMini " PokeMini_Version " Wii";

#define DEFAULT_FIFO_SIZE	(256*1024)
#define STACKSIZE		(8192)

int emurunning = 1;
int PMWidth, PMHeight;
int PixPitch;

GXRModeObj *rmode;
static void *xfb = NULL;
GXTexObj vbuf_tex;
u16 *vbuf = NULL;
u16 *vbuftiled = NULL;
int vbuf_w, vbuf_h, vbuf_t;
float vbuf_fnw, vbuf_fnh;

static lwp_t h_snd = LWP_THREAD_NULL;
static u8 h_snd_stack[STACKSIZE];
static s16 *h_snd_buffer[2] = {NULL, NULL};
static int h_snd_ptr = 0;
static int h_snd_mode = 0;

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

// Joystick names and mapping (NEW IN 0.5.0)
char *Wii_KeysNames[] = {
	"Off",		// -1
	"Mote 2",		// 0
	"Mote 1",		// 1
	"Mote B",		// 2
	"Mote A",		// 3
	"Mote -",	// 4
	NULL,		// 5
	NULL,		// 6
	NULL,		// 7
	"Mote Left",		// 8
	"Mote Right",	// 9
	"Mote Down",		// 10
	"Mote Up",		// 11
	"Mote +",		// 12
	NULL, 		// 13
	NULL, 		// 14
	NULL, 		// 15
	"N.Z/C.Up",		// 16
	"N.C/C.Left",		// 17
	"Classic ZR",		// 18
	"Classic X",		// 19
	"Classic A",		// 20
	"Classic Y",		// 21
	"Classic B",		// 22
	"Classic ZL",		// 23
	NULL,		// 24
	"Classic FR",		// 25
	"Classic +",		// 26
	"Classic H",		// 27
	"Classic -",		// 28
	"Classic FL",		// 29
	"C.Down",		// 30
	"C.Right",		// 31
};
int Wii_KeysMapping[] = {
	1,		// Menu
	3,		// A
	2,		// B
	12,		// C
	11,		// Up
	10,		// Down
	8,		// Left
	9,		// Right
	0,		// Power
	4		// Shake
};

// Custom command line (NEW IN 0.5.0)
int clc_zoom = 4;
const TCommandLineCustom CustomConf[] = {
	{ "zoom", &clc_zoom, COMMANDLINE_INT, 2, 6 },
	{ "", NULL, COMMANDLINE_EOL }
};

// Platform menu (REQUIRED >= 0.4.4)
int UIItems_PlatformC(int index, int reason);
TUIMenu_Item UIItems_Platform[] = {
	PLATFORMDEF_GOBACK,
	{ 0,  1, "Zoom: %s", UIItems_PlatformC },
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
				if (clc_zoom < 2) clc_zoom = 6;
				zoomchanged = 1;
				break;
		}
	}
	if (reason == UIMENU_RIGHT) {
		switch (index) {
			case 1: // Zoom
				clc_zoom++;
				if (clc_zoom > 6) clc_zoom = 2;
				zoomchanged = 1;
				break;
			case 9: // Define keys...
				JoystickEnterMenu();
				break;
		}
	}
	UIMenu_ChangeItem(UIItems_Platform, 1, "Zoom: %s", clc_zoom_txt[clc_zoom]);
	if (zoomchanged) {
		setup_screen();
		return 0;
	}
	return 1;
}

// A helper to calculate the power of 2 needed by the texture
static inline int getpow2siz16(int n)
{
	n--;
	n |= n >> 8;
	n |= n >> 4;
	n |= n >> 2;
	n |= n >> 1;
	return n + 1;
}

// Setup screen
void setup_screen()
{
	TPokeMini_VideoSpec *videospec;
	int depth;

	// Calculate size based of zoom
	if (clc_zoom == 2) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video2x2;
		PMWidth = 192; PMHeight = 128;
		UIMenu_SetDisplay(192, 128, PokeMini_BGR16, (uint8_t *)PokeMini_BG2, (uint16_t *)PokeMini_BG2_PalBGR16, (uint32_t *)PokeMini_BG2_PalBGR32);
	} else if (clc_zoom == 3) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video3x3;
		PMWidth = 288; PMHeight = 192;
		UIMenu_SetDisplay(288, 192, PokeMini_BGR16, (uint8_t *)PokeMini_BG3, (uint16_t *)PokeMini_BG3_PalBGR16, (uint32_t *)PokeMini_BG3_PalBGR32);
	} else if (clc_zoom == 4) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video4x4;
		PMWidth = 384; PMHeight = 256;
		UIMenu_SetDisplay(384, 256, PokeMini_BGR16, (uint8_t *)PokeMini_BG4, (uint16_t *)PokeMini_BG4_PalBGR16, (uint32_t *)PokeMini_BG4_PalBGR32);
	} else if (clc_zoom == 5) {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video5x5;
		PMWidth = 480; PMHeight = 320;
		UIMenu_SetDisplay(480, 320, PokeMini_BGR16, (uint8_t *)PokeMini_BG5, (uint16_t *)PokeMini_BG5_PalBGR16, (uint32_t *)PokeMini_BG5_PalBGR32);
	} else {
		videospec = (TPokeMini_VideoSpec *)&PokeMini_Video6x6;
		PMWidth = 576; PMHeight = 384;
		UIMenu_SetDisplay(576, 384, PokeMini_BGR16, (uint8_t *)PokeMini_BG6, (uint16_t *)PokeMini_BG6_PalBGR16, (uint32_t *)PokeMini_BG6_PalBGR32);
	}

	// Set video spec and check if is supported
	depth = PokeMini_SetVideo(videospec, 16, CommandLine.lcdfilter, CommandLine.lcdmode);
	if (!depth) {
		fprintf(stderr, "Couldn't set video spec from 16 bpp\n");
		exit(1);
	}

	// Set video mode
	vbuf_w = getpow2siz16(PMWidth);
	vbuf_fnw = (float)PMWidth / (float)vbuf_w;
	vbuf_h = getpow2siz16(PMHeight);
	vbuf_fnh = (float)PMHeight / (float)vbuf_h;
	vbuf_t = vbuf_w * vbuf_h;
	GX_InvVtxCache();
	GX_InvalidateTexAll();
	if (vbuf) {
		free(vbuf);
		vbuf = NULL;
	}
	vbuf = MEM_K0_TO_K1(memalign(32, vbuf_t * 2));
	if (vbuftiled) {
		free(vbuftiled);
		vbuftiled = NULL;
	}
	vbuftiled = MEM_K0_TO_K1(memalign(32, vbuf_t * 2));
	GX_InitTexObj(&vbuf_tex, vbuftiled, vbuf_w, vbuf_h, GX_TF_RGB565, GX_CLAMP, GX_CLAMP, 0);

	// Calculate pitch and offset
	PixPitch = vbuf_w;
}

// Render graphics
void rendergraphics(int offset, int waitvsync)
{
	int x, y, phy, vbuf_wZ;
	u16 *vbt, *vb = vbuf;
	static float ffoffsetT[8] = {
		-0.04f, -0.03f, -0.02f, -0.01f,
		0.00f, 0.01f, 0.02f, 0.03f,
	};
	float ffoffset = ffoffsetT[offset+4];
	float varea = 0.85f;

	vbuf_wZ = vbuf_w >> 2;
	for (y=0; y<PMHeight; y++) {
		phy = (((y >> 2) * vbuf_wZ) << 4) | ((y & 3) << 2);
		for (x=0; x<PMWidth; x+=4) {
			vbt = (u16 *)vbuftiled + phy + (x << 2);
			vbt[0] = *vb++;
			vbt[1] = *vb++;
			vbt[2] = *vb++;
			vbt[3] = *vb++;
		}
		vb += vbuf_w - PMWidth;
	}
	GX_InitTexObjData(&vbuf_tex, vbuftiled);
	GX_LoadTexObj(&vbuf_tex, GX_TEXMAP0);

	GX_Begin(GX_QUADS, GX_VTXFMT0, 4);
		GX_Position3f32(-varea, -varea+ffoffset, 0.0f);
		GX_TexCoord2f32(    0.0f,     0.0f);
		GX_Position3f32( varea, -varea+ffoffset, 0.0f);
		GX_TexCoord2f32(vbuf_fnw,     0.0f);
		GX_Position3f32( varea,  varea+ffoffset, 0.0f);
		GX_TexCoord2f32(vbuf_fnw, vbuf_fnh);
		GX_Position3f32(-varea,  varea+ffoffset, 0.0f);
		GX_TexCoord2f32(    0.0f, vbuf_fnh);
	GX_End();

	GX_DrawDone();
	GX_CopyDisp(xfb, GX_TRUE);

	VIDEO_Flush();
	if (waitvsync) VIDEO_WaitVSync();
}

// Handle inputs
void HandleInputs()
{
	int bdown, bheld;
	WPAD_ScanPads();
	bdown = WPAD_ButtonsDown(0);
	if (bdown & WPAD_BUTTON_HOME) emurunning = 0;
	bheld = WPAD_ButtonsHeld(0);
	JoystickBitsEvent(bheld);
}

// Sound thread for streaming
static void snd_thread_add(int voice)
{
	ASND_AddVoice(0, (void *)h_snd_buffer[h_snd_ptr], SOUNDBUFFER);
	h_snd_ptr ^= 1;
	h_snd_mode = 0;
}
static void *snd_thread(void *unused)
{
	int first_time = 1;
	h_snd_mode = 0;

	while (emurunning) {
		if (h_snd_mode == 0) {
			// Collect data
			if (!ASND_TestPointer(0, h_snd_buffer[h_snd_ptr]) || ASND_StatusVoice(0) == SND_UNUSED) {
				MinxAudio_GetSamplesS16(h_snd_buffer[h_snd_ptr], SOUNDBUFFER/2);
				h_snd_mode = 1;
			}
		}
		if (h_snd_mode == 1) {
			// Waiting (or init)
			if (first_time) {
				ASND_SetVoice(0, VOICE_MONO_16BIT, 44100, 0, (void *)h_snd_buffer[h_snd_ptr], SOUNDBUFFER, MID_VOLUME, MID_VOLUME, snd_thread_add);
				first_time = 0;
			}
		}
		usleep(1000);
	}

	return NULL;
}

// Enable / Disable sound
void enablesound(int sound)
{
	MinxAudio_ChangeEngine(sound);
	if (AudioEnabled) ASND_Pause(!sound);
}

// Get ticks count in miliseconds
u32 gettickscount()
{
	return ticks_to_millisecs(gettime());
}

// Menu loop
void menuloop()
{
	// Stop sound
	enablesound(0);

	// Update EEPROM
	PokeMini_SaveFromCommandLines(0);

	// Menu's loop
	while (emurunning && (UI_Status == UI_STATUS_MENU)) {
		// Slow down a little
		usleep(16000);

		// Process UI
		UIMenu_Process();

		// Screen rendering
		UIMenu_Display_16(vbuf, PixPitch);
		rendergraphics(0, 1);

		// Handle inputs
		HandleInputs();
	}

	// Apply configs
	PokeMini_ApplyChanges();
	if (UI_Status == UI_STATUS_EXIT) emurunning = 0;
	else enablesound(CommandLine.sound);
}

// Main function
int main(int argc, char **argv)
{
	f32 yscale;
	u32 xfbHeight;
	Mtx44 projection;

	// Initialize hardware
	VIDEO_Init();
	WPAD_Init();
	ASND_Init(NULL);
	rmode = VIDEO_GetPreferredMode(NULL);
	
	// Allocate framebuffer
	xfb = MEM_K0_TO_K1(SYS_AllocateFramebuffer(rmode));

	// Configure hardware video
	VIDEO_Configure(rmode);
	VIDEO_SetNextFramebuffer(xfb);
	VIDEO_SetBlack(FALSE);
	VIDEO_Flush();
	VIDEO_WaitVSync();
	if (rmode->viTVMode & VI_NON_INTERLACE) VIDEO_WaitVSync();

	// Setup the fifo and then init the flipper
	void *gp_fifo = NULL;
	gp_fifo = MEM_K0_TO_K1(memalign(32, DEFAULT_FIFO_SIZE));
	memset(gp_fifo, 0, DEFAULT_FIFO_SIZE);
 	GX_Init(gp_fifo, DEFAULT_FIFO_SIZE);
 
	// Clears the bg to color and clears the z buffer
	GXColor background = {0, 0, 0, 0xff};
	GX_SetCopyClear(background, 0x00ffffff);

	// Other GX setup
	GX_SetViewport(0, 0, rmode->fbWidth,rmode->efbHeight, 0, 1);
	yscale = GX_GetYScaleFactor(rmode->efbHeight, rmode->xfbHeight);
	xfbHeight = GX_SetDispCopyYScale(yscale);
	GX_SetScissor(0, 0, rmode->fbWidth, rmode->efbHeight);
	GX_SetDispCopySrc(0, 0, rmode->fbWidth, rmode->efbHeight);
	GX_SetDispCopyDst(rmode->fbWidth, xfbHeight);
	GX_SetCopyFilter(rmode->aa, rmode->sample_pattern, GX_TRUE, rmode->vfilter);
	GX_SetFieldMode(rmode->field_rendering, ((rmode->viHeight == 2 * rmode->xfbHeight) ? GX_ENABLE : GX_DISABLE));
	if (rmode->aa)
		GX_SetPixelFmt(GX_PF_RGB565_Z16, GX_ZC_LINEAR);
	else
		GX_SetPixelFmt(GX_PF_RGB8_Z24, GX_ZC_LINEAR);
	GX_SetCullMode(GX_CULL_NONE);
	GX_SetZMode(GX_TRUE, GX_LEQUAL, GX_TRUE);
	GX_SetColorUpdate(GX_TRUE);
	GX_CopyDisp(xfb, GX_TRUE);
	GX_SetDispCopyGamma(GX_GM_1_0);

	// setup the vertex descriptor and attribute table
	GX_ClearVtxDesc();
	GX_SetVtxDesc(GX_VA_POS, GX_DIRECT);
	GX_SetVtxDesc(GX_VA_TEX0, GX_DIRECT);
	GX_SetVtxAttrFmt(GX_VTXFMT0, GX_VA_POS, GX_POS_XYZ, GX_F32, 0);
	GX_SetVtxAttrFmt(GX_VTXFMT0, GX_VA_TEX0, GX_TEX_ST, GX_F32, 0);

	// Setup the TEV combiner operation
	GX_SetNumChans(0);
	GX_SetNumTexGens(1);
	GX_SetTexCoordGen(GX_TEXCOORD0, GX_TG_MTX2x4, GX_TG_TEX0, GX_IDENTITY);
	GX_SetTevOp(GX_TEVSTAGE0, GX_REPLACE);
	GX_SetTevOrder(GX_TEVSTAGE0, GX_TEXCOORD0, GX_TEXMAP0, GX_COLORNULL);

	// setup our projection matrix
	guOrtho(projection, -1.0f, 1.0f, -1.0f, 1.0f, 0, 10.0f);
	GX_LoadProjectionMtx(projection, GX_ORTHOGRAPHIC);

	// Initialize fat lib
	if (!fatInitDefault()) {
		printf("fatInitDefault failure: terminating\n");
		//exit(0);
	}

	// Process arguments
	printf("%s\n\n", AppName);
	PokeMini_InitDirs("/PokeMini", NULL);
	CommandLineInit();
	CommandLineConfFile("pokemini.cfg", "pokemini_wii.cfg", CustomConf);
	JoystickSetup("WII", 0, 30000, Wii_KeysNames, 32, Wii_KeysMapping);

	// Initialize the display
	setup_screen();

	// Initialize the sound
	h_snd_buffer[0] = (s16 *)memalign(32, SOUNDBUFFER);
	memset(h_snd_buffer[0], 0, SOUNDBUFFER);
	h_snd_buffer[1] = (s16 *)memalign(32, SOUNDBUFFER);
	memset(h_snd_buffer[1], 0, SOUNDBUFFER);
	if (LWP_CreateThread(&h_snd, (void *)snd_thread, NULL, h_snd_stack, STACKSIZE, 80) == -1) {
		AudioEnabled = 0;
	} else {
		AudioEnabled = 1;
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
	enablesound(CommandLine.sound);

	// Emulator's loop
	unsigned long time, NewTickSync = 0;
	while (emurunning) {
		// Emulate and syncronize
		time = gettickscount();
		if (RequireSoundSync) {
			PokeMini_EmulateFrame();
			// Sleep a little in the hope to free a few samples
			while (MinxAudio_SyncWithAudio()) usleep(1000);
		} else {
			PokeMini_EmulateFrame();
			do {
				usleep(1000);
				time = gettickscount();
			} while (time < NewTickSync);
			NewTickSync = time + 13;	// Aprox 72 times per sec
		}

		// Screen rendering
		PokeMini_VideoBlit(vbuf, PixPitch);
		if (PokeMini_Rumbling) {
			rendergraphics(PokeMini_GenRumbleOffset(1), 0);
		} else {
			rendergraphics(0, 0);
		}
		LCDDirty = 0;

		// Handle inputs
		HandleInputs();

		// Menu
		if (UI_Status == UI_STATUS_MENU) menuloop();

		// calculate FPS
		// TODO
	}

	// Disable sound & free UI
	enablesound(0);
	UIMenu_Destroy();

	// Wait for thread to finish
	if(h_snd != LWP_THREAD_NULL)
	{
		LWP_JoinThread(h_snd, NULL);
		h_snd = LWP_THREAD_NULL;
	}

	// Save Stuff
	PokeMini_SaveFromCommandLines(1);

	// Terminate...
	printf("Shutdown emulator...\n");
	PokeMini_VideoPalette_Free();
	PokeMini_Destroy();

	// Free up memory
	if (vbuf) free(vbuf);
	if (vbuftiled) free(vbuftiled);
	if (h_snd_buffer[0]) free(h_snd_buffer[0]);
	if (h_snd_buffer[1]) free(h_snd_buffer[1]);

	exit(0);
}
