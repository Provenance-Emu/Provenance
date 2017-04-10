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

#include "IRQWindow.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

static int IRQWindow_InConfigs = 0;

GtkWindow *IRQWindow;
static int IRQWindow_minimized;
static GtkItemFactory *ItemFactory;
static GtkAccelGroup *AccelGroup;
static GtkBox *VBox1;
static GtkMenuBar *MenuBar;
static GtkLabel *LabelRunFull;
static GtkScrolledWindow *IRQSW;
static GtkTable *MTable;
static GtkFrame *FramePri;
static GtkTable *TablePri;
static GtkLabel *LabelsPri[9];
static GtkComboBox *ComboPri[9];
static GtkFrame *FrameEna;
static GtkBox *VBoxEna;
static GtkToggleButton *CheckEna[27];
static GtkFrame *FrameAct;
static GtkBox *VBoxAct;
static GtkToggleButton *CheckAct[27];

// Enable/Disable frames
static int IRQShow_Pri = 1;
static int IRQShow_Ena = 1;
static int IRQShow_Act = 1;

static void IRQWindow_Render(int force)
{
	IRQWindow_InConfigs = 1;

	// Priority
	if (IRQShow_Pri) {
		gtk_combo_box_set_active(ComboPri[0], (PMR_IRQ_PRI1 & 0xC0) >> 6);
		gtk_combo_box_set_active(ComboPri[1], (PMR_IRQ_PRI1 & 0x30) >> 4);
		gtk_combo_box_set_active(ComboPri[2], (PMR_IRQ_PRI1 & 0x0C) >> 2);
		gtk_combo_box_set_active(ComboPri[3], (PMR_IRQ_PRI1 & 0x03));
		gtk_combo_box_set_active(ComboPri[4], (PMR_IRQ_PRI2 & 0xC0) >> 6);
		gtk_combo_box_set_active(ComboPri[5], (PMR_IRQ_PRI3 & 0x03));
		gtk_combo_box_set_active(ComboPri[6], (PMR_IRQ_PRI2 & 0x30) >> 4);
		gtk_combo_box_set_active(ComboPri[7], (PMR_IRQ_PRI2 & 0x0C) >> 2);
		gtk_combo_box_set_active(ComboPri[8], (PMR_IRQ_PRI2 & 0x03));
	}

	// Enable
	if (IRQShow_Ena) {
		gtk_toggle_button_set_active(CheckEna[0], PMR_IRQ_ENA1 & 0x80);
		gtk_toggle_button_set_active(CheckEna[1], PMR_IRQ_ENA1 & 0x40);
		gtk_toggle_button_set_active(CheckEna[2], PMR_IRQ_ENA1 & 0x20);
		gtk_toggle_button_set_active(CheckEna[3], PMR_IRQ_ENA1 & 0x10);
		gtk_toggle_button_set_active(CheckEna[4], PMR_IRQ_ENA1 & 0x08);
		gtk_toggle_button_set_active(CheckEna[5], PMR_IRQ_ENA1 & 0x04);
		gtk_toggle_button_set_active(CheckEna[6], PMR_IRQ_ENA1 & 0x02);
		gtk_toggle_button_set_active(CheckEna[7], PMR_IRQ_ENA1 & 0x01);
		gtk_toggle_button_set_active(CheckEna[8], PMR_IRQ_ENA2 & 0x20);
		gtk_toggle_button_set_active(CheckEna[9], PMR_IRQ_ENA2 & 0x10);
		gtk_toggle_button_set_active(CheckEna[10], PMR_IRQ_ENA2 & 0x08);
		gtk_toggle_button_set_active(CheckEna[11], PMR_IRQ_ENA2 & 0x04);
		gtk_toggle_button_set_active(CheckEna[12], PMR_IRQ_ENA4 & 0x80);
		gtk_toggle_button_set_active(CheckEna[13], PMR_IRQ_ENA4 & 0x40);
		gtk_toggle_button_set_active(CheckEna[14], PMR_IRQ_ENA2 & 0x02);
		gtk_toggle_button_set_active(CheckEna[15], PMR_IRQ_ENA2 & 0x01);
		gtk_toggle_button_set_active(CheckEna[16], PMR_IRQ_ENA3 & 0x80);
		gtk_toggle_button_set_active(CheckEna[17], PMR_IRQ_ENA3 & 0x40);
		gtk_toggle_button_set_active(CheckEna[18], PMR_IRQ_ENA3 & 0x20);
		gtk_toggle_button_set_active(CheckEna[19], PMR_IRQ_ENA3 & 0x10);
		gtk_toggle_button_set_active(CheckEna[20], PMR_IRQ_ENA3 & 0x08);
		gtk_toggle_button_set_active(CheckEna[21], PMR_IRQ_ENA3 & 0x04);
		gtk_toggle_button_set_active(CheckEna[22], PMR_IRQ_ENA3 & 0x02);
		gtk_toggle_button_set_active(CheckEna[23], PMR_IRQ_ENA3 & 0x01);
		gtk_toggle_button_set_active(CheckEna[24], PMR_IRQ_ENA4 & 0x04);
		gtk_toggle_button_set_active(CheckEna[25], PMR_IRQ_ENA4 & 0x02);
		gtk_toggle_button_set_active(CheckEna[26], PMR_IRQ_ENA4 & 0x01);
	}

	// Active
	if (IRQShow_Act) {
		gtk_toggle_button_set_active(CheckAct[0], PMR_IRQ_ACT1 & 0x80);
		gtk_toggle_button_set_active(CheckAct[1], PMR_IRQ_ACT1 & 0x40);
		gtk_toggle_button_set_active(CheckAct[2], PMR_IRQ_ACT1 & 0x20);
		gtk_toggle_button_set_active(CheckAct[3], PMR_IRQ_ACT1 & 0x10);
		gtk_toggle_button_set_active(CheckAct[4], PMR_IRQ_ACT1 & 0x08);
		gtk_toggle_button_set_active(CheckAct[5], PMR_IRQ_ACT1 & 0x04);
		gtk_toggle_button_set_active(CheckAct[6], PMR_IRQ_ACT1 & 0x02);
		gtk_toggle_button_set_active(CheckAct[7], PMR_IRQ_ACT1 & 0x01);
		gtk_toggle_button_set_active(CheckAct[8], PMR_IRQ_ACT2 & 0x20);
		gtk_toggle_button_set_active(CheckAct[9], PMR_IRQ_ACT2 & 0x10);
		gtk_toggle_button_set_active(CheckAct[10], PMR_IRQ_ACT2 & 0x08);
		gtk_toggle_button_set_active(CheckAct[11], PMR_IRQ_ACT2 & 0x04);
		gtk_toggle_button_set_active(CheckAct[12], PMR_IRQ_ACT4 & 0x80);
		gtk_toggle_button_set_active(CheckAct[13], PMR_IRQ_ACT4 & 0x40);
		gtk_toggle_button_set_active(CheckAct[14], PMR_IRQ_ACT2 & 0x02);
		gtk_toggle_button_set_active(CheckAct[15], PMR_IRQ_ACT2 & 0x01);
		gtk_toggle_button_set_active(CheckAct[16], PMR_IRQ_ACT3 & 0x80);
		gtk_toggle_button_set_active(CheckAct[17], PMR_IRQ_ACT3 & 0x40);
		gtk_toggle_button_set_active(CheckAct[18], PMR_IRQ_ACT3 & 0x20);
		gtk_toggle_button_set_active(CheckAct[19], PMR_IRQ_ACT3 & 0x10);
		gtk_toggle_button_set_active(CheckAct[20], PMR_IRQ_ACT3 & 0x08);
		gtk_toggle_button_set_active(CheckAct[21], PMR_IRQ_ACT3 & 0x04);
		gtk_toggle_button_set_active(CheckAct[22], PMR_IRQ_ACT3 & 0x02);
		gtk_toggle_button_set_active(CheckAct[23], PMR_IRQ_ACT3 & 0x01);
		gtk_toggle_button_set_active(CheckAct[24], PMR_IRQ_ACT4 & 0x04);
		gtk_toggle_button_set_active(CheckAct[25], PMR_IRQ_ACT4 & 0x02);
		gtk_toggle_button_set_active(CheckAct[26], PMR_IRQ_ACT4 & 0x01);
	}

	IRQWindow_InConfigs = 0;
}

