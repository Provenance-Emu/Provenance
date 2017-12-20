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

#ifndef GTKXDIALOGS_H
#define GTKXDIALOGS_H

#include <gtk/gtk.h>

enum {
	GTKXCD_EOL = 0,	// End-of-list
	GTKXCD_LABEL,	// Label widget
	GTKXCD_CHECK,	// Check item widget
	GTKXCD_RADIO,	// Radio item widget
	GTKXCD_RADIO2,	// Radio item widget (group 2)
	GTKXCD_RADIO3,	// Radio item widget (group 3)
	GTKXCD_COMBO,	// Combo item widget
	GTKXCD_HSEP,	// Horizontal separator
	GTKXCD_NUMIN,	// Number input
	GTKXCD_ENTRY	// Text input
};

typedef struct {
	int wtype;		// Widget type
	char text[128];		// Text
	int number;		// Checked for check/radio, In/out for number input
	int digits;		// Number of digits, number of strings
	int hexformat;		// Hex decimal format for number input, strings pointer
	int min;		// Minimum value for number input
	int max;		// Maximum value for number input
	const char **combolist;	// Combo list content
	GtkWidget *widget;	// Allocated widget
} GtkXCustomDialog;

// messagetype:
// GTK_MESSAGE_INFO: Informational message
// GTK_MESSAGE_WARNING: Nonfatal warning message
// GTK_MESSAGE_QUESTION: Question requiring a choice
// GTK_MESSAGE_ERROR: Fatal error message
// GTK_MESSAGE_OTHER: None of the above, doesn't get an icon

void MessageDialog(GtkWindow *parentwindow, const char *caption, const char *title, int messagetype, const char **xpm_img);

int YesNoDialog(GtkWindow *parentwindow, const char *caption, const char *title, int messagetype, const char **xpm_img);

int OpenFileDialog(GtkWindow *parentwindow, const char *title, char *fileout, const char *filein);

int SaveFileDialog(GtkWindow *parentwindow, const char *title, char *fileout, const char *filein);

int PickColorFormatDialog(GtkWindow *parentwindow, unsigned char colorformat, unsigned char colorflags);

int EnterNumberDialog(GtkWindow *parentwindow, const char *title, const char *caption,
	int *numberout, int numberin, int digits, int hexnum, int min, int max);

int CustomDialog(GtkWindow *parentwindow, const char *title, GtkXCustomDialog *items);

int OpenFileDialogEx(GtkWindow *parentwindow, const char *title, char *fileout, const char *filein, const char *exts, int extidx);

int SaveFileDialogEx(GtkWindow *parentwindow, const char *title, char *fileout, const char *filein, const char *exts, int extidx);

#endif
