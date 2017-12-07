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

#include "PRCTilesWindow.h"
#include "PokeMini_ColorPal.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

static int PRCTilesWindow_InConfigs = 0;

GtkWindow *PRCTilesWindow;
static int PRCTilesWindow_minimized;
static GtkItemFactory *ItemFactory;
static GtkAccelGroup *AccelGroup;
static GtkBox *VBox1;
static GtkMenuBar *MenuBar;
static GtkLabel *LabelRunFull;
static GtkLabel *LabelInfo;
static SGtkXDrawingView PRCTilesView;

// Locals
static int Follow = 0;
static int SpriteMode = 0;
static int ShowGrid = 1;
static int Negative = 0;

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

static void PRCTilesRender_decodespriteidx(int spriteidx, int x, int y, int *dataidx, int *maskidx)
{
	switch ((y & 8) + ((x & 8) >> 1)) {
		case 0: // Top-Left
			if (dataidx) *dataidx = (spriteidx << 3) + 2;
			if (maskidx) *maskidx = (spriteidx << 3) + 0;
			break;
		case 4: // Top-Right
			if (dataidx) *dataidx = (spriteidx << 3) + 6;
			if (maskidx) *maskidx = (spriteidx << 3) + 4;
			break;
		case 8: // Bottom-Left
			if (dataidx) *dataidx = (spriteidx << 3) + 3;
			if (maskidx) *maskidx = (spriteidx << 3) + 1;
			break;
		case 12: // Bottom-Right
			if (dataidx) *dataidx = (spriteidx << 3) + 7;
			if (maskidx) *maskidx = (spriteidx << 3) + 5;
			break;
	}
}

// PRC Tiles render (Mono)
static void PRCTilesRenderMono(SGtkXDrawingView *widg,
	int spritemode, int zoom, uint32_t offset,
	int negative, uint32_t transparency)
{
	uint32_t *scanptr;
	int x, y;
	int xp, yp, pitchp;
	int tileidx, tileidxD = 0, tileidxM = 0, tiledataaddr, tilemaskaddr;

	uint8_t ddata = 0, mdata = 0;

	if (spritemode) {
		// Draw sprites
		offset = offset & ~7;
		pitchp = widg->pitch / zoom;
		for (y=0; y<widg->height; y++) {
			yp = y / zoom;
			scanptr = &widg->imgptr[y * widg->pitch];
			for (x=0; x<widg->width; x++) {
				xp = x / zoom;

				// Calculate
				tileidx = (yp >> 4) * (pitchp >> 4) + (xp >> 4);
				PRCTilesRender_decodespriteidx(tileidx, xp, yp, &tileidxD, &tileidxM);
				tiledataaddr = ((offset << 3) + (tileidxD << 3));
				tilemaskaddr = ((offset << 3) + (tileidxM << 3));

				// Draw sprite
				if (tiledataaddr < PM_ROM_Size) {
					// Decode and draw sprite
					mdata = MinxPRC_OnRead(0, tilemaskaddr + (xp & 7)) & (1 << (yp & 7));
					if (!mdata) {
						ddata = MinxPRC_OnRead(0, tiledataaddr + (xp & 7)) & (1 << (yp & 7));
						if (negative) ddata = !ddata;
						scanptr[x] = ddata ? 0x000000 : 0xFFFFFF;
					} else {
						scanptr[x] = transparency;
					}
				} else {
					// Outside ROM range
					scanptr[x] = (yp ^ xp) & 1 ? 0x808080 : 0x404040;
				}
			}
		}
	} else {
		// Draw tiles
		pitchp = widg->pitch / zoom;
		for (y=0; y<widg->height; y++) {
			yp = y / zoom;
			scanptr = &widg->imgptr[y * widg->pitch];
			for (x=0; x<widg->width; x++) {
				xp = x / zoom;

				// Calculate
				tileidx = (yp >> 3) * (pitchp >> 3) + (xp >> 3);
				tiledataaddr = ((offset << 3) + (tileidx << 3));

				// Draw tile
				if (tiledataaddr < PM_ROM_Size) {
					// Decode and draw tile
					ddata = MinxPRC_OnRead(0, tiledataaddr + (xp & 7)) & (1 << (yp & 7));
					if (negative) ddata = !ddata;
					scanptr[x] = ddata ? 0x000000 : 0xFFFFFF;
				} else {
					// Outside ROM range
					scanptr[x] = (yp ^ xp) & 1 ? 0x808080 : 0x404040;
				}
			}
		}
	}
}

