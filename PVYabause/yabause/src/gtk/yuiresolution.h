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

#ifndef YUI_RESOLUTION_H
#define YUI_RESOLUTION_H

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtktable.h>

G_BEGIN_DECLS

#define YUI_RESOLUTION_TYPE            (yui_resolution_get_type ())
#define YUI_RESOLUTION(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_RESOLUTION_TYPE, YuiResolution))
#define YUI_RESOLUTION_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), YUI_RESOLUTION_TYPE, YuiResolutionClass))
#define IS_YUI_RESOLUTION(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_RESOLUTION_TYPE))
#define IS_YUI_RESOLUTION_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), YUI_RESOLUTION_TYPE))


typedef struct _YuiResolution       YuiResolution;
typedef struct _YuiResolutionClass  YuiResolutionClass;

struct _YuiResolution
{
	GtkHBox table;

	GtkWidget * entry_w;
	GtkWidget * entry_h;
	GtkWidget * options;

	GKeyFile * keyfile;
	gchar * group;
};

struct _YuiResolutionClass {
	GtkHBoxClass parent_class;

	void (* yui_resolution) (YuiResolution *yie);
};

GType          yui_resolution_get_type        (void);
GtkWidget*     yui_resolution_new             (GKeyFile * keyfile, const gchar * group);

G_END_DECLS

#endif /* YUI_RESOLUTION_H */
