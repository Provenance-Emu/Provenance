/*
 * (C) Gražvydas "notaz" Ignotas, 2008-2012
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
#include <sys/ioctl.h>
#include <unistd.h>
#include <linux/input.h>
#include <errno.h>

#include "../input.h"
#include "in_evdev.h"

#define MAX_ABS_DEVS 8

typedef struct {
	int fd;
	int *kbits;
	int abs_min_x; /* abs->digital mapping */
	int abs_max_x;
	int abs_min_y;
	int abs_max_y;
	int abs_lzone;
	int abs_lastx;
	int abs_lasty;
	int kc_first;
	int kc_last;
	unsigned int abs_count;
	int abs_mult[MAX_ABS_DEVS]; /* 16.16 multiplier to IN_ABS_RANGE */
	int abs_adj[MAX_ABS_DEVS];  /* adjust for centering */
	unsigned int abs_to_digital:1;

	const in_drv_t *drv;
} in_evdev_t;

#ifndef KEY_CNT
#define KEY_CNT (KEY_MAX + 1)
#endif

#define KEYBITS_BIT(x) (keybits[(x)/sizeof(keybits[0])/8] & \
	(1 << ((x) & (sizeof(keybits[0])*8-1))))

#define KEYBITS_BIT_SET(x) (keybits[(x)/sizeof(keybits[0])/8] |= \
	(1 << ((x) & (sizeof(keybits[0])*8-1))))

#define KEYBITS_BIT_CLEAR(x) (keybits[(x)/sizeof(keybits[0])/8] &= \
	~(1 << ((x) & (sizeof(keybits[0])*8-1))))

int in_evdev_allow_abs_only;

#define IN_EVDEV_PREFIX "evdev:"

