/*
 * PicoDrive input driver for PS2
 *
 * (C) fjtrujy,irixxxx 2024
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <malloc.h>

#include "libpad.h"
#include "libmtap.h"

#include "../libpicofe/input.h"
#include "in_ps2.h"

#define IN_PS2_PREFIX "ps2:"
#define IN_PS2_NBUTTONS 32
#define ANALOG_DEADZONE 80

/* note: in_ps2 handles combos (if 2 btns have the same bind,
 * both must be pressed for action to happen) */
static int in_ps2_combo_keys[4];
static int in_ps2_combo_acts[4];

static void *padBuf[2][4];
static int padMap[4][2]; // port/slot for 4 mapped pads
static int padMapped; // #pads successfully opened

static const char *in_ps2_keys[IN_PS2_NBUTTONS];

static unsigned old_keys[4];

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

static unsigned int ps2_pad_read(int pad)
{
	unsigned int paddata = 0;
	struct padButtonStatus buttons;
	int32_t ret, port, slot;

	if (pad < padMapped) {
		port = padMap[pad][0];
		slot = padMap[pad][1];

		ret = padRead(port, slot, &buttons);

		if (ret != 0) {
			paddata = 0xffff ^ buttons.btns;
		}
	}

	return paddata;
}

static unsigned in_ps2_get_bits(int pad)
{
	unsigned mask =
	    PAD_UP|PAD_DOWN|PAD_LEFT|PAD_RIGHT |
	    PAD_CIRCLE|PAD_CROSS|PAD_TRIANGLE|PAD_SQUARE |
	    PAD_L1|PAD_R1|PAD_L2|PAD_R2|PAD_L3|PAD_R3|PAD_SELECT|PAD_START;

	return ps2_pad_read(pad) & mask;
}

static void in_ps2_probe(const in_drv_t *drv)
{
	in_register(IN_PS2_PREFIX "PS2 pad 1", -1, (void *)0,
		IN_PS2_NBUTTONS, in_ps2_keys, 1);
	in_register(IN_PS2_PREFIX "PS2 pad 2", -1, (void *)1,
		IN_PS2_NBUTTONS, in_ps2_keys, 1);
	in_register(IN_PS2_PREFIX "PS2 pad 3", -1, (void *)2,
		IN_PS2_NBUTTONS, in_ps2_keys, 1);
	in_register(IN_PS2_PREFIX "PS2 pad 4", -1, (void *)3,
		IN_PS2_NBUTTONS, in_ps2_keys, 1);
}

static void in_ps2_free(void *drv_data)
{

}

static const char * const *
in_ps2_get_key_names(const in_drv_t *drv, int *count)
{
	*count = IN_PS2_NBUTTONS;
	return in_ps2_keys;
}

