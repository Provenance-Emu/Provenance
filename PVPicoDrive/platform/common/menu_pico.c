/*
 * PicoDrive
 * (C) notaz, 2010,2011
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include <stdio.h>
#include <string.h>
#include <time.h>

#include "emu.h"
#include "menu_pico.h"
#include "input_pico.h"
#include "version.h"

#include <pico/pico.h>
#include <pico/patch.h>

#ifdef PANDORA
#define MENU_X2 1
#else
#define MENU_X2 0
#endif

// FIXME
#define REVISION "0"

static const char *rom_exts[] = {
	"zip",
	"bin", "smd", "gen", "md",
	"iso", "cso", "cue",
	"32x",
	"sms",
	NULL
};

// rrrr rggg gggb bbbb
static unsigned short fname2color(const char *fname)
{
	static const char *other_exts[] = { "gmv", "pat" };
	const char *ext;
	int i;

	ext = strrchr(fname, '.');
	if (ext++ == NULL) {
		ext = fname + strlen(fname) - 3;
		if (ext < fname) ext = fname;
	}

	for (i = 0; rom_exts[i] != NULL; i++)
		if (strcasecmp(ext, rom_exts[i]) == 0) return 0xbdff; // FIXME: mk defines
	for (i = 0; i < array_size(other_exts); i++)
		if (strcasecmp(ext, other_exts[i]) == 0) return 0xaff5;
	return 0xffff;
}

#include "../libpicofe/menu.c"

static const char *men_dummy[] = { NULL };

/* platform specific options and handlers */
#if   defined(__GP2X__)
#include "../gp2x/menu.c"
#elif defined(PANDORA)
#include "../pandora/menu.c"
#else
#define MENU_OPTIONS_GFX
#define MENU_OPTIONS_ADV
#endif

static void make_bg(int no_scale)
{
	unsigned short *src = (void *)g_menubg_src_ptr;
	int w = g_screen_width, h = g_screen_height;
	short *dst;
	int x, y;

	if (src == NULL) {
		memset(g_menubg_ptr, 0, g_menuscreen_w * g_menuscreen_h * 2);
		return;
	}

	if (!no_scale && g_menuscreen_w / w >= 2 && g_menuscreen_h / h >= 2)
	{
		unsigned int t, *d = g_menubg_ptr;
		d += (g_menuscreen_h / 2 - h * 2 / 2)
			* g_menuscreen_w / 2;
		d += (g_menuscreen_w / 2 - w * 2 / 2) / 2;
		for (y = 0; y < h; y++, src += w, d += g_menuscreen_w*2/2) {
			for (x = 0; x < w; x++) {
				t = src[x];
				t = ((t & 0xf79e)>>1) - ((t & 0xc618)>>3);
				t |= t << 16;
				d[x] = d[x + g_menuscreen_w / 2] = t;
			}
		}
		return;
	}

	if (w > g_menuscreen_w)
		w = g_menuscreen_w;
	if (h > g_menuscreen_h)
		h = g_menuscreen_h;
	dst = (short *)g_menubg_ptr +
		(g_menuscreen_h / 2 - h / 2) * g_menuscreen_w +
		(g_menuscreen_w / 2 - w / 2);

	// darken the active framebuffer
	for (; h > 0; dst += g_menuscreen_w, src += g_screen_width, h--)
		menu_darken_bg(dst, src, w, 1);
}

static void menu_enter(int is_rom_loaded)
{
	if (is_rom_loaded)
	{
		make_bg(0);
	}
	else
	{
		int pos;
		char buff[256];
		pos = plat_get_skin_dir(buff, 256);
		strcpy(buff + pos, "background.png");

		// should really only happen once, on startup..
		if (readpng(g_menubg_ptr, buff, READPNG_BG,
						g_menuscreen_w, g_menuscreen_h) < 0)
			memset(g_menubg_ptr, 0, g_menuscreen_w * g_menuscreen_h * 2);
	}

	plat_video_menu_enter(is_rom_loaded);
}

static void draw_savestate_bg(int slot)
{
	const char *fname;
	void *tmp_state;

	fname = emu_get_save_fname(1, 0, slot, NULL);
	if (!fname)
		return;

	tmp_state = PicoTmpStateSave();

	PicoStateLoadGfx(fname);

	/* do a frame and fetch menu bg */
	pemu_forced_frame(0, 0);

	make_bg(0);

	PicoTmpStateRestore(tmp_state);
}

// --------- loading ROM screen ----------

static int cdload_called = 0;

static void load_progress_cb(int percent)
{
	int ln, len = percent * g_menuscreen_w / 100;
	unsigned short *dst;

	if (len > g_menuscreen_w)
		len = g_menuscreen_w;

	menu_draw_begin(0, 1);
	dst = (unsigned short *)g_menuscreen_ptr + g_menuscreen_w * me_sfont_h * 2;
	for (ln = me_sfont_h - 2; ln > 0; ln--, dst += g_menuscreen_w)
		memset(dst, 0xff, len * 2);
	menu_draw_end();
}

static void cdload_progress_cb(const char *fname, int percent)
{
	int ln, len = percent * g_menuscreen_w / 100;
	unsigned short *dst;

	menu_draw_begin(0, 1);
	dst = (unsigned short *)g_menuscreen_ptr + g_menuscreen_w * me_sfont_h * 2;
	memset(dst, 0xff, g_menuscreen_w * (me_sfont_h - 2) * 2);

	smalltext_out16(1, 3 * me_sfont_h, "Processing CD image / MP3s", 0xffff);
	smalltext_out16(1, 4 * me_sfont_h, fname, 0xffff);
	dst += g_menuscreen_w * me_sfont_h * 3;

	if (len > g_menuscreen_w)
		len = g_menuscreen_w;

	for (ln = (me_sfont_h - 2); ln > 0; ln--, dst += g_menuscreen_w)
		memset(dst, 0xff, len * 2);
	menu_draw_end();

	cdload_called = 1;
}

