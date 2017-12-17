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
#include "gtkx_palettepicker.h"

#include "PokeMini_ColorPal.h"

G_DEFINE_TYPE (GtkXpalettepicker, gtkx_palettepicker, GTK_TYPE_DRAWING_AREA)

static gboolean gtkx_palettepicker_button_press(GtkWidget *widget, GdkEventButton *event)
{
	GtkXpalettepicker *widg = GTKX_PALETTEPICKER(widget);
	int x = (int)(event->x);
	int y = (int)(event->y);
	int cx = x, cy = y - 16;

	if ((cx < 0) || (cx >= 128) || (cy < 0) || (cy >= 128)) return TRUE;

	if (event->type == GDK_BUTTON_PRESS) {
		if (event->button == 1) {
			widg->color_on = (cy >> 3) * 16 + (cx >> 3);
			if (widg->on_color) widg->on_color(widget, 1, widg->color_on);
			gtk_widget_queue_draw(widget);
		}
		if (event->button == 3) {
			widg->color_off = (cy >> 3) * 16 + (cx >> 3);
			if (widg->on_color) widg->on_color(widget, 0, widg->color_off);
			gtk_widget_queue_draw(widget);
		}
	}

	return TRUE;
}

static gboolean gtkx_palettepicker_button_release(GtkWidget *widget, GdkEventButton *event)
{
	return TRUE;
}

static gboolean gtkx_palettepicker_motion_notify(GtkWidget *widget, GdkEventMotion *event)
{
	GtkXpalettepicker *widg = GTKX_PALETTEPICKER(widget);
	int x = (int)(event->x);
	int y = (int)(event->y);
	int cx = x, cy = y - 16;

	if ((cx < 0) || (cx >= 128) || (cy < 0) || (cy >= 128)) return TRUE;

	widg->inside = 1;
	widg->color_under = (cy >> 3) * 16 + (cx >> 3);
	gtk_widget_queue_draw(widget);

	return TRUE;
}

static void gtkx_palettepicker_expose_setstroke(cairo_t *cr, int index)
{
	if ((index & 0xF0) == 0x70) cairo_set_source_rgb(cr, 0.5, 0.5, 0.5);
	else if (index & 0x80) cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
	else cairo_set_source_rgb(cr, 0.0, 0.0, 0.0);
}

static void gtkx_palettepicker_expose_setcolorindex(cairo_t *cr, int index)
{
	double b = ((PokeMini_ColorPalBGR32[index]) & 0xFF) / 255.0;
	double g = ((PokeMini_ColorPalBGR32[index] >> 8) & 0xFF) / 255.0;
	double r = ((PokeMini_ColorPalBGR32[index] >> 16) & 0xFF) / 255.0;
	cairo_set_source_rgb(cr, r, g, b);
}

static gboolean gtkx_palettepicker_expose(GtkWidget *widget, GdkEventExpose *event)
{
	GtkXpalettepicker *widg = GTKX_PALETTEPICKER(widget);

	cairo_t *cr;
	int x, y;
	char txt[256];

	// Create cairo
	cr = gdk_cairo_create(widget->window);
	gdk_cairo_rectangle(cr, &event->area);
	cairo_clip(cr);
	cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
	cairo_set_font_size(cr, 12.0);
	cairo_set_line_width(cr, 2.0);

	// Paint palette image
	cairo_set_source_surface(cr, widg->paletteimg, 0, 16);
	cairo_paint(cr);

	// Highlight off color
	x = (widg->color_off & 15) << 3;
	y = ((widg->color_off >> 4) << 3) + 16;
	cairo_rectangle(cr, x, y, 8.0, 8.0);
	cairo_set_source_rgb(cr, 1.0, 0.0, 0.0);
	cairo_stroke_preserve(cr);
	gtkx_palettepicker_expose_setcolorindex(cr, widg->color_off);
	cairo_fill(cr);

	// Highlight on color
	x = (widg->color_on & 15) << 3;
	y = ((widg->color_on >> 4) << 3) + 16;
	cairo_rectangle(cr, x, y, 8.0, 8.0);
	cairo_set_source_rgb(cr, 0.0, 1.0, 0.0);
	cairo_stroke_preserve(cr);
	gtkx_palettepicker_expose_setcolorindex(cr, widg->color_on);
	cairo_fill(cr);

	if (widg->inside) {
		// Display text
		sprintf(txt, "Pal. ($%02X, %i)", widg->color_under, widg->color_under);
		cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
		cairo_move_to(cr, 19.0, 13.0);
		cairo_show_text(cr, txt);
		cairo_set_source_rgb(cr, 0.0, 0.0, 0.0);
		cairo_move_to(cr, 20.0, 14.0);
		cairo_show_text(cr, txt);

		// Display under color
		cairo_rectangle(cr, 1.0, 1.0, 12.0, 12.0);
		gtkx_palettepicker_expose_setstroke(cr, widg->color_under);
		cairo_stroke_preserve(cr);
		gtkx_palettepicker_expose_setcolorindex(cr, widg->color_under);
		cairo_fill(cr);

		// Highlight under color
		x = (widg->color_under & 15) << 3;
		y = ((widg->color_under >> 4) << 3) + 16;
		cairo_rectangle(cr, x, y, 8.0, 8.0);
		gtkx_palettepicker_expose_setstroke(cr, widg->color_under);
		cairo_stroke_preserve(cr);
		gtkx_palettepicker_expose_setcolorindex(cr, widg->color_under);
		cairo_fill(cr);
	}

	// Destroy cairo
	cairo_destroy(cr);

	return TRUE;
}