static void ComboPri_changed(GtkComboBox *widget, gpointer data)
{
	if (IRQWindow_InConfigs) return;
	switch((int)data) {
		case 0: PMR_IRQ_PRI1 &= ~0xC0;
			PMR_IRQ_PRI1 |= gtk_combo_box_get_active(ComboPri[0]) << 6;
			break;
		case 1: PMR_IRQ_PRI1 &= ~0x30;
			PMR_IRQ_PRI1 |= gtk_combo_box_get_active(ComboPri[1]) << 4;
			break;
		case 2: PMR_IRQ_PRI1 &= ~0x0C;
			PMR_IRQ_PRI1 |= gtk_combo_box_get_active(ComboPri[2]) << 2;
			break;
		case 3: PMR_IRQ_PRI1 &= ~0x03;
			PMR_IRQ_PRI1 |= gtk_combo_box_get_active(ComboPri[3]);
			break;
		case 4: PMR_IRQ_PRI2 &= ~0xC0;
			PMR_IRQ_PRI2 |= gtk_combo_box_get_active(ComboPri[4]) << 6;
			break;
		case 5: PMR_IRQ_PRI3 &= ~0x03;
			PMR_IRQ_PRI3 |= gtk_combo_box_get_active(ComboPri[5]);
			break;
		case 6: PMR_IRQ_PRI2 &= ~0x30;
			PMR_IRQ_PRI2 |= gtk_combo_box_get_active(ComboPri[6]) << 4;
			break;
		case 7: PMR_IRQ_PRI2 &= ~0x0C;
			PMR_IRQ_PRI2 |= gtk_combo_box_get_active(ComboPri[7]) << 2;
			break;
		case 8: PMR_IRQ_PRI2 &= ~0x03;
			PMR_IRQ_PRI2 |= gtk_combo_box_get_active(ComboPri[8]);
			break;
	}
	MinxIRQ_Process();
	refresh_debug(1);
}

