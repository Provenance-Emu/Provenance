/*
 * PicoDrive platform interface for PS2
 *
 * (C) fjtrujy,irixxxx 2024
 */

#include <stdio.h>
#include <stdarg.h>
#include <sys/types.h>
#include <dirent.h>
#include <unistd.h>
#include <string.h>
#include <sys/time.h>
#include <stdlib.h>
#include <malloc.h>
#include <errno.h>

#include <kernel.h>
#include <iopcontrol.h>
#include <sbv_patches.h>
#include <sifrpc.h>
#include <loadfile.h>
#include <ps2_filesystem_driver.h>
#include <ps2_joystick_driver.h>
#include <ps2_audio_driver.h>

#include "../libpicofe/plat.h"

static int sound_rates[] = { 11025, 22050, 44100, -1 };
struct plat_target plat_target = { .sound_rates = sound_rates };

static void reset_IOP() {
    SifInitRpc(0);
#if !defined(DEBUG) || defined(BUILD_FOR_PCSX2)
    /* Comment this line if you don't wanna debug the output */
    while (!SifIopReset(NULL, 0)) {};
#endif

    while (!SifIopSync()) {};
    SifInitRpc(0);
    sbv_patch_enable_lmb();
    sbv_patch_disable_prefix_check();
}

static void init_drivers() {
    init_ps2_filesystem_driver();
}

static void deinit_drivers() {
    deinit_ps2_filesystem_driver();
}

int  plat_target_init(void)
{ 
    return 0; 
}

/* System level deinitialization */
void plat_target_finish(void)
{
    deinit_drivers();
}

int plat_parse_arg(int argc, char *argv[], int *x)
{ 
    return 1; 
}

/* Preliminary initialization needed at program start */
void plat_early_init(void) {
    reset_IOP();
    init_drivers();
#if defined(LOG_TO_FILE)
	log_init();
#endif
}

/* base directory for configuration and save files */
int plat_get_root_dir(char *dst, int len)
{
 	getcwd(dst, len);
    // We need to append / at the end
    strcat(dst, "/");
    return strlen(dst);
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
    getcwd(dst, len);
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

/* sleep for some time in us */
void plat_wait_till_us(unsigned int us_to)
{
	unsigned int ticks = clock();
	if (us_to > ticks)
		usleep(us_to - ticks);
}

/* sleep for some time in ms */
void plat_sleep_ms(int ms)
{
	usleep(ms * 1000);
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

int _flush_cache (char *addr, const int size, const int op)
{ 
    FlushCache(WRITEBACK_DCACHE); /* WRITEBACK_DCACHE */
    FlushCache(INVALIDATE_ICACHE); /* INVALIDATE_ICACHE */
    return 0;
}

int posix_memalign(void **p, size_t align, size_t size)
{
	if (p)
		*p = memalign(align, size);
	return (p ? *p ? 0 : ENOMEM : EINVAL);
}

/* lprintf */
void lprintf(const char *fmt, ...)
{
	va_list vl;

	va_start(vl, fmt);
#if defined(LOG_TO_FILE)
	vfprintf(logFile, fmt, vl);
#else
	vprintf(fmt, vl);
#endif
	va_end(vl);
}

void plat_debug_cat(char *str) {}
