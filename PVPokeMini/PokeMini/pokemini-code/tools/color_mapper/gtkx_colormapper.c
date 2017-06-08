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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "gtkx_colormapper.h"

#include "color_info.h"
#include "color_display.h"
#include "PokeMini_ColorPal.h"
#include "Video.h"

#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))

G_DEFINE_TYPE (GtkXcolormapper, gtkx_colormapper, GTK_TYPE_DRAWING_AREA)

static void gtkx_colormapper_input8x8Attr(GtkXcolormapper *widg, int xp, int yp, int pitchp)
{
	int tileidx, tiledataaddr, tileidxD;

	int status = 0;
	uint32_t press = widg->buttonbits & ~widg->buttonbits_old;
	uint32_t release = ~widg->buttonbits & widg->buttonbits_old;
	uint32_t hold = widg->buttonbits;
	widg->buttonbits_old = widg->buttonbits;

	// Calculate
	if (widg->spritemode) {
		tileidx = (yp >> 4) * (pitchp >> 4) + (xp >> 4);
		colordisplay_decodespriteidx(tileidx, xp, yp, &tileidxD, NULL);
		tiledataaddr = (((widg->tileoff & ~7) << 3) + (tileidxD << 3));
	} else {
		tileidx = (yp >> 3) * (pitchp >> 3) + (xp >> 3);
		tiledataaddr = ((widg->tileoff << 3) + (tileidx << 3));
	}

	// Motion and paint
	if (tiledataaddr < PM_ROM_FSize) {

		if ((press | release | hold) & 2) {	// Left-Button down
			if (widg->on_lbutton) {
				if (press & 2) status = 1;
				else if (release & 2) status = 2;
				if (widg->on_lbutton(GTK_WIDGET(widg), tiledataaddr >> 3, 0, status)) gtk_widget_queue_draw(GTK_WIDGET(widg));
			}
		}
		if ((press | release | hold) & 4) {	// Middle-Button down
			if (widg->on_mbutton) {
				if (press & 4) status = 1;
				else if (release & 4) status = 2;
				if (widg->on_mbutton(GTK_WIDGET(widg), tiledataaddr >> 3, 0, status)) gtk_widget_queue_draw(GTK_WIDGET(widg));
			}
		}
		if ((press | release | hold) & 8) {	// Right-Button down
			if (widg->on_rbutton) {
				if (press & 8) status = 1;
				else if (release & 8) status = 2;
				if (widg->on_rbutton(GTK_WIDGET(widg), tiledataaddr >> 3, 0, status)) gtk_widget_queue_draw(GTK_WIDGET(widg));
			}
		}

		// Inside ROM range
		if (widg->on_motion) widg->on_motion(GTK_WIDGET(widg), 1, tiledataaddr >> 3, 0);
	} else {
		// Outside ROM range
		if (widg->on_motion) widg->on_motion(GTK_WIDGET(widg), 0, tiledataaddr >> 3, 0);
	}
}

static void gtkx_colormapper_input4x4Attr(GtkXcolormapper *widg, int xp, int yp, int pitchp)
{
	int tileidx, tiledataaddr, tileidxD, subtile;

	int status = 0;
	uint32_t press = widg->buttonbits & ~widg->buttonbits_old;
	uint32_t release = ~widg->buttonbits & widg->buttonbits_old;
	uint32_t hold = widg->buttonbits;
	widg->buttonbits_old = widg->buttonbits;

	// Calculate
	if (widg->spritemode) {
		tileidx = (yp >> 4) * (pitchp >> 4) + (xp >> 4);
		colordisplay_decodespriteidx(tileidx, xp, yp, &tileidxD, NULL);
		tiledataaddr = (((widg->tileoff & ~7) << 3) + (tileidxD << 3));
	} else {
		tileidx = (yp >> 3) * (pitchp >> 3) + (xp >> 3);
		tiledataaddr = ((widg->tileoff << 3) + (tileidx << 3));
	}
	subtile = ((yp & 4) >> 1) + ((xp & 4) >> 2);

	// Motion and paint
	if (tiledataaddr < PM_ROM_FSize) {

		if ((press | release | hold) & 2) {	// Left-Button down
			if (widg->on_lbutton) {
				if (press & 2) status = 1;
				else if (release & 2) status = 2;
				if (widg->on_lbutton(GTK_WIDGET(widg), tiledataaddr >> 3, subtile, status)) gtk_widget_queue_draw(GTK_WIDGET(widg));
			}
		}
		if ((press | release | hold) & 4) {	// Middle-Button down
			if (widg->on_mbutton) {
				if (press & 4) status = 1;
				else if (release & 4) status = 2;
				if (widg->on_mbutton(GTK_WIDGET(widg), tiledataaddr >> 3, subtile, status)) gtk_widget_queue_draw(GTK_WIDGET(widg));
			}
		}
		if ((press | release | hold) & 8) {	// Right-Button down
			if (widg->on_rbutton) {
				if (press & 8) status = 1;
				else if (release & 8) status = 2;
				if (widg->on_rbutton(GTK_WIDGET(widg), tiledataaddr >> 3, subtile, status)) gtk_widget_queue_draw(GTK_WIDGET(widg));
			}
		}

		// Inside ROM range
		if (widg->on_motion) widg->on_motion(GTK_WIDGET(widg), 1, tiledataaddr >> 3, subtile);
	} else {
		// Outside ROM range
		if (widg->on_motion) widg->on_motion(GTK_WIDGET(widg), 0, tiledataaddr >> 3, subtile);
	}
}

