/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

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
#include <stdarg.h>
#include <math.h>
#include "SGtkXDrawingView.h"

#include "Font8x12.h"

uint8_t *sgtkx_drawing_view_font = (uint8_t *)Font8x12;

void sgtkx_drawing_view_setfont(uint8_t *font)
{
	if (font) sgtkx_drawing_view_font = font;
	else sgtkx_drawing_view_font = (uint8_t *)Font8x12;
}

void sgtkx_drawing_view_drawhline(SGtkXDrawingView *widg, int y, int start, int end, uint32_t color)
{
	if ((y < 0) || (y >= widg->height)) return;
	if (start < 0) start = 0;
	else if (start >= widg->width) return;
	if (end < 0) return;
	else if (end > widg->width) end = widg->width;
	uint32_t *imgptr = (uint32_t *)widg->imgptr + y * widg->pitch + start;
	while (start != end) {
		*imgptr = color;
		imgptr++;
		start++;
	}
}

void sgtkx_drawing_view_drawvline(SGtkXDrawingView *widg, int x, int start, int end, uint32_t color)
{
	if ((x < 0) || (x >= widg->width)) return;
	if (start < 0) start = 0;
	else if (start >= widg->height) return;
	if (end < 0) return;
	else if (end > widg->height) end = widg->height;
	uint32_t *imgptr = (uint32_t *)widg->imgptr + start * widg->pitch + x;
	while (start != end) {
		*imgptr = color;
		imgptr += widg->pitch;
		start++;
	}
}

void sgtkx_drawing_view_drawsrect(SGtkXDrawingView *widg, int x, int y, int width, int height, uint32_t color)
{
	sgtkx_drawing_view_drawhline(widg, y, x, x + width, color);
	sgtkx_drawing_view_drawhline(widg, y + height - 1, x, x + width, color);
	sgtkx_drawing_view_drawvline(widg, x, y, y + height, color);
	sgtkx_drawing_view_drawvline(widg, x + width - 1, y, y + height, color);
}

void sgtkx_drawing_view_drawfrect(SGtkXDrawingView *widg, int x, int y, int width, int height, uint32_t color)
{
	int z;
	if ((x > widg->width) || (y > widg->height)) return;
	if (x < 0) { width += x; x = 0; }
	if (y < 0) { height += y; y = 0; }
	if ((x + width) > widg->width) width = widg->width - x;
	if ((y + height) > widg->height) height = widg->height - y;
	if ((width <= 0) || (height <= 0)) return;
	uint32_t *imgptr = (uint32_t *)widg->imgptr + y * widg->pitch + x;
	while (height--) {
		for (z=0; z<width; z++) imgptr[z] = color;
		imgptr += widg->pitch;
	}
}

void sgtkx_drawing_view_drawchar(SGtkXDrawingView *widg, int x, int y, uint32_t color, unsigned char ch)
{
	unsigned char *chptr = (unsigned char *)sgtkx_drawing_view_font + (ch >> 4) * 1536 + (ch & 15) * 8;
	int z, width = 8, height = 12;
	if ((x > widg->width) || (y > widg->height)) return;
	if (x < 0) { width += x; chptr += x; x = 0; }
	if (y < 0) { height += y; chptr += y * 128; y = 0; }
	if ((x + width) > widg->width) width = widg->width - x;
	if ((y + height) > widg->height) height = widg->height - y;
	if ((width <= 0) || (height <= 0)) return;
	uint32_t *imgptr = (uint32_t *)widg->imgptr + y * widg->pitch + x;
	while (height--) {
		for (z=0; z<width; z++) if (chptr[z]) imgptr[z] = color;
		imgptr += widg->pitch;
		chptr += 128;
	}	
}

void sgtkx_drawing_view_drawtext(SGtkXDrawingView *widg, int x, int y, uint32_t color, char *format, ...)
{
	char buffer[2048], ch;
	int r, g, b;
	char *sbuf;

	va_list args;
	va_start(args, format);
	vsprintf(buffer, format, args);
	sbuf = buffer;
	while ((ch = *sbuf++) != 0) {
		if (ch == '\e') {
			r = ((*sbuf++ - '0') * 28) & 255;
			g = ((*sbuf++ - '0') * 28) & 255;
			b = ((*sbuf++ - '0') * 28) & 255;
			color = (r << 16) | (g << 8) | b;
			continue;
		}
		sgtkx_drawing_view_drawchar(widg, x, y, color, ch);
		x += 8.0;
	}
	va_end(args);
}

void sgtkx_drawing_view_refresh(SGtkXDrawingView *widg)
{
	gtk_widget_queue_draw(GTK_WIDGET(widg->da));
}

static void sgtkx_drawing_view_sbachanged(GtkAdjustment *adj, SGtkXDrawingView *widg)
{
	int refresh = 1;
	widg->sboffset = (int)adj->value;
	if (widg->on_scroll) refresh = widg->on_scroll((void *)widg, (int)adj->value, (int)adj->lower, (int)adj->upper);
	if (refresh) sgtkx_drawing_view_refresh(widg);
}

