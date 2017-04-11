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

#include <gtk/gtk.h>
#include <gdk/gdkkeysyms.h>

#include "yuish.h"
#include "../sh2core.h"
#include "../sh2d.h"
#include "../yabause.h"
#include "settings.h"

static void yui_sh_class_init	(YuiShClass * klass);
static void yui_sh_init		(YuiSh      * yfe);
static void yui_sh_clear(YuiSh * sh);
static void yui_sh_editedReg( GtkCellRendererText *cellrenderertext,
			      gchar *arg1,
			      gchar *arg2,
			      YuiSh *sh2);
static void yui_sh_editedBp( GtkCellRendererText *cellrenderertext,
			     gchar *arg1,
			     gchar *arg2,
			     YuiSh *sh2);
static void yui_sh_editedMbp( GtkCellRendererText *cellrenderertext,
			     gchar *arg1,
			     gchar *arg2,
			      YuiSh *sh2);
static void yui_sh_editedMbpFlags( GtkCellRendererText *cellrenderertext,
			     gchar *arg1,
			     gchar *arg2,
			      YuiSh *sh2);
static void yui_sh_step( GtkWidget* widget, YuiSh * sh2 );
static void SH2BreakpointHandler (SH2_struct *context, u32 addr, void *userdata);
static gint yui_sh_popup(GtkWidget * widget, GdkEvent * event, gpointer data);
static gint yui_sh_bp_popup(GtkWidget * widget, GdkEventButton * event, gpointer data);
static gint yui_sh_mbp_popup(GtkWidget * widget, GdkEventButton * event, gpointer data);
static void yui_sh_popup_add_bp(GtkMenuItem * menuitem, gpointer user_data);
static void yui_sh_popup_del_bp(GtkMenuItem * menuitem, gpointer user_data);
static void SH2UpdateBreakpointList(YuiSh * sh2);
static void SH2UpdateMemoryBreakpointList(YuiSh * sh2);
static void yui_sh_bp_add(GtkEntry * entry, gpointer user_data);
static void yui_sh_button_bp_add(GtkWidget * widget, gpointer user_data);
static void yui_sh_mbp_add(GtkEntry * entry, gpointer user_data);
static void yui_sh_mbp_toggle_flag(GtkWidget * menuitem, gpointer user_data);
static void yui_sh_mbp_remove(GtkWidget * menuitem, gpointer user_data);
static void yui_sh_mbp_clear(GtkWidget * menuitem, gpointer user_data);
static void yui_sh_bp_remove(GtkWidget * menuitem, gpointer user_data);
static void yui_sh_bp_clear(GtkWidget * menuitem, gpointer user_data);

static YuiSh *yui_msh, *yui_ssh;
static YuiWindow * yui;

GType yui_sh_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiShClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_sh_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiSh),
	0,
	(GInstanceInitFunc) yui_sh_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_WINDOW, "YuiSh", &yfe_info, 0);
    }

  return yfe_type;
}

static void yui_sh_class_init (UNUSED YuiShClass * klass) {
}

