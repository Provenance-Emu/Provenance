/*
 * quick tool to set various timings for Wiz
 *
 * Copyright (c) Gražvydas "notaz" Ignotas, 2009
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the organization nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * HTOTAL:    X VTOTAL:  341
 * HSWIDTH:   1 VSWIDTH:   0
 * HASTART:  37 VASTART:  17
 * HAEND:   277 VAEND:   337
 *
 * 120Hz
 * pcd  8, 447: + 594us
 * pcd  9, 397: +  36us
 * pcd 10, 357: - 523us
 * pcd 11, 325: +1153us
 *
 * 'lcd_timings=397,1,37,277,341,0,17,337;dpc_clkdiv0=9'
 * 'ram_timings=2,9,4,1,1,1,1'
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pollux_set.h"

/* parse stuff */
static int parse_lcd_timings(const char *str, void *data)
{
	int *lcd_timings = data;
	const char *p = str;
	int ret, c;
	ret = sscanf(str, "%d,%d,%d,%d,%d,%d,%d,%d",
			&lcd_timings[0], &lcd_timings[1], &lcd_timings[2], &lcd_timings[3],
			&lcd_timings[4], &lcd_timings[5], &lcd_timings[6], &lcd_timings[7]);
	if (ret != 8)
		return -1;
	/* skip seven commas */
	for (c = 0; c < 7 && *p != 0; p++)
		if (*p == ',')
			c++;
	if (c != 7)
		return -1;
	/* skip last number */
	while ('0' <= *p && *p <= '9')
		p++;

	return p - str;
}

static int parse_ram_timings(const char *str, void *data)
{
	int *ram_timings = data;
	const char *p = str;
	int ret, c;
	float cas;

	ret = sscanf(p, "%f,%d,%d,%d,%d,%d,%d",
			&cas, &ram_timings[1], &ram_timings[2], &ram_timings[3],
			&ram_timings[4], &ram_timings[5], &ram_timings[6]);
	if (ret != 7)
		return -1;
	if (cas == 2)
		ram_timings[0] = 1;
	else if (cas == 2.5)
		ram_timings[0] = 2;
	else if (cas == 3)
		ram_timings[0] = 3;
	else
		return -1;
	for (c = 0; c < 6 && *p != 0; p++)
		if (*p == ',')
			c++;
	if (c != 6)
		return -1;
	while ('0' <= *p && *p <= '9')
		p++;

	return p - str;
}

static int parse_decimal(const char *str, void *data)
{
	char *ep;

	*(int *)data = strtoul(str, &ep, 10);
	if (ep == str)
		return -1;

	return ep - str;
}

/* validate and apply stuff */
static int apply_lcd_timings(volatile unsigned short *memregs, void *data)
{
	int *lcd_timings = data;
	int i;

	for (i = 0; i < 8; i++) {
		if (lcd_timings[i] & ~0xffff) {
			fprintf(stderr, "pollux_set: invalid lcd timing %d: %d\n", i, lcd_timings[i]);
			return -1;
		}
	}

	for (i = 0; i < 8; i++)
		memregs[(0x307c>>1) + i] = lcd_timings[i];

	return 0;
}

static const struct {
	signed char adj;	/* how to adjust value passed by user */
	signed short min;	/* range of */
	signed short max;	/* allowed values (inclusive) */
}
ram_ranges[] = {
	{  0,  1,  3 },	/* cas (cl) */
	{ -2,  0, 15 },	/* trc */
	{ -2,  0, 15 },	/* tras */
	{  0,  0, 15 },	/* twr */
	{  0,  0, 15 },	/* tmrd */
	{  0,  0, 15 },	/* trp */
	{  0,  0, 15 },	/* trcd */
};

static int apply_ram_timings(volatile unsigned short *memregs, void *data)
{
	int *ram_timings = data;
	int i, val;

	for (i = 0; i < 7; i++)
	{
		ram_timings[i] += ram_ranges[i].adj;
		if (ram_timings[i] < ram_ranges[i].min || ram_timings[i] > ram_ranges[i].max) {
			fprintf(stderr, "pollux_set: invalid RAM timing %d\n", i);
			return -1;
		}
	}

	val = memregs[0x14802>>1] & 0x0f00;
	val |= (ram_timings[4] << 12) | (ram_timings[5] << 4) | ram_timings[6];
	memregs[0x14802>>1] = val;

	val = memregs[0x14804>>1] & 0x4000;
	val |= (ram_timings[0] << 12) | (ram_timings[1] << 8) |
		(ram_timings[2] << 4) | ram_timings[3];
	val |= 0x8000;
	memregs[0x14804>>1] = val;

	for (i = 0; i < 0x100000 && (memregs[0x14804>>1] & 0x8000); i++)
		;

	return 0;
}

static int apply_dpc_clkdiv0(volatile unsigned short *memregs, void *data)
{
	int pcd = *(int *)data;
	int tmp;

	if ((pcd - 1) & ~0x3f) {
		fprintf(stderr, "pollux_set: invalid lcd clkdiv0: %d\n", pcd);
		return -1;
	}

	pcd = (pcd - 1) & 0x3f;
	tmp = memregs[0x31c4>>1];
	memregs[0x31c4>>1] = (tmp & ~0x3f0) | (pcd << 4);

	return 0;
}

