/*
 * (C) Gražvydas "notaz" Ignotas, 2012
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <SDL.h>
#include "input.h"
#include "in_sdl.h"

#define IN_SDL_PREFIX "sdl:"
/* should be machine word for best performace */
typedef unsigned long keybits_t;
#define KEYBITS_WORD_BITS (sizeof(keybits_t) * 8)

struct in_sdl_state {
	const in_drv_t *drv;
	SDL_Joystick *joy;
	int joy_id;
	int axis_keydown[2];
	keybits_t keystate[SDLK_LAST / KEYBITS_WORD_BITS + 1];
};

static void (*ext_event_handler)(void *event);

static const char * const in_sdl_keys[SDLK_LAST] = {
	[SDLK_BACKSPACE] = "backspace",
	[SDLK_TAB] = "tab",
	[SDLK_CLEAR] = "clear",
	[SDLK_RETURN] = "return",
	[SDLK_PAUSE] = "pause",
	[SDLK_ESCAPE] = "escape",
	[SDLK_SPACE] = "space",
	[SDLK_EXCLAIM]  = "!",
	[SDLK_QUOTEDBL]  = "\"",
	[SDLK_HASH]  = "#",
	[SDLK_DOLLAR]  = "$",
	[SDLK_AMPERSAND]  = "&",
	[SDLK_QUOTE] = "'",
	[SDLK_LEFTPAREN] = "(",
	[SDLK_RIGHTPAREN] = ")",
	[SDLK_ASTERISK] = "*",
	[SDLK_PLUS] = "+",
	[SDLK_COMMA] = ",",
	[SDLK_MINUS] = "-",
	[SDLK_PERIOD] = ".",
	[SDLK_SLASH] = "/",
	[SDLK_0] = "0",
	[SDLK_1] = "1",
	[SDLK_2] = "2",
	[SDLK_3] = "3",
	[SDLK_4] = "4",
	[SDLK_5] = "5",
	[SDLK_6] = "6",
	[SDLK_7] = "7",
	[SDLK_8] = "8",
	[SDLK_9] = "9",
	[SDLK_COLON] = ":",
	[SDLK_SEMICOLON] = ";",
	[SDLK_LESS] = "<",
	[SDLK_EQUALS] = "=",
	[SDLK_GREATER] = ">",
	[SDLK_QUESTION] = "?",
	[SDLK_AT] = "@",
	[SDLK_LEFTBRACKET] = "[",
	[SDLK_BACKSLASH] = "\\",
	[SDLK_RIGHTBRACKET] = "]",
	[SDLK_CARET] = "^",
	[SDLK_UNDERSCORE] = "_",
	[SDLK_BACKQUOTE] = "`",
	[SDLK_a] = "a",
	[SDLK_b] = "b",
	[SDLK_c] = "c",
	[SDLK_d] = "d",
	[SDLK_e] = "e",
	[SDLK_f] = "f",
	[SDLK_g] = "g",
	[SDLK_h] = "h",
	[SDLK_i] = "i",
	[SDLK_j] = "j",
	[SDLK_k] = "k",
	[SDLK_l] = "l",
	[SDLK_m] = "m",
	[SDLK_n] = "n",
	[SDLK_o] = "o",
	[SDLK_p] = "p",
	[SDLK_q] = "q",
	[SDLK_r] = "r",
	[SDLK_s] = "s",
	[SDLK_t] = "t",
	[SDLK_u] = "u",
	[SDLK_v] = "v",
	[SDLK_w] = "w",
	[SDLK_x] = "x",
	[SDLK_y] = "y",
	[SDLK_z] = "z",
	[SDLK_DELETE] = "delete",

	[SDLK_KP0] = "[0]",
	[SDLK_KP1] = "[1]",
	[SDLK_KP2] = "[2]",
	[SDLK_KP3] = "[3]",
	[SDLK_KP4] = "[4]",
	[SDLK_KP5] = "[5]",
	[SDLK_KP6] = "[6]",
	[SDLK_KP7] = "[7]",
	[SDLK_KP8] = "[8]",
	[SDLK_KP9] = "[9]",
	[SDLK_KP_PERIOD] = "[.]",
	[SDLK_KP_DIVIDE] = "[/]",
	[SDLK_KP_MULTIPLY] = "[*]",
	[SDLK_KP_MINUS] = "[-]",
	[SDLK_KP_PLUS] = "[+]",
	[SDLK_KP_ENTER] = "enter",
	[SDLK_KP_EQUALS] = "equals",

	[SDLK_UP] = "up",
	[SDLK_DOWN] = "down",
	[SDLK_RIGHT] = "right",
	[SDLK_LEFT] = "left",
	[SDLK_INSERT] = "insert",
	[SDLK_HOME] = "home",
	[SDLK_END] = "end",
	[SDLK_PAGEUP] = "page up",
	[SDLK_PAGEDOWN] = "page down",

	[SDLK_F1] = "f1",
	[SDLK_F2] = "f2",
	[SDLK_F3] = "f3",
	[SDLK_F4] = "f4",
	[SDLK_F5] = "f5",
	[SDLK_F6] = "f6",
	[SDLK_F7] = "f7",
	[SDLK_F8] = "f8",
	[SDLK_F9] = "f9",
	[SDLK_F10] = "f10",
	[SDLK_F11] = "f11",
	[SDLK_F12] = "f12",
	[SDLK_F13] = "f13",
	[SDLK_F14] = "f14",
	[SDLK_F15] = "f15",

	[SDLK_NUMLOCK] = "numlock",
	[SDLK_CAPSLOCK] = "caps lock",
	[SDLK_SCROLLOCK] = "scroll lock",
	[SDLK_RSHIFT] = "right shift",
	[SDLK_LSHIFT] = "left shift",
	[SDLK_RCTRL] = "right ctrl",
	[SDLK_LCTRL] = "left ctrl",
	[SDLK_RALT] = "right alt",
	[SDLK_LALT] = "left alt",
	[SDLK_RMETA] = "right meta",
	[SDLK_LMETA] = "left meta",
	[SDLK_LSUPER] = "left super",	/* "Windows" keys */
	[SDLK_RSUPER] = "right super",	
	[SDLK_MODE] = "alt gr",
	[SDLK_COMPOSE] = "compose",
};

