/*
 * (C) Gražvydas "notaz" Ignotas, 2006-2009,2013
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
#include <linux/fb.h>
#include <sys/mman.h>

#include "../libpicofe/gp2x/plat_gp2x.h"
#include "../libpicofe/gp2x/soc.h"
#include "../common/arm_utils.h"
#include "../common/emu.h"
#include "plat.h"

#define FRAMEBUFF_SIZE  0x30000
#define FRAMEBUFF_WHOLESIZE (FRAMEBUFF_SIZE*4) // 320*240*2 + some more
#define FRAMEBUFF_ADDR0 (0x4000000 - FRAMEBUFF_WHOLESIZE)
#define FRAMEBUFF_ADDR1 (FRAMEBUFF_ADDR0 + FRAMEBUFF_SIZE)
#define FRAMEBUFF_ADDR2 (FRAMEBUFF_ADDR1 + FRAMEBUFF_SIZE)
#define FRAMEBUFF_ADDR3 (FRAMEBUFF_ADDR2 + FRAMEBUFF_SIZE)

static const int gp2x_screenaddrs[4] = { FRAMEBUFF_ADDR0, FRAMEBUFF_ADDR1, FRAMEBUFF_ADDR2, FRAMEBUFF_ADDR3 };
static int gp2x_screenaddrs_use[4];

static unsigned short gp2x_screenaddr_old[4];
static int screensel;

static void gp2x_video_flip_(void)
{
	unsigned short lsw = (unsigned short) gp2x_screenaddrs_use[screensel&3];
	unsigned short msw = (unsigned short)(gp2x_screenaddrs_use[screensel&3] >> 16);

  	memregs[0x2910>>1] = msw;
  	memregs[0x2914>>1] = msw;
	memregs[0x290E>>1] = lsw;
  	memregs[0x2912>>1] = lsw;

	// jump to other buffer:
	g_screen_ptr = gp2x_screens[++screensel&3];
}

/* doulblebuffered flip */
static void gp2x_video_flip2_(void)
{
	unsigned short msw = (unsigned short)(gp2x_screenaddrs_use[screensel&1] >> 16);

  	memregs[0x2910>>1] = msw;
  	memregs[0x2914>>1] = msw;
	memregs[0x290E>>1] = 0;
  	memregs[0x2912>>1] = 0;

	// jump to other buffer:
	g_screen_ptr = gp2x_screens[++screensel&1];
}

static void gp2x_video_changemode_ll_(int bpp, int is_pal)
{
  	memregs[0x28DA>>1] = (((bpp+1)/8)<<9)|0xAB; /*8/15/16/24bpp...*/
  	memregs[0x290C>>1] = 320*((bpp+1)/8); /*line width in bytes*/
}

static void gp2x_video_setpalette_(int *pal, int len)
{
	unsigned short *g = (unsigned short *)pal;
	volatile unsigned short *memreg = &memregs[0x295A>>1];

	memregs[0x2958>>1] = 0;

	len *= 2;
	while (len--)
		*memreg = *g++;
}

static void gp2x_video_RGB_setscaling_(int ln_offs, int W, int H)
{
	float escalaw, escalah;
	int bpp = (memregs[0x28DA>>1]>>9)&0x3;
	unsigned short scalw;

	// set offset
	gp2x_screenaddrs_use[0] = gp2x_screenaddrs[0] + ln_offs * 320 * bpp;
	gp2x_screenaddrs_use[1] = gp2x_screenaddrs[1] + ln_offs * 320 * bpp;
	gp2x_screenaddrs_use[2] = gp2x_screenaddrs[2] + ln_offs * 320 * bpp;
	gp2x_screenaddrs_use[3] = gp2x_screenaddrs[3] + ln_offs * 320 * bpp;

	escalaw = 1024.0; // RGB Horiz LCD
	escalah = 320.0; // RGB Vert LCD

	if (memregs[0x2800>>1]&0x100) //TV-Out
	{
		escalaw=489.0; // RGB Horiz TV (PAL, NTSC)
		if (memregs[0x2818>>1]  == 287) //PAL
			escalah=274.0; // RGB Vert TV PAL
		else if (memregs[0x2818>>1]  == 239) //NTSC
			escalah=331.0; // RGB Vert TV NTSC
	}

	// scale horizontal
	scalw = (unsigned short)((float)escalaw *(W/320.0));
	/* if there is no horizontal scaling, vertical doesn't work.
	 * Here is a nasty wrokaround... */
	if (H != 240 && W == 320) scalw--;
	memregs[0x2906>>1]=scalw;
	// scale vertical
	memregl[0x2908>>2]=(unsigned long)((float)escalah *bpp *(H/240.0));
}

static void gp2x_video_wait_vsync_(void)
{
	unsigned short v = memregs[0x1182>>1];
	while (!((v ^ memregs[0x1182>>1]) & 0x10))
		spend_cycles(1024);
}


void vid_mmsp2_init(void)
{
	int i;

  	gp2x_screens[0] = mmap(0, FRAMEBUFF_WHOLESIZE, PROT_WRITE, MAP_SHARED,
		memdev, gp2x_screenaddrs[0]);
	if (gp2x_screens[0] == MAP_FAILED)
	{
		perror("mmap(g_screen_ptr)");
		exit(1);
	}
	printf("framebuffers:\n");
	printf("  %08x -> %p\n", gp2x_screenaddrs[0], gp2x_screens[0]);
	for (i = 1; i < 4; i++)
	{
		gp2x_screens[i] = (char *) gp2x_screens[i - 1] + FRAMEBUFF_SIZE;
		printf("  %08x -> %p\n", gp2x_screenaddrs[i], gp2x_screens[i]);
	}

	g_screen_ptr = gp2x_screens[0];
	screensel = 0;

	gp2x_screenaddr_old[0] = memregs[0x290E>>1];
	gp2x_screenaddr_old[1] = memregs[0x2910>>1];
	gp2x_screenaddr_old[2] = memregs[0x2912>>1];
	gp2x_screenaddr_old[3] = memregs[0x2914>>1];

	memcpy(gp2x_screenaddrs_use, gp2x_screenaddrs, sizeof(gp2x_screenaddrs));

	gp2x_video_flip = gp2x_video_flip_;
	gp2x_video_flip2 = gp2x_video_flip2_;
	gp2x_video_changemode_ll = gp2x_video_changemode_ll_;
	gp2x_video_setpalette = gp2x_video_setpalette_;
	gp2x_video_RGB_setscaling = gp2x_video_RGB_setscaling_;
	gp2x_video_wait_vsync = gp2x_video_wait_vsync_;
}

void vid_mmsp2_finish(void)
{
	gp2x_video_RGB_setscaling_(0, 320, 240);
	gp2x_video_changemode_ll_(16, 0);

	memregs[0x290E>>1] = gp2x_screenaddr_old[0];
	memregs[0x2910>>1] = gp2x_screenaddr_old[1];
	memregs[0x2912>>1] = gp2x_screenaddr_old[2];
	memregs[0x2914>>1] = gp2x_screenaddr_old[3];

	munmap(gp2x_screens[0], FRAMEBUFF_WHOLESIZE);
}
