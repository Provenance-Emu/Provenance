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
#include <gtk/gtkcheckbutton.h>
#include <gtk/gtkhbox.h>
#include <gtk/gtkcombobox.h>
#include "yuiresolution.h"

static void yui_resolution_class_init          (YuiResolutionClass *klass);
static void yui_resolution_init                (YuiResolution      *yie);
static void yui_resolution_width_changed	(GtkWidget * w, YuiResolution * yr);
static void yui_resolution_height_changed	(GtkWidget * w, YuiResolution * yr);
static void yui_resolution_options_changed	(GtkWidget * w, YuiResolution * yr);

GType yui_resolution_get_type (void) {
	static GType yie_type = 0;

	if (!yie_type) {
		static const GTypeInfo yie_info = {
			sizeof (YuiResolutionClass),
			NULL, /* base_init */
			NULL, /* base_finalize */
			(GClassInitFunc) yui_resolution_class_init,
			NULL, /* class_finalize */
			NULL, /* class_data */
			sizeof (YuiResolution),
			0,
			(GInstanceInitFunc) yui_resolution_init,
			NULL,
		};

		yie_type = g_type_register_static (GTK_TYPE_HBOX, "YuiResolution", &yie_info, 0);
	}

	return yie_type;
}

#define PROP_KEYFILE	1
#define PROP_GROUP	2

static void yui_resolution_set_property(GObject * object, guint property_id,
		const GValue * value, GParamSpec * pspec) {
	switch(property_id) {
		case PROP_KEYFILE:
			YUI_RESOLUTION(object)->keyfile = g_value_get_pointer(value);
			break;
		case PROP_GROUP:
			YUI_RESOLUTION(object)->group = g_value_get_pointer(value);
			break;
	}
}

static void yui_resolution_get_property(GObject * object, guint property_id,
		GValue * value, GParamSpec * pspec) {
}

static void yui_resolution_class_init (YuiResolutionClass *klass) {
	GParamSpec * param;

	G_OBJECT_CLASS(klass)->set_property = yui_resolution_set_property;
	G_OBJECT_CLASS(klass)->get_property = yui_resolution_get_property;

	param = g_param_spec_pointer("key-file", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_KEYFILE, param);

	param = g_param_spec_pointer("group", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_GROUP, param);
}

static void yui_resolution_init(YuiResolution * yr) {
	GtkWidget * label_w;
	GtkWidget * label_h;

	gtk_container_set_border_width (GTK_CONTAINER (yr), 10);

	label_w = gtk_label_new ("Width");
	gtk_box_pack_start(GTK_BOX(yr), label_w, TRUE, TRUE, 0);

	yr->entry_w = gtk_entry_new ();
	gtk_entry_set_width_chars(GTK_ENTRY(yr->entry_w), 8);
	gtk_box_pack_start(GTK_BOX(yr), yr->entry_w, TRUE, TRUE, 0);

	label_h = gtk_label_new ("Height");
	gtk_box_pack_start(GTK_BOX(yr), label_h, TRUE, TRUE, 0);

	yr->entry_h = gtk_entry_new ();
	gtk_entry_set_width_chars(GTK_ENTRY(yr->entry_h), 8);
	gtk_box_pack_start(GTK_BOX(yr), yr->entry_h, TRUE, TRUE, 0);

	yr->options = gtk_combo_box_new_text();
	gtk_combo_box_append_text(GTK_COMBO_BOX(yr->options), "Window");
	gtk_combo_box_append_text(GTK_COMBO_BOX(yr->options), "Fullscreen");
	gtk_combo_box_append_text(GTK_COMBO_BOX(yr->options), "Keep ratio");
	gtk_box_pack_start(GTK_BOX(yr), yr->options, TRUE, TRUE, 0);

	g_signal_connect(yr->entry_w, "changed", G_CALLBACK(yui_resolution_width_changed), yr);
	g_signal_connect(yr->entry_h, "changed", G_CALLBACK(yui_resolution_height_changed), yr);
	g_signal_connect(yr->options, "changed", G_CALLBACK(yui_resolution_options_changed), yr);
}

GtkWidget* yui_resolution_new(GKeyFile * keyfile, const gchar * group) {
	GtkWidget * widget;
	YuiResolution * yr;
	gchar *widthText, *heightText;

	widget = GTK_WIDGET(g_object_new(yui_resolution_get_type(), "key-file", keyfile, "group", group, NULL));
	yr = YUI_RESOLUTION(widget);

	widthText = g_key_file_get_value(yr->keyfile, yr->group, "Width", 0);
	if ( !widthText ) widthText = "";
	heightText = g_key_file_get_value(yr->keyfile, yr->group, "Height", 0);
	if ( !heightText ) heightText = "";
	gtk_entry_set_text(GTK_ENTRY(yr->entry_w), widthText );
	gtk_entry_set_text(GTK_ENTRY(yr->entry_h), heightText );
	if (g_key_file_get_integer(yr->keyfile, yr->group, "Fullscreen", 0) == 1)
		gtk_combo_box_set_active(GTK_COMBO_BOX(yr->options), 1);
	else if (g_key_file_get_integer(yr->keyfile, yr->group, "KeepRatio", 0) == 1)
		gtk_combo_box_set_active(GTK_COMBO_BOX(yr->options), 2);
	else
		gtk_combo_box_set_active(GTK_COMBO_BOX(yr->options), 0);

	return widget;
}

static void yui_resolution_width_changed(GtkWidget * w, YuiResolution * yr) {
	g_key_file_set_value(yr->keyfile, yr->group, "Width", gtk_entry_get_text(GTK_ENTRY(w)));
}

static void yui_resolution_height_changed(GtkWidget * w, YuiResolution * yr) {
	g_key_file_set_value(yr->keyfile, yr->group, "Height", gtk_entry_get_text(GTK_ENTRY(w)));
}

static void yui_resolution_options_changed(GtkWidget * w, YuiResolution * yr) {
	gint active = gtk_combo_box_get_active(GTK_COMBO_BOX(yr->options));
	switch(active) {
		case 0:
			g_key_file_set_integer(yr->keyfile, yr->group, "Fullscreen", 0);
			g_key_file_set_integer(yr->keyfile, yr->group, "KeepRatio", 0);
			break;
		case 1:
			g_key_file_set_integer(yr->keyfile, yr->group, "Fullscreen", 1);
			g_key_file_set_integer(yr->keyfile, yr->group, "KeepRatio", 0);
			break;
		case 2:
			g_key_file_set_integer(yr->keyfile, yr->group, "Fullscreen", 0);
			g_key_file_set_integer(yr->keyfile, yr->group, "KeepRatio", 1);
			break;
	}
}
