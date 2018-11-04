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

#include "MiscWindow.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

static int MiscWindow_InConfigs = 0;

GtkWindow *MiscWindow;
static int MiscWindow_minimized;
static GtkItemFactory *ItemFactory;
static GtkAccelGroup *AccelGroup;
static GtkBox *VBox1;
static GtkMenuBar *MenuBar;
static GtkLabel *LabelRunFull;
static GtkScrolledWindow *MiscSW;
static GtkBox *VBox2;
static GtkFrame *FramePRC;
static GtkBox *VBoxPRC;
static GtkLabel *LabelsPRC[8];
static GtkFrame *FrameColorPRC;
static GtkBox *VBoxColorPRC;
static GtkLabel *LabelsColorPRC[11];
static GtkFrame *FrameLCD;
static GtkBox *VBoxLCD;
static GtkLabel *LabelsLCD[12];
static GtkFrame *FrameEEPROM;
static GtkBox *VBoxEEPROM;
static GtkLabel *LabelsEEPROM[5];
static GtkFrame *FrameMulticart;
static GtkBox *VBoxMulticart;
static GtkLabel *LabelsMulticart[10];

// Enable/Disable frames
static int MiscShow_PRC = 1;
static int MiscShow_ColorPRC = 1;
static int MiscShow_LCD = 1;
static int MiscShow_EEPROM = 1;
static int MiscShow_Multicart = 1;

// ---------------
// Get information
// ---------------

static char *EEPROM_TxtOperState[] = {
	"Device ID",
	"High Address Byte",
	"Low Address Byte",
	"Write Byte",
	"Read Byte"
};

static char *Multicart_TxtType[] = {
	"0 - Disabled",
	"1 - Flash 512KB (AM29LV040B)",
	"2 - Lupin 512KB (AM29LV040B)"
};

static char *Multicart_TxtBusCycle[] = {
	"1st", "2nd", "3rd", "4th", "5th"
};

static char *Multicart_TxtCommand[] = {
	"None", "Programming", "Erasing"
};

static char *ColorPRC_Access[] = {
	"Fixed", "Post-Increment", "Post-Decrement", "Pre-Increment"
};

