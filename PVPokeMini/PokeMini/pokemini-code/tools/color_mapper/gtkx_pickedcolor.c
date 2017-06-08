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
#include "gtkx_pickedcolor.h"

#include "PokeMini_ColorPal.h"

G_DEFINE_TYPE (GtkXpickedcolor, gtkx_pickedcolor, GTK_TYPE_DRAWING_AREA)

static gboolean gtkx_pickedcolor_button_press(GtkWidget *widget, GdkEventButton *event)
{
	GtkXpickedcolor *widg = GTKX_PICKEDCOLOR(widget);
	int x = (int)(event->x);
	int y = (int)(event->y);
	int pi = x * GtkXpickedcolor_palsize / widget->allocation.width;

	if (event->type == GDK_BUTTON_PRESS) {
		if (event->button == 1) {
			if ((y >= 28) && (y < 48)) {
				widg->color_on_enabled = !widg->color_on_enabled;
			}
			if ((y >= 78) && (y < 98)) {
				widg->color_off_enabled = !widg->color_off_enabled;
			}
			if ((y >= 120) && (y < 144)) {
				widg->color_off = widg->color_off_pal[pi];
				widg->color_on = widg->color_on_pal[pi];
			}
			gtk_widget_queue_draw(widget);
		}
		if (event->button == 3) {
			if ((y >= 0) && (y < 100)) {
				widg->color_on_enabled = 1;
				widg->color_off_enabled = 1;
			}
			if ((y >= 120) && (y < 144)) {
				widg->color_off_pal[pi] = widg->color_off;
				widg->color_on_pal[pi] = widg->color_on;
			}
			gtk_widget_queue_draw(widget);
		}
	}

	return TRUE;
}

static void gtkx_pickedcolor_expose_setstroke(cairo_t *cr, int index)
{
	if ((index & 0xF0) == 0x70) cairo_set_source_rgb(cr, 0.5, 0.5, 0.5);
	else if (index & 0x80) cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
	else cairo_set_source_rgb(cr, 0.0, 0.0, 0.0);
}

static void gtkx_pickedcolor_expose_setcolorindex(cairo_t *cr, int index)
{
	double b = ((PokeMini_ColorPalBGR32[index]) & 0xFF) / 255.0;
	double g = ((PokeMini_ColorPalBGR32[index] >> 8) & 0xFF) / 255.0;
	double r = ((PokeMini_ColorPalBGR32[index] >> 16) & 0xFF) / 255.0;
	cairo_set_source_rgb(cr, r, g, b);
}

