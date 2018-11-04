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

#include "yuiscreenshot.h"
#include "gtkglwidget.h"
#include "yuiviewer.h"
#include "../core.h"

static void yui_screenshot_class_init	(YuiScreenshotClass * klass);
static void yui_screenshot_init		(YuiScreenshot      * yfe);
static void yui_screenshot_update	(YuiScreenshot	* ys, gpointer data);
static gboolean yui_screenshot_draw(YuiScreenshot * ys);

GType yui_screenshot_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiScreenshotClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_screenshot_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiScreenshot),
	0,
	(GInstanceInitFunc) yui_screenshot_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_WINDOW, "YuiScreenshot", &yfe_info, 0);
    }

  return yfe_type;
}

static void yui_screenshot_class_init (UNUSED YuiScreenshotClass * klass) {
}

static YuiWindow * yui;

static void yui_screenshot_init (YuiScreenshot * yv) {
	GtkWidget * box;
	GtkWidget * button_box;
	GtkWidget * button;

	gtk_window_set_title(GTK_WINDOW(yv), "Screenshot");
	gtk_container_set_border_width(GTK_CONTAINER(yv), 4);

	box = gtk_vbox_new(FALSE, 4);
	gtk_container_add(GTK_CONTAINER(yv), box);

	yv->image = yui_viewer_new();
	gtk_box_pack_start(GTK_BOX(box), yv->image, FALSE, FALSE, 0);
	gtk_widget_set_size_request(GTK_WIDGET(yv->image), 320, 224);

	button_box = gtk_hbutton_box_new();
	gtk_box_pack_start(GTK_BOX(box), button_box, FALSE, FALSE, 0);

	button = gtk_button_new_from_stock(GTK_STOCK_REFRESH);
	gtk_box_pack_start(GTK_BOX(button_box), button, FALSE, FALSE, 0);
	g_signal_connect_swapped(button, "clicked", G_CALLBACK(yui_screenshot_update), yv);

	button = gtk_button_new_from_stock(GTK_STOCK_SAVE);
	gtk_box_pack_start(GTK_BOX(button_box), button, FALSE, FALSE, 0);
	g_signal_connect_swapped(button, "clicked", G_CALLBACK(yui_viewer_save), yv->image);

	button = gtk_button_new_from_stock(GTK_STOCK_CLOSE);
	gtk_box_pack_start(GTK_BOX(button_box), button, FALSE, FALSE, 0);
	g_signal_connect_swapped(button, "clicked", G_CALLBACK(gtk_widget_destroy), yv);
}

GtkWidget * yui_screenshot_new(YuiWindow * y) {
	GtkWidget * dialog;
	YuiScreenshot * yv;

	yui = y;

	dialog = GTK_WIDGET(g_object_new(yui_screenshot_get_type(), NULL));
	yv = YUI_SCREENSHOT(dialog);

	gtk_widget_show_all(dialog);
       
	yui_gl_dump_screen(YUI_GL(yui->area));
	yui_screenshot_draw(yv);

	return dialog;
}

static void yui_screenshot_update(YuiScreenshot	* ys, UNUSED gpointer data) {
	yui_gl_dump_screen(YUI_GL(yui->area));
	yui_screenshot_draw(ys);
}

static gboolean yui_screenshot_draw(YuiScreenshot * ys) {
	GdkPixbuf * pixbuf, * correct;

	pixbuf = gdk_pixbuf_new_from_data((const guchar *) YUI_GL(yui->area)->pixels, GDK_COLORSPACE_RGB, FALSE, 8,
			YUI_GL(yui->area)->pixels_width, YUI_GL(yui->area)->pixels_height, YUI_GL(yui->area)->pixels_rowstride, NULL, NULL);
	correct = gdk_pixbuf_flip(pixbuf, FALSE);

	yui_viewer_draw_pixbuf(YUI_VIEWER(ys->image), correct, YUI_GL(yui->area)->pixels_width, YUI_GL(yui->area)->pixels_height);

	g_object_unref(pixbuf);
	g_object_unref(correct);

	return TRUE;
}