static void in_sdl_probe(const in_drv_t *drv)
{
	const struct in_pdata *pdata = drv->pdata;
	const char * const * key_names = in_sdl_keys;
	struct in_sdl_state *state;
	SDL_Joystick *joy;
	int i, joycount;
	char name[256];

	if (pdata->key_names)
		key_names = pdata->key_names;

	state = calloc(1, sizeof(*state));
	if (state == NULL) {
		fprintf(stderr, "in_sdl: OOM\n");
		return;
	}

	state->drv = drv;
	in_register(IN_SDL_PREFIX "keys", -1, state, SDLK_LAST,
		key_names, 0);

	/* joysticks go here too */
	SDL_InitSubSystem(SDL_INIT_JOYSTICK);

	joycount = SDL_NumJoysticks();
	for (i = 0; i < joycount; i++) {
		joy = SDL_JoystickOpen(i);
		if (joy == NULL)
			continue;

		state = calloc(1, sizeof(*state));
		if (state == NULL) {
			fprintf(stderr, "in_sdl: OOM\n");
			break;
		}
		state->joy = joy;
		state->joy_id = i;
		state->drv = drv;

		snprintf(name, sizeof(name), IN_SDL_PREFIX "%s", SDL_JoystickName(i));
		in_register(name, -1, state, SDLK_LAST, key_names, 0);
	}

	if (joycount > 0)
		SDL_JoystickEventState(SDL_ENABLE);
}

static void in_sdl_free(void *drv_data)
{
	struct in_sdl_state *state = drv_data;

	if (state != NULL) {
		if (state->joy != NULL)
			SDL_JoystickClose(state->joy);
		free(state);
	}
}

