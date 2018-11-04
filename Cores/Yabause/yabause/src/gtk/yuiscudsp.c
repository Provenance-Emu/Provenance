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

#include "yuiscudsp.h"
#include "../scu.h"
#include "../yabause.h"
#include "settings.h"

static void yui_scudsp_class_init	(YuiScudspClass * klass);
static void yui_scudsp_init		(YuiScudsp      * yfe);
static void yui_scudsp_clear(YuiScudsp * scudsp);
static void yui_scudsp_editedReg( GtkCellRendererText *cellrenderertext,
			      gchar *arg1,
			      gchar *arg2,
			      YuiScudsp *scudsp);
static void yui_scudsp_editedBp( GtkCellRendererText *cellrenderertext,
			     gchar *arg1,
			     gchar *arg2,
			     YuiScudsp *scudsp);
static void yui_scudsp_step( GtkWidget* widget, YuiScudsp * scudsp );
static void yui_scudsp_breakpoint_handler (u32 addr);

static YuiScudsp *yui_scudsp;
static YuiWindow * yui;

GType yui_scudsp_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiScudspClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_scudsp_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiScudsp),
	0,
	(GInstanceInitFunc) yui_scudsp_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_WINDOW, "YuiScudsp", &yfe_info, 0);
    }

  return yfe_type;
}

static void yui_scudsp_class_init (UNUSED YuiScudspClass * klass) {
}

static void yui_scudsp_init (YuiScudsp * scudsp) {
  gtk_window_set_title(GTK_WINDOW(scudsp), "SCU-DSP");
  gtk_window_set_resizable( GTK_WINDOW(scudsp), FALSE );

  scudsp->vbox = gtk_vbox_new(FALSE, 2);
  gtk_container_set_border_width( GTK_CONTAINER( scudsp->vbox ),4 );
  gtk_container_add (GTK_CONTAINER (scudsp), scudsp->vbox);  

  scudsp->hboxmain = gtk_hbox_new(FALSE, 2);
  gtk_container_set_border_width( GTK_CONTAINER( scudsp->hboxmain ),4 );
  gtk_box_pack_start( GTK_BOX( scudsp->vbox ), scudsp->hboxmain, FALSE, FALSE, 4 );

  scudsp->hbox = gtk_hbutton_box_new();
  gtk_container_set_border_width( GTK_CONTAINER( scudsp->hbox ),4 );
  gtk_box_pack_start( GTK_BOX( scudsp->vbox ), scudsp->hbox, FALSE, FALSE, 4 ); 

  scudsp->vboxmain = gtk_vbox_new(FALSE, 2);
  gtk_container_set_border_width( GTK_CONTAINER( scudsp->vboxmain ),4 );
  gtk_box_pack_start( GTK_BOX( scudsp->hboxmain ), scudsp->vboxmain, FALSE, FALSE, 4 );

  /* unassembler frame */

  scudsp->uFrame = gtk_frame_new("Disassembled code");
  gtk_box_pack_start( GTK_BOX( scudsp->vboxmain ), scudsp->uFrame, FALSE, FALSE, 4 );
  
  scudsp->uLabel = gtk_label_new(NULL);
  gtk_container_add (GTK_CONTAINER (scudsp->uFrame), scudsp->uLabel );

  /* Register list */

  scudsp->regListStore = gtk_list_store_new(2,G_TYPE_STRING,G_TYPE_STRING);
  scudsp->regList = gtk_tree_view_new_with_model( GTK_TREE_MODEL(scudsp->regListStore) );
  scudsp->regListRenderer1 = gtk_cell_renderer_text_new();
  scudsp->regListRenderer2 = gtk_cell_renderer_text_new();
  g_object_set(G_OBJECT(scudsp->regListRenderer2), "editable", TRUE, "mode", GTK_CELL_RENDERER_MODE_EDITABLE, NULL );
  scudsp->regListColumn1 = gtk_tree_view_column_new_with_attributes("Register", scudsp->regListRenderer1, "text", 0, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(scudsp->regList), scudsp->regListColumn1);
  scudsp->regListColumn2 = gtk_tree_view_column_new_with_attributes("Value", scudsp->regListRenderer2, "text", 1, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(scudsp->regList), scudsp->regListColumn2);
  gtk_box_pack_start( GTK_BOX( scudsp->hboxmain ), scudsp->regList, FALSE, FALSE, 4 );
  g_signal_connect(G_OBJECT(scudsp->regListRenderer2), "edited", GTK_SIGNAL_FUNC(yui_scudsp_editedReg), scudsp );

  /* breakpoint list */

  scudsp->bpListStore = gtk_list_store_new(1,G_TYPE_STRING);
  scudsp->bpList = gtk_tree_view_new_with_model( GTK_TREE_MODEL(scudsp->bpListStore) );
  scudsp->bpListRenderer = gtk_cell_renderer_text_new();
  g_object_set(G_OBJECT(scudsp->bpListRenderer), "editable", TRUE, "mode", GTK_CELL_RENDERER_MODE_EDITABLE, NULL );
  scudsp->bpListColumn = gtk_tree_view_column_new_with_attributes("Breakpoints", scudsp->bpListRenderer, "text", 0, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(scudsp->bpList), scudsp->bpListColumn);
  gtk_box_pack_start( GTK_BOX( scudsp->hboxmain ), scudsp->bpList, FALSE, FALSE, 4 );
  g_signal_connect(G_OBJECT(scudsp->bpListRenderer), "edited", GTK_SIGNAL_FUNC(yui_scudsp_editedBp), scudsp );

  g_signal_connect(G_OBJECT(scudsp), "delete-event", GTK_SIGNAL_FUNC(yui_scudsp_destroy), NULL);
}