static const char * const in_evdev_keys[KEY_CNT] = {
	// [0 ... KEY_MAX] = NULL, // not necessary
	[KEY_RESERVED] = "Reserved",		[KEY_ESC] = "Esc",
	[KEY_1] = "1",				[KEY_2] = "2",
	[KEY_3] = "3",				[KEY_4] = "4",
	[KEY_5] = "5",				[KEY_6] = "6",
	[KEY_7] = "7",				[KEY_8] = "8",
	[KEY_9] = "9",				[KEY_0] = "0",
	[KEY_MINUS] = "Minus",			[KEY_EQUAL] = "Equal",
	[KEY_BACKSPACE] = "Backspace",		[KEY_TAB] = "Tab",
	[KEY_Q] = "Q",				[KEY_W] = "W",
	[KEY_E] = "E",				[KEY_R] = "R",
	[KEY_T] = "T",				[KEY_Y] = "Y",
	[KEY_U] = "U",				[KEY_I] = "I",
	[KEY_O] = "O",				[KEY_P] = "P",
	[KEY_LEFTBRACE] = "LeftBrace",		[KEY_RIGHTBRACE] = "RightBrace",
	[KEY_ENTER] = "Enter",			[KEY_LEFTCTRL] = "LeftControl",
	[KEY_A] = "A",				[KEY_S] = "S",
	[KEY_D] = "D",				[KEY_F] = "F",
	[KEY_G] = "G",				[KEY_H] = "H",
	[KEY_J] = "J",				[KEY_K] = "K",
	[KEY_L] = "L",				[KEY_SEMICOLON] = "Semicolon",
	[KEY_APOSTROPHE] = "Apostrophe",	[KEY_GRAVE] = "Grave",
	[KEY_LEFTSHIFT] = "LeftShift",		[KEY_BACKSLASH] = "BackSlash",
	[KEY_Z] = "Z",				[KEY_X] = "X",
	[KEY_C] = "C",				[KEY_V] = "V",
	[KEY_B] = "B",				[KEY_N] = "N",
	[KEY_M] = "M",				[KEY_COMMA] = "Comma",
	[KEY_DOT] = "Dot",			[KEY_SLASH] = "Slash",
	[KEY_RIGHTSHIFT] = "RightShift",	[KEY_KPASTERISK] = "KPAsterisk",
	[KEY_LEFTALT] = "LeftAlt",		[KEY_SPACE] = "Space",
	[KEY_CAPSLOCK] = "CapsLock",		[KEY_F1] = "F1",
	[KEY_F2] = "F2",			[KEY_F3] = "F3",
	[KEY_F4] = "F4",			[KEY_F5] = "F5",
	[KEY_F6] = "F6",			[KEY_F7] = "F7",
	[KEY_F8] = "F8",			[KEY_F9] = "F9",
	[KEY_F10] = "F10",			[KEY_NUMLOCK] = "NumLock",
	[KEY_SCROLLLOCK] = "ScrollLock",	[KEY_KP7] = "KP7",
	[KEY_KP8] = "KP8",			[KEY_KP9] = "KP9",
	[KEY_KPMINUS] = "KPMinus",		[KEY_KP4] = "KP4",
	[KEY_KP5] = "KP5",			[KEY_KP6] = "KP6",
	[KEY_KPPLUS] = "KPPlus",		[KEY_KP1] = "KP1",
	[KEY_KP2] = "KP2",			[KEY_KP3] = "KP3",
	[KEY_KP0] = "KP0",			[KEY_KPDOT] = "KPDot",
	[KEY_ZENKAKUHANKAKU] = "Zenkaku/Hankaku", [KEY_102ND] = "102nd",
	[KEY_F11] = "F11",			[KEY_F12] = "F12",
	[KEY_KPJPCOMMA] = "KPJpComma",		[KEY_KPENTER] = "KPEnter",
	[KEY_RIGHTCTRL] = "RightCtrl",		[KEY_KPSLASH] = "KPSlash",
	[KEY_SYSRQ] = "SysRq",			[KEY_RIGHTALT] = "RightAlt",
	[KEY_LINEFEED] = "LineFeed",		[KEY_HOME] = "Home",
	[KEY_UP] = "Up",			[KEY_PAGEUP] = "PageUp",
	[KEY_LEFT] = "Left",			[KEY_RIGHT] = "Right",
	[KEY_END] = "End",			[KEY_DOWN] = "Down",
	[KEY_PAGEDOWN] = "PageDown",		[KEY_INSERT] = "Insert",
	[KEY_DELETE] = "Delete",		[KEY_MACRO] = "Macro",
	[KEY_HELP] = "Help",			[KEY_MENU] = "Menu",
	[KEY_COFFEE] = "Coffee",		[KEY_DIRECTION] = "Direction",
	[BTN_0] = "Btn0",			[BTN_1] = "Btn1",
	[BTN_2] = "Btn2",			[BTN_3] = "Btn3",
	[BTN_4] = "Btn4",			[BTN_5] = "Btn5",
	[BTN_6] = "Btn6",			[BTN_7] = "Btn7",
	[BTN_8] = "Btn8",			[BTN_9] = "Btn9",
	[BTN_LEFT] = "LeftBtn",			[BTN_RIGHT] = "RightBtn",
	[BTN_MIDDLE] = "MiddleBtn",		[BTN_SIDE] = "SideBtn",
	[BTN_EXTRA] = "ExtraBtn",		[BTN_FORWARD] = "ForwardBtn",
	[BTN_BACK] = "BackBtn",			[BTN_TASK] = "TaskBtn",
	[BTN_TRIGGER] = "Trigger",		[BTN_THUMB] = "ThumbBtn",
	[BTN_THUMB2] = "ThumbBtn2",		[BTN_TOP] = "TopBtn",
	[BTN_TOP2] = "TopBtn2",			[BTN_PINKIE] = "PinkieBtn",
	[BTN_BASE] = "BaseBtn",			[BTN_BASE2] = "BaseBtn2",
	[BTN_BASE3] = "BaseBtn3",		[BTN_BASE4] = "BaseBtn4",
	[BTN_BASE5] = "BaseBtn5",		[BTN_BASE6] = "BaseBtn6",
	[BTN_DEAD] = "BtnDead",			[BTN_A] = "BtnA",
	[BTN_B] = "BtnB",			[BTN_C] = "BtnC",
	[BTN_X] = "BtnX",			[BTN_Y] = "BtnY",
	[BTN_Z] = "BtnZ",			[BTN_TL] = "BtnTL",
	[BTN_TR] = "BtnTR",			[BTN_TL2] = "BtnTL2",
	[BTN_TR2] = "BtnTR2",			[BTN_SELECT] = "BtnSelect",
	[BTN_START] = "BtnStart",		[BTN_MODE] = "BtnMode",
	[BTN_THUMBL] = "BtnThumbL",		[BTN_THUMBR] = "BtnThumbR",
	[BTN_TOUCH] = "Touch",			[BTN_STYLUS] = "Stylus",
	[BTN_STYLUS2] = "Stylus2",		[BTN_TOOL_DOUBLETAP] = "Tool Doubletap",
	[BTN_TOOL_TRIPLETAP] = "Tool Tripletap", [BTN_GEAR_DOWN] = "WheelBtn",
	[BTN_GEAR_UP] = "Gear up",		[KEY_OK] = "Ok",
};


