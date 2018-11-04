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

#ifndef GTKX_COLORMAPPER_H
#define GTKX_COLORMAPPER_H

#include <gtk/gtk.h>
#include <stdint.h>

G_BEGIN_DECLS

#define GTKX_TYPE_COLORMAPPER            (gtkx_colormapper_get_type ())
#define GTKX_COLORMAPPER(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), GTKX_TYPE_COLORMAPPER, GtkXcolormapper))
#define GTKX_COLORMAPPER_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), GTKX_TYPE_COLORMAPPER, GtkXcolormapperClass))
#define GTKX_IS_COLORMAPPER(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GTKX_TYPE_COLORMAPPER))
#define GTKX_IS_COLORMAPPER_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), GTKX_TYPE_COLORMAPPER))
#define GTKX_COLORMAPPER_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), GTKX_TYPE_COLORMAPPER, GtkXcolormapperClass))

typedef struct _GtkXcolormapper       GtkXcolormapper;
typedef struct _GtkXcolormapperClass  GtkXcolormapperClass;

struct _GtkXcolormapper
{
	GtkDrawingArea drawarea;
	cairo_surface_t *imgcache;
	cairo_surface_t *imgblendcache;
	uint32_t imgcache_w;
	uint32_t imgcache_h;
	uint32_t imgcache_p;
	uint32_t tileoff;
	uint32_t tileblendoff;
	int zoom;
	int grid;
	int negative;
	int dispblend;
	int spritemode;
	void (*on_motion)(GtkWidget *widg, int valid, uint32_t tileaddr, uint32_t subtileidx);
	int (*on_lbutton)(GtkWidget *widg, uint32_t tileidx, uint32_t subtileidx, int keystatus);
	int (*on_mbutton)(GtkWidget *widg, uint32_t tileidx, uint32_t subtileidx, int keystatus);
	int (*on_rbutton)(GtkWidget *widg, uint32_t tileidx, uint32_t subtileidx, int keystatus);
	uint32_t buttonbits;
	uint32_t buttonbits_old;
	uint32_t transparency;
	int select_a, select_b;
	int contrast;
};

struct _GtkXcolormapperClass
{
	GtkDrawingAreaClass parent_class;
};

GType      gtkx_colormapper_get_type (void) G_GNUC_CONST;
GtkWidget *gtkx_colormapper_new();
void       gtkx_colormapper_settileoff(GtkXcolormapper *widg, uint32_t offset);
void       gtkx_colormapper_settileblendoff(GtkXcolormapper *widg, uint32_t offset);
void       gtkx_colormapper_setdispblend(GtkXcolormapper *widg, int enabled);
void       gtkx_colormapper_setgrid(GtkXcolormapper *widg, int enabled);
void       gtkx_colormapper_setzoom(GtkXcolormapper *widg, int zoomscale);
void       gtkx_colormapper_setnegative(GtkXcolormapper *widg, int negative);
void       gtkx_colormapper_setspritemode(GtkXcolormapper *widg, int spritemode);
void       gtkx_colormapper_settransparency(GtkXcolormapper *widg, uint32_t color);
void       gtkx_colormapper_setcontrast(GtkXcolormapper *widg, int contrast);

G_END_DECLS

#endif