static const char * const *
in_sdl_get_key_names(const in_drv_t *drv, int *count)
{
	const struct in_pdata *pdata = drv->pdata;
	*count = SDLK_LAST;

	if (pdata->key_names)
		return pdata->key_names;
	return in_sdl_keys;
}

/* could use SDL_GetKeyState, but this gives better packing */
static void update_keystate(keybits_t *keystate, int sym, int is_down)
{
	keybits_t *ks_word, mask;

	mask = 1;
	mask <<= sym & (KEYBITS_WORD_BITS - 1);
	ks_word = keystate + sym / KEYBITS_WORD_BITS;
	if (is_down)
		*ks_word |= mask;
	else
		*ks_word &= ~mask;
}

static int handle_event(struct in_sdl_state *state, SDL_Event *event,
	int *kc_out, int *down_out)
{
	if (event->type != SDL_KEYDOWN && event->type != SDL_KEYUP)
		return -1;

	update_keystate(state->keystate, event->key.keysym.sym,
		event->type == SDL_KEYDOWN);
	if (kc_out != NULL)
		*kc_out = event->key.keysym.sym;
	if (down_out != NULL)
		*down_out = event->type == SDL_KEYDOWN;

	return 1;
}

static int handle_joy_event(struct in_sdl_state *state, SDL_Event *event,
	int *kc_out, int *down_out)
{
	int kc = -1, down = 0, ret = 0;

	/* TODO: remaining axis */
	switch (event->type) {
	case SDL_JOYAXISMOTION:
		if (event->jaxis.which != state->joy_id)
			return -2;
		if (event->jaxis.axis > 1)
			break;
		if (-16384 <= event->jaxis.value && event->jaxis.value <= 16384) {
			kc = state->axis_keydown[event->jaxis.axis];
			state->axis_keydown[event->jaxis.axis] = 0;
			ret = 1;
		}
		else if (event->jaxis.value < -16384) {
			kc = state->axis_keydown[event->jaxis.axis];
			if (kc)
				update_keystate(state->keystate, kc, 0);
			kc = event->jaxis.axis ? SDLK_UP : SDLK_LEFT;
			state->axis_keydown[event->jaxis.axis] = kc;
			down = 1;
			ret = 1;
		}
		else if (event->jaxis.value > 16384) {
			kc = state->axis_keydown[event->jaxis.axis];
			if (kc)
				update_keystate(state->keystate, kc, 0);
			kc = event->jaxis.axis ? SDLK_DOWN : SDLK_RIGHT;
			state->axis_keydown[event->jaxis.axis] = kc;
			down = 1;
			ret = 1;
		}
		break;

	case SDL_JOYBUTTONDOWN:
	case SDL_JOYBUTTONUP:
		if (event->jbutton.which != state->joy_id)
			return -2;
		kc = (int)event->jbutton.button + SDLK_WORLD_0;
		down = event->jbutton.state == SDL_PRESSED;
		ret = 1;
		break;
	default:
		return -1;
	}

	if (ret)
		update_keystate(state->keystate, kc, down);
	if (kc_out != NULL)
		*kc_out = kc;
	if (down_out != NULL)
		*down_out = down;

	return ret;
}

#define JOY_EVENTS (SDL_JOYAXISMOTIONMASK | SDL_JOYBALLMOTIONMASK | SDL_JOYHATMOTIONMASK \
		    | SDL_JOYBUTTONDOWNMASK | SDL_JOYBUTTONUPMASK)

