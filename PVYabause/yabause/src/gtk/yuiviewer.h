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

#ifndef YUI_VIEWER_H
#define YUI_VIEWER_H

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define YUI_VIEWER_TYPE            (yui_viewer_get_type ())
#define YUI_VIEWER(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_VIEWER_TYPE, YuiViewer))
#define YUI_VIEWER_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_VIEWER_TYPE, YuiViewerClass))
#define IS_YUI_VIEWER(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_VIEWER_TYPE))
#define IS_YUI_VIEWER_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_VIEWER_TYPE))

typedef struct _YuiViewer       YuiViewer;
typedef struct _YuiViewerClass  YuiViewerClass;

struct _YuiViewer
{
	GtkDrawingArea parent;

	int w;
	int h;
	GdkPixbuf * pixbuf;
};

struct _YuiViewerClass
{
	GtkDrawingAreaClass parent_class;
};

GType		yui_viewer_get_type (void);
GtkWidget *	yui_viewer_new      (void);
void		yui_viewer_draw_pixbuf(YuiViewer * yv, GdkPixbuf * pixbuf, int w, int h);
void		yui_viewer_save     (YuiViewer * yv);
void		yui_viewer_clear    (YuiViewer * yv);

G_END_DECLS

#endif
