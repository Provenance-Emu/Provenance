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

#include "PRCMapWindow.h"
#include "PokeMini_ColorPal.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

static int PRCMapWindow_InConfigs = 0;

GtkWindow *PRCMapWindow;
static int PRCMapWindow_minimized;
static GtkItemFactory *ItemFactory;
static GtkAccelGroup *AccelGroup;
static GtkBox *VBox1;
static GtkMenuBar *MenuBar;
static GtkLabel *LabelRunFull;
static GtkLabel *LabelInfo;
static SGtkXDrawingView PRCMapView;
static GtkLabel *MapPosInfo;

// Locals
static int FullRedraw = 1;
static int ShowGrid = 1;
static int ShowVisible = 1;
static int Negative = 0;

static uint32_t VisibleBorderCol[4] = {0xFF0000, 0xFFFF00, 0xFF8080, 0xFF0000};

// PRC Map render (Mono)
static void PRCMapRenderMono(SGtkXDrawingView *widg, int zoom, int negative)
{
	uint32_t *scanptr;
	int x, y, xp, yp, xl, yl;
	uint32_t tileidxaddr, ltileidxaddr = -1;
	uint32_t tiledataddr = 0;
	uint8_t tileidx = 0, data;
	xl = MinxPRC.PRCMapTW * 8;
	yl = MinxPRC.PRCMapTH * 8;

	for (y=0; y<widg->height; y++) {
		yp = y / zoom;
		if (yp >= yl) break;
		scanptr = &widg->imgptr[y * widg->pitch];
		for (x=0; x<widg->width; x++) {
			xp = x / zoom;
			if (xp >= xl) break;

			// Index address
			tileidxaddr = 0x1360 + (yp >> 3) * MinxPRC.PRCMapTW + (xp >> 3);

			// Read tile index
			if (ltileidxaddr != tileidxaddr) {
				ltileidxaddr = tileidxaddr;
				tileidx = MinxPRC_OnRead(0, tileidxaddr);
				tiledataddr = MinxPRC.PRCBGBase + (tileidx << 3);
			}

			// Read tile data
			data = MinxPRC_OnRead(0, tiledataddr + (xp & 7)) & (1 << (yp & 7));
			if (PMR_PRC_MODE & 0x01) data = !data;
			if (negative) data = !data;

			// Write result
			scanptr[x] = data ? 0x000000 : 0xFFFFFF;
		}
	}
}

// PRC Map render (Color 8x8)
static void PRCMapRenderColor8x8(SGtkXDrawingView *widg, int zoom, int negative)
{
	uint32_t *scanptr;
	int x, y, xp, yp, xl, yl;
	uint32_t tileidxaddr, ltileidxaddr = -1;
	uint32_t tiledataddr = 0;
	uint8_t tileidx = 0, data;
	uint8_t *ColorMap = (uint8_t *)PRCStaticColorMap;
	xl = MinxPRC.PRCMapTW * 8;
	yl = MinxPRC.PRCMapTH * 8;

	negative = negative ? 1 : 0;
	for (y=0; y<widg->height; y++) {
		yp = y / zoom;
		if (yp >= yl) break;
		scanptr = &widg->imgptr[y * widg->pitch];
		for (x=0; x<widg->width; x++) {
			xp = x / zoom;
			if (xp >= xl) break;

			// Index address
			tileidxaddr = 0x1360 + (yp >> 3) * MinxPRC.PRCMapTW + (xp >> 3);

			// Read tile index
			if (ltileidxaddr != tileidxaddr) {
				ltileidxaddr = tileidxaddr;
				tileidx = MinxPRC_OnRead(0, tileidxaddr);
				tiledataddr = MinxPRC.PRCBGBase + (tileidx << 3);
				ColorMap = (uint8_t *)PRCColorMap + (tiledataddr >> 2) - PRCColorOffset;
				if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;
			}

			// Read tile data
			data = MinxPRC_OnRead(0, tiledataddr + (xp & 7)) & (1 << (yp & 7));
			if (PMR_PRC_MODE & 0x01) data = !data;
			if (negative) data = !data;
			data = data ? ColorMap[1] : ColorMap[0];

			// Write result
			scanptr[x] = PokeMini_ColorPalBGR32[data];
		}
	}
}