GtkWidget * yui_scudsp_new(YuiWindow * y) {
  GtkWidget * dialog;
  GClosure *closureF7;
  GtkAccelGroup *accelGroup;
  const scucodebreakpoint_struct *cbp;
  gint i;
  yui = y;

  if ( yui_scudsp ) return GTK_WIDGET(yui_scudsp);
  
  dialog = GTK_WIDGET(g_object_new(yui_scudsp_get_type(), NULL));
  yui_scudsp = YUI_SCUDSP(dialog);

  if (!( yui->state & YUI_IS_INIT )) {
    yui_window_run(yui);
    yui_window_pause(yui);
  }

  ScuDspSetBreakpointCallBack(&yui_scudsp_breakpoint_handler);

  for (i = 0; i < 23 ; i++) {
    
    GtkTreeIter iter;
    gtk_list_store_append( GTK_LIST_STORE( yui_scudsp->regListStore ), &iter );
  }	
  
  cbp = ScuDspGetBreakpointList();
  
  for (i = 0; i < MAX_BREAKPOINTS; i++) {
    
    GtkTreeIter iter;
    yui_scudsp->cbp[i] = cbp[i].addr;
    gtk_list_store_append( GTK_LIST_STORE( yui_scudsp->bpListStore ), &iter );
    if (cbp[i].addr != 0xFFFFFFFF) {
      
      gchar tempstr[20];
      sprintf(tempstr, "%08X", (int)cbp[i].addr);
      gtk_list_store_set( GTK_LIST_STORE( yui_scudsp->bpListStore ), &iter, 0, tempstr, -1 );
    } else gtk_list_store_set( GTK_LIST_STORE( yui_scudsp->bpListStore ), &iter, 0, "<empty>", -1 );
  } 

  {
    GtkWidget * but2, * but3, * but4;
    
    yui_scudsp->buttonStep = gtk_button_new_with_label( "Step [F7]" );
    gtk_box_pack_start( GTK_BOX( yui_scudsp->hbox ), yui_scudsp->buttonStep, FALSE, FALSE, 2 );
    g_signal_connect( yui_scudsp->buttonStep, "clicked", G_CALLBACK(yui_scudsp_step), yui_scudsp );
    
    but2 = gtk_button_new();
    gtk_action_connect_proxy(gtk_action_group_get_action(yui->action_group, "run"), but2);
    gtk_box_pack_start(GTK_BOX(yui_scudsp->hbox), but2, FALSE, FALSE, 2);
    
    but3 = gtk_button_new();
    gtk_action_connect_proxy(gtk_action_group_get_action(yui->action_group, "pause"), but3);
    gtk_box_pack_start(GTK_BOX(yui_scudsp->hbox), but3, FALSE, FALSE, 2);
    
    but4 = gtk_button_new_from_stock("gtk-close");
    g_signal_connect_swapped(but4, "clicked", G_CALLBACK(yui_scudsp_destroy), dialog);
    gtk_box_pack_start(GTK_BOX(yui_scudsp->hbox), but4, FALSE, FALSE, 2);
  }
  yui_scudsp->paused_handler = g_signal_connect_swapped(yui, "paused", G_CALLBACK(yui_scudsp_update), yui_scudsp);
  yui_scudsp->running_handler = g_signal_connect_swapped(yui, "running", G_CALLBACK(yui_scudsp_clear), yui_scudsp);
  accelGroup = gtk_accel_group_new ();
  closureF7 = g_cclosure_new (G_CALLBACK (yui_scudsp_step), yui_scudsp, NULL);
  gtk_accel_group_connect( accelGroup, GDK_F7, 0, 0, closureF7 );
  gtk_window_add_accel_group( GTK_WINDOW( dialog ), accelGroup );
  
  yui_scudsp_update(yui_scudsp);
  if ( yui->state & YUI_IS_RUNNING ) yui_scudsp_clear(yui_scudsp);
  
  gtk_widget_show_all(GTK_WIDGET(yui_scudsp));
  
  return dialog;
}


