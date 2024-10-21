/*
 * (C) Gražvydas "notaz" Ignotas, 2006-2012
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
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include "../input.h"
#include "soc.h"
#include "plat_gp2x.h"
#include "in_gp2x.h"

#define IN_GP2X_PREFIX "gp2x:"
#define IN_GP2X_NBUTTONS 32

/* note: in_gp2x handles combos (if 2 btns have the same bind,
 * both must be pressed for action to happen) */
static int in_gp2x_combo_keys = 0;
static int in_gp2x_combo_acts = 0;
static int gpiodev = -1;	/* Wiz only */

static int (*in_gp2x_get_bits)(void);

static const char *in_gp2x_keys[IN_GP2X_NBUTTONS] = {
	[0 ... IN_GP2X_NBUTTONS-1] = NULL,
	[GP2X_BTN_UP]    = "Up",    [GP2X_BTN_LEFT]   = "Left",
	[GP2X_BTN_DOWN]  = "Down",  [GP2X_BTN_RIGHT]  = "Right",
	[GP2X_BTN_START] = "Start", [GP2X_BTN_SELECT] = "Select",
	[GP2X_BTN_L]     = "L",     [GP2X_BTN_R]      = "R",
	[GP2X_BTN_A]     = "A",     [GP2X_BTN_B]      = "B",
	[GP2X_BTN_X]     = "X",     [GP2X_BTN_Y]      = "Y",
	[GP2X_BTN_VOL_DOWN] = "VOL DOWN",
	[GP2X_BTN_VOL_UP]   = "VOL UP",
	[GP2X_BTN_PUSH]     = "PUSH"
};


static int in_gp2x_get_mmsp2_bits(void)
{
	int value;
	value = memregs[0x1198>>1] & 0xff; // GPIO M
	if (value == 0xFD) value = 0xFA;
	if (value == 0xF7) value = 0xEB;
	if (value == 0xDF) value = 0xAF;
	if (value == 0x7F) value = 0xBE;
	value |= memregs[0x1184>>1] & 0xFF00; // GPIO C
	value |= memregs[0x1186>>1] << 16; // GPIO D
	value = ~value & 0x08c0ff55;

	return value;
}

static int in_gp2x_get_wiz_bits(void)
{
	int r, value = 0;
	r = read(gpiodev, &value, 4);
	if (value & 0x02)
		value |= 0x05;
	if (value & 0x08)
		value |= 0x14;
	if (value & 0x20)
		value |= 0x50;
	if (value & 0x80)
		value |= 0x41;

	/* convert to GP2X style */
	value &= 0x7ff55;
	if (value & (1 << 16))
		value |= 1 << GP2X_BTN_VOL_UP;
	if (value & (1 << 17))
		value |= 1 << GP2X_BTN_VOL_DOWN;
	if (value & (1 << 18))
		value |= 1 << GP2X_BTN_PUSH;
	value &= ~0x70000;

	return value;
}

static void in_gp2x_probe(const in_drv_t *drv)
{
	switch (gp2x_dev_id)
	{
	case GP2X_DEV_GP2X:
		in_gp2x_get_bits = in_gp2x_get_mmsp2_bits;
		break;
	case GP2X_DEV_WIZ:
		gpiodev = open("/dev/GPIO", O_RDONLY);
		if (gpiodev < 0) {
			perror("in_gp2x: couldn't open /dev/GPIO");
			return;
		}
		in_gp2x_get_bits = in_gp2x_get_wiz_bits;
		break;
	// we'll use evdev for Caanoo
	default:
		return;
	}

	in_register(IN_GP2X_PREFIX "GP2X pad", -1, NULL,
		IN_GP2X_NBUTTONS, in_gp2x_keys, 1);
}

static void in_gp2x_free(void *drv_data)
{
	if (gpiodev >= 0) {
		close(gpiodev);
		gpiodev = -1;
	}
}

static const char * const *
in_gp2x_get_key_names(const in_drv_t *drv, int *count)
{
	*count = IN_GP2X_NBUTTONS;
	return in_gp2x_keys;
}

/* ORs result with pressed buttons */
static int in_gp2x_update(void *drv_data, const int *binds, int *result)
{
	int type_start = 0;
	int i, t, keys;

	keys = in_gp2x_get_bits();

	if (keys & in_gp2x_combo_keys) {
		result[IN_BINDTYPE_EMU] = in_combos_do(keys, binds, GP2X_BTN_PUSH,
						in_gp2x_combo_keys, in_gp2x_combo_acts);
		type_start = IN_BINDTYPE_PLAYER12;
	}

	for (i = 0; keys; i++, keys >>= 1) {
		if (!(keys & 1))
			continue;

		for (t = type_start; t < IN_BINDTYPE_COUNT; t++)
			result[t] |= binds[IN_BIND_OFFS(i, t)];
	}

	return 0;
}

int in_gp2x_update_keycode(void *data, int *is_down)
{
	static int old_val = 0;
	int val, diff, i;

	val = in_gp2x_get_bits();
	diff = val ^ old_val;
	if (diff == 0)
		return -1;

	/* take one bit only */
	for (i = 0; i < sizeof(diff)*8; i++)
		if (diff & (1<<i))
			break;

	old_val ^= 1 << i;

	if (is_down)
		*is_down = !!(val & (1<<i));
	return i;
}

