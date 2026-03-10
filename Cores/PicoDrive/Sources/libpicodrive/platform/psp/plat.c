/*
 * Platform interface functions for PSP picodrive frontend
 *
 * (C) 2020 irixxxx
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <malloc.h>
#include <errno.h>
#include <unistd.h>

#include "../common/emu.h"
#include "../libpicofe/menu.h"
#include "../libpicofe/plat.h"

#include <pspiofilemgr.h>
#include <pspthreadman.h>
#include <pspdisplay.h>
#include <psputils.h>
#include <psppower.h>
#include <pspgu.h>
#include <pspaudio.h>

#include "psp.h"
#include "emu.h"
#include "asm_utils.h"

#include <pico/pico_int.h>

/* graphics buffer management in VRAM:
 * -	VRAM_FB0, VRAM_FB1	frame buffers
 * -	VRAM_DEPTH		Z buffer (unused)
 * -	VRAM_BUF0, VRAM_BUF1	emulator render buffers
 * Emulator screen output is using the MD screen resolutions and is rendered
 * to VRAM_BUFx and subsequently projected (that is, scaled and blitted) into
 * the associated frame buffer (in PSP output resolution). Additional emulator
 * output is then directly rendered to that frame buffer.
 * The emulator menu is rendered directly into the frame buffers, using the
 * native PSP resolution.
 * Menu background uses native resolution and is copied and shaded from a frame
 * buffer, or read in from a file if no emulator screen output is present.
 */

/* System level intialization */
int plat_target_init(void)
{
	psp_init();

	/* buffer resolutions */
	g_menuscreen_w = 480, g_menuscreen_h  = 272, g_menuscreen_pp = 512;
	g_screen_width = 328, g_screen_height = 256, g_screen_ppitch = 512;
	g_menubg_src_w = 480, g_menubg_src_h  = 272, g_menubg_src_pp = 512;

	/* buffer settings for menu display on startup */
	g_screen_ptr = VRAM_CACHED_STUFF + (psp_screen - VRAM_FB0);
	g_menuscreen_ptr = psp_screen;
	g_menubg_ptr = malloc(512*272*2);

	return 0;
}

/* System level deinitialization */
void plat_target_finish(void)
{
	psp_finish();
}

/* display a completed frame buffer and prepare a new render buffer */
void plat_video_flip(void)
{
	unsigned long offs;

	g_menubg_src_ptr = psp_screen;

	sceGuSync(0, 0); // sync with prev
	psp_video_flip(currentConfig.EmuOpt & EOPT_VSYNC);
	offs = (unsigned long)psp_screen - VRAM_ADDR; // back buffer offset

	sceGuStart(GU_DIRECT, guCmdList);
	sceGuDrawBuffer(GU_PSM_5650, (void *)offs, 512);
	sceGuClearColor(0);
	sceGuClearDepth(0);
	sceGuClear(GU_COLOR_BUFFER_BIT | GU_DEPTH_BUFFER_BIT);

	blitscreen_clut();

	sceGuFinish();

	g_screen_ptr = VRAM_CACHED_STUFF + offs;
	plat_video_set_buffer(g_screen_ptr);
}

/* wait for start of vertical blanking */
void plat_video_wait_vsync(void)
{
	sceDisplayWaitVblankStart();
}

/* update surface data */
void plat_video_menu_update(void)
{
	// surface is always the screen
}

/* switch from emulation display to menu display */
void plat_video_menu_enter(int is_rom_loaded)
{
}

/* start rendering a menu screen */
void plat_video_menu_begin(void)
{
	g_menuscreen_ptr = psp_screen;
}

/* display a completed menu screen */
void plat_video_menu_end(void)
{
	g_menuscreen_ptr = NULL;
	psp_video_flip(1);
}

/* terminate menu display */
void plat_video_menu_leave(void)
{
	g_screen_ptr = VRAM_CACHED_STUFF + (psp_screen - VRAM_FB0);
	plat_video_set_buffer(g_screen_ptr);
}

/* check arg at index x */
int plat_parse_arg(int argc, char *argv[], int *x)
{
	return 1;
}

/* Preliminary initialization needed at program start */
void plat_early_init(void)
{
}

/* base directory for configuration and save files */
int plat_get_root_dir(char *dst, int len)
{
 	if (len > 0) *dst = 0;
	return 0;
}

/* base directory for emulator resources */
int plat_get_skin_dir(char *dst, int len)
{
	if (len > 5)
		strcpy(dst, "skin/");
	else if (len > 0)
		*dst = 0;
	return strlen(dst);
}

/* top directory for rom images */
int plat_get_data_dir(char *dst, int len)
{
	if (len > 5)
		strcpy(dst, "ms0:/");
	else if (len > 0)
		*dst = 0;
	return strlen(dst);
}

/* check if path is a directory */
int plat_is_dir(const char *path)
{
	DIR *dir;
	if ((dir = opendir(path))) {
		closedir(dir);
		return 1;
	}
	return 0;
}

/* current time in ms */
unsigned int plat_get_ticks_ms(void)
{
	return clock() / 1000;
}

/* current time in us */
unsigned int plat_get_ticks_us(void)
{
	return clock();
}

/* sleep for some time in ms */
void plat_sleep_ms(int ms)
{
	usleep(ms * 1000);
}

/* sleep for some time in us */
void plat_wait_till_us(unsigned int us_to)
{
	unsigned int ticks = clock();
	if (us_to > ticks)
		usleep(us_to - ticks);
}

/* wait until some event occurs, or timeout */
int plat_wait_event(int *fds_hnds, int count, int timeout_ms)
{
	return 0;	// unused
}

/* memory mapping functions */
void *plat_mmap(unsigned long addr, size_t size, int need_exec, int is_fixed)
{
	return malloc(size);
}

void *plat_mremap(void *ptr, size_t oldsize, size_t newsize)
{
	return realloc(ptr, newsize);
}

void plat_munmap(void *ptr, size_t size)
{
	free(ptr);
}

void *plat_mem_get_for_drc(size_t size)
{
	return NULL;
}

int plat_mem_set_exec(void *ptr, size_t size)
{
	return 0;
}

/* get current CPU clock */
static int plat_cpu_clock_get(void)
{
	return scePowerGetCpuClockFrequencyInt();
}

/* set CPU clock */
static int plat_cpu_clock_set(int clock)
{
	if (clock < 33) clock = 33;
	if (clock > 333) clock = 333;

	return scePowerSetClockFrequency(clock, clock, clock/2);
}

/* get battery state in percent */
static int plat_bat_capacity_get(void)
{
	return scePowerGetBatteryLifePercent();
}

static int sound_rates[] = { 11025, 22050, 44100, -1 };
struct plat_target plat_target = {
	.cpu_clock_get = plat_cpu_clock_get,
	.cpu_clock_set = plat_cpu_clock_set,
	.bat_capacity_get = plat_bat_capacity_get,
//	.gamma_set = plat_gamma_set,
//	.hwfilter_set = plat_hwfilter_set,
//	.hwfilters = plat_hwfilters,
	.sound_rates = sound_rates,
};

int _flush_cache (char *addr, const int size, const int op)
{
	//sceKernelDcacheWritebackAll();
	sceKernelDcacheWritebackRange(addr, size);
	sceKernelIcacheInvalidateRange(addr, size);
	return 0;
}

int posix_memalign(void **p, size_t align, size_t size)
{
	if (p)
		*p = memalign(align, size);
	return (p ? *p ? 0 : ENOMEM : EINVAL);
}