static void CheckEna_toggled(GtkToggleButton *togglebutton, gpointer data)
{
	uint8_t regn, mask;
	if (IRQWindow_InConfigs) return;
	switch ((int)data) {
		case  0: regn = 1; mask = 0x80; break;
		case  1: regn = 1; mask = 0x40; break;
		case  2: regn = 1; mask = 0x20; break;
		case  3: regn = 1; mask = 0x10; break;
		case  4: regn = 1; mask = 0x08; break;
		case  5: regn = 1; mask = 0x04; break;
		case  6: regn = 1; mask = 0x02; break;
		case  7: regn = 1; mask = 0x01; break;
		case  8: regn = 2; mask = 0x20; break;
		case  9: regn = 2; mask = 0x10; break;
		case 10: regn = 2; mask = 0x08; break;
		case 11: regn = 2; mask = 0x04; break;
		case 12: regn = 4; mask = 0x80; break;
		case 13: regn = 4; mask = 0x40; break;
		case 14: regn = 2; mask = 0x02; break;
		case 15: regn = 2; mask = 0x01; break;
		case 16: regn = 3; mask = 0x80; break;
		case 17: regn = 3; mask = 0x40; break;
		case 18: regn = 3; mask = 0x20; break;
		case 19: regn = 3; mask = 0x10; break;
		case 20: regn = 3; mask = 0x08; break;
		case 21: regn = 3; mask = 0x04; break;
		case 22: regn = 3; mask = 0x02; break;
		case 23: regn = 3; mask = 0x01; break;
		case 24: regn = 4; mask = 0x04; break;
		case 25: regn = 4; mask = 0x02; break;
		case 26: regn = 4; mask = 0x01; break;
		default: return;
	}
	if (gtk_toggle_button_get_active(togglebutton)) {
		switch (regn) {
			case 1: PMR_IRQ_ENA1 |= mask; break;
			case 2: PMR_IRQ_ENA2 |= mask; break;
			case 3: PMR_IRQ_ENA3 |= mask; break;
			case 4: PMR_IRQ_ENA4 |= mask; break;
		}
	} else {
		switch (regn) {
			case 1: PMR_IRQ_ENA1 &= ~mask; break;
			case 2: PMR_IRQ_ENA2 &= ~mask; break;
			case 3: PMR_IRQ_ENA3 &= ~mask; break;
			case 4: PMR_IRQ_ENA4 &= ~mask; break;
		}
	}
	MinxIRQ_Process();
	refresh_debug(1);
}

