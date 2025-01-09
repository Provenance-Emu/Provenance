/*
 * (C) Gražvydas "notaz" Ignotas, 2009-2010
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 *
 * <random_info=mem_map>
 * 00000000-029fffff linux (42MB)
 * 02a00000-02dfffff fb (4MB, 153600B really used)
 * 02e00000-02ffffff sound dma (2MB)
 * 03000000-03ffffff MPEGDEC (?, 16MB)
 * </random_info>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/soundcard.h>

#include "soc.h"
#include "plat_gp2x.h"
#include "pollux_set.h"
#include "../plat.h"

static int battdev = -1, mixerdev = -1;
static int cpu_clock_allowed;
static unsigned short saved_memtimex[2];
static unsigned int saved_video_regs[2][6];
static unsigned int timer_drift; // count per real second

#ifndef ARRAY_SIZE
#define ARRAY_SIZE(x) (sizeof(x) / sizeof(x[0]))
#endif

/* note: both PLLs are programmed the same way,
 * the databook incorrectly states that PLL1 differs */
static int decode_pll(unsigned int reg)
{
	long long v;
	int p, m, s;

	p = (reg >> 18) & 0x3f;
	m = (reg >> 8) & 0x3ff;
	s = reg & 0xff;

	if (p == 0)
		p = 1;

	v = 27000000; // master clock
	v = v * m / (p << s);
	return v;
}

/* RAM timings */
static void set_ram_timings(void)
{
	pollux_set_fromenv(memregs, "POLLUX_RAM_TIMINGS");
}

static void unset_ram_timings(void)
{
	int i;

	memregs[0x14802>>1] = saved_memtimex[0];
	memregs[0x14804>>1] = saved_memtimex[1] | 0x8000;

	for (i = 0; i < 0x100000; i++)
		if (!(memregs[0x14804>>1] & 0x8000))
			break;

	printf("RAM timings reset to startup values.\n");
}

#define TIMER_BASE3 0x1980
#define TIMER_REG(x) memregl[(TIMER_BASE3 + x) >> 2]

static unsigned int gp2x_get_ticks_us_(void)
{
	unsigned int div = TIMER_REG(0x08) & 3;
	TIMER_REG(0x08) = 0x48 | div;  /* run timer, latch value */
	return TIMER_REG(0);
}

static unsigned int gp2x_get_ticks_ms_(void)
{
	/* approximate /= 1000 */
	unsigned long long v64;
	v64 = (unsigned long long)gp2x_get_ticks_us_() * 4294968;
	return v64 >> 32;
}

static void timer_cleanup(void)
{
	TIMER_REG(0x40) = 0x0c;	/* be sure clocks are on */
	TIMER_REG(0x08) = 0x23;	/* stop the timer, clear irq in case it's pending */
	TIMER_REG(0x00) = 0;	/* clear counter */
	TIMER_REG(0x40) = 0;	/* clocks off */
	TIMER_REG(0x44) = 0;	/* dividers back to default */
}

static void save_multiple_regs(unsigned int *dest, int base, int count)
{
	const volatile unsigned int *regs = memregl + base / 4;
	int i;

	for (i = 0; i < count; i++)
		dest[i] = regs[i];
}

static void restore_multiple_regs(int base, const unsigned int *src, int count)
{
	volatile unsigned int *regs = memregl + base / 4;
	int i;

	for (i = 0; i < count; i++)
		regs[i] = src[i];
}

int pollux_get_real_snd_rate(int req_rate)
{
	int clk0_src, clk1_src, rate, div;

	clk0_src = (memregl[0xdbc4>>2] >> 1) & 7;
	clk1_src = (memregl[0xdbc8>>2] >> 1) & 7;
	if (clk0_src > 1 || clk1_src != 7) {
		fprintf(stderr, "get_real_snd_rate: bad clk sources: %d %d\n", clk0_src, clk1_src);
		return req_rate;
	}

	rate = decode_pll(clk0_src ? memregl[0xf008>>2] : memregl[0xf004>>2]);

	// apply divisors
	div = ((memregl[0xdbc4>>2] >> 4) & 0x3f) + 1;
	rate /= div;
	div = ((memregl[0xdbc8>>2] >> 4) & 0x3f) + 1;
	rate /= div;
	rate /= 64;

	//printf("rate %d\n", rate);
	rate -= rate * timer_drift / 1000000;
	printf("adjusted rate: %d\n", rate);

	if (rate < 8000-1000 || rate > 44100+1000) {
		fprintf(stderr, "get_real_snd_rate: got bad rate: %d\n", rate);
		return req_rate;
	}

	return rate;
}

/* newer API */
static int pollux_cpu_clock_get(void)
{
	return decode_pll(memregl[0xf004>>2]) / 1000000;
}

int pollux_cpu_clock_set(int mhz)
{
	int adiv, mdiv, pdiv, sdiv = 0;
	int i, vf000, vf004;

	if (!cpu_clock_allowed)
		return -1;
	if (mhz == pollux_cpu_clock_get())
		return 0;

	// m = MDIV, p = PDIV, s = SDIV
	#define SYS_CLK_FREQ 27
	pdiv = 9;
	mdiv = (mhz * pdiv) / SYS_CLK_FREQ;
	if (mdiv & ~0x3ff)
		return -1;
	vf004 = (pdiv<<18) | (mdiv<<8) | sdiv;

	// attempt to keep the AHB divider close to 250, but not higher
	for (adiv = 1; mhz / adiv > 250; adiv++)
		;

	vf000 = memregl[0xf000>>2];
	vf000 = (vf000 & ~0x3c0) | ((adiv - 1) << 6);
	memregl[0xf000>>2] = vf000;
	memregl[0xf004>>2] = vf004;
	memregl[0xf07c>>2] |= 0x8000;
	for (i = 0; (memregl[0xf07c>>2] & 0x8000) && i < 0x100000; i++)
		;

	printf("clock set to %dMHz, AHB set to %dMHz\n", mhz, mhz / adiv);
	return 0;
}

