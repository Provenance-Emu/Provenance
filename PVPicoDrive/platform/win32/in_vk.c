#define RC_INVOKED // we only need defines
#include <winuser.h>
#undef RC_INVOKED
#include <string.h>

#include "../common/input.h"
#include "../common/emu.h" // array_size
#include "in_vk.h"

#define IN_VK_PREFIX "vk:"
#define IN_VK_NKEYS 0x100

static const char * const in_vk_prefix = IN_VK_PREFIX;
static const char * const in_vk_keys[IN_VK_NKEYS] = {
	[0 ... (IN_VK_NKEYS - 1)] = NULL,
	[VK_LBUTTON] = "LBUTTON",	[VK_RBUTTON] = "RBUTTON",
	[VK_TAB] = "TAB",		[VK_RETURN] = "RETURN",
	[VK_SHIFT] = "SHIFT",		[VK_CONTROL] = "CONTROL",
	[VK_LEFT] = "LEFT",		[VK_UP] = "UP",
	[VK_RIGHT] = "RIGHT",		[VK_DOWN] = "DOWN",
	[VK_SPACE] = "SPACE",
};

// additional player12 keys
int in_vk_add_pl12;

// up to 4, keyboards rarely allow more
static int in_vk_keys_down[4];

/*
#define VK_END	35
#define VK_HOME	36
#define VK_INSERT	45
#define VK_DELETE	46
#define VK_NUMPAD0	0x60
#define VK_NUMPAD1	0x61
#define VK_NUMPAD2	0x62
#define VK_NUMPAD3	0x63
#define VK_NUMPAD4	0x64
#define VK_NUMPAD5	0x65
#define VK_NUMPAD6	0x66
#define VK_NUMPAD7	0x67
#define VK_NUMPAD8	0x68
#define VK_NUMPAD9	0x69
#define VK_MULTIPLY	0x6A
#define VK_ADD	0x6B
#define VK_SEPARATOR	0x6C
#define VK_SUBTRACT	0x6D
#define VK_DECIMAL	0x6E
#define VK_DIVIDE	0x6F
#define VK_F1	0x70
#define VK_F2	0x71
#define VK_F3	0x72
#define VK_F4	0x73
#define VK_F5	0x74
#define VK_F6	0x75
#define VK_F7	0x76
#define VK_F8	0x77
#define VK_F9	0x78
#define VK_F10	0x79
#define VK_F11	0x7A
#define VK_F12	0x7B
*/

static void in_vk_probe(void)
{
	memset(in_vk_keys_down, 0, sizeof(in_vk_keys_down));
	in_register(IN_VK_PREFIX "vk", IN_DRVID_VK, -1, (void *)1, IN_VK_NKEYS, NULL, 0);
}

static int in_vk_get_bind_count(void)
{
	return IN_VK_NKEYS;
}

/* ORs result with pressed buttons */
int in_vk_update(void *drv_data, const int *binds, int *result)
{
	int i, t, k;

	for (i = 0; i < array_size(in_vk_keys_down); i++) {
		k = in_vk_keys_down[i];
		if (!k)
			continue;

		for (t = 0; t < IN_BINDTYPE_COUNT; t++)
			result[t] |= binds[IN_BIND_OFFS(k, t)];
	}

	result[IN_BINDTYPE_PLAYER12] |= in_vk_add_pl12;

	return 0;
}

void in_vk_keydown(int kc)
{
	int i;

	// search
	for (i = 0; i < array_size(in_vk_keys_down); i++)
		if (in_vk_keys_down[i] == kc)
			return;

	// do
	for (i = 0; i < array_size(in_vk_keys_down); i++) {
		if (in_vk_keys_down[i] == 0) {
			in_vk_keys_down[i] = kc;
			return;
		}
	}
}

void in_vk_keyup(int kc)
{
	int i;
	for (i = 0; i < array_size(in_vk_keys_down); i++)
		if (in_vk_keys_down[i] == kc)
			in_vk_keys_down[i] = 0;
}

static int in_vk_update_keycode(void *data, int *is_down)
{
	return 0;
}

static const struct {
	short key;
	short pbtn;
} key_pbtn_map[] =
{
	{ VK_UP,	PBTN_UP },
	{ VK_DOWN,	PBTN_DOWN },
	{ VK_LEFT,	PBTN_LEFT },
	{ VK_RIGHT,	PBTN_RIGHT },
	{ VK_RETURN,	PBTN_MOK },
/*
	{ BTN_X,	PBTN_MBACK },
	{ BTN_A,	PBTN_MA2 },
	{ BTN_Y,	PBTN_MA3 },
	{ BTN_L,	PBTN_L },
	{ BTN_R,	PBTN_R },
	{ BTN_SELECT,	PBTN_MENU },
*/
};