void menu_romload_prepare(const char *rom_name)
{
	const char *p = rom_name + strlen(rom_name);
	int i;

	while (p > rom_name && *p != '/')
		p--;

	/* fill all buffers, callbacks won't update in full */
	for (i = 0; i < 3; i++) {
		menu_draw_begin(1, 1);
		smalltext_out16(1, 1, "Loading", 0xffff);
		smalltext_out16(1, me_sfont_h, p, 0xffff);
		menu_draw_end();
	}

	PicoCartLoadProgressCB = load_progress_cb;
	PicoCDLoadProgressCB = cdload_progress_cb;
	cdload_called = 0;
}

void menu_romload_end(void)
{
	PicoCartLoadProgressCB = NULL;
	PicoCDLoadProgressCB = NULL;

	menu_draw_begin(0, 1);
	smalltext_out16(1, (cdload_called ? 6 : 3) * me_sfont_h,
		"Starting emulation...", 0xffff);
	menu_draw_end();
}

// ------------ patch/gg menu ------------

static void draw_patchlist(int sel)
{
	int max_cnt, start, i, pos, active;

	max_cnt = g_menuscreen_h / me_sfont_h;
	start = max_cnt / 2 - sel;

	menu_draw_begin(1, 0);

	for (i = 0; i < PicoPatchCount; i++) {
		pos = start + i;
		if (pos < 0) continue;
		if (pos >= max_cnt) break;
		active = PicoPatches[i].active;
		smalltext_out16(14,                pos * me_sfont_h, active ? "ON " : "OFF", active ? 0xfff6 : 0xffff);
		smalltext_out16(14 + me_sfont_w*4, pos * me_sfont_h, PicoPatches[i].name,    active ? 0xfff6 : 0xffff);
	}
	pos = start + i;
	if (pos < max_cnt)
		smalltext_out16(14, pos * me_sfont_h, "done", 0xffff);

	text_out16(5, max_cnt / 2 * me_sfont_h, ">");
	menu_draw_end();
}

static void menu_loop_patches(void)
{
	static int menu_sel = 0;
	int inp;

	for (;;)
	{
		draw_patchlist(menu_sel);
		inp = in_menu_wait(PBTN_UP|PBTN_DOWN|PBTN_LEFT|PBTN_RIGHT|PBTN_L|PBTN_R
				|PBTN_MOK|PBTN_MBACK, NULL, 33);
		if (inp & PBTN_UP  ) { menu_sel--; if (menu_sel < 0) menu_sel = PicoPatchCount; }
		if (inp & PBTN_DOWN) { menu_sel++; if (menu_sel > PicoPatchCount) menu_sel = 0; }
		if (inp &(PBTN_LEFT|PBTN_L))  { menu_sel-=10; if (menu_sel < 0) menu_sel = 0; }
		if (inp &(PBTN_RIGHT|PBTN_R)) { menu_sel+=10; if (menu_sel > PicoPatchCount) menu_sel = PicoPatchCount; }
		if (inp & PBTN_MOK) { // action
			if (menu_sel < PicoPatchCount)
				PicoPatches[menu_sel].active = !PicoPatches[menu_sel].active;
			else 	break;
		}
		if (inp & PBTN_MBACK)
			break;
	}
}

// -------------- key config --------------

// PicoPad[] format: MXYZ SACB RLDU
me_bind_action me_ctrl_actions[] =
{
	{ "UP     ", 0x0001 },
	{ "DOWN   ", 0x0002 },
	{ "LEFT   ", 0x0004 },
	{ "RIGHT  ", 0x0008 },
	{ "A      ", 0x0040 },
	{ "B      ", 0x0010 },
	{ "C      ", 0x0020 },
	{ "A turbo", 0x4000 },
	{ "B turbo", 0x1000 },
	{ "C turbo", 0x2000 },
	{ "START  ", 0x0080 },
	{ "MODE   ", 0x0800 },
	{ "X      ", 0x0400 },
	{ "Y      ", 0x0200 },
	{ "Z      ", 0x0100 },
	{ NULL,      0 },
};

me_bind_action emuctrl_actions[] =
{
	{ "Load State       ", PEV_STATE_LOAD },
	{ "Save State       ", PEV_STATE_SAVE },
	{ "Prev Save Slot   ", PEV_SSLOT_PREV },
	{ "Next Save Slot   ", PEV_SSLOT_NEXT },
	{ "Switch Renderer  ", PEV_SWITCH_RND },
	{ "Volume Down      ", PEV_VOL_DOWN },
	{ "Volume Up        ", PEV_VOL_UP },
	{ "Fast forward     ", PEV_FF },
	{ "Enter Menu       ", PEV_MENU },
	{ "Pico Next page   ", PEV_PICO_PNEXT },
	{ "Pico Prev page   ", PEV_PICO_PPREV },
	{ "Pico Switch input", PEV_PICO_SWINP },
	{ NULL,                0 }
};

static int key_config_loop_wrap(int id, int keys)
{
	switch (id) {
		case MA_CTRL_PLAYER1:
			key_config_loop(me_ctrl_actions, array_size(me_ctrl_actions) - 1, 0);
			break;
		case MA_CTRL_PLAYER2:
			key_config_loop(me_ctrl_actions, array_size(me_ctrl_actions) - 1, 1);
			break;
		case MA_CTRL_EMU:
			key_config_loop(emuctrl_actions, array_size(emuctrl_actions) - 1, -1);
			break;
		default:
			break;
	}
	return 0;
}

static const char *mgn_dev_name(int id, int *offs)
{
	const char *name = NULL;
	static int it = 0;

	if (id == MA_CTRL_DEV_FIRST)
		it = 0;

	for (; it < IN_MAX_DEVS; it++) {
		name = in_get_dev_name(it, 1, 1);
		if (name != NULL)
			break;
	}

	it++;
	return name;
}

static int mh_saveloadcfg(int id, int keys);
static const char *mgn_saveloadcfg(int id, int *offs);