static void yui_scudsp_update_reglist( YuiScudsp *scudsp, scudspregs_struct *regs) {
  /* refrescudsp the registery list */

  GtkTreeIter iter;
  char valuestr[32];
  
  gtk_tree_model_get_iter_first( GTK_TREE_MODEL( scudsp->regListStore ), &iter );
  sprintf(valuestr, "%d", regs->ProgControlPort.part.PR);
  gtk_list_store_set( GTK_LIST_STORE( scudsp->regListStore ), &iter, 0, "PR", 1, valuestr, -1 );

  #define SCUDSPUPDATEREGLISTp(rreg,format) \
  gtk_tree_model_iter_next( GTK_TREE_MODEL( scudsp->regListStore ), &iter ); \
  sprintf(valuestr, #format, (int)regs->ProgControlPort.part.rreg); \
  gtk_list_store_set( GTK_LIST_STORE( scudsp->regListStore ), &iter, 0, #rreg, 1, valuestr, -1 );
  #define SCUDSPUPDATEREGLIST(rreg,format) \
  gtk_tree_model_iter_next( GTK_TREE_MODEL( scudsp->regListStore ), &iter ); \
  sprintf(valuestr, #format, (int)regs->rreg); \
  gtk_list_store_set( GTK_LIST_STORE( scudsp->regListStore ), &iter, 0, #rreg, 1, valuestr, -1 );
  #define SCUDSPUPDATEREGLISTx(rreg,vreg,format) \
  gtk_tree_model_iter_next( GTK_TREE_MODEL( scudsp->regListStore ), &iter ); \
  sprintf(valuestr, #format, (int)(vreg)); \
  gtk_list_store_set( GTK_LIST_STORE( scudsp->regListStore ), &iter, 0, #rreg, 1, valuestr, -1 );
  
  SCUDSPUPDATEREGLISTp(EP,%d);
  SCUDSPUPDATEREGLISTp(T0,%d);
  SCUDSPUPDATEREGLISTp(S,%d);
  SCUDSPUPDATEREGLISTp(Z,%d);
  SCUDSPUPDATEREGLISTp(C,%d);
  SCUDSPUPDATEREGLISTp(V,%d);
  SCUDSPUPDATEREGLISTp(E,%d);
  SCUDSPUPDATEREGLISTp(ES,%d);
  SCUDSPUPDATEREGLISTp(EX,%d);
  SCUDSPUPDATEREGLISTp(LE,%d);
  SCUDSPUPDATEREGLISTp(P,%02X);
  SCUDSPUPDATEREGLIST(TOP,%02X);
  SCUDSPUPDATEREGLIST(LOP,%02X);
  gtk_tree_model_iter_next( GTK_TREE_MODEL( scudsp->regListStore ), &iter );
  sprintf(valuestr, "%08X", (int)(((u32)(regs->CT[0]))<<24 | ((u32)(regs->CT[1]))<<16 | ((u32)(regs->CT[2]))<<8 | ((u32)(regs->CT[3]))) );
  gtk_list_store_set( GTK_LIST_STORE( scudsp->regListStore ), &iter, 0, "CT", 1, valuestr, -1 );
  SCUDSPUPDATEREGLISTx(RA,regs->RA0,%08X);
  SCUDSPUPDATEREGLISTx(WA,regs->WA0,%08X);
  SCUDSPUPDATEREGLIST(RX,%08X);
  SCUDSPUPDATEREGLIST(RY,%08X);
  SCUDSPUPDATEREGLISTx(PH,regs->P.part.H & 0xFFFF,%04X);
  SCUDSPUPDATEREGLISTx(PL,regs->P.part.L & 0xFFFFFFFF,%08X);
  SCUDSPUPDATEREGLISTx(ACH,regs->AC.part.H & 0xFFFF,%04X);
  SCUDSPUPDATEREGLISTx(ACL,regs->AC.part.L & 0xFFFFFFFF,%08X);
}

static void scudspsetRegister( YuiScudsp *scudsp, int nReg, u32 value ) {
  /* set register number <nReg> to value <value> in proc <scudsp> */

  scudspregs_struct scudspregs;
  ScuDspGetRegisters(&scudspregs);

  switch ( nReg ) {
  case 0: scudspregs.ProgControlPort.part.PR = value; break;
  case 1: scudspregs.ProgControlPort.part.EP = value; break;
  case 2: scudspregs.ProgControlPort.part.T0 = value; break;
  case 3: scudspregs.ProgControlPort.part.S = value; break;
  case 4: scudspregs.ProgControlPort.part.Z = value; break;
  case 5: scudspregs.ProgControlPort.part.C = value; break;
  case 6: scudspregs.ProgControlPort.part.V = value; break;
  case 7: scudspregs.ProgControlPort.part.E = value; break;
  case 8: scudspregs.ProgControlPort.part.ES = value; break;
  case 9: scudspregs.ProgControlPort.part.EX = value; break;
  case 10: scudspregs.ProgControlPort.part.LE = value; break;
  case 11: scudspregs.ProgControlPort.part.P = value; break;
  case 12: scudspregs.TOP = value; break;
  case 13: scudspregs.LOP = value; break;
  case 14: 
    scudspregs.CT[0] = (value>>24) & 0xff;
    scudspregs.CT[1] = (value>>16) & 0xff;
    scudspregs.CT[2] = (value>>8) & 0xff;
    scudspregs.CT[3] = (value) & 0xff;
    break;
  case 15: scudspregs.RA0 = value; break;
  case 16: scudspregs.WA0 = value; break;
  case 17: scudspregs.RX = value; break;
  case 18: scudspregs.RY = value; break;
  case 19: scudspregs.P.part.H = value; break;
  case 20: scudspregs.P.part.L = value; break;
  case 21: scudspregs.AC.part.H = value; break;
  case 22: scudspregs.AC.part.L = value; break;
  }

  ScuDspSetRegisters(&scudspregs);
}

static void yui_scudsp_update_codelist( YuiScudsp *scudsp, u32 addr) {
  /* refresh the assembler view. <addr> points the line to be highlighted. */

  int i;
  static char tagPC[] = "<span foreground=\"red\">";
  static char tagEnd[] = "</span>\n";
  char buf[100*24+40];
  char *curs = buf;
  char lineBuf[100];
  u32 offset;

  if ( addr - scudsp->lastCode >= 20 ) offset = addr - 8;
  else offset = scudsp->lastCode;
  scudsp->lastCode = offset;

  for (i=0; i < 24; i++) {

    if ( offset + i == addr ) { strcpy( curs, tagPC ); curs += strlen(tagPC); }
    ScuDspDisasm(offset+i, lineBuf);
    strcpy( curs, lineBuf );
    curs += strlen(lineBuf);
    if ( offset + i == addr ) { strcpy( curs, tagEnd ); curs += strlen(tagEnd); }
    else { strcpy( curs, "\n" ); curs += 1;}
  }
  *curs = 0;  

  gtk_label_set_markup( GTK_LABEL(scudsp->uLabel), buf );
}

static void yui_scudsp_step( GtkWidget* widget, YuiScudsp * scudsp ) {

  ScuDspStep();
  yui_window_invalidate( yui ); /* update all dialogs, including us */
}

static void yui_scudsp_editedReg( GtkCellRendererText *cellrenderertext,
			      gchar *arg1,
			      gchar *arg2,
			      YuiScudsp *scudsp) {
  /* registry number <arg1> value has been set to <arg2> */

  GtkTreeIter iter;
  char bptext[10];
  char *endptr;
  int i = atoi(arg1);
  u32 addr;

  gtk_tree_model_get_iter_from_string( GTK_TREE_MODEL( scudsp->regListStore ), &iter, arg1 );
  addr = strtoul(arg2, &endptr, 16 );
  if ( endptr - arg2 == strlen(arg2) ) {
   
    sprintf(bptext, "%08X", (int)addr);
    scudspsetRegister( scudsp, i, addr );
    gtk_list_store_set( GTK_LIST_STORE( scudsp->regListStore ), &iter, 1, bptext, -1 );
  }
  yui_window_invalidate( yui );
}

static void yui_scudsp_editedBp( GtkCellRendererText *cellrenderertext,
			     gchar *arg1,
			     gchar *arg2,
			     YuiScudsp *scudsp) {
  /* breakpoint <arg1> has been set to address <arg2> */

  GtkTreeIter iter;
  char bptext[10];
  char *endptr;
  int i = atoi(arg1);
  u32 addr;
  gtk_tree_model_get_iter_from_string( GTK_TREE_MODEL( scudsp->bpListStore ), &iter, arg1 );
  addr = strtoul(arg2, &endptr, 16 );
  if ((endptr - arg2 < strlen(arg2)) || (!addr)) addr = 0xFFFFFFFF;
  if ( scudsp->cbp[i] != 0xFFFFFFFF) ScuDspDelCodeBreakpoint(scudsp->cbp[i]);
  scudsp->cbp[i] = 0xFFFFFFFF;

  if ((addr!=0xFFFFFFFF)&&(ScuDspAddCodeBreakpoint(addr) == 0)) {
   
    sprintf(bptext, "%08X", (int)addr);
    scudsp->cbp[i] = addr;
  } else strcpy(bptext,"<empty>");
  gtk_list_store_set( GTK_LIST_STORE( scudsp->bpListStore ), &iter, 0, bptext, -1 );
}

static void debugPauseLoop(void) { /* secondary gtk event loop for the "breakpoint pause" state */

  while ( !(yui->state & YUI_IS_RUNNING) )
    if ( gtk_main_iteration() ) return;
}

static void yui_scudsp_breakpoint_handler (u32 addr) {

  yui_window_pause(yui);
  {
    scudspregs_struct scudspregs;
    YuiScudsp* scudsp = YUI_SCUDSP(yui_scudsp_new( yui ));
    
    ScuDspGetRegisters(&scudspregs);
    yui_scudsp_update_reglist(scudsp, &scudspregs);
    yui_scudsp_update_codelist(scudsp, scudspregs.PC);  
  }
  debugPauseLoop(); /* execution is suspended inside a normal cycle - enter secondary gtk loop */
}


void yui_scudsp_update(YuiScudsp * scudsp) {
  scudspregs_struct scudspregs;
  ScuDspGetRegisters(&scudspregs);
  yui_scudsp_update_codelist(scudsp,scudspregs.PC);
  yui_scudsp_update_reglist(scudsp, &scudspregs);	
  gtk_widget_set_sensitive(scudsp->uLabel, TRUE);
  gtk_widget_set_sensitive(scudsp->bpList, TRUE);
  gtk_widget_set_sensitive(scudsp->regList, TRUE);
  gtk_widget_set_sensitive(scudsp->buttonStep, TRUE);
}

void yui_scudsp_destroy(YuiScudsp * scudsp) {
  g_signal_handler_disconnect(yui, scudsp->running_handler);
  g_signal_handler_disconnect(yui, scudsp->paused_handler);
  
  yui_scudsp = NULL;

  gtk_widget_destroy(GTK_WIDGET(scudsp));
}

static void yui_scudsp_clear(YuiScudsp * scudsp) {
  
  gtk_widget_set_sensitive(scudsp->uLabel, FALSE);
  gtk_widget_set_sensitive(scudsp->bpList, FALSE);
  gtk_widget_set_sensitive(scudsp->regList, FALSE);
  gtk_widget_set_sensitive(scudsp->buttonStep, FALSE);
}