static void CheckAct_toggled(GtkToggleButton *togglebutton, gpointer data)
{
	uint8_t regn, mask;
	if (IRQWindow_InConfigs) return;
	switch ((int)data) {
		case  0: regn = 1; mask = 0x80; break;
		case  1: regn = 1; mask = 0x40; break;
		case  2: regn = 1; mask = 0x20; break;
		case  3: regn = 1; mask = 0x10; break;
		case  4: regn = 1; mask = 0x08; break;
		case  5: regn = 1; mask = 0x04; break;
		case  6: regn = 1; mask = 0x02; break;
		case  7: regn = 1; mask = 0x01; break;
		case  8: regn = 2; mask = 0x20; break;
		case  9: regn = 2; mask = 0x10; break;
		case 10: regn = 2; mask = 0x08; break;
		case 11: regn = 2; mask = 0x04; break;
		case 12: regn = 4; mask = 0x80; break;
		case 13: regn = 4; mask = 0x40; break;
		case 14: regn = 2; mask = 0x02; break;
		case 15: regn = 2; mask = 0x01; break;
		case 16: regn = 3; mask = 0x80; break;
		case 17: regn = 3; mask = 0x40; break;
		case 18: regn = 3; mask = 0x20; break;
		case 19: regn = 3; mask = 0x10; break;
		case 20: regn = 3; mask = 0x08; break;
		case 21: regn = 3; mask = 0x04; break;
		case 22: regn = 3; mask = 0x02; break;
		case 23: regn = 3; mask = 0x01; break;
		case 24: regn = 4; mask = 0x04; break;
		case 25: regn = 4; mask = 0x02; break;
		case 26: regn = 4; mask = 0x01; break;
		default: return;
	}
	if (gtk_toggle_button_get_active(togglebutton)) {
		switch (regn) {
			case 1: PMR_IRQ_ACT1 |= mask; break;
			case 2: PMR_IRQ_ACT2 |= mask; break;
			case 3: PMR_IRQ_ACT3 |= mask; break;
			case 4: PMR_IRQ_ACT4 |= mask; break;
		}
	} else {
		switch (regn) {
			case 1: PMR_IRQ_ACT1 &= ~mask; break;
			case 2: PMR_IRQ_ACT2 &= ~mask; break;
			case 3: PMR_IRQ_ACT3 &= ~mask; break;
			case 4: PMR_IRQ_ACT4 &= ~mask; break;
		}
	}
	MinxIRQ_Process();
	refresh_debug(1);
}

