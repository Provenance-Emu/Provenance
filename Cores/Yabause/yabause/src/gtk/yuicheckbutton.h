/*  Copyright 2006 Guillaume Duhamel
    Copyright 2005-2006 Fabien Coulon
    Copyright 2009 Andrew Church

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

#ifndef YUI_CHECK_BUTTON_H
#define YUI_CHECK_BUTTON_H

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtkcheckbutton.h>

G_BEGIN_DECLS

#define YUI_CHECK_BUTTON_TYPE            (yui_check_button_get_type ())
#define YUI_CHECK_BUTTON(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_CHECK_BUTTON_TYPE, YuiCheckButton))
#define YUI_CHECK_BUTTON_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_CHECK_BUTTON_TYPE, YuiCheckButtonClass))
#define IS_YUI_CHECK_BUTTON(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_CHECK_BUTTON_TYPE))
#define IS_YUI_CHECK_BUTTON_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_CHECK_BUTTON_TYPE))

typedef struct _YuiCheckButton       YuiCheckButton;
typedef struct _YuiCheckButtonClass  YuiCheckButtonClass;

struct _YuiCheckButton
{
  GtkCheckButton button;

  GKeyFile * keyfile;
  gchar * group;
  gchar * key;
};

struct _YuiCheckButtonClass
{
  GtkCheckButtonClass parent_class;

  void (* yui_check_button_change) (YuiCheckButton * ycb);
};

GType          yui_check_button_get_type       (void);
GtkWidget *    yui_check_button_new            (const gchar * label, GKeyFile * keyfile, const gchar * group, const gchar * key);
gboolean       yui_check_button_get_active     (YuiCheckButton * ycb);

G_END_DECLS

#endif /* YUI_CHECK_BUTTON_H */