static int pollux_bat_capacity_get(void)
{
	unsigned short magic_val = 0;

	if (battdev < 0)
		return -1;
	if (read(battdev, &magic_val, sizeof(magic_val)) != sizeof(magic_val))
		return -1;
	switch (magic_val) {
	default:
	case 1:	return 100;
	case 2: return 66;
	case 3: return 40;
	case 4: return 0;
	}
}

static int step_volume(int *volume, int diff)
{
	int ret, val;

	if (mixerdev < 0)
		return -1;

	*volume += diff;
	if (*volume > 255)
		*volume = 255;
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

void pollux_init(void)
{
	int rate, timer_div, timer_div2;

	memdev = open("/dev/mem", O_RDWR);
	if (memdev == -1) {
		perror("open(/dev/mem) failed");
		exit(1);
	}

	memregs	= mmap(0, 0x20000, PROT_READ|PROT_WRITE, MAP_SHARED,
		memdev, 0xc0000000);
	if (memregs == MAP_FAILED) {
		perror("mmap(memregs) failed");
		exit(1);
	}
	memregl = (volatile void *)memregs;

	saved_memtimex[0] = memregs[0x14802>>1];
	saved_memtimex[1] = memregs[0x14804>>1];

	set_ram_timings();

	// save video regs of both MLCs
	save_multiple_regs(saved_video_regs[0], 0x4058, ARRAY_SIZE(saved_video_regs[0]));
	save_multiple_regs(saved_video_regs[1], 0x4458, ARRAY_SIZE(saved_video_regs[1]));

	/* some firmwares have sys clk on PLL0, we can't adjust CPU clock
	 * by reprogramming the PLL0 then, as it overclocks system bus */
	if ((memregl[0xf000>>2] & 0x03000030) == 0x01000000)
		cpu_clock_allowed = 1;
	else {
		cpu_clock_allowed = 0;
		fprintf(stderr, "unexpected PLL config (%08x), overclocking disabled\n",
			memregl[0xf000>>2]);
	}

	/* find what PLL1 runs at, for the timer */
	rate = decode_pll(memregl[0xf008>>2]);
	printf("PLL1 @ %dHz\n", rate);

	/* setup timer */
	timer_div = (rate + 500000) / 1000000;
	timer_div2 = 0;
	while (timer_div > 256) {
		timer_div /= 2;
		timer_div2++;
	}
	if (1 <= timer_div && timer_div <= 256 && timer_div2 < 4) {
		int timer_rate = (rate >> timer_div2) / timer_div;
		if (TIMER_REG(0x08) & 8) {
			fprintf(stderr, "warning: timer in use, overriding!\n");
			timer_cleanup();
		}
		timer_drift = timer_rate - 1000000;
		if (timer_drift != 0)
			fprintf(stderr, "warning: timer drift %d us\n",
				timer_drift);

		timer_div2 = (timer_div2 + 3) & 3;
		TIMER_REG(0x44) = ((timer_div - 1) << 4) | 2;	/* using PLL1 */
		TIMER_REG(0x40) = 0x0c;				/* clocks on */
		TIMER_REG(0x08) = 0x68 | timer_div2;		/* run timer, clear irq, latch value */

		gp2x_get_ticks_ms = gp2x_get_ticks_ms_;
		gp2x_get_ticks_us = gp2x_get_ticks_us_;
	}
	else {
		fprintf(stderr, "warning: could not make use of timer\n");

		// those functions are actually not good at all on Wiz kernel
		gp2x_get_ticks_ms = plat_get_ticks_ms_good;
		gp2x_get_ticks_us = plat_get_ticks_us_good;
	}

	battdev = open("/dev/pollux_batt", O_RDONLY);
	if (battdev < 0)
		perror("Warning: could't open pollux_batt");

	mixerdev = open("/dev/mixer", O_RDWR);
	if (mixerdev == -1)
		perror("open(/dev/mixer)");

	plat_target.cpu_clock_get = pollux_cpu_clock_get;
	plat_target.cpu_clock_set = pollux_cpu_clock_set;
	plat_target.bat_capacity_get = pollux_bat_capacity_get;
	plat_target.step_volume = step_volume;
}

void pollux_finish(void)
{
	timer_cleanup();

	unset_ram_timings();

	restore_multiple_regs(0x4058, saved_video_regs[0],
		ARRAY_SIZE(saved_video_regs[0]));
	restore_multiple_regs(0x4458, saved_video_regs[1],
		ARRAY_SIZE(saved_video_regs[1]));
	memregl[0x4058>>2] |= 0x10;
	memregl[0x4458>>2] |= 0x10;

	if (battdev >= 0)
		close(battdev);
	if (mixerdev >= 0)
		close(mixerdev);
	munmap((void *)memregs, 0x20000);
	close(memdev);
}