static void yui_sh_init (YuiSh * sh2) {
  //GtkWidget *vboxBp;

  sh2->breakpointEnabled = MSH2->breakpointEnabled; 

  gtk_window_set_title(GTK_WINDOW(sh2), "SH");

  sh2->vbox = gtk_vbox_new(FALSE, 0);
  gtk_container_set_border_width( GTK_CONTAINER( sh2->vbox ), 0);
  gtk_container_add (GTK_CONTAINER (sh2), sh2->vbox);  

	sh2->toolbar = gtk_toolbar_new();
	gtk_toolbar_set_style(GTK_TOOLBAR(sh2->toolbar), GTK_TOOLBAR_ICONS);
	gtk_box_pack_start(GTK_BOX(sh2->vbox), sh2->toolbar, FALSE, FALSE, 0);

  sh2->hboxmain = gtk_hbox_new(FALSE, 4);
  gtk_box_pack_start( GTK_BOX( sh2->vbox ), sh2->hboxmain, FALSE, FALSE, 0);

  /* Register list */

  sh2->regListStore = gtk_list_store_new(2,G_TYPE_STRING,G_TYPE_STRING);
  sh2->regList = gtk_tree_view_new_with_model( GTK_TREE_MODEL(sh2->regListStore) );
  sh2->regListRenderer1 = gtk_cell_renderer_text_new();
  sh2->regListRenderer2 = gtk_cell_renderer_text_new();
  g_object_set(G_OBJECT(sh2->regListRenderer2), "editable", TRUE, "mode", GTK_CELL_RENDERER_MODE_EDITABLE, NULL );
  sh2->regListColumn1 = gtk_tree_view_column_new_with_attributes(_("Register"), sh2->regListRenderer1, "text", 0, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(sh2->regList), sh2->regListColumn1);
  sh2->regListColumn2 = gtk_tree_view_column_new_with_attributes(_("Value"), sh2->regListRenderer2, "text", 1, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(sh2->regList), sh2->regListColumn2);
  gtk_box_pack_start( GTK_BOX( sh2->hboxmain ), sh2->regList, FALSE, FALSE, 0);
  g_signal_connect(G_OBJECT(sh2->regListRenderer2), "edited", GTK_SIGNAL_FUNC(yui_sh_editedReg), sh2 );

	sh2->store = gtk_list_store_new(3, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
	sh2->view = gtk_tree_view_new_with_model(GTK_TREE_MODEL (sh2->store));
	gtk_tree_view_set_headers_visible(GTK_TREE_VIEW(sh2->view), FALSE);
	{
		GtkWidget * scroll;
		GtkCellRenderer *renderer;
		GtkCellRenderer *icon;
		GtkTreeViewColumn *column;

		scroll = gtk_scrolled_window_new(NULL, NULL);
		gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);

		icon = gtk_cell_renderer_pixbuf_new();
		g_object_set(icon, "xalign", 0, NULL);
		column = gtk_tree_view_column_new_with_attributes("Icon", icon, "stock-id", 0, NULL);
		gtk_tree_view_append_column(GTK_TREE_VIEW (sh2->view), column);

		renderer = gtk_cell_renderer_text_new();
		column = gtk_tree_view_column_new_with_attributes("Address", renderer, "text", 1, NULL);
		gtk_tree_view_append_column(GTK_TREE_VIEW (sh2->view), column);

		column = gtk_tree_view_column_new_with_attributes("Command", renderer, "text", 2, NULL);
		gtk_tree_view_append_column(GTK_TREE_VIEW (sh2->view), column);

		gtk_container_add(GTK_CONTAINER(scroll), sh2->view);
		gtk_box_pack_start(GTK_BOX(sh2->hboxmain), scroll, TRUE, TRUE, 0);
	}

	if (sh2->breakpointEnabled) {
		GtkWidget * menu = gtk_menu_new();
		GtkWidget * item;

		item = gtk_image_menu_item_new_from_stock(GTK_STOCK_ADD, NULL);
		gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
		g_signal_connect(item, "activate", G_CALLBACK(yui_sh_popup_add_bp), sh2);

		item = gtk_image_menu_item_new_from_stock(GTK_STOCK_REMOVE, NULL);
		gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
		g_signal_connect(item, "activate", G_CALLBACK(yui_sh_popup_del_bp), sh2);

		gtk_widget_show_all(menu);

		g_signal_connect(sh2->view, "button-press-event", G_CALLBACK(yui_sh_popup), menu);
	}

  /* breakpoint list */

  sh2->vboxBp = gtk_vbox_new(FALSE, 0);
  gtk_box_pack_start( GTK_BOX( sh2->hboxmain ), sh2->vboxBp, FALSE, FALSE, 0 );

  sh2->bpListStore = gtk_list_store_new(1,G_TYPE_STRING);
  sh2->bpList = gtk_tree_view_new_with_model( GTK_TREE_MODEL(sh2->bpListStore) );
  sh2->bpListRenderer = gtk_cell_renderer_text_new();
  g_object_set(G_OBJECT(sh2->bpListRenderer), "editable", TRUE, "mode", GTK_CELL_RENDERER_MODE_EDITABLE, NULL );
  sh2->bpListColumn = gtk_tree_view_column_new_with_attributes("Code breaks", sh2->bpListRenderer, "text", 0, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(sh2->bpList), sh2->bpListColumn);
  gtk_box_pack_start( GTK_BOX( sh2->vboxBp ), sh2->bpList, TRUE, TRUE, 0 );
  g_signal_connect(G_OBJECT(sh2->bpListRenderer), "edited", GTK_SIGNAL_FUNC(yui_sh_editedBp), sh2 );

	{
		GtkWidget * bp_form_box;
		GtkWidget * bp_input;
		GtkWidget * bp_add;

		bp_form_box = gtk_hbox_new(FALSE, 0);
		gtk_box_pack_start(GTK_BOX(sh2->vboxBp), bp_form_box, FALSE, FALSE, 0);

		bp_input = gtk_entry_new();
		gtk_entry_set_width_chars(GTK_ENTRY(bp_input), 8);
		g_signal_connect(bp_input, "activate", G_CALLBACK(yui_sh_bp_add), sh2);
		gtk_box_pack_start(GTK_BOX(bp_form_box), bp_input, TRUE, TRUE, 0);

		bp_add = gtk_button_new();
		gtk_container_add(GTK_CONTAINER(bp_add), gtk_image_new_from_stock(GTK_STOCK_ADD, GTK_ICON_SIZE_BUTTON));
		gtk_button_set_relief(GTK_BUTTON(bp_add), GTK_RELIEF_NONE);
		g_signal_connect(bp_add, "clicked", G_CALLBACK(yui_sh_button_bp_add), bp_input);
		gtk_box_pack_start(GTK_BOX(bp_form_box), bp_add, FALSE, FALSE, 0);
	}

	{
		GtkWidget * bp_item;
		sh2->bp_menu = gtk_menu_new();

		bp_item = gtk_image_menu_item_new_from_stock(GTK_STOCK_REMOVE, NULL);
		gtk_menu_shell_append(GTK_MENU_SHELL(sh2->bp_menu), bp_item);
		g_signal_connect(bp_item, "activate", G_CALLBACK(yui_sh_bp_remove), sh2);

		bp_item = gtk_image_menu_item_new_from_stock(GTK_STOCK_CLEAR, NULL);
		gtk_menu_shell_append(GTK_MENU_SHELL(sh2->bp_menu), bp_item);
		g_signal_connect(bp_item, "activate", G_CALLBACK(yui_sh_bp_clear), sh2);

		gtk_widget_show_all(sh2->bp_menu);

		g_signal_connect(sh2->bpList, "button-press-event", G_CALLBACK(yui_sh_bp_popup), sh2);
	}

  /* memory breakpoint list */

  sh2->mbpListStore = gtk_list_store_new(2,G_TYPE_STRING,G_TYPE_STRING);
  sh2->mbpList = gtk_tree_view_new_with_model( GTK_TREE_MODEL(sh2->mbpListStore) );
  sh2->mbpListRenderer = gtk_cell_renderer_text_new();
  g_object_set(G_OBJECT(sh2->mbpListRenderer), "editable", TRUE, "mode", GTK_CELL_RENDERER_MODE_EDITABLE, NULL );
  sh2->mbpListColumn = gtk_tree_view_column_new_with_attributes("Memory breaks", sh2->mbpListRenderer, "text", 0, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(sh2->mbpList), sh2->mbpListColumn);

	{
		GtkCellRenderer * flags_renderer;
		GtkTreeViewColumn * flags_column;

		flags_renderer = gtk_cell_renderer_text_new();
		g_object_set(G_OBJECT(flags_renderer), "editable", TRUE, "mode", GTK_CELL_RENDERER_MODE_EDITABLE, NULL);
		g_signal_connect(G_OBJECT(flags_renderer), "edited", GTK_SIGNAL_FUNC(yui_sh_editedMbpFlags), sh2 );

		flags_column =  gtk_tree_view_column_new_with_attributes("Flags", flags_renderer, "text", 1, NULL);
		gtk_tree_view_append_column(GTK_TREE_VIEW(sh2->mbpList), flags_column);
	}

  gtk_box_pack_start( GTK_BOX( sh2->vboxBp ), sh2->mbpList, TRUE, TRUE, 0 );
  g_signal_connect(G_OBJECT(sh2->mbpListRenderer), "edited", GTK_SIGNAL_FUNC(yui_sh_editedMbp), sh2 );

	{
		GtkWidget * mbp_item;

		sh2->mbp_menu = gtk_menu_new();

		sh2->mbp_menu_item[0] = gtk_check_menu_item_new_with_label("Byte read");
		gtk_menu_shell_append(GTK_MENU_SHELL(sh2->mbp_menu), sh2->mbp_menu_item[0]);
		g_signal_connect(sh2->mbp_menu_item[0], "activate", G_CALLBACK(yui_sh_mbp_toggle_flag), sh2);

		sh2->mbp_menu_item[1] = gtk_check_menu_item_new_with_label("Word read");
		gtk_menu_shell_append(GTK_MENU_SHELL(sh2->mbp_menu), sh2->mbp_menu_item[1]);
		g_signal_connect(sh2->mbp_menu_item[1], "activate", G_CALLBACK(yui_sh_mbp_toggle_flag), sh2);

		sh2->mbp_menu_item[2] = gtk_check_menu_item_new_with_label("Long read");
		gtk_menu_shell_append(GTK_MENU_SHELL(sh2->mbp_menu), sh2->mbp_menu_item[2]);
		g_signal_connect(sh2->mbp_menu_item[2], "activate", G_CALLBACK(yui_sh_mbp_toggle_flag), sh2);

		sh2->mbp_menu_item[3] = gtk_check_menu_item_new_with_label("Byte write");
		gtk_menu_shell_append(GTK_MENU_SHELL(sh2->mbp_menu), sh2->mbp_menu_item[3]);
		g_signal_connect(sh2->mbp_menu_item[3], "activate", G_CALLBACK(yui_sh_mbp_toggle_flag), sh2);

		sh2->mbp_menu_item[4] = gtk_check_menu_item_new_with_label("Word write");
		gtk_menu_shell_append(GTK_MENU_SHELL(sh2->mbp_menu), sh2->mbp_menu_item[4]);
		g_signal_connect(sh2->mbp_menu_item[4], "activate", G_CALLBACK(yui_sh_mbp_toggle_flag), sh2);

		sh2->mbp_menu_item[5] = gtk_check_menu_item_new_with_label("Long write");
		gtk_menu_shell_append(GTK_MENU_SHELL(sh2->mbp_menu), sh2->mbp_menu_item[5]);
		g_signal_connect(sh2->mbp_menu_item[5], "activate", G_CALLBACK(yui_sh_mbp_toggle_flag), sh2);

		gtk_menu_shell_append(GTK_MENU_SHELL(sh2->mbp_menu), gtk_separator_menu_item_new());

		mbp_item = gtk_image_menu_item_new_from_stock(GTK_STOCK_REMOVE, NULL);
		gtk_menu_shell_append(GTK_MENU_SHELL(sh2->mbp_menu), mbp_item);
		g_signal_connect(mbp_item, "activate", G_CALLBACK(yui_sh_mbp_remove), sh2);

		mbp_item = gtk_image_menu_item_new_from_stock(GTK_STOCK_CLEAR, NULL);
		gtk_menu_shell_append(GTK_MENU_SHELL(sh2->mbp_menu), mbp_item);
		g_signal_connect(mbp_item, "activate", G_CALLBACK(yui_sh_mbp_clear), sh2);

		gtk_widget_show_all(sh2->mbp_menu);

		g_signal_connect(sh2->mbpList, "button-press-event", G_CALLBACK(yui_sh_mbp_popup), sh2);
	}

	{
		GtkWidget * bp_form_box;
		GtkWidget * bp_input;
		GtkWidget * bp_add;

		bp_form_box = gtk_hbox_new(FALSE, 0);
		gtk_box_pack_start(GTK_BOX(sh2->vboxBp), bp_form_box, FALSE, FALSE, 0);

		bp_input = gtk_entry_new();
		gtk_entry_set_width_chars(GTK_ENTRY(bp_input), 8);
		g_signal_connect(bp_input, "activate", G_CALLBACK(yui_sh_mbp_add), sh2);
		gtk_box_pack_start(GTK_BOX(bp_form_box), bp_input, TRUE, TRUE, 0);

		bp_add = gtk_button_new();
		gtk_container_add(GTK_CONTAINER(bp_add), gtk_image_new_from_stock(GTK_STOCK_ADD, GTK_ICON_SIZE_BUTTON));
		gtk_button_set_relief(GTK_BUTTON(bp_add), GTK_RELIEF_NONE);
		g_signal_connect(bp_add, "clicked", G_CALLBACK(yui_sh_button_bp_add), bp_input);
		gtk_box_pack_start(GTK_BOX(bp_form_box), bp_add, FALSE, FALSE, 0);
	}

  g_signal_connect(G_OBJECT(sh2), "delete-event", GTK_SIGNAL_FUNC(yui_sh_destroy), NULL);

	gtk_window_set_default_size(GTK_WINDOW(sh2), 650, -1);
}


