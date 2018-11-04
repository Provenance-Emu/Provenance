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

#ifndef YUI_GL_H
#define YUI_GL_H

#include <gtk/gtk.h>

#ifdef HAVE_LIBGTKGLEXT
#include <GL/gl.h>
#include <gtk/gtkgl.h>
#endif

G_BEGIN_DECLS

#define YUI_GL_TYPE            (yui_gl_get_type ())
#define YUI_GL(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_GL_TYPE, YuiGl))
#define YUI_GL_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_GL_TYPE, YuiGlClass))
#define IS_YUI_GL(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_GL_TYPE))
#define IS_YUI_GL_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_GL_TYPE))

typedef struct _YuiGl       YuiGl;
typedef struct _YuiGlClass  YuiGlClass;

struct _YuiGl
{
  GtkDrawingArea hbox;

  guint * pixels;
  gint pixels_width;
  gint pixels_height;
  gint pixels_rowstride;
  gint is_init;
};

struct _YuiGlClass
{
  GtkDrawingAreaClass parent_class;
};

GType		yui_gl_get_type		(void);
GtkWidget *	yui_gl_new		(void);

void		yui_gl_draw		(YuiGl *);
void		yui_gl_draw_pause	(YuiGl *);
void		yui_gl_dump_screen	(YuiGl *);

G_END_DECLS

#endif
