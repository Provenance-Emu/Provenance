/*  Copyright 2006-2007 Guillaume Duhamel
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

#include "yuiviewer.h"
#include "yuivdp1.h"
#include "../vdp1.h"
#include "../yabause.h"
#include "settings.h"

static void yui_vdp1_class_init	(YuiVdp1Class * klass);
static void yui_vdp1_init		(YuiVdp1      * yfe);
static void yui_vdp1_view_cursor_changed(GtkWidget * view, YuiVdp1 * vdp1);
static void yui_vdp1_clear(YuiVdp1 * vdp1);
static void yui_vdp1_draw(YuiVdp1 * vdp1);

GType yui_vdp1_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiVdp1Class),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_vdp1_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiVdp1),
	0,
	(GInstanceInitFunc) yui_vdp1_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_WINDOW, "YuiVdp1", &yfe_info, 0);
    }

  return yfe_type;
}

static void yui_vdp1_class_init (UNUSED YuiVdp1Class * klass) {
}

static void yui_vdp1_init (YuiVdp1 * yv) {
	GtkWidget * hbox, * vbox, * vbox2, * view;

	gtk_window_set_title(GTK_WINDOW(yv), "VDP1");

	vbox = gtk_vbox_new(FALSE, 0);
	gtk_container_set_border_width(GTK_CONTAINER(vbox), 0);
	gtk_container_add(GTK_CONTAINER(yv), vbox);

	yv->toolbar = gtk_toolbar_new();

	gtk_toolbar_set_style(GTK_TOOLBAR(yv->toolbar), GTK_TOOLBAR_ICONS);

	gtk_box_pack_start(GTK_BOX(vbox), yv->toolbar, FALSE, FALSE, 0);

	hbox = gtk_hpaned_new();
	gtk_box_pack_start(GTK_BOX(vbox), hbox, TRUE, TRUE, 4);

	yv->store = gtk_list_store_new(2, G_TYPE_STRING, GDK_TYPE_PIXBUF);
	view = gtk_tree_view_new_with_model(GTK_TREE_MODEL (yv->store));
	gtk_tree_view_set_headers_visible(GTK_TREE_VIEW(view), FALSE);
	{
		GtkWidget * scroll;
		GtkCellRenderer *renderer;
		GtkCellRenderer *icon;
		GtkTreeViewColumn *column;

		scroll = gtk_scrolled_window_new(NULL, NULL);
		gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);

		renderer = gtk_cell_renderer_text_new();
		column = gtk_tree_view_column_new_with_attributes("Command", renderer, "text", 0, NULL);
		gtk_tree_view_append_column(GTK_TREE_VIEW (view), column);

		icon = gtk_cell_renderer_pixbuf_new();
		g_object_set(icon, "xalign", 0, NULL);
		column = gtk_tree_view_column_new_with_attributes("Icon", icon, "pixbuf", 1, NULL);
		gtk_tree_view_append_column(GTK_TREE_VIEW (view), column);

		gtk_container_add(GTK_CONTAINER(scroll), view);
		gtk_paned_pack1(GTK_PANED(hbox), scroll, FALSE, TRUE);
	}
	g_signal_connect(view, "cursor-changed", G_CALLBACK(yui_vdp1_view_cursor_changed), yv);

	g_signal_connect(G_OBJECT(yv), "delete-event", GTK_SIGNAL_FUNC(yui_vdp1_destroy), NULL);

	vbox2 = gtk_vpaned_new();
	gtk_paned_pack2(GTK_PANED(hbox), vbox2, TRUE, TRUE);
	{
		GtkWidget * scroll = gtk_scrolled_window_new(NULL, NULL);
		GtkWidget * text = gtk_text_view_new();
		gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
		gtk_text_view_set_editable(GTK_TEXT_VIEW(text), FALSE);
		gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(text), FALSE);
		yv->buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (text));
		gtk_container_add(GTK_CONTAINER(scroll), text);
		gtk_paned_pack1(GTK_PANED(vbox2), scroll, FALSE, TRUE);
	}
	yv->image = yui_viewer_new();
	{
		GtkWidget * scroll = gtk_scrolled_window_new(NULL, NULL);
		gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
		gtk_scrolled_window_add_with_viewport(GTK_SCROLLED_WINDOW(scroll), yv->image);
		gtk_paned_pack2(GTK_PANED(vbox2), scroll, TRUE, TRUE);
	}

	yv->cursor = 0;
	yv->texture = NULL;

	gtk_window_set_default_size(GTK_WINDOW(yv), 500, 450);

	gtk_paned_set_position(GTK_PANED(hbox), 250);

	gtk_paned_set_position(GTK_PANED(vbox2), 200);
}

GtkWidget * yui_vdp1_new(YuiWindow * y) {
	GtkWidget * dialog;
	YuiVdp1 * yv;

	dialog = GTK_WIDGET(g_object_new(yui_vdp1_get_type(), NULL));
	yv = YUI_VDP1(dialog);

	yv->yui = y;

	if (!( yv->yui->state & YUI_IS_INIT )) {
	  yui_window_run(yv->yui);
	  yui_window_pause(yv->yui);
	}

	{
		GtkToolItem * play_button, * pause_button;

		play_button = gtk_tool_button_new_from_stock("run");
		gtk_action_connect_proxy(gtk_action_group_get_action(yv->yui->action_group, "run"), GTK_WIDGET(play_button));
		gtk_toolbar_insert(GTK_TOOLBAR(yv->toolbar), GTK_TOOL_ITEM(play_button), -1);

		pause_button = gtk_tool_button_new_from_stock("pause");
		gtk_action_connect_proxy(gtk_action_group_get_action(yv->yui->action_group, "pause"), GTK_WIDGET(pause_button));
		gtk_toolbar_insert(GTK_TOOLBAR(yv->toolbar), GTK_TOOL_ITEM(pause_button), -1);
	}
	yv->paused_handler = g_signal_connect_swapped(yv->yui, "paused", G_CALLBACK(yui_vdp1_update), yv);
	yv->running_handler = g_signal_connect_swapped(yv->yui, "running", G_CALLBACK(yui_vdp1_clear), yv);

	if ((yv->yui->state & (YUI_IS_RUNNING | YUI_IS_INIT)) == YUI_IS_INIT)
		yui_vdp1_update(yv);

	gtk_widget_show_all(GTK_WIDGET(yv));

	return dialog;
}

void yui_vdp1_fill(YuiVdp1 * vdp1) {
	gint j;
	gchar * string;
	gchar nameTemp[1024];
	GtkTreeIter iter;

	yui_vdp1_clear(vdp1);

	j = 0;

	string = Vdp1DebugGetCommandNumberName(j);
	while(string && (j < MAX_VDP1_COMMAND)) {
		gtk_list_store_append(vdp1->store, &iter);
		gtk_list_store_set(vdp1->store, &iter, 0, string, -1);

		{
			u32 * icontext;
			int wtext, htext;
			int rowstride;
			GdkPixbuf * pixbuftext, * resized;
			float ratio;

			icontext = Vdp1DebugTexture(j, &wtext, &htext);

			if ((icontext != NULL) && (wtext > 0) && (htext > 0)) {
 				rowstride = wtext * 4;
 				rowstride += (rowstride % 4)? (4 - (rowstride % 4)): 0;
				pixbuftext = gdk_pixbuf_new_from_data((const guchar *) icontext, GDK_COLORSPACE_RGB, TRUE, 8,
					wtext, htext, rowstride, yui_texture_free, NULL);

				ratio = (float) 16 / htext;
				if (htext > 16) {
					resized = gdk_pixbuf_scale_simple(pixbuftext, wtext * ratio, 16, GDK_INTERP_BILINEAR);
				} else {
					resized = gdk_pixbuf_scale_simple(pixbuftext, wtext, htext, GDK_INTERP_BILINEAR);
				}

				gtk_list_store_set(vdp1->store, &iter, 1, resized, -1);

				g_object_unref(pixbuftext);
				g_object_unref(resized);
			}
		}

		j++;
		string = Vdp1DebugGetCommandNumberName(j);
	}

	Vdp1DebugCommand(vdp1->cursor, nameTemp);
	gtk_text_buffer_set_text(vdp1->buffer, g_strstrip(nameTemp), -1);
	vdp1->texture = Vdp1DebugTexture(vdp1->cursor, &vdp1->w, &vdp1->h);
	yui_vdp1_draw(vdp1);
}

static void yui_vdp1_view_cursor_changed(GtkWidget * view, YuiVdp1 * vdp1) {
	GtkTreePath * path;
	gchar * strpath;
	int i;

	gtk_tree_view_get_cursor(GTK_TREE_VIEW(view), &path, NULL);

	if (path) {
		gchar nameTemp[1024];

		yui_viewer_clear(YUI_VIEWER(vdp1->image));

		strpath = gtk_tree_path_to_string(path);

		sscanf(strpath, "%i", &i);

		vdp1->cursor = i;

		Vdp1DebugCommand(i, nameTemp);
		gtk_text_buffer_set_text(vdp1->buffer, g_strstrip(nameTemp), -1);
		vdp1->texture = Vdp1DebugTexture(i, &vdp1->w, &vdp1->h);
		yui_vdp1_draw(vdp1);

		g_free(strpath);
		gtk_tree_path_free(path);
	}
}

void yui_vdp1_update(YuiVdp1 * vdp1) {
	gint i;
	for(i = 0 ; i < MAX_VDP1_COMMAND ; i++ ) if ( !Vdp1DebugGetCommandNumberName(i)) break;
	vdp1->cursor = 0;
	yui_vdp1_fill(vdp1);
}

void yui_vdp1_destroy(YuiVdp1 * vdp1) {
	g_signal_handler_disconnect(vdp1->yui, vdp1->running_handler);
	g_signal_handler_disconnect(vdp1->yui, vdp1->paused_handler);

	gtk_widget_destroy(GTK_WIDGET(vdp1));
}

static void yui_vdp1_clear(YuiVdp1 * vdp1) {
	gtk_list_store_clear(vdp1->store);
	gtk_text_buffer_set_text(vdp1->buffer, "", -1);
	yui_viewer_clear(YUI_VIEWER(vdp1->image));
}

static void yui_vdp1_draw(YuiVdp1 * vdp1) {
	GdkPixbuf * pixbuf;
 	int rowstride;
 
 	if ((vdp1->texture != NULL) && (vdp1->w > 0) && (vdp1->h > 0)) {
 		rowstride = vdp1->w * 4;
 		rowstride += (rowstride % 4)? (4 - (rowstride % 4)): 0;
 		pixbuf = gdk_pixbuf_new_from_data((const guchar *) vdp1->texture, GDK_COLORSPACE_RGB, TRUE, 8,
			vdp1->w, vdp1->h, rowstride, yui_texture_free, NULL);
 
 		yui_viewer_draw_pixbuf(YUI_VIEWER(vdp1->image), pixbuf, vdp1->w, vdp1->h);
 
 		g_object_unref(pixbuf);
 	}
}
