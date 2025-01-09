/*
 * (C) Gražvydas "notaz" Ignotas, 2006-2012
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <linux/soundcard.h>

#include "soc.h"
#include "soc_mmsp2.h"
#include "plat_gp2x.h"
#include "../linux/sndout_oss.h"
#include "../plat.h"

static int mixerdev = -1;
static int touchdev = -1;
static int touchcal[7] = { 6203, 0, -1501397, 0, -4200, 16132680, 65536 };

static char gamma_was_changed = 0;
static char cpuclk_was_changed = 0;
static unsigned short memtimex_old[2];
static unsigned short reg0910;

/* 940 */
void pause940(int yes)
{
	if (yes)
		memregs[0x0904>>1] &= 0xFFFE;
	else
		memregs[0x0904>>1] |= 1;
}

void reset940(int yes, int bank)
{
	memregs[0x3B48>>1] = ((yes&1) << 7) | (bank & 0x03);
}

/*
 * CPU clock
 * Fout = (m * Fin) / (p * 2^s)
 * m = MDIV+8, p = PDIV+2, s = SDIV
 *
 * m = (Fout * p * 2^s) / Fin
 */

#define SYS_CLK_FREQ 7372800

static int cpu_current_mhz = 200;

static int mmsp2_clock_get(void)
{
	// TODO: read the actual value?
	return cpu_current_mhz;
}

static int mmsp2_clock_set(int mhz)
{
	unsigned int mdiv, pdiv, sdiv = 0;
	unsigned int v;
	int i;

	pdiv = 3;
	mdiv = (mhz * pdiv * 1000000) / SYS_CLK_FREQ;
	if (mdiv & ~0xff) {
		fprintf(stderr, "invalid cpuclk MHz: %u\n", mhz);
		return -1;
	}
	v = ((mdiv-8)<<8) | ((pdiv-2)<<2) | sdiv;
	memregs[0x910>>1] = v;

	for (i = 0; i < 10000; i++)
		if (!(memregs[0x902>>1] & 1))
			break;

	cpuclk_was_changed = 1;
	cpu_current_mhz = mhz;
	return 0;
}

/* RAM timings */
#define TIMING_CHECK(t, adj, mask) \
	t += adj; \
	if (t & ~mask) \
		goto bad

static __attribute__((noinline)) void spend_cycles(int c)
{
	asm volatile(
		"0: subs %0, %0, #1 ;"
		"bgt 0b"
		: "=r" (c) : "0" (c) : "cc");
}

static void set_ram_timing_vals(int tCAS, int tRC, int tRAS, int tWR, int tMRD, int tRFC, int tRP, int tRCD)
{
	int i;
	TIMING_CHECK(tCAS, -2, 0x1);
	TIMING_CHECK(tRC,  -1, 0xf);
	TIMING_CHECK(tRAS, -1, 0xf);
	TIMING_CHECK(tWR,  -1, 0xf);
	TIMING_CHECK(tMRD, -1, 0xf);
	TIMING_CHECK(tRFC, -1, 0xf);
	TIMING_CHECK(tRP,  -1, 0xf);
	TIMING_CHECK(tRCD, -1, 0xf);

	/* get spend_cycles() into cache */
	spend_cycles(1);

	memregs[0x3802>>1] = ((tMRD & 0xF) << 12) | ((tRFC & 0xF) << 8) | ((tRP & 0xF) << 4) | (tRCD & 0xF);
	memregs[0x3804>>1] = 0x8000 | ((tCAS & 1) << 12) | ((tRC & 0xF) << 8) | ((tRAS & 0xF) << 4) | (tWR & 0xF);

	/* be sure we don't access the mem while it's being reprogrammed */
	spend_cycles(128*1024);
	for (i = 0; i < 8*1024; i++)
		if (!(memregs[0x3804>>1] & 0x8000))
			break;

	printf("RAM timings set.\n");
	return;
bad:
	fprintf(stderr, "RAM timings invalid.\n");
}

static void set_ram_timings_(void)
{
	/* craigix: --cas 2 --trc 6 --tras 4 --twr 1 --tmrd 1 --trfc 1 --trp 2 --trcd 2 */
	set_ram_timing_vals(2, 6, 4, 1, 1, 1, 2, 2);
}

static void unset_ram_timings_(void)
{
	memregs[0x3802>>1] = memtimex_old[0];
	memregs[0x3804>>1] = memtimex_old[1] | 0x8000;
	printf("RAM timings reset to startup values.\n");
}

/* LCD refresh */
typedef struct
{
	unsigned short reg, valmask, val;
}
reg_setting;

