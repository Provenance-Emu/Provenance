/*
 * (c) Copyright 2006-2010 notaz, All rights reserved.
 * (c) Copyright 2019-2024 irixxxx
 *
 * For performance reasons 3 renderers are exported for both MD and 32x modes:
 * - 16bpp line renderer
 * - 8bpp line renderer (slightly faster)
 * - 8bpp tile renderer
 * In 32x mode:
 * - 32x layer is overlayed on top of 16bpp one
 * - line internal one done on .Draw2FB, then mixed with 32x
 * - tile internal one done on .Draw2FB, then mixed with 32x
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "../libpicofe/gp2x/plat_gp2x.h"
#include "../libpicofe/gp2x/soc.h"
#include "../libpicofe/input.h"
#include "../libpicofe/plat.h"
#include "../libpicofe/gp2x/soc_pollux.h"
#include "../common/menu_pico.h"
#include "../common/arm_utils.h"
#include "../common/emu.h"
#include "../common/keyboard.h"
#include "../common/config_file.h"
#include "../common/version.h"
#include "plat.h"

#include <pico/pico_int.h>
#include <pico/patch.h>
#include <pico/sound/mix.h>
#include <zlib.h>

#ifdef BENCHMARK
#define OSD_FPS_X 220
#else
#define OSD_FPS_X 260
#endif


//extern int crashed_940;

static int osd_fps_x, osd_y, doing_bg_frame;
const char *renderer_names[] = { "16bit accurate", " 8bit accurate", " 8bit fast", NULL };
const char *renderer_names32x[] = { "accurate", "faster", "fastest", NULL };
enum renderer_types { RT_16BIT, RT_8BIT_ACC, RT_8BIT_FAST, RT_COUNT };

static int is_1stblanked;
static int firstline, linecount;
static int firstcol, colcount;

static int (*emu_scan_begin)(unsigned int num) = NULL;
static int (*emu_scan_end)(unsigned int num) = NULL;


void pemu_prep_defconfig(void)
{
	gp2x_soc_t soc;

	defaultConfig.CPUclock = default_cpu_clock;
	defaultConfig.renderer32x = RT_8BIT_ACC;
	defaultConfig.analog_deadzone = 50;

	soc = soc_detect();
	if (soc == SOCID_MMSP2)
		defaultConfig.s_PicoOpt |= POPT_EXT_FM;
	else if (soc == SOCID_POLLUX) {
		defaultConfig.EmuOpt |= EOPT_WIZ_TEAR_FIX|EOPT_SHOW_RTC;
		defaultConfig.s_PicoOpt |= POPT_EN_MCD_GFX;
	}
}

void pemu_validate_config(void)
{
	if (gp2x_dev_id != GP2X_DEV_GP2X)
		PicoIn.opt &= ~POPT_EXT_FM;
	if (gp2x_dev_id != GP2X_DEV_WIZ)
		currentConfig.EmuOpt &= ~EOPT_WIZ_TEAR_FIX;

	if (currentConfig.gamma < 10 || currentConfig.gamma > 300)
		currentConfig.gamma = 100;

	if (currentConfig.CPUclock < 10 || currentConfig.CPUclock > 1024)
		currentConfig.CPUclock = default_cpu_clock;
}

static int get_renderer(void)
{
	if (doing_bg_frame)
		return RT_16BIT;
	if (PicoIn.AHW & PAHW_32X)
		return currentConfig.renderer32x;
	else
		return currentConfig.renderer;
}

static void change_renderer(int diff)
{
	int *r;
	if (PicoIn.AHW & PAHW_32X)
		r = &currentConfig.renderer32x;
	else
		r = &currentConfig.renderer;
	*r += diff;

	if      (*r >= RT_COUNT)
		*r = 0;
	else if (*r < 0)
		*r = RT_COUNT - 1;
}

#define is_16bit_mode() \
	(currentConfig.renderer == RT_16BIT || (PicoIn.AHW & PAHW_32X) || doing_bg_frame)

static void (*osd_text)(int x, int y, const char *text);

static void osd_text8(int x, int y, const char *text)
{
	int len = strlen(text)*8;
	int *p, i, h, offs;

	len = (len+3) >> 2;
	for (h = 0; h < 8; h++) {
		offs = (x + g_screen_width * (y+h)) & ~3;
		p = (int *) ((char *)g_screen_ptr + offs);
		for (i = len; i; i--, p++)
			*p = 0xe0e0e0e0;
	}
	emu_text_out8(x, y, text);
}

static void osd_text8_rot(int x, int y, const char *text)
{
	int len = strlen(text) * 8;
	char *p = (char *)g_screen_ptr + 240*(320-x) + y;

	while (len--) {
		memset(p, 0xe0, 8);
		p -= 240;
	}

	emu_text_out8_rot(x, y, text);
}

static void osd_text16_rot(int x, int y, const char *text)
{
	int len = strlen(text) * 8;
	short *p = (short *)g_screen_ptr + 240*(320-x) + y;

	while (len--) {
		memset(p, 0, 8*2);
		p -= 240;
	}

	emu_text_out16_rot(x, y, text);
}

static void draw_cd_leds(void)
{
	int led_reg, pitch, scr_offs, led_offs;
	led_reg = Pico_mcd->s68k_regs[0];

	if (currentConfig.EmuOpt & EOPT_WIZ_TEAR_FIX) {
		pitch = 240;
		led_offs = -pitch * 6;
		scr_offs = pitch * (320 - 4);
	} else {
		pitch = 320;
		led_offs = 4;
		scr_offs = pitch * 2 + 4;
	}

	if (!is_16bit_mode()) {
	#define p(x) px[(x) >> 2]
		// 8-bit modes
		unsigned int *px = (unsigned int *)((char *)g_screen_ptr + scr_offs);
		unsigned int col_g = (led_reg & 2) ? 0xc0c0c0c0 : 0xe0e0e0e0;
		unsigned int col_r = (led_reg & 1) ? 0xd0d0d0d0 : 0xe0e0e0e0;
		p(pitch*0) = p(pitch*1) = p(pitch*2) = col_g;
		p(pitch*0 + led_offs) = p(pitch*1 + led_offs) = p(pitch*2 + led_offs) = col_r;
	#undef p
	} else {
	#define p(x) px[(x)*2 >> 2] = px[((x)*2 >> 2) + 1]
		// 16-bit modes
		unsigned int *px = (unsigned int *)((short *)g_screen_ptr + scr_offs);
		unsigned int col_g = (led_reg & 2) ? 0x06000600 : 0;
		unsigned int col_r = (led_reg & 1) ? 0xc000c000 : 0;
		p(pitch*0) = p(pitch*1) = p(pitch*2) = col_g;
		p(pitch*0 + led_offs) = p(pitch*1 + led_offs) = p(pitch*2 + led_offs) = col_r;
	#undef p
	}
}

static void draw_pico_ptr(void)
{
	int up = (PicoPicohw.pen_pos[0]|PicoPicohw.pen_pos[1]) & 0x8000;
	int x, y, pitch = 320, offs;
	// storyware pages are actually squished, 2:1
	int h = (pico_inp_mode == 1 ? 160 : linecount);
	if (h < 224) y++;

	x = ((pico_pen_x * colcount  * ((1ULL<<32)/320 + 1)) >> 32) + firstcol;
	y = ((pico_pen_y * h         * ((1ULL<<32)/224 + 1)) >> 32) + firstline;

	if (currentConfig.EmuOpt & EOPT_WIZ_TEAR_FIX) {
		pitch = 240;
		offs = (319 - x) * pitch + y;
	} else
		offs = x + y * pitch;

	if (is_16bit_mode()) {
		unsigned short *p = (unsigned short *)g_screen_ptr + offs;
		int o = (up ? 0x0000 : 0xffff), _ = (up ? 0xffff : 0x0000);

		p[-pitch-1] ^= o; p[-pitch] ^= _; p[-pitch+1] ^= _; p[-pitch+2] ^= o;
		p[-1]       ^= _; p[0]      ^= o; p[1]        ^= o; p[2]        ^= _;
		p[pitch-1]  ^= _; p[pitch]  ^= o; p[pitch+1]  ^= o; p[pitch+2]  ^= _;
		p[2*pitch-1]^= o; p[2*pitch]^= _; p[2*pitch+1]^= _; p[2*pitch+2]^= o;
	} else {
		unsigned char *p = (unsigned char *)g_screen_ptr + offs;
		int o = (up ? 0xe0 : 0xf0), _ = (up ? 0xf0 : 0xe0);

		p[-pitch-1] = o; p[-pitch] = _; p[-pitch+1] = _; p[-pitch+2] = o;
		p[-1]       = _; p[0]      = o; p[1]        = o; p[2]        = _;
		p[pitch-1]  = _; p[pitch]  = o; p[pitch+1]  = o; p[pitch+2]  = _;
		p[2*pitch-1]= o; p[2*pitch]= _; p[2*pitch+1]= _; p[2*pitch+2]= o;
	}
}

static void clear_1st_column(int firstcol, int firstline, int linecount)
{
	int size = is_16bit_mode() ? 2 : 1;
	int black = is_16bit_mode() ? 0 : 0xe0;
	int i;

	// SMS 1st column blanked, replace with black
	if ((currentConfig.EmuOpt & EOPT_WIZ_TEAR_FIX) && !doing_bg_frame) {
		int pitch = 240*size;
		char *p = (char *)g_screen_ptr + (319-(firstcol-8))*pitch;
		for (i = 0; i < 8; i++, p -= pitch)
			memset(p+(firstline)*size, black, linecount*size);
	} else {
		int pitch = 320*size;
		char *p = (char *)g_screen_ptr + (firstline)*pitch;
		for (i = 0; i < linecount; i++, p += pitch)
			memset(p+(firstcol-8)*size, black, 8*size);
	}
}

/* rot thing for Wiz */
static unsigned char __attribute__((aligned(4))) rot_buff[320*4*2];

