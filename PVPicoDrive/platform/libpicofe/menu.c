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
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <time.h>
#include <locale.h> // savestate date

#include "menu.h"
#include "fonts.h"
#include "readpng.h"
#include "lprintf.h"
#include "input.h"
#include "plat.h"
#include "posix.h"

static char static_buff[64];
static int  menu_error_time = 0;
char menu_error_msg[64] = { 0, };
void *g_menuscreen_ptr;
void *g_menubg_src_ptr;
void *g_menubg_ptr;

int g_menuscreen_w;
int g_menuscreen_h;

int g_autostateld_opt;

static unsigned char *menu_font_data = NULL;
static int menu_text_color = 0xfffe; // default to white
static int menu_sel_color = -1; // disabled

/* note: these might become non-constant in future */
#if MENU_X2
static const int me_mfont_w = 16, me_mfont_h = 20;
static const int me_sfont_w = 12, me_sfont_h = 20;
#else
static const int me_mfont_w = 8, me_mfont_h = 10;
static const int me_sfont_w = 6, me_sfont_h = 10;
#endif

static int g_menu_filter_off;
static int g_border_style;
static int border_left, border_right, border_top, border_bottom;

// draws text to current bbp16 screen
static void text_out16_(int x, int y, const char *text, int color)
{
	int i, lh, tr, tg, tb, len;
	unsigned short *dest = (unsigned short *)g_menuscreen_ptr + x + y * g_menuscreen_w;
	tr = (color & 0xf800) >> 8;
	tg = (color & 0x07e0) >> 3;
	tb = (color & 0x001f) << 3;

	if (text == (void *)1)
	{
		// selector symbol
		text = "";
		len = 1;
	}
	else
	{
		const char *p;
		for (p = text; *p != 0 && *p != '\n'; p++)
			;
		len = p - text;
	}

	lh = me_mfont_h;
	if (y + lh > g_menuscreen_h)
		lh = g_menuscreen_h - y;

	for (i = 0; i < len; i++)
	{
		unsigned char  *src = menu_font_data + (unsigned int)text[i] * me_mfont_w * me_mfont_h / 2;
		unsigned short *dst = dest;
		int u, l;

		for (l = 0; l < lh; l++, dst += g_menuscreen_w - me_mfont_w)
		{
			for (u = me_mfont_w / 2; u > 0; u--, src++)
			{
				int c, r, g, b;
				c = *src >> 4;
				r = (*dst & 0xf800) >> 8;
				g = (*dst & 0x07e0) >> 3;
				b = (*dst & 0x001f) << 3;
				r = (c^0xf)*r/15 + c*tr/15;
				g = (c^0xf)*g/15 + c*tg/15;
				b = (c^0xf)*b/15 + c*tb/15;
				*dst++ = ((r<<8)&0xf800) | ((g<<3)&0x07e0) | (b>>3);
				c = *src & 0xf;
				r = (*dst & 0xf800) >> 8;
				g = (*dst & 0x07e0) >> 3;
				b = (*dst & 0x001f) << 3;
				r = (c^0xf)*r/15 + c*tr/15;
				g = (c^0xf)*g/15 + c*tg/15;
				b = (c^0xf)*b/15 + c*tb/15;
				*dst++ = ((r<<8)&0xf800) | ((g<<3)&0x07e0) | (b>>3);
			}
		}
		dest += me_mfont_w;
	}

	if (x < border_left)
		border_left = x;
	if (x + i * me_mfont_w > border_right)
		border_right = x + i * me_mfont_w;
	if (y < border_top)
		border_top = y;
	if (y + me_mfont_h > border_bottom)
		border_bottom = y + me_mfont_h;
}

void text_out16(int x, int y, const char *texto, ...)
{
	va_list args;
	char    buffer[256];
	int     maxw = (g_menuscreen_w - x) / me_mfont_w;

	if (maxw < 0)
		return;

	va_start(args, texto);
	vsnprintf(buffer, sizeof(buffer), texto, args);
	va_end(args);

	if (maxw > sizeof(buffer) - 1)
		maxw = sizeof(buffer) - 1;
	buffer[maxw] = 0;

	text_out16_(x,y,buffer,menu_text_color);
}

/* draws in 6x8 font, might multiply size by integer */
static void smalltext_out16_(int x, int y, const char *texto, int color)
{
	unsigned char  *src;
	unsigned short *dst;
	int multiplier = me_sfont_w / 6;
	int i;

	for (i = 0;; i++, x += me_sfont_w)
	{
		unsigned char c = (unsigned char) texto[i];
		int h = 8;

		if (!c || c == '\n')
			break;

		src = fontdata6x8[c];
		dst = (unsigned short *)g_menuscreen_ptr + x + y * g_menuscreen_w;

		while (h--)
		{
			int m, w2, h2;
			for (h2 = multiplier; h2 > 0; h2--)
			{
				for (m = 0x20; m; m >>= 1) {
					if (*src & m)
						for (w2 = multiplier; w2 > 0; w2--)
							*dst++ = color;
					else
						dst += multiplier;
				}

				dst += g_menuscreen_w - me_sfont_w;
			}
			src++;
		}
	}
}

static void smalltext_out16(int x, int y, const char *texto, int color)
{
	char buffer[128];
	int maxw = (g_menuscreen_w - x) / me_sfont_w;

	if (maxw < 0)
		return;

	strncpy(buffer, texto, sizeof(buffer));
	if (maxw > sizeof(buffer) - 1)
		maxw = sizeof(buffer) - 1;
	buffer[maxw] = 0;

	smalltext_out16_(x, y, buffer, color);
}

static void menu_draw_selection(int x, int y, int w)
{
	int i, h;
	unsigned short *dst, *dest;

	text_out16_(x, y, (void *)1, (menu_sel_color < 0) ? menu_text_color : menu_sel_color);

	if (menu_sel_color < 0) return; // no selection hilight

	if (y > 0) y--;
	dest = (unsigned short *)g_menuscreen_ptr + x + y * g_menuscreen_w + me_mfont_w * 2 - 2;
	for (h = me_mfont_h + 1; h > 0; h--)
	{
		dst = dest;
		for (i = w - (me_mfont_w * 2 - 2); i > 0; i--)
			*dst++ = menu_sel_color;
		dest += g_menuscreen_w;
	}
}

