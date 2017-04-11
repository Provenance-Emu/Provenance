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

#ifndef YUI_VDP1_H
#define YUI_VDP1_H

#include <gtk/gtk.h>

#include "yuiwindow.h"
#include "../core.h"

G_BEGIN_DECLS

#define YUI_VDP1_TYPE            (yui_vdp1_get_type ())
#define YUI_VDP1(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_VDP1_TYPE, YuiVdp1))
#define YUI_VDP1_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_VDP1_TYPE, YuiVdp1Class))
#define IS_YUI_VDP1(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_VDP1_TYPE))
#define IS_YUI_VDP1_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_VDP1_TYPE))

#define MAX_VDP1_COMMAND 4000

typedef struct _YuiVdp1       YuiVdp1;
typedef struct _YuiVdp1Class  YuiVdp1Class;

struct _YuiVdp1
{
  GtkWindow dialog;

  GtkWidget * image;
  GtkWidget * toolbar;

  GtkListStore * store;
  GtkTextBuffer * buffer;

  gint cursor;
  u32 * texture;
  int w;
  int h;

  gulong paused_handler;
  gulong running_handler;
  YuiWindow * yui;
};

struct _YuiVdp1Class
{
  GtkWindowClass parent_class;

  void (* yui_vdp1) (YuiVdp1 * yv);
};

GType		yui_vdp1_get_type       (void);
GtkWidget *	yui_vdp1_new            (YuiWindow * yui);
void		yui_vdp1_fill		(YuiVdp1 * vdp1);
void		yui_vdp1_update		(YuiVdp1 * vdp1);
void		yui_vdp1_destroy	(YuiVdp1 * vdp1);

G_END_DECLS

#endif
