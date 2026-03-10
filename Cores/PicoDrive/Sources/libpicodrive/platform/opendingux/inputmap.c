#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <SDL_keysym.h>

#include "../libpicofe/input.h"
#include "../libpicofe/in_sdl.h"
#include "../libpicofe/plat.h"
#include "../common/input_pico.h"
#include "../common/plat_sdl.h"
#include "../common/emu.h"

struct in_default_bind _in_sdl_defbinds[] = {
	{ SDLK_UP,	IN_BINDTYPE_PLAYER12, GBTN_UP },
	{ SDLK_DOWN,	IN_BINDTYPE_PLAYER12, GBTN_DOWN },
	{ SDLK_LEFT,	IN_BINDTYPE_PLAYER12, GBTN_LEFT },
	{ SDLK_RIGHT,	IN_BINDTYPE_PLAYER12, GBTN_RIGHT },
	{ SDLK_LSHIFT,	IN_BINDTYPE_PLAYER12, GBTN_A },
	{ SDLK_LALT,	IN_BINDTYPE_PLAYER12, GBTN_B },
	{ SDLK_LCTRL,	IN_BINDTYPE_PLAYER12, GBTN_C },
	{ SDLK_RETURN,	IN_BINDTYPE_PLAYER12, GBTN_START },
	{ SDLK_ESCAPE,	IN_BINDTYPE_EMU, PEVB_MENU },
	{ SDLK_TAB,		IN_BINDTYPE_EMU, PEVB_PICO_PPREV },
	{ SDLK_BACKSPACE,	IN_BINDTYPE_EMU, PEVB_PICO_PNEXT },
	{ SDLK_BACKSPACE,	IN_BINDTYPE_EMU, PEVB_STATE_SAVE },
	{ SDLK_TAB,		IN_BINDTYPE_EMU, PEVB_STATE_LOAD },
	{ SDLK_SPACE,	IN_BINDTYPE_EMU, PEVB_FF },
	{ 0, 0, 0 }
};
const struct in_default_bind *in_sdl_defbinds = _in_sdl_defbinds;

struct menu_keymap _in_sdl_key_map[] = {
	{ SDLK_UP,	PBTN_UP },
	{ SDLK_DOWN,	PBTN_DOWN },
	{ SDLK_LEFT,	PBTN_LEFT },
	{ SDLK_RIGHT,	PBTN_RIGHT },
	{ SDLK_LCTRL,	PBTN_MOK },
	{ SDLK_LALT,	PBTN_MBACK },
	{ SDLK_SPACE,	PBTN_MA2 },
	{ SDLK_LSHIFT,	PBTN_MA3 },
	{ SDLK_TAB,	PBTN_L },
	{ SDLK_BACKSPACE,	PBTN_R },
};
const int in_sdl_key_map_sz = sizeof(_in_sdl_key_map) / sizeof(_in_sdl_key_map[0]);
const struct menu_keymap *in_sdl_key_map = _in_sdl_key_map;

const struct menu_keymap _in_sdl_joy_map[] = {
	{ SDLK_UP,	PBTN_UP },
	{ SDLK_DOWN,	PBTN_DOWN },
	{ SDLK_LEFT,	PBTN_LEFT },
	{ SDLK_RIGHT,	PBTN_RIGHT },
	/* joystick */
	{ SDLK_WORLD_0,	PBTN_MOK },
	{ SDLK_WORLD_1,	PBTN_MBACK },
	{ SDLK_WORLD_2,	PBTN_MA2 },
	{ SDLK_WORLD_3,	PBTN_MA3 },
};
const int in_sdl_joy_map_sz = sizeof(_in_sdl_joy_map) / sizeof(_in_sdl_joy_map[0]);
const struct menu_keymap *in_sdl_joy_map = _in_sdl_joy_map;

