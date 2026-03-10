/*
 * PicoDrive
 * (C) notaz, 2013
 * (C) irixxxx, 2020-2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>

#include "../libpicofe/input.h"
#include "../libpicofe/plat.h"
#include "../libpicofe/plat_sdl.h"
#include "../libpicofe/in_sdl.h"
#include "../libpicofe/gl.h"
#include "emu.h"
#include "menu_pico.h"
#include "input_pico.h"
#include "plat_sdl.h"
#include "version.h"

#include <pico/pico_int.h>

static void *shadow_fb;
static int shadow_size;
static struct area { int w, h; } area;

static struct in_pdata in_sdl_platform_data;

static int sound_rates[] = { 8000, 11025, 16000, 22050, 32000, 44100, 53000, -1 };
struct plat_target plat_target = { .sound_rates = sound_rates };

#if defined __MIYOO__
const char *plat_device = "miyoo";
#elif defined __GCW0__
const char *plat_device = "gcw0";
#elif defined __RETROFW__
const char *plat_device = "retrofw";
#elif defined __DINGUX__
const char *plat_device = "dingux";
#else
const char *plat_device = "";
#endif

int plat_parse_arg(int argc, char *argv[], int *x)
{
#if defined __OPENDINGUX__
	if (*plat_device == '\0' && strcasecmp(argv[*x], "-device") == 0) {
		plat_device = argv[++(*x)];
		return 0;
	}
#endif
	return 1;
}

void plat_early_init(void)
{
}

int plat_target_init(void)
{
#if defined __ODBETA__
	if (*plat_device == '\0') {
		/* ODbeta should always have a device tree, get the model info from there */
		FILE *f = fopen("/proc/device-tree/compatible", "r");
		if (f) {
			char buf[10];
			int c = fread(buf, 1, sizeof(buf), f);
			if (strncmp(buf, "gcw,", 4) == 0)
				plat_device = "gcw0";
		}
	}
#endif
	return 0;
}

void plat_target_finish(void)
{
}

/* YUV stuff */
static int yuv_ry[32], yuv_gy[32], yuv_by[32];
static unsigned char yuv_u[32 * 2], yuv_v[32 * 2];
static unsigned char yuv_y[256];
static struct uyvy { uint32_t y:8; uint32_t vyu:24; } yuv_uyvy[65536];

void bgr_to_uyvy_init(void)
{
	int i, v;

	/* init yuv converter:
	    y0 = (int)((0.299f * r0) + (0.587f * g0) + (0.114f * b0));
	    y1 = (int)((0.299f * r1) + (0.587f * g1) + (0.114f * b1));
	    u = (int)(8 * 0.565f * (b0 - y0)) + 128;
	    v = (int)(8 * 0.713f * (r0 - y0)) + 128;
	*/
	for (i = 0; i < 32; i++) {
		yuv_ry[i] = (int)(0.299f * i * 65536.0f + 0.5f);
		yuv_gy[i] = (int)(0.587f * i * 65536.0f + 0.5f);
		yuv_by[i] = (int)(0.114f * i * 65536.0f + 0.5f);
	}
	for (i = -32; i < 32; i++) {
		v = (int)(8 * 0.565f * i) + 128;
		if (v < 0)
			v = 0;
		if (v > 255)
			v = 255;
		yuv_u[i + 32] = v;
		v = (int)(8 * 0.713f * i) + 128;
		if (v < 0)
			v = 0;
		if (v > 255)
			v = 255;
		yuv_v[i + 32] = v;
	}
	// valid Y range seems to be 16..235
	for (i = 0; i < 256; i++) {
		yuv_y[i] = 16 + 219 * i / 32;
	}
	// everything combined into one large array for speed
	for (i = 0; i < 65536; i++) {
		int r = (i >> 11) & 0x1f, g = (i >> 6) & 0x1f, b = (i >> 0) & 0x1f;
		int y = (yuv_ry[r] + yuv_gy[g] + yuv_by[b]) >> 16;
		yuv_uyvy[i].y = yuv_y[y];
#if CPU_IS_LE
		yuv_uyvy[i].vyu = (yuv_v[r-y + 32] << 16) | (yuv_y[y] << 8) | yuv_u[b-y + 32];
#else
		yuv_uyvy[i].vyu = (yuv_v[b-y + 32] << 16) | (yuv_y[y] << 8) | yuv_u[r-y + 32];
#endif
	}
}

