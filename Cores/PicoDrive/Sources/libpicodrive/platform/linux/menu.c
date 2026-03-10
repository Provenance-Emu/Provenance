// ------------ gfx options menu ------------

#include "../libpicofe/plat_sdl.h"

static const char *men_scaling_opts[] = { "OFF", "software", "hardware", NULL };
static const char *men_filter_opts[] = { "nearest", "smoother", "bilinear 1", "bilinear 2", NULL };

static const char h_scale[] = "Hardware scaling might not work on some devices";
static const char h_stype[] = "Scaler algorithm for software scaling";

static const char *mgn_windowsize(int id, int *offs)
{
	int scale = g_menuscreen_w / 320;

	if (g_menuscreen_w == scale*320 && g_menuscreen_h == scale*240)
		sprintf(static_buff, "%dx%d", scale*320, scale*240);
	else	sprintf(static_buff, "custom");
	return static_buff;
}

static int mh_windowsize(int id, int keys)
{
	if (keys & (PBTN_LEFT|PBTN_RIGHT)) { // multi choice
		int scale = g_menuscreen_w / 320;
		if (keys & PBTN_RIGHT) scale++;
		if (keys & PBTN_LEFT ) scale--;
		if (scale <= 0) scale = 1;
		g_menuscreen_w = scale*320;
		g_menuscreen_h = scale*240;
		return 0;
	}
	return 1;
}

#define MENU_OPTIONS_GFX \
	mee_cust_s_h  ("Window size",            MA_OPT_VOUT_SIZE, 0,mh_windowsize, mgn_windowsize, NULL), \
	mee_enum_h    ("Horizontal scaling",     MA_OPT_SCALING, currentConfig.scaling, men_scaling_opts, h_scale), \
	mee_enum_h    ("Vertical scaling",       MA_OPT_VSCALING, currentConfig.vscaling, men_scaling_opts, h_scale), \
	mee_enum_h    ("Scaler type",            MA_OPT3_FILTERING, currentConfig.filter, men_filter_opts, h_stype), \

#define MENU_OPTIONS_ADV

static menu_entry e_menu_keyconfig[], e_menu_gfx_options[];

void linux_menu_init(void)
{
	me_enable(e_menu_gfx_options, MA_OPT_VOUT_SIZE, plat_sdl_is_windowed());
	me_enable(e_menu_keyconfig, MA_CTRL_DEADZONE, 0);
}

