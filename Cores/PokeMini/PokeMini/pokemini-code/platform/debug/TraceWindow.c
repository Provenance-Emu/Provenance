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

#include "TraceWindow.h"
#include "PokeMiniIcon_96x128.h"
#include "InstructionProc.h"
#include "InstructionInfo.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

static int TraceWindow_InConfigs = 0;

GtkWindow *TraceWindow;
static int TraceWindow_minimized;
static GtkItemFactory *ItemFactory;
static GtkAccelGroup *AccelGroup;
static GtkBox *VBox1;
static GtkMenuBar *MenuBar;
static GtkLabel *LabelRunFull;
static SGtkXDrawingView TraceView;
static GtkBox *HBox1;
static GtkBox *VBox2[3];
static GtkLabel *TmrTitle[3];
static GtkToggleButton *TmrEna[3];
static GtkLabel *TmrValue[3];
static GtkButton *TmrClear[3];
static GtkButton *TmrClipCopy[3];
static GtkButton *TmrClipPaste[3];

static char *TmrTitle_Txt[3] = {
	"-: Timing Counter 1 :-",
	"-: Timing Counter 2 :-",
	"-: Timing Counter 3 :-"
};

// -----------------
// Widgets callbacks
// -----------------

static void TraceWindow_Render(void)
{
	char txt[PMTMPV];

	// Update cycle timers values
	sprintf(txt, "%i", CYCTmr1Cnt);
	gtk_label_set_text(TmrValue[0], txt);
	sprintf(txt, "%i", CYCTmr2Cnt);
	gtk_label_set_text(TmrValue[1], txt);
	sprintf(txt, "%i", CYCTmr3Cnt);
	gtk_label_set_text(TmrValue[2], txt);

	// Render trace view
	sgtkx_drawing_view_refresh(&TraceView);
}

static void TmrEna_toggled(GtkToggleButton *togglebutton, gpointer data)
{
	if (TraceWindow_InConfigs) return;
	switch ((int)data) {
		case 0: CYCTmr1Ena = gtk_toggle_button_get_active(togglebutton); break;
		case 1: CYCTmr2Ena = gtk_toggle_button_get_active(togglebutton); break;
		case 2: CYCTmr3Ena = gtk_toggle_button_get_active(togglebutton); break;
	}
}

static void TmrClear_clicked(GtkWidget *widget, gpointer data)
{
	switch ((int)data) {
		case 0: CYCTmr1Cnt = 0; break;
		case 1: CYCTmr2Cnt = 0; break;
		case 2: CYCTmr3Cnt = 0; break;
	}
	TraceWindow_Render();
}

static void TmrClipCopy_clicked(GtkWidget *widget, gpointer data)
{
	char txt[PMTMPV];
	txt[0] = 0;
	switch ((int)data) {
		case 0: sprintf(txt, "%i", CYCTmr1Cnt); break;
		case 1: sprintf(txt, "%i", CYCTmr2Cnt); break;
		case 2: sprintf(txt, "%i", CYCTmr3Cnt); break;
	}
	gtk_clipboard_set_text(gtk_clipboard_get(GDK_SELECTION_PRIMARY), txt, -1);
	gtk_clipboard_set_text(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD), txt, -1);
}

static void TmrClipPaste_clicked(GtkWidget *widget, gpointer data)
{
	gchar *clip = gtk_clipboard_wait_for_text(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD));
	if (clip == NULL) return;
	switch ((int)data) {
		case 0: CYCTmr1Cnt = atoi(clip); break;
		case 1: CYCTmr2Cnt = atoi(clip); break;
		case 2: CYCTmr3Cnt = atoi(clip); break;
	}
	g_free(clip);
	TraceWindow_Render();
}

// -------
// Viewers
// -------