// PRC Tiles render (Color 8x8)
static void PRCTilesRenderColor8x8(SGtkXDrawingView *widg,
	int spritemode, int zoom, uint32_t offset,
	int negative, uint32_t transparency)
{
	uint32_t *scanptr, mapoff;
	int x, y;
	int xp, yp, pitchp;
	int tileidx, tileidxD = 0, tileidxM = 0, tiledataaddr, tilemaskaddr;

	negative = negative ? 1 : 0;
	uint8_t *ColorMap = (uint8_t *)PRCStaticColorMap;
	uint8_t ddata = 0, mdata = 0, odata;

	if (spritemode) {
		// Draw sprites
		offset = offset & ~7;
		pitchp = widg->pitch / zoom;
		for (y=0; y<widg->height; y++) {
			yp = y / zoom;
			scanptr = &widg->imgptr[y * widg->pitch];
			for (x=0; x<widg->width; x++) {
				xp = x / zoom;

				// Calculate
				tileidx = (yp >> 4) * (pitchp >> 4) + (xp >> 4);
				PRCTilesRender_decodespriteidx(tileidx, xp, yp, &tileidxD, &tileidxM);
				tiledataaddr = ((offset << 3) + (tileidxD << 3));
				tilemaskaddr = ((offset << 3) + (tileidxM << 3));
				mapoff = (offset << 1) + (tileidxD << 1);

				// Draw sprite
				if (tiledataaddr < PM_ROM_Size) {
					// Get map offset
					ColorMap = (uint8_t *)PRCColorMap + mapoff - PRCColorOffset;
					if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;

					// Decode and draw sprite
					mdata = MinxPRC_OnRead(0, tilemaskaddr + (xp & 7)) & (1 << (yp & 7));
					if (!mdata) {
						ddata = MinxPRC_OnRead(0, tiledataaddr + (xp & 7)) & (1 << (yp & 7));
						odata = ddata ? ColorMap[1 ^ negative] : ColorMap[0 ^ negative];
						scanptr[x] = PokeMini_ColorPalBGR32[odata];
					} else {
						scanptr[x] = transparency;
					}
				} else {
					// Outside ROM range
					scanptr[x] = (yp ^ xp) & 1 ? 0x808080 : 0x404040;
				}
			}
		}
	} else {
		// Draw tiles
		pitchp = widg->pitch / zoom;
		for (y=0; y<widg->height; y++) {
			yp = y / zoom;
			scanptr = &widg->imgptr[y * widg->pitch];
			for (x=0; x<widg->width; x++) {
				xp = x / zoom;

				// Calculate
				tileidx = (yp >> 3) * (pitchp >> 3) + (xp >> 3);
				tiledataaddr = ((offset << 3) + (tileidx << 3));
				mapoff = (offset << 1) + (tileidx << 1);

				// Draw tile
				if (tiledataaddr < PM_ROM_Size) {
					// Get map offset
					ColorMap = (uint8_t *)PRCColorMap + mapoff - PRCColorOffset;
					if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;

					// Decode and draw tile
					ddata = MinxPRC_OnRead(0, tiledataaddr + (xp & 7)) & (1 << (yp & 7));
					odata = ddata ? ColorMap[1 ^ negative] : ColorMap[0 ^ negative];
					scanptr[x] = PokeMini_ColorPalBGR32[odata];
				} else {
					// Outside ROM range
					scanptr[x] = (yp ^ xp) & 1 ? 0x808080 : 0x404040;
				}
			}
		}
	}
}

