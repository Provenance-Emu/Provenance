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

#ifndef YUI_SETTINGS_H
#define YUI_SETTINGS_H

#include <gtk/gtk.h>

#include "../vdp1.h"
#include "../vdp2.h"
#include "../scsp.h"
#include "../yabause.h"
#include "../cdbase.h"
#include "../peripheral.h"

#include "yuiwindow.h"

extern GKeyFile * keyfile;
extern yabauseinit_struct yinit;

extern void YuiSaveState(void);
extern void YuiLoadState(void);

GtkWidget* create_dialog1(void);
GtkWidget* create_menu(YuiWindow *);

void yui_conf(void);
void yui_resize(guint, guint, gboolean);

void gtk_yui_toggle_fullscreen(void);

void yui_texture_free(guchar *pixels, gpointer data);

#endif
