/*
 * (C) Gražvydas "notaz" Ignotas, 2009,2013
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
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/fb.h>
#include <unistd.h>

#include "../libpicofe/gp2x/soc.h"
#include "../libpicofe/gp2x/plat_gp2x.h"
#include "../libpicofe/gp2x/pollux_set.h"
#include "../common/emu.h"
#include "../common/arm_utils.h"
#include "plat.h"

#define FB_BUF_COUNT 4
#define FB_MEM_SIZE (320*240*2 * FB_BUF_COUNT)

static unsigned int fb_paddr[FB_BUF_COUNT];
static int fb_work_buf;
static int fbdev = -1;


/* video stuff */
static void pollux_video_flip(int buf_count)
{
	memregl[0x406C>>2] = memregl[0x446C>>2] = fb_paddr[fb_work_buf];
	memregl[0x4058>>2] |= 0x10;
	memregl[0x4458>>2] |= 0x10;

	fb_work_buf++;
	if (fb_work_buf >= buf_count)
		fb_work_buf = 0;
	g_screen_ptr = gp2x_screens[fb_work_buf];
}

static void gp2x_video_flip_(void)
{
	pollux_video_flip(FB_BUF_COUNT);
}

/* doulblebuffered flip */
static void gp2x_video_flip2_(void)
{
	pollux_video_flip(2);
}

static void gp2x_video_changemode_ll_(int bpp, int is_pal)
{
	static int prev_bpp = 0;
	int code = 0, bytes = 2;
	int rot_cmd[2] = { 0, 0 };
	unsigned int r;
	char buff[32];
	int ret;

	if (bpp == prev_bpp)
		return;
	prev_bpp = bpp;

	printf("changemode: %dbpp rot=%d\n", abs(bpp), bpp < 0);

	/* negative bpp means rotated mode */
	rot_cmd[0] = (bpp < 0) ? 6 : 5;
	ret = ioctl(fbdev, _IOW('D', 90, int[2]), rot_cmd);
	if (ret < 0)
		perror("rot ioctl failed");
	memregl[0x4004>>2] = (bpp < 0) ? 0x013f00ef : 0x00ef013f;
	memregl[0x4000>>2] |= 1 << 3;

	/* the above ioctl resets LCD timings, so set them here */
	snprintf(buff, sizeof(buff), "POLLUX_LCD_TIMINGS_%s",
		is_pal ? "PAL" : "NTSC");
	pollux_set_fromenv(memregs, buff);

	switch (abs(bpp))
	{
		case 8:
			code = 0x443a;
			bytes = 1;
			break;

		case 15:
		case 16:
			code = 0x4432;
			bytes = 2;
			break;

		default:
			printf("unhandled bpp request: %d\n", abs(bpp));
			return;
	}

	// program both MLCs so that TV-out works
	memregl[0x405c>>2] = memregl[0x445c>>2] = bytes;
	memregl[0x4060>>2] = memregl[0x4460>>2] =
		bytes * (bpp < 0 ? 240 : 320);

	r = memregl[0x4058>>2];
	r = (r & 0xffff) | (code << 16) | 0x10;
	memregl[0x4058>>2] = r;

	r = memregl[0x4458>>2];
	r = (r & 0xffff) | (code << 16) | 0x10;
	memregl[0x4458>>2] = r;
}

static void gp2x_video_setpalette_(int *pal, int len)
{
	/* pollux palette is 16bpp only.. */
	int i;
	for (i = 0; i < len; i++)
	{
		int c = pal[i];
		c = ((c >> 8) & 0xf800) | ((c >> 5) & 0x07c0) | ((c >> 3) & 0x001f);
		memregl[0x4070>>2] = (i << 24) | c;
	}
}

static void gp2x_video_RGB_setscaling_(int ln_offs, int W, int H)
{
	/* maybe a job for 3d hardware? */
}

static void gp2x_video_wait_vsync_(void)
{
	while (!(memregl[0x308c>>2] & (1 << 10)))
		spend_cycles(128);
	memregl[0x308c>>2] |= 1 << 10;
}

void vid_pollux_init(void)
{
	struct fb_fix_screeninfo fbfix;
	int i, ret;

	fbdev = open("/dev/fb0", O_RDWR);
	if (fbdev < 0) {
		perror("can't open fbdev");
		exit(1);
	}

	ret = ioctl(fbdev, FBIOGET_FSCREENINFO, &fbfix);
	if (ret == -1) {
		perror("ioctl(fbdev) failed");
		exit(1);
	}

	printf("framebuffer: \"%s\" @ %08lx\n", fbfix.id, fbfix.smem_start);
	fb_paddr[0] = fbfix.smem_start;

	gp2x_screens[0] = mmap(0, FB_MEM_SIZE, PROT_READ|PROT_WRITE,
			MAP_SHARED, memdev, fb_paddr[0]);
	if (gp2x_screens[0] == MAP_FAILED)
	{
		perror("mmap(gp2x_screens) failed");
		exit(1);
	}
	memset(gp2x_screens[0], 0, FB_MEM_SIZE);

	printf("  %p -> %08x\n", gp2x_screens[0], fb_paddr[0]);
	for (i = 1; i < FB_BUF_COUNT; i++)
	{
		fb_paddr[i] = fb_paddr[i-1] + 320*240*2;
		gp2x_screens[i] = (char *)gp2x_screens[i-1] + 320*240*2;
		printf("  %p -> %08x\n", gp2x_screens[i], fb_paddr[i]);
	}
	fb_work_buf = 0;
	g_screen_ptr = gp2x_screens[0];

	gp2x_video_flip = gp2x_video_flip_;
	gp2x_video_flip2 = gp2x_video_flip2_;
	gp2x_video_changemode_ll = gp2x_video_changemode_ll_;
	gp2x_video_setpalette = gp2x_video_setpalette_;
	gp2x_video_RGB_setscaling = gp2x_video_RGB_setscaling_;
	gp2x_video_wait_vsync = gp2x_video_wait_vsync_;
}

void vid_pollux_finish(void)
{
	memset(gp2x_screens[0], 0, FB_MEM_SIZE);
	munmap(gp2x_screens[0], FB_MEM_SIZE);
	close(fbdev);
	fbdev = -1;
}
