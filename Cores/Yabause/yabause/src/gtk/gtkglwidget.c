/*  Copyright 2006 Guillaume Duhamel
    Copyright 2006 Fabien Coulon

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

#include "gtkglwidget.h"
#ifdef HAVE_LIBGTKGLEXT
#include <gtk/gtkgl.h>
#endif
#include "../vidsoft.h"
#include "../peripheral.h"

#define X_NOSCALE 160
#define Y_NOSCALE 120

static void yui_gl_class_init	(YuiGlClass * klass);
static void yui_gl_init		(YuiGl      * yfe);
static gboolean yui_gl_resize   (GtkWidget *w,GdkEventConfigure *event, gpointer data);

void yui_gl_draw(YuiGl * glxarea) {
#ifdef HAVE_LIBGTKGLEXT
	GdkGLContext *glcontext = gtk_widget_get_gl_context (GTK_WIDGET(glxarea));
	GdkGLDrawable *gldrawable = gtk_widget_get_gl_drawable (GTK_WIDGET(glxarea));

	if (!gdk_gl_drawable_make_current (gldrawable, glcontext)) {
		g_print("Cannot set gl drawable current\n");
		return;
	}

	gdk_gl_drawable_swap_buffers(gldrawable);
#else
	int buf_width, buf_height;
	GdkPixbuf * pixbuf, * scaledpixbuf;

	VIDCore->GetGlSize( &buf_width, &buf_height );
	glxarea->pixels_width = GTK_WIDGET(glxarea)->allocation.width;
	glxarea->pixels_height = GTK_WIDGET(glxarea)->allocation.height;
	glxarea->pixels_rowstride = glxarea->pixels_width * 4;
	glxarea->pixels_rowstride += (glxarea->pixels_rowstride % 4)? (4 - (glxarea->pixels_rowstride % 4)): 0;

	if (dispbuffer == NULL) return;

	pixbuf = gdk_pixbuf_new_from_data((const guchar *) dispbuffer, GDK_COLORSPACE_RGB, TRUE, 8,
			buf_width, buf_height, buf_width*4, NULL, NULL);

	if (( glxarea->pixels_width < buf_width + X_NOSCALE )&&( glxarea->pixels_height < buf_height + Y_NOSCALE )) {

	  gdk_draw_pixbuf(GTK_WIDGET(glxarea)->window, NULL, pixbuf, 0, 0,
			  (glxarea->pixels_width-buf_width)/2, (glxarea->pixels_height-buf_height)/2,
			  buf_width, buf_height, GDK_RGB_DITHER_NONE, 0, 0);
	} else {

	  scaledpixbuf = gdk_pixbuf_scale_simple(pixbuf, 
						 glxarea->pixels_width, glxarea->pixels_height, GDK_INTERP_NEAREST );
	  gdk_draw_pixbuf(GTK_WIDGET(glxarea)->window, NULL, 
			  scaledpixbuf, 0, 0, 0, 0, glxarea->pixels_width, glxarea->pixels_height, 
			  GDK_RGB_DITHER_NONE, 0, 0);
	  g_object_unref(scaledpixbuf);
	}
	g_object_unref(pixbuf);
#endif
	glxarea->is_init = 1;
}

void yui_gl_draw_pause(YuiGl * glxarea) {
#ifdef HAVE_LIBGTKGLEXT
	if (glxarea->pixels) {
		/* The "correct" raster position would be (0, height) but it's not a
		 * valid position, so I have to use this hack... found here:
		 * http://www.opengl.org/resources/features/KilgardTechniques/oglpitfall/ */ 
		glRasterPos2i(0, 0);
		glBitmap(0, 0, 0, 0, 0, - glxarea->pixels_height, NULL);
		glPixelZoom(1, 1);
		glDrawPixels(glxarea->pixels_width, glxarea->pixels_height, GL_RGB, GL_UNSIGNED_BYTE, glxarea->pixels);
		yui_gl_draw(glxarea);
	} else {
		gdk_draw_rectangle(GTK_WIDGET(glxarea)->window, GTK_WIDGET(glxarea)->style->bg_gc[GTK_WIDGET_STATE (glxarea)],
				TRUE, 0, 0, GTK_WIDGET(glxarea)->allocation.width, GTK_WIDGET(glxarea)->allocation.height);
	}