static int EmuScanBegin16_rot(unsigned int num)
{
	Pico.est.DrawLineDest = rot_buff + (num & 3) * 320 * 2;
	return 0;
}

static int EmuScanEnd16_rot(unsigned int num)
{
	if ((num & 3) != 3)
		return 0;
	rotated_blit16(g_screen_ptr, rot_buff, num + 1,
		!(Pico.video.reg[12] & 1) && !(PicoIn.opt & POPT_EN_SOFTSCALE));
	return 0;
}

static int EmuScanBegin8_rot(unsigned int num)
{
	Pico.est.DrawLineDest = rot_buff + (num & 3) * 320;
	return 0;
}

static int EmuScanEnd8_rot(unsigned int num)
{
	if ((num & 3) != 3)
		return 0;
	rotated_blit8(g_screen_ptr, rot_buff, num + 1,
		!(Pico.video.reg[12] & 1) && !(PicoIn.opt & POPT_EN_SOFTSCALE));
	return 0;
}

/* line doublers */
static unsigned int ld_counter;
static int ld_left, ld_lines; // numbers in Q1 format

static int EmuScanBegin16_ld(unsigned int num)
{
	if ((signed int)(ld_counter - num) > 100) {
		// vsync, offset so that the upscaled image is centered
		ld_counter = 120 - (120-num) * (ld_lines+2)/ld_lines;
		ld_left = ld_lines;
	}

	if (emu_scan_begin)
		return emu_scan_begin(ld_counter);
	else
		Pico.est.DrawLineDest = (char *)g_screen_ptr + 320 * ld_counter * gp2x_current_bpp / 8;

	return 0;
}

