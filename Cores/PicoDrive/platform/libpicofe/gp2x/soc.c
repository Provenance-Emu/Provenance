/*
 * (C) Gražvydas "notaz" Ignotas, 2009-2010
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "soc.h"

volatile unsigned short *memregs;
volatile unsigned int   *memregl;
int memdev = -1;

unsigned int (*gp2x_get_ticks_ms)(void);
unsigned int (*gp2x_get_ticks_us)(void);

gp2x_soc_t soc_detect(void)
{
	volatile unsigned short *memregs;
	volatile unsigned int *memregl;
	static gp2x_soc_t ret = -2;
	int pollux_chipname[0x30/4 + 1];
	char *pollux_chipname_c = (char *)pollux_chipname;
	int memdev_tmp;
	int i;

	if ((int)ret != -2)
		/* already detected */
		return ret;

  	memdev_tmp = open("/dev/mem", O_RDONLY);
	if (memdev_tmp == -1)
	{
		perror("open(/dev/mem)");
		ret = -1;
		return -1;
	}

	memregs = mmap(0, 0x20000, PROT_READ, MAP_SHARED,
		memdev_tmp, 0xc0000000);
	if (memregs == MAP_FAILED)
	{
		perror("mmap(memregs)");
		close(memdev_tmp);
		ret = -1;
		return -1;
	}
	memregl = (volatile void *)memregs;

	if (memregs[0x1836>>1] == 0x2330)
	{
		printf("looks like this is MMSP2\n");
		ret = SOCID_MMSP2;
		goto out;
	}

	/* perform word reads. Byte reads might also work,
	 * but we don't want to play with that. */
	for (i = 0; i < 0x30; i += 4)
	{
		pollux_chipname[i >> 2] = memregl[(0x1f810 + i) >> 2];
	}
	pollux_chipname_c[0x30] = 0;

	for (i = 0; i < 0x30; i++)
	{
		unsigned char c = pollux_chipname_c[i];
		if (c < 0x20 || c > 0x7f)
			goto not_pollux_like;
	}

	printf("found pollux-like id: \"%s\"\n", pollux_chipname_c);

	if (strncmp(pollux_chipname_c, "MAGICEYES-LEAPFROG-LF1000", 25) ||
		strncmp(pollux_chipname_c, "MAGICEYES-POLLUX", 16))
	{
		ret = SOCID_POLLUX;
		goto out;
	}

not_pollux_like:
out:
	munmap((void *)memregs, 0x20000);
	close(memdev_tmp);
	return ret;	
}