// PRC Map render (Color 4x4)
static void PRCMapRenderColor4x4(SGtkXDrawingView *widg, int zoom, int negative)
{
	uint32_t *scanptr;
	int x, y, xp, yp, xl, yl, quad;
	uint32_t tileidxaddr, ltileidxaddr = -1;
	uint32_t tiledataddr = 0;
	uint8_t tileidx = 0, data;
	uint8_t *ColorMap = (uint8_t *)PRCStaticColorMap;
	xl = MinxPRC.PRCMapTW * 8;
	yl = MinxPRC.PRCMapTH * 8;

	negative = negative ? 1 : 0;
	for (y=0; y<widg->height; y++) {
		yp = y / zoom;
		if (yp >= yl) break;
		scanptr = &widg->imgptr[y * widg->pitch];
		for (x=0; x<widg->width; x++) {
			xp = x / zoom;
			if (xp >= xl) break;

			// Get quad index
			quad = (yp & 4) + ((xp & 4) >> 1);

			// Index address
			tileidxaddr = 0x1360 + (yp >> 3) * MinxPRC.PRCMapTW + (xp >> 3);

			// Read tile index
			if (ltileidxaddr != tileidxaddr) {
				ltileidxaddr = tileidxaddr;
				tileidx = MinxPRC_OnRead(0, tileidxaddr);
				tiledataddr = MinxPRC.PRCBGBase + (tileidx << 3);
				ColorMap = (uint8_t *)PRCColorMap + tiledataddr - PRCColorOffset;
				if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;
			}

			// Read tile data
			data = MinxPRC_OnRead(0, tiledataddr + (xp & 7)) & (1 << (yp & 7));
			if (PMR_PRC_MODE & 0x01) data = !data;
			if (negative) data = !data;
			data = data ? ColorMap[quad+1] : ColorMap[quad];

			// Write result
			scanptr[x] = PokeMini_ColorPalBGR32[data];
		}
	}
}

static void PRCMapDrawGrid(SGtkXDrawingView *widg, int zoom)
{
	int x, y;

	for (x=0; x<widg->width; x+=(zoom*8)) {
		sgtkx_drawing_view_drawvline(widg, x, 0, widg->height, 0xC0C0C0);
		sgtkx_drawing_view_drawvline(widg, x+1, 0, widg->height, 0x404040);
	}
	for (y=0; y<widg->height; y+=(zoom*8)) {
		sgtkx_drawing_view_drawhline(widg, y, 0, widg->width, 0xC0C0C0);
		sgtkx_drawing_view_drawhline(widg, y+1, 0, widg->width, 0x404040);
	}
}

static void PRCMapDrawVisible(SGtkXDrawingView *widg, int zoom)
{
	int x, y, w, h;
	x = MinxPRC.PRCMapPX * zoom;
	y = MinxPRC.PRCMapPY * zoom;
	w = 96 * zoom;
	h = 64 * zoom;
	if (zoom >= 4) sgtkx_drawing_view_drawsrect(widg, x-3, y-3, w+6, h+6, VisibleBorderCol[3]);
	if (zoom >= 3) sgtkx_drawing_view_drawsrect(widg, x-2, y-2, w+4, h+4, VisibleBorderCol[2]);
	if (zoom >= 2) sgtkx_drawing_view_drawsrect(widg, x-1, y-1, w+2, h+2, VisibleBorderCol[1]);
	          else sgtkx_drawing_view_drawsrect(widg, x-1, y-1, w+2, h+2, VisibleBorderCol[0]);
	if (zoom >= 2) sgtkx_drawing_view_drawsrect(widg, x, y, w, h, VisibleBorderCol[0]);
}

// -------
// Viewers
// -------

static int PRCMapView_imgresize(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	AnyView_DrawBackground(widg, width, height, dclc_zoom_prcmap);
	return 1;
}