static gboolean gtkx_colormapper_button_event(GtkWidget *widget, GdkEventButton *event)
{
	GtkXcolormapper *widg = GTKX_COLORMAPPER(widget);

	int xp = (int)(event->x) / widg->zoom;
	int yp = (int)(event->y) / widg->zoom;
	int pitchp = widg->imgcache_p / widg->zoom;

	if ((xp < 0) || (yp < 0)) return TRUE;

	if (event->type == GDK_BUTTON_PRESS) {
		widg->buttonbits |= (1 << event->button);
	} else if (event->type == GDK_BUTTON_RELEASE) {
		widg->buttonbits &= ~(1 << event->button);
	}

	if (PRCColorFormat == 1) {
		gtkx_colormapper_input4x4Attr(widg, xp, yp, pitchp);
	} else {
		gtkx_colormapper_input8x8Attr(widg, xp, yp, pitchp);
	}

	return TRUE;
}

static gboolean gtkx_colormapper_motion_notify(GtkWidget *widget, GdkEventMotion *event)
{
	GtkXcolormapper *widg = GTKX_COLORMAPPER(widget);

	int xp = (int)(event->x) / widg->zoom;
	int yp = (int)(event->y) / widg->zoom;
	int pitchp = widg->imgcache_p / widg->zoom;

	if ((xp < 0) || (yp < 0)) return TRUE;

	if (PRCColorFormat == 1) {
		gtkx_colormapper_input4x4Attr(widg, xp, yp, pitchp);
	} else {
		gtkx_colormapper_input8x8Attr(widg, xp, yp, pitchp);
	}

	return TRUE;
}

static void gtkx_colormapper_blend(GtkXcolormapper *widg, uint32_t *dst, uint32_t *src)
{
	uint32_t *srcptr, *dstptr;
	int x, y, pitch = widg->imgcache_p;

	for (y=0; y<widg->imgcache_h; y++) {
		srcptr = &src[y * pitch];
		dstptr = &dst[y * pitch];
		for (x=0; x<widg->imgcache_w; x++) {
			dstptr[x] = InterpolateRGB24(srcptr[x], dstptr[x], 128);
		}
	}
}

static gboolean gtkx_colormapper_expose(GtkWidget *widget, GdkEventExpose *event)
{
	GtkXcolormapper *widg = GTKX_COLORMAPPER(widget);

	cairo_t *cr;
	uint32_t *ptr, *blendptr;

	// Recreate image cache on resize
	if ((widget->allocation.width != widg->imgcache_w) || (widget->allocation.height != widg->imgcache_h)) {
		cairo_surface_destroy(widg->imgcache);
		cairo_surface_destroy(widg->imgblendcache);
		widg->imgcache_w = widget->allocation.width;
		widg->imgcache_h = widget->allocation.height;
		widg->imgcache_p = (widget->allocation.width + 3) & ~3;
		widg->imgcache = cairo_image_surface_create(CAIRO_FORMAT_RGB24, widg->imgcache_p, widg->imgcache_h);
		widg->imgblendcache = cairo_image_surface_create(CAIRO_FORMAT_RGB24, widg->imgcache_p, widg->imgcache_h);
	}
	ptr = (uint32_t *)cairo_image_surface_get_data(widg->imgcache);
	blendptr = (uint32_t *)cairo_image_surface_get_data(widg->imgblendcache);

	// Create cairo
	cr = gdk_cairo_create(widget->window);
	gdk_cairo_rectangle(cr, &event->area);
	cairo_clip(cr);
	cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
	cairo_set_font_size(cr, 12);

	// Render
	if (PRCColorFormat == 1) {
		if (widg->dispblend) {
			colordisplay_4x4Attr(ptr, widg->imgcache_w, widg->imgcache_h, widg->imgcache_p,
			widg->spritemode, widg->zoom, widg->tileoff, widg->select_a, widg->select_b,
			widg->negative, widg->transparency, widg->grid, 0, widg->contrast);
			colordisplay_4x4Attr(blendptr, widg->imgcache_w, widg->imgcache_h, widg->imgcache_p,
			widg->spritemode, widg->zoom, widg->tileblendoff, widg->select_a, widg->select_b,
			widg->negative, widg->transparency, widg->grid, 0, widg->contrast);
			gtkx_colormapper_blend(widg, ptr, blendptr);
		} else {
			colordisplay_4x4Attr(ptr, widg->imgcache_w, widg->imgcache_h, widg->imgcache_p,
			widg->spritemode, widg->zoom, widg->tileoff, widg->select_a, widg->select_b,
			widg->negative, widg->transparency, widg->grid, 0, widg->contrast);
		}
	} else {
		if (widg->dispblend) {
			colordisplay_8x8Attr(ptr, widg->imgcache_w, widg->imgcache_h, widg->imgcache_p,
			widg->spritemode, widg->zoom, widg->tileoff, widg->select_a, widg->select_b,
			widg->negative, widg->transparency, widg->grid, 0, widg->contrast);
			colordisplay_8x8Attr(blendptr, widg->imgcache_w, widg->imgcache_h, widg->imgcache_p,
			widg->spritemode, widg->zoom, widg->tileblendoff, widg->select_a, widg->select_b,
			widg->negative, widg->transparency, widg->grid, 0, widg->contrast);
			gtkx_colormapper_blend(widg, ptr, blendptr);
		} else {
			colordisplay_8x8Attr(ptr, widg->imgcache_w, widg->imgcache_h, widg->imgcache_p,
			widg->spritemode, widg->zoom, widg->tileoff, widg->select_a, widg->select_b,
			widg->negative, widg->transparency, widg->grid, 0, widg->contrast);
		}
	}

	// Paint result to the widget
	cairo_set_source_surface(cr, widg->imgcache, 0, 0);
	cairo_paint(cr);

	// Destroy cairo
	cairo_destroy(cr);

	return TRUE;
}