static void in_evdev_probe(const in_drv_t *drv)
{
	long keybits[KEY_CNT / sizeof(long) / 8];
	long absbits[(ABS_MAX+1) / sizeof(long) / 8];
	int i;

	// the kernel might support and return less keys then we know about,
	// so make sure the buffers are clear.
	memset(keybits, 0, sizeof(keybits));
	memset(absbits, 0, sizeof(absbits));

	for (i = 0;; i++)
	{
		int support = 0, count = 0;
		int u, ret, fd, kc_first = KEY_MAX, kc_last = 0, have_abs = 0;
		in_evdev_t *dev;
		char name[64];

		snprintf(name, sizeof(name), "/dev/input/event%d", i);
		fd = open(name, O_RDONLY|O_NONBLOCK);
		if (fd == -1) {
			if (errno == EACCES)
				continue;	/* maybe we can access next one */
			break;
		}

		/* check supported events */
		ret = ioctl(fd, EVIOCGBIT(0, sizeof(support)), &support);
		if (ret == -1) {
			printf("in_evdev: ioctl failed on %s\n", name);
			goto skip;
		}

		if (support & (1 << EV_KEY)) {
			ret = ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(keybits)), keybits);
			if (ret == -1) {
				printf("in_evdev: ioctl failed on %s\n", name);
				goto skip;
			}

			/* check for interesting keys */
			for (u = 0; u < KEY_CNT; u++) {
				if (KEYBITS_BIT(u)) {
					if (u < kc_first)
						kc_first = u;
					if (u > kc_last)
						kc_last = u;
					if (u != KEY_POWER && u != KEY_SLEEP && u != BTN_TOUCH)
						count++;
					if (u == BTN_TOUCH) /* we can't deal with ts currently */
						goto skip;
				}
			}
		}

		dev = calloc(1, sizeof(*dev));
		if (dev == NULL)
			goto skip;

		dev->drv = drv;

		ret = ioctl(fd, EVIOCGKEY(sizeof(keybits)), keybits);
		if (ret == -1) {
			printf("Warning: EVIOCGKEY not supported, will have to track state\n");
			dev->kbits = calloc(KEY_CNT, sizeof(int));
			if (dev->kbits == NULL) {
				free(dev);
				goto skip;
			}
		}

		/* check for abs too */
		if (support & (1 << EV_ABS)) {
			struct input_absinfo ainfo;
			int dist;
			ret = ioctl(fd, EVIOCGBIT(EV_ABS, sizeof(absbits)), absbits);
			if (ret == -1)
				goto no_abs;
			if (absbits[0] & (1 << ABS_X)) {
				ret = ioctl(fd, EVIOCGABS(ABS_X), &ainfo);
				if (ret == -1)
					goto no_abs;
				dist = ainfo.maximum - ainfo.minimum;
				dev->abs_lzone = dist / 4;
				dev->abs_min_x = ainfo.minimum;
				dev->abs_max_x = ainfo.maximum;
			}
			if (absbits[0] & (1 << ABS_Y)) {
				ret = ioctl(fd, EVIOCGABS(ABS_Y), &ainfo);
				if (ret == -1)
					goto no_abs;
				dist = ainfo.maximum - ainfo.minimum;
				dev->abs_min_y = ainfo.minimum;
				dev->abs_max_y = ainfo.maximum;
			}
			for (u = 0; u < MAX_ABS_DEVS; u++) {
				ret = ioctl(fd, EVIOCGABS(u), &ainfo);
				if (ret == -1)
					break;
				dist = ainfo.maximum - ainfo.minimum;
				if (dist != 0)
					dev->abs_mult[u] = IN_ABS_RANGE * 2 * 65536 / dist;
				dev->abs_adj[u] = -(ainfo.maximum + ainfo.minimum + 1) / 2;
				have_abs = 1;
			}
			dev->abs_count = u;
		}

