#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <linux/input.h>

#include "../common/emu.h"
#include "../common/menu_pico.h"
#include "../common/input_pico.h"
#include "../libpicofe/input.h"
#include "../libpicofe/plat.h"
#include "../libpicofe/linux/in_evdev.h"
#include "../libpicofe/gp2x/soc.h"
#include "../libpicofe/gp2x/plat_gp2x.h"
#include "../libpicofe/gp2x/in_gp2x.h"
#include "940ctl.h"
#include "warm.h"
#include "plat.h"

#include <pico/pico.h>

/* GP2X local */
int gp2x_current_bpp;
void *gp2x_screens[4];

void (*gp2x_video_flip)(void);
void (*gp2x_video_flip2)(void);
void (*gp2x_video_changemode_ll)(int bpp, int is_pal);
void (*gp2x_video_setpalette)(int *pal, int len);
void (*gp2x_video_RGB_setscaling)(int ln_offs, int W, int H);
void (*gp2x_video_wait_vsync)(void);

static struct in_default_bind in_evdev_defbinds[] =
{
	/* MXYZ SACB RLDU */
	{ KEY_UP,	IN_BINDTYPE_PLAYER12, GBTN_UP },
	{ KEY_DOWN,	IN_BINDTYPE_PLAYER12, GBTN_DOWN },
	{ KEY_LEFT,	IN_BINDTYPE_PLAYER12, GBTN_LEFT },
	{ KEY_RIGHT,	IN_BINDTYPE_PLAYER12, GBTN_RIGHT },
	{ KEY_A,	IN_BINDTYPE_PLAYER12, GBTN_A },
	{ KEY_S,	IN_BINDTYPE_PLAYER12, GBTN_B },
	{ KEY_D,	IN_BINDTYPE_PLAYER12, GBTN_C },
	{ KEY_ENTER,	IN_BINDTYPE_PLAYER12, GBTN_START },
	{ KEY_BACKSLASH, IN_BINDTYPE_EMU, PEVB_MENU },
	/* Caanoo */
	{ BTN_TRIGGER,	IN_BINDTYPE_PLAYER12, GBTN_A },
	{ BTN_THUMB,	IN_BINDTYPE_PLAYER12, GBTN_B },
	{ BTN_THUMB2,	IN_BINDTYPE_PLAYER12, GBTN_C },
	{ BTN_BASE3,	IN_BINDTYPE_PLAYER12, GBTN_START },
	{ BTN_TOP2,	IN_BINDTYPE_EMU, PEVB_STATE_SAVE },
	{ BTN_PINKIE,	IN_BINDTYPE_EMU, PEVB_STATE_LOAD },
	{ BTN_BASE,	IN_BINDTYPE_EMU, PEVB_MENU },
	{ 0, 0, 0 }
};

static struct in_default_bind in_gp2x_defbinds[] =
{
	{ GP2X_BTN_UP,    IN_BINDTYPE_PLAYER12, GBTN_UP },
	{ GP2X_BTN_DOWN,  IN_BINDTYPE_PLAYER12, GBTN_DOWN },
	{ GP2X_BTN_LEFT,  IN_BINDTYPE_PLAYER12, GBTN_LEFT },
	{ GP2X_BTN_RIGHT, IN_BINDTYPE_PLAYER12, GBTN_RIGHT },
	{ GP2X_BTN_A,     IN_BINDTYPE_PLAYER12, GBTN_A },
	{ GP2X_BTN_X,     IN_BINDTYPE_PLAYER12, GBTN_B },
	{ GP2X_BTN_B,     IN_BINDTYPE_PLAYER12, GBTN_C },
	{ GP2X_BTN_START, IN_BINDTYPE_PLAYER12, GBTN_START },
	{ GP2X_BTN_Y,     IN_BINDTYPE_EMU, PEVB_SWITCH_RND },
	{ GP2X_BTN_L,     IN_BINDTYPE_EMU, PEVB_STATE_SAVE },
	{ GP2X_BTN_R,     IN_BINDTYPE_EMU, PEVB_STATE_LOAD },
	{ GP2X_BTN_VOL_DOWN, IN_BINDTYPE_EMU, PEVB_VOL_DOWN },
	{ GP2X_BTN_VOL_UP,   IN_BINDTYPE_EMU, PEVB_VOL_UP },
	{ GP2X_BTN_SELECT,   IN_BINDTYPE_EMU, PEVB_MENU },
	{ 0, 0, 0 }
};

static const struct menu_keymap key_pbtn_map[] =
{
	{ KEY_UP,	PBTN_UP },
	{ KEY_DOWN,	PBTN_DOWN },
	{ KEY_LEFT,	PBTN_LEFT },
	{ KEY_RIGHT,	PBTN_RIGHT },
	/* Caanoo */
	{ BTN_THUMB2,	PBTN_MOK },
	{ BTN_THUMB,	PBTN_MBACK },
	{ BTN_TRIGGER,	PBTN_MA2 },
	{ BTN_TOP,	PBTN_MA3 },
	{ BTN_BASE,	PBTN_MENU },
	{ BTN_TOP2,	PBTN_L },
	{ BTN_PINKIE,	PBTN_R },
	/* "normal" keyboards */
	{ KEY_ENTER,	PBTN_MOK },
	{ KEY_ESC,	PBTN_MBACK },
	{ KEY_SEMICOLON,  PBTN_MA2 },
	{ KEY_APOSTROPHE, PBTN_MA3 },
	{ KEY_BACKSLASH,  PBTN_MENU },
	{ KEY_LEFTBRACE,  PBTN_L },
	{ KEY_RIGHTBRACE, PBTN_R },
};