const char * _in_sdl_key_names[SDLK_LAST] = {
	/* common */
	[SDLK_UP] = "UP",
	[SDLK_DOWN] = "DOWN",
	[SDLK_LEFT] = "LEFT",
	[SDLK_RIGHT] = "RIGHT",
	[SDLK_LCTRL] = "A",
	[SDLK_LALT] = "B",
	[SDLK_LSHIFT] = "Y",
	[SDLK_SPACE] = "X",
	[SDLK_RETURN] = "START",
	[SDLK_ESCAPE] = "SELECT",
	[SDLK_TAB] = "L1",
	[SDLK_BACKSPACE] = "R1",

	/* opendingux rg, gkd etc */
	[SDLK_PAGEUP] = "L2",
	[SDLK_PAGEDOWN] = "R2",
	[SDLK_KP_DIVIDE] = "L3",
	[SDLK_KP_PERIOD] = "R3",
	[SDLK_HOME] = "POWER",
	/* gkd (mini) */
	/*[SDLK_HOME] = "MENU",*/
	[SDLK_END] = "EXIT",
	/* gcw0 */
	[SDLK_POWER] = "POWER",
	[SDLK_PAUSE] = "LOCK",
	/* miyoo */
	[SDLK_RALT] = "L2",
	[SDLK_RSHIFT] = "R2",
	[SDLK_RCTRL] = "RESET",
	/* retrofw */
	[SDLK_LEFTBRACKET] = "SETUP",   /* actually brightness setting */
	/*[SDLK_END] = "POWER",*/
};
const char * const *in_sdl_key_names = _in_sdl_key_names;

const struct in_default_bind in_sdl_kbd_map[] = {
	// Opendingux devices usually don't have a keyboard.
	{ 0, 0, 0 }
};


static void nameset(int x1, const char *name)
{
	_in_sdl_key_names[x1] = name;
}

static void nameswap(int x1, int x2)
{
	const char **p = &_in_sdl_key_names[x1];
	const char **q = &_in_sdl_key_names[x2];
	const char *t = *p; *p = *q; *q = t;
}

static void keyswap(int k1, int k2)
{
	int x1, x2, t;

	for (x1 = in_sdl_key_map_sz-1; x1 >= 0; x1--)
		if (_in_sdl_key_map[x1].key == k1) break;
	for (x2 = in_sdl_key_map_sz-1; x2 >= 0; x2--)
		if (_in_sdl_key_map[x2].key == k2) break;
	if (x1 >= 0 && x2 >= 0) {
		struct menu_keymap *p = &_in_sdl_key_map[x1];
		struct menu_keymap *q = &_in_sdl_key_map[x2];
		t = p->pbtn; p->pbtn = q->pbtn; q->pbtn = t;
	}
}

static void bindswap(int k1, int k2)
{
	int i;

	for (i = 0; _in_sdl_defbinds[i].code; i++)
		if (_in_sdl_defbinds[i].code == k1)
			_in_sdl_defbinds[i].code = k2;
}

void plat_target_setup_input(void)
{
	if (strcmp(plat_device, "miyoo") == 0) {
		/* swapped A/B and X/Y keys */
		keyswap(SDLK_LALT, SDLK_LCTRL);
		nameswap(SDLK_LALT, SDLK_LCTRL);
		nameswap(SDLK_SPACE, SDLK_LSHIFT);
		bindswap(SDLK_ESCAPE, SDLK_RCTRL);
	} else if (strcmp(plat_device, "gcw0") == 0) {
		/* swapped X/Y keys, single L/R keys */
		nameswap(SDLK_SPACE, SDLK_LSHIFT);
		nameset(SDLK_TAB, "L"); nameset(SDLK_BACKSPACE, "R");
	} else if (strcmp(plat_device, "retrofw") == 0 || strcmp(plat_device, "dingux") == 0) {
		/* single L/R keys */
		nameset(SDLK_TAB, "L"); nameset(SDLK_BACKSPACE, "R");
		nameset(SDLK_END, "POWER");
	}
}