static GtkWidget * yui_sh_new(YuiWindow * y, gboolean bMaster) {
  GtkWidget * dialog;
  GClosure *closureF7; //, *closureF8;
  GtkAccelGroup *accelGroup;
  YuiSh * sh2;
  gint i;
  yui = y;

  if (!( yui->state & YUI_IS_INIT )) {
    yui_window_run(yui);
    yui_window_pause(yui);
  }

  if ( bMaster && yui_msh ) return GTK_WIDGET(yui_msh);
  if ( !bMaster && yui_ssh ) return GTK_WIDGET(yui_ssh);
  
  dialog = GTK_WIDGET(g_object_new(yui_sh_get_type(), NULL));
  sh2 = YUI_SH(dialog);

  //sh2->breakpointEnabled = MSH2->breakpointEnabled; 
/*
  if ( !sh2->breakpointEnabled )
    gtk_box_pack_start( GTK_BOX( sh2->vboxmain ), 
			gtk_label_new("Breakpoints are disabled (fast interpreter)"), FALSE, FALSE, 4 );
*/

  sh2->bMaster = bMaster;
  sh2->debugsh = bMaster ? MSH2 : SSH2; 

  SH2SetBreakpointCallBack(sh2->debugsh, (void (*)(void *, u32, void *))SH2BreakpointHandler, NULL);

  gtk_window_set_title(GTK_WINDOW(sh2), bMaster?"Master SH2":"Slave SH2");  

  for (i = 0; i < 23 ; i++) {
    
    GtkTreeIter iter;
    gtk_list_store_append( GTK_LIST_STORE( sh2->regListStore ), &iter );
  }	
  
  SH2UpdateBreakpointList(sh2);

  SH2UpdateMemoryBreakpointList(sh2);

	{
		GtkToolItem * play_button, * pause_button;

		play_button = gtk_tool_button_new_from_stock("run");
		gtk_action_connect_proxy(gtk_action_group_get_action(yui->action_group, "run"), GTK_WIDGET(play_button));
		gtk_toolbar_insert(GTK_TOOLBAR(sh2->toolbar), GTK_TOOL_ITEM(play_button), 0);

		pause_button = gtk_tool_button_new_from_stock("pause");
		gtk_action_connect_proxy(gtk_action_group_get_action(yui->action_group, "pause"), GTK_WIDGET(pause_button));
		gtk_toolbar_insert(GTK_TOOLBAR(sh2->toolbar), GTK_TOOL_ITEM(pause_button), 1);

		sh2->buttonStep = gtk_tool_button_new_from_stock(GTK_STOCK_GO_DOWN);
		g_signal_connect(sh2->buttonStep, "clicked", G_CALLBACK(yui_sh_step), sh2);
		gtk_toolbar_insert(GTK_TOOLBAR(sh2->toolbar), GTK_TOOL_ITEM(sh2->buttonStep), 2);
#if GTK_CHECK_VERSION(2,12,0)
		gtk_widget_set_tooltip_text(GTK_WIDGET(sh2->buttonStep), "step");
#endif
	}
  
  sh2->paused_handler = g_signal_connect_swapped(yui, "paused", G_CALLBACK(yui_sh_update), sh2);
  sh2->running_handler = g_signal_connect_swapped(yui, "running", G_CALLBACK(yui_sh_clear), sh2);
  accelGroup = gtk_accel_group_new ();
  closureF7 = g_cclosure_new (G_CALLBACK (yui_sh_step), sh2, NULL);
  gtk_accel_group_connect( accelGroup, GDK_F7, 0, 0, closureF7 );
  gtk_window_add_accel_group( GTK_WINDOW( dialog ), accelGroup );

  yui_sh_update(sh2);
  if ( yui->state & YUI_IS_RUNNING ) yui_sh_clear(sh2);
  
  gtk_widget_show_all(GTK_WIDGET(sh2));
  if ( !sh2->breakpointEnabled ) {
/*
    gtk_widget_hide( sh2->bpList );
    gtk_widget_hide( sh2->mbpList );
*/
    gtk_widget_hide(sh2->vboxBp);
  }
  
  return dialog;
}