static int apply_cpuclk(volatile unsigned short *memregs, void *data)
{
	volatile unsigned int *memregl = (volatile void *)memregs;
	int mhz = *(int *)data;
	int adiv, mdiv, pdiv, sdiv = 0;
	int i, vf000, vf004;

	// m = MDIV, p = PDIV, s = SDIV
	#define SYS_CLK_FREQ 27
	pdiv = 9;
	mdiv = (mhz * pdiv) / SYS_CLK_FREQ;
	if (mdiv & ~0x3ff)
		return -1;
	vf004 = (pdiv<<18) | (mdiv<<8) | sdiv;

	// attempt to keep AHB the divider close to 250, but not higher
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

static int lcd_timings[8];
static int ram_timings[7];
static int dpc_clkdiv0;
static int cpuclk;

static const char lcd_t_help[] = "htotal,hswidth,hastart,haend,vtotal,vswidth,vastart,vaend";
static const char ram_t_help[] = "CAS,tRC,tRAS,tWR,tMRD,tRP,tRCD";

static const struct {
	const char *name;
	const char *help;
	int (*parse)(const char *str, void *data);
	int (*apply)(volatile unsigned short *memregs, void *data);
	void *data;
}
all_params[] = {
	{ "lcd_timings", lcd_t_help, parse_lcd_timings, apply_lcd_timings, lcd_timings  },
	{ "ram_timings", ram_t_help, parse_ram_timings, apply_ram_timings, ram_timings  },
	{ "dpc_clkdiv0", "divider",  parse_decimal,     apply_dpc_clkdiv0, &dpc_clkdiv0 },
	{ "clkdiv0",     "divider",  parse_decimal,     apply_dpc_clkdiv0, &dpc_clkdiv0 }, /* alias */
	{ "cpuclk",      "MHZ",      parse_decimal,     apply_cpuclk,      &cpuclk      },
};
#define ALL_PARAM_COUNT (sizeof(all_params) / sizeof(all_params[0]))

/*
 * set timings based on preformated string
 * returns 0 on success.
 */
int pollux_set(volatile unsigned short *memregs, const char *str)
{
	int parsed_params[ALL_PARAM_COUNT];
	int applied_params[ALL_PARAM_COUNT];
	int applied_something = 0;
	const char *p, *po;
	int i, ret;

	if (str == NULL)
		return -1;

	memset(parsed_params, 0, sizeof(parsed_params));
	memset(applied_params, 0, sizeof(applied_params));

	p = str;
	while (1)
	{
again:
		while (*p == ';' || *p == ' ')
			p++;
		if (*p == 0)
			break;

		for (i = 0; i < ALL_PARAM_COUNT; i++)
		{
			int param_len = strlen(all_params[i].name);
			if (strncmp(p, all_params[i].name, param_len) == 0 && p[param_len] == '=')
			{
				p += param_len + 1;
				ret = all_params[i].parse(p, all_params[i].data);
				if (ret < 0) {
					fprintf(stderr, "pollux_set parser: error at %-10s\n", p);
					fprintf(stderr, "  valid format is: <%s>\n", all_params[i].help);
					return -1;
				}
				parsed_params[i] = 1;
				p += ret;
				goto again;
			}
		}

		/* Unknown param. Attempt to be forward compatible and ignore it. */
		for (po = p; *p != 0 && *p != ';'; p++)
			;

		fprintf(stderr, "unhandled param: ");
		fwrite(po, 1, p - po, stderr);
		fprintf(stderr, "\n");
	}

	/* validate and apply */
	for (i = 0; i < ALL_PARAM_COUNT; i++)
	{
		if (!parsed_params[i])
			continue;

		ret = all_params[i].apply(memregs, all_params[i].data);
		if (ret < 0) {
			fprintf(stderr, "pollux_set: failed to apply %s (bad value?)\n",
				all_params[i].name);
			continue;
		}

		applied_something = 1;
		applied_params[i] = 1;
	}

	if (applied_something)
	{
		int c;
		printf("applied: ");
		for (i = c = 0; i < ALL_PARAM_COUNT; i++)
		{
			if (!applied_params[i])
				continue;
			if (c != 0)
				printf(", ");
			printf("%s", all_params[i].name);
			c++;
		}
		printf("\n");
	}

	return 0;
}

int pollux_set_fromenv(volatile unsigned short *memregs,
	const char *env_var)
{
	const char *set_string;
	int ret = -1;

	set_string = getenv(env_var);
	if (set_string)
		ret = pollux_set(memregs, set_string);
	else
		printf("env var %s not defined.\n", env_var);

	return ret;
}

#ifdef BINARY
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

static void usage(const char *binary)
{
	int i;
	printf("usage:\n%s <set_str[;set_str[;...]]>\n"
		"set_str:\n", binary);
	for (i = 0; i < ALL_PARAM_COUNT; i++)
		printf("  %s=<%s>\n", all_params[i].name, all_params[i].help);
}

int main(int argc, char *argv[])
{
	volatile unsigned short *memregs;
	int ret, memdev;

	if (argc != 2) {
		usage(argv[0]);
		return 1;
	}

	memdev = open("/dev/mem", O_RDWR);
	if (memdev == -1)
	{
		perror("open(/dev/mem) failed");
		return 1;
	}

	memregs	= mmap(0, 0x20000, PROT_READ|PROT_WRITE, MAP_SHARED, memdev, 0xc0000000);
	if (memregs == MAP_FAILED)
	{
		perror("mmap(memregs) failed");
		close(memdev);
		return 1;
	}

	ret = pollux_set(memregs, argv[1]);

	munmap((void *)memregs, 0x20000);
	close(memdev);

	return ret;
}
#endif