/* 120.00 97/0/2/7|25/ 7/ 7/11/37 */
static const reg_setting lcd_rate_120[] =
{
	{ 0x0914, 0xffff, (97<<8)|(0<<2)|2 },	/* UPLLSETVREG */
	{ 0x0924, 0xff00, (2<<14)|(7<<8) },	/* DISPCSETREG */
	{ 0x281A, 0x00ff, 25 },			/* .HSWID(T2) */
	{ 0x281C, 0x00ff, 7 },			/* .HSSTR(T8) */
	{ 0x281E, 0x00ff, 7 },			/* .HSEND(T7) */
	{ 0x2822, 0x01ff, 11 },			/* .VSEND (T9) */
	{ 0x2826, 0x0ff0, 37<<4 },		/* .DESTR(T3) */
	{ 0, 0, 0 }
};

/* 100.00 96/0/2/7|29/25/53/15/37 */
static const reg_setting lcd_rate_100[] =
{
	{ 0x0914, 0xffff, (96<<8)|(0<<2)|2 },	/* UPLLSETVREG */
	{ 0x0924, 0xff00, (2<<14)|(7<<8) },	/* DISPCSETREG */
	{ 0x281A, 0x00ff, 29 },			/* .HSWID(T2) */
	{ 0x281C, 0x00ff, 25 },			/* .HSSTR(T8) */
	{ 0x281E, 0x00ff, 53 },			/* .HSEND(T7) */
	{ 0x2822, 0x01ff, 15 },			/* .VSEND (T9) */
	{ 0x2826, 0x0ff0, 37<<4 },		/* .DESTR(T3) */
	{ 0, 0, 0 }
};

static reg_setting lcd_rate_defaults[] =
{
	{ 0x0914, 0xffff, 0 },
	{ 0x0924, 0xff00, 0 },
	{ 0x281A, 0x00ff, 0 },
	{ 0x281C, 0x00ff, 0 },
	{ 0x281E, 0x00ff, 0 },
	{ 0x2822, 0x01ff, 0 },
	{ 0x2826, 0x0ff0, 0 },
	{ 0, 0, 0 }
};

static void get_reg_setting(reg_setting *set)
{
	for (; set->reg; set++)
	{
		unsigned short val = memregs[set->reg >> 1];
		val &= set->valmask;
		set->val = val;
	}
}

static void set_reg_setting(const reg_setting *set)
{
	for (; set->reg; set++)
	{
		unsigned short val = memregs[set->reg >> 1];
		val &= ~set->valmask;
		val |= set->val;
		memregs[set->reg >> 1] = val;
	}
}

static int mmsp2_lcdrate_set(int is_pal)
{
	if (memregs[0x2800>>1] & 0x100) // tv-out
		return 0;

	printf("setting custom LCD refresh (%d Hz)... ", is_pal ? 100 : 120);
	fflush(stdout);

	set_reg_setting(is_pal ? lcd_rate_100 : lcd_rate_120);
	printf("done.\n");
	return 0;
}

static void unset_lcd_custom_rate_(void)
{
	printf("reset to prev LCD refresh.\n");
	set_reg_setting(lcd_rate_defaults);
}

static void set_lcd_gamma_(int g100, int A_SNs_curve)
{
	float gamma = (float) g100 / 100.0f;
	int i;
	gamma = 1 / gamma;

	if (g100 == 100)
		A_SNs_curve = 0;

	/* enable gamma */
	memregs[0x2880>>1] &= ~(1<<12);

	memregs[0x295C>>1] = 0;
	for (i = 0; i < 256; i++)
	{
		unsigned char g;
		unsigned short s;
		const unsigned short grey50=143, grey75=177, grey25=97;
		double blah;

		if (A_SNs_curve)
		{
			// The next formula is all about gaussian interpolation
			blah = ((  -128 * exp(-powf((float) i/64.0f + 2.0f , 2.0f))) +
				(   -64 * exp(-powf((float) i/64.0f + 1.0f , 2.0f))) +
				(grey25 * exp(-powf((float) i/64.0f - 1.0f , 2.0f))) +
				(grey50 * exp(-powf((float) i/64.0f - 2.0f , 2.0f))) +
				(grey75 * exp(-powf((float) i/64.0f - 3.0f , 2.0f))) +
				(   256 * exp(-powf((float) i/64.0f - 4.0f , 2.0f))) +
				(   320 * exp(-powf((float) i/64.0f - 5.0f , 2.0f))) +
				(   384 * exp(-powf((float) i/64.0f - 6.0f , 2.0f)))) / 1.772637;
			blah += 0.5;
		}
		else
		{
			blah = (double)i;
		}

		g = (unsigned char)(255.0 * pow(blah/255.0, gamma));
		//printf("%d : %d\n", i, g);
		s = (g<<8) | g;
		memregs[0x295E>>1]= s;
		memregs[0x295E>>1]= g;
	}

	gamma_was_changed = 1;
}

static int mmsp2_gamma_set(int val, int black_level)
{
	set_lcd_gamma_(val, 1);
	return 0;
}

