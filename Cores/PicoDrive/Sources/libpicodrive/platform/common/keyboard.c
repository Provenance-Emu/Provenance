/*
 * PicoDrive
 * (C) irixxxx, 2025
 *
 * keyboard support for Pico and SC-3000/SK-1100
 */

#include <pico/pico_int.h>

#include "keyboard.h"
#include "input_pico.h"
#include "../libpicofe/menu.h"
#include "../libpicofe/plat.h"
#include "emu.h" // for menuscreen hack

#define KBD_ROWS    5

// pico
static struct key kbd_pico_row1[] = {
	{  0, "esc", "esc",	PEVB_KBD_ESCAPE },
	{  4, "1", "!",		PEVB_KBD_1 },
	{  7, "2", "\"",	PEVB_KBD_2 },
	{ 10, "3", "#",		PEVB_KBD_3 },
	{ 13, "4", "$",		PEVB_KBD_4 },
	{ 16, "5", "%",		PEVB_KBD_5 },
	{ 19, "6", "&",		PEVB_KBD_6 },
	{ 22, "7", "'",		PEVB_KBD_7 },
	{ 25, "8", "(",		PEVB_KBD_8 },
	{ 28, "9", ")",		PEVB_KBD_9 },
	{ 31, "0", "0",		PEVB_KBD_0 },
	{ 34, "-", "=",		PEVB_KBD_MINUS },
	{ 37, "^", "~",		PEVB_KBD_CARET },
	{ 40, "Y", "|",		PEVB_KBD_YEN },
	{ 43, "bs", "bs",	PEVB_KBD_BACKSPACE },
	{ 0 },
};
static struct key kbd_pico_row2[] = {
	{  5, "q", "Q",		PEVB_KBD_q },
	{  8, "w", "W",		PEVB_KBD_w },
	{ 11, "e", "E",		PEVB_KBD_e },
	{ 14, "r", "R",		PEVB_KBD_r },
	{ 17, "t", "T",		PEVB_KBD_t },
	{ 20, "y", "Y",		PEVB_KBD_y },
	{ 23, "u", "U",		PEVB_KBD_u },
	{ 26, "i", "I",		PEVB_KBD_i },
	{ 29, "o", "O",		PEVB_KBD_o },
	{ 32, "p", "P",		PEVB_KBD_p },
	{ 35, "@", "`",		PEVB_KBD_AT },
	{ 38, "[", "{",		PEVB_KBD_LEFTBRACKET },
	{ 43, "ins", "ins",	PEVB_KBD_INSERT },
	{ 0 },
};
static struct key kbd_pico_row3[] = {
	{  0, "caps", "caps",	PEVB_KBD_CAPSLOCK },
	{  6, "a", "A",		PEVB_KBD_a },
	{  9, "s", "S",		PEVB_KBD_s },
	{ 12, "d", "D",		PEVB_KBD_d },
	{ 15, "f", "F",		PEVB_KBD_f },
	{ 18, "g", "G",		PEVB_KBD_g },
	{ 21, "h", "H",		PEVB_KBD_h },
	{ 24, "j", "J",		PEVB_KBD_j },
	{ 27, "k", "K",		PEVB_KBD_k },
	{ 30, "l", "L",		PEVB_KBD_l },
	{ 33, ";", "+",		PEVB_KBD_SEMICOLON },
	{ 36, ":", "*",		PEVB_KBD_COLON },
	{ 39, "]", "}",		PEVB_KBD_RIGHTBRACKET },
	{ 43, "del", "del",	PEVB_KBD_DELETE },
	{ 0 },
};
static struct key kbd_pico_row4[] = {
	{  0, "shift", "shift",	PEVB_KBD_LSHIFT },
	{  7, "z", "Z",		PEVB_KBD_z },
	{ 10, "x", "X",		PEVB_KBD_x },
	{ 13, "c", "C",		PEVB_KBD_c },
	{ 16, "v", "V",		PEVB_KBD_v },
	{ 19, "b", "B",		PEVB_KBD_b },
	{ 22, "n", "N",		PEVB_KBD_n },
	{ 25, "m", "M",		PEVB_KBD_m },
	{ 28, ",", "<",		PEVB_KBD_COMMA },
	{ 31, ".", ">",		PEVB_KBD_PERIOD },
	{ 34, "/", "?",		PEVB_KBD_SLASH },
	{ 37, "_", "_",		PEVB_KBD_RO },
	{ 41, "enter", "enter",	PEVB_KBD_RETURN },
	{ 0 },
};
static struct key kbd_pico_row5[] = {
	{  0, "muhenkan", "muhenkan",	PEVB_KBD_SOUND }, // Korean: sound
	{ 13, "space", "space",		PEVB_KBD_SPACE },
	{ 22, "henkan", "henkan",	PEVB_KBD_HOME }, // Korean: home
	{ 29, "kana", "kana",		PEVB_KBD_CJK },
	{ 34, "romaji", "romaji",	PEVB_KBD_ROMAJI },
	{ 0 },
};

