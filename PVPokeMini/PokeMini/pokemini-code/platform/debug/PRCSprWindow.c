/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdarg.h>
#include <math.h>
#include <unistd.h>

#include "SDL.h"
#include "PokeMini.h"
#include "PokeMini_Debug.h"
#include "Hardware_Debug.h"
#include "CPUWindow.h"

#include "PRCSprWindow.h"
#include "PokeMini_ColorPal.h"
#include "MinxPRC.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

static int PRCSprWindow_InConfigs = 0;

GtkWindow *PRCSprWindow;
static int PRCSprWindow_minimized;
static GtkItemFactory *ItemFactory;
static GtkAccelGroup *AccelGroup;
static GtkBox *VBox1;
static GtkMenuBar *MenuBar;
static GtkLabel *LabelRunFull;
static SGtkXDrawingView PRCSprView;
static GtkFrame *MFrame;
static GtkBox *MBox;
static GtkLabel *SprLabels[4];

// Locals
static int FullRedraw = 1;
static int SelectedSprite = 0;

// Transparency
static const char *TransparencyColorMenu[16] = {
	"/View/Transparency/Pink",
	"/View/Transparency/Red",
	"/View/Transparency/Green",
	"/View/Transparency/Blue",
	"/View/Transparency/Yellow",
	"/View/Transparency/Orange",
	"/View/Transparency/Purple",
	"/View/Transparency/Bright Red",
	"/View/Transparency/Bright Green",
	"/View/Transparency/Bright Blue",
	"/View/Transparency/Bright Yellow",
	"/View/Transparency/Cyan",
	"/View/Transparency/Black",
	"/View/Transparency/Grey",
	"/View/Transparency/Silver",
	"/View/Transparency/White"
};
static const uint32_t TransparencyColor[16] = {
	0xFF00FF,	// Pink
	0xC00000,	// Red
	0x00C000,	// Green
	0x0000C0,	// Blue
	0xC0C000,	// Yellow
	0xFF8000,	// Orange
	0x800080,	// Purple
	0xFF0000,	// Bright Red
	0x00FF00,	// Bright Green
	0x0000FF,	// Bright Blue
	0xFFFF00,	// Bright Yellow
	0x00FFFF,	// Cyan
	0x000000,	// Black
	0x808080,	// Grey
	0xC0C0C0,	// Silver
	0xFFFFFF	// White
};

static inline void PRCSprView_DrawSprite8x8_Mono(SGtkXDrawingView *widg, uint32_t transparent,
	uint8_t cfg, int zoom, int X, int Y, int DrawT, int MaskT)
{
	uint32_t *scanptr;
	int x, y, xp, yp, xP;
	uint8_t sdata, smask;

	// Draw sprite
	for (y=0; y<8*zoom; y++) {
		yp = y / zoom;
		if (((Y+y) < 0) || ((Y+y) >= widg->height)) break;
		scanptr = &widg->imgptr[(Y+y) * widg->pitch];
		for (x=0; x<8*zoom; x++) {
			xp = x / zoom;
			if (((X+x) < 0) || ((X+x) >= widg->width)) break;

			xP = (cfg & 0x01) ? (7 - xp) : xp;
			smask = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (MaskT * 8) + xP);
			if (cfg & 0x02) smask = PRCInvertBit[smask];
			smask = smask & (1 << (yp & 7));

			// Write result
			if (!smask) {
				sdata = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (DrawT * 8) + xP);
				if (cfg & 0x02) sdata = PRCInvertBit[sdata];
				if (cfg & 0x04) sdata = ~sdata;
				sdata = sdata & (1 << (yp & 7));

				scanptr[X+x] = sdata ? 0x000000 : 0xFFFFFF;
			} else {
				scanptr[X+x] = transparent;
			}
		}
	}
}

static inline void PRCSprView_DrawSprite8x8_Color8(SGtkXDrawingView *widg, uint32_t transparent,
	uint8_t cfg, int zoom, int X, int Y, int DrawT, int MaskT)
{
	uint32_t *scanptr;
	uint8_t *ColorMap;
	int x, y, xp, yp, xP;
	uint8_t sdata, smask;

	// Pre calculate
	ColorMap = (uint8_t *)PRCColorMap + (MinxPRC.PRCSprBase >> 2) + (DrawT << 1) - PRCColorOffset;
	if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;

	// Draw sprite
	for (y=0; y<8*zoom; y++) {
		yp = y / zoom;
		if (((Y+y) < 0) || ((Y+y) >= widg->height)) break;
		scanptr = &widg->imgptr[(Y+y) * widg->pitch];
		for (x=0; x<8*zoom; x++) {
			xp = x / zoom;
			if (((X+x) < 0) || ((X+x) >= widg->width)) break;

			xP = (cfg & 0x01) ? (7 - xp) : xp;
			smask = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (MaskT * 8) + xP);
			if (cfg & 0x02) smask = PRCInvertBit[smask];
			smask = smask & (1 << (yp & 7));

			// Write result
			if (!smask) {
				sdata = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (DrawT * 8) + xP);
				if (cfg & 0x02) sdata = PRCInvertBit[sdata];
				if (cfg & 0x04) sdata = ~sdata;
				sdata = sdata & (1 << (yp & 7));
				sdata = sdata ? ColorMap[1] : *ColorMap;

				scanptr[X+x] = PokeMini_ColorPalBGR32[sdata];
			} else {
				scanptr[X+x] = transparent;
			}
		}
	}
}