// Trace view exposure event
static int TraceView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	uint32_t color;
	int y, pp, ppp;
	int yc, ys = -1;
	int size;
	InstructionInfo *opcode;
	uint8_t data[4];
	char opcodename[PMTMPV];

	// Calculate height and selected item
	yc = height / 12;
	if ((widg->mouseinside) && (widg->mousey >= 12)) {
		ys = (widg->mousey - 12) / 12;
	}

	// Draw content
	pp = widg->sboffset;
	for (y=1; y<yc+1; y++) {
		if (emumode != EMUMODE_RUNFULL) {
			if ((y-1) == ys) {
				if (pp & 1) color = 0xF8F8DC;
				else color = 0xF8F8F8;
			} else {
				if (pp & 1) color = 0xFFFFE4;
				else color = 0xFFFFFF;
			}
		} else {
			if (pp & 1) color = 0x808064;
			else color = 0x808080;
		}
		sgtkx_drawing_view_drawfrect(widg, 0, y * 12, widg->width, 12, color);

		if (pp >= TRACECODE_LENGTH) continue;

		// Get address from history
		ppp = TRACAddr[(TRACPoint + (TRACECODE_LENGTH - 1 - pp) + 1) % TRACECODE_LENGTH];

		// Draw timelapse
		if (pp == (TRACECODE_LENGTH - 1)) sgtkx_drawing_view_drawtext(widg, 4, y * 12, 0x4C3000, "====>");
		else sgtkx_drawing_view_drawtext(widg, 4, y * 12, 0x4C3000, "%5d", -(TRACECODE_LENGTH - 1) + pp);

		if (ppp != 0xFFFFFFFF) {
			// Decode instruction
			opcode = GetInstructionInfo(MinxCPU_OnRead, 1, ppp, data, &size);
			DisasmSingleOpcode(opcode, ppp, data, opcodename, &CDisAsm_SOpcDec);

			// Draw instruction
			sgtkx_drawing_view_drawtext(widg, 52, y * 12, 0x4C3000, "$%06X", ppp);
			if (size >= 1) sgtkx_drawing_view_drawtext(widg, 108, y * 12, 0x605020, "%02X", data[0]);
			if (size >= 2) sgtkx_drawing_view_drawtext(widg, 124, y * 12, 0x605040, "%02X", data[1]);
			if (size >= 3) sgtkx_drawing_view_drawtext(widg, 140, y * 12, 0x605060, "%02X", data[2]);
			if (size >= 4) sgtkx_drawing_view_drawtext(widg, 156, y * 12, 0x605080, "%02X", data[3]);
			sgtkx_drawing_view_drawtext(widg, 188, y * 12, 0x4C3000, "%s", opcodename);
		} else {
			sgtkx_drawing_view_drawtext(widg, 52, y * 12, 0x404040, "$------");
		}
		pp++;
	}

	// Draw top bar
	if (emumode != EMUMODE_RUNFULL) {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0xD8D8CC);
	} else {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0x68685C);
	}
	sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "Run Trace List (Click will go to address)");

	return 1;
}

// Trace view button press
static int TraceView_buttonpress(SGtkXDrawingView *widg, int button, int press, int _c)
{
	int ys = -1;
	int pp, ppp;

	// Calculate selected item
	if  (emumode == EMUMODE_RUNFULL) return 0;
	if ((!widg->mouseinside) || (widg->mousey < 12)) return 0;
	ys = (widg->mousey - 12) / 12;

	// Process selected item
	pp = widg->sboffset + ys;
	if (pp >= TRACECODE_LENGTH) return 1;
	ppp = TRACAddr[(TRACPoint + (TRACECODE_LENGTH - 1 - pp) + 1) % TRACECODE_LENGTH];
	if (button == SGTKXDV_BLEFT) {
		if (ppp != 0xFFFFFFFF) {
			ProgramView_GotoAddr(ppp, 1);
			refresh_debug(1);
		}
	}

	return 1;
}

// Trace view resize
static int TraceView_resize(SGtkXDrawingView *widg, int width, int height, int _c)
{
	int lastheight = widg->total_lines;
	int currpos = widg->sboffset;
	widg->total_lines = height / 12;
	sgtkx_drawing_view_sbpage(widg, widg->total_lines, widg->total_lines - 2);
	sgtkx_drawing_view_sbvalue(widg, currpos + (lastheight - widg->total_lines));

	return (emumode == EMUMODE_STOP);
}

// --------------
// Menu callbacks
// --------------

static void TraceW_RefreshNow(GtkWidget *widget, gpointer data)
{
	refresh_debug(1);
}

static void TraceW_Refresh(GtkWidget *widget, gpointer data)
{
	int val, index = (int)data;
	static int lastrefrindex = -2;

	if (lastrefrindex == index) return;
	lastrefrindex = index;
	if (TraceWindow_InConfigs) return;

	if (index >= 0) {
		dclc_tracewin_refresh = index;
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(TraceWindow, "Custom refresh rate", "Frames skip per refresh:", &val, dclc_tracewin_refresh, 4, 0, 0, 1000)) {
			dclc_tracewin_refresh = val;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

static gint TraceWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(TraceWindow));
	return TRUE;
}

static gboolean TraceWindow_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{
	if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) TraceWindow_minimized = event->new_window_state & GDK_WINDOW_STATE_ICONIFIED;
	return TRUE;
}

