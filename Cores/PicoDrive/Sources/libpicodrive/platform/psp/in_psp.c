/*
 * PicoDrive input driver for PSP
 *
 * (C) Gražvydas "notaz" Ignotas, 2006-2012
 * (C) irixxxx 2020
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

#include "../libpicofe/input.h"
#include "psp.h"
#include "in_psp.h"

#define IN_PSP_PREFIX "psp:"
#define IN_PSP_NBUTTONS 32

/* note: in_psp handles combos (if 2 btns have the same bind,
 * both must be pressed for action to happen) */
static int in_psp_combo_keys = 0;
static int in_psp_combo_acts = 0;


static const char *in_psp_keys[IN_PSP_NBUTTONS] = {
	[0 ... IN_PSP_NBUTTONS-1] = NULL,
};


/* calculate bit number from bit mask (logarithm to the basis 2) */
static int lg2(unsigned v)
{
	/* credits to https://graphics.stanford.edu/~seander/bithacks.html */
	int r, s;

	r = (v > 0xFFFF) << 4; v >>= r;
	s = (v > 0xFF  ) << 3; v >>= s; r |= s;
	s = (v > 0xF   ) << 2; v >>= s; r |= s;
	s = (v > 0x3   ) << 1; v >>= s; r |= s;
					r |= (v >> 1);
	return r;
}

static unsigned in_psp_get_bits(void)
{
	unsigned mask = PSP_NUB_UP|PSP_NUB_DOWN|PSP_NUB_LEFT|PSP_NUB_RIGHT |
	    PSP_CTRL_UP|PSP_CTRL_DOWN|PSP_CTRL_LEFT|PSP_CTRL_RIGHT |
	    PSP_CTRL_CIRCLE|PSP_CTRL_CROSS|PSP_CTRL_TRIANGLE|PSP_CTRL_SQUARE |
	    PSP_CTRL_LTRIGGER|PSP_CTRL_RTRIGGER|PSP_CTRL_SELECT|PSP_CTRL_START;

	return psp_pad_read(0) & mask;
}

static void in_psp_probe(const in_drv_t *drv)
{
	in_register(IN_PSP_PREFIX "PSP pad", -1, NULL,
		IN_PSP_NBUTTONS, in_psp_keys, 1);
}

static void in_psp_free(void *drv_data)
{
}

static const char * const *
in_psp_get_key_names(const in_drv_t *drv, int *count)
{
	*count = IN_PSP_NBUTTONS;
	return in_psp_keys;
}

/* ORs result with pressed buttons */
static int in_psp_update(void *drv_data, const int *binds, int *result)
{
	int type_start = 0;
	int i, t;
	unsigned keys;

	keys = in_psp_get_bits();

	if (keys & in_psp_combo_keys) {
		result[IN_BINDTYPE_EMU] = in_combos_do(keys, binds, IN_PSP_NBUTTONS,
						in_psp_combo_keys, in_psp_combo_acts);
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

int in_psp_update_keycode(void *data, int *is_down)
{
	static unsigned old_val = 0;
	unsigned val, diff, i;

	val = in_psp_get_bits();
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

static struct {
	unsigned key;
	int pbtn;
} key_pbtn_map[] =
{
	{ PSP_CTRL_UP,		PBTN_UP },
	{ PSP_CTRL_DOWN,	PBTN_DOWN },
	{ PSP_CTRL_LEFT,	PBTN_LEFT },
	{ PSP_CTRL_RIGHT,	PBTN_RIGHT },
	{ PSP_CTRL_CIRCLE,	PBTN_MOK },
	{ PSP_CTRL_CROSS,	PBTN_MBACK },
	{ PSP_CTRL_TRIANGLE,	PBTN_MA2 },
	{ PSP_CTRL_SQUARE,	PBTN_MA3 },
	{ PSP_CTRL_LTRIGGER,	PBTN_L },
	{ PSP_CTRL_RTRIGGER,	PBTN_R },
};

#define KEY_PBTN_MAP_SIZE (sizeof(key_pbtn_map) / sizeof(key_pbtn_map[0]))

static int in_psp_menu_translate(void *drv_data, int keycode, char *charcode)
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

/* remove binds of missing keys, count remaining ones */
static int in_psp_clean_binds(void *drv_data, int *binds, int *def_binds)
{
	int i, count = 0;

	for (i = 0; i < IN_PSP_NBUTTONS; i++) {
		int t, offs;
		for (t = 0; t < IN_BINDTYPE_COUNT; t++) {
			offs = IN_BIND_OFFS(i, t);
			if (in_psp_keys[i] == NULL)
				binds[offs] = def_binds[offs] = 0;
			if (binds[offs])
				count++;
		}
	}

	in_combos_find(binds, IN_PSP_NBUTTONS, &in_psp_combo_keys, &in_psp_combo_acts);

	return count;
}

static const in_drv_t in_psp_drv = {
	.prefix         = IN_PSP_PREFIX,
	.probe          = in_psp_probe,
	.free           = in_psp_free,
	.get_key_names  = in_psp_get_key_names,
	.clean_binds    = in_psp_clean_binds,
	.update         = in_psp_update,
	.update_keycode = in_psp_update_keycode,
	.menu_translate = in_psp_menu_translate,
};

void in_psp_init(struct in_default_bind *defbinds)
{
	int i;

	/* PSP keys have bit masks, Picodrive wants bit numbers */
	for (i = 0; defbinds[i].code; i++)
		defbinds[i].code = lg2(defbinds[i].code);
	for (i = 0; i < KEY_PBTN_MAP_SIZE; i++)
		key_pbtn_map[i].key = lg2(key_pbtn_map[i].key);

	in_psp_combo_keys = in_psp_combo_acts = 0;

	/* fill keys array, converting key bitmasks to bit numbers */
	in_psp_keys[lg2(PSP_CTRL_UP)] = "Up";
	in_psp_keys[lg2(PSP_CTRL_LEFT)] = "Left";
	in_psp_keys[lg2(PSP_CTRL_DOWN)] = "Down";
	in_psp_keys[lg2(PSP_CTRL_RIGHT)] = "Right";
	in_psp_keys[lg2(PSP_CTRL_START)] = "Start";
	in_psp_keys[lg2(PSP_CTRL_SELECT)] = "Select";
	in_psp_keys[lg2(PSP_CTRL_LTRIGGER)] = "L";
	in_psp_keys[lg2(PSP_CTRL_RTRIGGER)] = "R";
	in_psp_keys[lg2(PSP_CTRL_TRIANGLE)] = "Triangle";
	in_psp_keys[lg2(PSP_CTRL_CIRCLE)] = "Circle";
	in_psp_keys[lg2(PSP_CTRL_CROSS)] = "Cross";
	in_psp_keys[lg2(PSP_CTRL_SQUARE)] = "Square";
	in_psp_keys[lg2(PSP_NUB_UP)] = "Analog up";
	in_psp_keys[lg2(PSP_NUB_LEFT)] = "Analog left";
	in_psp_keys[lg2(PSP_NUB_DOWN)] = "Analog down";
	in_psp_keys[lg2(PSP_NUB_RIGHT)] = "Analog right";

	in_register_driver(&in_psp_drv, defbinds, NULL, NULL);
}

