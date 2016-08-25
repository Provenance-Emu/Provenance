/*
 * PicoDrive
 * (C) notaz, 2010,2011
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <linux/fb.h>
#include <linux/omapfb.h>
#include <linux/input.h>

#include "../common/emu.h"
#include "../common/arm_utils.h"
#include "../common/input_pico.h"
#include "../common/version.h"
#include "../libpicofe/input.h"
#include "../libpicofe/menu.h"
#include "../libpicofe/plat.h"
#include "../libpicofe/linux/in_evdev.h"
#include "../libpicofe/linux/sndout_oss.h"
#include "../libpicofe/linux/fbdev.h"
#include "../libpicofe/linux/xenv.h"
#include "plat.h"
#include "asm_utils.h"

#include <pico/pico_int.h>

#define LAYER_MEM_SIZE (320*240*2 * 4)

static struct vout_fbdev *main_fb, *layer_fb;
// g_layer_* - in use, g_layer_c* - configured custom
int g_layer_cx, g_layer_cy, g_layer_cw, g_layer_ch;
static int g_layer_x, g_layer_y;
static int g_layer_w = 320, g_layer_h = 240;
static int g_osd_fps_x, g_osd_y, doing_bg_frame;

static unsigned char __attribute__((aligned(4))) fb_copy[320 * 240 * 2];
static void *temp_frame;
const char *renderer_names[] = { NULL };
const char *renderer_names32x[] = { NULL };

static const char * const pandora_gpio_keys[KEY_MAX + 1] = {
	[0 ... KEY_MAX] = NULL,
	[KEY_UP]	= "Up",
	[KEY_LEFT]	= "Left",
	[KEY_RIGHT]	= "Right",
	[KEY_DOWN]	= "Down",
	[KEY_HOME]	= "A",
	[KEY_PAGEDOWN]	= "X",
	[KEY_END]	= "B",
	[KEY_PAGEUP]	= "Y",
	[KEY_RIGHTSHIFT]= "L",
	[KEY_RIGHTCTRL]	= "R",
	[KEY_LEFTALT]	= "Start",
	[KEY_LEFTCTRL]	= "Select",
	[KEY_MENU]	= "Pandora",
};

static struct in_default_bind in_evdev_defbinds[] =
{
	{ KEY_UP,	IN_BINDTYPE_PLAYER12, GBTN_UP },
	{ KEY_DOWN,	IN_BINDTYPE_PLAYER12, GBTN_DOWN },
	{ KEY_LEFT,	IN_BINDTYPE_PLAYER12, GBTN_LEFT },
	{ KEY_RIGHT,	IN_BINDTYPE_PLAYER12, GBTN_RIGHT },
	{ KEY_A,	IN_BINDTYPE_PLAYER12, GBTN_A },
	{ KEY_S,	IN_BINDTYPE_PLAYER12, GBTN_B },
	{ KEY_D,	IN_BINDTYPE_PLAYER12, GBTN_C },
	{ KEY_ENTER,	IN_BINDTYPE_PLAYER12, GBTN_START },
	{ KEY_F,	IN_BINDTYPE_EMU, PEVB_FF },
	{ KEY_BACKSPACE,IN_BINDTYPE_EMU, PEVB_FF },
	{ KEY_BACKSLASH,IN_BINDTYPE_EMU, PEVB_MENU },
	{ KEY_SPACE,	IN_BINDTYPE_EMU, PEVB_MENU },
	{ KEY_LEFTCTRL,	IN_BINDTYPE_EMU, PEVB_MENU },
	{ KEY_HOME,	IN_BINDTYPE_PLAYER12, GBTN_A },
	{ KEY_PAGEDOWN,	IN_BINDTYPE_PLAYER12, GBTN_B },
	{ KEY_END,	IN_BINDTYPE_PLAYER12, GBTN_C },
	{ KEY_LEFTALT,	IN_BINDTYPE_PLAYER12, GBTN_START },
	{ KEY_1,	IN_BINDTYPE_EMU, PEVB_STATE_SAVE },
	{ KEY_2,	IN_BINDTYPE_EMU, PEVB_STATE_LOAD },
	{ KEY_3,	IN_BINDTYPE_EMU, PEVB_SSLOT_PREV },
	{ KEY_4,	IN_BINDTYPE_EMU, PEVB_SSLOT_NEXT },
	{ KEY_5,	IN_BINDTYPE_EMU, PEVB_PICO_PPREV },
	{ KEY_6,	IN_BINDTYPE_EMU, PEVB_PICO_PNEXT },
	{ KEY_7,	IN_BINDTYPE_EMU, PEVB_PICO_SWINP },
	{ 0, 0, 0 }
};

static const struct menu_keymap key_pbtn_map[] =
{
	{ KEY_UP,	PBTN_UP },
	{ KEY_DOWN,	PBTN_DOWN },
	{ KEY_LEFT,	PBTN_LEFT },
	{ KEY_RIGHT,	PBTN_RIGHT },
	/* Pandora */
	{ KEY_END,	PBTN_MOK },
	{ KEY_PAGEDOWN,	PBTN_MBACK },
	{ KEY_HOME,	PBTN_MA2 },
	{ KEY_PAGEUP,	PBTN_MA3 },
	{ KEY_LEFTCTRL,   PBTN_MENU },
	{ KEY_RIGHTSHIFT, PBTN_L },
	{ KEY_RIGHTCTRL,  PBTN_R },
	/* "normal" keyboards */
	{ KEY_ENTER,	PBTN_MOK },
	{ KEY_ESC,	PBTN_MBACK },
	{ KEY_SEMICOLON,  PBTN_MA2 },
	{ KEY_APOSTROPHE, PBTN_MA3 },
	{ KEY_BACKSLASH,  PBTN_MENU },
	{ KEY_LEFTBRACE,  PBTN_L },
	{ KEY_RIGHTBRACE, PBTN_R },
};