static int EmuScanEnd16_ld(unsigned int num)
{
	void *oldline = Pico.est.DrawLineDest;

	if (emu_scan_end)
		emu_scan_end(ld_counter);

	ld_counter++;
	ld_left -= 2;
	if (ld_left <= 0) {
		ld_left += ld_lines;

		EmuScanBegin16_ld(num);
		memcpy(Pico.est.DrawLineDest, oldline, 320 * gp2x_current_bpp / 8);
		if (emu_scan_end)
			emu_scan_end(ld_counter);

		ld_counter++;
	}

	return 0;
}

static int localPal[0x100];
static int localPalSize;

static void (*vidcpy8bit)(void *dest, void *src, int x_y, int w_h);
static int (*make_local_pal)(int fast_mode);

static int make_local_pal_md(int fast_mode)
{
	int pallen = 0x100;

	if (fast_mode) {
		bgr444_to_rgb32(localPal, PicoMem.cram, 64);
		pallen = 0x40;
		Pico.m.dirtyPal = 0;
	}
	else if (Pico.est.rendstatus & PDRAW_SONIC_MODE) { // mid-frame palette changes
		switch (Pico.est.SonicPalCount) {
		case 3: bgr444_to_rgb32(localPal+0xc0, Pico.est.SonicPal+0xc0, 64);
		case 2: bgr444_to_rgb32(localPal+0x80, Pico.est.SonicPal+0x80, 64);
		case 1: bgr444_to_rgb32(localPal+0x40, Pico.est.SonicPal+0x40, 64);
		default:bgr444_to_rgb32(localPal, Pico.est.SonicPal, 64);
		}
		pallen = (Pico.est.SonicPalCount+1)*0x40;
	}
	else if (Pico.video.reg[0xC] & 8) { // shadow/hilight mode
		bgr444_to_rgb32(localPal, Pico.est.SonicPal, 64);
		bgr444_to_rgb32_sh(localPal, Pico.est.SonicPal);
		memcpy(localPal+0xc0, localPal, 0x40*4); // for spr prio mess
	}
	else {
		bgr444_to_rgb32(localPal, Pico.est.SonicPal, 64);
		memcpy(localPal+0x40, localPal, 0x40*4); // for spr prio mess
		memcpy(localPal+0x80, localPal, 0x80*4); // for spr prio mess
	}
	localPal[0xc0] = 0x0000c000;
	localPal[0xd0] = 0x00c00000;
	localPal[0xe0] = 0x00000000; // reserved pixels for OSD
	localPal[0xf0] = 0x00ffffff;

	if (Pico.m.dirtyPal == 2)
		Pico.m.dirtyPal = 0;
	return pallen;
}