static void MiscWindow_Render(int force)
{
	char tmp[PMTMPV];
	int val;

	// PRC
	if (MiscShow_PRC) {
		sprintf(tmp, "Copy to LCD: %s", MinxPRC.PRCMode ? "Yes" : "No");
		gtk_label_set_text(LabelsPRC[0], tmp);
		sprintf(tmp, "Map Render: %s", (MinxPRC.PRCMode == 2) && (PMR_PRC_MODE & 0x02) ? "Yes" : "No");
		gtk_label_set_text(LabelsPRC[1], tmp);
		sprintf(tmp, "Map Tile Base: $%06X", (int)MinxPRC.PRCBGBase);
		gtk_label_set_text(LabelsPRC[2], tmp);
		sprintf(tmp, "Sprites Render: %s", (MinxPRC.PRCMode == 2) && (PMR_PRC_MODE & 0x04) ? "Yes" : "No");
		gtk_label_set_text(LabelsPRC[3], tmp);
		sprintf(tmp, "Sprite Tile Base: $%06X", (int)MinxPRC.PRCSprBase);
		gtk_label_set_text(LabelsPRC[4], tmp);
		val = (MinxPRC.PRCRateMatch >> 4) + 1;
		sprintf(tmp, "Frame Rate: /%i (%i Hz)", val, 72 / val);
		gtk_label_set_text(LabelsPRC[5], tmp);
		sprintf(tmp, "Frame Match: %i (%i)", (int)(PMR_PRC_RATE >> 4), (int)(MinxPRC.PRCRateMatch >> 4));
		gtk_label_set_text(LabelsPRC[6], tmp);
		val = MinxPRC.PRCCnt >> 24;
		sprintf(tmp, "PRC Counter: $%02X, %i", val, val);
		gtk_label_set_text(LabelsPRC[7], tmp);
	}

	// Color PRC
	if (MiscShow_ColorPRC) {
		sprintf(tmp, "Color available: %s", PRCColorMap ? "Yes" : "No");
		gtk_label_set_text(LabelsColorPRC[0], tmp);
		if (PRCColorMap) {
			sprintf(tmp, "Color Mode: %s%s", PokeMini_ColorFormat ? "4x4" : "8x8", (PRCColorFlags & 2) ? " +RAM Copy" : "");
			gtk_label_set_text(LabelsColorPRC[1], tmp);
			sprintf(tmp, "Unlock Code <%04X< (5ACE)", (int)MinxColorPRC.UnlockCode);
			gtk_label_set_text(LabelsColorPRC[2], tmp);
			sprintf(tmp, "Unlocked: %s", MinxColorPRC.Unlocked ? "Yes" : "No");
			gtk_label_set_text(LabelsColorPRC[3], tmp);
			sprintf(tmp, "CVRAM Active Page: %i", (int)MinxColorPRC.ActivePage);
			gtk_label_set_text(LabelsColorPRC[4], tmp);
			sprintf(tmp, "CVRAM Address: $%04X", (int)MinxColorPRC.Address);
			gtk_label_set_text(LabelsColorPRC[5], tmp);
			sprintf(tmp, "Access Mode: %s", ColorPRC_Access[MinxColorPRC.Access & 3]);
			gtk_label_set_text(LabelsColorPRC[6], tmp);
			val = MinxColorPRC.LNColor0;
			sprintf(tmp, "Low Nibble Pixel 0 Color: $%02X, %i", val, val);
			gtk_label_set_text(LabelsColorPRC[7], tmp);
			val = MinxColorPRC.HNColor0;
			sprintf(tmp, "High Nibble Pixel 0 Color: $%02X, %i", val, val);
			gtk_label_set_text(LabelsColorPRC[8], tmp);
			val = MinxColorPRC.LNColor1;
			sprintf(tmp, "Low Nibble Pixel 1 Color: $%02X, %i", val, val);
			gtk_label_set_text(LabelsColorPRC[9], tmp);
			val = MinxColorPRC.HNColor1;
			sprintf(tmp, "High Nibble Pixel 1 Color: $%02X, %i", val, val);
			gtk_label_set_text(LabelsColorPRC[10], tmp);
		} else {
			gtk_label_set_text(LabelsColorPRC[1], "----");
			gtk_label_set_text(LabelsColorPRC[2], "----");
			gtk_label_set_text(LabelsColorPRC[3], "----");
			gtk_label_set_text(LabelsColorPRC[4], "----");
			gtk_label_set_text(LabelsColorPRC[5], "----");
			gtk_label_set_text(LabelsColorPRC[6], "----");
			gtk_label_set_text(LabelsColorPRC[7], "----");
			gtk_label_set_text(LabelsColorPRC[8], "----");
			gtk_label_set_text(LabelsColorPRC[9], "----");
			gtk_label_set_text(LabelsColorPRC[10], "----");
		}
	}

	// LCD
	if (MiscShow_LCD) {
		sprintf(tmp, "Display On: %s", MinxLCD.DisplayOn ? "Yes" : "No");
		gtk_label_set_text(LabelsLCD[0], tmp);
		sprintf(tmp, "Column: %i%c", (int)MinxLCD.Column, MinxLCD.RequireDummyR ? '*' : ' ');
		gtk_label_set_text(LabelsLCD[1], tmp);
		sprintf(tmp, "Page: %i", (int)MinxLCD.Page);
		gtk_label_set_text(LabelsLCD[2], tmp);
		sprintf(tmp, "Start Line: %i", (int)MinxLCD.StartLine);
		gtk_label_set_text(LabelsLCD[3], tmp);
		sprintf(tmp, "Next CMD is Contrast: %s", MinxLCD.SetContrast ? "Yes" : "No");
		gtk_label_set_text(LabelsLCD[4], tmp);
		sprintf(tmp, "Contrast: %i", (int)MinxLCD.Contrast);
		gtk_label_set_text(LabelsLCD[5], tmp);
		sprintf(tmp, "Segment Direction: %s", MinxLCD.SegmentDir ? "Inverted" : "Normal");
		gtk_label_set_text(LabelsLCD[6], tmp);
		sprintf(tmp, "Max Contrast: %s", MinxLCD.MaxContrast ? "Yes" : "No");
		gtk_label_set_text(LabelsLCD[7], tmp);
		sprintf(tmp, "Set All Pixels: %s", MinxLCD.SetAllPix ? "Yes" : "No");
		gtk_label_set_text(LabelsLCD[8], tmp);
		sprintf(tmp, "Invert All Pixels: %s", MinxLCD.InvAllPix ? "Yes" : "No");
		gtk_label_set_text(LabelsLCD[9], tmp);
		sprintf(tmp, "Row Order: %s", MinxLCD.RowOrder ? "Top->Bottom" : "Bottom->Top");
		gtk_label_set_text(LabelsLCD[10], tmp);
		sprintf(tmp, "Read Modify Write: %s (%i)", MinxLCD.ReadModifyMode ? "On" : "Off", MinxLCD.RMWColumn);
		gtk_label_set_text(LabelsLCD[11], tmp);
	}

	// EEPROM
	if (MiscShow_EEPROM) {
		sprintf(tmp, "Listening: %s", MinxIO.ListenState ? "Yes" : "No");
		gtk_label_set_text(LabelsEEPROM[0], tmp);
		if (MinxIO.ListenState) {
			sprintf(tmp, "Operation State: Waiting %s", EEPROM_TxtOperState[MinxIO.OperState]);
		} else {
			strcpy(tmp, "Operation State: Idle");
		}
		gtk_label_set_text(LabelsEEPROM[1], tmp);
		sprintf(tmp, "Address: $%04X", (int)(MinxIO.EEPAddress & 0x1FFF));
		gtk_label_set_text(LabelsEEPROM[2], tmp);
		sprintf(tmp, "Data Latch: $%02X", (int)MinxIO.EEPData);
		gtk_label_set_text(LabelsEEPROM[3], tmp);
		sprintf(tmp, "Data Bit Offset: %i", (int)MinxIO.EEPBit);
		gtk_label_set_text(LabelsEEPROM[4], tmp);
	}

	// Multicart
	if (MiscShow_Multicart) {
		sprintf(tmp, "Multicart type: %s", Multicart_TxtType[PM_MM_Type]);
		gtk_label_set_text(LabelsMulticart[0], tmp);
		sprintf(tmp, "ROM Changed: %s", PM_MM_Dirty ? "Yes" : "No");
		gtk_label_set_text(LabelsMulticart[1], tmp);
		sprintf(tmp, "ROM Offset: $%06X", (int)PM_MM_Offset);
		gtk_label_set_text(LabelsMulticart[2], tmp);
		sprintf(tmp, "Bus Cycle: %s", Multicart_TxtBusCycle[PM_MM_BusCycle]);
		gtk_label_set_text(LabelsMulticart[3], tmp);
		sprintf(tmp, "Product ID Mode: %s", PM_MM_GetID ? "Yes" : "No");
		gtk_label_set_text(LabelsMulticart[4], tmp);
		sprintf(tmp, "Bypass Mode: %s", PM_MM_Bypass ? "Yes" : "No");
		gtk_label_set_text(LabelsMulticart[5], tmp);
		sprintf(tmp, "Command: %s", Multicart_TxtCommand[PM_MM_Command]);
		gtk_label_set_text(LabelsMulticart[6], tmp);
		sprintf(tmp, "Last erase start: $%06X", PM_MM_LastErase_Start);
		gtk_label_set_text(LabelsMulticart[7], tmp);
		sprintf(tmp, "Last erase end: $%06X", PM_MM_LastErase_End);
		gtk_label_set_text(LabelsMulticart[8], tmp);
		sprintf(tmp, "Last programmed address: $%06X", PM_MM_LastProg);
		gtk_label_set_text(LabelsMulticart[9], tmp);
	}
}

