/*
 * PicoDrive
 * (C) notaz, 2006-2010
 * (C) irixxxx, 2019-2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <unistd.h>
#ifndef __MINGW32__
#include <sys/mman.h> // MAP_JIT
#endif

#include "../libpicofe/menu.h"
#include "../libpicofe/plat.h"
#include "../common/emu.h"
#include "../common/arm_utils.h"
#include "../common/upscale.h"
#include "../common/keyboard.h"
#include "../common/version.h"

#include <pico/pico_int.h>


const char *renderer_names[] = { "16bit accurate", " 8bit accurate", " 8bit fast", NULL };
const char *renderer_names32x[] = { "accurate", "faster", "fastest", NULL };
enum renderer_types { RT_16BIT, RT_8BIT_ACC, RT_8BIT_FAST, RT_COUNT };

static int out_x, out_y, out_w, out_h;	// renderer output in render buffer
static int screen_x, screen_y, screen_w, screen_h; // final render destination 
static int render_bg;			// force 16bit mode for bg render
static u16 *ghost_buf;			// backbuffer to simulate LCD ghosting

void pemu_prep_defconfig(void)
{
}

void pemu_validate_config(void)
{
#if !defined(DRC_SH2)
	PicoIn.opt &= ~POPT_EN_DRC;
#endif
}

#define is_16bit_mode() \
	(currentConfig.renderer == RT_16BIT || (PicoIn.AHW & PAHW_32X) || render_bg)

static int get_renderer(void)
{
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

static void draw_cd_leds(void)
{
	int led_reg, pitch, scr_offs, led_offs;
	led_reg = Pico_mcd->s68k_regs[0];

	pitch = g_screen_ppitch;
	led_offs = 4;
	scr_offs = pitch * 2 + 4;

#define p(x) px[(x)*2 >> 2] = px[((x)*2 >> 2) + 1]
	// 16-bit modes
	uint32_t *px = (uint32_t *)((short *)g_screen_ptr + scr_offs);
	uint32_t col_g = (led_reg & 2) ? 0x06000600 : 0;
	uint32_t col_r = (led_reg & 1) ? 0xc000c000 : 0;
	p(pitch*0) = p(pitch*1) = p(pitch*2) = col_g;
	p(pitch*0 + led_offs) = p(pitch*1 + led_offs) = p(pitch*2 + led_offs) = col_r;
#undef p
}

static void draw_pico_ptr(void)
{
	int up = (PicoPicohw.pen_pos[0]|PicoPicohw.pen_pos[1]) & 0x8000;
	int o = (up ? 0x0000 : 0xffff), _ = (up ? 0xffff : 0x0000);
	int pitch = g_screen_ppitch;
	u16 *p = g_screen_ptr;
	int x = pico_pen_x, y = pico_pen_y;
	// storyware pages are actually squished, 2:1
	int h = (pico_inp_mode == 1 ? 160 : out_h);
	if (h < 224) y++;

	x = (x * out_w * ((1ULL<<32) / 320 + 1)) >> 32;
	y = (y *     h * ((1ULL<<32) / 224 + 1)) >> 32;
	p += (screen_y+y)*pitch + (screen_x+x);

	p[-pitch-1] ^= o; p[-pitch] ^= _; p[-pitch+1] ^= _; p[-pitch+2] ^= o;
	p[-1]       ^= _; p[0]      ^= o; p[1]        ^= o; p[2]        ^= _;
	p[pitch-1]  ^= _; p[pitch]  ^= o; p[pitch+1]  ^= o; p[pitch+2]  ^= _;
	p[2*pitch-1]^= o; p[2*pitch]^= _; p[2*pitch+1]^= _; p[2*pitch+2]^= o;
}

/* render/screen buffer handling:
 * In 16 bit mode, render output is directly placed in the screen buffer.
 * SW scaling is handled in renderer (x) and in vscaling callbacks here (y).
 * In 8 bit modes, output goes to the internal Draw2FB buffer in alternate
 * renderer format (8 pix overscan at left/top/bottom), left aligned (DIS_32C).
 * It is converted to 16 bit and SW scaled in pemu_finalize_frame.
 *
 * HW scaling always aligns the image to the left/top, since selecting an area
 * for display isn't always possible.
 */

static inline u16 *screen_buffer(u16 *buf)
{
	return buf + screen_y * g_screen_ppitch + screen_x -
			(out_y * g_screen_ppitch + out_x);
}

