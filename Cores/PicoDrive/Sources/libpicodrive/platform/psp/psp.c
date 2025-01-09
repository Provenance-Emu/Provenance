/*
 * PicoDrive
 * (C) notaz, 2007,2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>

#include <pspkernel.h>
#include <pspiofilemgr.h>
#include <pspdisplay.h>
#include <psppower.h>
#include <psprtc.h>
#include <pspgu.h>
#include <pspsdk.h>

#include "psp.h"
#include "emu.h"
#include "../common/lprintf.h"
#include "version.h"

extern int pico_main(void);

#ifndef FW15

PSP_MODULE_INFO("PicoDrive", 0, 1, 51);
PSP_HEAP_SIZE_MAX();

int main() { return pico_main(); }	/* just a wrapper */

#else

PSP_MODULE_INFO("PicoDrive", 0x1000, 1, 51);
PSP_MAIN_THREAD_ATTR(0);

int main()
{
	SceUID thid;

	/* this is the thing we need the kernel mode for */
	pspSdkInstallNoDeviceCheckPatch();

	thid = sceKernelCreateThread("pico_main", (SceKernelThreadEntry) pico_main, 32, 0x2000, PSP_THREAD_ATTR_USER, NULL);
	if (thid >= 0)
		sceKernelStartThread(thid, 0, 0);
#ifndef GCOV
	sceKernelExitDeleteThread(0);
#else
	while (engineState != PGS_Quit)
		sceKernelDelayThread(1024 * 1024);
#endif

	return 0;
}

#endif

int psp_unhandled_suspend = 0;

unsigned int __attribute__((aligned(16))) guCmdList[GU_CMDLIST_SIZE];

void *psp_screen = VRAM_FB0;

static int current_screen = 0; /* front bufer */

static SceUID main_thread_id = -1;

#define ANALOG_DEADZONE 80

/* Exit callback */
static int exit_callback(int arg1, int arg2, void *common)
{
	sceKernelExitGame();
	return 0;
}

/* Power Callback */
static int power_callback(int unknown, int pwrflags, void *common)
{
	lprintf("power_callback: flags: 0x%08X\n", pwrflags);

	/* check for power switch and suspending as one is manual and the other automatic */
	if (pwrflags & PSP_POWER_CB_POWER_SWITCH || pwrflags & PSP_POWER_CB_SUSPENDING || pwrflags & PSP_POWER_CB_STANDBY)
	{
		psp_unhandled_suspend = 1;
		if (engineState != PGS_Suspending)
			engineStateSuspend = engineState;
		sceKernelDelayThread(100000); // ??
	}
	else if (pwrflags & PSP_POWER_CB_RESUME_COMPLETE)
	{
		engineState = PGS_SuspendWake;
	}

	//sceDisplayWaitVblankStart();
	return 0;
}

/* Callback thread */
static int callback_thread(SceSize args, void *argp)
{
	int cbid;

	lprintf("callback_thread started with id %08x, priority %i\n",
		sceKernelGetThreadId(), sceKernelGetThreadCurrentPriority());

	cbid = sceKernelCreateCallback("Exit Callback", exit_callback, NULL);
	sceKernelRegisterExitCallback(cbid);
	cbid = sceKernelCreateCallback("Power Callback", power_callback, NULL);
	scePowerRegisterCallback(0, cbid);

	sceKernelSleepThreadCB();

	return 0;
}

