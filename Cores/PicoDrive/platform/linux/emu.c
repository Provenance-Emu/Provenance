/*
 * PicoDrive
 * (C) notaz, 2006-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <unistd.h>

#include "../libpicofe/menu.h"
#include "../libpicofe/plat.h"
#include "../common/emu.h"
#include "../common/arm_utils.h"
#include "../common/version.h"

#include <pico/pico_int.h>


const char *renderer_names[] = { "16bit accurate", " 8bit accurate", " 8bit fast", NULL };
const char *renderer_names32x[] = { "accurate", "faster", "fastest", NULL };
enum renderer_types { RT_16BIT, RT_8BIT_ACC, RT_8BIT_FAST, RT_COUNT };


void pemu_prep_defconfig(void)
{
}

void pemu_validate_config(void)
{
	extern int PicoOpt;
//	PicoOpt &= ~POPT_EXT_FM;
	PicoOpt &= ~POPT_EN_DRC;
}

static void draw_cd_leds(void)
{
	int led_reg, pitch, scr_offs, led_offs;
	led_reg = Pico_mcd->s68k_regs[0];

	pitch = 320;
	led_offs = 4;
	scr_offs = pitch * 2 + 4;

	if (currentConfig.renderer != RT_16BIT) {
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

void pemu_finalize_frame(const char *fps, const char *notice)
{
	if (currentConfig.renderer != RT_16BIT && !(PicoAHW & PAHW_32X)) {
		unsigned short *pd = (unsigned short *)g_screen_ptr + 8 * g_screen_width;
		unsigned char *ps = PicoDraw2FB + 328*8 + 8;
		unsigned short *pal = HighPal;
		int i, x;
		if (Pico.m.dirtyPal)
			PicoDrawUpdateHighPal();
		for (i = 0; i < 224; i++, ps += 8)
			for (x = 0; x < 320; x++)
				*pd++ = pal[*ps++];
	}

	if (notice || (currentConfig.EmuOpt & EOPT_SHOW_FPS)) {
		if (notice)
			emu_osd_text16(4, g_screen_height - 8, notice);
		if (currentConfig.EmuOpt & EOPT_SHOW_FPS)
			emu_osd_text16(g_screen_width - 60, g_screen_height - 8, fps);
	}
	if ((PicoAHW & PAHW_MCD) && (currentConfig.EmuOpt & EOPT_EN_CD_LEDS))
		draw_cd_leds();
}

static void apply_renderer(void)
{
	switch (currentConfig.renderer) {
	case RT_16BIT:
		PicoOpt &= ~POPT_ALT_RENDERER;
		PicoDrawSetOutFormat(PDF_RGB555, 0);
		PicoDrawSetOutBuf(g_screen_ptr, g_screen_width * 2);
		break;
	case RT_8BIT_ACC:
		PicoOpt &= ~POPT_ALT_RENDERER;
		PicoDrawSetOutFormat(PDF_8BIT, 0);
		PicoDrawSetOutBuf(PicoDraw2FB + 8, 328);
		break;
	case RT_8BIT_FAST:
		PicoOpt |=  POPT_ALT_RENDERER;
		PicoDrawSetOutFormat(PDF_NONE, 0);
		break;
	}

	if (PicoAHW & PAHW_32X)
		PicoDrawSetOutBuf(g_screen_ptr, g_screen_width * 2);
}

void plat_video_toggle_renderer(int change, int is_menu)
{
	currentConfig.renderer += change;
	if      (currentConfig.renderer >= RT_COUNT)
		currentConfig.renderer = 0;
	else if (currentConfig.renderer < 0)
		currentConfig.renderer = RT_COUNT - 1;

	if (!is_menu)
		apply_renderer();

	emu_status_msg(renderer_names[currentConfig.renderer]);
}

void plat_status_msg_clear(void)
{
	unsigned short *d = (unsigned short *)g_screen_ptr + g_screen_width * g_screen_height;
	int l = g_screen_width * 8;
	memset32((int *)(d - l), 0, l * 2 / 4);
}

void plat_status_msg_busy_next(const char *msg)
{
	plat_status_msg_clear();
	pemu_finalize_frame("", msg);
	plat_video_flip();
	emu_status_msg("");
	reset_timing = 1;
}

void plat_status_msg_busy_first(const char *msg)
{
//	memset32(g_screen_ptr, 0, g_screen_width * g_screen_height * 2 / 4);
	plat_status_msg_busy_next(msg);
}

void plat_update_volume(int has_changed, int is_up)
{
}

void pemu_forced_frame(int no_scale, int do_emu)
{
	PicoDrawSetOutBuf(g_screen_ptr, g_screen_width * 2);
	PicoDrawSetCallbacks(NULL, NULL);
	Pico.m.dirtyPal = 1;

	emu_cmn_forced_frame(no_scale, do_emu);

	g_menubg_src_ptr = g_screen_ptr;
}

void pemu_sound_start(void)
{
	emu_sound_start();
}

void plat_debug_cat(char *str)
{
}

void emu_video_mode_change(int start_line, int line_count, int is_32cols)
{
	// clear whole screen in all buffers
	memset32(g_screen_ptr, 0, g_screen_width * g_screen_height * 2 / 4);
}

void pemu_loop_prep(void)
{
	apply_renderer();
}

void pemu_loop_end(void)
{
	/* do one more frame for menu bg */
	pemu_forced_frame(0, 1);
}

void plat_wait_till_us(unsigned int us_to)
{
	unsigned int now;

	now = plat_get_ticks_us();

	while ((signed int)(us_to - now) > 512)
	{
		usleep(1024);
		now = plat_get_ticks_us();
	}
}

