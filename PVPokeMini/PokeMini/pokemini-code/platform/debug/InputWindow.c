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

#include "InputWindow.h"
#include "PokeMiniIcon_96x128.h"
#include "InstructionProc.h"
#include "InstructionInfo.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

#include "Joystick.h"
#include "Keyboard.h"
#include "KeybMapSDL.h"

int InputWindow_InConfigs = 0;

GtkWindow *InputWindow;
static GtkScrolledWindow *InputSW;
static GtkBox *VBox1;
static GtkNotebook *NBook;
static GtkTable *KTable;
static GtkLabel *KLabelK[10];
static GtkComboBox *KComboA[10];
static GtkComboBox *KComboB[10];
static GtkBox *JVBox;
static GtkTable *JTable;
static GtkToggleButton *JEnabled;
static GtkComboBox *JJoyID;
static GtkToggleButton *JAxisAsDPad;
static GtkToggleButton *JHatsAsDPad;
static GtkLabel *JLabelJ[10];
static GtkComboBox *JCombo[10];
static GtkButtonBox *HButtonBox;
static GtkButton *ButtonApply;
static GtkButton *ButtonRestore;
static GtkButton *ButtonDefaults;
static GtkButton *ButtonClose;

// -----------------
// Widgets callbacks
// -----------------

static gint InputWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(InputWindow));
	return TRUE;
}

static void InputWindow_ButtonApply_clicked(GtkWidget *widget, gpointer data)
{
	int i, newdevice = 0;

	if (CommandLine.joyid != gtk_combo_box_get_active(JJoyID)) newdevice = 1;

	// Joystick configs
	CommandLine.joyenabled = gtk_toggle_button_get_active(JEnabled) ? 1 : 0;
	CommandLine.joyid = gtk_combo_box_get_active(JJoyID);
	CommandLine.joyaxis_dpad = gtk_toggle_button_get_active(JAxisAsDPad) ? 1 : 0;
	CommandLine.joyhats_dpad = gtk_toggle_button_get_active(JHatsAsDPad) ? 1 : 0;

	// Keyboard / Joystick buttons mapping
	for (i=0; i<10; i++) {
		CommandLine.keyb_a[i] = gtk_combo_box_get_active(KComboA[i]);
		CommandLine.keyb_b[i] = gtk_combo_box_get_active(KComboB[i]);
		CommandLine.joybutton[i] = gtk_combo_box_get_active(JCombo[i]);
	}

	if (newdevice) reopenjoystick();
	KeyboardRemap(&KeybMapSDL);
}

static void InputWindow_ButtonRestore_clicked(GtkWidget *widget, gpointer data)
{
	InputWindow_UpdateConfigs();
}

static void InputWindow_ButtonDefaults_clicked(GtkWidget *widget, gpointer data)
{
	// This definitions were taken from "CommandLine.c":
	CommandLine.joyaxis_dpad = 1;	// Joystick Axis as DPad
	CommandLine.joyhats_dpad = 1;	// Joystick Hats as DPad
	// Joystick mapping
	CommandLine.joybutton[0] = 8;	// Menu:  Button 8
	CommandLine.joybutton[1] = 1;	// A:     Button 1
	CommandLine.joybutton[2] = 2;	// B:     Button 2
	CommandLine.joybutton[3] = 7;	// C:     Button 7
	CommandLine.joybutton[4] = 10;	// Up:    Button 10
	CommandLine.joybutton[5] = 11;	// Down:  Button 11
	CommandLine.joybutton[6] = 4;	// Left:  Button 4
	CommandLine.joybutton[7] = 5;	// Right: Button 5
	CommandLine.joybutton[8] = 9;	// Power: Button 9
	CommandLine.joybutton[9] = 6;	// Shake: Button 6
	// Keyboard mapping (Magic numbers!)
	CommandLine.keyb_a[0] = PMKEYB_ESCAPE;	// Menu:  ESCAPE
	CommandLine.keyb_a[1] = PMKEYB_X;	// A:     X
	CommandLine.keyb_a[2] = PMKEYB_Z;	// B:     Z
	CommandLine.keyb_a[3] = PMKEYB_C;	// C:     C
	CommandLine.keyb_a[4] = PMKEYB_UP;	// Up:    UP
	CommandLine.keyb_a[5] = PMKEYB_DOWN;	// Down:  DOWN
	CommandLine.keyb_a[6] = PMKEYB_LEFT;	// Left:  LEFT
	CommandLine.keyb_a[7] = PMKEYB_RIGHT;	// Right: RIGHT
	CommandLine.keyb_a[8] = PMKEYB_E;	// Power: E
	CommandLine.keyb_a[9] = PMKEYB_A;	// Shake: A
	// Keyboard alternative mapping (Magic numbers!)
	CommandLine.keyb_b[0] = PMKEYB_Q;	// Menu:  Q
	CommandLine.keyb_b[1] = PMKEYB_NONE;	// A:     NONE
	CommandLine.keyb_b[2] = PMKEYB_NONE;	// B:     NONE
	CommandLine.keyb_b[3] = PMKEYB_D;	// C:     D
	CommandLine.keyb_b[4] = PMKEYB_KP_8;	// Up:    KP_8
	CommandLine.keyb_b[5] = PMKEYB_KP_2;	// Down:  KP_2
	CommandLine.keyb_b[6] = PMKEYB_KP_4;	// Left:  KP_4
	CommandLine.keyb_b[7] = PMKEYB_KP_6;	// Right: KP_6
	CommandLine.keyb_b[8] = PMKEYB_P;	// Power: P
	CommandLine.keyb_b[9] = PMKEYB_S;	// Shake: S

	InputWindow_UpdateConfigs();
}