// --------------
// Menu callbacks
// --------------

static void MiscW_View_PRC(GtkWidget *widget, gpointer data)
{
	if (MiscWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/PRC Status");
	MiscShow_PRC = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (MiscShow_PRC) gtk_widget_show(GTK_WIDGET(FramePRC));
	else gtk_widget_hide(GTK_WIDGET(FramePRC));
	MiscWindow_Refresh(1);
}

static void MiscW_View_ColorPRC(GtkWidget *widget, gpointer data)
{
	if (MiscWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Color PRC Status");
	MiscShow_ColorPRC = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (MiscShow_ColorPRC) gtk_widget_show(GTK_WIDGET(FrameColorPRC));
	else gtk_widget_hide(GTK_WIDGET(FrameColorPRC));
	MiscWindow_Refresh(1);
}

static void MiscW_View_LCD(GtkWidget *widget, gpointer data)
{
	if (MiscWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/LCD Internals");
	MiscShow_LCD = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (MiscShow_LCD) gtk_widget_show(GTK_WIDGET(FrameLCD));
	else gtk_widget_hide(GTK_WIDGET(FrameLCD));
	MiscWindow_Refresh(1);
}

static void MiscW_View_EEPROM(GtkWidget *widget, gpointer data)
{
	if (MiscWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/EEPROM Internals");
	MiscShow_EEPROM = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (MiscShow_EEPROM) gtk_widget_show(GTK_WIDGET(FrameEEPROM));
	else gtk_widget_hide(GTK_WIDGET(FrameEEPROM));
	MiscWindow_Refresh(1);
}

static void MiscW_View_Multicart(GtkWidget *widget, gpointer data)
{
	if (MiscWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Multicart Internals");
	MiscShow_Multicart = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (MiscShow_Multicart) gtk_widget_show(GTK_WIDGET(FrameMulticart));
	else gtk_widget_hide(GTK_WIDGET(FrameMulticart));
	MiscWindow_Refresh(1);
}

static void MiscW_RefreshNow(GtkWidget *widget, gpointer data)
{
	refresh_debug(1);
}

static void MiscW_Refresh(GtkWidget *widget, gpointer data)
{
	int val, index = (int)data;
	static int lastrefrindex = -2;

	if (lastrefrindex == index) return;
	lastrefrindex = index;
	if (MiscWindow_InConfigs) return;

	if (index >= 0) {
		dclc_miscwin_refresh = index;
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(MiscWindow, "Custom refresh rate", "Frames skip per refresh:", &val, dclc_miscwin_refresh, 4, 0, 0, 1000)) {
			dclc_miscwin_refresh = val;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

static gint MiscWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(MiscWindow));
	return TRUE;
}

static gboolean MiscWindow_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{
	if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) MiscWindow_minimized = event->new_window_state & GDK_WINDOW_STATE_ICONIFIED;
	return TRUE;
}

static GtkItemFactoryEntry MiscWindow_MenuItems[] = {
	{ "/_View",                              NULL,           NULL,                     0, "<Branch>" },
	{ "/View/PRC Status",                    NULL,           MiscW_View_PRC,           0, "<CheckItem>" },
	{ "/View/Color PRC Status",              NULL,           MiscW_View_ColorPRC,      0, "<CheckItem>" },
	{ "/View/LCD Internals",                 NULL,           MiscW_View_LCD,           0, "<CheckItem>" },
	{ "/View/EEPROM Internals",              NULL,           MiscW_View_EEPROM,        0, "<CheckItem>" },
	{ "/View/Multicart Internals",           NULL,           MiscW_View_Multicart,     0, "<CheckItem>" },

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
	{ "/Refresh/Now!",                       NULL,           MiscW_RefreshNow,         0, "<Item>" },
	{ "/Refresh/sep1",                       NULL,           NULL,                     0, "<Separator>" },
	{ "/Refresh/100% 72fps",                 NULL,           MiscW_Refresh,            0, "<RadioItem>" },
	{ "/Refresh/ 50% 36fps",                 NULL,           MiscW_Refresh,            1, "/Refresh/100% 72fps" },
	{ "/Refresh/ 33% 24fps",                 NULL,           MiscW_Refresh,            2, "/Refresh/100% 72fps" },
	{ "/Refresh/ 25% 18fps",                 NULL,           MiscW_Refresh,            3, "/Refresh/100% 72fps" },
	{ "/Refresh/ 17% 12fps",                 NULL,           MiscW_Refresh,            5, "/Refresh/100% 72fps" },
	{ "/Refresh/ 12%  9fps",                 NULL,           MiscW_Refresh,            7, "/Refresh/100% 72fps" },
	{ "/Refresh/  8%  6fps",                 NULL,           MiscW_Refresh,           11, "/Refresh/100% 72fps" },
	{ "/Refresh/  3%  2fps",                 NULL,           MiscW_Refresh,           35, "/Refresh/100% 72fps" },
	{ "/Refresh/  1%  1fps",                 NULL,           MiscW_Refresh,           71, "/Refresh/100% 72fps" },
	{ "/Refresh/Custom...",                  NULL,           MiscW_Refresh,           -1, "/Refresh/100% 72fps" },
};
static gint MiscWindow_MenuItemsNum = sizeof(MiscWindow_MenuItems) / sizeof(*MiscWindow_MenuItems);

// -----------
// Misc Window
// -----------

int MiscWindow_Create(void)
{
	int i;

	// Window
	MiscWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(MiscWindow), "Misc. View");
	gtk_widget_set_size_request(GTK_WIDGET(MiscWindow), 200, 100);
	gtk_window_set_default_size(MiscWindow, 420, 200);
	g_signal_connect(MiscWindow, "delete_event", G_CALLBACK(MiscWindow_delete_event), NULL);
	g_signal_connect(MiscWindow, "window-state-event", G_CALLBACK(MiscWindow_state_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(MiscWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Menu bar
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, MiscWindow_MenuItemsNum, MiscWindow_MenuItems, NULL);
	gtk_window_add_accel_group(MiscWindow, AccelGroup);
	MenuBar = GTK_MENU_BAR(gtk_item_factory_get_widget(ItemFactory, "<main>"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MenuBar), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MenuBar));

	// Label that warn when running full speed
	LabelRunFull = GTK_LABEL(gtk_label_new("To view content you must stop emulation or run in debug frames/steps."));
	gtk_box_pack_start(VBox1, GTK_WIDGET(LabelRunFull), FALSE, TRUE, 0);

	// Scrolling window with vertical box
	MiscSW = GTK_SCROLLED_WINDOW(gtk_scrolled_window_new(NULL, NULL));
	gtk_scrolled_window_set_policy(MiscSW, GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
	gtk_container_add(GTK_CONTAINER(VBox1), GTK_WIDGET(MiscSW));
	gtk_widget_show(GTK_WIDGET(MiscSW));
	VBox2 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_scrolled_window_add_with_viewport(MiscSW, GTK_WIDGET(VBox2));
	gtk_widget_show(GTK_WIDGET(VBox2));

	// PRC
	FramePRC = GTK_FRAME(gtk_frame_new(" PRC Status "));
	gtk_box_pack_start(VBox2, GTK_WIDGET(FramePRC), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(FramePRC));
	VBoxPRC = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FramePRC), GTK_WIDGET(VBoxPRC));
	gtk_widget_show(GTK_WIDGET(VBoxPRC));
	for (i=0; i<8; i++) {
		LabelsPRC[i] = GTK_LABEL(gtk_label_new("???"));
		gtk_misc_set_alignment(GTK_MISC(LabelsPRC[i]), 0.0, 0.5);
		gtk_label_set_justify(LabelsPRC[i], GTK_JUSTIFY_LEFT);
		gtk_box_pack_start(VBoxPRC, GTK_WIDGET(LabelsPRC[i]), TRUE, TRUE, 2);
		gtk_widget_show(GTK_WIDGET(LabelsPRC[i]));
	}

	// Color PRC
	FrameColorPRC = GTK_FRAME(gtk_frame_new(" Color PRC Status "));
	gtk_box_pack_start(VBox2, GTK_WIDGET(FrameColorPRC), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(FrameColorPRC));
	VBoxColorPRC = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FrameColorPRC), GTK_WIDGET(VBoxColorPRC));
	gtk_widget_show(GTK_WIDGET(VBoxColorPRC));
	for (i=0; i<11; i++) {
		LabelsColorPRC[i] = GTK_LABEL(gtk_label_new("???"));
		gtk_misc_set_alignment(GTK_MISC(LabelsColorPRC[i]), 0.0, 0.5);
		gtk_label_set_justify(LabelsColorPRC[i], GTK_JUSTIFY_LEFT);
		gtk_box_pack_start(VBoxColorPRC, GTK_WIDGET(LabelsColorPRC[i]), TRUE, TRUE, 2);
		gtk_widget_show(GTK_WIDGET(LabelsColorPRC[i]));
	}

	// LCD
	FrameLCD = GTK_FRAME(gtk_frame_new(" LCD Internals "));
	gtk_box_pack_start(VBox2, GTK_WIDGET(FrameLCD), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(FrameLCD));
	VBoxLCD = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FrameLCD), GTK_WIDGET(VBoxLCD));
	gtk_widget_show(GTK_WIDGET(VBoxLCD));
	for (i=0; i<12; i++) {
		LabelsLCD[i] = GTK_LABEL(gtk_label_new("???"));
		gtk_misc_set_alignment(GTK_MISC(LabelsLCD[i]), 0.0, 0.5);
		gtk_label_set_justify(LabelsLCD[i], GTK_JUSTIFY_LEFT);
		gtk_box_pack_start(VBoxLCD, GTK_WIDGET(LabelsLCD[i]), TRUE, TRUE, 2);
		gtk_widget_show(GTK_WIDGET(LabelsLCD[i]));
	}

	// EEPROM
	FrameEEPROM = GTK_FRAME(gtk_frame_new(" EEPROM Internals "));
	gtk_box_pack_start(VBox2, GTK_WIDGET(FrameEEPROM), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(FrameEEPROM));
	VBoxEEPROM = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FrameEEPROM), GTK_WIDGET(VBoxEEPROM));
	gtk_widget_show(GTK_WIDGET(VBoxEEPROM));
	for (i=0; i<5; i++) {
		LabelsEEPROM[i] = GTK_LABEL(gtk_label_new("???"));
		gtk_misc_set_alignment(GTK_MISC(LabelsEEPROM[i]), 0.0, 0.5);
		gtk_label_set_justify(LabelsEEPROM[i], GTK_JUSTIFY_LEFT);
		gtk_box_pack_start(VBoxEEPROM, GTK_WIDGET(LabelsEEPROM[i]), TRUE, TRUE, 2);
		gtk_widget_show(GTK_WIDGET(LabelsEEPROM[i]));
	}

	// Multicart
	FrameMulticart = GTK_FRAME(gtk_frame_new(" Multicart Internals "));
	gtk_box_pack_start(VBox2, GTK_WIDGET(FrameMulticart), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(FrameMulticart));
	VBoxMulticart = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FrameMulticart), GTK_WIDGET(VBoxMulticart));
	gtk_widget_show(GTK_WIDGET(VBoxMulticart));
	for (i=0; i<10; i++) {
		LabelsMulticart[i] = GTK_LABEL(gtk_label_new("???"));
		gtk_misc_set_alignment(GTK_MISC(LabelsMulticart[i]), 0.0, 0.5);
		gtk_label_set_justify(LabelsMulticart[i], GTK_JUSTIFY_LEFT);
		gtk_box_pack_start(VBoxMulticart, GTK_WIDGET(LabelsMulticart[i]), TRUE, TRUE, 2);
		gtk_widget_show(GTK_WIDGET(LabelsMulticart[i]));
	}

	return 1;
}

