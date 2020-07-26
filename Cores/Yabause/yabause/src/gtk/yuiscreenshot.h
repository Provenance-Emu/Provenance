/*  Copyright 2006 Guillaume Duhamel
    Copyright 2005-2006 Fabien Coulon

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

#ifndef YUI_SCREENSHOT_H
#define YUI_SCREENSHOT_H

#include <gtk/gtk.h>

#include "yuiwindow.h"

G_BEGIN_DECLS

#define YUI_SCREENSHOT_TYPE            (yui_screenshot_get_type ())
#define YUI_SCREENSHOT(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_SCREENSHOT_TYPE, YuiScreenshot))
#define YUI_SCREENSHOT_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_SCREENSHOT_TYPE, YuiScreenshotClass))
#define IS_YUI_SCREENSHOT(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_SCREENSHOT_TYPE))
#define IS_YUI_SCREENSHOT_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_SCREENSHOT_TYPE))

typedef struct _YuiScreenshot       YuiScreenshot;
typedef struct _YuiScreenshotClass  YuiScreenshotClass;

struct _YuiScreenshot
{
  GtkWindow dialog;

  GtkWidget * image;
};

struct _YuiScreenshotClass
{
  GtkWindowClass parent_class;
};

GType		yui_screenshot_get_type (void);
GtkWidget *	yui_screenshot_new      (YuiWindow * yui);

G_END_DECLS

#endif