static int make_local_pal_sms(int fast_mode)
{
	static u16 tmspal[32] = {
		// SMS palette for TMS modes
		0x0000, 0x0000, 0x00a0, 0x00f0, 0x0500, 0x0f00, 0x0005, 0x0ff0,
		0x000a, 0x000f, 0x0055, 0x00ff, 0x0050, 0x0f0f, 0x0555, 0x0fff,
		// TMS palette
		0x0000, 0x0000, 0x04c2, 0x07d6, 0x0e55, 0x0f77, 0x055c, 0x0ee4,
		0x055f, 0x077f, 0x05bc, 0x08ce, 0x03a2, 0x0b5c, 0x0ccc, 0x0fff,
	};
	int i;
	
	if (!(Pico.video.reg[0] & 0x4)) {
		for (i = Pico.est.SonicPalCount; i >= 0; i--) {
			int sg = !!(PicoIn.AHW & (PAHW_SG|PAHW_SC));
			bgr444_to_rgb32(localPal+i*0x40, tmspal+sg*0x10, 32);
			memcpy(localPal+i*0x40+0x20, localPal+i*0x40, 0x20*4);
		}
	} else if (fast_mode) {
		for (i = 0;i >= 0; i--) {
			bgr444_to_rgb32(localPal+i*0x40, PicoMem.cram+i*0x40, 32);
			memcpy(localPal+i*0x40+0x20, localPal+i*0x40, 0x20*4);
		}
	} else {
		for (i = Pico.est.SonicPalCount; i >= 0; i--) {
			bgr444_to_rgb32(localPal+i*0x40, Pico.est.SonicPal+i*0x40, 32);
			memcpy(localPal+i*0x40+0x20, localPal+i*0x40, 0x20*4);
		}
	}
	if (Pico.m.dirtyPal == 2)
		Pico.m.dirtyPal = 0;
	return (Pico.est.SonicPalCount+1)*0x40;
}

