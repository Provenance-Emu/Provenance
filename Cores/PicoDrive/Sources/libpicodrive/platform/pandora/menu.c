#include "plat.h"

static int min(int x, int y) { return x < y ? x : y; }
static int max(int x, int y) { return x > y ? x : y; }

static const char *men_scaler[] = { "1x1, 1x1", "2x2, 3x2", "2x2, 2x2", "fullscreen", "custom", NULL };
static const char h_scaler[]    = "Scalers for 40 and 32 column modes\n"
				  "(320 and 256 pixel wide horizontal)";
static const char h_cscaler[]   = "Displays the scaler layer, you can resize it\n"
				  "using d-pad or move it using R+d-pad";

static int menu_loop_cscaler(int id, int keys)
{
	int was_layer_clipped = 0;
	unsigned int inp;

	currentConfig.scaling = SCALE_CUSTOM;

	pnd_setup_layer(1, g_layer_cx, g_layer_cy, g_layer_cw, g_layer_ch);
	pnd_restore_layer_data();

	menu_draw_begin(0, 1);
	menuscreen_memset_lines(g_menuscreen_ptr, 0, g_menuscreen_h);
	menu_draw_end();

	for (;;)
	{
		int top_x = max(0, -g_layer_cx * g_screen_ppitch / 800) + 1;
		int top_y = max(0, -g_layer_cy * g_screen_height / 480) + 1;
		char text[128];
		memcpy(g_screen_ptr, g_menubg_src_ptr,
			g_screen_ppitch * g_screen_height * 2);
		snprintf(text, sizeof(text), "%d,%d %dx%d",
			g_layer_cx, g_layer_cy, g_layer_cw, g_layer_ch);
		basic_text_out16_nf(g_screen_ptr, g_screen_ppitch,
			saved_start_col + top_x, saved_start_line + top_y, text);
		basic_text_out16_nf(g_screen_ptr, g_screen_ppitch, 2,
			g_screen_height - 20, "d-pad: resize, R+d-pad: move");
		plat_video_flip();

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
			int layer_clipped = 0;
			g_layer_cx = max(-320, min(g_layer_cx, 640));
			g_layer_cy = max(-240, min(g_layer_cy, 420));
			g_layer_cw = max(160, g_layer_cw);
			g_layer_ch = max( 60, g_layer_ch);
			if (g_layer_cx < 0 || g_layer_cx + g_layer_cw > 800)
				layer_clipped = 1;
			if (g_layer_cw > 800+400)
				g_layer_cw = 800+400;
			if (g_layer_cy < 0 || g_layer_cy + g_layer_ch > 480)
				layer_clipped = 1;
			if (g_layer_ch > 480+360)
				g_layer_ch = 480+360;
			// resize the layer
			pnd_setup_layer(1, g_layer_cx, g_layer_cy, g_layer_cw, g_layer_ch);
			if (layer_clipped || was_layer_clipped)
				emu_video_mode_change(saved_start_line, saved_line_count,
					saved_start_col, saved_col_count);
			was_layer_clipped = layer_clipped;
		}
	}

	pnd_setup_layer(0, g_layer_cx, g_layer_cy, g_layer_cw, g_layer_ch);

	return 0;
}

#define MENU_OPTIONS_GFX \
	mee_enum_h    ("Scaler",                   MA_OPT_SCALING,        currentConfig.scaling, \
	                                                                  men_scaler, h_scaler), \
	mee_onoff     ("Vsync",                    MA_OPT2_VSYNC,         currentConfig.EmuOpt, EOPT_VSYNC), \
	mee_cust_s_h  ("Setup custom scaler",      MA_NONE, 0,            menu_loop_cscaler, NULL, h_cscaler), \
	mee_range_hide("layer_x",                  MA_OPT3_LAYER_X,       g_layer_cx, -320, 640), \
	mee_range_hide("layer_y",                  MA_OPT3_LAYER_Y,       g_layer_cy, -240, 420), \
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

