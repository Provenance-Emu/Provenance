
extern int g_layer_cx, g_layer_cy;
extern int g_layer_cw, g_layer_ch;

void pnd_menu_init(void);
int  pnd_setup_layer(int enabled, int x, int y, int w, int h);
void pnd_restore_layer_data(void);

enum {
	SCALE_1x1,
	SCALE_2x2_3x2,
	SCALE_2x2_2x2,
	SCALE_FULLSCREEN,
	SCALE_CUSTOM,
};

