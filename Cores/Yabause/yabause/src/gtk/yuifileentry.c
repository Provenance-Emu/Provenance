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

#include "yuifileentry.h"

static void yui_file_entry_class_init	(YuiFileEntryClass * klass);
static void yui_file_entry_init		(YuiFileEntry      * yfe);
static void yui_file_entry_browse	(GtkWidget * widget, gpointer user_data);
static void yui_file_entry_changed	(GtkWidget * widget, YuiFileEntry * yfe);

GType yui_file_entry_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiFileEntryClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_file_entry_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiFileEntry),
	0,
	(GInstanceInitFunc) yui_file_entry_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_HBOX, "YuiFileEntry", &yfe_info, 0);
    }

  return yfe_type;
}

#define PROP_KEYFILE	1
#define PROP_GROUP	2
#define PROP_KEY	3

static void yui_file_entry_set_property(GObject * object, guint property_id,
		const GValue * value, GParamSpec * pspec) {
	switch(property_id) {
		case PROP_KEYFILE:
			YUI_FILE_ENTRY(object)->keyfile = g_value_get_pointer(value);
			break;
		case PROP_GROUP:
			YUI_FILE_ENTRY(object)->group = g_value_get_pointer(value);
			break;
		case PROP_KEY:
			YUI_FILE_ENTRY(object)->key = g_value_get_pointer(value);
			break;
	}
}

static void yui_file_entry_get_property(GObject * object, guint property_id,
		GValue * value, GParamSpec * pspec) {
}

static void yui_file_entry_class_init (YuiFileEntryClass * klass) {
	GParamSpec * param;

	G_OBJECT_CLASS(klass)->set_property = yui_file_entry_set_property;
	G_OBJECT_CLASS(klass)->get_property = yui_file_entry_get_property;

	param = g_param_spec_pointer("key-file", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_KEYFILE, param);

	param = g_param_spec_pointer("group", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_GROUP, param);

	param = g_param_spec_pointer("key", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_KEY, param);
}

static void yui_file_entry_init (YuiFileEntry * yfe) {
        gtk_container_set_border_width(GTK_CONTAINER(yfe), 10);
}

GtkWidget * yui_file_entry_new(GKeyFile * keyfile, const gchar * group, const gchar * key, gint flags, const gchar * label) {
	GtkWidget * entry;
	YuiFileEntry * yfe;
	gchar * entryText;

	entry = GTK_WIDGET(g_object_new(yui_file_entry_get_type(), "spacing", 10,
		"key-file", keyfile, "group", group, "key", key, NULL));
	yfe = YUI_FILE_ENTRY(entry);

	yfe->flags = flags;

	if (label) {
        	gtk_box_pack_start(GTK_BOX(yfe), gtk_label_new_with_mnemonic(label), FALSE, FALSE, 0);
	}

        yfe->entry = gtk_entry_new ();
        gtk_box_pack_start(GTK_BOX(yfe), yfe->entry, TRUE, TRUE, 0);

	if (flags & YUI_FILE_ENTRY_BROWSE) {
	        yfe->button = gtk_button_new_with_mnemonic ("Browse");
        	g_signal_connect(yfe->button, "clicked", G_CALLBACK(yui_file_entry_browse), yfe);
	        gtk_box_pack_start(GTK_BOX(yfe), yfe->button, FALSE, FALSE, 0);
	}

	entryText = g_key_file_get_value(yfe->keyfile, yfe->group, yfe->key, 0);
	if ( !entryText ) entryText = "";
        gtk_entry_set_text(GTK_ENTRY(yfe->entry), entryText );
        g_signal_connect(GTK_ENTRY(yfe->entry), "changed", G_CALLBACK(yui_file_entry_changed), yfe);

	return entry;
}

static void yui_file_entry_browse(GtkWidget * widget, gpointer user_data) {
        GtkWidget * file_selector;
        gint result;
        const gchar * filename;
	YuiFileEntry * yfe = user_data;
	GtkFileChooserAction action;

	if (yfe->flags & YUI_FILE_ENTRY_DIRECTORY) {
		action = GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER;
	} else {
		action = GTK_FILE_CHOOSER_ACTION_OPEN;
	}

        file_selector = gtk_file_chooser_dialog_new ("Please choose a file", NULL, action,
                        GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL, GTK_STOCK_OPEN, GTK_RESPONSE_ACCEPT, NULL);
	filename = gtk_entry_get_text(GTK_ENTRY(yfe->entry));
	if (filename[0] != '\0')
        	gtk_file_chooser_set_filename(GTK_FILE_CHOOSER(file_selector), filename);

        gtk_widget_show(file_selector);

        result = gtk_dialog_run(GTK_DIALOG(file_selector));

        switch(result) {
                case GTK_RESPONSE_ACCEPT:
                        filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(file_selector));
                        gtk_entry_set_text(GTK_ENTRY(yfe->entry), filename);
                        break;
                case GTK_RESPONSE_CANCEL:
                        break;
        }

        gtk_widget_destroy(file_selector);
}

static void yui_file_entry_changed(GtkWidget * entry, YuiFileEntry * yfe) {
        g_key_file_set_value(yfe->keyfile, yfe->group, yfe->key, gtk_entry_get_text(GTK_ENTRY(yfe->entry)));
}
