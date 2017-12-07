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
#include <unistd.h>

#include "SDL.h"
#include "PokeMini.h"
#include "PokeMini_Debug.h"
#include "Hardware_Debug.h"

#include "PalEditWindow.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

static int PalEditWindow_InConfigs = 0;

GtkWindow *PalEditWindow;
static GtkScrolledWindow *PalEditSW;
static GtkBox *VBox1;
static GtkTable *CTable;
static GtkLabel *ColorLabel[4];
static GtkDrawingArea *ColorPrev[4];
static GtkAdjustment *ColorComp_Adj[4][3];
static GtkScale *ColorComp[4][3];
static GtkButtonBox *HButtonBox;
static GtkButton *ButtonClose;

// -----------------
// Widgets callbacks
// -----------------

static gint PalEditWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(PalEditWindow));
	return TRUE;
}

static gboolean ColorPrev_exposure(GtkWidget *widget, GdkEventExpose *event, gpointer data)
{
	int index = (int)data;
	uint32_t color;
	cairo_t *cr;

	// Initialize cairo
	cr = gdk_cairo_create(widget->window);
	gdk_cairo_rectangle(cr, &event->area);
	cairo_clip(cr);

	// Get color
	color = CommandLine.custompal[index];
	cairo_set_source_rgb(cr, GetValH24(color) / 255.0, GetValM24(color) / 255.0, GetValL24(color) / 255.0);
	cairo_set_line_width(cr, 1);

	// Draw preview color
	cairo_rectangle(cr, 0, 0, widget->allocation.width, widget->allocation.height);
	cairo_fill(cr);

	// Draw border
	cairo_set_source_rgb(cr, 0.0, 0.0, 0.0);
	cairo_rectangle(cr, 0, 0, widget->allocation.width, widget->allocation.height);
	cairo_stroke(cr);

	// Destroy cairo
	cairo_destroy (cr);

	return TRUE;
}


static void ColorComp_Adj_changed(GtkAdjustment *adj, gpointer data)
{
	int index = (int)data;
	int r, g, b, ix, ic;

	if (PalEditWindow_InConfigs) return;

	ix = index >> 2;
	ic = index & 3;
	r = GetValH24(CommandLine.custompal[ix]);
	g = GetValM24(CommandLine.custompal[ix]);
	b = GetValL24(CommandLine.custompal[ix]);
	if (ic == 0) r = (int)(adj->value);
	if (ic == 1) g = (int)(adj->value);
	if (ic == 2) b = (int)(adj->value);
	CommandLine.custompal[ix] = RGB24(b, g, r);
	PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
	gtk_widget_queue_draw(GTK_WIDGET(ColorPrev[ix]));
}

static gchar *ColorComp_formatvalue(GtkScale *scale, gdouble value, gpointer data)
{
	int index = (int)data;
	switch (index) {
		case  0: return g_strdup_printf("Red: %i", (int)value);
		case  1: return g_strdup_printf("Green: %i", (int)value);
		case  2: return g_strdup_printf("Blue: %i", (int)value);
		case  4: return g_strdup_printf("Red: %i", (int)value);
		case  5: return g_strdup_printf("Green: %i", (int)value);
		case  6: return g_strdup_printf("Blue: %i", (int)value);
		case  8: return g_strdup_printf("Red: %i", (int)value);
		case  9: return g_strdup_printf("Green: %i", (int)value);
		case 10: return g_strdup_printf("Blue: %i", (int)value);
		case 12: return g_strdup_printf("Red: %i", (int)value);
		case 13: return g_strdup_printf("Green: %i", (int)value);
		case 14: return g_strdup_printf("Blue: %i", (int)value);
	}
	return NULL;
}

static void PalEditWindow_ButtonClose_clicked(GtkWidget *widget, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(PalEditWindow));
}

// --------------
// PalEdit Window
// --------------

static const char *PalEditLab[4] = {
	"Custom 1 (Light Pixel):",
	"Custom 1 (Dark Pixel):",
	"Custom 2 (Light Pixel):",
	"Custom 2 (Dark Pixel):"
};