// PRC Tiles render (Color 4x4)
static void PRCTilesRenderColor4x4(SGtkXDrawingView *widg,
	int spritemode, int zoom, uint32_t offset,
	int negative, uint32_t transparency)
{
	uint32_t *scanptr, mapoff;
	int x, y;
	int xp, yp, pitchp, subtile2;
	int tileidx, tileidxD = 0, tileidxM = 0, tiledataaddr, tilemaskaddr;

	negative = negative ? 1 : 0;
	uint8_t *ColorMap = (uint8_t *)PRCStaticColorMap;
	uint8_t ddata = 0, mdata = 0, odata;

	if (spritemode) {
		// Draw sprites
		offset = offset & ~7;
		pitchp = widg->pitch / zoom;
		for (y=0; y<widg->height; y++) {
			yp = y / zoom;
			scanptr = &widg->imgptr[y * widg->pitch];
			for (x=0; x<widg->width; x++) {
				xp = x / zoom;

				// Calculate
				tileidx = (yp >> 4) * (pitchp >> 4) + (xp >> 4);
				PRCTilesRender_decodespriteidx(tileidx, xp, yp, &tileidxD, &tileidxM);
				tiledataaddr = (offset << 3) + (tileidxD << 3);
				tilemaskaddr = (offset << 3) + (tileidxM << 3);
				mapoff = (offset << 3) + (tileidxD << 3);
				subtile2 = (yp & 4) + ((xp & 4) >> 1);

				// Draw sprite
				if (tiledataaddr < PM_ROM_Size) {
					// Get map offset
					ColorMap = (uint8_t *)PRCColorMap + mapoff - PRCColorOffset;
					if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;

					// Decode and draw sprite
					mdata = MinxPRC_OnRead(0, tilemaskaddr + (xp & 7)) & (1 << (yp & 7));
					if (!mdata) {
						ddata = MinxPRC_OnRead(0, tiledataaddr + (xp & 7)) & (1 << (yp & 7));
						odata = ddata ? ColorMap[(subtile2 + 1) ^ negative] : ColorMap[subtile2 ^ negative];
						scanptr[x] = PokeMini_ColorPalBGR32[odata];
					} else {
						scanptr[x] = transparency;
					}
				} else {
					// Outside ROM range
					scanptr[x] = (yp ^ xp) & 1 ? 0x808080 : 0x404040;
				}
			}
		}
	} else {
		// Draw tiles
		pitchp = widg->pitch / zoom;
		for (y=0; y<widg->height; y++) {
			yp = y / zoom;
			scanptr = &widg->imgptr[y * widg->pitch];
			for (x=0; x<widg->width; x++) {
				xp = x / zoom;

				// Calculate
				tileidx = (yp >> 3) * (pitchp >> 3) + (xp >> 3);
				tiledataaddr = (offset << 3) + (tileidx << 3);
				mapoff = (offset << 3) + (tileidx << 3);
				subtile2 = (yp & 4) + ((xp & 4) >> 1);

				// Draw tile
				if (tiledataaddr < PM_ROM_Size) {
					// Get map offset
					ColorMap = (uint8_t *)PRCColorMap + mapoff - PRCColorOffset;
					if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;

					// Decode and draw tile
					ddata = MinxPRC_OnRead(0, tiledataaddr + (xp & 7)) & (1 << (yp & 7));
					odata = ddata ? ColorMap[(subtile2 + 1) ^ negative] : ColorMap[subtile2 ^ negative];
					scanptr[x] = PokeMini_ColorPalBGR32[odata];
				} else {
					// Outside ROM range
					scanptr[x] = (yp ^ xp) & 1 ? 0x808080 : 0x404040;
				}
			}
		}
	}
}

static void PRCTilesDrawGrid(SGtkXDrawingView *widg, int zoom)
{
	int x, y;

	if (SpriteMode) {
		for (x=0; x<widg->width; x+=(zoom*16)) {
			sgtkx_drawing_view_drawvline(widg, x, 0, widg->height, 0xC0C0C0);
			sgtkx_drawing_view_drawvline(widg, x+1, 0, widg->height, 0x404040);
		}
		for (y=0; y<widg->height; y+=(zoom*16)) {
			sgtkx_drawing_view_drawhline(widg, y, 0, widg->width, 0xC0C0C0);
			sgtkx_drawing_view_drawhline(widg, y+1, 0, widg->width, 0x404040);
		}
	} else {
		for (x=0; x<widg->width; x+=(zoom*8)) {
			sgtkx_drawing_view_drawvline(widg, x, 0, widg->height, 0xC0C0C0);
			sgtkx_drawing_view_drawvline(widg, x+1, 0, widg->height, 0x404040);
		}
		for (y=0; y<widg->height; y+=(zoom*8)) {
			sgtkx_drawing_view_drawhline(widg, y, 0, widg->width, 0xC0C0C0);
			sgtkx_drawing_view_drawhline(widg, y+1, 0, widg->width, 0x404040);
		}
	}
}