const char *indev_names[] = { "none", "3 button pad", "6 button pad", NULL };

static menu_entry e_menu_keyconfig[] =
{
	mee_handler_id("Player 1",          MA_CTRL_PLAYER1,    key_config_loop_wrap),
	mee_handler_id("Player 2",          MA_CTRL_PLAYER2,    key_config_loop_wrap),
	mee_handler_id("Emulator controls", MA_CTRL_EMU,        key_config_loop_wrap),
	mee_enum      ("Input device 1",    MA_OPT_INPUT_DEV0,  currentConfig.input_dev0, indev_names),
	mee_enum      ("Input device 2",    MA_OPT_INPUT_DEV1,  currentConfig.input_dev1, indev_names),
	mee_range     ("Turbo rate",        MA_CTRL_TURBO_RATE, currentConfig.turbo_rate, 1, 30),
	mee_range     ("Analog deadzone",   MA_CTRL_DEADZONE,   currentConfig.analog_deadzone, 1, 99),
	mee_cust_nosave("Save global config",       MA_OPT_SAVECFG, mh_saveloadcfg, mgn_saveloadcfg),
	mee_cust_nosave("Save cfg for loaded game", MA_OPT_SAVECFG_GAME, mh_saveloadcfg, mgn_saveloadcfg),
	mee_label     (""),
	mee_label     ("Input devices:"),
	mee_label_mk  (MA_CTRL_DEV_FIRST, mgn_dev_name),
	mee_label_mk  (MA_CTRL_DEV_NEXT,  mgn_dev_name),
	mee_label_mk  (MA_CTRL_DEV_NEXT,  mgn_dev_name),
	mee_label_mk  (MA_CTRL_DEV_NEXT,  mgn_dev_name),
	mee_label_mk  (MA_CTRL_DEV_NEXT,  mgn_dev_name),
	mee_label_mk  (MA_CTRL_DEV_NEXT,  mgn_dev_name),
	mee_label_mk  (MA_CTRL_DEV_NEXT,  mgn_dev_name),
	mee_end,
};

static int menu_loop_keyconfig(int id, int keys)
{
	static int sel = 0;

	me_enable(e_menu_keyconfig, MA_OPT_SAVECFG_GAME, PicoGameLoaded);
	me_loop(e_menu_keyconfig, &sel);

	PicoSetInputDevice(0, currentConfig.input_dev0);
	PicoSetInputDevice(1, currentConfig.input_dev1);

	return 0;
}

// ------------ SCD options menu ------------

static const char h_cdleds[] = "Show power/CD LEDs of emulated console";
static const char h_cdda[]   = "Play audio tracks from mp3s/wavs/bins";
static const char h_cdpcm[]  = "Emulate PCM audio chip for effects/voices/music";
static const char h_srcart[] = "Emulate the save RAM cartridge accessory\n"
				"most games don't need this";
static const char h_scfx[]   = "Emulate scale/rotate ASIC chip for graphics effects\n"
				"disable to improve performance";
static const char h_bsync[]  = "More accurate mode for CPUs (needed for some games)\n"
				"disable to improve performance";

static menu_entry e_menu_cd_options[] =
{
	mee_onoff_h("CD LEDs",              MA_CDOPT_LEDS,          currentConfig.EmuOpt, EOPT_EN_CD_LEDS, h_cdleds),
	mee_onoff_h("CDDA audio",           MA_CDOPT_CDDA,          PicoOpt, POPT_EN_MCD_CDDA, h_cdda),
	mee_onoff_h("PCM audio",            MA_CDOPT_PCM,           PicoOpt, POPT_EN_MCD_PCM, h_cdpcm),
	mee_onoff_h("SaveRAM cart",         MA_CDOPT_SAVERAM,       PicoOpt, POPT_EN_MCD_RAMCART, h_srcart),
	mee_onoff_h("Scale/Rot. fx",        MA_CDOPT_SCALEROT_CHIP, PicoOpt, POPT_EN_MCD_GFX, h_scfx),
	mee_end,
};

static int menu_loop_cd_options(int id, int keys)
{
	static int sel = 0;
	me_loop(e_menu_cd_options, &sel);
	return 0;
}

// ------------ 32X options menu ------------

#ifndef NO_32X

// convert from multiplier of VClk
static int mh_opt_sh2cycles(int id, int keys)
{
	int *khz = (id == MA_32XOPT_MSH2_CYCLES) ?
		&currentConfig.msh2_khz : &currentConfig.ssh2_khz;

	if (keys & (PBTN_LEFT|PBTN_RIGHT))
		*khz += (keys & PBTN_LEFT) ? -50 : 50;
	if (keys & (PBTN_L|PBTN_R))
		*khz += (keys & PBTN_L) ? -500 : 500;

	if (*khz < 1)
		*khz = 1;
	else if (*khz > 0x7fffffff / 1000)
		*khz = 0x7fffffff / 1000;

	return 0;
}

static const char *mgn_opt_sh2cycles(int id, int *offs)
{
	int khz = (id == MA_32XOPT_MSH2_CYCLES) ?
		currentConfig.msh2_khz : currentConfig.ssh2_khz;

	sprintf(static_buff, "%d", khz);
	return static_buff;
}

static const char h_32x_enable[] = "Enable emulation of the 32X addon";
static const char h_pwm[]        = "Disabling may improve performance, but break sound";
static const char h_sh2cycles[]  = "Cycles/millisecond (similar to DOSBox)\n"
				   "lower values speed up emulation but break games\n"
				   "at least 11000 recommended for compatibility";