void rgb565_to_uyvy(void *d, const void *s, int w, int h, int pitch, int dpitch, int x2)
{
	uint32_t *dst = d;
	const uint16_t *src = s;
	int i;

	if (x2) while (h--) {
		for (i = w; i >= 4; src += 4, dst += 4, i -= 4)
		{
			struct uyvy *uyvy0 = yuv_uyvy + src[0], *uyvy1 = yuv_uyvy + src[1];
			struct uyvy *uyvy2 = yuv_uyvy + src[2], *uyvy3 = yuv_uyvy + src[3];
#if CPU_IS_LE
			dst[0] = (uyvy0->y << 24) | uyvy0->vyu;
			dst[1] = (uyvy1->y << 24) | uyvy1->vyu;
			dst[2] = (uyvy2->y << 24) | uyvy2->vyu;
			dst[3] = (uyvy3->y << 24) | uyvy3->vyu;
#else
			dst[0] = uyvy0->y | (uyvy0->vyu << 8);
			dst[1] = uyvy1->y | (uyvy1->vyu << 8);
			dst[2] = uyvy2->y | (uyvy2->vyu << 8);
			dst[3] = uyvy3->y | (uyvy3->vyu << 8);
#endif
		}
		src += pitch - (w-i);
		dst += (dpitch - 2*(w-i))/2;
	} else while (h--) {
		for (i = w; i >= 4; src += 4, dst += 2, i -= 4)
		{
			struct uyvy *uyvy0 = yuv_uyvy + src[0], *uyvy1 = yuv_uyvy + src[1];
			struct uyvy *uyvy2 = yuv_uyvy + src[2], *uyvy3 = yuv_uyvy + src[3];
#if CPU_IS_LE
			dst[0] = (uyvy1->y << 24) | uyvy0->vyu;
			dst[1] = (uyvy3->y << 24) | uyvy2->vyu;
#else
			dst[0] = uyvy1->y | (uyvy0->vyu << 8);
			dst[1] = uyvy3->y | (uyvy2->vyu << 8);
#endif
		}
		src += pitch - (w-i);
		dst += (dpitch - (w-i))/2;
	}
}

void copy_intscale(void *dst, int w, int h, int pp, void *src, int sw, int sh, int spp)
{
	int xf = w / sw, yf = h / sh, f = xf < yf ? xf : yf;
	int wf = f * sw, hf = f * sh;
	int x = (w - wf)/2, y = (h - hf)/2;
	uint16_t *p = (uint16_t *)dst;
	uint16_t *q = (uint16_t *)src;

	// copy 16bit image with scaling by an integer factor
	int i, j, k, l;
	p += y * pp + x;
	for (i = 0; i < sh; i++) {
		for (j = 0; j < sw; j++, q++)
			for (l = 0; l < f; l++)
				*p++ = *q;
		p += pp - wf;
		q += spp - sw;
		for (k = 1; k < f; k++) {
			memcpy(p, p-pp, wf*2);
			p += pp;
		}
	}
}

static int clear_buf_cnt, clear_stat_cnt;

static void resize_buffers(void)
{
	// make sure the shadow buffers are big enough in case of resize
	if (shadow_size < g_menuscreen_w * g_menuscreen_h * 2) {
		shadow_size = g_menuscreen_w * g_menuscreen_h * 2;
		shadow_fb = realloc(shadow_fb, shadow_size);
		g_menubg_ptr = realloc(g_menubg_ptr, shadow_size);
	}
}

void plat_video_set_size(int w, int h)
{
	if ((plat_sdl_overlay || plat_sdl_gl_active) &&
	    (w != g_screen_width || h != g_screen_height)) {
		// scale to the window, but mind aspect ratio (scaled to 4:3)
		if (g_menuscreen_w * 3/4 >= g_menuscreen_h)
			w = (w * 3 * g_menuscreen_w/g_menuscreen_h)/4 & ~1;
		else
			h = (h * 4 * g_menuscreen_h/g_menuscreen_w)/3 & ~1;
	}

	if (area.w != w || area.h != h) {
		area = (struct area) { w, h };

		if (plat_sdl_overlay || plat_sdl_gl_active || !plat_sdl_is_windowed()) {
			// create surface for overlays, or try using a hw scaler
			if (plat_sdl_change_video_mode(w, h, 0) < 0) {
				// failed, revert to original resolution
				area = (struct area) { g_screen_width,g_screen_height };
				plat_sdl_change_video_mode(g_screen_width, g_screen_height, 0);
			}
		}
		if (plat_sdl_overlay || plat_sdl_gl_active ||
		    (plat_sdl_screen->w >= 320*2 || plat_sdl_screen->h >= 240*2 ||
		     plat_sdl_screen->w < 320 || plat_sdl_screen->h < 240)) {
			// use shadow buffer for overlays and sw integer scaling
			g_screen_width = area.w;
			g_screen_height = area.h;
			g_screen_ppitch = area.w;
			g_screen_ptr = shadow_fb;
		} else {
			// unscaled SDL window buffer can be used directly
			g_screen_width = plat_sdl_screen->w;
			g_screen_height = plat_sdl_screen->h;
			g_screen_ppitch = plat_sdl_screen->pitch/2;
			g_screen_ptr = plat_sdl_screen->pixels;
		}
	}
}