static const struct {
	short key;
	short pbtn;
} key_pbtn_map[] =
{
	{ GP2X_BTN_UP,		PBTN_UP },
	{ GP2X_BTN_DOWN,	PBTN_DOWN },
	{ GP2X_BTN_LEFT,	PBTN_LEFT },
	{ GP2X_BTN_RIGHT,	PBTN_RIGHT },
	{ GP2X_BTN_B,		PBTN_MOK },
	{ GP2X_BTN_X,		PBTN_MBACK },
	{ GP2X_BTN_A,		PBTN_MA2 },
	{ GP2X_BTN_Y,		PBTN_MA3 },
	{ GP2X_BTN_L,		PBTN_L },
	{ GP2X_BTN_R,		PBTN_R },
	{ GP2X_BTN_SELECT,	PBTN_MENU },
};

#define KEY_PBTN_MAP_SIZE (sizeof(key_pbtn_map) / sizeof(key_pbtn_map[0]))

static int in_gp2x_menu_translate(void *drv_data, int keycode, char *charcode)
{
	int i;
	if (keycode < 0)
	{
		/* menu -> kc */
		keycode = -keycode;
		for (i = 0; i < KEY_PBTN_MAP_SIZE; i++)
			if (key_pbtn_map[i].pbtn == keycode)
				return key_pbtn_map[i].key;
	}
	else
	{
		for (i = 0; i < KEY_PBTN_MAP_SIZE; i++)
			if (key_pbtn_map[i].key == keycode)
				return key_pbtn_map[i].pbtn;
	}

	return 0;
}

#if 0 // TODO: move to pico
static const struct {
	short code;
	char btype;
	char bit;
} in_gp2x_defbinds[] =
{
	/* MXYZ SACB RLDU */
	{ BTN_UP,	IN_BINDTYPE_PLAYER12, 0 },
	{ BTN_DOWN,	IN_BINDTYPE_PLAYER12, 1 },
	{ BTN_LEFT,	IN_BINDTYPE_PLAYER12, 2 },
	{ BTN_RIGHT,	IN_BINDTYPE_PLAYER12, 3 },
	{ BTN_X,	IN_BINDTYPE_PLAYER12, 4 },	/* B */
	{ BTN_B,	IN_BINDTYPE_PLAYER12, 5 },	/* C */
	{ BTN_A,	IN_BINDTYPE_PLAYER12, 6 },	/* A */
	{ BTN_START,	IN_BINDTYPE_PLAYER12, 7 },
	{ BTN_SELECT,	IN_BINDTYPE_EMU, PEVB_MENU },
//	{ BTN_Y,	IN_BINDTYPE_EMU, PEVB_SWITCH_RND },
	{ BTN_L,	IN_BINDTYPE_EMU, PEVB_STATE_SAVE },
	{ BTN_R,	IN_BINDTYPE_EMU, PEVB_STATE_LOAD },
	{ BTN_VOL_UP,	IN_BINDTYPE_EMU, PEVB_VOL_UP },
	{ BTN_VOL_DOWN,	IN_BINDTYPE_EMU, PEVB_VOL_DOWN },
	{ 0, 0, 0 },
};
#endif

/* remove binds of missing keys, count remaining ones */
static int in_gp2x_clean_binds(void *drv_data, int *binds, int *def_binds)
{
	int i, count = 0;
//	int eb, have_vol = 0, have_menu = 0;

	for (i = 0; i < IN_GP2X_NBUTTONS; i++) {
		int t, offs;
		for (t = 0; t < IN_BINDTYPE_COUNT; t++) {
			offs = IN_BIND_OFFS(i, t);
			if (in_gp2x_keys[i] == NULL)
				binds[offs] = def_binds[offs] = 0;
			if (binds[offs])
				count++;
		}
#if 0
		eb = binds[IN_BIND_OFFS(i, IN_BINDTYPE_EMU)];
		if (eb & (PEV_VOL_DOWN|PEV_VOL_UP))
			have_vol = 1;
		if (eb & PEV_MENU)
			have_menu = 1;
#endif
	}

	// TODO: move to pico
#if 0
	/* autobind some important keys, if they are unbound */
	if (!have_vol && binds[GP2X_BTN_VOL_UP] == 0 && binds[GP2X_BTN_VOL_DOWN] == 0) {
		binds[IN_BIND_OFFS(GP2X_BTN_VOL_UP, IN_BINDTYPE_EMU)]   = PEV_VOL_UP;
		binds[IN_BIND_OFFS(GP2X_BTN_VOL_DOWN, IN_BINDTYPE_EMU)] = PEV_VOL_DOWN;
		count += 2;
	}

	if (!have_menu) {
		binds[IN_BIND_OFFS(GP2X_BTN_SELECT, IN_BINDTYPE_EMU)] = PEV_MENU;
		count++;
	}
#endif

	in_combos_find(binds, GP2X_BTN_PUSH, &in_gp2x_combo_keys, &in_gp2x_combo_acts);

	return count;
}

static const in_drv_t in_gp2x_drv = {
	.prefix         = IN_GP2X_PREFIX,
	.probe          = in_gp2x_probe,
	.free           = in_gp2x_free,
	.get_key_names  = in_gp2x_get_key_names,
	.clean_binds    = in_gp2x_clean_binds,
	.update         = in_gp2x_update,
	.update_keycode = in_gp2x_update_keycode,
	.menu_translate = in_gp2x_menu_translate,
};

void in_gp2x_init(const struct in_default_bind *defbinds)
{
	if (gp2x_dev_id == GP2X_DEV_WIZ)
		in_gp2x_keys[GP2X_BTN_START] = "MENU";
	
	in_gp2x_combo_keys = in_gp2x_combo_acts = 0;

	in_register_driver(&in_gp2x_drv, defbinds, NULL);
}