int PalEditWindow_Create(void)
{
	int x, y;

	// Window
	PalEditWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(PalEditWindow), "Custom palette edit");
	gtk_widget_set_size_request(GTK_WIDGET(PalEditWindow), 350, 450);
	gtk_window_set_default_size(PalEditWindow, 350, 450);
	g_signal_connect(PalEditWindow, "delete_event", G_CALLBACK(PalEditWindow_delete_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(PalEditWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Table
	CTable = GTK_TABLE(gtk_table_new(12, 3, FALSE));
	gtk_widget_show(GTK_WIDGET(CTable));

	// Keyboard labels & comboboxes
	for (y=0; y<4; y++) {
		ColorLabel[y] = GTK_LABEL(gtk_label_new(PalEditLab[y]));
		gtk_table_attach(CTable, GTK_WIDGET(ColorLabel[y]), 0, 3, y*3, y*3+1, GTK_FILL | GTK_EXPAND, GTK_FILL, 12, 2);
		gtk_widget_show(GTK_WIDGET(ColorLabel[y]));
		ColorPrev[y] = GTK_DRAWING_AREA(gtk_drawing_area_new());
		gtk_widget_set_size_request(GTK_WIDGET(ColorPrev[y]), 32, 32);
		g_signal_connect(GTK_WIDGET(ColorPrev[y]), "expose_event", G_CALLBACK(ColorPrev_exposure), (gpointer)y);
		gtk_table_attach(CTable, GTK_WIDGET(ColorPrev[y]), 0, 3, y*3+1, y*3+2, GTK_FILL | GTK_EXPAND, GTK_FILL, 12, 2);
		gtk_widget_show(GTK_WIDGET(ColorPrev[y]));
		for (x=0; x<3; x++) {
			ColorComp_Adj[y][x] = GTK_ADJUSTMENT(gtk_adjustment_new(0.0, 0.0, 255.0, 1.0, 16.0, 0.0));
			g_signal_connect(ColorComp_Adj[y][x], "value_changed", G_CALLBACK(ColorComp_Adj_changed), (gpointer)(y*4+x));
			ColorComp[x][y] = GTK_SCALE(gtk_hscale_new(ColorComp_Adj[y][x]));
			g_signal_connect(ColorComp[x][y], "format-value", G_CALLBACK(ColorComp_formatvalue), (gpointer)(y*4+x));
			gtk_table_attach(CTable, GTK_WIDGET(ColorComp[x][y]), x, x+1, y*3+2, y*3+3, GTK_FILL | GTK_EXPAND, GTK_FILL, 12, 2);
			gtk_widget_show(GTK_WIDGET(ColorComp[x][y]));
		}
	}

	// Scrolling window
	PalEditSW = GTK_SCROLLED_WINDOW(gtk_scrolled_window_new(NULL, NULL));
	gtk_scrolled_window_set_policy(PalEditSW, GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
	gtk_scrolled_window_add_with_viewport(PalEditSW, GTK_WIDGET(CTable));
	gtk_container_add(GTK_CONTAINER(VBox1), GTK_WIDGET(PalEditSW));
	gtk_widget_show(GTK_WIDGET(PalEditSW));

	// Horizontal buttons box and they buttons
	HButtonBox = GTK_BUTTON_BOX(gtk_hbutton_box_new());
	gtk_button_box_set_layout(GTK_BUTTON_BOX(HButtonBox), GTK_BUTTONBOX_END);
	gtk_box_set_spacing(GTK_BOX(HButtonBox), 0);
	gtk_box_pack_start(VBox1, GTK_WIDGET(HButtonBox), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(HButtonBox));

	ButtonClose = GTK_BUTTON(gtk_button_new_with_label("Close"));
	g_signal_connect(ButtonClose, "clicked", G_CALLBACK(PalEditWindow_ButtonClose_clicked), NULL);
	gtk_container_add(GTK_CONTAINER(HButtonBox), GTK_WIDGET(ButtonClose));
	gtk_widget_show(GTK_WIDGET(ButtonClose));

	return 1;
}

void PalEditWindow_Destroy(void)
{
}

void PalEditWindow_Activate(void)
{
	gtk_widget_show(GTK_WIDGET(PalEditWindow));
	gtk_window_present(PalEditWindow);
}

void PalEditWindow_UpdateConfigs(void)
{
	int y;

	PalEditWindow_InConfigs = 1;

	// Modify adjusters
	for (y=0; y<4; y++) {
		gtk_adjustment_set_value(ColorComp_Adj[y][0], (double)GetValH24(CommandLine.custompal[y]));
		gtk_adjustment_set_value(ColorComp_Adj[y][1], (double)GetValM24(CommandLine.custompal[y]));
		gtk_adjustment_set_value(ColorComp_Adj[y][2], (double)GetValL24(CommandLine.custompal[y]));
	}	

	PalEditWindow_InConfigs = 0;
}
