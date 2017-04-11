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

#ifndef YUI_FILE_ENTRY_H
#define YUI_FILE_ENTRY_H

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtktable.h>

G_BEGIN_DECLS

#define YUI_FILE_ENTRY_TYPE            (yui_file_entry_get_type ())
#define YUI_FILE_ENTRY(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_FILE_ENTRY_TYPE, YuiFileEntry))
#define YUI_FILE_ENTRY_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_FILE_ENTRY_TYPE, YuiFileEntryClass))
#define IS_YUI_FILE_ENTRY(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_FILE_ENTRY_TYPE))
#define IS_YUI_FILE_ENTRY_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_FILE_ENTRY_TYPE))

#define YUI_FILE_ENTRY_BROWSE	1
#define YUI_FILE_ENTRY_DIRECTORY	2

typedef struct _YuiFileEntry       YuiFileEntry;
typedef struct _YuiFileEntryClass  YuiFileEntryClass;

struct _YuiFileEntry
{
  GtkHBox hbox;

  GtkWidget * entry;
  GtkWidget * button;

  GKeyFile * keyfile;
  gchar * group;
  gchar * key;

  int flags;
};

struct _YuiFileEntryClass
{
  GtkHBoxClass parent_class;

  void (* yui_file_entry) (YuiFileEntry * yfe);
};

GType          yui_file_entry_get_type        (void);
GtkWidget*     yui_file_entry_new             (GKeyFile *, const gchar *, const gchar *, gint flags, const gchar * label);

G_END_DECLS

#endif /* YUI_FILE_ENTRY_H */