static int parse_hex_color(char *buff)
{
	char *endp = buff;
	int t = (int) strtoul(buff, &endp, 16);
	if (endp != buff)
#ifdef PSP
		return ((t<<8)&0xf800) | ((t>>5)&0x07e0) | ((t>>19)&0x1f);
#else
		return ((t>>8)&0xf800) | ((t>>5)&0x07e0) | ((t>>3)&0x1f);
#endif
	return -1;
}

static char tolower_simple(char c)
{
	if ('A' <= c && c <= 'Z')
		c = c - 'A' + 'a';
	return c;
}

void menu_init_base(void)
{
	int i, c, l, pos;
	unsigned char *fd, *fds;
	char buff[256];
	FILE *f;

	if (menu_font_data != NULL)
		free(menu_font_data);

	menu_font_data = calloc((MENU_X2 ? 256 * 320 : 128 * 160) / 2, 1);
	if (menu_font_data == NULL)
		return;

	// generate default 8x10 font from fontdata8x8
	for (c = 0, fd = menu_font_data; c < 256; c++)
	{
		for (l = 0; l < 8; l++)
		{
			unsigned char fd8x8 = fontdata8x8[c*8+l];
			if (fd8x8&0x80) *fd  = 0xf0;
			if (fd8x8&0x40) *fd |= 0x0f; fd++;
			if (fd8x8&0x20) *fd  = 0xf0;
			if (fd8x8&0x10) *fd |= 0x0f; fd++;
			if (fd8x8&0x08) *fd  = 0xf0;
			if (fd8x8&0x04) *fd |= 0x0f; fd++;
			if (fd8x8&0x02) *fd  = 0xf0;
			if (fd8x8&0x01) *fd |= 0x0f; fd++;
		}
		fd += 8*2/2; // 2 empty lines
	}

	if (MENU_X2) {
		// expand default font
		fds = menu_font_data + 128 * 160 / 2 - 4;
		fd  = menu_font_data + 256 * 320 / 2 - 1;
		for (c = 255; c >= 0; c--)
		{
			for (l = 9; l >= 0; l--, fds -= 4)
			{
				for (i = 3; i >= 0; i--) {
					int px = fds[i] & 0x0f;
					*fd-- = px | (px << 4);
					px = (fds[i] >> 4) & 0x0f;
					*fd-- = px | (px << 4);
				}
				for (i = 3; i >= 0; i--) {
					int px = fds[i] & 0x0f;
					*fd-- = px | (px << 4);
					px = (fds[i] >> 4) & 0x0f;
					*fd-- = px | (px << 4);
				}
			}
		}
	}

	// load custom font and selector (stored as 1st symbol in font table)
	pos = plat_get_skin_dir(buff, sizeof(buff));
	strcpy(buff + pos, "font.png");
	readpng(menu_font_data, buff, READPNG_FONT,
		MENU_X2 ? 256 : 128, MENU_X2 ? 320 : 160);
	// default selector symbol is '>'
	memcpy(menu_font_data, menu_font_data + ((int)'>') * me_mfont_w * me_mfont_h / 2,
		me_mfont_w * me_mfont_h / 2);
	strcpy(buff + pos, "selector.png");
	readpng(menu_font_data, buff, READPNG_SELECTOR, me_mfont_w, me_mfont_h);

	// load custom colors
	strcpy(buff + pos, "skin.txt");
	f = fopen(buff, "r");
	if (f != NULL)
	{
		lprintf("found skin.txt\n");
		while (!feof(f))
		{
			if (fgets(buff, sizeof(buff), f) == NULL)
				break;
			if (buff[0] == '#'  || buff[0] == '/')  continue; // comment
			if (buff[0] == '\r' || buff[0] == '\n') continue; // empty line
			if (strncmp(buff, "text_color=", 11) == 0)
			{
				int tmp = parse_hex_color(buff+11);
				if (tmp >= 0) menu_text_color = tmp;
				else lprintf("skin.txt: parse error for text_color\n");
			}
			else if (strncmp(buff, "selection_color=", 16) == 0)
			{
				int tmp = parse_hex_color(buff+16);
				if (tmp >= 0) menu_sel_color = tmp;
				else lprintf("skin.txt: parse error for selection_color\n");
			}
			else
				lprintf("skin.txt: parse error: %s\n", buff);
		}
		fclose(f);
	}

	// use user's locale for savestate date display
	setlocale(LC_TIME, "");
}

static void menu_darken_bg(void *dst, void *src, int pixels, int darker)
{
	unsigned int *dest = dst;
	unsigned int *sorc = src;
	pixels /= 2;
	if (darker)
	{
		while (pixels--)
		{
			unsigned int p = *sorc++;
			*dest++ = ((p&0xf79ef79e)>>1) - ((p&0xc618c618)>>3);
		}
	}
	else
	{
		while (pixels--)
		{
			unsigned int p = *sorc++;
			*dest++ = (p&0xf79ef79e)>>1;
		}
	}
}

static void menu_darken_text_bg(void)
{
	int x, y, xmin, xmax, ymax, ls;
	unsigned short *screen = g_menuscreen_ptr;

	xmin = border_left - 3;
	if (xmin < 0)
		xmin = 0;
	xmax = border_right + 2;
	if (xmax > g_menuscreen_w - 1)
		xmax = g_menuscreen_w - 1;

	y = border_top - 3;
	if (y < 0)
		y = 0;
	ymax = border_bottom + 2;
	if (ymax > g_menuscreen_h - 1)
		ymax = g_menuscreen_h - 1;

	for (x = xmin; x <= xmax; x++)
		screen[y * g_menuscreen_w + x] = 0xa514;
	for (y++; y < ymax; y++)
	{
		ls = y * g_menuscreen_w;
		screen[ls + xmin] = 0xffff;
		for (x = xmin + 1; x < xmax; x++)
		{
			unsigned int p = screen[ls + x];
			if (p != menu_text_color)
				screen[ls + x] = ((p&0xf79e)>>1) - ((p&0xc618)>>3);
		}
		screen[ls + xmax] = 0xffff;
	}
	ls = y * g_menuscreen_w;
	for (x = xmin; x <= xmax; x++)
		screen[ls + x] = 0xffff;
}