#else
	if (dispbuffer)
		yui_gl_draw(glxarea);
#endif
}

static gboolean yui_gl_resize(GtkWidget *w,GdkEventConfigure *event, gpointer data) {
#ifdef HAVE_LIBGTKGLEXT
	GdkGLContext *glcontext = gtk_widget_get_gl_context (w);
	GdkGLDrawable *gldrawable = gtk_widget_get_gl_drawable (w);

	if (!gdk_gl_drawable_gl_begin (gldrawable, glcontext))
		return FALSE;

	glViewport(0, 0, event->width, event->height);
        if ( YUI_GL(w)->is_init ) VIDCore->Resize(event->width, event->height, FALSE );
#endif
	return FALSE;
}

int beforehiding = 0;

static gboolean gonna_hide(gpointer data) {
	beforehiding--;

	if (beforehiding == 0) {
		static char source_data[] = { 0 };
		static char mask_data[] = { 0 };

		GdkCursor *cursor;
 		GdkPixmap *source, *mask;
		GdkColor fg = { 0, 65535, 65535, 65535 };
		GdkColor bg = { 0, 0, 0, 0 };
 
		source = gdk_bitmap_create_from_data(NULL, source_data, 1, 1);
		mask = gdk_bitmap_create_from_data(NULL, mask_data, 1, 1);
		cursor = gdk_cursor_new_from_pixmap(source, mask, &fg, &bg, 1, 1);
		gdk_pixmap_unref(source);
		gdk_pixmap_unref(mask);

		gdk_window_set_cursor(GTK_WIDGET(data)->window, cursor);

		return FALSE;
	} else {
		return TRUE;
	}
}

extern void * padbits;
extern GKeyFile * keyfile;
int oldx = 0;
int oldy = 0;

static gboolean yui_gl_hide_cursor(GtkWidget * widget, GdkEventMotion * event, gpointer user_data) {
	if (PerGetId(padbits) == PERMOUSE) {
		int x = event->x;
		int y = event->y;
		double speed = g_key_file_get_double(keyfile, "General", "MouseSpeed", NULL);

		PerMouseMove(padbits, speed * (x - oldx), -speed * (y - oldy));
		oldx = x;
		oldy = y;
	}

	if (beforehiding == 0) {
		gdk_window_set_cursor(widget->window, NULL);
		g_timeout_add(1000, gonna_hide, widget);
	}

	beforehiding = 2;

	return FALSE;
}

static gboolean yui_gl_button_press(GtkWidget * widget, GdkEventButton * event, gpointer user_data) {
	if (PerGetId(padbits) == PERMOUSE) {
		switch(event->button) {
			case 1:
				PerMouseLeftPressed(padbits);
				break;
			case 2:
				PerMouseMiddlePressed(padbits);
				break;
			case 3:
				PerMouseRightPressed(padbits);
				break;
		}
	}
	return FALSE;
}

static gboolean yui_gl_button_release(GtkWidget * widget, GdkEventButton * event, gpointer user_data) {
	if (PerGetId(padbits) == PERMOUSE) {
		switch(event->button) {
			case 1:
				PerMouseLeftReleased(padbits);
				break;
			case 2:
				PerMouseMiddleReleased(padbits);
				break;
			case 3:
				PerMouseRightReleased(padbits);
				break;
		}
	}
	return FALSE;
}