static int collect_events(struct in_sdl_state *state, int *one_kc, int *one_down)
{
	SDL_Event events[4];
	Uint32 mask = state->joy ? JOY_EVENTS : (SDL_ALLEVENTS & ~JOY_EVENTS);
	int count, maxcount;
	int i, ret, retval = 0;
	int num_events, num_peeped_events;
	SDL_Event *event;

	maxcount = (one_kc != NULL) ? 1 : sizeof(events) / sizeof(events[0]);

	SDL_PumpEvents();

	num_events = SDL_PeepEvents(NULL, 0, SDL_PEEKEVENT, mask);

	for (num_peeped_events = 0; num_peeped_events < num_events; num_peeped_events += count) {
		count = SDL_PeepEvents(events, maxcount, SDL_GETEVENT, mask);
		if (count <= 0)
			break;
		for (i = 0; i < count; i++) {
			event = &events[i];
			if (state->joy)
				ret = handle_joy_event(state,
					event, one_kc, one_down);
			else
				ret = handle_event(state,
					event, one_kc, one_down);
			if (ret < 0) {
				switch (ret) {
					case -2:
						SDL_PushEvent(event);
						break;
					default:
						if (ext_event_handler != NULL)
							ext_event_handler(event);
						break;
				}
				continue;
			}

			retval |= ret;
			if (one_kc != NULL && ret)
			{
				// don't lose events other devices might want to handle
				for (i++; i < count; i++)
					SDL_PushEvent(&events[i]);
				goto out;
			}
		}
	}

out:
	return retval;
}

static int in_sdl_update(void *drv_data, const int *binds, int *result)
{
	struct in_sdl_state *state = drv_data;
	keybits_t mask;
	int i, sym, bit, b;

	collect_events(state, NULL, NULL);

	for (i = 0; i < SDLK_LAST / KEYBITS_WORD_BITS + 1; i++) {
		mask = state->keystate[i];
		if (mask == 0)
			continue;
		for (bit = 0; mask != 0; bit++, mask >>= 1) {
			if ((mask & 1) == 0)
				continue;
			sym = i * KEYBITS_WORD_BITS + bit;

			for (b = 0; b < IN_BINDTYPE_COUNT; b++)
				result[b] |= binds[IN_BIND_OFFS(sym, b)];
		}
	}

	return 0;
}

static int in_sdl_update_keycode(void *drv_data, int *is_down)
{
	struct in_sdl_state *state = drv_data;
	int ret_kc = -1, ret_down = 0;

	collect_events(state, &ret_kc, &ret_down);

	if (is_down != NULL)
		*is_down = ret_down;

	return ret_kc;
}

static int in_sdl_menu_translate(void *drv_data, int keycode, char *charcode)
{
	struct in_sdl_state *state = drv_data;
	const struct in_pdata *pdata = state->drv->pdata;
	const char * const * key_names = in_sdl_keys;
	const struct menu_keymap *map;
	int map_len;
	int ret = 0;
	int i;

	if (pdata->key_names)
		key_names = pdata->key_names;

	if (state->joy) {
		map = pdata->joy_map;
		map_len = pdata->jmap_size;
	} else {
		map = pdata->key_map;
		map_len = pdata->kmap_size;
	}

	if (keycode < 0)
	{
		/* menu -> kc */
		keycode = -keycode;
		for (i = 0; i < map_len; i++)
			if (map[i].pbtn == keycode)
				return map[i].key;
	}
	else
	{
		for (i = 0; i < map_len; i++) {
			if (map[i].key == keycode) {
				ret = map[i].pbtn;
				break;
			}
		}

		if (charcode != NULL && (unsigned int)keycode < SDLK_LAST &&
		    key_names[keycode] != NULL && key_names[keycode][1] == 0)
		{
			ret |= PBTN_CHAR;
			*charcode = key_names[keycode][0];
		}
	}

	return ret;
}

static const in_drv_t in_sdl_drv = {
	.prefix         = IN_SDL_PREFIX,
	.probe          = in_sdl_probe,
	.free           = in_sdl_free,
	.get_key_names  = in_sdl_get_key_names,
	.update         = in_sdl_update,
	.update_keycode = in_sdl_update_keycode,
	.menu_translate = in_sdl_menu_translate,
};

int in_sdl_init(const struct in_pdata *pdata, void (*handler)(void *event))
{
	if (!pdata) {
		fprintf(stderr, "in_sdl: Missing input platform data\n");
		return -1;
	}

	in_register_driver(&in_sdl_drv, pdata->defbinds, pdata);
	ext_event_handler = handler;
	return 0;
}
