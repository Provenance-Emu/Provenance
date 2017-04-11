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

#include "yuiscsp.h"
#include "../scsp.h"
#include "../yabause.h"
#include "settings.h"

static void yui_scsp_class_init	(YuiScspClass * klass);
static void yui_scsp_init		(YuiScsp      * yfe);
static void yui_scsp_spin_cursor_changed(GtkWidget * spin, YuiScsp * scsp);
static void yui_scsp_clear(YuiScsp * scsp);

GType yui_scsp_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiScspClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_scsp_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiScsp),
	0,
	(GInstanceInitFunc) yui_scsp_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_WINDOW, "YuiScsp", &yfe_info, 0);
    }

  return yfe_type;
}

static void yui_scsp_class_init (UNUSED YuiScspClass * klass) {
}

static void yui_scsp_init (YuiScsp * yv) {
	gtk_window_set_title(GTK_WINDOW(yv), "SCSP");

	yv->vbox = gtk_vbox_new(FALSE, 2);
	gtk_container_set_border_width(GTK_CONTAINER(yv->vbox), 4);
	gtk_container_add(GTK_CONTAINER(yv), yv->vbox);

	yv->spin = gtk_spin_button_new_with_range(0, 31, 1);
	gtk_spin_button_set_range(GTK_SPIN_BUTTON(yv->spin), 0, 31);
	gtk_box_pack_start(GTK_BOX(yv->vbox), yv->spin, FALSE, FALSE, 4);
	g_signal_connect(G_OBJECT(yv->spin), "value-changed", GTK_SIGNAL_FUNC(yui_scsp_spin_cursor_changed), yv);

	g_signal_connect(G_OBJECT(yv), "delete-event", GTK_SIGNAL_FUNC(yui_scsp_destroy), NULL);

	{
		GtkWidget * scroll = gtk_scrolled_window_new(NULL, NULL);
		GtkWidget * text = gtk_text_view_new();
		gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
		gtk_text_view_set_editable(GTK_TEXT_VIEW(text), FALSE);
		gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(text), FALSE);
		yv->buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (text));
		gtk_container_add(GTK_CONTAINER(scroll), text);
		gtk_box_pack_start(GTK_BOX(yv->vbox), scroll, TRUE, TRUE, 4);
	}

	yv->hbox = gtk_hbutton_box_new();
	gtk_box_set_spacing(GTK_BOX(yv->hbox), 4);
	gtk_box_pack_start(GTK_BOX(yv->vbox ), yv->hbox, FALSE, FALSE, 4);

	yv->cursor = 0;
}

static gulong paused_handler;
static gulong running_handler;
static YuiWindow * yui;

GtkWidget * yui_scsp_new(YuiWindow * y) {
	GtkWidget * dialog;
	YuiScsp * yv;

	yui = y;

	dialog = GTK_WIDGET(g_object_new(yui_scsp_get_type(), NULL));
	yv = YUI_SCSP(dialog);

	{
		GtkWidget * but2, * but3, * but4;
		but2 = gtk_button_new();
		gtk_action_connect_proxy(gtk_action_group_get_action(yui->action_group, "run"), but2);
		gtk_box_pack_start(GTK_BOX(yv->hbox), but2, FALSE, FALSE, 2);

		but3 = gtk_button_new();
		gtk_action_connect_proxy(gtk_action_group_get_action(yui->action_group, "pause"), but3);
		gtk_box_pack_start(GTK_BOX(yv->hbox), but3, FALSE, FALSE, 2);

		but4 = gtk_button_new_from_stock("gtk-close");
		g_signal_connect_swapped(but4, "clicked", G_CALLBACK(yui_scsp_destroy), dialog);
		gtk_box_pack_start(GTK_BOX(yv->hbox), but4, FALSE, FALSE, 2);
	}
	paused_handler = g_signal_connect_swapped(yui, "paused", G_CALLBACK(yui_scsp_update), yv);
	running_handler = g_signal_connect_swapped(yui, "running", G_CALLBACK(yui_scsp_clear), yv);

	if ((yui->state & (YUI_IS_RUNNING | YUI_IS_INIT)) == YUI_IS_INIT)
		yui_scsp_update(yv);

	gtk_widget_show_all(GTK_WIDGET(yv));

	return dialog;
}

void yui_scsp_fill(YuiScsp * scsp) {
	gchar nameTemp[1024];

	yui_scsp_clear(scsp);

	ScspSlotDebugStats(scsp->cursor, nameTemp );

	gtk_text_buffer_set_text(scsp->buffer, g_strstrip(nameTemp), -1);
}

static void yui_scsp_spin_cursor_changed(GtkWidget * spin, YuiScsp * scsp) {
	scsp->cursor = gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(spin));
	yui_scsp_fill(scsp);
}

void yui_scsp_update(YuiScsp * scsp) {
	yui_scsp_fill(scsp);
}

void yui_scsp_destroy(YuiScsp * scsp) {
	g_signal_handler_disconnect(yui, running_handler);
	g_signal_handler_disconnect(yui, paused_handler);

	gtk_widget_destroy(GTK_WIDGET(scsp));
}

static void yui_scsp_clear(YuiScsp * scsp) {
	gtk_text_buffer_set_text(scsp->buffer, "", -1);
}