void screen_blit(u16 *pd, int pp, u8* ps, int ss, u16 *pal)
{
	typedef void (*upscale_t)
			(u16 *di,int ds, u8 *si,int ss, int w,int h, u16 *pal);
	static const upscale_t upscale_256_224_hv[] = {
		upscale_rgb_nn_x_4_5_y_16_17,	upscale_rgb_snn_x_4_5_y_16_17,
		upscale_rgb_bl2_x_4_5_y_16_17,	upscale_rgb_bl4_x_4_5_y_16_17,
	};
	static const upscale_t upscale_256_____h[] = {
		upscale_rgb_nn_x_4_5,		upscale_rgb_snn_x_4_5,
		upscale_rgb_bl2_x_4_5,		upscale_rgb_bl4_x_4_5,
	};
	static const upscale_t upscale_____224_v[] = {
		upscale_rgb_nn_y_16_17,		upscale_rgb_snn_y_16_17,
		upscale_rgb_bl2_y_16_17,	upscale_rgb_bl4_y_16_17,
	};
	static const upscale_t upscale_160_144_hv[] = {
		upscale_rgb_nn_x_1_2_y_3_5,	upscale_rgb_nn_x_1_2_y_3_5,
		upscale_rgb_bl2_x_1_2_y_3_5,	upscale_rgb_bl4_x_1_2_y_3_5,
	};
	static const upscale_t upscale_160_____h[] = {
		upscale_rgb_nn_x_1_2,		upscale_rgb_nn_x_1_2,
		upscale_rgb_bl2_x_1_2,		upscale_rgb_bl2_x_1_2,
	};
	static const upscale_t upscale_____144_v[] = {
		upscale_rgb_nn_y_3_5,		upscale_rgb_nn_y_3_5,
		upscale_rgb_bl2_y_3_5,		upscale_rgb_bl4_y_3_5,
	};
	const upscale_t *upscale;
	int y;

	// handle software upscaling
	upscale = NULL;
	if (currentConfig.scaling == EOPT_SCALE_SW && out_w <= 256) {
	    if (currentConfig.vscaling == EOPT_SCALE_SW && out_h <= 224)
		// h+v scaling
		upscale = out_w >= 240 ? upscale_256_224_hv: upscale_160_144_hv;
	    else
		// h scaling
		upscale = out_w >= 240 ? upscale_256_____h : upscale_160_____h;
	} else if (currentConfig.vscaling == EOPT_SCALE_SW && out_h <= 224)
		// v scaling
		upscale = out_w >= 240 ? upscale_____224_v : upscale_____144_v;
	if (!upscale) {
		// no scaling
		for (y = 0; y < out_h; y++)
			h_copy(pd, pp, ps, 328, out_w, f_pal);
		return;
	}

	upscale[currentConfig.filter & 0x3](pd, pp, ps, ss, out_w, out_h, pal);
}

void pemu_finalize_frame(const char *fps, const char *notice)
{
	if (!is_16bit_mode()) {
		// convert the 8 bit CLUT output to 16 bit RGB
		u16 *pd = screen_buffer(g_screen_ptr) +
				out_y * g_screen_ppitch + out_x;
		u8  *ps = Pico.est.Draw2FB + out_y * 328 + out_x + 8;

		PicoDrawUpdateHighPal();

		if (out_w == 248 && currentConfig.scaling == EOPT_SCALE_SW)
			pd += (320 - out_w*320/256) / 2; // SMS with 1st tile blanked, recenter
		screen_blit(pd, g_screen_ppitch, ps, 328, Pico.est.HighPal);
	}

	if (currentConfig.ghosting && out_h == 144) {
		// GG LCD ghosting emulation
		u16 *pd = screen_buffer(g_screen_ptr) +
				out_y * g_screen_ppitch + out_x;
		u16 *ps = ghost_buf;
		int y, h = currentConfig.vscaling == EOPT_SCALE_SW ? 240:out_h;
		int w = currentConfig.scaling == EOPT_SCALE_SW ? 320:out_w;

		if (currentConfig.ghosting == 1)
			for (y = 0; y < h; y++) {
				v_blend((u32 *)pd, (u32 *)ps, w/2, p_075_round);
				pd += g_screen_ppitch;
				ps += w;
			}
		else
			for (y = 0; y < h; y++) {
				v_blend((u32 *)pd, (u32 *)ps, w/2, p_05_round);
				pd += g_screen_ppitch;
				ps += w;
			}
	}

	if (PicoIn.AHW & PAHW_PICO) {
		int h = currentConfig.vscaling == EOPT_SCALE_SW ? 240:out_h;
		int w = currentConfig.scaling == EOPT_SCALE_SW ? 320:out_w;
		u16 *pd = screen_buffer(g_screen_ptr) + out_y*g_screen_ppitch + out_x;

		if (pico_inp_mode)
			emu_pico_overlay(pd, w, h, g_screen_ppitch);
		if (pico_inp_mode /*== 2 || overlay*/)
			draw_pico_ptr();
	}

	// draw virtual keyboard on display
	if (kbd_mode && currentConfig.keyboard == 2 && vkbd)
		vkbd_draw(vkbd);

	if (notice)
		emu_osd_text16(4, g_screen_height - 8, notice);
	if (currentConfig.EmuOpt & EOPT_SHOW_FPS)
		emu_osd_text16(g_screen_width - 60, g_screen_height - 8, fps);
	if ((PicoIn.AHW & PAHW_MCD) && (currentConfig.EmuOpt & EOPT_EN_CD_LEDS))
		draw_cd_leds();
}

