/*
 * (C) Gražvydas "notaz" Ignotas, 2011-2012
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
#include "input.h"
#include "menu.h"
#include "config_file.h"
#include "lprintf.h"

#define array_size(x) (sizeof(x) / sizeof(x[0]))

static char *mystrip(char *str)
{
	int i, len;

	len = strlen(str);
	for (i = 0; i < len; i++)
		if (str[i] != ' ') break;
	if (i > 0) memmove(str, str + i, len - i + 1);

	len = strlen(str);
	for (i = len - 1; i >= 0; i--)
		if (str[i] != ' ' && str[i] != '\r' && str[i] != '\n') break;
	str[i+1] = 0;

	return str;
}

static void get_line(char *d, size_t size, const char *s)
{
	const char *pe;
	size_t len;

	for (pe = s; *pe != '\r' && *pe != '\n' && *pe != 0; pe++)
		;
	len = pe - s;
	if (len > size - 1)
		len = size - 1;
	strncpy(d, s, len);
	d[len] = 0;

	mystrip(d);
}

void config_write_keys(FILE *f)
{
	int d;

	for (d = 0; d < IN_MAX_DEVS; d++)
	{
		const int *binds = in_get_dev_binds(d);
		const char *name = in_get_dev_name(d, 0, 0);
		int k, count = 0;

		if (binds == NULL || name == NULL)
			continue;

		fprintf(f, "binddev = %s\n", name);
		in_get_config(d, IN_CFG_BIND_COUNT, &count);

		for (k = 0; k < count; k++)
		{
			int i, kbinds, mask;
			char act[32];

			act[0] = act[31] = 0;
			name = in_get_key_name(d, k);

			kbinds = binds[IN_BIND_OFFS(k, IN_BINDTYPE_PLAYER12)];
			for (i = 0; kbinds && me_ctrl_actions[i].name != NULL; i++) {
				mask = me_ctrl_actions[i].mask;
				if (mask & kbinds) {
					strncpy(act, me_ctrl_actions[i].name, 31);
					fprintf(f, "bind %s = player1 %s\n", name, mystrip(act));
					kbinds &= ~mask;
				}
				mask = me_ctrl_actions[i].mask << 16;
				if (mask & kbinds) {
					strncpy(act, me_ctrl_actions[i].name, 31);
					fprintf(f, "bind %s = player2 %s\n", name, mystrip(act));
					kbinds &= ~mask;
				}
			}

			kbinds = binds[IN_BIND_OFFS(k, IN_BINDTYPE_EMU)];
			for (i = 0; kbinds && emuctrl_actions[i].name != NULL; i++) {
				mask = emuctrl_actions[i].mask;
				if (mask & kbinds) {
					strncpy(act, emuctrl_actions[i].name, 31);
					fprintf(f, "bind %s = %s\n", name, mystrip(act));
					kbinds &= ~mask;
				}
			}
		}

#ifdef ANALOG_BINDS
		for (k = 0; k < array_size(in_adev); k++)
		{
			if (in_adev[k] == d)
				fprintf(f, "bind_analog = %d\n", k);
		}
#endif
	}
}

static int parse_bind_val(const char *val, int *type)
{
	int i;

	*type = IN_BINDTYPE_NONE;
	if (val[0] == 0)
		return 0;
	
	if (strncasecmp(val, "player", 6) == 0)
	{
		int player, shift = 0;
		player = atoi(val + 6) - 1;

		if ((unsigned int)player > 1)
			return -1;
		if (player == 1)
			shift = 16;

		*type = IN_BINDTYPE_PLAYER12;
		for (i = 0; me_ctrl_actions[i].name != NULL; i++) {
			if (strncasecmp(me_ctrl_actions[i].name, val + 8, strlen(val + 8)) == 0)
				return me_ctrl_actions[i].mask << shift;
		}
	}
	for (i = 0; emuctrl_actions[i].name != NULL; i++) {
		if (strncasecmp(emuctrl_actions[i].name, val, strlen(val)) == 0) {
			*type = IN_BINDTYPE_EMU;
			return emuctrl_actions[i].mask;
		}
	}

	return -1;
}

void config_read_keys(const char *cfg_content)
{
	char dev[256], key[128], *act;
	const char *p;
	int bind, bindtype;
	int dev_id;

	p = cfg_content;
	while (p != NULL && (p = strstr(p, "binddev = ")) != NULL) {
		p += 10;

		get_line(dev, sizeof(dev), p);
		dev_id = in_config_parse_dev(dev);
		if (dev_id < 0) {
			printf("input: can't handle dev: %s\n", dev);
			continue;
		}

		in_unbind_all(dev_id, -1, -1);
		while ((p = strstr(p, "bind"))) {
			if (strncmp(p, "binddev = ", 10) == 0)
				break;

#ifdef ANALOG_BINDS
			if (strncmp(p, "bind_analog", 11) == 0) {
				int ret = sscanf(p, "bind_analog = %d", &bind);
				p += 11;
				if (ret != 1) {
					printf("input: parse error: %16s..\n", p);
					continue;
				}
				if ((unsigned int)bind >= array_size(in_adev)) {
					printf("input: analog id %d out of range\n", bind);
					continue;
				}
				in_adev[bind] = dev_id;
				continue;
			}
#endif

			p += 4;
			if (*p != ' ') {
				printf("input: parse error: %16s..\n", p);
				continue;
			}

			get_line(key, sizeof(key), p);
			act = strchr(key, '=');
			if (act == NULL) {
				printf("parse failed: %16s..\n", p);
				continue;
			}
			*act = 0;
			act++;
			mystrip(key);
			mystrip(act);

			bind = parse_bind_val(act, &bindtype);
			if (bind != -1 && bind != 0) {
				//printf("bind #%d '%s' %08x (%s)\n", dev_id, key, bind, act);
				in_config_bind_key(dev_id, key, bind, bindtype);
			}
			else
				lprintf("config: unhandled action \"%s\"\n", act);
		}
	}
	in_clean_binds();
}
