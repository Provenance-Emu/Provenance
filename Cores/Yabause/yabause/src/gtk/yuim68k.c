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

#include <gtk/gtk.h>
#include <gdk/gdkkeysyms.h>

#include "yuim68k.h"
#include "../m68kd.h"
#include "../yabause.h"
#include "settings.h"

static void yui_m68k_class_init	(YuiM68kClass * klass);
static void yui_m68k_init		(YuiM68k      * yfe);
static void yui_m68k_clear(YuiM68k * m68k);
static void yui_m68k_editedReg( GtkCellRendererText *cellrenderertext,
			      gchar *arg1,
			      gchar *arg2,
			      YuiM68k *m68k);
static void yui_m68k_editedBp( GtkCellRendererText *cellrenderertext,
			     gchar *arg1,
			     gchar *arg2,
			     YuiM68k *m68k);
static void yui_m68k_step( GtkWidget* widget, YuiM68k * m68k );
static void yui_m68k_breakpoint_handler(u32 addr);

static YuiM68k *yui_m68k;
static YuiWindow * yui;

GType yui_m68k_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiM68kClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_m68k_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiM68k),
	0,
	(GInstanceInitFunc) yui_m68k_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_WINDOW, "YuiM68k", &yfe_info, 0);
    }

  return yfe_type;
}

static void yui_m68k_class_init (UNUSED YuiM68kClass * klass) {
}

static void yui_m68k_init (YuiM68k * m68k) {
  gtk_window_set_title(GTK_WINDOW(m68k), "M68K");
  gtk_window_set_resizable( GTK_WINDOW(m68k), FALSE );

  m68k->vbox = gtk_vbox_new(FALSE, 2);
  gtk_container_set_border_width( GTK_CONTAINER( m68k->vbox ),4 );
  gtk_container_add (GTK_CONTAINER (m68k), m68k->vbox);  

  m68k->hboxmain = gtk_hbox_new(FALSE, 2);
  gtk_container_set_border_width( GTK_CONTAINER( m68k->hboxmain ),4 );
  gtk_box_pack_start( GTK_BOX( m68k->vbox ), m68k->hboxmain, FALSE, FALSE, 4 );

  m68k->hbox = gtk_hbutton_box_new();
  gtk_container_set_border_width( GTK_CONTAINER( m68k->hbox ),4 );
  gtk_box_pack_start( GTK_BOX( m68k->vbox ), m68k->hbox, FALSE, FALSE, 4 ); 

  m68k->vboxmain = gtk_vbox_new(FALSE, 2);
  gtk_container_set_border_width( GTK_CONTAINER( m68k->vboxmain ),4 );
  gtk_box_pack_start( GTK_BOX( m68k->hboxmain ), m68k->vboxmain, FALSE, FALSE, 4 );

  /* unassembler frame */

  m68k->uFrame = gtk_frame_new("Disassembled code");
  gtk_box_pack_start( GTK_BOX( m68k->vboxmain ), m68k->uFrame, FALSE, FALSE, 4 );
  
  m68k->uLabel = gtk_label_new(NULL);
  gtk_container_add (GTK_CONTAINER (m68k->uFrame), m68k->uLabel );

  /* Register list */

  m68k->regListStore = gtk_list_store_new(2,G_TYPE_STRING,G_TYPE_STRING);
  m68k->regList = gtk_tree_view_new_with_model( GTK_TREE_MODEL(m68k->regListStore) );
  m68k->regListRenderer1 = gtk_cell_renderer_text_new();
  m68k->regListRenderer2 = gtk_cell_renderer_text_new();
  g_object_set(G_OBJECT(m68k->regListRenderer2), "editable", TRUE, "mode", GTK_CELL_RENDERER_MODE_EDITABLE, NULL );
  m68k->regListColumn1 = gtk_tree_view_column_new_with_attributes("Register", m68k->regListRenderer1, "text", 0, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(m68k->regList), m68k->regListColumn1);
  m68k->regListColumn2 = gtk_tree_view_column_new_with_attributes("Value", m68k->regListRenderer2, "text", 1, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(m68k->regList), m68k->regListColumn2);
  gtk_box_pack_start( GTK_BOX( m68k->hboxmain ), m68k->regList, FALSE, FALSE, 4 );
  g_signal_connect(G_OBJECT(m68k->regListRenderer2), "edited", GTK_SIGNAL_FUNC(yui_m68k_editedReg), m68k );

  /* breakpoint list */

  m68k->bpListStore = gtk_list_store_new(1,G_TYPE_STRING);
  m68k->bpList = gtk_tree_view_new_with_model( GTK_TREE_MODEL(m68k->bpListStore) );
  m68k->bpListRenderer = gtk_cell_renderer_text_new();
  g_object_set(G_OBJECT(m68k->bpListRenderer), "editable", TRUE, "mode", GTK_CELL_RENDERER_MODE_EDITABLE, NULL );
  m68k->bpListColumn = gtk_tree_view_column_new_with_attributes("Breakpoints", m68k->bpListRenderer, "text", 0, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(m68k->bpList), m68k->bpListColumn);
  gtk_box_pack_start( GTK_BOX( m68k->hboxmain ), m68k->bpList, FALSE, FALSE, 4 );
  g_signal_connect(G_OBJECT(m68k->bpListRenderer), "edited", GTK_SIGNAL_FUNC(yui_m68k_editedBp), m68k );

  g_signal_connect(G_OBJECT(m68k), "delete-event", GTK_SIGNAL_FUNC(yui_m68k_destroy), NULL);
}