void plat_video_set_buffer(void *buf)
{
	if (is_16bit_mode())
		PicoDrawSetOutBuf(screen_buffer(buf), g_screen_ppitch * 2);
}

static void apply_renderer(void)
{
	PicoIn.opt |= POPT_DIS_32C_BORDER;
	PicoIn.opt &= ~(POPT_ALT_RENDERER|POPT_EN_SOFTSCALE);
	if (is_16bit_mode()) {
		if (currentConfig.scaling == EOPT_SCALE_SW)
			PicoIn.opt |= POPT_EN_SOFTSCALE;
		PicoIn.filter = currentConfig.filter;
	}

	switch (get_renderer()) {
	case RT_16BIT:
		// 32X uses line mode for vscaling with accurate renderer, since
		// the MD VDP layer must be unscaled and merging the scaled 32X
		// image data will fail.
		PicoDrawSetOutFormat(PDF_RGB555,
			(PicoIn.AHW & PAHW_32X) && currentConfig.vscaling);
		PicoDrawSetOutBuf(screen_buffer(g_screen_ptr), g_screen_ppitch * 2);
		break;
	case RT_8BIT_ACC:
		// for simplification the 8 bit accurate renderer uses the same
		// storage format as the fast renderer
		PicoDrawSetOutFormat(PDF_8BIT, 0);
		PicoDrawSetOutBuf(Pico.est.Draw2FB, 328);
		break;
	case RT_8BIT_FAST:
		PicoIn.opt |=  POPT_ALT_RENDERER;
		PicoDrawSetOutFormat(PDF_NONE, 0);
		break;
	}

	if (PicoIn.AHW & PAHW_32X)
		PicoDrawSetOutBuf(screen_buffer(g_screen_ptr), g_screen_ppitch * 2);
	Pico.m.dirtyPal = 1;
}

void plat_video_toggle_renderer(int change, int is_menu)
{
	change_renderer(change);
	plat_video_clear_buffers();

	if (!is_menu) {
		apply_renderer();

		if (PicoIn.AHW & PAHW_32X)
			emu_status_msg(renderer_names32x[get_renderer()]);
		else
			emu_status_msg(renderer_names[get_renderer()]);
	}
}

void plat_status_msg_clear(void)
{
	plat_video_clear_status();
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
	plat_status_msg_busy_next(msg);
}

void plat_status_msg_busy_done(void)
{
}

void plat_update_volume(int has_changed, int is_up)
{
}

void pemu_sound_start(void)
{
	emu_sound_start();
}

void plat_debug_cat(char *str)
{
}

void pemu_forced_frame(int no_scale, int do_emu)
{
	int hs = currentConfig.scaling, vs = currentConfig.vscaling;

	// create centered and sw scaled (if scaling enabled) 16 bit output
	PicoIn.opt &= ~POPT_DIS_32C_BORDER;
	Pico.m.dirtyPal = 1;
	if (currentConfig.scaling)  currentConfig.scaling  = EOPT_SCALE_SW;
	if (currentConfig.vscaling) currentConfig.vscaling = EOPT_SCALE_SW;

	// render a frame in 16 bit mode
	render_bg = 1;
	emu_cmn_forced_frame(no_scale, do_emu, screen_buffer(g_screen_ptr));
	render_bg = 0;

	g_menubg_src_ptr = realloc(g_menubg_src_ptr, g_screen_height * g_screen_ppitch * 2);
	memcpy(g_menubg_src_ptr, g_screen_ptr, g_screen_height * g_screen_ppitch * 2);
	g_menubg_src_w = g_screen_width;
	g_menubg_src_h = g_screen_height;
	g_menubg_src_pp = g_screen_ppitch;

	currentConfig.scaling = hs, currentConfig.vscaling = vs;
}

/* vertical sw scaling, 16 bit mode */
static int vscale_state;

static int cb_vscaling_begin(unsigned int line)
{
	// at start of new frame?
	if (line <= out_y) {
		// set y frame offset (see emu_video_mode_change)
		Pico.est.DrawLineDest = screen_buffer(g_screen_ptr) +
				(out_y * g_screen_ppitch /*+ out_x*/);
		vscale_state = 0;
		return out_y - line;
	} else if (line > out_y + out_h)
		return 1;

	return 0;
}

static int cb_vscaling_nop(unsigned int line)
{
	return 0;
}