static menu_entry e_menu_32x_options[] =
{
	mee_onoff_h   ("32X enabled",       MA_32XOPT_ENABLE_32X,  PicoOpt, POPT_EN_32X, h_32x_enable),
	mee_enum      ("32X renderer",      MA_32XOPT_RENDERER,    currentConfig.renderer32x, renderer_names32x),
	mee_onoff_h   ("PWM sound",         MA_32XOPT_PWM,         PicoOpt, POPT_EN_PWM, h_pwm),
	mee_cust_h    ("Master SH2 cycles", MA_32XOPT_MSH2_CYCLES, mh_opt_sh2cycles, mgn_opt_sh2cycles, h_sh2cycles),
	mee_cust_h    ("Slave SH2 cycles",  MA_32XOPT_SSH2_CYCLES, mh_opt_sh2cycles, mgn_opt_sh2cycles, h_sh2cycles),
	mee_end,
};

static int menu_loop_32x_options(int id, int keys)
{
	static int sel = 0;

	me_enable(e_menu_32x_options, MA_32XOPT_RENDERER, renderer_names32x[0] != NULL);
	me_loop(e_menu_32x_options, &sel);

	Pico32xSetClocks(currentConfig.msh2_khz * 1000, currentConfig.msh2_khz * 1000);

	return 0;
}

#endif

// ------------ adv options menu ------------

static menu_entry e_menu_adv_options[] =
{
	mee_onoff     ("SRAM/BRAM saves",          MA_OPT_SRAM_STATES,    currentConfig.EmuOpt, EOPT_EN_SRAM),
	mee_onoff     ("Disable sprite limit",     MA_OPT2_NO_SPRITE_LIM, PicoOpt, POPT_DIS_SPRITE_LIM),
	mee_onoff     ("Emulate Z80",              MA_OPT2_ENABLE_Z80,    PicoOpt, POPT_EN_Z80),
	mee_onoff     ("Emulate YM2612 (FM)",      MA_OPT2_ENABLE_YM2612, PicoOpt, POPT_EN_FM),
	mee_onoff     ("Emulate SN76496 (PSG)",    MA_OPT2_ENABLE_SN76496,PicoOpt, POPT_EN_PSG),
	mee_onoff     ("gzip savestates",          MA_OPT2_GZIP_STATES,   currentConfig.EmuOpt, EOPT_GZIP_SAVES),
	mee_onoff     ("Don't save last used ROM", MA_OPT2_NO_LAST_ROM,   currentConfig.EmuOpt, EOPT_NO_AUTOSVCFG),
	mee_onoff     ("Disable idle loop patching",MA_OPT2_NO_IDLE_LOOPS,PicoOpt, POPT_DIS_IDLE_DET),
	mee_onoff     ("Disable frame limiter",    MA_OPT2_NO_FRAME_LIMIT,currentConfig.EmuOpt, EOPT_NO_FRMLIMIT),
	mee_onoff     ("Enable dynarecs",          MA_OPT2_DYNARECS,      PicoOpt, POPT_EN_DRC),
	mee_onoff     ("Status line in main menu", MA_OPT2_STATUS_LINE,   currentConfig.EmuOpt, EOPT_SHOW_RTC),
	MENU_OPTIONS_ADV
	mee_end,
};

static int menu_loop_adv_options(int id, int keys)
{
	static int sel = 0;
	me_loop(e_menu_adv_options, &sel);
	return 0;
}

// ------------ gfx options menu ------------

static const char h_gamma[] = "Gamma/brightness adjustment (default 1.00)";

static const char *mgn_aopt_gamma(int id, int *offs)
{
	sprintf(static_buff, "%i.%02i", currentConfig.gamma / 100, currentConfig.gamma % 100);
	return static_buff;
}

static menu_entry e_menu_gfx_options[] =
{
	mee_enum   ("Video output mode", MA_OPT_VOUT_MODE, plat_target.vout_method, men_dummy),
	mee_enum   ("Renderer",          MA_OPT_RENDERER, currentConfig.renderer, renderer_names),
	mee_enum   ("Filter",            MA_OPT3_FILTERING, currentConfig.filter, men_dummy),
	mee_range_cust_h("Gamma correction", MA_OPT2_GAMMA, currentConfig.gamma, 1, 300, mgn_aopt_gamma, h_gamma),
	MENU_OPTIONS_GFX
	mee_end,
};

static int menu_loop_gfx_options(int id, int keys)
{
	static int sel = 0;

	me_enable(e_menu_gfx_options, MA_OPT_RENDERER, renderer_names[0] != NULL);
	me_loop(e_menu_gfx_options, &sel);

	return 0;
}

// ------------ options menu ------------

static menu_entry e_menu_options[];

static int sndrate_prevnext(int rate, int dir)
{
	static const int rates[] = { 8000, 11025, 16000, 22050, 44100 };
	int i;

	for (i = 0; i < 5; i++)
		if (rates[i] == rate) break;

	i += dir ? 1 : -1;
	if (i > 4) {
		if (!(PicoOpt & POPT_EN_STEREO)) {
			PicoOpt |= POPT_EN_STEREO;
			return rates[0];
		}
		return rates[4];
	}
	if (i < 0) {
		if (PicoOpt & POPT_EN_STEREO) {
			PicoOpt &= ~POPT_EN_STEREO;
			return rates[4];
		}
		return rates[0];
	}
	return rates[i];
}

static void region_prevnext(int right)
{
	// jp_ntsc=1, jp_pal=2, usa=4, eu=8
	static const int rgn_orders[] = { 0x148, 0x184, 0x814, 0x418, 0x841, 0x481 };
	int i;

	if (right) {
		if (!PicoRegionOverride) {
			for (i = 0; i < 6; i++)
				if (rgn_orders[i] == PicoAutoRgnOrder) break;
			if (i < 5) PicoAutoRgnOrder = rgn_orders[i+1];
			else PicoRegionOverride=1;
		}
		else
			PicoRegionOverride <<= 1;
		if (PicoRegionOverride > 8)
			PicoRegionOverride = 8;
	} else {
		if (!PicoRegionOverride) {
			for (i = 0; i < 6; i++)
				if (rgn_orders[i] == PicoAutoRgnOrder) break;
			if (i > 0) PicoAutoRgnOrder = rgn_orders[i-1];
		}
		else
			PicoRegionOverride >>= 1;
	}
}