static void UpdateWidgetsOrder()
{
 	g_object_ref(G_OBJECT(FrameEna));
	gtk_container_remove(GTK_CONTAINER(MTable), GTK_WIDGET(FrameEna));
	g_object_ref(G_OBJECT(FrameAct));
	gtk_container_remove(GTK_CONTAINER(MTable), GTK_WIDGET(FrameAct));
	if (dclc_irqframes_on_1row) {
		gtk_table_attach(MTable, GTK_WIDGET(FrameEna), 2, 3, 0, 1, GTK_FILL | GTK_EXPAND, GTK_FILL, 2, 2);
		gtk_table_attach(MTable, GTK_WIDGET(FrameAct), 3, 4, 0, 1, GTK_FILL | GTK_EXPAND, GTK_FILL, 2, 2);
	} else {
		gtk_table_attach(MTable, GTK_WIDGET(FrameEna), 0, 1, 1, 2, GTK_FILL | GTK_EXPAND, GTK_FILL, 2, 2);
		gtk_table_attach(MTable, GTK_WIDGET(FrameAct), 1, 2, 1, 2, GTK_FILL | GTK_EXPAND, GTK_FILL, 2, 2);
	}
}

// --------------
// Menu callbacks
// --------------

static void IRQW_View_Priority(GtkWidget *widget, gpointer data)
{
	if (IRQWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/IRQ Priority");
	IRQShow_Pri = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (IRQShow_Pri) gtk_widget_show(GTK_WIDGET(FramePri));
	else gtk_widget_hide(GTK_WIDGET(FramePri));
	IRQWindow_Refresh(1);
}

static void IRQW_View_Enable(GtkWidget *widget, gpointer data)
{
	if (IRQWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/IRQ Enable");
	IRQShow_Ena = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (IRQShow_Ena) gtk_widget_show(GTK_WIDGET(FrameEna));
	else gtk_widget_hide(GTK_WIDGET(FrameEna));
	IRQWindow_Refresh(1);
}

static void IRQW_View_Active(GtkWidget *widget, gpointer data)
{
	if (IRQWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/IRQ Active");
	IRQShow_Act = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (IRQShow_Act) gtk_widget_show(GTK_WIDGET(FrameAct));
	else gtk_widget_hide(GTK_WIDGET(FrameAct));
	IRQWindow_Refresh(1);
}

static void IRQW_View_Frame1Row(GtkWidget *widget, gpointer data)
{
	if (IRQWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Frames in single-row");
	dclc_irqframes_on_1row = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	UpdateWidgetsOrder();
}

static void IRQW_RefreshNow(GtkWidget *widget, gpointer data)
{
	refresh_debug(1);
}

static void IRQW_Refresh(GtkWidget *widget, gpointer data)
{
	int val, index = (int)data;
	static int lastrefrindex = -2;

	if (lastrefrindex == index) return;
	lastrefrindex = index;
	if (IRQWindow_InConfigs) return;

	if (index >= 0) {
		dclc_irqwin_refresh = index;
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(IRQWindow, "Custom refresh rate", "Frames skip per refresh:", &val, dclc_irqwin_refresh, 4, 0, 0, 1000)) {
			dclc_irqwin_refresh = val;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

static gint IRQWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(IRQWindow));
	return TRUE;
}

static gboolean IRQWindow_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{
	if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) IRQWindow_minimized = event->new_window_state & GDK_WINDOW_STATE_ICONIFIED;
	return TRUE;
}

static GtkItemFactoryEntry IRQWindow_MenuItems[] = {
	{ "/_View",                              NULL,           NULL,                     0, "<Branch>" },
	{ "/View/IRQ Priority",                  NULL,           IRQW_View_Priority,       0, "<CheckItem>" },
	{ "/View/IRQ Enable",                    NULL,           IRQW_View_Enable,         0, "<CheckItem>" },
	{ "/View/IRQ Active",                    NULL,           IRQW_View_Active,         0, "<CheckItem>" },
	{ "/View/sep1",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/View/Frames in single-row",          NULL,           IRQW_View_Frame1Row,      0, "<CheckItem>" },

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
	{ "/Refresh/Now!",                       NULL,           IRQW_RefreshNow,          0, "<Item>" },
	{ "/Refresh/sep1",                       NULL,           NULL,                     0, "<Separator>" },
	{ "/Refresh/100% 72fps",                 NULL,           IRQW_Refresh,             0, "<RadioItem>" },
	{ "/Refresh/ 50% 36fps",                 NULL,           IRQW_Refresh,             1, "/Refresh/100% 72fps" },
	{ "/Refresh/ 33% 24fps",                 NULL,           IRQW_Refresh,             2, "/Refresh/100% 72fps" },
	{ "/Refresh/ 25% 18fps",                 NULL,           IRQW_Refresh,             3, "/Refresh/100% 72fps" },
	{ "/Refresh/ 17% 12fps",                 NULL,           IRQW_Refresh,             5, "/Refresh/100% 72fps" },
	{ "/Refresh/ 12%  9fps",                 NULL,           IRQW_Refresh,             7, "/Refresh/100% 72fps" },
	{ "/Refresh/  8%  6fps",                 NULL,           IRQW_Refresh,            11, "/Refresh/100% 72fps" },
	{ "/Refresh/  3%  2fps",                 NULL,           IRQW_Refresh,            35, "/Refresh/100% 72fps" },
	{ "/Refresh/  1%  1fps",                 NULL,           IRQW_Refresh,            71, "/Refresh/100% 72fps" },
	{ "/Refresh/Custom...",                  NULL,           IRQW_Refresh,            -1, "/Refresh/100% 72fps" },
};
static gint IRQWindow_MenuItemsNum = sizeof(IRQWindow_MenuItems) / sizeof(*IRQWindow_MenuItems);

// ----------
// IRQ Window
// ----------

static char *IRQPri_Txt[] = {
	"PRC IRQs ($03~$04):",
	"Timer 2 IRQs ($05~$06):",
	"Timer 3 IRQs ($07~$08):",
	"Timer 1 IRQs ($09~$0A):",
	"256 Hz IRQs ($0B~$0E):",
	"IR/Shock IRQs ($13~$14):",
	"Cartridge IRQs ($0F~$10):",
	"Keypad IRQs ($15~$1C):",
	"Unknown IRQs ($1D~$1F):"
};

static char *IRQEnaAct_Txt[] = {
	"PRC Copy Complete ($03)",
	"PRC Frame Divider Overflow ($04)",
	"Timer 2-B Underflow ($05)",
	"Timer 2-A Underflow 8-Bits ($06)",
	"Timer 1-B Underflow ($07)",
	"Timer 1-A Underflow 8-Bits ($08)",
	"Timer 3 Underflow ($09)",
	"Timer 3 Pivot ($0A)",
	"32 Hz ($0B)",
	" 8 Hz ($0C)",
	" 2 Hz ($0D)",
	" 1 Hz ($0E)",
	"IR Receiver ($13)",
	"Shock Sensor ($14)",
	"Cartridge Ejected ($0F)",
	"Cartridge IRQ ($10)",
	"Power Key ($15)",
	"Right Key ($16)",
	"Left Key ($17)",
	"Down Key ($18)",
	"Up Key ($19)",
	"C Key ($1A)",
	"B Key ($1B)",
	"A Key ($1C)",
	"Unknown 1 ($1D)",
	"Unknown 2 ($1E)",
	"Unknown 3 ($1F)"
};

static void LoadPriOnCombo(GtkComboBox *combo)
{
	gtk_combo_box_append_text(combo, "0 - IRQs Disabled");
	gtk_combo_box_append_text(combo, "1 - Low Priority");
	gtk_combo_box_append_text(combo, "2 - Medium Priority");
	gtk_combo_box_append_text(combo, "3 - High Priority");
}

int IRQWindow_Create(void)
{
	int i;

	// Window
	IRQWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(IRQWindow), "IRQ View");
	gtk_widget_set_size_request(GTK_WIDGET(IRQWindow), 200, 100);
	gtk_window_set_default_size(IRQWindow, 420, 300);
	g_signal_connect(IRQWindow, "delete_event", G_CALLBACK(IRQWindow_delete_event), NULL);
	g_signal_connect(IRQWindow, "window-state-event", G_CALLBACK(IRQWindow_state_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(IRQWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Menu bar
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, IRQWindow_MenuItemsNum, IRQWindow_MenuItems, NULL);
	gtk_window_add_accel_group(IRQWindow, AccelGroup);
	MenuBar = GTK_MENU_BAR(gtk_item_factory_get_widget(ItemFactory, "<main>"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MenuBar), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MenuBar));

	// Label that warn when running full speed
	LabelRunFull = GTK_LABEL(gtk_label_new("To view content you must stop emulation or run in debug frames/steps."));
	gtk_box_pack_start(VBox1, GTK_WIDGET(LabelRunFull), FALSE, TRUE, 0);

	// Scrolling window with vertical box
	IRQSW = GTK_SCROLLED_WINDOW(gtk_scrolled_window_new(NULL, NULL));
	gtk_scrolled_window_set_policy(IRQSW, GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
	gtk_container_add(GTK_CONTAINER(VBox1), GTK_WIDGET(IRQSW));
	gtk_widget_show(GTK_WIDGET(IRQSW));
	MTable = GTK_TABLE(gtk_table_new(2, 4, FALSE));
	gtk_scrolled_window_add_with_viewport(IRQSW, GTK_WIDGET(MTable));
	gtk_widget_show(GTK_WIDGET(MTable));

	// Priority
	FramePri = GTK_FRAME(gtk_frame_new(" IRQ Priority "));
	gtk_table_attach(MTable, GTK_WIDGET(FramePri), 0, 2, 0, 1, GTK_FILL | GTK_EXPAND, GTK_FILL, 2, 2);
	gtk_widget_show(GTK_WIDGET(FramePri));
	TablePri = GTK_TABLE(gtk_table_new(9, 2, FALSE));
	gtk_container_add(GTK_CONTAINER(FramePri), GTK_WIDGET(TablePri));
	gtk_widget_show(GTK_WIDGET(TablePri));
	for (i=0; i<9; i++) {
		LabelsPri[i] = GTK_LABEL(gtk_label_new(IRQPri_Txt[i]));
		gtk_misc_set_alignment(GTK_MISC(LabelsPri[i]), 0.0, 0.5);
		gtk_label_set_justify(LabelsPri[i], GTK_JUSTIFY_LEFT);
		gtk_table_attach(TablePri, GTK_WIDGET(LabelsPri[i]), 0, 1, i, i+1, GTK_FILL, GTK_FILL, 2, 2);
		gtk_widget_show(GTK_WIDGET(LabelsPri[i]));
		ComboPri[i] = GTK_COMBO_BOX(gtk_combo_box_new_text());
		g_signal_connect(ComboPri[i], "changed", G_CALLBACK(ComboPri_changed), (gpointer)i);
		LoadPriOnCombo(ComboPri[i]);
		gtk_table_attach(TablePri, GTK_WIDGET(ComboPri[i]), 1, 2, i, i+1, GTK_FILL | GTK_EXPAND, GTK_FILL, 2, 2);
		gtk_widget_show(GTK_WIDGET(ComboPri[i]));
	}

	// Enable
	FrameEna = GTK_FRAME(gtk_frame_new(" IRQ Enable "));
	gtk_table_attach(MTable, GTK_WIDGET(FrameEna), 2, 3, 0, 1, GTK_FILL | GTK_EXPAND, GTK_FILL, 2, 2);
	gtk_widget_show(GTK_WIDGET(FrameEna));
	VBoxEna = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FrameEna), GTK_WIDGET(VBoxEna));
	gtk_widget_show(GTK_WIDGET(VBoxEna));
	for (i=0; i<27; i++) {
		CheckEna[i] = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label(IRQEnaAct_Txt[i]));
		g_signal_connect(CheckEna[i], "toggled", G_CALLBACK(CheckEna_toggled), (gpointer)i);
		gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(CheckEna[i]), TRUE);
		gtk_box_pack_start(VBoxEna, GTK_WIDGET(CheckEna[i]), FALSE, TRUE, 0);
		gtk_widget_show(GTK_WIDGET(CheckEna[i]));
	}

	// Active
	FrameAct = GTK_FRAME(gtk_frame_new(" IRQ Active "));
	gtk_table_attach(MTable, GTK_WIDGET(FrameAct), 3, 4, 0, 1, GTK_FILL | GTK_EXPAND, GTK_FILL, 2, 2);
	gtk_widget_show(GTK_WIDGET(FrameAct));
	VBoxAct = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FrameAct), GTK_WIDGET(VBoxAct));
	gtk_widget_show(GTK_WIDGET(VBoxAct));
	for (i=0; i<27; i++) {
		CheckAct[i] = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label(IRQEnaAct_Txt[i]));
		g_signal_connect(CheckAct[i], "toggled", G_CALLBACK(CheckAct_toggled), (gpointer)i);
		gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(CheckAct[i]), TRUE);
		gtk_box_pack_start(VBoxAct, GTK_WIDGET(CheckAct[i]), FALSE, TRUE, 0);
		gtk_widget_show(GTK_WIDGET(CheckAct[i]));
	}

	return 1;
}