GtkWidget * yui_msh_new(YuiWindow * y) { 
  return GTK_WIDGET( yui_msh = YUI_SH(yui_sh_new( y, TRUE )) );
}

GtkWidget * yui_ssh_new(YuiWindow * y) { 
  return GTK_WIDGET( yui_ssh = YUI_SH(yui_sh_new( y, FALSE )) );
}

static void SH2UpdateRegList( YuiSh *sh2, sh2regs_struct *regs) {
  /* refresh the registery list */

  GtkTreeIter iter;
  char regstr[32];
  char valuestr[32];
  int i;
  
  for (i = 0; i < 16; i++) {
    sprintf(regstr, "R%02d", i);
    sprintf(valuestr, "%08X", (int)regs->R[i] );
    if ( !i ) gtk_tree_model_get_iter_first( GTK_TREE_MODEL( sh2->regListStore ), &iter );
    else gtk_tree_model_iter_next( GTK_TREE_MODEL( sh2->regListStore ), &iter );
    gtk_list_store_set( GTK_LIST_STORE( sh2->regListStore ), &iter, 0, regstr, 1, valuestr, -1 );
  }
  
  #define SH2UPDATEREGLIST(rreg) \
  gtk_tree_model_iter_next( GTK_TREE_MODEL( sh2->regListStore ), &iter ); \
  sprintf(valuestr, "%08X", (int)regs->rreg); \
  gtk_list_store_set( GTK_LIST_STORE( sh2->regListStore ), &iter, 0, #rreg, 1, valuestr, -1 );
  
  SH2UPDATEREGLIST(SR.all);
  SH2UPDATEREGLIST(GBR);
  SH2UPDATEREGLIST(VBR);
  SH2UPDATEREGLIST(MACH);
  SH2UPDATEREGLIST(MACL);
  SH2UPDATEREGLIST(PR);
  SH2UPDATEREGLIST(PC);
}

static void sh2setRegister( YuiSh *sh2, int nReg, u32 value ) {
  /* set register number <nReg> to value <value> in proc <sh2> */

  sh2regs_struct sh2regs;
  SH2GetRegisters(sh2->debugsh, &sh2regs);

  if ( nReg < 16 ) sh2regs.R[nReg] = value;
  switch ( nReg ) {
  case 16: sh2regs.SR.all = value; break;
  case 17: sh2regs.GBR = value; break;
  case 18: sh2regs.VBR = value; break;
  case 19: sh2regs.MACH = value; break;
  case 20: sh2regs.MACL = value; break;
  case 21: sh2regs.PR = value; break;
  case 22: sh2regs.PC = value; break;
  }

  SH2SetRegisters(sh2->debugsh, &sh2regs);
}

void SH2UpdateBreakpointList(YuiSh * sh2) {
  const codebreakpoint_struct *cbp;
  int i;

  gtk_list_store_clear(GTK_LIST_STORE( sh2->bpListStore ));
  
  cbp = SH2GetBreakpointList(sh2->debugsh);
  
  for (i = 0; i < MAX_BREAKPOINTS-1; i++) {
    
    if (cbp[i].addr != 0xFFFFFFFF) {
      gchar tempstr[20];
      GtkTreeIter iter;
      gtk_list_store_append( GTK_LIST_STORE( sh2->bpListStore ), &iter );
      
      sprintf(tempstr, "%08X", (int)cbp[i].addr);
      gtk_list_store_set( GTK_LIST_STORE( sh2->bpListStore ), &iter, 0, tempstr, -1 );
    }
  } 
}

void SH2UpdateMemoryBreakpointList(YuiSh * sh2) {
  const memorybreakpoint_struct *cmbp;
  int i;

  gtk_list_store_clear( sh2->mbpListStore );

  cmbp = SH2GetMemoryBreakpointList(sh2->debugsh);

  for (i = 0; i < MAX_BREAKPOINTS; i++) {
    
    if (cmbp[i].addr != 0xFFFFFFFF) {
      gchar tempstr[30];
      gchar flagstr[30];
      gchar *curs = flagstr;
      u32 flags = cmbp[i].flags;

      GtkTreeIter iter;
      gtk_list_store_append( GTK_LIST_STORE( sh2->mbpListStore ), &iter );
      
      sprintf(tempstr, "%08X", (int)cmbp[i].addr);
      if ( flags & BREAK_BYTEREAD ) *(curs++) = 'b';
      if ( flags & BREAK_WORDREAD ) *(curs++) = 'w';
      if ( flags & BREAK_LONGREAD ) *(curs++) = 'l';
      if ( flags & BREAK_BYTEWRITE ) *(curs++) = 'B';
      if ( flags & BREAK_WORDWRITE ) *(curs++) = 'W';
      if ( flags & BREAK_LONGWRITE ) *(curs++) = 'L';
      *curs = 0;
       
      gtk_list_store_set( GTK_LIST_STORE( sh2->mbpListStore ), &iter, 0, tempstr, -1 );
      gtk_list_store_set( GTK_LIST_STORE( sh2->mbpListStore ), &iter, 1, flagstr, -1 );
    }
  } 
}

static void SH2UpdateCodeList( YuiSh *sh2, u32 addr) {
  /* refresh the assembler view. <addr> points the line to be highlighted. */

  int i, j;
  char lineBuf[64];
  u32 offset;
  GtkTreeIter iter;
  unsigned int address;
  char address_s[20];
  char command_s[64];
  codebreakpoint_struct *cbp;

  gtk_list_store_clear(sh2->store);

  if ( addr - sh2->lastCode >= 20*2 ) offset = addr - (8*2);
  else offset = sh2->lastCode;
  sh2->lastCode = offset;

  cbp = SH2GetBreakpointList(sh2->debugsh);

  for (i = 0; i < 24; i++) {
    SH2Disasm(offset+2*i, MappedMemoryReadWord(offset+2*i), 0, lineBuf);

    sscanf(lineBuf, "0x%8X: %[^\n]", &address, command_s);
    sprintf(address_s, "0x%08X", address);

    gtk_list_store_append(sh2->store, &iter);
    if ( offset + 2*i == addr ) {
      gtk_list_store_set(sh2->store, &iter, 0, GTK_STOCK_GO_FORWARD, -1);
    } else {
      for (j = 0;j < MAX_BREAKPOINTS - 1;j++) {
        if (cbp[j].addr == address) {
          gtk_list_store_set(sh2->store, &iter, 0, GTK_STOCK_STOP, -1);
        }
      }
    }

    gtk_list_store_set(sh2->store, &iter, 1, address_s, -1);

    gtk_list_store_set(sh2->store, &iter, 2, command_s, -1);
  }
}

static void yui_sh_step( GtkWidget* widget, YuiSh * sh2 ) {

  SH2Step(sh2->debugsh);
  yui_window_invalidate( yui ); /* update all dialogs, including us */
}

static void yui_sh_editedReg( GtkCellRendererText *cellrenderertext,
			      gchar *arg1,
			      gchar *arg2,
			      YuiSh *sh2) {
  /* registry number <arg1> value has been set to <arg2> */

  GtkTreeIter iter;
  char bptext[10];
  char *endptr;
  int i = atoi(arg1);
  u32 addr;

  gtk_tree_model_get_iter_from_string( GTK_TREE_MODEL( sh2->regListStore ), &iter, arg1 );
  addr = strtoul(arg2, &endptr, 16 );
  if ( endptr - arg2 == strlen(arg2) ) {
   
    sprintf(bptext, "%08X", (int)addr);
    sh2setRegister( sh2, i, addr );
    gtk_list_store_set( GTK_LIST_STORE( sh2->regListStore ), &iter, 1, bptext, -1 );
  }
  yui_window_invalidate( yui );
}

static void yui_sh_editedBp( GtkCellRendererText *cellrenderertext,
			     gchar *arg1,
			     gchar *arg2,
			     YuiSh *sh2) {
  /* breakpoint <arg1> has been set to address <arg2> */

  GtkTreeIter iter;
  char *endptr;
  unsigned int addr;
  gchar * oldaddr_s;
  unsigned int oldaddr;

  gtk_tree_model_get_iter_from_string( GTK_TREE_MODEL( sh2->bpListStore ), &iter, arg1 );

  gtk_tree_model_get(GTK_TREE_MODEL( sh2->bpListStore ), &iter, 0, &oldaddr_s, -1);
  sscanf(oldaddr_s, "%8X", &oldaddr);
  g_free(oldaddr_s);

  SH2DelCodeBreakpoint(sh2->debugsh, oldaddr);

  addr = strtoul(arg2, &endptr, 16 );
  if ((endptr - arg2 < strlen(arg2)) || (!addr)) addr = 0xFFFFFFFF;

  if (addr != 0xFFFFFFFF) {
    SH2AddCodeBreakpoint(sh2->debugsh, addr);
  }

  {
    sh2regs_struct sh2regs;
    SH2GetRegisters(sh2->debugsh, &sh2regs);
    SH2UpdateCodeList(sh2,sh2regs.PC);
    SH2UpdateBreakpointList(sh2);
  }
}

static void yui_sh_editedMbp( GtkCellRendererText *cellrenderertext,
			     gchar *arg1,
			     gchar *arg2,
			      YuiSh *sh2) {
  /* breakpoint <arg1> has been set to address <arg2> */
  
  GtkTreeIter iter;
  gchar *endptr;
  unsigned int addr;
  gchar * oldaddr_s, * flags_s;
  unsigned int oldaddr;
  u32 flags;

  gtk_tree_model_get_iter_from_string( GTK_TREE_MODEL( sh2->mbpListStore ), &iter, arg1 );

  gtk_tree_model_get(GTK_TREE_MODEL( sh2->mbpListStore ), &iter, 0, &oldaddr_s, -1);
  sscanf(oldaddr_s, "%8X", &oldaddr);
  g_free(oldaddr_s);

  gtk_tree_model_get(GTK_TREE_MODEL( sh2->mbpListStore ), &iter, 1, &flags_s, -1);

  SH2DelMemoryBreakpoint(sh2->debugsh, oldaddr);

  addr = strtoul(arg2, &endptr, 16 );
  if (!addr) addr = 0xFFFFFFFF;
  
  if (addr!=0xFFFFFFFF) {
    
    flags = 0;
    endptr = flags_s;
    while ( *endptr ) {
      
      switch (*endptr) {
	
      case 'b': flags |= BREAK_BYTEREAD; break;
      case 'w': flags |= BREAK_WORDREAD; break;
      case 'l': flags |= BREAK_LONGREAD; break;
      case 'B': flags |= BREAK_BYTEWRITE; break;
      case 'W': flags |= BREAK_WORDWRITE; break;
      case 'L': flags |= BREAK_LONGWRITE; break;
      }
      endptr++;
    }
    
    if ( !flags ) flags = BREAK_BYTEREAD|BREAK_WORDREAD|BREAK_LONGREAD|BREAK_BYTEWRITE|BREAK_WORDWRITE|BREAK_LONGWRITE;
    SH2AddMemoryBreakpoint(sh2->debugsh, addr, flags);
  }

  SH2UpdateMemoryBreakpointList(sh2);
}

static void yui_sh_editedMbpFlags( GtkCellRendererText *cellrenderertext,
			     gchar *arg1,
			     gchar *arg2,
			      YuiSh *sh2) {
  /* breakpoint <arg1> has been set to address <arg2> */
  
  GtkTreeIter iter;
  gchar *endptr;
  unsigned int addr;
  gchar * addr_s;
  u32 flags = 0;

  gtk_tree_model_get_iter_from_string( GTK_TREE_MODEL( sh2->mbpListStore ), &iter, arg1 );

  gtk_tree_model_get(GTK_TREE_MODEL( sh2->mbpListStore ), &iter, 0, &addr_s, -1);
  sscanf(addr_s, "%8X", &addr);
  g_free(addr_s);

  SH2DelMemoryBreakpoint(sh2->debugsh, addr);

  endptr = arg2;
    
  while ( *endptr ) {
      
    switch (*endptr) {
	
      case 'b': flags |= BREAK_BYTEREAD; break;
      case 'w': flags |= BREAK_WORDREAD; break;
      case 'l': flags |= BREAK_LONGREAD; break;
      case 'B': flags |= BREAK_BYTEWRITE; break;
      case 'W': flags |= BREAK_WORDWRITE; break;
      case 'L': flags |= BREAK_LONGWRITE; break;
      }
      endptr++;
  }
    
  SH2AddMemoryBreakpoint(sh2->debugsh, addr, flags);

  SH2UpdateMemoryBreakpointList(sh2);
}

static void debugPauseLoop(void) { /* secondary gtk event loop for the "breakpoint pause" state */

  while ( !(yui->state & YUI_IS_RUNNING) )
    if ( gtk_main_iteration() ) return;
}

static void SH2BreakpointHandler (SH2_struct *context, u32 addr, void *userdata) {

  yui_window_pause(yui);
  {
    sh2regs_struct sh2regs;
    YuiSh* sh2 = YUI_SH(yui_sh_new( yui, context == MSH2 ));
    
    SH2GetRegisters(sh2->debugsh, &sh2regs);
    SH2UpdateRegList(sh2, &sh2regs);
    SH2UpdateCodeList(sh2, sh2regs.PC);  
  }
  debugPauseLoop(); /* execution is suspended inside a normal cycle - enter secondary gtk loop */
}


void yui_sh_update(YuiSh * sh) {
  sh2regs_struct sh2regs;
  SH2GetRegisters(sh->debugsh, &sh2regs);
  SH2UpdateCodeList(sh,sh2regs.PC);
  SH2UpdateRegList(sh, &sh2regs);	
  gtk_widget_set_sensitive(sh->bpList, TRUE);
  gtk_widget_set_sensitive(sh->mbpList, TRUE);
  gtk_widget_set_sensitive(sh->regList, TRUE);
  gtk_widget_set_sensitive(GTK_WIDGET(sh->buttonStep), 
			   !sh->debugsh->isIdle && !(( sh->debugsh == SSH2 )&&( !yabsys.IsSSH2Running )));
}

void yui_sh_destroy(YuiSh * sh) {
  g_signal_handler_disconnect(yui, sh->running_handler);
  g_signal_handler_disconnect(yui, sh->paused_handler);
  
  if ( sh->bMaster ) yui_msh = NULL;
  else yui_ssh = NULL;

  gtk_widget_destroy(GTK_WIDGET(sh));
}

static void yui_sh_clear(YuiSh * sh) {
  
  gtk_widget_set_sensitive(sh->bpList, FALSE);
  gtk_widget_set_sensitive(sh->mbpList, FALSE);
  gtk_widget_set_sensitive(sh->regList, FALSE);
  gtk_widget_set_sensitive(GTK_WIDGET(sh->buttonStep), FALSE);

  gtk_list_store_clear(sh->store);
}

gint yui_sh_popup(GtkWidget * widget, GdkEvent * event, gpointer data)
{
  GtkMenu *menu;
  GdkEventButton *event_button;

  g_return_val_if_fail (data != NULL, FALSE);
  g_return_val_if_fail (GTK_IS_MENU (data), FALSE);
  g_return_val_if_fail (event != NULL, FALSE);

  menu = GTK_MENU(data);

  if (event->type == GDK_BUTTON_PRESS) {
      event_button = (GdkEventButton *) event;
      if (event_button->button == 3) {
	  gtk_menu_popup (menu, NULL, NULL, NULL, NULL, event_button->button, event_button->time);
      }
  }

  return FALSE;
}

void yui_sh_popup_add_bp(GtkMenuItem * menuitem, gpointer user_data) {
	YuiSh * sh2 = user_data;
	GtkTreeView * view = GTK_TREE_VIEW(sh2->view);
	GtkTreeSelection * selection;
	GtkTreeModel * model;
	GtkTreeIter iter;
	gchar * address_s;
	unsigned int address;

	selection = gtk_tree_view_get_selection(view);

	gtk_tree_selection_get_selected(selection, &model, &iter);

	gtk_tree_model_get(model, &iter, 1, &address_s, -1);

	sscanf(address_s, "0x%08X", &address);

	SH2AddCodeBreakpoint(sh2->debugsh, address);

	g_free(address_s);

	{
		sh2regs_struct sh2regs;
		SH2GetRegisters(sh2->debugsh, &sh2regs);
		SH2UpdateCodeList(sh2,sh2regs.PC);
		SH2UpdateBreakpointList(sh2);
	}
}

void yui_sh_popup_del_bp(GtkMenuItem * menuitem, gpointer user_data) {
	YuiSh * sh2 = user_data;
	GtkTreeView * view = GTK_TREE_VIEW(sh2->view);
	GtkTreeSelection * selection;
	GtkTreeModel * model;
	GtkTreeIter iter;
	gchar * address_s;
	unsigned int address;

	selection = gtk_tree_view_get_selection(view);

	gtk_tree_selection_get_selected(selection, &model, &iter);

	gtk_tree_model_get(model, &iter, 1, &address_s, -1);

	sscanf(address_s, "0x%08X", &address);

	SH2DelCodeBreakpoint(sh2->debugsh, address);

	g_free(address_s);

	{
		sh2regs_struct sh2regs;
		SH2GetRegisters(sh2->debugsh, &sh2regs);
		SH2UpdateCodeList(sh2,sh2regs.PC);
		SH2UpdateBreakpointList(sh2);
	}
}

static void yui_sh_bp_add(GtkEntry * entry, gpointer user_data) {
	YuiSh * sh2 = user_data;
	const gchar * address_s;
	unsigned int address;

	address_s = gtk_entry_get_text(entry);

	if (*address_s == 0) return;

	sscanf(address_s, "%8X", &address);

	SH2AddCodeBreakpoint(sh2->debugsh, address);

	gtk_entry_set_text(entry, "");

	{
		sh2regs_struct sh2regs;
		SH2GetRegisters(sh2->debugsh, &sh2regs);
		SH2UpdateCodeList(sh2,sh2regs.PC);
		SH2UpdateBreakpointList(sh2);
	}
}

static void yui_sh_button_bp_add(GtkWidget * widget, gpointer user_data) {
	g_signal_emit_by_name(user_data, "activate");
}

static void yui_sh_mbp_add(GtkEntry * entry, gpointer user_data) {
	YuiSh * sh2 = user_data;
	const gchar * address_s;
	unsigned int address;

	address_s = gtk_entry_get_text(entry);

	if (*address_s == 0) return;

	sscanf(address_s, "%8X", &address);

	SH2AddMemoryBreakpoint(sh2->debugsh, address, BREAK_BYTEREAD|BREAK_WORDREAD|BREAK_LONGREAD|BREAK_BYTEWRITE|BREAK_WORDWRITE|BREAK_LONGWRITE);

	gtk_entry_set_text(entry, "");

	SH2UpdateMemoryBreakpointList(sh2);
}

gint yui_sh_mbp_popup(GtkWidget * widget, GdkEventButton * event, gpointer data)
{
  GtkMenu *menu;
  GdkEventButton *event_button;
  YuiSh * sh2 = data;
  GtkTreeView * view;
  GtkTreeSelection * selection;
  GtkTreeIter iter;
  GtkTreeModel * model;
  gchar * flags_s;
  char *endptr;
  int i;
  guint signal_id;

  g_return_val_if_fail (data != NULL, FALSE);
  g_return_val_if_fail (event != NULL, FALSE);

  view  = GTK_TREE_VIEW(sh2->mbpList);
  menu = GTK_MENU(sh2->mbp_menu);

  if (event->type == GDK_BUTTON_PRESS) {
      event_button = (GdkEventButton *) event;
      if (event_button->button == 3) {

           GtkTreePath *path;

	  selection = gtk_tree_view_get_selection(view);

           if (gtk_tree_view_get_path_at_pos(GTK_TREE_VIEW(view), event->x, event->y, &path, NULL, NULL, NULL)) {
               gtk_tree_selection_unselect_all(selection);
               gtk_tree_selection_select_path(selection, path);
               gtk_tree_path_free(path);
           } 

	  gtk_tree_selection_get_selected(selection, &model, &iter);

          if (gtk_tree_selection_count_selected_rows(selection) == 0) return FALSE;

	  gtk_tree_model_get(model, &iter, 1, &flags_s, -1);

          signal_id = g_signal_lookup("activate", GTK_TYPE_CHECK_MENU_ITEM);

          for(i = 0;i < 6;i++) g_signal_handlers_block_matched(sh2->mbp_menu_item[i], G_SIGNAL_MATCH_DATA, signal_id, 0, NULL, NULL, sh2);

          for(i = 0;i < 6;i++) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(sh2->mbp_menu_item[i]), FALSE);

          endptr = flags_s;
          while ( *endptr ) {
              switch (*endptr) {
	
                  case 'b': gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(sh2->mbp_menu_item[0]), TRUE); break;
                  case 'w': gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(sh2->mbp_menu_item[1]), TRUE); break;
                  case 'l': gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(sh2->mbp_menu_item[2]), TRUE); break;
                  case 'B': gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(sh2->mbp_menu_item[3]), TRUE); break;
                  case 'W': gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(sh2->mbp_menu_item[4]), TRUE); break;
                  case 'L': gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(sh2->mbp_menu_item[5]), TRUE); break;
              }
              endptr++;
          }

          for(i = 0;i < 6;i++) g_signal_handlers_unblock_matched(sh2->mbp_menu_item[i], G_SIGNAL_MATCH_DATA, signal_id, 0, NULL, NULL, sh2);

	  gtk_menu_popup (menu, NULL, NULL, NULL, NULL, event_button->button, event_button->time);
      }
  }

  return FALSE;
}

