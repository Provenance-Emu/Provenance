/*  Copyright 2006 Guillaume Duhamel

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
#include "yuirange.h"
#include "yuiresolution.h"
#include "yuipage.h"
#include "../core.h"

static void yui_page_class_init	(YuiPageClass * klass);
static void yui_page_init		(YuiPage      * yfe);

GType yui_page_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiPageClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_page_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiPage),
	0,
	(GInstanceInitFunc) yui_page_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_VBOX, "YuiPage", &yfe_info, 0);
    }

  return yfe_type;
}

static void yui_page_class_init (UNUSED YuiPageClass * klass) {
}

static void yui_page_init (UNUSED YuiPage * yp) {
}

GtkWidget * yui_page_new(GKeyFile * keyfile) {
	GtkWidget * widget;
	YuiPage * yp;

	widget = GTK_WIDGET(g_object_new(yui_page_get_type(), NULL));
	yp = YUI_PAGE(widget);

	yp->keyfile = keyfile;

	return widget;
}

GtkWidget * yui_page_add(YuiPage * yp, const gchar * name) {
	GtkWidget * label;
	GtkWidget * frame;
	GtkWidget * box;
	gchar buffer[1024];

	frame = gtk_frame_new(NULL);
  
	gtk_box_pack_start(GTK_BOX(yp), frame, FALSE, TRUE, 0);
	gtk_frame_set_shadow_type(GTK_FRAME(frame), GTK_SHADOW_NONE);

	box = gtk_vbox_new(FALSE, 0);
	gtk_container_add(GTK_CONTAINER(frame), box);

	sprintf(buffer, "<b>%s</b>", name);

	label = gtk_label_new(buffer);
	gtk_frame_set_label_widget(GTK_FRAME(frame), label);
	gtk_label_set_use_markup(GTK_LABEL(label), TRUE);

	return box;
}
