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

#ifndef YUI_MEM_H
#define YUI_MEM_H

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtktable.h>

#include "yuiwindow.h"

G_BEGIN_DECLS

#define YUI_MEM_TYPE            (yui_mem_get_type ())
#define YUI_MEM(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_MEM_TYPE, YuiMem))
#define YUI_MEM_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_MEM_TYPE, YuiMemClass))
#define IS_YUI_MEM(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_MEM_TYPE))
#define IS_YUI_MEM_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_MEM_TYPE))

typedef struct _YuiMem       YuiMem;
typedef struct _YuiMemClass  YuiMemClass;

struct _YuiMem
{
  GtkWindow dialog;

  GtkWidget * toolbar;

  GtkListStore * store;
  GtkWidget * quickCombo;

  guint wLine;
  guint32 address;
  gulong paused_handler;
  gulong running_handler;

  YuiWindow * yui;
};

struct _YuiMemClass
{
  GtkWindowClass parent_class;

  void (* yui_mem) (YuiMem * yv);
};

GType		yui_mem_get_type(void);
GtkWidget *	yui_mem_new	(YuiWindow * yui);
void		yui_mem_fill	(YuiMem * vdp1);
void		yui_mem_destroy	(YuiMem * vdp1);

G_END_DECLS

#endif
