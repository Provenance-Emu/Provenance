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
#include <string.h>

#include "yuirange.h"

static void yui_range_class_init	(YuiRangeClass * klass);
static void yui_range_init		(YuiRange      * yfe);
static void yui_range_changed	(GtkWidget * widget, YuiRange * yfe);

GType yui_range_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiRangeClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_range_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiRange),
	0,
	(GInstanceInitFunc) yui_range_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_HBOX, "YuiRange", &yfe_info, 0);
    }

  return yfe_type;
}

#define PROP_KEYFILE	1
#define PROP_GROUP	2
#define PROP_KEY	3
#define PROP_ITEMS	4

static void yui_range_set_property(GObject * object, guint property_id,
		const GValue * value, GParamSpec * pspec) {
	switch(property_id) {
		case PROP_KEYFILE:
			YUI_RANGE(object)->keyfile = g_value_get_pointer(value);
			break;
		case PROP_GROUP:
			YUI_RANGE(object)->group = g_value_get_pointer(value);
			break;
		case PROP_KEY:
			YUI_RANGE(object)->key = g_value_get_pointer(value);
			break;
		case PROP_ITEMS:
			YUI_RANGE(object)->items = g_value_get_pointer(value);
			break;
	}
}

static void yui_range_get_property(GObject * object, guint property_id,
		GValue * value, GParamSpec * pspec) {
}

enum { YUI_RANGE_CHANGED_SIGNAL, LAST_SIGNAL };

static guint yui_range_signals[LAST_SIGNAL] = { 0 };

static void yui_range_class_init (YuiRangeClass * klass) {
	GParamSpec * param;

	G_OBJECT_CLASS(klass)->set_property = yui_range_set_property;
	G_OBJECT_CLASS(klass)->get_property = yui_range_get_property;

	param = g_param_spec_pointer("key-file", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_KEYFILE, param);

	param = g_param_spec_pointer("group", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_GROUP, param);

	param = g_param_spec_pointer("key", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_KEY, param);

	param = g_param_spec_pointer("items", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_ITEMS, param);

	yui_range_signals[YUI_RANGE_CHANGED_SIGNAL] = g_signal_new ("changed", G_TYPE_FROM_CLASS(klass), G_SIGNAL_RUN_FIRST | G_SIGNAL_ACTION,
			G_STRUCT_OFFSET(YuiRangeClass, yui_range_change), NULL, NULL, g_cclosure_marshal_VOID__VOID, G_TYPE_NONE, 0);
}

static void yui_range_init (YuiRange * yfe) {
        gtk_container_set_border_width(GTK_CONTAINER(yfe), 10);

        yfe->combo = gtk_combo_box_new_text();

        gtk_box_pack_start(GTK_BOX(yfe), yfe->combo, TRUE, TRUE, 0);
}

GtkWidget * yui_range_new(GKeyFile * keyfile, const gchar * group, const gchar * key, YuiRangeItem * items) {
	GtkWidget * entry;
	YuiRange * yfe;
	gchar * current;
	guint i;

	entry = GTK_WIDGET(g_object_new(yui_range_get_type(), "spacing", 10,
		"key-file", keyfile, "group", group, "key", key, "items", items, NULL));
	yfe = YUI_RANGE(entry);

	current = g_key_file_get_value(yfe->keyfile, yfe->group, yfe->key, 0);
	i = 0;
	while(yfe->items[i].name) {
		gtk_combo_box_append_text(GTK_COMBO_BOX(yfe->combo), yfe->items[i].name);
		if (current && !strcmp(yfe->items[i].value, current))
			gtk_combo_box_set_active(GTK_COMBO_BOX(yfe->combo), i);
		i++;
	}
	if ( !current ) {
		gtk_combo_box_set_active(GTK_COMBO_BOX(yfe->combo), 0);
		g_key_file_set_value(yfe->keyfile, yfe->group, yfe->key, items[0].value);
	}

        g_signal_connect(GTK_COMBO_BOX(yfe->combo), "changed", G_CALLBACK(yui_range_changed), yfe);

	return entry;
}

static void yui_range_changed(GtkWidget * entry, YuiRange * yfe) {
	g_key_file_set_value(yfe->keyfile, yfe->group, yfe->key,
			yfe->items[gtk_combo_box_get_active(GTK_COMBO_BOX(yfe->combo))].value);
	g_signal_emit(G_OBJECT(yfe), yui_range_signals[YUI_RANGE_CHANGED_SIGNAL], 0);
}

gint yui_range_get_active(YuiRange * range) {
	return gtk_combo_box_get_active(GTK_COMBO_BOX(range->combo));
}
