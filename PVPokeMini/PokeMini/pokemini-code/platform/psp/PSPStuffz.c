/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "PSPStuffz.h"

PSP_MODULE_INFO("PokeMini", 0, 1, 1);
PSP_MAIN_THREAD_ATTR(THREAD_ATTR_USER);

int _isatty(int fildes) { return 1; } // devkitPro Hack

static unsigned int __attribute__((aligned(16))) list[262144];
extern uint16_t *VIDEO;
extern int emurunning;
uint16_t *PSP_DispVideo, *PSP_DrawVideo;

int callbackThread(SceSize args, void *argp)
{
	int cbid;
	cbid = sceKernelCreateCallback("Exit Callback", exitCallback, NULL);
	sceKernelRegisterExitCallback(cbid);
	sceKernelSleepThreadCB();
	return 0;
}

int setupCallbacks(void)
{
	int thid = 0;
	thid = sceKernelCreateThread("update_thread", callbackThread, 0x11, 0xFA0, 0, 0);
	if(thid >= 0) sceKernelStartThread(thid, 0, 0);
	return thid;
}

void PSP_Correct_Timezone()
{
	char tzStr[32];
	int tzOffset = 0;
	int dst = 0;
	sceUtilityGetSystemParamInt(PSP_SYSTEMPARAM_ID_INT_TIMEZONE, &tzOffset);
	sceUtilityGetSystemParamInt(PSP_SYSTEMPARAM_ID_INT_DAYLIGHTSAVINGS, &dst);
	int tzOffsetAbs = tzOffset < 0 ? -tzOffset : tzOffset;
	sprintf(tzStr, "GMT%s%02i:%02i%s", (tzOffset < 0) ? "+" : "-", tzOffsetAbs / 60, tzOffsetAbs % 60, (dst == 1) ? " DST" : "");
	setenv("TZ", tzStr, 1);
	tzset();
} 

void PSP_Init()
{
	setupCallbacks();

	PSP_Correct_Timezone();
	sceCtrlSetSamplingCycle(0);
	sceCtrlSetSamplingMode(PSP_CTRL_MODE_DIGITAL);

	sceGuInit();

	sceDisplaySetMode(0, 480, 272);		// Seems optional
	sceDisplaySetFrameBuf((void *)0, 512, PSP_DISPLAY_PIXEL_FORMAT_565, PSP_DISPLAY_SETBUF_IMMEDIATE);
	sceGuStart(GU_DIRECT, list);

	sceGuDrawBuffer(GU_PSM_5650, (void *)0, 512);
	sceGuDispBuffer(480, 272, (void *)(512*512*2), 512);
	sceDisplayWaitVblankStart();
	sceGuDisplay(GU_TRUE);

	PSP_DrawVideo = (uint16_t *)sceGeEdramGetAddr();
	PSP_DispVideo = PSP_DrawVideo + (512*512*2);

	// Clear screen and offset to the center
	memset(PSP_DrawVideo, 0, 512*272*2);

	// Initialize sound
	pspAudioInit();
}

void PSP_Flip()
{
	uint16_t *tmp;

	// Flush all data cache
	sceKernelDcacheWritebackAll();

	// Swap buffers
	tmp = PSP_DrawVideo;
	PSP_DrawVideo = PSP_DispVideo;
	PSP_DispVideo = tmp;
	sceDisplaySetFrameBuf(PSP_DispVideo, 512, PSP_DISPLAY_PIXEL_FORMAT_565, PSP_DISPLAY_SETBUF_IMMEDIATE);
}

void PSP_ClearDraw()
{
	memset(PSP_DrawVideo, 0, 512*272*2);
}

void PSP_Quit()
{
	pspAudioEnd();
	sceGuTerm();
	sceKernelExitGame();
}
