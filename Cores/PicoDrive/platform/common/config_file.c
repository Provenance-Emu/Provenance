/*
 * Human-readable config file management for PicoDrive
 * (C) notaz, 2008-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#ifdef __EPOC32__
#include <unistd.h>
#endif

#include "../libpicofe/input.h"
#include "../libpicofe/plat.h"
#include "../libpicofe/lprintf.h"
#include "config_file.h"

static char *mystrip(char *str);

#ifndef _MSC_VER

#include "menu_pico.h"
#include "emu.h"
#include <pico/pico.h>

// always output DOS endlines
#ifdef _WIN32
#define NL "\n"
#else
#define NL "\r\n"
#endif

static int seek_sect(FILE *f, const char *section)
{
	char line[128], *tmp;
	int len;

	len = strlen(section);
	// seek to the section needed
	while (!feof(f))
	{
		tmp = fgets(line, sizeof(line), f);
		if (tmp == NULL) break;

		if (line[0] != '[') continue; // not section start
		if (strncmp(line + 1, section, len) == 0 && line[len+1] == ']')
			return 1; // found it
	}

	return 0;
}

static void keys_write(FILE *fn, int dev_id, const int *binds)
{
	char act[48];
	int key_count = 0, k, i;

	in_get_config(dev_id, IN_CFG_BIND_COUNT, &key_count);

	for (k = 0; k < key_count; k++)
	{
		const char *name;
		int mask;
		act[0] = act[31] = 0;

		name = in_get_key_name(dev_id, k);

		for (i = 0; me_ctrl_actions[i].name != NULL; i++) {
			mask = me_ctrl_actions[i].mask;
			if (mask & binds[IN_BIND_OFFS(k, IN_BINDTYPE_PLAYER12)]) {
				strncpy(act, me_ctrl_actions[i].name, 31);
				fprintf(fn, "bind %s = player1 %s" NL, name, mystrip(act));
			}
			mask = me_ctrl_actions[i].mask << 16;
			if (mask & binds[IN_BIND_OFFS(k, IN_BINDTYPE_PLAYER12)]) {
				strncpy(act, me_ctrl_actions[i].name, 31);
				fprintf(fn, "bind %s = player2 %s" NL, name, mystrip(act));
			}
		}

		for (i = 0; emuctrl_actions[i].name != NULL; i++) {
			mask = emuctrl_actions[i].mask;
			if (mask & binds[IN_BIND_OFFS(k, IN_BINDTYPE_EMU)]) {
				strncpy(act, emuctrl_actions[i].name, 31);
				fprintf(fn, "bind %s = %s" NL, name, mystrip(act));
			}
		}
	}
}

int config_write(const char *fname)
{
	FILE *fn = NULL;
	menu_entry *me;
	int t;
	char line[128];

	fn = fopen(fname, "w");
	if (fn == NULL)
		return -1;

	for (me = me_list_get_first(); me != NULL; me = me_list_get_next())
	{
		int dummy;
		if (!me->need_to_save || !me->enabled)
			continue;
		if (me->name == NULL || me->name[0] == 0)
			continue;

		if (me->beh == MB_OPT_ONOFF || me->beh == MB_OPT_CUSTONOFF) {
			fprintf(fn, "%s = %i" NL, me->name, (*(int *)me->var & me->mask) ? 1 : 0);
		}
		else if (me->beh == MB_OPT_RANGE || me->beh == MB_OPT_CUSTRANGE) {
			fprintf(fn, "%s = %i" NL, me->name, *(int *)me->var);
		}
		else if (me->beh == MB_OPT_ENUM && me->data != NULL) {
			const char **names = (const char **)me->data;
			for (t = 0; names[t] != NULL; t++) {
				if (*(int *)me->var == t) {
					strncpy(line, names[t], sizeof(line));
					goto write_line;
				}
			}
		}
		else if (me->generate_name != NULL) {
			strncpy(line, me->generate_name(0, &dummy), sizeof(line));
			goto write_line;
		}
		else
			lprintf("config: unhandled write: %i\n", me->id);
		continue;

write_line:
		line[sizeof(line) - 1] = 0;
		mystrip(line);
		fprintf(fn, "%s = %s" NL, me->name, line);
	}

	/* input: save binds */
	for (t = 0; t < IN_MAX_DEVS; t++)
	{
		const int *binds = in_get_dev_binds(t);
		const char *name = in_get_dev_name(t, 0, 0);
		int count = 0;

		if (binds == NULL || name == NULL)
			continue;

		fprintf(fn, "binddev = %s" NL, name);

		in_get_config(t, IN_CFG_BIND_COUNT, &count);
		keys_write(fn, t, binds);
	}

	fprintf(fn, "Sound Volume = %i" NL, currentConfig.volume);

	fprintf(fn, NL);

	fclose(fn);
	return 0;
}

