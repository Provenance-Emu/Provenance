/*
 * (C) notaz, 2013
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <dirent.h>
#include <linux/input.h>
#include <errno.h>

#include "../plat.h"
#include "../input.h"
#include "plat_gp2x.h"
#include "soc.h"

int default_cpu_clock;
int gp2x_dev_id;

static const char * const caanoo_keys[KEY_MAX + 1] = {
	[0 ... KEY_MAX] = NULL,
	[KEY_UP]	= "Up",
	[KEY_LEFT]	= "Left",
	[KEY_RIGHT]	= "Right",
	[KEY_DOWN]	= "Down",
	[BTN_TRIGGER]	= "A",
	[BTN_THUMB]	= "X",
	[BTN_THUMB2]	= "B",
	[BTN_TOP]	= "Y",
	[BTN_TOP2]	= "L",
	[BTN_PINKIE]	= "R",
	[BTN_BASE]	= "Home",
	[BTN_BASE2]	= "Lock",
	[BTN_BASE3]	= "I",
	[BTN_BASE4]	= "II",
	[BTN_BASE5]	= "Push",
};

/* to be filled by mmsp2/pollux _init */
struct plat_target plat_target;

int plat_target_init(void)
{
	gp2x_soc_t soc;
	FILE *f;

	soc = soc_detect();
	switch (soc)
	{
	case SOCID_MMSP2:
		mmsp2_init();
		default_cpu_clock = 200;
		gp2x_dev_id = GP2X_DEV_GP2X;
		break;
	case SOCID_POLLUX:
		pollux_init();
		default_cpu_clock = 533;
		f = fopen("/dev/accel", "rb");
		if (f) {
			printf("detected Caanoo\n");
			gp2x_dev_id = GP2X_DEV_CAANOO;
			fclose(f);
		}
		else {
			printf("detected Wiz\n");
			gp2x_dev_id = GP2X_DEV_WIZ;
		}
		break;
	default:
		printf("could not recognize SoC.\n");
		break;
	}

	return 0;
}

/* to be called after in_probe */
void plat_target_setup_input(void)
{
	if (gp2x_dev_id == GP2X_DEV_CAANOO)
		in_set_config(in_name_to_id("evdev:pollux-analog"),
			IN_CFG_KEY_NAMES,
			caanoo_keys, sizeof(caanoo_keys));
}

void plat_target_finish(void)
{
	gp2x_soc_t soc;

	soc = soc_detect();
	switch (soc)
	{
	case SOCID_MMSP2:
		mmsp2_finish();
		break;
	case SOCID_POLLUX:
		pollux_finish();
		break;
	default:
		break;
	}
}