static inline void PRCSprView_DrawSprite8x8_Color4(SGtkXDrawingView *widg, uint32_t transparent,
	uint8_t cfg, int zoom, int X, int Y, int DrawT, int MaskT)
{
	uint32_t *scanptr;
	uint8_t *ColorMap;
	int x, y, xp, yp, xP, subtile2;
	uint8_t sdata, smask;

	// Pre calculate
	ColorMap = (uint8_t *)PRCColorMap + MinxPRC.PRCSprBase + (DrawT << 3) - PRCColorOffset;
	if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;

	// Draw sprite
	for (y=0; y<8*zoom; y++) {
		yp = y / zoom;
		if (((Y+y) < 0) || ((Y+y) >= widg->height)) break;
		scanptr = &widg->imgptr[(Y+y) * widg->pitch];
		for (x=0; x<8*zoom; x++) {
			xp = x / zoom;
			if (((X+x) < 0) || ((X+x) >= widg->width)) break;
			subtile2 = (yp & 4) + ((xp & 4) >> 1);

			xP = (cfg & 0x01) ? (7 - xp) : xp;
			smask = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (MaskT * 8) + xP);
			if (cfg & 0x02) smask = PRCInvertBit[smask];
			smask = smask & (1 << (yp & 7));

			// Write result
			if (!smask) {
				sdata = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (DrawT * 8) + xP);
				if (cfg & 0x02) sdata = PRCInvertBit[sdata];
				if (cfg & 0x04) sdata = ~sdata;
				sdata = sdata & (1 << (yp & 7));
				sdata = sdata ? ColorMap[subtile2+1] : ColorMap[subtile2];

				scanptr[X+x] = PokeMini_ColorPalBGR32[sdata];
			} else {
				scanptr[X+x] = transparent;
			}
		}
	}
}

static void PRCSprView_DrawSpriteMono(SGtkXDrawingView *widg, uint32_t transparent, uint8_t cfg, int zoom, int X, int Y, int Tile)
{
	uint32_t *scanptr;
	int x, y, z = 8 * zoom;
	Tile <<= 3;

	// Draw 16x16 sprite
	PRCSprView_DrawSprite8x8_Mono(widg, transparent, cfg, zoom, X + (cfg & 1 ? z : 0), Y + (cfg & 2 ? z : 0), Tile+2, Tile);
	PRCSprView_DrawSprite8x8_Mono(widg, transparent, cfg, zoom, X + (cfg & 1 ? z : 0), Y + (cfg & 2 ? 0 : z), Tile+3, Tile+1);
	PRCSprView_DrawSprite8x8_Mono(widg, transparent, cfg, zoom, X + (cfg & 1 ? 0 : z), Y + (cfg & 2 ? z : 0), Tile+6, Tile+4);
	PRCSprView_DrawSprite8x8_Mono(widg, transparent, cfg, zoom, X + (cfg & 1 ? 0 : z), Y + (cfg & 2 ? 0 : z), Tile+7, Tile+5);

	// Mask if disabled
	if (!(cfg & 8)) {
		z <<= 1;
		for (y=Y; y<Y+z; y++) {
			if ((y < 0) || (y >= widg->height)) break;
			scanptr = &widg->imgptr[y * widg->pitch];
			for (x=X; x<X+z; x++) {
				if ((x < 0) || (x >= widg->width)) break;
				if ((x ^ y) & 1) scanptr[x] = 0x808080;
			}
		}
	}
}