int config_writelrom(const char *fname)
{
	char line[128], *tmp, *optr = NULL;
	char *old_data = NULL;
	int size;
	FILE *f;

	if (strlen(rom_fname_loaded) == 0) return -1;

	f = fopen(fname, "r");
	if (f != NULL)
	{
		fseek(f, 0, SEEK_END);
		size = ftell(f);
		fseek(f, 0, SEEK_SET);
		old_data = malloc(size + size/8);
		if (old_data != NULL)
		{
			optr = old_data;
			while (!feof(f))
			{
				tmp = fgets(line, sizeof(line), f);
				if (tmp == NULL) break;
				mystrip(line);
				if (strncasecmp(line, "LastUsedROM", 11) == 0)
					continue;
				sprintf(optr, "%s", line);
				optr += strlen(optr);
			}
		}
		fclose(f);
	}

	f = fopen(fname, "w");
	if (f == NULL) return -1;

	if (old_data != NULL) {
		fwrite(old_data, 1, optr - old_data, f);
		free(old_data);
	}
	fprintf(f, "LastUsedROM = %s" NL, rom_fname_loaded);
	fclose(f);
	return 0;
}

/* --------------------------------------------------------------------------*/

int config_readlrom(const char *fname)
{
	char line[128], *tmp;
	int i, len, ret = -1;
	FILE *f;

	f = fopen(fname, "r");
	if (f == NULL) return -1;

	// seek to the section needed
	while (!feof(f))
	{
		tmp = fgets(line, sizeof(line), f);
		if (tmp == NULL) break;

		if (strncasecmp(line, "LastUsedROM", 11) != 0) continue;
		len = strlen(line);
		for (i = 0; i < len; i++)
			if (line[i] == '#' || line[i] == '\r' || line[i] == '\n') { line[i] = 0; break; }
		tmp = strchr(line, '=');
		if (tmp == NULL) break;
		tmp++;
		mystrip(tmp);

		len = sizeof(rom_fname_loaded);
		strncpy(rom_fname_loaded, tmp, len);
		rom_fname_loaded[len-1] = 0;
		ret = 0;
		break;
	}
	fclose(f);
	return ret;
}