void plat_video_set_shadow(int w, int h)
{
	g_screen_width = w;
	g_screen_height = h;
	g_screen_ppitch = w;
	g_screen_ptr = shadow_fb;
}

void plat_video_flip(void)
{
	resize_buffers();

	if (plat_sdl_overlay != NULL) {
		SDL_Rect dstrect =
			{ 0, 0, plat_sdl_screen->w, plat_sdl_screen->h };
		SDL_LockYUVOverlay(plat_sdl_overlay);
		if (area.w <= plat_sdl_overlay->w && area.h <= plat_sdl_overlay->h)
			rgb565_to_uyvy(plat_sdl_overlay->pixels[0], shadow_fb,
					area.w, area.h, g_screen_ppitch,
					plat_sdl_overlay->pitches[0]/2,
					plat_sdl_overlay->w >= 2*area.w);
		SDL_UnlockYUVOverlay(plat_sdl_overlay);
		SDL_DisplayYUVOverlay(plat_sdl_overlay, &dstrect);
	}
	else if (plat_sdl_gl_active) {
		gl_flip(shadow_fb, g_screen_ppitch, g_screen_height);
	}
	else {
		int copy = g_screen_ptr != plat_sdl_screen->pixels;
		if (copy)
			copy_intscale(plat_sdl_screen->pixels, plat_sdl_screen->w,
				plat_sdl_screen->h, plat_sdl_screen->pitch/2,
				shadow_fb, area.w, area.h, area.w);

		if (SDL_MUSTLOCK(plat_sdl_screen))
			SDL_UnlockSurface(plat_sdl_screen);
		SDL_Flip(plat_sdl_screen);

		// take over resized settings for the physical SDL surface
		if ((plat_sdl_screen->w != g_menuscreen_w ||
		    plat_sdl_screen->h != g_menuscreen_h)  && plat_sdl_is_windowed() &&
		    SDL_WM_GrabInput(SDL_GRAB_ON) == SDL_GRAB_ON) {
			plat_sdl_change_video_mode(g_menuscreen_w, g_menuscreen_h, 1);
			SDL_WM_GrabInput(SDL_GRAB_OFF);
			g_menuscreen_pp = plat_sdl_screen->pitch/2;

			// force upper layer to use new dimensions
			plat_video_set_shadow(g_screen_width, g_screen_height);
			plat_video_set_buffer(g_screen_ptr);
			rendstatus_old = -1;
		} else if (!copy) {
			g_screen_ppitch = plat_sdl_screen->pitch/2;
			g_screen_ptr = plat_sdl_screen->pixels;
			plat_video_set_buffer(g_screen_ptr);
		}

		if (SDL_MUSTLOCK(plat_sdl_screen))
			SDL_LockSurface(plat_sdl_screen);

		if (clear_buf_cnt) {
			memset(g_screen_ptr, 0, plat_sdl_screen->pitch*plat_sdl_screen->h);
			clear_buf_cnt--;
		}
	}

	// for overlay/gl modes buffer ptr may change on resize
	if ((plat_sdl_overlay || plat_sdl_gl_active) &&
	    (g_screen_ptr != shadow_fb || g_screen_ppitch != g_screen_width)) {
		g_screen_ppitch = g_screen_width;
		g_screen_ptr = shadow_fb;
		plat_video_set_buffer(g_screen_ptr);
	}
	if (clear_stat_cnt) {
		unsigned short *d = (unsigned short *)g_screen_ptr + g_screen_ppitch * g_screen_height;
		int l = g_screen_ppitch * 8;
		memset((int *)(d - l), 0, l * 2);
		clear_stat_cnt--;
	}
}

void plat_video_wait_vsync(void)
{
}