static int PRCMapView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	char txt[PMTMPV];

	if (FullRedraw) {
		AnyView_DrawBackground(widg, width, height, dclc_zoom_prcmap);
		FullRedraw = 0;
	} else {
		AnyView_DrawBackground(widg, MinxPRC.PRCMapTW*8+4, MinxPRC.PRCMapTH*8+4, dclc_zoom_prcmap);
	}
	if (PRCColorMap) {
		if (PokeMini_ColorFormat == 1) {
			// Color 4x4 Attributes
			PRCMapRenderColor4x4(widg, dclc_zoom_prcmap, Negative);
		} else {
			// Color 8x8 Attributes
			PRCMapRenderColor8x8(widg, dclc_zoom_prcmap, Negative);
		}

	} else {
		// Mono
		PRCMapRenderMono(widg, dclc_zoom_prcmap, Negative);
	}
	if (emumode != EMUMODE_RUNFULL) {
		if (ShowGrid) PRCMapDrawGrid(widg, dclc_zoom_prcmap);
		if (ShowVisible) PRCMapDrawVisible(widg, dclc_zoom_prcmap);
	} else {
		AnyView_DrawDisableMask(widg);
	}

	// Map position label
	sprintf(txt, "Map X=($%02X, %i) -:- Map Y=($%02X, %i)",
		(int)MinxPRC.PRCMapPX, (int)MinxPRC.PRCMapPX,
		(int)MinxPRC.PRCMapPY, (int)MinxPRC.PRCMapPY);
	gtk_label_set_text(MapPosInfo, txt);

	return 1;
}

static int PRCMapView_motion(SGtkXDrawingView *widg, int x, int y, int _c)
{
	char txt[PMTMPV];
	int tzoom, tx, ty;
	int mapaddr, mapnum;
	int tileaddr, tilenum;

	tzoom = 8 * dclc_zoom_prcmap;
	tx = x / tzoom;
	ty = y / tzoom;
	mapnum = ty * MinxPRC.PRCMapTW + tx;
	mapaddr = 0x1360 + mapnum;

	// Info label
	if ((tx < MinxPRC.PRCMapTW) && (ty < MinxPRC.PRCMapTH)) {
		tilenum = MinxPRC_OnRead(0, mapaddr);
		tileaddr = MinxPRC.PRCBGBase + (tilenum << 3);
		sprintf(txt, "Map=($%04X, %i) @%06X -:- Tile=($%02X, %i) @$%06X",
			mapnum, mapnum, mapaddr, tilenum, tilenum, tileaddr);
	} else {
		strcpy(txt, "-:-");
	}
	gtk_label_set_text(LabelInfo, txt);

	return 0;
}

// --------------
// Menu callbacks
// --------------

