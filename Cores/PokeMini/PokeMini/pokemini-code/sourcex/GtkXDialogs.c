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
#include "GtkXDialogs.h"
#include "PMCommon.h"

#ifdef _WIN32
#include <gdk/gdkwin32.h>
#include <windows.h>
#endif

#include <gdk/gdkkeysyms.h>

void MessageDialog(GtkWindow *parentwindow, const char *caption, const char *title, int messagetype, const char **xpm_img)
{
	GtkDialog *dialog;
	GtkWidget *image;
	GdkPixbuf *pixbuf;

	dialog = GTK_DIALOG(gtk_message_dialog_new(NULL, GTK_DIALOG_DESTROY_WITH_PARENT, messagetype, GTK_BUTTONS_OK, "%s", caption));
	if (xpm_img) {
		pixbuf = gdk_pixbuf_new_from_xpm_data(xpm_img);
		image = gtk_image_new_from_pixbuf(pixbuf);
		gtk_message_dialog_set_image(GTK_MESSAGE_DIALOG(dialog), image);
		gtk_widget_show(image);
	}
	gtk_window_set_title(GTK_WINDOW(dialog), title);
	gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_OK);
	gtk_window_present(GTK_WINDOW(dialog));
	gtk_dialog_run(dialog);
	gtk_window_present(parentwindow);
	if (xpm_img) {
		gtk_widget_destroy(GTK_WIDGET(image));
	}
	gtk_widget_destroy(GTK_WIDGET(dialog));
}

int YesNoDialog(GtkWindow *parentwindow, const char *caption, const char *title, int messagetype, const char **xpm_img)
{
	GtkDialog *dialog;
	GtkWidget *image;
	GdkPixbuf *pixbuf;
	GtkResponseType response;

	dialog = GTK_DIALOG(gtk_message_dialog_new(NULL, GTK_DIALOG_DESTROY_WITH_PARENT, messagetype, GTK_BUTTONS_YES_NO, "%s", caption));
	if (xpm_img) {
		pixbuf = gdk_pixbuf_new_from_xpm_data(xpm_img);
		image = gtk_image_new_from_pixbuf(pixbuf);
		gtk_message_dialog_set_image(GTK_MESSAGE_DIALOG(dialog), image);
		gtk_widget_show(image);
	}
	gtk_window_set_title(GTK_WINDOW(dialog), title);
	gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_OK);
	gtk_window_present(GTK_WINDOW(dialog));
	response = gtk_dialog_run(dialog);
	gtk_window_present(parentwindow);
	if (xpm_img) {
		gtk_widget_destroy(GTK_WIDGET(image));
	}
	gtk_widget_destroy(GTK_WIDGET(dialog));

	return (response == GTK_RESPONSE_YES);
}

int OpenFileDialog(GtkWindow *parentwindow, const char *title, char *fileout, const char *filein)
{
	GtkDialog *dialog;
	GtkResponseType response;
	char *filename, tmp[256];

	dialog = GTK_DIALOG(gtk_file_chooser_dialog_new(title, GTK_WINDOW(parentwindow), GTK_FILE_CHOOSER_ACTION_OPEN,
		GTK_STOCK_OPEN, GTK_RESPONSE_ACCEPT,
		GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
		NULL));
	if (FileExist(filein)) {
		strcpy(tmp, filein);
		gtk_file_chooser_set_filename(GTK_FILE_CHOOSER(dialog), GetFilename(filein));
		ExtractPath(tmp, 0);
		gtk_file_chooser_set_current_folder(GTK_FILE_CHOOSER(dialog), tmp);
	}

	gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_OK);
	gtk_window_present(GTK_WINDOW(dialog));
	response = gtk_dialog_run(dialog);
	if (response == GTK_RESPONSE_ACCEPT) {
		filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
		if (fileout) strcpy(fileout, filename);
		g_free(filename);
	}
	gtk_widget_destroy(GTK_WIDGET(dialog));
	gtk_window_present(parentwindow);

	return (response == GTK_RESPONSE_ACCEPT);
}

