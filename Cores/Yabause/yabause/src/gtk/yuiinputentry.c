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

#include <gtk/gtksignal.h>
#include <gtk/gtktable.h>
#include <gtk/gtklabel.h>
#include <gtk/gtkentry.h>
#include <glib/gprintf.h>
#include "yuiinputentry.h"
#include "settings.h"

static void yui_input_entry_class_init          (YuiInputEntryClass *klass);
static void yui_input_entry_init                (YuiInputEntry      *yie);
gboolean yui_input_entry_keypress(GtkWidget * widget, GdkEventKey * event, gpointer name);
gboolean yui_input_entry_focus_in(GtkWidget * widget, GdkEventFocus * event, gpointer user_data);
gboolean yui_input_entry_focus_out(GtkWidget * widget, GdkEventFocus * event, gpointer user_data);

GType yui_input_entry_get_type (void) {
	static GType yie_type = 0;

	if (!yie_type) {
		static const GTypeInfo yie_info = {
			sizeof (YuiInputEntryClass),
			NULL, /* base_init */
			NULL, /* base_finalize */
			(GClassInitFunc) yui_input_entry_class_init,
			NULL, /* class_finalize */
			NULL, /* class_data */
			sizeof (YuiInputEntry),
			0,
			(GInstanceInitFunc) yui_input_entry_init,
			NULL,
		};

		yie_type = g_type_register_static (GTK_TYPE_TABLE, "YuiInputEntry", &yie_info, 0);
	}

	return yie_type;
}

#define PROP_KEYFILE	1
#define PROP_GROUP	2

static void yui_input_entry_set_property(GObject * object, guint property_id,
		const GValue * value, GParamSpec * pspec) {
	switch(property_id) {
		case PROP_KEYFILE:
			YUI_INPUT_ENTRY(object)->keyfile = g_value_get_pointer(value);
			break;
		case PROP_GROUP:
			YUI_INPUT_ENTRY(object)->group = g_value_get_pointer(value);
			break;
	}
}

static void yui_input_entry_get_property(GObject * object, guint property_id,
		GValue * value, GParamSpec * pspec) {
}

static void yui_input_entry_class_init (YuiInputEntryClass *klass) {
	GParamSpec * param;

	G_OBJECT_CLASS(klass)->set_property = yui_input_entry_set_property;
	G_OBJECT_CLASS(klass)->get_property = yui_input_entry_get_property;

	param = g_param_spec_pointer("key-file", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_KEYFILE, param);

	param = g_param_spec_pointer("group", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_GROUP, param);
}

static void yui_input_entry_init(YuiInputEntry *yie) {
	gtk_container_set_border_width(GTK_CONTAINER(yie), 0);
	gtk_table_set_row_spacings(GTK_TABLE(yie), 10);
	gtk_table_set_col_spacings(GTK_TABLE(yie), 10);
}

GtkWidget* yui_input_entry_new(GKeyFile * keyfile, const gchar * group, const gchar * keys[]) {
	GtkWidget * widget;
	GtkWidget * label;
	GtkWidget * entry;
	guint keyName;
	int row = 0;

	widget = GTK_WIDGET(g_object_new(yui_input_entry_get_type(), "key-file", keyfile, "group", group, NULL));

	while(keys[row]) {
		char tmp[100];
		gtk_table_resize(GTK_TABLE(widget), row + 1, 2);
		label = gtk_label_new(keys[row]);
  
		gtk_table_attach(GTK_TABLE(widget), label, 0, 1, row , row + 1,
			(GtkAttachOptions) (GTK_FILL), (GtkAttachOptions) (0), 0, 0);
		gtk_misc_set_alignment (GTK_MISC (label), 0, 0.5);

		entry = gtk_entry_new ();
		gtk_entry_set_width_chars(GTK_ENTRY(entry), 10);

		sprintf(tmp, "%s.%s.1", group, keys[row]);
		keyName = g_key_file_get_integer(keyfile, PERCore->Name, tmp, 0);
		if (keyName > 0) {
			char buffer[50];
			PERCore->KeyName(keyName, buffer, 50);
			gtk_entry_set_text(GTK_ENTRY(entry), buffer);
		}

		if (PERCore) {
			//if (PERCore->canScan)
				g_signal_connect(entry, "focus-in-event", G_CALLBACK(yui_input_entry_focus_in), (gpointer) keys[row]);
				g_signal_connect(entry, "focus-out-event", G_CALLBACK(yui_input_entry_focus_out), NULL);
			//else
				g_signal_connect(entry, "key-press-event", G_CALLBACK(yui_input_entry_keypress), (gpointer) keys[row]);
		} else {
			gtk_widget_set_sensitive(entry, FALSE);
		}
  
		gtk_table_attach(GTK_TABLE(widget), entry,  1, 2, row, row + 1,
			(GtkAttachOptions) (GTK_EXPAND | GTK_FILL), (GtkAttachOptions) (0), 0, 0);
		row++;
	}

	return widget;
}