struct key *kbd_pico[KBD_ROWS+1] =
	{ kbd_pico_row1, kbd_pico_row2, kbd_pico_row3, kbd_pico_row4, kbd_pico_row5, NULL };


//sc3000
static struct key kbd_sc3000_row1[] = {
	{  4, "1", "!",		PEVB_KBD_1 },
	{  7, "2", "\"",	PEVB_KBD_2 },
	{ 10, "3", "#",		PEVB_KBD_3 },
	{ 13, "4", "$",		PEVB_KBD_4 },
	{ 16, "5", "%",		PEVB_KBD_5 },
	{ 19, "6", "&",		PEVB_KBD_6 },
	{ 22, "7", "'",		PEVB_KBD_7 },
	{ 25, "8", "(",		PEVB_KBD_8 },
	{ 28, "9", ")",		PEVB_KBD_9 },
	{ 31, "0", "0",		PEVB_KBD_0 },
	{ 34, "-", "=",		PEVB_KBD_MINUS },
	{ 37, "^", "~",		PEVB_KBD_CARET },
	{ 40, "Y", "|",		PEVB_KBD_YEN },
	{ 49, "brk", "brk",	PEVB_KBD_ESCAPE },
	{ 0 },
};
static struct key kbd_sc3000_row2[] = {
	{  0, "func", "func",	PEVB_KBD_FUNC },
	{  5, "Q", "q",		PEVB_KBD_q },
	{  8, "W", "w",		PEVB_KBD_w },
	{ 11, "E", "e",		PEVB_KBD_e },
	{ 14, "R", "r",		PEVB_KBD_r },
	{ 17, "T", "t",		PEVB_KBD_t },
	{ 20, "Y", "y",		PEVB_KBD_y },
	{ 23, "U", "u",		PEVB_KBD_u },
	{ 26, "I", "i",		PEVB_KBD_i },
	{ 29, "O", "o",		PEVB_KBD_o },
	{ 32, "P", "p",		PEVB_KBD_p },
	{ 35, "@", "`",		PEVB_KBD_AT },
	{ 38, "[", "{",		PEVB_KBD_LEFTBRACKET },
	{ 50, "^", "^",		PEVB_KBD_UP },
	{ 0 },
};
static struct key kbd_sc3000_row3[] = {
	{  0, "ctrl", "ctrl",	PEVB_KBD_CAPSLOCK },
	{  6, "A", "a",		PEVB_KBD_a },
	{  9, "S", "s",		PEVB_KBD_s },
	{ 12, "D", "d",		PEVB_KBD_d },
	{ 15, "F", "f",		PEVB_KBD_f },
	{ 18, "G", "g",		PEVB_KBD_g },
	{ 21, "H", "h",		PEVB_KBD_h },
	{ 24, "J", "j",		PEVB_KBD_j },
	{ 27, "K", "k",		PEVB_KBD_k },
	{ 30, "L", "l",		PEVB_KBD_l },
	{ 33, ";", "+",		PEVB_KBD_SEMICOLON },
	{ 36, ":", "*",		PEVB_KBD_COLON },
	{ 39, "]", "}",		PEVB_KBD_RIGHTBRACKET },
	{ 41, "enter", "enter",	PEVB_KBD_RETURN },
	{ 49, "<", "<",		PEVB_KBD_LEFT },
	{ 51, ">", ">",		PEVB_KBD_RIGHT },
	{ 0 },
};
static struct key kbd_sc3000_row4[] = {
	{  0, "shift", "shift",	PEVB_KBD_LSHIFT },
	{  7, "Z", "z",		PEVB_KBD_z },
	{ 10, "X", "x",		PEVB_KBD_x },
	{ 13, "C", "c",		PEVB_KBD_c },
	{ 16, "V", "v",		PEVB_KBD_v },
	{ 19, "B", "b",		PEVB_KBD_b },
	{ 22, "N", "n",		PEVB_KBD_n },
	{ 25, "M", "m",		PEVB_KBD_m },
	{ 28, ",", "<",		PEVB_KBD_COMMA },
	{ 31, ".", ">",		PEVB_KBD_PERIOD },
	{ 34, "/", "?",		PEVB_KBD_SLASH },
	{ 37, "pi", "pi",	PEVB_KBD_RO },
	{ 41, "shift", "shift",	PEVB_KBD_RSHIFT },
	{ 50, "v", "v",		PEVB_KBD_DOWN },
	{ 0 },
};
static struct key kbd_sc3000_row5[] = {
	{  7, "graph", "graph",	PEVB_KBD_SOUND },
	{ 14, "kana", "kana",	PEVB_KBD_CJK },
	{ 22, "space", "space",	PEVB_KBD_SPACE },
	{ 31, "clr", "home",	PEVB_KBD_HOME },
	{ 36, "del", "ins",	PEVB_KBD_BACKSPACE },
	{ 0 },
};