static int mh_opt_misc(int id, int keys)
{
	switch (id) {
	case MA_OPT_SOUND_QUALITY:
		PsndRate = sndrate_prevnext(PsndRate, keys & PBTN_RIGHT);
		break;
	case MA_OPT_REGION:
		region_prevnext(keys & PBTN_RIGHT);
		break;
	default:
		break;
	}
	return 0;
}

static int mh_saveloadcfg(int id, int keys)
{
	int ret;

	if (keys & (PBTN_LEFT|PBTN_RIGHT)) { // multi choice
		config_slot += (keys & PBTN_LEFT) ? -1 : 1;
		if (config_slot < 0) config_slot = 9;
		else if (config_slot > 9) config_slot = 0;
		me_enable(e_menu_options, MA_OPT_LOADCFG, config_slot != config_slot_current);
		return 0;
	}

	switch (id) {
	case MA_OPT_SAVECFG:
	case MA_OPT_SAVECFG_GAME:
		if (emu_write_config(id == MA_OPT_SAVECFG_GAME ? 1 : 0))
			menu_update_msg("config saved");
		else
			menu_update_msg("failed to write config");
		break;
	case MA_OPT_LOADCFG:
		ret = emu_read_config(rom_fname_loaded, 1);
		if (!ret) ret = emu_read_config(NULL, 1);
		if (ret)  menu_update_msg("config loaded");
		else      menu_update_msg("failed to load config");
		break;
	default:
		return 0;
	}

	return 1;
}

static int mh_restore_defaults(int id, int keys)
{
	emu_set_defconfig();
	menu_update_msg("defaults restored");
	return 1;
}

static const char *mgn_opt_fskip(int id, int *offs)
{
	if (currentConfig.Frameskip < 0)
		return "Auto";
	sprintf(static_buff, "%d", currentConfig.Frameskip);
	return static_buff;
}

static const char *mgn_opt_sound(int id, int *offs)
{
	const char *str2;
	*offs = -8;
	str2 = (PicoOpt & POPT_EN_STEREO) ? "stereo" : "mono";
	sprintf(static_buff, "%5iHz %s", PsndRate, str2);
	return static_buff;
}

static const char *mgn_opt_region(int id, int *offs)
{
	static const char *names[] = { "Auto", "      Japan NTSC", "      Japan PAL", "      USA", "      Europe" };
	static const char *names_short[] = { "", " JP", " JP", " US", " EU" };
	int code = PicoRegionOverride;
	int u, i = 0;

	*offs = -6;
	if (code) {
		code <<= 1;
		while ((code >>= 1)) i++;
		if (i > 4)
			return "unknown";
		return names[i];
	} else {
		strcpy(static_buff, "Auto:");
		for (u = 0; u < 3; u++) {
			code = (PicoAutoRgnOrder >> u*4) & 0xf;
			for (i = 0; code; code >>= 1, i++)
				;
			strcat(static_buff, names_short[i]);
		}
		return static_buff;
	}
}

static const char *mgn_saveloadcfg(int id, int *offs)
{
	static_buff[0] = 0;
	if (config_slot != 0)
		sprintf(static_buff, "[%i]", config_slot);
	return static_buff;
}

static const char *men_confirm_save[] = { "OFF", "writes", "loads", "both", NULL };
static const char h_confirm_save[]    = "Ask for confirmation when overwriting save,\n"
					"loading state or both";

static menu_entry e_menu_options[] =
{
	mee_range     ("Save slot",                MA_OPT_SAVE_SLOT,     state_slot, 0, 9),
	mee_range_cust("Frameskip",                MA_OPT_FRAMESKIP,     currentConfig.Frameskip, -1, 16, mgn_opt_fskip),
	mee_cust      ("Region",                   MA_OPT_REGION,        mh_opt_misc, mgn_opt_region),
	mee_onoff     ("Show FPS",                 MA_OPT_SHOW_FPS,      currentConfig.EmuOpt, EOPT_SHOW_FPS),
	mee_onoff     ("Enable sound",             MA_OPT_ENABLE_SOUND,  currentConfig.EmuOpt, EOPT_EN_SOUND),
	mee_cust      ("Sound Quality",            MA_OPT_SOUND_QUALITY, mh_opt_misc, mgn_opt_sound),
	mee_enum_h    ("Confirm savestate",        MA_OPT_CONFIRM_STATES,currentConfig.confirm_save, men_confirm_save, h_confirm_save),
	mee_range     ("",                         MA_OPT_CPU_CLOCKS,    currentConfig.CPUclock, 20, 3200),
	mee_handler   ("[Display options]",        menu_loop_gfx_options),
	mee_handler   ("[Sega/Mega CD options]",   menu_loop_cd_options),
#ifndef NO_32X
	mee_handler   ("[32X options]",            menu_loop_32x_options),
#endif
	mee_handler   ("[Advanced options]",       menu_loop_adv_options),
	mee_cust_nosave("Save global config",      MA_OPT_SAVECFG, mh_saveloadcfg, mgn_saveloadcfg),
	mee_cust_nosave("Save cfg for loaded game",MA_OPT_SAVECFG_GAME, mh_saveloadcfg, mgn_saveloadcfg),
	mee_cust_nosave("Load cfg from profile",   MA_OPT_LOADCFG, mh_saveloadcfg, mgn_saveloadcfg),
	mee_handler   ("Restore defaults",         mh_restore_defaults),
	mee_end,
};

static int menu_loop_options(int id, int keys)
{
	static int sel = 0;

	me_enable(e_menu_options, MA_OPT_SAVECFG_GAME, PicoGameLoaded);
	me_enable(e_menu_options, MA_OPT_LOADCFG, config_slot != config_slot_current);

	me_loop(e_menu_options, &sel);

	return 0;
}

// ------------ debug menu ------------

#include <pico/debug.h>

extern void SekStepM68k(void);