gboolean yui_input_entry_keypress(GtkWidget * widget, GdkEventKey * event, gpointer name) {
	char tmp[100];

	if (PERCore->canScan) return FALSE;

	PERCore->KeyName(event->keyval, tmp, 100);
	gtk_entry_set_text(GTK_ENTRY(widget), tmp);
	sprintf(tmp, "%s.%s.1", YUI_INPUT_ENTRY(gtk_widget_get_parent(widget))->group, (char *)name);
	g_key_file_set_integer(YUI_INPUT_ENTRY(gtk_widget_get_parent(widget))->keyfile,
		PERCore->Name, tmp, event->keyval);

	return TRUE;
}

gboolean is_watching = FALSE;
GtkEntry * entry_hack = NULL;

static gboolean watch_joy(gpointer name) {
	u32 i;

	if (! is_watching) return TRUE;

	if (! PERCore->canScan) {
		is_watching = FALSE;
		return TRUE;
	}

	i = PERCore->Scan(PERSF_KEY | PERSF_BUTTON | PERSF_HAT);

	if (i == 0) {
		return TRUE;
	} else {
		char tmp[100];

		sprintf(tmp, "Pad.%s.1", (char *)name); // should be group.name
		g_key_file_set_integer(keyfile, PERCore->Name, tmp, i);
		PERCore->KeyName(i, tmp, 100);
		gtk_entry_set_text(entry_hack, tmp);
		is_watching = FALSE;
		return FALSE;
	}
}

gboolean yui_input_entry_focus_in(GtkWidget * widget, GdkEventFocus * event, gpointer name) {
	if (! PERCore->canScan) return TRUE;

	PERCore->Flush();
	entry_hack = GTK_ENTRY(widget);

	if (!is_watching) {
		g_timeout_add(100, watch_joy, name);
		is_watching = TRUE;
	}

	return FALSE;
}

gboolean yui_input_entry_focus_out(GtkWidget * widget, GdkEventFocus * event, gpointer name) {
	is_watching = FALSE;

	return FALSE;
}

void yui_input_entry_update(YuiInputEntry * yie) {
	GList * wlist = gtk_container_get_children(GTK_CONTAINER(yie));
	u32 key;
	GtkEntry * entry = NULL;
	char tmp[100];

	while(wlist) {
		if (strcmp(gtk_widget_get_name(wlist->data), "GtkEntry") == 0) {
			entry = wlist->data;
		}
		if (strcmp(gtk_widget_get_name(wlist->data), "GtkLabel") == 0) {
			sprintf(tmp, "%s.%s.1", yie->group, gtk_label_get_text(wlist->data));
                	key = g_key_file_get_integer(yie->keyfile, PERCore->Name, tmp, 0);
			if (key > 0) {
				PERCore->KeyName(key, tmp, 100);
				gtk_entry_set_text(entry, tmp);
			} else {
				gtk_entry_set_text(entry, "");
			}
		}
		wlist = g_list_next(wlist);
	}
}