// -------
// Viewers
// -------

static int PRCTilesView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	if (PRCColorMap) {
		if (PokeMini_ColorFormat == 1) {
			// Color 4x4 Attributes
			PRCTilesRenderColor4x4(widg, SpriteMode, dclc_zoom_prctiles, widg->sboffset, Negative, dclc_trans_prctiles);
		} else {
			// Color 8x8 Attributes
			PRCTilesRenderColor8x8(widg, SpriteMode, dclc_zoom_prctiles, widg->sboffset, Negative, dclc_trans_prctiles);
		}

	} else {
		// Mono
		PRCTilesRenderMono(widg, SpriteMode, dclc_zoom_prctiles, widg->sboffset, Negative, dclc_trans_prctiles);
	}
	if (ShowGrid) PRCTilesDrawGrid(widg, dclc_zoom_prctiles);
	if (emumode == EMUMODE_RUNFULL) AnyView_DrawDisableMask(widg);

	return 1;
}

static int PRCTilesView_motion(SGtkXDrawingView *widg, int x, int y, int _c)
{
	char txt[PMTMPV];
	int tileaddr, tilenum, tzoom, tx, ty, tp;

	if (SpriteMode) {
		tzoom = 16 * dclc_zoom_prctiles;
		tx = x / tzoom;
		ty = y / tzoom;
		tp = widg->pitch / tzoom;
		tilenum = ty * tp + tx + widg->sboffset;
		tileaddr = tilenum * 64;
	} else {
		tzoom = 8 * dclc_zoom_prctiles;
		tx = x / tzoom;
		ty = y / tzoom;
		tp = widg->pitch / tzoom;
		tilenum = ty * tp + tx + widg->sboffset;
		tileaddr = tilenum * 8;
	}

	sprintf(txt, "%s Tile=($%04X, %i) -:- Addr=($%06X, %i)", SpriteMode ? "Sprite" : "BG", tilenum, tilenum, tileaddr, tileaddr);
	gtk_label_set_text(LabelInfo, txt);

	return 0;
}

// --------------
// Menu callbacks
// --------------