static void mplayer_loop(void)
{
	pemu_sound_start();

	while (1)
	{
		PDebugZ80Frame();
		if (in_menu_wait_any(NULL, 0) & PBTN_MA3)
			break;
		emu_sound_wait();
	}

	emu_sound_stop();
}

static void draw_text_debug(const char *str, int skip, int from)
{
	const char *p;
	int line;

	p = str;
	while (skip-- > 0)
	{
		while (*p && *p != '\n')
			p++;
		if (*p == 0 || p[1] == 0)
			return;
		p++;
	}

	str = p;
	for (line = from; line < g_menuscreen_h / me_sfont_h; line++)
	{
		smalltext_out16(1, line * me_sfont_h, str, 0xffff);
		while (*p && *p != '\n')
			p++;
		if (*p == 0)
			break;
		p++; str = p;
	}
}

#ifdef __GNUC__
#define COMPILER "gcc " __VERSION__
#else
#define COMPILER
#endif

static void draw_frame_debug(void)
{
	char layer_str[48] = "layers:                   ";
	if (PicoDrawMask & PDRAW_LAYERB_ON)      memcpy(layer_str +  8, "B", 1);
	if (PicoDrawMask & PDRAW_LAYERA_ON)      memcpy(layer_str + 10, "A", 1);
	if (PicoDrawMask & PDRAW_SPRITES_LOW_ON) memcpy(layer_str + 12, "spr_lo", 6);
	if (PicoDrawMask & PDRAW_SPRITES_HI_ON)  memcpy(layer_str + 19, "spr_hi", 6);
	if (PicoDrawMask & PDRAW_32X_ON)         memcpy(layer_str + 26, "32x", 4);

	pemu_forced_frame(1, 0);
	make_bg(1);

	smalltext_out16(4, 1, "build: r" REVISION "  "__DATE__ " " __TIME__ " " COMPILER, 0xffff);
	smalltext_out16(4, g_menuscreen_h - me_sfont_h, layer_str, 0xffff);
}

static void debug_menu_loop(void)
{
	int inp, mode = 0;
	int spr_offs = 0, dumped = 0;
	char *tmp;

	while (1)
	{
		menu_draw_begin(1, 0);
		switch (mode)
		{
			case 0: tmp = PDebugMain();
				plat_debug_cat(tmp);
				draw_text_debug(tmp, 0, 0);
				if (dumped) {
					smalltext_out16(g_menuscreen_w - 6 * me_sfont_h,
						g_menuscreen_h - me_mfont_h, "dumped", 0xffff);
					dumped = 0;
				}
				break;
			case 1: draw_frame_debug();
				break;
			case 2: pemu_forced_frame(1, 0);
				make_bg(1);
				PDebugShowSpriteStats((unsigned short *)g_menuscreen_ptr + (g_menuscreen_h/2 - 240/2)*g_menuscreen_w +
					g_menuscreen_w/2 - 320/2, g_menuscreen_w);
				break;
			case 3: memset(g_menuscreen_ptr, 0, g_menuscreen_w * g_menuscreen_h * 2);
				PDebugShowPalette(g_menuscreen_ptr, g_menuscreen_w);
				PDebugShowSprite((unsigned short *)g_menuscreen_ptr + g_menuscreen_w*120 + g_menuscreen_w/2 + 16,
					g_menuscreen_w, spr_offs);
				draw_text_debug(PDebugSpriteList(), spr_offs, 6);
				break;
			case 4: tmp = PDebug32x();
				draw_text_debug(tmp, 0, 0);
				break;
		}
		menu_draw_end();

		inp = in_menu_wait(PBTN_MOK|PBTN_MBACK|PBTN_MA2|PBTN_MA3|PBTN_L|PBTN_R |
					PBTN_UP|PBTN_DOWN|PBTN_LEFT|PBTN_RIGHT, NULL, 70);
		if (inp & PBTN_MBACK) return;
		if (inp & PBTN_L) { mode--; if (mode < 0) mode = 4; }
		if (inp & PBTN_R) { mode++; if (mode > 4) mode = 0; }
		switch (mode)
		{
			case 0:
				if (inp & PBTN_MOK)
					PDebugCPUStep();
				if (inp & PBTN_MA3) {
					while (inp & PBTN_MA3)
						inp = in_menu_wait_any(NULL, -1);
					mplayer_loop();
				}
				if ((inp & (PBTN_MA2|PBTN_LEFT)) == (PBTN_MA2|PBTN_LEFT)) {
					mkdir("dumps", 0777);
					PDebugDumpMem();
					while (inp & PBTN_MA2) inp = in_menu_wait_any(NULL, -1);
					dumped = 1;
				}
				break;
			case 1:
				if (inp & PBTN_LEFT)  PicoDrawMask ^= PDRAW_LAYERB_ON;
				if (inp & PBTN_RIGHT) PicoDrawMask ^= PDRAW_LAYERA_ON;
				if (inp & PBTN_DOWN)  PicoDrawMask ^= PDRAW_SPRITES_LOW_ON;
				if (inp & PBTN_UP)    PicoDrawMask ^= PDRAW_SPRITES_HI_ON;
				if (inp & PBTN_MA2)   PicoDrawMask ^= PDRAW_32X_ON;
				if (inp & PBTN_MOK) {
					PsndOut = NULL; // just in case
					PicoSkipFrame = 1;
					PicoFrame();
					PicoSkipFrame = 0;
					while (inp & PBTN_MOK) inp = in_menu_wait_any(NULL, -1);
				}
				break;
			case 3:
				if (inp & PBTN_DOWN)  spr_offs++;
				if (inp & PBTN_UP)    spr_offs--;
				if (spr_offs < 0) spr_offs = 0;
				break;
		}
	}
}

// ------------ main menu ------------

static void draw_frame_credits(void)
{
	smalltext_out16(4, 1, "build: " __DATE__ " " __TIME__, 0xe7fc);
}