GtkWidget * yui_m68k_new(YuiWindow * y) {
  GtkWidget * dialog;
  GClosure *closureF7;
  GtkAccelGroup *accelGroup;
  const m68kcodebreakpoint_struct *cbp;
  gint i;
  yui = y;

  if ( yui_m68k ) return GTK_WIDGET(yui_m68k);
  
  dialog = GTK_WIDGET(g_object_new(yui_m68k_get_type(), NULL));
  yui_m68k = YUI_M68K(dialog);

  if (!( yui->state & YUI_IS_INIT )) {
    yui_window_run(yui);
    yui_window_pause(yui);
  }

  M68KSetBreakpointCallBack(&yui_m68k_breakpoint_handler);

  for (i = 0; i < 23 ; i++) {
    
    GtkTreeIter iter;
    gtk_list_store_append( GTK_LIST_STORE( yui_m68k->regListStore ), &iter );
  }	
  
  cbp = M68KGetBreakpointList();
  
  for (i = 0; i < MAX_BREAKPOINTS ; i++) {
    
    GtkTreeIter iter;
    yui_m68k->cbp[i] = cbp[i].addr;
    gtk_list_store_append( GTK_LIST_STORE( yui_m68k->bpListStore ), &iter );
    if (cbp[i].addr != 0xFFFFFFFF) {
      
      gchar tempstr[20];
      sprintf(tempstr, "%08X", (int)cbp[i].addr);
      gtk_list_store_set( GTK_LIST_STORE( yui_m68k->bpListStore ), &iter, 0, tempstr, -1 );
    } else gtk_list_store_set( GTK_LIST_STORE( yui_m68k->bpListStore ), &iter, 0, "<empty>", -1 );
  } 

  {
    GtkWidget * but2, * but3, * but4;
    
    yui_m68k->buttonStep = gtk_button_new_with_label( "Step [F7]" );
    gtk_box_pack_start( GTK_BOX( yui_m68k->hbox ), yui_m68k->buttonStep, FALSE, FALSE, 2 );
    g_signal_connect( yui_m68k->buttonStep, "clicked", G_CALLBACK(yui_m68k_step), yui_m68k );
    
    but2 = gtk_button_new();
    gtk_action_connect_proxy(gtk_action_group_get_action(yui->action_group, "run"), but2);
    gtk_box_pack_start(GTK_BOX(yui_m68k->hbox), but2, FALSE, FALSE, 2);
    
    but3 = gtk_button_new();
    gtk_action_connect_proxy(gtk_action_group_get_action(yui->action_group, "pause"), but3);
    gtk_box_pack_start(GTK_BOX(yui_m68k->hbox), but3, FALSE, FALSE, 2);
    
    but4 = gtk_button_new_from_stock("gtk-close");
    g_signal_connect_swapped(but4, "clicked", G_CALLBACK(yui_m68k_destroy), dialog);
    gtk_box_pack_start(GTK_BOX(yui_m68k->hbox), but4, FALSE, FALSE, 2);
  }
  yui_m68k->paused_handler = g_signal_connect_swapped(yui, "paused", G_CALLBACK(yui_m68k_update), yui_m68k);
  yui_m68k->running_handler = g_signal_connect_swapped(yui, "running", G_CALLBACK(yui_m68k_clear), yui_m68k);
  accelGroup = gtk_accel_group_new ();
  closureF7 = g_cclosure_new (G_CALLBACK (yui_m68k_step), yui_m68k, NULL);
  gtk_accel_group_connect( accelGroup, GDK_F7, 0, 0, closureF7 );
  gtk_window_add_accel_group( GTK_WINDOW( dialog ), accelGroup );
  
  yui_m68k_update(yui_m68k);
  if ( yui->state & YUI_IS_RUNNING ) yui_m68k_clear(yui_m68k);
  
  gtk_widget_show_all(GTK_WIDGET(yui_m68k));
  
  return dialog;
}