static int borders_pending;

static void menu_reset_borders(void)
{
	border_left = g_menuscreen_w;
	border_right = 0;
	border_top = g_menuscreen_h;
	border_bottom = 0;
}

static void menu_draw_begin(int need_bg, int no_borders)
{
	plat_video_menu_begin();

	menu_reset_borders();
	borders_pending = g_border_style && !no_borders;

	if (need_bg) {
		if (g_border_style && no_borders) {
			menu_darken_bg(g_menuscreen_ptr, g_menubg_ptr,
				g_menuscreen_w * g_menuscreen_h, 1);
		}
		else {
			memcpy(g_menuscreen_ptr, g_menubg_ptr,
				g_menuscreen_w * g_menuscreen_h * 2);
		}
	}
}

static void menu_draw_end(void)
{
	if (borders_pending)
		menu_darken_text_bg();
	plat_video_menu_end();
}

static void menu_separation(void)
{
	if (borders_pending) {
		menu_darken_text_bg();
		menu_reset_borders();
	}
}

static int me_id2offset(const menu_entry *ent, menu_id id)
{
	int i;
	for (i = 0; ent->name; ent++, i++)
		if (ent->id == id) return i;

	lprintf("%s: id %i not found\n", __FUNCTION__, id);
	return 0;
}

static void me_enable(menu_entry *entries, menu_id id, int enable)
{
	int i = me_id2offset(entries, id);
	entries[i].enabled = enable;
}

static int me_count(const menu_entry *ent)
{
	int ret;

	for (ret = 0; ent->name; ent++, ret++)
		;

	return ret;
}

static unsigned int me_read_onoff(const menu_entry *ent)
{
	// guess var size based on mask to avoid reading too much
	if (ent->mask & 0xffff0000)
		return *(unsigned int *)ent->var & ent->mask;
	else if (ent->mask & 0xff00)
		return *(unsigned short *)ent->var & ent->mask;
	else
		return *(unsigned char *)ent->var & ent->mask;
}

static void me_toggle_onoff(menu_entry *ent)
{
	// guess var size based on mask to avoid reading too much
	if (ent->mask & 0xffff0000)
		*(unsigned int *)ent->var ^= ent->mask;
	else if (ent->mask & 0xff00)
		*(unsigned short *)ent->var ^= ent->mask;
	else
		*(unsigned char *)ent->var ^= ent->mask;
}

static void me_draw(const menu_entry *entries, int sel, void (*draw_more)(void))
{
	const menu_entry *ent, *ent_sel = entries;
	int x, y, w = 0, h = 0;
	int offs, col2_offs = 27 * me_mfont_w;
	int vi_sel_ln = 0;
	const char *name;
	int i, n;

	/* calculate size of menu rect */
	for (ent = entries, i = n = 0; ent->name; ent++, i++)
	{
		int wt;

		if (!ent->enabled)
			continue;

		if (i == sel) {
			ent_sel = ent;
			vi_sel_ln = n;
		}

		name = NULL;
		wt = strlen(ent->name) * me_mfont_w;
		if (wt == 0 && ent->generate_name)
			name = ent->generate_name(ent->id, &offs);
		if (name != NULL)
			wt = strlen(name) * me_mfont_w;

		if (ent->beh != MB_NONE)
		{
			if (wt > col2_offs)
				col2_offs = wt + me_mfont_w;
			wt = col2_offs;

			switch (ent->beh) {
			case MB_NONE:
				break;
			case MB_OPT_ONOFF:
			case MB_OPT_RANGE:
				wt += me_mfont_w * 3;
				break;
			case MB_OPT_CUSTOM:
			case MB_OPT_CUSTONOFF:
			case MB_OPT_CUSTRANGE:
				name = NULL;
				offs = 0;
				if (ent->generate_name != NULL)
					name = ent->generate_name(ent->id, &offs);
				if (name != NULL)
					wt += (strlen(name) + offs) * me_mfont_w;
				break;
			case MB_OPT_ENUM:
				wt += 10 * me_mfont_w;
				break;
			}
		}

		if (wt > w)
			w = wt;
		n++;
	}
	h = n * me_mfont_h;
	w += me_mfont_w * 2; /* selector */

	if (w > g_menuscreen_w) {
		lprintf("width %d > %d\n", w, g_menuscreen_w);
		w = g_menuscreen_w;
	}
	if (h > g_menuscreen_h) {
		lprintf("height %d > %d\n", w, g_menuscreen_h);
		h = g_menuscreen_h;
	}

	x = g_menuscreen_w / 2 - w / 2;
	y = g_menuscreen_h / 2 - h / 2;
#ifdef MENU_ALIGN_LEFT
	if (x > 12) x = 12;
#endif

	/* draw */
	menu_draw_begin(1, 0);
	menu_draw_selection(x, y + vi_sel_ln * me_mfont_h, w);
	x += me_mfont_w * 2;

	for (ent = entries; ent->name; ent++)
	{
		const char **names;
		int len, leftname_end = 0;

		if (!ent->enabled)
			continue;

		name = ent->name;
		if (strlen(name) == 0) {
			if (ent->generate_name)
				name = ent->generate_name(ent->id, &offs);
		}
		if (name != NULL) {
			text_out16(x, y, name);
			leftname_end = x + (strlen(name) + 1) * me_mfont_w;
		}

		switch (ent->beh) {
		case MB_NONE:
			break;
		case MB_OPT_ONOFF:
			text_out16(x + col2_offs, y, me_read_onoff(ent) ? "ON" : "OFF");
			break;
		case MB_OPT_RANGE:
			text_out16(x + col2_offs, y, "%i", *(int *)ent->var);
			break;
		case MB_OPT_CUSTOM:
		case MB_OPT_CUSTONOFF:
		case MB_OPT_CUSTRANGE:
			name = NULL;
			offs = 0;
			if (ent->generate_name)
				name = ent->generate_name(ent->id, &offs);
			if (name != NULL)
				text_out16(x + col2_offs + offs * me_mfont_w, y, "%s", name);
			break;
		case MB_OPT_ENUM:
			names = (const char **)ent->data;
			for (i = 0; names[i] != NULL; i++) {
				offs = x + col2_offs;
				len = strlen(names[i]);
				if (len > 10)
					offs += (10 - len - 2) * me_mfont_w;
				if (offs < leftname_end)
					offs = leftname_end;
				if (i == *(unsigned char *)ent->var) {
					text_out16(offs, y, "%s", names[i]);
					break;
				}
			}
			break;
		}

		y += me_mfont_h;
	}

	menu_separation();

	/* display help or message if we have one */
	h = (g_menuscreen_h - h) / 2; // bottom area height
	if (menu_error_msg[0] != 0) {
		if (h >= me_mfont_h + 4)
			text_out16(5, g_menuscreen_h - me_mfont_h - 4, menu_error_msg);
		else
			lprintf("menu msg doesn't fit!\n");

		if (plat_get_ticks_ms() - menu_error_time > 2048)
			menu_error_msg[0] = 0;
	}
	else if (ent_sel->help != NULL) {
		const char *tmp = ent_sel->help;
		int l;
		for (l = 0; tmp != NULL && *tmp != 0; l++)
			tmp = strchr(tmp + 1, '\n');
		if (h >= l * me_sfont_h + 4)
			for (tmp = ent_sel->help; l > 0; l--, tmp = strchr(tmp, '\n') + 1)
				smalltext_out16(5, g_menuscreen_h - (l * me_sfont_h + 4), tmp, 0xffff);
	}

	menu_separation();

	if (draw_more != NULL)
		draw_more();

	menu_draw_end();
}