int SaveFileDialog(GtkWindow *parentwindow, const char *title, char *fileout, const char *filein)
{
	GtkDialog *dialog;
	GtkResponseType response;
	char *filename, tmp[256];

	dialog = GTK_DIALOG(gtk_file_chooser_dialog_new(title, GTK_WINDOW(parentwindow), GTK_FILE_CHOOSER_ACTION_SAVE,
		GTK_STOCK_SAVE, GTK_RESPONSE_ACCEPT,
		GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
		NULL));
	gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(dialog), TRUE);

	strcpy(tmp, filein);
	gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(dialog), GetFilename(filein));
	ExtractPath(tmp, 0);
	gtk_file_chooser_set_current_folder(GTK_FILE_CHOOSER(dialog), tmp);

	gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_OK);
	gtk_window_present(GTK_WINDOW(dialog));
	response = gtk_dialog_run(dialog);
	if (response == GTK_RESPONSE_ACCEPT) {
		filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
		if (fileout) strcpy(fileout, filename);
		g_free(filename);
	}
	gtk_widget_destroy(GTK_WIDGET(dialog));
	gtk_window_present(parentwindow);

	return (response == GTK_RESPONSE_ACCEPT);
}

int PickColorFormatDialog(GtkWindow *parentwindow, unsigned char colorformat, unsigned char colorflags)
{
	GtkDialog *dialog;
	GtkLabel *label1;
	GtkComboBox *combobox;
	GtkLabel *label2;
	GtkToggleButton *checkbox;

	dialog = GTK_DIALOG(gtk_dialog_new_with_buttons("Color Format", parentwindow,
		GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
		GTK_STOCK_OK, GTK_RESPONSE_OK,
		NULL));
	gtk_container_set_border_width(GTK_CONTAINER(dialog->vbox), 4);

	label1 = GTK_LABEL(gtk_label_new("Select Color Format:"));
	gtk_box_pack_start(GTK_BOX(dialog->vbox), GTK_WIDGET(label1), FALSE, TRUE, 4);

	combobox = GTK_COMBO_BOX(gtk_combo_box_new_text());
	gtk_combo_box_append_text(combobox, "8x8 Attributes");
	gtk_combo_box_append_text(combobox, "4x4 Attributes");
	gtk_combo_box_set_active(combobox, colorformat);
	gtk_box_pack_start(GTK_BOX(dialog->vbox), GTK_WIDGET(combobox), FALSE, TRUE, 4);

	checkbox = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("Require rendering video to RAM"));
	gtk_toggle_button_set_mode(checkbox, TRUE);
	gtk_toggle_button_set_active(checkbox, colorflags & 2);
	gtk_box_pack_start(GTK_BOX(dialog->vbox), GTK_WIDGET(checkbox), FALSE, TRUE, 4);

	label2 = GTK_LABEL(gtk_label_new("8x8 will use 1/4 of memory and storage\n4x4 will avoid attribute clash better"));
	gtk_box_pack_start(GTK_BOX(dialog->vbox), GTK_WIDGET(label2), FALSE, TRUE, 4);

	gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_OK);
	gtk_window_present(GTK_WINDOW(dialog));
	gtk_widget_show_all(GTK_WIDGET(dialog->vbox));

	gtk_dialog_run(dialog);

	colorformat = gtk_combo_box_get_active(combobox);
	colorflags &= ~2;
	colorflags |= gtk_toggle_button_get_active(checkbox) ? 2 : 0;
	gtk_widget_destroy(GTK_WIDGET(dialog));
	gtk_window_present(parentwindow);

	return (colorformat & 0xFF) | ((colorflags & 0xFF) << 8);
}

#ifndef GDK_KEY_Return
#define GDK_KEY_Return    GDK_Return
#define GDK_KEY_KP_Enter  GDK_KP_Enter
#define GDK_KEY_Escape    GDK_Escape
#endif

static gboolean WidgetReturnAsOkayClose(GtkWidget *widget, GdkEventKey *event, gpointer user_data)
{
	GtkDialog *dialog = (GtkDialog *)user_data;
	if (event->type == GDK_KEY_PRESS) {
		if ((event->keyval == GDK_KEY_Return) || (event->keyval == GDK_KEY_KP_Enter)) {
			gtk_dialog_response(dialog, GTK_RESPONSE_OK);
			return TRUE;
		} else if ((event->keyval == GDK_KEY_Escape)) {
			gtk_dialog_response(dialog, GTK_RESPONSE_CANCEL);
			return TRUE;
		}
	}
	return FALSE;
}