static gboolean gtk_palettepicker_enter_notify(GtkWidget *widget, GdkEventCrossing *event)
{
	GtkXpalettepicker *widg = GTKX_PALETTEPICKER(widget);
	widg->inside = 1;
	gtk_widget_queue_draw(widget);
	return TRUE;
}

static gboolean gtk_palettepicker_leave_notify(GtkWidget *widget, GdkEventCrossing *event)
{
	GtkXpalettepicker *widg = GTKX_PALETTEPICKER(widget);
	widg->inside = 0;
	gtk_widget_queue_draw(widget);	
	return TRUE;
}

static void gtkx_palettepicker_init(GtkXpalettepicker *widg)
{
	int *ptr, x, y;

	gtk_widget_add_events(GTK_WIDGET(widg), GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK | GDK_POINTER_MOTION_MASK);
	gtk_widget_add_events(GTK_WIDGET(widg), GDK_ENTER_NOTIFY_MASK | GDK_LEAVE_NOTIFY_MASK);
	gtk_widget_set_size_request(GTK_WIDGET(widg), 128, 144);

	widg->paletteimg = cairo_image_surface_create(CAIRO_FORMAT_RGB24, 128, 128);
	ptr = (int *)cairo_image_surface_get_data(widg->paletteimg);
	for (y=0; y<128; y++) {
		for (x=0; x<128; x++) {
			ptr[y * 128 + x] = PokeMini_ColorPalBGR32[(y >> 3) * 16 + (x >> 3)];
		}
	}

	widg->inside = 0;
	widg->color_off = 0x00;
	widg->color_on = 0xF0;
	widg->on_color = NULL;
}

static void gtkx_palettepicker_class_init(GtkXpalettepickerClass *class)
{
	GtkWidgetClass *widget_class = GTK_WIDGET_CLASS(class);

	widget_class->expose_event = gtkx_palettepicker_expose;
	widget_class->button_press_event = gtkx_palettepicker_button_press;
	widget_class->button_release_event = gtkx_palettepicker_button_release;
	widget_class->motion_notify_event = gtkx_palettepicker_motion_notify;
	widget_class->enter_notify_event = gtk_palettepicker_enter_notify;
	widget_class->leave_notify_event = gtk_palettepicker_leave_notify;
}

GtkWidget *gtkx_palettepicker_new(void)
{
	return g_object_new(GTKX_TYPE_PALETTEPICKER, NULL);
}

void gtkx_palettepicker_swapcolors(GtkXpalettepicker *widg)
{
	int tmp;
	tmp = widg->color_off;
	widg->color_off = widg->color_on;
	widg->color_on = tmp;
	if (widg->on_color) {
		widg->on_color(GTK_WIDGET(widg), 0, widg->color_off);
		widg->on_color(GTK_WIDGET(widg), 1, widg->color_on);
	}
	gtk_widget_queue_draw(GTK_WIDGET(widg));
}

void gtkx_palettepicker_setcolorindex(GtkXpalettepicker *widg, int type, int index)
{
	if (type) {
		widg->color_on = index;
	} else {
		widg->color_off = index;
	}
	widg->on_color(GTK_WIDGET(widg), type, index);
	gtk_widget_queue_draw(GTK_WIDGET(widg));
}
