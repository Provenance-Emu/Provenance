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

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

#include "SDL.h"
#include "PokeMini.h"
#include "PokeMini_Debug.h"
#include "Hardware_Debug.h"

#include "CPUWindow.h"
#include "ExternalWindow.h"
#include "PokeMiniIcon_96x128.h"
#include "InstructionProc.h"
#include "InstructionInfo.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

int ExternalWindow_InConfigs = 0;

GtkWindow *ExternalWindow;
static GtkScrolledWindow *ExternalSW;
static GtkBox *VBox1;
static GtkTable *MTable;
static GtkLabel *MLabelTitle[10];
static GtkLabel *MLabelExec[10];
static GtkEntry *MEntryTitle[10];
static GtkEntry *MEntryExec[10];
static GtkToggleButton *MCurrDir[10];
static GtkLabel *LabelDesc;
static GtkButtonBox *HButtonBox;
static GtkButton *ButtonOk;
static GtkButton *ButtonCancel;

// Locals
GtkItemFactory *CPUItemFactory = NULL;

#define EXTMPV	(4096)

// --------
// Launcher
// --------

static int RunCmdNoWait(const char *runcmd, int atcurrdir)
{
	char **argv, *argpars = "", *launchdir;
	int i, res = 1, argc;

	// Select launch directory
	launchdir = atcurrdir ? PokeMini_CurrDir : PokeMini_ExecDir;

	// Decode arguments
	argc = GetArgument(runcmd, 1, NULL, 0, &argpars);
	argv = (char **)malloc((argc + 1) * sizeof(char *));
	for (i=0; i<argc; i++) {
		argv[i] = (char *)malloc(EXTMPV);
		memset(argv[i], 0, EXTMPV);
		GetArgument(runcmd, i, argv[i], EXTMPV-1, NULL);
	}
	argv[argc] = NULL;

#ifdef _WIN32
	// Shell execute
	res = (int)ShellExecute(NULL, "open", argv[0], argpars, launchdir, SW_SHOW) > 32;
#else
	// Fork and execute
	i = fork();
	if (i == -1) {
		fprintf(stderr, "Error: Couldn't fork()\n");
		res = 0;
	} else if (i == 0) {
		// Child process
		PokeMini_GotoCustomDir(launchdir);
		execvp(argv[0], argv);
		_exit(0);
	}
#endif

	// Free memory
	for (i=0; i<argc; i++) free(argv[i]);
	free(argv);

	return res;
}