void pemu_finalize_frame(const char *fps, const char *notice)
{
	int emu_opt = currentConfig.EmuOpt;
	int direct_rendered = 1;

	if (is_16bit_mode())
		localPalSize = 0; // nothing to do
	else if (get_renderer() == RT_8BIT_FAST)
	{
		// 8bit fast renderer
		if (Pico.m.dirtyPal)
			localPalSize = make_local_pal(1);
		// a hack for VR
		if (PicoIn.AHW & PAHW_SVP)
			memset32((int *)(Pico.est.Draw2FB+328*8+328*223), 0xe0e0e0e0, 328/4);
		// do actual copy
		vidcpy8bit(g_screen_ptr, Pico.est.Draw2FB,
			(firstcol << 16) | firstline, (colcount << 16) | linecount);
		direct_rendered = 0;
	}
	else if (get_renderer() == RT_8BIT_ACC)
	{
		// 8bit accurate renderer
		if (Pico.m.dirtyPal)
			localPalSize = make_local_pal(0);
	}

	// blank 1st column, only needed in modes directly rendering to screen
	if (is_1stblanked && direct_rendered)
		clear_1st_column(firstcol, firstline, linecount);

	if (notice)
		osd_text(4, osd_y, notice);
	if (emu_opt & EOPT_SHOW_FPS)
		osd_text(osd_fps_x, osd_y, fps);
	if ((PicoIn.AHW & PAHW_MCD) && (emu_opt & EOPT_EN_CD_LEDS))
		draw_cd_leds();
	if (PicoIn.AHW & PAHW_PICO) {
		int h = linecount, w = colcount;
		u16 *pd = g_screen_ptr + firstline*g_screen_ppitch + firstcol;

		if (pico_inp_mode && is_16bit_mode())
			emu_pico_overlay(pd, w, h, g_screen_ppitch);
		if (pico_inp_mode /*== 2 || overlay*/)
			draw_pico_ptr();
	}
	// draw virtual keyboard on display
	if (kbd_mode && currentConfig.keyboard == 2 && vkbd)
		vkbd_draw(vkbd);
}

void plat_video_flip(void)
{
	int stride = g_screen_width;
	gp2x_video_flip();
	// switching the palette takes immediate effect, whilst flipping only
	// takes effect with the next vsync; unavoidable flicker may occur!
	if (localPalSize)
		gp2x_video_setpalette(localPal, localPalSize);

	if (is_16bit_mode())
		stride *= 2;
	// the fast renderer has overlap areas and can't directly render to
	// screen buffers. Its output is copied to screen in finalize_frame
	if (get_renderer() != RT_8BIT_FAST || (PicoIn.AHW & PAHW_32X))
		PicoDrawSetOutBuf(g_screen_ptr, stride);
}

/* XXX */
unsigned int plat_get_ticks_ms(void)
{
	return gp2x_get_ticks_ms();
}

unsigned int plat_get_ticks_us(void)
{
	return gp2x_get_ticks_us();
}

void plat_wait_till_us(unsigned int us_to)
{
	unsigned int now;

	spend_cycles(1024);
	now = plat_get_ticks_us();

	while ((signed int)(us_to - now) > 512)
	{
		spend_cycles(1024);
		now = plat_get_ticks_us();
	}
}

void plat_video_wait_vsync(void)
{
	gp2x_video_wait_vsync();
}

void plat_status_msg_clear(void)
{
	int i, is_8bit = !is_16bit_mode();

	for (i = 0; i < 4; i++) {
		if (currentConfig.EmuOpt & EOPT_WIZ_TEAR_FIX) {
			/* ugh.. */
			int u, *p;
			if (is_8bit) {
				p = (int *)gp2x_screens[i] + (240-8) / 4;
				for (u = 320; u > 0; u--, p += 240/4)
					p[0] = p[1] = 0xe0e0e0e0;
			} else {
				p = (int *)gp2x_screens[i] + (240-8)*2 / 4;
				for (u = 320; u > 0; u--, p += 240*2/4)
					p[0] = p[1] = p[2] = p[3] = 0;
			}
		} else {
			if (is_8bit) {
				char *d = (char *)gp2x_screens[i] + 320 * (240-8);
				memset32((int *)d, 0xe0e0e0e0, 320 * 8 / 4);
			} else {
				char *d = (char *)gp2x_screens[i] + 320*2 * (240-8);
				memset32((int *)d, 0, 2*320 * 8 / 4);
			}
		}
	}
}