void MiscWindow_Destroy(void)
{
	int x, y, width, height;
	if (gtk_widget_get_realized(GTK_WIDGET(MiscWindow))) {
		gtk_widget_show(GTK_WIDGET(MiscWindow));
		gtk_window_deiconify(MiscWindow);
		gtk_window_get_position(MiscWindow, &x, &y);
		gtk_window_get_size(MiscWindow, &width, &height);
		dclc_miscwin_winx = x;
		dclc_miscwin_winy = y;
		dclc_miscwin_winw = width;
		dclc_miscwin_winh = height;
	}
}

void MiscWindow_Activate(void)
{
	MiscWindow_Render(1);
	if (MiscShow_PRC) gtk_widget_show(GTK_WIDGET(FramePRC));
	else gtk_widget_hide(GTK_WIDGET(FramePRC));
	if (MiscShow_ColorPRC) gtk_widget_show(GTK_WIDGET(FrameColorPRC));
	else gtk_widget_hide(GTK_WIDGET(FrameColorPRC));
	if (MiscShow_LCD) gtk_widget_show(GTK_WIDGET(FrameLCD));
	else gtk_widget_hide(GTK_WIDGET(FrameLCD));
	if (MiscShow_EEPROM) gtk_widget_show(GTK_WIDGET(FrameEEPROM));
	else gtk_widget_hide(GTK_WIDGET(FrameEEPROM));
	if (MiscShow_Multicart) gtk_widget_show(GTK_WIDGET(FrameMulticart));
	else gtk_widget_hide(GTK_WIDGET(FrameMulticart));
	gtk_widget_realize(GTK_WIDGET(MiscWindow));
	if ((dclc_miscwin_winx > -15) && (dclc_miscwin_winy > -16)) {
		gtk_window_move(MiscWindow, dclc_miscwin_winx, dclc_miscwin_winy);
	}
	if ((dclc_miscwin_winw > 0) && (dclc_miscwin_winh > 0)) {
		gtk_window_resize(MiscWindow, dclc_miscwin_winw, dclc_miscwin_winh);
	}
	gtk_widget_show(GTK_WIDGET(MiscWindow));
	gtk_window_present(MiscWindow);
}