static const struct in_pdata gp2x_evdev_pdata = {
	.defbinds = in_evdev_defbinds,
	.key_map = key_pbtn_map,
	.kmap_size = sizeof(key_pbtn_map) / sizeof(key_pbtn_map[0]),
};

void gp2x_video_changemode(int bpp, int is_pal)
{
	gp2x_video_changemode_ll(bpp, is_pal);

	gp2x_current_bpp = bpp < 0 ? -bpp : bpp;
}

static void gp2x_memcpy_buffers(int buffers, void *data, int offset, int len)
{
	char *dst;
	if (buffers & (1<<0)) { dst = (char *)gp2x_screens[0] + offset; if (dst != data) memcpy(dst, data, len); }
	if (buffers & (1<<1)) { dst = (char *)gp2x_screens[1] + offset; if (dst != data) memcpy(dst, data, len); }
	if (buffers & (1<<2)) { dst = (char *)gp2x_screens[2] + offset; if (dst != data) memcpy(dst, data, len); }
	if (buffers & (1<<3)) { dst = (char *)gp2x_screens[3] + offset; if (dst != data) memcpy(dst, data, len); }
}

void gp2x_memcpy_all_buffers(void *data, int offset, int len)
{
	gp2x_memcpy_buffers(0xf, data, offset, len);
}

void gp2x_memset_all_buffers(int offset, int byte, int len)
{
	memset((char *)gp2x_screens[0] + offset, byte, len);
	memset((char *)gp2x_screens[1] + offset, byte, len);
	memset((char *)gp2x_screens[2] + offset, byte, len);
	memset((char *)gp2x_screens[3] + offset, byte, len);
}

void gp2x_make_fb_bufferable(int yes)
{
	int ret = 0;
	
	yes = yes ? 1 : 0;
	ret |= warm_change_cb_range(WCB_B_BIT, yes, gp2x_screens[0], 320*240*2);
	ret |= warm_change_cb_range(WCB_B_BIT, yes, gp2x_screens[1], 320*240*2);
	ret |= warm_change_cb_range(WCB_B_BIT, yes, gp2x_screens[2], 320*240*2);
	ret |= warm_change_cb_range(WCB_B_BIT, yes, gp2x_screens[3], 320*240*2);

	if (ret)
		fprintf(stderr, "could not make fb buferable.\n");
	else
		printf("made fb buferable.\n");
}

/* common */
void plat_video_menu_enter(int is_rom_loaded)
{
	if (gp2x_current_bpp != 16 || gp2x_dev_id == GP2X_DEV_WIZ) {
		/* try to switch nicely avoiding glitches */
		gp2x_video_wait_vsync();
		memset(gp2x_screens[0], 0, 320*240*2);
		memset(gp2x_screens[1], 0, 320*240*2);
		gp2x_video_flip2(); // might flip to fb2/3
		gp2x_video_flip2(); // ..so we do it again
	}
	else
		gp2x_video_flip2();

	// switch to 16bpp
	gp2x_video_changemode_ll(16, 0);
	gp2x_video_RGB_setscaling(0, 320, 240);
}

void plat_video_menu_begin(void)
{
	g_menuscreen_ptr = g_screen_ptr;
}

void plat_video_menu_end(void)
{
	gp2x_video_flip2();
}

void plat_video_menu_leave(void)
{
}

void plat_early_init(void)
{
	// just use gettimeofday until plat_init()
	gp2x_get_ticks_ms = plat_get_ticks_ms_good;
	gp2x_get_ticks_us = plat_get_ticks_us_good;
}

void plat_init(void)
{
	warm_init();

	switch (gp2x_dev_id) {
	case GP2X_DEV_GP2X:
		sharedmem940_init();
		vid_mmsp2_init();
		break;
	case GP2X_DEV_WIZ:
	case GP2X_DEV_CAANOO:
		vid_pollux_init();
		break;
	}

	g_menuscreen_w = 320;
	g_menuscreen_h = 240;
	gp2x_memset_all_buffers(0, 0, 320*240*2);

	gp2x_make_fb_bufferable(1);

	// use buffer2 for menubg to save mem (using only buffers 0, 1 in menu)
	g_menubg_ptr = gp2x_screens[2];

	flip_after_sync = 1;
	gp2x_menu_init();

	in_evdev_init(&gp2x_evdev_pdata);
	in_gp2x_init(in_gp2x_defbinds);
	in_probe();
	plat_target_setup_input();
}

void plat_finish(void)
{
	warm_finish();

	switch (gp2x_dev_id) {
	case GP2X_DEV_GP2X:
		sharedmem940_finish();
		vid_mmsp2_finish();
		break;
	case GP2X_DEV_WIZ:
	case GP2X_DEV_CAANOO:
		vid_pollux_finish();
		break;
	}
}
