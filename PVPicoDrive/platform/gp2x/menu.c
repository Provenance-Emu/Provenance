#include "../libpicofe/gp2x/plat_gp2x.h"

// ------------ gfx options menu ------------


const char *men_scaling_opts[] = { "OFF", "software", "hardware", NULL };

#define MENU_OPTIONS_GFX \
	mee_enum      ("Horizontal scaling",       MA_OPT_SCALING,        currentConfig.scaling, men_scaling_opts), \
	mee_enum      ("Vertical scaling",         MA_OPT_VSCALING,       currentConfig.vscaling, men_scaling_opts), \
	mee_onoff     ("Tearing Fix",              MA_OPT_TEARING_FIX,    currentConfig.EmuOpt, EOPT_WIZ_TEAR_FIX), \
	/*mee_onoff     ("A_SN's gamma curve",       MA_OPT2_A_SN_GAMMA,    currentConfig.EmuOpt, EOPT_A_SN_GAMMA),*/ \
	mee_onoff     ("Vsync",                    MA_OPT2_VSYNC,         currentConfig.EmuOpt, EOPT_VSYNC),

#define MENU_OPTIONS_ADV \
	mee_onoff     ("Use second CPU for sound", MA_OPT_ARM940_SOUND,   PicoOpt, POPT_EXT_FM), \


static menu_entry e_menu_adv_options[];
static menu_entry e_menu_gfx_options[];
static menu_entry e_menu_options[];
static menu_entry e_menu_keyconfig[];

void gp2x_menu_init(void)
{
	/* disable by default.. */
	me_enable(e_menu_adv_options, MA_OPT_ARM940_SOUND, 0);
	me_enable(e_menu_gfx_options, MA_OPT_TEARING_FIX, 0);
	me_enable(e_menu_gfx_options, MA_OPT2_GAMMA, 0);
	me_enable(e_menu_gfx_options, MA_OPT2_A_SN_GAMMA, 0);

	switch (gp2x_dev_id) {
	case GP2X_DEV_GP2X:
		me_enable(e_menu_adv_options, MA_OPT_ARM940_SOUND, 1);
		me_enable(e_menu_gfx_options, MA_OPT2_GAMMA, 1);
		me_enable(e_menu_gfx_options, MA_OPT2_A_SN_GAMMA, 1);
		break;
	case GP2X_DEV_WIZ:
		me_enable(e_menu_gfx_options, MA_OPT_TEARING_FIX, 1);
		break;
	case GP2X_DEV_CAANOO:
		break;
	default:
		break;
	}

	if (gp2x_dev_id != GP2X_DEV_GP2X)
		men_scaling_opts[2] = NULL; /* leave only off and sw */

	if (gp2x_dev_id != GP2X_DEV_CAANOO)
		me_enable(e_menu_keyconfig, MA_CTRL_DEADZONE, 0);
}

