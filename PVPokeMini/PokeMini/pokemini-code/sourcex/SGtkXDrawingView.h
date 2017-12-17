/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

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

#ifndef SGTKXDRAWINGVIEW_H
#define SGTKXDRAWINGVIEW_H

#include <stdint.h>
#include <gtk/gtk.h>

typedef int (*TSGtkXDVCB)(void *obj, int a, int b, int c);

#define SGtkXDVCB(a)	((TSGtkXDVCB)(a))

enum {
	SGTKXDV_BLEFT = 1,
	SGTKXDV_BMIDDLE = 2,
	SGTKXDV_BRIGHT = 3
};

typedef struct {
	GtkBox *box;			// Box widget
	GtkAdjustment *sba;		// Scrollbar's adjusment
	GtkScrollbar *sb;		// Scrollbar widget
	GtkDrawingArea *da;		// Drawing area widget
	cairo_surface_t *surface;	// Surface
	uint32_t *imgptr;		// Image buffer
	int width;			// Image width
	int height;			// Image height
	int pitch;			// Image pitch in pixels
	TSGtkXDVCB on_scroll;		// Callback: Scrollbar moved		ret = refresh	a = value
	TSGtkXDVCB on_resize;		// Callback: Window resized				a = width	b = height
	TSGtkXDVCB on_imgresize;	// Callback: Image resize				a = width	b = height	c = pitch
	TSGtkXDVCB on_exposure;		// Callback: Drawing area repaint			a = width	b = height	c = pitch
	TSGtkXDVCB on_motion;		// Callback: Mouse moving		ret = refresh	a = x		b = y
	TSGtkXDVCB on_buttonpress;	// Callback: Mouse button pressing	ret = refresh	a = button	b = press
	TSGtkXDVCB on_buttonrelease;	// Callback: Mouse button release	ret = refresh	a = button	b = press
	TSGtkXDVCB on_enterleave;	// Callback: Enter / Leave widget	ret = refresh	a = inside
	int buttons;			// Mouse buttons down (bitmask)
	int mousex;			// Mouse x position
	int mousey;			// Mouse y position
	int mouseinside;		// Mouse inside widget
	int sboffset;			// Scrollbar offset
	// User extra
	int total_lines;		// Total lines
	int first_addr;			// First address
	int last_addr;			// Last address
	int highlight_addr;		// Highlight address
	int highlight_rem;		// Highlight remaining timer
} SGtkXDrawingView;

void sgtkx_drawing_view_setfont(uint8_t *font);

void sgtkx_drawing_view_drawhline(SGtkXDrawingView *widg, int y, int start, int end, uint32_t color);

void sgtkx_drawing_view_drawvline(SGtkXDrawingView *widg, int x, int start, int end, uint32_t color);

void sgtkx_drawing_view_drawsrect(SGtkXDrawingView *widg, int x, int y, int width, int height, uint32_t color);

void sgtkx_drawing_view_drawfrect(SGtkXDrawingView *widg, int x, int y, int width, int height, uint32_t color);

void sgtkx_drawing_view_drawtext(SGtkXDrawingView *widg, int x, int y, uint32_t color, char *format, ...);

void sgtkx_drawing_view_drawchar(SGtkXDrawingView *widg, int x, int y, uint32_t color, unsigned char ch);

void sgtkx_drawing_view_refresh(SGtkXDrawingView *widg);

int sgtkx_drawing_view_new(SGtkXDrawingView *widg, int scrollbar);

void sgtkx_drawing_view_sbvalue(SGtkXDrawingView *widg, int value);

void sgtkx_drawing_view_sbminmax(SGtkXDrawingView *widg, int min, int max);

void sgtkx_drawing_view_sbpage(SGtkXDrawingView *widg, int page_inc, int page_size);

void sgtkx_drawing_view_repaint_after(SGtkXDrawingView *widg, int milisec);

#endif