static int custom_read(menu_entry *me, const char *var, const char *val)
{
	char *tmp;

	switch (me->id)
	{
		case MA_OPT_FRAMESKIP:
			if (strcasecmp(var, "Frameskip") != 0) return 0;
			if (strcasecmp(val, "Auto") == 0)
			     currentConfig.Frameskip = -1;
			else currentConfig.Frameskip = atoi(val);
			return 1;

		case MA_OPT_SOUND_QUALITY:
			if (strcasecmp(var, "Sound Quality") != 0) return 0;
			PsndRate = strtoul(val, &tmp, 10);
			if (PsndRate < 8000 || PsndRate > 44100)
				PsndRate = 22050;
			if (*tmp == 'H' || *tmp == 'h') tmp++;
			if (*tmp == 'Z' || *tmp == 'z') tmp++;
			while (*tmp == ' ') tmp++;
			if        (strcasecmp(tmp, "stereo") == 0) {
				PicoOpt |=  POPT_EN_STEREO;
			} else if (strcasecmp(tmp, "mono") == 0) {
				PicoOpt &= ~POPT_EN_STEREO;
			} else
				return 0;
			return 1;

		case MA_OPT_REGION:
			if (strcasecmp(var, "Region") != 0) return 0;
			if       (strncasecmp(val, "Auto: ", 6) == 0)
			{
				const char *p = val + 5, *end = val + strlen(val);
				int i;
				PicoRegionOverride = PicoAutoRgnOrder = 0;
				for (i = 0; p < end && i < 3; i++)
				{
					while (*p == ' ') p++;
					if        (p[0] == 'J' && p[1] == 'P') {
						PicoAutoRgnOrder |= 1 << (i*4);
					} else if (p[0] == 'U' && p[1] == 'S') {
						PicoAutoRgnOrder |= 4 << (i*4);
					} else if (p[0] == 'E' && p[1] == 'U') {
						PicoAutoRgnOrder |= 8 << (i*4);
					}
					while (*p != ' ' && *p != 0) p++;
					if (*p == 0) break;
				}
			}
			else   if (strcasecmp(val, "Auto") == 0) {
				PicoRegionOverride = 0;
			} else if (strcasecmp(val, "Japan NTSC") == 0) {
				PicoRegionOverride = 1;
			} else if (strcasecmp(val, "Japan PAL") == 0) {
				PicoRegionOverride = 2;
			} else if (strcasecmp(val, "USA") == 0) {
				PicoRegionOverride = 4;
			} else if (strcasecmp(val, "Europe") == 0) {
				PicoRegionOverride = 8;
			} else
				return 0;
			return 1;

		case MA_32XOPT_MSH2_CYCLES:
			currentConfig.msh2_khz = atoi(val);
			Pico32xSetClocks(currentConfig.msh2_khz * 1000, 0);
			return 1;

		case MA_32XOPT_SSH2_CYCLES:
			currentConfig.ssh2_khz = atoi(val);
			Pico32xSetClocks(0, currentConfig.ssh2_khz * 1000);
			return 1;

		case MA_OPT2_GAMMA:
			currentConfig.gamma = atoi(val);
			return 1;

		/* PSP */
		case MA_OPT3_SCALE:
			if (strcasecmp(var, "Scale factor") != 0) return 0;
			currentConfig.scale = atof(val);
			return 1;
		case MA_OPT3_HSCALE32:
			if (strcasecmp(var, "Hor. scale (for low res. games)") != 0) return 0;
			currentConfig.hscale32 = atof(val);
			return 1;
		case MA_OPT3_HSCALE40:
			if (strcasecmp(var, "Hor. scale (for hi res. games)") != 0) return 0;
			currentConfig.hscale40 = atof(val);
			return 1;
		case MA_OPT3_VSYNC:
			// XXX: use enum
			if (strcasecmp(var, "Wait for vsync") != 0) return 0;
			if        (strcasecmp(val, "never") == 0) {
				currentConfig.EmuOpt &= ~0x12000;
			} else if (strcasecmp(val, "sometimes") == 0) {
				currentConfig.EmuOpt |=  0x12000;
			} else if (strcasecmp(val, "always") == 0) {
				currentConfig.EmuOpt &= ~0x12000;
				currentConfig.EmuOpt |=  0x02000;
			} else
				return 0;
			return 1;

		default:
			lprintf("unhandled custom_read %i: %s\n", me->id, var);
			return 0;
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

		if (player > 1)
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

static void keys_parse_all(FILE *f)
{
	char line[256], *var, *val;
	int dev_id = -1;
	int acts, type;
	int ret;

	while (!feof(f))
	{
		ret = config_get_var_val(f, line, sizeof(line), &var, &val);
		if (ret ==  0) break;
		if (ret == -1) continue;

		if (strcasecmp(var, "binddev") == 0) {
			dev_id = in_config_parse_dev(val);
			if (dev_id < 0) {
				printf("input: can't handle dev: %s\n", val);
				continue;
			}
			in_unbind_all(dev_id, -1, -1);
			continue;
		}
		if (dev_id < 0 || strncasecmp(var, "bind ", 5) != 0)
			continue;

		acts = parse_bind_val(val, &type);
		if (acts == -1) {
			lprintf("config: unhandled action \"%s\"\n", val);
			return;
		}

		mystrip(var + 5);
		in_config_bind_key(dev_id, var + 5, acts, type);
	}
}

static void parse(const char *var, const char *val, int *keys_encountered)
{
	menu_entry *me;
	int tmp;

	if (strcasecmp(var, "LastUsedROM") == 0)
		return; /* handled elsewhere */

	if (strncasecmp(var, "bind", 4) == 0) {
		*keys_encountered = 1;
		return; /* handled elsewhere */
	}

	if (strcasecmp(var, "Sound Volume") == 0) {
		currentConfig.volume = atoi(val);
		return;
	}

	for (me = me_list_get_first(); me != NULL; me = me_list_get_next())
	{
		char *p;

		if (!me->need_to_save)
			continue;
		if (me->name == NULL || strcasecmp(var, me->name) != 0)
			continue;

		if (me->beh == MB_OPT_ONOFF) {
			tmp = strtol(val, &p, 0);
			if (*p != 0)
				goto bad_val;
			if (tmp) *(int *)me->var |=  me->mask;
			else     *(int *)me->var &= ~me->mask;
			return;
		}
		else if (me->beh == MB_OPT_RANGE) {
			tmp = strtol(val, &p, 0);
			if (*p != 0)
				goto bad_val;
			if (tmp < me->min) tmp = me->min;
			if (tmp > me->max) tmp = me->max;
			*(int *)me->var = tmp;
			return;
		}
		else if (me->beh == MB_OPT_ENUM) {
			const char **names, *p1;
			int i;

			names = (const char **)me->data;
			if (names == NULL)
				goto bad_val;
			for (i = 0; names[i] != NULL; i++) {
				for (p1 = names[i]; *p1 == ' '; p1++)
					;
				if (strcasecmp(p1, val) == 0) {
					*(int *)me->var = i;
					return;
				}
			}
			goto bad_val;
		}
		else if (custom_read(me, var, val))
			return;
	}

	lprintf("config_readsect: unhandled var: \"%s\"\n", var);
	return;

bad_val:
	lprintf("config_readsect: unhandled val for \"%s\": \"%s\"\n", var, val);
}

int config_readsect(const char *fname, const char *section)
{
	char line[128], *var, *val;
	int keys_encountered = 0;
	FILE *f;
	int ret;

	f = fopen(fname, "r");
	if (f == NULL) return -1;

	if (section != NULL)
	{
		/* for game_def.cfg only */
		ret = seek_sect(f, section);
		if (!ret) {
			lprintf("config_readsect: %s: missing section [%s]\n", fname, section);
			fclose(f);
			return -1;
		}
	}

	emu_set_defconfig();

	while (!feof(f))
	{
		ret = config_get_var_val(f, line, sizeof(line), &var, &val);
		if (ret ==  0) break;
		if (ret == -1) continue;

		parse(var, val, &keys_encountered);
	}

	if (keys_encountered) {
		rewind(f);
		keys_parse_all(f);
	}

	fclose(f);

	lprintf("config_readsect: loaded from %s", fname);
	if (section != NULL)
		lprintf(" [%s]", section);
	printf("\n");

	return 0;
}

#endif // _MSC_VER

static char *mystrip(char *str)
{
	int i, len;

	len = strlen(str);
	for (i = 0; i < len; i++)
		if (str[i] != ' ') break;
	if (i > 0) memmove(str, str + i, len - i + 1);

	len = strlen(str);
	for (i = len - 1; i >= 0; i--)
		if (str[i] != ' ') break;
	str[i+1] = 0;

	return str;
}

/* returns:
 *  0 - EOF, end
 *  1 - parsed ok
 * -1 - failed to parse line
 */
int config_get_var_val(void *file, char *line, int lsize, char **rvar, char **rval)
{
	char *var, *val, *tmp;
	FILE *f = file;
	int len, i;

	tmp = fgets(line, lsize, f);
	if (tmp == NULL) return 0;

	if (line[0] == '[') return 0; // other section

	// strip comments, linefeed, spaces..
	len = strlen(line);
	for (i = 0; i < len; i++)
		if (line[i] == '#' || line[i] == '\r' || line[i] == '\n') { line[i] = 0; break; }
	mystrip(line);
	len = strlen(line);
	if (len <= 0) return -1;;

	// get var and val
	for (i = 0; i < len; i++)
		if (line[i] == '=') break;
	if (i >= len || strchr(&line[i+1], '=') != NULL) {
		lprintf("config_readsect: can't parse: %s\n", line);
		return -1;
	}
	line[i] = 0;
	var = line;
	val = &line[i+1];
	mystrip(var);
	mystrip(val);

#ifndef _MSC_VER
	if (strlen(var) == 0 || (strlen(val) == 0 && strncasecmp(var, "bind", 4) != 0)) {
		lprintf("config_readsect: something's empty: \"%s\" = \"%s\"\n", var, val);
		return -1;;
	}
#endif

	*rvar = var;
	*rval = val;
	return 1;
}