static void yui_m68k_update_reglist( YuiM68k *m68k, m68kregs_struct *regs) {
  /* refresh the registery list */

  GtkTreeIter iter;
  char regstr[32];
  char valuestr[32];
  int i;
  
  for ( i = 0 ; i < 8 ; i++ ) {
    
    if ( i==0 ) gtk_tree_model_get_iter_first( GTK_TREE_MODEL( yui_m68k->regListStore ), &iter );
    else gtk_tree_model_iter_next( GTK_TREE_MODEL( yui_m68k->regListStore ), &iter );
    sprintf(regstr, "D%d", i );
    sprintf(valuestr, "%08x", (int)regs->D[i]);
    gtk_list_store_set( GTK_LIST_STORE( yui_m68k->regListStore ), &iter, 0, regstr, 1, valuestr, -1 );
  }
  for ( i = 0 ; i < 8 ; i++ ) {
    
    gtk_tree_model_iter_next( GTK_TREE_MODEL( yui_m68k->regListStore ), &iter );
    sprintf(regstr, "A%d", i );
    sprintf(valuestr, "%08x", (int)regs->A[i]);
    gtk_list_store_set( GTK_LIST_STORE( yui_m68k->regListStore ), &iter, 0, regstr, 1, valuestr, -1 );
  }

  gtk_tree_model_iter_next( GTK_TREE_MODEL( yui_m68k->regListStore ), &iter );
  sprintf(valuestr, "%08x", (int)regs->SR);
  gtk_list_store_set( GTK_LIST_STORE( yui_m68k->regListStore ), &iter, 0, "SR", 1, valuestr, -1 );

  gtk_tree_model_iter_next( GTK_TREE_MODEL( yui_m68k->regListStore ), &iter );
  sprintf(valuestr, "%08x", (int)regs->PC);
  gtk_list_store_set( GTK_LIST_STORE( yui_m68k->regListStore ), &iter, 0, "PC", 1, valuestr, -1 );
}

static void m68ksetRegister( YuiM68k *m68k, int nReg, u32 value ) {
  /* set register number <nReg> to value <value> in proc <m68k> */

  m68kregs_struct m68kregs;
  M68KGetRegisters(&m68kregs);

  if ( nReg < 8 ) m68kregs.D[nReg] = value;
  else if ( nReg < 16 ) m68kregs.A[nReg-8] = value;
  if ( nReg == 16 ) m68kregs.SR = value;
  if ( nReg == 17 ) m68kregs.PC = value;

  M68KSetRegisters(&m68kregs);
}

static void yui_m68k_update_codelist( YuiM68k *m68k, u32 addr) {
  /* refrem68k the assembler view. <addr> points the line to be highlighted. */

  int i;
  static char tagPC[] = "<span foreground=\"red\">";
  static char tagEnd[] = "</span>\n";
  char buf[64*24+40];
  char *curs = buf;
  char lineBuf[64];
  u8 bOnPC = 0;
  u32 offset;

  if ( addr - m68k->lastCode >= 22 ) offset = addr;
  else offset = m68k->lastCode;
  m68k->lastCode = offset;

  for (i=0; i < 24; i++) {

    if ( offset == addr ) { bOnPC = 1; strcpy( curs, tagPC ); curs += strlen(tagPC); }
    offset = M68KDisasm(offset, lineBuf);
    strcpy( curs, lineBuf );
    curs += strlen(lineBuf);
    if ( bOnPC ) { bOnPC = 0; strcpy( curs, tagEnd ); curs += strlen(tagEnd); }
    else { strcpy( curs, "\n" ); curs += 1;}
  }
  *curs = 0;
  gtk_label_set_markup( GTK_LABEL(m68k->uLabel), buf );
}