GtkWidget * yui_gl_new(void) {
	GtkWidget * drawingArea;
#ifdef HAVE_LIBGTKGLEXT
	int attribs[] = {
		GDK_GL_RGBA,
		GDK_GL_RED_SIZE,   1,
		GDK_GL_GREEN_SIZE, 1,
		GDK_GL_BLUE_SIZE,  1,

		GDK_GL_DOUBLEBUFFER,

		GDK_GL_DEPTH_SIZE ,1,
        GDK_GL_STENCIL_SIZE ,8,
		GDK_GL_ATTRIB_LIST_NONE 
	};
#endif

	drawingArea = GTK_WIDGET(g_object_new(yui_gl_get_type(), NULL));
	YUI_GL(drawingArea)->is_init = 0;

#ifdef HAVE_LIBGTKGLEXT
	gtk_widget_set_gl_capability(drawingArea, gdk_gl_config_new(attribs), NULL, TRUE, GDK_GL_RGBA_TYPE);
#endif

	g_signal_connect (GTK_OBJECT(drawingArea),"configure_event", GTK_SIGNAL_FUNC(yui_gl_resize),0);

	gtk_widget_set_events(drawingArea, GDK_POINTER_MOTION_MASK | GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK);

	g_signal_connect(GTK_OBJECT(drawingArea), "motion-notify-event", GTK_SIGNAL_FUNC(yui_gl_hide_cursor),0);
	g_signal_connect(GTK_OBJECT(drawingArea), "button-press-event", GTK_SIGNAL_FUNC(yui_gl_button_press),0);
	g_signal_connect(GTK_OBJECT(drawingArea), "button-release-event", GTK_SIGNAL_FUNC(yui_gl_button_release),0);

	return drawingArea;
}

void yui_gl_dump_screen(YuiGl * glxarea) {
#ifdef HAVE_LIBGTKGLEXT
	int size;

	glxarea->pixels_width = GTK_WIDGET(glxarea)->allocation.width;
	glxarea->pixels_height = GTK_WIDGET(glxarea)->allocation.height;
	glxarea->pixels_rowstride = glxarea->pixels_width * 3;
	glxarea->pixels_rowstride += (glxarea->pixels_rowstride % 4)? (4 - (glxarea->pixels_rowstride % 4)): 0;

        size = glxarea->pixels_rowstride * glxarea->pixels_height;
 
	if (glxarea->pixels) free(glxarea->pixels);
        glxarea->pixels = malloc(sizeof(GLubyte) * size);
        if (glxarea->pixels == NULL) return;    

        glReadPixels(0, 0, glxarea->pixels_width, glxarea->pixels_height, GL_RGB, GL_UNSIGNED_BYTE, glxarea->pixels);
#else
	int buf_width, buf_height;
	int i, j;
	int size;
	int cur = 0;
	u8 * pixels;
	u8 * buffer;

	VIDCore->GetGlSize( &buf_width, &buf_height );
	size = buf_width * buf_height * 3;

	glxarea->pixels_width = buf_width;
	glxarea->pixels_height = buf_height;
	glxarea->pixels_rowstride = glxarea->pixels_width * 3;
	glxarea->pixels_rowstride += (glxarea->pixels_rowstride % 4)? (4 - (glxarea->pixels_rowstride % 4)): 0;

	if (! glxarea->pixels) glxarea->pixels = malloc(sizeof(u8) * size);

	pixels = (u8 *)glxarea->pixels;
	pixels += size - (buf_width * 3);
	buffer = (u8 *)dispbuffer;

	for(i = 0;i < buf_height;i++) {
		for(j = 0;j < buf_width;j++) {
			*pixels++ = buffer[cur];
			*pixels++ = buffer[cur + 1];
			*pixels++ = buffer[cur + 2];
			cur += 4;
		}
		pixels -= buf_width * 6;
	}
#endif
}

GType yui_gl_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiGlClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_gl_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiGl),
	0,
	(GInstanceInitFunc) yui_gl_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_DRAWING_AREA, "YuiGl", &yfe_info, 0);
    }

  return yfe_type;
}

static void yui_gl_class_init (UNUSED YuiGlClass * klass) {
}

static void yui_gl_init (YuiGl * y) {
	y->pixels = NULL;
}