// Return:
// -1 - Required ROM
//  0 - Overflow, failure to call
//  1 - Empty
//  2 - Success
int ExternalWindow_Launch(const char *execcod, int atcurrdir)
{
	char ch, execrun[EXTMPV], tmp[EXTMPV];
	int execp = 0;
	memset(execrun, 0, sizeof(EXTMPV));
	while ((ch = *execcod++) != 0) {
		if (ch == '%') {
			switch (*execcod++) {
				case 0: break;
				case '%':
					execrun[execp++] = '%';
					break;
				case 'x': case 'X': // Executable path
					strcpy(tmp, PokeMini_ExecDir);
					strncpy(&execrun[execp], tmp, EXTMPV-execp-1);
					execp += strlen(tmp);
					break;
				case 'c': case 'C': // Current path
					strcpy(tmp, PokeMini_CurrDir);
					strncpy(&execrun[execp], tmp, EXTMPV-execp-1);
					execp += strlen(tmp);
					break;
				case 'R': // ROM filename with path
					if (!strlen(CommandLine.min_file)) return -1;
					if ((CommandLine.min_file[0] != '/') && (CommandLine.min_file[1] != ':')) {
#ifdef _WIN32
						sprintf(tmp, "%s\\%s", PokeMini_CurrDir, CommandLine.min_file);
#else
						sprintf(tmp, "%s/%s", PokeMini_CurrDir, CommandLine.min_file);
#endif
					} else strcpy(tmp, CommandLine.min_file);
					strncpy(&execrun[execp], tmp, EXTMPV-execp-1);
					execp += strlen(tmp);
					break;
				case 'r': // ROM filename
					if (!strlen(CommandLine.min_file)) return -1;
					strcpy(tmp, CommandLine.min_file);
					strncpy(&execrun[execp], tmp, EXTMPV-execp-1);
					execp += strlen(tmp);
					break;
				case 'F': // ROM filename without path
					if (!strlen(CommandLine.min_file)) return -1;
					strcpy(tmp, GetFilename(CommandLine.min_file));
					strncpy(&execrun[execp], tmp, EXTMPV-execp-1);
					execp += strlen(tmp);
					break;
				case 'f': // ROM filename without path & extension
					if (!strlen(CommandLine.min_file)) return -1;
					strcpy(tmp, GetFilename(CommandLine.min_file));
					RemoveExtension(tmp);
					strncpy(&execrun[execp], tmp, EXTMPV-execp-1);
					execp += strlen(tmp);
					break;
				case 'N': // ROM filename with path but without extension
					if (!strlen(CommandLine.min_file)) return -1;
					if ((CommandLine.min_file[0] != '/') && (CommandLine.min_file[1] != ':')) {
#ifdef _WIN32
						sprintf(tmp, "%s\\%s", PokeMini_CurrDir, CommandLine.min_file);
#else
						sprintf(tmp, "%s/%s", PokeMini_CurrDir, CommandLine.min_file);
#endif
					} else strcpy(tmp, CommandLine.min_file);
					RemoveExtension(tmp);
					strncpy(&execrun[execp], tmp, EXTMPV-execp-1);
					execp += strlen(tmp);
					break;
				case 'n': // ROM filename without extension
					if (!strlen(CommandLine.min_file)) return -1;
					strcpy(tmp, GetFilename(CommandLine.min_file));
					RemoveExtension(tmp);
					strncpy(&execrun[execp], tmp, EXTMPV-execp-1);
					execp += strlen(tmp);
					break;
				case 'P': // ROM path only, with slash
					if (!strlen(CommandLine.min_file)) return -1;
					strcpy(tmp, CommandLine.min_file);
					ExtractPath(tmp, 1);
					strncpy(&execrun[execp], tmp, EXTMPV-execp-1);
					execp += strlen(tmp);
					break;
				case 'p': // ROM path only, without slash
					if (!strlen(CommandLine.min_file)) return -1;
					strcpy(tmp, CommandLine.min_file);
					ExtractPath(tmp, 0);
					strncpy(&execrun[execp], tmp, EXTMPV-execp-1);
					execp += strlen(tmp);
					break;
			}
		} else {
			execrun[execp++] = ch;
		}
		if ((EXTMPV-execp-1) <= 0) {
			return 0;
		}
	}
	execrun[execp] = 0;
	if (strlen(execrun)) {
		if (RunCmdNoWait(execrun, atcurrdir)) return 2;
		return 0;
	}
	return 1;
}

// -----------------
// Widgets callbacks
// -----------------

static gint ExternalWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(ExternalWindow));
	return TRUE;
}

static void ExternalWindow_ButtonOk_clicked(GtkWidget *widget, gpointer data)
{
	int i;
	for (i=0; i<10; i++) {
		memset(dclc_extapp_title[i], 0, PMTMPV);
		strncpy(dclc_extapp_title[i], gtk_entry_get_text(MEntryTitle[i]), PMTMPV-1);
		memset(dclc_extapp_exec[i], 0, PMTMPV);
		strncpy(dclc_extapp_exec[i], gtk_entry_get_text(MEntryExec[i]), PMTMPV-1);
		dclc_extapp_atcurrdir[i] = gtk_toggle_button_get_active(MCurrDir[i]) ? 1 : 0;
	}
	if (CPUItemFactory) ExternalWindow_UpdateMenu(CPUItemFactory);
	gtk_widget_hide(GTK_WIDGET(ExternalWindow));
}