no_abs:
		if (count == 0 && !have_abs) {
			free(dev);
			goto skip;
		}

		dev->fd = fd;
		dev->kc_first = kc_first;
		dev->kc_last = kc_last;
		if (count > 0 || in_evdev_allow_abs_only)
			dev->abs_to_digital = 1;
		strcpy(name, IN_EVDEV_PREFIX);
		ioctl(fd, EVIOCGNAME(sizeof(name)-6), name+6);
		printf("in_evdev: found \"%s\" with %d events (type %08x)\n",
			name+6, count, support);
		in_register(name, fd, dev, KEY_CNT, in_evdev_keys, 0);
		continue;

skip:
		close(fd);
	}
}

static void in_evdev_free(void *drv_data)
{
	in_evdev_t *dev = drv_data;
	if (dev == NULL)
		return;
	close(dev->fd);
	free(dev);
}

static const char * const *
in_evdev_get_key_names(const in_drv_t *drv, int *count)
{
	const struct in_pdata *pdata = drv->pdata;
	*count = KEY_CNT;

	if (pdata->key_names)
		return pdata->key_names;
	return in_evdev_keys;
}

static void or_binds(const int *binds, int key, int *result)
{
	int t;
	for (t = 0; t < IN_BINDTYPE_COUNT; t++)
		result[t] |= binds[IN_BIND_OFFS(key, t)];
}

/* ORs result with binds of pressed buttons
 * XXX: should measure performance hit of this func, might need to optimize */
static int in_evdev_update(void *drv_data, const int *binds, int *result)
{
	struct input_event ev[16];
	struct input_absinfo ainfo;
	int keybits_[KEY_CNT / sizeof(int)];
	int *keybits = keybits_;
	in_evdev_t *dev = drv_data;
	int rd, ret, u, lzone;

	if (dev->kbits == NULL) {
		ret = ioctl(dev->fd, EVIOCGKEY(sizeof(keybits_)), keybits_);
		if (ret == -1) {
			perror("in_evdev: ioctl failed");
			return -1;
		}
	}
	else {
		keybits = dev->kbits;
		while (1) {
			rd = read(dev->fd, ev, sizeof(ev));
			if (rd < (int)sizeof(ev[0])) {
				if (errno != EAGAIN)
					perror("in_evdev: read failed");
				break;
			}
			for (u = 0; u < rd / sizeof(ev[0]); u++) {
				if (ev[u].type != EV_KEY)
					continue;
				else if (ev[u].value == 1)
					KEYBITS_BIT_SET(ev[u].code);
				else if (ev[u].value == 0)
					KEYBITS_BIT_CLEAR(ev[u].code);
			}
		}
	}

	for (u = dev->kc_first; u <= dev->kc_last; u++) {
		if (KEYBITS_BIT(u))
			or_binds(binds, u, result);
	}

	/* map X and Y absolute to UDLR */
	lzone = dev->abs_lzone;
	if (dev->abs_to_digital && lzone != 0) {
		ret = ioctl(dev->fd, EVIOCGABS(ABS_X), &ainfo);
		if (ret != -1) {
			if (ainfo.value < dev->abs_min_x + lzone) or_binds(binds, KEY_LEFT, result);
			if (ainfo.value > dev->abs_max_x - lzone) or_binds(binds, KEY_RIGHT, result);
		}
		ret = ioctl(dev->fd, EVIOCGABS(ABS_Y), &ainfo);
		if (ret != -1) {
			if (ainfo.value < dev->abs_min_y + lzone) or_binds(binds, KEY_UP, result);
			if (ainfo.value > dev->abs_max_y - lzone) or_binds(binds, KEY_DOWN, result);
		}
	}

	return 0;
}