static void PRCSprView_DrawSpriteColor8x8(SGtkXDrawingView *widg, uint32_t transparent, uint8_t cfg, int zoom, int X, int Y, int Tile)
{
	uint32_t *scanptr;
	int x, y, z = 8 * zoom;
	Tile <<= 3;

	// Draw 16x16 sprite
	PRCSprView_DrawSprite8x8_Color8(widg, transparent, cfg, zoom, X + (cfg & 1 ? z : 0), Y + (cfg & 2 ? z : 0), Tile+2, Tile);
	PRCSprView_DrawSprite8x8_Color8(widg, transparent, cfg, zoom, X + (cfg & 1 ? z : 0), Y + (cfg & 2 ? 0 : z), Tile+3, Tile+1);
	PRCSprView_DrawSprite8x8_Color8(widg, transparent, cfg, zoom, X + (cfg & 1 ? 0 : z), Y + (cfg & 2 ? z : 0), Tile+6, Tile+4);
	PRCSprView_DrawSprite8x8_Color8(widg, transparent, cfg, zoom, X + (cfg & 1 ? 0 : z), Y + (cfg & 2 ? 0 : z), Tile+7, Tile+5);

	// Mask if disabled
	if (!(cfg & 8)) {
		z <<= 1;
		for (y=Y; y<Y+z; y++) {
			if ((y < 0) || (y >= widg->height)) break;
			scanptr = &widg->imgptr[y * widg->pitch];
			for (x=X; x<X+z; x++) {
				if ((x < 0) || (x >= widg->width)) break;
				if ((x ^ y) & 1) scanptr[x] = 0x808080;
			}
		}
	}
}

static void PRCSprView_DrawSpriteColor4x4(SGtkXDrawingView *widg, uint32_t transparent, uint8_t cfg, int zoom, int X, int Y, int Tile)
{
	uint32_t *scanptr;
	int x, y, z = 8 * zoom;
	Tile <<= 3;

	// Draw 16x16 sprite
	PRCSprView_DrawSprite8x8_Color4(widg, transparent, cfg, zoom, X + (cfg & 1 ? z : 0), Y + (cfg & 2 ? z : 0), Tile+2, Tile);
	PRCSprView_DrawSprite8x8_Color4(widg, transparent, cfg, zoom, X + (cfg & 1 ? z : 0), Y + (cfg & 2 ? 0 : z), Tile+3, Tile+1);
	PRCSprView_DrawSprite8x8_Color4(widg, transparent, cfg, zoom, X + (cfg & 1 ? 0 : z), Y + (cfg & 2 ? z : 0), Tile+6, Tile+4);
	PRCSprView_DrawSprite8x8_Color4(widg, transparent, cfg, zoom, X + (cfg & 1 ? 0 : z), Y + (cfg & 2 ? 0 : z), Tile+7, Tile+5);

	// Mask if disabled
	if (!(cfg & 8)) {
		z <<= 1;
		for (y=Y; y<Y+z; y++) {
			if ((y < 0) || (y >= widg->height)) break;
			scanptr = &widg->imgptr[y * widg->pitch];
			for (x=X; x<X+z; x++) {
				if ((x < 0) || (x >= widg->width)) break;
				if ((x ^ y) & 1) scanptr[x] = 0x808080;
			}
		}
	}
}

// -------
// Viewers
// -------

static int PRCSprView_imgresize(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	uint32_t *scanimg;
	int x, y;

	for (y=0; y<height; y++) {
		scanimg = &widg->imgptr[y * pitch];
		for (x=0; x<width; x++) {
			scanimg[x] = (x ^ y) & 4 ? 0x808080 : 0x404040;
		}
	}
	return 1;
}