struct key *kbd_sc3000[KBD_ROWS+1] =
	{ kbd_sc3000_row1, kbd_sc3000_row2, kbd_sc3000_row3, kbd_sc3000_row4, kbd_sc3000_row5, NULL };


struct vkbd vkbd_pico   = { kbd_pico, { {3,0}, {-1,-1} } };
struct vkbd vkbd_sc3000 = { kbd_sc3000, { {1,0}, {2,0}, {3,0}, {3,12} } };

int vkbd_find_xpos(struct key *keys, int xpos)
{
	int i;

	for (i = 0; keys[i].lower && keys[i].xpos < xpos; i++)
		;

	if (i == 0)			return i;
	else if (keys[i].lower == NULL)	return i-1;
	else if (keys[i].xpos - xpos < xpos - keys[i-1].xpos) return i;
	else				return i-1;
}

void vkbd_draw(struct vkbd *vkbd)
{
	int i, j, k;
	struct key *key;
	int ypos = (vkbd->top ? 0 : g_screen_height - KBD_ROWS*me_sfont_h);

// HACK: smalltext_out is only available on menuscreen :-/
int w = g_menuscreen_w, h = g_menuscreen_h;
g_menuscreen_ptr = (u16 *)g_screen_ptr;
g_menuscreen_pp = g_screen_ppitch;
g_menuscreen_w = g_screen_width;
g_menuscreen_h = g_screen_height;
if (g_screen_width >= 320) {
    g_menuscreen_ptr = (u16 *)g_screen_ptr + (g_screen_width-320)/2;
    g_menuscreen_w = 320;
}

	for (i = 0; vkbd->kbd[i]; i++) {
		// darken background
		for (j = 0; j < me_sfont_h; j++) {
			u16 *p = (u16 *)g_menuscreen_ptr + (ypos+i*me_sfont_h+j)*g_menuscreen_pp;
			for (k = 0; k < g_menuscreen_w; k++) {
				u16 v = *p;
				*p++ = PXMASKH(v,1)>>1;
			}
		}
		// draw keyboard
		for (j = 0, key = &vkbd->kbd[i][j]; key->lower; j++, key++) {
			int is_meta = 0;
			int is_current = vkbd->x == j && vkbd->y == i;
			for (k = 0; k < VKBD_METAS && vkbd->meta[k][0] != -1 && !is_meta; k++)
				is_meta |= (vkbd->meta_state & (1<<k)) &&
					    i == vkbd->meta[k][0] && j == vkbd->meta[k][1];
			int color = is_current	? PXMAKE(0xff, 0xff, 0xff) :
				    is_meta	? PXMAKE(0xc8, 0xc8, 0xc8) :
						  PXMAKE(0xa0, 0xa0, 0xa0);
			char *text = (vkbd->shift ? key->upper : key->lower);
			int xpos = key->xpos*me_sfont_w * g_menuscreen_w/320;
			smalltext_out16(xpos, ypos+i*me_sfont_h, text, color);
		}
	}

g_menuscreen_w = w, g_menuscreen_h = h;
}

