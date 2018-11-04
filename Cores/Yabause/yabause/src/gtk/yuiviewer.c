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
#include "gtkglwidget.h"
#include "../core.h"

static void yui_viewer_class_init	(YuiViewerClass * klass);
static void yui_viewer_init		(YuiViewer      * yfe);
static void yui_viewer_expose		(GtkWidget * widget, GdkEventExpose *event, gpointer data);

GType yui_viewer_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiViewerClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_viewer_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiViewer),
	0,
	(GInstanceInitFunc) yui_viewer_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_DRAWING_AREA, "YuiViewer", &yfe_info, 0);
    }

  return yfe_type;
}

static void yui_viewer_class_init (UNUSED YuiViewerClass * klass) {
}

static gint
my_popup_handler (GtkWidget *widget, GdkEvent *event)
{
  GtkMenu *menu;
  GdkEventButton *event_button;

  g_return_val_if_fail (widget != NULL, FALSE);
  g_return_val_if_fail (GTK_IS_MENU (widget), FALSE);
  g_return_val_if_fail (event != NULL, FALSE);

  /* The "widget" is the menu that was supplied when 
 *    * g_signal_connect_swapped() was called.
 *       */
  menu = GTK_MENU (widget);

  if (event->type == GDK_BUTTON_PRESS)
    {
      event_button = (GdkEventButton *) event;
      if (event_button->button == 3)
	{
	  gtk_menu_popup (menu, NULL, NULL, NULL, NULL, 
			  event_button->button, event_button->time);
	  return TRUE;
	}
    }

  return FALSE;
}

static void yui_viewer_init (YuiViewer * yv) {
	GtkWidget * menu;
	GtkWidget * item;

	gtk_widget_set_events(GTK_WIDGET(yv), GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK);

	menu = gtk_menu_new();
	item = gtk_image_menu_item_new_from_stock(GTK_STOCK_SAVE, NULL);

	gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);

	gtk_widget_show_all(menu);

	g_signal_connect_swapped(yv, "button-press-event", G_CALLBACK(my_popup_handler), menu);
	g_signal_connect(yv, "expose-event", G_CALLBACK(yui_viewer_expose), NULL);
	g_signal_connect_swapped(item, "activate", G_CALLBACK(yui_viewer_save), yv);

	yv->pixbuf = NULL;
}

GtkWidget * yui_viewer_new(void) {
	GtkWidget * dialog;

	dialog = GTK_WIDGET(g_object_new(yui_viewer_get_type(), NULL));

	return dialog;
}

static void yui_viewer_expose(GtkWidget * widget, GdkEventExpose *event, gpointer data) {
	YuiViewer * yv = YUI_VIEWER(widget);

	if (yv->pixbuf != NULL) {
		gdk_draw_pixbuf(widget->window, NULL, yv->pixbuf, 0, 0, 0, 0, yv->w, yv->h, GDK_RGB_DITHER_NONE, 0, 0);
	}
}

void yui_viewer_save(YuiViewer * yv) {
        GtkWidget * file_selector;
        gint result;
	char * filename;
	int rowstride;

        file_selector = gtk_file_chooser_dialog_new ("Please choose a file", NULL, GTK_FILE_CHOOSER_ACTION_SAVE,
                        GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL, GTK_STOCK_SAVE, GTK_RESPONSE_ACCEPT, NULL);

        gtk_widget_show(file_selector);

        result = gtk_dialog_run(GTK_DIALOG(file_selector));

        switch(result) {
                case GTK_RESPONSE_ACCEPT:
			rowstride = yv->w * 4;
			rowstride += (rowstride % 4)? (4 - (rowstride % 4)): 0;
			filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(file_selector));

			gdk_pixbuf_save(yv->pixbuf, filename, "png", NULL, NULL);

                        break;
                case GTK_RESPONSE_CANCEL:
                        break;
        }

        gtk_widget_destroy(file_selector);
}

void yui_viewer_draw_pixbuf(YuiViewer * yv, GdkPixbuf * pixbuf, int w, int h) {
	if (yv->pixbuf) {
		g_object_unref(yv->pixbuf);
	}
	yv->pixbuf = g_object_ref(pixbuf);
	yv->w = w;
	yv->h = h;
	gdk_window_clear(GTK_WIDGET(yv)->window);
	gtk_widget_queue_draw_area(GTK_WIDGET(yv), 0, 0, w, h);
}

void yui_viewer_clear(YuiViewer * yv) {
	if (GTK_WIDGET(yv)->window != NULL) {
		gdk_window_clear(GTK_WIDGET(yv)->window);
	}
}
