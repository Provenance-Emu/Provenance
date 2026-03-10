
static const char *men_vscaling_opts[] = { "OFF", "fullscreen", "borderless", NULL };
static const char *men_hscaling_opts[] = { "1:1", "4:3", "extended", "fullwidth", NULL };
static const char *men_filter_opts[] = { "nearest", "bilinear", NULL };

static const char h_8bit[] = "This option only works for 8bit renderers";

#define MENU_OPTIONS_GFX \
	mee_enum    ("Vertical scaling",   MA_OPT_VSCALING,   currentConfig.vscaling, men_vscaling_opts), \
	mee_enum    ("Aspect ratio",       MA_OPT_SCALING,    currentConfig.scaling, men_hscaling_opts), \
	mee_enum    ("Scaler type",        MA_OPT3_FILTERING, currentConfig.filter, men_filter_opts), \
	mee_range_h ("Gamma adjustment",   MA_OPT3_GAMMAA,    currentConfig.gamma, -4, 16, h_8bit), \
	mee_range_h ("Black level",        MA_OPT3_BLACKLVL,  currentConfig.gamma2, 0,  2, h_8bit), \
	mee_onoff   ("Wait for vsync",     MA_OPT3_VSYNC,     currentConfig.EmuOpt, EOPT_VSYNC), \

#define MENU_OPTIONS_ADV

static menu_entry e_menu_sms_options[];
static menu_entry e_menu_keyconfig[];

void psp_menu_init(void)
{
	me_enable(e_menu_sms_options, MA_SMSOPT_GHOSTING, 0);
	me_enable(e_menu_keyconfig, MA_CTRL_DEADZONE, 0);
}