int vkbd_update(struct vkbd *vkbd, int input, int *actions)
{
	int pressed = (input ^ vkbd->prev_input) & input;
	struct key *key = &vkbd->kbd[vkbd->y][vkbd->x];
	int count = 0;
	int is_meta, i;

	// process input keys
	if (pressed & (1<<GBTN_UP)) {
		if (--vkbd->y < 0) while (vkbd->kbd[vkbd->y+1]) vkbd->y++;
		vkbd->x = vkbd_find_xpos(vkbd->kbd[vkbd->y], key->xpos);
	}
	if (pressed & (1<<GBTN_DOWN)) {
		if (vkbd->kbd[++vkbd->y] == NULL) vkbd->y = 0;
		vkbd->x = vkbd_find_xpos(vkbd->kbd[vkbd->y], key->xpos);
	}
	if (pressed & (1<<GBTN_LEFT)) {
		if (--vkbd->x < 0) while (vkbd->kbd[vkbd->y][vkbd->x+1].lower) vkbd->x++;
	}
	if (pressed & (1<<GBTN_RIGHT)) {
		if (vkbd->kbd[vkbd->y][++vkbd->x].lower == NULL) vkbd->x = 0;
	}
	if (pressed & (1<<GBTN_C)) {
		vkbd->top = !vkbd->top;
		plat_video_clear_buffers(); // if renderer isn't using full screen
	}
	if (pressed & (1<<GBTN_B)) {
		vkbd->shift = !vkbd->shift;
	}

	if (pressed & (1<<GBTN_A)) {
		for (i = 0; i < VKBD_METAS && vkbd->meta[i][0] != -1; i++)
			if (vkbd->y == vkbd->meta[i][0] && vkbd->x == vkbd->meta[i][1])
				vkbd->meta_state  = (vkbd->meta_state ^ (1<<i)) & (1<<i);
	}

	// compute pressed virtual keys: meta keys + current char key
	for (i = 0, is_meta = 0; i < VKBD_METAS && vkbd->meta[i][0] != -1; i++) {
		is_meta |= vkbd->y == vkbd->meta[i][0] && vkbd->x == vkbd->meta[i][1];

		if (vkbd->meta_state & (1<<i))
			actions[count++] = vkbd->kbd[vkbd->meta[i][0]][vkbd->meta[i][1]].key;
	}
	if (!is_meta && (input & (1<<GBTN_A)))
		actions[count++] = vkbd->kbd[vkbd->y][vkbd->x].key;

	vkbd->prev_input = input;

	return count;
}

struct vkbd *vkbd_init(int is_pico)
{
	struct vkbd *vkbd = is_pico ? &vkbd_pico : &vkbd_sc3000;
	int offs = (u8 *)vkbd->meta - (u8 *)vkbd + sizeof(vkbd->meta);
	memset((u8 *)vkbd + offs, 0, sizeof(*vkbd) - offs);
	vkbd->top = 1;
	return vkbd;
}