static int in_evdev_update_analog(void *drv_data, int axis_id, int *result)
{
	struct input_absinfo ainfo;
	in_evdev_t *dev = drv_data;
	int ret;

	if ((unsigned int)axis_id >= MAX_ABS_DEVS)
		return -1;

	ret = ioctl(dev->fd, EVIOCGABS(axis_id), &ainfo);
	if (ret != 0)
		return ret;

	*result = (ainfo.value + dev->abs_adj[axis_id]) * dev->abs_mult[axis_id];
	*result >>= 16;
	return 0;
}

static int in_evdev_set_blocking(in_evdev_t *dev, int y)
{
	long flags;
	int ret;

	flags = (long)fcntl(dev->fd, F_GETFL);
	if ((int)flags == -1) {
		perror("in_evdev: F_GETFL fcntl failed");
		return -1;
	}

	if (flags & O_NONBLOCK) {
		/* flush the event queue */
		struct input_event ev;
		do {
			ret = read(dev->fd, &ev, sizeof(ev));
		}
		while (ret == sizeof(ev));
	}

	if (y)
		flags &= ~O_NONBLOCK;
	else
		flags |=  O_NONBLOCK;
	ret = fcntl(dev->fd, F_SETFL, flags);
	if (ret == -1) {
		perror("in_evdev: F_SETFL fcntl failed");
		return -1;
	}

	return 0;
}

static int in_evdev_get_config(void *drv_data, int what, int *val)
{
	in_evdev_t *dev = drv_data;

	switch (what) {
	case IN_CFG_ABS_AXIS_COUNT:
		*val = dev->abs_count;
		break;
	default:
		return -1;
	}

	return 0;
}

static int in_evdev_set_config(void *drv_data, int what, int val)
{
	in_evdev_t *dev = drv_data;
	int tmp;

	switch (what) {
	case IN_CFG_BLOCKING:
		return in_evdev_set_blocking(dev, val);
	case IN_CFG_ABS_DEAD_ZONE:
		if (val < 1 || val > 99 || dev->abs_lzone == 0)
			return -1;
		/* XXX: based on X axis only, for now.. */
		tmp = (dev->abs_max_x - dev->abs_min_x) / 2;
		dev->abs_lzone = tmp - tmp * val / 100;
		if (dev->abs_lzone < 1)
			dev->abs_lzone = 1;
		else if (dev->abs_lzone >= tmp)
			dev->abs_lzone = tmp - 1;
		break;
	default:
		return -1;
	}

	return 0;
}

static int in_evdev_update_keycode(void *data, int *is_down)
{
	int ret_kc = -1, ret_down = 0;
	in_evdev_t *dev = data;
	struct input_event ev;
	int rd;

	/* do single event, the caller sometimes wants
	 * to do select() in blocking mode */
	rd = read(dev->fd, &ev, sizeof(ev));
	if (rd < (int) sizeof(ev)) {
		if (errno != EAGAIN) {
			perror("in_evdev: error reading");
			//sleep(1);
			ret_kc = -2;
		}
		goto out;
	}

	if (ev.type == EV_KEY) {
		if (ev.value < 0 || ev.value > 1)
			goto out;
		ret_kc = ev.code;
		ret_down = ev.value;
		goto out;
	}
	else if (ev.type == EV_ABS && dev->abs_to_digital)
	{
		int lzone = dev->abs_lzone, down = 0, *last;

		// map absolute to up/down/left/right
		if (lzone != 0 && ev.code == ABS_X) {
			if (ev.value < dev->abs_min_x + lzone)
				down = KEY_LEFT;
			else if (ev.value > dev->abs_max_x - lzone)
				down = KEY_RIGHT;
			last = &dev->abs_lastx;
		}
		else if (lzone != 0 && ev.code == ABS_Y) {
			if (ev.value < dev->abs_min_y + lzone)
				down = KEY_UP;
			else if (ev.value > dev->abs_max_y - lzone)
				down = KEY_DOWN;
			last = &dev->abs_lasty;
		}
		else
			goto out;

		if (down == *last)
			goto out;

		if (down == 0 || *last != 0) {
			/* key up or direction change, return up event for old key */
			ret_kc = *last;
			ret_down = 0;
			*last = 0;
			goto out;
		}
		ret_kc = *last = down;
		ret_down = 1;
		goto out;
	}

out:
	if (is_down != NULL)
		*is_down = ret_down;

	return ret_kc;
}