void MiscWindow_UpdateConfigs(void)
{
	GtkWidget *widg;

	MiscWindow_InConfigs = 1;

	widg = gtk_item_factory_get_item(ItemFactory, "/View/PRC Status");
	if (MiscShow_PRC) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Color PRC Status");
	if (MiscShow_ColorPRC) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/LCD Internals");
	if (MiscShow_LCD) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/EEPROM Internals");
	if (MiscShow_EEPROM) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Multicart Internals");
	if (MiscShow_Multicart) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	switch (dclc_miscwin_refresh) {
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

	MiscWindow_InConfigs = 0;
}

void MiscWindow_Sensitive(int enabled)
{
	if (enabled) {
		gtk_widget_hide(GTK_WIDGET(LabelRunFull));
		gtk_widget_show(GTK_WIDGET(MiscSW));
	} else {
		gtk_widget_show(GTK_WIDGET(LabelRunFull));
		gtk_widget_hide(GTK_WIDGET(MiscSW));
	}
}

void MiscWindow_Refresh(int now)
{
	static int refreshcnt = 0;
	if ((refreshcnt <= 0) || (now)) {
		refreshcnt = dclc_miscwin_refresh;
		if (!now) {
			if (!gtk_widget_get_visible(GTK_WIDGET(MiscWindow)) || MiscWindow_minimized) return;
		}
		MiscWindow_Render(0);
	} else refreshcnt--;
}