/* these are not quite MMSP2 related,
 * more to GP2X F100/F200 consoles themselves. */
typedef struct ucb1x00_ts_event
{
	unsigned short pressure;
	unsigned short x;
	unsigned short y;
	unsigned short pad;
	struct timeval stamp;
} UCB1X00_TS_EVENT;

int gp2x_touchpad_read(int *x, int *y)
{
	UCB1X00_TS_EVENT event;
	static int zero_seen = 0;
	int retval;

	if (touchdev < 0) return -1;

	retval = read(touchdev, &event, sizeof(event));
	if (retval <= 0) {
		perror("touch read failed");
		return -1;
	}
	// this is to ignore the messed-up 4.1.x driver
	if (event.pressure == 0) zero_seen = 1;

	if (x) *x = (event.x * touchcal[0] + touchcal[2]) >> 16;
	if (y) *y = (event.y * touchcal[4] + touchcal[5]) >> 16;
	// printf("read %i %i %i\n", event.pressure, *x, *y);

	return zero_seen ? event.pressure : 0;
}

static void proc_set(const char *path, const char *val)
{
	FILE *f;
	char tmp[16];

	f = fopen(path, "w");
	if (f == NULL) {
		printf("failed to open: %s\n", path);
		return;
	}

	fprintf(f, "0\n");
	fclose(f);

	printf("\"%s\" is set to: ", path);
	f = fopen(path, "r");
	if (f == NULL) {
		printf("(open failed)\n");
		return;
	}

	fgets(tmp, sizeof(tmp), f);
	printf("%s", tmp);
	fclose(f);
}

static int step_volume(int *volume, int diff)
{
	int ret, val;

	if (mixerdev < 0)
		return -1;

	*volume += diff;
	if (*volume >= 100)
		*volume = 100;
	else if (*volume < 0)
		*volume = 0;

	val = *volume;
	val |= val << 8;

 	ret = ioctl(mixerdev, SOUND_MIXER_WRITE_PCM, &val);
	if (ret == -1) {
		perror("WRITE_PCM");
		return ret;
	}

	return 0;
}

void mmsp2_init(void)
{
  	memdev = open("/dev/mem", O_RDWR);
	if (memdev == -1)
	{
		perror("open(\"/dev/mem\")");
		exit(1);
	}

	memregs = mmap(0, 0x10000, PROT_READ|PROT_WRITE, MAP_SHARED, memdev, 0xc0000000);
	if (memregs == MAP_FAILED)
	{
		perror("mmap(memregs)");
		exit(1);
	}
	memregl = (volatile unsigned int *) memregs;

	memregs[0x2880>>1] &= ~0x383; // disable cursor, subpict, osd, video layers

	/* save startup values: LCD refresh */
	get_reg_setting(lcd_rate_defaults);

	/* CPU and RAM timings */
	reg0910 = memregs[0x0910>>1];
	memtimex_old[0] = memregs[0x3802>>1];
	memtimex_old[1] = memregs[0x3804>>1];

	/* touchscreen */
	touchdev = open("/dev/touchscreen/wm97xx", O_RDONLY);
	if (touchdev >= 0) {
		FILE *pcf = fopen("/etc/pointercal", "r");
		if (pcf) {
			fscanf(pcf, "%d %d %d %d %d %d %d", &touchcal[0], &touchcal[1],
				&touchcal[2], &touchcal[3], &touchcal[4], &touchcal[5], &touchcal[6]);
			fclose(pcf);
		}
		printf("found touchscreen/wm97xx\n");
	}

	/* disable Linux read-ahead */
	proc_set("/proc/sys/vm/max-readahead", "0\n");
	proc_set("/proc/sys/vm/min-readahead", "0\n");

	mixerdev = open("/dev/mixer", O_RDWR);
	if (mixerdev == -1)
		perror("open(/dev/mixer)");

	set_ram_timings_();

	plat_target.cpu_clock_get = mmsp2_clock_get;
	plat_target.cpu_clock_set = mmsp2_clock_set;
	plat_target.lcdrate_set = mmsp2_lcdrate_set;
	plat_target.gamma_set = mmsp2_gamma_set;
	plat_target.step_volume = step_volume;

	gp2x_get_ticks_ms = plat_get_ticks_ms_good;
	gp2x_get_ticks_us = plat_get_ticks_us_good;

	sndout_oss_can_restart = 0;
}

void mmsp2_finish(void)
{
	reset940(1, 3);
	pause940(1);

	unset_lcd_custom_rate_();
	if (gamma_was_changed)
		set_lcd_gamma_(100, 0);
	unset_ram_timings_();
	if (cpuclk_was_changed)
		memregs[0x910>>1] = reg0910;

	munmap((void *)memregs, 0x10000);
	close(memdev);
	if (touchdev >= 0)
		close(touchdev);
	if (mixerdev >= 0)
		close(mixerdev);
}