void yui_sh_mbp_toggle_flag(GtkWidget * menuitem, gpointer user_data) {
	GtkTreeSelection * selection;
	YuiSh * sh2 = user_data;
	GtkTreeIter iter;
	GtkTreeModel * model;
	gchar * address_s, * flags_s;
	unsigned int address;
	u32 flags;
	GtkTreeView * view;
	char *endptr;

	view  = GTK_TREE_VIEW(sh2->mbpList);

	  selection = gtk_tree_view_get_selection(view);

	  gtk_tree_selection_get_selected(selection, &model, &iter);

	  gtk_tree_model_get(model, &iter, 0, &address_s, -1);
	  gtk_tree_model_get(model, &iter, 1, &flags_s, -1);
          sscanf(address_s, "%8X", &address);

          SH2DelMemoryBreakpoint(sh2->debugsh, address);

          flags = 0;
          endptr = flags_s;
          while ( *endptr ) {
              switch (*endptr) {
                  case 'b': flags |= BREAK_BYTEREAD; break;
                  case 'w': flags |= BREAK_WORDREAD; break;
                  case 'l': flags |= BREAK_LONGREAD; break;
                  case 'B': flags |= BREAK_BYTEWRITE; break;
                  case 'W': flags |= BREAK_WORDWRITE; break;
                  case 'L': flags |= BREAK_LONGWRITE; break;
              }
              endptr++;
          }

	  if (menuitem == sh2->mbp_menu_item[0]) flags = (flags & ~BREAK_BYTEREAD) | (~flags & BREAK_BYTEREAD);
	  if (menuitem == sh2->mbp_menu_item[1]) flags = (flags & ~BREAK_WORDREAD) | (~flags & BREAK_WORDREAD);
	  if (menuitem == sh2->mbp_menu_item[2]) flags = (flags & ~BREAK_LONGREAD) | (~flags & BREAK_LONGREAD);
	  if (menuitem == sh2->mbp_menu_item[3]) flags = (flags & ~BREAK_BYTEWRITE) | (~flags & BREAK_BYTEWRITE);
	  if (menuitem == sh2->mbp_menu_item[4]) flags = (flags & ~BREAK_WORDWRITE) | (~flags & BREAK_WORDWRITE);
	  if (menuitem == sh2->mbp_menu_item[5]) flags = (flags & ~BREAK_LONGWRITE) | (~flags & BREAK_LONGWRITE);

          SH2AddMemoryBreakpoint(sh2->debugsh, address, flags);

	SH2UpdateMemoryBreakpointList(sh2);
}