static void PRCTilesW_SpriteMode(GtkWidget *widget, gpointer data)
{
	if (PRCTilesWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Sprite Mode");
	SpriteMode = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (SpriteMode) {
		sgtkx_drawing_view_sbpage(&PRCTilesView, 8, 128);
	} else {
		sgtkx_drawing_view_sbpage(&PRCTilesView, 1, 16);
	}
	PRCTilesWindow_Refresh(1);
}

static void PRCTilesW_ShowGrid(GtkWidget *widget, gpointer data)
{
	if (PRCTilesWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Show Grid");
	ShowGrid = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	PRCTilesWindow_Refresh(1);
}

static void PRCTilesW_Negative(GtkWidget *widget, gpointer data)
{
	if (PRCTilesWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Show Negative");
	Negative = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	PRCTilesWindow_Refresh(1);
}

static void PRCTilesW_Zoom(GtkWidget *widget, gpointer data)
{
	if (PRCTilesWindow_InConfigs) return;
	dclc_zoom_prctiles = (int)data;
	PRCTilesWindow_Refresh(1);
}

static void PRCTilesW_Transparency(GtkWidget *widget, gpointer data)
{
	int number, index = (int)data;
	static int lasttransindex = -2;

	if (lasttransindex == index) return;
	lasttransindex = index;
	if (PRCTilesWindow_InConfigs) return;

	if (index >= 0) {
		dclc_trans_prctiles = TransparencyColor[index];
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(PRCTilesWindow, "Custom tranparent color", "Transparency value:", &number, dclc_trans_prctiles, 6, 1, 0x000000, 0xFFFFFF)) {
			dclc_trans_prctiles = number & 0xFFFFFF;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
	PRCTilesWindow_Refresh(1);
}

static void PRCTilesW_Goto_Address(GtkWidget *widget, gpointer data)
{
	int val = PRCTilesView.sboffset * 8;

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(PRCTilesWindow, "Go to address", "Set address to top of view:", &val, val, 6, 1, 0, PM_ROM_Size-1)) {
		sgtkx_drawing_view_sbvalue(&PRCTilesView, val/8);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void PRCTilesW_Goto_Tile(GtkWidget *widget, gpointer data)
{
	int val = PRCTilesView.sboffset;

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(PRCTilesWindow, "Go to tile", "Set tile to top of view:", &val, val, 6, 1, 0, PM_ROM_Size-1)) {
		sgtkx_drawing_view_sbvalue(&PRCTilesView, val);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void PRCTilesW_Goto_FrameTB(GtkWidget *widget, gpointer data)
{
	sgtkx_drawing_view_sbvalue(&PRCTilesView, 0x1000 / 8);
}

static void PRCTilesW_Goto_MapTB(GtkWidget *widget, gpointer data)
{
	sgtkx_drawing_view_sbvalue(&PRCTilesView, MinxPRC.PRCBGBase / 8);
}

static void PRCTilesW_Goto_SpriteTB(GtkWidget *widget, gpointer data)
{
	sgtkx_drawing_view_sbvalue(&PRCTilesView, MinxPRC.PRCSprBase / 8);
}

static void PRCTilesW_Follow(GtkWidget *widget, gpointer data)
{
	Follow = (int)data;
	PRCTilesWindow_Refresh(1);
}

static void PRCTilesW_RefreshNow(GtkWidget *widget, gpointer data)
{
	refresh_debug(1);
}

static void PRCTilesW_Refresh(GtkWidget *widget, gpointer data)
{
	int val, index = (int)data;
	static int lastrefreshindex = -2;

	if (lastrefreshindex == index) return;
	lastrefreshindex = index;
	if (PRCTilesWindow_InConfigs) return;

	if (index >= 0) {
		dclc_prctileswin_refresh = index;
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(PRCTilesWindow, "Custom refresh rate", "Frames skip per refresh:", &val, dclc_prctileswin_refresh, 4, 0, 0, 1000)) {
			dclc_prctileswin_refresh = val;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

static gint PRCTilesWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(PRCTilesWindow));
	return TRUE;
}

static gboolean PRCTilesWindow_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{
	if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) PRCTilesWindow_minimized = event->new_window_state & GDK_WINDOW_STATE_ICONIFIED;
	return TRUE;
}

static GtkItemFactoryEntry PRCTilesWindow_MenuItems[] = {
	{ "/_View",                              NULL,           NULL,                     0, "<Branch>" },
	{ "/View/Sprite Mode",                   NULL,           PRCTilesW_SpriteMode,     0, "<CheckItem>" },
	{ "/View/Show Grid",                     NULL,           PRCTilesW_ShowGrid,       0, "<CheckItem>" },
	{ "/View/Show Negative",                 NULL,           PRCTilesW_Negative,       0, "<CheckItem>" },
	{ "/View/Zoom",                          NULL,           NULL,                     0, "<Branch>" },
	{ "/View/Zoom/100%",                     NULL,           PRCTilesW_Zoom,           1, "<RadioItem>" },
	{ "/View/Zoom/200%",                     NULL,           PRCTilesW_Zoom,           2, "/View/Zoom/100%" },
	{ "/View/Zoom/300%",                     NULL,           PRCTilesW_Zoom,           3, "/View/Zoom/100%" },
	{ "/View/Zoom/400%",                     NULL,           PRCTilesW_Zoom,           4, "/View/Zoom/100%" },
	{ "/View/Zoom/500%",                     NULL,           PRCTilesW_Zoom,           5, "/View/Zoom/100%" },
	{ "/View/Zoom/600%",                     NULL,           PRCTilesW_Zoom,           6, "/View/Zoom/100%" },
	{ "/View/Zoom/700%",                     NULL,           PRCTilesW_Zoom,           7, "/View/Zoom/100%" },
	{ "/View/Zoom/800%",                     NULL,           PRCTilesW_Zoom,           8, "/View/Zoom/100%" },
	{ "/View/Transparency",                  NULL,           NULL,                     0, "<Branch>" },
	{ "/View/Transparency/Pink",             NULL,           PRCTilesW_Transparency,   0, "<RadioItem>" },
	{ "/View/Transparency/Red",              NULL,           PRCTilesW_Transparency,   1, "/View/Transparency/Pink" },
	{ "/View/Transparency/Green",            NULL,           PRCTilesW_Transparency,   2, "/View/Transparency/Pink" },
	{ "/View/Transparency/Blue",             NULL,           PRCTilesW_Transparency,   3, "/View/Transparency/Pink" },
	{ "/View/Transparency/Yellow",           NULL,           PRCTilesW_Transparency,   4, "/View/Transparency/Pink" },
	{ "/View/Transparency/Orange",           NULL,           PRCTilesW_Transparency,   5, "/View/Transparency/Pink" },
	{ "/View/Transparency/Purple",           NULL,           PRCTilesW_Transparency,   6, "/View/Transparency/Pink" },
	{ "/View/Transparency/Bright Red",       NULL,           PRCTilesW_Transparency,   7, "/View/Transparency/Pink" },
	{ "/View/Transparency/Bright Green",     NULL,           PRCTilesW_Transparency,   8, "/View/Transparency/Pink" },
	{ "/View/Transparency/Bright Blue",      NULL,           PRCTilesW_Transparency,   9, "/View/Transparency/Pink" },
	{ "/View/Transparency/Bright Yellow",    NULL,           PRCTilesW_Transparency,  10, "/View/Transparency/Pink" },
	{ "/View/Transparency/Cyan",             NULL,           PRCTilesW_Transparency,  11, "/View/Transparency/Pink" },
	{ "/View/Transparency/Black",            NULL,           PRCTilesW_Transparency,  12, "/View/Transparency/Pink" },
	{ "/View/Transparency/Grey",             NULL,           PRCTilesW_Transparency,  13, "/View/Transparency/Pink" },
	{ "/View/Transparency/Silver",           NULL,           PRCTilesW_Transparency,  14, "/View/Transparency/Pink" },
	{ "/View/Transparency/White",            NULL,           PRCTilesW_Transparency,  15, "/View/Transparency/Pink" },
	{ "/View/Transparency/Custom",           NULL,           PRCTilesW_Transparency,  -1, "/View/Transparency/Pink" },

	{ "/_Go to",                             NULL,           NULL,                     0, "<Branch>" },
	{ "/Go to/_Address...",                  "<SHIFT>G",     PRCTilesW_Goto_Address,   0, "<Item>" },
	{ "/Go to/_Tile...",                     "<CTRL>T",      PRCTilesW_Goto_Tile,      0, "<Item>" },
	{ "/Go to/_Framebuffer Base",            "<SHIFT>F",     PRCTilesW_Goto_FrameTB,   0, "<Item>" },
	{ "/Go to/_Map Tile Base",               "<SHIFT>M",     PRCTilesW_Goto_MapTB,     0, "<Item>" },
	{ "/Go to/_Sprite Tile Base",            "<SHIFT>S",     PRCTilesW_Goto_SpriteTB,  0, "<Item>" },

	{ "/_Follow",                            NULL,           NULL,                     0, "<Branch>" },
	{ "/Follow/Don't follow",                NULL,           PRCTilesW_Follow,         0, "<RadioItem>" },
	{ "/Follow/Follow Map Tile Base",        NULL,           PRCTilesW_Follow,         1, "/Follow/Don't follow" },
	{ "/Follow/Follow Sprite Tile Base",     NULL,           PRCTilesW_Follow,         2, "/Follow/Don't follow" },

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
	{ "/Refresh/Now!",                       NULL,           PRCTilesW_RefreshNow,     0, "<Item>" },
	{ "/Refresh/sep1",                       NULL,           NULL,                     0, "<Separator>" },
	{ "/Refresh/100% 72fps",                 NULL,           PRCTilesW_Refresh,        0, "<RadioItem>" },
	{ "/Refresh/ 50% 36fps",                 NULL,           PRCTilesW_Refresh,        1, "/Refresh/100% 72fps" },
	{ "/Refresh/ 33% 24fps",                 NULL,           PRCTilesW_Refresh,        2, "/Refresh/100% 72fps" },
	{ "/Refresh/ 25% 18fps",                 NULL,           PRCTilesW_Refresh,        3, "/Refresh/100% 72fps" },
	{ "/Refresh/ 17% 12fps",                 NULL,           PRCTilesW_Refresh,        5, "/Refresh/100% 72fps" },
	{ "/Refresh/ 12%  9fps",                 NULL,           PRCTilesW_Refresh,        7, "/Refresh/100% 72fps" },
	{ "/Refresh/  8%  6fps",                 NULL,           PRCTilesW_Refresh,       11, "/Refresh/100% 72fps" },
	{ "/Refresh/  3%  2fps",                 NULL,           PRCTilesW_Refresh,       35, "/Refresh/100% 72fps" },
	{ "/Refresh/  1%  1fps",                 NULL,           PRCTilesW_Refresh,       71, "/Refresh/100% 72fps" },
	{ "/Refresh/Custom...",                  NULL,           PRCTilesW_Refresh,       -1, "/Refresh/100% 72fps" },
};
static gint PRCTilesWindow_MenuItemsNum = sizeof(PRCTilesWindow_MenuItems) / sizeof(*PRCTilesWindow_MenuItems);

// ----------------
// PRC Tiles Window
// ----------------

int PRCTilesWindow_Create(void)
{
	// Window
	PRCTilesWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(PRCTilesWindow), "PRC Tiles View");
	gtk_widget_set_size_request(GTK_WIDGET(PRCTilesWindow), 200, 100);
	gtk_window_set_default_size(PRCTilesWindow, 420, 200);
	g_signal_connect(PRCTilesWindow, "delete_event", G_CALLBACK(PRCTilesWindow_delete_event), NULL);
	g_signal_connect(PRCTilesWindow, "window-state-event", G_CALLBACK(PRCTilesWindow_state_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(PRCTilesWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Menu bar
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, PRCTilesWindow_MenuItemsNum, PRCTilesWindow_MenuItems, NULL);
	gtk_window_add_accel_group(PRCTilesWindow, AccelGroup);
	MenuBar = GTK_MENU_BAR(gtk_item_factory_get_widget(ItemFactory, "<main>"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MenuBar), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MenuBar));

	// Label that warn when running full speed
	LabelRunFull = GTK_LABEL(gtk_label_new("To view content you must stop emulation or run in debug frames/steps."));
	gtk_box_pack_start(VBox1, GTK_WIDGET(LabelRunFull), FALSE, TRUE, 0);

	// Info label
	LabelInfo = GTK_LABEL(gtk_label_new("-:-"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(LabelInfo), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(LabelInfo));

	// PRC Tiles View
	PRCTilesView.on_exposure = SGtkXDVCB(PRCTilesView_exposure);
	PRCTilesView.on_scroll = SGtkXDVCB(AnyView_scroll);
	PRCTilesView.on_resize = SGtkXDVCB(AnyView_resize);
	PRCTilesView.on_motion = SGtkXDVCB(PRCTilesView_motion);
	PRCTilesView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	sgtkx_drawing_view_new(&PRCTilesView, 1);
	sgtkx_drawing_view_sbminmax(&PRCTilesView, 0, 512);	// $1000 to $1FFF
	gtk_widget_set_size_request(GTK_WIDGET(PRCTilesView.box), 64, 64);
	gtk_box_pack_start(VBox1, GTK_WIDGET(PRCTilesView.box), TRUE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(PRCTilesView.box));

	return 1;
}

void PRCTilesWindow_Destroy(void)
{
	int x, y, width, height;
	if (gtk_widget_get_realized(GTK_WIDGET(PRCTilesWindow))) {
		gtk_widget_show(GTK_WIDGET(PRCTilesWindow));
		gtk_window_deiconify(PRCTilesWindow);
		gtk_window_get_position(PRCTilesWindow, &x, &y);
		gtk_window_get_size(PRCTilesWindow, &width, &height);
		dclc_prctileswin_winx = x;
		dclc_prctileswin_winy = y;
		dclc_prctileswin_winw = width;
		dclc_prctileswin_winh = height;
	}
}

void PRCTilesWindow_Activate(void)
{
	gtk_widget_realize(GTK_WIDGET(PRCTilesWindow));
	if ((dclc_prctileswin_winx > -15) && (dclc_prctileswin_winy > -16)) {
		gtk_window_move(PRCTilesWindow, dclc_prctileswin_winx, dclc_prctileswin_winy);
	}
	if ((dclc_prctileswin_winw > 0) && (dclc_prctileswin_winh > 0)) {
		gtk_window_resize(PRCTilesWindow, dclc_prctileswin_winw, dclc_prctileswin_winh);
	}
	gtk_widget_show(GTK_WIDGET(PRCTilesWindow));
	gtk_window_present(PRCTilesWindow);
}

void PRCTilesWindow_UpdateConfigs(void)
{
	GtkWidget *widg;
	int i;

	PRCTilesWindow_InConfigs = 1;

	widg = gtk_item_factory_get_item(ItemFactory, "/Follow/Don't follow");
	if (Follow == 0) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Follow/Follow Map Tile Base");
	if (Follow == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Follow/Follow Sprite Tile Base");
	if (Follow == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/View/Sprite Mode");
	if (SpriteMode) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Show Grid");
	if (ShowGrid) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Show Negative");
	if (Negative) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/100%");
	if (dclc_zoom_prctiles == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/200%");
	if (dclc_zoom_prctiles == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/300%");
	if (dclc_zoom_prctiles == 3) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/400%");
	if (dclc_zoom_prctiles == 4) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/500%");
	if (dclc_zoom_prctiles == 5) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/600%");
	if (dclc_zoom_prctiles == 6) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/700%");
	if (dclc_zoom_prctiles == 7) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/800%");
	if (dclc_zoom_prctiles == 8) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/View/Transparency/Custom");
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	for (i=0; i<16; i++) {
		widg = gtk_item_factory_get_item(ItemFactory, TransparencyColorMenu[i]);
		if (dclc_trans_prctiles == TransparencyColor[i]) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	}

	if (SpriteMode) {
		sgtkx_drawing_view_sbpage(&PRCTilesView, 8, 128);
	} else {
		sgtkx_drawing_view_sbpage(&PRCTilesView, 1, 16);
	}

	switch (dclc_prctileswin_refresh) {
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

	PRCTilesWindow_InConfigs = 0;
}

void PRCTilesWindow_ROMResized(void)
{
	sgtkx_drawing_view_sbminmax(&PRCTilesView, 0, (PM_ROM_Size/8)-1);
	PRCTilesWindow_Refresh(1);
}

void PRCTilesWindow_Sensitive(int enabled)
{
	if (enabled) {
		gtk_widget_hide(GTK_WIDGET(LabelRunFull));
		gtk_widget_show(GTK_WIDGET(PRCTilesView.box));
		gtk_widget_show(GTK_WIDGET(LabelInfo));
	} else {
		gtk_widget_show(GTK_WIDGET(LabelRunFull));
		gtk_widget_hide(GTK_WIDGET(PRCTilesView.box));
		gtk_widget_hide(GTK_WIDGET(LabelInfo));
	}
}

void PRCTilesWindow_Refresh(int now)
{
	static int refreshcnt = 0;
	if ((refreshcnt <= 0) || (now)) {
		refreshcnt = dclc_prctileswin_refresh;
		if (!now) {
			if (!gtk_widget_get_visible(GTK_WIDGET(PRCTilesWindow)) || PRCTilesWindow_minimized) return;
		}
		if (emumode != EMUMODE_STOP) {
			switch (Follow) {
				case 1:	sgtkx_drawing_view_sbvalue(&PRCTilesView, MinxPRC.PRCBGBase / 8);
					break;
				case 2:	sgtkx_drawing_view_sbvalue(&PRCTilesView, MinxPRC.PRCSprBase / 8);
					break;
			}
		}
		sgtkx_drawing_view_refresh(&PRCTilesView);
	} else refreshcnt--;
}
