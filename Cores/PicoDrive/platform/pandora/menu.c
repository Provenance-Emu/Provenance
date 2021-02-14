#include "plat.h"

static const char *men_scaler[] = { "1x1, 1x1", "2x2, 3x2", "2x2, 2x2", "fullscreen", "custom", NULL };
static const char h_scaler[]    = "Scalers for 40 and 32 column modes\n"
				  "(320 and 256 pixel wide horizontal)";
static const char h_cscaler[]   = "Displays the scaler layer, you can resize it\n"
				  "using d-pad or move it using R+d-pad";

static int menu_loop_cscaler(int id, int keys)
{
	unsigned int inp;

	currentConfig.scaling = SCALE_CUSTOM;

	pnd_setup_layer(1, g_layer_cx, g_layer_cy, g_layer_cw, g_layer_ch);
	pnd_restore_layer_data();

	for (;;)
	{
		menu_draw_begin(0, 1);
		memset(g_menuscreen_ptr, 0, g_menuscreen_w * g_menuscreen_h * 2);
		text_out16(2, 480 - 18, "%dx%d | d-pad to resize, R+d-pad to move", g_layer_cw, g_layer_ch);
		menu_draw_end();

		inp = in_menu_wait(PBTN_UP|PBTN_DOWN|PBTN_LEFT|PBTN_RIGHT
				   |PBTN_R|PBTN_MOK|PBTN_MBACK, NULL, 40);
		if (inp & PBTN_UP)    g_layer_cy--;
		if (inp & PBTN_DOWN)  g_layer_cy++;
		if (inp & PBTN_LEFT)  g_layer_cx--;
		if (inp & PBTN_RIGHT) g_layer_cx++;
		if (!(inp & PBTN_R)) {
			if (inp & PBTN_UP)    g_layer_ch += 2;
			if (inp & PBTN_DOWN)  g_layer_ch -= 2;
			if (inp & PBTN_LEFT)  g_layer_cw += 2;
			if (inp & PBTN_RIGHT) g_layer_cw -= 2;
		}
		if (inp & (PBTN_MOK|PBTN_MBACK))
			break;

		if (inp & (PBTN_UP|PBTN_DOWN|PBTN_LEFT|PBTN_RIGHT)) {
			if (g_layer_cx < 0)   g_layer_cx = 0;
			if (g_layer_cx > 640) g_layer_cx = 640;
			if (g_layer_cy < 0)   g_layer_cy = 0;
			if (g_layer_cy > 420) g_layer_cy = 420;
			if (g_layer_cw < 160) g_layer_cw = 160;
			if (g_layer_ch < 60)  g_layer_ch = 60;
			if (g_layer_cx + g_layer_cw > 800)
				g_layer_cw = 800 - g_layer_cx;
			if (g_layer_cy + g_layer_ch > 480)
				g_layer_ch = 480 - g_layer_cy;
			pnd_setup_layer(1, g_layer_cx, g_layer_cy, g_layer_cw, g_layer_ch);
		}
	}

	pnd_setup_layer(0, g_layer_cx, g_layer_cy, g_layer_cw, g_layer_ch);

	return 0;
}

#define MENU_OPTIONS_GFX \
	mee_enum_h    ("Scaler",                   MA_OPT_SCALING,        currentConfig.scaling, \
	                                                                  men_scaler, h_scaler), \
	mee_onoff     ("Vsync",                    MA_OPT2_VSYNC,         currentConfig.EmuOpt, EOPT_VSYNC), \
	mee_cust_h    ("Setup custom scaler",      MA_NONE,               menu_loop_cscaler, NULL, h_cscaler), \
	mee_range_hide("layer_x",                  MA_OPT3_LAYER_X,       g_layer_cx, 0, 640), \
	mee_range_hide("layer_y",                  MA_OPT3_LAYER_Y,       g_layer_cy, 0, 420), \
	mee_range_hide("layer_w",                  MA_OPT3_LAYER_W,       g_layer_cw, 160, 800), \
	mee_range_hide("layer_h",                  MA_OPT3_LAYER_H,       g_layer_ch,  60, 480), \

#define MENU_OPTIONS_ADV

static menu_entry e_menu_gfx_options[];
static menu_entry e_menu_options[];
static menu_entry e_menu_keyconfig[];

void pnd_menu_init(void)
{
	me_enable(e_menu_keyconfig, MA_CTRL_DEADZONE, 0);
}

