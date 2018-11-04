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

#ifndef PALETTEPICKER_H
#define PALETTEPICKER_H

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define GTKX_TYPE_PALETTEPICKER            (gtkx_palettepicker_get_type ())
#define GTKX_PALETTEPICKER(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), GTKX_TYPE_PALETTEPICKER, GtkXpalettepicker))
#define GTKX_PALETTEPICKER_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), GTKX_TYPE_PALETTEPICKER, GtkXpalettepickerClass))
#define GTKX_IS_PALETTEPICKER(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GTKX_TYPE_PALETTEPICKER))
#define GTKX_IS_PALETTEPICKER_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), GTKX_TYPE_PALETTEPICKER))
#define GTKX_PALETTEPICKER_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), GTKX_TYPE_PALETTEPICKER, GtkXpalettepickerClass))

typedef struct _GtkXpalettepicker       GtkXpalettepicker;
typedef struct _GtkXpalettepickerClass  GtkXpalettepickerClass;

struct _GtkXpalettepicker
{
	GtkDrawingArea drawarea;
	cairo_surface_t *paletteimg;
	int inside;
	unsigned char color_off;
	unsigned char color_on;
	unsigned char color_under;
	void (*on_color)(GtkWidget *widg, int type, int index);
};

struct _GtkXpalettepickerClass
{
	GtkDrawingAreaClass parent_class;
};

GType      gtkx_palettepicker_get_type (void) G_GNUC_CONST;
GtkWidget *gtkx_palettepicker_new();
void       gtkx_palettepicker_swapcolors(GtkXpalettepicker *widg);
void       gtkx_palettepicker_setcolorindex(GtkXpalettepicker *widg, int type, int index);

G_END_DECLS

#endif