static int PRCSprView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	int i, x, y, w, h, sprx, spry, sprsize, ify;
	uint8_t dsprt, dsprx, dspry, dsprc;
	uint32_t color;
	char tmp[PMTMPV];
	int visible;

	if (FullRedraw) {
		PRCSprView_imgresize(widg, width, height, pitch);
		FullRedraw = 0;
	}

	sprsize = 16 * dclc_zoom_prcspr;
	for (y=0; y<4; y++) {
		for (x=0; x<6; x++) {
			i = y * 6 + x;
			if (emumode != EMUMODE_RUNFULL) {
				color = (x ^ y) & 1 ? 0xFFFFFF : 0xFFFFE4;
			} else {
				color = (x ^ y) & 1 ? 0x808080 : 0x808064;
			}
			if (dclc_minimalist_sprview) {
				w = 32 + sprsize;
				h = 28 + sprsize;
			} else {
				w = 64 + sprsize;
				h = 100 + sprsize;
			}
			if (w < 72) w = 72;
			sprx = x * w + (w >> 1) - (sprsize >> 1);
			spry = y * h + 20;
			ify = spry + sprsize + 8;
			dsprx = MinxPRC_OnRead(0, 0x1300 + i*4) & 0x7F;
			dspry = MinxPRC_OnRead(0, 0x1300 + i*4+1) & 0x7F;
			dsprt = MinxPRC_OnRead(0, 0x1300 + i*4+2);
			dsprc = MinxPRC_OnRead(0, 0x1300 + i*4+3);
			visible = (dsprc & 8) && (dsprx > 0) && (dsprx < 112) && (dspry > 0) && (dspry < 80);

			// Draw stuffz
			sgtkx_drawing_view_drawfrect(widg, x*w, y*h, w, h, color);
			if (w >= 92) {
				sgtkx_drawing_view_drawtext(widg, x*w+6, y*h+4, 0x4C3000, "Sprite \e340#%i", i);
			} else {
				sgtkx_drawing_view_drawtext(widg, x*w+6, y*h+4, 0x4C3000, "Spr. \e340#%i", i);
			}
			if (emumode != EMUMODE_RUNFULL) {
				if (dclc_show_hspr || visible) {
					if (PRCColorMap) {
						if (PokeMini_ColorFormat == 1) {
							// Color 4x4 Attributes
							PRCSprView_DrawSpriteColor4x4(widg, dclc_trans_prcspr, dsprc, dclc_zoom_prcspr, sprx, spry, dsprt);
						} else {
							// Color 8x8 Attributes
							PRCSprView_DrawSpriteColor8x8(widg, dclc_trans_prcspr, dsprc, dclc_zoom_prcspr, sprx, spry, dsprt);
						}
					} else {
						// Mono
						PRCSprView_DrawSpriteMono(widg, dclc_trans_prcspr, dsprc, dclc_zoom_prcspr, sprx, spry, dsprt);
					}
					// Sprite frame
					if (visible) {
						sgtkx_drawing_view_drawsrect(widg, sprx-1, spry-1, sprsize+2, sprsize+2, 0xFF0000);
						sgtkx_drawing_view_drawsrect(widg, sprx-2, spry-2, sprsize+4, sprsize+4, 0xFFFF00);
						sgtkx_drawing_view_drawsrect(widg, sprx-3, spry-3, sprsize+6, sprsize+6, 0xFF8080);
					} else {
						sgtkx_drawing_view_drawsrect(widg, sprx-1, spry-1, sprsize+2, sprsize+2, 0xA0A0A0);
						sgtkx_drawing_view_drawsrect(widg, sprx-2, spry-2, sprsize+4, sprsize+4, 0xD0D0D0);
						sgtkx_drawing_view_drawsrect(widg, sprx-3, spry-3, sprsize+6, sprsize+6, 0xB0B0B0);
					}
				}
				if (!dclc_minimalist_sprview) {
					// Sprite information
					if (dclc_zoom_prcspr >= 2) {
						sgtkx_drawing_view_drawtext(widg, x*w+6, ify+ 0, 0x605020, "C.: $%02X,%i", dsprc, dsprc);
						sgtkx_drawing_view_drawtext(widg, x*w+6, ify+12, 0x605040, "ID: $%02X,%i", dsprt, dsprt);
						if (dsprx < 16) sgtkx_drawing_view_drawtext(widg, x*w+6, ify+24, 0x605060, " X:-$%02X,-%i", 16 - dsprx, 16 - dsprx);
						else sgtkx_drawing_view_drawtext(widg, x*w+6, ify+24, 0x605060, " X: $%02X,%i", dsprx - 16, dsprx - 16);
						if (dspry < 16) sgtkx_drawing_view_drawtext(widg, x*w+6, ify+36, 0x605070, " Y:-$%02X,-%i", 16 - dspry, 16 - dspry);
						else sgtkx_drawing_view_drawtext(widg, x*w+6, ify+36, 0x605070, " Y: $%02X,%i", dspry - 16, dspry - 16);
					} else {
						sgtkx_drawing_view_drawtext(widg, x*w+6, ify+ 0, 0x605020, "C.: $%02X", dsprc);
						sgtkx_drawing_view_drawtext(widg, x*w+6, ify+12, 0x605040, "ID: $%02X", dsprt);
						if (dsprx < 16) sgtkx_drawing_view_drawtext(widg, x*w+6, ify+24, 0x605060, " X:-$%02X", 16 - dsprx);
						else sgtkx_drawing_view_drawtext(widg, x*w+6, ify+24, 0x605060, " X: $%02X", dsprx - 16);
						if (dspry < 16) sgtkx_drawing_view_drawtext(widg, x*w+6, ify+36, 0x605070, " Y:-$%02X", 16 - dspry);
						else sgtkx_drawing_view_drawtext(widg, x*w+6, ify+36, 0x605070, " Y: $%02X", dspry - 16);
					}
					// Sprite control
					if (dclc_zoom_prcspr >= 4) {
						sgtkx_drawing_view_drawtext(widg, x*w+6, ify+48, 0x605080, "\e%sEnabled  \e%sInvert",
							dsprc & 8 ? "240" : "897", dsprc & 4 ? "240" : "897");
						sgtkx_drawing_view_drawtext(widg, x*w+6, ify+60, 0x605090, "\e%sVFlip    \e%sHFlip",
							dsprc & 2 ? "240" : "897", dsprc & 1 ? "240" : "897");
					} else {
						sgtkx_drawing_view_drawtext(widg, x*w+6, ify+48, 0x605080, "\e%sEna. \e%sInv.",
							dsprc & 8 ? "240" : "897", dsprc & 4 ? "240" : "897");
						sgtkx_drawing_view_drawtext(widg, x*w+6, ify+60, 0x605090, "\e%sVFlp \e%sHFlp",
							dsprc & 2 ? "240" : "897", dsprc & 1 ? "240" : "897");
					}
				} else {
					if (i == SelectedSprite) {
						sgtkx_drawing_view_drawsrect(widg, x*w, y*h, w, h, 0xFF0000);
						sgtkx_drawing_view_drawsrect(widg, x*w+1, y*h+1, w-2, h-2, 0xFF8000);
					}
				}
			}
		}
	}

	// Minimalist view
	if (dclc_minimalist_sprview) {
		i = SelectedSprite;
		dsprx = MinxPRC_OnRead(0, 0x1300 + i*4) & 0x7F;
		dspry = MinxPRC_OnRead(0, 0x1300 + i*4+1) & 0x7F;
		dsprt = MinxPRC_OnRead(0, 0x1300 + i*4+2);
		dsprc = MinxPRC_OnRead(0, 0x1300 + i*4+3);
		sprintf(tmp, "Control: $%02X, %i  -  %s %s %s %s", dsprc, dsprc,
			dsprc & 8 ? "(Enabled)" : "(Disabled)",
			dsprc & 4 ? "(Inverted)" : "",
			dsprc & 2 ? "(Hozizontal Flip)" : "",
			dsprc & 1 ? "(Vertical Flip)" : ""
		);
		gtk_label_set_text(SprLabels[0], tmp);
		sprintf(tmp, "Tile ID: $%02X, %i", dsprt, dsprt);
		gtk_label_set_text(SprLabels[1], tmp);
		if (dsprx < 16) sprintf(tmp, "X Position: -$%02X, -%i", 16 - dsprx, 16 - dsprx);
		else sprintf(tmp, "X Position: $%02X, %i", dsprx - 16, dsprx - 16);
		gtk_label_set_text(SprLabels[2], tmp);
		if (dspry < 16) sprintf(tmp, "Y Position: -$%02X, -%i", 16 - dspry, 16 - dspry);
		else sprintf(tmp, "Y Position: $%02X, %i", dspry - 16, dspry - 16);
		gtk_label_set_text(SprLabels[3], tmp);
	}

	return 1;
}