int EnterNumberDialog(GtkWindow *parentwindow, const char *title, const char *caption,
	int *numberout, int numberin, int digits, int hexnum, int min, int max)
{
	GtkDialog *dialog;
	GtkResponseType response;
	GtkLabel *label1;
	GtkEntry *entry;
	GtkLabel *label2;
	char tmp[256];
	int result = 0;

	if (hexnum) {
		if (numberin < 0) sprintf(tmp, "-$%0*X", digits, numberin);
		else sprintf(tmp, "$%0*X", digits, numberin);
	} else {
		sprintf(tmp, "%i", numberin);
	}

	dialog = GTK_DIALOG(gtk_dialog_new_with_buttons(title, GTK_WINDOW(parentwindow),
		GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
		GTK_STOCK_OK, GTK_RESPONSE_OK,
		GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
		NULL));
	gtk_container_set_border_width(GTK_CONTAINER(dialog->vbox), 4);

	label1 = GTK_LABEL(gtk_label_new(caption));
	gtk_box_pack_start(GTK_BOX(dialog->vbox), GTK_WIDGET(label1), FALSE, TRUE, 4);

	entry = GTK_ENTRY(gtk_entry_new());
	gtk_entry_set_text(GTK_ENTRY(entry), tmp);
	g_signal_connect(entry, "key-press-event", G_CALLBACK(WidgetReturnAsOkayClose), dialog);
	gtk_box_pack_start(GTK_BOX(dialog->vbox), GTK_WIDGET(entry), FALSE, TRUE, 4);

	label2 = GTK_LABEL(gtk_label_new("Prefix \"$\" for hexadecimal numbers"));
	gtk_box_pack_start(GTK_BOX(dialog->vbox), GTK_WIDGET(label2), FALSE, TRUE, 4);

	gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_OK);
	gtk_window_present(GTK_WINDOW(dialog));
	gtk_widget_show_all(GTK_WIDGET(dialog->vbox));
	do {
		gtk_widget_grab_focus(GTK_WIDGET(entry));
		response = gtk_dialog_run(dialog);
		if (response == GTK_RESPONSE_OK) {
			result = atoi_Ex2(gtk_entry_get_text(GTK_ENTRY(entry)), numberout);
			if (result != 1) {
				result = -1;
				MessageDialog(parentwindow, "Invalid number", title, GTK_MESSAGE_ERROR, NULL);
			}
			if ((*numberout < min) || (*numberout > max)) {
				result = -1;
				sprintf(tmp, "Value must be between %i and %i", min, max);
				MessageDialog(parentwindow, tmp, title, GTK_MESSAGE_ERROR, NULL);
			}
		} else result = 0;
	} while (result < 0);

	gtk_widget_destroy(GTK_WIDGET(dialog));
	gtk_window_present(parentwindow);

	return result;
}

