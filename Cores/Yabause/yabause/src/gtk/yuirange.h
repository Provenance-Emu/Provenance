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

#ifndef YUI_RANGE_H
#define YUI_RANGE_H

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtktable.h>

G_BEGIN_DECLS

#define YUI_RANGE_TYPE            (yui_range_get_type ())
#define YUI_RANGE(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_RANGE_TYPE, YuiRange))
#define YUI_RANGE_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_RANGE_TYPE, YuiRangeClass))
#define IS_YUI_RANGE(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_RANGE_TYPE))
#define IS_YUI_RANGE_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_RANGE_TYPE))

typedef struct _YuiRangeItem   YuiRangeItem;
typedef struct _YuiRange       YuiRange;
typedef struct _YuiRangeClass  YuiRangeClass;

struct _YuiRangeItem
{
  const gchar * value;
  const gchar * name;
};

struct _YuiRange
{
  GtkHBox hbox;

  GtkWidget * combo;

  GKeyFile * keyfile;
  gchar * group;
  gchar * key;

  YuiRangeItem * items;
};

struct _YuiRangeClass
{
  GtkHBoxClass parent_class;

  void (* yui_range_change) (YuiRange * yfe);
};

GType          yui_range_get_type       (void);
GtkWidget *    yui_range_new            (GKeyFile * keyfile, const gchar * group, const gchar * key, YuiRangeItem * items);
gint           yui_range_get_active	(YuiRange * range);

G_END_DECLS

#endif /* YUI_RANGE_H */
