/*  Copyright 2005-2006 Fabien Coulon

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

#ifndef YUI_M68K_H
#define YUI_M68K_H

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtktable.h>

#include "../scsp.h"
#include "yuiwindow.h"

G_BEGIN_DECLS

#define YUI_M68K_TYPE            (yui_m68k_get_type ())
#define YUI_M68K(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_M68K_TYPE, YuiM68k))
#define YUI_M68K_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_M68K_TYPE, YuiM68kClass))
#define IS_YUI_M68K(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_M68K_TYPE))
#define IS_YUI_M68K_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_M68K_TYPE))

typedef struct _YuiM68k       YuiM68k;
typedef struct _YuiM68kClass  YuiM68kClass;

struct _YuiM68k
{
  GtkWindow dialog;

  GtkWidget *vbox, *vboxmain;
  GtkWidget *hbox, *hboxmain;
  GtkWidget * buttonStep, * buttonStepOver;
  GtkWidget * bpList, *regList, *uLabel, *uFrame;
  GtkListStore *bpListStore, *regListStore;
  GtkCellRenderer *bpListRenderer, *regListRenderer1, *regListRenderer2;
  GtkTreeViewColumn *bpListColumn, *regListColumn1, *regListColumn2;
  u32 cbp[MAX_BREAKPOINTS]; /* the list of breakpoint positions, as they can be found in the list widget */
  u32 lastCode; /* offset of last unassembly. Try to reuse it to prevent sliding. */
  gulong paused_handler;
  gulong running_handler;
};

struct _YuiM68kClass
{
  GtkWindowClass parent_class;

  void (* yui_m68k) (YuiM68k * yv);
};

GType		yui_m68k_get_type       (void);
GtkWidget*      yui_m68k_new(YuiWindow * y); 
void		yui_m68k_update		(YuiM68k * m68k);
void		yui_m68k_destroy	(YuiM68k * sh);

G_END_DECLS

#endif