static gboolean gtkx_pickedcolor_expose(GtkWidget *widget, GdkEventExpose *event)
{
	GtkXpickedcolor *widg = GTKX_PICKEDCOLOR(widget);

	cairo_t *cr;
	char txt[256];
	int w = widget->allocation.width;
	int i, wc;

	// Create cairo
	cr = gdk_cairo_create(widget->window);
	gdk_cairo_rectangle(cr, &event->area);
	cairo_clip(cr);
	cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
	cairo_set_font_size(cr, 10.0);
	cairo_set_line_width(cr, 3.0);

	// Display on color
	cairo_rectangle(cr, 2.0, 30.0, w - 4.0, 16.0);
	gtkx_pickedcolor_expose_setstroke(cr, widg->color_on);
	cairo_stroke_preserve(cr);
	gtkx_pickedcolor_expose_setcolorindex(cr, widg->color_on);
	cairo_fill(cr);

	// Display disabled if it is...
	if (!widg->color_on_enabled) {
		cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
		cairo_set_font_size(cr, 10.0);
		cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
		cairo_move_to(cr, 4.0, 41.0);
		cairo_show_text(cr, "Paint Disabled");
		cairo_set_source_rgb(cr, 0.0, 0.0, 0.0);
		cairo_move_to(cr, 5.0, 42.0);
		cairo_show_text(cr, "Paint Disabled");
	}

	// Display on text
	cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
	cairo_move_to(cr, 4.0, 13.0);
	cairo_show_text(cr, "Dark Pixel");
	if (widg->color_on_enabled) cairo_set_source_rgb(cr, 0.0, 0.0, 0.0); else cairo_set_source_rgb(cr, 1.0, 0.0, 0.0);
	cairo_move_to(cr, 5.0, 14.0);
	cairo_show_text(cr, "Dark Pixel");
	sprintf(txt, "($%02X, %i)", widg->color_on, widg->color_on);
	cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
	cairo_move_to(cr, 4.0, 23.0);
	cairo_show_text(cr, txt);
	if (widg->color_on_enabled) cairo_set_source_rgb(cr, 0.0, 0.0, 0.0); else cairo_set_source_rgb(cr, 1.0, 0.0, 0.0);
	cairo_move_to(cr, 5.0, 24.0);
	cairo_show_text(cr, txt);

	// Display off color
	cairo_rectangle(cr, 2.0, 80.0, w - 4.0, 16.0);
	gtkx_pickedcolor_expose_setstroke(cr, widg->color_off);
	cairo_stroke_preserve(cr);
	gtkx_pickedcolor_expose_setcolorindex(cr, widg->color_off);
	cairo_fill(cr);

	// Display disabled if it is...
	if (!widg->color_off_enabled) {
		cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
		cairo_move_to(cr, 4.0, 91.0);
		cairo_show_text(cr, "Paint Disabled");
		cairo_set_source_rgb(cr, 0.0, 0.0, 0.0);
		cairo_move_to(cr, 5.0, 92.0);
		cairo_show_text(cr, "Paint Disabled");
	}

	// Display off text
	cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
	cairo_move_to(cr, 4.0, 63.0);
	cairo_show_text(cr, "Light Pixel");
	if (widg->color_off_enabled) cairo_set_source_rgb(cr, 0.0, 0.0, 0.0); else cairo_set_source_rgb(cr, 1.0, 0.0, 0.0);
	cairo_move_to(cr, 5.0, 64.0);
	cairo_show_text(cr, "Light Pixel");
	sprintf(txt, "($%02X, %i)", widg->color_off, widg->color_off);
	cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
	cairo_move_to(cr, 4.0, 73.0);
	cairo_show_text(cr, txt);
	if (widg->color_off_enabled) cairo_set_source_rgb(cr, 0.0, 0.0, 0.0); else cairo_set_source_rgb(cr, 1.0, 0.0, 0.0);
	cairo_move_to(cr, 5.0, 74.0);
	cairo_show_text(cr, txt);

	// Display mini palette
	cairo_set_line_width(cr, 1.0);
	cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
	cairo_move_to(cr, 4.0, 113.0);
	cairo_show_text(cr, "Mini palette");
	cairo_set_source_rgb(cr, 0.0, 0.0, 0.0);
	cairo_move_to(cr, 5.0, 114.0);
	cairo_show_text(cr, "Mini palette");
	wc = w / GtkXpickedcolor_palsize;
	for (i=0; i<GtkXpickedcolor_palsize; i++) {
		cairo_rectangle(cr, 2.0 + (i*wc), 120.0, wc - 4.0, 10.0);
		gtkx_pickedcolor_expose_setstroke(cr, widg->color_off_pal[i]);
		cairo_stroke_preserve(cr);
		gtkx_pickedcolor_expose_setcolorindex(cr, widg->color_off_pal[i]);
		cairo_fill(cr);
		cairo_rectangle(cr, 2.0 + (i*wc), 132.0, wc - 4.0, 10.0);
		gtkx_pickedcolor_expose_setstroke(cr, widg->color_on_pal[i]);
		cairo_stroke_preserve(cr);
		gtkx_pickedcolor_expose_setcolorindex(cr, widg->color_on_pal[i]);
		cairo_fill(cr);
	}

	// Destroy cairo
	cairo_destroy(cr);

	return TRUE;
}

static void gtkx_pickedcolor_class_init(GtkXpickedcolorClass *class)
{
	GtkWidgetClass *widget_class = GTK_WIDGET_CLASS(class);

	widget_class->expose_event = gtkx_pickedcolor_expose;
	widget_class->button_press_event = gtkx_pickedcolor_button_press;
}

static void gtkx_pickedcolor_init(GtkXpickedcolor *widg)
{
	int i;

	gtk_widget_add_events(GTK_WIDGET(widg), GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK | GDK_POINTER_MOTION_MASK);
	gtk_widget_add_events(GTK_WIDGET(widg), GDK_ENTER_NOTIFY_MASK | GDK_LEAVE_NOTIFY_MASK);
	gtk_widget_set_size_request(GTK_WIDGET(widg), 80, 144);

	widg->color_off = 0x00;
	widg->color_on = 0xF0;
	widg->color_off_enabled = 1;
	widg->color_on_enabled = 1;

	for (i=0; i<GtkXpickedcolor_palsize; i++) {
		widg->color_off_pal[i] = 0x00;
		widg->color_on_pal[i] = 0xF0;
	}
}

GtkWidget *gtkx_pickedcolor_new(void)
{
	return g_object_new(GTKX_TYPE_PICKEDCOLOR, NULL);
}

void gtkx_pickedcolor_setcolorindex(GtkXpickedcolor *widg, int type, int index)
{
	if (type) {
		if (widg->color_on != index) {
			widg->color_on = index;
			gtk_widget_queue_draw(GTK_WIDGET(widg));
		}
	} else {
		if (widg->color_off != index) {
			widg->color_off = index;
			gtk_widget_queue_draw(GTK_WIDGET(widg));
		}
	}
}