static int me_process(menu_entry *entry, int is_next, int is_lr)
{
	const char **names;
	int c;
	switch (entry->beh)
	{
		case MB_OPT_ONOFF:
		case MB_OPT_CUSTONOFF:
			me_toggle_onoff(entry);
			return 1;
		case MB_OPT_RANGE:
		case MB_OPT_CUSTRANGE:
			c = is_lr ? 10 : 1;
			*(int *)entry->var += is_next ? c : -c;
			if (*(int *)entry->var < (int)entry->min)
				*(int *)entry->var = (int)entry->max;
			if (*(int *)entry->var > (int)entry->max)
				*(int *)entry->var = (int)entry->min;
			return 1;
		case MB_OPT_ENUM:
			names = (const char **)entry->data;
			for (c = 0; names[c] != NULL; c++)
				;
			*(signed char *)entry->var += is_next ? 1 : -1;
			if (*(signed char *)entry->var < 0)
				*(signed char *)entry->var = 0;
			if (*(signed char *)entry->var >= c)
				*(signed char *)entry->var = c - 1;
			return 1;
		default:
			return 0;
	}
}

static void debug_menu_loop(void);

static int me_loop_d(menu_entry *menu, int *menu_sel, void (*draw_prep)(void), void (*draw_more)(void))
{
	int ret = 0, inp, sel = *menu_sel, menu_sel_max;

	menu_sel_max = me_count(menu) - 1;
	if (menu_sel_max < 0) {
		lprintf("no enabled menu entries\n");
		return 0;
	}

	while ((!menu[sel].enabled || !menu[sel].selectable) && sel < menu_sel_max)
		sel++;

	/* make sure action buttons are not pressed on entering menu */
	me_draw(menu, sel, NULL);
	while (in_menu_wait_any(NULL, 50) & (PBTN_MOK|PBTN_MBACK|PBTN_MENU));

	for (;;)
	{
		if (draw_prep != NULL)
			draw_prep();

		me_draw(menu, sel, draw_more);
		inp = in_menu_wait(PBTN_UP|PBTN_DOWN|PBTN_LEFT|PBTN_RIGHT|
			PBTN_MOK|PBTN_MBACK|PBTN_MENU|PBTN_L|PBTN_R, NULL, 70);
		if (inp & (PBTN_MENU|PBTN_MBACK))
			break;

		if (inp & PBTN_UP  ) {
			do {
				sel--;
				if (sel < 0)
					sel = menu_sel_max;
			}
			while (!menu[sel].enabled || !menu[sel].selectable);
		}
		if (inp & PBTN_DOWN) {
			do {
				sel++;
				if (sel > menu_sel_max)
					sel = 0;
			}
			while (!menu[sel].enabled || !menu[sel].selectable);
		}

		/* a bit hacky but oh well */
		if ((inp & (PBTN_L|PBTN_R)) == (PBTN_L|PBTN_R))
			debug_menu_loop();

		if (inp & (PBTN_LEFT|PBTN_RIGHT|PBTN_L|PBTN_R)) { /* multi choice */
			if (me_process(&menu[sel], (inp & (PBTN_RIGHT|PBTN_R)) ? 1 : 0,
						inp & (PBTN_L|PBTN_R)))
				continue;
		}

		if (inp & (PBTN_MOK|PBTN_LEFT|PBTN_RIGHT|PBTN_L|PBTN_R))
		{
			/* require PBTN_MOK for MB_NONE */
			if (menu[sel].handler != NULL && (menu[sel].beh != MB_NONE || (inp & PBTN_MOK))) {
				ret = menu[sel].handler(menu[sel].id, inp);
				if (ret) break;
				menu_sel_max = me_count(menu) - 1; /* might change, so update */
			}
		}
	}
	*menu_sel = sel;

	return ret;
}

static int me_loop(menu_entry *menu, int *menu_sel)
{
	return me_loop_d(menu, menu_sel, NULL, NULL);
}

/* ***************************************** */