static int PRCSprView_buttonpress(SGtkXDrawingView *widg, int button, int press, int _c)
{
	int x, y, w, h, sprsize;
	char tmp[64];

	// Must be minimalist
	if (!dclc_minimalist_sprview) return 0;	

	// Calculate
	sprsize = 16 * dclc_zoom_prcspr;
	w = 32 + sprsize;
	h = 28 + sprsize;
	if (w < 72) w = 72;
	x = widg->mousex / w;
	y = widg->mousey / h;
	if ((x < 0) || (x >= 6) || (y < 0) || (y >= 4)) return 0;

	// Set as selected
	SelectedSprite = y * 6 + x;
	sprintf(tmp, " Sprite #%i ", SelectedSprite);
	gtk_frame_set_label(MFrame, tmp);
	return 1;
}

// --------------
// Menu callbacks
// --------------

static void PRCSprW_ShowHSpr(GtkWidget *widget, gpointer data)
{
	if (PRCSprWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Show hidden sprites");
	dclc_show_hspr = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	PRCSprWindow_Refresh(1);
}

static void PRCSprW_Minimalist(GtkWidget *widget, gpointer data)
{
	if (PRCSprWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Minimalist view");
	dclc_minimalist_sprview = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (dclc_minimalist_sprview) {
		gtk_widget_show(GTK_WIDGET(MFrame));
	} else {
		gtk_widget_hide(GTK_WIDGET(MFrame));
	}
	FullRedraw = 1;
	PRCSprWindow_Refresh(1);
}

static void PRCSprW_Zoom(GtkWidget *widget, gpointer data)
{
	if (PRCSprWindow_InConfigs) return;
	dclc_zoom_prcspr = (int)data;
	FullRedraw = 1;
	PRCSprWindow_Refresh(1);
}

static void PRCSprW_Transparency(GtkWidget *widget, gpointer data)
{
	int number, index = (int)data;
	static int lasttransindex = -2;

	if (lasttransindex == index) return;
	lasttransindex = index;
	if (PRCSprWindow_InConfigs) return;

	if (index >= 0) {
		dclc_trans_prcspr = TransparencyColor[index];
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(PRCSprWindow, "Custom tranparent color", "Transparency value:", &number, dclc_trans_prcspr, 6, 1, 0x000000, 0xFFFFFF)) {
			dclc_trans_prcspr = number & 0xFFFFFF;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
	PRCSprWindow_Refresh(1);
}

static void PRCSprW_RefreshNow(GtkWidget *widget, gpointer data)
{
	FullRedraw = 1;
	refresh_debug(1);
}

static void PRCSprW_Refresh(GtkWidget *widget, gpointer data)
{
	int val, index = (int)data;
	static int lastrefrindex = -2;

	if (lastrefrindex == index) return;
	lastrefrindex = index;
	if (PRCSprWindow_InConfigs) return;

	if (index >= 0) {
		dclc_prcsprwin_refresh = index;
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(PRCSprWindow, "Custom refresh rate", "Frames skip per refresh:", &val, dclc_prcsprwin_refresh, 4, 0, 0, 1000)) {
			dclc_prcsprwin_refresh = val;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

static gint PRCSprWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(PRCSprWindow));
	return TRUE;
}

static gboolean PRCSprWindow_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{
	if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) PRCSprWindow_minimized = event->new_window_state & GDK_WINDOW_STATE_ICONIFIED;
	return TRUE;
}

static GtkItemFactoryEntry PRCSprWindow_MenuItems[] = {
	{ "/_View",                              NULL,           NULL,                     0, "<Branch>" },
	{ "/View/Show hidden sprites",           NULL,           PRCSprW_ShowHSpr,         0, "<CheckItem>" },
	{ "/View/Minimalist view",               NULL,           PRCSprW_Minimalist,       0, "<CheckItem>" },
	{ "/View/Zoom",                          NULL,           NULL,                     0, "<Branch>" },
	{ "/View/Zoom/100%",                     NULL,           PRCSprW_Zoom,             1, "<RadioItem>" },
	{ "/View/Zoom/200%",                     NULL,           PRCSprW_Zoom,             2, "/View/Zoom/100%" },
	{ "/View/Zoom/300%",                     NULL,           PRCSprW_Zoom,             3, "/View/Zoom/100%" },
	{ "/View/Zoom/400%",                     NULL,           PRCSprW_Zoom,             4, "/View/Zoom/100%" },
	{ "/View/Zoom/500%",                     NULL,           PRCSprW_Zoom,             5, "/View/Zoom/100%" },
	{ "/View/Zoom/600%",                     NULL,           PRCSprW_Zoom,             6, "/View/Zoom/100%" },
	{ "/View/Zoom/700%",                     NULL,           PRCSprW_Zoom,             7, "/View/Zoom/100%" },
	{ "/View/Zoom/800%",                     NULL,           PRCSprW_Zoom,             8, "/View/Zoom/100%" },
	{ "/View/Transparency",                  NULL,           NULL,                     0, "<Branch>" },
	{ "/View/Transparency/Pink",             NULL,           PRCSprW_Transparency,     0, "<RadioItem>" },
	{ "/View/Transparency/Red",              NULL,           PRCSprW_Transparency,     1, "/View/Transparency/Pink" },
	{ "/View/Transparency/Green",            NULL,           PRCSprW_Transparency,     2, "/View/Transparency/Pink" },
	{ "/View/Transparency/Blue",             NULL,           PRCSprW_Transparency,     3, "/View/Transparency/Pink" },
	{ "/View/Transparency/Yellow",           NULL,           PRCSprW_Transparency,     4, "/View/Transparency/Pink" },
	{ "/View/Transparency/Orange",           NULL,           PRCSprW_Transparency,     5, "/View/Transparency/Pink" },
	{ "/View/Transparency/Purple",           NULL,           PRCSprW_Transparency,     6, "/View/Transparency/Pink" },
	{ "/View/Transparency/Bright Red",       NULL,           PRCSprW_Transparency,     7, "/View/Transparency/Pink" },
	{ "/View/Transparency/Bright Green",     NULL,           PRCSprW_Transparency,     8, "/View/Transparency/Pink" },
	{ "/View/Transparency/Bright Blue",      NULL,           PRCSprW_Transparency,     9, "/View/Transparency/Pink" },
	{ "/View/Transparency/Bright Yellow",    NULL,           PRCSprW_Transparency,    10, "/View/Transparency/Pink" },
	{ "/View/Transparency/Cyan",             NULL,           PRCSprW_Transparency,    11, "/View/Transparency/Pink" },
	{ "/View/Transparency/Black",            NULL,           PRCSprW_Transparency,    12, "/View/Transparency/Pink" },
	{ "/View/Transparency/Grey",             NULL,           PRCSprW_Transparency,    13, "/View/Transparency/Pink" },
	{ "/View/Transparency/Silver",           NULL,           PRCSprW_Transparency,    14, "/View/Transparency/Pink" },
	{ "/View/Transparency/White",            NULL,           PRCSprW_Transparency,    15, "/View/Transparency/Pink" },
	{ "/View/Transparency/Custom",           NULL,           PRCSprW_Transparency,    -1, "/View/Transparency/Pink" },

	{ "/_Debugger",                          NULL,           NULL,                     0, "<Branch>" },
	{ "/Debugger/Run full speed",            "F5",           Menu_Debug_RunFull,       0, "<Item>" },
	{ "/Debugger/Run debug frames (Sound)",  "<SHIFT>F5",    Menu_Debug_RunDFrameSnd,  0, "<Item>" },
	{ "/Debugger/Run debug frames",          "<CTRL>F5",     Menu_Debug_RunDFrame,     0, "<Item>" },
	{ "/Debugger/Run debug steps",           "<CTRL>F3",     Menu_Debug_RunDStep,      0, "<Item>" },
	{ "/Debugger/Single frame",              "F4",           Menu_Debug_SingleFrame,   0, "<Item>" },
	{ "/Debugger/Single step",               "F3",           Menu_Debug_SingleStep,    0, "<Item>" },
	{ "/Debugger/Step skip",                 "<SHIFT>F3",    Menu_Debug_StepSkip,      0, "<Item>" },
	{ "/Debugger/Stop",                      "F2",           Menu_Debug_Stop,          0, "<Item>" },

	{ "/_Refresh",                           NULL,           NULL,                     0, "<Branch>" },
	{ "/Refresh/Now!",                       NULL,           PRCSprW_RefreshNow,       0, "<Item>" },
	{ "/Refresh/sep1",                       NULL,           NULL,                     0, "<Separator>" },
	{ "/Refresh/100% 72fps",                 NULL,           PRCSprW_Refresh,          0, "<RadioItem>" },
	{ "/Refresh/ 50% 36fps",                 NULL,           PRCSprW_Refresh,          1, "/Refresh/100% 72fps" },
	{ "/Refresh/ 33% 24fps",                 NULL,           PRCSprW_Refresh,          2, "/Refresh/100% 72fps" },
	{ "/Refresh/ 25% 18fps",                 NULL,           PRCSprW_Refresh,          3, "/Refresh/100% 72fps" },
	{ "/Refresh/ 17% 12fps",                 NULL,           PRCSprW_Refresh,          5, "/Refresh/100% 72fps" },
	{ "/Refresh/ 12%  9fps",                 NULL,           PRCSprW_Refresh,          7, "/Refresh/100% 72fps" },
	{ "/Refresh/  8%  6fps",                 NULL,           PRCSprW_Refresh,         11, "/Refresh/100% 72fps" },
	{ "/Refresh/  3%  2fps",                 NULL,           PRCSprW_Refresh,         35, "/Refresh/100% 72fps" },
	{ "/Refresh/  1%  1fps",                 NULL,           PRCSprW_Refresh,         71, "/Refresh/100% 72fps" },
	{ "/Refresh/Custom...",                  NULL,           PRCSprW_Refresh,         -1, "/Refresh/100% 72fps" },
};
static gint PRCSprWindow_MenuItemsNum = sizeof(PRCSprWindow_MenuItems) / sizeof(*PRCSprWindow_MenuItems);

// ------------------
// PRC Sprites Window
// ------------------

int PRCSprWindow_Create(void)
{
	int i;

	// Window
	PRCSprWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(PRCSprWindow), "PRC Sprites View");
	gtk_widget_set_size_request(GTK_WIDGET(PRCSprWindow), 200, 100);
	gtk_window_set_default_size(PRCSprWindow, 420, 200);
	g_signal_connect(PRCSprWindow, "delete_event", G_CALLBACK(PRCSprWindow_delete_event), NULL);
	g_signal_connect(PRCSprWindow, "window-state-event", G_CALLBACK(PRCSprWindow_state_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(PRCSprWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Menu bar
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, PRCSprWindow_MenuItemsNum, PRCSprWindow_MenuItems, NULL);
	gtk_window_add_accel_group(PRCSprWindow, AccelGroup);
	MenuBar = GTK_MENU_BAR(gtk_item_factory_get_widget(ItemFactory, "<main>"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MenuBar), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MenuBar));

	// Label that warn when running full speed
	LabelRunFull = GTK_LABEL(gtk_label_new("To view content you must stop emulation or run in debug frames/steps."));
	gtk_box_pack_start(VBox1, GTK_WIDGET(LabelRunFull), FALSE, TRUE, 0);

	// PRC Map View
	PRCSprView.on_imgresize = SGtkXDVCB(PRCSprView_imgresize);
	PRCSprView.on_exposure = SGtkXDVCB(PRCSprView_exposure);
	PRCSprView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	PRCSprView.on_buttonpress = SGtkXDVCB(PRCSprView_buttonpress);
	sgtkx_drawing_view_new(&PRCSprView, 0);
	gtk_widget_set_size_request(GTK_WIDGET(PRCSprView.box), 64, 64);
	gtk_box_pack_start(VBox1, GTK_WIDGET(PRCSprView.box), TRUE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(PRCSprView.box));

	// Minimalist view
	MFrame = GTK_FRAME(gtk_frame_new(" Sprite #0 "));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MFrame), FALSE, TRUE, 2);
	gtk_widget_show(GTK_WIDGET(MFrame));
	MBox = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(MFrame), GTK_WIDGET(MBox));
	gtk_widget_show(GTK_WIDGET(MBox));
	for (i=0; i<4; i++) {
		SprLabels[i] = GTK_LABEL(gtk_label_new("???"));
		gtk_misc_set_alignment(GTK_MISC(SprLabels[i]), 0.0, 0.5);
		gtk_label_set_justify(SprLabels[i], GTK_JUSTIFY_LEFT);
		gtk_box_pack_start(MBox, GTK_WIDGET(SprLabels[i]), TRUE, TRUE, 2);
		gtk_widget_show(GTK_WIDGET(SprLabels[i]));
	}

	return 1;
}