static const char credits[] =
	"PicoDrive v" VERSION " (c) notaz, 2006-2013\n\n\n"
	"Credits:\n"
	"fDave: initial code\n"
#ifdef EMU_C68K
	"      Cyclone 68000 core\n"
#else
	"Stef, Chui: FAME/C 68k core\n"
#endif
#ifdef _USE_DRZ80
	"Reesy & FluBBa: DrZ80 core\n"
#else
	"Stef, NJ: CZ80 core\n"
#endif
	"MAME devs: SH2, YM2612 and SN76496 cores\n"
	"Eke, Stef: some Sega CD code\n"
	"Inder, ketchupgun: graphics\n"
#ifdef __GP2X__
	"Squidge: mmuhack\n"
	"Dzz: ARM940 sample\n"
#endif
	"\n"
	"special thanks (for docs, ideas):\n"
	" Charles MacDonald, Haze,\n"
	" Stephane Dallongeville,\n"
	" Lordus, Exophase, Rokas,\n"
	" Eke, Nemesis, Tasco Deluxe";

static void menu_main_draw_status(void)
{
	static time_t last_bat_read = 0;
	static int last_bat_val = -1;
	unsigned short *bp = g_screen_ptr;
	int bat_h = me_mfont_h * 2 / 3;
	int i, u, w, wfill, batt_val;
	struct tm *tmp;
	time_t ltime;
	char time_s[16];

	if (!(currentConfig.EmuOpt & EOPT_SHOW_RTC))
		return;

	ltime = time(NULL);
	tmp = gmtime(&ltime);
	strftime(time_s, sizeof(time_s), "%H:%M", tmp);

	text_out16(g_screen_width - me_mfont_w * 6, me_mfont_h + 2, time_s);

	if (ltime - last_bat_read > 10) {
		last_bat_read = ltime;
		last_bat_val = batt_val = plat_target_bat_capacity_get();
	}
	else
		batt_val = last_bat_val;

	if (batt_val < 0 || batt_val > 100)
		return;

	/* battery info */
	bp += (me_mfont_h * 2 + 2) * g_screen_width + g_screen_width - me_mfont_w * 3 - 3;
	for (i = 0; i < me_mfont_w * 2; i++)
		bp[i] = menu_text_color;
	for (i = 0; i < me_mfont_w * 2; i++)
		bp[i + g_screen_width * bat_h] = menu_text_color;
	for (i = 0; i <= bat_h; i++)
		bp[i * g_screen_width] =
		bp[i * g_screen_width + me_mfont_w * 2] = menu_text_color;
	for (i = 2; i < bat_h - 1; i++)
		bp[i * g_screen_width - 1] =
		bp[i * g_screen_width - 2] = menu_text_color;

	w = me_mfont_w * 2 - 1;
	wfill = batt_val * w / 100;
	for (u = 1; u < bat_h; u++)
		for (i = 0; i < wfill; i++)
			bp[(w - i) + g_screen_width * u] = menu_text_color;
}

static int main_menu_handler(int id, int keys)
{
	const char *ret_name;

	switch (id)
	{
	case MA_MAIN_RESUME_GAME:
		if (PicoGameLoaded)
			return 1;
		break;
	case MA_MAIN_SAVE_STATE:
		if (PicoGameLoaded)
			return menu_loop_savestate(0);
		break;
	case MA_MAIN_LOAD_STATE:
		if (PicoGameLoaded)
			return menu_loop_savestate(1);
		break;
	case MA_MAIN_RESET_GAME:
		if (PicoGameLoaded) {
			emu_reset_game();
			return 1;
		}
		break;
	case MA_MAIN_LOAD_ROM:
		rom_fname_reload = NULL;
		ret_name = menu_loop_romsel(rom_fname_loaded,
			sizeof(rom_fname_loaded), rom_exts, NULL);
		if (ret_name != NULL) {
			lprintf("selected file: %s\n", ret_name);
			rom_fname_reload = ret_name;
			engineState = PGS_ReloadRom;
			return 1;
		}
		break;
	case MA_MAIN_CHANGE_CD:
		if (PicoAHW & PAHW_MCD) {
			// if cd is loaded, cdd_unload() triggers eject and
			// returns 1, else we'll select and load new CD here
			if (!cdd_unload())
				menu_loop_tray();
			return 1;
		}
		break;
	case MA_MAIN_CREDITS:
		draw_menu_message(credits, draw_frame_credits);
		in_menu_wait(PBTN_MOK|PBTN_MBACK, NULL, 70);
		break;
	case MA_MAIN_EXIT:
		engineState = PGS_Quit;
		return 1;
	case MA_MAIN_PATCHES:
		if (PicoGameLoaded && PicoPatches) {
			menu_loop_patches();
			PicoPatchApply();
			menu_update_msg("Patches applied");
		}
		break;
	default:
		lprintf("%s: something unknown selected\n", __FUNCTION__);
		break;
	}

	return 0;
}

static menu_entry e_menu_main[] =
{
	mee_label     ("PicoDrive " VERSION),
	mee_label     (""),
	mee_label     (""),
	mee_label     (""),
	mee_handler_id("Resume game",        MA_MAIN_RESUME_GAME, main_menu_handler),
	mee_handler_id("Save State",         MA_MAIN_SAVE_STATE,  main_menu_handler),
	mee_handler_id("Load State",         MA_MAIN_LOAD_STATE,  main_menu_handler),
	mee_handler_id("Reset game",         MA_MAIN_RESET_GAME,  main_menu_handler),
	mee_handler_id("Load new ROM/ISO",   MA_MAIN_LOAD_ROM,    main_menu_handler),
	mee_handler_id("Change CD/ISO",      MA_MAIN_CHANGE_CD,   main_menu_handler),
	mee_handler   ("Change options",                          menu_loop_options),
	mee_handler   ("Configure controls",                      menu_loop_keyconfig),
	mee_handler_id("Credits",            MA_MAIN_CREDITS,     main_menu_handler),
	mee_handler_id("Patches / GameGenie",MA_MAIN_PATCHES,     main_menu_handler),
	mee_handler_id("Exit",               MA_MAIN_EXIT,        main_menu_handler),
	mee_end,
};