static const struct in_pdata pandora_evdev_pdata = {
	.defbinds = in_evdev_defbinds,
	.key_map = key_pbtn_map,
	.kmap_size = sizeof(key_pbtn_map) / sizeof(key_pbtn_map[0]),
};

void pemu_prep_defconfig(void)
{
	defaultConfig.EmuOpt |= EOPT_VSYNC|EOPT_16BPP;
	defaultConfig.s_PicoOpt |= POPT_EN_MCD_GFX;
	defaultConfig.scaling = SCALE_2x2_3x2;
}

void pemu_validate_config(void)
{
	currentConfig.CPUclock = plat_target_cpu_clock_get();
}

static void draw_cd_leds(void)
{
	int old_reg;
	old_reg = Pico_mcd->s68k_regs[0];

	if (0) {
		// 8-bit modes
		unsigned int col_g = (old_reg & 2) ? 0xc0c0c0c0 : 0xe0e0e0e0;
		unsigned int col_r = (old_reg & 1) ? 0xd0d0d0d0 : 0xe0e0e0e0;
		*(unsigned int *)((char *)g_screen_ptr + g_screen_width*2+ 4) =
		*(unsigned int *)((char *)g_screen_ptr + g_screen_width*3+ 4) =
		*(unsigned int *)((char *)g_screen_ptr + g_screen_width*4+ 4) = col_g;
		*(unsigned int *)((char *)g_screen_ptr + g_screen_width*2+12) =
		*(unsigned int *)((char *)g_screen_ptr + g_screen_width*3+12) =
		*(unsigned int *)((char *)g_screen_ptr + g_screen_width*4+12) = col_r;
	} else {
		// 16-bit modes
		unsigned int *p = (unsigned int *)((short *)g_screen_ptr + g_screen_width*2+4);
		unsigned int col_g = (old_reg & 2) ? 0x06000600 : 0;
		unsigned int col_r = (old_reg & 1) ? 0xc000c000 : 0;
		*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r; p += g_screen_width/2 - 12/2;
		*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r; p += g_screen_width/2 - 12/2;
		*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r;
	}
}

void pemu_finalize_frame(const char *fps, const char *notice)
{
	if (notice && notice[0])
		emu_osd_text16(2, g_osd_y, notice);
	if (fps && fps[0] && (currentConfig.EmuOpt & EOPT_SHOW_FPS))
		emu_osd_text16(g_osd_fps_x, g_osd_y, fps);
	if ((PicoAHW & PAHW_MCD) && (currentConfig.EmuOpt & EOPT_EN_CD_LEDS))
		draw_cd_leds();
}

void plat_video_flip(void)
{
	g_screen_ptr = vout_fbdev_flip(layer_fb);
	PicoDrawSetOutBuf(g_screen_ptr, g_screen_width * 2);

	// XXX: drain OS event queue here, maybe we'll actually use it someday..
	xenv_update(NULL, NULL, NULL, NULL);
}

void plat_video_toggle_renderer(int change, int is_menu)
{
}

void plat_video_menu_enter(int is_rom_loaded)
{
}

void plat_video_menu_begin(void)
{
}

void plat_video_menu_end(void)
{
	g_menuscreen_ptr = vout_fbdev_flip(main_fb);
}

void plat_video_menu_leave(void)
{
}

void plat_video_wait_vsync(void)
{
	vout_fbdev_wait_vsync(main_fb);
}