/* ORs result with pressed buttons */
static int in_ps2_update(void *drv_data, const int *binds, int *result)
{
	int pad = (int)drv_data & 3;
	int type_start = 0;
	int i, t;
	unsigned keys;

	keys = in_ps2_get_bits(pad);

	if (keys & in_ps2_combo_keys[pad]) {
		result[IN_BINDTYPE_EMU] = in_combos_do(keys, binds, IN_PS2_NBUTTONS,
					in_ps2_combo_keys[pad], in_ps2_combo_acts[pad]);
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

int in_ps2_update_keycode(void *data, int *is_down)
{
	int pad = (int)data & 3;
	unsigned val, diff, i;

	val = in_ps2_get_bits(pad);
	diff = val ^ old_keys[pad];
	if (diff == 0)
		return -1;

	/* take one bit only */
	for (i = 0; i < sizeof(diff)*8; i++)
		if (diff & (1<<i))
			break;

	old_keys[pad] ^= 1 << i;

	if (is_down)
		*is_down = !!(val & (1<<i));
	return i;
}

static struct {
	unsigned key;
	int pbtn;
} key_pbtn_map[] =
{
	{ PAD_UP,	PBTN_UP },
	{ PAD_DOWN,	PBTN_DOWN },
	{ PAD_LEFT,	PBTN_LEFT },
	{ PAD_RIGHT,	PBTN_RIGHT },
	{ PAD_CIRCLE,	PBTN_MOK },
	{ PAD_CROSS,	PBTN_MBACK },
	{ PAD_TRIANGLE,	PBTN_MA2 },
	{ PAD_SQUARE,	PBTN_MA3 },
	{ PAD_L1,	PBTN_L },
	{ PAD_R1,	PBTN_R },
};

#define KEY_PBTN_MAP_SIZE (sizeof(key_pbtn_map) / sizeof(key_pbtn_map[0]))

static int in_ps2_menu_translate(void *drv_data, int keycode, char *charcode)
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
static int in_ps2_clean_binds(void *drv_data, int *binds, int *def_binds)
{
	int pad = (int)drv_data & 3;
	int i, count = 0;

	for (i = 0; i < IN_PS2_NBUTTONS; i++) {
		int t, offs;
		for (t = 0; t < IN_BINDTYPE_COUNT; t++) {
			offs = IN_BIND_OFFS(i, t);
			if (in_ps2_keys[i] == NULL)
				binds[offs] = def_binds[offs] = 0;
			if (binds[offs])
				count++;
		}
	}

	in_combos_find(binds, IN_PS2_NBUTTONS, &in_ps2_combo_keys[pad], &in_ps2_combo_acts[pad]);

	return count;
}

static const in_drv_t in_ps2_drv = {
	.prefix         = IN_PS2_PREFIX,
	.probe          = in_ps2_probe,
	.free           = in_ps2_free,
	.get_key_names  = in_ps2_get_key_names,
	.clean_binds    = in_ps2_clean_binds,
	.update         = in_ps2_update,
	.update_keycode = in_ps2_update_keycode,
	.menu_translate = in_ps2_menu_translate,
};

void in_ps2_init(struct in_default_bind *defbinds)
{
	int i, j;

	for (j = 0; j < 2 && padMapped < 4; j++) {
		mtapPortOpen(j);

		for (i = 0; i < 4 && padMapped < 4; i++) {
			padBuf[j][i] = memalign(64, 256);
			if (padPortOpen(j, i, padBuf[j][i])) {
				padMap[padMapped][0] = j;
				padMap[padMapped][1] = i;
				padMapped++;
			} else
				free(padBuf[j][i]);
		}
	}

	/* PS2 keys have bit masks, Picodrive wants bit numbers */
	for (i = 0; defbinds[i].code; i++)
		defbinds[i].code = lg2(defbinds[i].code);
	for (i = 0; i < KEY_PBTN_MAP_SIZE; i++)
		key_pbtn_map[i].key = lg2(key_pbtn_map[i].key);

	memset(in_ps2_combo_keys, 0, sizeof(in_ps2_combo_keys));
	memset(in_ps2_combo_acts, 0, sizeof(in_ps2_combo_acts));

	/* fill keys array, converting key bitmasks to bit numbers */
	in_ps2_keys[lg2(PAD_UP)] = "Up";
	in_ps2_keys[lg2(PAD_LEFT)] = "Left";
	in_ps2_keys[lg2(PAD_DOWN)] = "Down";
	in_ps2_keys[lg2(PAD_RIGHT)] = "Right";
	in_ps2_keys[lg2(PAD_START)] = "Start";
	in_ps2_keys[lg2(PAD_SELECT)] = "Select";
	in_ps2_keys[lg2(PAD_L1)] = "L1";
	in_ps2_keys[lg2(PAD_R1)] = "R1";
	in_ps2_keys[lg2(PAD_L2)] = "L2";
	in_ps2_keys[lg2(PAD_R2)] = "R2";
	in_ps2_keys[lg2(PAD_L3)] = "L3";
	in_ps2_keys[lg2(PAD_R3)] = "R3";
	in_ps2_keys[lg2(PAD_TRIANGLE)] = "Triangle";
	in_ps2_keys[lg2(PAD_CIRCLE)] = "Circle";
	in_ps2_keys[lg2(PAD_CROSS)] = "Cross";
	in_ps2_keys[lg2(PAD_SQUARE)] = "Square";

	in_register_driver(&in_ps2_drv, defbinds, NULL, NULL);
}