static GtkItemFactoryEntry TraceWindow_MenuItems[] = {

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
	{ "/Refresh/Now!",                       NULL,           TraceW_RefreshNow,        0, "<Item>" },
	{ "/Refresh/sep1",                       NULL,           NULL,                     0, "<Separator>" },
	{ "/Refresh/100% 72fps",                 NULL,           TraceW_Refresh,           0, "<RadioItem>" },
	{ "/Refresh/ 50% 36fps",                 NULL,           TraceW_Refresh,           1, "/Refresh/100% 72fps" },
	{ "/Refresh/ 33% 24fps",                 NULL,           TraceW_Refresh,           2, "/Refresh/100% 72fps" },
	{ "/Refresh/ 25% 18fps",                 NULL,           TraceW_Refresh,           3, "/Refresh/100% 72fps" },
	{ "/Refresh/ 17% 12fps",                 NULL,           TraceW_Refresh,           5, "/Refresh/100% 72fps" },
	{ "/Refresh/ 12%  9fps",                 NULL,           TraceW_Refresh,           7, "/Refresh/100% 72fps" },
	{ "/Refresh/  8%  6fps",                 NULL,           TraceW_Refresh,          11, "/Refresh/100% 72fps" },
	{ "/Refresh/  3%  2fps",                 NULL,           TraceW_Refresh,          35, "/Refresh/100% 72fps" },
	{ "/Refresh/  1%  1fps",                 NULL,           TraceW_Refresh,          71, "/Refresh/100% 72fps" },
	{ "/Refresh/Custom...",                  NULL,           TraceW_Refresh,          -1, "/Refresh/100% 72fps" },
};
static gint TraceWindow_MenuItemsNum = sizeof(TraceWindow_MenuItems) / sizeof(*TraceWindow_MenuItems);

// ------------
// Trace Window
// ------------

int TraceWindow_Create(void)
{
	int i;

	// Window
	TraceWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(TraceWindow), "Run Trace View");
	gtk_widget_set_size_request(GTK_WIDGET(TraceWindow), 200, 100);
	gtk_window_set_default_size(TraceWindow, 420, 200);
	g_signal_connect(TraceWindow, "delete_event", G_CALLBACK(TraceWindow_delete_event), NULL);
	g_signal_connect(TraceWindow, "window-state-event", G_CALLBACK(TraceWindow_state_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(TraceWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Menu bar
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, TraceWindow_MenuItemsNum, TraceWindow_MenuItems, NULL);
	gtk_window_add_accel_group(TraceWindow, AccelGroup);
	MenuBar = GTK_MENU_BAR(gtk_item_factory_get_widget(ItemFactory, "<main>"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MenuBar), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MenuBar));

	// Label that warn when running full speed
	LabelRunFull = GTK_LABEL(gtk_label_new("To view content you must stop emulation or run in debug frames/steps."));
	gtk_box_pack_start(VBox1, GTK_WIDGET(LabelRunFull), FALSE, TRUE, 0);

	// Trace View
	TraceView.on_exposure = SGtkXDVCB(TraceView_exposure);
	TraceView.on_scroll = SGtkXDVCB(AnyView_scroll);
	TraceView.on_resize = SGtkXDVCB(TraceView_resize);
	TraceView.on_motion = SGtkXDVCB(AnyView_motion);
	TraceView.on_buttonpress = SGtkXDVCB(TraceView_buttonpress);
	TraceView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	TraceView.total_lines = 2;
	sgtkx_drawing_view_new(&TraceView, 1);
	sgtkx_drawing_view_sbminmax(&TraceView, 0, TRACECODE_LENGTH - 1);
	sgtkx_drawing_view_sbvalue(&TraceView, TRACECODE_LENGTH - 1);
	gtk_widget_set_size_request(GTK_WIDGET(TraceView.box), 64, 64);
	gtk_box_pack_start(VBox1, GTK_WIDGET(TraceView.box), TRUE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(TraceView.box));

	// Timers box
	HBox1 = GTK_BOX(gtk_hbox_new(FALSE, 0));
	gtk_box_pack_start(VBox1, GTK_WIDGET(HBox1), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(HBox1));
	for (i=0; i<3; i++) {
		// Container
		VBox2[i] = GTK_BOX(gtk_vbox_new(FALSE, 0));
		gtk_box_pack_start(HBox1, GTK_WIDGET(VBox2[i]), TRUE, TRUE, 0);
		gtk_widget_show(GTK_WIDGET(VBox2[i]));

		// Timer name
		TmrTitle[i] = GTK_LABEL(gtk_label_new(TmrTitle_Txt[i]));
		gtk_misc_set_alignment(GTK_MISC(TmrTitle[i]), 0.5, 0.0);
		gtk_label_set_justify(TmrTitle[i], GTK_JUSTIFY_CENTER);
		gtk_box_pack_start(VBox2[i], GTK_WIDGET(TmrTitle[i]), FALSE, TRUE, 0);
		gtk_widget_show(GTK_WIDGET(TmrTitle[i]));

		// Timer value
		TmrValue[i] = GTK_LABEL(gtk_label_new("0"));
		gtk_box_pack_start(VBox2[i], GTK_WIDGET(TmrValue[i]), FALSE, TRUE, 0);
		gtk_widget_show(GTK_WIDGET(TmrValue[i]));

		// Enable checkbox
		TmrEna[i] = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("Enable"));
		g_signal_connect(TmrEna[i], "toggled", G_CALLBACK(TmrEna_toggled), (gpointer)i);
		gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(TmrEna[i]), TRUE);
		gtk_box_pack_start(VBox2[i], GTK_WIDGET(TmrEna[i]), FALSE, TRUE, 0);
		gtk_widget_show(GTK_WIDGET(TmrEna[i]));

		// Timer clear button
		TmrClear[i] = GTK_BUTTON(gtk_button_new_with_label("Clear"));
		g_signal_connect(TmrClear[i], "clicked", G_CALLBACK(TmrClear_clicked), (gpointer)i);
		gtk_box_pack_start(VBox2[i], GTK_WIDGET(TmrClear[i]), FALSE, TRUE, 0);
		gtk_widget_show(GTK_WIDGET(TmrClear[i]));

		// Timer clipboard copy button
		TmrClipCopy[i] = GTK_BUTTON(gtk_button_new_with_label("Copy"));
		g_signal_connect(TmrClipCopy[i], "clicked", G_CALLBACK(TmrClipCopy_clicked), (gpointer)i);
		gtk_box_pack_start(VBox2[i], GTK_WIDGET(TmrClipCopy[i]), FALSE, TRUE, 0);
		gtk_widget_show(GTK_WIDGET(TmrClipCopy[i]));

		// Timer clipboard copy button
		TmrClipPaste[i] = GTK_BUTTON(gtk_button_new_with_label("Paste"));
		g_signal_connect(TmrClipPaste[i], "clicked", G_CALLBACK(TmrClipPaste_clicked), (gpointer)i);
		gtk_box_pack_start(VBox2[i], GTK_WIDGET(TmrClipPaste[i]), FALSE, TRUE, 0);
		gtk_widget_show(GTK_WIDGET(TmrClipPaste[i]));
	}

	return 1;
}