void yui_sh_mbp_remove(GtkWidget * menuitem, gpointer user_data) {
	GtkTreeSelection * selection;
	YuiSh * sh2 = user_data;
	GtkTreeIter iter;
	GtkTreeModel * model;
	gchar * address_s;
	unsigned int address;
	GtkTreeView * view;

	view  = GTK_TREE_VIEW(sh2->mbpList);

	  selection = gtk_tree_view_get_selection(view);

	  gtk_tree_selection_get_selected(selection, &model, &iter);

	  gtk_tree_model_get(model, &iter, 0, &address_s, -1);
          sscanf(address_s, "%8X", &address);

          SH2DelMemoryBreakpoint(sh2->debugsh, address);

	SH2UpdateMemoryBreakpointList(sh2);
}

void yui_sh_mbp_clear(GtkWidget * menuitem, gpointer user_data) {
	YuiSh * sh2 = user_data;

	SH2ClearMemoryBreakpoints(sh2->debugsh);

	SH2UpdateMemoryBreakpointList(sh2);
}

gint yui_sh_bp_popup(GtkWidget * widget, GdkEventButton * event, gpointer data)
{
  GtkMenu *menu;
  GdkEventButton *event_button;
  YuiSh * sh2 = data;

  g_return_val_if_fail (data != NULL, FALSE);
  g_return_val_if_fail (event != NULL, FALSE);

  menu = GTK_MENU(sh2->bp_menu);

  if (event->type == GDK_BUTTON_PRESS) {
      event_button = (GdkEventButton *) event;
      if (event_button->button == 3) {
	  gtk_menu_popup (menu, NULL, NULL, NULL, NULL, event_button->button, event_button->time);
      }
  }

  return FALSE;
}