int CustomDialog(GtkWindow *parentwindow, const char *title, GtkXCustomDialog *items)
{
	GtkXCustomDialog *cwidg;
	GtkDialog *dialog;
	GtkResponseType response;
	GtkRadioButton *radiomaster = NULL;
	GtkRadioButton *radiomaster2 = NULL;
	GtkRadioButton *radiomaster3 = NULL;
	GtkWidget *firstwidget = NULL;
	char tmp[256];
	int i, result = 1;

	dialog = GTK_DIALOG(gtk_dialog_new_with_buttons(title, GTK_WINDOW(parentwindow),
		GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
		GTK_STOCK_OK, GTK_RESPONSE_OK,
		GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
		NULL));
	gtk_container_set_border_width(GTK_CONTAINER(dialog->vbox), 4);

	cwidg = items;
	while (cwidg->wtype) {
		if (cwidg->wtype == GTKXCD_LABEL) {
			cwidg->widget = gtk_label_new(cwidg->text);
			gtk_box_pack_start(GTK_BOX(dialog->vbox), cwidg->widget, FALSE, TRUE, 4);
		} else if (cwidg->wtype == GTKXCD_CHECK) {
			cwidg->widget = gtk_check_button_new_with_label(cwidg->text);
			gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(cwidg->widget), TRUE);
			gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(cwidg->widget), cwidg->number);
			gtk_box_pack_start(GTK_BOX(dialog->vbox), cwidg->widget, FALSE, TRUE, 4);
		} else if (cwidg->wtype == GTKXCD_RADIO) {
			if (radiomaster) {
				cwidg->widget = gtk_radio_button_new_with_label_from_widget(radiomaster, cwidg->text);
			} else {
				cwidg->widget = gtk_radio_button_new_with_label(NULL, cwidg->text);
				radiomaster = GTK_RADIO_BUTTON(cwidg->widget);
			}
			gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(cwidg->widget), cwidg->number);
			gtk_box_pack_start(GTK_BOX(dialog->vbox), cwidg->widget, FALSE, TRUE, 4);
		} else if (cwidg->wtype == GTKXCD_RADIO2) {
			if (radiomaster2) {
				cwidg->widget = gtk_radio_button_new_with_label_from_widget(radiomaster2, cwidg->text);
			} else {
				cwidg->widget = gtk_radio_button_new_with_label(NULL, cwidg->text);
				radiomaster2 = GTK_RADIO_BUTTON(cwidg->widget);
			}
			gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(cwidg->widget), cwidg->number);
			gtk_box_pack_start(GTK_BOX(dialog->vbox), cwidg->widget, FALSE, TRUE, 4);
		} else if (cwidg->wtype == GTKXCD_RADIO3) {
			if (radiomaster3) {
				cwidg->widget = gtk_radio_button_new_with_label_from_widget(radiomaster3, cwidg->text);
			} else {
				cwidg->widget = gtk_radio_button_new_with_label(NULL, cwidg->text);
				radiomaster3 = GTK_RADIO_BUTTON(cwidg->widget);
			}
			gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(cwidg->widget), cwidg->number);
			gtk_box_pack_start(GTK_BOX(dialog->vbox), cwidg->widget, FALSE, TRUE, 4);
		} else if (cwidg->wtype == GTKXCD_COMBO) {
			cwidg->widget = gtk_combo_box_new_text();
			for (i=0; i<cwidg->digits; i++) {
				gtk_combo_box_append_text(GTK_COMBO_BOX(cwidg->widget), cwidg->combolist[i]);
			}
			gtk_combo_box_set_active(GTK_COMBO_BOX(cwidg->widget), cwidg->number);
			gtk_box_pack_start(GTK_BOX(dialog->vbox), cwidg->widget, FALSE, TRUE, 4);
		} else if (cwidg->wtype == GTKXCD_HSEP) {
			cwidg->widget = gtk_hseparator_new();
			gtk_box_pack_start(GTK_BOX(dialog->vbox), cwidg->widget, FALSE, TRUE, 4);
		} else if (cwidg->wtype == GTKXCD_NUMIN) {
			if (cwidg->hexformat) {
				if (cwidg->number < 0) sprintf(tmp, "-$%0*X", cwidg->digits, cwidg->number);
				else sprintf(tmp, "$%0*X", cwidg->digits, cwidg->number);
			} else {
				sprintf(tmp, "%i", cwidg->number);
			}
			cwidg->widget = gtk_entry_new();
			gtk_entry_set_text(GTK_ENTRY(cwidg->widget), tmp);
			g_signal_connect(cwidg->widget, "key-press-event", G_CALLBACK(WidgetReturnAsOkayClose), dialog);
			gtk_box_pack_start(GTK_BOX(dialog->vbox), cwidg->widget, FALSE, TRUE, 4);
			if (!firstwidget) firstwidget = cwidg->widget;
		} else if (cwidg->wtype == GTKXCD_ENTRY) {
			cwidg->widget = gtk_entry_new();
			gtk_entry_set_text(GTK_ENTRY(cwidg->widget), cwidg->text);
			g_signal_connect(cwidg->widget, "key-press-event", G_CALLBACK(WidgetReturnAsOkayClose), dialog);
			gtk_box_pack_start(GTK_BOX(dialog->vbox), cwidg->widget, FALSE, TRUE, 4);
			if (!firstwidget) firstwidget = cwidg->widget;
		}
		cwidg++;
	}

	gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_OK);
	gtk_window_present(GTK_WINDOW(dialog));
	gtk_widget_show_all(GTK_WIDGET(dialog->vbox));
	do {
		if (firstwidget) gtk_widget_grab_focus(GTK_WIDGET(firstwidget));
		response = gtk_dialog_run(dialog);
		cwidg = items;
		if (response == GTK_RESPONSE_OK) {
			result = 1;
			while (cwidg->wtype) {
				if ((cwidg->wtype == GTKXCD_CHECK) || (cwidg->wtype == GTKXCD_RADIO) ||
				    (cwidg->wtype == GTKXCD_RADIO2) || (cwidg->wtype == GTKXCD_RADIO3)) {
					cwidg->number = gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(cwidg->widget)) ? 1 : 0;
				} else if (cwidg->wtype == GTKXCD_COMBO) {
					cwidg->number = gtk_combo_box_get_active(GTK_COMBO_BOX(cwidg->widget));
				} else if (cwidg->wtype == GTKXCD_NUMIN) {
					if (atoi_Ex2(gtk_entry_get_text(GTK_ENTRY(cwidg->widget)), &cwidg->number) != 1) {
						result = -1;
						MessageDialog(parentwindow, "Invalid number", title, GTK_MESSAGE_ERROR, NULL);
					}
					if ((cwidg->number < cwidg->min) || (cwidg->number > cwidg->max)) {
						result = -1;
						sprintf(tmp, "Value must be between %i and %i", cwidg->min, cwidg->max);
						MessageDialog(parentwindow, tmp, title, GTK_MESSAGE_ERROR, NULL);
					}
				} else if (cwidg->wtype == GTKXCD_ENTRY) {
					strncpy(cwidg->text, gtk_entry_get_text(GTK_ENTRY(cwidg->widget)), 128);
					cwidg->text[127] = 0;
				}
				cwidg++;
			}
		} else result = 0;
	} while (result < 0);
	
	gtk_widget_destroy(GTK_WIDGET(dialog));
	gtk_window_present(parentwindow);

	if (response == GTK_RESPONSE_CANCEL) return 0;
	return result;
}

