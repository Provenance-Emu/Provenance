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

#ifndef YUI_PAGE_H
#define YUI_PAGE_H

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtktable.h>

G_BEGIN_DECLS

#define YUI_PAGE_TYPE            (yui_page_get_type ())
#define YUI_PAGE(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_PAGE_TYPE, YuiPage))
#define YUI_PAGE_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_PAGE_TYPE, YuiPageClass))
#define IS_YUI_PAGE(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_PAGE_TYPE))
#define IS_YUI_PAGE_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_PAGE_TYPE))

#define YUI_FILE_SETTING	1
#define YUI_RANGE_SETTING	2
#define YUI_RESOLUTION_SETTING	3

typedef struct _YuiPage       YuiPage;
typedef struct _YuiPageClass  YuiPageClass;

struct _YuiPage
{
  GtkVBox vbox;

  GKeyFile * keyfile;
};

struct _YuiPageClass
{
  GtkHBoxClass parent_class;

  void (* yui_page) (YuiPage * yfe);
};

GType          yui_page_get_type        (void);
GtkWidget *    yui_page_new             (GKeyFile * keyfile);

GtkWidget *    yui_page_add		(YuiPage * yp, const gchar * name);

G_END_DECLS

#endif
