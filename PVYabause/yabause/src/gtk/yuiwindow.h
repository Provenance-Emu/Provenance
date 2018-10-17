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

#ifndef YUI_WINDOW_H
#define YUI_WINDOW_H

#include <gtk/gtk.h>
#include <glib.h>
#include <glib-object.h>
#include <gtk/gtkwindow.h>

G_BEGIN_DECLS

#define YUI_WINDOW_TYPE            (yui_window_get_type ())
#define YUI_WINDOW(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_WINDOW_TYPE, YuiWindow))
#define YUI_WINDOW_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_WINDOW_TYPE, YuiWindowClass))
#define IS_YUI_WINDOW(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_WINDOW_TYPE))
#define IS_YUI_WINDOW_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_WINDOW_TYPE))

typedef struct _YuiAction       YuiAction;
typedef struct _YuiWindow       YuiWindow;
typedef struct _YuiWindowClass  YuiWindowClass;

struct _YuiAction {
	guint key;
	const char * name;
	void (*press)(void);
	void (*release)(void);
};

#define YUI_IS_INIT	1
#define YUI_IS_RUNNING	2

struct _YuiWindow {
	GtkWindow hbox;

        GtkWidget * logpopup;
	GtkWidget * box;
	GtkWidget * menu;
	GtkWidget * area;
	GtkWidget * log;

	YuiAction * actions;
	gulong clean_handler;
	GCallback init_func;
	gpointer init_data;
	GSourceFunc run_func;
	GCallback reset_func;

	guint state;

	GtkActionGroup * action_group;
};

struct _YuiWindowClass {
	GtkWindowClass parent_class;

	void (* yui_window_running) (YuiWindow * yw);
	void (* yui_window_paused) (YuiWindow * yw);
};

GType		yui_window_get_type	(void);
GtkWidget *	yui_window_new		(YuiAction * act, GCallback ifunc, gpointer idata,
					GSourceFunc rfunc, GCallback resetfunc);
void		yui_window_update	(YuiWindow * yui);
void		yui_window_log		(YuiWindow * yui, const char * message);
void		yui_window_show_log	(YuiWindow * yui);
void		yui_window_start	(YuiWindow * yui);
void		yui_window_run		(YuiWindow * yui);
void		yui_window_pause	(YuiWindow * yui);
void		yui_window_reset	(YuiWindow * yui);
void            yui_window_invalidate   (YuiWindow * yui);
void		yui_window_set_fullscreen(YuiWindow * yui, gboolean f);
void		yui_window_set_frameskip(YuiWindow * yui, gboolean f);

G_END_DECLS

#endif /* YUI_WINDOW_H */