int OpenFileDialogEx(GtkWindow *parentwindow, const char *title, char *fileout, const char *filein, const char *exts, int extidx)
{
#ifdef _WIN32
	OPENFILENAME ofn;
	char szFile[256];

	strcpy(szFile, filein);
	ZeroMemory(&ofn, sizeof(OPENFILENAME));
	ofn.lStructSize = sizeof(OPENFILENAME);
	ofn.hwndOwner = GDK_WINDOW_HWND(GTK_WIDGET(parentwindow)->window);
	ofn.lpstrFile = szFile;
	ofn.nMaxFile = sizeof(szFile);
	ofn.lpstrFilter = exts;
	ofn.nFilterIndex = extidx + 1;
	ofn.lpstrFileTitle = (char *)title;
	ofn.nMaxFileTitle = 0;
	ofn.lpstrInitialDir = NULL;
	ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;

	if (GetOpenFileName(&ofn)) {
		strcpy(fileout, ofn.lpstrFile);
		return 1;
	}
	return 0;
#else
	return OpenFileDialog(parentwindow, title, fileout, filein);
#endif
}

int SaveFileDialogEx(GtkWindow *parentwindow, const char *title, char *fileout, const char *filein, const char *exts, int extidx)
{
#ifdef _WIN32
	OPENFILENAME ofn;
	char szFile[256];

	strcpy(szFile, filein);
	ZeroMemory(&ofn, sizeof(OPENFILENAME));
	ofn.lStructSize = sizeof(OPENFILENAME);
	ofn.hwndOwner = GDK_WINDOW_HWND(GTK_WIDGET(parentwindow)->window);
	ofn.lpstrFile = szFile;
	ofn.nMaxFile = sizeof(szFile);
	ofn.lpstrFilter = exts;
	ofn.nFilterIndex = extidx + 1;
	ofn.lpstrFileTitle = (char *)title;
	ofn.nMaxFileTitle = 0;
	ofn.lpstrInitialDir = NULL;
	ofn.Flags = OFN_PATHMUSTEXIST;

	if (GetSaveFileName(&ofn)) {
		strcpy(fileout, ofn.lpstrFile);
		return 1;
	}
	return 0;
#else
	return SaveFileDialog(parentwindow, title, fileout, filein);
#endif
}