void PRCSprWindow_Destroy(void)
{
	int x, y, width, height;
	if (gtk_widget_get_realized(GTK_WIDGET(PRCSprWindow))) {
		gtk_widget_show(GTK_WIDGET(PRCSprWindow));
		gtk_window_deiconify(PRCSprWindow);
		gtk_window_get_position(PRCSprWindow, &x, &y);
		gtk_window_get_size(PRCSprWindow, &width, &height);
		dclc_prcsprwin_winx = x;
		dclc_prcsprwin_winy = y;
		dclc_prcsprwin_winw = width;
		dclc_prcsprwin_winh = height;
	}
}

void PRCSprWindow_Activate(void)
{
	gtk_widget_realize(GTK_WIDGET(PRCSprWindow));
	if ((dclc_prcsprwin_winx > -15) && (dclc_prcsprwin_winy > -16)) {
		gtk_window_move(PRCSprWindow, dclc_prcsprwin_winx, dclc_prcsprwin_winy);
	}
	if ((dclc_prcsprwin_winw > 0) && (dclc_prcsprwin_winh > 0)) {
		gtk_window_resize(PRCSprWindow, dclc_prcsprwin_winw, dclc_prcsprwin_winh);
	}
	gtk_widget_show(GTK_WIDGET(PRCSprWindow));
	gtk_window_present(PRCSprWindow);
}