void IRQWindow_Destroy(void)
{
	int x, y, width, height;
	if (gtk_widget_get_realized(GTK_WIDGET(IRQWindow))) {
		gtk_widget_show(GTK_WIDGET(IRQWindow));
		gtk_window_deiconify(IRQWindow);
		gtk_window_get_position(IRQWindow, &x, &y);
		gtk_window_get_size(IRQWindow, &width, &height);
		dclc_irqwin_winx = x;
		dclc_irqwin_winy = y;
		dclc_irqwin_winw = width;
		dclc_irqwin_winh = height;
	}
}

void IRQWindow_Activate(void)
{
	IRQWindow_Render(1);
	gtk_widget_realize(GTK_WIDGET(IRQWindow));
	if ((dclc_irqwin_winx > -15) && (dclc_irqwin_winy > -16)) {
		gtk_window_move(IRQWindow, dclc_irqwin_winx, dclc_irqwin_winy);
	}
	if ((dclc_irqwin_winw > 0) && (dclc_irqwin_winh > 0)) {
		gtk_window_resize(IRQWindow, dclc_irqwin_winw, dclc_irqwin_winh);
	}
	gtk_widget_show(GTK_WIDGET(IRQWindow));
	gtk_window_present(IRQWindow);
}

void IRQWindow_UpdateConfigs(void)
{
	GtkWidget *widg;

	IRQWindow_InConfigs = 1;

	widg = gtk_item_factory_get_item(ItemFactory, "/View/IRQ Priority");
	if (IRQShow_Pri) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/IRQ Enable");
	if (IRQShow_Ena) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/IRQ Active");
	if (IRQShow_Act) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Frames in single-row");
	if (dclc_irqframes_on_1row) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	UpdateWidgetsOrder();

	switch (dclc_irqwin_refresh) {
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

	IRQWindow_InConfigs = 0;
}

void IRQWindow_Sensitive(int enabled)
{
	if (enabled) {
		gtk_widget_hide(GTK_WIDGET(LabelRunFull));
		gtk_widget_show(GTK_WIDGET(IRQSW));
	} else {
		gtk_widget_show(GTK_WIDGET(LabelRunFull));
		gtk_widget_hide(GTK_WIDGET(IRQSW));
	}
}

void IRQWindow_Refresh(int now)
{
	static int refreshcnt = 0;
	if ((refreshcnt <= 0) || (now)) {
		refreshcnt = dclc_irqwin_refresh;
		if (!now) {
			if (!gtk_widget_get_visible(GTK_WIDGET(IRQWindow)) || IRQWindow_minimized) return;
		}
		IRQWindow_Render(0);
	} else refreshcnt--;
}