void yui_sh_bp_remove(GtkWidget * menuitem, gpointer user_data) {
	GtkTreeSelection * selection;
	YuiSh * sh2 = user_data;
	GtkTreeIter iter;
	GtkTreeModel * model;
	gchar * address_s;
	unsigned int address;
	GtkTreeView * view;

	view  = GTK_TREE_VIEW(sh2->bpList);

	  selection = gtk_tree_view_get_selection(view);

	  gtk_tree_selection_get_selected(selection, &model, &iter);

	  gtk_tree_model_get(model, &iter, 0, &address_s, -1);
          sscanf(address_s, "%8X", &address);

          SH2DelCodeBreakpoint(sh2->debugsh, address);

	{
		sh2regs_struct sh2regs;
		SH2GetRegisters(sh2->debugsh, &sh2regs);
		SH2UpdateCodeList(sh2,sh2regs.PC);
		SH2UpdateBreakpointList(sh2);
	}
}

void yui_sh_bp_clear(GtkWidget * menuitem, gpointer user_data) {
	YuiSh * sh2 = user_data;

	SH2ClearCodeBreakpoints(sh2->debugsh);

	{
		sh2regs_struct sh2regs;
		SH2GetRegisters(sh2->debugsh, &sh2regs);
		SH2UpdateCodeList(sh2,sh2regs.PC);
		SH2UpdateBreakpointList(sh2);
	}
}