void plat_status_msg_busy_next(const char *msg)
{
	plat_status_msg_clear();
	pemu_finalize_frame("", msg);
	plat_video_flip();
	emu_status_msg("");

	/* assumption: msg_busy_next gets called only when
	 * something slow is about to happen */
	reset_timing = 1;
}

void plat_status_msg_busy_first(const char *msg)
{
	plat_status_msg_busy_next(msg);
}

void plat_status_msg_busy_done(void)
{
}

static void vid_reset_mode(void)
{
	int gp2x_mode = 16;
	int renderer = get_renderer();

	PicoIn.opt &= ~(POPT_ALT_RENDERER|POPT_DIS_32C_BORDER|POPT_EN_SOFTSCALE);
	if (currentConfig.scaling == EOPT_SCALE_SW) {
		PicoIn.opt |= POPT_EN_SOFTSCALE;
		PicoIn.filter = EOPT_FILTER_BILINEAR2;
	} else if (currentConfig.scaling == EOPT_SCALE_HW)
		// hw scaling, render without any padding
		PicoIn.opt |= POPT_DIS_32C_BORDER;

	switch (renderer) {
	case RT_16BIT:
		PicoDrawSetOutFormat(PDF_RGB555, 0);
		PicoDrawSetOutBuf(g_screen_ptr, g_screen_width * 2);
		break;
	case RT_8BIT_ACC:
		PicoDrawSetOutFormat(PDF_8BIT, 0);
		PicoDrawSetOutBuf(g_screen_ptr, g_screen_width);
		gp2x_mode = 8;
		break;
	case RT_8BIT_FAST:
		PicoIn.opt |= POPT_ALT_RENDERER;
		PicoDrawSetOutFormat(PDF_NONE, 0);
		vidcpy8bit = vidcpy_8bit;
		gp2x_mode = 8;
		break;
	default:
		printf("bad renderer\n");
		break;
	}

	if (PicoIn.AHW & PAHW_32X) {
		// Wiz 16bit is an exception, uses line rendering due to rotation mess
		if (renderer == RT_16BIT && (currentConfig.EmuOpt & EOPT_WIZ_TEAR_FIX)) {
			PicoDrawSetOutFormat(PDF_RGB555, 1);
		}
		PicoDrawSetOutBuf(g_screen_ptr, g_screen_width * 2);
		gp2x_mode = 16;
	}

	emu_scan_begin = NULL;
	emu_scan_end = NULL;

	if (currentConfig.EmuOpt & EOPT_WIZ_TEAR_FIX) {
		if ((PicoIn.AHW & PAHW_32X) || renderer == RT_16BIT) {
			emu_scan_begin = EmuScanBegin16_rot;
			emu_scan_end = EmuScanEnd16_rot;
			memset(rot_buff, 0, 320*4*2);
		}
		else if (renderer == RT_8BIT_ACC) {
			emu_scan_begin = EmuScanBegin8_rot;
			emu_scan_end = EmuScanEnd8_rot;
			memset(rot_buff, 0xe0, 320*4);
		}
		else if (renderer == RT_8BIT_FAST)
			vidcpy8bit = vidcpy_8bit_rot;
	}

	PicoDrawSetCallbacks(emu_scan_begin, emu_scan_end);

	if (is_16bit_mode())
		osd_text = (currentConfig.EmuOpt & EOPT_WIZ_TEAR_FIX) ? osd_text16_rot : emu_osd_text16;
	else
		osd_text = (currentConfig.EmuOpt & EOPT_WIZ_TEAR_FIX) ? osd_text8_rot : osd_text8;

	gp2x_video_wait_vsync();
	if (!is_16bit_mode()) {
		// setup pal for 8-bit modes
		localPal[0xc0] = 0x0000c000; // MCD LEDs
		localPal[0xd0] = 0x00c00000;
		localPal[0xe0] = 0x00000000; // reserved pixels for OSD
		localPal[0xf0] = 0x00ffffff;
		gp2x_video_setpalette(localPal, 0x100);
	}

	if (currentConfig.EmuOpt & EOPT_WIZ_TEAR_FIX)
		gp2x_mode = -gp2x_mode;

	gp2x_video_changemode(gp2x_mode, Pico.m.pal);

	// clear whole screen in all buffers
	if (!is_16bit_mode())
		gp2x_memset_all_buffers(0, 0xe0, 320*240);
	else
		gp2x_memset_all_buffers(0, 0, 320*240*2);

	Pico.m.dirtyPal = 1;

	// palette converters for 8bit modes
	make_local_pal = (PicoIn.AHW & PAHW_SMS) ? make_local_pal_sms : make_local_pal_md;
}