static void draw_menu_message(const char *msg, void (*draw_more)(void))
{
	int x, y, h, w, wt;
	const char *p;

	p = msg;
	for (h = 1, w = 0; *p != 0; h++) {
		for (wt = 0; *p != 0 && *p != '\n'; p++)
			wt++;

		if (wt > w)
			w = wt;
		if (*p == 0)
			break;
		p++;
	}

	x = g_menuscreen_w / 2 - w * me_mfont_w / 2;
	y = g_menuscreen_h / 2 - h * me_mfont_h / 2;
	if (x < 0) x = 0;
	if (y < 0) y = 0;

	menu_draw_begin(1, 0);

	for (p = msg; *p != 0 && y <= g_menuscreen_h - me_mfont_h; y += me_mfont_h) {
		text_out16(x, y, p);

		for (; *p != 0 && *p != '\n'; p++)
			;
		if (*p != 0)
			p++;
	}

	menu_separation();

	if (draw_more != NULL)
		draw_more();

	menu_draw_end();
}

// -------------- del confirm ---------------

static void do_delete(const char *fpath, const char *fname)
{
	int len, mid, inp;
	const char *nm;
	char tmp[64];

	menu_draw_begin(1, 0);

	len = strlen(fname);
	if (len > g_menuscreen_w / me_sfont_w)
		len = g_menuscreen_w / me_sfont_w;

	mid = g_menuscreen_w / 2;
	text_out16(mid - me_mfont_w * 15 / 2,  8 * me_mfont_h, "About to delete");
	smalltext_out16(mid - len * me_sfont_w / 2, 9 * me_mfont_h + 5, fname, 0xbdff);
	text_out16(mid - me_mfont_w * 13 / 2, 11 * me_mfont_h, "Are you sure?");

	nm = in_get_key_name(-1, -PBTN_MA3);
	snprintf(tmp, sizeof(tmp), "(%s - confirm, ", nm);
	len = strlen(tmp);
	nm = in_get_key_name(-1, -PBTN_MBACK);
	snprintf(tmp + len, sizeof(tmp) - len, "%s - cancel)", nm);
	len = strlen(tmp);

	text_out16(mid - me_mfont_w * len / 2, 12 * me_mfont_h, tmp);
	menu_draw_end();

	while (in_menu_wait_any(NULL, 50) & (PBTN_MENU|PBTN_MA2));
	inp = in_menu_wait(PBTN_MA3|PBTN_MBACK, NULL, 100);
	if (inp & PBTN_MA3)
		remove(fpath);
}

// -------------- ROM selector --------------

static void draw_dirlist(char *curdir, struct dirent **namelist,
	int n, int sel, int show_help)
{
	int max_cnt, start, i, x, pos;
	void *darken_ptr;
	char buff[64];

	max_cnt = g_menuscreen_h / me_sfont_h;
	start = max_cnt / 2 - sel;
	n--; // exclude current dir (".")

	menu_draw_begin(1, 1);

//	if (!rom_loaded)
//		menu_darken_bg(gp2x_screen, 320*240, 0);

	darken_ptr = (short *)g_menuscreen_ptr + g_menuscreen_w * max_cnt/2 * me_sfont_h;
	menu_darken_bg(darken_ptr, darken_ptr, g_menuscreen_w * me_sfont_h * 8 / 10, 0);

	x = 5 + me_mfont_w + 1;
	if (start - 2 >= 0)
		smalltext_out16(14, (start - 2) * me_sfont_h, curdir, 0xffff);
	for (i = 0; i < n; i++) {
		pos = start + i;
		if (pos < 0)  continue;
		if (pos >= max_cnt) break;
		if (namelist[i+1]->d_type == DT_DIR) {
			smalltext_out16(x, pos * me_sfont_h, "/", 0xfff6);
			smalltext_out16(x + me_sfont_w, pos * me_sfont_h, namelist[i+1]->d_name, 0xfff6);
		} else {
			unsigned short color = fname2color(namelist[i+1]->d_name);
			smalltext_out16(x, pos * me_sfont_h, namelist[i+1]->d_name, color);
		}
	}
	smalltext_out16(5, max_cnt/2 * me_sfont_h, ">", 0xffff);

	if (show_help) {
		darken_ptr = (short *)g_menuscreen_ptr
			+ g_menuscreen_w * (g_menuscreen_h - me_sfont_h * 5 / 2);
		menu_darken_bg(darken_ptr, darken_ptr,
			g_menuscreen_w * (me_sfont_h * 5 / 2), 1);

		snprintf(buff, sizeof(buff), "%s - select, %s - back",
			in_get_key_name(-1, -PBTN_MOK), in_get_key_name(-1, -PBTN_MBACK));
		smalltext_out16(x, g_menuscreen_h - me_sfont_h * 3 - 2, buff, 0xe78c);

		snprintf(buff, sizeof(buff), g_menu_filter_off ?
			 "%s - hide unknown files" : "%s - show all files",
			in_get_key_name(-1, -PBTN_MA3));
		smalltext_out16(x, g_menuscreen_h - me_sfont_h * 2 - 2, buff, 0xe78c);

		snprintf(buff, sizeof(buff), g_autostateld_opt ?
			 "%s - autoload save is ON" : "%s - autoload save is OFF",
			in_get_key_name(-1, -PBTN_MA2));
		smalltext_out16(x, g_menuscreen_h - me_sfont_h * 1 - 2, buff, 0xe78c);
	}

	menu_draw_end();
}

static int scandir_cmp(const void *p1, const void *p2)
{
	const struct dirent **d1 = (const struct dirent **)p1;
	const struct dirent **d2 = (const struct dirent **)p2;
	if ((*d1)->d_type == (*d2)->d_type)
		return alphasort(d1, d2);
	if ((*d1)->d_type == DT_DIR)
		return -1; // put before
	if ((*d2)->d_type == DT_DIR)
		return  1;

	return alphasort(d1, d2);
}

static const char **filter_exts_internal;

static int scandir_filter(const struct dirent *ent)
{
	const char **filter = filter_exts_internal;
	const char *ext;
	int i;

	if (ent == NULL || ent->d_name == NULL)
		return 0;

	if (ent->d_type == DT_DIR)
		return 1;

	ext = strrchr(ent->d_name, '.');
	if (ext == NULL)
		return 0;

	ext++;
	for (i = 0; filter[i] != NULL; i++)
		if (strcasecmp(ext, filter[i]) == 0)
			return 1;

	return 0;
}