void plat_status_msg_clear(void)
{
	vout_fbdev_clear_lines(layer_fb, g_osd_y, 8);
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

void plat_update_volume(int has_changed, int is_up)
{
}

void pemu_forced_frame(int no_scale, int do_emu)
{
	doing_bg_frame = 1;
	emu_cmn_forced_frame(no_scale, do_emu);
	doing_bg_frame = 0;

	// making a copy because enabling the layer clears it's mem
	memcpy((void *)fb_copy, g_screen_ptr, sizeof(fb_copy));
	g_menubg_src_ptr = fb_copy;
}

void pemu_sound_start(void)
{
	emu_sound_start();
}

void plat_debug_cat(char *str)
{
}

static int pnd_setup_layer_(int fd, int enabled, int x, int y, int w, int h)
{
	struct omapfb_plane_info pi;
	struct omapfb_mem_info mi;
	int is_enabled;
	int retval = 0;
	int ret;

	ret = ioctl(fd, OMAPFB_QUERY_PLANE, &pi);
	if (ret != 0) {
		perror("QUERY_PLANE");
		return -1;
	}

	ret = ioctl(fd, OMAPFB_QUERY_MEM, &mi);
	if (ret != 0) {
		perror("QUERY_MEM");
		return -1;
	}

	/* must disable when changing stuff */
	is_enabled = pi.enabled;
	if (is_enabled) {
		pi.enabled = 0;
		ret = ioctl(fd, OMAPFB_SETUP_PLANE, &pi);
		if (ret != 0)
			perror("SETUP_PLANE");
		else
			is_enabled = 0;
	}

	if (mi.size < LAYER_MEM_SIZE) {
		unsigned int size_old = mi.size;

		mi.size = LAYER_MEM_SIZE;
		ret = ioctl(fd, OMAPFB_SETUP_MEM, &mi);
		if (ret != 0) {
			perror("SETUP_MEM");
			fprintf(stderr, "(requested %u, had %u)\n",
				mi.size, size_old);
			return -1;
		}
	}

	pi.pos_x = x;
	pi.pos_y = y;
	pi.out_width = w;
	pi.out_height = h;
	pi.enabled = enabled;

	ret = ioctl(fd, OMAPFB_SETUP_PLANE, &pi);
	if (ret == 0) {
		is_enabled = pi.enabled;
	}
	else {
		perror("SETUP_PLANE");
		retval = -1;
	}

	plat_target_switch_layer(1, is_enabled);

	return retval;
}

int pnd_setup_layer(int enabled, int x, int y, int w, int h)
{
	return pnd_setup_layer_(vout_fbdev_get_fd(layer_fb), enabled, x, y, w, h);
}

void pnd_restore_layer_data(void)
{
	short *t = (short *)fb_copy + 320*240 / 2 + 160;

	// right now this is used by menu, which wants to preview something
	// so try to get something on the layer.
	if ((t[0] | t[5] | t[13]) == 0)
		memset32((void *)fb_copy, 0x07000700, sizeof(fb_copy) / 4);

	memcpy(g_screen_ptr, (void *)fb_copy, 320*240*2);
	plat_video_flip();
}

void emu_video_mode_change(int start_line, int line_count, int is_32cols)
{
	int fb_w = 320, fb_h = 240, fb_left = 0, fb_right = 0, fb_top = 0, fb_bottom = 0;

	if (doing_bg_frame)
		return;

	if (is_32cols) {
		fb_w = 256;
		fb_left = fb_right = 32;
	}

	switch (currentConfig.scaling) {
	case SCALE_1x1:
		g_layer_w = fb_w;
		g_layer_h = fb_h;
		break;
	case SCALE_2x2_3x2:
		g_layer_w = fb_w * (is_32cols ? 3 : 2);
		g_layer_h = fb_h * 2;
		break;
	case SCALE_2x2_2x2:
		g_layer_w = fb_w * 2;
		g_layer_h = fb_h * 2;
		break;
	case SCALE_FULLSCREEN:
		g_layer_w = 800;
		g_layer_h = 480;
		break;
	case SCALE_CUSTOM:
		g_layer_x = g_layer_cx;
		g_layer_y = g_layer_cy;
		g_layer_w = g_layer_cw;
		g_layer_h = g_layer_ch;
		break;
	}

	if (currentConfig.scaling != SCALE_CUSTOM) {
		// center the layer
		g_layer_x = 800 / 2 - g_layer_w / 2;
		g_layer_y = 480 / 2 - g_layer_h / 2;
	}

	switch (currentConfig.scaling) {
	case SCALE_FULLSCREEN:
	case SCALE_CUSTOM:
		fb_top = start_line;
		fb_h = line_count;
		break;
	}
	g_osd_fps_x = is_32cols ? 232 : 264;
	g_osd_y = fb_top + fb_h - 8;

	pnd_setup_layer(1, g_layer_x, g_layer_y, g_layer_w, g_layer_h);
	vout_fbdev_clear(layer_fb);
	vout_fbdev_resize(layer_fb, fb_w, fb_h, 16, fb_left, fb_right, fb_top, fb_bottom, 4);
	plat_video_flip();

	PicoDrawSetOutFormat(PDF_RGB555, 0);
}

void plat_video_loop_prepare(void)
{
	// make sure there is no junk left behind the layer
	memset(g_menuscreen_ptr, 0, g_menuscreen_w * g_menuscreen_h * 2);
	g_menuscreen_ptr = vout_fbdev_flip(main_fb);

	// emu_video_mode_change will call pnd_setup_layer()
}

void pemu_loop_prep(void)
{
	// dirty buffers better go now than during gameplay
	fflush(stdout);
	fflush(stderr);
	sync();
	sleep(0);
}

void pemu_loop_end(void)
{
	/* do one more frame for menu bg */
	pemu_forced_frame(0, 1);

	pnd_setup_layer(0, g_layer_x, g_layer_y, g_layer_w, g_layer_h);
}

void plat_wait_till_us(unsigned int us_to)
{
	unsigned int now;
	signed int diff;

	now = plat_get_ticks_us();

	// XXX: need to check NOHZ
	diff = (signed int)(us_to - now);
	if (diff > 10000) {
		//printf("sleep %d\n", us_to - now);
		usleep(diff * 15 / 16);
		now = plat_get_ticks_us();
		//printf(" wake %d\n", (signed)(us_to - now));
	}
/*
	while ((signed int)(us_to - now) > 512) {
		spend_cycles(1024);
		now = plat_get_ticks_us();
	}
*/
}

void plat_early_init(void)
{
}

void plat_init(void)
{
	const char *main_fb_name, *layer_fb_name;
	int fd, ret, w, h;

	main_fb_name = getenv("FBDEV_MAIN");
	if (main_fb_name == NULL)
		main_fb_name = "/dev/fb0";

	layer_fb_name = getenv("FBDEV_LAYER");
	if (layer_fb_name == NULL)
		layer_fb_name = "/dev/fb1";

	// must set the layer up first to be able to use it
	fd = open(layer_fb_name, O_RDWR);
	if (fd == -1) {
		fprintf(stderr, "%s: ", layer_fb_name);
		perror("open");
		exit(1);
	}

	ret = pnd_setup_layer_(fd, 0, g_layer_x, g_layer_y, g_layer_w, g_layer_h);
	close(fd);
	if (ret != 0) {
		fprintf(stderr, "failed to set up layer, exiting.\n");
		exit(1);
	}

	xenv_init(NULL, "PicoDrive " VERSION);

	w = h = 0;
	main_fb = vout_fbdev_init(main_fb_name, &w, &h, 16, 2);
	if (main_fb == NULL) {
		fprintf(stderr, "couldn't init fb: %s\n", main_fb_name);
		exit(1);
	}

	g_menuscreen_w = w;
	g_menuscreen_h = h;
	g_menuscreen_ptr = vout_fbdev_flip(main_fb);

	w = 320; h = 240;
	layer_fb = vout_fbdev_init(layer_fb_name, &w, &h, 16, 4);
	if (layer_fb == NULL) {
		fprintf(stderr, "couldn't init fb: %s\n", layer_fb_name);
		goto fail0;
	}

	if (w != g_screen_width || h != g_screen_height) {
		fprintf(stderr, "%dx%d not supported on %s\n", w, h, layer_fb_name);
		goto fail1;
	}
	g_screen_ptr = vout_fbdev_flip(layer_fb);

	temp_frame = calloc(g_menuscreen_w * g_menuscreen_h * 2, 1);
	if (temp_frame == NULL) {
		fprintf(stderr, "OOM\n");
		goto fail1;
	}
	g_menubg_ptr = temp_frame;
	g_menubg_src_ptr = temp_frame;

	pnd_menu_init();

	// default ROM path
	strcpy(rom_fname_loaded, "/media");

	in_evdev_init(&pandora_evdev_pdata);
	in_probe();
	plat_target_setup_input();

	sndout_oss_frag_frames = 2;

	return;

fail1:
	vout_fbdev_finish(layer_fb);
fail0:
	vout_fbdev_finish(main_fb);
	exit(1);
}

void plat_finish(void)
{
	vout_fbdev_finish(main_fb);
	xenv_finish();

	printf("all done\n");
}