void psp_init(void)
{
	SceUID thid;
	char buff[128], *r;

	/* fw 1.5 sometimes returns 8002032c, although getcwd works */
	r = getcwd(buff, sizeof(buff));
	if (r) sceIoChdir(buff);

	main_thread_id = sceKernelGetThreadId();

	lprintf("\n%s\n", "PicoDrive v" VERSION " " __DATE__ " " __TIME__);
	lprintf("running on %08x kernel\n", sceKernelDevkitVersion()),
	lprintf("entered psp_init, threadId %08x, priority %i\n", main_thread_id,
		sceKernelGetThreadCurrentPriority());

	thid = sceKernelCreateThread("update_thread", callback_thread, 0x11, 0xFA0, 0, NULL);
	if (thid >= 0)
	{
		sceKernelStartThread(thid, 0, 0);
	}

	/* video */
	sceDisplaySetMode(0, 480, 272);
	sceDisplaySetFrameBuf(VRAM_FB1, 512, PSP_DISPLAY_PIXEL_FORMAT_565, PSP_DISPLAY_SETBUF_NEXTFRAME);
	current_screen = 1;
	psp_screen = VRAM_FB0;

	/* gu */
	sceGuInit();

	sceGuStart(GU_DIRECT, guCmdList);
	sceGuDrawBuffer(GU_PSM_5650, (void *)VRAMOFFS_FB0, 512);
	sceGuDispBuffer(480, 272, (void *)VRAMOFFS_FB1, 512); // don't care
	sceGuClear(GU_COLOR_BUFFER_BIT | GU_DEPTH_BUFFER_BIT);
	sceGuDepthBuffer((void *)VRAMOFFS_DEPTH, 512);
	sceGuOffset(2048 - (480 / 2), 2048 - (272 / 2));
	sceGuViewport(2048, 2048, 480, 272);
	sceGuDepthRange(0xc350, 0x2710);
	sceGuScissor(0, 0, 480, 272);
	sceGuEnable(GU_SCISSOR_TEST);

	sceGuDepthMask(0xffff);
	sceGuDisable(GU_DEPTH_TEST);

	sceGuFrontFace(GU_CW);
	sceGuEnable(GU_TEXTURE_2D);
	sceGuTexFunc(GU_TFX_REPLACE, GU_TCC_RGB);
	sceGuAmbientColor(0xffffffff);
	sceGuColor(0xffffffff);
	sceGuFinish();
	sceGuSync(0, 0);

	sceDisplayWaitVblankStart();
	sceGuDisplay(GU_TRUE);


	/* input */
	sceCtrlSetSamplingCycle(0);
	sceCtrlSetSamplingMode(PSP_CTRL_MODE_ANALOG);
}

void psp_finish(void)
{
	lprintf("psp_finish..\n");
	sceGuTerm();

	//sceKernelSleepThread();
	sceKernelExitGame();
}

void psp_video_flip(int wait_vsync)
{
	if (wait_vsync) sceDisplayWaitVblankStart();
	sceDisplaySetFrameBuf(psp_screen, 512, PSP_DISPLAY_PIXEL_FORMAT_565,
		wait_vsync ? PSP_DISPLAY_SETBUF_IMMEDIATE : PSP_DISPLAY_SETBUF_NEXTFRAME);
	current_screen ^= 1;
	psp_screen = current_screen ? VRAM_FB0 : VRAM_FB1;
}

void *psp_video_get_active_fb(void)
{
	return current_screen ? VRAM_FB1 : VRAM_FB0;
}

void psp_video_switch_to_single(void)
{
	psp_screen = VRAM_FB0;
	sceDisplaySetFrameBuf(psp_screen, 512, PSP_DISPLAY_PIXEL_FORMAT_565, PSP_DISPLAY_SETBUF_NEXTFRAME);
	current_screen = 0;
}

void psp_msleep(int ms)
{
	sceKernelDelayThread(ms * 1000);
}

unsigned int psp_pad_read(int blocking)
{
	unsigned int buttons;
	SceCtrlData pad;
	if (blocking)
	     sceCtrlReadBufferPositive(&pad, 1);
	else sceCtrlPeekBufferPositive(&pad, 1);
	buttons = pad.Buttons;

	// analog..
	buttons &= ~(PBTN_NUB_UP|PBTN_NUB_DOWN|PBTN_NUB_LEFT|PBTN_NUB_RIGHT);
	if (pad.Lx < 128 - ANALOG_DEADZONE) buttons |= PBTN_NUB_LEFT;
	if (pad.Lx > 128 + ANALOG_DEADZONE) buttons |= PBTN_NUB_RIGHT;
	if (pad.Ly < 128 - ANALOG_DEADZONE) buttons |= PBTN_NUB_UP;
	if (pad.Ly > 128 + ANALOG_DEADZONE) buttons |= PBTN_NUB_DOWN;

	return buttons;
}