static int dirent_seek_char(struct dirent **namelist, int len, int sel, char c)
{
	int i;

	sel++;
	for (i = sel + 1; ; i++) {
		if (i >= len)
			i = 1;
		if (i == sel)
			break;

		if (tolower_simple(namelist[i]->d_name[0]) == c)
			break;
	}

	return i - 1;
}

static const char *menu_loop_romsel(char *curr_path, int len,
	const char **filter_exts,
	int (*extra_filter)(struct dirent **namelist, int count,
			    const char *basedir))
{
	static char rom_fname_reload[256]; // used for return
	char sel_fname[256];
	int (*filter)(const struct dirent *);
	struct dirent **namelist = NULL;
	int n = 0, inp = 0, sel = 0, show_help = 0;
	char *curr_path_restore = NULL;
	const char *ret = NULL;
	char cinp;

	filter_exts_internal = filter_exts;
	sel_fname[0] = 0;

	// is this a dir or a full path?
	if (!plat_is_dir(curr_path)) {
		char *p = strrchr(curr_path, '/');
		if (p != NULL) {
			*p = 0;
			curr_path_restore = p;
			snprintf(sel_fname, sizeof(sel_fname), "%s", p + 1);
		}

		if (rom_fname_reload[0] == 0)
			show_help = 2;
	}

rescan:
	if (namelist != NULL) {
		while (n-- > 0)
			free(namelist[n]);
		free(namelist);
		namelist = NULL;
	}

	filter = NULL;
	if (!g_menu_filter_off)
		filter = scandir_filter;

	n = scandir(curr_path, &namelist, filter, (void *)scandir_cmp);
	if (n < 0) {
		char *t;
		lprintf("menu_loop_romsel failed, dir: %s\n", curr_path);

		// try root
		t = getcwd(curr_path, len);
		if (t == NULL)
			plat_get_root_dir(curr_path, len);
		n = scandir(curr_path, &namelist, filter, (void *)scandir_cmp);
		if (n < 0) {
			// oops, we failed
			lprintf("menu_loop_romsel failed, dir: %s\n", curr_path);
			return NULL;
		}
	}

	if (!g_menu_filter_off && extra_filter != NULL)
		n = extra_filter(namelist, n, curr_path);

	// try to find selected file
	// note: we don't show '.' so sel is namelist index - 1
	sel = 0;
	if (sel_fname[0] != 0) {
		int i;
		for (i = 1; i < n; i++) {
			char *dname = namelist[i]->d_name;
			if (dname[0] == sel_fname[0] && strcmp(dname, sel_fname) == 0) {
				sel = i - 1;
				break;
			}
		}
	}

	/* make sure action buttons are not pressed on entering menu */
	draw_dirlist(curr_path, namelist, n, sel, show_help);
	while (in_menu_wait_any(NULL, 50) & (PBTN_MOK|PBTN_MBACK|PBTN_MENU))
		;

	for (;;)
	{
		draw_dirlist(curr_path, namelist, n, sel, show_help);
		inp = in_menu_wait(PBTN_UP|PBTN_DOWN|PBTN_LEFT|PBTN_RIGHT
			| PBTN_L|PBTN_R|PBTN_MA2|PBTN_MA3|PBTN_MOK|PBTN_MBACK
			| PBTN_MENU|PBTN_CHAR, &cinp, 33);
		if (inp & PBTN_MA3)   {
			g_menu_filter_off = !g_menu_filter_off;
			snprintf(sel_fname, sizeof(sel_fname), "%s",
				namelist[sel+1]->d_name);
			goto rescan;
		}
		if (inp & PBTN_UP  )  { sel--;   if (sel < 0)   sel = n-2; }
		if (inp & PBTN_DOWN)  { sel++;   if (sel > n-2) sel = 0; }
		if (inp & PBTN_LEFT)  { sel-=10; if (sel < 0)   sel = 0; }
		if (inp & PBTN_L)     { sel-=24; if (sel < 0)   sel = 0; }
		if (inp & PBTN_RIGHT) { sel+=10; if (sel > n-2) sel = n-2; }
		if (inp & PBTN_R)     { sel+=24; if (sel > n-2) sel = n-2; }

		if ((inp & PBTN_MOK) || (inp & (PBTN_MENU|PBTN_MA2)) == (PBTN_MENU|PBTN_MA2))
		{
			again:
			if (namelist[sel+1]->d_type == DT_REG)
			{
				snprintf(rom_fname_reload, sizeof(rom_fname_reload),
					"%s/%s", curr_path, namelist[sel+1]->d_name);
				if (inp & PBTN_MOK) { // return sel
					ret = rom_fname_reload;
					break;
				}
				do_delete(rom_fname_reload, namelist[sel+1]->d_name);
				goto rescan;
			}
			else if (namelist[sel+1]->d_type == DT_DIR)
			{
				int newlen;
				char *p, *newdir;
				if (!(inp & PBTN_MOK))
					continue;
				newlen = strlen(curr_path) + strlen(namelist[sel+1]->d_name) + 2;
				newdir = malloc(newlen);
				if (newdir == NULL)
					break;
				if (strcmp(namelist[sel+1]->d_name, "..") == 0) {
					char *start = curr_path;
					p = start + strlen(start) - 1;
					while (*p == '/' && p > start) p--;
					while (*p != '/' && p > start) p--;
					if (p <= start) strcpy(newdir, "/");
					else { strncpy(newdir, start, p-start); newdir[p-start] = 0; }
				} else {
					strcpy(newdir, curr_path);
					p = newdir + strlen(newdir) - 1;
					while (*p == '/' && p >= newdir) *p-- = 0;
					strcat(newdir, "/");
					strcat(newdir, namelist[sel+1]->d_name);
				}
				ret = menu_loop_romsel(newdir, newlen, filter_exts, extra_filter);
				free(newdir);
				break;
			}
			else
			{
				// unknown file type, happens on NTFS mounts. Try to guess.
				FILE *tstf; int tmp;
				snprintf(rom_fname_reload, sizeof(rom_fname_reload),
					"%s/%s", curr_path, namelist[sel+1]->d_name);
				tstf = fopen(rom_fname_reload, "rb");
				if (tstf != NULL)
				{
					if (fread(&tmp, 1, 1, tstf) > 0 || ferror(tstf) == 0)
						namelist[sel+1]->d_type = DT_REG;
					else	namelist[sel+1]->d_type = DT_DIR;
					fclose(tstf);
					goto again;
				}
			}
		}
		else if (inp & PBTN_MA2) {
			g_autostateld_opt = !g_autostateld_opt;
			show_help = 3;
		}
		else if (inp & PBTN_CHAR) {
			// must be last
			sel = dirent_seek_char(namelist, n, sel, cinp);
		}

		if (inp & PBTN_MBACK)
			break;

		if (show_help > 0)
			show_help--;
	}

	if (n > 0) {
		while (n-- > 0)
			free(namelist[n]);
		free(namelist);
	}

	// restore curr_path
	if (curr_path_restore != NULL)
		*curr_path_restore = '/';

	return ret;
}