void emu_video_mode_change(int start_line, int line_count, int start_col, int col_count)
{
	int scalex = 320, scaley = 240;
	int ln_offs = 0;

	if (currentConfig.vscaling != EOPT_SCALE_NONE &&
			(is_16bit_mode() || get_renderer() != RT_8BIT_FAST)) {
		/* NTSC always has 224 visible lines, anything smaller has bars */
		if (line_count < 224 && line_count > 144) {
			start_line -= (224-line_count) /2;
			line_count = 224;
		}

		/* line doubling for swscaling, also needed for bg frames */
		if (currentConfig.vscaling == EOPT_SCALE_SW && line_count < 240) {
			ld_lines = ld_left = 2*line_count / (240 - line_count);
			PicoDrawSetCallbacks(EmuScanBegin16_ld,EmuScanEnd16_ld);
		}
	}

	/* blanking for SMS with 1st tile blanked */
	is_1stblanked = (col_count == 248);
	firstline = start_line; linecount = line_count;
	firstcol = start_col; colcount = col_count;

	if (doing_bg_frame)
		return;

	osd_fps_x = OSD_FPS_X;
	osd_y = 232;

	/* set up hwscaling here */
	if (col_count < 320 && currentConfig.scaling == EOPT_SCALE_HW) {
		scalex = col_count;
		osd_fps_x = col_count - (320-OSD_FPS_X);
	}

	if (currentConfig.vscaling == EOPT_SCALE_HW) {
		ln_offs = start_line;
		scaley = line_count;
		osd_y = start_line + line_count - 8;
	}

	gp2x_video_RGB_setscaling(ln_offs, scalex, scaley);

	// clear whole screen in all buffers
	if (!is_16bit_mode())
		gp2x_memset_all_buffers(0, 0xe0, 320*240);
	else
		gp2x_memset_all_buffers(0, 0, 320*240*2);
}

void plat_video_clear_buffers(void)
{
	if (!is_16bit_mode())
		gp2x_memset_all_buffers(0, 0xe0, 320*240);
	else
		gp2x_memset_all_buffers(0, 0, 320*240*2);
}

void plat_video_toggle_renderer(int change, int is_menu_call)
{
	change_renderer(change);

	if (is_menu_call)
		return;

	vid_reset_mode();
	rendstatus_old = -1;

	if (PicoIn.AHW & PAHW_32X)
		emu_status_msg(renderer_names32x[get_renderer()]);
	else
		emu_status_msg(renderer_names[get_renderer()]);
}

#if 0 // TODO
static void RunEventsPico(unsigned int events)
{
	int ret, px, py, lim_x;
	static int pdown_frames = 0;

	// for F200
	ret = gp2x_touchpad_read(&px, &py);
	if (ret >= 0)
	{
		if (ret > 35000)
		{
			if (pdown_frames++ > 5)
				PicoIn.pad[0] |= 0x20;

			pico_pen_x = px;
			pico_pen_y = py;
			if (!(Pico.video.reg[12]&1)) {
				pico_pen_x -= 32;
				if (pico_pen_x <   0) pico_pen_x = 0;
				if (pico_pen_x > 248) pico_pen_x = 248;
			}
			if (pico_pen_y > 224) pico_pen_y = 224;
		}
		else
			pdown_frames = 0;

		//if (ret == 0)
		//	PicoPicohw.pen_pos[0] = PicoPicohw.pen_pos[1] = 0x8000;
	}
}
#endif