static void sgtkx_drawing_view_size_request(GtkWidget *widget, GdkRectangle *allocation, SGtkXDrawingView *widg)
{
	if (widg->on_resize) widg->on_resize((void *)widg, (int)allocation->width, (int)allocation->height, 0);
}

static gboolean sgtkx_drawing_view_exposure(GtkWidget *widget, GdkEventExpose *event, SGtkXDrawingView *widg)
{
	cairo_t *cr;

	// Initialize cairo
	cr = gdk_cairo_create(widget->window);
	gdk_cairo_rectangle(cr, &event->area);
	cairo_clip(cr);

	// Recreate image cache on resize
	if ((widget->allocation.width != widg->width) || (widget->allocation.height != widg->height)) {
		cairo_surface_destroy(widg->surface);
		widg->width = widget->allocation.width;
		widg->height = widget->allocation.height;
		if (widg->width < 0) widg->width = 8;
		if (widg->height < 0) widg->height = 8;
		widg->pitch = (widget->allocation.width + 7) & ~7;
		widg->surface = cairo_image_surface_create(CAIRO_FORMAT_RGB24, widg->pitch, widg->height);
		widg->imgptr = (uint32_t *)cairo_image_surface_get_data(widg->surface);
		if (widg->on_imgresize) widg->on_imgresize((void *)widg, widg->width, widg->height, widg->pitch);
	}

	// Callback exposure
	if (widg->on_exposure) widg->on_exposure((void *)widg, widg->width, widg->height, widg->pitch);

	// Paint image
	cairo_set_source_surface(cr, widg->surface, 0, 0);
	cairo_paint(cr);

	// Destroy cairo
	cairo_destroy (cr);

	return TRUE;
}

static gboolean sgtkx_drawing_view_scroll_event(GtkWidget *widget, GdkEventScroll *event, SGtkXDrawingView *widg)
{
	if (event->direction == GDK_SCROLL_UP) {
		sgtkx_drawing_view_sbvalue(widg, (int)widg->sba->value - (int)widg->sba->page_size);
	} else if (event->direction == GDK_SCROLL_DOWN) {
		sgtkx_drawing_view_sbvalue(widg, (int)widg->sba->value + (int)widg->sba->page_size);
	}

	return TRUE;
}

static gboolean sgtkx_drawing_view_button_event(GtkWidget *widget, GdkEventButton *event, SGtkXDrawingView *widg)
{
	int refresh = 0;
	if (event->type == GDK_BUTTON_PRESS) {
		widg->buttons |= (1 << event->button);
		if (widg->on_buttonpress) refresh = widg->on_buttonpress((void *)widg, event->button, 1, 0);
	} else if (event->type == GDK_BUTTON_RELEASE) {
		widg->buttons &= ~(1 << event->button);
		if (widg->on_buttonrelease) refresh = widg->on_buttonrelease((void *)widg, event->button, 0, 0);
	}
	if (refresh) sgtkx_drawing_view_refresh(widg);

	return TRUE;
}

static gboolean sgtkx_drawing_view_motion_notify(GtkWidget *widget, GdkEventMotion *event, SGtkXDrawingView *widg)
{
	int refresh = 0;
	widg->mousex = (int)event->x;
	widg->mousey = (int)event->y;
	if (widg->on_motion) refresh = widg->on_motion((void *)widg, widg->mousex, widg->mousey, 0);
	if (refresh) sgtkx_drawing_view_refresh(widg);

	return TRUE;
}

static gboolean sgtkx_drawing_view_enterleave_notify(GtkWidget *widget, GdkEvent *event, SGtkXDrawingView *widg)
{
	int refresh = 0;
	if (event->type == GDK_ENTER_NOTIFY) {
		widg->mouseinside = 1;
		if (widg->on_enterleave) refresh = widg->on_enterleave((void *)widg, 1, 0, 0);
	} else if (event->type == GDK_LEAVE_NOTIFY) {
		widg->mouseinside = 0;
		if (widg->on_enterleave) refresh = widg->on_enterleave((void *)widg, 0, 0, 0);
	}
	if (refresh) sgtkx_drawing_view_refresh(widg);

	return TRUE;
}