// ------------ savestate loader ------------

#define STATE_SLOT_COUNT 10

static int state_slot_flags = 0;
static int state_slot_times[STATE_SLOT_COUNT];

static void state_check_slots(void)
{
	int slot;

	state_slot_flags = 0;

	for (slot = 0; slot < STATE_SLOT_COUNT; slot++) {
		state_slot_times[slot] = 0;
		if (emu_check_save_file(slot, &state_slot_times[slot]))
			state_slot_flags |= 1 << slot;
	}
}

static void draw_savestate_bg(int slot);

static void draw_savestate_menu(int menu_sel, int is_loading)
{
	int i, x, y, w, h;
	char time_buf[32];

	if (state_slot_flags & (1 << menu_sel))
		draw_savestate_bg(menu_sel);

	w = (13 + 2) * me_mfont_w;
	h = (1+2+STATE_SLOT_COUNT+1) * me_mfont_h;
	x = g_menuscreen_w / 2 - w / 2;
	if (x < 0) x = 0;
	y = g_menuscreen_h / 2 - h / 2;
	if (y < 0) y = 0;
#ifdef MENU_ALIGN_LEFT
	if (x > 12 + me_mfont_w * 2)
		x = 12 + me_mfont_w * 2;
#endif

	menu_draw_begin(1, 1);

	text_out16(x, y, is_loading ? "Load state" : "Save state");
	y += 3 * me_mfont_h;

	menu_draw_selection(x - me_mfont_w * 2, y + menu_sel * me_mfont_h, (23 + 2) * me_mfont_w + 4);

	/* draw all slots */
	for (i = 0; i < STATE_SLOT_COUNT; i++, y += me_mfont_h)
	{
		if (!(state_slot_flags & (1 << i)))
			strcpy(time_buf, "free");
		else {
			strcpy(time_buf, "USED");
			if (state_slot_times[i] != 0) {
				time_t time = state_slot_times[i];
				struct tm *t = localtime(&time);
				strftime(time_buf, sizeof(time_buf), "%x %R", t);
			}
		}

		text_out16(x, y, "SLOT %i (%s)", i, time_buf);
	}
	text_out16(x, y, "back");

	menu_draw_end();
}

static int menu_loop_savestate(int is_loading)
{
	static int menu_sel = STATE_SLOT_COUNT;
	int menu_sel_max = STATE_SLOT_COUNT;
	unsigned long inp = 0;
	int ret = 0;

	state_check_slots();

	if (!(state_slot_flags & (1 << menu_sel)) && is_loading)
		menu_sel = menu_sel_max;

	for (;;)
	{
		draw_savestate_menu(menu_sel, is_loading);
		inp = in_menu_wait(PBTN_UP|PBTN_DOWN|PBTN_MOK|PBTN_MBACK, NULL, 100);
		if (inp & PBTN_UP) {
			do {
				menu_sel--;
				if (menu_sel < 0)
					menu_sel = menu_sel_max;
			} while (!(state_slot_flags & (1 << menu_sel)) && menu_sel != menu_sel_max && is_loading);
		}
		if (inp & PBTN_DOWN) {
			do {
				menu_sel++;
				if (menu_sel > menu_sel_max)
					menu_sel = 0;
			} while (!(state_slot_flags & (1 << menu_sel)) && menu_sel != menu_sel_max && is_loading);
		}
		if (inp & PBTN_MOK) { // save/load
			if (menu_sel < STATE_SLOT_COUNT) {
				state_slot = menu_sel;
				if (emu_save_load_game(is_loading, 0)) {
					menu_update_msg(is_loading ? "Load failed" : "Save failed");
					break;
				}
				ret = 1;
				break;
			}
			break;
		}
		if (inp & PBTN_MBACK)
			break;
	}

	return ret;
}

// -------------- key config --------------

static char *action_binds(int player_idx, int action_mask, int dev_id)
{
	int dev = 0, dev_last = IN_MAX_DEVS - 1;
	int can_combo = 1, type;

	static_buff[0] = 0;

	type = IN_BINDTYPE_EMU;
	if (player_idx >= 0) {
		can_combo = 0;
		type = IN_BINDTYPE_PLAYER12;
	}
	if (player_idx == 1)
		action_mask <<= 16;

	if (dev_id >= 0)
		dev = dev_last = dev_id;

	for (; dev <= dev_last; dev++) {
		int k, count = 0, combo = 0;
		const int *binds;

		binds = in_get_dev_binds(dev);
		if (binds == NULL)
			continue;

		in_get_config(dev, IN_CFG_BIND_COUNT, &count);
		in_get_config(dev, IN_CFG_DOES_COMBOS, &combo);
		combo = combo && can_combo;

		for (k = 0; k < count; k++) {
			const char *xname;
			int len;

			if (!(binds[IN_BIND_OFFS(k, type)] & action_mask))
				continue;

			xname = in_get_key_name(dev, k);
			len = strlen(static_buff);
			if (len) {
				strncat(static_buff, combo ? " + " : ", ",
					sizeof(static_buff) - len - 1);
				len += combo ? 3 : 2;
			}
			strncat(static_buff, xname, sizeof(static_buff) - len - 1);
		}
	}

	return static_buff;
}

