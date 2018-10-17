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

#ifndef YUI_SCSP_H
#define YUI_SCSP_H

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtktable.h>

#include "yuiwindow.h"

G_BEGIN_DECLS

#define YUI_SCSP_TYPE            (yui_scsp_get_type ())
#define YUI_SCSP(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_SCSP_TYPE, YuiScsp))
#define YUI_SCSP_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_SCSP_TYPE, YuiScspClass))
#define IS_YUI_SCSP(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_SCSP_TYPE))
#define IS_YUI_SCSP_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_SCSP_TYPE))

typedef struct _YuiScsp       YuiScsp;
typedef struct _YuiScspClass  YuiScspClass;

struct _YuiScsp
{
  GtkWindow dialog;

  GtkWidget * vbox;
  GtkWidget * hbox;
  GtkWidget * commName;
  GtkWidget * commDesc;
  GtkWidget * spin;

  GtkTextBuffer * buffer;

  gint cursor;
};

struct _YuiScspClass
{
  GtkWindowClass parent_class;

  void (* yui_scsp) (YuiScsp * yv);
};

GType		yui_scsp_get_type       (void);
GtkWidget *	yui_scsp_new            (YuiWindow * yui);
void		yui_scsp_fill		(YuiScsp * scsp);
void		yui_scsp_update		(YuiScsp * scsp);
void		yui_scsp_destroy	(YuiScsp * scsp);

G_END_DECLS

#endif
