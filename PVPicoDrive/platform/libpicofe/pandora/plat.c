/*
 * (C) Gražvydas "notaz" Ignotas, 2011,2012
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

static const char * const pandora_gpio_keys[KEY_MAX + 1] = {
	[0 ... KEY_MAX] = NULL,
	[KEY_UP]	= "Up",
	[KEY_LEFT]	= "Left",
	[KEY_RIGHT]	= "Right",
	[KEY_DOWN]	= "Down",
	[KEY_HOME]	= "(A)",
	[KEY_PAGEDOWN]	= "(X)",
	[KEY_END]	= "(B)",
	[KEY_PAGEUP]	= "(Y)",
	[KEY_RIGHTSHIFT]= "(L)",
	[KEY_RIGHTCTRL]	= "(R)",
	[KEY_LEFTALT]	= "Start",
	[KEY_LEFTCTRL]	= "Select",
	[KEY_MENU]	= "Pandora",
};

static const char pnd_script_base[] = "sudo -n /usr/pandora/scripts";

static void scan_for_filters(void)
{
	struct dirent *ent;
	int i, count = 0;
	const char **mfilters;
	char buff[64];
	DIR *dir;

	dir = opendir("/etc/pandora/conf/dss_fir");
	if (dir == NULL) {
		perror("filter opendir");
		return;
	}

	while (1) {
		errno = 0;
		ent = readdir(dir);
		if (ent == NULL) {
			if (errno != 0)
				perror("readdir");
			break;
		}

		if (ent->d_type != DT_REG && ent->d_type != DT_LNK)
			continue;

		count++;
	}

	if (count == 0)
		return;

	mfilters = calloc(count + 1, sizeof(mfilters[0]));
	if (mfilters == NULL)
		return;

	rewinddir(dir);
	for (i = 0; (ent = readdir(dir)); ) {
		size_t len;

		if (ent->d_type != DT_REG && ent->d_type != DT_LNK)
			continue;

		len = strlen(ent->d_name);

		// skip pre-HF5 extra files
		if (len >= 3 && strcmp(ent->d_name + len - 3, "_v3") == 0)
			continue;
		if (len >= 3 && strcmp(ent->d_name + len - 3, "_v5") == 0)
			continue;

		// have to cut "_up_h" for pre-HF5
		if (len > 5 && strcmp(ent->d_name + len - 5, "_up_h") == 0)
			len -= 5;

		if (len > sizeof(buff) - 1)
			continue;

		strncpy(buff, ent->d_name, len);
		buff[len] = 0;
		mfilters[i] = strdup(buff);
		if (mfilters[i] != NULL)
			i++;
	}
	closedir(dir);

	plat_target.hwfilters = mfilters;
}

static int do_system(const char *cmd)
{
	int ret;

	ret = system(cmd);
	if (ret >= 0)
		ret = 0;

	return ret;
}

static int read_int_from_file(const char *fname)
{
	int ret = -1;
	FILE *f;

	f = fopen(fname, "r");
	if (f) {
		fscanf(f, "%d", &ret);
		fclose(f);
	}
	return ret;
}

static int lcdrate_set(int is_pal)
{
	static int old_pal = -1;
	char buf[128];

	if (is_pal == old_pal)
		return 0;
	old_pal = is_pal;

	snprintf(buf, sizeof(buf), "%s/op_lcdrate.sh %d",
			pnd_script_base, is_pal ? 50 : 60);
	return do_system(buf);
}

static int hwfilter_set(int which)
{
	static int old_filter = -1;
	char buf[128];
	int i;

	if (plat_target.hwfilters == NULL)
		return -1;

	if (which == old_filter)
		return 0;

	for (i = 0; i <= which; i++)
		if (plat_target.hwfilters[i] == NULL)
			return -1;

	old_filter = which;

	snprintf(buf, sizeof(buf), "%s/op_videofir.sh %s",
		pnd_script_base, plat_target.hwfilters[which]);
	return do_system(buf);
}

static int cpu_clock_get(void)
{
	return read_int_from_file("/proc/pandora/cpu_mhz_max");
}

static int cpu_clock_set(int cpu_clock)
{
	char buf[128];

	if (cpu_clock < 14)
		return -1;

	if (cpu_clock == cpu_clock_get())
		return 0;

	snprintf(buf, sizeof(buf),
		 "unset DISPLAY; echo y | %s/op_cpuspeed.sh %d",
		 pnd_script_base, cpu_clock);
	return do_system(buf);
}

static int bat_capacity_get(void)
{
	return read_int_from_file("/sys/class/power_supply/bq27500-0/capacity");
}

static int gamma_set(int val, int black_level)
{
	char buf[128];

	snprintf(buf, sizeof(buf), "%s/op_gamma.sh -b %d %.2f",
		 pnd_script_base, black_level, (float)val / 100.0f);
	return do_system(buf);
}

/* For now, this only switches tv-out to appropriate fb.
 * Maybe this could control actual layers too? */
static int switch_layer(int which, int enable)
{
	static int was_ovl_enabled = -1;
	int tv_enabled = 0;
	char buf[128];
	int ret;

	if (which != 1)
		return -1;
	if (enable == was_ovl_enabled)
		return 0;

	was_ovl_enabled = -1;

	tv_enabled = read_int_from_file(
		   "/sys/devices/platform/omapdss/display1/enabled");
	if (tv_enabled < 0)
		return -1;

	if (!tv_enabled) {
		// tv-out not enabled
		return 0;
	}

	snprintf(buf, sizeof(buf), "%s/op_tvout.sh -l %d",
		 pnd_script_base, enable);
	ret = do_system(buf);
	if (ret == 0)
		was_ovl_enabled = enable;

	return ret;
}

struct plat_target plat_target = {
	cpu_clock_get,
	cpu_clock_set,
	bat_capacity_get,
	hwfilter_set,
	lcdrate_set,
	gamma_set,
	.switch_layer = switch_layer,
};

int plat_target_init(void)
{
	scan_for_filters();

	return 0;
}

/* to be called after in_probe */
void plat_target_setup_input(void)
{
	int gpiokeys_id;

	gpiokeys_id = in_name_to_id("evdev:gpio-keys");
	in_set_config(gpiokeys_id, IN_CFG_KEY_NAMES,
		      pandora_gpio_keys, sizeof(pandora_gpio_keys));
	in_set_config(gpiokeys_id, IN_CFG_DEFAULT_DEV, NULL, 0);
}

void plat_target_finish(void)
{
}
