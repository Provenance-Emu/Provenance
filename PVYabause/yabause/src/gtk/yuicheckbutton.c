/*  Copyright 2006 Guillaume Duhamel
    Copyright 2005-2006 Fabien Coulon
    Copyright 2009 Andrew Church

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

#include "yuicheckbutton.h"

static void yui_check_button_class_init(YuiCheckButtonClass * klass);
static void yui_check_button_init      (YuiCheckButton      * ycb);
static void yui_check_button_toggled   (GtkToggleButton * button, YuiCheckButton * ycb);

GType yui_check_button_get_type (void) {
  static GType ycb_type = 0;

  if (!ycb_type)
    {
      static const GTypeInfo ycb_info =
      {
	sizeof (YuiCheckButtonClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_check_button_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiCheckButton),
	0,
	(GInstanceInitFunc) yui_check_button_init,
        NULL,
      };

      ycb_type = g_type_register_static(GTK_TYPE_CHECK_BUTTON, "YuiCheckButton", &ycb_info, 0);
    }

  return ycb_type;
}

#define PROP_KEYFILE	1
#define PROP_GROUP	2
#define PROP_KEY	3

static void yui_check_button_set_property(GObject * object, guint property_id,
		const GValue * value, GParamSpec * pspec) {
	switch(property_id) {
		case PROP_KEYFILE:
			YUI_CHECK_BUTTON(object)->keyfile = g_value_get_pointer(value);
			break;
		case PROP_GROUP:
			YUI_CHECK_BUTTON(object)->group = g_value_get_pointer(value);
			break;
		case PROP_KEY:
			YUI_CHECK_BUTTON(object)->key = g_value_get_pointer(value);
			break;
	}
}

static void yui_check_button_get_property(GObject * object, guint property_id,
		GValue * value, GParamSpec * pspec) {
}

enum { YUI_CHECK_BUTTON_CHANGED_SIGNAL, LAST_SIGNAL };

static guint yui_check_button_signals[LAST_SIGNAL] = { 0 };

static void yui_check_button_class_init (YuiCheckButtonClass * klass) {
	GParamSpec * param;

	G_OBJECT_CLASS(klass)->set_property = yui_check_button_set_property;
	G_OBJECT_CLASS(klass)->get_property = yui_check_button_get_property;

	param = g_param_spec_pointer("key-file", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_KEYFILE, param);

	param = g_param_spec_pointer("group", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_GROUP, param);

	param = g_param_spec_pointer("key", 0, 0, G_PARAM_READABLE | G_PARAM_WRITABLE);
	g_object_class_install_property(G_OBJECT_CLASS(klass), PROP_KEY, param);

	yui_check_button_signals[YUI_CHECK_BUTTON_CHANGED_SIGNAL] = g_signal_new ("changed", G_TYPE_FROM_CLASS(klass), G_SIGNAL_RUN_FIRST | G_SIGNAL_ACTION,
			G_STRUCT_OFFSET(YuiCheckButtonClass, yui_check_button_change), NULL, NULL, g_cclosure_marshal_VOID__VOID, G_TYPE_NONE, 0);
}

static void yui_check_button_init (YuiCheckButton * ycb) {
}

GtkWidget * yui_check_button_new(const gchar * label, GKeyFile * keyfile, const gchar * group, const gchar * key) {
	GtkWidget * button;
	YuiCheckButton * ycb;
	gboolean current;

	button = GTK_WIDGET(g_object_new(yui_check_button_get_type(),
		"label", label,
		"key-file", keyfile, "group", group, "key", key, NULL));
	ycb = YUI_CHECK_BUTTON(button);

	gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(ycb), TRUE);

	current = g_key_file_get_boolean(ycb->keyfile, ycb->group, ycb->key, NULL);
	gtk_toggle_button_set_state(GTK_TOGGLE_BUTTON(ycb), current);

        g_signal_connect(GTK_TOGGLE_BUTTON(ycb), "toggled", G_CALLBACK(yui_check_button_toggled), ycb);

	return button;
}

static void yui_check_button_toggled(GtkToggleButton * button, YuiCheckButton * ycb) {
	g_key_file_set_boolean(ycb->keyfile, ycb->group, ycb->key,
	                       gtk_toggle_button_get_active(button));
	g_signal_emit(G_OBJECT(ycb), yui_check_button_signals[YUI_CHECK_BUTTON_CHANGED_SIGNAL], 0);
}

gboolean yui_check_button_get_active(YuiCheckButton * ycb) {
	return gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(ycb));
}
