/*  Copyright 2006 Guillaume Duhamel
    Copyright 2005-2006 Fabien Coulon

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include <gtk/gtk.h>

#include "yuitransfer.h"
#include "../core.h"
#include "../memory.h"

static void yui_transfer_class_init	(YuiTransferClass * klass);
static void yui_transfer_init		(YuiTransfer      * yfe);
static void yui_transfer_browse		(GtkWidget * widget, gpointer user_data);
static void yui_transfer_exec		(GtkWidget * widget, YuiTransfer * yt);
static void yui_transfer_load		(GtkWidget * entry, YuiTransfer * yt);
static void yui_transfer_load_exec	(GtkWidget * entry, YuiTransfer * yt);
static void yui_transfer_store		(GtkWidget * entry, YuiTransfer * yt);
static void yui_transfer_check		(YuiTransfer * yt);

GType yui_transfer_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiTransferClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_transfer_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiTransfer),
	0,
	(GInstanceInitFunc) yui_transfer_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_WINDOW, "YuiTransfer", &yfe_info, 0);
    }

  return yfe_type;
}

static void yui_transfer_class_init (UNUSED YuiTransferClass * klass) {
}

static void yui_transfer_init (YuiTransfer * yt) {
  GtkWidget *vbox1;
  GtkWidget *hbox1;
  GtkWidget *label4;
  GtkWidget *button1;
  GtkWidget *hbox2;
  GtkWidget *label2;
  GtkWidget *hbuttonbox1;
  GtkWidget *button5;
  GtkWidget *hbox3;
  GSList *radiobutton1_group = NULL;
  GtkWidget *radiobutton1;
  GtkWidget *radiobutton2;
  GtkWidget *radiobutton3;
  const char * tmp;

  gtk_window_set_title (GTK_WINDOW (yt), _("File transfer"));

  vbox1 = gtk_vbox_new (FALSE, 0);
  gtk_container_add (GTK_CONTAINER (yt), vbox1);

  hbox1 = gtk_hbox_new (FALSE, 10);
  gtk_box_pack_start (GTK_BOX (vbox1), hbox1, FALSE, TRUE, 0);
  gtk_container_set_border_width (GTK_CONTAINER (hbox1), 10);

  tmp = _("File");
  label4 = gtk_label_new (tmp);
  gtk_box_pack_start (GTK_BOX (hbox1), label4, FALSE, FALSE, 0);
  gtk_misc_set_alignment (GTK_MISC (label4), 0, 0.5);
  gtk_label_set_width_chars (GTK_LABEL (label4), strlen(tmp));

  yt->file_entry = gtk_entry_new ();
  g_signal_connect_swapped(yt->file_entry, "changed", G_CALLBACK(yui_transfer_check), yt);
  gtk_box_pack_start (GTK_BOX (hbox1), yt->file_entry, TRUE, TRUE, 0);

  button1 = gtk_button_new_with_mnemonic (_("Browse"));
  g_signal_connect(button1, "clicked", G_CALLBACK(yui_transfer_browse), yt->file_entry);
  gtk_box_pack_start (GTK_BOX (hbox1), button1, FALSE, FALSE, 0);

  hbox3 = gtk_hbox_new (FALSE, 10);
  gtk_box_pack_start (GTK_BOX (vbox1), hbox3, FALSE, FALSE, 0);
  gtk_container_set_border_width (GTK_CONTAINER (hbox3), 10);

  radiobutton1 = gtk_radio_button_new_with_mnemonic (NULL, _("Load as executable"));
  g_signal_connect(radiobutton1, "toggled", G_CALLBACK(yui_transfer_load_exec), yt);
  gtk_box_pack_start (GTK_BOX (hbox3), radiobutton1, FALSE, FALSE, 0);
  gtk_radio_button_set_group (GTK_RADIO_BUTTON (radiobutton1), radiobutton1_group);
  radiobutton1_group = gtk_radio_button_get_group (GTK_RADIO_BUTTON (radiobutton1));

  radiobutton2 = gtk_radio_button_new_with_mnemonic (NULL, _("Load"));
  g_signal_connect(radiobutton2, "toggled", G_CALLBACK(yui_transfer_load), yt);
  gtk_box_pack_start (GTK_BOX (hbox3), radiobutton2, FALSE, FALSE, 0);
  gtk_radio_button_set_group (GTK_RADIO_BUTTON (radiobutton2), radiobutton1_group);
  radiobutton1_group = gtk_radio_button_get_group (GTK_RADIO_BUTTON (radiobutton2));

  radiobutton3 = gtk_radio_button_new_with_mnemonic (NULL, _("Store"));
  g_signal_connect(radiobutton3, "toggled", G_CALLBACK(yui_transfer_store), yt);
  gtk_box_pack_start (GTK_BOX (hbox3), radiobutton3, FALSE, FALSE, 0);
  gtk_radio_button_set_group (GTK_RADIO_BUTTON (radiobutton3), radiobutton1_group);
  radiobutton1_group = gtk_radio_button_get_group (GTK_RADIO_BUTTON (radiobutton3));

  hbox2 = gtk_hbox_new (FALSE, 10);
  gtk_box_pack_start (GTK_BOX (vbox1), hbox2, FALSE, TRUE, 0);
  gtk_container_set_border_width (GTK_CONTAINER (hbox2), 10);

  tmp = _("From");
  label2 = gtk_label_new (tmp);
  gtk_box_pack_start (GTK_BOX (hbox2), label2, FALSE, FALSE, 0);
  gtk_misc_set_alignment (GTK_MISC (label2), 0, 0.5);
  gtk_label_set_width_chars (GTK_LABEL (label2), strlen(tmp));

  yt->from_entry = gtk_entry_new ();
  g_signal_connect_swapped(yt->from_entry, "changed", G_CALLBACK(yui_transfer_check), yt);
  gtk_box_pack_start (GTK_BOX (hbox2), yt->from_entry, TRUE, TRUE, 0);

  tmp = _("To");
  yt->to_label = gtk_label_new (tmp);
  gtk_box_pack_start (GTK_BOX (hbox2), yt->to_label, FALSE, FALSE, 0);
  gtk_misc_set_alignment (GTK_MISC (yt->to_label), 0, 0.5);
  gtk_label_set_width_chars (GTK_LABEL (yt->to_label), strlen(tmp));

  yt->to_entry = gtk_entry_new ();
  g_signal_connect_swapped(yt->to_entry, "changed", G_CALLBACK(yui_transfer_check), yt);
  gtk_box_pack_start (GTK_BOX (hbox2), yt->to_entry, TRUE, TRUE, 0);

  hbuttonbox1 = gtk_hbutton_box_new ();
  gtk_box_pack_start (GTK_BOX (vbox1), hbuttonbox1, FALSE, TRUE, 0);
  gtk_container_set_border_width (GTK_CONTAINER (hbuttonbox1), 10);

  yt->transfer_button = gtk_button_new_with_mnemonic (_("Transfer"));
  gtk_container_add (GTK_CONTAINER (hbuttonbox1), yt->transfer_button);
  g_signal_connect(yt->transfer_button, "clicked", G_CALLBACK(yui_transfer_exec), yt);
  GTK_WIDGET_SET_FLAGS (yt->transfer_button, GTK_CAN_DEFAULT);

  button5 = gtk_button_new_from_stock ("gtk-cancel");
  gtk_container_add (GTK_CONTAINER (hbuttonbox1), button5);
  g_signal_connect_swapped(button5, "clicked", G_CALLBACK(gtk_widget_destroy), yt);
  GTK_WIDGET_SET_FLAGS (button5, GTK_CAN_DEFAULT);

  gtk_widget_show_all (GTK_WIDGET(yt));

	gtk_widget_set_sensitive(GTK_WIDGET(yt->to_label), FALSE);
	gtk_widget_set_sensitive(GTK_WIDGET(yt->to_entry), FALSE);

  yt->mode = YUI_TRANSFER_LOAD_EXEC;

}

GtkWidget * yui_transfer_new(YuiWindow * yw) {
	GtkWidget * entry;
	YuiTransfer * yfe;

	entry = GTK_WIDGET(g_object_new(yui_transfer_get_type(), NULL));
	yfe = YUI_TRANSFERT(entry);

	gtk_widget_show_all(entry);

	yui_transfer_check(yfe);

	yui_window_start(yw);

	return entry;
}

static void yui_transfer_browse(UNUSED GtkWidget * widget, gpointer user_data) {
        GtkWidget * file_selector;
        gint result;
        const gchar * filename;

        file_selector = gtk_file_chooser_dialog_new (_("Please choose a file"), NULL, GTK_FILE_CHOOSER_ACTION_OPEN,
                        GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL, GTK_STOCK_OPEN, GTK_RESPONSE_ACCEPT, NULL);
	filename = gtk_entry_get_text(GTK_ENTRY(user_data));
	if (filename[0] != '\0')
        	gtk_file_chooser_set_filename(GTK_FILE_CHOOSER(file_selector), filename);

        gtk_widget_show(file_selector);

        result = gtk_dialog_run(GTK_DIALOG(file_selector));

        switch(result) {
                case GTK_RESPONSE_ACCEPT:
                        filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(file_selector));
                        gtk_entry_set_text(GTK_ENTRY(user_data), filename);
                        break;
                case GTK_RESPONSE_CANCEL:
                        break;
        }

        gtk_widget_destroy(file_selector);
}

static void yui_transfer_exec(UNUSED GtkWidget * widget, YuiTransfer * yt) {
	guint32 from, to;

	switch(yt->mode) {
		case YUI_TRANSFER_LOAD:
			sscanf(gtk_entry_get_text(GTK_ENTRY(yt->from_entry)), "%x", &from);
			MappedMemoryLoad(gtk_entry_get_text(GTK_ENTRY(yt->file_entry)), from);
			break;
		case YUI_TRANSFER_LOAD_EXEC:
			sscanf(gtk_entry_get_text(GTK_ENTRY(yt->from_entry)), "%x", &from);
			MappedMemoryLoadExec(gtk_entry_get_text(GTK_ENTRY(yt->file_entry)), from);
			break;
		case YUI_TRANSFER_STORE:
			sscanf(gtk_entry_get_text(GTK_ENTRY(yt->from_entry)), "%x", &from);
			sscanf(gtk_entry_get_text(GTK_ENTRY(yt->to_entry)), "%x", &to);
			MappedMemorySave(gtk_entry_get_text(GTK_ENTRY(yt->file_entry)), from, to - from);
			break;
	}

	gtk_widget_destroy(GTK_WIDGET(yt));
}

static void yui_transfer_load(GtkWidget * entry, YuiTransfer * yt) {
	if (gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(entry))) {
		yt->mode = YUI_TRANSFER_LOAD;
		gtk_widget_set_sensitive(GTK_WIDGET(yt->to_label), FALSE);
		gtk_widget_set_sensitive(GTK_WIDGET(yt->to_entry), FALSE);
		yui_transfer_check(yt);
	}
}

static void yui_transfer_load_exec(GtkWidget * entry, YuiTransfer * yt) {
	if (gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(entry))) {
		yt->mode = YUI_TRANSFER_LOAD_EXEC;
		gtk_widget_set_sensitive(GTK_WIDGET(yt->to_label), FALSE);
		gtk_widget_set_sensitive(GTK_WIDGET(yt->to_entry), FALSE);
		yui_transfer_check(yt);
	}
}

static void yui_transfer_store(GtkWidget * entry, YuiTransfer * yt) {
	if (gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(entry))) {
		yt->mode = YUI_TRANSFER_STORE;
		gtk_widget_set_sensitive(GTK_WIDGET(yt->to_label), TRUE);
		gtk_widget_set_sensitive(GTK_WIDGET(yt->to_entry), TRUE);
		yui_transfer_check(yt);
	}
}

static void yui_transfer_check(YuiTransfer * yt) {
	gboolean ok = FALSE;

	if (*gtk_entry_get_text(GTK_ENTRY(yt->file_entry)) != '\0') {
		switch(yt->mode) {
			case YUI_TRANSFER_LOAD:
			case YUI_TRANSFER_LOAD_EXEC:
				if (*gtk_entry_get_text(GTK_ENTRY(yt->from_entry)) != '\0') {
					ok = TRUE;
				}
				break;
			case YUI_TRANSFER_STORE:
				if ((*gtk_entry_get_text(GTK_ENTRY(yt->from_entry)) != '\0') && (*gtk_entry_get_text(GTK_ENTRY(yt->to_entry)) != '\0')) {
					ok = TRUE;
				}
				break;
		}
	}

	gtk_widget_set_sensitive(yt->transfer_button, ok);
}