void plat_video_clear_status(void)
{
	clear_stat_cnt = 3; // do it thrice in case of triple buffering
}

void plat_video_clear_buffers(void)
{
	memset(shadow_fb, 0, g_menuscreen_w * g_menuscreen_h * 2);
	memset(plat_sdl_screen->pixels, 0, plat_sdl_screen->pitch*plat_sdl_screen->h);
	clear_buf_cnt = 3; // do it thrice in case of triple buffering
}

void plat_video_menu_update(void)
{
	// WM may grab input while resizing the window; our own window resizing
	// is only safe if the WM isn't active anymore, so try to grab input.
	if (plat_sdl_is_windowed() && SDL_WM_GrabInput(SDL_GRAB_ON) == SDL_GRAB_ON) {
		// w/h might change in resize callback
		int w, h;
		do {
			w = g_menuscreen_w, h = g_menuscreen_h;
			plat_sdl_change_video_mode(w, h, 1);
		} while (w != g_menuscreen_w || h != g_menuscreen_h);
		SDL_WM_GrabInput(SDL_GRAB_OFF);
	}

	// update pitch as it is needed by the menu bg scaler
	if (plat_sdl_overlay || plat_sdl_gl_active)
		g_menuscreen_pp = g_menuscreen_w;
	else
		g_menuscreen_pp = plat_sdl_screen->pitch / 2;
}

void plat_video_menu_enter(int is_rom_loaded)
{
	if (SDL_MUSTLOCK(plat_sdl_screen))
		SDL_UnlockSurface(plat_sdl_screen);
}

void plat_video_menu_begin(void)
{
	plat_video_menu_update(); // just in case

	if (plat_sdl_overlay || plat_sdl_gl_active)
		g_menuscreen_ptr = shadow_fb;
	else {
		if (SDL_MUSTLOCK(plat_sdl_screen))
			SDL_LockSurface(plat_sdl_screen);
		g_menuscreen_ptr = plat_sdl_screen->pixels;
	}
}

void plat_video_menu_end(void)
{
	if (plat_sdl_overlay != NULL) {
		SDL_Rect dstrect =
			{ 0, 0, plat_sdl_screen->w, plat_sdl_screen->h };

		SDL_LockYUVOverlay(plat_sdl_overlay);
		if (g_menuscreen_w <= plat_sdl_overlay->w && g_menuscreen_h <= plat_sdl_overlay->h)
			rgb565_to_uyvy(plat_sdl_overlay->pixels[0], shadow_fb,
				g_menuscreen_w, g_menuscreen_h, g_menuscreen_pp,
				plat_sdl_overlay->pitches[0]/2,
				plat_sdl_overlay->w >= 2 * g_menuscreen_w);
		SDL_UnlockYUVOverlay(plat_sdl_overlay);

		SDL_DisplayYUVOverlay(plat_sdl_overlay, &dstrect);
	}
	else if (plat_sdl_gl_active) {
		gl_flip(g_menuscreen_ptr, g_menuscreen_pp, g_menuscreen_h);
	}
	else {
		if (SDL_MUSTLOCK(plat_sdl_screen))
			SDL_UnlockSurface(plat_sdl_screen);
		SDL_Flip(plat_sdl_screen);
	}
	g_menuscreen_ptr = NULL;
}

void plat_video_menu_leave(void)
{
}

void plat_video_loop_prepare(void)
{
	// take over any new vout settings
	area = (struct area) { 0, 0 };
	plat_sdl_change_video_mode(0, 0, 0);
	resize_buffers();

	// switch over to scaled output if available, but keep the aspect ratio
	if (plat_sdl_overlay || plat_sdl_gl_active) {
		if (g_menuscreen_w * 240 >= g_menuscreen_h * 320) {
			g_screen_width = (240 * g_menuscreen_w/g_menuscreen_h) & ~1;
			g_screen_height= 240;
		} else {
			g_screen_width = 320;
			g_screen_height= (320 * g_menuscreen_h/g_menuscreen_w) & ~1;
		}
		g_screen_ppitch = g_screen_width;
		plat_video_set_size(g_screen_width, g_screen_height);
		g_screen_ptr = shadow_fb;
	}
	else {
		plat_video_set_size(g_menuscreen_w, g_menuscreen_h);
		if (plat_sdl_is_windowed() &&
		    (plat_sdl_screen->w >= 320*2 || plat_sdl_screen->h >= 240*2 ||
		     plat_sdl_screen->w < 320 || plat_sdl_screen->h < 240)) {
			// shadow buffer for integer scaling
			g_screen_width = 320;
			g_screen_height = 240;
			g_screen_ppitch = 320;
			g_screen_ptr = shadow_fb;
		} else {
			// no scaling needed, use screen buffer directly
			g_screen_width = plat_sdl_screen->w;
			g_screen_height = plat_sdl_screen->h;
			g_screen_ppitch = plat_sdl_screen->pitch/2;
			g_screen_ptr = plat_sdl_screen->pixels;
		}

		if (SDL_MUSTLOCK(plat_sdl_screen))
			SDL_LockSurface(plat_sdl_screen);
	}

	plat_video_set_buffer(g_screen_ptr);
}