int psp_get_cpu_clock(void)
{
	return scePowerGetCpuClockFrequencyInt();
}

int psp_set_cpu_clock(int clock)
{
	int ret = scePowerSetClockFrequency(clock, clock, clock/2);
	if (ret != 0) lprintf("failed to set clock: %i\n", ret);

	return ret;
}

char *psp_get_status_line(void)
{
	static char buff[64];
	int ret, bat_percent, bat_time;
	pspTime time;

	ret = sceRtcGetCurrentClockLocalTime(&time);
	bat_percent = scePowerGetBatteryLifePercent();
	bat_time = scePowerGetBatteryLifeTime();
	if (ret < 0 || bat_percent < 0 || bat_time < 0) return NULL;

	snprintf(buff, sizeof(buff), "%02i:%02i  bat: %3i%%", time.hour, time.minutes, bat_percent);
	if (!scePowerIsPowerOnline())
		snprintf(buff+strlen(buff), sizeof(buff)-strlen(buff), " (%i:%02i)", bat_time/60, bat_time%60);
	return buff;
}

void psp_wait_suspend(void)
{
	// probably should do something smarter here?
	sceDisplayWaitVblankStart();
}

void psp_resume_suspend(void)
{
	// for some reason file IO doesn't seem to work
	// after resume for some period of time, at least on 1.5
	SceUID fd;
	int i;
	for (i = 0; i < 30; i++) {
		fd = sceIoOpen("EBOOT.PBP", PSP_O_RDONLY, 0777);
		if (fd >= 0) break;
		sceKernelDelayThread(100 * 1024);
	}
	if (fd >= 0) sceIoClose(fd);
	sceDisplayWaitVblankStart();
	if (i < 30)
		lprintf("io resumed after %i tries\n", i);
	else {
		lprintf("io resume failed with %08x\n", fd);
		sceKernelDelayThread(500 * 1024);
	}
}

/* alt logging */
#define LOG_FILE "log.txt"

#ifndef LPRINTF_STDIO
typedef struct _log_entry
{
	char buff[256];
	struct _log_entry *next;
} log_entry;

static log_entry *le_root = NULL;
#endif

/* strange: if this function leaks memory (before psp_init() call?),
 * resume after suspend breaks on 3.90 */
void lprintf(const char *fmt, ...)
{
	va_list vl;

#ifdef LPRINTF_STDIO
	va_start(vl, fmt);
	vprintf(fmt, vl);
	va_end(vl);
#else
	static SceUID logfd = -1;
	static int msg_count = 0;
	char buff[256];
	log_entry *le, *le1;

	if (logfd == -2) return; // disabled

	va_start(vl, fmt);
	vsnprintf(buff, sizeof(buff), fmt, vl);
	va_end(vl);

	// note: this is still unsafe code
	if (main_thread_id != sceKernelGetThreadId())
	{
		le = malloc(sizeof(*le));
		if (le == NULL) return;
		le->next = NULL;
		strcpy(le->buff, buff);
		if (le_root == NULL) le_root = le;
		else {
			for (le1 = le_root; le1->next != NULL; le1 = le1->next);
			le1->next = le;
		}
		return;
	}

	logfd = sceIoOpen(LOG_FILE, PSP_O_WRONLY|PSP_O_APPEND, 0777);
	if (logfd < 0) {
		if (msg_count == 0) logfd = -2;
		return;
	}

	if (le_root != NULL)
	{
		le1 = le_root;
		le_root = NULL;
		sceKernelDelayThread(1000);
		while (le1 != NULL) {
			le = le1;
			le1 = le->next;
			sceIoWrite(logfd, le->buff, strlen(le->buff));
			free(le);
			msg_count++;
		}
	}

	sceIoWrite(logfd, buff, strlen(buff));
	msg_count++;

	// make sure it gets flushed
	sceIoClose(logfd);
	logfd = -1;
#endif
}


