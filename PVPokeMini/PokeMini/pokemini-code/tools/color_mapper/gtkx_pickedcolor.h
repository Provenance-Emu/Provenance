/*
  PokeMini Color Mapper
  Copyright (C) 2011-2012  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef GTKX_PICKEDCOLOR_H
#define GTKX_PICKEDCOLOR_H

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define GTKX_TYPE_PICKEDCOLOR            (gtkx_pickedcolor_get_type ())
#define GTKX_PICKEDCOLOR(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), GTKX_TYPE_PICKEDCOLOR, GtkXpickedcolor))
#define GTKX_PICKEDCOLOR_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), GTKX_TYPE_PICKEDCOLOR, GtkXpickedcolorClass))
#define GTKX_IS_PICKEDCOLOR(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GTKX_TYPE_PICKEDCOLOR))
#define GTKX_IS_PICKEDCOLOR_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), GTKX_TYPE_PICKEDCOLOR))
#define GTKX_PICKEDCOLOR_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), GTKX_TYPE_PICKEDCOLOR, GtkXpickedcolorClass))

typedef struct _GtkXpickedcolor       GtkXpickedcolor;
typedef struct _GtkXpickedcolorClass  GtkXpickedcolorClass;

#define GtkXpickedcolor_palsize	4

struct _GtkXpickedcolor
{
	GtkDrawingArea drawarea;
	unsigned char color_off;
	unsigned char color_on;
	int color_off_enabled;
	int color_on_enabled;
	int color_off_pal[GtkXpickedcolor_palsize];
	int color_on_pal[GtkXpickedcolor_palsize];
};

struct _GtkXpickedcolorClass
{
	GtkDrawingAreaClass parent_class;
};

GType      gtkx_pickedcolor_get_type (void) G_GNUC_CONST;
GtkWidget *gtkx_pickedcolor_new();
void       gtkx_pickedcolor_setcolorindex(GtkXpickedcolor *widg, int type, int index);


G_END_DECLS

#endif
