#ifndef LIBPICOFE_PLAT_H
#define LIBPICOFE_PLAT_H

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* target device, everything is optional */
struct plat_target {
	int (*cpu_clock_get)(void);
	int (*cpu_clock_set)(int clock);
	int (*bat_capacity_get)(void);
	int (*hwfilter_set)(int which);
	int (*lcdrate_set)(int is_pal);
	int (*gamma_set)(int val, int black_level);
	int (*step_volume)(int *volume, int diff);
	int (*switch_layer)(int which, int enable);
	const char **vout_methods;
	int vout_method;
	int vout_fullscreen;
	const char **hwfilters;
	int hwfilter;
};

extern struct plat_target plat_target;
int  plat_target_init(void);
void plat_target_finish(void);
void plat_target_setup_input(void);

/* CPU clock in MHz */
static __inline int plat_target_cpu_clock_get(void)
{
	if (plat_target.cpu_clock_get)
		return plat_target.cpu_clock_get();
	return -1;
}

static __inline int plat_target_cpu_clock_set(int mhz)
{
	if (plat_target.cpu_clock_set)
		return plat_target.cpu_clock_set(mhz);
	return -1;
}

/* battery capacity (0-100) */
static __inline int plat_target_bat_capacity_get(void)
{
	if (plat_target.bat_capacity_get)
		return plat_target.bat_capacity_get();
	return -1;
}

/* set some hardware-specific video filter, 0 for none */
static __inline int plat_target_hwfilter_set(int which)
{
	if (plat_target.hwfilter_set)
		return plat_target.hwfilter_set(which);
	return -1;
}

/* set device LCD rate, is_pal 0 for NTSC, 1 for PAL compatible */
static __inline int plat_target_lcdrate_set(int is_pal)
{
	if (plat_target.lcdrate_set)
		return plat_target.lcdrate_set(is_pal);
	return -1;
}

/* set device LCD rate, is_pal 0 for NTSC, 1 for PAL compatible */
static __inline int plat_target_gamma_set(int val, int black_level)
{
	if (plat_target.gamma_set)
		return plat_target.gamma_set(val, black_level);
	return -1;
}

/* step sound volume up or down */
static __inline int plat_target_step_volume(int *volume, int diff)
{
	if (plat_target.step_volume)
		return plat_target.step_volume(volume, diff);
	return -1;
}

/* switch device graphics layers/overlays */
static __inline int plat_target_switch_layer(int which, int enable)
{
	if (plat_target.switch_layer)
		return plat_target.switch_layer(which, enable);
	return -1;
}

/* menu: enter (switch bpp, etc), begin/end drawing */
void plat_video_menu_enter(int is_rom_loaded);
void plat_video_menu_begin(void);
void plat_video_menu_end(void);
void plat_video_menu_leave(void);

void plat_video_flip(void);
void plat_video_wait_vsync(void);

/* return the dir/ where configs, saves, bios, etc. are found */
int  plat_get_root_dir(char *dst, int len);

/* return the dir/ where skin files are found */
int  plat_get_skin_dir(char *dst, int len);

int  plat_is_dir(const char *path);
int  plat_wait_event(int *fds_hnds, int count, int timeout_ms);
void plat_sleep_ms(int ms);

void *plat_mmap(unsigned long addr, size_t size, int need_exec, int is_fixed);
void *plat_mremap(void *ptr, size_t oldsize, size_t newsize);
void  plat_munmap(void *ptr, size_t size);
int   plat_mem_set_exec(void *ptr, size_t size);

/* timers, to be used for time diff and must refer to the same clock */
unsigned int plat_get_ticks_ms(void);
unsigned int plat_get_ticks_us(void);
void plat_wait_till_us(unsigned int us);

void plat_debug_cat(char *str);

#ifdef __cplusplus
} // extern "C"
#endif

#endif /* LIBPICOFE_PLAT_H */