static void plat_sdl_resize(int w, int h)
{
	// take over new settings
#if defined(__OPENDINGUX__)
	if (currentConfig.vscaling != EOPT_SCALE_HW &&
	    plat_sdl_screen->w == 320 && plat_sdl_screen->h == 480) {
		g_menuscreen_h = 240;
		g_menuscreen_w = 320;
	} else
#endif
	{
		g_menuscreen_h = plat_sdl_screen->h;
		g_menuscreen_w = plat_sdl_screen->w;
#if 0 // auto resizing may be nice, but creates problems on some SDL platforms
		if (!plat_sdl_overlay && !plat_sdl_gl_active &&
		    plat_sdl_is_windowed() && !plat_sdl_is_fullscreen()) {
			// in SDL window mode, adapt window to integer scaling
			if (g_menuscreen_w * 3/4 >= g_menuscreen_h)
				g_menuscreen_w = g_menuscreen_h * 4/3;
			else
				g_menuscreen_h = g_menuscreen_w * 3/4;
			g_menuscreen_w = g_menuscreen_w/320*320;
			g_menuscreen_h = g_menuscreen_h/240*240;
			if (g_menuscreen_w == 0) {
				g_menuscreen_w = 320;
				g_menuscreen_h = 240;
			}
		}
#endif
	}

	resize_buffers();
	rendstatus_old = -1;
}

static void plat_sdl_quit(void)
{
	// for now..
	exit(1);
}

void plat_init(void)
{
	int ret;

	ret = plat_sdl_init();
	if (ret != 0)
		exit(1);

#if defined(__OPENDINGUX__)
	// opendingux on JZ47x0 may falsely report a HW overlay, fix to window
	plat_target.vout_method = 0;
#elif !defined(__MIYOO__) && !defined(__RETROFW__) && !defined(__DINGUX__)
	if (! plat_sdl_is_windowed())
#endif
		SDL_ShowCursor(0);

	plat_sdl_quit_cb = plat_sdl_quit;
	plat_sdl_resize_cb = plat_sdl_resize;

	SDL_WM_SetCaption("PicoDrive " VERSION, NULL);

	g_menuscreen_pp = g_menuscreen_w;
	g_menuscreen_ptr = NULL;

	shadow_size = g_menuscreen_w * g_menuscreen_h * 2;
	if (shadow_size < 320 * 480 * 2)
		shadow_size = 320 * 480 * 2;

	shadow_fb = calloc(1, shadow_size);
	g_menubg_ptr = calloc(1, shadow_size);
	if (shadow_fb == NULL || g_menubg_ptr == NULL) {
		fprintf(stderr, "OOM\n");
		exit(1);
	}

	g_screen_width = 320;
	g_screen_height = 240;
	g_screen_ppitch = 320;
	g_screen_ptr = shadow_fb;

	plat_target_setup_input();
	in_sdl_platform_data.defbinds = in_sdl_defbinds,
	in_sdl_platform_data.kmap_size = in_sdl_key_map_sz,
	in_sdl_platform_data.key_map = in_sdl_key_map,
	in_sdl_platform_data.jmap_size = in_sdl_joy_map_sz,
	in_sdl_platform_data.joy_map = in_sdl_joy_map,
	in_sdl_platform_data.key_names = in_sdl_key_names,
	in_sdl_platform_data.kbd_map = in_sdl_kbd_map,
	in_sdl_init(&in_sdl_platform_data, plat_sdl_event_handler);
	in_probe();

	bgr_to_uyvy_init();
	linux_menu_init();
}

void plat_finish(void)
{
	free(shadow_fb);
	shadow_fb = NULL;
	free(g_menubg_ptr);
	g_menubg_ptr = NULL;
	plat_sdl_finish();
}