void menu_loop(void)
{
	static int sel = 0;

	me_enable(e_menu_main, MA_MAIN_RESUME_GAME, PicoGameLoaded);
	me_enable(e_menu_main, MA_MAIN_SAVE_STATE,  PicoGameLoaded);
	me_enable(e_menu_main, MA_MAIN_LOAD_STATE,  PicoGameLoaded);
	me_enable(e_menu_main, MA_MAIN_RESET_GAME,  PicoGameLoaded);
	me_enable(e_menu_main, MA_MAIN_CHANGE_CD,   PicoAHW & PAHW_MCD);
	me_enable(e_menu_main, MA_MAIN_PATCHES, PicoPatches != NULL);

	menu_enter(PicoGameLoaded);
	in_set_config_int(0, IN_CFG_BLOCKING, 1);
	me_loop_d(e_menu_main, &sel, NULL, menu_main_draw_status);

	if (PicoGameLoaded) {
		if (engineState == PGS_Menu)
			engineState = PGS_Running;
		/* wait until menu, ok, back is released */
		while (in_menu_wait_any(NULL, 50) & (PBTN_MENU|PBTN_MOK|PBTN_MBACK))
			;
	}

	in_set_config_int(0, IN_CFG_BLOCKING, 0);
	plat_video_menu_leave();
}

// --------- CD tray close menu ----------

static int mh_tray_load_cd(int id, int keys)
{
	const char *ret_name;

	rom_fname_reload = NULL;
	ret_name = menu_loop_romsel(rom_fname_loaded,
			sizeof(rom_fname_loaded), rom_exts, NULL);
	if (ret_name == NULL)
		return 0;

	rom_fname_reload = ret_name;
	engineState = PGS_RestartRun;
	return emu_swap_cd(ret_name);
}

static int mh_tray_nothing(int id, int keys)
{
	return 1;
}

static menu_entry e_menu_tray[] =
{
	mee_label  ("The CD tray has opened."),
	mee_label  (""),
	mee_label  (""),
	mee_handler("Load CD image",  mh_tray_load_cd),
	mee_handler("Insert nothing", mh_tray_nothing),
	mee_end,
};

int menu_loop_tray(void)
{
	int ret = 1, sel = 0;

	menu_enter(PicoGameLoaded);

	in_set_config_int(0, IN_CFG_BLOCKING, 1);
	me_loop(e_menu_tray, &sel);

	if (engineState != PGS_RestartRun) {
		engineState = PGS_RestartRun;
		ret = 0; /* no CD inserted */
	}

	while (in_menu_wait_any(NULL, 50) & (PBTN_MENU|PBTN_MOK|PBTN_MBACK))
		;
	in_set_config_int(0, IN_CFG_BLOCKING, 0);
	plat_video_menu_leave();

	return ret;
}

void menu_update_msg(const char *msg)
{
	strncpy(menu_error_msg, msg, sizeof(menu_error_msg));
	menu_error_msg[sizeof(menu_error_msg) - 1] = 0;

	menu_error_time = plat_get_ticks_ms();
	lprintf("msg: %s\n", menu_error_msg);
}

// ------------ util ------------

/* hidden options for config engine only */
static menu_entry e_menu_hidden[] =
{
	mee_onoff("Accurate sprites", MA_OPT_ACC_SPRITES, PicoOpt, 0x080),
	mee_onoff("autoload savestates", MA_OPT_AUTOLOAD_SAVE, g_autostateld_opt, 1),
	mee_end,
};

static menu_entry *e_menu_table[] =
{
	e_menu_options,
	e_menu_gfx_options,
	e_menu_adv_options,
	e_menu_cd_options,
#ifndef NO_32X
	e_menu_32x_options,
#endif
	e_menu_keyconfig,
	e_menu_hidden,
};

static menu_entry *me_list_table = NULL;
static menu_entry *me_list_i = NULL;

menu_entry *me_list_get_first(void)
{
	me_list_table = me_list_i = e_menu_table[0];
	return me_list_i;
}

menu_entry *me_list_get_next(void)
{
	int i;

	me_list_i++;
	if (me_list_i->name != NULL)
		return me_list_i;

	for (i = 0; i < array_size(e_menu_table); i++)
		if (me_list_table == e_menu_table[i])
			break;

	if (i + 1 < array_size(e_menu_table))
		me_list_table = me_list_i = e_menu_table[i + 1];
	else
		me_list_table = me_list_i = NULL;

	return me_list_i;
}

void menu_init(void)
{
	int i;

	menu_init_base();

	i = 0;
#if defined(_SVP_DRC) || defined(DRC_SH2)
	i = 1;
#endif
	me_enable(e_menu_adv_options, MA_OPT2_DYNARECS, i);

	i = me_id2offset(e_menu_gfx_options, MA_OPT_VOUT_MODE);
	e_menu_gfx_options[i].data = plat_target.vout_methods;
	me_enable(e_menu_gfx_options, MA_OPT_VOUT_MODE,
		plat_target.vout_methods != NULL);

	i = me_id2offset(e_menu_gfx_options, MA_OPT3_FILTERING);
	e_menu_gfx_options[i].data = plat_target.hwfilters;
	me_enable(e_menu_gfx_options, MA_OPT3_FILTERING,
		plat_target.hwfilters != NULL);

	me_enable(e_menu_gfx_options, MA_OPT2_GAMMA,
                plat_target.gamma_set != NULL);

	i = me_id2offset(e_menu_options, MA_OPT_CPU_CLOCKS);
	e_menu_options[i].enabled = 0;
	if (plat_target.cpu_clock_set != NULL) {
		e_menu_options[i].name = "CPU clock";
		e_menu_options[i].enabled = 1;
	}
}