static int count_bound_keys(int dev_id, int action_mask, int bindtype)
{
	const int *binds;
	int k, keys = 0;
	int count = 0;

	binds = in_get_dev_binds(dev_id);
	if (binds == NULL)
		return 0;

	in_get_config(dev_id, IN_CFG_BIND_COUNT, &count);
	for (k = 0; k < count; k++)
	{
		if (binds[IN_BIND_OFFS(k, bindtype)] & action_mask)
			keys++;
	}

	return keys;
}

static void draw_key_config(const me_bind_action *opts, int opt_cnt, int player_idx,
		int sel, int dev_id, int dev_count, int is_bind)
{
	char buff[64], buff2[32];
	const char *dev_name;
	int x, y, w, i;

	w = ((player_idx >= 0) ? 20 : 30) * me_mfont_w;
	x = g_menuscreen_w / 2 - w / 2;
	y = (g_menuscreen_h - 4 * me_mfont_h) / 2 - (2 + opt_cnt) * me_mfont_h / 2;
	if (x < me_mfont_w * 2)
		x = me_mfont_w * 2;

	menu_draw_begin(1, 0);
	if (player_idx >= 0)
		text_out16(x, y, "Player %i controls", player_idx + 1);
	else
		text_out16(x, y, "Emulator controls");

	y += 2 * me_mfont_h;
	menu_draw_selection(x - me_mfont_w * 2, y + sel * me_mfont_h, w + 2 * me_mfont_w);

	for (i = 0; i < opt_cnt; i++, y += me_mfont_h)
		text_out16(x, y, "%s : %s", opts[i].name,
			action_binds(player_idx, opts[i].mask, dev_id));

	menu_separation();

	if (dev_id < 0)
		dev_name = "(all devices)";
	else
		dev_name = in_get_dev_name(dev_id, 0, 1);
	w = strlen(dev_name) * me_mfont_w;
	if (w < 30 * me_mfont_w)
		w = 30 * me_mfont_w;
	if (w > g_menuscreen_w)
		w = g_menuscreen_w;

	x = g_menuscreen_w / 2 - w / 2;

	if (!is_bind) {
		snprintf(buff2, sizeof(buff2), "%s", in_get_key_name(-1, -PBTN_MOK));
		snprintf(buff, sizeof(buff), "%s - bind, %s - clear", buff2,
				in_get_key_name(-1, -PBTN_MA2));
		text_out16(x, g_menuscreen_h - 4 * me_mfont_h, buff);
	}
	else
		text_out16(x, g_menuscreen_h - 4 * me_mfont_h, "Press a button to bind/unbind");

	if (dev_count > 1) {
		text_out16(x, g_menuscreen_h - 3 * me_mfont_h, dev_name);
		text_out16(x, g_menuscreen_h - 2 * me_mfont_h, "Press left/right for other devs");
	}

	menu_draw_end();
}

static void key_config_loop(const me_bind_action *opts, int opt_cnt, int player_idx)
{
	int i, sel = 0, menu_sel_max = opt_cnt - 1, does_combos = 0;
	int dev_id, bind_dev_id, dev_count, kc, is_down, mkey;
	int unbind, bindtype, mask_shift;

	for (i = 0, dev_id = -1, dev_count = 0; i < IN_MAX_DEVS; i++) {
		if (in_get_dev_name(i, 1, 0) != NULL) {
			dev_count++;
			if (dev_id < 0)
				dev_id = i;
		}
	}

	if (dev_id == -1) {
		lprintf("no devs, can't do config\n");
		return;
	}

	dev_id = -1; // show all
	mask_shift = 0;
	if (player_idx == 1)
		mask_shift = 16;
	bindtype = player_idx >= 0 ? IN_BINDTYPE_PLAYER12 : IN_BINDTYPE_EMU;

	for (;;)
	{
		draw_key_config(opts, opt_cnt, player_idx, sel, dev_id, dev_count, 0);
		mkey = in_menu_wait(PBTN_UP|PBTN_DOWN|PBTN_LEFT|PBTN_RIGHT
				|PBTN_MBACK|PBTN_MOK|PBTN_MA2, NULL, 100);
		switch (mkey) {
			case PBTN_UP:   sel--; if (sel < 0) sel = menu_sel_max; continue;
			case PBTN_DOWN: sel++; if (sel > menu_sel_max) sel = 0; continue;
			case PBTN_LEFT:
				for (i = 0, dev_id--; i < IN_MAX_DEVS + 1; i++, dev_id--) {
					if (dev_id < -1)
						dev_id = IN_MAX_DEVS - 1;
					if (dev_id == -1 || in_get_dev_name(dev_id, 0, 0) != NULL)
						break;
				}
				continue;
			case PBTN_RIGHT:
				for (i = 0, dev_id++; i < IN_MAX_DEVS; i++, dev_id++) {
					if (dev_id >= IN_MAX_DEVS)
						dev_id = -1;
					if (dev_id == -1 || in_get_dev_name(dev_id, 0, 0) != NULL)
						break;
				}
				continue;
			case PBTN_MBACK:
				return;
			case PBTN_MOK:
				if (sel >= opt_cnt)
					return;
				while (in_menu_wait_any(NULL, 30) & PBTN_MOK)
					;
				break;
			case PBTN_MA2:
				in_unbind_all(dev_id, opts[sel].mask << mask_shift, bindtype);
				continue;
			default:continue;
		}

		draw_key_config(opts, opt_cnt, player_idx, sel, dev_id, dev_count, 1);

		/* wait for some up event */
		for (is_down = 1; is_down; )
			kc = in_update_keycode(&bind_dev_id, &is_down, NULL, -1);

		i = count_bound_keys(bind_dev_id, opts[sel].mask << mask_shift, bindtype);
		unbind = (i > 0);

		/* allow combos if device supports them */
		in_get_config(bind_dev_id, IN_CFG_DOES_COMBOS, &does_combos);
		if (i == 1 && bindtype == IN_BINDTYPE_EMU && does_combos)
			unbind = 0;

		if (unbind)
			in_unbind_all(bind_dev_id, opts[sel].mask << mask_shift, bindtype);

		in_bind_key(bind_dev_id, kc, opts[sel].mask << mask_shift, bindtype, 0);
	}
}