static int cb_vscaling_end(unsigned int line)
{
	u16 *dest = (u16 *)Pico.est.DrawLineDest + out_x;
	// helpers for 32 bit operation (2 pixels at once):
	u32 *dest32 = (u32 *)dest;
	int pp = g_screen_ppitch;

	if (out_h == 144)
	  switch (currentConfig.filter) {
	  case 0: v_upscale_nn_3_5(dest32, pp/2, out_w/2, vscale_state);
		  break;
	  default: v_upscale_snn_3_5(dest32, pp/2, out_w/2, vscale_state);
		  break;
	  }
	else
	  switch (currentConfig.filter) {
	  case 3: v_upscale_bl4_16_17(dest32, pp/2, out_w/2, vscale_state);
		  break;
	  case 2: v_upscale_bl2_16_17(dest32, pp/2, out_w/2, vscale_state);
		  break;
	  case 1: v_upscale_snn_16_17(dest32, pp/2, out_w/2, vscale_state);
		  break;
	  default: v_upscale_nn_16_17(dest32, pp/2, out_w/2, vscale_state);
		  break;
	  }
	Pico.est.DrawLineDest = (u16 *)dest32 - out_x;
	return 0;
}

void emu_video_mode_change(int start_line, int line_count, int start_col, int col_count)
{
	// relative position in core fb and screen fb
	out_y = start_line; out_x = start_col;
	out_h = line_count; out_w = col_count;

	if (! render_bg)
		plat_video_loop_prepare(); // recalculates g_screen_w/h
	PicoDrawSetCallbacks(NULL, NULL);
	// center output in screen
	screen_w = g_screen_width,  screen_x = (screen_w - out_w)/2;
	screen_h = g_screen_height, screen_y = (screen_h - out_h)/2;

	switch (currentConfig.scaling) {
	case EOPT_SCALE_HW:
		// mind aspect ratio for SMS with 1st column blanked
		screen_w = (out_w == 248 ? 256 : out_w);
		screen_x = (screen_w - out_w)/2;
		break;
	case EOPT_SCALE_SW:
		screen_x = (screen_w - 320)/2;
		break;
	}
	switch (currentConfig.vscaling) {
	case EOPT_SCALE_HW:
		screen_h = (out_h < 224 && out_h > 144 ? 224 : out_h);
		screen_y = 0;
		// NTSC always has 224 visible lines, anything smaller has bars
		if (out_h < 224 && out_h > 144)
			screen_y += (224 - out_h)/2;
		// handle vertical centering for 16 bit mode
		if (is_16bit_mode())
			PicoDrawSetCallbacks(cb_vscaling_begin,cb_vscaling_nop);
		break;
	case EOPT_SCALE_SW:
		screen_y = (screen_h - 240)/2 + (out_h < 240 && out_h > 144);
		// NTSC always has 224 visible lines, anything smaller has bars
		if (out_h < 224 && out_h > 144)
			screen_y += (224 - out_h)/2;
		// in 16 bit mode sw scaling is divided between core and platform
		if (is_16bit_mode() && out_h < 240)
			PicoDrawSetCallbacks(cb_vscaling_begin,cb_vscaling_end);
		break;
	}

	if (! render_bg)
		plat_video_set_size(screen_w, screen_h);

	if (screen_w < g_screen_width)
		screen_x = (g_screen_width  - screen_w)/2;
	if (screen_h < g_screen_height) {
		screen_y = (g_screen_height - screen_h)/2;
		// NTSC always has 224 visible lines, anything smaller has bars
		if (out_h < 224 && out_h > 144)
			screen_y += (224 - out_h)/2;
	}

	plat_video_set_buffer(g_screen_ptr);

	// create a backing buffer for emulating the bad GG lcd display
	if (currentConfig.ghosting && out_h == 144) {
		int h = currentConfig.vscaling == EOPT_SCALE_SW ? 240:out_h;
		int w = currentConfig.scaling == EOPT_SCALE_SW ? 320:out_w;
		ghost_buf = realloc(ghost_buf, w * h * 2);
		memset(ghost_buf, 0, w * h * 2);
	}

	// clear whole screen in all buffers
	if (!is_16bit_mode())
		memset32(Pico.est.Draw2FB, 0xe0e0e0e0, (320+8) * (8+240+8) / 4);
	plat_video_clear_buffers();
}

void pemu_loop_prep(void)
{
	apply_renderer();
	plat_video_clear_buffers();
}

void pemu_loop_end(void)
{
	/* do one more frame for menu bg */
	plat_video_set_shadow(320, 240);
	pemu_forced_frame(0, 1);
	if (ghost_buf) {
		free(ghost_buf);
		ghost_buf = NULL;
	}
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

void *plat_mem_get_for_drc(size_t size)
{
#ifdef MAP_JIT
	// newer versions of OSX, IOS or TvOS need this
	return plat_mmap(0, size, 1, 0);
#else
	return NULL;
#endif
}