static void gtkx_colormapper_class_init(GtkXcolormapperClass *class)
{
	GtkWidgetClass *widget_class = GTK_WIDGET_CLASS(class);

	widget_class->expose_event = gtkx_colormapper_expose;
	widget_class->motion_notify_event = gtkx_colormapper_motion_notify;
	widget_class->button_press_event = gtkx_colormapper_button_event;
	widget_class->button_release_event = gtkx_colormapper_button_event;
}

static void gtkx_colormapper_init(GtkXcolormapper *widg)
{
	gtk_widget_set_double_buffered(GTK_WIDGET(widg), FALSE);
	gtk_widget_add_events(GTK_WIDGET(widg), GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK | GDK_POINTER_MOTION_MASK);
	gtk_widget_add_events(GTK_WIDGET(widg), GDK_ENTER_NOTIFY_MASK | GDK_LEAVE_NOTIFY_MASK);

	widg->imgcache = cairo_image_surface_create(CAIRO_FORMAT_RGB24, 8, 8);
	widg->imgcache_w = 8;
	widg->imgcache_h = 8;
	widg->imgcache_p = 8;
	widg->tileoff = 0;
	widg->tileblendoff = 0;
	widg->zoom = 4;
	widg->grid = 1;
	widg->negative = 0;
	widg->dispblend = 0;
	widg->spritemode = 0;
	widg->buttonbits = 0;
	widg->buttonbits_old = 0;
	widg->transparency = 0xFF00FF;
	widg->select_a = 0;
	widg->select_b = -8;
}

GtkWidget *gtkx_colormapper_new(void)
{
	return g_object_new(GTKX_TYPE_COLORMAPPER, NULL);
}

void gtkx_colormapper_settileoff(GtkXcolormapper *widg, uint32_t offset)
{
	widg->tileoff = offset;
	gtk_widget_queue_draw(GTK_WIDGET(widg));
}

void gtkx_colormapper_settileblendoff(GtkXcolormapper *widg, uint32_t offset)
{
	widg->tileblendoff = offset;
	gtk_widget_queue_draw(GTK_WIDGET(widg));
}

void gtkx_colormapper_setdispblend(GtkXcolormapper *widg, int enabled)
{
	widg->dispblend = enabled;
	gtk_widget_queue_draw(GTK_WIDGET(widg));
}

void gtkx_colormapper_setgrid(GtkXcolormapper *widg, int enabled)
{
	widg->grid = enabled;
	gtk_widget_queue_draw(GTK_WIDGET(widg));
}

void gtkx_colormapper_setzoom(GtkXcolormapper *widg, int zoomscale)
{
	if (zoomscale >= 1) {
		widg->zoom = zoomscale;
		gtk_widget_queue_draw(GTK_WIDGET(widg));
	}
}

void gtkx_colormapper_setnegative(GtkXcolormapper *widg, int negative)
{
	widg->negative = negative & 1;
	gtk_widget_queue_draw(GTK_WIDGET(widg));
}

void gtkx_colormapper_setspritemode(GtkXcolormapper *widg, int spritemode)
{
	widg->spritemode = spritemode;
	gtk_widget_queue_draw(GTK_WIDGET(widg));
}

void gtkx_colormapper_settransparency(GtkXcolormapper *widg, uint32_t color)
{
	widg->transparency = color;
	gtk_widget_queue_draw(GTK_WIDGET(widg));
}

void gtkx_colormapper_setcontrast(GtkXcolormapper *widg, int contrast)
{
	widg->contrast = contrast;
	gtk_widget_queue_draw(GTK_WIDGET(widg));
}