static void PRCMapW_ShowVisible(GtkWidget *widget, gpointer data)
{
	if (PRCMapWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Show Visible");
	ShowVisible = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	FullRedraw = 1;
	PRCMapWindow_Refresh(1);
}

static void PRCMapW_ShowGrid(GtkWidget *widget, gpointer data)
{
	if (PRCMapWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Show Grid");
	ShowGrid = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	FullRedraw = 1;
	PRCMapWindow_Refresh(1);
}

static void PRCMapW_Negative(GtkWidget *widget, gpointer data)
{
	if (PRCMapWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Show Negative");
	Negative = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	PRCMapWindow_Refresh(1);
}

static void PRCMapW_Zoom(GtkWidget *widget, gpointer data)
{
	if (PRCMapWindow_InConfigs) return;
	dclc_zoom_prcmap = (int)data;
	FullRedraw = 1;
	PRCMapWindow_Refresh(1);
}

static void PRCMapW_RefreshNow(GtkWidget *widget, gpointer data)
{
	FullRedraw = 1;
	refresh_debug(1);
}

static void PRCMapW_Refresh(GtkWidget *widget, gpointer data)
{
	int val, index = (int)data;
	static int lastrefrindex = -2;

	if (lastrefrindex == index) return;
	lastrefrindex = index;
	if (PRCMapWindow_InConfigs) return;

	if (index >= 0) {
		dclc_prcmapwin_refresh = index;
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(PRCMapWindow, "Custom refresh rate", "Frames skip per refresh:", &val, dclc_prcmapwin_refresh, 4, 0, 0, 1000)) {
			dclc_prcmapwin_refresh = val;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

static gint PRCMapWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(PRCMapWindow));
	return TRUE;
}

static gboolean PRCMapWindow_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{
	if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) PRCMapWindow_minimized = event->new_window_state & GDK_WINDOW_STATE_ICONIFIED;
	return TRUE;
}

static GtkItemFactoryEntry PRCMapWindow_MenuItems[] = {
	{ "/_View",                              NULL,           NULL,                     0, "<Branch>" },
	{ "/View/Show Visible",                  NULL,           PRCMapW_ShowVisible,      0, "<CheckItem>" },
	{ "/View/Show Grid",                     NULL,           PRCMapW_ShowGrid,         0, "<CheckItem>" },
	{ "/View/Show Negative",                 NULL,           PRCMapW_Negative,         0, "<CheckItem>" },
	{ "/View/Zoom",                          NULL,           NULL,                     0, "<Branch>" },
	{ "/View/Zoom/100%",                     NULL,           PRCMapW_Zoom,             1, "<RadioItem>" },
	{ "/View/Zoom/200%",                     NULL,           PRCMapW_Zoom,             2, "/View/Zoom/100%" },
	{ "/View/Zoom/300%",                     NULL,           PRCMapW_Zoom,             3, "/View/Zoom/100%" },
	{ "/View/Zoom/400%",                     NULL,           PRCMapW_Zoom,             4, "/View/Zoom/100%" },
	{ "/View/Zoom/500%",                     NULL,           PRCMapW_Zoom,             5, "/View/Zoom/100%" },
	{ "/View/Zoom/600%",                     NULL,           PRCMapW_Zoom,             6, "/View/Zoom/100%" },
	{ "/View/Zoom/700%",                     NULL,           PRCMapW_Zoom,             7, "/View/Zoom/100%" },
	{ "/View/Zoom/800%",                     NULL,           PRCMapW_Zoom,             8, "/View/Zoom/100%" },

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
	{ "/Refresh/Now!",                       NULL,           PRCMapW_RefreshNow,       0, "<Item>" },
	{ "/Refresh/sep1",                       NULL,           NULL,                     0, "<Separator>" },
	{ "/Refresh/100% 72fps",                 NULL,           PRCMapW_Refresh,          0, "<RadioItem>" },
	{ "/Refresh/ 50% 36fps",                 NULL,           PRCMapW_Refresh,          1, "/Refresh/100% 72fps" },
	{ "/Refresh/ 33% 24fps",                 NULL,           PRCMapW_Refresh,          2, "/Refresh/100% 72fps" },
	{ "/Refresh/ 25% 18fps",                 NULL,           PRCMapW_Refresh,          3, "/Refresh/100% 72fps" },
	{ "/Refresh/ 17% 12fps",                 NULL,           PRCMapW_Refresh,          5, "/Refresh/100% 72fps" },
	{ "/Refresh/ 12%  9fps",                 NULL,           PRCMapW_Refresh,          7, "/Refresh/100% 72fps" },
	{ "/Refresh/  8%  6fps",                 NULL,           PRCMapW_Refresh,         11, "/Refresh/100% 72fps" },
	{ "/Refresh/  3%  2fps",                 NULL,           PRCMapW_Refresh,         35, "/Refresh/100% 72fps" },
	{ "/Refresh/  1%  1fps",                 NULL,           PRCMapW_Refresh,         71, "/Refresh/100% 72fps" },
	{ "/Refresh/Custom...",                  NULL,           PRCMapW_Refresh,         -1, "/Refresh/100% 72fps" },
};
static gint PRCMapWindow_MenuItemsNum = sizeof(PRCMapWindow_MenuItems) / sizeof(*PRCMapWindow_MenuItems);

// --------------
// PRC Map Window
// --------------

int PRCMapWindow_Create(void)
{
	// Window
	PRCMapWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(PRCMapWindow), "PRC Map View");
	gtk_widget_set_size_request(GTK_WIDGET(PRCMapWindow), 200, 100);
	gtk_window_set_default_size(PRCMapWindow, 420, 200);
	g_signal_connect(PRCMapWindow, "delete_event", G_CALLBACK(PRCMapWindow_delete_event), NULL);
	g_signal_connect(PRCMapWindow, "window-state-event", G_CALLBACK(PRCMapWindow_state_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(PRCMapWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Menu bar
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, PRCMapWindow_MenuItemsNum, PRCMapWindow_MenuItems, NULL);
	gtk_window_add_accel_group(PRCMapWindow, AccelGroup);
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

	// PRC Map View
	PRCMapView.on_imgresize = SGtkXDVCB(PRCMapView_imgresize);
	PRCMapView.on_exposure = SGtkXDVCB(PRCMapView_exposure);
	PRCMapView.on_motion = SGtkXDVCB(PRCMapView_motion);
	PRCMapView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	sgtkx_drawing_view_new(&PRCMapView, 0);
	gtk_widget_set_size_request(GTK_WIDGET(PRCMapView.box), 64, 64);
	gtk_box_pack_start(VBox1, GTK_WIDGET(PRCMapView.box), TRUE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(PRCMapView.box));

	// Map position label
	MapPosInfo = GTK_LABEL(gtk_label_new("Map X=($00, 0) -:- Map Y=($00, 0)"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MapPosInfo), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MapPosInfo));

	return 1;
}

void PRCMapWindow_Destroy(void)
{
	int x, y, width, height;
	if (gtk_widget_get_realized(GTK_WIDGET(PRCMapWindow))) {
		gtk_widget_show(GTK_WIDGET(PRCMapWindow));
		gtk_window_deiconify(PRCMapWindow);
		gtk_window_get_position(PRCMapWindow, &x, &y);
		gtk_window_get_size(PRCMapWindow, &width, &height);
		dclc_prcmapwin_winx = x;
		dclc_prcmapwin_winy = y;
		dclc_prcmapwin_winw = width;
		dclc_prcmapwin_winh = height;
	}
}

void PRCMapWindow_Activate(void)
{
	gtk_widget_realize(GTK_WIDGET(PRCMapWindow));
	if ((dclc_prcmapwin_winx > -15) && (dclc_prcmapwin_winy > -16)) {
		gtk_window_move(PRCMapWindow, dclc_prcmapwin_winx, dclc_prcmapwin_winy);
	}
	if ((dclc_prcmapwin_winw > 0) && (dclc_prcmapwin_winh > 0)) {
		gtk_window_resize(PRCMapWindow, dclc_prcmapwin_winw, dclc_prcmapwin_winh);
	}
	gtk_widget_show(GTK_WIDGET(PRCMapWindow));
	gtk_window_present(PRCMapWindow);
}

void PRCMapWindow_UpdateConfigs(void)
{
	GtkWidget *widg;

	PRCMapWindow_InConfigs = 1;

	widg = gtk_item_factory_get_item(ItemFactory, "/View/Show Visible");
	if (ShowVisible) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Show Grid");
	if (ShowGrid) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Show Negative");
	if (Negative) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/100%");
	if (dclc_zoom_prcmap == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/200%");
	if (dclc_zoom_prcmap == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/300%");
	if (dclc_zoom_prcmap == 3) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/400%");
	if (dclc_zoom_prcmap == 4) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/500%");
	if (dclc_zoom_prcmap == 5) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/600%");
	if (dclc_zoom_prcmap == 6) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/700%");
	if (dclc_zoom_prcmap == 7) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Zoom/800%");
	if (dclc_zoom_prcmap == 8) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	switch (dclc_prcmapwin_refresh) {
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

	PRCMapWindow_InConfigs = 0;
}

void PRCMapWindow_Sensitive(int enabled)
{
	if (enabled) {
		gtk_widget_hide(GTK_WIDGET(LabelRunFull));
		gtk_widget_show(GTK_WIDGET(PRCMapView.box));
		gtk_widget_show(GTK_WIDGET(LabelInfo));
		gtk_widget_show(GTK_WIDGET(MapPosInfo));
	} else {
		gtk_widget_show(GTK_WIDGET(LabelRunFull));
		gtk_widget_hide(GTK_WIDGET(PRCMapView.box));
		gtk_widget_hide(GTK_WIDGET(LabelInfo));
		gtk_widget_hide(GTK_WIDGET(MapPosInfo));
	}
}

void PRCMapWindow_Refresh(int now)
{
	static int refreshcnt = 0;
	if ((refreshcnt <= 0) || (now)) {
		refreshcnt = dclc_prcmapwin_refresh;
		if (!now) {
			if (!gtk_widget_get_visible(GTK_WIDGET(PRCMapWindow)) || PRCMapWindow_minimized) return;
		}
		sgtkx_drawing_view_refresh(&PRCMapView);
	} else refreshcnt--;
}