static void ExternalWindow_ButtonCancel_clicked(GtkWidget *widget, gpointer data)
{
	ExternalWindow_UpdateConfigs();
	gtk_widget_hide(GTK_WIDGET(ExternalWindow));
}

// ---------------
// External Window
// ---------------

int ExternalWindow_Create(void)
{
	char tmp[PMTMPV];
	int i;

	// Window
	ExternalWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(ExternalWindow), "External configuration");
	gtk_widget_set_size_request(GTK_WIDGET(ExternalWindow), 300, 250);
	gtk_window_set_default_size(ExternalWindow, 350, 450);
	g_signal_connect(ExternalWindow, "delete_event", G_CALLBACK(ExternalWindow_delete_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(ExternalWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Table
	MTable = GTK_TABLE(gtk_table_new(31, 2, FALSE));
	gtk_widget_show(GTK_WIDGET(MTable));

	// Applications
	for (i=0; i<10; i++) {
		sprintf(tmp, "App. %i Name:", i+1);
		MLabelTitle[i] = GTK_LABEL(gtk_label_new(tmp));
		gtk_misc_set_alignment(GTK_MISC(MLabelTitle[i]), 1.0, 0.5);
		gtk_table_attach(MTable, GTK_WIDGET(MLabelTitle[i]), 0, 1, i*3, i*3+1, GTK_FILL, GTK_FILL, 2, 2);
		gtk_widget_show(GTK_WIDGET(MLabelTitle[i]));
		MEntryTitle[i] = GTK_ENTRY(gtk_entry_new());
		gtk_table_attach(MTable, GTK_WIDGET(MEntryTitle[i]), 1, 2, i*3, i*3+1, GTK_FILL | GTK_EXPAND, GTK_FILL, 2, 2);
		gtk_widget_show(GTK_WIDGET(MEntryTitle[i]));
		sprintf(tmp, "App. %i Command:", i+1);
		MLabelExec[i] = GTK_LABEL(gtk_label_new(tmp));
		gtk_misc_set_alignment(GTK_MISC(MLabelExec[i]), 1.0, 0.5);
		gtk_table_attach(MTable, GTK_WIDGET(MLabelExec[i]), 0, 1, i*3+1, i*3+2, GTK_FILL, GTK_FILL, 2, 2);
		gtk_widget_show(GTK_WIDGET(MLabelExec[i]));
		MEntryExec[i] = GTK_ENTRY(gtk_entry_new());
		gtk_table_attach(MTable, GTK_WIDGET(MEntryExec[i]), 1, 2, i*3+1, i*3+2, GTK_FILL | GTK_EXPAND, GTK_FILL, 2, 2);
		gtk_widget_show(GTK_WIDGET(MEntryExec[i]));
		MCurrDir[i] = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("Launch from current directory"));
		gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(MCurrDir[i]), TRUE);
		gtk_table_attach(MTable, GTK_WIDGET(MCurrDir[i]), 1, 2, i*3+2, i*3+3, GTK_FILL, GTK_FILL, 2, 2);
		gtk_widget_show(GTK_WIDGET(MCurrDir[i]));
	}
	LabelDesc = GTK_LABEL(gtk_label_new(
		"Special keywords for command:\n"
		"  %% = % character\n"
		"  %X = Executable path\n"
		"  %C = Current path\n"
		"  %R = ROM filename, with path\n"
		"  %r = ROM filename\n"
		"  %F = ROM filename, no path\n"
		"  %f = ROM filename, no path, no extension\n"
		"  %N = ROM filename, with path, no extension\n"
		"  %n = ROM filename, no extension\n"
		"  %p = ROM path only, without slash\n"
		"  %P = ROM path only, with slash\n"
	));
	gtk_misc_set_alignment(GTK_MISC(LabelDesc), 0.0, 0.5);
	gtk_table_attach(MTable, GTK_WIDGET(LabelDesc), 0, 2, i*3, i*3+1, GTK_FILL | GTK_EXPAND, GTK_FILL, 12, 8);
	gtk_widget_show(GTK_WIDGET(LabelDesc));

	// Scrolling window
	ExternalSW = GTK_SCROLLED_WINDOW(gtk_scrolled_window_new(NULL, NULL));
	gtk_scrolled_window_set_policy(ExternalSW, GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
	gtk_scrolled_window_add_with_viewport(ExternalSW, GTK_WIDGET(MTable));
	gtk_container_add(GTK_CONTAINER(VBox1), GTK_WIDGET(ExternalSW));
	gtk_widget_show(GTK_WIDGET(ExternalSW));

	// Horizontal buttons box and they buttons
	HButtonBox = GTK_BUTTON_BOX(gtk_hbutton_box_new());
	gtk_button_box_set_layout(GTK_BUTTON_BOX(HButtonBox), GTK_BUTTONBOX_END);
	gtk_box_set_spacing(GTK_BOX(HButtonBox), 4);
	gtk_box_pack_start(VBox1, GTK_WIDGET(HButtonBox), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(HButtonBox));

	ButtonOk = GTK_BUTTON(gtk_button_new_with_label("OK"));
	g_signal_connect(ButtonOk, "clicked", G_CALLBACK(ExternalWindow_ButtonOk_clicked), NULL);
	gtk_container_add(GTK_CONTAINER(HButtonBox), GTK_WIDGET(ButtonOk));
	gtk_widget_show(GTK_WIDGET(ButtonOk));

	ButtonCancel = GTK_BUTTON(gtk_button_new_with_label("Cancel"));
	g_signal_connect(ButtonCancel, "clicked", G_CALLBACK(ExternalWindow_ButtonCancel_clicked), NULL);
	gtk_container_add(GTK_CONTAINER(HButtonBox), GTK_WIDGET(ButtonCancel));
	gtk_widget_show(GTK_WIDGET(ButtonCancel));

	// Initialize command-line strings
	for (i=0; i<10; i++) {
		strcpy(dclc_extapp_title[i], "---");
		strcpy(dclc_extapp_exec[i], "");
		dclc_extapp_atcurrdir[i] = 0;
	}
	strcpy(dclc_extapp_title[8], "Color Mapper");
	strcpy(dclc_extapp_exec[8], "\"%X/color_mapper\" \"%R\"");
	dclc_extapp_atcurrdir[8] = 1;
#ifdef _WIN32
	strcpy(dclc_extapp_title[9], "Shell (Win2K)");
	strcpy(dclc_extapp_exec[9], "cmd");
	dclc_extapp_atcurrdir[9] = 1;
#else
	strcpy(dclc_extapp_title[9], "Terminal (Linux)");
	strcpy(dclc_extapp_exec[9], "xterm");
	dclc_extapp_atcurrdir[9] = 1;
#endif


	return 1;
}

void ExternalWindow_Destroy(void)
{
}

void ExternalWindow_Activate(GtkItemFactory *itemfact)
{
	CPUItemFactory = itemfact;
	gtk_widget_show(GTK_WIDGET(ExternalWindow));
	gtk_window_present(ExternalWindow);
}

void ExternalWindow_UpdateConfigs(void)
{
	int i;

	ExternalWindow_InConfigs = 1;

	// Setup entries
	for (i=0; i<10; i++) {
		gtk_entry_set_text(MEntryTitle[i], dclc_extapp_title[i]);
		gtk_entry_set_text(MEntryExec[i], dclc_extapp_exec[i]);
		gtk_toggle_button_set_active(MCurrDir[i], dclc_extapp_atcurrdir[i]);
	}

	ExternalWindow_InConfigs = 0;
}

void ExternalWindow_UpdateMenu(GtkItemFactory *itemfact)
{
	char tmp[PMTMPV];
	GtkWidget *widg;
	int i;

	for (i=0; i<10; i++) {
		sprintf(tmp, "/External/App%i", i+1);
		widg = gtk_item_factory_get_item(itemfact, tmp);
		gtk_menu_item_set_label(GTK_MENU_ITEM(widg), dclc_extapp_title[i]);
	}
}
