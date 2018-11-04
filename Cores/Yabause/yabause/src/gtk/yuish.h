/*  Copyright 2005-2006 Fabien Coulon
    Copyright 2008 Guillaume Duhamel

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

#ifndef YUI_SH_H
#define YUI_SH_H

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtktable.h>

#include "../sh2core.h"
#include "yuiwindow.h"

G_BEGIN_DECLS

#define YUI_SH_TYPE            (yui_sh_get_type ())
#define YUI_SH(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), YUI_SH_TYPE, YuiSh))
#define YUI_SH_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),  YUI_SH_TYPE, YuiShClass))
#define IS_YUI_SH(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), YUI_SH_TYPE))
#define IS_YUI_SH_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),  YUI_SH_TYPE))

typedef struct _YuiSh       YuiSh;
typedef struct _YuiShClass  YuiShClass;

struct _YuiSh
{
  GtkWindow dialog;

  GtkWidget * view;
  GtkWidget * toolbar;
  GtkWidget *vbox;
  GtkWidget *hboxmain;
  GtkToolItem * buttonStep;
  GtkWidget *bpList, *mbpList, *regList; //, *uLabel, *uFrame;
  GtkListStore *bpListStore, *mbpListStore, *regListStore;
  GtkCellRenderer *bpListRenderer, *mbpListRenderer, *regListRenderer1, *regListRenderer2;
  GtkTreeViewColumn *bpListColumn, *mbpListColumn, *regListColumn1, *regListColumn2;
  //u32 cbp[MAX_BREAKPOINTS]; /* the list of breakpoint positions, as they can be found in the list widget */
  //u32 cmbp[MAX_BREAKPOINTS]; /* the list of memory breakpoint positions, as they can be found in the list widget */
  //u32 mbpFlags[MAX_BREAKPOINTS]; 
  u32 lastCode; /* offset of last unassembly. Try to reuse it to prevent sliding. */
  SH2_struct *debugsh;  
  gboolean bMaster;
  gboolean breakpointEnabled;
  gulong paused_handler;
  gulong running_handler;

  GtkListStore * store;

  GtkWidget * bp_menu;
  GtkWidget * mbp_menu;
  GtkWidget * mbp_menu_item[6];

  GtkWidget * vboxBp;
};

struct _YuiShClass
{
  GtkWindowClass parent_class;

  void (* yui_sh) (YuiSh * yv);
};

GType		yui_sh_get_type       (void);
GtkWidget * yui_msh_new(YuiWindow * y); 
GtkWidget * yui_ssh_new(YuiWindow * y);
void		yui_sh_fill		(YuiSh * sh);
void		yui_sh_update		(YuiSh * sh);
void		yui_sh_destroy	(YuiSh * sh);

G_END_DECLS

#endif