static void yui_m68k_step( GtkWidget* widget, YuiM68k * m68k ) {

  M68KStep();
  yui_window_invalidate( yui ); /* update all dialogs, including us */
}

static void yui_m68k_editedReg( GtkCellRendererText *cellrenderertext,
			      gchar *arg1,
			      gchar *arg2,
			      YuiM68k *m68k) {
  /* registry number <arg1> value has been set to <arg2> */

  GtkTreeIter iter;
  char bptext[10];
  char *endptr;
  int i = atoi(arg1);
  u32 addr;

  gtk_tree_model_get_iter_from_string( GTK_TREE_MODEL( m68k->regListStore ), &iter, arg1 );
  addr = strtoul(arg2, &endptr, 16 );
  if ( endptr - arg2 == strlen(arg2) ) {
   
    sprintf(bptext, "%08X", (int)addr);
    m68ksetRegister( m68k, i, addr );
    gtk_list_store_set( GTK_LIST_STORE( m68k->regListStore ), &iter, 1, bptext, -1 );
  }
  yui_window_invalidate( yui );
}

static void yui_m68k_editedBp( GtkCellRendererText *cellrenderertext,
			     gchar *arg1,
			     gchar *arg2,
			     YuiM68k *m68k) {
  /* breakpoint <arg1> has been set to address <arg2> */

  GtkTreeIter iter;
  char bptext[10];
  char *endptr;
  int i = atoi(arg1);
  u32 addr;
  gtk_tree_model_get_iter_from_string( GTK_TREE_MODEL( m68k->bpListStore ), &iter, arg1 );
  addr = strtoul(arg2, &endptr, 16 );
  if ((endptr - arg2 < strlen(arg2)) || (!addr)) addr = 0xFFFFFFFF;
  if ( m68k->cbp[i] != 0xFFFFFFFF) M68KDelCodeBreakpoint(m68k->cbp[i]);
  m68k->cbp[i] = 0xFFFFFFFF;

  if ((addr!=0xFFFFFFFF)&&(M68KAddCodeBreakpoint(addr) == 0)) {
   
    sprintf(bptext, "%08X", (int)addr);
    m68k->cbp[i] = addr;
  } else strcpy(bptext,"<empty>");
  gtk_list_store_set( GTK_LIST_STORE( m68k->bpListStore ), &iter, 0, bptext, -1 );
}

static void debugPauseLoop(void) { /* secondary gtk event loop for the "breakpoint pause" state */

  while ( !(yui->state & YUI_IS_RUNNING) )
    if ( gtk_main_iteration() ) return;
}

static void yui_m68k_breakpoint_handler (u32 addr) {

  yui_window_pause(yui);
  {
    m68kregs_struct regs;
    YuiM68k* m68k = YUI_M68K(yui_m68k_new( yui ));
    
    M68KGetRegisters(&regs);
    yui_m68k_update_codelist(m68k,regs.PC);
    yui_m68k_update_reglist(m68k,&regs);
  }
  debugPauseLoop(); /* execution is suspended inside a normal cycle - enter secondary gtk loop */
}


void yui_m68k_update(YuiM68k * m68k) {
  m68kregs_struct m68kregs;
  M68KGetRegisters(&m68kregs);
  yui_m68k_update_codelist(m68k,m68kregs.PC);
  yui_m68k_update_reglist(m68k, &m68kregs);	
  gtk_widget_set_sensitive(m68k->uLabel, TRUE);
  gtk_widget_set_sensitive(m68k->bpList, TRUE);
  gtk_widget_set_sensitive(m68k->regList, TRUE);
  gtk_widget_set_sensitive(m68k->buttonStep, TRUE);
}

void yui_m68k_destroy(YuiM68k * m68k) {
  g_signal_handler_disconnect(yui, m68k->running_handler);
  g_signal_handler_disconnect(yui, m68k->paused_handler);
  
  yui_m68k = NULL;

  gtk_widget_destroy(GTK_WIDGET(m68k));
}

static void yui_m68k_clear(YuiM68k * m68k) {
  
  gtk_widget_set_sensitive(m68k->uLabel, FALSE);
  gtk_widget_set_sensitive(m68k->bpList, FALSE);
  gtk_widget_set_sensitive(m68k->regList, FALSE);
  gtk_widget_set_sensitive(m68k->buttonStep, FALSE);
}