void plat_update_volume(int has_changed, int is_up)
{
	static int prev_frame = 0, wait_frames = 0;
	int need_low_volume = 0;
	int vol = currentConfig.volume;
	gp2x_soc_t soc;

	soc = soc_detect();
	if ((PicoIn.opt & POPT_EN_STEREO) && soc == SOCID_MMSP2)
		need_low_volume = 1;

	if (has_changed)
	{
		if (need_low_volume && vol < 5 && prev_frame == Pico.m.frame_count - 1 && wait_frames < 12)
			wait_frames++;
		else {
			wait_frames = 0;
			plat_target_step_volume(&currentConfig.volume, is_up ? 1 : -1);
			vol = currentConfig.volume;
		}
		emu_status_msg("VOL: %02i", vol);
		prev_frame = Pico.m.frame_count;
	}

	if (!need_low_volume)
		return;

	/* set the right mixer func */
	if (vol >= 5)
		PsndMix_32_to_16 = mix_32_to_16_stereo;
	else {
		mix_32_to_16_level = 5 - vol;
		PsndMix_32_to_16 = mix_32_to_16_stereo_lvl;
	}
}

void pemu_sound_start(void)
{
	gp2x_soc_t soc;

	emu_sound_start();

	if (currentConfig.EmuOpt & EOPT_EN_SOUND)
	{
		soc = soc_detect();
		if (soc == SOCID_POLLUX) {
			PicoIn.sndRate = pollux_get_real_snd_rate(PicoIn.sndRate);
			PsndRerate(Pico.m.frame_count ? 1 : 0);
		}

		plat_target_step_volume(&currentConfig.volume, 0);
	}
}

static const int sound_rates[] = { 52000, 44100, 32000, 22050, 16000, 11025, 8000 };

void pemu_sound_stop(void)
{
	int i;

	/* get back from Pollux pain */
	PicoIn.sndRate += 1000;
	for (i = 0; i < ARRAY_SIZE(sound_rates); i++) {
		if (PicoIn.sndRate >= sound_rates[i]) {
			PicoIn.sndRate = sound_rates[i];
			break;
		}
	}
}

void pemu_forced_frame(int no_scale, int do_emu)
{
	doing_bg_frame = 1;
	PicoDrawSetCallbacks(NULL, NULL);
	Pico.m.dirtyPal = 1;
	PicoIn.opt &= ~POPT_DIS_32C_BORDER;
	gp2x_current_bpp = 16;
	// always render in screen 3 since menu uses 0-2
	g_screen_ptr = gp2x_screens[3];

	if (!no_scale)
		no_scale = currentConfig.scaling == EOPT_SCALE_NONE;
	emu_cmn_forced_frame(no_scale, do_emu, g_screen_ptr);

	if (is_1stblanked)
		clear_1st_column(firstcol, firstline, linecount);

	g_menubg_src_ptr = g_screen_ptr;
	doing_bg_frame = 0;
}

void plat_debug_cat(char *str)
{
}

void plat_video_loop_prepare(void) 
{
	// make sure we are in correct mode
	change_renderer(0);
	vid_reset_mode();
	rendstatus_old = -1;
}

void pemu_loop_prep(void)
{
	if (gp2x_dev_id == GP2X_DEV_CAANOO)
		in_set_config_int(in_name_to_id("evdev:pollux-analog"),
			IN_CFG_ABS_DEAD_ZONE,
			currentConfig.analog_deadzone);

	// dirty buffers better go now than during gameplay
	sync();
	sleep(0);
}

void pemu_loop_end(void)
{
	pemu_sound_stop();

	if (g_screen_ptr == gp2x_screens[0]) {
		/* currently on screen 3, which is needed for forced_frame */
		int size = gp2x_current_bpp / 8;
		gp2x_memcpy_all_buffers(g_screen_ptr, 0, 320*240 * size);
		gp2x_video_flip();
	}
	/* do one more frame for menu bg */
	pemu_forced_frame(0, 1);
}