void TraceWindow_Destroy(void)
{
	int x, y, width, height;
	if (gtk_widget_get_realized(GTK_WIDGET(TraceWindow))) {
		gtk_widget_show(GTK_WIDGET(TraceWindow));
		gtk_window_deiconify(TraceWindow);
		gtk_window_get_position(TraceWindow, &x, &y);
		gtk_window_get_size(TraceWindow, &width, &height);
		dclc_tracewin_winx = x;
		dclc_tracewin_winy = y;
		dclc_tracewin_winw = width;
		dclc_tracewin_winh = height;
	}
}

void TraceWindow_Activate(void)
{
	gtk_widget_realize(GTK_WIDGET(TraceWindow));
	if ((dclc_tracewin_winx > -15) && (dclc_tracewin_winy > -16)) {
		gtk_window_move(TraceWindow, dclc_tracewin_winx, dclc_tracewin_winy);
	}
	if ((dclc_tracewin_winw > 0) && (dclc_tracewin_winh > 0)) {
		gtk_window_resize(TraceWindow, dclc_tracewin_winw, dclc_tracewin_winh);
	}
	gtk_widget_show(GTK_WIDGET(TraceWindow));
	gtk_window_present(TraceWindow);
}

void TraceWindow_UpdateConfigs(void)
{
	TraceWindow_InConfigs = 1;

	switch (dclc_tracewin_refresh) {
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

	TraceWindow_InConfigs = 0;
}

void TraceWindow_Sensitive(int enabled)
{
	if (enabled) {
		gtk_widget_hide(GTK_WIDGET(LabelRunFull));
		gtk_widget_show(GTK_WIDGET(TraceView.box));
		gtk_widget_show(GTK_WIDGET(HBox1));
	} else {
		gtk_widget_show(GTK_WIDGET(LabelRunFull));
		gtk_widget_hide(GTK_WIDGET(TraceView.box));
		gtk_widget_hide(GTK_WIDGET(HBox1));
	}
}

void TraceWindow_Refresh(int now)
{
	static int refreshcnt = 0;
	if ((refreshcnt <= 0) || (now)) {
		refreshcnt = dclc_tracewin_refresh;
		if (!now) {
			if (!gtk_widget_get_visible(GTK_WIDGET(TraceWindow)) || TraceWindow_minimized) return;
		}
		TraceWindow_Render();
	} else refreshcnt--;
}