#define KEY_PBTN_MAP_SIZE (sizeof(key_pbtn_map) / sizeof(key_pbtn_map[0]))

static int in_vk_menu_translate(void *drv_data, int keycode)
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

static int in_vk_get_key_code(const char *key_name)
{
	int i;

	if (key_name[1] == 0 && 'A' <= key_name[0] && key_name[0] <= 'Z')
		return key_name[0];

	for (i = 0; i < IN_VK_NKEYS; i++) {
		const char *k = in_vk_keys[i];
		if (k != NULL && strcasecmp(k, key_name) == 0)
			return i;
	}

	return -1;
}

static const char *in_vk_get_key_name(int keycode)
{
	const char *name = NULL;
	static char buff[4];

	if ('A' <= keycode && keycode < 'Z') {
		buff[0] = keycode;
		buff[1] = 0;
		return buff;
	}

	if (0 <= keycode && keycode < IN_VK_NKEYS)
		name = in_vk_keys[keycode];
	if (name == NULL)
		name = "Unkn";
	
	return name;
}

static const struct {
	short code;
	char btype;
	char bit;
} in_vk_def_binds[] =
{
	/* MXYZ SACB RLDU */
	{ VK_UP,	IN_BINDTYPE_PLAYER12, 0 },
	{ VK_DOWN,	IN_BINDTYPE_PLAYER12, 1 },
	{ VK_LEFT,	IN_BINDTYPE_PLAYER12, 2 },
	{ VK_RIGHT,	IN_BINDTYPE_PLAYER12, 3 },
	{ 'S',		IN_BINDTYPE_PLAYER12, 4 },	/* B */
	{ 'D',		IN_BINDTYPE_PLAYER12, 5 },	/* C */
	{ 'A',		IN_BINDTYPE_PLAYER12, 6 },	/* A */
	{ VK_RETURN,	IN_BINDTYPE_PLAYER12, 7 },
	{ 'E',		IN_BINDTYPE_PLAYER12, 8 },	/* Z */
	{ 'W',		IN_BINDTYPE_PLAYER12, 9 },	/* Y */
	{ 'Q',		IN_BINDTYPE_PLAYER12,10 },	/* X */
	{ 'R',		IN_BINDTYPE_PLAYER12,11 },	/* M */
/*
	{ BTN_SELECT,	IN_BINDTYPE_EMU, PEVB_MENU },
//	{ BTN_Y,	IN_BINDTYPE_EMU, PEVB_SWITCH_RND },
	{ BTN_L,	IN_BINDTYPE_EMU, PEVB_STATE_SAVE },
	{ BTN_R,	IN_BINDTYPE_EMU, PEVB_STATE_LOAD },
	{ BTN_VOL_UP,	IN_BINDTYPE_EMU, PEVB_VOL_UP },
	{ BTN_VOL_DOWN,	IN_BINDTYPE_EMU, PEVB_VOL_DOWN },
*/
};

#define DEF_BIND_COUNT (sizeof(in_vk_def_binds) / sizeof(in_vk_def_binds[0]))

static void in_vk_get_def_binds(int *binds)
{
	int i;

	for (i = 0; i < DEF_BIND_COUNT; i++)
		binds[IN_BIND_OFFS(in_vk_def_binds[i].code, in_vk_def_binds[i].btype)] =
			1 << in_vk_def_binds[i].bit;
}

/* remove binds of missing keys, count remaining ones */
static int in_vk_clean_binds(void *drv_data, int *binds, int *def_binds)
{
	int i, count = 0;

	for (i = 0; i < IN_VK_NKEYS; i++) {
		int t, offs;
		for (t = 0; t < IN_BINDTYPE_COUNT; t++) {
			offs = IN_BIND_OFFS(i, t);
			if (strcmp(in_vk_get_key_name(i), "Unkn") == 0)
				binds[offs] = def_binds[offs] = 0;
			if (binds[offs])
				count++;
		}
	}

	return count;
}

void in_vk_init(void *vdrv)
{
	in_drv_t *drv = vdrv;

	drv->prefix = in_vk_prefix;
	drv->probe = in_vk_probe;
	drv->get_bind_count = in_vk_get_bind_count;
	drv->get_def_binds = in_vk_get_def_binds;
	drv->clean_binds = in_vk_clean_binds;
	drv->menu_translate = in_vk_menu_translate;
	drv->get_key_code = in_vk_get_key_code;
	drv->get_key_name = in_vk_get_key_name;
	drv->update_keycode = in_vk_update_keycode;
}