static void InputWindow_ButtonClose_clicked(GtkWidget *widget, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(InputWindow));
}

// ------------
// Input Window
// ------------

static void LoadKeybsymOnCombo(GtkComboBox *combo)
{
	int i;
	for (i=0; i<PMKEYB_EOL; i++) {
		gtk_combo_box_append_text(combo, KeyboardMapStr[i]);
	}
}

static void LoadButtonsOnCombo(GtkComboBox *combo)
{
	char tmp[16];
	int i;
	for (i=-1; i<32; i++) {
		if (i == -1) strcpy(tmp, "Off");
		else sprintf(tmp, "Button %i", i);
		gtk_combo_box_append_text(combo, tmp);
	}
}

static char *KeysStr[10] = {
	"Menu", "A",
	"B", "C",
	"Up", "Down",
	"Left", "Right",
	"Power", "Shake"
};

int InputWindow_Create(void)
{
	char tmp[PMTMPV];
	int i, x, y;

	// Window
	InputWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(InputWindow), "Input configuration");
	gtk_widget_set_size_request(GTK_WIDGET(InputWindow), 350, 450);
	gtk_window_set_default_size(InputWindow, 350, 450);
	g_signal_connect(InputWindow, "delete_event", G_CALLBACK(InputWindow_delete_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(InputWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Keyboard table
	KTable = GTK_TABLE(gtk_table_new(15, 2, FALSE));
	gtk_widget_show(GTK_WIDGET(KTable));

	// Keyboard labels & comboboxes
	for (y=0; y<5; y++) {
		for (x=0; x<2; x++) {
			i = y*2+x;
			sprintf(tmp, "Key %s", KeysStr[i]);
			KLabelK[i] = GTK_LABEL(gtk_label_new(tmp));
			gtk_table_attach(KTable, GTK_WIDGET(KLabelK[i]), x, x+1, y*3, y*3+1, GTK_FILL | GTK_EXPAND, GTK_FILL, 12, 2);
			gtk_widget_show(GTK_WIDGET(KLabelK[i]));
			KComboA[i] = GTK_COMBO_BOX(gtk_combo_box_new_text());
			LoadKeybsymOnCombo(KComboA[i]);
			gtk_table_attach(KTable, GTK_WIDGET(KComboA[i]), x, x+1, y*3+1, y*3+2, GTK_FILL | GTK_EXPAND, GTK_FILL, 12, 2);
			gtk_widget_show(GTK_WIDGET(KComboA[i]));
			KComboB[i] = GTK_COMBO_BOX(gtk_combo_box_new_text());
			LoadKeybsymOnCombo(KComboB[i]);
			gtk_table_attach(KTable, GTK_WIDGET(KComboB[i]), x, x+1, y*3+2, y*3+3, GTK_FILL | GTK_EXPAND, GTK_FILL, 12, 2);
			gtk_widget_show(GTK_WIDGET(KComboB[i]));
		}
	}

	// Joystick configs
	JVBox = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_widget_show(GTK_WIDGET(JVBox));

	JEnabled = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("Enable Joystick"));
	gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(JEnabled), TRUE);
	gtk_box_pack_start(JVBox, GTK_WIDGET(JEnabled), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(JEnabled));

	JJoyID = GTK_COMBO_BOX(gtk_combo_box_new_text());
	for (i=0; i<16; i++) {
		sprintf(tmp, "Device %i", i);
		gtk_combo_box_append_text(JJoyID, tmp);
	}
	gtk_box_pack_start(JVBox, GTK_WIDGET(JJoyID), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(JJoyID));
	
	JAxisAsDPad = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("Axis as D-Pad"));
	gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(JAxisAsDPad), TRUE);
	gtk_box_pack_start(JVBox, GTK_WIDGET(JAxisAsDPad), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(JAxisAsDPad));

	JHatsAsDPad = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("Hats as D-Pad"));
	gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(JHatsAsDPad), TRUE);
	gtk_box_pack_start(JVBox, GTK_WIDGET(JHatsAsDPad), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(JHatsAsDPad));

	// Joystick table
	JTable = GTK_TABLE(gtk_table_new(10, 2, FALSE));
	gtk_box_pack_start(JVBox, GTK_WIDGET(JTable), TRUE, TRUE, 2);
	gtk_widget_show(GTK_WIDGET(JTable));

	// Joystick labels & comboboxes
	for (y=0; y<5; y++) {
		for (x=0; x<2; x++) {
			i = y*2+x;
			sprintf(tmp, "Button %s", KeysStr[i]);
			JLabelJ[i] = GTK_LABEL(gtk_label_new(tmp));
			gtk_table_attach(JTable, GTK_WIDGET(JLabelJ[i]), x, x+1, y*2, y*2+1, GTK_FILL | GTK_EXPAND, GTK_FILL, 12, 2);
			gtk_widget_show(GTK_WIDGET(JLabelJ[i]));
			JCombo[i] = GTK_COMBO_BOX(gtk_combo_box_new_text());
			LoadButtonsOnCombo(JCombo[i]);
			gtk_table_attach(JTable, GTK_WIDGET(JCombo[i]), x, x+1, y*2+1, y*2+2, GTK_FILL | GTK_EXPAND, GTK_FILL, 12, 2);
			gtk_widget_show(GTK_WIDGET(JCombo[i]));
		}
	}

	// Notebook
	NBook = GTK_NOTEBOOK(gtk_notebook_new());
	gtk_notebook_append_page(GTK_NOTEBOOK(NBook), GTK_WIDGET(KTable), gtk_label_new("Keyboard"));
	gtk_notebook_append_page(GTK_NOTEBOOK(NBook), GTK_WIDGET(JVBox), gtk_label_new("Joystick"));
	gtk_widget_show(GTK_WIDGET(NBook));

	// Scrolling window
	InputSW = GTK_SCROLLED_WINDOW(gtk_scrolled_window_new(NULL, NULL));
	gtk_scrolled_window_set_policy(InputSW, GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
	gtk_scrolled_window_add_with_viewport(InputSW, GTK_WIDGET(NBook));
	gtk_container_add(GTK_CONTAINER(VBox1), GTK_WIDGET(InputSW));
	gtk_widget_show(GTK_WIDGET(InputSW));

	// Horizontal buttons box and they buttons
	HButtonBox = GTK_BUTTON_BOX(gtk_hbutton_box_new());
	gtk_button_box_set_layout(GTK_BUTTON_BOX(HButtonBox), GTK_BUTTONBOX_END);
	gtk_box_set_spacing(GTK_BOX(HButtonBox), 0);
	gtk_box_pack_start(VBox1, GTK_WIDGET(HButtonBox), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(HButtonBox));

	ButtonApply = GTK_BUTTON(gtk_button_new_with_label("Apply"));
	g_signal_connect(ButtonApply, "clicked", G_CALLBACK(InputWindow_ButtonApply_clicked), NULL);
	gtk_container_add(GTK_CONTAINER(HButtonBox), GTK_WIDGET(ButtonApply));
	gtk_widget_show(GTK_WIDGET(ButtonApply));

	ButtonRestore = GTK_BUTTON(gtk_button_new_with_label("Restore"));
	g_signal_connect(ButtonRestore, "clicked", G_CALLBACK(InputWindow_ButtonRestore_clicked), NULL);
	gtk_container_add(GTK_CONTAINER(HButtonBox), GTK_WIDGET(ButtonRestore));
	gtk_widget_show(GTK_WIDGET(ButtonRestore));

	ButtonDefaults = GTK_BUTTON(gtk_button_new_with_label("Defaults"));
	g_signal_connect(ButtonDefaults, "clicked", G_CALLBACK(InputWindow_ButtonDefaults_clicked), NULL);
	gtk_container_add(GTK_CONTAINER(HButtonBox), GTK_WIDGET(ButtonDefaults));
	gtk_widget_show(GTK_WIDGET(ButtonDefaults));

	ButtonClose = GTK_BUTTON(gtk_button_new_with_label("Close"));
	g_signal_connect(ButtonClose, "clicked", G_CALLBACK(InputWindow_ButtonClose_clicked), NULL);
	gtk_container_add(GTK_CONTAINER(HButtonBox), GTK_WIDGET(ButtonClose));
	gtk_widget_show(GTK_WIDGET(ButtonClose));

	return 1;
}

void InputWindow_Destroy(void)
{
}

void InputWindow_Activate(int tab)
{
	gtk_notebook_set_current_page(NBook, tab);
	gtk_widget_show(GTK_WIDGET(InputWindow));
	gtk_window_present(InputWindow);
}

void InputWindow_UpdateConfigs(void)
{
	int i;

	InputWindow_InConfigs = 1;

	// Joystick configs
	gtk_toggle_button_set_active(JEnabled, CommandLine.joyenabled);
	gtk_combo_box_set_active(JJoyID, CommandLine.joyid);
	gtk_toggle_button_set_active(JAxisAsDPad, CommandLine.joyaxis_dpad);
	gtk_toggle_button_set_active(JHatsAsDPad, CommandLine.joyhats_dpad);

	// Keyboard / Joystick buttons mapping
	for (i=0; i<10; i++) {
		gtk_combo_box_set_active(KComboA[i], CommandLine.keyb_a[i]);
		gtk_combo_box_set_active(KComboB[i], CommandLine.keyb_b[i]);
		gtk_combo_box_set_active(JCombo[i], CommandLine.joybutton[i]);
	}

	InputWindow_InConfigs = 0;
}