int sgtkx_drawing_view_new(SGtkXDrawingView *widg, int scrollbar)
{
	// Horizontal Box
	widg->box = GTK_BOX(gtk_hbox_new(FALSE, 0));
	if (!widg->box) return 0;

	// Drawing area
	widg->da = GTK_DRAWING_AREA(gtk_drawing_area_new());
	if (!widg->da) return 0;
	gtk_widget_set_double_buffered(GTK_WIDGET(widg->da), FALSE);
	gtk_widget_add_events(GTK_WIDGET(widg->da), GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK | GDK_POINTER_MOTION_MASK);
	gtk_widget_add_events(GTK_WIDGET(widg->da), GDK_ENTER_NOTIFY_MASK | GDK_LEAVE_NOTIFY_MASK);
	g_signal_connect(GTK_WIDGET(widg->da), "size-allocate", G_CALLBACK(sgtkx_drawing_view_size_request), widg);
	g_signal_connect(GTK_WIDGET(widg->da), "expose_event", G_CALLBACK(sgtkx_drawing_view_exposure), widg);
	g_signal_connect(GTK_WIDGET(widg->da), "motion_notify_event", G_CALLBACK(sgtkx_drawing_view_motion_notify), widg);
	g_signal_connect(GTK_WIDGET(widg->da), "button_press_event", G_CALLBACK(sgtkx_drawing_view_button_event), widg);
	g_signal_connect(GTK_WIDGET(widg->da), "button_release_event", G_CALLBACK(sgtkx_drawing_view_button_event), widg);
	g_signal_connect(GTK_WIDGET(widg->da), "scroll_event", G_CALLBACK(sgtkx_drawing_view_scroll_event), widg);
	g_signal_connect(GTK_WIDGET(widg->da), "enter_notify_event", G_CALLBACK(sgtkx_drawing_view_enterleave_notify), widg);
	g_signal_connect(GTK_WIDGET(widg->da), "leave_notify_event", G_CALLBACK(sgtkx_drawing_view_enterleave_notify), widg);
	gtk_box_pack_start(widg->box, GTK_WIDGET(widg->da), TRUE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(widg->da));

	// Scroll bar adjustment
	widg->sba = GTK_ADJUSTMENT(gtk_adjustment_new(0.0, 0.0, 0.0, 1.0, 16.0, 0.0));
	g_signal_connect(widg->sba, "value_changed", G_CALLBACK(sgtkx_drawing_view_sbachanged), (gpointer)widg);
	if (!widg->sba) return 0;
	widg->sboffset = 0;

	// Scroll bar
	widg->sb = GTK_SCROLLBAR(gtk_vscrollbar_new(widg->sba));
	if (!widg->sb) return 0;
	gtk_box_pack_start(widg->box, GTK_WIDGET(widg->sb), FALSE, TRUE, 0);
	if (scrollbar) gtk_widget_show(GTK_WIDGET(widg->sb));

	// Surface
	widg->surface = cairo_image_surface_create(CAIRO_FORMAT_RGB24, 8, 8);
	widg->width = 8;
	widg->height = 8;
	widg->pitch = 8;
	widg->imgptr = (uint32_t *)cairo_image_surface_get_data(widg->surface);

	return 1;
}


void sgtkx_drawing_view_sbvalue(SGtkXDrawingView *widg, int value)
{
	double fullmax, fvalue;
	fvalue = (double)value;
	fullmax = widg->sba->upper - widg->sba->page_size;
	if (fvalue < widg->sba->lower) {
		widg->sboffset = widg->sba->lower;
		gtk_adjustment_set_value(widg->sba, widg->sboffset);
	} else if (fvalue > fullmax) {
		widg->sboffset = fullmax;
		gtk_adjustment_set_value(widg->sba, widg->sboffset);
	} else {
		widg->sboffset = fvalue;
		gtk_adjustment_set_value(widg->sba, widg->sboffset);
	}
}

void sgtkx_drawing_view_sbminmax(SGtkXDrawingView *widg, int min, int max)
{
	double fullmax, fvalue;
	gtk_adjustment_set_lower(widg->sba, (double)min);
	gtk_adjustment_set_upper(widg->sba, (double)max);
	fvalue = floor(widg->sba->value);
	fullmax = widg->sba->upper - widg->sba->page_size;
	if (fvalue < widg->sba->lower) {
		gtk_adjustment_set_value(widg->sba, widg->sba->lower);
	} else if (fvalue > fullmax) {
		gtk_adjustment_set_value(widg->sba, fullmax);
	}
}

void sgtkx_drawing_view_sbpage(SGtkXDrawingView *widg, int page_inc, int page_size)
{
	double fullmax, fvalue;
	gtk_adjustment_set_page_increment(widg->sba, (double)page_inc);
	gtk_adjustment_set_page_size(widg->sba, (double)page_size);
	fvalue = floor(widg->sba->value);
	fullmax = widg->sba->upper - widg->sba->page_size;
	if (fvalue < widg->sba->lower) {
		gtk_adjustment_set_value(widg->sba, widg->sba->lower);
	} else if (fvalue > fullmax) {
		gtk_adjustment_set_value(widg->sba, fullmax);
	}
}

static gboolean sgtkx_drawing_view_repaint_NOW(gpointer user_data)
{
	sgtkx_drawing_view_refresh((SGtkXDrawingView *)user_data);
	return FALSE;
}

void sgtkx_drawing_view_repaint_after(SGtkXDrawingView *widg, int milisec)
{
	g_timeout_add(milisec, sgtkx_drawing_view_repaint_NOW, (gpointer)widg);
}