static int in_evdev_menu_translate(void *drv_data, int keycode, char *charcode)
{
	in_evdev_t *dev = drv_data;
	const struct in_pdata *pdata = dev->drv->pdata;
	int ret = 0;
	int i;

	if (keycode < 0)
	{
		/* menu -> kc */
		keycode = -keycode;
		for (i = 0; i < pdata->kmap_size; i++)
			if (pdata->key_map[i].pbtn == keycode) {
				int k = pdata->key_map[i].key;
				/* should really check EVIOCGBIT, but this is enough for now */
				if (dev->kc_first <= k && k <= dev->kc_last)
					return k;
			}
	}
	else
	{
		for (i = 0; i < pdata->kmap_size; i++) {
			if (pdata->key_map[i].key == keycode) {
				ret = pdata->key_map[i].pbtn;
				break;
			}
		}

		if (charcode != NULL && (unsigned int)keycode < KEY_CNT &&
		    in_evdev_keys[keycode] != NULL && in_evdev_keys[keycode][1] == 0)
		{
			char c = in_evdev_keys[keycode][0];
			if ('A' <= c && c <= 'Z')
				c = 'a' + c - 'A';
			ret |= PBTN_CHAR;
			*charcode = c;
		}
	}

	return ret;
}

/* remove binds of missing keys, count remaining ones */
static int in_evdev_clean_binds(void *drv_data, int *binds, int *def_binds)
{
	int keybits[KEY_CNT / sizeof(int)];
	in_evdev_t *dev = drv_data;
	int i, t, ret, offs, count = 0;

	memset(keybits, 0, sizeof(keybits));
	ret = ioctl(dev->fd, EVIOCGBIT(EV_KEY, sizeof(keybits)), keybits);
	if (ret == -1) {
		perror("in_evdev: ioctl failed");
		// memset(keybits, 0xff, sizeof(keybits)); /* mark all as good */
	}

	if (dev->abs_to_digital && dev->abs_lzone != 0) {
		KEYBITS_BIT_SET(KEY_LEFT);
		KEYBITS_BIT_SET(KEY_RIGHT);
		KEYBITS_BIT_SET(KEY_UP);
		KEYBITS_BIT_SET(KEY_DOWN);
	}

	for (i = 0; i < KEY_CNT; i++) {
		for (t = 0; t < IN_BINDTYPE_COUNT; t++) {
			offs = IN_BIND_OFFS(i, t);
			if (!KEYBITS_BIT(i))
				binds[offs] = def_binds[offs] = 0;
			if (binds[offs])
				count++;
		}
	}

	return count;
}

static const in_drv_t in_evdev_drv = {
	.prefix         = IN_EVDEV_PREFIX,
	.probe          = in_evdev_probe,
	.free           = in_evdev_free,
	.get_key_names  = in_evdev_get_key_names,
	.clean_binds    = in_evdev_clean_binds,
	.get_config     = in_evdev_get_config,
	.set_config     = in_evdev_set_config,
	.update         = in_evdev_update,
	.update_analog  = in_evdev_update_analog,
	.update_keycode = in_evdev_update_keycode,
	.menu_translate = in_evdev_menu_translate,
};

int in_evdev_init(const struct in_pdata *pdata)
{
	if (!pdata) {
		fprintf(stderr, "in_sdl: Missing input platform data\n");
		return -1;
	}

	in_register_driver(&in_evdev_drv, pdata->defbinds, pdata);
	return 0;
}