void PRCSprWindow_UpdateConfigs(void)
{
	GtkWidget *widg;
	int i;

	PRCSprWindow_InConfigs = 1;

	widg = gtk_item_factory_get_item(ItemFactory, "/View/Show hidden sprites");
	if (dclc_show_hspr) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Minimalist view");
	if (dclc_minimalist_sprview) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/100%");
	if (dclc_zoom_prcspr == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/200%");
	if (dclc_zoom_prcspr == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/300%");
	if (dclc_zoom_prcspr == 3) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/400%");
	if (dclc_zoom_prcspr == 4) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/500%");
	if (dclc_zoom_prcspr == 5) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/600%");
	if (dclc_zoom_prcspr == 6) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/700%");
	if (dclc_zoom_prcspr == 7) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/800%");
	if (dclc_zoom_prcspr == 8) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/View/Transparency/Custom");
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	for (i=0; i<16; i++) {
		widg = gtk_item_factory_get_item(ItemFactory, TransparencyColorMenu[i]);
		if (dclc_trans_prcspr == TransparencyColor[i]) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	}

	if (dclc_minimalist_sprview) {
		gtk_widget_show(GTK_WIDGET(MFrame));
	} else {
		gtk_widget_hide(GTK_WIDGET(MFrame));
	}

	switch (dclc_prcsprwin_refresh) {
		case 0: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/100% 72fps")), 1);
			break;
		case 1: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 50% 36fps")), 1);
			break;
		case 2: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 33% 24fps")), 1);
			break;
		case 3: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 25% 18fps")), 1);
			break;
		case 5: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 17% 12fps")), 1);
			break;
		case 7: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 12%  9fps")), 1);
			break;
		case 11: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/  8%  6fps")), 1);
			break;
		case 19: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/  6%  3fps")), 1);
			break;
		default: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/Custom...")), 1);
			break;
	}

	PRCSprWindow_InConfigs = 0;
}

void PRCSprWindow_Sensitive(int enabled)
{
	if (enabled) {
		gtk_widget_hide(GTK_WIDGET(LabelRunFull));
		gtk_widget_show(GTK_WIDGET(PRCSprView.box));
		if (dclc_minimalist_sprview) {
			gtk_widget_show(GTK_WIDGET(MFrame));
		}
	} else {
		gtk_widget_show(GTK_WIDGET(LabelRunFull));
		gtk_widget_hide(GTK_WIDGET(PRCSprView.box));
		gtk_widget_hide(GTK_WIDGET(MFrame));
	}
}

void PRCSprWindow_Refresh(int now)
{
	static int refreshcnt = 0;
	if ((refreshcnt <= 0) || (now)) {
		refreshcnt = dclc_prcsprwin_refresh;
		if (!now) {
			if (!gtk_widget_get_visible(GTK_WIDGET(PRCSprWindow)) || PRCSprWindow_minimized) return;
		}
		sgtkx_drawing_view_refresh(&PRCSprView);
	} else refreshcnt--;
}
